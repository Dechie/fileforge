import 'dart:async';
import 'dart:io';

import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/contracts/engines/engines.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_args.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_progress.dart';
import 'package:fileforge/infrastructure/engines/linux/ffprobe_parser.dart';
import 'package:fileforge/infrastructure/filesystem/file_reference_io.dart';
import 'package:fileforge/infrastructure/platform/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Shared FFmpeg process runner used by the video and audio adapters.
class FfmpegCliEngine {
  FfmpegCliEngine({CommandRunner? runner})
    : _runner = runner ?? const CommandRunner();

  final CommandRunner _runner;
  final Uuid _ids = const Uuid();
  final StreamController<double> _progress =
      StreamController<double>.broadcast();

  ProcessHandle? _active;
  bool _busy = false;

  String get engineId => 'ffmpeg_cli';

  Stream<double> get progressStream => _progress.stream;

  Future<void> cancel() async {
    final handle = _active;
    if (handle == null) return;
    await handle.cancel();
  }

  Future<MediaMetadata> inspect(FileReference file) async {
    _ensureIdle();
    return _probe(fileReferencePath(file));
  }

  Future<MediaMetadata> _probe(String path) async {
    try {
      final result = await _runner.run('ffprobe', [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        path,
      ]);
      return FfprobeParser.parse(result.stdout);
    } on ProcessException catch (error) {
      if (isMissingExecutable(error)) {
        throw const DependencyMissingException('ffprobe');
      }
      throw FileValidationException(
        'Unable to inspect media: ${error.message}',
      );
    }
  }

  Future<ProcessingResult> runFfmpeg({
    required List<String> args,
    required String inputPath,
    String? outputPath,
    String? outputDirectory,
    bool reencoded = false,
    Map<String, dynamic> metrics = const {},
  }) async {
    _ensureIdle();
    _busy = true;
    final jobId = _ids.v4();
    final watch = Stopwatch()..start();
    try {
      if (!await File(inputPath).exists()) {
        throw const FileValidationException('Input file not found');
      }
      if (outputPath != null) {
        rejectOverwrite(inputPath, outputPath);
        final parent = Directory(p.dirname(outputPath));
        if (!await parent.exists()) await parent.create(recursive: true);
      }
      if (outputDirectory != null) {
        await Directory(outputDirectory).create(recursive: true);
      }

      _progress.add(0);
      Duration? total;
      try {
        total = (await _probe(inputPath)).duration;
      } catch (_) {
        total = null;
      }

      var lastSpeed = '';
      var lastFrame = 0;
      final captured = await _runner.startAndCapture(
        'ffmpeg',
        args,
        onStarted: (handle) => _active = handle,
        onStderrLine: (line) {
          final snapshot = FfmpegProgress.parse(line, total: total);
          if (snapshot.fraction != null) _progress.add(snapshot.fraction!);
          if (snapshot.speed != null) lastSpeed = snapshot.speed!;
          if (snapshot.frame != null) lastFrame = snapshot.frame!;
        },
      );
      watch.stop();

      if (captured.cancelled) {
        return ProcessingResult(
          jobId: jobId,
          success: false,
          errorMessage: 'Cancelled',
          elapsed: watch.elapsed,
        );
      }
      if (captured.exitCode != 0) {
        final message =
            captured.stderr.trim().isEmpty
                ? 'ffmpeg exited with code ${captured.exitCode}'
                : captured.stderr.trim();
        return ProcessingResult(
          jobId: jobId,
          success: false,
          errorMessage: message,
          elapsed: watch.elapsed,
        );
      }

      final resultMetrics = {
        'reencoded': reencoded,
        'streamCopy': !reencoded,
        'speed': lastSpeed,
        'frame': lastFrame,
        ...metrics,
      };

      if (outputDirectory != null) {
        final frames =
            Directory(outputDirectory)
                .listSync()
                .whereType<File>()
                .where((file) => file.path.toLowerCase().endsWith('.png'))
                .length;
        if (frames == 0) {
          return ProcessingResult(
            jobId: jobId,
            success: false,
            errorMessage: 'No frames were written',
            elapsed: watch.elapsed,
          );
        }
        _progress.add(1);
        return ProcessingResult(
          jobId: jobId,
          success: true,
          outputs: [await _artifact(jobId, outputDirectory, isDirectory: true)],
          elapsed: watch.elapsed,
          metrics: {...resultMetrics, 'frameCount': frames},
        );
      }

      final output = File(outputPath!);
      if (!await output.exists() || await output.length() == 0) {
        return ProcessingResult(
          jobId: jobId,
          success: false,
          errorMessage: 'Output file is missing or empty',
          elapsed: watch.elapsed,
        );
      }
      _progress.add(1);
      return ProcessingResult(
        jobId: jobId,
        success: true,
        outputs: [await _artifact(jobId, outputPath)],
        elapsed: watch.elapsed,
        metrics: resultMetrics,
      );
    } on ProcessException catch (error) {
      if (isMissingExecutable(error)) {
        throw const DependencyMissingException('ffmpeg');
      }
      rethrow;
    } finally {
      _busy = false;
      _active = null;
    }
  }

  void _ensureIdle() {
    if (_busy) {
      throw ProcessingException(engineId, message: 'Engine is already running');
    }
  }

  Future<OutputArtifact> _artifact(
    String jobId,
    String path, {
    bool isDirectory = false,
  }) async {
    int? size;
    if (!isDirectory) {
      final stat = await File(path).stat();
      size = stat.size;
    }
    final format = FileFormat.fromExtension(p.extension(path));
    return OutputArtifact(
      id: _ids.v4(),
      jobId: jobId,
      status: OutputArtifactStatus.completed,
      sizeBytes: size,
      file: FileReference(
        displayName: p.basename(path),
        uri: path,
        sizeBytes: size,
        detectedFormat: format,
        mimeType: format?.mimeTypes.first,
        hasWriteAccess: true,
      ),
    );
  }
}

/// Linux [VideoEngine] backed by the FFmpeg CLI.
class FfmpegVideoEngine extends FfmpegCliEngine implements VideoEngine {
  FfmpegVideoEngine({super.runner});

  @override
  Future<ProcessingResult> trim(
    FileReference file,
    Duration start,
    Duration end,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      args: FfmpegArgs.trim(
        inputPath: inputPath,
        outputPath: outputPath,
        start: start,
        end: end,
      ),
    );
  }

  @override
  Future<ProcessingResult> crop(
    FileReference file, {
    required int x,
    required int y,
    required int width,
    required int height,
    required String outputPath,
  }) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      reencoded: true,
      args: FfmpegArgs.crop(
        inputPath: inputPath,
        outputPath: outputPath,
        x: x,
        y: y,
        width: width,
        height: height,
      ),
      metrics: {'reason': 'crop'},
    );
  }

  @override
  Future<ProcessingResult> resize(
    FileReference file,
    int width,
    int height,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      reencoded: true,
      args: FfmpegArgs.resize(
        inputPath: inputPath,
        outputPath: outputPath,
        width: width,
        height: height,
      ),
      metrics: {'reason': 'resize'},
    );
  }

  @override
  Future<ProcessingResult> compress(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  ) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      reencoded: true,
      args: FfmpegArgs.compress(
        inputPath: inputPath,
        outputPath: outputPath,
        crf: FfmpegArgs.optionalCrf(options),
        preset: FfmpegArgs.optionalToken(options, 'preset', 'medium'),
        codec: FfmpegArgs.optionalToken(options, 'codec', 'libx264'),
      ),
      metrics: {'reason': 'compress', 'evenDimensions': true},
    );
  }

  @override
  Future<ProcessingResult> convertContainer(
    FileReference file,
    String outputPath,
    String targetContainer,
  ) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      args: FfmpegArgs.convertContainer(
        inputPath: inputPath,
        outputPath: outputPath,
      ),
      metrics: {'container': targetContainer, 'mode': 'stream_copy'},
    );
  }

  @override
  Future<ProcessingResult> extractAudio(FileReference file, String outputPath) {
    return _extractAudio(file, outputPath);
  }

  @override
  Future<ProcessingResult> removeAudio(FileReference file, String outputPath) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      args: FfmpegArgs.removeAudio(
        inputPath: inputPath,
        outputPath: outputPath,
      ),
    );
  }

  @override
  Future<ProcessingResult> extractFrames(
    FileReference file,
    String outputDir,
    double intervalSeconds,
  ) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputDirectory: outputDir,
      reencoded: true,
      args: FfmpegArgs.extractFrames(
        inputPath: inputPath,
        outputDirectory: outputDir,
        intervalSeconds: intervalSeconds,
      ),
    );
  }

  @override
  Future<ProcessingResult> addSubtitles(
    FileReference video,
    FileReference subtitles,
    String outputPath, {
    bool burn = false,
  }) {
    final videoPath = fileReferencePath(video);
    final subtitlePath = fileReferencePath(subtitles);
    if (burn) {
      return runFfmpeg(
        inputPath: videoPath,
        outputPath: outputPath,
        reencoded: true,
        args: FfmpegArgs.burnSubtitles(
          videoPath: videoPath,
          subtitlePath: subtitlePath,
          outputPath: outputPath,
        ),
        metrics: {'reason': 'burned_subtitles'},
      );
    }
    return runFfmpeg(
      inputPath: videoPath,
      outputPath: outputPath,
      args: FfmpegArgs.addSoftSubtitles(
        videoPath: videoPath,
        subtitlePath: subtitlePath,
        outputPath: outputPath,
      ),
      metrics: {'subtitleCodec': FfmpegArgs.subtitleCodecFor(outputPath)},
    );
  }

  @override
  Future<ProcessingResult> extractSubtitles(
    FileReference file,
    String outputPath,
    int streamIndex,
  ) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      args: FfmpegArgs.extractSubtitles(
        inputPath: inputPath,
        outputPath: outputPath,
        streamIndex: streamIndex,
      ),
    );
  }

  Future<ProcessingResult> _extractAudio(
    FileReference file,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    final encoder = FfmpegArgs.audioEncoderForPath(outputPath);
    if (encoder == null) {
      return runFfmpeg(
        inputPath: inputPath,
        outputPath: outputPath,
        args: FfmpegArgs.extractAudioCopy(
          inputPath: inputPath,
          outputPath: outputPath,
        ),
      );
    }
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      reencoded: true,
      args: FfmpegArgs.encodeAudio(
        inputPath: inputPath,
        outputPath: outputPath,
        encoder: encoder,
      ),
      metrics: {'reason': 'audio_encode'},
    );
  }
}

/// Linux [AudioEngine] backed by the FFmpeg CLI.
class FfmpegAudioEngine extends FfmpegCliEngine implements AudioEngine {
  FfmpegAudioEngine({super.runner});

  @override
  Future<ProcessingResult> convert(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  ) {
    return _encode(file, outputPath, options, reason: 'convert');
  }

  @override
  Future<ProcessingResult> compress(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  ) {
    return _encode(file, outputPath, options, reason: 'compress');
  }

  @override
  Future<ProcessingResult> trim(
    FileReference file,
    Duration start,
    Duration end,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      args: FfmpegArgs.trim(
        inputPath: inputPath,
        outputPath: outputPath,
        start: start,
        end: end,
      ),
    );
  }

  @override
  Future<ProcessingResult> extractFromVideo(
    FileReference videoFile,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(videoFile);
    final encoder = FfmpegArgs.audioEncoderForPath(outputPath);
    if (encoder == null) {
      return runFfmpeg(
        inputPath: inputPath,
        outputPath: outputPath,
        args: FfmpegArgs.extractAudioCopy(
          inputPath: inputPath,
          outputPath: outputPath,
        ),
      );
    }
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      reencoded: true,
      args: FfmpegArgs.encodeAudio(
        inputPath: inputPath,
        outputPath: outputPath,
        encoder: encoder,
      ),
    );
  }

  Future<ProcessingResult> _encode(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options, {
    required String reason,
  }) {
    final inputPath = fileReferencePath(file);
    return runFfmpeg(
      inputPath: inputPath,
      outputPath: outputPath,
      reencoded: true,
      args: FfmpegArgs.encodeAudio(
        inputPath: inputPath,
        outputPath: outputPath,
        encoder: FfmpegArgs.resolveAudioEncoder(options, outputPath),
        bitrate: FfmpegArgs.optionalBitrate(options),
      ),
      metrics: {'reason': reason},
    );
  }
}
