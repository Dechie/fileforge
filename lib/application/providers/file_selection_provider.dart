import 'package:flutter/foundation.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/domain/models/models.dart';

/// Tracks the current file selection across the app.
///
/// When an inspection service is supplied, each added file is given a
/// content-detected [FileReference.detectedFormat] before it is stored.
class FileSelectionProvider extends ChangeNotifier {
  FileSelectionProvider({FileInspectionService? inspectionService})
    : _inspectionService = inspectionService;

  final FileInspectionService? _inspectionService;
  final List<FileReference> _selectedFiles = [];

  List<FileReference> get selectedFiles => List.unmodifiable(_selectedFiles);
  bool get hasSelection => _selectedFiles.isNotEmpty;
  int get fileCount => _selectedFiles.length;

  Future<void> addFile(FileReference file) async {
    final inspected = await _withFormat(file);
    if (!_selectedFiles.contains(inspected)) {
      _selectedFiles.add(inspected);
      notifyListeners();
    }
  }

  Future<void> addFiles(List<FileReference> files) async {
    var changed = false;
    for (final file in files) {
      final inspected = await _withFormat(file);
      if (!_selectedFiles.contains(inspected)) {
        _selectedFiles.add(inspected);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  Future<FileReference> _withFormat(FileReference file) async {
    if (file.detectedFormat != null || _inspectionService == null) return file;
    try {
      final format = await _inspectionService.detectFormat(file);
      if (format == null) return file;
      return file.copyWith(detectedFormat: format);
    } catch (_) {
      return file;
    }
  }

  void removeFile(FileReference file) {
    _selectedFiles.remove(file);
    notifyListeners();
  }

  void clearSelection() {
    _selectedFiles.clear();
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _selectedFiles.removeAt(oldIndex);
    _selectedFiles.insert(newIndex, item);
    notifyListeners();
  }
}
