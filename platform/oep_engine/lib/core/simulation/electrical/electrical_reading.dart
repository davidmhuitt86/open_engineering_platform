import 'electrical_reading_state.dart';

/// PRODUCT-READINESS-004 Phase A — one quantity's value, paired with its
/// [ElectricalReadingState]. The single reusable building block every
/// electrical quantity (voltage, current, resistance, power) in this model
/// is expressed through, instead of four separate ad hoc "is it null, is
/// it zero, is it a sentinel" conventions.
///
/// [value] is non-null if and only if [state] is [ElectricalReadingState.valid]
/// — enforced by the named constructors below, which are the only way to
/// build one. There is no public default constructor: a caller cannot
/// accidentally construct a [state] of [ElectricalReadingState.open] that
/// still carries a numeric [value], or a [ElectricalReadingState.valid]
/// with no value.
class ElectricalReading {
  const ElectricalReading._(this.state, this.value, this.unit, this.note);

  final ElectricalReadingState state;

  /// Present only when [state] is [ElectricalReadingState.valid] — a real
  /// zero is represented here as `0.0`/`0`, never as a null/sentinel.
  final num? value;

  final String unit;

  /// Free-text context — e.g. which [SimulationFaultType] produced a
  /// [ElectricalReadingState.fault] reading, or why a quantity is
  /// [ElectricalReadingState.unsupported]. Never required for a caller to
  /// interpret [state]/[value] correctly; purely explanatory.
  final String? note;

  factory ElectricalReading.valid(num value, {String unit = '', String? note}) =>
      ElectricalReading._(ElectricalReadingState.valid, value, unit, note);

  factory ElectricalReading.unknown({String unit = '', String? note}) =>
      ElectricalReading._(ElectricalReadingState.unknown, null, unit, note);

  factory ElectricalReading.unreached({String unit = '', String? note}) =>
      ElectricalReading._(ElectricalReadingState.unreached, null, unit, note);

  factory ElectricalReading.open({String unit = '', String? note}) =>
      ElectricalReading._(ElectricalReadingState.open, null, unit, note);

  factory ElectricalReading.overload({String unit = '', String? note}) =>
      ElectricalReading._(ElectricalReadingState.overload, null, unit, note);

  factory ElectricalReading.fault({String unit = '', String? note}) =>
      ElectricalReading._(ElectricalReadingState.fault, null, unit, note);

  factory ElectricalReading.unsupported({String unit = '', String? note}) =>
      ElectricalReading._(ElectricalReadingState.unsupported, null, unit, note);

  bool get isValid => state == ElectricalReadingState.valid;

  Map<String, Object?> toJson() => {
        'state': state.name,
        if (value != null) 'value': value,
        'unit': unit,
        if (note != null) 'note': note,
      };

  factory ElectricalReading.fromJson(Map<String, Object?> json) {
    final state = ElectricalReadingState.values.firstWhere(
      (s) => s.name == json['state'],
      orElse: () => ElectricalReadingState.unknown,
    );
    final unit = json['unit'] as String? ?? '';
    final note = json['note'] as String?;
    final value = json['value'] as num?;
    return state == ElectricalReadingState.valid && value != null
        ? ElectricalReading.valid(value, unit: unit, note: note)
        : ElectricalReading._(state, null, unit, note);
  }

  @override
  bool operator ==(Object other) =>
      other is ElectricalReading &&
      other.state == state &&
      other.value == value &&
      other.unit == unit &&
      other.note == note;

  @override
  int get hashCode => Object.hash(state, value, unit, note);

  @override
  String toString() => isValid ? 'ElectricalReading($value $unit)' : 'ElectricalReading(${state.name})';
}
