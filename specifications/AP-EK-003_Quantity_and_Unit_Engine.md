# AP-EK-003
# Quantity + Unit Engine
## Deterministic Engineering Quantity, Unit, and Dimensional Analysis Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessor:** AP-EK-002 — Reference Compiler Boundary  
**Primary consumers:** OEP Engine / Engineering Analysis  
**Presentation consumer:** Diagram Studio

---

## 1. Purpose

Define the deterministic quantity and unit subsystem required for OEP engineering analysis.

This subsystem establishes a common mathematical foundation for engineering values such as:

```text
12.6 V
4.2 A
10 Ω
14.4 W
```

It SHALL provide:

- explicit engineering quantities;
- unit identity;
- dimensional analysis;
- deterministic conversion;
- arithmetic validation;
- precision/representation rules;
- serialization;
- comparison;
- diagnostics.

This subsystem is foundational to the Equation Engine and therefore precedes AP-EK-004.

---

## 2. Architectural Principle

A number without engineering meaning is not sufficient for engineering analysis.

The system must distinguish:

```text
12
12 V
12 A
12 Ω
```

These are not interchangeable.

Therefore, whenever engineering semantics require a physical unit, OEP SHALL represent the value as:

```text
Quantity
  value
  unit
```

The Quantity + Unit Engine is deterministic and contains no LLM dependency.

---

## 3. Authority Boundary

The Quantity + Unit Engine is an execution capability.

It does NOT author engineering knowledge.

```text
Reference Library
      |
      v
canonical unit definitions
      |
      v
Reference Compiler
      |
      v
runtime unit registry
      |
      v
Quantity + Unit Engine
      |
      v
Equation Engine
```

Canonical unit definitions originate from the authoritative knowledge pipeline.

The runtime may normalize them for execution but must retain identity/version information.

---

## 4. Core Concepts

The subsystem has five primary concepts:

```text
Quantity
Unit
Dimension
Conversion
Measurement
```

### Quantity

A numerical engineering value paired with a unit.

### Unit

A named representation of a physical dimension.

### Dimension

The dimensional structure underlying a unit.

### Conversion

A deterministic transformation between compatible units.

### Measurement

A quantity associated with a measured or observed engineering value and optional uncertainty/observation metadata.

Measurement support is architectural groundwork; uncertainty analysis is outside the first vertical slice.

---

## 5. Quantity Contract

Conceptual model:

```text
Quantity
  value
  unitId
```

Runtime metadata MAY additionally retain:

```text
dimensionId
precision
significantDigits
source
```

Example:

```text
Quantity
  value: 12.6
  unitId: volt
```

The canonical unit registry determines the dimension and conversion behavior.

---

## 6. Quantity Identity

A Quantity is a value, not an Engineering Object by default.

It does not require a UUID simply because it exists during calculation.

However, when a quantity is persisted as an engineering fact, measurement, component property, or derived result, the containing Engineering Object/analysis model provides the identity and provenance.

This prevents every temporary calculation value from becoming a repository object.

---

## 7. Unit Contract

Conceptual model:

```text
Unit
  unitId
  symbol
  name
  dimensionId
  scale
  offset
```

Examples:

```text
volt
  symbol: V
  dimension: electrical_potential

ampere
  symbol: A
  dimension: electric_current

ohm
  symbol: Ω
  dimension: electrical_resistance

watt
  symbol: W
  dimension: power
```

The actual canonical unit definitions remain subject to the Reference Library schema.

---

## 8. Dimension Contract

Dimensions provide mathematical compatibility independent of the displayed unit.

A dimension may be represented using base-dimension exponents.

Conceptual example:

```text
Voltage
  M¹ L² T⁻³ I⁻¹

Current
  I¹

Resistance
  M¹ L² T⁻³ I⁻²

Power
  M¹ L² T⁻³
```

The exact base-dimension system should be standardized during implementation, but the engine must support dimensional composition.

---

## 9. Dimensional Signature

Every runtime unit resolves to a deterministic dimensional signature.

Conceptual representation:

```text
DimensionSignature
  mass
  length
  time
  current
  temperature
  amount
  luminosity
```

with integer exponents.

Example:

```text
volt:
  M^1 L^2 T^-3 I^-1
```

Two units are dimensionally compatible when their signatures are equal.

---

## 10. SI Base Units

The initial implementation should establish SI base dimensions and units as the computational foundation.

At minimum:

```text
meter
kilogram
second
ampere
kelvin
mole
candela
```

The engine may support additional domain-specific dimensions later.

---

## 11. Derived Units

Derived units are represented through dimensional composition and may have named aliases.

Initial electrical examples:

```text
volt
ohm
watt
coulomb
farad
henry
siemens
joule
```

The runtime must preserve both:

```text
named unit identity
underlying dimension
```

---

## 12. Unit Conversion

Conversion SHALL be deterministic.

For the initial implementation, conversion should support:

```text
linear scale
offset + scale
```

Conceptual:

```text
baseValue = (value + sourceOffset) * sourceScale
targetValue = baseValue / targetScale - targetOffset
```

The exact convention for offset storage must be fixed before implementation and covered by tests.

This permits units such as temperature to be represented correctly without treating every conversion as a simple multiplication.

---

## 13. Compatibility

The engine SHALL distinguish:

```text
IDENTICAL
CONVERTIBLE
INCOMPATIBLE
UNKNOWN
```

Examples:

```text
12 V -> 12000 mV
  CONVERTIBLE

12 V + 3 V
  VALID

12 V + 3 A
  INCOMPATIBLE
```

Unknown units must not be silently treated as compatible.

---

## 14. Arithmetic Rules

The Quantity Engine SHALL define deterministic arithmetic semantics.

### Addition/Subtraction

Allowed only for compatible dimensions.

```text
12 V + 3 V = 15 V
```

Compatible units should be normalized as necessary.

### Multiplication

Dimensions multiply.

```text
V * A = W
```

### Division

Dimensions divide.

```text
V / Ω = A
```

### Power

Dimensions are exponentiated.

```text
Ω * A² = W
```

### Scalar operations

A dimensionless scalar may multiply or divide a quantity.

```text
12 V * 2 = 24 V
```

A quantity SHALL NOT be silently treated as a dimensionless scalar.

---

## 15. Dimensionless Quantities

The engine SHALL support dimensionless quantities.

Examples include:

```text
ratio
gain
efficiency
coefficient
percentage
```

Dimensionless values may be represented with:

```text
dimension = dimensionless
```

Percentages are presentation/scale semantics and must not be confused with arbitrary unit compatibility.

---

## 16. Comparison

Quantity comparisons are allowed only between compatible dimensions.

```text
12 V > 10 V
```

is valid.

```text
12 V > 10 A
```

is invalid.

The engine must report an explicit dimensional incompatibility.

---

## 17. Equality and Precision

Floating-point equality SHALL NOT be used blindly for engineering comparisons.

The subsystem must define comparison behavior.

At minimum:

```text
exact representation comparison
tolerance comparison
```

The tolerance policy must be explicit and must never silently change between analyses.

The analysis engine should record the relevant precision/tolerance policy when it materially affects a conclusion.

---

## 18. Numeric Representation

The implementation must choose and document the numeric representation used for calculations.

The initial implementation should prioritize:

```text
determinism
sufficient engineering precision
cross-platform reproducibility
stable serialization
```

The architecture must not assume that binary floating-point is automatically sufficient for every future engineering domain.

The numeric type should therefore be abstracted behind the Quantity Engine API.

---

## 19. Parsing

Human-readable quantities may eventually be parsed:

```text
12 V
4.2 A
10 kΩ
```

Parsing is a convenience boundary, not the authoritative representation.

Internally the engine must operate on:

```text
numeric value
+
canonical unit identity
```

Parsing failures must be explicit.

---

## 20. Formatting

Formatting is presentation behavior.

The core engine should provide normalized data.

A presentation layer may render:

```text
12 V
12.00 V
12.000 V
```

according to user settings or analysis requirements.

Formatting MUST NOT alter the underlying engineering quantity.

---

## 21. Prefixes

The initial unit registry should support SI prefixes.

Examples:

```text
milli 10^-3
micro 10^-6
nano  10^-9
kilo  10^3
mega  10^6
giga  10^9
```

Prefixes should be represented deterministically rather than creating uncontrolled duplicate unit definitions.

For example:

```text
kΩ
```

should resolve to:

```text
ohm × 10^3
```

while preserving the displayed symbol when requested.

---

## 22. Derived-Unit Reduction

The engine should be able to reduce a compound dimensional expression to a canonical dimension.

Example:

```text
V / Ω
```

reduces to:

```text
A
```

and:

```text
V * A
```

reduces to:

```text
W
```

Named-unit simplification is optional for the first implementation, but dimensional equivalence is mandatory.

---

## 23. Quantity Provenance

A Quantity used in analysis must be classifiable as:

```text
INPUT
REFERENCE
MEASUREMENT
CALCULATED
ASSUMPTION
```

The Quantity Engine itself does not decide engineering authority.

It preserves the metadata supplied by the analysis layer.

---

## 24. Measurement Foundation

Measurements may contain:

```text
Quantity
timestamp
instrument/source
measurementState
uncertainty
```

The initial Quantity Engine need only preserve the structure.

Uncertainty propagation is a future architecture increment.

---

## 25. Error Model

Errors SHALL be structured.

Conceptual categories:

```text
UNKNOWN_UNIT
UNKNOWN_DIMENSION
INVALID_QUANTITY
INCOMPATIBLE_DIMENSIONS
INVALID_CONVERSION
DIVISION_BY_ZERO
INVALID_EXPONENT
INVALID_NUMERIC_VALUE
PRECISION_POLICY_ERROR
```

An error must identify the operation and relevant operands where possible.

---

## 26. Example

Given:

```text
V = 12.0 V
R = 10 Ω
```

The Quantity Engine evaluates:

```text
V / R
```

Dimensionally:

```text
voltage / resistance
=
current
```

Numerically:

```text
12.0 / 10 = 1.2
```

Result:

```text
1.2 A
```

The Equation Engine will later use this result as the output of Ohm's Law.

---

## 27. Example — Invalid Operation

Given:

```text
V = 12 V
I = 2 A
```

Operation:

```text
V + I
```

Result:

```text
ERROR
INCOMPATIBLE_DIMENSIONS

voltage != electric_current
```

No numeric result is produced.

---

## 28. Example — Conversion

Given:

```text
12 V
```

Convert to millivolts:

```text
12 V
=
12000 mV
```

The conversion must preserve dimension:

```text
voltage -> voltage
```

and alter only representation/value scale.

---

## 29. Registry Contract

The runtime SHALL expose a unit registry.

Conceptually:

```text
UnitRegistry
  getUnit(unitId)
  findBySymbol(symbol)
  getDimension(unitId)
  convert(quantity, targetUnit)
  areCompatible(unitA, unitB)
```

The registry must be immutable during an analysis session.

Changing the unit registry requires a new runtime knowledge version.

---

## 30. Runtime Loading

The runtime should load unit definitions from the compiled Knowledge Runtime package.

It must not depend on raw Reference Library files during calculation.

```text
Runtime Package
      |
      v
Unit Registry
      |
      v
Quantity Engine
```

This preserves offline operation.

---

## 31. Serialization

Quantities must serialize without losing engineering meaning.

Minimum:

```text
{
  value: ...,
  unitId: ...
}
```

When required:

```text
dimensionId
precisionPolicy
provenance
```

must also be retained.

Serialized quantities must be deterministic.

---

## 32. Cross-Platform Requirement

The Quantity Engine must produce equivalent results across:

```text
Windows
Linux
macOS
Android
iOS
```

for identical inputs, unit registry version, numeric policy, and engine version.

Platform-specific UI formatting must not change calculation semantics.

---

## 33. Equation Engine Interface

AP-EK-004 will consume this API.

Conceptually:

```text
QuantityEngine.add(a, b)
QuantityEngine.subtract(a, b)
QuantityEngine.multiply(a, b)
QuantityEngine.divide(a, b)
QuantityEngine.power(a, exponent)
QuantityEngine.convert(quantity, unit)
QuantityEngine.compare(a, b)
QuantityEngine.areCompatible(a, b)
```

The Equation Engine should not duplicate unit logic.

---

## 34. Testing

### Unit identity

- known units resolve;
- unknown units fail;
- symbols resolve unambiguously.

### Conversion

- V → mV;
- kΩ → Ω;
- compatible conversions preserve dimensions;
- incompatible conversions fail.

### Arithmetic

```text
12 V + 3 V = 15 V
12 V / 10 Ω = 1.2 A
12 V * 2 A = 24 W
```

### Invalid arithmetic

```text
12 V + 2 A -> error
12 V > 2 A -> error
```

### Dimension algebra

```text
V / Ω -> A
V * A -> W
```

### Precision

- deterministic tolerance behavior;
- stable serialization;
- cross-platform reproducibility.

### Error handling

Every invalid operation produces a structured diagnostic.

---

## 35. Definition of Done

AP-EK-003 is complete when:

1. Quantity and Unit contracts are implemented;
2. dimensional signatures are implemented;
3. SI base dimensions are defined;
4. unit registry is deterministic;
5. compatible conversion works;
6. dimensional arithmetic works;
7. incompatible arithmetic fails;
8. structured diagnostics exist;
9. serialization is deterministic;
10. runtime unit definitions can be loaded from the Knowledge Runtime;
11. cross-platform behavior is specified/testable;
12. AP-EK-004 can implement equations without duplicating unit logic.

---

## 36. Follow-On

```text
AP-EK-004  Deterministic Equation Engine
AP-EK-005  Electrical Law Library
AP-EK-006  Component Behavior Models
AP-EK-007  Circuit Analysis
AP-EK-008  Constraint Evaluation
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/DS Analysis API
```

---

## Architectural Non-Negotiables

1. Engineering quantities carry explicit units.
2. Dimensional compatibility is deterministic.
3. Unit conversion is deterministic.
4. The Quantity Engine does not author knowledge.
5. The runtime unit registry is versioned.
6. Raw reference files are not required during analysis.
7. Incompatible dimensional operations fail rather than guess.
8. Quantity logic is centralized and not duplicated in the Equation Engine or DS.
9. Numeric representation is abstracted sufficiently to preserve future engineering precision requirements.
10. The subsystem remains independent of Flutter/UI.
11. AI is not involved in calculation.
12. Existing OEP package/version/integrity conventions are reused.
