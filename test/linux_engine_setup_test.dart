import 'dart:io';

import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/infrastructure/engines/linux/linux_engine_setup.dart';
import 'package:fileforge/infrastructure/platform/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers capabilities from probed executables', () async {
    final engines = await discoverLinuxEngines(runner: _ScriptedRunner());
    final byId = {for (final engine in engines) engine.id: engine};

    final ffmpeg = byId['ffmpeg_cli']!;
    expect(ffmpeg.isInstalled, isTrue);
    expect(ffmpeg.version, 'ffmpeg version test');
    expect(ffmpeg.supportedOperations, contains(OperationType.videoCrop));
    expect(ffmpeg.supportedOperations, contains(OperationType.audioConvert));
    expect(ffmpeg.supportedCodecs, contains('libx264'));
    expect(ffmpeg.platforms, {AppPlatform.linux});
    expect(ffmpeg.architectures, {CpuArchitecture.x86_64});

    expect(byId['ffmpeg_image']!.isInstalled, isFalse);
    expect(byId['ffmpeg_image']!.supportedOperations, isEmpty);

    expect(byId['qpdf']!.isInstalled, isFalse);
    expect(byId['qpdf']!.supportedOperations, contains(OperationType.pdfMerge));

    expect(byId['libreoffice']!.isInstalled, isTrue);
    expect(byId['libreoffice']!.version, 'LibreOffice 24');
    expect(
      byId['libreoffice']!.supportedOperations,
      contains(OperationType.markdownToPdf),
    );
  });
}

class _ScriptedRunner extends CommandRunner {
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool throwOnError = true,
    Duration? timeout,
  }) async {
    ProcessRunResult result;
    if (executable == 'which') {
      result = switch (arguments.single) {
        'ffmpeg' => _ok('/usr/bin/ffmpeg\n'),
        'ffprobe' => _ok('/usr/bin/ffprobe\n'),
        'libreoffice' => _ok('/usr/bin/libreoffice\n'),
        _ => _missing(),
      };
    } else if (executable == 'uname') {
      result = _ok('x86_64\n');
    } else if (arguments.contains('-encoders')) {
      result = _ok(
        ' V....D libx264              x\n A....D aac                  x\n',
      );
    } else if (arguments.contains('-version')) {
      result = _ok('ffmpeg version test\n');
    } else if (arguments.contains('--version')) {
      result = _ok('LibreOffice 24\n');
    } else {
      result = _missing();
    }

    if (throwOnError && result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        result.stderr,
        result.exitCode,
      );
    }
    return result;
  }

  ProcessRunResult _ok(String stdout) {
    return ProcessRunResult(exitCode: 0, stdout: stdout, stderr: '');
  }

  ProcessRunResult _missing() {
    return const ProcessRunResult(exitCode: 1, stdout: '', stderr: '');
  }
}
