import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/domain/enums/enums.dart';

/// Service contract for file inspection and content-based format detection.
abstract class FileInspectionService {
  /// Detect the actual format of a file by inspecting its contents.
  ///
  /// Does NOT rely solely on file extension.
  Future<FileFormat?> detectFormat(FileReference file);

  /// Get generic metadata about a file.
  Future<FileMetadata> getFileMetadata(FileReference file);

  /// Get media-specific metadata (video/audio files).
  Future<MediaMetadata?> getMediaMetadata(FileReference file);

  /// Get image-specific metadata.
  Future<ImageMetadata?> getImageMetadata(FileReference file);

  /// Get PDF-specific metadata.
  Future<PdfMetadata?> getPdfMetadata(FileReference file);
}
