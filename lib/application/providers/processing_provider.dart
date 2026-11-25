import 'package:flutter/foundation.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';

/// Manages processing jobs: creation, tracking, progress, history.
class ProcessingProvider extends ChangeNotifier {
  final List<ProcessingJob> _activeJobs = [];
  final List<ProcessingJob> _completedJobs = [];

  List<ProcessingJob> get activeJobs => List.unmodifiable(_activeJobs);
  List<ProcessingJob> get completedJobs => List.unmodifiable(_completedJobs);

  int get activeJobCount => _activeJobs.length;

  /// Submit a new processing request.
  Future<ProcessingJob> submitJob(ProcessingRequest request) async {
    final job = ProcessingJob(
      id: request.id,
      request: request,
      status: JobStatus.created,
      createdAt: DateTime.now(),
    );
    _activeJobs.add(job);
    notifyListeners();
    return job;
  }

  /// Update a job's status.
  void updateJobStatus(
    String jobId,
    JobStatus status, {
    double? progress,
    String? error,
    String? engineId,
    String? engineVersion,
    List<OutputArtifact>? outputs,
  }) {
    final index = _activeJobs.indexWhere((j) => j.id == jobId);
    if (index < 0) return;

    final updated = _activeJobs[index].transitionTo(
      status,
      progress: progress,
      errorMessage: error,
      engineId: engineId,
      engineVersion: engineVersion,
      outputs: outputs,
    );

    if (status.isTerminal) {
      _activeJobs.removeAt(index);
      _completedJobs.insert(0, updated);
    } else {
      _activeJobs[index] = updated;
    }
    notifyListeners();
  }

  /// Update progress without changing status.
  ///
  /// Processing stays in [JobStatus.processing] while an engine reports
  /// progress, and that state has no self-transition.
  void updateProgress(String jobId, double progress) {
    final index = _activeJobs.indexWhere((j) => j.id == jobId);
    if (index < 0) return;
    _activeJobs[index] = _activeJobs[index].copyWith(
      progress: progress.clamp(0.0, 1.0),
    );
    notifyListeners();
  }

  /// Cancel an active job.
  void cancelJob(String jobId) {
    updateJobStatus(jobId, JobStatus.cancelled);
  }

  /// Clear completed job history.
  void clearHistory() {
    _completedJobs.clear();
    notifyListeners();
  }
}
