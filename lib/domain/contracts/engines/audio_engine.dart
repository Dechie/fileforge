import 'package:fileforge/domain/models/models.dart';

/// Contract for all audio processing engines.
///
/// Implementations: Linux → FFmpeg CLI adapter, Android → Media3.
abstract class AudioEngine {
  String get engineId;

  Future<MediaMetadata> inspect(FileReference file);
  Future<ProcessingResult> convert(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  );
  Future<ProcessingResult> compress(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  );
  Future<ProcessingResult> trim(
    FileReference file,
    Duration start,
    Duration end,
    String outputPath,
  );
  Future<ProcessingResult> extractFromVideo(
    FileReference videoFile,
    String outputPath,
  );

  Stream<double> get progressStream;
  Future<void> cancel();
}
