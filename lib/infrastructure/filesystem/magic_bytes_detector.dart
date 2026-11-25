import 'dart:convert';
import 'dart:typed_data';

import 'package:fileforge/domain/enums/enums.dart';

/// Content-based file format detection using magic bytes.
///
/// Does NOT rely on file extensions (spec §4.2).
class MagicBytesDetector {
  MagicBytesDetector._();

  /// Minimum bytes needed for reliable detection.
  static const int minBytes = 12;

  static const Set<String> _heifBrands = {
    'heic',
    'heix',
    'hevc',
    'hevx',
    'heim',
    'heis',
    'heif',
    'mif1',
    'msf1',
  };

  /// Detect file format from the leading bytes of a file.
  static FileFormat? detect(Uint8List bytes) {
    if (bytes.length < 4) return null;

    // PDF: %PDF
    if (_matches(bytes, [0x25, 0x50, 0x44, 0x46])) return FileFormat.pdf;

    // PNG: 89 50 4E 47
    if (_matches(bytes, [0x89, 0x50, 0x4E, 0x47])) return FileFormat.png;

    // JPEG: FF D8 FF
    if (_matches(bytes, [0xFF, 0xD8, 0xFF])) return FileFormat.jpg;

    // RIFF containers: WebP and WAV share the RIFF prefix.
    if (bytes.length >= 12 && _matches(bytes, [0x52, 0x49, 0x46, 0x46])) {
      if (bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return FileFormat.webpImage;
      }
      if (bytes[8] == 0x57 &&
          bytes[9] == 0x41 &&
          bytes[10] == 0x56 &&
          bytes[11] == 0x45) {
        return FileFormat.wav;
      }
    }

    // FLAC: fLaC
    if (_matches(bytes, [0x66, 0x4C, 0x61, 0x43])) return FileFormat.flac;

    // Ogg container. Opus lives inside Ogg and is identified by OpusHead.
    if (_matches(bytes, [0x4F, 0x67, 0x67, 0x53])) {
      final head = latin1.decode(
        bytes.length > 64 ? bytes.sublist(0, 64) : bytes,
      );
      if (head.contains('OpusHead')) return FileFormat.opus;
      return FileFormat.ogg;
    }

    // ISO Base Media: size + 'ftyp' + brand.
    if (bytes.length >= 8 && latin1.decode(bytes.sublist(4, 8)) == 'ftyp') {
      if (bytes.length < 12) return FileFormat.mp4;
      final brand = latin1.decode(bytes.sublist(8, 12));
      if (brand == 'M4A ' || brand == 'M4B ') return FileFormat.m4a;
      if (brand == 'qt  ') return FileFormat.mov;
      if (brand == 'avif' || brand == 'avis') return null;
      if (_heifBrands.contains(brand)) return FileFormat.heic;
      return FileFormat.mp4;
    }

    // Matroska / WebM: EBML header. The doctype string distinguishes them.
    if (_matches(bytes, [0x1A, 0x45, 0xDF, 0xA3])) {
      final window = bytes.length > 256 ? bytes.sublist(0, 256) : bytes;
      if (latin1.decode(window).contains('webm')) return FileFormat.webm;
      return FileFormat.mkv;
    }

    // MP3 with an ID3 tag.
    if (_matches(bytes, [0x49, 0x44, 0x33])) return FileFormat.mp3;

    // ADTS AAC shares the 0xFF sync prefix with MP3, but its layer bits are 00.
    if (_isAdts(bytes)) return FileFormat.aac;
    if (_isMp3Frame(bytes)) return FileFormat.mp3;

    // ZIP-based formats (DOCX, PPTX, XLSX, ODT, ODS, ODP).
    // The caller inspects archive entries to tell them apart.
    if (_matches(bytes, [0x50, 0x4B, 0x03, 0x04])) return null;

    return null;
  }

  static bool _isAdts(Uint8List bytes) {
    if (bytes.length < 2 || bytes[0] != 0xFF) return false;
    if ((bytes[1] & 0xF0) != 0xF0) return false;
    final layer = (bytes[1] & 0x06) >> 1;
    return layer == 0;
  }

  static bool _isMp3Frame(Uint8List bytes) {
    if (bytes.length < 2 || bytes[0] != 0xFF) return false;
    if ((bytes[1] & 0xE0) != 0xE0) return false;
    final layer = (bytes[1] & 0x06) >> 1;
    return layer != 0;
  }

  static bool _matches(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }
}
