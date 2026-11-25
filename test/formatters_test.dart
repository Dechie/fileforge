import 'package:fileforge/core/utils/duration_formatter.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileSizeFormatter', () {
    test('formats byte sizes', () {
      expect(FileSizeFormatter.format(0), '0 B');
      expect(FileSizeFormatter.format(-5), '0 B');
      expect(FileSizeFormatter.format(1536), '1.50 KB');
      expect(FileSizeFormatter.format(1024 * 1024, decimals: 0), '1 MB');
    });

    test('parses human-readable sizes', () {
      expect(
        FileSizeFormatter.parse('1.5 GB'),
        (1.5 * 1024 * 1024 * 1024).round(),
      );
      expect(FileSizeFormatter.parse('500MB'), 500 * 1024 * 1024);
      expect(FileSizeFormatter.parse('2 KB'), 2 * 1024);
      expect(FileSizeFormatter.parse('nope'), isNull);
    });
  });

  group('DurationFormatter', () {
    test('formats clock and natural text', () {
      expect(DurationFormatter.format(Duration.zero), '00:00');
      expect(DurationFormatter.format(const Duration(seconds: 90)), '01:30');
      expect(
        DurationFormatter.format(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '01:02:03',
      );
      expect(
        DurationFormatter.formatNatural(const Duration(seconds: 30)),
        '30s',
      );
      expect(
        DurationFormatter.formatNatural(
          const Duration(hours: 1, minutes: 23, seconds: 45),
        ),
        '1h 23m 45s',
      );
      expect(
        DurationFormatter.formatNatural(
          const Duration(minutes: 5, seconds: 12),
        ),
        '5m 12s',
      );
    });
  });
}
