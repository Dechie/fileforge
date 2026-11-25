import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/providers/providers.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/page_spec.dart';
import 'package:fileforge/presentation/screens/pick_files.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/app_banner.dart';
import 'package:fileforge/presentation/widgets/empty_state.dart';
import 'package:fileforge/presentation/widgets/file_drop_zone.dart';
import 'package:fileforge/presentation/widgets/operation_picker.dart';
import 'package:fileforge/presentation/widgets/output_gallery.dart';

const _operations = <OperationType>[
  OperationType.pdfMerge,
  OperationType.pdfSplit,
  OperationType.pdfExtractPages,
  OperationType.pdfReorderPages,
  OperationType.pdfRotatePages,
  OperationType.pdfDeletePages,
  OperationType.pdfCompress,
  OperationType.pdfAddWatermark,
  OperationType.pdfAddPageNumbers,
  OperationType.pdfProtect,
  OperationType.pdfUnprotect,
];

/// PDF tools: merge, split, page edits, watermark, and passwords.
class PdfStudioScreen extends StatefulWidget {
  const PdfStudioScreen({super.key});

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final List<FileReference> _files = [];
  final Map<String, int?> _pageCounts = {};
  final _pages = TextEditingController();
  final _watermark = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  OperationType? _operation;
  int _rotation = 90;
  bool _busy = false;
  bool _showGallery = false;

  @override
  void dispose() {
    _pages.dispose();
    _watermark.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickFiles(
      context,
      extensions: extensionsFor(const [FileFormat.pdf]),
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      for (final file in picked) {
        _files.removeWhere((existing) => existing.uri == file.uri);
        _files.add(file);
      }
    });
    await _loadPageCounts(picked);
  }

  Future<void> _loadPageCounts(List<FileReference> picked) async {
    final inspector = context.read<FileInspectionService>();
    for (final file in picked) {
      if (file.detectedFormat != FileFormat.pdf) continue;
      try {
        final metadata = await inspector.getPdfMetadata(file);
        if (!mounted) return;
        setState(() => _pageCounts[file.uri] = metadata?.pageCount);
      } catch (_) {}
    }
  }

  Future<void> _process() async {
    final operation = _operation;
    if (operation == null || _files.isEmpty || _busy) return;
    if (operation == OperationType.pdfMerge && _files.length < 2) {
      showMessage(context, 'Merge needs at least two PDF files.');
      return;
    }

    Map<String, dynamic> parameters = const {};
    try {
      parameters = _parameters(operation);
    } on FormatException catch (error) {
      showMessage(context, error.message);
      return;
    }
    if (parameters.containsKey('error')) {
      showMessage(context, parameters['error'] as String);
      return;
    }

    final request = ProcessingRequest(
      id: newJobId(),
      studio: StudioType.pdfStudio,
      operation: operation,
      inputs:
          operation == OperationType.pdfMerge
              ? List<FileReference>.of(_files)
              : [_files.first],
      parameters: parameters,
      outputFormat: FileFormat.pdf,
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

  Map<String, dynamic> _parameters(OperationType operation) {
    switch (operation) {
      case OperationType.pdfExtractPages:
      case OperationType.pdfReorderPages:
      case OperationType.pdfDeletePages:
        return {'pages': parsePageSpec(_pages.text)};
      case OperationType.pdfRotatePages:
        return {'pages': parsePageSpec(_pages.text), 'rotation': _rotation};
      case OperationType.pdfAddWatermark:
        final text = _watermark.text.trim();
        if (text.isEmpty) return {'error': 'Enter watermark text'};
        return {'watermark': text};
      case OperationType.pdfProtect:
        if (_password.text.isEmpty) return {'error': 'Enter a password'};
        if (_password.text != _confirm.text) {
          return {'error': 'Passwords do not match'};
        }
        return {'password': _password.text};
      case OperationType.pdfUnprotect:
        if (_password.text.isEmpty) return {'error': 'Enter the password'};
        return {'password': _password.text};
      default:
        return const {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = unavailableOperations(
      context.watch<EngineProvider>(),
      _operations,
    );
    final ready = disabled.length < _operations.length;
    return Scaffold(
      appBar: forgeAppBar(
        context,
        title: 'PDF Studio',
        actions: [
          galleryToggle(
            showing: _showGallery,
            onPressed: () => setState(() => _showGallery = !_showGallery),
          ),
        ],
      ),
      body:
          _showGallery
              ? const OutputGallery(studio: StudioType.pdfStudio)
              : Column(
                children: [
                  if (!ready)
                    const AppBanner(
                      severity: BannerSeverity.warning,
                      message:
                          'qpdf is not available. PDF processing is unavailable.',
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: FileDropZone(
                      onTap: _pick,
                      compact: _files.isNotEmpty,
                      allowMultiple: true,
                      icon: Icons.picture_as_pdf_outlined,
                      hint: 'Drop PDF files or tap to select',
                      acceptedTypes: const ['PDF'],
                    ),
                  ),
                  SelectedFileList(
                    files: _files,
                    onReorder: (oldIndex, newIndex) {
                      setState(() => reorderItems(_files, oldIndex, newIndex));
                    },
                    onRemove: (file) => setState(() => _files.remove(file)),
                    detail: (file) {
                      final pages = _pageCounts[file.uri];
                      final size =
                          file.sizeBytes == null
                              ? null
                              : FileSizeFormatter.format(file.sizeBytes!);
                      final parts = [
                        if (pages != null) '$pages pages',
                        if (size != null) size,
                      ];
                      return parts.isEmpty ? null : parts.join(' · ');
                    },
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
                                icon: Icons.picture_as_pdf_outlined,
                                title: 'Choose an operation',
                                subtitle:
                                    'Select PDFs, then pick what to do with them.',
                              )
                              : OperationFormCard(
                                children: [
                                  ..._fields(_operation!),
                                  const SizedBox(height: 16),
                                  ProcessButton(
                                    label: 'Process',
                                    busy: _busy,
                                    onPressed:
                                        _files.isEmpty ||
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

  List<Widget> _fields(OperationType operation) {
    switch (operation) {
      case OperationType.pdfMerge:
        return const [
          Text('Files are merged in the list order. Drag a row to reorder.'),
        ];
      case OperationType.pdfSplit:
        return const [Text('Each page is written as its own PDF.')];
      case OperationType.pdfExtractPages:
        return [_pageField('Pages to keep, for example 1,3,5-7')];
      case OperationType.pdfReorderPages:
        return [_pageField('New page order, for example 3,1,2')];
      case OperationType.pdfDeletePages:
        return [_pageField('Pages to delete, for example 2,4-6')];
      case OperationType.pdfRotatePages:
        return [
          _pageField('Pages to rotate, for example 1,3-5'),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _rotation,
            decoration: const InputDecoration(labelText: 'Rotation'),
            items: const [
              DropdownMenuItem(value: 90, child: Text('90° clockwise')),
              DropdownMenuItem(value: 180, child: Text('180°')),
              DropdownMenuItem(value: 270, child: Text('270° clockwise')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _rotation = value);
            },
          ),
        ];
      case OperationType.pdfCompress:
        return const [Text('Rewrite the PDF with qpdf object streams.')];
      case OperationType.pdfAddWatermark:
        return [
          TextField(
            controller: _watermark,
            decoration: const InputDecoration(labelText: 'Watermark text'),
          ),
        ];
      case OperationType.pdfAddPageNumbers:
        return const [Text('A page number is stamped on each page.')];
      case OperationType.pdfProtect:
        return [
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
        ];
      case OperationType.pdfUnprotect:
        return [
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _pageField(String hint) {
    return TextField(
      controller: _pages,
      decoration: InputDecoration(labelText: 'Pages', hintText: hint),
    );
  }
}
