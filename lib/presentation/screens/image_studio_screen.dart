import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/providers/engine_provider.dart';
import 'package:fileforge/application/providers/settings_provider.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/filesystem/file_reference_io.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/pick_files.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/app_banner.dart';
import 'package:fileforge/presentation/widgets/empty_state.dart';
import 'package:fileforge/presentation/widgets/file_drop_zone.dart';
import 'package:fileforge/presentation/widgets/format_icon.dart';
import 'package:fileforge/presentation/widgets/operation_picker.dart';
import 'package:fileforge/presentation/widgets/output_gallery.dart';

const _operations = <OperationType>[
  OperationType.imageConvert,
  OperationType.imageResize,
  OperationType.imageCompress,
  OperationType.imageRemoveMetadata,
];

const _imageFormats = [FileFormat.jpg, FileFormat.png, FileFormat.webpImage];

const _targetOrder = [FileFormat.jpg, FileFormat.png, FileFormat.webpImage];

/// Image convert, resize, compress, and metadata removal.
///
/// JPEG, PNG, and WebP run through FFmpeg. HEIC stays out of this studio
/// because the installed FFmpeg build has no HEIF decoder.
class ImageStudioScreen extends StatefulWidget {
  const ImageStudioScreen({super.key});

  @override
  State<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends State<ImageStudioScreen> {
  final List<FileReference> _files = [];
  final _width = TextEditingController();
  final _height = TextEditingController();

  bool _batch = false;
  bool _keepAspect = true;
  bool _busy = false;
  bool _showGallery = false;
  late bool _preserveMetadata;
  late bool _removeGps;
  OperationType? _operation;
  FileFormat _target = FileFormat.png;
  late double _quality;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _preserveMetadata = settings.preserveMetadata;
    _removeGps = settings.removeGpsData;
    _quality = settings.defaultImageQuality.toDouble();
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickFiles(
      context,
      allowMultiple: _batch,
      extensions: extensionsFor(_imageFormats),
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      if (!_batch) _files.clear();
      for (final file in picked) {
        _files.removeWhere((existing) => existing.uri == file.uri);
        _files.add(file);
      }
    });
  }

  Future<void> _process() async {
    final operation = _operation;
    if (operation == null || _files.isEmpty || _busy) return;
    final inputs =
        _batch || operation == OperationType.imageRemoveMetadata
            ? List<FileReference>.of(_files)
            : [_files.first];
    final request = ProcessingRequest(
      id: newJobId(),
      studio: StudioType.imageStudio,
      operation: _batch ? _batchOperation(operation) : operation,
      inputs: inputs,
      outputFormat:
          operation == OperationType.imageConvert
              ? _effectiveTarget(context.read<EngineProvider>())
              : null,
      parameters: {
        'format':
            _effectiveTarget(context.read<EngineProvider>()).extensions.first,
        'width': int.tryParse(_width.text.trim()),
        'height': int.tryParse(_height.text.trim()),
        'keepAspect': _keepAspect,
        'quality': _quality.round(),
        'preserveMetadata': _preserveMetadata,
        'removeGps': _removeGps,
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

  OperationType _batchOperation(OperationType operation) {
    if (operation == OperationType.imageConvert) {
      return OperationType.imageBatchConvert;
    }
    if (operation == OperationType.imageResize) {
      return OperationType.imageBatchResize;
    }
    return operation;
  }

  List<FileFormat> _targetChoices(EngineProvider engines) {
    final available =
        engines
            .enginesForOperation(OperationType.imageConvert)
            .expand((engine) => engine.supportedOutputFormats)
            .toSet();
    if (available.isEmpty) return _targetOrder;
    final choices = [
      for (final format in _targetOrder)
        if (available.contains(format)) format,
    ];
    return choices.isEmpty ? _targetOrder : choices;
  }

  FileFormat _effectiveTarget(EngineProvider engines) {
    final choices = _targetChoices(engines);
    return choices.contains(_target) ? _target : choices.first;
  }

  @override
  Widget build(BuildContext context) {
    final engines = context.watch<EngineProvider>();
    final disabled = unavailableOperations(engines, _operations);
    final imageReady = !disabled.contains(OperationType.imageConvert);
    final target = _effectiveTarget(engines);
    return Scaffold(
      appBar: forgeAppBar(
        context,
        title: 'Image Studio',
        actions: [
          galleryToggle(
            showing: _showGallery,
            onPressed: () => setState(() => _showGallery = !_showGallery),
          ),
          IconButton(
            tooltip: _batch ? 'Batch mode on' : 'Batch mode',
            onPressed: () {
              setState(() {
                _batch = !_batch;
                if (!_batch && _files.length > 1) {
                  _files.removeRange(1, _files.length);
                }
              });
            },
            icon: Icon(_batch ? Icons.collections : Icons.collections_outlined),
          ),
        ],
      ),
      body:
          _showGallery
              ? const OutputGallery(studio: StudioType.imageStudio)
              : Column(
                children: [
                  if (!imageReady)
                    const AppBanner(
                      severity: BannerSeverity.info,
                      message:
                          'Image conversion needs FFmpeg with JPEG, PNG, or WebP support.',
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: FileDropZone(
                      onTap: _pick,
                      compact: _files.isNotEmpty,
                      allowMultiple: _batch,
                      icon: Icons.image_outlined,
                      hint: 'Drop images or tap to select',
                      acceptedTypes: const ['JPEG', 'PNG', 'WebP'],
                    ),
                  ),
                  if (_files.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 140,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return _Thumbnail(
                            file: file,
                            onRemove:
                                () => setState(() => _files.removeAt(index)),
                          );
                        },
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
                                icon: Icons.image_outlined,
                                title: 'Choose an operation',
                              )
                              : OperationFormCard(
                                children: [
                                  ..._fields(target, _targetChoices(engines)),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Preserve metadata'),
                                    value: _preserveMetadata,
                                    onChanged: (value) {
                                      setState(
                                        () =>
                                            _preserveMetadata = value ?? false,
                                      );
                                    },
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Remove GPS data'),
                                    value: _removeGps,
                                    onChanged: (value) {
                                      setState(
                                        () => _removeGps = value ?? true,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  ProcessButton(
                                    label:
                                        _batch && _files.length > 1
                                            ? 'Batch Process'
                                            : 'Process',
                                    busy: _busy,
                                    onPressed: _files.isEmpty ? null : _process,
                                  ),
                                ],
                              ),
                    ),
                  ),
                ],
              ),
    );
  }

  List<Widget> _fields(FileFormat target, List<FileFormat> choices) {
    switch (_operation) {
      case OperationType.imageConvert:
        return [
          DropdownButtonFormField<FileFormat>(
            initialValue: target,
            decoration: const InputDecoration(labelText: 'Target format'),
            items: [
              for (final format in choices)
                DropdownMenuItem(
                  value: format,
                  child: Text(format.displayName),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _target = value);
            },
          ),
        ];
      case OperationType.imageResize:
        return [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _width,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Width'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height'),
                ),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep aspect ratio'),
            value: _keepAspect,
            onChanged: (value) => setState(() => _keepAspect = value ?? true),
          ),
        ];
      case OperationType.imageCompress:
        return [
          Text('Quality · ${_quality.round()}'),
          Slider(
            value: _quality,
            min: 1,
            max: 100,
            divisions: 99,
            label: '${_quality.round()}',
            onChanged: (value) => setState(() => _quality = value),
          ),
        ];
      default:
        return const [Text('GPS tags and other metadata are stripped.')];
    }
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.file, required this.onRemove});

  final FileReference file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(fileReferencePath(file)),
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => ColoredBox(
                  color: AppTheme.cardColor,
                  child: Center(
                    child: FormatIcon.badge(format: file.detectedFormat),
                  ),
                ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                file.detectedFormat?.displayName ?? 'Image',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
