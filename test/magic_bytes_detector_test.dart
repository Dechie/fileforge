import 'dart:convert';
import 'dart:typed_data';

import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/infrastructure/filesystem/magic_bytes_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List bytes(List<int> data) => Uint8List.fromList(data);

  Uint8List ftyp(String brand) {
    return bytes([
      0,
      0,
      0,
      24,
      ...utf8.encode('ftyp'),
      ...utf8.encode(brand),
      0,
      0,
      0,
      0,
    ]);
  }

  test('recognizes the formats named by their signatures', () {
    expect(
      MagicBytesDetector.detect(bytes([0x25, 0x50, 0x44, 0x46])),
      FileFormat.pdf,
    );
    expect(
      MagicBytesDetector.detect(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])),
      FileFormat.png,
    );
    expect(
      MagicBytesDetector.detect(bytes([0xFF, 0xD8, 0xFF, 0xE0])),
      FileFormat.jpg,
    );
    expect(
      MagicBytesDetector.detect(bytes([0x66, 0x4C, 0x61, 0x43])),
      FileFormat.flac,
    );
    expect(
      MagicBytesDetector.detect(bytes([0x49, 0x44, 0x33, 0x04])),
      FileFormat.mp3,
    );
    expect(
      MagicBytesDetector.detect(bytes([0xFF, 0xFB, 0x90, 0x00])),
      FileFormat.mp3,
    );
    expect(
      MagicBytesDetector.detect(bytes([0xFF, 0xF1, 0x50, 0x80])),
      FileFormat.aac,
    );
  });

  test('distinguishes RIFF WebP from WAV', () {
    expect(
      MagicBytesDetector.detect(
        bytes([
          0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, // RIFF....
          0x57, 0x45, 0x42, 0x50, // WEBP
        ]),
      ),
      FileFormat.webpImage,
    );
    expect(
      MagicBytesDetector.detect(
        bytes([
          0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0,
          0x57, 0x41, 0x56, 0x45, // WAVE
        ]),
      ),
      FileFormat.wav,
    );
  });

  test('uses the ftyp brand instead of the file name', () {
    expect(ftyp('heic').length, greaterThan(8));
    expect(MagicBytesDetector.detect(ftyp('heic')), FileFormat.heic);
    expect(MagicBytesDetector.detect(ftyp('mif1')), FileFormat.heic);
    expect(MagicBytesDetector.detect(ftyp('M4A ')), FileFormat.m4a);
    expect(MagicBytesDetector.detect(ftyp('qt  ')), FileFormat.mov);
    expect(MagicBytesDetector.detect(ftyp('isom')), FileFormat.mp4);
    expect(MagicBytesDetector.detect(ftyp('avif')), isNull);
  });

  test('separates WebM, MKV, Opus, and Ogg', () {
    expect(
      MagicBytesDetector.detect(
        bytes([0x1A, 0x45, 0xDF, 0xA3, ...utf8.encode('webm')]),
      ),
      FileFormat.webm,
    );
    expect(
      MagicBytesDetector.detect(
        bytes([0x1A, 0x45, 0xDF, 0xA3, ...utf8.encode('matroska')]),
      ),
      FileFormat.mkv,
    );
    expect(
      MagicBytesDetector.detect(
        bytes([...utf8.encode('OggS'), 0, 0, ...utf8.encode('OpusHead')]),
      ),
      FileFormat.opus,
    );
    expect(
      MagicBytesDetector.detect(
        bytes([...utf8.encode('OggS'), ...utf8.encode('vorbis')]),
      ),
      FileFormat.ogg,
    );
  });

  test('does not treat a ZIP package or random bytes as a known format', () {
    expect(
      MagicBytesDetector.detect(bytes([0x50, 0x4B, 0x03, 0x04, 0, 0])),
      isNull,
    );
    expect(MagicBytesDetector.detect(bytes([1, 2, 3, 4, 5, 6, 7, 8])), isNull);
    expect(MagicBytesDetector.detect(bytes([0x25, 0x50])), isNull);
  });
}
