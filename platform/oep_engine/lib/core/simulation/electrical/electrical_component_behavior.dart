import '../../graph/models/engineering_node.dart';
import 'electrical_operating_context.dart';
import 'electrical_reading.dart';

/// PRODUCT-READINESS-005/006 — resolves a component's electrical behavior
/// for trace/solve purposes. A caller supplies real behaviors for whatever
/// component types their diagram actually uses (PRODUCT-READINESS-004 §8:
/// "this phase does not implement every component type"). `null` means
/// "no specific behavior known for this node." Shared by [TraceEngine] and
/// [ElectricalSolver] (its natural home is here, alongside the contract
/// itself, rather than duplicated in both consumers).
typedef ElectricalBehaviorResolver = ElectricalComponentBehavior? Function(EngineeringNode node);

/// PRODUCT-READINESS-004 Phase A, §8 — an unordered pair of terminal ids
/// on the SAME component (§3: "two terminals belonging to the same
/// component" are not automatically electrically equivalent — this is the
/// value type that lets a behavior explicitly assert which pairs ARE,
/// under the current operating state, without implying every other pair
/// is too).
class ElectricalTerminalPair {
  ElectricalTerminalPair(String a, String b)
      : terminalA = (a.compareTo(b) <= 0) ? a : b,
        terminalB = (a.compareTo(b) <= 0) ? b : a;

  final String terminalA;
  final String terminalB;

  bool contains(String terminalId) => terminalId == terminalA || terminalId == terminalB;

  @override
  bool operator ==(Object other) =>
      other is ElectricalTerminalPair && other.terminalA == terminalA && other.terminalB == terminalB;

  @override
  int get hashCode => Object.hash(terminalA, terminalB);

  @override
  String toString() => 'ElectricalTerminalPair($terminalA, $terminalB)';
}

/// PRODUCT-READINESS-004 Phase A, §8 — the contract between component
/// behavior and the (future) solution engine.
///
/// **This phase does not implement every component type** (§8's own
/// instruction) — the Legacy V2 behaviors (`MultiSwitchBehavior`,
/// `LampBehavior`, `MotorBehavior`, `DiodeBehavior`,
/// `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/knowledge/behaviors/`)
/// remain the authoritative REFERENCE for what each of these answers
/// should be for the TRX300 (§15) — this interface exists so a future Dart
/// solver has a real, tested contract those behaviors' EQUIVALENT logic
/// can be ported behind, one component type at a time, without needing to
/// invent the contract shape at that point. See
/// `PassThroughElectricalComponentBehavior`/`DeadEndElectricalComponentBehavior`
/// below for the two minimal reference implementations this phase adds
/// purely to prove the contract is real and usable (connector/splice-style
/// same-pin passthrough, and lamp/motor-style dead-end — the two
/// generalized rules PRODUCT-READINESS-002 already proved correct for the
/// Legacy V2 solver, per that work package's `AP-CONNECTOR-BRIDGE-001`/
/// `AP-DEADEND-GENERALIZE-001`).
abstract class ElectricalComponentBehavior {
  const ElectricalComponentBehavior();

  /// Whether this behavior applies to [node] at all — a solver would
  /// consult behaviors in some priority order and use the first one whose
  /// [appliesTo] returns true (mirroring the Legacy V2
  /// `ComponentBehaviors.getEdgeBehavior`'s own dispatch-by-type shape,
  /// `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/knowledge/behaviors/index.js`).
  bool appliesTo(EngineeringNode node);

  /// The terminal ids this component exposes — by default, every
  /// [Port.id] already on [node] (`EngineeringNode.ports`); a behavior may
  /// override this only if it needs to expose terminals the graph model
  /// doesn't otherwise carry (expected to be rare).
  List<String> terminalIds(EngineeringNode node) => node.ports.map((p) => p.id).toList(growable: false);

  /// PRODUCT-READINESS-006 §9 additive extension — whether current is
  /// permitted to flow specifically FROM [fromTerminalId] TO
  /// [toTerminalId] (order matters) under [context]. Defaults to the
  /// order-AGNOSTIC [conductingTerminalPairs] check (correct for every
  /// non-directional component — [ElectricalTerminalPair] is itself
  /// unordered, matching how a switch/connector/splice conducts equally
  /// both ways). [isDirectional] behaviors (a diode) MUST override this
  /// to enforce their real one-way conduction — [ElectricalTerminalPair]
  /// alone cannot encode direction, which is exactly why this exists
  /// rather than trying to overload that type. The solver's own terminal-
  /// BFS calls this (not [conductingTerminalPairs] directly) whenever
  /// direction could matter, so a diode is never silently treated as
  /// bidirectional.
  bool conductsFrom(EngineeringNode node, String fromTerminalId, String toTerminalId, ElectricalOperatingContext context) =>
      conductingTerminalPairs(node, context).contains(ElectricalTerminalPair(fromTerminalId, toTerminalId));

  /// Which pairs of [node]'s own terminals are electrically bridged
  /// together under [context]'s current operating/input state (§3: "Do not
  /// collapse terminals belonging to the same component unless the
  /// component behavior explicitly defines them as electrically
  /// equivalent"). Empty by default (§21 "do not overbuild" — a behavior
  /// that has nothing to say about internal bridging, e.g. a component
  /// this contract has no specific model for yet, conducts nothing rather
  /// than everything).
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      const {};

  /// The resistance between [terminalA] and [terminalB] on [node] under
  /// [context], or an appropriately-stated [ElectricalReading] (e.g.
  /// [ElectricalReading.open] when the pair is not in
  /// [conductingTerminalPairs], [ElectricalReading.unsupported] when this
  /// behavior has no resistance model at all). Never fabricated —
  /// matching PRODUCT-READINESS-004's own audit finding that "do not
  /// invent component parameters" applies here just as much as to the
  /// existing Legacy V2 behaviors' own hand-authored constants.
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  );

  /// PRODUCT-READINESS-005, §29 additive extension — every terminal pair
  /// this component could EVER bridge, across every operating state it has
  /// a defined position for. This is the state-INDEPENDENT "structural
  /// capacity to conduct" a Physical Topology Trace needs (PRODUCT-
  /// READINESS-005 §4.1's own worked example: an OPEN switch is still part
  /// of the physical chain from battery to headlight — physical topology
  /// answers "is there a wire path," not "is it presently active").
  ///
  /// Defaults to [conductingTerminalPairs] evaluated against
  /// [ElectricalOperatingContext.none] — exactly correct for a state-
  /// INDEPENDENT behavior (a splice/connector's own [conductingTerminalPairs]
  /// never reads its `context` argument at all, so this default degenerates
  /// to the same always-true answer either way) and a deliberately
  /// conservative default for a state-DEPENDENT one (a real switch
  /// behavior should override this to return the UNION of every position's
  /// own pairs, since [ElectricalOperatingContext.none] alone under-reports
  /// what a switch could ever bridge).
  ///
  /// This was added rather than modifying [conductingTerminalPairs] itself
  /// (PRODUCT-READINESS-004's own established contract) because the two
  /// methods answer genuinely different questions — "what does this
  /// component do RIGHT NOW" vs. "what is this component STRUCTURALLY
  /// capable of" — and PRODUCT-READINESS-005 §4 requires both to be
  /// independently answerable. Purely additive: existing callers of
  /// [conductingTerminalPairs] are unaffected; existing subclasses need no
  /// changes since this has a working default.
  Set<ElectricalTerminalPair> physicallyConnectableTerminalPairs(EngineeringNode node) =>
      conductingTerminalPairs(node, ElectricalOperatingContext.none);

  /// Whether current can only flow one way between this component's
  /// terminals (true for a diode; false for everything else this phase
  /// models). Defaults to `false`.
  bool get isDirectional => false;

  /// Whether this component is itself a source of electrical energy
  /// (true for a battery/alternator-type component). Defaults to `false`.
  bool get generatesPower => false;
}

/// A minimal reference implementation matching the Legacy V2 solver's own
/// proven "connector/splice-style same-pin passthrough" rule
/// (`AP-CONNECTOR-BRIDGE-001`/`AP-DEADEND-GENERALIZE-001`, PRODUCT-
/// READINESS-002): every terminal conducts only to another wire landing on
/// the SAME physical pin, never to a different one — appropriate for a
/// connector housing, or any component with no more specific behavior
/// (§9 of PRODUCT-READINESS-002's own regression suite covers exactly this
/// invariant on the JS side; this is the Dart-side CONTRACT that same
/// invariant would be expressed through, not a reimplementation of the JS
/// solver's own math).
class PassThroughElectricalComponentBehavior extends ElectricalComponentBehavior {
  const PassThroughElectricalComponentBehavior();

  @override
  bool appliesTo(EngineeringNode node) => node.category == NodeCategory.connector;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      const {}; // Same-pin-only: no two DIFFERENT terminal ids are ever bridged by a connector.

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      terminalA == terminalB
          ? ElectricalReading.valid(0, unit: 'Ω', note: 'Same physical pin — direct passthrough.')
          : ElectricalReading.open(note: 'Connector: different pins are not electrically joined.');
}

/// A minimal reference implementation matching the Legacy V2 solver's own
/// proven "lamp/motor-style dead end" rule (`AP-LAMP-TUNNEL-001`,
/// PRODUCT-READINESS-002): a real two-terminal load never bridges its own
/// power and return terminals together (that bridging is exactly what
/// makes it a LOAD rather than a plain conductor) — its own internal
/// resistance is a property of the component, never modeled as "pass" or
/// "open" between its own two terminals directly.
class DeadEndElectricalComponentBehavior extends ElectricalComponentBehavior {
  const DeadEndElectricalComponentBehavior();

  @override
  bool appliesTo(EngineeringNode node) => false; // Reference-only; a real caller supplies its own appliesTo.

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      const {}; // A load's own terminals are never mutually bridged.

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      ElectricalReading.unsupported(note: 'Load resistance is a component property, not a terminal-to-terminal path.');
}

/// PRODUCT-READINESS-005 — a minimal reference implementation matching the
/// Legacy V2 solver's own proven splice semantics (`js/simulation/
/// voltage-propagator.js`'s own explicit `if (m.cat === 'splice') return
/// false;` exclusion from same-pin gating, PRODUCT-READINESS-002): a
/// splice is a true, unconditional, state-independent electrical junction
/// — EVERY terminal on it bridges to every other, in every operating
/// state — the direct opposite of [PassThroughElectricalComponentBehavior]'s
/// same-pin-only rule, and the reason PRODUCT-READINESS-005 §11/§12
/// insists the two must never be treated as equivalent.
class AlwaysBridgeElectricalComponentBehavior extends ElectricalComponentBehavior {
  const AlwaysBridgeElectricalComponentBehavior();

  @override
  bool appliesTo(EngineeringNode node) => false; // Reference-only; a real caller supplies its own appliesTo.

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) {
    final terminals = terminalIds(node);
    final pairs = <ElectricalTerminalPair>{};
    for (var i = 0; i < terminals.length; i++) {
      for (var j = i + 1; j < terminals.length; j++) {
        pairs.add(ElectricalTerminalPair(terminals[i], terminals[j]));
      }
    }
    return pairs;
  }

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      ElectricalReading.valid(0, unit: 'Ω', note: 'Splice — unconditional junction.');
}

/// PRODUCT-READINESS-006 §9 — a plain, always-conducting inline component
/// (an intact fuse, or any simple 2-terminal pass-through part that is not
/// itself state-gated). Bridges its own two terminals unconditionally, in
/// both physical and conducting/current-flow modes — the generic
/// counterpart of a real wire's own near-zero resistance
/// (`ComponentBehaviors.wireResistance`'s own "all copper wire is
/// essentially 0Ω" convention, `reference/legacy_wiring_sim_v2/`).
/// Matched by [appliesTo] via [terminalIds] having exactly two entries and
/// [node.category] being [NodeCategory.fuse] by default — a caller may
/// construct this directly for any node it knows is a plain inline part,
/// rather than relying on that default.
class InlinePassThroughElectricalComponentBehavior extends ElectricalComponentBehavior {
  const InlinePassThroughElectricalComponentBehavior({this.resistanceOhms = 0.1});

  /// Near-zero by default, matching the Legacy V2 solver's own
  /// `wireResistance` default for an intact conductor (`0.1Ω`) — never
  /// exactly `0` so a real (if tiny) voltage-drop/current calculation
  /// stays well-defined rather than dividing by zero.
  final num resistanceOhms;

  @override
  bool appliesTo(EngineeringNode node) => node.category == NodeCategory.fuse && terminalIds(node).length == 2;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) {
    final terminals = terminalIds(node);
    return terminals.length == 2 ? {ElectricalTerminalPair(terminals[0], terminals[1])} : const {};
  }

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      conductingTerminalPairs(node, context).contains(ElectricalTerminalPair(terminalA, terminalB))
          ? ElectricalReading.valid(resistanceOhms, unit: 'Ω')
          : ElectricalReading.open();
}

/// PRODUCT-READINESS-006 §9/§13 — a generic, state-dependent 2-terminal
/// switch. Conducts its own two terminals only when
/// `context.activeInputStates[switchId] == closedValue` — [switchId]
/// (typically the switch's own [EngineeringNode.id], per this class's own
/// constructor doc) and [closedValue] are supplied by the CALLER when
/// resolving a real diagram's real switches (§33: never hardcoded into
/// this generic class itself). No domain terminology ("ignition,"
/// "kill switch," ...) appears here — this is the same generic mechanism
/// for every 2-position switch in any diagram.
class SwitchElectricalBehavior extends ElectricalComponentBehavior {
  const SwitchElectricalBehavior({required this.switchId, this.closedValue = true, this.closedResistanceOhms = 0.1});

  /// The key looked up in [ElectricalOperatingContext.activeInputStates] —
  /// conventionally the switch's own [EngineeringNode.id] (no separate id
  /// scheme is required), but any caller-chosen key works.
  final String switchId;

  /// The value [switchId] must hold in `activeInputStates` for this switch
  /// to be closed — `true`/`false` for a simple on/off switch, or any
  /// other value (a String position label, etc.) for one of several
  /// discrete states a caller models this way.
  final Object? closedValue;

  final num closedResistanceOhms;

  @override
  bool appliesTo(EngineeringNode node) => node.id == switchId;

  bool _isClosed(ElectricalOperatingContext context) => context.activeInputStates[switchId] == closedValue;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) {
    if (!_isClosed(context)) return const {};
    final terminals = terminalIds(node);
    return terminals.length == 2 ? {ElectricalTerminalPair(terminals[0], terminals[1])} : const {};
  }

  /// §4.1 (PRODUCT-READINESS-005) — an open switch is still part of the
  /// PHYSICAL chain; this is the structural-capacity override that makes
  /// that true regardless of [closedValue]'s current runtime value.
  @override
  Set<ElectricalTerminalPair> physicallyConnectableTerminalPairs(EngineeringNode node) {
    final terminals = terminalIds(node);
    return terminals.length == 2 ? {ElectricalTerminalPair(terminals[0], terminals[1])} : const {};
  }

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      conductingTerminalPairs(node, context).contains(ElectricalTerminalPair(terminalA, terminalB))
          ? ElectricalReading.valid(closedResistanceOhms, unit: 'Ω')
          : ElectricalReading.open(note: 'Switch is open.');
}

/// PRODUCT-READINESS-006 §9/§13 — a generic, DATA-DRIVEN multi-position
/// switch, matching the Legacy V2 solver's own proven `MultiSwitchBehavior`
/// design (`js/knowledge/behaviors/multi-switch.js`, PRODUCT-READINESS-002
/// `AP-MULTI-SWITCH-001`): recognized and configured entirely by data
/// (terminal names + a position->closed-pairs table) supplied by the
/// CALLER, never by hardcoding a real switch's identity into this class.
///
/// [positionKey] reads the switch's current discrete position from
/// [ElectricalOperatingContext.activeInputStates] (again, conventionally
/// the switch's own node id, matching [SwitchElectricalBehavior]'s
/// convention). [closedPairsForPosition] maps that position's value to
/// the set of this SAME component's own terminal pairs bridged while it
/// holds that position — e.g. the real TRX300 ignition switch's own real
/// table (`{'off': {}, 'on': {(BAT1,BAT2), (BAT3,IG1)}}`) is exactly this
/// shape, supplied as DATA by a TRX300-specific reference fixture, never
/// written into this generic class.
class MultiPositionSwitchElectricalBehavior extends ElectricalComponentBehavior {
  const MultiPositionSwitchElectricalBehavior({
    required this.switchId,
    required this.closedPairsForPosition,
    this.closedResistanceOhms = 0.1,
  });

  final String switchId;
  final Map<Object?, Set<ElectricalTerminalPair>> closedPairsForPosition;
  final num closedResistanceOhms;

  @override
  bool appliesTo(EngineeringNode node) => node.id == switchId;

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      closedPairsForPosition[context.activeInputStates[switchId]] ?? const {};

  /// §4.1 — structurally, ANY pair this switch could ever bridge in ANY
  /// position is part of the physical chain, regardless of which position
  /// is currently active.
  @override
  Set<ElectricalTerminalPair> physicallyConnectableTerminalPairs(EngineeringNode node) =>
      closedPairsForPosition.values.expand((pairs) => pairs).toSet();

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      conductingTerminalPairs(node, context).contains(ElectricalTerminalPair(terminalA, terminalB))
          ? ElectricalReading.valid(closedResistanceOhms, unit: 'Ω')
          : ElectricalReading.open(note: 'This terminal pair is not closed in the current position.');
}

/// PRODUCT-READINESS-006 §9 — a generic diode: conducts one direction
/// only, with a real, small forward voltage drop, matching the Legacy V2
/// solver's own `DiodeBehavior` constants (`FORWARD_DROP_SILICON = 0.65V`,
/// `reference/legacy_wiring_sim_v2/eke-wiring-sim/js/knowledge/behaviors/diode.js`)
/// — not reinvented, carried over as the same real, disclosed constant.
/// [anodeTerminalId]/[cathodeTerminalId] identify which of the diode's own
/// two terminals is which — supplied by the caller (§33: never inferred
/// from a hardcoded id), matching this component's own real polarity.
class DiodeElectricalBehavior extends ElectricalComponentBehavior {
  const DiodeElectricalBehavior({
    required this.anodeTerminalId,
    required this.cathodeTerminalId,
    this.forwardDropVolts = 0.65,
  });

  final String anodeTerminalId;
  final String cathodeTerminalId;
  final num forwardDropVolts;

  @override
  bool get isDirectional => true;

  @override
  bool appliesTo(EngineeringNode node) =>
      terminalIds(node).toSet().containsAll({anodeTerminalId, cathodeTerminalId});

  /// A diode conducts anode->cathode only — represented as a single
  /// [ElectricalTerminalPair] (which is inherently unordered) PLUS the
  /// directionality is enforced by the solver consulting [isDirectional]
  /// together with [anodeTerminalId]/[cathodeTerminalId] directly, not by
  /// this set alone (an [ElectricalTerminalPair] cannot itself encode
  /// direction — see class doc comment on why [isDirectional] exists).
  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      {ElectricalTerminalPair(anodeTerminalId, cathodeTerminalId)};

  /// Overrides the default order-agnostic check: a diode conducts ONLY
  /// anode->cathode, never cathode->anode, even though
  /// [ElectricalTerminalPair] itself has no concept of order.
  @override
  bool conductsFrom(EngineeringNode node, String fromTerminalId, String toTerminalId, ElectricalOperatingContext context) =>
      fromTerminalId == anodeTerminalId && toTerminalId == cathodeTerminalId;

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      ElectricalReading.unsupported(note: 'A diode\'s forward drop is not a linear resistance.');
}

/// PRODUCT-READINESS-006 §9/§14/§21 — a real, resistive two-terminal load
/// (a lamp, motor, or similar). Preserves [DeadEndElectricalComponentBehavior]'s
/// own proven topology rule (never bridges its own terminals for voltage/
/// ground PROPAGATION purposes, `AP-LAMP-TUNNEL-001`/`AP-BODY-GROUND-AUTO-001`
/// — a load terminates a circuit, it does not pass current through to
/// whatever else shares its pins) while ALSO providing a real [resistanceOhms]
/// value between those same two terminals for Ohm's-law CURRENT
/// calculation (§19) — a genuinely different question ("what value would
/// I=V/R use for this component") that [DeadEndElectricalComponentBehavior]
/// deliberately leaves [ElectricalReading.unsupported] since it has no
/// real component data to offer. This class exists specifically to supply
/// that real data where a caller has it (matching the Legacy V2 solver's
/// own `LampBehavior`/`MotorBehavior` constants — see [resistanceOhms]'s
/// own doc for the values carried over).
class ResistiveLoadElectricalComponentBehavior extends ElectricalComponentBehavior {
  const ResistiveLoadElectricalComponentBehavior({required this.resistanceOhms});

  /// A real resistance value in Ω — e.g. `120` for a hot incandescent lamp
  /// filament, or `0.3` for a running starter motor winding (Legacy V2's
  /// own `LampBehavior.HOT_RESISTANCE`/`MotorBehavior.RUNNING_RESISTANCE`
  /// constants, `js/knowledge/behaviors/{lamp,motor}.js`) — supplied by the
  /// caller per real component data, never invented by this class.
  final num resistanceOhms;

  @override
  bool appliesTo(EngineeringNode node) => false; // Reference-only; a real caller supplies its own appliesTo.

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      const {}; // Preserves AP-LAMP-TUNNEL-001 — never a topology bridge.

  /// Answers the Ohm's-law question directly for ANY two of this
  /// component's own terminals — a load has exactly one resistance value
  /// regardless of which two terminals are asked about (the common
  /// 2-terminal case); a caller modeling a genuinely asymmetric multi-
  /// terminal load should use a more specific behavior instead.
  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) =>
      ElectricalReading.valid(resistanceOhms, unit: 'Ω');
}

/// PRODUCT-READINESS-006B — the "more specific behavior" a genuinely
/// asymmetric multi-terminal load needs, per
/// [ResistiveLoadElectricalComponentBehavior]'s own doc comment: a real
/// dual-filament bulb (e.g. the TRX300's own LH Headlight, `GND`/`LO`/`Hi`)
/// has a real resistance between `GND`-`LO` and between `GND`-`Hi`, but
/// NO real resistance/edge directly between `LO`-`Hi` at all (the two
/// filaments are not connected to each other) — a caller declares exactly
/// the pairs that ARE real via [resistanceOhmsByPair]; every other pair on
/// the component (§26: terminal-level identity is never collapsed) is
/// honestly [ElectricalReading.unsupported], not silently defaulted to the
/// single [ResistiveLoadElectricalComponentBehavior.resistanceOhms] value
/// every OTHER pair would otherwise incorrectly share.
class MultiTerminalResistiveLoadElectricalComponentBehavior extends ElectricalComponentBehavior {
  const MultiTerminalResistiveLoadElectricalComponentBehavior({required this.resistanceOhmsByPair});

  final Map<ElectricalTerminalPair, num> resistanceOhmsByPair;

  @override
  bool appliesTo(EngineeringNode node) => false; // Reference-only; a real caller supplies its own appliesTo.

  @override
  Set<ElectricalTerminalPair> conductingTerminalPairs(EngineeringNode node, ElectricalOperatingContext context) =>
      const {}; // Preserves AP-LAMP-TUNNEL-001 — never a topology bridge, for any declared pair.

  @override
  ElectricalReading resistanceBetween(
    EngineeringNode node,
    String terminalA,
    String terminalB,
    ElectricalOperatingContext context,
  ) {
    final ohms = resistanceOhmsByPair[ElectricalTerminalPair(terminalA, terminalB)];
    return ohms == null
        ? ElectricalReading.unsupported(note: 'No real resistance declared between these two specific terminals of this component.')
        : ElectricalReading.valid(ohms, unit: 'Ω');
  }
}
