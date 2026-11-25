import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';

/// Discovers and tracks system dependencies (ffmpeg, qpdf, libreoffice, etc.).
class DependencyProvider extends ChangeNotifier {
  final Map<String, DependencyDescriptor> _dependencies = {};
  bool _isInitialized = false;

  Map<String, DependencyDescriptor> get dependencies =>
      Map.unmodifiable(_dependencies);
  bool get isInitialized => _isInitialized;

  /// All known dependency definitions for Linux.
  static final List<DependencyDescriptor> _linuxDependencies = [
    DependencyDescriptor(
      id: 'ffmpeg',
      name: 'FFmpeg',
      affectedStudios: {StudioType.videoStudio, StudioType.audioStudio},
      installCommands: {
        'debian': 'sudo apt install ffmpeg',
        'fedora': 'sudo dnf install ffmpeg',
        'arch': 'sudo pacman -S ffmpeg',
        'suse': 'sudo zypper install ffmpeg',
      },
    ),
    DependencyDescriptor(
      id: 'qpdf',
      name: 'qpdf',
      affectedStudios: {StudioType.pdfStudio},
      installCommands: {
        'debian': 'sudo apt install qpdf',
        'fedora': 'sudo dnf install qpdf',
        'arch': 'sudo pacman -S qpdf',
        'suse': 'sudo zypper install qpdf',
      },
    ),
    DependencyDescriptor(
      id: 'libreoffice',
      name: 'LibreOffice',
      affectedStudios: {StudioType.documentStudio},
      installCommands: {
        'debian': 'sudo apt install libreoffice',
        'fedora': 'sudo dnf install libreoffice',
        'arch': 'sudo pacman -S libreoffice-still',
        'suse': 'sudo zypper install libreoffice',
      },
    ),
  ];

  /// Run detection for all dependencies.
  Future<void> initialize() async {
    if (!Platform.isLinux) {
      _isInitialized = true;
      notifyListeners();
      return;
    }

    for (final dep in _linuxDependencies) {
      _dependencies[dep.id] = await _checkDependency(dep);
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Recheck a single dependency (e.g. after user installs it).
  Future<void> recheckDependency(String id) async {
    final dep = _dependencies[id];
    if (dep == null) return;
    _dependencies[id] = await _checkDependency(dep);
    notifyListeners();
  }

  /// Recheck all dependencies.
  Future<void> recheckAll() async {
    for (final dep in _linuxDependencies) {
      _dependencies[dep.id] = await _checkDependency(dep);
    }
    notifyListeners();
  }

  /// Whether a specific studio has all its dependencies met.
  bool isStudioAvailable(StudioType studio) {
    return _dependencies.values
        .where((d) => d.affectedStudios.contains(studio))
        .every((d) => d.status.isUsable);
  }

  /// Get the install command for a dependency on the current distro.
  String? getInstallCommand(String depId, DistroFamily family) {
    final dep = _dependencies[depId];
    if (dep == null) return null;
    return dep.installCommands[family.name];
  }

  Future<DependencyDescriptor> _checkDependency(
    DependencyDescriptor dep,
  ) async {
    try {
      final result = await Process.run('which', [dep.id]);
      if (result.exitCode != 0) {
        return dep.copyWith(status: DependencyStatus.missing);
      }

      final execPath = result.stdout.toString().trim();

      // Try to get version
      String? version;
      try {
        final vResult = await Process.run(dep.id, ['--version']);
        final output = vResult.stdout.toString() + vResult.stderr.toString();
        // Extract first line as version info
        version = output.split('\n').first.trim();
      } catch (_) {}

      return dep.copyWith(
        status: DependencyStatus.installed,
        executablePath: execPath,
        version: version,
      );
    } catch (_) {
      return dep.copyWith(status: DependencyStatus.missing);
    }
  }
}
