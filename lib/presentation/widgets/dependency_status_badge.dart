import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';

/// A colored chip showing a dependency or module availability status.
///
/// Variants: installed, missing, warning, checking.
class DependencyStatusBadge extends StatelessWidget {
  final String label;
  final DependencyBadgeVariant variant;
  final double fontSize;

  const DependencyStatusBadge({
    super.key,
    required this.label,
    required this.variant,
    this.fontSize = 11,
  });

  const DependencyStatusBadge.installed({
    super.key,
    this.label = 'Installed',
    this.fontSize = 11,
  }) : variant = DependencyBadgeVariant.installed;

  const DependencyStatusBadge.missing({
    super.key,
    this.label = 'Missing',
    this.fontSize = 11,
  }) : variant = DependencyBadgeVariant.missing;

  const DependencyStatusBadge.warning({
    super.key,
    required this.label,
    this.fontSize = 11,
  }) : variant = DependencyBadgeVariant.warning;

  const DependencyStatusBadge.checking({
    super.key,
    this.label = 'Checking…',
    this.fontSize = 11,
  }) : variant = DependencyBadgeVariant.checking;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _resolve() {
    switch (variant) {
      case DependencyBadgeVariant.installed:
        return (AppTheme.successColor, Icons.check_circle);
      case DependencyBadgeVariant.missing:
        return (AppTheme.errorColor, Icons.cancel);
      case DependencyBadgeVariant.warning:
        return (AppTheme.warningColor, Icons.warning_amber_rounded);
      case DependencyBadgeVariant.checking:
        return (AppTheme.textMuted, Icons.hourglass_top);
    }
  }
}

enum DependencyBadgeVariant { installed, missing, warning, checking }
