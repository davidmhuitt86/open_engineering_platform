import '../measurement/measurement_types.dart';
import 'electrical_conducting_state.dart';
import 'electrical_reading.dart';

/// PRODUCT-READINESS-004 Phase A, §7/§14 — the solved electrical state of
/// ONE branch: an electrically meaningful connection between two terminal
/// endpoints. Usually corresponds to a real [EngineeringRelationship]
/// (a wire), identified by [relationshipId] — but see §14's "physical
/// topology vs. electrical topology" distinction, which this type exists
/// to preserve, not flatten: a physical wire ([relationshipId] non-null)
/// may be present in the graph while [conductingState] is
/// [ElectricalConductingState.open] (a switch elsewhere gates it), and a
/// future branch derived purely from solving (e.g. a resistance path
/// spanning several relationships) may have no single [relationshipId] at
/// all — [relationshipId] is deliberately nullable for that reason, not an
/// oversight.
class ElectricalBranchState {
  const ElectricalBranchState({
    required this.branchId,
    required this.sourceTerminal,
    required this.destinationTerminal,
    required this.voltage,
    required this.voltageDrop,
    required this.current,
    required this.resistance,
    required this.power,
    required this.conductingState,
    required this.currentDirection,
    this.relationshipId,
  });

  /// Stable identity for this branch — the owning [relationshipId] when
  /// one exists (the common case today: one branch per wire), or a
  /// solver-assigned id for a derived, multi-relationship branch.
  final String branchId;

  final ProbePoint sourceTerminal;
  final ProbePoint destinationTerminal;

  /// The branch's own voltage (§7: "voltage"). For a simple wire this is
  /// typically the same as its higher-potential endpoint's terminal
  /// voltage; a solver is free to report this more precisely once it can.
  final ElectricalReading voltage;

  /// The potential difference actually dropped ACROSS this branch (§7:
  /// "voltage drop") — distinct from [voltage] itself, and from today's
  /// Legacy V2 solver, which does not compute a true drop at all
  /// (PRODUCT-READINESS-004's own audit: `wireV = max(fromV, toV)`
  /// discards direction/drop entirely). [ElectricalReadingState.unsupported]
  /// until a solver actually computes it.
  final ElectricalReading voltageDrop;

  final ElectricalReading current;
  final ElectricalReading resistance;
  final ElectricalReading power;

  final ElectricalConductingState conductingState;
  final ElectricalCurrentDirection currentDirection;

  /// The real [EngineeringRelationship.id] this branch corresponds to, or
  /// `null` for a derived/multi-relationship branch — see class doc
  /// comment.
  final String? relationshipId;

  Map<String, Object?> toJson() => {
        'branchId': branchId,
        'sourceTerminal': sourceTerminal.toJson(),
        'destinationTerminal': destinationTerminal.toJson(),
        'voltage': voltage.toJson(),
        'voltageDrop': voltageDrop.toJson(),
        'current': current.toJson(),
        'resistance': resistance.toJson(),
        'power': power.toJson(),
        'conductingState': conductingState.name,
        'currentDirection': currentDirection.name,
        if (relationshipId != null) 'relationshipId': relationshipId,
      };

  factory ElectricalBranchState.fromJson(Map<String, Object?> json) => ElectricalBranchState(
        branchId: json['branchId'] as String,
        sourceTerminal: ProbePoint.fromJson(Map<String, Object?>.from(json['sourceTerminal'] as Map)),
        destinationTerminal: ProbePoint.fromJson(Map<String, Object?>.from(json['destinationTerminal'] as Map)),
        voltage: ElectricalReading.fromJson(Map<String, Object?>.from(json['voltage'] as Map)),
        voltageDrop: ElectricalReading.fromJson(Map<String, Object?>.from(json['voltageDrop'] as Map)),
        current: ElectricalReading.fromJson(Map<String, Object?>.from(json['current'] as Map)),
        resistance: ElectricalReading.fromJson(Map<String, Object?>.from(json['resistance'] as Map)),
        power: ElectricalReading.fromJson(Map<String, Object?>.from(json['power'] as Map)),
        conductingState: ElectricalConductingState.values.firstWhere(
          (s) => s.name == json['conductingState'],
          orElse: () => ElectricalConductingState.unknown,
        ),
        currentDirection: ElectricalCurrentDirection.values.firstWhere(
          (d) => d.name == json['currentDirection'],
          orElse: () => ElectricalCurrentDirection.unknown,
        ),
        relationshipId: json['relationshipId'] as String?,
      );
}
