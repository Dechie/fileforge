import 'package:fileforge/domain/models/models.dart';

/// Contract for document-to-PDF conversion engines.
///
/// Implementations: Linux → LibreOffice headless, Android → unavailable MVP.
abstract class DocumentEngine {
  String get engineId;

  /// Whether this engine is available on the current platform.
  bool get isAvailable;

  Future<ProcessingResult> convertToPdf(FileReference file, String outputPath);
  Future<ProcessingResult> markdownToPdf(FileReference file, String outputPath);

  Stream<double> get progressStream;
  Future<void> cancel();
}
