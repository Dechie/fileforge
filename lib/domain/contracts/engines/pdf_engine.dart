import 'package:fileforge/domain/models/models.dart';

/// Contract for all PDF processing engines.
///
/// Implementations: Linux → qpdf CLI adapter, Android → PDFBox-Android.
abstract class PdfEngine {
  String get engineId;

  Future<PdfMetadata> inspect(FileReference file);
  Future<ProcessingResult> merge(List<FileReference> files, String outputPath);
  Future<ProcessingResult> split(FileReference file, String outputDir);
  Future<ProcessingResult> extractPages(
    FileReference file,
    List<int> pageNumbers,
    String outputPath,
  );
  Future<ProcessingResult> reorderPages(
    FileReference file,
    List<int> newOrder,
    String outputPath,
  );
  Future<ProcessingResult> rotatePages(
    FileReference file,
    Map<int, int> pageRotations,
    String outputPath,
  );
  Future<ProcessingResult> deletePages(
    FileReference file,
    List<int> pageNumbers,
    String outputPath,
  );
  Future<ProcessingResult> compress(FileReference file, String outputPath);
  Future<ProcessingResult> addWatermark(
    FileReference file,
    String watermarkText,
    String outputPath,
  );
  Future<ProcessingResult> addPageNumbers(
    FileReference file,
    String outputPath,
  );
  Future<ProcessingResult> protect(
    FileReference file,
    String password,
    String outputPath,
  );
  Future<ProcessingResult> removeProtection(
    FileReference file,
    String password,
    String outputPath,
  );

  /// Stream of progress updates (0.0 – 1.0) for the current operation.
  Stream<double> get progressStream;

  /// Cancel the current operation.
  Future<void> cancel();
}
