import 'dart:io';
import 'dart:typed_data';

import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:path/path.dart' as p;

/// Resolve a [FileReference] to a local filesystem path.
///
/// Accepts a plain path or a `file://` URI. Android content URIs are not
/// handled by the Linux adapters.
String fileReferencePath(FileReference file) {
  final raw = file.uri;
  rejectNullPath(raw);
  if (raw.startsWith('file:')) {
    return Uri.parse(raw).toFilePath();
  }
  return raw;
}

/// Extension from the path, then from the display name.
String fileReferenceExtension(FileReference file) {
  final fromPath = p.extension(fileReferencePath(file));
  if (fromPath.isNotEmpty) return fromPath;
  return p.extension(file.displayName);
}

/// Read up to [maxBytes] from the start of [path].
Future<Uint8List> readPrefix(String path, int maxBytes) async {
  final file = File(path);
  final raf = await file.open();
  try {
    return await raf.read(maxBytes);
  } finally {
    await raf.close();
  }
}

/// Reject a path that contains a NUL, which cannot be passed as an argument.
void rejectNullPath(String path) {
  if (path.contains('\u0000')) {
    throw const FileValidationException('Path contains a null character');
  }
}

/// Absolute, normalized path without resolving symlinks.
String normalizeUserPath(String path) {
  rejectNullPath(path);
  return p.normalize(p.absolute(path));
}

/// Refuse to write an output onto the input file.
void rejectOverwrite(String inputPath, String outputPath) {
  if (normalizeUserPath(inputPath) == normalizeUserPath(outputPath)) {
    throw const FileValidationException(
      'Refusing to overwrite the original file',
    );
  }
}
