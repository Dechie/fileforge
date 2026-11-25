import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/output_library.dart';
import 'package:fileforge/application/output_paths.dart';
import 'package:fileforge/application/providers/providers.dart';
import 'package:fileforge/core/utils/file_size_formatter.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/presentation/navigation/nav_destinations.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/metadata_labels.dart';
import 'package:fileforge/presentation/screens/settings_screen.dart';
import 'package:fileforge/presentation/screens/studio_form.dart';
import 'package:fileforge/presentation/widgets/app_banner.dart';
import 'package:fileforge/presentation/widgets/format_icon.dart';
import 'package:fileforge/presentation/widgets/job_widgets.dart';
import 'package:fileforge/presentation/widgets/section_header.dart';
import 'package:fileforge/presentation/widgets/studio_card.dart';

/// Dashboard embedded in the app shell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = context.watch<DependencyProvider>();
    final processing = context.watch<ProcessingProvider>();
    final missing =
        dependencies.dependencies.values
            .where(
              (dependency) =>
                  dependency.status != DependencyStatus.checking &&
                  !dependency.status.isUsable,
            )
            .length;
    final shell = ShellScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FileForge'),
        actions: [
          if (shell.compact)
            IconButton(
              tooltip: 'System',
              onPressed: shell.openSystem,
              icon: const Icon(Icons.tune),
            ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (missing > 0)
              AppBanner(
                severity: BannerSeverity.warning,
                message:
                    missing == 1
                        ? '1 dependency missing'
                        : '$missing dependencies missing',
                actionLabel: 'View',
                onAction: shell.openSystem,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 3 : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      for (final destination in navDestinations)
                        StudioCard(
                          studio: destination.studio,
                          icon: destination.selectedIcon,
                          accentColor: destination.accentColor,
                          isAvailable: dependencies.isStudioAvailable(
                            destination.studio,
                          ),
                          onTap: () => shell.openStudio(destination.studio),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SectionHeader(title: 'Active Jobs'),
            if (processing.activeJobs.isEmpty)
              const _QuietLine('No jobs running')
            else
              for (final job in processing.activeJobs)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: JobProgressCard(
                    job: job,
                    onCancel: () => context.read<JobRunner>().cancel(job.id),
                    onTap: shell.openJobs,
                  ),
                ),
            const SectionHeader(title: 'Recent'),
            _RecentOutputs(items: context.watch<OutputLibrary>().recent),
          ],
        ),
      ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _RecentOutputs extends StatelessWidget {
  const _RecentOutputs({required this.items});

  final List<SavedOutput> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _QuietLine('No saved files yet');
    return Column(
      children: [
        for (final item in items.take(8))
          ListTile(
            leading: FormatIcon.badge(format: item.format),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                item.studio.displayName,
                FileSizeFormatter.format(item.sizeBytes),
                formatShortDate(item.modified),
              ].join(' · '),
            ),
            onTap: () async {
              final opened = await openSavedPath(item.path);
              if (!context.mounted || opened) return;
              showMessage(context, 'Could not open ${item.path}');
            },
          ),
      ],
    );
  }
}
