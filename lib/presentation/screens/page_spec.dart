/// Parse a page field such as `1,3,5-7` into page numbers.
///
/// Pages are 1-based. Ranges are inclusive. Throws [FormatException] when the
/// text is empty or a page number is below 1.
List<int> parsePageSpec(String text) {
  final pages = <int>[];
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Enter at least one page');
  }
  for (final part in trimmed.split(',')) {
    final piece = part.trim();
    if (piece.isEmpty) continue;
    if (piece.contains('-')) {
      final bits = piece.split('-');
      if (bits.length != 2) {
        throw FormatException('Invalid page range "$piece"');
      }
      final start = int.tryParse(bits[0].trim());
      final end = int.tryParse(bits[1].trim());
      if (start == null || end == null || start < 1 || end < start) {
        throw FormatException('Invalid page range "$piece"');
      }
      for (var page = start; page <= end; page++) {
        pages.add(page);
      }
    } else {
      final page = int.tryParse(piece);
      if (page == null || page < 1) {
        throw FormatException('Invalid page "$piece"');
      }
      pages.add(page);
    }
  }
  if (pages.isEmpty) {
    throw const FormatException('Enter at least one page');
  }
  return pages;
}
