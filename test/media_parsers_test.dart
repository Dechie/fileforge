import 'package:fileforge/infrastructure/engines/linux/ffmpeg_args.dart';
import 'package:fileforge/infrastructure/engines/linux/ffmpeg_progress.dart';
import 'package:fileforge/infrastructure/engines/linux/ffprobe_parser.dart';
import 'package:fileforge/infrastructure/engines/linux/linux_engine_setup.dart';
import 'package:fileforge/infrastructure/engines/linux/qpdf_args.dart';
import 'package:fileforge/infrastructure/engines/linux/qpdf_metadata_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses ffmpeg progress lines against the known duration', () {
    const total = Duration(seconds: 10);
    final progress = FfmpegProgress.parse(
      'frame=  120 fps=30 q=28.0 size=1024kB time=00:00:04.00 bitrate=1.0kbits/s speed=1.5x',
      total: total,
    );
    expect(progress.fraction, closeTo(0.4, 0.001));
    expect(progress.frame, 120);
    expect(progress.speed, '1.5');

    final protocol = FfmpegProgress.parse(
      'out_time=00:00:02.500000',
      total: total,
    );
    expect(protocol.fraction, closeTo(0.25, 0.001));

    final microsecondsField = FfmpegProgress.parse(
      'out_time_ms=2500000',
      total: total,
    );
    expect(microsecondsField.fraction, isNull);
  });

  test('parses ffprobe json into media metadata', () {
    const json = '''
    {
      "format": {
        "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
        "duration": "12.5",
        "bit_rate": "800000",
        "tags": {"title": "Demo"}
      },
      "streams": [
        {
          "codec_type": "video",
          "codec_name": "h264",
          "width": 1920,
          "height": 1080,
          "avg_frame_rate": "30000/1001",
          "bit_rate": "700000",
          "pix_fmt": "yuv420p"
        },
        {
          "codec_type": "audio",
          "codec_name": "aac",
          "bit_rate": "128000",
          "channels": 2,
          "sample_rate": "44100",
          "tags": {"language": "eng"}
        },
        {
          "codec_type": "subtitle",
          "codec_name": "mov_text",
          "tags": {"language": "spa"}
        }
      ]
    }
    ''';

    final metadata = FfprobeParser.parse(json);
    expect(metadata.container, contains('mp4'));
    expect(metadata.duration, const Duration(milliseconds: 12500));
    expect(metadata.videoCodec, 'h264');
    expect(metadata.width, 1920);
    expect(metadata.frameRate, closeTo(29.97, 0.01));
    expect(metadata.audioCodec, 'aac');
    expect(metadata.audioChannels, 2);
    expect(metadata.subtitleStreamCount, 1);
    expect(metadata.subtitleFormats, ['mov_text']);
    expect(metadata.streamLanguages, containsAll(['eng', 'spa']));
    expect(metadata.rawMetadata['title'], 'Demo');
  });

  test('builds ffmpeg argument lists without a shell string', () {
    final trim = FfmpegArgs.trim(
      inputPath: '/tmp/in.mp4',
      outputPath: '/tmp/out.mp4',
      start: const Duration(seconds: 1),
      end: const Duration(seconds: 5),
    );
    expect(trim, containsAll(['-c', 'copy', '/tmp/in.mp4', '/tmp/out.mp4']));
    expect(
      trim.where((arg) => arg.contains(';') || arg.contains('&&')),
      isEmpty,
    );

    final crop = FfmpegArgs.crop(
      inputPath: '/tmp/in.mp4',
      outputPath: '/tmp/out.mp4',
      x: 0,
      y: 0,
      width: 160,
      height: 120,
    );
    expect(crop, contains('crop=160:120:0:0'));
    expect(crop, contains('libx264'));

    expect(
      FfmpegArgs.escapeFilterPath('/tmp/my:file.srt'),
      r'/tmp/my\:file.srt',
    );
    expect(() => FfmpegArgs.requireEven(161, 120), throwsA(isA<Exception>()));
  });

  test('parses qpdf json and keeps page order in arguments', () {
    const json = '''
    {
      "qpdf": [
        {"jsonversion": 2, "pdfversion": "1.7"},
        {
          "pages": [
            {"pageposfrom1": 1, "/MediaBox": [0, 0, 612, 792]}
          ],
          "objects": {
            "obj:6 0 R": {
              "/Title": "Spec",
              "/Author": "Ada",
              "/CreationDate": "D:20200101120000Z"
            },
            "trailer": {"/Info": "6 0 R", "/Root": "1 0 R"}
          }
        }
      ]
    }
    ''';
    final metadata = QpdfMetadataParser.parse(json);
    expect(metadata.pageCount, 1);
    expect(metadata.pageWidth, 612);
    expect(metadata.pageHeight, 792);
    expect(metadata.title, 'Spec');
    expect(metadata.author, 'Ada');
    expect(metadata.isEncrypted, isFalse);
    expect(metadata.creationDate, DateTime.utc(2020, 1, 1, 12));

    expect(QpdfArgs.merge(['a.pdf', 'b.pdf'], 'out.pdf'), [
      '--empty',
      '--pages',
      'a.pdf',
      'b.pdf',
      '--',
      'out.pdf',
    ]);
    expect(QpdfArgs.pageList([3, 1, 2]), '3,1,2');
    expect(QpdfArgs.complementPages(5, [2, 4]), '1,3,5');
    expect(
      QpdfArgs.encrypt('in.pdf', 'out.pdf', 's3cret'),
      contains('--bits=256'),
    );
    expect(redactSecret('bad password s3cret', 's3cret'), 'bad password ***');
  });

  test('reads encoder names and ignores the legend', () {
    const listing = '''
Encoders:
 V..... = Video
 A..... = Audio
 ------
 V....D libx264              libx264 H.264
 A....D aac                  AAC
''';
    expect(parseFfmpegEncoders(listing), {'libx264', 'aac'});
  });
}
