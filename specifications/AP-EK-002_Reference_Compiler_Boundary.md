# AP-EK-002
# Reference Compiler Boundary
## Canonical Knowledge → Deterministic Runtime Knowledge

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessor:** AP-EK-001 — OEP Knowledge Contract  
**Authoritative source:** `oep_reference_library`  
**Acquisition/trust source:** `oep_acqusition`  
**Runtime consumer:** OEP Knowledge Runtime / Analysis Engine

---

## 1. Purpose

Define the architectural and data boundary between canonical engineering knowledge and the executable knowledge consumed by the OEP Knowledge Runtime.

The compiler exists to transform validated canonical knowledge into a deterministic runtime representation without:

- creating a second authoring system;
- moving reference-library authority into `oep_engine`;
- allowing Diagram Studio to become a knowledge store;
- allowing an LLM to manufacture engineering truth;
- losing identity, provenance, version, or evidence.

The compiler is a transformation boundary, not a new source of truth.

---

## 2. Authority Model

The authority chain is:

```text
Authoritative Sources
        |
        v
oep_acqusition
        |
        | acquisition / trust / immutable source record
        v
oep_reference_library
        |
        | canonical engineering knowledge
        v
REFERENCE COMPILER
        |
        | validated deterministic runtime representation
        v
OEP KNOWLEDGE RUNTIME
        |
        v
ENGINEERING ANALYSIS
        |
        v
Diagram Studio
```

`oep_reference_library` remains authoritative for canonical reference knowledge.

The runtime is authoritative only for the compiled representation of a specific published runtime version.

The compiler does not become authoritative over the source material.

---

## 3. Existing OEP Identity Rule

The existing Engineering Object Model establishes that Engineering Objects are the fundamental units of engineering knowledge, have permanent UUID identity, and are independent of UI concerns.

Therefore:

```text
canonical objectId
        |
        +----> runtime representation
```

is required.

The compiler MUST NOT generate a new UUID that replaces the canonical object's identity.

A compiler MAY generate a derived runtime identifier for indexing or internal lookup, but that identifier MUST remain explicitly subordinate to the canonical `objectId`.

---

## 4. Boundary Responsibilities

### `oep_acqusition`

Responsible for acquisition and trust-layer concerns.

It may provide:

```text
source records
acquisition metadata
integrity information
immutable source artifacts
provenance references
```

It does not become the runtime analysis engine.

### `oep_reference_library`

Responsible for:

```text
canonical engineering knowledge
schema validation
canonical representation
knowledge authoring/reference compilation concerns
deterministic source data
```

### Reference Compiler

Responsible for:

```text
canonical input validation
semantic validation
cross-reference validation
equation validation
unit/dimension validation
provenance validation
runtime normalization
runtime indexing
deterministic packaging
integrity metadata
```

### Knowledge Runtime

Responsible for:

```text
runtime lookup
model resolution
equation access
constraint access
component behavior access
analysis consumption
```

### `oep_engine`

Responsible for executing engineering analysis against the runtime knowledge and Engineering Graph.

It MUST NOT silently become the canonical reference-library authoring layer.

---

## 5. Compiler Input Contract

The compiler SHALL consume canonical, validated engineering objects from the Reference Library boundary.

Conceptually:

```text
CanonicalKnowledgeSet
  schemaVersion
  knowledgeVersion
  objects[]
  relationships[]
  evidence[]
  manifests[]
```

The exact canonical schema names remain subordinate to the eventual authoritative Reference Library/EKO schema.

This specification does not replace that schema.

---

## 6. Compiler Output Contract

The compiler SHALL produce a versioned runtime knowledge package.

Conceptually:

```text
RuntimeKnowledgePackage
  manifest
  schemaVersion
  runtimeVersion
  compilerVersion

  entities[]
  laws[]
  equations[]
  units[]
  componentModels[]
  behaviors[]
  constraints[]

  indexes[]
  provenance[]
  integrity[]
```

The output is optimized for deterministic lookup and execution.

Optimization may include:

```text
normalized fields
lookup indexes
compiled equation representations
unit lookup tables
domain indexes
applicability indexes
relationship indexes
```

Such optimization MUST NOT change engineering meaning.

---

## 7. Compilation Stages

The compiler pipeline SHALL be explicit.

```text
CANONICAL KNOWLEDGE
        |
        v
1. Input integrity validation
        |
        v
2. Schema validation
        |
        v
3. Identity validation
        |
        v
4. Relationship/reference validation
        |
        v
5. Semantic validation
        |
        v
6. Equation validation
        |
        v
7. Unit/dimension validation
        |
        v
8. Constraint validation
        |
        v
9. Provenance validation
        |
        v
10. Runtime normalization
        |
        v
11. Runtime indexing
        |
        v
12. Deterministic package generation
        |
        v
13. Package integrity verification
        |
        v
PUBLISHED RUNTIME PACKAGE
```

A failed mandatory stage prevents publication.

---

## 8. Stage 1 — Input Integrity

Before interpretation, the compiler verifies that the input set is internally intact.

Minimum checks:

```text
manifest present
schema version present
knowledge version present
required objects present
required referenced objects present
source integrity metadata valid
```

Corrupt or incomplete input MUST fail compilation.

---

## 9. Stage 2 — Schema Validation

The compiler validates every canonical object against the authoritative schema version supplied by the Reference Library.

Validation includes:

```text
required fields
field types
enumerations
identity format
relationship structure
version structure
nested object structure
```

The compiler MUST reject unknown mandatory schema violations rather than guessing.

---

## 10. Stage 3 — Identity Validation

The compiler verifies:

```text
objectId exists
objectId is valid
objectId is unique within the knowledge set
objectId is stable
```

References to missing objects MUST fail compilation unless the canonical schema explicitly defines them as optional external references.

Runtime compilation cannot repair broken identity.

---

## 11. Stage 4 — Relationship and Reference Validation

All internal references are resolved.

Examples:

```text
law -> equation
equation -> variable
component model -> property
component model -> behavior
constraint -> subject
knowledge object -> evidence
```

Broken references MUST be reported as compilation errors.

The compiler MUST NOT silently drop unresolved engineering relationships.

---

## 12. Stage 5 — Semantic Validation

Structural validity is insufficient.

The compiler SHALL validate semantic requirements appropriate to the knowledge classification.

Examples:

```text
LAW:
  must reference valid equations

EQUATION:
  must define valid variables and expression

COMPONENT_MODEL:
  must define valid terminals/properties/behaviors

CONSTRAINT:
  must reference a valid subject and condition

PROVENANCE:
  must identify an authoritative source
```

Semantic validation rules should be deterministic and versioned.

---

## 13. Stage 6 — Equation Validation

Every executable equation SHALL pass:

```text
syntax validation
variable validation
operator validation
dependency validation
dimension validation
domain validation
constraint validation
deterministic evaluator compatibility
```

The compiler MUST NOT invoke an LLM to validate whether an equation is mathematically executable.

The compiler should reject unsupported expressions rather than reinterpret them.

---

## 14. Stage 7 — Unit and Dimension Validation

Every quantity-bearing field must resolve to a known unit definition where units are required.

The compiler validates:

```text
unit identity
dimension
scale
offset
conversion compatibility
equation input dimensions
equation output dimensions
```

Example:

```text
I = V / R

V -> voltage
R -> resistance
I -> current

dimensionally valid
```

An equation with incompatible dimensions MUST fail compilation unless the canonical knowledge explicitly defines a valid transformation.

---

## 15. Stage 8 — Constraint Validation

Constraints are compiled into deterministic runtime forms.

Conceptually:

```text
Constraint
  subject
  condition
  severity
  message
  evidence
```

Conditions must be executable by the runtime constraint evaluator.

Natural-language-only constraints cannot become executable constraints without a canonical deterministic representation.

---

## 16. Stage 9 — Provenance Validation

Every authoritative engineering fact required at runtime MUST retain provenance.

At minimum:

```text
sourceObjectId
sourceVersion
sourceLocation
authority
```

Where supplied by upstream systems, preserve:

```text
contentHash
publication
revision
author
acquisitionRecord
validationRecord
```

The compiler MUST fail publication when mandatory provenance is missing.

---

## 17. Provenance Preservation Rule

Compilation is allowed to normalize data.

It is NOT allowed to sever traceability.

Therefore:

```text
runtime fact
    |
    v
canonical object identity
    |
    v
source evidence
```

must remain traversable.

A runtime optimization that makes provenance impossible to recover is invalid.

---

## 18. Runtime Normalization

Normalization may convert canonical structures into forms optimized for runtime execution.

Examples:

```text
string enum -> integer/internal enum
equation expression -> parsed expression tree
unit definition -> indexed unit record
object collection -> lookup index
applicability rules -> indexed predicates
```

Normalization MUST preserve:

```text
meaning
identity
version
provenance
applicability
constraints
```

---

## 19. Determinism

Given identical:

```text
canonical knowledge
compiler version
compiler configuration
schema version
```

the compiler SHALL produce semantically identical output.

Where deterministic package bytes are required, the compiler SHALL additionally use:

```text
stable ordering
stable serialization
stable numeric representation
stable metadata ordering
stable index construction
```

No timestamp, random UUID, process ID, machine-specific path, or nondeterministic map ordering may alter package content unless explicitly declared outside the content identity.

---

## 20. Runtime Version Identity

A runtime package SHALL identify:

```text
runtimeVersion
sourceKnowledgeVersion
schemaVersion
compilerVersion
```

It SHOULD additionally retain:

```text
sourceKnowledgeHash
compilerConfigurationHash
packageContentHash
```

This permits exact reproduction and historical analysis.

---

## 21. Incremental Compilation

The architecture SHOULD permit incremental compilation.

A changed canonical object may invalidate:

```text
direct dependents
equation consumers
component models
constraints
indexes
domain profiles
```

The compiler must calculate the affected dependency closure rather than blindly assuming unrelated knowledge changed.

However, incremental compilation MUST produce the same result as a clean compilation of the same source/version.

---

## 22. Compilation Diagnostics

Compiler diagnostics SHALL be structured.

Conceptual form:

```text
Diagnostic
  severity
  code
  objectId
  field
  message
  sourceLocation
  relatedObjectIds[]
```

Severity:

```text
ERROR
WARNING
INFO
```

Errors prevent publication.

Warnings may be permitted only when the package contract explicitly allows them.

---

## 23. Example Diagnostic

```text
ERROR EK-EQUATION-003

Object:
  electrical.ohms_law.current

Field:
  expression

Problem:
  Variable R has no declared dimension.

Related:
  electrical.resistance

Action:
  Declare the variable dimension before publication.
```

Diagnostics must be actionable and traceable.

---

## 24. Publication Boundary

Compilation and publication are separate operations.

```text
Canonical Knowledge
        |
        v
Compile
        |
        v
Candidate Runtime Package
        |
        v
Validation
        |
        v
Integrity Verification
        |
        v
Publish
        |
        v
Runtime Registry
```

An invalid candidate MUST NOT become visible as an active runtime version.

---

## 25. Runtime Package Activation

A runtime consumer must resolve an explicit runtime version.

It must not silently load an arbitrary newer package.

Conceptually:

```text
Analysis Request
      |
      +-- document version
      |
      +-- knowledge runtime version
      |
      +-- analysis engine version
      |
      v
Reproducible Analysis Context
```

This protects historical analysis from knowledge drift.

---

## 26. Package Integrity

The runtime package SHALL contain integrity information.

At minimum:

```text
package content identity
source knowledge identity
schema identity
compiler identity
```

The implementation should reuse established OEP package integrity and signing conventions rather than introducing a second package-security system.

---

## 27. Offline Operation

The runtime package MUST be usable without access to:

```text
Internet
Reference Library
Acquisition service
LLM service
Exchange
```

once the package has been provisioned.

This supports deterministic offline analysis and the OEP offline-first architecture.

---

## 28. No Reverse Authority

The runtime MUST NOT write canonical changes back into the Reference Library.

Invalid:

```text
Runtime
  |
  +--> modifies canonical reference
```

Valid:

```text
Reference Library
  |
  v
Compiler
  |
  v
Runtime
```

If engineering users identify a correction, that correction must enter the authoritative knowledge lifecycle through an explicit authoring/review process.

---

## 29. No Studio Compilation

Diagram Studio must not compile reference knowledge.

DS may request:

```text
analysis
knowledge lookup
evidence
derivation
explanation context
```

through Engine/runtime interfaces.

It must not directly:

```text
parse canonical reference files
compile equations
resolve authoritative component models
publish runtime knowledge
```

---

## 30. Domain Profile Boundary

Domain-specific knowledge must remain separable.

Example:

```text
Electrical Engineering
        |
        +-- Automotive Electrical
        |      +-- 12 V systems
        |      +-- 24 V systems
        |      +-- starting
        |      +-- charging
        |      +-- lighting
        |      +-- relay logic
        |
        +-- Industrial Electrical
        |
        +-- Power Electronics
```

The compiler should compile domain profiles as explicit runtime partitions or metadata.

Automotive-specific rules must not be hard-coded into the universal mathematical engine.

---

## 31. Initial Electrical Runtime Package

The first package should contain only the knowledge necessary for the initial deterministic vertical slice.

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

### Initial component models

```text
voltage source
current source
resistor
switch
fuse
diode
```

Reactive relationships remain deferred until the DC foundation is validated.

---

## 32. Example Compilation

Canonical source:

```text
Engineering Object
  objectId: R1-model
  classification: COMPONENT_MODEL
  name: Resistor

Property:
  resistance
  quantity dimension: resistance

Evidence:
  sourceObjectId: <reference>
  sourceVersion: 1.2
```

Compiler output:

```text
Runtime Component Model
  canonicalObjectId: R1-model
  classification: COMPONENT_MODEL

  property:
    resistance -> resistance dimension

  provenance:
    sourceObjectId: <reference>
    sourceVersion: 1.2
```

The runtime representation is derived.

The canonical object remains authoritative.

---

## 33. Compiler Failure Rule

The compiler MUST prefer failure over invention.

It must never:

```text
guess a missing unit
invent a missing equation variable
infer a missing engineering property from prose
replace missing provenance
silently discard a broken relationship
ask an LLM to decide engineering truth
```

When required information is absent, compilation fails with a structured diagnostic.

---

## 34. Test Strategy

### Identity

- canonical IDs preserved;
- duplicate IDs rejected;
- broken references rejected.

### Schema

- valid objects compile;
- invalid objects fail;
- unsupported schema versions fail cleanly.

### Equations

- valid equations compile;
- invalid syntax fails;
- unsupported operators fail;
- invalid variables fail;
- dimension mismatch fails.

### Provenance

- missing required provenance fails;
- provenance survives normalization;
- runtime facts resolve back to canonical evidence.

### Determinism

Compile identical source twice.

Expected:

```text
same semantic result
same package content
same content identity
```

### Incremental compilation

A changed source object produces the same final package as a clean rebuild.

### Publication

Invalid packages cannot become active.

### Offline

A published package performs runtime lookup without source-library access.

---

## 35. Security and Trust Boundary

The compiler is a trust boundary.

Untrusted source material must not become executable runtime behavior merely because it is syntactically valid.

The compiler SHALL distinguish:

```text
source authenticity
schema validity
semantic validity
engineering authority
runtime executability
```

A source can be syntactically valid and still fail authority or semantic validation.

---

## 36. Architectural Non-Negotiables

1. `oep_reference_library` remains authoritative.
2. `oep_acqusition` remains the acquisition/trust boundary.
3. Engineering Object identity remains canonical.
4. Runtime knowledge is derived, not independently authored.
5. Compilation never invents engineering truth.
6. LLM inference is never a compilation authority.
7. Provenance survives compilation.
8. Runtime packages are versioned and integrity-verifiable.
9. Deterministic input produces deterministic output.
10. DS does not compile or author reference knowledge.
11. `oep_engine` consumes runtime knowledge rather than replacing the Reference Library.
12. Existing OEP package/security conventions are reused.
13. Domain profiles remain separable from universal runtime mathematics.
14. No broad Engine rewrite is authorized for this phase.
15. Missing knowledge causes explicit diagnostics rather than silent assumptions.

---

## 37. Definition of Done

AP-EK-002 is complete when:

1. the canonical-source/runtime boundary is explicit;
2. ownership of `oep_acqusition`, `oep_reference_library`, compiler, runtime, Engine, and DS is explicit;
3. canonical Engineering Object identity is preserved;
4. compiler stages are defined;
5. schema, semantic, equation, unit, constraint, and provenance validation are defined;
6. deterministic compilation requirements are defined;
7. runtime version identity is defined;
8. publication and activation boundaries are defined;
9. reverse mutation from runtime into canonical knowledge is prohibited;
10. offline runtime operation is supported architecturally;
11. diagnostics are structured;
12. the initial electrical package has a bounded scope;
13. AP-EK-003 can begin without inventing a compiler boundary.

---

## 38. Follow-On Architecture

```text
AP-EK-003  Quantity + Unit Engine
AP-EK-004  Deterministic Equation Engine
AP-EK-005  Electrical Law Library
AP-EK-006  Component Behavior Models
AP-EK-007  Circuit Analysis
AP-EK-008  Constraint Evaluation
AP-EK-009  Provenance + Derivation
AP-EK-010  Engine/DS Analysis API
AP-EK-011  DS Analysis Surface
AP-EK-012  Automotive Electrical Profile
```

---

## Source Basis

This specification is derived from AP-ENGINEERING-KNOWLEDGE-001, which defines `oep_reference_library` as the authoritative reference-library/compiler domain, `oep_acqusition` as the acquisition/trust layer, the Knowledge Compiler → Knowledge Runtime boundary, deterministic executable equations, provenance, versioning, and the Engine/DS analysis boundary.

It also preserves OEP-SPEC-004, which establishes Engineering Objects as the fundamental units of engineering knowledge, permanent object identity, repository ownership, and UI-independent storage.

OEP-SPEC-005 establishes that relationships connect Engineering Objects into the engineering knowledge graph and that relationship storage remains independent of Studios.

No unsupported canonical “EKO Schema 1.0” definition is introduced by this specification.
