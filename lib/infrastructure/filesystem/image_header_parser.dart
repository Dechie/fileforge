import 'dart:convert';
import 'dart:typed_data';

import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';

/// Reads image metadata from file headers without an image engine.
class ImageHeaderParser {
  ImageHeaderParser._();

  static ImageMetadata parse(Uint8List bytes, FileFormat format) {
    switch (format) {
      case FileFormat.png:
        return _parsePng(bytes);
      case FileFormat.jpg:
        return _parseJpeg(bytes);
      case FileFormat.webpImage:
        return _parseWebp(bytes);
      case FileFormat.heic:
        return _parseHeic(bytes);
      default:
        return const ImageMetadata();
    }
  }

  static ImageMetadata _parsePng(Uint8List bytes) {
    if (bytes.length < 24) return const ImageMetadata();
    var offset = 8;
    int? width;
    int? height;
    var hasTransparency = false;
    var animated = false;
    int? frames;
    String? profile;

    while (offset + 12 <= bytes.length) {
      final length = _u32be(bytes, offset);
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
      final dataStart = offset + 8;
      if (length < 0 || dataStart + length > bytes.length) break;
      if (type == 'IHDR' && length >= 10) {
        width = _u32be(bytes, dataStart);
        height = _u32be(bytes, dataStart + 4);
        final colorType = bytes[dataStart + 9];
        if (colorType == 4 || colorType == 6) hasTransparency = true;
      } else if (type == 'tRNS') {
        hasTransparency = true;
      } else if (type == 'acTL' && length >= 4) {
        animated = true;
        frames = _u32be(bytes, dataStart);
      } else if (type == 'iCCP' && length > 0) {
        final end = bytes.indexOf(0, dataStart);
        if (end > dataStart && end < dataStart + length) {
          profile = latin1.decode(bytes.sublist(dataStart, end));
        }
      } else if (type == 'IEND') {
        break;
      }
      offset = dataStart + length + 4;
    }

    return ImageMetadata(
      width: width,
      height: height,
      colorProfile: profile,
      hasTransparency: hasTransparency,
      isAnimated: animated,
      frameCount: frames,
    );
  }

  static ImageMetadata _parseJpeg(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return const ImageMetadata();
    }
    var offset = 2;
    int? width;
    int? height;
    int? orientation;
    var hasGps = false;

    while (offset + 4 < bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }
      while (offset < bytes.length && bytes[offset] == 0xFF) {
        offset++;
      }
      if (offset >= bytes.length) break;
      final marker = bytes[offset++];
      if (marker == 0xD9 || marker == 0xDA) break;
      if (marker >= 0xD0 && marker <= 0xD9) continue;
      if (offset + 2 > bytes.length) break;
      final length = (bytes[offset] << 8) | bytes[offset + 1];
      if (length < 2 || offset + length > bytes.length) break;
      final segment = bytes.sublist(offset + 2, offset + length);

      final isSof =
          (marker >= 0xC0 && marker <= 0xC3) ||
          (marker >= 0xC5 && marker <= 0xC7) ||
          (marker >= 0xC9 && marker <= 0xCB) ||
          (marker >= 0xCD && marker <= 0xCF);
      if (isSof && segment.length >= 5) {
        height = (segment[1] << 8) | segment[2];
        width = (segment[3] << 8) | segment[4];
      } else if (marker == 0xE1) {
        final exif = _parseExif(segment);
        orientation ??= exif.orientation;
        hasGps = hasGps || exif.hasGps;
      }
      offset += length;
    }

    return ImageMetadata(
      width: width,
      height: height,
      orientation: orientation,
      hasGpsData: hasGps,
    );
  }

  static ImageMetadata _parseWebp(Uint8List bytes) {
    if (bytes.length < 12) return const ImageMetadata();
    var offset = 12;
    int? width;
    int? height;
    var hasTransparency = false;
    var animated = false;
    String? profile;
    int? orientation;
    var hasGps = false;

    while (offset + 8 <= bytes.length) {
      final type = latin1.decode(bytes.sublist(offset, offset + 4));
      final size = _u32le(bytes, offset + 4);
      final data = offset + 8;
      if (size < 0 || data + size > bytes.length) break;

      if (type == 'VP8X' && size >= 10) {
        final flags = bytes[data];
        animated = flags & 0x02 != 0;
        hasTransparency = flags & 0x10 != 0;
        if (flags & 0x20 != 0) profile = 'ICC';
        width =
            1 +
            (bytes[data + 4] |
                (bytes[data + 5] << 8) |
                (bytes[data + 6] << 16));
        height =
            1 +
            (bytes[data + 7] |
                (bytes[data + 8] << 8) |
                (bytes[data + 9] << 16));
      } else if (type == 'VP8 ' && width == null && size >= 10) {
        if (bytes[data + 3] == 0x9D &&
            bytes[data + 4] == 0x01 &&
            bytes[data + 5] == 0x2A) {
          width = (bytes[data + 6] | (bytes[data + 7] << 8)) & 0x3FFF;
          height = (bytes[data + 8] | (bytes[data + 9] << 8)) & 0x3FFF;
        }
      } else if (type == 'VP8L' &&
          width == null &&
          size >= 5 &&
          bytes[data] == 0x2F) {
        final b0 = bytes[data + 1];
        final b1 = bytes[data + 2];
        final b2 = bytes[data + 3];
        final b3 = bytes[data + 4];
        width = 1 + (b0 | ((b1 & 0x3F) << 8));
        height = 1 + (((b1 & 0xC0) >> 6) | (b2 << 2) | ((b3 & 0x0F) << 10));
        if (b3 & 0x10 != 0) hasTransparency = true;
      } else if (type == 'ALPH') {
        hasTransparency = true;
      } else if (type == 'ANIM') {
        animated = true;
      } else if (type == 'ICCP') {
        profile ??= 'ICC';
      } else if (type == 'EXIF') {
        final exif = _parseExif(bytes.sublist(data, data + size));
        orientation ??= exif.orientation;
        hasGps = hasGps || exif.hasGps;
      }

      offset = data + size + (size.isOdd ? 1 : 0);
    }

    return ImageMetadata(
      width: width,
      height: height,
      colorProfile: profile,
      hasTransparency: hasTransparency,
      orientation: orientation,
      isAnimated: animated,
      hasGpsData: hasGps,
    );
  }

  static ImageMetadata _parseHeic(Uint8List bytes) {
    int? width;
    int? height;
    final ispe = latin1.encode('ispe');
    for (var i = 0; i + 16 <= bytes.length; i++) {
      if (bytes[i] == ispe[0] &&
          bytes[i + 1] == ispe[1] &&
          bytes[i + 2] == ispe[2] &&
          bytes[i + 3] == ispe[3]) {
        width = _u32be(bytes, i + 8);
        height = _u32be(bytes, i + 12);
        if (width > 0 && height > 0 && width < 100000 && height < 100000) {
          break;
        }
        width = null;
        height = null;
      }
    }
    final exif = _parseExif(bytes);
    return ImageMetadata(
      width: width,
      height: height,
      orientation: exif.orientation,
      hasGpsData: exif.hasGps,
    );
  }

  static _ExifSummary _parseExif(Uint8List data) {
    var tiff = data;
    if (data.length > 6 &&
        data[0] == 0x45 &&
        data[1] == 0x78 &&
        data[2] == 0x69 &&
        data[3] == 0x66 &&
        data[4] == 0 &&
        data[5] == 0) {
      tiff = data.sublist(6);
    } else {
      final marker = latin1.encode('Exif\x00\x00');
      for (var i = 0; i + marker.length + 8 < data.length; i++) {
        var found = true;
        for (var j = 0; j < marker.length; j++) {
          if (data[i + j] != marker[j]) {
            found = false;
            break;
          }
        }
        if (found) {
          tiff = data.sublist(i + marker.length);
          break;
        }
      }
    }
    if (tiff.length < 8) return const _ExifSummary();
    final little = tiff[0] == 0x49 && tiff[1] == 0x49;
    final big = tiff[0] == 0x4D && tiff[1] == 0x4D;
    if (!little && !big) return const _ExifSummary();

    int u16(int offset) {
      if (offset + 2 > tiff.length) return 0;
      return little
          ? tiff[offset] | (tiff[offset + 1] << 8)
          : (tiff[offset] << 8) | tiff[offset + 1];
    }

    int u32(int offset) {
      if (offset + 4 > tiff.length) return 0;
      return little
          ? tiff[offset] |
              (tiff[offset + 1] << 8) |
              (tiff[offset + 2] << 16) |
              (tiff[offset + 3] << 24)
          : (tiff[offset] << 24) |
              (tiff[offset + 1] << 16) |
              (tiff[offset + 2] << 8) |
              tiff[offset + 3];
    }

    if (u16(2) != 42) return const _ExifSummary();
    final ifd = u32(4);
    if (ifd + 2 > tiff.length) return const _ExifSummary();
    final count = u16(ifd);
    int? orientation;
    var hasGps = false;
    for (var i = 0; i < count; i++) {
      final entry = ifd + 2 + i * 12;
      if (entry + 12 > tiff.length) break;
      final tag = u16(entry);
      final type = u16(entry + 2);
      if (tag == 0x0112 && type == 3) {
        orientation = u16(entry + 8);
      } else if (tag == 0x8825) {
        hasGps = true;
      }
    }
    return _ExifSummary(orientation: orientation, hasGps: hasGps);
  }

  static int _u32be(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static int _u32le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

class _ExifSummary {
  final int? orientation;
  final bool hasGps;

  const _ExifSummary({this.orientation, this.hasGps = false});
}
