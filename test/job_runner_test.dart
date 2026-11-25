import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/providers/engine_provider.dart';
import 'package:fileforge/application/providers/processing_provider.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image processing reports the missing engine', () async {
    final processing = ProcessingProvider();
    final runner = JobRunner(processing: processing, engines: EngineProvider());
    final result = await runner.run(
      const ProcessingRequest(
        id: 'job-image',
        studio: StudioType.imageStudio,
        operation: OperationType.imageConvert,
        inputs: [
          FileReference(displayName: 'photo.png', uri: '/tmp/photo.png'),
        ],
      ),
    );

    expect(result, isNotNull);
    expect(result!.success, isFalse);
    expect(result.errorMessage, contains('image'));
    expect(processing.activeJobs, isEmpty);
    expect(processing.completedJobs.single.status, JobStatus.failed);
  });

  test(
    'merge fails before an engine is required when only one file is chosen',
    () async {
      final processing = ProcessingProvider();
      final runner = JobRunner(
        processing: processing,
        engines: EngineProvider(),
      );
      final result = await runner.run(
        const ProcessingRequest(
          id: 'job-merge',
          studio: StudioType.pdfStudio,
          operation: OperationType.pdfMerge,
          inputs: [FileReference(displayName: 'a.pdf', uri: '/tmp/a.pdf')],
        ),
      );

      expect(result!.success, isFalse);
      expect(result.errorMessage, contains('two PDF'));
      expect(processing.completedJobs.single.status, JobStatus.failed);
    },
  );
}
