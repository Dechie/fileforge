import 'dart:io';

import 'package:fileforge/application/output_paths.dart';
import 'package:fileforge/application/providers/engine_provider.dart';
import 'package:fileforge/application/providers/processing_provider.dart';
import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/contracts/engines/engines.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_engine.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_image.dart';
import 'package:fileforge/infrastructure/engines/linux/libreoffice_engine.dart';
import 'package:fileforge/infrastructure/engines/linux/qpdf_engine.dart';
import 'package:path/path.dart' as p;

/// Runs a [ProcessingRequest] and records each lifecycle step.
///
/// Screens pass operation details in [ProcessingRequest.parameters]:
/// `pages`, `rotation`, `password`, `watermark`, `startMs`, `endMs`,
/// `x`, `y`, `width`, `height`, `crf`, `codec`, `preset`, `container`,
/// `subtitleUri`, `subtitleName`, `burn`, `bitrate`, `format`, `interval`.
class JobRunner {
  JobRunner({
    required this.processing,
    required this.engines,
    Future<Directory> Function()? outputDirectory,
    this.createPdf,
    this.createVideo,
    this.createAudio,
    this.createDocument,
    this.createImage,
  }) : outputDirectory = outputDirectory ?? defaultJobOutputDirectory;

  final ProcessingProvider processing;
  final EngineProvider engines;
  final Future<Directory> Function() outputDirectory;
  final PdfEngine Function()? createPdf;
  final VideoEngine Function()? createVideo;
  final AudioEngine Function()? createAudio;
  final DocumentEngine Function()? createDocument;
  final ImageEngine Function()? createImage;

  final Map<String, Future<void> Function()> _cancels = {};
  final Set<String> _cancelled = {};

  PdfEngine _pdf() => createPdf?.call() ?? QpdfEngine();
  VideoEngine _video() => createVideo?.call() ?? FfmpegVideoEngine();
  AudioEngine _audio() => createAudio?.call() ?? FfmpegAudioEngine();
  DocumentEngine _document() => createDocument?.call() ?? LibreOfficeEngine();
  ImageEngine _image() => createImage?.call() ?? FfmpegImageEngine();

  /// Stop the engine for [jobId] and mark the job cancelled.
  Future<void> cancel(String jobId) async {
    _cancelled.add(jobId);
    processing.cancelJob(jobId);
    final cancelEngine = _cancels.remove(jobId);
    if (cancelEngine != null) await cancelEngine();
  }

  /// Walk the legal job states and dispatch the request to an engine.
  Future<ProcessingResult?> run(ProcessingRequest request) async {
    final id = request.id;
    await processing.submitJob(request);
    try {
      if (!_step(id, JobStatus.pending)) return null;
      if (!_step(id, JobStatus.validating)) return null;

      if (request.inputs.isEmpty) {
        return _fail(id, 'Choose a file first.');
      }
      if (request.operation == OperationType.pdfMerge &&
          request.inputs.length < 2) {
        return _fail(id, 'Merge needs at least two PDF files.');
      }

      final descriptor = _select(request);
      if (descriptor == null) {
        return _fail(id, _missingEngineMessage(request));
      }
      if (!_step(
        id,
        JobStatus.processing,
        progress: 0,
        engineId: descriptor.id,
        engineVersion: descriptor.version,
      )) {
        return null;
      }

      final result = await _dispatch(request);
      if (result == null || _cancelled.contains(id)) return result;
      if (!result.success) {
        return _fail(id, result.errorMessage ?? 'Processing failed');
      }
      if (!_step(
        id,
        JobStatus.verifying,
        progress: 1,
        engineId: descriptor.id,
      )) {
        return result;
      }
      _step(
        id,
        JobStatus.completed,
        progress: 1,
        engineId: descriptor.id,
        outputs: result.outputs,
      );
      return result;
    } catch (error) {
      return _fail(id, _message(error));
    } finally {
      _cancels.remove(id);
      _cancelled.remove(id);
    }
  }

  EngineDescriptor? _select(ProcessingRequest request) {
    final input =
        request.inputs.isEmpty ? null : request.inputs.first.detectedFormat;
    return engines.selectEngine(
          operation: request.operation,
          inputFormat: input,
          outputFormat: request.outputFormat,
        ) ??
        engines.selectEngine(
          operation: request.operation,
          outputFormat: request.outputFormat,
        );
  }

  String _missingEngineMessage(ProcessingRequest request) {
    if (request.studio == StudioType.documentStudio) {
      return 'Office conversion requires Linux with LibreOffice.';
    }
    if (request.studio == StudioType.imageStudio) {
      return 'No image processing engine is installed.';
    }
    return 'No engine is available for this operation.';
  }

  Future<ProcessingResult?> _dispatch(ProcessingRequest request) async {
    if (_cancelled.contains(request.id)) return null;
    switch (request.operation) {
      case OperationType.pdfMerge:
        return _pdfJob(
          request,
          (engine, output) => engine.merge(request.inputs, output),
        );
      case OperationType.pdfSplit:
        return _pdfDirectory(
          request,
          (engine, dir) => engine.split(_first(request), dir),
        );
      case OperationType.pdfExtractPages:
        return _pdfJob(
          request,
          (engine, output) => engine.extractPages(
            _first(request),
            _pageList(request.parameters),
            output,
          ),
        );
      case OperationType.pdfReorderPages:
        return _pdfJob(
          request,
          (engine, output) => engine.reorderPages(
            _first(request),
            _pageList(request.parameters),
            output,
          ),
        );
      case OperationType.pdfRotatePages:
        return _pdfJob(
          request,
          (engine, output) => engine.rotatePages(
            _first(request),
            _rotations(request.parameters),
            output,
          ),
        );
      case OperationType.pdfDeletePages:
        return _pdfJob(
          request,
          (engine, output) => engine.deletePages(
            _first(request),
            _pageList(request.parameters),
            output,
          ),
        );
      case OperationType.pdfCompress:
        return _pdfJob(
          request,
          (engine, output) => engine.compress(_first(request), output),
        );
      case OperationType.pdfAddWatermark:
        return _pdfJob(
          request,
          (engine, output) => engine.addWatermark(
            _first(request),
            _requiredText(request.parameters, 'watermark', 'Watermark text'),
            output,
          ),
        );
      case OperationType.pdfAddPageNumbers:
        return _pdfJob(
          request,
          (engine, output) => engine.addPageNumbers(_first(request), output),
        );
      case OperationType.pdfProtect:
        return _pdfJob(
          request,
          (engine, output) => engine.protect(
            _first(request),
            _password(request.parameters),
            output,
          ),
        );
      case OperationType.pdfUnprotect:
        return _pdfJob(
          request,
          (engine, output) => engine.removeProtection(
            _first(request),
            _password(request.parameters),
            output,
          ),
        );
      case OperationType.documentToPdf:
      case OperationType.markdownToPdf:
        return _runDocument(request);
      case OperationType.videoTrim:
        final range = _trim(request.parameters);
        return _videoJob(
          request,
          _sourceExtension(_first(request), 'mp4'),
          (engine, output) =>
              engine.trim(_first(request), range.$1, range.$2, output),
        );
      case OperationType.videoCrop:
        return _videoJob(
          request,
          'mp4',
          (engine, output) => engine.crop(
            _first(request),
            x: _asInt(request.parameters['x'], label: 'X offset'),
            y: _asInt(request.parameters['y'], label: 'Y offset'),
            width: _positiveEven(request.parameters['width'], 'Width'),
            height: _positiveEven(request.parameters['height'], 'Height'),
            outputPath: output,
          ),
        );
      case OperationType.videoResize:
        return _videoJob(
          request,
          'mp4',
          (engine, output) => engine.resize(
            _first(request),
            _positiveEven(request.parameters['width'], 'Width'),
            _positiveEven(request.parameters['height'], 'Height'),
            output,
          ),
        );
      case OperationType.videoCompress:
        return _videoJob(
          request,
          'mp4',
          (engine, output) => engine.compress(
            _first(request),
            output,
            _videoOptions(request.parameters),
          ),
        );
      case OperationType.videoConvertContainer:
        final container = _container(request.parameters);
        return _videoJob(
          request,
          container,
          (engine, output) =>
              engine.convertContainer(_first(request), output, container),
        );
      case OperationType.videoAddSubtitles:
      case OperationType.videoBurnSubtitles:
        final burn = request.operation == OperationType.videoBurnSubtitles;
        return _videoJob(
          request,
          'mp4',
          (engine, output) => engine.addSubtitles(
            _first(request),
            _subtitles(request.parameters),
            output,
            burn: burn,
          ),
        );
      case OperationType.videoExtractAudio:
        return _videoJob(
          request,
          _formatExtension(request, 'm4a'),
          (engine, output) => engine.extractAudio(_first(request), output),
        );
      case OperationType.videoRemoveAudio:
        return _videoJob(
          request,
          _sourceExtension(_first(request), 'mp4'),
          (engine, output) => engine.removeAudio(_first(request), output),
        );
      case OperationType.videoExtractFrames:
        return _videoDirectory(request, (engine, dir) {
          final raw = request.parameters['interval'];
          final interval =
              raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 1;
          if (interval <= 0) {
            throw const FileValidationException('Interval must be positive');
          }
          return engine.extractFrames(_first(request), dir, interval);
        });
      case OperationType.videoExtractSubtitles:
        return _videoJob(
          request,
          'srt',
          (engine, output) =>
              engine.extractSubtitles(_first(request), output, 0),
        );
      case OperationType.audioConvert:
        return _audioJob(
          request,
          _formatExtension(request, 'mp3'),
          (engine, output) => engine.convert(
            _first(request),
            output,
            _audioOptions(request.parameters),
          ),
        );
      case OperationType.audioCompress:
        return _audioJob(
          request,
          _sourceExtension(_first(request), 'mp3'),
          (engine, output) => engine.compress(
            _first(request),
            output,
            _audioOptions(request.parameters),
          ),
        );
      case OperationType.audioTrim:
        final range = _trim(request.parameters);
        return _audioJob(
          request,
          _sourceExtension(_first(request), 'mp3'),
          (engine, output) =>
              engine.trim(_first(request), range.$1, range.$2, output),
        );
      case OperationType.audioExtractFromVideo:
        return _audioJob(
          request,
          _formatExtension(request, 'mp3'),
          (engine, output) => engine.extractFromVideo(_first(request), output),
        );
      case OperationType.imageConvert:
      case OperationType.imageBatchConvert:
      case OperationType.imageResize:
      case OperationType.imageBatchResize:
      case OperationType.imageCompress:
      case OperationType.imageRemoveMetadata:
        return _runImages(request);
      default:
        throw const FileValidationException(
          'This operation is not available yet.',
        );
    }
  }

  Future<ProcessingResult?> _pdfJob(
    ProcessingRequest request,
    Future<ProcessingResult> Function(PdfEngine engine, String output) action,
  ) async {
    final engine = _pdf();
    final output = await _outputFile(request, 'pdf');
    return _track(
      jobId: request.id,
      progress: engine.progressStream,
      cancel: engine.cancel,
      action: () => action(engine, output),
    );
  }

  Future<ProcessingResult?> _pdfDirectory(
    ProcessingRequest request,
    Future<ProcessingResult> Function(PdfEngine engine, String directory)
    action,
  ) async {
    final engine = _pdf();
    final directory = await _outputFolder(request, 'pages');
    return _track(
      jobId: request.id,
      progress: engine.progressStream,
      cancel: engine.cancel,
      action: () => action(engine, directory),
    );
  }

  Future<ProcessingResult?> _videoJob(
    ProcessingRequest request,
    String extension,
    Future<ProcessingResult> Function(VideoEngine engine, String output) action,
  ) async {
    final engine = _video();
    final output = await _outputFile(request, extension);
    return _track(
      jobId: request.id,
      progress: engine.progressStream,
      cancel: engine.cancel,
      action: () => action(engine, output),
    );
  }

  Future<ProcessingResult?> _videoDirectory(
    ProcessingRequest request,
    Future<ProcessingResult> Function(VideoEngine engine, String directory)
    action,
  ) async {
    final engine = _video();
    final directory = await _outputFolder(request, 'frames');
    return _track(
      jobId: request.id,
      progress: engine.progressStream,
      cancel: engine.cancel,
      action: () => action(engine, directory),
    );
  }

  Future<ProcessingResult?> _audioJob(
    ProcessingRequest request,
    String extension,
    Future<ProcessingResult> Function(AudioEngine engine, String output) action,
  ) async {
    final engine = _audio();
    final output = await _outputFile(request, extension);
    return _track(
      jobId: request.id,
      progress: engine.progressStream,
      cancel: engine.cancel,
      action: () => action(engine, output),
    );
  }

  Future<ProcessingResult?> _runDocument(ProcessingRequest request) async {
    final engine = _document();
    if (!engine.isAvailable) {
      throw const FileValidationException(
        'Office conversion requires Linux with LibreOffice.',
      );
    }
    final output = await _outputFile(request, 'pdf');
    final file = _first(request);
    return _track(
      jobId: request.id,
      progress: engine.progressStream,
      cancel: engine.cancel,
      action: () {
        if (request.operation == OperationType.markdownToPdf) {
          return engine.markdownToPdf(file, output);
        }
        return engine.convertToPdf(file, output);
      },
    );
  }

  Future<ProcessingResult?> _track({
    required String jobId,
    required Stream<double> progress,
    required Future<void> Function() cancel,
    required Future<ProcessingResult> Function() action,
  }) async {
    if (_cancelled.contains(jobId)) return null;
    _cancels[jobId] = cancel;
    final subscription = progress.listen((value) {
      if (!_cancelled.contains(jobId)) {
        processing.updateProgress(jobId, value);
      }
    }, onError: (_) {});
    try {
      if (_cancelled.contains(jobId)) {
        await cancel();
        return null;
      }
      return await action();
    } finally {
      await subscription.cancel();
      if (_cancels[jobId] == cancel) _cancels.remove(jobId);
    }
  }

  bool _step(
    String jobId,
    JobStatus status, {
    double? progress,
    String? error,
    String? engineId,
    String? engineVersion,
    List<OutputArtifact>? outputs,
  }) {
    if (_cancelled.contains(jobId)) return false;
    if (_active(jobId) == null) return false;
    processing.updateJobStatus(
      jobId,
      status,
      progress: progress,
      error: error,
      engineId: engineId,
      engineVersion: engineVersion,
      outputs: outputs,
    );
    return true;
  }

  ProcessingResult? _fail(String jobId, String message) {
    if (_cancelled.contains(jobId)) return null;
    final job = _active(jobId);
    if (job != null && job.status.canTransitionTo(JobStatus.failed)) {
      processing.updateJobStatus(jobId, JobStatus.failed, error: message);
    }
    return ProcessingResult(
      jobId: jobId,
      success: false,
      errorMessage: message,
    );
  }

  ProcessingJob? _active(String jobId) {
    for (final job in processing.activeJobs) {
      if (job.id == jobId) return job;
    }
    return null;
  }

  Future<String> _outputFile(
    ProcessingRequest request,
    String extension, {
    FileReference? source,
    int? index,
  }) async {
    final directory = await _directory(request);
    final chosen =
        source ?? (request.inputs.isEmpty ? null : request.inputs.first);
    final raw =
        chosen == null
            ? 'output'
            : p.basenameWithoutExtension(chosen.displayName);
    final safe = raw.replaceAll(RegExp(r'[^\w.-]+'), '_');
    final name = safe.isEmpty ? 'output' : safe;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = index == null ? '$stamp' : '${stamp}_$index';
    return p.join(
      directory.path,
      '${name}_${request.operation.name}_$suffix.$extension',
    );
  }

  Future<ProcessingResult?> _runImages(ProcessingRequest request) async {
    final engine = _image();
    final outputs = <OutputArtifact>[];
    var elapsed = Duration.zero;
    for (var index = 0; index < request.inputs.length; index++) {
      if (_cancelled.contains(request.id)) return null;
      final file = request.inputs[index];
      final output = await _outputFile(
        request,
        _imageExtension(request, file),
        source: file,
        index: index,
      );
      final result = await _track(
        jobId: request.id,
        progress: engine.progressStream,
        cancel: engine.cancel,
        action: () => _imageCall(engine, request, file, output),
      );
      if (result == null || !result.success) return result;
      outputs.addAll(result.outputs);
      elapsed += result.elapsed;
    }
    return ProcessingResult(
      jobId: request.id,
      success: true,
      outputs: outputs,
      elapsed: elapsed,
    );
  }

  Future<ProcessingResult> _imageCall(
    ImageEngine engine,
    ProcessingRequest request,
    FileReference file,
    String output,
  ) {
    final options = _imageOptions(request);
    switch (request.operation) {
      case OperationType.imageResize:
      case OperationType.imageBatchResize:
        return engine.resize(
          file,
          _optionalInt(request.parameters['width']),
          _optionalInt(request.parameters['height']),
          output,
          maintainAspect: request.parameters['keepAspect'] != false,
          options: options,
        );
      case OperationType.imageCompress:
        return engine.compress(file, output, options);
      case OperationType.imageRemoveMetadata:
        return engine.removeMetadata(file, output);
      case OperationType.imageConvert:
      case OperationType.imageBatchConvert:
        return engine.convert(file, output, options);
      default:
        throw const FileValidationException(
          'This image operation is not available yet.',
        );
    }
  }

  Future<String> _outputFolder(ProcessingRequest request, String label) async {
    final parent = await _directory(request);
    final source =
        request.inputs.isEmpty
            ? label
            : p.basenameWithoutExtension(request.inputs.first.displayName);
    final safe = source.replaceAll(RegExp(r'[^\w.-]+'), '_');
    final name = safe.isEmpty ? label : safe;
    final directory = Directory(p.join(parent.path, '${name}_$label'));
    await directory.create(recursive: true);
    return directory.path;
  }

  Future<Directory> _directory(ProcessingRequest request) async {
    if (request.outputDirectory != null &&
        request.outputDirectory!.isNotEmpty) {
      final directory = Directory(request.outputDirectory!);
      await directory.create(recursive: true);
      return directory;
    }
    final root = await outputDirectory();
    final folder = studioOutputFolder(request.studio);
    if (folder == null) return root;
    final directory = Directory(p.join(root.path, folder));
    await directory.create(recursive: true);
    return directory;
  }
}

FileReference _first(ProcessingRequest request) {
  if (request.inputs.isEmpty) {
    throw const FileValidationException('Choose a file first');
  }
  return request.inputs.first;
}

String _message(Object error) {
  if (error is FileForgeException) return error.message;
  return error.toString();
}

int _asInt(Object? value, {required String label}) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FileValidationException('$label is required');
}

int _positiveEven(Object? value, String label) {
  final number = _asInt(value, label: label);
  if (number < 2) {
    throw FileValidationException('$label must be at least 2');
  }
  return number.isEven ? number : number - 1;
}

List<int> _pageList(Map<String, dynamic> parameters) {
  final value = parameters['pages'];
  if (value is! List || value.isEmpty) {
    throw const FileValidationException('Enter at least one page');
  }
  return [for (final page in value) _asInt(page, label: 'Page')];
}

Map<int, int> _rotations(Map<String, dynamic> parameters) {
  final degrees = _asInt(parameters['rotation'], label: 'Rotation');
  if (degrees != 90 && degrees != 180 && degrees != 270) {
    throw const FileValidationException(
      'Rotation must be 90, 180, or 270 degrees',
    );
  }
  return {for (final page in _pageList(parameters)) page: degrees};
}

String _password(Map<String, dynamic> parameters) {
  return _requiredText(parameters, 'password', 'Password');
}

String _requiredText(
  Map<String, dynamic> parameters,
  String key,
  String label,
) {
  final value = parameters[key];
  if (value is! String || value.trim().isEmpty) {
    throw FileValidationException('$label is required');
  }
  return value;
}

(Duration, Duration) _trim(Map<String, dynamic> parameters) {
  final startMs = _asInt(parameters['startMs'], label: 'Start time');
  final endMs = _asInt(parameters['endMs'], label: 'End time');
  if (endMs <= startMs) {
    throw const FileValidationException('Trim end must be after the start');
  }
  return (Duration(milliseconds: startMs), Duration(milliseconds: endMs));
}

String _container(Map<String, dynamic> parameters) {
  const allowed = {'mp4', 'mkv', 'webm', 'mov'};
  final value = parameters['container'];
  if (value is! String || !allowed.contains(value)) {
    throw const FileValidationException('Choose a container');
  }
  return value;
}

FileReference _subtitles(Map<String, dynamic> parameters) {
  final uri = parameters['subtitleUri'];
  if (uri is! String || uri.isEmpty) {
    throw const FileValidationException('Choose a subtitle file');
  }
  final name = parameters['subtitleName'];
  return FileReference(
    displayName: name is String && name.isNotEmpty ? name : 'subtitles.srt',
    uri: uri,
  );
}

Map<String, dynamic> _videoOptions(Map<String, dynamic> parameters) {
  return {
    if (parameters['crf'] != null) 'crf': parameters['crf'],
    if (parameters['codec'] != null) 'codec': parameters['codec'],
    if (parameters['preset'] != null) 'preset': parameters['preset'],
  };
}

Map<String, dynamic> _audioOptions(Map<String, dynamic> parameters) {
  return {
    if (parameters['format'] != null) 'format': parameters['format'],
    if (parameters['bitrate'] != null) 'bitrate': parameters['bitrate'],
  };
}

String _formatExtension(ProcessingRequest request, String fallback) {
  final format = request.outputFormat?.extensions.first;
  if (format != null && format.isNotEmpty) return format;
  final raw = request.parameters['format'];
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim().replaceFirst('.', '').toLowerCase();
  }
  return fallback;
}

String _imageExtension(ProcessingRequest request, FileReference file) {
  final converting =
      request.operation == OperationType.imageConvert ||
      request.operation == OperationType.imageBatchConvert;
  final raw =
      converting
          ? _formatExtension(request, 'png')
          : _sourceExtension(file, 'png');
  return raw == 'jpeg' ? 'jpg' : raw;
}

Map<String, dynamic> _imageOptions(ProcessingRequest request) {
  return {
    'quality': _imageQuality(request.parameters),
    'preserveMetadata': request.parameters['preserveMetadata'] == true,
    'removeGps': request.parameters['removeGps'] == true,
  };
}

int _imageQuality(Map<String, dynamic> parameters) {
  final value = parameters['quality'];
  if (value is int) return value.clamp(1, 100);
  if (value is num) return value.round().clamp(1, 100);
  return 85;
}

int _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

String _sourceExtension(FileReference file, String fallback) {
  final detected = file.detectedFormat?.extensions.first;
  if (detected != null && detected.isNotEmpty) return detected;
  final fromName =
      p.extension(file.displayName).replaceFirst('.', '').toLowerCase();
  if (fromName.isNotEmpty) return fromName;
  return fallback;
}
