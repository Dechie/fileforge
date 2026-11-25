import 'package:fileforge/domain/enums/enums.dart';

/// Information about the host system, populated at startup.
class SystemInfo {
  /// The platform we're running on.
  final AppPlatform platform;

  /// E.g. 'Devuan', 'Ubuntu', 'Fedora'.
  final String? distributionId;

  /// E.g. 'debian', 'fedora', 'arch'.
  final String? distributionIdLike;

  /// Distribution version.
  final String? distributionVersion;

  /// Human-readable distribution name.
  final String? prettyName;

  /// Detected distribution family.
  final DistroFamily distroFamily;

  /// CPU architecture.
  final CpuArchitecture architecture;

  /// How the app is packaged (native, appimage, flatpak, etc.).
  final RuntimeEnvironment runtimeEnvironment;

  /// Android SDK version (Android only).
  final int? androidSdkVersion;

  const SystemInfo({
    required this.platform,
    this.distributionId,
    this.distributionIdLike,
    this.distributionVersion,
    this.prettyName,
    this.distroFamily = DistroFamily.unknown,
    this.architecture = CpuArchitecture.unknown,
    this.runtimeEnvironment = RuntimeEnvironment.unknown,
    this.androidSdkVersion,
  });
}

/// Storage usage information.
class StorageInfo {
  /// Total storage available on the main storage device, in bytes.
  final int totalBytes;

  /// Free space on the main storage device, in bytes.
  final int freeBytes;

  /// Space used by the app's temp directory.
  final int tempUsageBytes;

  /// Space used by the app's output directory.
  final int outputUsageBytes;

  /// Space used by the app's cache directory.
  final int cacheUsageBytes;

  const StorageInfo({
    this.totalBytes = 0,
    this.freeBytes = 0,
    this.tempUsageBytes = 0,
    this.outputUsageBytes = 0,
    this.cacheUsageBytes = 0,
  });

  int get usedByApp => tempUsageBytes + outputUsageBytes + cacheUsageBytes;
}
