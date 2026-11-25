import 'dart:convert';

import 'package:fileforge/domain/models/models.dart';

/// Reads page count, page size, encryption, and Info fields from qpdf JSON.
class QpdfMetadataParser {
  QpdfMetadataParser._();

  static PdfMetadata parse(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('qpdf JSON was not an object');
    }
    final root = Map<String, dynamic>.from(decoded);
    final body = _body(root);
    final objects = _objects(body);
    final pages = root['pages'] is List ? root['pages'] : body['pages'];

    var pageCount = pages is List ? pages.length : null;
    double? width;
    double? height;
    if (pages is List && pages.isNotEmpty) {
      final box = _mediaBox(_pageDictionary(pages.first, objects));
      if (box != null) {
        width = box.$1;
        height = box.$2;
      }
    }

    final trailer = _lookup(objects, 'trailer') ?? const <String, dynamic>{};
    final encrypted = _isEncrypted(root, trailer);
    final info = _resolve(objects, trailer['/Info']);
    if (pageCount == null || pageCount == 0) {
      pageCount = _pageCountFromCatalog(objects) ?? pageCount;
    }

    final properties = <String, String>{};
    info?.forEach((key, value) {
      if (value is String || value is num || value is bool) {
        properties[key] = '$value';
      }
    });

    return PdfMetadata(
      pageCount: pageCount,
      pageWidth: width,
      pageHeight: height,
      isEncrypted: encrypted,
      title: _string(info?['/Title']),
      author: _string(info?['/Author']),
      subject: _string(info?['/Subject']),
      creator: _string(info?['/Creator']),
      creationDate: _pdfDate(info?['/CreationDate']),
      modificationDate: _pdfDate(info?['/ModDate']),
      properties: properties,
    );
  }

  static Map<String, dynamic> _body(Map<String, dynamic> root) {
    final wrapped = root['qpdf'];
    if (wrapped is List && wrapped.length >= 2 && wrapped[1] is Map) {
      return Map<String, dynamic>.from(wrapped[1] as Map);
    }
    return root;
  }

  static Map<String, dynamic> _objects(Map<String, dynamic> body) {
    final objects = body['objects'];
    if (objects is Map) return Map<String, dynamic>.from(objects);
    if (body.keys.any((key) => key.startsWith('obj:') || key == 'trailer')) {
      return body;
    }
    return const {};
  }

  static Map<String, dynamic>? _lookup(
    Map<String, dynamic> objects,
    String key,
  ) {
    final direct = objects[key] ?? objects['obj:$key'];
    if (direct is! Map) return null;
    final map = Map<String, dynamic>.from(direct);
    final value = map['value'];
    if (value is Map) return Map<String, dynamic>.from(value);
    return map;
  }

  /// qpdf 12 puts page size on the page object. Older JSON puts it on the
  /// page summary itself.
  static Map<String, dynamic>? _pageDictionary(
    Object? page,
    Map<String, dynamic> objects,
  ) {
    final summary = page is Map ? Map<String, dynamic>.from(page) : null;
    if (summary != null && summary.containsKey('/MediaBox')) return summary;
    final resolved = _resolve(objects, summary?['object']);
    return resolved ?? summary;
  }

  static bool _isEncrypted(
    Map<String, dynamic> root,
    Map<String, dynamic> trailer,
  ) {
    final encrypt = root['encrypt'];
    if (encrypt is Map && encrypt['encrypted'] == true) return true;
    return trailer.containsKey('/Encrypt');
  }

  static Map<String, dynamic>? _resolve(
    Map<String, dynamic> objects,
    Object? ref,
  ) {
    if (ref is Map) return Map<String, dynamic>.from(ref);
    if (ref is! String) return null;
    final key = ref.startsWith('obj:') ? ref.substring(4) : ref;
    return _lookup(objects, key);
  }

  static (double, double)? _mediaBox(Object? page) {
    if (page is! Map) return null;
    final map = Map<String, dynamic>.from(page);
    final box = map['/MediaBox'] ?? map['MediaBox'];
    if (box is! List || box.length < 4) return null;
    final x0 = _double(box[0]);
    final y0 = _double(box[1]);
    final x1 = _double(box[2]);
    final y1 = _double(box[3]);
    if (x0 == null || y0 == null || x1 == null || y1 == null) return null;
    return (x1 - x0, y1 - y0);
  }

  static int? _pageCountFromCatalog(Map<String, dynamic> objects) {
    for (final value in objects.values) {
      if (value is! Map) continue;
      final raw = Map<String, dynamic>.from(value);
      final nested = raw['value'];
      final map = nested is Map ? Map<String, dynamic>.from(nested) : raw;
      if (map['/Type'] == '/Pages') {
        final count = map['/Count'];
        if (count is int) return count;
        if (count is num) return count.round();
      }
    }
    return null;
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty) return null;
    if (text.length >= 2 && text.startsWith('(') && text.endsWith(')')) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  static DateTime? _pdfDate(Object? value) {
    final text = _string(value);
    if (text == null) return null;
    final match = RegExp(
      r'D:(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?',
    ).firstMatch(text);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2) ?? '1'),
      int.parse(match.group(3) ?? '1'),
      int.parse(match.group(4) ?? '0'),
      int.parse(match.group(5) ?? '0'),
      int.parse(match.group(6) ?? '0'),
    );
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
