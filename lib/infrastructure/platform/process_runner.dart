import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Wraps Linux process execution for engine adapters.
///
/// Uses argument lists (never shell string interpolation) per spec §12.5.
class ProcessRunner {
  /// Run an external process and return stdout.
  ///
  /// Throws [ProcessException] on non-zero exit codes if [throwOnError] is true.
  static Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool throwOnError = true,
    Duration? timeout,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );

    final runResult = ProcessRunResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );

    if (throwOnError && result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        'Process exited with code ${result.exitCode}: ${runResult.stderr}',
        result.exitCode,
      );
    }

    return runResult;
  }

  /// Start a long-running process and return a handle for progress tracking.
  static Future<ProcessHandle> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    return ProcessHandle(process);
  }
}

/// Result of a completed process execution.
class ProcessRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get isSuccess => exitCode == 0;
}

/// Handle to a running process, for progress tracking and cancellation.
class ProcessHandle {
  final Process process;
  bool _cancelled = false;

  ProcessHandle(this.process);

  bool get isCancelled => _cancelled;

  /// Subscribe to stdout lines.
  Stream<String> get stdoutLines =>
      process.stdout.transform(const SystemEncoding().decoder);

  /// Subscribe to stderr lines.
  Stream<String> get stderrLines =>
      process.stderr.transform(const SystemEncoding().decoder);

  /// Cancel the running process.
  Future<void> cancel() async {
    _cancelled = true;
    process.kill(ProcessSignal.sigterm);
    // Give it a moment to clean up, then force kill.
    await Future.delayed(const Duration(seconds: 2));
    process.kill(ProcessSignal.sigkill);
  }

  /// Wait for the process to complete.
  Future<int> get exitCode => process.exitCode;
}

/// Stdout, stderr, and exit status collected from a finished process.
class CapturedProcess {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool cancelled;

  const CapturedProcess({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.cancelled,
  });

  bool get isSuccess => exitCode == 0 && !cancelled;
}

/// Whether [error] means the executable itself could not be found.
bool isMissingExecutable(ProcessException error) {
  final message = error.message.toLowerCase();
  return error.errorCode == 2 ||
      message.contains('no such file') ||
      message.contains('cannot find') ||
      message.contains('not found');
}

/// Instance wrapper around [ProcessRunner] so engines can take a fake in tests.
class CommandRunner {
  const CommandRunner();

  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool throwOnError = true,
    Duration? timeout,
  }) {
    return ProcessRunner.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      throwOnError: throwOnError,
      timeout: timeout,
    );
  }

  Future<ProcessHandle> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return ProcessRunner.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  }

  /// Start a process, drain both pipes, and return when it exits.
  ///
  /// [onStarted] runs before the wait so the caller can cancel the handle.
  /// [onStderrLine] receives each stderr line as it arrives.
  Future<CapturedProcess> startAndCapture(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    void Function(ProcessHandle handle)? onStarted,
    void Function(String line)? onStderrLine,
  }) async {
    final handle = await start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    onStarted?.call(handle);

    final stdout = StringBuffer();
    final stderr = StringBuffer();
    final errDone = Completer<void>();
    final outDone = Completer<void>();

    handle.process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (stderr.length < 8000) stderr.writeln(line);
            onStderrLine?.call(line);
          },
          onError: (_) {
            if (!errDone.isCompleted) errDone.complete();
          },
          onDone: () {
            if (!errDone.isCompleted) errDone.complete();
          },
          cancelOnError: false,
        );

    handle.process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          stdout.write,
          onError: (_) {
            if (!outDone.isCompleted) outDone.complete();
          },
          onDone: () {
            if (!outDone.isCompleted) outDone.complete();
          },
          cancelOnError: false,
        );

    final code = await handle.exitCode;
    await errDone.future;
    await outDone.future;

    return CapturedProcess(
      exitCode: code,
      stdout: stdout.toString(),
      stderr: stderr.toString(),
      cancelled: handle.isCancelled,
    );
  }
}
