import 'package:flutter/foundation.dart';
import 'package:fileforge/domain/models/models.dart';

/// Provides storage usage info and coordinates storage across studios.
class StorageProvider extends ChangeNotifier {
  StorageInfo _storageInfo = const StorageInfo();
  bool _isInitialized = false;

  StorageInfo get storageInfo => _storageInfo;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    await refresh();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    // TODO: Implement actual storage scanning via StorageService.
    _storageInfo = const StorageInfo();
    notifyListeners();
  }

  /// Check if sufficient space is available for an estimated operation.
  bool hasEnoughSpace(int requiredBytes) {
    return _storageInfo.freeBytes >= requiredBytes;
  }
}
