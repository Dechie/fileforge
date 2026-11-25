import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/core/utils/duration_formatter.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/processing_job.dart';

/// A card showing an active processing job with progress.
class JobProgressCard extends StatelessWidget {
  final ProcessingJob job;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;

  const JobProgressCard({
    super.key,
    required this.job,
    this.onCancel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: studio icon + operation + status
              Row(
                children: [
                  Icon(
                    _studioIcon(job.request.studio),
                    size: 18,
                    color: _studioColor(job.request.studio),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.request.operation.displayName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusChip(status: job.status),
                ],
              ),
              const SizedBox(height: 10),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: job.status.isActive ? job.progress : null,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),

              // Footer: elapsed time + engine + cancel
              Row(
                children: [
                  if (job.startedAt != null) ...[
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DurationFormatter.formatNatural(
                        DateTime.now().difference(job.startedAt!),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (job.engineId != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.memory, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(job.engineId!, style: theme.textTheme.bodySmall),
                  ],
                  const Spacer(),
                  if (onCancel != null && job.status.isActive)
                    SizedBox(
                      height: 28,
                      child: TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.stop, size: 14),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _studioIcon(StudioType studio) {
    switch (studio) {
      case StudioType.pdfStudio:
        return Icons.picture_as_pdf;
      case StudioType.documentStudio:
        return Icons.description;
      case StudioType.imageStudio:
        return Icons.image;
      case StudioType.videoStudio:
        return Icons.videocam;
      case StudioType.audioStudio:
        return Icons.audiotrack;
      default:
        return Icons.settings;
    }
  }

  Color _studioColor(StudioType studio) {
    switch (studio) {
      case StudioType.pdfStudio:
        return AppTheme.pdfStudioColor;
      case StudioType.documentStudio:
        return AppTheme.documentStudioColor;
      case StudioType.imageStudio:
        return AppTheme.imageStudioColor;
      case StudioType.videoStudio:
        return AppTheme.videoStudioColor;
      case StudioType.audioStudio:
        return AppTheme.audioStudioColor;
      default:
        return AppTheme.textMuted;
    }
  }
}

/// A compact list tile for a completed job in the history.
class JobHistoryTile extends StatelessWidget {
  final ProcessingJob job;
  final VoidCallback? onTap;

  const JobHistoryTile({super.key, required this.job, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = job.status == JobStatus.completed;
    final elapsed =
        (job.completedAt != null && job.startedAt != null)
            ? DurationFormatter.formatNatural(
              job.completedAt!.difference(job.startedAt!),
            )
            : null;

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        success ? Icons.check_circle : Icons.error,
        color: success ? AppTheme.successColor : AppTheme.errorColor,
        size: 20,
      ),
      title: Text(
        job.request.operation.displayName,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        [
          job.request.studio.displayName,
          if (elapsed != null) elapsed,
          if (job.errorMessage != null) job.errorMessage!,
        ].join(' · '),
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDate(job.completedAt ?? job.createdAt),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
}

/// Small colored chip showing a [JobStatus].
class StatusChip extends StatelessWidget {
  final JobStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, String) _resolve(JobStatus s) {
    switch (s) {
      case JobStatus.completed:
        return (AppTheme.successColor, 'Done');
      case JobStatus.failed:
        return (AppTheme.errorColor, 'Failed');
      case JobStatus.cancelled:
        return (AppTheme.warningColor, 'Cancelled');
      case JobStatus.processing:
        return (AppTheme.primaryColor, 'Processing');
      case JobStatus.validating:
      case JobStatus.verifying:
        return (AppTheme.infoColor, s.displayName);
      case JobStatus.interrupted:
      case JobStatus.recoverable:
        return (AppTheme.warningColor, s.displayName);
      default:
        return (AppTheme.textMuted, s.displayName);
    }
  }
}
