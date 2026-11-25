import 'dart:io';
import 'dart:typed_data';

import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/markdown_html.dart';
import 'package:fileforge/infrastructure/filesystem/file_inspector_service.dart';
import 'package:fileforge/infrastructure/filesystem/image_header_parser.dart';
import 'package:fileforge/infrastructure/filesystem/zip_format_detector.dart';
import 'package:fileforge/application/providers/file_selection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'detects a PDF from its contents when the name says otherwise',
    () async {
      final dir = await Directory.systemTemp.createTemp('fileforge-inspect-');
      try {
        final file = File('${dir.path}/notes.txt');
        await file.writeAsBytes([
          0x25,
          0x50,
          0x44,
          0x46,
          0x2D,
          0x31,
          0x2E,
          0x34,
        ]);
        final service = FileInspectorService();
        final reference = FileReference(
          displayName: 'notes.txt',
          uri: file.path,
        );

        expect(await service.detectFormat(reference), FileFormat.pdf);

        final metadata = await service.getFileMetadata(reference);
        expect(metadata.format, FileFormat.pdf);
        expect(metadata.mimeType, 'application/pdf');

        final selection = FileSelectionProvider(inspectionService: service);
        await selection.addFile(reference);
        expect(selection.selectedFiles.single.detectedFormat, FileFormat.pdf);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test('identifies Office packages inside a ZIP', () {
    expect(
      ZipFormatDetector.detect(_zipEntry('word/document.xml')),
      FileFormat.docx,
    );
    expect(
      ZipFormatDetector.detect(
        _storedEntry('mimetype', 'application/vnd.oasis.opendocument.text'),
      ),
      FileFormat.odt,
    );
  });

  test('reads PNG dimensions and JPEG orientation', () {
    final png = ImageHeaderParser.parse(
      _png(width: 32, height: 16),
      FileFormat.png,
    );
    expect(png.width, 32);
    expect(png.height, 16);
    expect(png.hasTransparency, isTrue);

    final jpeg = ImageHeaderParser.parse(_jpegWithExif(), FileFormat.jpg);
    expect(jpeg.width, 32);
    expect(jpeg.height, 16);
    expect(jpeg.orientation, 6);
    expect(jpeg.hasGpsData, isTrue);
  });

  test('markdown conversion escapes html and keeps structure', () {
    final html = markdownToHtml(
      '# Title\n\nHello **world** & <tag>\n\n- one\n',
    );
    expect(html, contains('<h1>Title</h1>'));
    expect(html, contains('<strong>world</strong>'));
    expect(html, contains('&amp;'));
    expect(html, contains('&lt;tag&gt;'));
    expect(html, contains('<li>one</li>'));
  });
}

Uint8List _zipEntry(String name) {
  final nameBytes = Uint8List.fromList(name.codeUnits);
  final header =
      BytesBuilder()
        ..add([0x50, 0x4B, 0x03, 0x04])
        ..add(Uint8List(22))
        ..add([nameBytes.length, 0, 0, 0])
        ..add(nameBytes);
  return header.toBytes();
}

Uint8List _storedEntry(String name, String contents) {
  final nameBytes = Uint8List.fromList(name.codeUnits);
  final data = Uint8List.fromList(contents.codeUnits);
  final size = _le32(data.length);
  final fields = Uint8List(22);
  fields[14] = size[0];
  fields[15] = size[1];
  fields[16] = size[2];
  fields[17] = size[3];
  fields[18] = size[0];
  fields[19] = size[1];
  fields[20] = size[2];
  fields[21] = size[3];
  return BytesBuilder().toBytesAfter([
    [0x50, 0x4B, 0x03, 0x04],
    fields,
    [nameBytes.length, 0, 0, 0],
    nameBytes,
    data,
  ]);
}

Uint8List _le32(int value) => Uint8List.fromList([
  value & 0xFF,
  (value >> 8) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 24) & 0xFF,
]);

Uint8List _png({required int width, required int height}) {
  final builder =
      BytesBuilder()
        ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add([0, 0, 0, 13])
        ..add('IHDR'.codeUnits)
        ..add([
          (width >> 24) & 0xFF,
          (width >> 16) & 0xFF,
          (width >> 8) & 0xFF,
          width & 0xFF,
        ])
        ..add([
          (height >> 24) & 0xFF,
          (height >> 16) & 0xFF,
          (height >> 8) & 0xFF,
          height & 0xFF,
        ])
        ..add([8, 6, 0, 0, 0])
        ..add([0, 0, 0, 0]);
  return builder.toBytes();
}

Uint8List _jpegWithExif() {
  final tiff =
      BytesBuilder()
        ..add([0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00])
        ..add([0x02, 0x00])
        ..add([
          0x12,
          0x01,
          0x03,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x06,
          0x00,
          0x00,
          0x00,
        ])
        ..add([
          0x25,
          0x88,
          0x04,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
        ])
        ..add([0, 0, 0, 0]);
  final exif =
      BytesBuilder()
        ..add('Exif'.codeUnits)
        ..add([0, 0])
        ..add(tiff.toBytes());
  final exifBytes = exif.toBytes();
  final app1Length = exifBytes.length + 2;

  final sof = Uint8List.fromList([8, 0x00, 0x10, 0x00, 0x20, 1, 1, 0x11, 0]);
  final sofLength = sof.length + 2;

  return BytesBuilder().toBytesAfter([
    [0xFF, 0xD8],
    [0xFF, 0xE1, (app1Length >> 8) & 0xFF, app1Length & 0xFF],
    exifBytes,
    [0xFF, 0xC0, (sofLength >> 8) & 0xFF, sofLength & 0xFF],
    sof,
    [0xFF, 0xD9],
  ]);
}

extension on BytesBuilder {
  Uint8List toBytesAfter(List<List<int>> parts) {
    for (final part in parts) {
      add(part);
    }
    return toBytes();
  }
}
