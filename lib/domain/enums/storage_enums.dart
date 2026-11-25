/// State of an output artifact managed by the Storage Manager.
enum OutputArtifactStatus {
  pending,
  processing,
  partial,
  verified,
  completed,
  failed,
  cancelled,
}

/// Categories of files the Storage Manager tracks.
enum StorageFileType {
  original,
  temporaryWorkingCopy,
  intermediateArtifact,
  partialOutput,
  completedOutput,
  cachedPreview,
  recoverableCheckpoint,
}

/// Engine recovery capability declarations (§10.7).
enum RecoveryCapability {
  /// Engine cannot resume; must restart from beginning.
  restartFromBeginning,

  /// Engine can resume from a verified checkpoint.
  restartFromCheckpoint,

  /// Engine can continue from previously completed chunks.
  partialContinuation,
}
