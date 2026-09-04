# AP-EK-005
# Electrical Law Library
## Authoritative Electrical Relationships and Law-to-Equation Runtime Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 — Reference Compiler Boundary; AP-EK-003 — Quantity + Unit Engine; AP-EK-004 — Deterministic Equation Engine  
**Primary consumers:** OEP Knowledge Runtime and Engineering Analysis

---

## 1. Purpose

Define the first authoritative electrical law set available to OEP Engineering Analysis.

This increment establishes how electrical laws are represented, versioned, compiled, selected, evaluated, and traced to provenance.

The first scope is intentionally narrow:

```text
Ohm's Law
Kirchhoff's Current Law
Kirchhoff's Voltage Law
Electrical Power relationships
Series resistance
Parallel resistance
Voltage divider
Current divider
```

These laws form the minimum useful deterministic foundation for the first circuit-analysis vertical slice.

---

## 2. Architectural Principle

A law is engineering knowledge.

An equation is an executable representation of a law or relationship.

The distinction is:

```text
Engineering Law
      |
      +-- authoritative statement
      +-- applicability
      +-- assumptions
      +-- provenance
      |
      v
Equation Form(s)
      |
      v
Deterministic Equation Engine
```

The Equation Engine executes equations.

It does not establish the authority or truth of the law.

---

## 3. Authority Chain

```text
Authoritative Source
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
Compiled Electrical Law Package
       |
       v
Knowledge Runtime
       |
       v
Engineering Analysis
```

No electrical law SHALL be introduced into the runtime solely because an AI model generated it.

---

## 4. Engineering Law Contract

Conceptual:

```text
EngineeringLaw
  lawId
  name
  domain
  statement
  equations[]
  variables[]
  assumptions[]
  applicability
  constraints[]
  provenance
  version
```

A law may contain multiple executable equation forms.

---

## 5. Law Identity

Each law requires a stable identity.

Initial identifiers should be conceptually similar to:

```text
electrical.ohms_law
electrical.kcl
electrical.kvl
electrical.power
electrical.series_resistance
electrical.parallel_resistance
electrical.voltage_divider
electrical.current_divider
```

The final identifier namespace is subject to the canonical knowledge schema.

Identity must survive recompilation when the underlying authoritative law has not changed.

---

## 6. Law Metadata

Each law should provide:

```text
lawId
name
domain
description
statement
equationIds
assumptions
applicability
provenance
version
```

The natural-language statement is explanatory metadata.

The executable equations remain structured representations.

---

## 7. Ohm's Law

Canonical relationship:

```text
V = I × R
```

Explicit equation forms:

```text
V = I × R
I = V / R
R = V / I
```

Dimensions:

```text
V / Ω = A
V / A = Ω
A × Ω = V
```

The equations delegate dimensional behavior to AP-EK-003 and evaluation to AP-EK-004.

---

## 8. Ohm's Law Applicability

The initial implementation should treat Ohm's Law as applicable to the component/model context that explicitly represents an ohmic relationship.

It must not assume that every electrical device is an ideal resistor merely because voltage and current exist.

Examples requiring additional models include:

```text
diodes
transistors
motors
capacitors
inductors
nonlinear loads
switching devices
```

Applicability therefore belongs to the law/model context, not merely the presence of V and I quantities.

---

## 9. Kirchhoff's Current Law

KCL expresses conservation of charge at a node.

Canonical form:

```text
Σ I = 0
```

A practical node form may be:

```text
Σ I_in = Σ I_out
```

The signed-sum representation should be canonical for computation.

Example:

```text
I1 + I2 - I3 = 0
```

where the sign convention is explicitly defined by the analysis topology.

---

## 10. KCL Representation

KCL is not a simple two-variable equation.

It is a relationship over a node's incident branches.

Conceptually:

```text
KCLConstraint
  nodeId
  branchCurrents[]
  signConvention
  equation
```

This is an important boundary:

```text
Equation Engine
  evaluates the signed current expression

Engineering Analysis
  determines which branches belong to the node
```

The Equation Engine must not discover topology itself.

---

## 11. KCL Applicability

KCL applies to an electrical node under the adopted circuit model.

The implementation must document the sign convention.

The first implementation should use:

```text
incoming current = positive
outgoing current = negative
```

or the inverse, provided the convention is globally explicit and deterministic.

The topology extractor must apply the same convention consistently.

---

## 12. Kirchhoff's Voltage Law

KVL expresses conservation of energy around a closed electrical loop.

Canonical form:

```text
Σ V = 0
```

A loop may be represented as:

```text
V1 + V2 + V3 + ... + Vn = 0
```

with signed voltage contributions according to an explicit traversal convention.

---

## 13. KVL Representation

Conceptually:

```text
KVLConstraint
  loopId
  voltageTerms[]
  traversalDirection
  signConvention
  equation
```

Engineering Analysis determines the loop and traversal.

The Equation Engine evaluates the resulting signed expression.

---

## 14. KVL Applicability

KVL applies to the adopted lumped-circuit model.

The initial implementation does not attempt electromagnetic field analysis.

The law's applicability and assumptions must remain explicit in the compiled knowledge package.

---

## 15. Electrical Power

Initial canonical relationships:

```text
P = V × I
P = I² × R
P = V² / R
```

Derived forms may also be represented explicitly:

```text
I = P / V
V = P / I
R = V² / P
```

Only forms required by the analysis planner need to be initially compiled.

---

## 16. Power Dimensions

The runtime must validate:

```text
V × A = W
A² × Ω = W
V² / Ω = W
```

The Quantity Engine establishes dimensional equivalence.

The Electrical Law Library establishes that these relationships are valid electrical laws/models under their applicability conditions.

---

## 17. Series Resistance

For resistors in series:

```text
R_total = R1 + R2 + ... + Rn
```

Current is common through the series path under the applicable lumped-circuit model.

The relationship requires topology classification.

Therefore:

```text
Engineering Analysis
  identifies series topology
        |
        v
Law selection
        |
        v
Equation Engine
```

The law does not inspect the DiagramDocument itself.

---

## 18. Parallel Resistance

For resistors in parallel:

```text
1 / R_total = 1/R1 + 1/R2 + ... + 1/Rn
```

For two resistors:

```text
R_total = (R1 × R2) / (R1 + R2)
```

The two-resistor form may be provided as a specialized compiled equation.

The general form remains preferable for arbitrary resistor count.

---

## 19. Parallel Applicability

The relationship requires a valid parallel-resistor topology.

The analysis layer must establish that:

```text
all participating elements
share the same two electrical nodes
```

under the adopted circuit graph semantics.

The law package records this as applicability metadata.

---

## 20. Voltage Divider

For two series resistors:

```text
Vout = Vin × R2 / (R1 + R2)
```

where:

```text
Vin
R1
R2
Vout
```

must be explicitly defined.

The unloaded-divider relationship SHALL NOT automatically be applied to a loaded network.

A loaded divider requires a model including the load resistance.

---

## 21. Current Divider

For two parallel resistors:

```text
I1 = Itotal × R2 / (R1 + R2)
I2 = Itotal × R1 / (R1 + R2)
```

The reciprocal relationship between the branch resistance and branch current must be explicit.

Again, topology classification belongs to Engineering Analysis.

---

## 22. Law vs Component Model

Electrical laws describe general relationships.

Component models describe device-specific behavior.

For example:

```text
Ohm's Law
```

does not itself define:

```text
what a diode does
```

A future diode model may use equations that depend on:

```text
temperature
forward voltage
current
device parameters
```

The law library must therefore remain separate from AP-EK-006 Component Behavior Models.

---

## 23. Assumptions

Each law/equation may declare assumptions.

Examples:

```text
steady state
lumped circuit
ideal conductor
linear resistor
constant resistance
unloaded output
```

Assumptions must be structured data.

They must not exist only as prose.

---

## 24. Applicability Evaluation

The runtime should expose structured applicability outcomes:

```text
APPLICABLE
NOT_APPLICABLE
INSUFFICIENT_CONTEXT
UNKNOWN
```

For example:

```text
Voltage Divider
```

may return:

```text
INSUFFICIENT_CONTEXT
```

if the topology indicates a divider candidate but loading information is unavailable.

The system must not silently assume an unloaded output.

---

## 25. Law Selection

Law selection is an Engineering Analysis responsibility.

The selection pipeline is:

```text
Engineering Graph
       |
       v
Topology / component model
       |
       v
Candidate laws
       |
       v
Applicability evaluation
       |
       v
Selected law/equation
       |
       v
Equation Engine
```

The runtime may provide candidate discovery APIs, but selection must remain deterministic and explainable.

---

## 26. Law Registry

Conceptual API:

```text
ElectricalLawRegistry
  getLaw(lawId)
  listLaws(domain)
  getEquations(lawId)
  evaluateApplicability(lawId, context)
```

The registry must be immutable during an analysis session.

---

## 27. Law Versioning

A law package must carry:

```text
lawVersion
knowledgeVersion
schemaVersion
compilerVersion
```

A change to any authoritative law definition must result in an identifiable knowledge/runtime version change.

Previously produced analyses must retain the versions necessary to explain their result.

---

## 28. Provenance

Every law and equation must retain provenance.

Minimum conceptual fields:

```text
sourceObjectId
sourceReference
knowledgeVersion
lawVersion
equationId
```

The exact provenance contract is inherited from AP-EK-001/AP-EK-002.

The law runtime must not invent missing provenance.

---

## 29. Deterministic Law Package

The compiled electrical law package must be deterministic.

Identical authoritative inputs and compiler versions must produce equivalent:

```text
law identities
equation identities
serialized definitions
indexes
integrity metadata
```

Ordering must be canonical.

---

## 30. First Electrical Law Package

The initial package SHALL contain at minimum:

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

This is intentionally a compact foundation rather than a complete electrical textbook.

---

## 31. First Vertical Slice

The first end-to-end analysis should use:

```text
12 V source
10 Ω resistor
ground/reference
```

Expected:

```text
I = 12 V / 10 Ω
I = 1.2 A

P = 12 V × 1.2 A
P = 14.4 W
```

The resulting analysis must identify:

```text
selected law
equation
inputs
calculated quantities
derivation
provenance
```

---

## 32. Example — KCL

Given a node:

```text
I1 = 2 A incoming
I2 = 1 A incoming
I3 = 3 A outgoing
```

Signed representation:

```text
+2 A +1 A -3 A = 0 A
```

Result:

```text
KCL SATISFIED
```

If:

```text
I3 = 2.5 A
```

then:

```text
+2 A +1 A -2.5 A = 0.5 A
```

Result:

```text
KCL VIOLATION
```

subject to the analysis tolerance policy.

---

## 33. Example — KVL

For a loop containing:

```text
+12 V source
-7 V drop
-5 V drop
```

the signed sum is:

```text
12 V - 7 V - 5 V = 0 V
```

Result:

```text
KVL SATISFIED
```

---

## 34. Example — Series Resistance

Given:

```text
R1 = 10 Ω
R2 = 20 Ω
```

series relationship:

```text
Rtotal = 10 Ω + 20 Ω
Rtotal = 30 Ω
```

With:

```text
Vin = 12 V
```

Ohm's Law may then determine:

```text
I = 12 V / 30 Ω
I = 0.4 A
```

The multi-equation chain belongs to Engineering Analysis.

---

## 35. Example — Parallel Resistance

Given:

```text
R1 = 10 Ω
R2 = 20 Ω
```

two-resistor parallel form:

```text
Rtotal = (10 × 20) / (10 + 20)
       = 200 / 30
       = 6.666... Ω
```

The numeric result must retain the configured precision policy rather than being prematurely rounded.

---

## 36. Constraint Interaction

Electrical laws calculate relationships.

Constraints evaluate conditions.

Example:

```text
calculated current = 1.2 A
fuse rating = 1.0 A
```

Law result:

```text
I = 1.2 A
```

Constraint result:

```text
CURRENT_RATING_EXCEEDED
```

The law library must not embed arbitrary component ratings.

Those belong to component models/reference constraints.

---

## 37. Analysis Result

A law-driven result should be represented conceptually as:

```text
AnalysisResult
  resultId
  status
  quantities[]
  equations[]
  derivation
  provenance[]
  constraints[]
  runtimeVersion
```

The precise result contract is finalized in AP-EK-009.

---

## 38. Failure Modes

The electrical law subsystem must explicitly handle:

```text
UNKNOWN_LAW
UNKNOWN_EQUATION
NOT_APPLICABLE
INSUFFICIENT_CONTEXT
MISSING_INPUT
INVALID_DIMENSIONS
DIVISION_BY_ZERO
TOPOLOGY_REQUIREMENT_UNMET
CONSTRAINT_VIOLATION
```

Failure must never silently downgrade to an approximate answer.

---

## 39. AI Boundary

AI may:

```text
explain Ohm's Law
describe why KCL applies
suggest a candidate law for human review
translate engineering terminology
```

AI may not:

```text
modify authoritative law definitions
invent missing equations
override applicability
override dimensional validation
replace deterministic calculation
alter provenance
```

AI suggestions remain hypotheses until accepted into the authoritative knowledge workflow.

---

## 40. Testing

### Law registration

- every initial law resolves;
- identifiers remain stable;
- versions are exposed.

### Equation validity

```text
V = I × R
P = V × I
P = I² × R
P = V² / R
```

must pass dimensional validation.

### KCL

Valid and violating node examples must be distinguished.

### KVL

Valid and violating loop examples must be distinguished.

### Topology-dependent laws

Series/parallel/divider equations must reject contexts lacking required topology information.

### Loaded divider

An unloaded divider equation must not be selected when a load materially changes the circuit.

### Provenance

Every selected law/equation must preserve its authoritative source identity/version.

### Determinism

Identical runtime package and analysis inputs must yield equivalent results.

---

## 41. Definition of Done

AP-EK-005 is complete when:

1. EngineeringLaw contract is defined;
2. law/equation distinction is explicit;
3. initial electrical law registry exists;
4. Ohm's Law is represented;
5. KCL is represented;
6. KVL is represented;
7. power relationships are represented;
8. series resistance is represented;
9. parallel resistance is represented;
10. voltage divider is represented;
11. current divider is represented;
12. assumptions are structured;
13. applicability is structured;
14. provenance is preserved;
15. law/equation versions are deterministic;
16. first vertical slice evaluates end-to-end;
17. invalid applicability is reported rather than guessed;
18. AP-EK-006 can build component models without duplicating law infrastructure.

---

## 42. Follow-On

```text
AP-EK-006  Component Behavior Models
AP-EK-007  Circuit Analysis / Topology Solver
AP-EK-008  Constraint Evaluation
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/Diagram Studio Analysis API
```

---

## Architectural Non-Negotiables

1. Engineering laws are authoritative knowledge, not UI logic.
2. Laws and equations are distinct concepts.
3. Equations are executable only after deterministic compilation/validation.
4. Dimensional validation is mandatory.
5. Applicability is explicit.
6. Topology-dependent law selection belongs to Engineering Analysis.
7. Component behavior is separate from general electrical laws.
8. Provenance is mandatory for authoritative law execution.
9. AI cannot become an authority for electrical computation.
10. Invalid or insufficient context produces an explicit result status.
11. Runtime law packages are versioned.
12. The first law library remains deliberately compact.
13. Existing OEP Engineering Object and Relationship identity remain authoritative.
14. The law library does not bypass the Reference Compiler.
15. The law library remains independent of Diagram Studio and Flutter.
