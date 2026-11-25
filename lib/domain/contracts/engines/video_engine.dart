import 'package:fileforge/domain/models/models.dart';

/// Contract for all video processing engines.
///
/// Implementations: Linux → FFmpeg CLI adapter, Android → Media3 Transformer.
abstract class VideoEngine {
  String get engineId;

  Future<MediaMetadata> inspect(FileReference file);
  Future<ProcessingResult> trim(
    FileReference file,
    Duration start,
    Duration end,
    String outputPath,
  );
  Future<ProcessingResult> crop(
    FileReference file, {
    required int x,
    required int y,
    required int width,
    required int height,
    required String outputPath,
  });
  Future<ProcessingResult> resize(
    FileReference file,
    int width,
    int height,
    String outputPath,
  );
  Future<ProcessingResult> compress(
    FileReference file,
    String outputPath,
    Map<String, dynamic> options,
  );
  Future<ProcessingResult> convertContainer(
    FileReference file,
    String outputPath,
    String targetContainer,
  );
  Future<ProcessingResult> extractAudio(FileReference file, String outputPath);
  Future<ProcessingResult> removeAudio(FileReference file, String outputPath);
  Future<ProcessingResult> extractFrames(
    FileReference file,
    String outputDir,
    double intervalSeconds,
  );
  Future<ProcessingResult> addSubtitles(
    FileReference video,
    FileReference subtitles,
    String outputPath, {
    bool burn = false,
  });
  Future<ProcessingResult> extractSubtitles(
    FileReference file,
    String outputPath,
    int streamIndex,
  );

  Stream<double> get progressStream;
  Future<void> cancel();
}
