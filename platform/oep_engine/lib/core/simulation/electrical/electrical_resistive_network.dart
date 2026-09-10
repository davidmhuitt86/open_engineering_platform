import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import '../measurement/measurement_types.dart';
import 'electrical_component_behavior.dart';
import 'electrical_operating_context.dart';
import 'electrical_reading.dart';
import 'electrical_reading_state.dart';

/// PRODUCT-READINESS-006B — a component's own resistance is a real,
/// disclosed number (§8/§21); a plain WIRE's resistance is not modeled
/// anywhere on [EngineeringRelationship] itself, so this resolver exists
/// for the same reason [ElectricalSourceVoltageResolver] does: a real,
/// disclosed default (the Legacy V2 solver's own "all copper wire is
/// essentially 0Ω" convention concretely expressed as `0.1Ω`,
/// `reference/legacy_wiring_sim_v2/`), overridable by a caller with real,
/// richer per-wire data. Deliberately never exactly `0` — see
/// [ElectricalResistiveNetwork]'s own "Why wires are real edges" doc note
/// below for why a tiny, real, uniform resistance (rather than an ideal
/// merge) is what makes per-wire current well-defined at a junction with
/// more than two wires (a splice, a 3-way branch).
typedef ElectricalWireResistanceResolver = num Function(String relationshipId);

num _defaultWireResistanceOhms(String relationshipId) => 0.1;

/// §31 — numeric tolerance this solver uses everywhere it must decide
/// "is this effectively zero." Never compared via exact floating-point
/// equality elsewhere in this file.
const double kElectricalVoltageToleranceVolts = 1e-9;
const double kElectricalCurrentToleranceAmps = 1e-9;

num _snapToZero(double v, double tolerance) => v.abs() < tolerance ? 0 : v;

/// One resistor edge in the general network (§9/§10/§11) — either a real
/// wire ([relationshipId] non-null) at [ElectricalWireResistanceResolver]'s
/// resistance, or a real component's own two terminals
/// ([relationshipId] null) at [ElectricalComponentBehavior.resistanceBetween]'s
/// value. A component pair that BRIDGES ideally (a splice's unconditional
/// junction, a connector's same-pin passthrough — both real,
/// [ElectricalReading.valid]`(0, ...)` per their own behavior) is NOT
/// represented as an edge at all — see [ElectricalResistiveNetwork.build]'s
/// own doc comment for why those are merged into one supernode instead of
/// modeled as a (singular, infinite-conductance) `0Ω` edge.
class ElectricalNetworkEdge {
  const ElectricalNetworkEdge({
    required this.id,
    required this.fromSupernode,
    required this.toSupernode,
    required this.fromTerminal,
    required this.toTerminal,
    required this.resistanceOhms,
    this.relationshipId,
  });

  final String id;
  final int fromSupernode;
  final int toSupernode;

  /// Canonical orientation for this edge's own signed current/direction —
  /// for a wire, the relationship's own `sourceNode`/`targetNode`; for a
  /// component pair, an arbitrary but stable (lower-sorts-first) order.
  final ProbePoint fromTerminal;
  final ProbePoint toTerminal;

  final num resistanceOhms;
  final String? relationshipId;

  num get conductanceSiemens => resistanceOhms <= 0 ? 0 : 1 / resistanceOhms;
}

class ElectricalDiodeTerminals {
  const ElectricalDiodeTerminals({required this.anode, required this.cathode, required this.forwardDropVolts});
  final ProbePoint anode;
  final ProbePoint cathode;
  final num forwardDropVolts;
}

class _SourceReferencePair {
  const _SourceReferencePair(this.sourceSupernode, this.referenceSupernode);
  final int sourceSupernode;
  final int referenceSupernode;
}

class _UnionFind {
  _UnionFind(int size) : _parent = List.generate(size, (i) => i), _rank = List.filled(size, 0);
  final List<int> _parent;
  final List<int> _rank;

  int find(int x) {
    while (_parent[x] != x) {
      _parent[x] = _parent[_parent[x]];
      x = _parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra == rb) return;
    if (_rank[ra] < _rank[rb]) {
      _parent[ra] = rb;
    } else if (_rank[ra] > _rank[rb]) {
      _parent[rb] = ra;
    } else {
      _parent[rb] = ra;
      _rank[ra]++;
    }
  }
}

/// Priority order used to pick the "worse" of two [ElectricalReading]s when
/// combining two terminals into one derived answer (e.g. VDC between a
/// valid terminal and a faulted one reports the fault, not a fabricated
/// number) — higher sorts as more severe/informative-about-a-problem.
const Map<ElectricalReadingState, int> _severity = {
  ElectricalReadingState.fault: 5,
  ElectricalReadingState.unsupported: 4,
  ElectricalReadingState.unknown: 3,
  ElectricalReadingState.unreached: 2,
  ElectricalReadingState.overload: 2,
  ElectricalReadingState.open: 1,
  ElectricalReadingState.valid: 0,
};

/// Returns the more severe of [a]/[b] when either is non-valid; `null` when
/// both are [ElectricalReading.isValid] (meaning the caller should proceed
/// with its own valid-value computation).
ElectricalReading? worseReading(ElectricalReading a, ElectricalReading b) {
  if (a.isValid && b.isValid) return null;
  return _severity[a.state]! >= _severity[b.state]! ? a : b;
}

/// PRODUCT-READINESS-006B — the general resistive-network representation
/// and solver §1/§9/§10/§11/§12 asks for, ADDITIVE to (never replacing)
/// [ElectricalSolver]'s own existing terminal-BFS voltage/ground
/// propagation (`electrical_solver.dart`) and its existing narrow, dead-
/// end-only Ohm's-law current calc — both of which remain completely
/// unchanged, exactly to preserve every PRODUCT-READINESS-006 regression
/// value (§47 of that phase, §39/§47 of this one). This is a SEPARATE,
/// more rigorous, genuinely general capability living ALONGSIDE those
/// fields on [SolvedElectricalState] (via the additive `network` field),
/// used by [ElectricalMeasurementQuery] for arbitrary two-terminal
/// resistance/current/power/continuity/diode queries (§28/§42/§43: a
/// QUERY over already-solved data, not a second electrical authority — no
/// new topology/behavior decision is made here that
/// [ElectricalComponentBehavior]/[ElectricalOperatingContext] did not
/// already make; this class only performs the linear-algebra REDUCTION of
/// those already-determined resistor values).
///
/// **Method: nodal analysis (Modified Nodal Analysis, restricted to the
/// linear-resistive case)** — §12. Reference-node semantics: every
/// terminal identified as a modeled reference/ground
/// ([ElectricalReferenceRoleResolver]) is a Dirichlet (fixed-voltage, 0V)
/// boundary condition; every modeled source terminal
/// ([ElectricalSourceRoleResolver]) is a Dirichlet boundary at its own
/// declared voltage (§13 — see "Voltage source treatment" below). Free
/// (non-fixed) supernode voltages are solved via deterministic dense
/// Gaussian elimination with partial pivoting, one linear system per
/// connected component of the network (§32/§33 — a component with no
/// fixed boundary at all is a genuinely floating network, reported
/// [ElectricalReading.unreached], never solved as if grounded).
///
/// **Voltage source treatment (§13)**: an ideal voltage source — no
/// internal resistance is modeled (matching the disclosed TRX300 data:
/// nothing in `diagram7.json`'s own Battery node, or the Legacy V2
/// `BatteryBehavior`, carries an internal-resistance value). For the
/// OPERATING solve (real voltage/current/power under the current
/// operating state — [solveOperating]), a source is a fixed-voltage
/// boundary. For arbitrary RESISTANCE measurement ([resistanceBetween]),
/// per the standard circuit-analysis convention for computing an
/// equivalent/Thevenin resistance, every ideal source is DEACTIVATED
/// (shorted between its own + and - terminals) before the reduction runs
/// — never left as a live, undefined-resistance boundary condition that
/// would make "resistance through a battery" a nonsensical question
/// (§8's own explicit warning).
///
/// **Supported network class (§9/§10/§11)**: any linear DC resistive
/// network built from real component resistances plus real wire
/// resistances — series, parallel, mixed series/parallel, and arbitrary
/// (including cyclic — §32.W) graph topology, EXCLUDING any component
/// whose own behavior has no linear resistance value (a diode — §49's own
/// scope limit forbids a nonlinear I-V solve; see [diodes] for the
/// separate, structural-only diode model used by [ElectricalMeasurementQuery]'s
/// DIODE mode instead).
///
/// **Why wires are real (non-ideal) edges, not union-find merges**: an
/// earlier design considered treating every wire as an ideal `0Ω` merge
/// (mirroring [ElectricalSolver]'s own existing propagation, which assumes
/// no drop across any wire). That collapses a 3-way splice's THREE wires
/// into one indistinguishable point, making "how much of the total
/// current flows through wire #2 specifically" mathematically
/// ill-posed — there is no way to attribute a specific numeric current to
/// a specific `0Ω` wire among several without an arbitrary tie-break.
/// Giving every wire the same small, real, disclosed resistance instead
/// makes every wire its own genuine, uniquely-solved edge in the same
/// linear system as every other resistor — current splits among
/// parallel/branching wires exactly the way real Kirchhoff analysis
/// requires (equal split for equal downstream resistance — §32.K; unequal,
/// inversely-proportional split otherwise — §32.J), with no special-casing
/// or heuristic "nearest downstream load" attribution needed at all. The
/// two EXCEPTIONS — an unconditional splice junction, and a connector's
/// own same-pin passthrough — are still merged (not given a resistor
/// edge): both behaviors report a real, disclosed `ElectricalReading.valid(0,
/// ...)`, and unlike a wire, both genuinely represent "this is definitionally
/// the same electrical point," not "a short, real length of conductor
/// between two distinct points" — modeling either as a finite resistor
/// would require inventing a resistance value neither behavior has ever
/// disclosed.
class ElectricalResistiveNetwork {
  ElectricalResistiveNetwork._({
    required this.supernodeOf,
    required this.supernodeCount,
    required this.edges,
    required this.referenceSupernodes,
    required Map<int, ElectricalReading> fixedSourceVoltageBySupernode,
    required List<_SourceReferencePair> sourceReferencePairs,
    required this.diodes,
    required Map<ProbePoint, List<ProbePoint>> continuityAdjacency,
  })  : _fixedSourceVoltageBySupernode = fixedSourceVoltageBySupernode,
        _sourceReferencePairs = sourceReferencePairs,
        _continuityAdjacency = continuityAdjacency {
    _solveOperating();
  }

  /// Every terminal's own supernode id — terminals that are definitionally
  /// the SAME electrical point (a splice's own junction, a connector's own
  /// same pin) share an id; every other terminal, including every wire's
  /// own two distinct endpoints, has its own.
  final Map<ProbePoint, int> supernodeOf;
  final int supernodeCount;
  final List<ElectricalNetworkEdge> edges;
  final Set<int> referenceSupernodes;
  final Map<int, ElectricalReading> _fixedSourceVoltageBySupernode;
  final List<_SourceReferencePair> _sourceReferencePairs;
  final List<ElectricalDiodeTerminals> diodes;
  final Map<ProbePoint, List<ProbePoint>> _continuityAdjacency;

  /// The REAL, operating-state solve — populated by the constructor.
  /// `null` entries never occur for a supernode index within range; every
  /// supernode gets a real [ElectricalReading] (valid, unreached, unknown,
  /// or fault — never a bare Dart `null` standing in for "no answer").
  late final List<ElectricalReading> _operatingVoltageBySupernode;
  late final Map<String, num?> _operatingSignedCurrentByEdgeId;

  static ElectricalResistiveNetwork build({
    required EngineeringGraph graph,
    required ElectricalOperatingContext context,
    required ElectricalComponentBehavior? Function(EngineeringNode node) behaviorFor,
    required bool Function(EngineeringNode node, String? portId, ElectricalComponentBehavior? behavior) isSourceTerminal,
    required bool Function(EngineeringNode node, String? portId) isReferenceTerminal,
    required ElectricalReading Function(EngineeringNode node, ElectricalOperatingContext context) sourceVoltage,
    ElectricalWireResistanceResolver wireResistanceOhms = _defaultWireResistanceOhms,
  }) {
    final terminalsByNode = <String, List<ProbePoint>>{};
    final terminalIndex = <ProbePoint, int>{};
    final allTerminals = <ProbePoint>[];
    for (final node in graph.nodes.values) {
      final ports = node.ports.isEmpty
          ? [ProbePoint(nodeId: node.id)]
          : node.ports.map((p) => ProbePoint(nodeId: node.id, portId: p.id)).toList();
      terminalsByNode[node.id] = ports;
      for (final t in ports) {
        terminalIndex[t] = allTerminals.length;
        allTerminals.add(t);
      }
    }

    final structuralMerge = _UnionFind(allTerminals.length);
    final continuityAdjacency = <ProbePoint, List<ProbePoint>>{for (final t in allTerminals) t: <ProbePoint>[]};
    // Directed: a plain (non-directional) conducting pair adds BOTH
    // directions; a directional one (a diode) adds only its own real
    // conducting direction — see [ElectricalResistiveNetwork.continuityBetween]
    // for why this must stay direction-aware rather than a flat undirected
    // union-find (§16/§19: never treat a diode as bidirectional).
    void addDirectedContinuity(ProbePoint from, ProbePoint to) => continuityAdjacency[from]!.add(to);

    final pendingComponentEdges = <({ProbePoint a, ProbePoint b, num resistanceOhms, String nodeId})>[];
    final diodes = <ElectricalDiodeTerminals>[];

    for (final node in graph.nodes.values) {
      final behavior = behaviorFor(node);
      if (behavior == null) continue;
      final ids = terminalsByNode[node.id]!.map((t) => t.portId).whereType<String>().toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final a = ids[i], b = ids[j];
          final ta = ProbePoint(nodeId: node.id, portId: a);
          final tb = ProbePoint(nodeId: node.id, portId: b);

          if (behavior.isDirectional && behavior is DiodeElectricalBehavior) {
            // §19/§49 — a diode has no linear resistance; excluded from the
            // resistor network entirely. Structural continuity still
            // respects its own real, one-way direction (never both).
            final forward = behavior.conductsFrom(node, a, b, context);
            final backward = behavior.conductsFrom(node, b, a, context);
            if (!forward && !backward) continue;
            if (forward) addDirectedContinuity(ta, tb);
            if (backward) addDirectedContinuity(tb, ta);
            diodes.add(ElectricalDiodeTerminals(
              anode: ProbePoint(nodeId: node.id, portId: behavior.anodeTerminalId),
              cathode: ProbePoint(nodeId: node.id, portId: behavior.cathodeTerminalId),
              forwardDropVolts: behavior.forwardDropVolts,
            ));
            continue;
          }

          // §9/§14 fix: whether a pair gets a resistor edge is answered by
          // [ElectricalComponentBehavior.resistanceBetween] directly, NOT
          // by [ElectricalComponentBehavior.conductsFrom] — those are
          // deliberately DIFFERENT questions (PRODUCT-READINESS-006's own
          // "bridges" vs. "has resistance" distinction, `AP-LAMP-TUNNEL-001`):
          // a real resistive LOAD (a lamp) never "conducts"/bridges its own
          // terminals in the topology sense (so voltage/ground propagation
          // correctly stops at it), yet it very much DOES have a real,
          // finite resistance between them — exactly the case this
          // general network needs to represent as an edge. Gating edge
          // creation on `conductsFrom` alone (an earlier version of this
          // method did) silently produced NO edge at all for every real
          // load, making arbitrary CURRENT/POWER/RESISTANCE queries across
          // a lamp's own two terminals wrongly UNSUPPORTED.
          final resistance = behavior.resistanceBetween(node, a, b, context);
          final bridges = behavior.conductsFrom(node, a, b, context) || behavior.conductsFrom(node, b, a, context);
          if (!resistance.isValid && !bridges) continue; // nothing to represent for this pair at all.

          // A resistively-modeled or bridging pair is also structurally
          // continuous (non-directional — diode is handled separately,
          // above) in both directions.
          addDirectedContinuity(ta, tb);
          addDirectedContinuity(tb, ta);
          if (!resistance.isValid) continue; // bridges, but this behavior offers no linear resistance value for it.

          final ohms = resistance.value!;
          if (ohms == 0) {
            structuralMerge.union(terminalIndex[ta]!, terminalIndex[tb]!);
          } else {
            pendingComponentEdges.add((a: ta, b: tb, resistanceOhms: ohms, nodeId: node.id));
          }
        }
      }
    }

    final pendingWireEdges = <({ProbePoint a, ProbePoint b, num resistanceOhms, String relationshipId})>[];
    for (final relationship in graph.relationships.values) {
      final sourceTerminal = ProbePoint(nodeId: relationship.sourceNode, portId: relationship.metadata['sourcePort'] as String?);
      final targetTerminal = ProbePoint(nodeId: relationship.targetNode, portId: relationship.metadata['targetPort'] as String?);
      if (!terminalIndex.containsKey(sourceTerminal) || !terminalIndex.containsKey(targetTerminal)) continue;
      addDirectedContinuity(sourceTerminal, targetTerminal);
      addDirectedContinuity(targetTerminal, sourceTerminal);
      final ohms = wireResistanceOhms(relationship.id);
      if (ohms == 0) {
        // A caller-supplied resolver may legitimately declare an ideal
        // (0Ω) wire (e.g. a synthetic fixture isolating pure resistor-
        // network math) — merged the same way a splice/connector same-pin
        // is, never modeled as a literal 0Ω resistor edge (which would
        // wrongly carry zero conductance under this class's own
        // [ElectricalNetworkEdge.conductanceSiemens] convention).
        structuralMerge.union(terminalIndex[sourceTerminal]!, terminalIndex[targetTerminal]!);
      } else {
        pendingWireEdges.add((
          a: sourceTerminal,
          b: targetTerminal,
          resistanceOhms: ohms,
          relationshipId: relationship.id,
        ));
      }
    }

    final supernodeOf = <ProbePoint, int>{};
    final rootToSupernode = <int, int>{};
    for (final t in allTerminals) {
      final root = structuralMerge.find(terminalIndex[t]!);
      final sn = rootToSupernode.putIfAbsent(root, () => rootToSupernode.length);
      supernodeOf[t] = sn;
    }
    final supernodeCount = rootToSupernode.length;

    final edges = <ElectricalNetworkEdge>[];
    for (final e in pendingComponentEdges) {
      edges.add(ElectricalNetworkEdge(
        id: 'component:${e.nodeId}:${e.a.portId}-${e.b.portId}',
        fromSupernode: supernodeOf[e.a]!,
        toSupernode: supernodeOf[e.b]!,
        fromTerminal: e.a,
        toTerminal: e.b,
        resistanceOhms: e.resistanceOhms,
      ));
    }
    for (final e in pendingWireEdges) {
      edges.add(ElectricalNetworkEdge(
        id: 'wire:${e.relationshipId}',
        fromSupernode: supernodeOf[e.a]!,
        toSupernode: supernodeOf[e.b]!,
        fromTerminal: e.a,
        toTerminal: e.b,
        resistanceOhms: e.resistanceOhms,
        relationshipId: e.relationshipId,
      ));
    }

    final referenceSupernodes = <int>{};
    final sourceReadingsBySupernode = <int, List<ElectricalReading>>{};
    final sourceReferencePairs = <_SourceReferencePair>[];
    for (final node in graph.nodes.values) {
      final behavior = behaviorFor(node);
      final nodeSourceSupernodes = <int>{};
      final nodeReferenceSupernodes = <int>{};
      for (final t in terminalsByNode[node.id]!) {
        final sn = supernodeOf[t]!;
        if (isSourceTerminal(node, t.portId, behavior)) {
          nodeSourceSupernodes.add(sn);
          sourceReadingsBySupernode.putIfAbsent(sn, () => []).add(sourceVoltage(node, context));
        }
        if (isReferenceTerminal(node, t.portId)) {
          nodeReferenceSupernodes.add(sn);
          referenceSupernodes.add(sn);
        }
      }
      for (final s in nodeSourceSupernodes) {
        for (final r in nodeReferenceSupernodes) {
          sourceReferencePairs.add(_SourceReferencePair(s, r));
        }
      }
    }

    // Resolve each source supernode's own fixed boundary reading, detecting
    // contradiction (§32 — two DIFFERENT declared voltages, or a source
    // shorted directly to a reference, both reported as a real
    // [ElectricalReadingState.fault], never silently averaged/overwritten).
    final fixedSourceVoltageBySupernode = <int, ElectricalReading>{};
    sourceReadingsBySupernode.forEach((sn, readings) {
      final validValues = readings.where((r) => r.isValid).map((r) => r.value!).toSet();
      final anyUnknown = readings.any((r) => !r.isValid);
      if (referenceSupernodes.contains(sn) && validValues.any((v) => v != 0)) {
        fixedSourceVoltageBySupernode[sn] =
            ElectricalReading.fault(unit: 'V', note: 'A source terminal and a reference terminal are directly shorted together.');
        return;
      }
      if (validValues.length > 1) {
        fixedSourceVoltageBySupernode[sn] = ElectricalReading.fault(
            unit: 'V', note: 'Multiple sources with different declared voltages are shorted together at this junction.');
        return;
      }
      if (validValues.isNotEmpty) {
        fixedSourceVoltageBySupernode[sn] = ElectricalReading.valid(validValues.first, unit: 'V');
      } else if (anyUnknown) {
        fixedSourceVoltageBySupernode[sn] =
            ElectricalReading.unknown(unit: 'V', note: 'No nominalVoltageV declared on this source component.');
      }
    });

    return ElectricalResistiveNetwork._(
      supernodeOf: supernodeOf,
      supernodeCount: supernodeCount,
      edges: edges,
      referenceSupernodes: referenceSupernodes,
      fixedSourceVoltageBySupernode: fixedSourceVoltageBySupernode,
      sourceReferencePairs: sourceReferencePairs,
      diodes: diodes,
      continuityAdjacency: continuityAdjacency,
    );
  }

  // ---- Operating solve (real source voltages as fixed boundaries) -------

  void _solveOperating() {
    final fixed = <int, ElectricalReading>{};
    for (final sn in referenceSupernodes) {
      fixed[sn] = ElectricalReading.valid(0, unit: 'V');
    }
    _fixedSourceVoltageBySupernode.forEach((sn, reading) {
      if (reading.state == ElectricalReadingState.fault) {
        // Surface the contradiction regardless of any prior 0V reference
        // entry for this same supernode (a source/reference short, or
        // multiple differently-valued sources shorted together — both
        // already detected and stamped `fault` at build time).
        fixed[sn] = reading;
      } else if (!fixed.containsKey(sn)) {
        fixed[sn] = reading;
      }
      // else: `sn` is a reference (0V) and this source's own reading isn't
      // a fault — the reference's 0V already correctly reflects "this
      // point is grounded"; a source with an unresolved voltage sharing
      // that same point is not itself a contradiction.
    });

    final adjacency = List.generate(supernodeCount, (_) => <int>[]);
    for (var i = 0; i < edges.length; i++) {
      adjacency[edges[i].fromSupernode].add(i);
      adjacency[edges[i].toSupernode].add(i);
    }

    final componentOf = List<int>.filled(supernodeCount, -1);
    var componentCount = 0;
    for (var s = 0; s < supernodeCount; s++) {
      if (componentOf[s] != -1) continue;
      final queue = <int>[s];
      componentOf[s] = componentCount;
      var head = 0;
      while (head < queue.length) {
        final cur = queue[head++];
        for (final ei in adjacency[cur]) {
          final e = edges[ei];
          final other = e.fromSupernode == cur ? e.toSupernode : e.fromSupernode;
          if (componentOf[other] == -1) {
            componentOf[other] = componentCount;
            queue.add(other);
          }
        }
      }
      componentCount++;
    }

    final voltage = List<ElectricalReading?>.filled(supernodeCount, null);
    for (var c = 0; c < componentCount; c++) {
      final membersFixed = [for (var sn = 0; sn < supernodeCount; sn++) if (componentOf[sn] == c && fixed.containsKey(sn)) sn];
      if (membersFixed.isEmpty) {
        for (var sn = 0; sn < supernodeCount; sn++) {
          if (componentOf[sn] == c) voltage[sn] = ElectricalReading.unreached(unit: 'V');
        }
        continue;
      }
      if (membersFixed.any((sn) => fixed[sn]!.state == ElectricalReadingState.fault)) {
        for (var sn = 0; sn < supernodeCount; sn++) {
          if (componentOf[sn] == c) {
            voltage[sn] = ElectricalReading.fault(unit: 'V', note: 'Contradictory source/reference boundary within this connected network.');
          }
        }
        continue;
      }
      if (membersFixed.any((sn) => !fixed[sn]!.isValid)) {
        for (var sn = 0; sn < supernodeCount; sn++) {
          if (componentOf[sn] == c) {
            voltage[sn] = ElectricalReading.unknown(unit: 'V', note: 'A source on this network has no declared voltage.');
          }
        }
        continue;
      }

      final freeMembers = [for (var sn = 0; sn < supernodeCount; sn++) if (componentOf[sn] == c && !fixed.containsKey(sn)) sn];
      for (final sn in membersFixed) {
        voltage[sn] = fixed[sn];
      }
      if (freeMembers.isEmpty) continue;

      final localIndex = {for (var i = 0; i < freeMembers.length; i++) freeMembers[i]: i};
      final n = freeMembers.length;
      final g = List.generate(n, (_) => List<double>.filled(n, 0.0));
      final inj = List<double>.filled(n, 0.0);
      for (final e in edges) {
        if (componentOf[e.fromSupernode] != c) continue;
        final conductance = e.conductanceSiemens.toDouble();
        if (conductance <= 0) continue;
        final fi = localIndex[e.fromSupernode];
        final ti = localIndex[e.toSupernode];
        if (fi != null) g[fi][fi] += conductance;
        if (ti != null) g[ti][ti] += conductance;
        if (fi != null && ti != null) {
          g[fi][ti] -= conductance;
          g[ti][fi] -= conductance;
        }
        if (fi != null && ti == null) inj[fi] += conductance * (fixed[e.toSupernode]!.value!.toDouble());
        if (ti != null && fi == null) inj[ti] += conductance * (fixed[e.fromSupernode]!.value!.toDouble());
      }
      final solved = _solveLinearSystem(g, inj);
      if (solved == null) {
        for (final sn in freeMembers) {
          voltage[sn] = ElectricalReading.unknown(unit: 'V', note: 'Network reduction was singular for this topology.');
        }
      } else {
        for (var i = 0; i < n; i++) {
          voltage[freeMembers[i]] = ElectricalReading.valid(_snapToZero(solved[i], kElectricalVoltageToleranceVolts), unit: 'V');
        }
      }
    }

    _operatingVoltageBySupernode = [for (var sn = 0; sn < supernodeCount; sn++) voltage[sn] ?? ElectricalReading.unreached(unit: 'V')];

    final signedCurrent = <String, num?>{};
    for (final e in edges) {
      final vFrom = _operatingVoltageBySupernode[e.fromSupernode];
      final vTo = _operatingVoltageBySupernode[e.toSupernode];
      if (vFrom.isValid && vTo.isValid && e.resistanceOhms > 0) {
        final amps = (vFrom.value!.toDouble() - vTo.value!.toDouble()) / e.resistanceOhms;
        signedCurrent[e.id] = _snapToZero(amps, kElectricalCurrentToleranceAmps);
      } else {
        signedCurrent[e.id] = null;
      }
    }
    _operatingSignedCurrentByEdgeId = signedCurrent;
  }

  // ---- Queries ------------------------------------------------------------

  /// The real, operating-state-solved voltage at [terminal] (§13's fixed-
  /// source-boundary solve) — distinct from [ElectricalSolver]'s own
  /// existing ideal-propagation `voltage` (may differ by the small,
  /// disclosed wire/switch/fuse resistances this network genuinely
  /// accounts for and the ideal propagation does not — both are honest,
  /// differently-scoped answers; see this class's own top doc comment).
  ElectricalReading? operatingVoltage(ProbePoint terminal) {
    final sn = supernodeOf[terminal];
    if (sn == null) return null;
    return _operatingVoltageBySupernode[sn];
  }

  /// The single network edge whose own two terminals are EXACTLY
  /// {[a], [b]} (a real wire, or a real component's own two terminals) —
  /// §20/§21's own "a current probe must be a unique series insertion
  /// point" decision. Returns `null` when no such single edge exists
  /// (including when [a]/[b] are the same supernode via an ideal merge, or
  /// span multiple edges/branches) — the caller reports UNSUPPORTED rather
  /// than fabricating a value for an ill-posed probe placement.
  ({ElectricalReading current, ElectricalReading power, String direction})? edgeBetween(ProbePoint a, ProbePoint b) {
    for (final e in edges) {
      final matchesForward = e.fromTerminal == a && e.toTerminal == b;
      final matchesReverse = e.fromTerminal == b && e.toTerminal == a;
      if (!matchesForward && !matchesReverse) continue;
      final signed = _operatingSignedCurrentByEdgeId[e.id];
      if (signed == null) {
        final vFrom = _operatingVoltageBySupernode[e.fromSupernode];
        final vTo = _operatingVoltageBySupernode[e.toSupernode];
        final bad = worseReading(vFrom, vTo) ?? ElectricalReading.unknown(unit: 'A');
        return (
          current: _restateReading(bad, unit: 'A'),
          power: _restateReading(bad, unit: 'W'),
          direction: 'unknown',
        );
      }
      // `signed` is positive when current flows fromTerminal -> toTerminal.
      // Re-express relative to the CALLER's own a->b probe order.
      final signedFromAToB = matchesForward ? signed : -signed;
      final magnitude = signedFromAToB.abs();
      final vDrop = (_operatingVoltageBySupernode[e.fromSupernode].value! - _operatingVoltageBySupernode[e.toSupernode].value!).abs();
      return (
        current: ElectricalReading.valid(magnitude, unit: 'A'),
        power: ElectricalReading.valid(magnitude * vDrop, unit: 'W'),
        direction: signedFromAToB > kElectricalCurrentToleranceAmps
            ? 'positive probe to negative probe'
            : (signedFromAToB < -kElectricalCurrentToleranceAmps ? 'negative probe to positive probe' : 'none (zero current)'),
      );
    }
    return null;
  }

  /// §8/§9/§10/§11/§12/§13 — the equivalent resistance between [a] and
  /// [b], computed by deactivating every modeled ideal source (shorting
  /// each one's own source/reference terminal pair — the standard
  /// technique for an equivalent/Thevenin resistance calculation, chosen
  /// specifically so this never "calculates nonsensical resistance through
  /// an ideal voltage source," §8's own explicit warning) and then
  /// injecting a 1A test current at [a], extracting it at [b], and reading
  /// the resulting potential difference (which numerically equals the
  /// resistance in Ω, since `R = V / 1A`).
  ElectricalReading resistanceBetween(ProbePoint a, ProbePoint b) {
    final sa = supernodeOf[a];
    final sb = supernodeOf[b];
    if (sa == null || sb == null) return ElectricalReading.unknown(unit: 'Ω', note: 'Unknown terminal.');
    if (sa == sb) return ElectricalReading.valid(0, unit: 'Ω', note: 'Same electrical point.');

    final deactivated = _UnionFind(supernodeCount);
    for (final pair in _sourceReferencePairs) {
      deactivated.union(pair.sourceSupernode, pair.referenceSupernode);
    }
    final groupOf = List.generate(supernodeCount, deactivated.find);
    final groupA = groupOf[sa];
    final groupB = groupOf[sb];
    if (groupA == groupB) {
      return ElectricalReading.valid(0, unit: 'Ω', note: 'Directly shorted once ideal sources are deactivated.');
    }

    // Group-level adjacency (edges between DISTINCT groups only) — built
    // once so the matrix below can be restricted to exactly the connected
    // component reachable from [groupA]. Restricting matters for
    // correctness, not just performance: including an unrelated, fully
    // isolated group anywhere else in a large real diagram (a component
    // with no source/reference/resistor path touching it at all) would
    // otherwise make the WHOLE matrix singular (an all-zero row for that
    // group), even though the [a]/[b] question itself is perfectly
    // well-posed.
    final groupAdjacency = <int, List<int>>{};
    for (final e in edges) {
      final gf = groupOf[e.fromSupernode];
      final gt = groupOf[e.toSupernode];
      if (gf == gt) continue;
      groupAdjacency.putIfAbsent(gf, () => []).add(gt);
      groupAdjacency.putIfAbsent(gt, () => []).add(gf);
    }
    final reachableGroups = <int>{groupA};
    final bfsQueue = <int>[groupA];
    var bfsHead = 0;
    while (bfsHead < bfsQueue.length) {
      final cur = bfsQueue[bfsHead++];
      for (final other in groupAdjacency[cur] ?? const <int>[]) {
        if (reachableGroups.add(other)) bfsQueue.add(other);
      }
    }
    if (!reachableGroups.contains(groupB)) {
      return _continuityFallbackForUnreachedResistance(a, b);
    }

    final groupIds = reachableGroups.toList()..sort();
    final groupIndex = {for (var i = 0; i < groupIds.length; i++) groupIds[i]: i};
    final n = groupIds.length;
    final g = List.generate(n, (_) => List<double>.filled(n, 0.0));
    for (final e in edges) {
      final gf = groupOf[e.fromSupernode];
      final gt = groupOf[e.toSupernode];
      if (gf == gt) continue;
      final gfIndex = groupIndex[gf];
      final gtIndex = groupIndex[gt];
      if (gfIndex == null || gtIndex == null) continue; // outside this connected component.
      final conductance = e.conductanceSiemens.toDouble();
      g[gfIndex][gfIndex] += conductance;
      g[gtIndex][gtIndex] += conductance;
      g[gfIndex][gtIndex] -= conductance;
      g[gtIndex][gfIndex] -= conductance;
    }

    final refIndex = groupIndex[groupB]!;
    final probeIndex = groupIndex[groupA]!;
    // Fix the reference group's own row/col to `V=0` by removing it from
    // the free system (standard grounded-nodal-analysis reduction), inject
    // +1A at the probe group.
    final freeIndices = [for (var i = 0; i < n; i++) if (i != refIndex) i];
    final localIndex = {for (var i = 0; i < freeIndices.length; i++) freeIndices[i]: i};
    final reducedN = freeIndices.length;
    final gr = List.generate(reducedN, (_) => List<double>.filled(reducedN, 0.0));
    for (var i = 0; i < freeIndices.length; i++) {
      for (var j = 0; j < freeIndices.length; j++) {
        gr[i][j] = g[freeIndices[i]][freeIndices[j]];
      }
    }
    final inj = List<double>.filled(reducedN, 0.0);
    final probeLocal = localIndex[probeIndex];
    if (probeLocal == null) {
      // probe group IS the reference group after grouping quirks — already
      // handled by the `groupA == groupB` check above; defensive fallback.
      return ElectricalReading.valid(0, unit: 'Ω', note: 'Directly shorted once ideal sources are deactivated.');
    }
    inj[probeLocal] = 1.0;

    final solved = _solveLinearSystem(gr, inj);
    if (solved == null) {
      return ElectricalReading.unknown(unit: 'Ω', note: 'Network reduction was singular for this topology.');
    }
    final ohms = solved[probeLocal];
    return ElectricalReading.valid(_snapToZero(ohms, 1e-9), unit: 'Ω');
  }

  ElectricalReading _continuityFallbackForUnreachedResistance(ProbePoint a, ProbePoint b) {
    // No resistor-edge path exists once sources are deactivated — but a
    // NON-LINEAR path (a diode) might still genuinely connect them, which
    // is a real connection this solver simply cannot assign a linear Ω
    // value to (§49) — reported UNSUPPORTED, never OPEN (which would
    // incorrectly claim no connection exists at all). Only report OPEN
    // when there truly is no path of any kind.
    return continuityBetween(a, b)
        ? ElectricalReading.unsupported(unit: 'Ω', note: 'Connected only through a non-linear component (e.g. a diode) — no linear resistance value applies.')
        : ElectricalReading.open(note: 'No conducting path between these terminals.');
  }

  /// §18 — pure structural reachability (wires always connect; a component
  /// pair connects only while [ElectricalComponentBehavior.conductsFrom]
  /// is true for the current operating state, respecting a diode's own
  /// real direction) — independent of any resistance VALUE, unlike
  /// [resistanceBetween].
  bool continuityBetween(ProbePoint a, ProbePoint b) {
    if (a == b) return true;
    if (!_continuityAdjacency.containsKey(a) || !_continuityAdjacency.containsKey(b)) return false;
    final visited = <ProbePoint>{a};
    final queue = <ProbePoint>[a];
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      for (final next in _continuityAdjacency[cur] ?? const []) {
        if (next == b) return true;
        if (visited.add(next)) queue.add(next);
      }
    }
    return false;
  }

  /// §19 — the real diode, if any, whose own anode/cathode are EXACTLY
  /// {[a], [b]} (in either probe order) — used by [ElectricalMeasurementQuery]'s
  /// DIODE mode.
  ({bool forward, num forwardDropVolts})? diodeBetween(ProbePoint a, ProbePoint b) {
    for (final d in diodes) {
      if (d.anode == a && d.cathode == b) return (forward: true, forwardDropVolts: d.forwardDropVolts);
      if (d.anode == b && d.cathode == a) return (forward: false, forwardDropVolts: d.forwardDropVolts);
    }
    return null;
  }
}

/// Deterministic dense Gaussian elimination with partial pivoting.
/// Returns `null` for a singular system (a pivot column with no usable row
/// — §32/§33: reported by callers as [ElectricalReadingState.unknown], never
/// silently zeroed).
List<double>? _solveLinearSystem(List<List<double>> a, List<double> b) {
  final n = b.length;
  if (n == 0) return const [];
  final m = [for (var i = 0; i < n; i++) [...a[i], b[i]]];
  for (var col = 0; col < n; col++) {
    var pivotRow = col;
    var pivotVal = m[col][col].abs();
    for (var row = col + 1; row < n; row++) {
      if (m[row][col].abs() > pivotVal) {
        pivotVal = m[row][col].abs();
        pivotRow = row;
      }
    }
    if (pivotVal < 1e-12) return null;
    if (pivotRow != col) {
      final tmp = m[col];
      m[col] = m[pivotRow];
      m[pivotRow] = tmp;
    }
    final pivot = m[col][col];
    for (var row = 0; row < n; row++) {
      if (row == col) continue;
      final factor = m[row][col] / pivot;
      if (factor == 0) continue;
      for (var k = col; k <= n; k++) {
        m[row][k] -= factor * m[col][k];
      }
    }
  }
  return [for (var i = 0; i < n; i++) m[i][n] / m[i][i]];
}

/// Re-expresses [source]'s own state/note under a different [unit] — used
/// when a derived quantity (e.g. current) inherits its non-valid state from
/// an underlying voltage reading.
ElectricalReading _restateReading(ElectricalReading source, {required String unit}) {
  switch (source.state) {
    case ElectricalReadingState.fault:
      return ElectricalReading.fault(unit: unit, note: source.note);
    case ElectricalReadingState.unsupported:
      return ElectricalReading.unsupported(unit: unit, note: source.note);
    case ElectricalReadingState.unknown:
      return ElectricalReading.unknown(unit: unit, note: source.note);
    case ElectricalReadingState.unreached:
      return ElectricalReading.unreached(unit: unit, note: source.note);
    case ElectricalReadingState.overload:
      return ElectricalReading.overload(unit: unit, note: source.note);
    case ElectricalReadingState.open:
      return ElectricalReading.open(unit: unit, note: source.note);
    case ElectricalReadingState.valid:
      return ElectricalReading.valid(source.value!, unit: unit, note: source.note);
  }
}
