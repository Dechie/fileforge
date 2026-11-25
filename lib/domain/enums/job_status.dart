/// Processing job lifecycle states, matching the spec §10.2.
enum JobStatus {
  created('Created'),
  pending('Pending'),
  validating('Validating'),
  waitingForEngine('Waiting for Engine'),
  waitingForStorage('Waiting for Storage'),
  processing('Processing'),
  checkpointing('Checkpointing'),
  verifying('Verifying'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled'),
  interrupted('Interrupted'),
  recoverable('Recoverable');

  final String displayName;
  const JobStatus(this.displayName);

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;

  bool get isActive =>
      this == processing ||
      this == validating ||
      this == verifying ||
      this == checkpointing;

  /// Legal edges in the job lifecycle. Completion is only reachable from
  /// [verifying], so a job cannot be marked done before output checks.
  static const Map<JobStatus, Set<JobStatus>> allowedTransitions = {
    JobStatus.created: {JobStatus.pending, JobStatus.cancelled},
    JobStatus.pending: {
      JobStatus.validating,
      JobStatus.cancelled,
      JobStatus.failed,
    },
    JobStatus.validating: {
      JobStatus.waitingForEngine,
      JobStatus.waitingForStorage,
      JobStatus.processing,
      JobStatus.failed,
      JobStatus.cancelled,
    },
    JobStatus.waitingForEngine: {
      JobStatus.waitingForStorage,
      JobStatus.processing,
      JobStatus.failed,
      JobStatus.cancelled,
    },
    JobStatus.waitingForStorage: {
      JobStatus.processing,
      JobStatus.failed,
      JobStatus.cancelled,
    },
    JobStatus.processing: {
      JobStatus.checkpointing,
      JobStatus.verifying,
      JobStatus.failed,
      JobStatus.cancelled,
      JobStatus.interrupted,
    },
    JobStatus.checkpointing: {
      JobStatus.processing,
      JobStatus.verifying,
      JobStatus.failed,
      JobStatus.cancelled,
      JobStatus.interrupted,
      JobStatus.recoverable,
    },
    JobStatus.verifying: {
      JobStatus.completed,
      JobStatus.failed,
      JobStatus.processing,
      JobStatus.cancelled,
    },
    JobStatus.interrupted: {
      JobStatus.recoverable,
      JobStatus.failed,
      JobStatus.pending,
    },
    JobStatus.recoverable: {
      JobStatus.pending,
      JobStatus.validating,
      JobStatus.failed,
      JobStatus.cancelled,
    },
  };

  /// Whether a job in this state may move to [next].
  bool canTransitionTo(JobStatus next) =>
      allowedTransitions[this]?.contains(next) ?? false;
}
