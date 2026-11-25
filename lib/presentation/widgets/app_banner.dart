import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';

/// Severity level for [AppBanner].
enum BannerSeverity { info, success, warning, error }

/// A horizontal banner for system messages, warnings, and dependency alerts.
///
/// Used for missing dependency notices, re-encoding warnings, platform
/// unavailability messages, etc.
class AppBanner extends StatelessWidget {
  final String message;
  final BannerSeverity severity;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onDismiss;
  final IconData? icon;

  const AppBanner({
    super.key,
    required this.message,
    this.severity = BannerSeverity.info,
    this.onAction,
    this.actionLabel,
    this.onDismiss,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (color, defaultIcon) = _resolveStyle();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon ?? defaultIcon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
            ),
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: AppTheme.textMuted,
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }

  (Color, IconData) _resolveStyle() {
    switch (severity) {
      case BannerSeverity.info:
        return (AppTheme.infoColor, Icons.info_outline);
      case BannerSeverity.success:
        return (AppTheme.successColor, Icons.check_circle_outline);
      case BannerSeverity.warning:
        return (AppTheme.warningColor, Icons.warning_amber_rounded);
      case BannerSeverity.error:
        return (AppTheme.errorColor, Icons.error_outline);
    }
  }
}
