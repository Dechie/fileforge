import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';

/// An empty-state placeholder shown when a list or section has no content.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight =
            constraints.maxHeight.isFinite && constraints.maxHeight < 280;
        final content = Padding(
          padding: EdgeInsets.symmetric(
            vertical: tight ? 16 : 40,
            horizontal: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: tight ? 40 : 56,
                color: AppTheme.textMuted.withValues(alpha: 0.5),
              ),
              SizedBox(height: tight ? 8 : 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                SizedBox(height: tight ? 4 : 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (action != null) ...[
                SizedBox(height: tight ? 12 : 20),
                action!,
              ],
            ],
          ),
        );
        if (!tight) return Center(child: content);
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 480.0;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
