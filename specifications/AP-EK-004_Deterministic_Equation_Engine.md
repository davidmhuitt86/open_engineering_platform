# AP-EK-004
# Deterministic Equation Engine
## Engineering Equation Representation, Validation, Evaluation, and Derivation Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 — Reference Compiler Boundary; AP-EK-003 — Quantity + Unit Engine  
**Primary consumer:** OEP Engineering Analysis Runtime

---

## 1. Purpose

Define the deterministic Equation Engine that converts authoritative engineering equations into executable, validated calculations.

The Equation Engine SHALL:

- represent equations as structured knowledge;
- validate equation structure before execution;
- resolve quantities and units through the Quantity + Unit Engine;
- evaluate equations deterministically;
- reject dimensionally invalid expressions;
- expose derivation information;
- preserve provenance;
- produce structured Analysis-ready results;
- remain independent of AI and UI.

The Equation Engine is a computation mechanism, not an engineering-authority mechanism.

---

## 2. Architectural Position

The equation subsystem sits between compiled engineering knowledge and deterministic engineering analysis:

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
        +---- Laws
        +---- Equations
        +---- Units
        +---- Component Models
        +---- Constraints
        |
        v
Equation Engine
        |
        v
Engineering Analysis
        |
        v
AnalysisResult
        |
        v
Diagram Studio
```

The Equation Engine SHALL NOT read raw reference documents during calculation.

---

## 3. Authority

An equation is authoritative only because it originates from the authoritative knowledge pipeline and is accepted into the compiled runtime.

The Equation Engine does not decide whether an equation is scientifically or engineeringly correct.

Its responsibilities are:

```text
structural validity
dimensional validity
input completeness
deterministic evaluation
error reporting
derivation production
```

---

## 4. Equation Contract

Conceptual model:

```text
Equation
  equationId
  name
  expression
  variables
  resultVariable
  domain
  applicability
  provenance
  version
```

Additional metadata MAY include:

```text
description
symbolDefinitions
assumptions
constraints
sourceObjectId
knowledgeVersion
```

The exact persisted schema is governed by the canonical knowledge contract.

---

## 5. Equation Identity

Every compiled equation SHALL have a stable identity.

Conceptually:

```text
equationId
```

must identify the equation independently of:

- display text;
- formatting;
- variable order;
- UI;
- runtime memory address.

Equation identity must survive recompilation when the authoritative equation has not changed.

---

## 6. Variables

An equation consists of typed variables.

Example:

```text
V = I × R
```

Variables:

```text
V
  role: result
  dimension: voltage

I
  role: input
  dimension: current

R
  role: input
  dimension: resistance
```

A variable reference is not itself a Quantity.

At evaluation time:

```text
Variable
    +
Quantity binding
    =
Evaluation input
```

---

## 7. Expression Representation

The engine SHALL use a structured expression representation.

A raw string such as:

```text
V = I * R
```

may be retained for human-readable presentation, but SHALL NOT be the sole executable representation.

The executable representation should be an expression tree / AST or equivalent canonical structure.

Conceptually:

```text
Multiply
  Variable(I)
  Variable(R)
```

with:

```text
result -> Variable(V)
```

This prevents execution from depending on arbitrary string parsing.

---

## 8. Supported Operators

The initial expression engine SHALL support:

```text
ADD
SUBTRACT
MULTIPLY
DIVIDE
POWER
NEGATE
```

Future operators may include:

```text
ABS
MIN
MAX
SQRT
SIN
COS
TAN
LOG
EXP
```

Advanced functions must not be added merely for convenience; each requires explicit domain and dimensional semantics.

---

## 9. Constants

Equations may contain constants.

Examples:

```text
2
1/2
π
```

Constants must have explicit semantic classification.

A scalar constant is dimensionless unless explicitly assigned a unit.

The engine SHALL not infer a unit for an untyped constant from surrounding operands unless the equation schema explicitly defines that behavior.

---

## 10. Quantity Binding

Evaluation begins by binding equation variables to Quantities.

Example:

```text
Equation:
V = I × R

Bindings:
I = 1.2 A
R = 10 Ω
```

The evaluator calculates:

```text
I × R
=
1.2 A × 10 Ω
=
12 V
```

The resulting Quantity is bound to:

```text
V
```

---

## 11. Dimensional Validation

Every expression node SHALL carry a determinable dimensional result.

For example:

```text
I × R
```

produces:

```text
A × Ω = V
```

The equation is valid only if the result dimension agrees with the declared result variable.

Therefore:

```text
V = I × R
```

passes.

An incorrectly declared equation such as:

```text
P = I × R
```

fails dimensional validation.

This validation occurs before execution.

---

## 12. Algebraic Validation

The engine SHALL validate equation structure independently of numerical values.

Required checks include:

- referenced variables exist;
- result variable exists;
- expression is structurally valid;
- operators have valid arity;
- powers have valid exponent semantics;
- declared dimensions agree;
- required bindings are known;
- prohibited operations are absent.

---

## 13. Evaluation Pipeline

A deterministic evaluation SHALL follow:

```text
1. Resolve equation
2. Verify equation version
3. Validate applicability
4. Validate required variables
5. Bind quantities
6. Validate dimensions
7. Evaluate expression
8. Validate result dimension
9. Apply precision policy
10. Construct derivation
11. Construct result
12. Attach provenance
```

No step may invoke an LLM to determine an engineering value.

---

## 14. Applicability

Equations may have conditions under which they are valid.

Examples:

```text
DC steady-state
linear resistor
ideal conductor
temperature range
frequency range
component operating region
```

Applicability metadata must be evaluated separately from mathematical syntax.

An equation may be mathematically valid but engineeringly inapplicable.

The Equation Engine should return an explicit applicability status rather than silently proceeding.

---

## 15. Equation Status

An evaluation SHALL distinguish at least:

```text
VALID
INVALID_STRUCTURE
INVALID_DIMENSIONS
MISSING_INPUT
INAPPLICABLE
EVALUATION_ERROR
UNKNOWN_EQUATION
```

This status must be machine-readable.

---

## 16. Multiple Forms of an Equation

The same law may have multiple useful forms.

Example:

```text
V = I × R

I = V / R

R = V / I
```

These may be represented as:

```text
distinct executable equations
```

or as one canonical relationship with derived solution forms.

The architecture should prefer a canonical relationship with deterministic derived forms when practical, while preserving distinct equation identities where the authoritative knowledge source treats them separately.

The implementation must not create mathematically equivalent equations and accidentally assign them conflicting authority.

---

## 17. Equation Solving

General symbolic solving is NOT part of the first implementation.

The initial engine executes precompiled equation forms.

For example:

```text
I = V / R
```

is compiled explicitly.

The engine does not need to discover that rearrangement dynamically.

This preserves:

```text
determinism
auditability
predictable performance
clear provenance
```

Symbolic algebra may become a future capability.

---

## 18. Intermediate Values

Evaluation may produce intermediate quantities.

Example:

```text
I = V / R
P = V × I
```

For:

```text
V = 12 V
R = 10 Ω
```

the first equation yields:

```text
I = 1.2 A
```

which becomes an input to:

```text
P = V × I
```

Intermediate results should remain available to the derivation graph.

---

## 19. Derivation

Every nontrivial calculated result SHOULD be explainable through a deterministic derivation.

Conceptual:

```text
Derivation
  equationId
  inputs
  operations
  intermediateValues
  result
```

Example:

```text
Input:
12 V

Input:
10 Ω

Operation:
V / R

Result:
1.2 A
```

The derivation records what the engine actually calculated.

It does not contain generated natural-language reasoning.

---

## 20. Provenance

The Equation Engine SHALL preserve provenance references supplied by the compiled knowledge package.

A result may therefore trace:

```text
AnalysisResult
   |
   +-- equationId
   +-- equationVersion
   +-- knowledgeVersion
   +-- sourceObjectId
   +-- input quantities
   +-- derivation
```

This permits an engineer to determine where the governing equation originated.

---

## 21. Precision

Evaluation SHALL use the numeric policy established by AP-EK-003.

The Equation Engine must not independently introduce arbitrary rounding.

Intermediate calculations should retain the precision required by the configured numeric representation.

Presentation rounding occurs outside the calculation core unless an authoritative equation explicitly requires rounding.

---

## 22. Division by Zero

Division by zero SHALL be detected before numeric evaluation where possible.

Example:

```text
I = V / R
R = 0 Ω
```

must produce a structured evaluation error.

The engine must not return:

```text
Infinity
NaN
```

as if these were valid engineering results.

---

## 23. Invalid Numeric Values

The engine must reject invalid numerical states where the selected numeric policy cannot represent a meaningful result.

Examples:

```text
NaN
Infinity
undefined numeric state
```

Such states must become structured diagnostics.

---

## 24. Exponents

The first implementation should support integer exponents.

Examples:

```text
R²
I²
V³
```

The dimensional signature must be raised to the same exponent.

Fractional or irrational exponents require additional dimensional semantics and are deferred unless required by the initial authoritative knowledge set.

---

## 25. Equation Composition

Equations may be chained.

Example:

```text
V = I × R
P = V × I
```

The analysis layer may execute:

```text
V
 |
 v
Equation 1
 |
 v
I
 |
 v
Equation 2
 |
 v
P
```

The Equation Engine remains responsible for each deterministic equation evaluation.

Graph-level sequencing belongs to Engineering Analysis.

---

## 26. Constraints

Equation evaluation may expose values required for constraint evaluation.

Example:

```text
calculated current = 1.2 A
component maximum current = 1.0 A
```

The Equation Engine reports:

```text
current = 1.2 A
```

The Constraint Engine determines:

```text
VIOLATION
```

This separation prevents equation execution from becoming a general constraint system.

---

## 27. Example — Ohm's Law

Equation:

```text
V = I × R
```

Bindings:

```text
I = 1.2 A
R = 10 Ω
```

Evaluation:

```text
1.2 A × 10 Ω
=
12 V
```

Result:

```text
12 V
```

Derivation:

```text
Equation: Ohm's Law
I × R
1.2 A × 10 Ω
12 V
```

---

## 28. Example — Power

Equation:

```text
P = V × I
```

Bindings:

```text
V = 12 V
I = 1.2 A
```

Result:

```text
14.4 W
```

Dimensional validation:

```text
V × A = W
```

---

## 29. Example — Invalid Equation

Declared:

```text
P = I × R
```

where:

```text
P = power
I = current
R = resistance
```

Dimensional evaluation:

```text
A × Ω = V
```

but:

```text
V != W
```

Therefore:

```text
INVALID_DIMENSIONS
```

No engineering result is emitted.

---

## 30. Equation Registry

The runtime SHALL expose a deterministic Equation Registry.

Conceptually:

```text
EquationRegistry
  getEquation(equationId)
  listEquations(domain)
  validateEquation(equationId)
  evaluate(equationId, bindings)
```

The registry must be immutable during an analysis session.

Changing the equation registry requires a new knowledge/runtime version.

---

## 31. Runtime Loading

Equations are loaded from the compiled Knowledge Runtime.

The evaluator does not load equations directly from:

```text
PDF
HTML
DOCX
image
raw source document
```

Those belong upstream in the acquisition/reference pipeline.

---

## 32. Caching

Deterministic equation evaluation MAY be cached.

A cache key must include every input that can affect the result, including as applicable:

```text
equationId
equationVersion
knowledgeVersion
unit registry version
numeric policy
input quantities
applicability context
```

Caching must never alter observable provenance.

---

## 33. Serialization

Equation definitions and evaluation results must serialize deterministically.

An evaluation result should contain enough information to reproduce or audit the calculation:

```text
equationId
equationVersion
inputs
result
status
derivation
knowledgeVersion
```

Large source documents should not be embedded in each result.

References/hashes should be used instead.

---

## 34. API Boundary

Conceptual runtime interface:

```text
EquationEngine
  validate(equation)
  evaluate(equation, bindings, context)
```

Supporting services:

```text
EquationRegistry
QuantityEngine
ApplicabilityEvaluator
DerivationBuilder
ProvenanceResolver
```

The Equation Engine owns equation execution.

It does not own:

```text
repository persistence
diagram rendering
Flutter widgets
simulation state
reference acquisition
marketplace licensing
```

---

## 35. Engineering Analysis Boundary

Engineering Analysis orchestrates multi-equation reasoning.

Conceptually:

```text
EngineeringGraph
      |
      v
Topology / model extraction
      |
      v
Applicable equation selection
      |
      v
Equation Engine
      |
      v
Calculated quantities
      |
      v
Constraint Engine
      |
      v
AnalysisResult
```

Equation selection is an analysis concern unless the equation itself contains explicit applicability rules.

The Equation Engine does not inspect arbitrary diagram topology.

---

## 36. AI Boundary

AI may assist with:

```text
explanation
natural-language summaries
candidate equation suggestions
documentation
interactive tutoring
```

AI must not:

```text
invent an equation
alter a compiled equation
override dimensional validation
supply a missing numerical result
override an applicability failure
change authoritative provenance
```

If AI proposes an equation, that proposal remains non-authoritative until accepted through the appropriate knowledge-authoring pipeline.

---

## 37. Testing

### Structural tests

- valid AST;
- invalid AST;
- missing variable;
- invalid operator arity;
- unknown equation;
- stable equation identity.

### Dimensional tests

```text
V = I × R -> valid
P = V × I -> valid
P = I × R -> invalid
```

### Numerical tests

```text
12 V / 10 Ω = 1.2 A
12 V × 1.2 A = 14.4 W
```

### Failure tests

```text
division by zero
missing input
incompatible dimensions
invalid numeric state
inapplicable equation
```

### Determinism tests

Repeated evaluation with identical:

```text
equation
knowledge version
inputs
unit registry
numeric policy
context
```

must produce equivalent serialized results.

### Provenance tests

Results must preserve:

```text
equation identity
version
input references
knowledge version
derivation
```

---

## 38. First Vertical Slice

The first end-to-end equation capability SHALL implement:

```text
Ohm's Law
V = I × R
```

and its explicit solved forms:

```text
I = V / R
R = V / I
```

plus:

```text
Power
P = V × I
```

Required result:

```text
12 V / 10 Ω = 1.2 A
12 V × 1.2 A = 14.4 W
```

The result must include deterministic derivation and provenance metadata.

---

## 39. Definition of Done

AP-EK-004 is complete when:

1. equation identity is defined;
2. structured equation representation exists;
3. executable expression representation exists;
4. variables are typed;
5. Quantity Engine integration works;
6. dimensional validation works;
7. deterministic evaluation works;
8. structured error/status handling exists;
9. applicability can be represented and evaluated;
10. derivation data is produced;
11. provenance is preserved;
12. equation registry is versioned;
13. deterministic serialization is implemented;
14. first electrical equations pass end-to-end tests;
15. Engineering Analysis can consume the results without duplicating equation logic.

---

## 40. Follow-On

```text
AP-EK-005  Electrical Law Library
AP-EK-006  Component Behavior Models
AP-EK-007  Circuit Analysis
AP-EK-008  Constraint Evaluation
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/Diagram Studio Analysis API
```

---

## Architectural Non-Negotiables

1. Equations are structured knowledge, not executable UI strings.
2. Compiled equations are the runtime authority.
3. Equation execution is deterministic.
4. Dimensional validation precedes calculation.
5. Quantity/unit logic is delegated to AP-EK-003.
6. General symbolic solving is deferred.
7. Applicability is explicit.
8. Invalid engineering operations fail explicitly.
9. Provenance is preserved.
10. Derivations describe actual computation, not generated reasoning.
11. AI cannot override engineering computation.
12. The Equation Engine remains independent of Flutter and Diagram Studio.
13. Engineering Analysis orchestrates multi-equation reasoning.
14. Runtime equations are versioned with their knowledge package.
15. Identical inputs and runtime versions must produce reproducible results.
