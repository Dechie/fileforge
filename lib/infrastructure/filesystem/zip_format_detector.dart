import 'dart:convert';
import 'dart:typed_data';

import 'package:fileforge/domain/enums/enums.dart';

/// Identifies Office documents that share the ZIP magic bytes.
///
/// OOXML is recognized by well-known entry names. ODF is recognized by the
/// uncompressed `mimetype` entry stored at the start of the package.
class ZipFormatDetector {
  ZipFormatDetector._();

  static FileFormat? detect(Uint8List bytes) {
    if (bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      return null;
    }

    final fromHeaders = _walkLocalHeaders(bytes);
    if (fromHeaders != null) return fromHeaders;
    return _scanAscii(bytes);
  }

  static FileFormat? _walkLocalHeaders(Uint8List bytes) {
    var offset = 0;
    var scanned = 0;
    while (offset + 30 <= bytes.length && scanned < 32) {
      if (!_isLocalHeader(bytes, offset)) break;
      final flags = _u16(bytes, offset + 6);
      final method = _u16(bytes, offset + 8);
      final compSize = _u32(bytes, offset + 18);
      final nameLen = _u16(bytes, offset + 26);
      final extraLen = _u16(bytes, offset + 28);
      final nameStart = offset + 30;
      if (nameStart + nameLen > bytes.length) break;
      final name = utf8.decode(
        bytes.sublist(nameStart, nameStart + nameLen),
        allowMalformed: true,
      );
      final dataStart = nameStart + nameLen + extraLen;

      if (name == 'mimetype' && method == 0 && (flags & 0x08) == 0) {
        if (dataStart + compSize <= bytes.length) {
          final mime = latin1.decode(
            bytes.sublist(dataStart, dataStart + compSize),
          );
          final format = _fromOdfMime(mime);
          if (format != null) return format;
        }
      }

      final fromName = _fromEntryName(name);
      if (fromName != null) return fromName;

      final dataDescriptor = (flags & 0x08) != 0;
      if (!dataDescriptor && dataStart + compSize <= bytes.length) {
        offset = dataStart + compSize;
      } else {
        final next = _indexOfLocal(bytes, dataStart);
        if (next < 0) break;
        offset = next;
      }
      scanned++;
    }
    return null;
  }

  static FileFormat? _scanAscii(Uint8List bytes) {
    final text = latin1.decode(bytes);
    if (text.contains('word/document.xml')) return FileFormat.docx;
    if (text.contains('ppt/presentation.xml')) return FileFormat.pptx;
    if (text.contains('xl/workbook.xml')) return FileFormat.xlsx;
    if (text.contains('application/vnd.oasis.opendocument.text')) {
      return FileFormat.odt;
    }
    if (text.contains('application/vnd.oasis.opendocument.spreadsheet')) {
      return FileFormat.ods;
    }
    if (text.contains('application/vnd.oasis.opendocument.presentation')) {
      return FileFormat.odp;
    }
    return null;
  }

  static FileFormat? _fromEntryName(String name) {
    if (name == 'word/document.xml') return FileFormat.docx;
    if (name == 'ppt/presentation.xml') return FileFormat.pptx;
    if (name == 'xl/workbook.xml') return FileFormat.xlsx;
    return null;
  }

  static FileFormat? _fromOdfMime(String mime) {
    final trimmed = mime.trim();
    switch (trimmed) {
      case 'application/vnd.oasis.opendocument.text':
        return FileFormat.odt;
      case 'application/vnd.oasis.opendocument.spreadsheet':
        return FileFormat.ods;
      case 'application/vnd.oasis.opendocument.presentation':
        return FileFormat.odp;
      default:
        return null;
    }
  }

  static bool _isLocalHeader(Uint8List bytes, int offset) {
    return bytes[offset] == 0x50 &&
        bytes[offset + 1] == 0x4B &&
        bytes[offset + 2] == 0x03 &&
        bytes[offset + 3] == 0x04;
  }

  static int _indexOfLocal(Uint8List bytes, int from) {
    for (var i = from; i + 4 <= bytes.length; i++) {
      if (_isLocalHeader(bytes, i)) return i;
    }
    return -1;
  }

  static int _u16(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _u32(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
