import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/output_library.dart';
import 'package:fileforge/application/output_paths.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/presentation/screens/metadata_labels.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/empty_state.dart';
import 'package:fileforge/presentation/widgets/format_icon.dart';

/// Files this studio has already written to disk.
class OutputGallery extends StatelessWidget {
  const OutputGallery({super.key, required this.studio});

  final StudioType studio;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<OutputLibrary>();
    final items = library.outputsFor(studio);
    final folder = library.folderFor(studio);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gallery',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      folder == null
                          ? 'Looking up the save folder…'
                          : 'Saved in ${friendlyPath(folder)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open folder',
                onPressed: folder == null ? null : () => _open(context, folder),
                icon: const Icon(Icons.folder_open),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: library.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (library.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Could not read saved files.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        Expanded(
          child:
              items.isEmpty
                  ? EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'Nothing saved yet',
                    subtitle:
                        folder == null
                            ? 'Finished files from this studio show up here.'
                            : 'Finished files are written to ${friendlyPath(folder)}.',
                  )
                  : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _GalleryCard(item: items[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, String path) async {
    final opened = await openSavedPath(path);
    if (!context.mounted || opened) return;
    showMessage(context, 'Could not open $path');
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({required this.item});

  final SavedOutput item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showImage = item.format?.category == FileCategory.image;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, item.path),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child:
                  showImage
                      ? Image.file(
                        File(item.path),
                        fit: BoxFit.cover,
                        cacheWidth: 480,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                _Fallback(format: item.format),
                      )
                      : _Fallback(format: item.format),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${FileSizeFormatter.format(item.sizeBytes)} · ${formatShortDate(item.modified)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Show in folder',
                    onPressed: () => _open(context, item.directory),
                    icon: const Icon(Icons.folder_open, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String path) async {
    final opened = await openSavedPath(path);
    if (!context.mounted || opened) return;
    showMessage(context, 'Could not open $path');
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.format});

  final FileFormat? format;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.backgroundColor,
      child: Center(child: FormatIcon.badge(format: format, size: 56)),
    );
  }
}
