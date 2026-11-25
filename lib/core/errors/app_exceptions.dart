/// Base exception for all FileForge errors.
class FileForgeException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const FileForgeException(this.message, {this.code, this.cause});

  @override
  String toString() => 'FileForgeException($code): $message';
}

/// Thrown when a required engine is not available.
class EngineNotAvailableException extends FileForgeException {
  final String engineId;
  const EngineNotAvailableException(this.engineId, {String? message})
    : super(message ?? 'Engine "$engineId" is not available');
}

/// Thrown when a required system dependency is missing.
class DependencyMissingException extends FileForgeException {
  final String dependencyName;
  const DependencyMissingException(this.dependencyName, {String? message})
    : super(message ?? 'Dependency "$dependencyName" is not installed');
}

/// Thrown when a file format is not supported for the requested operation.
class UnsupportedFormatException extends FileForgeException {
  final String? format;
  const UnsupportedFormatException({this.format, String? message})
    : super(message ?? 'Unsupported format: $format');
}

/// Thrown when storage is insufficient for an operation.
class InsufficientStorageException extends FileForgeException {
  final int requiredBytes;
  final int availableBytes;
  const InsufficientStorageException({
    required this.requiredBytes,
    required this.availableBytes,
  }) : super(
         'Insufficient storage: need ${requiredBytes}B, have ${availableBytes}B',
       );
}

/// Thrown when a processing job fails.
class ProcessingException extends FileForgeException {
  final String jobId;
  const ProcessingException(this.jobId, {String? message})
    : super(message ?? 'Processing job "$jobId" failed');
}

/// Thrown when a processing job is cancelled by the user.
class JobCancelledException extends FileForgeException {
  final String jobId;
  const JobCancelledException(this.jobId) : super('Job "$jobId" was cancelled');
}

/// Thrown when file validation fails.
class FileValidationException extends FileForgeException {
  const FileValidationException(super.message);
}

/// Thrown when a platform operation is not supported.
class PlatformNotSupportedException extends FileForgeException {
  const PlatformNotSupportedException(super.message);
}
