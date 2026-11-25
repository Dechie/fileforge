/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'FileForge';
  static const String appVersion = '0.1.0';
  static const String dbName = 'fileforge.db';
  static const int dbVersion = 1;

  // Storage subdirectories
  static const String tempDir = 'temp';
  static const String outputDir = 'output';
  static const String cacheDir = 'cache';
  static const String checkpointDir = 'checkpoints';
  static const String previewDir = 'previews';

  // Processing limits
  static const int maxConcurrentJobs = 3;
  static const int maxRetryAttempts = 2;
  static const Duration jobTimeout = Duration(hours: 4);

  // File size thresholds
  static const int largePdfThreshold = 100 * 1024 * 1024; // 100 MB
  static const int largeVideoThreshold = 1024 * 1024 * 1024; // 1 GB
  static const int largeImageThreshold = 50 * 1024 * 1024; // 50 MB
}
