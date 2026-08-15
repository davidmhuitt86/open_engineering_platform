import 'package:flutter/widgets.dart';

/// WP-DS-005A Engineering Instruments Framework — the contract every
/// permanent instrument (Digital Multimeter first; Oscilloscope, Logic
/// Probe, Power Probe, CAN Analyzer, LIN Analyzer, Breakout Box, Signal
/// Generator, Bench Power Supply, Clamp Meter later) implements to appear
/// in the Instrument Dock.
///
/// Architectural boundary (governing spec, "Architectural Principles"):
/// an [EngineeringInstrument] is a presentation/interaction component
/// only. It never computes an engineering measurement itself — every
/// reading is requested from the Simulation Engine (via
/// `DiagramSimulationService.measure`) and only rendered here.
abstract class EngineeringInstrument {
  const EngineeringInstrument();

  /// Stable identifier — used as the dock tab key and in persisted dock
  /// layout state, so it must never change once shipped.
  String get id;

  /// Short display name shown on the dock tab / toolbar entry.
  String get title;

  IconData get icon;

  /// Optional keyboard shortcut label shown in tooltips (e.g. "Ctrl+M").
  /// Framework responsibility only — actual shortcut binding is wired by
  /// the host page (`diagram_studio_page.dart`), which owns the app's one
  /// `Shortcuts`/`Actions` scope; this is a display hint only.
  String? get shortcutLabel => null;

  /// Builds this instrument's panel content, shown inside the Instrument
  /// Dock (bottom dock or floating window) when this instrument's tab is
  /// active.
  Widget buildPanel(BuildContext context);
}

/// Registers every [EngineeringInstrument] available to the current
/// Diagram Studio session and notifies listeners (the Instrument Dock,
/// the toolbar) when the set changes — e.g. a Studio-scoped plugin
/// registering a new instrument at runtime.
///
/// One [InstrumentRegistry] per Diagram Studio page, matching this
/// codebase's established "one Engine/one Service per diagram" pattern
/// (`DiagramSimulationService`, `DiagramIntelligenceService`).
class InstrumentRegistry extends ChangeNotifier {
  final Map<String, EngineeringInstrument> _instruments = {};

  List<EngineeringInstrument> get all => List.unmodifiable(_instruments.values);

  EngineeringInstrument? byId(String id) => _instruments[id];

  bool get isEmpty => _instruments.isEmpty;

  void register(EngineeringInstrument instrument) {
    if (_instruments.containsKey(instrument.id)) {
      throw StateError('InstrumentRegistry: an instrument with id "${instrument.id}" is already registered.');
    }
    _instruments[instrument.id] = instrument;
    notifyListeners();
  }

  void unregister(String id) {
    if (_instruments.remove(id) != null) notifyListeners();
  }
}
