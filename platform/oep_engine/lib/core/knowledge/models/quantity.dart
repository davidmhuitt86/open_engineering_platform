/// Dimension, Unit, and Quantity — AP-EK-003 (Quantity and Unit Engine),
/// as consumed through the Knowledge Runtime (AP-EK-013 §20).
///
/// Dimensions are represented as SI base-quantity exponent vectors
/// (kg, m, s, A) rather than an enumerated list of named dimensions, so
/// that quantity arithmetic (division, multiplication) is dimensionally
/// checked by actual exponent algebra instead of a hardcoded lookup table
/// of "which combination produces which named result". This keeps the
/// first vertical slice's four dimensions (voltage, current, resistance,
/// power) genuinely composable rather than special-cased.
library;

/// SI base-quantity exponent vector. Only the bases needed by electrical
/// DC quantities are modelled (kg, m, s, A) — mol/cd/K are out of scope
/// for the first vertical slice (AP-EK-020 §4 non-goals).
class DimensionExponents {
  final int kg;
  final int m;
  final int s;
  final int a;

  const DimensionExponents({this.kg = 0, this.m = 0, this.s = 0, this.a = 0});

  DimensionExponents operator *(DimensionExponents other) => DimensionExponents(
    kg: kg + other.kg,
    m: m + other.m,
    s: s + other.s,
    a: a + other.a,
  );

  DimensionExponents operator /(DimensionExponents other) => DimensionExponents(
    kg: kg - other.kg,
    m: m - other.m,
    s: s - other.s,
    a: a - other.a,
  );

  @override
  bool operator ==(Object other) =>
      other is DimensionExponents &&
      other.kg == kg &&
      other.m == m &&
      other.s == s &&
      other.a == a;

  @override
  int get hashCode => Object.hash(kg, m, s, a);

  @override
  String toString() => 'kg^$kg·m^$m·s^$s·A^$a';
}

/// A physical dimension known to the runtime (AP-EK-013 §20 `dimension`).
class Dimension {
  final String id;
  final String name;
  final DimensionExponents exponents;

  const Dimension({
    required this.id,
    required this.name,
    required this.exponents,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'exponents': {
      'kg': exponents.kg,
      'm': exponents.m,
      's': exponents.s,
      'a': exponents.a,
    },
  };

  factory Dimension.fromJson(Map<String, Object?> json) {
    final exp = Map<String, Object?>.from(json['exponents'] as Map);
    return Dimension(
      id: json['id'] as String,
      name: json['name'] as String,
      exponents: DimensionExponents(
        kg: (exp['kg'] as num?)?.toInt() ?? 0,
        m: (exp['m'] as num?)?.toInt() ?? 0,
        s: (exp['s'] as num?)?.toInt() ?? 0,
        a: (exp['a'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// A unit of measure (AP-EK-013 §20). `scaleToBase` converts a value in
/// this unit to the SI-coherent base value for its dimension — all four
/// units required by the first slice (volt/ampere/ohm/watt) are already
/// SI-coherent, so `scaleToBase == 1.0` for each; unit-prefix scaling
/// (mV, kΩ, ...) is out of scope for the first vertical slice.
class Unit {
  final String id;
  final String symbol;
  final String dimensionId;
  final double scaleToBase;
  final List<String> aliases;

  const Unit({
    required this.id,
    required this.symbol,
    required this.dimensionId,
    this.scaleToBase = 1.0,
    this.aliases = const [],
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'symbol': symbol,
    'dimensionId': dimensionId,
    'scaleToBase': scaleToBase,
    'aliases': aliases,
  };

  factory Unit.fromJson(Map<String, Object?> json) => Unit(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    dimensionId: json['dimensionId'] as String,
    scaleToBase: (json['scaleToBase'] as num?)?.toDouble() ?? 1.0,
    aliases: (json['aliases'] as List? ?? const []).cast<String>(),
  );
}

/// A typed engineering quantity: a numeric value paired with its resolved
/// [Unit] and [Dimension] — never a raw `double` flowing through the
/// analysis pipeline where a dimensionally-meaningful value is required
/// (AP-EK-020 §13).
class Quantity {
  final double value;
  final Unit unit;
  final Dimension dimension;

  const Quantity(this.value, this.unit, this.dimension);

  /// Value expressed in the SI-coherent base for [dimension].
  double get baseValue => value * unit.scaleToBase;

  @override
  String toString() => '$value ${unit.symbol}';

  Map<String, Object?> toJson() => {'value': value, 'unitId': unit.id};
}

/// Thrown when an operation would combine or produce quantities whose
/// dimensions do not match a known, registered [Dimension].
class DimensionMismatchException implements Exception {
  final String message;
  const DimensionMismatchException(this.message);

  @override
  String toString() => 'DimensionMismatchException: $message';
}
