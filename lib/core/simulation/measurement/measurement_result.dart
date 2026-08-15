import 'measurement_types.dart';

/// WP-DS-005A Measurement Results — matches the governing work package's
/// "Measurement Results" list exactly (Measured value, Expected value,
/// Difference, Engineering path, Power source, Ground source, Contributing
/// relationships, Measurement timestamp, Measurement mode).
class MeasurementResult {
  const MeasurementResult({
    required this.type,
    required this.mode,
    required this.probeA,
    required this.probeB,
    required this.reachable,
    required this.timestamp,
    this.measuredValue,
    this.expectedValue,
    this.unit = '',
    this.continuous,
    this.path = const [],
    this.powerSourceId,
    this.groundSourceId,
    this.contributingRelationshipIds = const [],
    this.notes,
  });

  final MeasurementType type;
  final MeasurementMode mode;
  final ProbePoint probeA;
  final ProbePoint probeB;

  /// Whether probeB is reachable from probeA at all under current fault
  /// conditions (an open-circuit/disconnected result still returns a
  /// [MeasurementResult] with `reachable: false`, not an error).
  final bool reachable;

  final DateTime timestamp;

  /// The measured value, in [unit]. `null` when [type] has no numeric
  /// reading (e.g. a pure continuity/open-circuit result) or the point is
  /// unreachable.
  final num? measuredValue;

  /// The engineering-intended value, read from the graph's own authored
  /// `properties['expectedValue']` (see [MeasurementEngine] doc for the
  /// disclosed scope boundary this represents) — `null` when nothing was
  /// authored for this probe point.
  final num? expectedValue;

  final String unit;

  /// Set only for [MeasurementType.continuity]/[MeasurementType.diode].
  final bool? continuous;

  /// Node ids from probeA to probeB, shortest path found.
  final List<String> path;

  final String? powerSourceId;
  final String? groundSourceId;
  final List<String> contributingRelationshipIds;

  /// Human-readable disclosure for measurement types this engine does not
  /// compute from real physics (see [MeasurementEngine] doc) — e.g. "value
  /// reflects the graph's authored expected value, gated by current logical
  /// simulation state; not a computed analog reading."
  final String? notes;

  num? get difference => (measuredValue != null && expectedValue != null) ? measuredValue! - expectedValue! : null;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'mode': mode.name,
        'probeA': probeA.toJson(),
        'probeB': probeB.toJson(),
        'reachable': reachable,
        'timestamp': timestamp.toIso8601String(),
        if (measuredValue != null) 'measuredValue': measuredValue,
        if (expectedValue != null) 'expectedValue': expectedValue,
        if (difference != null) 'difference': difference,
        'unit': unit,
        if (continuous != null) 'continuous': continuous,
        'path': path,
        if (powerSourceId != null) 'powerSourceId': powerSourceId,
        if (groundSourceId != null) 'groundSourceId': groundSourceId,
        'contributingRelationshipIds': contributingRelationshipIds,
        if (notes != null) 'notes': notes,
      };

  factory MeasurementResult.fromJson(Map<String, Object?> json) => MeasurementResult(
        type: MeasurementType.values.firstWhere((t) => t.name == json['type']),
        mode: MeasurementMode.values.firstWhere((m) => m.name == json['mode']),
        probeA: ProbePoint.fromJson(Map<String, Object?>.from(json['probeA'] as Map)),
        probeB: ProbePoint.fromJson(Map<String, Object?>.from(json['probeB'] as Map)),
        reachable: json['reachable'] as bool? ?? false,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        measuredValue: json['measuredValue'] as num?,
        expectedValue: json['expectedValue'] as num?,
        unit: json['unit'] as String? ?? '',
        continuous: json['continuous'] as bool?,
        path: (json['path'] as List? ?? const []).cast<String>(),
        powerSourceId: json['powerSourceId'] as String?,
        groundSourceId: json['groundSourceId'] as String?,
        contributingRelationshipIds: (json['contributingRelationshipIds'] as List? ?? const []).cast<String>(),
        notes: json['notes'] as String?,
      );
}
