import 'measurement_range.dart';
import 'measurement_state.dart';

/// OIP-MEASUREMENT-001 §5 — "A Measurement consists of: Identifier,
/// Timestamp, Engineering Value, Engineering Unit, Measurement Type,
/// Source, Measurement Quality, Measurement State, Session Reference."
///
/// **This class never computes a value.** Per this whole repository's
/// Constitution (§6/§13): "OEP Instruments shall never calculate
/// [voltage/current/resistance/...]... shall display exactly what is
/// received... No filtering. No smoothing. No estimation." Every
/// [Measurement] instance is constructed from a value the Host already
/// computed and sent across the Host API — this type only carries and
/// presents that value, immutably, per §4's lifecycle ("Measurements
/// remain immutable once recorded.").
class Measurement {
  const Measurement({
    required this.id,
    required this.timestamp,
    required this.value,
    required this.unit,
    required this.measurementType,
    required this.source,
    required this.quality,
    required this.state,
    required this.sessionId,
    this.engineeringObjectId,
    this.electricalState,
  });

  final String id;
  final DateTime timestamp;

  /// The engineering value as received from the Host — never computed,
  /// filtered, or adjusted by this package. Ordinarily a `num`; may also
  /// be a [MeasurementRange] for a range-shaped reading (§13) — never a
  /// pre-formatted display string.
  final Object? value;

  final String unit;
  final String measurementType;

  /// PRODUCT-READINESS-007 §3 — the Host's own structured electrical
  /// reading state (the Engine's `ElectricalReadingState` name: `'valid'`,
  /// `'unknown'`, `'unreached'`, `'open'`, `'overload'`, `'fault'`, or
  /// `'unsupported'`), carried as a plain string for the same reason
  /// [source] is one (this package has, and must keep, no dependency on
  /// `oep_engine` — see this package's own pubspec doc comment,
  /// "completely independent from engineering computation"). `null` for a
  /// Host that predates this field (backward compatible) or a source with
  /// no such concept — a receiver must not treat `null` as "valid"; see
  /// [MeasurementState] for the (distinct, lifecycle-only) fallback this
  /// class already carried before this field existed. This is the field
  /// that lets a UI distinguish OL/fault/unsupported/unknown from a real
  /// zero, rather than collapsing every non-numeric case into the same
  /// placeholder (§3's own explicit "never collapse" instruction).
  final String? electricalState;

  /// OIP-MEASUREMENT-001 §7 — where this measurement originated
  /// (`'simulationEngine'`, `'diagramStudio'`, `'physicalHardware'`,
  /// ...). A plain string, not an enum, since the Constitution (§4)
  /// explicitly treats every future source (including hardware not yet
  /// designed) identically — a closed enum here would need editing for
  /// every new source, which is exactly the kind of "no Runtime redesign
  /// for new hardware" the Constitution rules out (§20).
  final String source;

  final MeasurementQuality quality;
  final MeasurementState state;
  final String sessionId;

  /// OIP-MEASUREMENT-001 §18 — optional reference to the Engineering
  /// Object this measurement concerns (a pin, connector, wire, ...).
  final String? engineeringObjectId;

  Map<String, Object?> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'value': value is MeasurementRange ? null : value,
        if (value is MeasurementRange) 'valueRange': (value as MeasurementRange).toJson(),
        'unit': unit,
        'measurementType': measurementType,
        'source': source,
        'quality': quality.name,
        'state': state.name,
        'sessionId': sessionId,
        if (engineeringObjectId != null) 'engineeringObjectId': engineeringObjectId,
        if (electricalState != null) 'electricalState': electricalState,
      };
}
