import '../measurement/measurement_types.dart';
import 'electrical_reading.dart';

/// PRODUCT-READINESS-004 Phase A, §3/§4 — the solved electrical state of
/// ONE terminal, addressed by [terminal] (an existing [ProbePoint] — see
/// that class's own doc comment for why this reuses it rather than a new
/// terminal-id type: `ProbePoint.nodeId` is the owning
/// [EngineeringNode.id], `ProbePoint.portId` is the specific [Port.id] on
/// it, exactly the "componentId + terminalId" address §4 asks for;
/// `ProbePoint.relationshipId` is always `null` here — that field is only
/// meaningful for the OTHER existing use of [ProbePoint], probing a point
/// along a wire, which is a different concept from a component's own
/// terminal).
///
/// This is the type that makes the model genuinely terminal-centric rather
/// than node-centric (§3: "Do not assume component == electrical node"):
/// two different [ElectricalTerminalState]s can — and for a multi-terminal
/// component like a battery, MUST be able to — exist for the same
/// [ProbePoint.nodeId] with different [ProbePoint.portId]s, carrying
/// independently different [voltage] readings. This is precisely what the
/// current Legacy V2 solver's own graph model CANNOT represent (confirmed,
/// PRODUCT-READINESS-004's own audit: one voltage value per node, not per
/// terminal — see that audit's STOP CONDITION) — establishing this type is
/// the foundational fix that audit called for, without yet requiring a
/// full terminal-aware resistive solve to populate it (a solver may
/// legitimately produce two [ElectricalTerminalState]s for the same node
/// with an IDENTICAL [voltage] today, honestly reflecting today's
/// per-node-precision solve, while the TYPE itself no longer forces that
/// collapse the way the old node-keyed `Map<String, num>` did).
class ElectricalTerminalState {
  const ElectricalTerminalState({
    required this.terminal,
    required this.voltage,
    required this.current,
    this.isSourceTerminal = false,
    this.isReferenceTerminal = false,
  });

  /// This terminal's own stable address — see class doc comment.
  final ProbePoint terminal;

  /// Voltage at this terminal, relative to the solved state's own
  /// reference/ground (§2 NODE STATE's "reference/ground").
  final ElectricalReading voltage;

  /// Current into/out of this terminal. [ElectricalReadingState.unsupported]
  /// today for every solver that has no Ohm's-law model (PRODUCT-
  /// READINESS-004's own audit finding) — never fabricated.
  final ElectricalReading current;

  /// True when this terminal is a modeled power source (e.g. a battery's
  /// `+` post) — §2 TERMINAL STATE's "source/reference identity".
  final bool isSourceTerminal;

  /// True when this terminal is a modeled ground/return reference (e.g. a
  /// chassis ground point, or a battery's `-` post once genuinely
  /// terminal-distinguished — see class doc comment).
  final bool isReferenceTerminal;

  /// Energized per §2 NODE STATE — derived from [voltage], never stored
  /// redundantly: `true` only for a real, nonzero [ElectricalReading.valid]
  /// voltage. A [voltage] that is [ElectricalReadingState.unknown]/
  /// [ElectricalReadingState.unreached]/etc. is honestly neither energized
  /// nor de-energized — it's undetermined, so this returns `false` rather
  /// than fabricating a definite answer (a caller that needs to
  /// distinguish "confirmed de-energized" from "undetermined" must inspect
  /// [voltage].state directly, not this convenience getter).
  bool get isEnergized => voltage.isValid && (voltage.value ?? 0) != 0;

  Map<String, Object?> toJson() => {
        'terminal': terminal.toJson(),
        'voltage': voltage.toJson(),
        'current': current.toJson(),
        'isSourceTerminal': isSourceTerminal,
        'isReferenceTerminal': isReferenceTerminal,
      };

  factory ElectricalTerminalState.fromJson(Map<String, Object?> json) => ElectricalTerminalState(
        terminal: ProbePoint.fromJson(Map<String, Object?>.from(json['terminal'] as Map)),
        voltage: ElectricalReading.fromJson(Map<String, Object?>.from(json['voltage'] as Map)),
        current: ElectricalReading.fromJson(Map<String, Object?>.from(json['current'] as Map)),
        isSourceTerminal: json['isSourceTerminal'] as bool? ?? false,
        isReferenceTerminal: json['isReferenceTerminal'] as bool? ?? false,
      );
}
