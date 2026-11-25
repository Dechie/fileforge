import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/output_library.dart';
import 'package:fileforge/application/providers/providers.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/infrastructure/filesystem/file_inspector_service.dart';
import 'package:fileforge/presentation/navigation/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FileForgeApp(inspectionService: createFileInspectionService()));
}

class FileForgeApp extends StatelessWidget {
  const FileForgeApp({super.key, required this.inspectionService});

  final FileInspectionService inspectionService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SystemProvider()..initialize()),
        ChangeNotifierProvider(
          create: (_) => DependencyProvider()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => EngineProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => StorageProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ProcessingProvider()),
        ChangeNotifierProvider(create: (_) => OutputLibrary()..refresh()),
        Provider<FileInspectionService>.value(value: inspectionService),
        ProxyProvider2<ProcessingProvider, EngineProvider, JobRunner>(
          update:
              (_, processing, engines, previous) =>
                  previous ??
                  JobRunner(processing: processing, engines: engines),
        ),
        ChangeNotifierProvider(
          create:
              (_) =>
                  FileSelectionProvider(inspectionService: inspectionService),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'FileForge',
            debugShowCheckedModeBanner: false,
            theme:
                settings.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: const _InitGate(),
          );
        },
      ),
    );
  }
}

/// Shows a loading indicator until system detection + dependency checks finish.
class _InitGate extends StatelessWidget {
  const _InitGate();

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();
    final deps = context.watch<DependencyProvider>();
    final engines = context.watch<EngineProvider>();

    if (!system.isInitialized ||
        !deps.isInitialized ||
        !engines.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction, size: 64, color: AppTheme.primaryColor),
              const SizedBox(height: 24),
              Text(
                'FileForge',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              const SizedBox(width: 200, child: LinearProgressIndicator()),
              const SizedBox(height: 12),
              Text(
                !system.isInitialized
                    ? 'Detecting system…'
                    : !deps.isInitialized
                    ? 'Checking dependencies…'
                    : 'Registering engines…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return const AppShell();
  }
}
