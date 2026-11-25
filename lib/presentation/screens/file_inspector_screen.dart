import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/core/errors/app_exceptions.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/metadata_labels.dart';
import 'package:fileforge/presentation/screens/pick_files.dart';
import 'package:fileforge/presentation/widgets/app_banner.dart';
import 'package:fileforge/presentation/widgets/file_drop_zone.dart';
import 'package:fileforge/presentation/widgets/info_table.dart';

/// Content-based details for a single file.
class FileInspectorScreen extends StatefulWidget {
  const FileInspectorScreen({super.key});

  @override
  State<FileInspectorScreen> createState() => _FileInspectorScreenState();
}

class _FileInspectorScreenState extends State<FileInspectorScreen> {
  FileReference? _file;
  FileMetadata? _general;
  MediaMetadata? _media;
  ImageMetadata? _image;
  PdfMetadata? _pdf;
  String? _error;
  bool _loading = false;

  Future<void> _pick() async {
    final picked = await pickFiles(context, allowMultiple: false);
    if (!mounted || picked.isEmpty) return;
    final file = picked.first;
    setState(() {
      _file = file;
      _general = null;
      _media = null;
      _image = null;
      _pdf = null;
      _error = null;
      _loading = true;
    });
    final inspector = context.read<FileInspectionService>();
    try {
      final general = await inspector.getFileMetadata(file);
      final media = await inspector.getMediaMetadata(file);
      final image = await inspector.getImageMetadata(file);
      final pdf = await inspector.getPdfMetadata(file);
      if (!mounted) return;
      setState(() {
        _general = general;
        _media = media;
        _image = image;
        _pdf = pdf;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is FileForgeException ? error.message : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return Scaffold(
      appBar: forgeAppBar(context, title: 'File Inspector'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FileDropZone(
              onTap: _pick,
              compact: file != null,
              allowMultiple: false,
              icon: Icons.search,
              hint: 'Drop a file or tap to inspect',
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (file != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    if (_error != null)
                      AppBanner(
                        severity: BannerSeverity.error,
                        message: _error!,
                      ),
                    _section('General', _generalRows(file)),
                    if (_formatRows(file) case final rows?)
                      _section(_sectionTitle(file), rows),
                    ExpansionTile(
                      title: const Text('Raw Metadata'),
                      children: [
                        if (_rawRows().isEmpty)
                          const ListTile(title: Text('No extra metadata'))
                        else
                          InfoTable(rows: _rawRows()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, List<(String, String?)> rows) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            InfoTable(rows: rows, highlights: _highlights(rows)),
          ],
        ),
      ),
    );
  }

  Map<String, Color> _highlights(List<(String, String?)> rows) {
    final highlights = <String, Color>{};
    for (final row in rows) {
      if (row.$1 == 'Extension match' && row.$2 == 'No') {
        highlights[row.$1] = AppTheme.warningColor;
      }
      if (row.$1 == 'Encrypted' && row.$2 == 'Yes') {
        highlights[row.$1] = AppTheme.warningColor;
      }
    }
    return highlights;
  }

  List<(String, String?)> _generalRows(FileReference file) {
    final metadata = _general;
    final size = metadata?.sizeBytes ?? file.sizeBytes;
    return [
      ('Name', file.displayName),
      ('Size', size == null ? null : FileSizeFormatter.format(size)),
      ('Detected format', file.detectedFormat?.displayName),
      ('MIME type', metadata?.mimeType ?? file.mimeType),
      ('Extension match', yesNo(extensionMatches(file))),
    ];
  }

  String _sectionTitle(FileReference file) {
    switch (file.detectedFormat?.category) {
      case FileCategory.video:
      case FileCategory.audio:
        return 'Media';
      case FileCategory.image:
        return 'Image';
      case FileCategory.pdf:
        return 'PDF';
      default:
        return 'Details';
    }
  }

  List<(String, String?)>? _formatRows(FileReference file) {
    switch (file.detectedFormat?.category) {
      case FileCategory.video:
      case FileCategory.audio:
        final media = _media;
        if (media == null) return [('Metadata', 'Unavailable')];
        return [
          ('Container', media.container),
          ('Duration', formatDuration(media.duration)),
          ('Bitrate', formatBitrate(media.overallBitrate)),
          ('Video codec', media.videoCodec),
          ('Resolution', formatResolution(media.width, media.height)),
          ('Frame rate', formatFps(media.frameRate)),
          ('Audio codec', media.audioCodec),
          ('Audio bitrate', formatBitrate(media.audioBitrate)),
          ('Channels', media.audioChannels?.toString()),
          (
            'Sample rate',
            media.sampleRate == null ? null : '${media.sampleRate} Hz',
          ),
          ('Subtitle streams', '${media.subtitleStreamCount}'),
        ];
      case FileCategory.image:
        final image = _image;
        if (image == null) return [('Metadata', 'Unavailable')];
        return [
          ('Dimensions', formatResolution(image.width, image.height)),
          ('Color profile', image.colorProfile),
          ('Transparency', yesNo(image.hasTransparency)),
          ('Orientation', image.orientation?.toString()),
          ('GPS', yesNo(image.hasGpsData)),
          ('Animated', yesNo(image.isAnimated)),
          ('Frames', image.frameCount?.toString()),
        ];
      case FileCategory.pdf:
        final pdf = _pdf;
        if (pdf == null) return [('Metadata', 'Unavailable')];
        final size =
            pdf.pageWidth == null || pdf.pageHeight == null
                ? null
                : '${pdf.pageWidth!.toStringAsFixed(0)} × ${pdf.pageHeight!.toStringAsFixed(0)} pt';
        return [
          ('Pages', pdf.pageCount?.toString()),
          ('Dimensions', size),
          ('Encrypted', yesNo(pdf.isEncrypted)),
          ('Title', pdf.title),
          ('Author', pdf.author),
        ];
      default:
        return null;
    }
  }

  List<(String, String?)> _rawRows() {
    final rows = <(String, String?)>[];
    _media?.rawMetadata.forEach((key, value) => rows.add((key, value)));
    _image?.exifData.forEach((key, value) => rows.add((key, value)));
    _pdf?.properties.forEach((key, value) => rows.add((key, value)));
    return rows;
  }
}
