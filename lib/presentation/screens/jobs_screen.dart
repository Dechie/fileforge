import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/providers/processing_provider.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/widgets/empty_state.dart';
import 'package:fileforge/presentation/widgets/job_widgets.dart';

/// Active work and the jobs that have already finished.
class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final processing = context.watch<ProcessingProvider>();
    final active = processing.activeJobs;
    final completed = processing.completedJobs;
    return Scaffold(
      appBar: forgeAppBar(
        context,
        title: 'Processing Jobs',
        actions: [
          IconButton(
            tooltip: 'Clear history',
            onPressed: completed.isEmpty ? null : processing.clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No active jobs'),
            )
          else
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: active.length,
                itemBuilder: (context, index) {
                  final job = active[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: JobProgressCard(
                      job: job,
                      onCancel: () => context.read<JobRunner>().cancel(job.id),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child:
                completed.isEmpty
                    ? const EmptyState(
                      icon: Icons.history,
                      title: 'No completed jobs',
                      subtitle: 'Finished work shows up here.',
                    )
                    : ListView.builder(
                      itemCount: completed.length,
                      itemBuilder: (context, index) {
                        final job = completed[index];
                        return JobHistoryTile(
                          job: job,
                          onTap: () => _showDetails(context, job),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, ProcessingJob job) {
    final outputs = job.outputs
        .map((output) => output.file.displayName)
        .join('\n');
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(job.request.operation.displayName),
            content: Text(
              job.errorMessage ??
                  (outputs.isEmpty ? job.status.displayName : outputs),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
