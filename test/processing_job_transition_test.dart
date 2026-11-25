import 'package:fileforge/application/providers/processing_provider.dart';
import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProcessingRequest request() {
    return const ProcessingRequest(
      id: 'job-1',
      studio: StudioType.videoStudio,
      operation: OperationType.videoTrim,
      inputs: [],
    );
  }

  ProcessingJob createdJob() {
    return ProcessingJob(
      id: 'job-1',
      request: request(),
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('walks the happy path and only completes after verification', () {
    final clock = DateTime.utc(2026, 1, 2, 3, 4, 5);
    var job = createdJob();
    job = job.transitionTo(JobStatus.pending, now: clock);
    job = job.transitionTo(JobStatus.validating, now: clock);
    job = job.transitionTo(JobStatus.processing, now: clock, progress: 0.1);

    expect(job.status, JobStatus.processing);
    expect(job.startedAt, clock);
    expect(job.completedAt, isNull);

    job = job.transitionTo(JobStatus.verifying, now: clock, progress: 1);
    expect(job.startedAt, clock);

    job = job.transitionTo(JobStatus.completed, now: clock);
    expect(job.status, JobStatus.completed);
    expect(job.completedAt, clock);
    expect(job.status.canTransitionTo(JobStatus.failed), isFalse);
  });

  test('rejects completing a job that has not been verified', () {
    final job = createdJob()
        .transitionTo(JobStatus.pending)
        .transitionTo(JobStatus.validating)
        .transitionTo(JobStatus.processing);

    expect(
      () => job.transitionTo(JobStatus.completed),
      throwsA(isA<FileForgeException>()),
    );
  });

  test(
    'provider moves a created job to cancelled and rejects a skip',
    () async {
      final provider = ProcessingProvider();
      final job = await provider.submitJob(request());
      provider.cancelJob(job.id);

      expect(provider.activeJobs, isEmpty);
      expect(provider.completedJobs.single.status, JobStatus.cancelled);

      final running = ProcessingProvider();
      final created = await running.submitJob(request());
      expect(
        () => running.updateJobStatus(created.id, JobStatus.completed),
        throwsA(isA<FileForgeException>()),
      );
      expect(running.activeJobs.single.status, JobStatus.created);
    },
  );
}
