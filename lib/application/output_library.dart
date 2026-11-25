import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fileforge/application/output_paths.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:path/path.dart' as p;

/// A file written by a studio, found by scanning the output folders.
class SavedOutput {
  const SavedOutput({
    required this.studio,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
    this.format,
  });

  final StudioType studio;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;
  final FileFormat? format;

  String get directory => p.dirname(path);
}

/// Scans each studio folder, plus older files left in the shared output root.
class OutputLibrary extends ChangeNotifier {
  String? _rootPath;
  String? _error;
  bool _ready = false;
  Map<StudioType, List<SavedOutput>> _byStudio = {};

  bool get isReady => _ready;
  String? get error => _error;
  String? get rootPath => _rootPath;

  List<SavedOutput> outputsFor(StudioType studio) {
    return List.unmodifiable(_byStudio[studio] ?? const <SavedOutput>[]);
  }

  /// Newest saved file across every studio.
  List<SavedOutput> get recent {
    final all = [for (final items in _byStudio.values) ...items];
    all.sort((a, b) => b.modified.compareTo(a.modified));
    return all;
  }

  String? folderFor(StudioType studio) {
    final root = _rootPath;
    final folder = studioOutputFolder(studio);
    if (root == null || folder == null) return null;
    return p.join(root, folder);
  }

  Future<void> refresh() async {
    try {
      final root = await defaultJobOutputDirectory();
      final found = <StudioType, List<SavedOutput>>{
        for (final studio in _galleryStudios) studio: <SavedOutput>[],
      };
      for (final studio in _galleryStudios) {
        final directory = Directory(
          p.join(root.path, studioOutputFolder(studio)!),
        );
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            final saved = await _describe(studio, entity);
            if (saved != null) found[studio]!.add(saved);
          }
        }
      }
      await for (final entity in root.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (_isStudioFolder(name)) continue;
        final studio = studioForSavedName(name);
        if (studio == null || !found.containsKey(studio)) continue;
        if (entity is File) {
          final saved = await _describe(studio, entity);
          if (saved != null) found[studio]!.add(saved);
        } else if (entity is Directory) {
          await for (final child in entity.list(
            recursive: true,
            followLinks: false,
          )) {
            if (child is! File) continue;
            final saved = await _describe(studio, child);
            if (saved != null) found[studio]!.add(saved);
          }
        }
      }
      for (final items in found.values) {
        items.sort((a, b) => b.modified.compareTo(a.modified));
      }
      _rootPath = root.path;
      _byStudio = found;
      _error = null;
    } catch (error) {
      _error = '$error';
    }
    _ready = true;
    notifyListeners();
  }
}

const _galleryStudios = [
  StudioType.pdfStudio,
  StudioType.documentStudio,
  StudioType.imageStudio,
  StudioType.videoStudio,
  StudioType.audioStudio,
];

bool _isStudioFolder(String name) {
  return _galleryStudios.any((studio) => studioOutputFolder(studio) == name);
}

Future<SavedOutput?> _describe(StudioType studio, File file) async {
  final name = p.basename(file.path);
  if (name.startsWith('.')) return null;
  final stat = await file.stat();
  return SavedOutput(
    studio: studio,
    path: file.path,
    name: name,
    sizeBytes: stat.size,
    modified: stat.modified,
    format: FileFormat.fromExtension(p.extension(name)),
  );
}
