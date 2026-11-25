import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/output_library.dart';
import 'package:fileforge/application/output_paths.dart';
import 'package:fileforge/application/providers/providers.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/filesystem/file_reference_io.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/pick_files.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/app_banner.dart';
import 'package:fileforge/presentation/widgets/file_drop_zone.dart';
import 'package:fileforge/presentation/widgets/output_gallery.dart';

const _documentFormats = [
  FileFormat.docx,
  FileFormat.pptx,
  FileFormat.xlsx,
  FileFormat.odt,
  FileFormat.ods,
  FileFormat.odp,
  FileFormat.markdown,
];

/// Converts office documents and Markdown to PDF.
class DocumentStudioScreen extends StatefulWidget {
  const DocumentStudioScreen({super.key});

  @override
  State<DocumentStudioScreen> createState() => _DocumentStudioScreenState();
}

class _DocumentStudioScreenState extends State<DocumentStudioScreen> {
  final List<FileReference> _files = [];
  String? _preview;
  bool _busy = false;
  bool _showGallery = false;

  bool _available(DependencyProvider dependencies) {
    if (Platform.isAndroid) return false;
    return dependencies.isStudioAvailable(StudioType.documentStudio);
  }

  Future<void> _pick() async {
    final picked = await pickFiles(
      context,
      extensions: extensionsFor(_documentFormats),
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      for (final file in picked) {
        _files.removeWhere((existing) => existing.uri == file.uri);
        _files.add(file);
      }
    });
    await _loadPreview();
  }

  Future<void> _loadPreview() async {
    FileReference? markdown;
    for (final file in _files) {
      if (file.detectedFormat == FileFormat.markdown) {
        markdown = file;
        break;
      }
    }
    if (markdown == null) {
      if (mounted) setState(() => _preview = null);
      return;
    }
    try {
      final text = await File(fileReferencePath(markdown)).readAsString();
      if (!mounted) return;
      setState(() {
        _preview = text.length > 4000 ? '${text.substring(0, 4000)}…' : text;
      });
    } catch (_) {
      if (mounted) setState(() => _preview = null);
    }
  }

  Future<void> _convert() async {
    if (_files.isEmpty || _busy) return;
    setState(() => _busy = true);
    var converted = 0;
    String? error;
    try {
      final runner = context.read<JobRunner>();
      for (final file in List<FileReference>.of(_files)) {
        final markdown = file.detectedFormat == FileFormat.markdown;
        final result = await runner.run(
          ProcessingRequest(
            id: newJobId(),
            studio: StudioType.documentStudio,
            operation:
                markdown
                    ? OperationType.markdownToPdf
                    : OperationType.documentToPdf,
            inputs: [file],
            outputFormat: FileFormat.pdf,
          ),
        );
        if (result?.success == true) {
          converted++;
        } else {
          error = result?.errorMessage ?? 'Conversion failed';
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (converted > 0) {
      await context.read<OutputLibrary>().refresh();
      if (!mounted) return;
      setState(() => _showGallery = true);
    }
    if (error != null) {
      showMessage(context, error);
      return;
    }
    final folder = context.read<OutputLibrary>().folderFor(
      StudioType.documentStudio,
    );
    final count = converted == 1 ? '1 file' : '$converted files';
    showMessage(
      context,
      folder == null
          ? 'Converted $count'
          : 'Saved $count in ${friendlyPath(folder)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _available(context.watch<DependencyProvider>());
    return Scaffold(
      appBar: forgeAppBar(
        context,
        title: 'Document Studio',
        actions: [
          galleryToggle(
            showing: _showGallery,
            onPressed: () => setState(() => _showGallery = !_showGallery),
          ),
        ],
      ),
      body:
          _showGallery
              ? const OutputGallery(studio: StudioType.documentStudio)
              : Column(
                children: [
                  if (!available)
                    const AppBanner(
                      severity: BannerSeverity.info,
                      message:
                          'Office conversion requires Linux with LibreOffice',
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: FileDropZone(
                      onTap: _pick,
                      compact: _files.isNotEmpty,
                      icon: Icons.description_outlined,
                      hint: 'Drop documents or tap to select',
                      acceptedTypes: const [
                        'DOCX',
                        'PPTX',
                        'XLSX',
                        'ODT',
                        'Markdown',
                      ],
                    ),
                  ),
                  SelectedFileList(
                    files: _files,
                    onRemove: (file) async {
                      setState(() => _files.remove(file));
                      await _loadPreview();
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<FileFormat>(
                                initialValue: FileFormat.pdf,
                                decoration: const InputDecoration(
                                  labelText: 'Output format',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: FileFormat.pdf,
                                    child: Text('PDF'),
                                  ),
                                ],
                                onChanged: available ? (_) {} : null,
                              ),
                              if (_preview != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Markdown preview',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 180,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(_preview!),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ProcessButton(
                      label: 'Convert to PDF',
                      busy: _busy,
                      onPressed: !available || _files.isEmpty ? null : _convert,
                    ),
                  ),
                ],
              ),
    );
  }
}
