# AP-EK-001
# OEP Knowledge Contract
## Runtime Knowledge, Equations, Quantities, Provenance, and Versioning

**Status:** Architecture Phase — Proposed
**Parent:** AP-ENGINEERING-KNOWLEDGE-001
**Purpose:** Define the contract between authoritative OEP engineering knowledge and deterministic engineering analysis.

---

## 1. Authority

This specification builds on the existing OEP Engineering Object and Relationship models.

The existing Engineering Object specification establishes that Engineering Objects are the fundamental units of engineering knowledge, have permanent UUID identity, are repository-owned, serializable, and independent of UI concerns.

The existing Relationship specification establishes that relationships connect Engineering Objects into a navigable engineering knowledge graph.

This phase therefore does NOT create a parallel knowledge-object identity system.

**Important:** an exact, separately named “EKO Schema 1.0” artifact was not located in the available repository/library evidence. This specification therefore defines the minimum analysis contract while preserving the existing Engineering Object model as the identity authority. A future canonical EKO schema must supersede any provisional field naming here.

---

## 2. Contract Boundary

```text
oep_reference_library
        |
        | canonical engineering knowledge
        v
Knowledge Compiler
        |
        | validated runtime representation
        v
Knowledge Runtime
        |
        +--------------------+
        |                    |
        v                    v
Engineering Graph      Analysis Engine
        |                    |
        +----------+---------+
                   |
                   v
              AnalysisResult
                   |
                   v
             Diagram Studio
```

The Knowledge Runtime is a consumer/runtime representation of canonical knowledge.

It is NOT a second authoring repository.

---

## 3. Identity

Every runtime knowledge entity MUST retain its canonical Engineering Object identity.

Minimum identity contract:

```text
objectId
objectType
version
```

`objectId` is the permanent identity.

Runtime compilation MAY add:

```text
runtimeId
compiledVersion
contentHash
```

but these MUST NOT replace canonical object identity.

---

## 4. Knowledge Classification

The runtime SHALL distinguish at least:

```text
CONCEPT
LAW
EQUATION
QUANTITY_DEFINITION
UNIT
COMPONENT_MODEL
BEHAVIOR_MODEL
CONSTRAINT
DOMAIN_PROFILE
REFERENCE
```

These are knowledge classifications, not necessarily new Foundation object types.

Implementation should use the existing object-type/metadata mechanisms unless the canonical EKO schema later establishes dedicated types.

---

## 5. Engineering Law Contract

A law is a knowledge object that establishes a governing engineering relationship.

Conceptual contract:

```text
EngineeringLaw
  identity
  name
  domain
  description
  equations[]
  applicability[]
  constraints[]
  evidence[]
```

Example:

```text
objectId: <canonical UUID>
classification: LAW
name: Ohm's Law

equations:
  electrical.ohms_law.voltage
  electrical.ohms_law.current
  electrical.ohms_law.resistance
```

The law itself is declarative knowledge.

Its equations provide executable mathematical relationships.

---

## 6. Equation Contract

An equation SHALL be represented in a machine-evaluable form.

Minimum contract:

```text
Equation
  id
  expression
  variables[]
  inputDimensions[]
  outputDimension
  domain
  applicability[]
  constraints[]
  evidence[]
```

The expression MUST be deterministic.

The runtime MUST NOT require an LLM to evaluate an equation.

Example:

```text
id:
  electrical.ohms_law.current

expression:
  I = V / R

variables:
  V -> voltage
  R -> resistance
  I -> current

inputDimensions:
  voltage
  resistance

outputDimension:
  current
```

---

## 7. Expression Safety

The initial equation evaluator SHALL support only an explicitly defined mathematical grammar.

It SHALL NOT evaluate arbitrary executable code.

Initial grammar may include:

```text
literal
variable
+
-
*
/
parentheses
power
```

Future grammar extensions require a separate architecture increment.

Expressions that cannot be parsed or dimensionally validated SHALL be rejected.

---

## 8. Quantity Contract

Engineering numerical values SHALL be represented as explicit quantities.

```text
Quantity
  value
  unit
```

Examples:

```text
12.6 V
4.2 A
10 Ω
14.4 W
```

A raw floating-point number SHALL NOT be treated as an engineering quantity when units are required for interpretation.

---

## 9. Unit Contract

Units SHALL have explicit identity and dimensional structure.

Conceptual model:

```text
Unit
  id
  symbol
  dimension
  scale
  offset
```

Example:

```text
volt
  symbol: V
  dimension: electrical_potential
```

The unit engine must distinguish:

```text
same dimension
compatible dimension
incompatible dimension
```

Unit conversion must be deterministic.

---

## 10. Dimensional Validation

Before an equation executes:

1. all required variables must be bound;
2. every quantity must have a valid unit;
3. units must be dimensionally compatible;
4. the equation's output dimension must be valid;
5. explicit constraints must be satisfied.

Example:

```text
V = 12 V
R = 10 Ω

I = V / R

dimension:
V / Ω = A

valid
```

An expression such as:

```text
12 V + 10 Ω
```

must fail dimensional validation.

---

## 11. Component Model Contract

A component model describes how an engineering object participates in analysis.

Conceptual contract:

```text
ComponentModel
  componentClassification
  properties[]
  terminals[]
  states[]
  behaviors[]
  equations[]
  constraints[]
  evidence[]
```

The model must remain separate from the visual representation of the component.

---

## 12. Property Contract

Component properties must retain engineering meaning.

Examples:

```text
resistance
capacitance
inductance
ratedVoltage
ratedCurrent
ratedPower
forwardVoltage
coilResistance
```

Each numerical property SHALL use a Quantity where applicable.

Example:

```text
resistance = 85 Ω
ratedVoltage = 12 V
ratedPower = 1.5 W
```

---

## 13. Behavior Contract

Behavior models describe state-dependent behavior.

Example:

```text
Relay

state:
  deenergized
  energized

behavior:
  deenergized -> contacts open
  energized -> contacts closed
```

Behavior SHALL be represented declaratively or through a deterministic runtime model.

Arbitrary executable behavior is outside the initial scope.

---

## 14. Constraint Contract

Constraints describe valid operating conditions.

```text
Constraint
  id
  subject
  condition
  severity
  message
  evidence[]
```

Example:

```text
subject:
  relay coil

condition:
  appliedVoltage <= maximumSpecifiedVoltage

severity:
  warning
```

Constraint evaluation produces deterministic results.

---

## 15. Provenance Contract

Every authoritative engineering fact used in analysis MUST retain provenance.

Minimum provenance:

```text
Evidence
  sourceObjectId
  sourceVersion
  sourceLocation
  authority
```

Where available, provenance SHOULD additionally include:

```text
contentHash
publication
revision
author
acquisitionRecord
validationRecord
```

The analysis engine must be able to identify the evidence behind:

- a law,
- an equation,
- a component property,
- a constraint,
- a conclusion.

---

## 16. Fact Classification

Analysis must distinguish:

```text
REFERENCE_FACT
INPUT_VALUE
MODEL_ASSUMPTION
CALCULATED_VALUE
REFERENCE_CONSTRAINT
ENGINEERING_INFERENCE
HYPOTHESIS
```

These categories must never be silently collapsed.

Example:

```text
R1 = 10 Ω
  type: INPUT_VALUE

I = 1.2 A
  type: CALCULATED_VALUE

R1 rated power >= 14.4 W
  type: REFERENCE_CONSTRAINT

"R1 may overheat"
  type: ENGINEERING_INFERENCE
```

---

## 17. Derivation Contract

Every derived value SHALL retain its derivation.

```text
DerivationStep
  stepId
  operation
  inputs[]
  equationId
  output
  assumptions[]
  evidence[]
```

Example:

```text
Step 1:
  equation = electrical.ohms_law.current

  inputs:
    V = 12 V
    R = 10 Ω

  output:
    I = 1.2 A
```

This permits deterministic “Why?” explanations.

---

## 18. Analysis Result Contract

Conceptual minimum:

```text
AnalysisResult
  analysisId
  documentIdentity
  graphContext
  knowledgeRuntimeVersion
  inputs[]
  equationsUsed[]
  derivedValues[]
  constraintsEvaluated[]
  derivation[]
  conclusions[]
  evidence[]
  warnings[]
```

The result is an immutable analysis snapshot.

---

## 19. Versioning

An analysis MUST record the versions required to reproduce it.

```text
knowledgeRuntimeVersion
knowledgeEntityVersions[]
analysisEngineVersion
documentVersion
```

A later knowledge revision must not silently rewrite the meaning of a historical analysis.

---

## 20. Runtime Compilation

The compiler transforms canonical knowledge into runtime form.

```text
Canonical Engineering Objects
            |
            v
Schema validation
            |
            v
Semantic validation
            |
            v
Equation validation
            |
            v
Unit/dimension validation
            |
            v
Provenance validation
            |
            v
Deterministic compilation
            |
            v
Runtime Knowledge Package
```

Compilation failures MUST prevent publication of the affected runtime package.

---

## 21. Runtime Package Minimum

A runtime package should contain:

```text
manifest
knowledge entities
laws
equations
units
component models
behaviors
constraints
indexes
provenance
schema version
compiler version
integrity information
```

It must be:

- deterministic,
- versioned,
- integrity-verifiable,
- offline-capable,
- portable,
- independently testable.

The package mechanism should reuse existing OEP package conventions.

---

## 22. Knowledge Lookup

The Analysis Engine must be able to resolve:

```text
component classification
applicable laws
applicable equations
required variables
component properties
behavior models
constraints
evidence
```

Lookup should be deterministic.

Given the same:

```text
knowledge runtime version
engineering graph
operating state
input values
```

the same knowledge resolution must occur.

---

## 23. Analysis Boundary

The analysis engine consumes:

```text
EngineeringGraph
+
OperatingState
+
KnowledgeRuntime
```

and produces:

```text
AnalysisResult
```

It does not consume rendered SVG, Flutter widgets, raw reference documents, or natural-language descriptions as authoritative engineering inputs.

---

## 24. Diagram Studio Boundary

DS receives immutable analysis/view data.

```text
Analysis Engine
       |
       v
AnalysisResult
       |
       v
DS Controller
       |
       v
Analysis / Derivation / Knowledge / Evidence surfaces
```

DS SHALL NOT:

- implement electrical laws,
- calculate engineering values in widgets,
- maintain a parallel circuit model,
- directly read raw reference-library files,
- become the knowledge database.

This is consistent with the established DS boundary that engineering logic remains authoritative in the Engine and presentation consumes immutable value data.

---

## 25. Initial Electrical Knowledge Set

The first compiled knowledge set should contain only enough knowledge to validate the complete pipeline.

### Laws

```text
Ohm's Law
Kirchhoff's Current Law
Kirchhoff's Voltage Law
```

### Power

```text
P = V * I
P = I² * R
P = V² / R
```

### Network relationships

```text
series resistance
parallel resistance
voltage divider
current divider
```

### Components

```text
voltage source
current source
resistor
switch
fuse
diode
```

---

## 26. First Acceptance Circuit

```text
12 V Source
     |
    R1
   10 Ω
     |
    GND
```

Expected deterministic result:

```text
V = 12 V
R = 10 Ω

I = V / R
I = 1.2 A

P = V * I
P = 14.4 W
```

The system must also retain:

```text
equation used
input values
derived values
derivation steps
knowledge versions
source evidence
```

---

## 27. Acceptance Tests

### Identity

- canonical object IDs survive compilation;
- versions are retained;
- runtime IDs cannot replace canonical IDs.

### Equation

- valid expressions evaluate;
- invalid expressions fail;
- missing variables fail;
- divide-by-zero is rejected;
- arbitrary code cannot execute.

### Units

- compatible units calculate;
- convertible units normalize;
- incompatible dimensions fail.

### Provenance

- every law has evidence;
- every equation has evidence;
- every authoritative property has evidence;
- every derived value has a derivation.

### Determinism

Same inputs + same runtime version = same result.

### Versioning

Changing a knowledge entity creates a distinct version and does not mutate historical analysis meaning.

---

## 28. Architectural Decisions

### AD-001
Engineering Object identity remains authoritative.

### AD-002
Knowledge Runtime is compiled/derived from canonical knowledge and is not a competing authoring store.

### AD-003
Equations are executable knowledge, but execution is performed by a deterministic evaluator.

### AD-004
Units are first-class analytical data.

### AD-005
Provenance is mandatory for authoritative engineering knowledge.

### AD-006
Derivation is mandatory for calculated conclusions.

### AD-007
AI is outside the deterministic calculation boundary.

### AD-008
The first implementation targets a complete DC electrical vertical slice rather than universal circuit simulation.

---

## 29. Required Follow-On Work

```text
AP-EK-002  Reference Compiler Boundary
AP-EK-003  Quantity + Unit Engine
AP-EK-004  Deterministic Equation Engine
AP-EK-005  Electrical Law Library
AP-EK-006  Component Behavior Models
AP-EK-007  Circuit Analysis
AP-EK-008  Constraint Evaluation
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/DS Analysis API
```

---

## 30. Definition of Done

AP-EK-001 is complete when:

1. the existing Engineering Object model is confirmed as the identity authority;
2. no parallel knowledge-object identity model exists;
3. equation, quantity, unit, provenance, derivation, component, behavior, constraint, and analysis-result contracts are defined;
4. runtime/compiler boundaries are explicit;
5. versioning requirements are explicit;
6. deterministic-vs-AI authority boundaries are explicit;
7. the first electrical vertical slice has measurable acceptance criteria;
8. AP-EK-002 can begin without inventing another knowledge model.

---

## Source Basis

This contract preserves the existing OEP principles that Engineering Objects are the fundamental units of engineering knowledge, that object identity is permanent, that objects are repository-owned and UI-independent, and that relationships form the engineering knowledge graph.

The parent AP-ENGINEERING-KNOWLEDGE-001 establishes the need for deterministic equations, explicit quantities/units, component models, constraints, provenance, derivation, versioning, and DS consumption through an Engine-facing analysis API.

The current DS architecture also establishes that engineering graph, simulation, measurement, routing, validation, and related engineering logic remain Engine-authoritative and that Studio must not create a parallel engineering model.
