import 'package:flutter/material.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/core/theme/app_theme.dart';

/// Maps [FileFormat] and [FileCategory] to a styled icon.
///
/// Used across all studio screens to visually identify file types.
class FormatIcon extends StatelessWidget {
  final FileFormat? format;
  final FileCategory? category;
  final double size;
  final Color? colorOverride;

  const FormatIcon({
    super.key,
    this.format,
    this.category,
    this.size = 24,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCategory =
        format?.category ?? category ?? FileCategory.unknown;
    final data = _resolve(effectiveCategory, format);
    return Icon(data.icon, size: size, color: colorOverride ?? data.color);
  }

  /// Returns a larger badge variant with a rounded background.
  static Widget badge({
    FileFormat? format,
    FileCategory? category,
    double size = 40,
  }) {
    final effectiveCategory =
        format?.category ?? category ?? FileCategory.unknown;
    final data = _resolve(effectiveCategory, format);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(data.icon, size: size * 0.55, color: data.color),
    );
  }

  static _IconData _resolve(FileCategory cat, FileFormat? fmt) {
    switch (cat) {
      case FileCategory.pdf:
        return _IconData(Icons.picture_as_pdf, AppTheme.pdfStudioColor);
      case FileCategory.document:
        return _IconData(Icons.description, AppTheme.documentStudioColor);
      case FileCategory.image:
        return _IconData(Icons.image, AppTheme.imageStudioColor);
      case FileCategory.video:
        return _IconData(Icons.videocam, AppTheme.videoStudioColor);
      case FileCategory.audio:
        return _IconData(Icons.audiotrack, AppTheme.audioStudioColor);
      case FileCategory.subtitle:
        return _IconData(Icons.subtitles, AppTheme.textSecondary);
      case FileCategory.unknown:
        return _IconData(Icons.insert_drive_file, AppTheme.textMuted);
    }
  }
}

class _IconData {
  final IconData icon;
  final Color color;
  const _IconData(this.icon, this.color);
}
