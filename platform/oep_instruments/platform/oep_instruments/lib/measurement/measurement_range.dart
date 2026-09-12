/// PRODUCT-READINESS-007 §13 — a range-shaped engineering value (e.g. a
/// V2 AC-voltage reading such as `"13-16"`), preserved as real structured
/// data rather than collapsed into a single scalar. [Measurement.value]
/// may legitimately hold either a plain `num` (the common case) or one of
/// these — never a display string that would need re-parsing (the exact
/// hazard this class exists to avoid: `double.parse("13-16")` throws,
/// and a naive `parseFloat`-style prefix-scan silently yields `13`,
/// discarding the upper bound entirely).
class MeasurementRange {
  const MeasurementRange({required this.low, required this.high});

  final num low;
  final num high;

  Map<String, Object?> toJson() => {'low': low, 'high': high};

  factory MeasurementRange.fromJson(Map<String, Object?> json) =>
      MeasurementRange(low: json['low'] as num, high: json['high'] as num);

  @override
  bool operator ==(Object other) => other is MeasurementRange && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  @override
  String toString() => '$low-$high';
}
