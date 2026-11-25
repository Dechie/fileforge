import 'dart:io';

import 'package:fileforge/core/constants/app_constants.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// `Documents/FileForge/output`.
Future<Directory> defaultJobOutputDirectory() async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(
    p.join(root.path, 'FileForge', AppConstants.outputDir),
  );
  await directory.create(recursive: true);
  return directory;
}

/// Subfolder under the output root for a studio gallery.
String? studioOutputFolder(StudioType studio) {
  switch (studio) {
    case StudioType.pdfStudio:
      return 'pdf';
    case StudioType.documentStudio:
      return 'documents';
    case StudioType.imageStudio:
      return 'images';
    case StudioType.videoStudio:
      return 'video';
    case StudioType.audioStudio:
      return 'audio';
    default:
      return null;
  }
}

/// Which studio produced a saved file or folder, based on its name.
///
/// New files include the operation name, for example `notes_pdfMerge_123.pdf`.
/// Older files that were written into the shared output folder use the same
/// pattern and still sort into a gallery.
StudioType? studioForSavedName(String name) {
  final stem = p.basenameWithoutExtension(name).toLowerCase();
  final parts = stem.split('_');
  for (final part in parts) {
    for (final operation in OperationType.values) {
      if (part == operation.name.toLowerCase()) {
        return _studioForOperation(operation);
      }
    }
  }
  if (stem.endsWith('_frames') || stem.contains('frame_')) {
    return StudioType.videoStudio;
  }
  if (stem.endsWith('_pages')) return StudioType.pdfStudio;
  return null;
}

StudioType? _studioForOperation(OperationType operation) {
  final name = operation.name;
  if (name.startsWith('pdf')) return StudioType.pdfStudio;
  if (name.startsWith('document') || name.startsWith('markdown')) {
    return StudioType.documentStudio;
  }
  if (name.startsWith('image')) return StudioType.imageStudio;
  if (name.startsWith('video')) return StudioType.videoStudio;
  if (name.startsWith('audio')) return StudioType.audioStudio;
  return null;
}

/// Replace the home directory with `~` so a path fits in the UI.
String friendlyPath(String path) {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty && path.startsWith(home)) {
    return '~${path.substring(home.length)}';
  }
  return path;
}

/// Ask the desktop to open a file or folder.
Future<bool> openSavedPath(String path) async {
  try {
    await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}
