import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/providers/engine_provider.dart';
import 'package:fileforge/core/utils/duration_formatter.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/metadata_labels.dart';
import 'package:fileforge/presentation/screens/pick_files.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/empty_state.dart';
import 'package:fileforge/presentation/widgets/file_drop_zone.dart';
import 'package:fileforge/presentation/widgets/operation_picker.dart';
import 'package:fileforge/presentation/widgets/output_gallery.dart';

const _operations = <OperationType>[
  OperationType.audioConvert,
  OperationType.audioCompress,
  OperationType.audioTrim,
  OperationType.audioExtractFromVideo,
];

const _audioFormats = [
  FileFormat.mp3,
  FileFormat.wav,
  FileFormat.flac,
  FileFormat.aac,
  FileFormat.m4a,
  FileFormat.ogg,
  FileFormat.opus,
  FileFormat.mp4,
  FileFormat.mkv,
  FileFormat.webm,
  FileFormat.mov,
];

/// Convert, compress, trim, and extract audio.
class AudioStudioScreen extends StatefulWidget {
  const AudioStudioScreen({super.key});

  @override
  State<AudioStudioScreen> createState() => _AudioStudioScreenState();
}

class _AudioStudioScreenState extends State<AudioStudioScreen> {
  FileReference? _file;
  MediaMetadata? _media;
  OperationType? _operation;
  String _format = 'mp3';
  String _bitrate = '128k';
  RangeValues _range = const RangeValues(0, 10);
  double _duration = 60;
  bool _durationKnown = false;
  bool _busy = false;
  bool _showGallery = false;

  Future<void> _pick() async {
    final picked = await pickFiles(
      context,
      allowMultiple: false,
      extensions: extensionsFor(_audioFormats),
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _file = picked.first;
      _media = null;
    });
    try {
      final media = await context
          .read<FileInspectionService>()
          .getMediaMetadata(picked.first);
      if (!mounted || media == null) return;
      final seconds = (media.duration?.inMilliseconds ?? 0) / 1000;
      setState(() {
        _media = media;
        if (seconds > 0) {
          _duration = seconds;
          _durationKnown = true;
          _range = RangeValues(0, seconds);
        }
      });
    } catch (_) {}
  }

  Future<void> _process() async {
    final file = _file;
    final operation = _operation;
    if (file == null || operation == null || _busy) return;
    final request = ProcessingRequest(
      id: newJobId(),
      studio: StudioType.audioStudio,
      operation: operation,
      inputs: [file],
      outputFormat:
          operation == OperationType.audioConvert ||
                  operation == OperationType.audioExtractFromVideo
              ? FileFormat.fromExtension(_format)
              : null,
      parameters: {
        if (operation == OperationType.audioConvert ||
            operation == OperationType.audioExtractFromVideo)
          'format': _format,
        'bitrate': _bitrate,
        'startMs': (_range.start * 1000).round(),
        'endMs': (_range.end * 1000).round(),
      },
    );
    setState(() => _busy = true);
    try {
      final result = await context.read<JobRunner>().run(request);
      if (!mounted) return;
      await revealSavedWork(context, result, () {
        if (mounted) setState(() => _showGallery = true);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = unavailableOperations(
      context.watch<EngineProvider>(),
      _operations,
    );
    final channels = _media?.audioChannels;
    return Scaffold(
      appBar: forgeAppBar(
        context,
        title: 'Audio Studio',
        actions: [
          galleryToggle(
            showing: _showGallery,
            onPressed: () => setState(() => _showGallery = !_showGallery),
          ),
        ],
      ),
      body:
          _showGallery
              ? const OutputGallery(studio: StudioType.audioStudio)
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: FileDropZone(
                      onTap: _pick,
                      compact: _file != null,
                      allowMultiple: false,
                      icon: Icons.audiotrack_outlined,
                      hint: 'Drop audio or tap to select',
                      acceptedTypes: const ['MP3', 'WAV', 'FLAC', 'AAC', 'OGG'],
                    ),
                  ),
                  if (_file != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: StatWrap(
                            stats: [
                              ('Codec', _media?.audioCodec ?? '—'),
                              (
                                'Bitrate',
                                formatBitrate(
                                  _media?.audioBitrate ??
                                      _media?.overallBitrate,
                                ),
                              ),
                              ('Duration', formatDuration(_media?.duration)),
                              (
                                'Channels',
                                channels == null
                                    ? '—'
                                    : channels == 1
                                    ? 'Mono'
                                    : channels == 2
                                    ? 'Stereo'
                                    : '$channels',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  OperationPicker(
                    operations: _operations,
                    selected: _operation,
                    disabledOperations: disabled,
                    onSelected:
                        (operation) => setState(() => _operation = operation),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child:
                          _operation == null
                              ? const EmptyState(
                                icon: Icons.audiotrack_outlined,
                                title: 'Choose an operation',
                              )
                              : OperationFormCard(
                                children: [
                                  ..._fields(),
                                  const SizedBox(height: 16),
                                  ProcessButton(
                                    label: 'Process',
                                    busy: _busy,
                                    onPressed:
                                        _file == null ||
                                                disabled.contains(_operation)
                                            ? null
                                            : _process,
                                  ),
                                ],
                              ),
                    ),
                  ),
                ],
              ),
    );
  }

  List<Widget> _fields() {
    switch (_operation) {
      case OperationType.audioConvert:
      case OperationType.audioExtractFromVideo:
        return [_formatField()];
      case OperationType.audioCompress:
        return [
          DropdownButtonFormField<String>(
            initialValue: _bitrate,
            decoration: const InputDecoration(labelText: 'Bitrate'),
            items: const [
              DropdownMenuItem(value: '64k', child: Text('64 kbps')),
              DropdownMenuItem(value: '96k', child: Text('96 kbps')),
              DropdownMenuItem(value: '128k', child: Text('128 kbps')),
              DropdownMenuItem(value: '192k', child: Text('192 kbps')),
              DropdownMenuItem(value: '256k', child: Text('256 kbps')),
              DropdownMenuItem(value: '320k', child: Text('320 kbps')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _bitrate = value);
            },
          ),
        ];
      case OperationType.audioTrim:
        return [
          Text(
            '${DurationFormatter.format(Duration(milliseconds: (_range.start * 1000).round()))}'
            ' – '
            '${DurationFormatter.format(Duration(milliseconds: (_range.end * 1000).round()))}',
          ),
          RangeSlider(
            values: _range,
            min: 0,
            max: _duration <= 0 ? 1 : _duration,
            onChanged: (value) => setState(() => _range = value),
          ),
          if (!_durationKnown)
            Text(
              'Duration is unknown. Set the range before processing.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ];
      default:
        return const [];
    }
  }

  Widget _formatField() {
    return DropdownButtonFormField<String>(
      initialValue: _format,
      decoration: const InputDecoration(labelText: 'Format'),
      items: const [
        DropdownMenuItem(value: 'mp3', child: Text('MP3')),
        DropdownMenuItem(value: 'wav', child: Text('WAV')),
        DropdownMenuItem(value: 'flac', child: Text('FLAC')),
        DropdownMenuItem(value: 'aac', child: Text('AAC')),
        DropdownMenuItem(value: 'ogg', child: Text('OGG')),
        DropdownMenuItem(value: 'opus', child: Text('Opus')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _format = value);
      },
    );
  }
}
