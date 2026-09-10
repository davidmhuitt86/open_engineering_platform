import '../simulation/electrical/electrical_conducting_state.dart';
import '../simulation/electrical/electrical_reading.dart';
import '../simulation/measurement/measurement_types.dart';

/// PRODUCT-READINESS-005, §7 — one step in an ordered trace path: the
/// terminal arrived at, and how it was reached. Terminal identity is
/// preserved at every step (§7: "Do NOT collapse this into a list of
/// object IDs without terminal information") — [terminal] is a full
/// [ProbePoint] (componentId + terminalId), never a bare node id.
class TracePathStep {
  const TracePathStep({required this.terminal, this.viaRelationshipId, this.isInternalBridge = false});

  final ProbePoint terminal;

  /// The [EngineeringRelationship.id] (wire) traversed to reach this step
  /// from the previous one — `null` for the path's own first step (the
  /// starting terminal), and `null` when [isInternalBridge] is true (the
  /// hop was WITHIN one component, between two of its own terminals, not
  /// across a wire).
  final String? viaRelationshipId;

  /// True when this step was reached by crossing between two terminals of
  /// the SAME component (e.g. a switch's own internal bridge, or a
  /// splice's own internal junction) rather than by crossing a wire.
  final bool isInternalBridge;

  @override
  String toString() => 'TracePathStep($terminal${viaRelationshipId != null ? " via $viaRelationshipId" : ""})';
}

/// PRODUCT-READINESS-005, §7/§17 — one ordered trace path, preserving full
/// topology (§7: "A trace path must preserve ordered topology").
///
/// A path that hits a block partway (§17) is NOT discarded — [steps] still
/// contains every step actually reached, [conductingState] is
/// [ElectricalConductingState.open], and [blockingStep]/[blockingReason]
/// name exactly where and why. This is deliberate: "physical path: FOUND,
/// conducting path: BLOCKED, blocking element: Switch" is valuable
/// diagnostic information (§17), not "no path."
class TracePath {
  const TracePath({
    required this.pathId,
    required this.steps,
    required this.conductingState,
    this.currentDirection = ElectricalCurrentDirection.unknown,
    this.current,
    this.blockingStep,
    this.blockingReason,
  });

  /// A deterministic identity for this path — the ordered join of every
  /// step's `terminal` (and, where present, `viaRelationshipId`) — used by
  /// `TraceEngine` for deduplication (§19) rather than object identity or
  /// collection iteration order.
  final String pathId;

  final List<TracePathStep> steps;

  ProbePoint get startTerminal => steps.first.terminal;
  ProbePoint get endTerminal => steps.last.terminal;

  /// Whether this path, taken as a whole, is presently conducting — `open`
  /// if [blockingStep] cut it short, `unknown` for a [TraceMode.physical]
  /// path (which never evaluates conducting state at all).
  final ElectricalConductingState conductingState;

  /// Only meaningful for a [TraceMode.currentFlow] path — `unknown` for
  /// physical/conducting paths, which never consult solved current at all
  /// (§15: current direction must come from solved state, never inferred).
  final ElectricalCurrentDirection currentDirection;

  /// The solved current magnitude along this path, when [TraceMode.currentFlow]
  /// produced it — `null` for physical/conducting paths.
  final ElectricalReading? current;

  /// The step at which this path was blocked, or `null` for a path that
  /// reached its natural end (a dead end, or `maxDepth`) without being
  /// blocked.
  final TracePathStep? blockingStep;

  /// Human-readable explanation of [blockingStep] (e.g. "switch open",
  /// "wire faulted") — structured diagnostics live on the owning
  /// [TraceResult], this is purely a per-path explanatory note.
  final String? blockingReason;

  @override
  String toString() => 'TracePath($pathId, ${steps.length} steps, ${conductingState.name})';
}
