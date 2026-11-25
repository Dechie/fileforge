import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';

/// Displays key-value pairs in a clean two-column table.
///
/// Used in the File Inspector and in info cards across studios.
class InfoTable extends StatelessWidget {
  /// Rows of (label, value) pairs. A `null` value renders as "—".
  final List<(String label, String? value)> rows;

  /// Whether to show dividers between rows.
  final bool showDividers;

  /// Optional highlight color for specific labels.
  final Map<String, Color> highlights;

  const InfoTable({
    super.key,
    required this.rows,
    this.showDividers = true,
    this.highlights = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    rows[i].$1,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: highlights[rows[i].$1] ?? AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2 ?? '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          rows[i].$2 != null
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDividers && i < rows.length - 1)
            const Divider(height: 1, indent: 4, endIndent: 4),
        ],
      ],
    );
  }
}
