import '../../../core/graph/models/engineering_node.dart';
import '../../../core/simulation/electrical/electrical_component_behavior.dart';
import '../../../core/simulation/electrical/electrical_node_roles.dart';
import '../../../core/simulation/electrical/electrical_operating_context.dart';
import '../../../core/simulation/electrical/electrical_reading.dart';

/// PRODUCT-READINESS-008 §11/§12/§16 — the REAL TRX300 ignition/handlebar
/// switch continuity data, moved here from what was previously test-only
/// fixture data (`electrical_solver_trx300_test.dart`, PRODUCT-READINESS-006)
/// so both that test AND the real production V2 bridge
/// (`platform/oep_studio/lib/diagram_studio/webview/`) import the SAME
/// single copy — never two independently-maintained tables (§11: "Do not
/// duplicate the TRX300 switch tables in Dart").
///
/// **This is TRX300-specific REFERENCE DATA, not generic solver logic**
/// (§11's own explicit requirement: "The Engine should remain generic" —
/// `ElectricalSolver`/`ElectricalResistiveNetwork` themselves have no idea
/// what an "ignition switch" is; this file exists purely as data a CALLER
/// supplies via `ElectricalBehaviorResolver`, the same contract point
/// every other component behavior in this codebase uses). Values are
/// verbatim from the Legacy V2 JS reference
/// (`reference/legacy_wiring_sim_v2/eke-wiring-sim/js/knowledge/behaviors/multi-switch.js`'s
/// own `MultiSwitchBehavior.DEFS`) — not invented.
///
/// **Why these are NOT [MultiPositionSwitchElectricalBehavior]**: that
/// class looks up a precomputed `closedPairsForPosition` table by the
/// EXACT `context.activeInputStates[switchId]` value as a Map key —
/// correct for a single, hashable position value (a String, a Record),
/// but the real, live V2 operating-state bridge
/// (`LegacyV2StateAdapter.currentOperatingContext`) supplies a
/// `Map<String, Object?>` of that switch's own real group/position data
/// (e.g. `{'lights': 'on', 'dimmer': 'lo', ...}`) — a plain Dart `Map` has
/// no value equality, so it can never match a table key by content. These
/// classes instead read the specific named group(s) they care about
/// directly out of that map on every call — exactly the same real
/// continuity logic, just computed inline instead of via a precomputed
/// table, and now genuinely usable against LIVE, dynamically-changing V2
/// state, not just a fixed enumerated set of test positions.
String _portIdForName(EngineeringNode node, String name) =>
    node.ports.firstWhere((p) => p.name.toUpperCase() == name.toUpperCase()).id;

/// The real TRX300 Ignition Switch: terminals `BAT1`/`BAT2`/`BAT3`/`IG1`;
/// closed pairs `{(BAT1,BAT2), (BAT3,IG1)}` only when the `power` group
/// (V2's own key-position group name) is `'on'`.
class Trx300IgnitionSwitchBehavior extends ElectricalComponentBehavior {
  const Trx300IgnitionSwitchBehavior({required this.switchId});

  final String switchId;

  @override
  bool appliesTo(EngineeringNode node) => node.id == switchId;

  Set<ElectricalTerminalPair> _pairsFor(EngineeringNode node, Object? rawState) {
    final power = rawState is Map ? rawState['power'] as Object? : null;
    if (power != 'on') return const {};
    String id(String name) => _portIdForName(node, name);
    return {
      ElectricalTerminalPair(id('BAT1'), id('BAT2')),
      ElectricalTerminalPair(id('BAT3'), id('IG1')),
    };
  }

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      _pairsFor(node, context.activeInputStates[switchId]);

  @override
  Set<ElectricalTerminalPair> physicallyConnectableTerminalPairs(EngineeringNode node) =>
      _pairsFor(node, const {'power': 'on'});

  @override
  ElectricalReading resistanceBetween(EngineeringNode node, String terminalA, String terminalB, ElectricalOperatingContext context) =>
      conductingTerminalPairs(node, context).contains(ElectricalTerminalPair(terminalA, terminalB))
          ? ElectricalReading.valid(0.1, unit: 'Ω')
          : ElectricalReading.open(note: 'Ignition switch is not in a position that bridges this pair.');
}

/// The real TRX300 Left Handlebar Switch: bundles FOUR independent groups
/// (`lights`/`dimmer`/`engineStop`/`starter`) on one physical switch —
/// terminals `BAT2`/`TL`/`LO`/`HI`/`IG1`/`IG2`/`ST`.
class Trx300HandlebarSwitchBehavior extends ElectricalComponentBehavior {
  const Trx300HandlebarSwitchBehavior({required this.switchId});

  final String switchId;

  @override
  bool appliesTo(EngineeringNode node) => node.id == switchId;

  Set<ElectricalTerminalPair> _pairsFor(EngineeringNode node, Object? rawState) {
    final state = rawState is Map ? rawState : const {};
    String id(String name) => _portIdForName(node, name);
    final pairs = <ElectricalTerminalPair>{};
    if (state['lights'] == 'on') {
      pairs.add(ElectricalTerminalPair(id('BAT2'), id('TL')));
      pairs.add(state['dimmer'] == 'lo' ? ElectricalTerminalPair(id('BAT2'), id('LO')) : ElectricalTerminalPair(id('BAT2'), id('HI')));
    }
    if (state['engineStop'] == 'run') pairs.add(ElectricalTerminalPair(id('IG1'), id('IG2')));
    if (state['starter'] == 'push') pairs.add(ElectricalTerminalPair(id('BAT2'), id('ST')));
    return pairs;
  }

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      _pairsFor(node, context.activeInputStates[switchId]);

  /// Union of every group's own possible pair — every position this
  /// switch could ever be in, regardless of current state (PR-005 §4.1's
  /// own "structural capacity" concept).
  @override
  Set<ElectricalTerminalPair> physicallyConnectableTerminalPairs(EngineeringNode node) {
    String id(String name) => _portIdForName(node, name);
    return {
      ElectricalTerminalPair(id('BAT2'), id('TL')),
      ElectricalTerminalPair(id('BAT2'), id('LO')),
      ElectricalTerminalPair(id('BAT2'), id('HI')),
      ElectricalTerminalPair(id('IG1'), id('IG2')),
      ElectricalTerminalPair(id('BAT2'), id('ST')),
    };
  }

  @override
  ElectricalReading resistanceBetween(EngineeringNode node, String terminalA, String terminalB, ElectricalOperatingContext context) =>
      conductingTerminalPairs(node, context).contains(ElectricalTerminalPair(terminalA, terminalB))
          ? ElectricalReading.valid(0.1, unit: 'Ω')
          : ElectricalReading.open(note: 'Handlebar switch is not in a position that bridges this pair.');
}

/// Real, disclosed Legacy V2 lamp-filament resistance constant
/// (`LampBehavior.HOT_RESISTANCE`, `js/knowledge/behaviors/lamp.js`) —
/// re-exported here so production code and tests share the one real
/// number rather than each hardcoding `120` independently.
const num trx300LampHotResistanceOhms = 120;

bool _hasTerminalNames(EngineeringNode node, Set<String> names) {
  final have = node.ports.map((p) => p.name.toUpperCase()).toSet();
  return names.map((n) => n.toUpperCase()).every(have.contains);
}

/// PRODUCT-READINESS-008 §11/§12 — a real, GENERIC-by-terminal-signature
/// dispatcher (matching the Legacy V2 JS reference's own
/// `MultiSwitchBehavior.match()` technique: "recognize by real terminal
/// names, never by a hardcoded node id" — the same discipline
/// `ElectricalSolver`/`ElectricalResistiveNetwork` themselves already
/// require of every behavior resolver in this codebase). Any diagram
/// whose components carry these SAME real terminal-name sets gets the
/// SAME real behavior — not specific to whatever node id happens to be
/// assigned in one particular saved file.
///
/// Recognizes: the real Ignition Switch (`BAT1`/`BAT2`/`BAT3`/`IG1`), the
/// real Left Handlebar Switch (`BAT2`/`TL`/`LO`/`HI`/`IG1`/`IG2`/`ST`),
/// the real dual-filament headlight (`GND`/`LO`/`Hi`, real 120Ω filament
/// resistance per terminal pair — never a single value shared across all
/// three terminals, §26), plus the generic splice/connector roles every
/// diagram already gets via [defaultElectricalBehaviorFor]. Returns
/// `null` (never fabricated) for anything else.
ElectricalComponentBehavior? trx300ElectricalBehaviorFor(EngineeringNode node) {
  if (_hasTerminalNames(node, const {'BAT1', 'BAT2', 'BAT3', 'IG1'})) {
    return Trx300IgnitionSwitchBehavior(switchId: node.id);
  }
  if (_hasTerminalNames(node, const {'BAT2', 'TL', 'LO', 'HI', 'IG1', 'IG2', 'ST'})) {
    return Trx300HandlebarSwitchBehavior(switchId: node.id);
  }
  if (_hasTerminalNames(node, const {'GND', 'LO', 'HI'})) {
    String id(String name) => node.ports.firstWhere((p) => p.name.toUpperCase() == name.toUpperCase()).id;
    return MultiTerminalResistiveLoadElectricalComponentBehavior(resistanceOhmsByPair: {
      ElectricalTerminalPair(id('GND'), id('LO')): trx300LampHotResistanceOhms,
      ElectricalTerminalPair(id('GND'), id('HI')): trx300LampHotResistanceOhms,
    });
  }
  return defaultElectricalBehaviorFor(node);
}

/// Real, disclosed Legacy V2 key-ON battery resting voltage constant
/// (`BatteryBehavior.VOLTAGE[1]`, `js/knowledge/behaviors/battery.js`).
/// The real, production `diagram7.json` Battery node has no
/// `properties['nominalVoltageV']` authored at all (confirmed,
/// PRODUCT-READINESS-006/006B) — a caller supplies this value via its own
/// `ElectricalSourceVoltageResolver` rather than the solver fabricating
/// one.
const num trx300BatteryKeyOnVoltage = 12.6;
