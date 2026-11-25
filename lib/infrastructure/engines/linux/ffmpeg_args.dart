import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:path/path.dart' as p;

/// Argument lists for the FFmpeg CLI. Each value is one argv element.
class FfmpegArgs {
  FfmpegArgs._();

  static final _token = RegExp(r'^[A-Za-z0-9_]+$');
  static final _bitrate = RegExp(r'^\d{1,7}[kKmM]?$');

  static List<String> base() => ['-hide_banner', '-loglevel', 'error', '-y'];

  static String timestamp(Duration duration) {
    if (duration.isNegative) {
      throw const FileValidationException('Time values cannot be negative');
    }
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = duration.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  static void requireRange(Duration start, Duration end) {
    if (start.isNegative || end.isNegative) {
      throw const FileValidationException('Time values cannot be negative');
    }
    if (end <= start) {
      throw const FileValidationException(
        'End time must be after the start time',
      );
    }
  }

  static void requireEven(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw const FileValidationException('Width and height must be positive');
    }
    if (width.isOdd || height.isOdd) {
      throw const FileValidationException(
        'H.264 output needs even width and height',
      );
    }
  }

  static List<String> trim({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration end,
  }) {
    requireRange(start, end);
    return [
      ...base(),
      '-ss',
      timestamp(start),
      '-to',
      timestamp(end),
      '-i',
      inputPath,
      '-c',
      'copy',
      '-avoid_negative_ts',
      'make_zero',
      ..._tail(outputPath),
    ];
  }

  static List<String> crop({
    required String inputPath,
    required String outputPath,
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    if (x < 0 || y < 0) {
      throw const FileValidationException('Crop offset cannot be negative');
    }
    requireEven(width, height);
    return [
      ...base(),
      '-i',
      inputPath,
      '-vf',
      'crop=$width:$height:$x:$y',
      '-c:v',
      'libx264',
      '-crf',
      '23',
      '-preset',
      'medium',
      '-c:a',
      'copy',
      ..._tail(outputPath),
    ];
  }

  static List<String> resize({
    required String inputPath,
    required String outputPath,
    required int width,
    required int height,
  }) {
    requireEven(width, height);
    return [
      ...base(),
      '-i',
      inputPath,
      '-vf',
      'scale=$width:$height',
      '-c:v',
      'libx264',
      '-crf',
      '23',
      '-preset',
      'medium',
      '-c:a',
      'copy',
      ..._tail(outputPath),
    ];
  }

  static List<String> compress({
    required String inputPath,
    required String outputPath,
    int crf = 23,
    String preset = 'medium',
    String codec = 'libx264',
  }) {
    if (crf < 0 || crf > 51) {
      throw const FileValidationException('CRF must be between 0 and 51');
    }
    if (!_token.hasMatch(preset) || !_token.hasMatch(codec)) {
      throw const FileValidationException('Invalid encoder option');
    }
    return [
      ...base(),
      '-i',
      inputPath,
      '-vf',
      'scale=trunc(iw/2)*2:trunc(ih/2)*2',
      '-c:v',
      codec,
      '-crf',
      '$crf',
      '-preset',
      preset,
      '-c:a',
      'copy',
      ..._tail(outputPath),
    ];
  }

  static List<String> convertContainer({
    required String inputPath,
    required String outputPath,
  }) {
    return [
      ...base(),
      '-i',
      inputPath,
      '-c',
      'copy',
      ..._fastStart(outputPath),
      ..._tail(outputPath),
    ];
  }

  static List<String> extractAudioCopy({
    required String inputPath,
    required String outputPath,
  }) {
    return [
      ...base(),
      '-i',
      inputPath,
      '-vn',
      '-c:a',
      'copy',
      ..._tail(outputPath),
    ];
  }

  static List<String> encodeAudio({
    required String inputPath,
    required String outputPath,
    required String encoder,
    String? bitrate,
  }) {
    if (!_token.hasMatch(encoder)) {
      throw const FileValidationException('Invalid audio encoder');
    }
    if (bitrate != null && !_bitrate.hasMatch(bitrate)) {
      throw const FileValidationException('Invalid audio bitrate');
    }
    return [
      ...base(),
      '-i',
      inputPath,
      '-vn',
      '-c:a',
      encoder,
      if (bitrate != null) ...['-b:a', bitrate],
      ..._tail(outputPath),
    ];
  }

  static List<String> removeAudio({
    required String inputPath,
    required String outputPath,
  }) {
    return [
      ...base(),
      '-i',
      inputPath,
      '-an',
      '-c:v',
      'copy',
      ..._tail(outputPath),
    ];
  }

  static List<String> extractFrames({
    required String inputPath,
    required String outputDirectory,
    required double intervalSeconds,
  }) {
    if (intervalSeconds <= 0) {
      throw const FileValidationException('Frame interval must be positive');
    }
    final fps = (1 / intervalSeconds).toStringAsFixed(6);
    return [
      ...base(),
      '-i',
      inputPath,
      '-vf',
      'fps=$fps',
      '-progress',
      'pipe:2',
      '-nostats',
      p.join(outputDirectory, 'frame_%04d.png'),
    ];
  }

  static List<String> addSoftSubtitles({
    required String videoPath,
    required String subtitlePath,
    required String outputPath,
  }) {
    return [
      ...base(),
      '-i',
      videoPath,
      '-i',
      subtitlePath,
      '-c',
      'copy',
      '-c:s',
      subtitleCodecFor(outputPath),
      ..._tail(outputPath),
    ];
  }

  static List<String> burnSubtitles({
    required String videoPath,
    required String subtitlePath,
    required String outputPath,
  }) {
    return [
      ...base(),
      '-i',
      videoPath,
      '-vf',
      "subtitles='${escapeFilterPath(subtitlePath)}'",
      '-c:v',
      'libx264',
      '-crf',
      '23',
      '-preset',
      'medium',
      '-c:a',
      'copy',
      ..._tail(outputPath),
    ];
  }

  static List<String> extractSubtitles({
    required String inputPath,
    required String outputPath,
    required int streamIndex,
  }) {
    if (streamIndex < 0) {
      throw const FileValidationException('Subtitle stream index starts at 0');
    }
    final srt = p.extension(outputPath).toLowerCase() == '.srt';
    return [
      ...base(),
      '-i',
      inputPath,
      '-map',
      '0:s:$streamIndex',
      '-c:s',
      srt ? 'srt' : 'copy',
      ..._tail(outputPath),
    ];
  }

  static String subtitleCodecFor(String outputPath) {
    switch (p.extension(outputPath).toLowerCase()) {
      case '.mp4':
      case '.m4v':
      case '.mov':
        return 'mov_text';
      case '.webm':
        return 'webvtt';
      default:
        return 'copy';
    }
  }

  static String escapeFilterPath(String path) {
    if (path.contains('\n') || path.contains('\r')) {
      throw const FileValidationException('Subtitle path contains a newline');
    }
    return path
        .replaceAll(r'\', r'\\')
        .replaceAll(':', r'\:')
        .replaceAll("'", r"\'")
        .replaceAll(',', r'\,')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll(';', r'\;');
  }

  static String? audioEncoderFor(FileFormat? format) {
    switch (format) {
      case FileFormat.mp3:
        return 'libmp3lame';
      case FileFormat.wav:
        return 'pcm_s16le';
      case FileFormat.flac:
        return 'flac';
      case FileFormat.aac:
      case FileFormat.m4a:
        return 'aac';
      case FileFormat.ogg:
        return 'libvorbis';
      case FileFormat.opus:
        return 'libopus';
      default:
        return null;
    }
  }

  static String? audioEncoderForPath(String outputPath) {
    return audioEncoderFor(FileFormat.fromExtension(p.extension(outputPath)));
  }

  static String resolveAudioEncoder(
    Map<String, dynamic> options,
    String outputPath,
  ) {
    final requested = options['codec'] ?? options['format'];
    if (requested is String && requested.isNotEmpty) {
      final fromFormat = audioEncoderFor(FileFormat.fromExtension(requested));
      if (fromFormat != null) return fromFormat;
      if (_token.hasMatch(requested)) return requested;
      throw const FileValidationException('Unknown audio format');
    }
    final fromPath = audioEncoderForPath(outputPath);
    if (fromPath == null) {
      throw const FileValidationException('Output audio format is required');
    }
    return fromPath;
  }

  static String? optionalBitrate(Map<String, dynamic> options) {
    final value = options['bitrate'];
    if (value == null) return null;
    final text = value is String ? value : '$value';
    if (!_bitrate.hasMatch(text)) {
      throw const FileValidationException('Invalid audio bitrate');
    }
    return text;
  }

  static int optionalCrf(Map<String, dynamic> options, {int fallback = 23}) {
    final value = options['crf'];
    if (value == null) return fallback;
    final parsed =
        value is int
            ? value
            : value is num
            ? value.round()
            : int.tryParse('$value');
    if (parsed == null || parsed < 0 || parsed > 51) {
      throw const FileValidationException('CRF must be between 0 and 51');
    }
    return parsed;
  }

  static String optionalToken(
    Map<String, dynamic> options,
    String key,
    String fallback,
  ) {
    final value = options[key];
    if (value == null) return fallback;
    final text = '$value';
    if (!_token.hasMatch(text)) {
      throw FileValidationException('Invalid $key');
    }
    return text;
  }

  static List<String> _fastStart(String outputPath) {
    switch (p.extension(outputPath).toLowerCase()) {
      case '.mp4':
      case '.m4v':
      case '.mov':
        return ['-movflags', '+faststart'];
      default:
        return const [];
    }
  }

  static List<String> _tail(String outputPath) => [
    '-progress',
    'pipe:2',
    '-nostats',
    outputPath,
  ];
}
