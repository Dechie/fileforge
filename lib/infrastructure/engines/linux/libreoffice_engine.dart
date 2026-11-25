import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/contracts/engines/document_engine.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/markdown_html.dart';
import 'package:fileforge/infrastructure/filesystem/file_reference_io.dart';
import 'package:fileforge/infrastructure/platform/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Linux [DocumentEngine] that converts documents with headless LibreOffice.
///
/// Android reports [isAvailable] as false. Office conversion is not part of
/// the Android MVP.
class LibreOfficeEngine implements DocumentEngine {
  LibreOfficeEngine({
    CommandRunner? runner,
    bool? forceAvailable,
    bool forceAndroid = false,
    String? binaryOverride,
  }) : _runner = runner ?? const CommandRunner(),
       _forceAvailable = forceAvailable,
       _forceAndroid = forceAndroid,
       _binaryOverride = binaryOverride;

  static const Set<FileFormat> officeFormats = {
    FileFormat.docx,
    FileFormat.pptx,
    FileFormat.xlsx,
    FileFormat.odt,
    FileFormat.ods,
    FileFormat.odp,
  };

  final CommandRunner _runner;
  final bool? _forceAvailable;
  final bool _forceAndroid;
  final String? _binaryOverride;
  final Uuid _ids = const Uuid();
  final StreamController<double> _progress =
      StreamController<double>.broadcast();

  ProcessHandle? _active;
  String? _resolvedBinary;

  @override
  String get engineId => 'libreoffice';

  @override
  Stream<double> get progressStream => _progress.stream;

  @override
  bool get isAvailable {
    if (_isAndroid) return false;
    final forced = _forceAvailable;
    if (forced != null) return forced;
    return _binary() != null;
  }

  bool get _isAndroid => _forceAndroid || Platform.isAndroid;

  @override
  Future<void> cancel() async {
    final handle = _active;
    if (handle == null) return;
    await handle.cancel();
  }

  @override
  Future<ProcessingResult> convertToPdf(FileReference file, String outputPath) {
    final format = _formatOf(file);
    if (format == null || !officeFormats.contains(format)) {
      throw UnsupportedFormatException(
        format: format?.displayName ?? file.displayName,
        message: 'LibreOffice conversion accepts Office documents only',
      );
    }
    return _convertFile(file, outputPath, format);
  }

  @override
  Future<ProcessingResult> markdownToPdf(
    FileReference file,
    String outputPath,
  ) async {
    _ensureReady();
    final format = _formatOf(file);
    if (format != null && format != FileFormat.markdown) {
      throw UnsupportedFormatException(
        format: format.displayName,
        message: 'Expected a Markdown file',
      );
    }
    final source = File(fileReferencePath(file));
    if (!await source.exists()) {
      throw const FileValidationException('Input file not found');
    }
    final bytes = await source.readAsBytes();
    final head = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
    if (head.contains(0)) {
      throw const FileValidationException('Markdown file looks binary');
    }
    final html = markdownToHtml(
      utf8.decode(bytes, allowMalformed: true),
      title: p.basenameWithoutExtension(file.displayName),
    );
    final temp = await Directory.systemTemp.createTemp('fileforge-md-');
    try {
      final htmlFile = File(p.join(temp.path, 'document.html'));
      await htmlFile.writeAsString(html);
      return await _convertPath(
        htmlFile.path,
        outputPath,
        sourcePathForGuard: fileReferencePath(file),
      );
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  }

  Future<ProcessingResult> _convertFile(
    FileReference file,
    String outputPath,
    FileFormat format,
  ) async {
    _ensureReady();
    final inputPath = fileReferencePath(file);
    if (!await File(inputPath).exists()) {
      throw const FileValidationException('Input file not found');
    }
    final expected = format.extensions.first;
    final actual = p.extension(inputPath).replaceFirst('.', '').toLowerCase();
    if (actual == expected) {
      return _convertPath(inputPath, outputPath, sourcePathForGuard: inputPath);
    }
    final temp = await Directory.systemTemp.createTemp('fileforge-doc-');
    try {
      final copy = File(p.join(temp.path, 'input.$expected'));
      await File(inputPath).copy(copy.path);
      return await _convertPath(
        copy.path,
        outputPath,
        sourcePathForGuard: inputPath,
      );
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  }

  Future<ProcessingResult> _convertPath(
    String inputPath,
    String outputPath, {
    required String sourcePathForGuard,
  }) async {
    rejectOverwrite(sourcePathForGuard, outputPath);
    final jobId = _ids.v4();
    final watch = Stopwatch()..start();
    final work = await Directory.systemTemp.createTemp('fileforge-lo-');
    final profile = Directory(p.join(work.path, 'profile'));
    final outDir = Directory(p.join(work.path, 'out'));
    await profile.create(recursive: true);
    await outDir.create();
    _progress.add(0);
    try {
      final binary = _binary();
      if (binary == null) {
        throw const DependencyMissingException('libreoffice');
      }
      final captured = await _runner.startAndCapture(binary, [
        '-env:UserInstallation=${Uri.file(profile.path)}',
        '--headless',
        '--norestore',
        '--nolockcheck',
        '--convert-to',
        'pdf',
        '--outdir',
        outDir.path,
        inputPath,
      ], onStarted: (handle) => _active = handle);
      watch.stop();
      if (captured.cancelled) {
        return ProcessingResult(
          jobId: jobId,
          success: false,
          errorMessage: 'Cancelled',
          elapsed: watch.elapsed,
        );
      }
      final produced = File(
        p.join(outDir.path, '${p.basenameWithoutExtension(inputPath)}.pdf'),
      );
      if (captured.exitCode != 0 || !await produced.exists()) {
        final message =
            captured.stderr.trim().isEmpty
                ? captured.stdout.trim()
                : captured.stderr.trim();
        return ProcessingResult(
          jobId: jobId,
          success: false,
          errorMessage:
              message.isEmpty ? 'LibreOffice did not write a PDF' : message,
          elapsed: watch.elapsed,
        );
      }
      final destination = File(outputPath);
      await destination.parent.create(recursive: true);
      await produced.copy(destination.path);
      final size = await destination.length();
      _progress.add(1);
      return ProcessingResult(
        jobId: jobId,
        success: true,
        elapsed: watch.elapsed,
        outputs: [
          OutputArtifact(
            id: _ids.v4(),
            jobId: jobId,
            status: OutputArtifactStatus.completed,
            sizeBytes: size,
            file: FileReference(
              displayName: p.basename(outputPath),
              uri: outputPath,
              sizeBytes: size,
              detectedFormat: FileFormat.pdf,
              mimeType: FileFormat.pdf.mimeTypes.first,
              hasWriteAccess: true,
            ),
          ),
        ],
      );
    } on ProcessException catch (error) {
      if (isMissingExecutable(error)) {
        throw const DependencyMissingException('libreoffice');
      }
      rethrow;
    } finally {
      _active = null;
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  void _ensureReady() {
    if (_isAndroid) {
      throw const PlatformNotSupportedException(
        'Office conversion requires Linux with LibreOffice',
      );
    }
    if (_forceAvailable == false || _binary() == null) {
      throw const DependencyMissingException('libreoffice');
    }
  }

  FileFormat? _formatOf(FileReference file) {
    return file.detectedFormat ??
        FileFormat.fromExtension(fileReferenceExtension(file));
  }

  String? _binary() {
    if (_binaryOverride != null) return _binaryOverride;
    if (_resolvedBinary != null) return _resolvedBinary;
    if (_isAndroid) return null;
    for (final name in ['libreoffice', 'soffice']) {
      final result = Process.runSync('which', [name]);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) {
          _resolvedBinary = path;
          return path;
        }
      }
    }
    return null;
  }
}
