import 'dart:io';

import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/contracts/engines/engines.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_engine.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_image.dart';
import 'package:fileforge/infrastructure/engines/linux/qpdf_engine.dart';
import 'package:fileforge/infrastructure/filesystem/file_reference_io.dart';
import 'package:fileforge/infrastructure/filesystem/image_header_parser.dart';
import 'package:fileforge/infrastructure/filesystem/magic_bytes_detector.dart';
import 'package:fileforge/infrastructure/filesystem/zip_format_detector.dart';

/// Content-based format detection and metadata inspection.
///
/// Magic bytes decide the format. ZIP packages are opened far enough to tell
/// Office documents apart. Deep media and PDF metadata is delegated to the
/// matching engine. Image headers are the fallback when no image engine is
/// registered.
class FileInspectorService implements FileInspectionService {
  FileInspectorService({
    this.videoEngine,
    this.audioEngine,
    this.pdfEngine,
    this.imageEngine,
  });

  final VideoEngine? videoEngine;
  final AudioEngine? audioEngine;
  final PdfEngine? pdfEngine;
  final ImageEngine? imageEngine;

  @override
  Future<FileFormat?> detectFormat(FileReference file) async {
    final path = fileReferencePath(file);
    final ioFile = File(path);
    if (!await ioFile.exists()) {
      throw const FileValidationException('File not found');
    }
    final bytes = await readPrefix(path, 64 * 1024);
    final detected = MagicBytesDetector.detect(bytes);
    if (detected != null) return detected;
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      final office = ZipFormatDetector.detect(bytes);
      if (office != null) return office;
    }
    return FileFormat.fromExtension(fileReferenceExtension(file));
  }

  @override
  Future<FileMetadata> getFileMetadata(FileReference file) async {
    final path = fileReferencePath(file);
    final ioFile = File(path);
    if (!await ioFile.exists()) {
      throw const FileValidationException('File not found');
    }
    final stat = await ioFile.stat();
    final format = file.detectedFormat ?? await detectFormat(file);
    return FileMetadata(
      fileName: file.displayName,
      sizeBytes: file.sizeBytes ?? stat.size,
      mimeType: file.mimeType ?? format?.mimeTypes.first,
      format: format,
      modified: stat.modified,
    );
  }

  @override
  Future<MediaMetadata?> getMediaMetadata(FileReference file) async {
    final format = await _format(file);
    if (format == null) return null;
    if (format.category == FileCategory.video) {
      return videoEngine?.inspect(file);
    }
    if (format.category == FileCategory.audio) {
      return audioEngine?.inspect(file);
    }
    return null;
  }

  @override
  Future<ImageMetadata?> getImageMetadata(FileReference file) async {
    final format = await _format(file);
    if (format == null || format.category != FileCategory.image) return null;
    if (imageEngine != null) return imageEngine!.inspect(file);
    final bytes = await readPrefix(fileReferencePath(file), 512 * 1024);
    return ImageHeaderParser.parse(bytes, format);
  }

  @override
  Future<PdfMetadata?> getPdfMetadata(FileReference file) async {
    final format = await _format(file);
    if (format != FileFormat.pdf) return null;
    return pdfEngine?.inspect(file);
  }

  Future<FileFormat?> _format(FileReference file) async {
    return file.detectedFormat ?? await detectFormat(file);
  }
}

/// Build the inspector used by the running app.
///
/// Linux gets the FFmpeg, image, and qpdf adapters. Other platforms keep
/// content detection and image-header parsing, without those engines.
FileInspectionService createFileInspectionService() {
  if (!Platform.isLinux) return FileInspectorService();
  return FileInspectorService(
    videoEngine: FfmpegVideoEngine(),
    audioEngine: FfmpegAudioEngine(),
    pdfEngine: QpdfEngine(),
    imageEngine: FfmpegImageEngine(),
  );
}
