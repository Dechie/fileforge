import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';

/// Provides host-system information detected at startup.
class SystemProvider extends ChangeNotifier {
  SystemInfo? _systemInfo;
  bool _isInitialized = false;

  SystemInfo? get systemInfo => _systemInfo;
  bool get isInitialized => _isInitialized;

  AppPlatform get currentPlatform =>
      Platform.isAndroid ? AppPlatform.android : AppPlatform.linux;

  Future<void> initialize() async {
    if (Platform.isLinux) {
      _systemInfo = await _detectLinuxSystem();
    } else if (Platform.isAndroid) {
      _systemInfo = SystemInfo(
        platform: AppPlatform.android,
        distroFamily: DistroFamily.unknown,
      );
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<SystemInfo> _detectLinuxSystem() async {
    String? distroId;
    String? distroIdLike;
    String? distroVersion;
    String? prettyName;

    // Read /etc/os-release (primary) or /usr/lib/os-release (fallback)
    for (final path in ['/etc/os-release', '/usr/lib/os-release']) {
      final file = File(path);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          final parts = line.split('=');
          if (parts.length != 2) continue;
          final key = parts[0].trim();
          final value = parts[1].trim().replaceAll('"', '');
          switch (key) {
            case 'ID':
              distroId = value;
            case 'ID_LIKE':
              distroIdLike = value;
            case 'VERSION_ID':
              distroVersion = value;
            case 'PRETTY_NAME':
              prettyName = value;
          }
        }
        break;
      }
    }

    // Detect architecture
    final archResult = await Process.run('uname', ['-m']);
    final arch = CpuArchitecture.fromString(
      archResult.stdout.toString().trim(),
    );

    // Detect runtime environment
    final runtime = _detectRuntime();

    // Detect distro family
    final family = _classifyDistro(distroId, distroIdLike);

    return SystemInfo(
      platform: AppPlatform.linux,
      distributionId: distroId,
      distributionIdLike: distroIdLike,
      distributionVersion: distroVersion,
      prettyName: prettyName,
      distroFamily: family,
      architecture: arch,
      runtimeEnvironment: runtime,
    );
  }

  DistroFamily _classifyDistro(String? id, String? idLike) {
    final combined = '${id ?? ''} ${idLike ?? ''}'.toLowerCase();
    if (combined.contains('debian') || combined.contains('ubuntu')) {
      return DistroFamily.debian;
    }
    if (combined.contains('fedora') || combined.contains('rhel')) {
      return DistroFamily.fedora;
    }
    if (combined.contains('arch')) return DistroFamily.arch;
    if (combined.contains('suse')) return DistroFamily.suse;
    return DistroFamily.unknown;
  }

  RuntimeEnvironment _detectRuntime() {
    if (Platform.environment.containsKey('APPIMAGE')) {
      return RuntimeEnvironment.appImage;
    }
    if (Platform.environment.containsKey('FLATPAK_ID')) {
      return RuntimeEnvironment.flatpak;
    }
    if (Platform.environment.containsKey('SNAP')) {
      return RuntimeEnvironment.snap;
    }
    return RuntimeEnvironment.native;
  }
}
