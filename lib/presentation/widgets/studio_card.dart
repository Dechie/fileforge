import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/domain/enums/enums.dart';

/// A card representing a studio module on the home dashboard grid.
class StudioCard extends StatelessWidget {
  final StudioType studio;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isAvailable;

  const StudioCard({
    super.key,
    required this.studio,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.isAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  studio.displayName,
                  style: theme.textTheme.labelLarge,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isAvailable) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Unavailable',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
