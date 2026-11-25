import 'package:flutter/foundation.dart';

/// Persistent user settings.
class SettingsProvider extends ChangeNotifier {
  // Theme
  bool _isDarkMode = true;

  // Processing defaults
  int _defaultVideoQuality = 23; // CRF value
  int _defaultImageQuality = 85; // 0-100
  bool _preserveMetadata = true;
  bool _removeGpsData = true;

  // Storage
  bool _autoCleanTempFiles = true;
  int _maxConcurrentJobs = 3;

  // Getters
  bool get isDarkMode => _isDarkMode;
  int get defaultVideoQuality => _defaultVideoQuality;
  int get defaultImageQuality => _defaultImageQuality;
  bool get preserveMetadata => _preserveMetadata;
  bool get removeGpsData => _removeGpsData;
  bool get autoCleanTempFiles => _autoCleanTempFiles;
  int get maxConcurrentJobs => _maxConcurrentJobs;

  // Setters
  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setDefaultVideoQuality(int value) {
    _defaultVideoQuality = value.clamp(0, 51);
    notifyListeners();
  }

  void setDefaultImageQuality(int value) {
    _defaultImageQuality = value.clamp(1, 100);
    notifyListeners();
  }

  void setPreserveMetadata(bool value) {
    _preserveMetadata = value;
    notifyListeners();
  }

  void setRemoveGpsData(bool value) {
    _removeGpsData = value;
    notifyListeners();
  }

  void setAutoCleanTempFiles(bool value) {
    _autoCleanTempFiles = value;
    notifyListeners();
  }

  void setMaxConcurrentJobs(int value) {
    _maxConcurrentJobs = value.clamp(1, 8);
    notifyListeners();
  }
}
