import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';
import 'package:fileforge/domain/models/file_reference.dart';
import 'package:fileforge/presentation/widgets/format_icon.dart';

/// A list tile displaying a file with its format icon, name, and size.
///
/// Used in file selection lists across all studios.
class FileTile extends StatelessWidget {
  final FileReference file;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final Widget? trailing;
  final bool showSize;
  final bool dense;

  /// Replaces the generated format-and-size subtitle when set.
  final String? subtitleText;

  const FileTile({
    super.key,
    required this.file,
    this.onTap,
    this.onRemove,
    this.trailing,
    this.showSize = true,
    this.dense = false,
    this.subtitleText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: FormatIcon.badge(format: file.detectedFormat),
      title: Text(
        file.displayName,
        style: theme.textTheme.bodyLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          subtitleText == null
              ? _buildSubtitle(theme)
              : Text(
                subtitleText!,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      trailing: trailing ?? _buildTrailing(),
      onTap: onTap,
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    if (file.detectedFormat != null) {
      parts.add(file.detectedFormat!.displayName);
    }
    if (showSize && file.sizeBytes != null) {
      parts.add(FileSizeFormatter.format(file.sizeBytes!));
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '), style: theme.textTheme.bodySmall);
  }

  Widget? _buildTrailing() {
    if (onRemove == null) return null;
    return IconButton(
      icon: const Icon(Icons.close, size: 18),
      color: AppTheme.textMuted,
      onPressed: onRemove,
      tooltip: 'Remove',
    );
  }
}
