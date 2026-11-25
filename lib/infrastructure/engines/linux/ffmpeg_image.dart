import 'dart:io';

import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/contracts/engines/engines.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_engine.dart';
import 'package:fileforge/infrastructure/filesystem/file_reference_io.dart';
import 'package:fileforge/infrastructure/filesystem/image_header_parser.dart';
import 'package:fileforge/infrastructure/platform/process_runner.dart';
import 'package:path/path.dart' as p;

/// Still-image adapter that shells out to FFmpeg.
///
/// JPEG, PNG, and WebP are encoded with mjpeg, png, and libwebp. HEIC is
/// rejected because this build has no HEIF decoder. Animated images are
/// rejected so a single-frame encode cannot flatten them.
class FfmpegImageEngine implements ImageEngine {
  FfmpegImageEngine({CommandRunner? runner})
    : _ffmpeg = FfmpegCliEngine(runner: runner);

  final FfmpegCliEngine _ffmpeg;

  @override
  String get engineId => 'ffmpeg_image';

  @override
  Stream<double> get progressStream => _ffmpeg.progressStream;

  @override
  Future<void> cancel() => _ffmpeg.cancel();

  @override
  Future<ImageMetadata> inspect(FileReference file) async {
    final path = fileReferencePath(file);
    final format =
        file.detectedFormat ??
        FileFormat.fromExtension(fileReferenceExtension(file));
    if (format == null) return const ImageMetadata();
    final bytes = await readPrefix(path, 512 * 1024);
    return ImageHeaderParser.parse(bytes, format);
  }

  @override
  Future<ProcessingResult> convert(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  ) {
    return _encode(
      file,
      outputPath,
      quality: _quality(options['quality'], fallback: 85),
      width: _dimension(options['width']),
      height: _dimension(options['height']),
      maintainAspect: options['keepAspect'] != false,
      strip: _strip(options),
    );
  }

  @override
  Future<ProcessingResult> resize(
    FileReference file,
    int width,
    int height,
    String outputPath, {
    bool maintainAspect = true,
    Map<String, dynamic> options = const {},
  }) {
    if (width <= 0 && height <= 0) {
      throw const FileValidationException('Enter a width or a height.');
    }
    return _encode(
      file,
      outputPath,
      quality: _quality(options['quality'], fallback: 90),
      width: width,
      height: height,
      maintainAspect: maintainAspect,
      strip: _strip(options),
    );
  }

  @override
  Future<ProcessingResult> compress(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  ) {
    return _encode(
      file,
      outputPath,
      quality: _quality(options['quality'], fallback: 70),
      strip: _strip(options),
    );
  }

  @override
  Future<ProcessingResult> removeMetadata(
    FileReference file,
    String outputPath,
  ) {
    return _encode(file, outputPath, quality: 100, strip: true);
  }

  Future<ProcessingResult> _encode(
    FileReference file,
    String outputPath, {
    required int quality,
    required bool strip,
    int width = 0,
    int height = 0,
    bool maintainAspect = true,
  }) async {
    await _rejectUnsupported(file);
    final inputPath = fileReferencePath(file);
    final scale = _scale(width, height, maintainAspect);
    final extension =
        p.extension(outputPath).replaceFirst('.', '').toLowerCase();
    return _ffmpeg.runFfmpeg(
      args: [
        '-hide_banner',
        '-y',
        '-i',
        inputPath,
        if (scale != null) ...['-vf', scale],
        '-frames:v',
        '1',
        ..._codecArgs(extension == 'jpeg' ? 'jpg' : extension, quality),
        '-map_metadata',
        strip ? '-1' : '0',
        outputPath,
      ],
      inputPath: inputPath,
      outputPath: outputPath,
      reencoded: true,
      metrics: {'quality': quality, 'metadataStripped': strip},
    );
  }

  Future<void> _rejectUnsupported(FileReference file) async {
    final path = fileReferencePath(file);
    final format =
        file.detectedFormat ??
        FileFormat.fromExtension(fileReferenceExtension(file));
    if (format == FileFormat.heic) {
      throw const FileValidationException(
        'HEIC needs a HEIF decoder, which is not available.',
      );
    }
    if (format == null || !await File(path).exists()) return;
    final bytes = await readPrefix(path, 512 * 1024);
    final meta = ImageHeaderParser.parse(bytes, format);
    if (meta.isAnimated) {
      throw const FileValidationException(
        'Animated images are left unchanged so they are not flattened to one frame.',
      );
    }
  }

  String? _scale(int width, int height, bool maintainAspect) {
    final w = width > 0 ? width : -1;
    final h = height > 0 ? height : -1;
    if (w < 0 && h < 0) return null;
    if (maintainAspect && w > 0 && h > 0) {
      return 'scale=$w:$h:force_original_aspect_ratio=decrease';
    }
    return 'scale=$w:$h';
  }

  List<String> _codecArgs(String extension, int quality) {
    switch (extension) {
      case 'jpg':
        return ['-c:v', 'mjpeg', '-q:v', '${_jpegQuantizer(quality)}'];
      case 'png':
        return [
          '-c:v',
          'png',
          '-compression_level',
          '${_pngCompression(quality)}',
        ];
      case 'webp':
        return ['-c:v', 'libwebp', '-quality', '${quality.clamp(1, 100)}'];
      default:
        throw FileValidationException('Unsupported image format: $extension');
    }
  }

  bool _strip(Map<String, dynamic> options) {
    if (options['removeGps'] == true) return true;
    if (options['preserveMetadata'] == false) return true;
    return false;
  }

  int _quality(Object? value, {required int fallback}) {
    if (value is int) return value.clamp(1, 100);
    if (value is num) return value.round().clamp(1, 100);
    return fallback;
  }

  int _dimension(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }

  /// FFmpeg's mjpeg quantizer is 2–31, and lower means higher quality.
  int _jpegQuantizer(int quality) {
    final q = quality.clamp(1, 100);
    return (2 + ((100 - q) * 29 / 99)).round().clamp(2, 31);
  }

  int _pngCompression(int quality) {
    final q = quality.clamp(1, 100);
    return ((100 - q) * 9 / 99).round().clamp(0, 9);
  }
}
