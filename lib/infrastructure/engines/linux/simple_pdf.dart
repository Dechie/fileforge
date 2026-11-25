import 'dart:convert';
import 'dart:typed_data';

import 'package:fileforge/core/errors/app_exceptions.dart';

/// Builds a text-only PDF for qpdf overlay stamps.
///
/// qpdf can impose pages, but it does not draw watermark text or visible
/// page numbers itself. This writer uses the standard Helvetica font so the
/// result needs no embedded font.
class SimplePdf {
  SimplePdf._();

  static Uint8List pages({
    required List<String> texts,
    double width = 612,
    double height = 792,
    double fontSize = 24,
    bool alignBottom = false,
  }) {
    if (texts.isEmpty) {
      throw const FileValidationException('PDF needs at least one page');
    }
    final objects = <int, String>{};
    final pageNumbers = <int>[];
    final contentNumbers = <int>[];
    var next = 4;
    for (var i = 0; i < texts.length; i++) {
      pageNumbers.add(next);
      contentNumbers.add(next + 1);
      next += 2;
    }

    final kids = pageNumbers.map((number) => '$number 0 R').join(' ');
    objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
    objects[2] = '<< /Type /Pages /Kids [$kids] /Count ${texts.length} >>';
    objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';

    final boxWidth = width.toStringAsFixed(2);
    final boxHeight = height.toStringAsFixed(2);
    for (var i = 0; i < texts.length; i++) {
      objects[pageNumbers[i]] =
          '<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 $boxWidth $boxHeight] '
          '/Contents ${contentNumbers[i]} 0 R '
          '/Resources << /Font << /F1 3 0 R >> >> >>';
      objects[contentNumbers[i]] = _content(
        texts[i],
        width: width,
        height: height,
        fontSize: fontSize,
        alignBottom: alignBottom,
      );
    }
    return _serialize(objects);
  }

  static String _content(
    String text, {
    required double width,
    required double height,
    required double fontSize,
    required bool alignBottom,
  }) {
    final safe = _pdfText(text);
    final estimated = fontSize * 0.5 * safe.length;
    final x = ((width - estimated) / 2).clamp(36.0, width - 36);
    final y = alignBottom ? 36.0 : height / 2;
    final stream =
        'BT /F1 ${fontSize.toStringAsFixed(2)} Tf 0.35 g '
        '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td ($safe) Tj ET';
    final length = latin1.encode(stream).length;
    return '<< /Length $length >>\nstream\n$stream\nendstream';
  }

  static String _pdfText(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final code = rune > 255 ? 0x3F : rune;
      if (code == 0x5C || code == 0x28 || code == 0x29) buffer.write('\\');
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  static Uint8List _serialize(Map<int, String> objects) {
    final ids = objects.keys.toList()..sort();
    final builder = BytesBuilder(copy: false);
    void add(String value) => builder.add(latin1.encode(value));

    add('%PDF-1.4\n');
    final offsets = List<int>.filled(ids.last + 1, 0);
    for (final id in ids) {
      offsets[id] = builder.length;
      add('$id 0 obj\n${objects[id]}\nendobj\n');
    }
    final xref = builder.length;
    final size = ids.last + 1;
    add('xref\n');
    add('0 $size\n');
    add('0000000000 65535 f \n');
    for (var i = 1; i < size; i++) {
      add('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
    }
    add('trailer\n');
    add('<< /Size $size /Root 1 0 R >>\n');
    add('startxref\n');
    add('$xref\n');
    add('%%EOF\n');
    return builder.toBytes();
  }
}
