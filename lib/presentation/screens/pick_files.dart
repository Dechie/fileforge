import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';

/// Extensions accepted by a studio picker, without the leading dot.
List<String> extensionsFor(Iterable<FileFormat> formats) {
  return [for (final format in formats) ...format.extensions];
}

/// Open the platform file picker and detect each file's format.
Future<List<FileReference>> pickFiles(
  BuildContext context, {
  bool allowMultiple = true,
  List<String>? extensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    type:
        extensions == null || extensions.isEmpty
            ? FileType.any
            : FileType.custom,
    allowedExtensions: extensions,
  );
  if (result == null) return const [];
  if (!context.mounted) return const [];
  final inspector = context.read<FileInspectionService>();
  final files = <FileReference>[];
  for (final picked in result.files) {
    final path = picked.path;
    if (path == null || path.isEmpty) continue;
    final ioFile = File(path);
    final size = await ioFile.exists() ? await ioFile.length() : picked.size;
    var file = FileReference(
      displayName: picked.name,
      uri: path,
      sizeBytes: size,
    );
    try {
      final format = await inspector.detectFormat(file);
      file = file.copyWith(
        detectedFormat: format,
        mimeType: format?.mimeTypes.first,
        sizeBytes: size,
      );
    } catch (_) {
      // Keep the selection so the studio can explain why it cannot be used.
    }
    files.add(file);
  }
  return files;
}
