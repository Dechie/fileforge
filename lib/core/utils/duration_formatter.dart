/// Formats Duration values into human-readable strings.
class DurationFormatter {
  DurationFormatter._();

  /// Formats a [Duration] as `HH:MM:SS` or `MM:SS` for durations under 1 hour.
  static String format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats a [Duration] as a natural language string.
  ///
  /// Example: `"1h 23m 45s"`, `"5m 12s"`, `"30s"`
  static String formatNatural(Duration duration) {
    final parts = <String>[];
    if (duration.inHours > 0) parts.add('${duration.inHours}h');
    if (duration.inMinutes.remainder(60) > 0) {
      parts.add('${duration.inMinutes.remainder(60)}m');
    }
    final secs = duration.inSeconds.remainder(60);
    if (secs > 0 || parts.isEmpty) parts.add('${secs}s');
    return parts.join(' ');
  }
}
