import 'package:flutter/services.dart' show rootBundle;
import 'package:engineering_engine/engineering_engine.dart';

/// The 14 seed symbols shipped under `engineering_engine`'s
/// `assets/symbols/` (SDD-028) — the same list the Engineering Engine
/// Demonstration Host uses, since both consume the exact same package
/// assets.
const List<String> _seedSymbolIdentifiers = [
  'battery',
  'ground',
  'fuse',
  'relay',
  'spst_switch',
  'spdt_switch',
  'connector',
  'lamp',
  'motor',
  'resistor',
  'capacitor',
  'diode',
  'ignition_coil',
  'generic_module',
];

/// Thin Engine lifecycle wrapper (WORK_PACKAGE_024, ENGINE-TASK-000109):
/// Engine initialization, provider wiring (delegated entirely to
/// `EngineeringEngine.create()`), session creation, and session
/// disposal. No engineering logic of its own — every other Diagram
/// Studio concern (editing, selection, search, routing, validation, ...)
/// calls straight through to [engine], which already exposes all of it
/// via its public API. This class exists only so Diagram Studio has one
/// place to create/tear down the Engine, not to wrap or reinterpret it.
class EngineHost {
  final EngineeringEngine engine;

  EngineHost._(this.engine);

  /// Creates and initializes an [EngineeringEngine] with its default
  /// providers (`EngineeringEngine.create()`), then loads the seed
  /// Symbol Library through Flutter's asset bundle — `SymbolLibrary`
  /// itself stays Flutter-independent (SDD-025/026), so this is the one
  /// place a Studio-specific loading mechanism (`rootBundle`, as opposed
  /// to `dart:io` directory scanning) is needed.
  ///
  /// AP-OEP-FOUNDATION-BRIDGE-001 — [foundationBridge], when supplied,
  /// is registered into [EngineeringEngine.registry] right here, the
  /// same "provider wiring" spot every other provider goes through
  /// (`EngineeringEngine.create()` itself). `null` is the normal case
  /// when no Foundation runtime is available yet — `EngineRegistry.
  /// foundationBridge` is nullable for exactly this reason (SDD-025:
  /// the Engine must operate fine with no bridge registered at all).
  static Future<EngineHost> create({FoundationBridgePort? foundationBridge}) async {
    final engine = EngineeringEngine.create();
    await engine.initialize();
    if (foundationBridge != null) {
      engine.registry.register<FoundationBridgePort>(foundationBridge);
    }
    final symbols = engine.registry.symbols;
    if (symbols is SymbolLibrary) {
      for (final identifier in _seedSymbolIdentifiers) {
        final raw = await rootBundle.loadString(
          'packages/engineering_engine/assets/symbols/$identifier.json',
        );
        symbols.registerFromJson(raw);
      }
    }
    return EngineHost._(engine);
  }

  /// Starts (or restarts) an undoable editing session against [graph] —
  /// a direct passthrough to `EngineeringEngine.beginEditingSession`.
  EditingSession beginSession(EngineeringGraph graph) => engine.beginEditingSession(graph);

  /// Tears down the Engine — a direct passthrough to
  /// `EngineeringEngine.shutdown`.
  Future<void> dispose() => engine.shutdown();
}
