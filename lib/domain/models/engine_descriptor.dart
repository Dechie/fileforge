import 'package:fileforge/domain/enums/enums.dart';

/// Describes a processing engine's identity and capabilities.
class EngineDescriptor {
  /// Unique identifier (e.g. 'ffmpeg_cli', 'media3_transformer').
  final String id;

  /// Human-readable name.
  final String name;

  /// Detected version string.
  final String? version;

  /// Platforms this engine runs on.
  final Set<AppPlatform> platforms;

  /// CPU architectures this engine supports.
  final Set<CpuArchitecture> architectures;

  /// Whether the engine is currently installed and usable.
  final bool isInstalled;

  /// Formats this engine can read.
  final Set<FileFormat> supportedInputFormats;

  /// Formats this engine can produce.
  final Set<FileFormat> supportedOutputFormats;

  /// Operations this engine can perform.
  final Set<OperationType> supportedOperations;

  /// Codecs this engine supports (free-form strings like 'h264', 'libx265').
  final Set<String> supportedCodecs;

  /// Other engines this engine depends on.
  final List<String> requiredDependencies;

  /// Recovery capability of this engine.
  final RecoveryCapability recoveryCapability;

  const EngineDescriptor({
    required this.id,
    required this.name,
    this.version,
    this.platforms = const {},
    this.architectures = const {},
    this.isInstalled = false,
    this.supportedInputFormats = const {},
    this.supportedOutputFormats = const {},
    this.supportedOperations = const {},
    this.supportedCodecs = const {},
    this.requiredDependencies = const [],
    this.recoveryCapability = RecoveryCapability.restartFromBeginning,
  });

  /// Whether this engine can handle a specific operation on the given formats.
  bool canHandle({
    required OperationType operation,
    FileFormat? inputFormat,
    FileFormat? outputFormat,
  }) {
    if (!supportedOperations.contains(operation)) return false;
    if (inputFormat != null && !supportedInputFormats.contains(inputFormat)) {
      return false;
    }
    if (outputFormat != null &&
        !supportedOutputFormats.contains(outputFormat)) {
      return false;
    }
    return true;
  }
}

/// Describes a system-level dependency (e.g. ffmpeg, qpdf, libreoffice).
class DependencyDescriptor {
  /// Identifier matching what the engine registry uses.
  final String id;

  /// Human-readable name.
  final String name;

  /// Detected version, if installed.
  final String? version;

  /// Minimum required version.
  final String? requiredVersion;

  /// Current installation status.
  final DependencyStatus status;

  /// Path to the executable, if found.
  final String? executablePath;

  /// Which studios are affected if this dependency is missing.
  final Set<StudioType> affectedStudios;

  /// Distribution-specific install commands.
  /// Key is the distro family name, value is the command.
  final Map<String, String> installCommands;

  const DependencyDescriptor({
    required this.id,
    required this.name,
    this.version,
    this.requiredVersion,
    this.status = DependencyStatus.checking,
    this.executablePath,
    this.affectedStudios = const {},
    this.installCommands = const {},
  });

  DependencyDescriptor copyWith({
    String? version,
    DependencyStatus? status,
    String? executablePath,
  }) {
    return DependencyDescriptor(
      id: id,
      name: name,
      version: version ?? this.version,
      requiredVersion: requiredVersion,
      status: status ?? this.status,
      executablePath: executablePath ?? this.executablePath,
      affectedStudios: affectedStudios,
      installCommands: installCommands,
    );
  }
}
