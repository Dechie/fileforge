import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/providers/storage_provider.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/app_banner.dart';
import 'package:fileforge/presentation/widgets/empty_state.dart';
import 'package:fileforge/presentation/widgets/section_header.dart';
import 'package:fileforge/presentation/widgets/storage_usage_bar.dart';

/// Storage overview. Folder scanning is not connected yet, so the lists are empty.
class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final info = context.watch<StorageProvider>().storageInfo;
    return Scaffold(
      appBar: forgeAppBar(context, title: 'Storage Manager'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StorageUsageBar(
                  totalBytes: info.totalBytes,
                  freeBytes: info.freeBytes,
                  tempBytes: info.tempUsageBytes,
                  outputBytes: info.outputUsageBytes,
                  cacheBytes: info.cacheUsageBytes,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const AppBanner(
              severity: BannerSeverity.info,
              message:
                  'Folder scanning is not connected yet. Totals stay at zero until it is.',
            ),
            Card(
              child: Column(
                children: [
                  SectionHeader(
                    title: 'Temporary Files',
                    trailing: TextButton(
                      onPressed: () => _clean(context, 'Temporary files'),
                      child: const Text('Clean All'),
                    ),
                  ),
                  const SizedBox(
                    height: 180,
                    child: EmptyState(
                      icon: Icons.folder_open,
                      title: 'No temporary files',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Column(
                children: [
                  SectionHeader(title: 'Output Files'),
                  SizedBox(
                    height: 180,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No output files',
                      subtitle:
                          'Each studio keeps a gallery of the files it has saved.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cache: ${FileSizeFormatter.format(info.cacheUsageBytes)}',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _clean(context, 'Cache'),
                      child: const Text('Clear Cache'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clean(BuildContext context, String label) async {
    await context.read<StorageProvider>().refresh();
    if (!context.mounted) return;
    showMessage(context, '$label is empty');
  }
}
