import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/providers/providers.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/widgets/dependency_status_badge.dart';
import 'package:fileforge/presentation/widgets/info_table.dart';
import 'package:fileforge/presentation/widgets/install_command_box.dart';
import 'package:fileforge/presentation/widgets/section_header.dart';

/// Host details, install commands, and the registered engines.
class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  bool _checking = false;

  Future<void> _recheckAll() async {
    setState(() => _checking = true);
    try {
      await context.read<DependencyProvider>().recheckAll();
      if (!mounted) return;
      await context.read<EngineProvider>().initialize();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>().systemInfo;
    final dependencies = context.watch<DependencyProvider>();
    final engines = context.watch<EngineProvider>().engines;
    return Scaffold(
      appBar: forgeAppBar(
        context,
        title: 'System & Dependencies',
        actions: [
          IconButton(
            tooltip: 'Recheck',
            onPressed: _checking ? null : _recheckAll,
            icon:
                _checking
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InfoTable(rows: _systemRows(system)),
              ),
            ),
            const SectionHeader(title: 'Dependencies'),
            if (dependencies.dependencies.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No dependencies were checked'),
                  subtitle: Text('Dependency checks run on Linux at startup.'),
                ),
              )
            else
              for (final dependency in dependencies.dependencies.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DependencyCard(
                    dependency: dependency,
                    command: _installCommand(dependency, system, dependencies),
                  ),
                ),
            ExpansionTile(
              title: const Text('Registered Engines'),
              children: [
                if (engines.isEmpty)
                  const ListTile(title: Text('No engines registered'))
                else
                  for (final engine in engines)
                    ListTile(
                      title: Text(engine.name),
                      subtitle: Text(
                        '${engine.isInstalled ? (engine.version ?? 'Installed') : 'Not installed'}'
                        ' · ${engine.supportedOperations.length} operations',
                      ),
                      trailing:
                          engine.isInstalled
                              ? const DependencyStatusBadge.installed()
                              : const DependencyStatusBadge.missing(),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<(String, String?)> _systemRows(SystemInfo? system) {
    if (system == null) {
      return const [
        ('OS', null),
        ('Distribution', null),
        ('Family', null),
        ('Version', null),
        ('Architecture', null),
        ('Runtime', null),
      ];
    }
    return [
      ('OS', system.platform == AppPlatform.android ? 'Android' : 'Linux'),
      ('Distribution', system.prettyName ?? system.distributionId),
      ('Family', system.distroFamily.displayName),
      ('Version', system.distributionVersion),
      ('Architecture', system.architecture.name),
      ('Runtime', _runtimeLabel(system.runtimeEnvironment)),
    ];
  }

  String _runtimeLabel(RuntimeEnvironment runtime) {
    switch (runtime) {
      case RuntimeEnvironment.native:
        return 'Native';
      case RuntimeEnvironment.appImage:
        return 'AppImage';
      case RuntimeEnvironment.flatpak:
        return 'Flatpak';
      case RuntimeEnvironment.snap:
        return 'Snap';
      case RuntimeEnvironment.unknown:
        return 'Unknown';
    }
  }

  String? _installCommand(
    DependencyDescriptor dependency,
    SystemInfo? system,
    DependencyProvider dependencies,
  ) {
    final family = system?.distroFamily;
    if (family != null) {
      final command = dependencies.getInstallCommand(dependency.id, family);
      if (command != null) return command;
    }
    return dependency.installCommands['debian'] ??
        (dependency.installCommands.isEmpty
            ? null
            : dependency.installCommands.values.first);
  }
}

class _DependencyCard extends StatelessWidget {
  const _DependencyCard({required this.dependency, required this.command});

  final DependencyDescriptor dependency;
  final String? command;

  @override
  Widget build(BuildContext context) {
    final missing = !dependency.status.isUsable;
    final studios = dependency.affectedStudios
        .map((studio) => studio.displayName)
        .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dependency.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _badge(dependency),
              ],
            ),
            if (dependency.version != null && dependency.status.isUsable) ...[
              const SizedBox(height: 6),
              Text(
                dependency.version!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (studios.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Required by: $studios'),
            ],
            if (missing && command != null) ...[
              const SizedBox(height: 12),
              InstallCommandBox(command: command!),
            ],
            if (missing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed:
                    () => context.read<DependencyProvider>().recheckDependency(
                      dependency.id,
                    ),
                child: const Text('Recheck'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(DependencyDescriptor dependency) {
    switch (dependency.status) {
      case DependencyStatus.installed:
      case DependencyStatus.partiallyAvailable:
        return const DependencyStatusBadge.installed();
      case DependencyStatus.missing:
        return const DependencyStatusBadge.missing();
      case DependencyStatus.checking:
        return const DependencyStatusBadge.checking();
      case DependencyStatus.incompatibleVersion:
        return DependencyStatusBadge.warning(
          label: dependency.status.displayName,
        );
    }
  }
}
