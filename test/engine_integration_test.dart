import 'dart:io';

import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_engine.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_image.dart';
import 'package:fileforge/infrastructure/engines/linux/qpdf_engine.dart';
import 'package:fileforge/infrastructure/engines/linux/simple_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ffmpeg inspects, trims, and converts a generated wav', () async {
    if (!await _has('ffmpeg') || !await _has('ffprobe')) {
      markTestSkipped('ffmpeg is not installed');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('fileforge-ffmpeg-');
    try {
      final source = File('${dir.path}/tone.wav');
      final made = await Process.run('ffmpeg', [
        '-y',
        '-hide_banner',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=1',
        '-c:a',
        'pcm_s16le',
        source.path,
      ]);
      expect(made.exitCode, 0, reason: made.stderr.toString());

      final engine = FfmpegAudioEngine();
      final input = FileReference(displayName: 'tone.wav', uri: source.path);
      final info = await engine.inspect(input);
      expect(info.audioCodec, 'pcm_s16le');
      expect(info.duration!.inMilliseconds, greaterThan(900));

      final trimmed = '${dir.path}/trim.wav';
      final trim = await engine.trim(
        input,
        Duration.zero,
        const Duration(milliseconds: 400),
        trimmed,
      );
      expect(trim.success, isTrue, reason: trim.errorMessage);
      expect(await File(trimmed).length(), greaterThan(0));

      final flac = '${dir.path}/tone.flac';
      final converted = await engine.convert(input, flac, const {});
      expect(converted.success, isTrue, reason: converted.errorMessage);
      expect(converted.metrics['reencoded'], isTrue);
      final flacInfo = await engine.inspect(
        FileReference(displayName: 'tone.flac', uri: flac),
      );
      expect(flacInfo.audioCodec, 'flac');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('qpdf inspects and rotates a generated pdf', () async {
    if (!await _has('qpdf')) {
      markTestSkipped('qpdf is not installed');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('fileforge-qpdf-');
    try {
      final source = File('${dir.path}/page.pdf');
      await source.writeAsBytes(SimplePdf.pages(texts: ['Hello']));
      final engine = QpdfEngine();
      final input = FileReference(displayName: 'page.pdf', uri: source.path);

      final info = await engine.inspect(input);
      expect(info.pageCount, 1);
      expect(info.pageWidth, closeTo(612, 0.1));

      final rotated = '${dir.path}/rotated.pdf';
      final result = await engine.rotatePages(input, const {1: 90}, rotated);
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(await File(rotated).length(), greaterThan(0));

      final merged = '${dir.path}/merged.pdf';
      final merge = await engine.merge([
        input,
        FileReference(displayName: 'rotated.pdf', uri: rotated),
      ], merged);
      expect(merge.success, isTrue, reason: merge.errorMessage);
      final mergedInfo = await engine.inspect(
        FileReference(displayName: 'merged.pdf', uri: merged),
      );
      expect(mergedInfo.pageCount, 2);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('ffmpeg converts and resizes a generated png', () async {
    if (!await _has('ffmpeg') || !await _has('ffprobe')) {
      markTestSkipped('ffmpeg is not installed');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('fileforge-image-');
    try {
      final source = File('${dir.path}/red.png');
      final made = await Process.run('ffmpeg', [
        '-y',
        '-hide_banner',
        '-f',
        'lavfi',
        '-i',
        'color=c=red:s=32x24',
        '-frames:v',
        '1',
        source.path,
      ]);
      expect(made.exitCode, 0, reason: made.stderr.toString());

      final engine = FfmpegImageEngine();
      final input = FileReference(
        displayName: 'red.png',
        uri: source.path,
        detectedFormat: FileFormat.png,
      );
      final info = await engine.inspect(input);
      expect(info.width, 32);
      expect(info.height, 24);
      expect(info.isAnimated, isFalse);

      final jpeg = '${dir.path}/red.jpg';
      final converted = await engine.convert(input, jpeg, {
        'quality': 80,
        'preserveMetadata': false,
      });
      expect(converted.success, isTrue, reason: converted.errorMessage);
      expect(await File(jpeg).length(), greaterThan(0));

      final small = '${dir.path}/small.png';
      final resized = await engine.resize(input, 16, 12, small);
      expect(resized.success, isTrue, reason: resized.errorMessage);
      final resizedInfo = await engine.inspect(
        FileReference(
          displayName: 'small.png',
          uri: small,
          detectedFormat: FileFormat.png,
        ),
      );
      expect(resizedInfo.width, 16);
      expect(resizedInfo.height, 12);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

Future<bool> _has(String executable) async {
  final result = await Process.run('which', [executable]);
  return result.exitCode == 0;
}
