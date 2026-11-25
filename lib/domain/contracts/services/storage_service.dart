import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/domain/enums/enums.dart';

/// Service contract for managing storage across all studios.
abstract class StorageService {
  /// Get current storage usage information.
  Future<StorageInfo> getStorageInfo();

  /// Estimate space required for a processing operation.
  Future<int> estimateRequiredSpace(ProcessingRequest request);

  /// Check if sufficient space is available for an operation.
  Future<bool> hasEnoughSpace(int requiredBytes);

  /// Get the app's working temp directory.
  Future<String> getTempDirectory(String jobId);

  /// Get the output directory for a job.
  Future<String> getOutputDirectory(String jobId);

  /// Clean temp files for a completed job.
  Future<void> cleanJobTempFiles(String jobId);

  /// Clean all orphaned temp files.
  Future<void> cleanOrphanedTempFiles();

  /// Clean app cache.
  Future<void> clearCache();

  /// Track a file so the storage manager knows about it.
  Future<void> trackFile(String path, StorageFileType type, String jobId);

  /// Remove tracking for a file.
  Future<void> untrackFile(String path);
}
