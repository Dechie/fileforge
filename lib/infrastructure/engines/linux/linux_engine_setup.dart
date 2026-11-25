import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/platform/process_runner.dart';

/// Probe the Linux tools and return engine descriptors for the registry.
///
/// A missing binary is still returned with `isInstalled: false` so the
/// dependency UI can show it. [EngineProvider] registers the result.
Future<List<EngineDescriptor>> discoverLinuxEngines({
  CommandRunner? runner,
}) async {
  final commands = runner ?? const CommandRunner();
  final architecture = await _architecture(commands);

  final ffmpegPath = await _which(commands, 'ffmpeg');
  final ffprobePath = await _which(commands, 'ffprobe');
  final qpdfPath = await _which(commands, 'qpdf');
  final libreOfficePath =
      await _which(commands, 'libreoffice') ??
      await _which(commands, 'soffice');

  final ffmpegInstalled = ffmpegPath != null && ffprobePath != null;
  String? ffmpegVersion;
  var encoders = <String>{};
  if (ffmpegPath != null) {
    ffmpegVersion = await _firstLine(commands, ffmpegPath, const ['-version']);
    encoders = await _encoders(commands, ffmpegPath);
  }

  return [
    EngineDescriptor(
      id: 'ffmpeg_cli',
      name: 'FFmpeg',
      version: ffmpegVersion,
      platforms: {AppPlatform.linux},
      architectures: {architecture},
      isInstalled: ffmpegInstalled,
      supportedInputFormats: _mediaFormats,
      supportedOutputFormats: _mediaFormats,
      supportedOperations: _ffmpegOperations(encoders),
      supportedCodecs: encoders,
      requiredDependencies: const ['ffmpeg'],
      recoveryCapability: RecoveryCapability.restartFromBeginning,
    ),
    EngineDescriptor(
      id: 'ffmpeg_image',
      name: 'FFmpeg Images',
      version: ffmpegVersion,
      platforms: {AppPlatform.linux},
      architectures: {architecture},
      isInstalled: ffmpegInstalled && _imageOutputs(encoders).isNotEmpty,
      supportedInputFormats: _stillImageFormats,
      supportedOutputFormats: _imageOutputs(encoders),
      supportedOperations: _imageOperations(encoders),
      supportedCodecs: encoders,
      requiredDependencies: const ['ffmpeg'],
      recoveryCapability: RecoveryCapability.restartFromBeginning,
    ),
    EngineDescriptor(
      id: 'qpdf',
      name: 'qpdf',
      version:
          qpdfPath == null
              ? null
              : await _firstLine(commands, qpdfPath, const ['--version']),
      platforms: {AppPlatform.linux},
      architectures: {architecture},
      isInstalled: qpdfPath != null,
      supportedInputFormats: const {FileFormat.pdf},
      supportedOutputFormats: const {FileFormat.pdf},
      supportedOperations: _pdfOperations,
      requiredDependencies: const ['qpdf'],
      recoveryCapability: RecoveryCapability.restartFromBeginning,
    ),
    EngineDescriptor(
      id: 'libreoffice',
      name: 'LibreOffice',
      version:
          libreOfficePath == null
              ? null
              : await _firstLine(commands, libreOfficePath, const [
                '--version',
              ]),
      platforms: {AppPlatform.linux},
      architectures: {architecture},
      isInstalled: libreOfficePath != null,
      supportedInputFormats: _documentFormats,
      supportedOutputFormats: const {FileFormat.pdf},
      supportedOperations: const {
        OperationType.documentToPdf,
        OperationType.markdownToPdf,
      },
      requiredDependencies: const ['libreoffice'],
      recoveryCapability: RecoveryCapability.restartFromBeginning,
    ),
  ];
}

/// Encoder names from `ffmpeg -encoders`. Header lines are ignored.
Set<String> parseFfmpegEncoders(String output) {
  final names = <String>{};
  final pattern = RegExp(r'^ ([A-Z.]{6}) ([A-Za-z0-9_]+)');
  for (final line in output.split('\n')) {
    final match = pattern.firstMatch(line);
    if (match != null) names.add(match.group(2)!);
  }
  return names;
}

const _videoFormats = {
  FileFormat.mp4,
  FileFormat.mkv,
  FileFormat.webm,
  FileFormat.mov,
};

const _audioFormats = {
  FileFormat.mp3,
  FileFormat.wav,
  FileFormat.flac,
  FileFormat.aac,
  FileFormat.m4a,
  FileFormat.ogg,
  FileFormat.opus,
};

const _mediaFormats = {..._videoFormats, ..._audioFormats};

const _stillImageFormats = {
  FileFormat.jpg,
  FileFormat.png,
  FileFormat.webpImage,
};

Set<FileFormat> _imageOutputs(Set<String> encoders) {
  return {
    if (encoders.contains('mjpeg')) FileFormat.jpg,
    if (encoders.contains('png')) FileFormat.png,
    if (encoders.contains('libwebp')) FileFormat.webpImage,
  };
}

Set<OperationType> _imageOperations(Set<String> encoders) {
  if (_imageOutputs(encoders).isEmpty) return {};
  return const {
    OperationType.imageConvert,
    OperationType.imageResize,
    OperationType.imageCompress,
    OperationType.imageBatchConvert,
    OperationType.imageBatchResize,
    OperationType.imageRemoveMetadata,
    OperationType.imageInspect,
  };
}

const _documentFormats = {
  FileFormat.docx,
  FileFormat.pptx,
  FileFormat.xlsx,
  FileFormat.odt,
  FileFormat.ods,
  FileFormat.odp,
  FileFormat.markdown,
};

const _pdfOperations = {
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
  OperationType.pdfInspect,
};

const _audioEncoders = {
  'aac',
  'libmp3lame',
  'libvorbis',
  'libopus',
  'flac',
  'pcm_s16le',
};

Set<OperationType> _ffmpegOperations(Set<String> encoders) {
  final operations = <OperationType>{
    OperationType.videoTrim,
    OperationType.videoConvertContainer,
    OperationType.videoExtractAudio,
    OperationType.videoRemoveAudio,
    OperationType.videoExtractSubtitles,
    OperationType.videoAddSubtitles,
    OperationType.videoInspect,
    OperationType.audioTrim,
    OperationType.audioExtractFromVideo,
    OperationType.audioInspect,
  };
  if (encoders.contains('png') || encoders.contains('apng')) {
    operations.add(OperationType.videoExtractFrames);
  }
  if (encoders.contains('libx264')) {
    operations.addAll(const {
      OperationType.videoCrop,
      OperationType.videoResize,
      OperationType.videoCompress,
      OperationType.videoBurnSubtitles,
    });
  }
  if (encoders.intersection(_audioEncoders).isNotEmpty) {
    operations.add(OperationType.audioConvert);
    operations.add(OperationType.audioCompress);
  }
  return operations;
}

Future<String?> _which(CommandRunner runner, String name) async {
  try {
    final result = await runner.run('which', [name], throwOnError: false);
    if (!result.isSuccess) return null;
    final path = result.stdout.trim();
    return path.isEmpty ? null : path;
  } catch (_) {
    return null;
  }
}

Future<String?> _firstLine(
  CommandRunner runner,
  String executable,
  List<String> arguments,
) async {
  try {
    final result = await runner.run(executable, arguments, throwOnError: false);
    final text = '${result.stdout}\n${result.stderr}'.trim();
    if (text.isEmpty) return null;
    return text.split('\n').first.trim();
  } catch (_) {
    return null;
  }
}

Future<Set<String>> _encoders(CommandRunner runner, String ffmpeg) async {
  try {
    final result = await runner.run(ffmpeg, const [
      '-hide_banner',
      '-encoders',
    ], throwOnError: false);
    return parseFfmpegEncoders('${result.stdout}\n${result.stderr}');
  } catch (_) {
    return {};
  }
}

Future<CpuArchitecture> _architecture(CommandRunner runner) async {
  try {
    final result = await runner.run('uname', const ['-m'], throwOnError: false);
    return CpuArchitecture.fromString(result.stdout.trim());
  } catch (_) {
    return CpuArchitecture.unknown;
  }
}
