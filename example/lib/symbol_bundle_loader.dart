import 'package:flutter/services.dart' show rootBundle;
import 'package:engineering_engine/engineering_engine.dart';

/// The 14 seed symbols shipped under `assets/symbols/` (SDD-028).
const List<String> seedSymbolIdentifiers = [
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

/// Loads the seed [SymbolDefinition]s via Flutter's asset bundle.
///
/// `SymbolLibrary.initialize()` scans a real filesystem directory with
/// `dart:io` — correct for plain-Dart contexts (tests, tooling) but not for
/// a bundled Flutter app, where assets are packed into the bundle rather
/// than left as loose files. This host loads the same JSON content through
/// `rootBundle` instead and registers it via `registerFromJson`, so the
/// Engineering Engine core never needs to know about Flutter's asset
/// system.
Future<void> loadBundledSymbols(SymbolLibrary symbols) async {
  for (final identifier in seedSymbolIdentifiers) {
    final raw = await rootBundle.loadString(
      'packages/engineering_engine/assets/symbols/$identifier.json',
    );
    symbols.registerFromJson(raw);
  }
}
