import 'package:fileforge/application/job_runner.dart';
import 'package:fileforge/application/output_library.dart';
import 'package:fileforge/application/providers/providers.dart';
import 'package:fileforge/domain/contracts/services/file_inspection_service.dart';
import 'package:fileforge/infrastructure/filesystem/file_inspector_service.dart';
import 'package:fileforge/presentation/navigation/app_shell.dart';
import 'package:fileforge/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('dashboard opens a studio and returns home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final processing = ProcessingProvider();
    final engines = EngineProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SystemProvider()),
          ChangeNotifierProvider(create: (_) => DependencyProvider()),
          ChangeNotifierProvider<EngineProvider>.value(value: engines),
          ChangeNotifierProvider(create: (_) => StorageProvider()),
          ChangeNotifierProvider<ProcessingProvider>.value(value: processing),
          Provider<FileInspectionService>.value(value: FileInspectorService()),
          Provider<JobRunner>(
            create: (_) => JobRunner(processing: processing, engines: engines),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => OutputLibrary()),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    expect(find.text('Active Jobs'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('PDF Studio'), findsOneWidget);
    expect(find.text('Drop PDF files or tap to select'), findsNothing);

    await tester.tap(find.text('PDF'));
    await tester.pump();

    expect(find.text('Drop PDF files or tap to select'), findsOneWidget);
    expect(find.text('Choose an operation'), findsOneWidget);

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();

    expect(find.text('Active Jobs'), findsOneWidget);
    expect(find.text('Drop PDF files or tap to select'), findsNothing);
  });

  testWidgets('settings lists the processing defaults', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.textContaining('Video Quality'), findsOneWidget);
    expect(find.textContaining('FileForge v'), findsOneWidget);
    expect(find.text('Max concurrent jobs'), findsOneWidget);
  });
}
