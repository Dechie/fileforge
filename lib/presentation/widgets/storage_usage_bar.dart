import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';

/// A visual bar + breakdown of storage usage.
///
/// Shows total/free/used with colored segments for temp, output, and cache.
class StorageUsageBar extends StatelessWidget {
  final int totalBytes;
  final int freeBytes;
  final int tempBytes;
  final int outputBytes;
  final int cacheBytes;

  const StorageUsageBar({
    super.key,
    required this.totalBytes,
    required this.freeBytes,
    this.tempBytes = 0,
    this.outputBytes = 0,
    this.cacheBytes = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usedBytes = totalBytes - freeBytes;
    final fraction = totalBytes > 0 ? usedBytes / totalBytes : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation(
                fraction > 0.9 ? AppTheme.errorColor : AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Labels row
        Row(
          children: [
            Text(
              '${FileSizeFormatter.format(usedBytes)} used',
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              '${FileSizeFormatter.format(freeBytes)} free of ${FileSizeFormatter.format(totalBytes)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Breakdown chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _UsageChip(
              label: 'Temp',
              bytes: tempBytes,
              color: AppTheme.warningColor,
            ),
            _UsageChip(
              label: 'Output',
              bytes: outputBytes,
              color: AppTheme.successColor,
            ),
            _UsageChip(
              label: 'Cache',
              bytes: cacheBytes,
              color: AppTheme.infoColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageChip extends StatelessWidget {
  final String label;
  final int bytes;
  final Color color;

  const _UsageChip({
    required this.label,
    required this.bytes,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ${FileSizeFormatter.format(bytes)}',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
