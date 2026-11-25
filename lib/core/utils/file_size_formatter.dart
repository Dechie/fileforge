import 'dart:math';

/// Formats byte sizes into human-readable strings.
class FileSizeFormatter {
  FileSizeFormatter._();

  static const List<String> _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// Formats [bytes] into a human-readable size string.
  ///
  /// Example: `format(1536)` → `"1.50 KB"`
  static String format(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    final i = (log(bytes) / log(1024)).floor().clamp(0, _units.length - 1);
    final size = bytes / pow(1024, i);
    return '${size.toStringAsFixed(decimals)} ${_units[i]}';
  }

  /// Parses a human-readable size string back into bytes.
  ///
  /// Supports formats like `"1.5 GB"`, `"500MB"`, `"2 KB"`.
  static int? parse(String sizeStr) {
    final match = RegExp(
      r'^([\d.]+)\s*(B|KB|MB|GB|TB)$',
      caseSensitive: false,
    ).firstMatch(sizeStr.trim());
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    final unit = match.group(2)!.toUpperCase();
    final index = _units.indexOf(unit);
    if (index < 0) return null;
    return (value * pow(1024, index)).round();
  }
}
