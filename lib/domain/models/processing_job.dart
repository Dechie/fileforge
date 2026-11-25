import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/file_reference.dart';

/// A request to process one or more files.
class ProcessingRequest {
  /// Unique request identifier.
  final String id;

  /// Which studio originated this request.
  final StudioType studio;

  /// The specific operation to perform.
  final OperationType operation;

  /// Input files to process.
  final List<FileReference> inputs;

  /// Operation-specific parameters (e.g. quality, dimensions, pages).
  final Map<String, dynamic> parameters;

  /// Desired output format, if applicable.
  final FileFormat? outputFormat;

  /// User-specified output directory, if any.
  final String? outputDirectory;

  const ProcessingRequest({
    required this.id,
    required this.studio,
    required this.operation,
    required this.inputs,
    this.parameters = const {},
    this.outputFormat,
    this.outputDirectory,
  });
}

/// A processing job that tracks the full lifecycle of a request.
class ProcessingJob {
  final String id;
  final ProcessingRequest request;
  final JobStatus status;
  final String? engineId;
  final String? engineVersion;
  final double progress; // 0.0 – 1.0
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final List<OutputArtifact> outputs;
  final ProcessingCheckpoint? checkpoint;

  const ProcessingJob({
    required this.id,
    required this.request,
    this.status = JobStatus.created,
    this.engineId,
    this.engineVersion,
    this.progress = 0.0,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.outputs = const [],
    this.checkpoint,
  });

  ProcessingJob copyWith({
    JobStatus? status,
    String? engineId,
    String? engineVersion,
    double? progress,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    List<OutputArtifact>? outputs,
    ProcessingCheckpoint? checkpoint,
  }) {
    return ProcessingJob(
      id: id,
      request: request,
      status: status ?? this.status,
      engineId: engineId ?? this.engineId,
      engineVersion: engineVersion ?? this.engineVersion,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      outputs: outputs ?? this.outputs,
      checkpoint: checkpoint ?? this.checkpoint,
    );
  }

  /// Move to [next] when [JobStatus.canTransitionTo] allows it.
  ///
  /// Sets [startedAt] the first time the job enters [JobStatus.processing]
  /// and [completedAt] when the new state is terminal.
  ProcessingJob transitionTo(
    JobStatus next, {
    double? progress,
    String? errorMessage,
    String? engineId,
    String? engineVersion,
    List<OutputArtifact>? outputs,
    DateTime? now,
  }) {
    if (!status.canTransitionTo(next)) {
      throw FileForgeException(
        'Cannot transition job $id from ${status.name} to ${next.name}',
        code: 'invalid_job_transition',
      );
    }
    final clock = now ?? DateTime.now();
    return copyWith(
      status: next,
      progress: progress,
      errorMessage: errorMessage,
      engineId: engineId,
      engineVersion: engineVersion,
      outputs: outputs,
      startedAt:
          next == JobStatus.processing && startedAt == null ? clock : null,
      completedAt: next.isTerminal ? clock : null,
    );
  }
}

/// A file produced by a processing job.
class OutputArtifact {
  final String id;
  final String jobId;
  final FileReference file;
  final OutputArtifactStatus status;
  final int? sizeBytes;

  const OutputArtifact({
    required this.id,
    required this.jobId,
    required this.file,
    this.status = OutputArtifactStatus.pending,
    this.sizeBytes,
  });
}

/// A checkpoint for resumable processing.
class ProcessingCheckpoint {
  final String jobId;
  final String inputIdentity;
  final String? inputHash;
  final String engineId;
  final String engineVersion;
  final Map<String, dynamic> processingParameters;
  final int completedUnits;
  final int totalUnits;
  final List<String> intermediateArtifactPaths;
  final DateTime createdAt;
  final RecoveryCapability recoveryCapability;

  const ProcessingCheckpoint({
    required this.jobId,
    required this.inputIdentity,
    this.inputHash,
    required this.engineId,
    required this.engineVersion,
    this.processingParameters = const {},
    this.completedUnits = 0,
    this.totalUnits = 0,
    this.intermediateArtifactPaths = const [],
    required this.createdAt,
    this.recoveryCapability = RecoveryCapability.restartFromBeginning,
  });

  bool isCompatibleWith(ProcessingCheckpoint other) {
    return inputIdentity == other.inputIdentity &&
        inputHash == other.inputHash &&
        engineId == other.engineId &&
        engineVersion == other.engineVersion;
  }
}

/// Result after a processing operation completes.
class ProcessingResult {
  final String jobId;
  final bool success;
  final List<OutputArtifact> outputs;
  final String? errorMessage;
  final Duration elapsed;
  final Map<String, dynamic> metrics;

  const ProcessingResult({
    required this.jobId,
    required this.success,
    this.outputs = const [],
    this.errorMessage,
    this.elapsed = Duration.zero,
    this.metrics = const {},
  });
}
