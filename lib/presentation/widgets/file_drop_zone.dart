import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';

/// A dashed-border drop zone that invites the user to pick files.
///
/// Supports tap-to-pick and optional drag-and-drop (platform dependent).
class FileDropZone extends StatefulWidget {
  /// Callback when the user taps to pick files.
  final VoidCallback? onTap;

  /// Hint text shown inside the zone.
  final String hint;

  /// Icon shown above the hint.
  final IconData icon;

  /// Accepted MIME types for display purposes (the actual picker handles filtering).
  final List<String> acceptedTypes;

  /// Whether multiple files can be selected.
  final bool allowMultiple;

  /// Compact variant for tight layouts.
  final bool compact;

  const FileDropZone({
    super.key,
    this.onTap,
    this.hint = 'Drop files here or tap to select',
    this.icon = Icons.upload_file,
    this.acceptedTypes = const [],
    this.allowMultiple = true,
    this.compact = false,
  });

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 100.0 : 160.0;
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          decoration: BoxDecoration(
            color:
                _hovering
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? AppTheme.primaryColor : AppTheme.borderColor,
              width: _hovering ? 2 : 1,
            ),
          ),
          child: CustomPaint(
            painter: _hovering ? null : _DashedBorderPainter(),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: widget.compact ? 28 : 40,
                    color:
                        _hovering ? AppTheme.primaryColor : AppTheme.textMuted,
                  ),
                  SizedBox(height: widget.compact ? 6 : 12),
                  Text(
                    widget.hint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          _hovering
                              ? AppTheme.primaryColor
                              : AppTheme.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.acceptedTypes.isNotEmpty && !widget.compact) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.acceptedTypes.join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed border inside the drop zone when not hovering.
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppTheme.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    var distance = 0.0;
    while (distance < metrics.length) {
      final end = (distance + dashWidth).clamp(0.0, metrics.length);
      final extracted = metrics.extractPath(distance, end);
      canvas.drawPath(extracted, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
