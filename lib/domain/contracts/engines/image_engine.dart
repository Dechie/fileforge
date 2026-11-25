import 'package:fileforge/domain/models/models.dart';

/// Contract for all image processing engines.
///
/// Linux stills use FFmpeg (JPEG, PNG, WebP). Android uses a native adapter.
abstract class ImageEngine {
  String get engineId;

  Future<ImageMetadata> inspect(FileReference file);
  Future<ProcessingResult> convert(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  );
  Future<ProcessingResult> resize(
    FileReference file,
    int width,
    int height,
    String outputPath, {
    bool maintainAspect = true,
    Map<String, dynamic> options = const {},
  });
  Future<ProcessingResult> compress(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  );
  Future<ProcessingResult> removeMetadata(
    FileReference file,
    String outputPath,
  );

  Stream<double> get progressStream;
  Future<void> cancel();
}
