# AP-EK-008
# Constraint Evaluation
## Deterministic Engineering Constraint, Limit, and Compliance Evaluation Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 through AP-EK-007  
**Primary consumers:** OEP Engineering Analysis Runtime  
**Presentation consumer:** Diagram Studio

---

## 1. Purpose

Define the deterministic subsystem that evaluates engineering constraints against known, measured, or calculated values.

The Constraint Engine answers questions such as:

```text
Is current within the rated limit?
Is voltage within the component operating range?
Does calculated power exceed the component rating?
Does a KCL residual satisfy the analysis tolerance?
Is a parameter within an authoritative range?
```

The Constraint Engine SHALL:

- represent constraints as structured knowledge;
- evaluate them deterministically;
- use explicit quantities and units;
- distinguish pass/fail from unknown;
- preserve provenance;
- report violations without modifying engineering state;
- remain independent of UI and AI.

---

## 2. Architectural Principle

A constraint is not an equation and is not a component behavior model.

The distinction is:

```text
Component Model
    = what the component does

Engineering Law / Equation
    = relationship used to calculate a value

Constraint
    = condition that determines whether a value/state is acceptable
```

Example:

```text
Resistor
  behavior:
    V = I × R

Constraint:
  P <= ratedPower
```

---

## 3. Authority Chain

Constraint definitions follow the same authoritative knowledge pipeline:

```text
Authoritative Sources
       |
       v
oep_acqusition
       |
       v
oep_reference_library
       |
       v
Reference Compiler
       |
       v
Knowledge Runtime
       |
       v
Constraint Engine
       |
       v
AnalysisResult
```

Constraints must not be invented at runtime.

---

## 4. Constraint Contract

Conceptual:

```text
Constraint
  constraintId
  name
  expression
  severity
  applicability
  assumptions
  provenance
  version
```

A constraint may additionally reference:

```text
targetObject
targetModel
quantity
limit
state
analysisResult
```

The canonical schema remains governed by AP-EK-001/AP-EK-002.

---

## 5. Constraint Types

The initial implementation should support:

```text
UPPER_BOUND
LOWER_BOUND
RANGE
EQUALITY
INEQUALITY
ENUMERATION
STATE
TOPOLOGY
RESIDUAL
```

These provide the minimum foundation for component ratings and circuit validation.

---

## 6. Upper Bound

Example:

```text
I <= 1.0 A
```

Given:

```text
I = 0.8 A
```

result:

```text
SATISFIED
```

Given:

```text
I = 1.2 A
```

result:

```text
VIOLATED
```

The comparison uses the Quantity Engine.

---

## 7. Lower Bound

Example:

```text
V >= 10 V
```

Given:

```text
V = 12 V
```

result:

```text
SATISFIED
```

Given:

```text
V = 8 V
```

result:

```text
VIOLATED
```

---

## 8. Range

Example:

```text
10 V <= V <= 16 V
```

The engine evaluates both boundaries.

A range constraint should expose which boundary failed.

---

## 9. Equality

Equality constraints are useful for relationships such as:

```text
V_reference = 0 V
```

or validation of expected exact state.

Numeric equality must use the explicit precision/tolerance policy rather than blindly comparing floating-point representations.

---

## 10. Inequality

Generic deterministic comparisons should support:

```text
<
<=
>
>=
==
!=
```

Operands must be dimensionally compatible where they represent engineering quantities.

---

## 11. Enumeration Constraints

Some constraints concern categorical state rather than numeric quantities.

Example:

```text
switch.state ∈ {OPEN, CLOSED}
```

or:

```text
analysis.mode ∈ {DC_STEADY_STATE}
```

The value must match an explicitly defined permitted state.

---

## 12. State Constraints

A component may impose state requirements.

Example:

```text
fuse.state == INTACT
```

or:

```text
switch.state == CLOSED
```

State constraints must not mutate the state they evaluate.

---

## 13. Topology Constraints

Topology constraints evaluate structural conditions.

Examples:

```text
component must have exactly two electrical terminals
source must connect to a valid circuit
divider output must have no load for unloaded-divider equation
```

Topology constraints consume normalized topology produced by AP-EK-007.

They do not independently reconstruct topology.

---

## 14. Residual Constraints

Circuit laws can be validated through residuals.

KCL example:

```text
ΣI = 0
```

Constraint:

```text
|ΣI| <= tolerance
```

KVL example:

```text
|ΣV| <= tolerance
```

Power balance:

```text
|ΣP| <= tolerance
```

Residual constraints provide deterministic validation of solver results.

---

## 15. Constraint Operand

A constraint must identify what it evaluates.

Conceptually:

```text
ConstraintOperand
  source
  quantity
  unit
```

The source may be:

```text
input
calculated value
measurement
component parameter
node result
branch result
analysis result
state
```

The source identity must be traceable.

---

## 16. Limit Values

Limits must themselves carry explicit engineering meaning.

Example:

```text
ratedCurrent = 1 A
```

must be represented as:

```text
Quantity
  value = 1
  unit = A
```

not:

```text
1
```

This prevents dimensional ambiguity.

---

## 17. Constraint Evaluation Pipeline

Canonical pipeline:

```text
1. Resolve constraint
2. Verify version
3. Evaluate applicability
4. Resolve operands
5. Validate operand dimensions/types
6. Resolve limits/reference values
7. Apply precision policy
8. Evaluate condition
9. Determine status
10. Build diagnostic
11. Attach provenance
```

---

## 18. Constraint Status

The engine SHALL distinguish at minimum:

```text
SATISFIED
VIOLATED
UNKNOWN
NOT_APPLICABLE
INSUFFICIENT_DATA
INVALID_CONSTRAINT
EVALUATION_ERROR
```

This distinction is essential.

For example:

```text
no current measurement
```

does not mean:

```text
current limit passed
```

It means:

```text
INSUFFICIENT_DATA
```

---

## 19. Severity

Constraints may have severity:

```text
INFO
WARNING
ERROR
CRITICAL
```

Severity is metadata and does not itself determine whether the constraint is satisfied.

Example:

```text
power > recommended level
```

may be:

```text
WARNING
```

while:

```text
absolute component maximum exceeded
```

may be:

```text
CRITICAL
```

Severity must come from authoritative knowledge where applicable.

---

## 20. Constraint Applicability

A constraint may apply only under specific conditions.

Examples:

```text
maximum current applies while fuse is intact
thermal rating applies within specified temperature range
voltage rating applies to a particular component state
```

The engine must evaluate applicability explicitly.

If applicability cannot be established:

```text
UNKNOWN
```

or:

```text
INSUFFICIENT_DATA
```

should be returned as appropriate.

---

## 21. No Silent Assumptions

The Constraint Engine must never silently assume:

```text
missing rating
missing unit
missing state
missing operating condition
missing measurement
missing tolerance
```

Missing information must produce a structured status.

---

## 22. Dimensional Validation

Before numeric comparison:

```text
12 V <= 16 V
```

is valid.

But:

```text
12 V <= 16 A
```

is invalid.

The Quantity Engine determines dimensional compatibility.

The Constraint Engine consumes that result.

---

## 23. Tolerance

Some constraints require tolerance.

Examples:

```text
KCL residual
KVL residual
power balance
measurement comparison
nominal value comparison
```

Tolerance must be explicit.

Conceptually:

```text
TolerancePolicy
  absolute
  relative
  numericVersion
```

The exact policy belongs to the numerical foundation.

---

## 24. Boundary Semantics

The engine must preserve the difference between:

```text
<
<=
>
>=
```

Example:

```text
I <= 1.0 A
```

means exactly:

```text
I = 1.0 A
```

is satisfied.

Whereas:

```text
I < 1.0 A
```

is violated at exactly:

```text
I = 1.0 A
```

---

## 25. Constraint Composition

Constraints may be combined.

Examples:

```text
A AND B
A OR B
NOT A
```

The first implementation should support:

```text
AND
OR
NOT
```

with deterministic short-circuit behavior only if that behavior does not hide required diagnostics.

For engineering auditing, retaining all evaluated child results is preferable.

---

## 26. Composite Constraints

Example:

```text
10 V <= V <= 16 V
AND
I <= 5 A
AND
P <= 50 W
```

Result:

```text
SATISFIED
```

only when all required child constraints are satisfied.

A composite result should preserve child statuses.

---

## 27. Unknown Propagation

Unknown must not become pass.

Example:

```text
P <= 50 W
```

but:

```text
P = UNKNOWN
```

Result:

```text
UNKNOWN
```

Similarly, a composite constraint containing an unresolved required condition should preserve that uncertainty.

---

## 28. Engineering Inference Boundary

Constraint evaluation can establish:

```text
limit exceeded
condition satisfied
condition not satisfied
insufficient evidence
```

It must not automatically infer broader engineering conclusions.

Example:

```text
current > fuse rating
```

may establish:

```text
CURRENT_RATING_EXCEEDED
```

It must not independently assert:

```text
fuse WILL blow in 0.5 seconds
```

unless an authoritative time-current model exists.

---

## 29. Component Rating Constraints

A component model may reference constraints such as:

```text
maximumVoltage
maximumCurrent
maximumPower
minimumTemperature
maximumTemperature
```

Example:

```text
R1:
  power = 14.4 W
  ratedPower = 10 W
```

Constraint:

```text
14.4 W <= 10 W
```

Result:

```text
VIOLATED
CRITICAL
```

assuming that severity is authoritative.

---

## 30. Fuse Constraint Example

Given:

```text
calculated current = 1.2 A
fuse rating = 1.0 A
```

Constraint:

```text
I <= ratedCurrent
```

Result:

```text
VIOLATED
```

This does not itself simulate fuse opening.

That requires a future fuse behavior/time-current model.

---

## 31. KCL Validation Example

Given:

```text
I1 = 2 A
I2 = 1 A
I3 = 3 A
```

residual:

```text
2 + 1 - 3 = 0 A
```

Constraint:

```text
|residual| <= tolerance
```

Result:

```text
SATISFIED
```

---

## 32. KCL Violation Example

Given:

```text
I1 = 2 A
I2 = 1 A
I3 = 2.5 A
```

residual:

```text
2 + 1 - 2.5 = 0.5 A
```

If tolerance is:

```text
0.001 A
```

result:

```text
VIOLATED
```

---

## 33. KVL Validation Example

```text
12 V - 7 V - 5 V = 0 V
```

Residual:

```text
0 V
```

Result:

```text
SATISFIED
```

---

## 34. Power Balance Example

```text
source = -14.4 W
load   = +14.4 W
```

Residual:

```text
0 W
```

Result:

```text
SATISFIED
```

---

## 35. Provenance

Constraint results must preserve:

```text
constraintId
constraintVersion
knowledgeVersion
sourceObjectId
operand sources
limit source
analysis/runtime version
```

A violation must be explainable in terms of the authoritative constraint and the values used.

---

## 36. Diagnostic Contract

A diagnostic should contain conceptually:

```text
diagnosticId
status
severity
constraintId
targetObjectId
messageCode
actualValue
expectedCondition
limitValue
provenance
```

Human-readable messages are presentation-layer output derived from structured diagnostic data.

---

## 37. Constraint Registry

Conceptual API:

```text
ConstraintRegistry
  getConstraint(constraintId)
  listConstraints(domain)
  validateConstraint(constraintId)
  evaluate(constraintId, context)
```

The registry is immutable during an analysis session.

Changing constraint definitions requires a new runtime knowledge version.

---

## 38. Analysis Integration

The canonical analysis flow becomes:

```text
Circuit Analysis
      |
      v
Calculated quantities
      |
      v
Constraint Engine
      |
      +---- component limits
      +---- topology constraints
      +---- KCL residuals
      +---- KVL residuals
      +---- power balance
      |
      v
AnalysisResult
```

Constraints are downstream consumers of calculated/observed state.

---

## 39. DS Integration

Diagram Studio receives structured constraint results.

DS may display:

```text
PASS
WARNING
VIOLATION
UNKNOWN
```

and detailed engineering diagnostics.

DS must not implement constraint logic.

Example:

```text
R1 Power: 14.4 W
Rating: 10 W
Status: VIOLATED
```

The comparison was performed by the runtime.

---

## 40. Simulation Boundary

Simulation may evaluate constraints against evolving state.

However:

```text
simulation state
```

does not become authoritative engineering knowledge merely because a constraint was evaluated against it.

Constraint definitions remain authoritative runtime knowledge.

---

## 41. Measurements

Measurements can be used as constraint operands.

Example:

```text
measured voltage = 11.7 V
acceptable range = 11.5–12.5 V
```

Result:

```text
SATISFIED
```

Measurement provenance must identify the measurement source where available.

---

## 42. Constraint Categories

The initial registry should organize constraints by domain:

```text
electrical.component
electrical.topology
electrical.analysis
electrical.measurement
electrical.safety
```

The taxonomy may expand as additional engineering domains are introduced.

---

## 43. Constraint Package

The compiled runtime package should contain:

```text
constraint definitions
operand schemas
applicability rules
severity
tolerance references
provenance
versions
indexes
```

The package must be deterministic and immutable once activated.

---

## 44. First Constraint Package

Initial constraints should include:

```text
resistor maximum power
component voltage limit
component current limit
KCL residual
KVL residual
power balance
valid reference-node requirement
valid terminal connectivity
```

Only constraints with authoritative definitions should be activated.

---

## 45. First Vertical Slice

Circuit:

```text
12 V source
10 Ω resistor
reference
```

Calculated:

```text
I = 1.2 A
P = 14.4 W
```

Given:

```text
resistor rated power = 20 W
```

results:

```text
current constraint -> model-dependent / no current limit unless defined
power constraint   -> SATISFIED
```

If:

```text
rated power = 10 W
```

then:

```text
power constraint -> VIOLATED
```

---

## 46. Failure Modes

At minimum:

```text
UNKNOWN_CONSTRAINT
INVALID_CONSTRAINT
MISSING_OPERAND
MISSING_LIMIT
INCOMPATIBLE_DIMENSIONS
UNKNOWN_APPLICABILITY
INSUFFICIENT_DATA
INVALID_TOLERANCE
EVALUATION_ERROR
```

These are distinct from:

```text
VIOLATED
```

because an inability to evaluate is not equivalent to a failed engineering condition.

---

## 47. Testing

### Numeric

- upper bound pass/fail;
- lower bound pass/fail;
- inclusive/exclusive boundary;
- range;
- equality with tolerance;
- inequality.

### Dimensional

```text
12 V <= 16 V -> valid
12 V <= 16 A -> invalid
```

### Unknown

- missing measurement;
- missing rating;
- missing state;
- unknown applicability.

### Composite

- AND;
- OR;
- NOT;
- child-result preservation.

### Electrical

- KCL residual;
- KVL residual;
- power balance;
- component rating.

### Determinism

Identical constraint definition, runtime version, operands, and tolerance policy must produce equivalent serialized results.

### Provenance

Every result must preserve the constraint and operand sources.

---

## 48. Definition of Done

AP-EK-008 is complete when:

1. Constraint contract exists;
2. numeric constraints are supported;
3. state constraints are supported;
4. topology constraints are supported;
5. residual constraints are supported;
6. dimensional validation works;
7. tolerance policy is explicit;
8. unknown/insufficient states are distinct from violations;
9. composite constraints work;
10. provenance is preserved;
11. constraint registry is versioned;
12. initial electrical constraints are represented;
13. KCL/KVL/power validation integrates with AP-EK-007;
14. component rating constraints integrate with AP-EK-006;
15. DS can consume structured results without implementing constraint logic.

---

## 49. Follow-On

```text
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/Diagram Studio Analysis API
AP-EK-011  Dynamic / Nonlinear Analysis Extension
AP-EK-012  Electrical Analysis Validation Suite
```

---

## Architectural Non-Negotiables

1. Constraints are distinct from equations.
2. Constraints are distinct from component behavior.
3. Constraint definitions originate from authoritative knowledge.
4. Numeric operands carry explicit units.
5. Dimensional compatibility is mandatory.
6. Missing information never becomes a pass.
7. Unknown is not equivalent to violated.
8. Applicability is explicit.
9. Tolerance is explicit and versioned.
10. Topology constraints consume normalized topology rather than reconstructing it.
11. Constraint evaluation never mutates engineering state.
12. AI cannot override authoritative constraints.
13. Provenance is mandatory for authoritative constraint evaluation.
14. Constraint registries are immutable during analysis.
15. Diagram Studio presents constraint results but does not calculate them.
16. Constraint evaluation must remain deterministic and reproducible.
17. A failed constraint establishes a condition; it does not automatically imply an unmodeled physical consequence.
