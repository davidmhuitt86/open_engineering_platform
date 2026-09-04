# AP-EK-018
# Frequency-Domain / Complex Quantity Implementation
## Deterministic AC Analysis, Phasors, Impedance, Admittance, Frequency Sweeps, and Small-Signal Foundations

**Status:** Architecture Phase — Implementation Specification  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-001 through AP-EK-017  
**Primary objective:** Define the first implementable frequency-domain electrical analysis architecture using complex quantities while preserving the deterministic OEP Knowledge Runtime, Engineering Analysis, provenance, persistence, explanation, and Diagram Studio boundaries.

---

## 1. Purpose

AP-EK-018 extends electrical analysis from:

```text
DC steady-state
nonlinear DC
time-domain transient
```

to:

```text
AC frequency-domain analysis
```

Frequency-domain analysis represents sinusoidal steady-state behavior using complex quantities.

The first implementation must establish deterministic support for:

```text
phasor voltage
phasor current
complex impedance
complex admittance
phase
magnitude
frequency
frequency sweeps
AC sources
R/L/C behavior
network solution
power quantities
provenance
```

---

## 2. Scope

This specification covers:

```text
complex quantities
complex arithmetic
phasor representation
polar/rectangular representation
impedance
admittance
frequency-dependent component models
frequency-domain MNA
AC source models
frequency sweeps
phase/magnitude results
complex power
small-signal boundary preparation
deterministic frequency ordering
```

It does not fully implement:

```text
nonlinear large-signal harmonic balance
electromagnetic field analysis
transmission-line field solvers
RF distributed networks
noise analysis
full semiconductor AC models
```

Those remain future extensions.

---

## 3. Architectural Position

The frequency-domain pipeline is:

```text
DiagramDocument
      ↓
Engineering Graph
      ↓
Topology Extraction
      ↓
Component Model Resolution
      ↓
Frequency-Domain Model Resolution
      ↓
Complex System Assembly
      ↓
Complex Linear Solver
      ↓
Constraint Evaluation
      ↓
Provenance / Derivation
      ↓
AnalysisResult
      ↓
Explanation / Diagram Studio
```

---

## 4. Analysis Mode

Use:

```text
AC_FREQUENCY_DOMAIN
```

for sinusoidal steady-state analysis.

This mode must be explicit in:

```text
AnalysisRequest
AnalysisResult
AnalysisSnapshot
```

---

## 5. Frequency-Domain Assumption

Initial AC analysis assumes:

```text
linear time-invariant
steady-state
sinusoidal excitation
```

unless an explicitly defined extension changes the analysis model.

A nonlinear component must not silently be treated as linear.

---

## 6. Complex Quantity

AP-EK-003 defines the physical Quantity/Unit architecture.

AP-EK-018 extends numeric representation so a quantity may carry a complex value.

Conceptually:

```text
ComplexQuantity
  real
  imaginary
  unit
  dimension
```

Example:

```text
Z = 10 + j5 Ω
```

---

## 7. Complex Number Representation

The runtime should support:

```text
rectangular:
a + jb

polar:
r ∠ θ
```

The canonical internal representation should be deterministic.

Recommended:

```text
rectangular complex value
```

with polar form treated as a presentation/derived representation.

---

## 8. Complex Quantity Identity

The physical quantity remains:

```text
Quantity + Unit
```

The complex numeric representation is an extension of its value.

It must not create a second unit system.

---

## 9. Complex Arithmetic

Required:

```text
addition
subtraction
multiplication
division
conjugate
magnitude
phase
```

Future:

```text
complex power
square root
logarithm
exponential
trigonometric functions
```

Only functions required by authoritative models should be implemented initially.

---

## 10. Dimensional Validation

Complex arithmetic does not change physical dimensions.

Examples:

```text
V / Ω = A
V × A = W
```

The Quantity/Unit Engine remains responsible for dimensional correctness.

---

## 11. Phase

Phase is a dimensionless angular quantity.

The system must define:

```text
radians
degrees
```

with one canonical internal representation.

Recommended:

```text
radians
```

---

## 12. Phase Normalization

A phase representation requires deterministic normalization.

Example policy:

```text
[-π, π)
```

or:

```text
[0, 2π)
```

The chosen canonical interval must be explicit.

Phase unwrapping for frequency sweeps is a separate derived presentation operation.

---

## 13. Frequency

Frequency is an explicit Quantity.

Initial unit:

```text
Hz
```

Future:

```text
kHz
MHz
GHz
```

must use the standard Unit Engine prefix system.

---

## 14. Angular Frequency

The system may derive:

```text
ω = 2πf
```

with:

```text
ω = rad/s
```

The relationship must be represented through the Equation/Quantity architecture rather than hidden in DS.

---

## 15. Phasor Convention

The analysis must define a single sinusoidal convention.

Recommended:

```text
x(t) = Re{X e^(jωt)}
```

The convention must be stored in the analysis policy.

Changing convention changes sign conventions for reactive quantities and phase.

---

## 16. RMS vs Peak

AC quantities may use:

```text
peak
RMS
```

The analysis must explicitly declare the amplitude convention.

Recommended default for AC power calculations:

```text
RMS phasors
```

Conversion between peak and RMS must be explicit.

---

## 17. AC Source Model

An AC source requires:

```text
magnitude
phase
frequency
amplitudeConvention
sourceReference
```

Example:

```text
V = 12 ∠ 0° V RMS
f = 60 Hz
```

---

## 18. Frequency Matching

Initial single-frequency AC analysis requires sources in the system to share a common frequency.

If incompatible frequencies exist:

```text
INCOMPATIBLE_FREQUENCIES
```

must be returned.

Do not silently select one frequency.

---

## 19. Frequency Sweep

A frequency sweep evaluates the system at multiple frequencies.

Conceptual:

```text
FrequencySweep
  start
  stop
  points
  spacing
```

Spacing may be:

```text
linear
logarithmic
explicit list
```

---

## 20. Sweep Determinism

The generated frequency list must be deterministic.

For logarithmic sweeps, the exact generation policy must define:

```text
point count
endpoint inclusion
rounding
duplicate handling
```

---

## 21. Frequency Ordering

Frequency results must use a deterministic ordering:

```text
ascending frequency
```

unless an explicit alternate ordering is requested.

---

## 22. Component Frequency Models

Frequency-dependent components expose frequency-domain behavior.

Initial models:

```text
resistor
capacitor
inductor
```

---

## 23. Resistor Impedance

For an ideal resistor:

```text
Z_R = R
```

The impedance is purely real.

---

## 24. Capacitor Impedance

For an ideal capacitor:

```text
Z_C = 1 / (jωC)
```

Equivalent:

```text
Z_C = -j / (ωC)
```

The model must define behavior at:

```text
f = 0
```

explicitly.

Do not silently divide by zero.

---

## 25. Inductor Impedance

For an ideal inductor:

```text
Z_L = jωL
```

The model must define behavior at:

```text
f = 0
```

explicitly.

---

## 26. Admittance

The system may use:

```text
Y = 1/Z
```

where appropriate.

Initial component admittances:

```text
Y_R = 1/R
Y_C = jωC
Y_L = 1/(jωL)
```

The chosen network representation must be explicit.

---

## 27. MNA Representation

Frequency-domain network analysis should use a complex extension of Modified Nodal Analysis.

Conceptually:

```text
A(f) X(f) = B(f)
```

where:

```text
A = complex system matrix
X = complex unknown vector
B = complex source vector
```

---

## 28. Unknowns

Typical unknowns:

```text
node voltage phasors
branch currents
auxiliary source currents
```

Unknown identity/order must be deterministic.

---

## 29. Complex Linear Solver

The solver abstraction should support:

```text
ComplexLinearSolver
```

with:

```text
solve(A, B)
```

It may initially be implemented using the same mathematical linear-solver architecture as the DC solver with complex scalar support.

---

## 30. Solver Reuse

Do not create a completely separate matrix/solver architecture merely because values are complex.

Reuse:

```text
matrix abstraction
assembly
ordering
factorization concepts
diagnostics
```

with complex numeric types.

---

## 31. Singular Systems

If:

```text
A(f)
```

is singular:

```text
SINGULAR_FREQUENCY_SYSTEM
```

must be reported.

The solver must not silently add conductance or modify the circuit.

---

## 32. Ill-Conditioning

Near-singular systems should produce an explicit warning/diagnostic where detected.

Example:

```text
ILL_CONDITIONED_FREQUENCY_SYSTEM
```

Condition indicators and thresholds must be deterministic.

---

## 33. Ground / Reference

The same electrical reference-node architecture used by DC/transient analysis applies.

Frequency-domain analysis must not invent a different reference-node convention.

---

## 34. KCL in Frequency Domain

KCL remains valid for phasor currents:

```text
Σ I = 0
```

The Constraint Engine may evaluate complex residuals.

Residual magnitude must be defined for constraint evaluation.

---

## 35. KVL in Frequency Domain

KVL remains:

```text
Σ V = 0
```

using complex voltage phasors.

Phase information is retained.

---

## 36. Magnitude

For:

```text
X = a + jb
```

magnitude is:

```text
|X| = sqrt(a² + b²)
```

Magnitude is derived data.

---

## 37. Phase

For:

```text
X = a + jb
```

phase is:

```text
atan2(b, a)
```

The canonical phase convention must be used.

---

## 38. Impedance Presentation

DS may display:

```text
Z = 10 + j5 Ω
```

or:

```text
|Z| = 11.18 Ω
∠Z = 26.565°
```

These are equivalent representations of the same complex Quantity.

---

## 39. Complex Power

With RMS phasors:

```text
S = V × I*
```

where `*` denotes complex conjugate.

Then:

```text
S = P + jQ
```

where:

```text
P = real(S)
Q = imaginary(S)
```

and:

```text
|S| = apparent power
```

---

## 40. Power Factor

Power factor may be derived as:

```text
PF = P / |S|
```

The system should preserve the sign of reactive power separately from magnitude.

---

## 41. Power Constraints

The Constraint Engine may evaluate:

```text
real power limit
apparent power limit
reactive power limit
current rating
voltage rating
```

The applicability of each constraint must be explicit.

---

## 42. Frequency Response

A frequency sweep produces:

```text
AnalysisTrajectory
```

over frequency rather than time.

Conceptually:

```text
f[]
V(f)[]
I(f)[]
Z(f)[]
S(f)[]
```

---

## 43. Frequency-Domain Result

Conceptual:

```text
FrequencyDomainResult
  frequencies[]
  nodeVoltages[]
  branchCurrents[]
  componentResponses[]
  powerResults[]
  constraints[]
  diagnostics[]
```

---

## 44. Transfer Function

Future analysis may calculate:

```text
H(f) = Y(f) / X(f)
```

where:

```text
X = input phasor
Y = output phasor
```

The transfer-function operation should be an explicit analysis output, not a DS calculation.

---

## 45. Gain

Magnitude gain may be presented as:

```text
|H|
```

or:

```text
20 log10(|H|)
```

The equation must be represented through the deterministic Equation Engine.

---

## 46. Phase Response

Transfer-function phase is:

```text
∠H
```

Phase unwrapping across frequency is a presentation/derived-analysis operation with explicit policy.

---

## 47. Bode Data

A future output representation may contain:

```text
frequency
magnitude
phase
```

The solver should produce canonical complex response data first.

Bode rendering remains DS responsibility.

---

## 48. Resonance

RLC networks may exhibit resonance.

The system may identify resonance through explicit analysis operations.

It must not label a frequency "resonant" merely because it looks visually significant.

---

## 49. Bandwidth

Bandwidth is a derived engineering result.

A future operation may calculate:

```text
lower cutoff
upper cutoff
bandwidth
```

using an explicit criterion such as:

```text
-3 dB
```

The criterion must be represented as an explicit constraint/analysis policy.

---

## 50. Small-Signal Boundary

AP-EK-011 identifies:

```text
SMALL_SIGNAL
```

as a future analysis mode.

AP-EK-018 prepares the complex quantity infrastructure required for small-signal AC analysis.

A nonlinear device may eventually be linearized around a DC operating point:

```text
nonlinear DC operating point
        ↓
linearization
        ↓
small-signal complex model
        ↓
AC analysis
```

This is not part of the first implementation.

---

## 51. Small-Signal Model Identity

A future linearized component model must record:

```text
original model
operating point
linearization method
linearized parameter values
frequency range
```

---

## 52. Nonlinear AC Boundary

The initial AC solver must reject unsupported nonlinear large-signal behavior.

It must not silently replace:

```text
nonlinear device
```

with:

```text
linear resistor
```

unless an explicit small-signal model is selected.

---

## 53. Harmonics

A sinusoidal steady-state solver does not automatically model harmonic generation.

Nonlinear harmonic behavior belongs to a future:

```text
HARMONIC_BALANCE
```

or equivalent analysis mode.

---

## 54. Frequency-Dependent Constraints

Constraints may apply only within a frequency range.

Example:

```text
|V| <= 5 V
for:
100 Hz <= f <= 10 kHz
```

Applicability must be explicit.

---

## 55. Constraint Residuals

Complex constraints need a declared comparison operation.

Possible:

```text
magnitude
real component
imaginary component
phase
complex equality residual
```

A constraint must specify which interpretation applies.

---

## 56. Complex Equality

A complex equality:

```text
X = Y
```

should be evaluated through:

```text
|X - Y| <= tolerance
```

with a declared tolerance policy.

---

## 57. Complex Tolerances

Tolerance may be:

```text
absolute complex magnitude
relative magnitude
component-wise
```

The policy must be explicit.

---

## 58. Zero Frequency

At:

```text
f = 0
```

reactive components require special handling.

The model must define:

```text
capacitor → open circuit in ideal steady-state DC limit
inductor → short circuit in ideal steady-state DC limit
```

if the analysis explicitly supports the zero-frequency limit.

These are model semantics, not numerical hacks.

---

## 59. Near-Zero Frequency

Numerically small frequencies must not automatically be treated as exactly zero.

The model should use explicit thresholds only when defined by the numerical policy.

---

## 60. Complex Unit Presentation

Examples:

```text
12 + j0 V
0 - j2.65 A
10 + j5 Ω
```

The unit applies to the complete complex quantity.

---

## 61. Quantity Serialization

Canonical serialization should preserve:

```text
real
imaginary
unit
```

with deterministic numeric formatting.

Polar representation should not replace canonical rectangular storage.

---

## 62. Frequency Sweep Serialization

Persist:

```text
sweep definition
generated frequencies
frequency ordering policy
analysis configuration
```

where required for reproducibility.

---

## 63. Frequency Sweep Caching

A cache key should include:

```text
documentHash
knowledgeHash
runtimeVersion
solverVersion
analysisMode
frequencySweepDefinition
numericPolicy
requestedOutputs
```

---

## 64. Parallel Frequency Evaluation

Each frequency point may be mathematically independent for an LTI system.

Parallel execution may be used.

However, output ordering must remain deterministic.

---

## 65. Frequency-Point Failure

If one frequency fails:

```text
f = 10 kHz → success
f = 20 kHz → singular
f = 30 kHz → success
```

the result must preserve the failed point explicitly.

Do not silently interpolate a missing engineering result.

---

## 66. Sweep Status

Conceptual:

```text
COMPLETE
PARTIAL
FAILED
```

with per-frequency statuses.

---

## 67. Frequency-Point Diagnostics

Each point may record:

```text
frequency
solver status
condition indicator
residual
constraint status
```

---

## 68. Provenance

Frequency-domain results must record:

```text
knowledge package
component model versions
equation versions
frequency convention
phasor convention
RMS/peak convention
solver identity
numeric policy
sweep definition
```

---

## 69. Derivation

A derivation may record:

```text
component model resolution
frequency substitution
impedance/admittance derivation
MNA assembly
linear solution
power calculation
constraint evaluation
```

---

## 70. Example Derivation

For:

```text
R = 10 Ω
C = 1 µF
f = 1 kHz
```

the capacitor impedance is derived as:

```text
ω = 2πf

ZC = 1/(jωC)
```

The actual numerical result must be calculated by the Quantity/Equation/Analysis system.

---

## 71. Analysis Result Persistence

AP-EK-015 must persist:

```text
AC_FREQUENCY_DOMAIN
complex result representation
frequency policy
phasor convention
amplitude convention
sweep definition
solver identity
```

---

## 72. Reproducibility

Given identical:

```text
document
knowledge
runtime
solver
frequency
source phasors
component parameters
numeric policy
```

the result must be deterministic.

---

## 73. No Hidden Unit Conversion

AC calculations must not silently interpret:

```text
mV as V
degrees as radians
peak as RMS
Hz as rad/s
```

Conversions must be explicit.

---

## 74. Explanation Integration

AP-EK-014 should support:

```text
Why is current behind voltage?
Why does the capacitor's impedance decrease with frequency?
Why does the inductor's impedance increase with frequency?
Why is power factor less than 1?
Why does the phase change?
```

Each explanation must reference the relevant model/equation/result.

---

## 75. Teaching Integration

Teaching objectives may include:

```text
understand phasors
convert rectangular/polar form
calculate impedance
understand capacitive reactance
understand inductive reactance
interpret phase
calculate complex power
read frequency response
```

---

## 76. Diagram Studio Integration

DS may render:

```text
phasor values
magnitude
phase
impedance
admittance
Bode plots
frequency sweeps
power factor
complex power
```

DS must not independently calculate authoritative AC results.

---

## 77. Phasor Visualization

Future visualizations may include:

```text
phasor vectors
magnitude labels
phase angles
reference phasor
```

These are presentation of AnalysisResult.

---

## 78. Frequency Cursor

A DS frequency cursor may request:

```text
result at f
```

from the analysis service.

Interpolation, if requested, must be explicit and supported by the analysis result representation.

---

## 79. Bode Rendering

DS may render:

```text
magnitude vs frequency
phase vs frequency
```

from canonical frequency-domain result data.

It should not recompute:

```text
20log10(|H|)
```

unless that is explicitly delegated as a presentation transform using the Equation Engine.

---

## 80. Testing

### Complex Quantity

- arithmetic;
- magnitude;
- phase;
- conjugate;
- serialization.

### Units

- complex voltage;
- complex current;
- complex impedance;
- angular frequency.

### Components

- resistor;
- capacitor;
- inductor.

### Network

- series RLC;
- parallel RLC;
- AC voltage source;
- complex MNA.

### Power

- real;
- reactive;
- apparent;
- power factor.

### Sweep

- linear;
- logarithmic;
- explicit list;
- deterministic ordering.

### Failure

- zero-frequency invalidity where unsupported;
- singular system;
- incompatible sources;
- invalid units;
- unsupported nonlinear model.

---

## 81. Canonical AC Fixture

Use:

```text
10 Ω resistor
1 µF capacitor
12 V RMS source
1 kHz
```

Verify:

```text
complex impedance
complex current
magnitude
phase
```

The expected values must be calculated by the implemented engine and recorded as golden validation values after implementation.

Do not hard-code unverified expected values into architecture logic.

---

## 82. RLC Fixture

Use:

```text
R
L
C
AC source
```

Verify:

```text
complex node voltages
branch currents
phase relationships
power
```

---

## 83. Frequency Sweep Fixture

Run:

```text
100 Hz → 100 kHz
```

using a declared logarithmic point policy.

Verify:

```text
deterministic frequency list
deterministic response
correct ordering
```

---

## 84. Power Fixture

Use an inductive load.

Verify:

```text
S = P + jQ
```

and:

```text
PF = P / |S|
```

with the selected RMS convention.

---

## 85. Zero-Frequency Fixture

Explicitly test:

```text
f = 0
```

for:

```text
capacitor
inductor
```

Expected behavior must match the declared component model.

---

## 86. Nonlinear Rejection Fixture

Place an unsupported nonlinear device in an AC analysis.

Expected:

```text
UNSUPPORTED_NONLINEAR_AC_MODEL
```

unless an explicitly supported linearized/small-signal model is selected.

---

## 87. Implementation Sequence

```text
1. extend numeric abstraction for complex values
2. extend Quantity Engine
3. implement complex arithmetic
4. implement phase/magnitude operations
5. implement AC analysis mode
6. implement phasor source model
7. implement R/C/L frequency models
8. extend matrix abstraction for complex values
9. implement/reuse complex linear solver
10. implement frequency-domain MNA
11. implement power calculations
12. implement single-frequency analysis
13. implement frequency sweeps
14. implement frequency-point diagnostics
15. integrate constraints
16. integrate provenance/derivation
17. integrate AP-EK-015 persistence
18. add AP-EK-012 validation
19. integrate DS frequency response presentation
20. prepare small-signal extension
```

---

## 88. Recommended Repository Boundary

Conceptual:

```text
platform/
  oep_engine/
    analysis/
      frequency_domain/
        complex/
        phasor/
        ac_system/
        frequency_sweep/
        ac_solver/
        diagnostics/
```

The Quantity/Unit extension should remain under the existing quantity infrastructure rather than being duplicated inside AC analysis.

---

## 89. Definition of Done

AP-EK-018 is complete when:

1. complex numeric values are supported;
2. complex quantities preserve units/dimensions;
3. rectangular representation is canonical;
4. polar representation is supported;
5. phase conventions are explicit;
6. RMS/peak conventions are explicit;
7. AC sources are represented;
8. R/C/L frequency models are implemented;
9. complex MNA is implemented;
10. complex linear solving works;
11. singular systems are detected;
12. zero-frequency semantics are explicit;
13. single-frequency AC analysis works;
14. frequency sweeps work;
15. sweep ordering is deterministic;
16. complex power is supported;
17. constraints support complex results;
18. provenance captures AC-specific policies;
19. results persist through AP-EK-015;
20. AP-EK-012 AC validation passes;
21. DS can display frequency-domain results without implementing the solver;
22. unsupported nonlinear AC behavior fails explicitly;
23. the architecture is ready for AP-EK-019 distribution/integration work and future small-signal analysis.

---

## 90. Architectural Non-Negotiables

1. AC analysis is an explicit analysis mode.
2. Complex quantities extend the existing Quantity/Unit system.
3. A second unit system is prohibited.
4. Rectangular complex representation is canonical.
5. Phase convention is explicit.
6. RMS/peak convention is explicit.
7. Frequency is an explicit Quantity.
8. Angular frequency is derived explicitly.
9. R/C/L frequency behavior comes from component models.
10. Zero-frequency behavior is model-defined.
11. Unsupported nonlinear large-signal AC behavior fails explicitly.
12. Complex MNA extends existing network analysis.
13. Complex solving reuses existing solver abstractions where possible.
14. Matrix/unknown ordering remains deterministic.
15. Frequency sweep ordering remains deterministic.
16. Missing frequency points are never silently fabricated.
17. Hidden regularization is prohibited.
18. Hidden unit conversion is prohibited.
19. Hidden amplitude conversion is prohibited.
20. Complex power uses an explicit phasor convention.
21. Constraint comparison semantics for complex values are explicit.
22. Provenance includes AC-specific conventions and policies.
23. Historical AC results remain immutable.
24. DS presents AC results but does not independently calculate them.
25. Explanation may teach phasors and frequency response but cannot alter authoritative results.
26. Small-signal analysis must explicitly identify its DC operating point and linearization model.
27. Harmonic generation is not implied by sinusoidal AC analysis.
28. The frequency-domain solver is an extension of Engineering Analysis, not a separate simulation authority.
