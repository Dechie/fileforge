import 'package:fileforge/presentation/screens/page_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses pages and inclusive ranges', () {
    expect(parsePageSpec('1,3,5-7'), [1, 3, 5, 6, 7]);
  });

  test('rejects an empty page list', () {
    expect(() => parsePageSpec('  '), throwsFormatException);
  });

  test('rejects a page below 1', () {
    expect(() => parsePageSpec('0'), throwsFormatException);
  });

  test('rejects a backwards range', () {
    expect(() => parsePageSpec('2-1'), throwsFormatException);
  });
}
