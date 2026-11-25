import 'package:flutter/material.dart';
import 'package:fileforge/core/utils/duration_formatter.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:path/path.dart' as p;

/// Whether the file name extension agrees with the detected format.
bool extensionMatches(FileReference file) {
  final ext = p.extension(file.displayName).replaceFirst('.', '').toLowerCase();
  final format = file.detectedFormat;
  if (format == null || ext.isEmpty) return false;
  return format.extensions.contains(ext);
}

String formatBitrate(int? bitsPerSecond) {
  if (bitsPerSecond == null || bitsPerSecond <= 0) return '—';
  if (bitsPerSecond >= 1000000) {
    return '${(bitsPerSecond / 1000000).toStringAsFixed(1)} Mbps';
  }
  return '${(bitsPerSecond / 1000).round()} kbps';
}

String formatResolution(int? width, int? height) {
  if (width == null || height == null) return '—';
  return '$width×$height';
}

String formatFps(double? fps) {
  if (fps == null || fps <= 0) return '—';
  if (fps.truncateToDouble() == fps) return '${fps.toStringAsFixed(0)} fps';
  return '${fps.toStringAsFixed(2)} fps';
}

String formatDuration(Duration? duration) {
  if (duration == null) return '—';
  return DurationFormatter.format(duration);
}

String yesNo(bool value) => value ? 'Yes' : 'No';

String formatShortDate(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  return '${date.month}/${date.day}';
}

/// A wrapping row of labeled values used on the media info cards.
class StatWrap extends StatelessWidget {
  const StatWrap({super.key, required this.stats});

  final List<(String label, String value)> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        for (final stat in stats)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stat.$1, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(stat.$2, style: theme.textTheme.bodyLarge),
            ],
          ),
      ],
    );
  }
}
