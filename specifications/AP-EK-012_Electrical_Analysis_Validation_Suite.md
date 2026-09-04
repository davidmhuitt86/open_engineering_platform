# AP-EK-012
# Electrical Analysis Validation Suite
## Deterministic Verification Architecture for the OEP Electrical Analysis Vertical Slice

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 through AP-EK-011  
**Primary purpose:** Verification and acceptance of the deterministic electrical-analysis stack

---

## 1. Purpose

Define the validation architecture required to prove that the OEP electrical-analysis stack behaves deterministically, correctly, reproducibly, and within its architectural boundaries.

AP-EK-012 is not another engineering capability.

It is the verification layer that establishes whether the preceding capabilities actually work together:

```text
Knowledge
   ↓
Units
   ↓
Equations
   ↓
Laws
   ↓
Component Models
   ↓
Topology
   ↓
Circuit Solver
   ↓
Constraints
   ↓
Provenance / Derivation
   ↓
Engine API
   ↓
Diagram Studio
```

The validation suite must test both:

```text
numerical correctness
architectural correctness
```

---

## 2. Verification Principle

A passing numerical result is insufficient.

The system must prove:

```text
Correctness
Determinism
Traceability
Dimensional validity
Constraint correctness
Failure behavior
Version reproducibility
Boundary enforcement
```

The test suite therefore treats engineering correctness and architectural integrity as separate acceptance dimensions.

---

## 3. Validation Layers

The suite SHALL be organized into:

```text
L0  Schema / Contract Validation
L1  Quantity + Unit Validation
L2  Equation Validation
L3  Law Validation
L4  Component Model Validation
L5  Topology Validation
L6  Circuit Solver Validation
L7  Constraint Validation
L8  Provenance / Derivation Validation
L9  Analysis API Validation
L10 End-to-End Electrical Validation
L11 Determinism / Reproducibility Validation
L12 Failure / Trust-Boundary Validation
```

Each layer should be independently executable.

---

## 4. Test Categories

Every test should be classified as one or more of:

```text
UNIT
INTEGRATION
CONTRACT
PROPERTY
REGRESSION
DETERMINISM
FAILURE
END_TO_END
SECURITY / TRUST
```

This permits targeted execution while retaining a complete acceptance suite.

---

## 5. Test Data Policy

Test circuits and knowledge fixtures must be deterministic.

Fixtures should use:

```text
fixed identities
fixed quantities
fixed models
fixed knowledge versions
fixed analysis contexts
fixed tolerances
```

Randomized tests may exist as supplemental property tests, but the canonical acceptance suite must never depend on random data.

---

## 6. Golden Results

The suite should maintain golden expected results for canonical circuits.

A golden result may include:

```text
node voltages
branch currents
component voltages
component power
constraint statuses
diagnostics
derivation structure
provenance identities
```

Golden results must be versioned with the corresponding runtime/knowledge expectations.

---

## 7. Golden Result Policy

A changed golden result must never be accepted merely because the implementation changed.

Any expected-result change requires an explicit determination of:

```text
bug correction
authoritative knowledge change
numerical-policy change
solver-version change
intentional behavior change
```

The reason must be recorded.

---

## 8. AP-EK-003 Quantity Tests

Required unit tests:

```text
12 V -> 12000 mV
1 kΩ -> 1000 Ω
1 A × 10 Ω -> 10 V
12 V / 10 Ω -> 1.2 A
```

Dimensional failures:

```text
12 V + 2 A -> INVALID
12 V > 2 A -> INVALID
```

Prefix tests:

```text
milli
micro
nano
kilo
mega
giga
```

---

## 9. Quantity Property Tests

Properties:

```text
convert(convert(x, A), B) == convert(x, B)
```

where compatible conversions exist.

Additional properties:

```text
x + 0_dimensionally_compatible = x
x × 1_dimensionless = x
x / x = dimensionless
```

subject to the defined numeric policy and domain restrictions.

---

## 10. Quantity Failure Tests

Verify:

```text
UNKNOWN_UNIT
INCOMPATIBLE_DIMENSIONS
INVALID_CONVERSION
INVALID_NUMERIC_VALUE
DIVISION_BY_ZERO
```

No failure may silently produce a plausible engineering quantity.

---

## 11. AP-EK-004 Equation Tests

Canonical equations:

```text
V = I × R
I = V / R
R = V / I

P = V × I
P = I² × R
P = V² / R
```

All must pass structural and dimensional validation.

---

## 12. Equation Negative Tests

Invalid definitions must fail:

```text
P = I × R
```

when `P` is declared as power.

Other invalid cases:

```text
unknown variable
invalid operator arity
missing result variable
invalid exponent
incompatible declared dimension
```

---

## 13. Equation Determinism

Repeated execution of the same equation with:

```text
same inputs
same unit registry
same numeric policy
same equation version
```

must produce equivalent:

```text
result
status
derivation
serialization
```

---

## 14. AP-EK-005 Law Tests

The initial law registry must resolve:

```text
Ohm's Law
KCL
KVL
Electrical Power
Series Resistance
Parallel Resistance
Voltage Divider
Current Divider
```

Each law must expose:

```text
identity
version
equations
applicability
provenance
```

---

## 15. Law Applicability Tests

Verify that:

```text
Ohm's Law
```

does not automatically imply every electrical component is an ideal resistor.

Verify that:

```text
unloaded voltage divider
```

is not selected when an explicit load materially changes the topology.

Verify that topology-dependent laws require sufficient topology context.

---

## 16. AP-EK-006 Component Model Tests

Initial models:

```text
resistor
voltage source
current source
reference node
switch
```

must pass:

```text
identity
terminal
parameter
state
applicability
equation reference
provenance
```

validation.

---

## 17. Component Parameter Tests

Valid:

```text
R = 10 Ω
```

Invalid:

```text
R = 10 V
```

Missing required values must produce:

```text
MISSING_REQUIRED_PARAMETER
```

rather than a default invented by the runtime.

---

## 18. Terminal Tests

Verify:

```text
valid terminal mapping
unknown terminal
duplicate invalid mapping
unconnected terminal
```

The topology system must preserve component-level terminal identity.

---

## 19. AP-EK-007 Topology Tests

Required canonical topology fixtures:

```text
single resistor
series resistors
parallel resistors
voltage divider
loaded voltage divider
switch open
switch closed
```

Topology normalization must be independent of:

```text
object ordering
relationship insertion order
diagram geometry
wire route geometry
UI state
```

---

## 20. Topology Equivalence Tests

Construct logically equivalent circuits with different:

```text
object insertion order
relationship ordering
diagram coordinates
wire geometry
```

Expected:

```text
equivalent normalized electrical topology
```

This proves that visual/editor state does not become electrical truth.

---

## 21. Reference Node Tests

Verify:

```text
valid explicit reference
missing reference
multiple conflicting references
reference in disconnected subcircuit
```

The solver must report explicit diagnostics rather than selecting an arbitrary reference.

---

## 22. AP-EK-007 Linear Solver Tests

### Circuit A — Single Resistor

```text
Vsource = 12 V
R1 = 10 Ω
```

Expected:

```text
I_R1 = 1.2 A
P_R1 = 14.4 W
V_R1 = 12 V
```

Power balance:

```text
P_source + P_R1 = 0 W
```

within configured tolerance.

---

## 23. Circuit B — Series

```text
Vsource = 12 V
R1 = 10 Ω
R2 = 20 Ω
```

Expected:

```text
Rtotal = 30 Ω
I = 0.4 A
V_R1 = 4 V
V_R2 = 8 V
```

KVL:

```text
12 - 4 - 8 = 0 V
```

KCL at the intermediate node must also satisfy the defined residual tolerance.

---

## 24. Circuit C — Parallel

```text
Vsource = 12 V
R1 = 10 Ω
R2 = 20 Ω
```

Expected:

```text
Rtotal = 6.666... Ω
I_total = 1.8 A
I_R1 = 1.2 A
I_R2 = 0.6 A
```

KCL:

```text
1.2 + 0.6 - 1.8 = 0 A
```

---

## 25. Circuit D — Unloaded Divider

```text
Vin = 12 V
R1 = 10 Ω
R2 = 20 Ω
```

Expected:

```text
Vout = 12 × 20 / (10 + 20)
     = 8 V
```

The specialized divider equation may be selected because the output is explicitly unloaded.

---

## 26. Circuit E — Loaded Divider

```text
Vin = 12 V
R1 = 10 Ω
R2 = 20 Ω
RL = 20 Ω
```

Expected lower branch:

```text
R2 || RL = 10 Ω
```

Therefore:

```text
Rtotal = 20 Ω
I_total = 0.6 A
Vout = 6 V
```

The unloaded divider equation must not be used.

---

## 27. Circuit F — Open Switch

```text
12 V source
switch = OPEN
10 Ω resistor
reference
```

Expected result must reflect the open switch model.

The solver must not report:

```text
1.2 A
```

merely because the closed topology previously produced that result.

---

## 28. Circuit G — Closed Switch

Same circuit:

```text
switch = CLOSED
```

Expected:

```text
I = 1.2 A
P_R1 = 14.4 W
```

This validates state-dependent topology/model behavior.

---

## 29. Source Tests

### Ideal voltage source

Verify exact voltage constraint behavior.

### Ideal current source

Verify exact current contribution.

### Conflicting voltage sources

Verify:

```text
INCONSISTENT_SYSTEM
```

rather than arbitrary source selection.

---

## 30. Singular / Underdetermined Tests

Test:

```text
floating network
redundant constraints
insufficient boundary conditions
```

Expected explicit statuses:

```text
SINGULAR_SYSTEM
UNDERDETERMINED
```

as appropriate.

---

## 31. AP-EK-008 Constraint Tests

Numeric:

```text
12 V <= 16 V -> SATISFIED
18 V <= 16 V -> VIOLATED
```

Boundary:

```text
16 V <= 16 V -> SATISFIED
16 V < 16 V  -> VIOLATED
```

Unknown:

```text
unknown voltage <= 16 V -> UNKNOWN / INSUFFICIENT_DATA
```

---

## 32. Constraint Dimensional Tests

Valid:

```text
12 V <= 16 V
```

Invalid:

```text
12 V <= 16 A
```

The latter must produce a dimensional error, not a boolean result.

---

## 33. Constraint Composite Tests

Verify:

```text
A AND B
A OR B
NOT A
```

Child statuses must remain available.

A missing child value must not silently become PASS.

---

## 34. Electrical Constraint Tests

Verify:

```text
KCL residual
KVL residual
power balance
component current limit
component voltage limit
component power limit
```

with both satisfied and violated cases.

---

## 35. AP-EK-009 Provenance Tests

For:

```text
I = 12 V / 10 Ω
```

verify lineage contains:

```text
input voltage
input resistance
resistor model
Ohm's Law
equation
runtime version
knowledge version
numeric policy
derivation
```

---

## 36. Derivation Tests

Expected structure:

```text
Input 12 V
Input 10 Ω
DIVIDE
Output 1.2 A
```

For power:

```text
Input 12 V
Input 1.2 A
MULTIPLY
Output 14.4 W
```

The derivation must describe the actual executed operations.

---

## 37. Provenance Integrity Tests

If a referenced content hash changes:

```text
PROVENANCE_MISMATCH
```

must be detectable.

Missing referenced artifacts must produce:

```text
VERIFICATION_FAILED
```

or the appropriate structured verification status.

---

## 38. Historical Version Tests

Run the same circuit against:

```text
knowledge runtime version N
knowledge runtime version N+1
```

Results must identify which version produced each analysis.

A historical result must not silently acquire the newer knowledge version.

---

## 39. AP-EK-010 API Tests

Verify:

```text
valid AnalysisRequest
invalid request
missing document identity
missing document version
unsupported analysis mode
invalid context
```

---

## 40. Stale Result Tests

Sequence:

```text
Document v1
    ↓
Analysis A

Document v2
    ↓
Analysis A becomes STALE
```

New analysis:

```text
Analysis B
```

must reference:

```text
Document v2
```

---

## 41. Result Immutability Tests

After:

```text
AnalysisResult A
```

is produced, modifying the document must not mutate A.

A new analysis produces:

```text
AnalysisResult B
```

A and B remain distinct.

---

## 42. Scope Tests

Verify:

```text
whole document
selected circuit
selected component neighborhood
node scope
branch scope
```

Unsupported or insufficient scopes must fail explicitly.

A partial result must identify its scope.

---

## 43. Diagram Studio Boundary Tests

The DS integration test must prove:

```text
DS requests analysis
Engine calculates
DS receives result
```

and that DS does not calculate:

```text
Ohm's Law
KCL
KVL
power
constraint comparison
```

independently.

---

## 44. UI Independence

The same AnalysisRequest should be usable by:

```text
CLI
DS
future Android client
future service client
```

without changing engineering semantics.

---

## 45. Determinism Suite

For each canonical circuit:

```text
run N times
serialize result
compare result hashes/normalized serialization
```

Expected:

```text
equivalent results
```

No run-dependent variation is acceptable under identical dependencies.

---

## 46. Cross-Platform Determinism

Where the same runtime implementation is available:

```text
Windows
Linux
macOS
Android
iOS
```

the canonical electrical fixtures should produce equivalent engineering results.

Platform-specific formatting differences must not alter the canonical result.

---

## 47. Regression Suite

Every defect corrected in the electrical-analysis runtime should create a regression test.

The regression suite becomes part of the permanent acceptance baseline.

---

## 48. Property Testing

Useful properties include:

```text
series resistance is associative
parallel resistance is commutative
unit conversion round-trip is stable
KCL residual remains invariant under branch ordering
topology normalization is invariant under object ordering
equivalent graphs yield equivalent solutions
```

Properties must respect domain restrictions.

---

## 49. Metamorphic Testing

The suite should test transformations that preserve expected engineering behavior.

Examples:

### Series order

Swapping:

```text
R1, R2
```

to:

```text
R2, R1
```

must preserve total resistance.

### Parallel order

Swapping parallel branches must preserve total resistance and total current.

### Unit conversion

Changing:

```text
10 Ω
```

to:

```text
10000 mΩ
```

must preserve physical results.

---

## 50. Negative Trust Tests

The runtime must reject:

```text
AI-invented equation
unknown model
unknown unit
missing provenance
invalid topology
untrusted executable payload
```

No fallback may silently create a plausible engineering answer.

---

## 51. Persistence Tests

Analysis results persisted through the repository boundary must retain:

```text
analysisId
document identity/version
runtime identity
knowledge identity
result values
constraints
derivation
provenance
```

Reopened results must remain verifiable.

---

## 52. Cache Tests

A cache hit must produce the same:

```text
result
status
provenance
derivation
diagnostics
```

as a clean calculation.

Changing any dependency included in the cache identity must invalidate the cached result.

---

## 53. Performance Tests

Initial targets should be established empirically rather than guessed.

The suite should record:

```text
analysis duration
topology extraction duration
equation assembly duration
solver duration
constraint duration
provenance construction duration
```

Performance regressions should be measured against a defined baseline.

---

## 54. Test Environment

The canonical test environment must identify:

```text
runtime version
compiler/toolchain version
knowledge package version
test fixture version
numeric policy
platform
```

This metadata belongs in test reports.

---

## 55. Acceptance Matrix

The release acceptance matrix should map:

```text
AP-EK-003 -> quantity tests
AP-EK-004 -> equation tests
AP-EK-005 -> law tests
AP-EK-006 -> model tests
AP-EK-007 -> topology/solver tests
AP-EK-008 -> constraint tests
AP-EK-009 -> provenance tests
AP-EK-010 -> API/DS tests
AP-EK-011 -> advanced-capability contract tests
```

Each increment must have explicit pass/fail status.

---

## 56. First Complete Acceptance Test

The minimum complete acceptance scenario is:

```text
12 V source
10 Ω resistor
reference
```

System performs:

```text
1. load knowledge runtime
2. resolve units
3. resolve resistor model
4. resolve voltage source
5. build topology
6. select Ohm's Law
7. evaluate I = V/R
8. evaluate P = V×I
9. evaluate constraints
10. build derivation
11. build provenance
12. return AnalysisResult
13. verify result
14. expose result to DS
```

Expected:

```text
I = 1.2 A
P = 14.4 W
KCL = satisfied
KVL = satisfied
power balance = satisfied
provenance = complete
derivation = complete
status = SUCCESS
```

---

## 57. First Complete Failure Acceptance Test

Use a circuit with:

```text
10 Ω resistor
no valid reference
```

Expected:

```text
analysis incomplete/failure
NO_REFERENCE_NODE
```

No calculated current should be presented as authoritative.

---

## 58. Second Complete Failure Acceptance Test

Use:

```text
R = 10 V
```

for a resistor parameter.

Expected:

```text
INVALID_PARAMETER_UNIT
```

The system must fail before circuit solving.

---

## 59. Third Complete Failure Acceptance Test

Use an unsupported nonlinear device in:

```text
DC_STEADY_STATE_LINEAR
```

when no valid model exists.

Expected:

```text
UNSUPPORTED_COMPONENT_MODEL
```

No resistor approximation is permitted unless authoritative.

---

## 60. Test Report

Every complete suite execution should produce:

```text
testRunId
timestamp
platform
runtimeVersion
knowledgeVersion
compilerVersion
numericPolicyVersion
fixtureVersion
passed
failed
skipped
warnings
regressions
```

Failed tests must identify:

```text
testId
layer
fixture
expected
actual
diagnostics
```

---

## 61. Release Gates

The electrical-analysis runtime must not be considered production-ready unless:

```text
all mandatory tests pass
no unresolved P0/P1 correctness defects exist
determinism tests pass
provenance tests pass
failure/trust tests pass
first complete acceptance scenario passes
```

Performance thresholds may be introduced after a baseline exists.

---

## 62. Definition of Done

AP-EK-012 is complete when:

1. validation layers are defined;
2. canonical fixtures exist;
3. Quantity tests exist;
4. Equation tests exist;
5. Law tests exist;
6. Component Model tests exist;
7. Topology tests exist;
8. Linear Solver tests exist;
9. Constraint tests exist;
10. Provenance/Derivation tests exist;
11. Analysis API tests exist;
12. DS boundary tests exist;
13. deterministic regression testing exists;
14. negative trust-boundary tests exist;
15. persistence/cache tests exist;
16. first complete acceptance test passes;
17. complete failure acceptance tests pass;
18. test reports identify runtime/knowledge/toolchain versions;
19. release gates are explicit.

---

## 63. Follow-On

```text
AP-EK-013  Knowledge Runtime Implementation
AP-EK-014  Engineering Explanation / Teaching Layer
AP-EK-015  Analysis Result Persistence
AP-EK-016  Nonlinear Electrical Solver Implementation
AP-EK-017  Dynamic Electrical Solver Implementation
AP-EK-018  Frequency-Domain / Complex Quantity Implementation
```

---

## Architectural Non-Negotiables

1. Testing is part of the engineering architecture, not an afterthought.
2. Numerical correctness and architectural correctness are separate acceptance dimensions.
3. Canonical fixtures are deterministic.
4. Golden results require explicit change justification.
5. Every runtime layer has dedicated validation.
6. Failure behavior is tested as rigorously as success behavior.
7. Missing information must never become a fabricated engineering result.
8. Provenance and derivation are acceptance requirements.
9. Determinism is a release requirement.
10. Equivalent graph representations must produce equivalent normalized topology/results.
11. UI geometry must not influence engineering results.
12. DS must not duplicate engineering calculations.
13. AI-generated engineering content must fail the authority boundary unless formally accepted into the knowledge pipeline.
14. Historical results must remain traceable to their original runtime/knowledge versions.
15. Cache behavior must be observationally equivalent to fresh calculation.
16. Unsupported capabilities must fail explicitly.
17. Advanced-analysis contracts may be tested before their numerical implementations exist.
18. Every corrected defect becomes a regression test.
19. The first complete electrical vertical slice is the primary architectural acceptance gate.
20. No production claim should be made from passing isolated unit tests alone; the complete stack must pass its end-to-end acceptance scenario.
