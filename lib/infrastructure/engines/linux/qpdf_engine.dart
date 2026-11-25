import 'dart:async';
import 'dart:io';

import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/contracts/engines/pdf_engine.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/qpdf_args.dart';
import 'package:fileforge/infrastructure/engines/linux/qpdf_metadata_parser.dart';
import 'package:fileforge/infrastructure/engines/linux/simple_pdf.dart';
import 'package:fileforge/infrastructure/filesystem/file_reference_io.dart';
import 'package:fileforge/infrastructure/platform/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Linux [PdfEngine] backed by the qpdf 12 CLI.
class QpdfEngine implements PdfEngine {
  QpdfEngine({CommandRunner? runner})
    : _runner = runner ?? const CommandRunner();

  final CommandRunner _runner;
  final Uuid _ids = const Uuid();
  final StreamController<double> _progress =
      StreamController<double>.broadcast();

  ProcessHandle? _active;
  bool _busy = false;

  @override
  String get engineId => 'qpdf';

  @override
  Stream<double> get progressStream => _progress.stream;

  @override
  Future<void> cancel() async {
    final handle = _active;
    if (handle == null) return;
    await handle.cancel();
  }

  @override
  Future<PdfMetadata> inspect(FileReference file) async {
    _ensureIdle();
    return _inspectPath(fileReferencePath(file));
  }

  @override
  Future<ProcessingResult> merge(List<FileReference> files, String outputPath) {
    final inputs = files.map(fileReferencePath).toList();
    return _run(
      QpdfArgs.merge(inputs, outputPath),
      inputPath: inputs.first,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> split(FileReference file, String outputDir) async {
    final inputPath = fileReferencePath(file);
    await Directory(outputDir).create(recursive: true);
    final pattern = p.join(outputDir, 'page.pdf');
    return _run(
      QpdfArgs.split(inputPath, pattern),
      inputPath: inputPath,
      outputPath: pattern,
      verifyExactOutput: false,
      outputDirectory: outputDir,
    );
  }

  @override
  Future<ProcessingResult> extractPages(
    FileReference file,
    List<int> pageNumbers,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return _run(
      QpdfArgs.selectPages(
        inputPath,
        QpdfArgs.pageList(pageNumbers),
        outputPath,
      ),
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> reorderPages(
    FileReference file,
    List<int> newOrder,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return _run(
      QpdfArgs.selectPages(inputPath, QpdfArgs.pageList(newOrder), outputPath),
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> rotatePages(
    FileReference file,
    Map<int, int> pageRotations,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return _run(
      QpdfArgs.rotate(
        inputPath,
        outputPath,
        QpdfArgs.rotateFlags(pageRotations),
      ),
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> deletePages(
    FileReference file,
    List<int> pageNumbers,
    String outputPath,
  ) async {
    final inputPath = fileReferencePath(file);
    final count = await _pageCount(inputPath);
    return _run(
      QpdfArgs.selectPages(
        inputPath,
        QpdfArgs.complementPages(count, pageNumbers),
        outputPath,
      ),
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> compress(FileReference file, String outputPath) {
    final inputPath = fileReferencePath(file);
    return _run(
      QpdfArgs.compress(inputPath, outputPath),
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> addWatermark(
    FileReference file,
    String watermarkText,
    String outputPath,
  ) async {
    if (watermarkText.trim().isEmpty) {
      throw const FileValidationException('Watermark text cannot be empty');
    }
    final inputPath = fileReferencePath(file);
    final meta = await _inspectPath(inputPath);
    if (meta.isEncrypted && meta.pageCount == null) {
      throw const FileValidationException(
        'This PDF is encrypted. Remove the password before adding a watermark',
      );
    }
    final stamp = SimplePdf.pages(
      texts: [watermarkText],
      width: meta.pageWidth ?? 612,
      height: meta.pageHeight ?? 792,
      fontSize: 48,
    );
    return _withStamp(
      stamp,
      (stampPath) => QpdfArgs.overlay(
        inputPath: inputPath,
        stampPath: stampPath,
        outputPath: outputPath,
        repeatFirstPage: true,
      ),
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> addPageNumbers(
    FileReference file,
    String outputPath,
  ) async {
    final inputPath = fileReferencePath(file);
    final meta = await _inspectPath(inputPath);
    final count = meta.pageCount;
    if (count == null || count < 1) {
      throw const FileValidationException(
        'Cannot number pages without a page count',
      );
    }
    final stamp = SimplePdf.pages(
      texts: [for (var i = 1; i <= count; i++) '$i'],
      width: meta.pageWidth ?? 612,
      height: meta.pageHeight ?? 792,
      fontSize: 12,
      alignBottom: true,
    );
    return _withStamp(
      stamp,
      (stampPath) => QpdfArgs.overlay(
        inputPath: inputPath,
        stampPath: stampPath,
        outputPath: outputPath,
      ),
      inputPath: inputPath,
      outputPath: outputPath,
    );
  }

  @override
  Future<ProcessingResult> protect(
    FileReference file,
    String password,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return _run(
      QpdfArgs.encrypt(inputPath, outputPath, password),
      inputPath: inputPath,
      outputPath: outputPath,
      secrets: [password],
    );
  }

  @override
  Future<ProcessingResult> removeProtection(
    FileReference file,
    String password,
    String outputPath,
  ) {
    final inputPath = fileReferencePath(file);
    return _run(
      QpdfArgs.decrypt(inputPath, outputPath, password),
      inputPath: inputPath,
      outputPath: outputPath,
      secrets: [password],
    );
  }

  Future<ProcessingResult> _withStamp(
    List<int> stampBytes,
    List<String> Function(String stampPath) args, {
    required String inputPath,
    required String outputPath,
  }) async {
    final stampFile = File(
      p.join(Directory.systemTemp.path, 'fileforge-stamp-${_ids.v4()}.pdf'),
    );
    await stampFile.writeAsBytes(stampBytes, flush: true);
    try {
      return await _run(
        args(stampFile.path),
        inputPath: inputPath,
        outputPath: outputPath,
      );
    } finally {
      if (await stampFile.exists()) await stampFile.delete();
    }
  }

  Future<int> _pageCount(String path) async {
    final meta = await _inspectPath(path);
    final count = meta.pageCount;
    if (count == null) {
      throw const FileValidationException('Unable to determine the page count');
    }
    return count;
  }

  Future<PdfMetadata> _inspectPath(String path) async {
    final captured = await _capture(QpdfArgs.inspect(path));
    if (captured.cancelled) {
      throw const FileValidationException('Inspection was cancelled');
    }
    if (captured.exitCode == 0 && captured.stdout.trim().isNotEmpty) {
      try {
        return QpdfMetadataParser.parse(captured.stdout);
      } on FormatException {
        // Fall through to the page-count command.
      }
    }
    if (_looksEncrypted(captured.stderr) || _looksEncrypted(captured.stdout)) {
      return const PdfMetadata(isEncrypted: true);
    }
    final pages = await _showPageCount(path);
    if (pages != null) return PdfMetadata(pageCount: pages);
    final message = captured.stderr.trim();
    throw FileValidationException(
      message.isEmpty ? 'Unable to inspect PDF' : message,
    );
  }

  Future<int?> _showPageCount(String path) async {
    final captured = await _capture(QpdfArgs.showPageCount(path));
    if (captured.exitCode != 0) return null;
    return int.tryParse(captured.stdout.trim());
  }

  Future<ProcessingResult> _run(
    List<String> args, {
    required String inputPath,
    required String outputPath,
    bool verifyExactOutput = true,
    String? outputDirectory,
    List<String> secrets = const [],
  }) async {
    _ensureIdle();
    _busy = true;
    final jobId = _ids.v4();
    final watch = Stopwatch()..start();
    try {
      if (!await File(inputPath).exists()) {
        throw const FileValidationException('Input file not found');
      }
      rejectOverwrite(inputPath, outputPath);
      final parent = Directory(p.dirname(outputPath));
      if (!await parent.exists()) await parent.create(recursive: true);

      _progress.add(0);
      final captured = await _capture(args, track: true);
      watch.stop();
      final stderr = _scrub(captured.stderr, secrets);

      if (captured.cancelled) {
        return ProcessingResult(
          jobId: jobId,
          success: false,
          errorMessage: 'Cancelled',
          elapsed: watch.elapsed,
        );
      }
      if (captured.exitCode != 0) {
        return ProcessingResult(
          jobId: jobId,
          success: false,
          errorMessage:
              stderr.trim().isEmpty
                  ? 'qpdf exited with code ${captured.exitCode}'
                  : stderr.trim(),
          elapsed: watch.elapsed,
        );
      }

      final outputs = <OutputArtifact>[];
      if (outputDirectory != null) {
        final produced =
            Directory(outputDirectory)
                .listSync()
                .whereType<File>()
                .where((file) => file.path.toLowerCase().endsWith('.pdf'))
                .toList();
        if (produced.isEmpty) {
          return ProcessingResult(
            jobId: jobId,
            success: false,
            errorMessage: 'qpdf did not write any pages',
            elapsed: watch.elapsed,
          );
        }
        for (final file in produced) {
          outputs.add(await _artifact(jobId, file.path));
        }
      } else if (verifyExactOutput) {
        final output = File(outputPath);
        if (!await output.exists() || await output.length() == 0) {
          return ProcessingResult(
            jobId: jobId,
            success: false,
            errorMessage: 'Output file is missing or empty',
            elapsed: watch.elapsed,
          );
        }
        outputs.add(await _artifact(jobId, outputPath));
      }

      _progress.add(1);
      return ProcessingResult(
        jobId: jobId,
        success: true,
        outputs: outputs,
        elapsed: watch.elapsed,
      );
    } on ProcessException catch (error) {
      if (isMissingExecutable(error)) {
        throw const DependencyMissingException('qpdf');
      }
      rethrow;
    } finally {
      _busy = false;
      _active = null;
    }
  }

  Future<CapturedProcess> _capture(
    List<String> args, {
    bool track = false,
  }) async {
    try {
      return await _runner.startAndCapture(
        'qpdf',
        args,
        onStarted: track ? (handle) => _active = handle : null,
      );
    } on ProcessException catch (error) {
      if (isMissingExecutable(error)) {
        throw const DependencyMissingException('qpdf');
      }
      rethrow;
    }
  }

  Future<OutputArtifact> _artifact(String jobId, String path) async {
    final size = await File(path).length();
    return OutputArtifact(
      id: _ids.v4(),
      jobId: jobId,
      status: OutputArtifactStatus.completed,
      sizeBytes: size,
      file: FileReference(
        displayName: p.basename(path),
        uri: path,
        sizeBytes: size,
        detectedFormat: FileFormat.pdf,
        mimeType: FileFormat.pdf.mimeTypes.first,
        hasWriteAccess: true,
      ),
    );
  }

  void _ensureIdle() {
    if (_busy) {
      throw ProcessingException(engineId, message: 'Engine is already running');
    }
  }

  bool _looksEncrypted(String text) {
    final lower = text.toLowerCase();
    return lower.contains('invalid password') ||
        lower.contains('file is encrypted') ||
        lower.contains('incorrect password');
  }

  String _scrub(String text, List<String> secrets) {
    var result = text;
    for (final secret in secrets) {
      result = redactSecret(result, secret);
    }
    return result;
  }
}
