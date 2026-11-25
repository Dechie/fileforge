import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/providers/providers.dart';
import 'package:fileforge/core/utils/duration_formatter.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/metadata_labels.dart';
import 'package:fileforge/presentation/screens/pick_files.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/app_banner.dart';
import 'package:fileforge/presentation/widgets/empty_state.dart';
import 'package:fileforge/presentation/widgets/file_drop_zone.dart';
import 'package:fileforge/presentation/widgets/operation_picker.dart';
import 'package:fileforge/presentation/widgets/output_gallery.dart';

const _operations = <OperationType>[
  OperationType.videoTrim,
  OperationType.videoCrop,
  OperationType.videoResize,
  OperationType.videoCompress,
  OperationType.videoConvertContainer,
  OperationType.videoAddSubtitles,
  OperationType.videoExtractAudio,
  OperationType.videoRemoveAudio,
  OperationType.videoExtractFrames,
  OperationType.videoExtractSubtitles,
];

const _videoFormats = [
  FileFormat.mp4,
  FileFormat.mkv,
  FileFormat.webm,
  FileFormat.mov,
];

/// Single-file video tools backed by FFmpeg.
class VideoStudioScreen extends StatefulWidget {
  const VideoStudioScreen({super.key});

  @override
  State<VideoStudioScreen> createState() => _VideoStudioScreenState();
}

class _VideoStudioScreenState extends State<VideoStudioScreen> {
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _x = TextEditingController(text: '0');
  final _y = TextEditingController(text: '0');
  final _interval = TextEditingController(text: '1');

  FileReference? _file;
  MediaMetadata? _media;
  FileReference? _subtitles;
  OperationType? _operation;
  RangeValues _range = const RangeValues(0, 10);
  double _duration = 60;
  bool _durationKnown = false;
  String _aspect = 'Original';
  String _container = 'mp4';
  String _codec = 'libx264';
  String _audioFormat = 'm4a';
  bool _burn = false;
  bool _busy = false;
  bool _showGallery = false;
  late double _crf;

  @override
  void initState() {
    super.initState();
    _crf = context.read<SettingsProvider>().defaultVideoQuality.toDouble();
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _x.dispose();
    _y.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickFiles(
      context,
      allowMultiple: false,
      extensions: extensionsFor(_videoFormats),
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _file = picked.first;
      _media = null;
    });
    await _loadMedia(picked.first);
  }

  Future<void> _loadMedia(FileReference file) async {
    try {
      final media = await context
          .read<FileInspectionService>()
          .getMediaMetadata(file);
      if (!mounted || media == null) return;
      final seconds = (media.duration?.inMilliseconds ?? 0) / 1000;
      setState(() {
        _media = media;
        _applyFrame(media);
        if (seconds > 0) {
          _duration = seconds;
          _durationKnown = true;
          _range = RangeValues(0, seconds);
        }
      });
    } catch (_) {}
  }

  void _applyFrame(MediaMetadata media) {
    final width = media.width;
    final height = media.height;
    if (width == null || height == null) return;
    _width.text = '${width.isEven ? width : width - 1}';
    _height.text = '${height.isEven ? height : height - 1}';
    _x.text = '0';
    _y.text = '0';
  }

  void _applyAspect(String aspect) {
    _aspect = aspect;
    final width = _media?.width;
    final height = _media?.height;
    if (width == null || height == null || aspect == 'Free') return;
    final ratio = switch (aspect) {
      '16:9' => 16 / 9,
      '4:3' => 4 / 3,
      '1:1' => 1.0,
      _ => width / height,
    };
    var cropWidth = width.toDouble();
    var cropHeight = cropWidth / ratio;
    if (cropHeight > height) {
      cropHeight = height.toDouble();
      cropWidth = cropHeight * ratio;
    }
    var evenWidth = cropWidth.floor();
    var evenHeight = cropHeight.floor();
    if (evenWidth.isOdd) evenWidth -= 1;
    if (evenHeight.isOdd) evenHeight -= 1;
    _width.text = '$evenWidth';
    _height.text = '$evenHeight';
    _x.text = '0';
    _y.text = '0';
  }

  Future<void> _pickSubtitles() async {
    final picked = await pickFiles(
      context,
      allowMultiple: false,
      extensions: extensionsFor(const [FileFormat.srt, FileFormat.ass]),
    );
    if (!mounted || picked.isEmpty) return;
    setState(() => _subtitles = picked.first);
  }

  bool get _reencode {
    if (_operation == OperationType.videoCrop ||
        _operation == OperationType.videoResize ||
        _operation == OperationType.videoCompress ||
        _operation == OperationType.videoExtractFrames) {
      return true;
    }
    return _operation == OperationType.videoAddSubtitles && _burn;
  }

  Future<void> _process() async {
    final file = _file;
    final operation = _operation;
    if (file == null || operation == null || _busy) return;
    final burn = operation == OperationType.videoAddSubtitles && _burn;
    final submitted = burn ? OperationType.videoBurnSubtitles : operation;
    final output = _outputFormat(submitted);
    final request = ProcessingRequest(
      id: newJobId(),
      studio: StudioType.videoStudio,
      operation: submitted,
      inputs: [file],
      outputFormat: output,
      parameters: {
        'startMs': (_range.start * 1000).round(),
        'endMs': (_range.end * 1000).round(),
        'x': int.tryParse(_x.text.trim()) ?? 0,
        'y': int.tryParse(_y.text.trim()) ?? 0,
        'width': int.tryParse(_width.text.trim()),
        'height': int.tryParse(_height.text.trim()),
        'crf': _crf.round(),
        'codec': _codec,
        'container': _container,
        'format': _audioFormat,
        'interval': double.tryParse(_interval.text.trim()) ?? 1,
        if (_subtitles != null) 'subtitleUri': _subtitles!.uri,
        if (_subtitles != null) 'subtitleName': _subtitles!.displayName,
        'burn': burn,
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

  FileFormat? _outputFormat(OperationType operation) {
    switch (operation) {
      case OperationType.videoConvertContainer:
        return FileFormat.fromExtension(_container);
      case OperationType.videoExtractAudio:
        return FileFormat.fromExtension(_audioFormat);
      case OperationType.videoExtractSubtitles:
        return FileFormat.srt;
      case OperationType.videoCrop:
      case OperationType.videoResize:
      case OperationType.videoCompress:
      case OperationType.videoAddSubtitles:
      case OperationType.videoBurnSubtitles:
        return FileFormat.mp4;
      default:
        return _file?.detectedFormat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final engines = context.watch<EngineProvider>();
    final disabled = unavailableOperations(engines, [
      ..._operations,
      OperationType.videoBurnSubtitles,
    ]);
    final codecs = engines.engines.expand((engine) => engine.supportedCodecs);
    final codecChoices = ['libx264', if (codecs.contains('libx265')) 'libx265'];
    return Scaffold(
      appBar: forgeAppBar(
        context,
        title: 'Video Studio',
        actions: [
          galleryToggle(
            showing: _showGallery,
            onPressed: () => setState(() => _showGallery = !_showGallery),
          ),
        ],
      ),
      body:
          _showGallery
              ? const OutputGallery(studio: StudioType.videoStudio)
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: FileDropZone(
                      onTap: _pick,
                      compact: _file != null,
                      allowMultiple: false,
                      icon: Icons.videocam_outlined,
                      hint: 'Drop a video or tap to select',
                      acceptedTypes: const ['MP4', 'MKV', 'WebM', 'MOV'],
                    ),
                  ),
                  if (_file != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _file!.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              StatWrap(
                                stats: [
                                  ('Codec', _media?.videoCodec ?? '—'),
                                  (
                                    'Resolution',
                                    formatResolution(
                                      _media?.width,
                                      _media?.height,
                                    ),
                                  ),
                                  (
                                    'Duration',
                                    formatDuration(_media?.duration),
                                  ),
                                  ('Container', _media?.container ?? '—'),
                                  (
                                    'Bitrate',
                                    formatBitrate(_media?.overallBitrate),
                                  ),
                                  ('Frame rate', formatFps(_media?.frameRate)),
                                ],
                              ),
                              if ((_media?.subtitleStreamCount ?? 0) > 0) ...[
                                const SizedBox(height: 12),
                                Chip(
                                  label: Text(
                                    '${_media!.subtitleStreamCount} subtitle streams',
                                  ),
                                ),
                              ],
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
                                icon: Icons.videocam_outlined,
                                title: 'Choose an operation',
                              )
                              : OperationFormCard(
                                children: _form(disabled, codecChoices),
                              ),
                    ),
                  ),
                ],
              ),
    );
  }

  List<Widget> _form(Set<OperationType> disabled, List<String> codecs) {
    return [
      ..._fields(codecs),
      if (_reencode)
        const AppBanner(
          severity: BannerSeverity.warning,
          message: 'This operation requires re-encoding',
        ),
      const SizedBox(height: 8),
      ProcessButton(
        label: 'Process',
        busy: _busy,
        onPressed:
            _file == null || disabled.contains(_operation) ? null : _process,
      ),
    ];
  }

  List<Widget> _fields(List<String> codecs) {
    switch (_operation) {
      case OperationType.videoTrim:
        return [_trimSlider()];
      case OperationType.videoCrop:
        return [
          DropdownButtonFormField<String>(
            initialValue: _aspect,
            decoration: const InputDecoration(labelText: 'Aspect ratio'),
            items: const [
              DropdownMenuItem(value: 'Original', child: Text('Original')),
              DropdownMenuItem(value: '16:9', child: Text('16:9')),
              DropdownMenuItem(value: '4:3', child: Text('4:3')),
              DropdownMenuItem(value: '1:1', child: Text('1:1')),
              DropdownMenuItem(value: 'Free', child: Text('Free')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _applyAspect(value));
            },
          ),
          const SizedBox(height: 12),
          _sizeRow(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _number(_x, 'X offset')),
              const SizedBox(width: 12),
              Expanded(child: _number(_y, 'Y offset')),
            ],
          ),
        ];
      case OperationType.videoResize:
        return [_sizeRow()];
      case OperationType.videoCompress:
        return [
          Text('Quality (CRF) · ${_crf.round()}'),
          Slider(
            value: _crf,
            min: 0,
            max: 51,
            divisions: 51,
            label: '${_crf.round()}',
            onChanged: (value) => setState(() => _crf = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: codecs.contains(_codec) ? _codec : codecs.first,
            decoration: const InputDecoration(labelText: 'Codec'),
            items: [
              for (final codec in codecs)
                DropdownMenuItem(value: codec, child: Text(codec)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _codec = value);
            },
          ),
        ];
      case OperationType.videoConvertContainer:
        return [_containerField()];
      case OperationType.videoAddSubtitles:
        final burnReady =
            context
                .read<EngineProvider>()
                .enginesForOperation(OperationType.videoBurnSubtitles)
                .isNotEmpty;
        return [
          OutlinedButton.icon(
            onPressed: _pickSubtitles,
            icon: const Icon(Icons.subtitles_outlined),
            label: Text(_subtitles?.displayName ?? 'Choose subtitles'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Burn subtitles into the video'),
            subtitle:
                burnReady
                    ? null
                    : const Text('Burning subtitles needs libx264'),
            value: _burn && burnReady,
            onChanged:
                burnReady ? (value) => setState(() => _burn = value) : null,
          ),
        ];
      case OperationType.videoExtractAudio:
        return [
          DropdownButtonFormField<String>(
            initialValue: _audioFormat,
            decoration: const InputDecoration(labelText: 'Audio format'),
            items: const [
              DropdownMenuItem(value: 'm4a', child: Text('M4A')),
              DropdownMenuItem(value: 'mp3', child: Text('MP3')),
              DropdownMenuItem(value: 'wav', child: Text('WAV')),
              DropdownMenuItem(value: 'flac', child: Text('FLAC')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _audioFormat = value);
            },
          ),
        ];
      case OperationType.videoRemoveAudio:
        return const [Text('The video stream is copied without audio.')];
      case OperationType.videoExtractFrames:
        return [
          TextField(
            controller: _interval,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Seconds between frames',
            ),
          ),
        ];
      case OperationType.videoExtractSubtitles:
        return const [Text('The first subtitle stream is saved as SRT.')];
      default:
        return const [];
    }
  }

  Widget _trimSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _sizeRow() {
    return Row(
      children: [
        Expanded(child: _number(_width, 'Width')),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('×'),
        ),
        Expanded(child: _number(_height, 'Height')),
      ],
    );
  }

  Widget _number(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _containerField() {
    return DropdownButtonFormField<String>(
      initialValue: _container,
      decoration: const InputDecoration(labelText: 'Container'),
      items: const [
        DropdownMenuItem(value: 'mp4', child: Text('MP4')),
        DropdownMenuItem(value: 'mkv', child: Text('MKV')),
        DropdownMenuItem(value: 'webm', child: Text('WebM')),
        DropdownMenuItem(value: 'mov', child: Text('MOV')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _container = value);
      },
    );
  }
}
