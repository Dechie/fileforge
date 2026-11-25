import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/infrastructure/engines/linux/linux_engine_setup.dart';

/// Manages the registry of available processing engines and selects
/// the best engine for a given operation.
class EngineProvider extends ChangeNotifier {
  final List<EngineDescriptor> _engines = [];
  bool _isInitialized = false;

  List<EngineDescriptor> get engines => List.unmodifiable(_engines);
  bool get isInitialized => _isInitialized;

  /// Register an engine.
  void registerEngine(EngineDescriptor engine) {
    _replace(engine);
    notifyListeners();
  }

  /// Register several engines and notify once.
  void registerEngines(Iterable<EngineDescriptor> engines) {
    for (final engine in engines) {
      _replace(engine);
    }
    notifyListeners();
  }

  void _replace(EngineDescriptor engine) {
    _engines.removeWhere((existing) => existing.id == engine.id);
    _engines.add(engine);
  }

  /// Find the best engine for the given operation and format requirements.
  EngineDescriptor? selectEngine({
    required OperationType operation,
    FileFormat? inputFormat,
    FileFormat? outputFormat,
    AppPlatform? platform,
  }) {
    final candidates =
        _engines.where((e) {
          if (!e.isInstalled) return false;
          if (platform != null && !e.platforms.contains(platform)) return false;
          return e.canHandle(
            operation: operation,
            inputFormat: inputFormat,
            outputFormat: outputFormat,
          );
        }).toList();

    if (candidates.isEmpty) return null;

    // Return the first match; in the future, rank by preference/quality.
    return candidates.first;
  }

  /// Get all engines that support a specific operation.
  List<EngineDescriptor> enginesForOperation(OperationType operation) {
    return _engines
        .where(
          (e) => e.isInstalled && e.supportedOperations.contains(operation),
        )
        .toList();
  }

  Future<void> initialize() async {
    if (Platform.isLinux) {
      registerEngines(await discoverLinuxEngines());
    }
    _isInitialized = true;
    notifyListeners();
  }
}
