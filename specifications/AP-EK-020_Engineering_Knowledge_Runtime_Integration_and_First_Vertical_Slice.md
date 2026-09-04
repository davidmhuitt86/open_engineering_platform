# AP-EK-020 — Engineering Knowledge Runtime Integration & First End-to-End Vertical Slice

**Status:** Architecture / Implementation Specification  
**Phase:** AP-EK — Engineering Knowledge Runtime  
**Predecessors:** AP-EK-001 through AP-EK-019  
**Purpose:** Define the first executable, end-to-end Engineering Knowledge vertical slice connecting authoritative reference knowledge to deterministic runtime analysis, persisted analysis evidence, explanation, and Diagram Studio presentation.

---

## 1. Purpose

AP-EK-020 is the integration boundary between the individual subsystems defined in AP-EK-001 through AP-EK-019.

The objective is no longer to define another isolated subsystem. The objective is to prove that the architecture can execute one complete engineering workflow:

```text
Authoritative Reference Knowledge
        ↓
oep_reference_library
        ↓
Reference Compiler
        ↓
Signed Knowledge Package
        ↓
Engineering Knowledge Runtime
        ↓
OEP Engine
        ↓
Engineering Graph / Electrical Topology
        ↓
Deterministic Analysis
        ↓
AnalysisResult
        ↓
Analysis Persistence
        ↓
Engineering Explanation
        ↓
Diagram Studio
```

The first vertical slice shall be intentionally small but architecturally complete.

The canonical acceptance circuit is:

```text
12 V ideal voltage source
        │
        │
      10 Ω resistor
        │
        │
      Reference Node
```

Expected steady-state result:

```text
Current = 1.2 A
Resistor Power = 14.4 W
```

The system must be able to explain where those values came from and preserve the knowledge/runtime/provenance identity required to reproduce them.

---

# 2. Architectural Objective

The first vertical slice must demonstrate that OEP can move from **knowledge** to **engineering computation** without placing engineering authority inside Diagram Studio or an AI subsystem.

The authority chain remains:

```text
Authoritative Source
    ↓
Acquisition / Trust
    ↓
Reference Library
    ↓
Knowledge Compiler
    ↓
Knowledge Runtime
    ↓
Engineering Analysis
    ↓
Analysis Evidence
    ↓
Explanation / Teaching
    ↓
Diagram Studio
```

No layer may bypass the layer above it to manufacture engineering truth.

In particular:

- Diagram Studio does not implement Ohm's law.
- Diagram Studio does not perform circuit calculations.
- AI does not determine electrical values.
- Exchange does not become an engineering authority.
- Runtime does not become the canonical reference library.
- Analysis results do not become authoritative design facts.
- UI state does not become engineering state.

---

# 3. First Vertical Slice Definition

The minimum complete slice contains the following capabilities:

1. Load a validated knowledge package.
2. Verify package integrity.
3. Activate an immutable runtime snapshot.
4. Resolve the canonical resistor component model.
5. Resolve the canonical voltage-source component model.
6. Resolve the reference-node model.
7. Resolve Ohm's law.
8. Accept an OEP Engineering Object / DiagramDocument.
9. Convert diagram connectivity into electrical topology.
10. Resolve component instances into behavior models.
11. Extract numerical inputs.
12. Construct a deterministic linear electrical system.
13. Solve the system.
14. Evaluate electrical constraints.
15. Produce deterministic derivation steps.
16. Produce provenance records.
17. Produce an immutable AnalysisResult.
18. Persist the analysis evidence.
19. Generate a deterministic engineering explanation.
20. Present the result in Diagram Studio.
21. Detect stale analysis after document modification.
22. Re-run analysis and produce a new analysis identity.
23. Reproduce the same result from the same snapshot and runtime.

This is the smallest useful proof of the architecture.

---

# 4. Explicit Non-Goals

The first vertical slice does **not** require:

- full nonlinear solving;
- transient simulation;
- AC analysis;
- frequency sweeps;
- arbitrary symbolic algebra;
- AI-generated engineering calculations;
- full marketplace integration;
- complete teaching curriculum;
- every component type;
- every electrical law;
- automatic schematic recognition from images;
- OCR-driven engineering interpretation;
- cloud dependency;
- online operation;
- broad Studio UI redesign.

Those capabilities are defined by later specifications or remain future implementation work.

The first slice must not become bloated in an attempt to prove every future feature.

---

# 5. Repository / Package Boundaries

The implementation must preserve the established subsystem boundaries.

Conceptually:

```text
oep_reference_library/
    canonical engineering knowledge

oep_acqusition/
    acquisition and trust metadata

knowledge compiler/
    canonical knowledge → runtime package

oep_exchange/
    publication/distribution/licensing

oep_foundation/
    repository and Engineering Object foundations

oep_engine/
    runtime + analysis + engineering computation

oep_studio/
    presentation and interaction
```

The implementation may place compiler/runtime code in the repository locations established by the actual implementation architecture, but the **logical ownership boundaries are mandatory**.

Do not collapse all components into one package merely to simplify the first implementation.

---

# 6. Canonical Knowledge Package

The first package shall contain only the knowledge required by the acceptance circuit.

Minimum package contents:

```text
Package Manifest
    ├── package identity
    ├── package version
    ├── schema version
    ├── compiler version
    ├── source knowledge version
    ├── content hash
    ├── publisher identity
    └── signature metadata

Units
    ├── volt
    ├── ampere
    ├── ohm
    └── watt

Dimensions
    ├── voltage
    ├── current
    ├── resistance
    └── power

Component Models
    ├── ideal voltage source
    ├── resistor
    └── reference node

Engineering Laws
    └── Ohm's Law

Equations
    ├── V = I × R
    ├── I = V / R
    └── P = V × I

Constraints
    ├── resistance > 0
    └── required source/reference topology constraints

Provenance
    └── source lineage for every authoritative knowledge item
```

The package must not contain hidden assumptions that are not represented in its structured knowledge.

---

# 7. Package Identity

Every activated package must have a stable identity.

Minimum identity:

```text
packageId
packageVersion
schemaVersion
compilerVersion
sourceKnowledgeVersion
contentHash
signature
publisherId
```

Runtime activation must preserve these values.

An analysis result must identify the exact package/runtime snapshot used to calculate it.

---

# 8. Runtime Activation

Runtime activation shall be transactional.

Required sequence:

```text
Load
  ↓
Parse
  ↓
Validate
  ↓
Verify Integrity
  ↓
Verify Signature / Trust
  ↓
Build Immutable Registries
  ↓
Build Runtime Snapshot
  ↓
Activate
```

Failure at any stage must prevent activation of the incomplete package.

Activation must not mutate an already active snapshot.

Existing analyses must remain reproducible against their original runtime identity after a newer package is activated.

---

# 9. Runtime Registry

The runtime must expose typed lookup facilities.

Conceptual interface:

```text
KnowledgeRuntime
    getUnit(unitId)
    getDimension(dimensionId)
    getComponentModel(modelId)
    getLaw(lawId)
    getEquation(equationId)
    getConstraint(constraintId)
    getProvenance(referenceId)
```

The actual implementation language/API may differ.

The important architectural rule is that the analysis engine consumes **typed runtime knowledge**, not raw package files.

---

# 10. Diagram Input Contract

The analysis layer consumes authoritative engineering structure.

Minimum input:

```text
DiagramDocument
    documentId
    documentVersion
    engineeringObjects
    relationships
    diagram connectivity
    component instances
    component parameters
```

The geometry of the diagram is not itself the electrical model.

The topology extractor must derive electrical connectivity from engineering relationships/terminal connectivity.

For the first circuit:

```text
VoltageSource(+)
      ↓
Resistor
      ↓
ReferenceNode
```

The exact representation must follow the existing OEP Engineering Object and Relationship models.

No parallel competing identity model shall be introduced.

---

# 11. Topology Extraction

The topology stage converts engineering graph structure into an electrical topology.

Required outputs:

```text
ElectricalNode
ElectricalBranch
ComponentInstance
TerminalConnection
ReferenceNode
```

Every derived topology entity must retain traceability to its source Engineering Object.

Example:

```text
Engineering Object:
    resistor-instance-001

Topology:
    branch-001

Component Model:
    resistor

Parameter:
    R = 10 Ω
```

Topology generation must be deterministic.

Equivalent input graph ordering must not arbitrarily change generated node identifiers or result ordering.

---

# 12. Component Model Resolution

Each electrical component instance must resolve to a runtime Component Model.

For the first slice:

```text
Voltage Source Instance
    → Ideal Voltage Source Model

Resistor Instance
    → Resistor Model

Reference Node Instance
    → Reference Node Model
```

Resolution failure is a hard analysis failure.

The engine must not silently substitute a generic component model.

---

# 13. Parameter Resolution

The resistor requires:

```text
R = 10 Ω
```

The voltage source requires:

```text
V = 12 V
```

Parameters must be represented as typed quantities.

Conceptually:

```text
Quantity(
    value = 10,
    unit = ohm
)

Quantity(
    value = 12,
    unit = volt
)
```

Raw untyped numerical values must not enter the engineering solver where a typed quantity is required.

---

# 14. Electrical System Construction

The first slice shall construct a normalized linear DC electrical system.

The preferred general foundation remains nodal analysis / modified nodal analysis rather than a special-case "voltage divided by resistor" implementation.

For the circuit:

```text
12 V source → 10 Ω resistor → ground
```

the solver must establish the relevant node voltage and branch current from the component equations and topology.

A special-case shortcut may be used as an optimization only if it produces the same authoritative component-level and provenance-level result as the general model.

The general solver remains the architectural source of truth.

---

# 15. Equation Resolution

Ohm's law must be resolved through the Knowledge Runtime.

Required equation:

```text
I = V / R
```

with:

```text
V = 12 V
R = 10 Ω
```

Dimensional validation occurs before evaluation.

Expected:

```text
12 V / 10 Ω = 1.2 A
```

The equation engine must record the equation identity/version used.

---

# 16. Power Calculation

Resistor power must be calculated using an authoritative equation.

Preferred first-slice equation:

```text
P = V × I
```

with:

```text
V = 12 V
I = 1.2 A
```

Result:

```text
P = 14.4 W
```

The result must preserve:

- equation identity;
- input quantities;
- output quantity;
- unit;
- derivation step;
- provenance.

---

# 17. Analysis Orchestration

The Engine analysis pipeline shall conceptually execute:

```text
AnalysisRequest
    ↓
Document Snapshot
    ↓
Topology Extraction
    ↓
Component Model Resolution
    ↓
Parameter Resolution
    ↓
Law Resolution
    ↓
Equation Resolution
    ↓
System Construction
    ↓
Deterministic Solve
    ↓
Constraint Evaluation
    ↓
Derivation Assembly
    ↓
Provenance Assembly
    ↓
AnalysisResult
```

No stage should require Diagram Studio UI state.

---

# 18. Analysis Request

Minimum request:

```text
AnalysisRequest
    requestId
    documentId
    documentVersion
    analysisMode
    requestedOutputs
    runtimeVersion
    knowledgePackageId
    numericPolicy
```

The request must identify the exact document version being analyzed.

A request must be immutable once execution begins.

---

# 19. Analysis Result

Minimum result:

```text
AnalysisResult
    analysisId
    requestId
    documentId
    documentVersion
    status
    runtimeIdentity
    topology
    componentResults
    nodeResults
    branchResults
    equationResults
    constraintResults
    diagnostics
    derivation
    provenance
    reproducibility
```

For the first circuit, the result must expose at least:

```text
Source Voltage = 12 V
Resistance = 10 Ω
Current = 1.2 A
Power = 14.4 W
```

---

# 20. Result Status

Minimum statuses:

```text
SUCCESS
PARTIAL
INVALID_INPUT
UNSUPPORTED
NON_CONVERGENT
SINGULAR
INCONSISTENT
INSUFFICIENT_DATA
FAILED
STALE
```

The first successful circuit must return:

```text
SUCCESS
```

A result must never report SUCCESS when required engineering constraints or model resolution failed.

---

# 21. Constraint Evaluation

At minimum evaluate:

```text
R > 0
```

and topology/reference-node validity.

For the acceptance circuit:

```text
R = 10 Ω
R > 0
→ SATISFIED
```

Constraint results must be preserved as structured evidence.

---

# 22. Power Balance

The first slice should include a basic power consistency check.

For the resistor:

```text
P_R = 14.4 W
```

For an ideal 12 V source delivering 1.2 A:

```text
P_source = -14.4 W
```

depending on the established passive-sign convention.

The total power balance should resolve to the expected numerical residual within the configured tolerance.

This validates more than Ohm's law alone: it verifies topology, sign convention, current direction, and component power accounting.

---

# 23. Derivation

The result must contain deterministic derivation steps.

Example conceptual derivation:

```text
Step 1:
Resolve voltage source.
V = 12 V

Step 2:
Resolve resistor.
R = 10 Ω

Step 3:
Apply Ohm's Law.
I = V / R

Step 4:
Evaluate.
I = 12 V / 10 Ω
I = 1.2 A

Step 5:
Calculate resistor power.
P = V × I

Step 6:
Evaluate.
P = 12 V × 1.2 A
P = 14.4 W
```

These steps are structured data first.

Human-readable text is generated downstream.

---

# 24. Provenance

Every authoritative input must retain lineage.

For example:

```text
12 V
    → voltage-source instance
    → voltage-source component model
    → analysis input

10 Ω
    → resistor instance
    → resistor component model
    → analysis input

I = V / R
    → Ohm's Law
    → equation version
    → runtime package
```

The final result must allow an engineer to answer:

> Where did this value come from?

and:

> Which knowledge/runtime version produced it?

---

# 25. Reproducibility Descriptor

The result must contain sufficient identity to reproduce the analysis.

Minimum:

```text
documentId
documentVersion
documentHash
knowledgePackageId
knowledgePackageVersion
knowledgePackageHash
runtimeVersion
compilerVersion
solverVersion
numericPolicy
analysisMode
```

If any required identity cannot be recorded, the result must explicitly report reduced reproducibility rather than pretending the analysis is fully reproducible.

---

# 26. Analysis Persistence

Analysis evidence is separate from:

```text
DiagramDocument
DiagramWorkspaceState
DiagramTabsStorage
DiagramStudioSettings
```

Persisting an analysis must not modify authoritative diagram engineering data.

A persisted analysis is an evidence artifact associated with a specific document version.

Conceptually:

```text
Document
    └── Analysis History
          ├── Analysis A
          ├── Analysis B
          └── Analysis C
```

Each analysis retains its own identity and runtime lineage.

---

# 27. Stale Analysis

If the diagram changes after analysis:

```text
Document Version 10
    ↓
Analysis A
```

then a modification creates:

```text
Document Version 11
```

Analysis A must no longer be treated as current for Version 11.

It remains historically valid for Version 10.

Re-analysis creates:

```text
Analysis B
    documentVersion = 11
```

The system must not mutate Analysis A into Analysis B.

---

# 28. Explanation Layer

The Explanation Service consumes AnalysisResult.

It does not recalculate engineering values.

For the acceptance circuit, the deterministic explanation should communicate:

```text
A 12 V source is connected through a 10 Ω resistor to the reference node.

Using Ohm's law:

I = V / R
I = 12 / 10
I = 1.2 A

The resistor dissipates:

P = V × I
P = 12 × 1.2
P = 14.4 W
```

The explanation must be traceable to the structured derivation and provenance.

---

# 29. Explanation Failure Behavior

If analysis fails, the explanation layer must explain the failure rather than invent a result.

Examples:

```text
No reference node found.
→ Cannot establish the required circuit reference.

Resistor resistance missing.
→ Current cannot be determined.

Unsupported nonlinear component.
→ This analysis mode cannot evaluate the selected model.
```

AI may later improve wording, but it cannot alter the underlying engineering result or failure classification.

---

# 30. Diagram Studio Integration

Diagram Studio receives analysis results through the established Engine boundary.

Conceptually:

```text
DS
  ↓ AnalysisRequest
Engine
  ↓ AnalysisResult
DS
```

DS may display:

- component values;
- current;
- voltage;
- power;
- constraint status;
- diagnostic messages;
- derivation;
- provenance;
- stale-state indicators.

DS must not calculate:

```text
12 / 10
```

itself.

---

# 31. Visual Traceability

A result displayed on a diagram must be traceable back to its engineering entity.

Example:

```text
Resistor
   ↓
Current = 1.2 A
   ↓
AnalysisResult.componentResult
   ↓
Derivation Step
   ↓
Ohm's Law Equation
   ↓
Knowledge Package
```

This establishes the foundation for future "Explain Why" and "Show Calculation" interactions.

---

# 32. Multi-Instance Diagram Studio

Analysis identity must not be conflated with a Diagram Studio tab identity.

Two open instances may analyze the same document version.

They may receive equivalent results while retaining independent UI state.

Analysis identity remains:

```text
analysisId
```

Workspace identity remains:

```text
WorkspaceTab.id
```

Diagram instance identity remains governed by the existing Diagram Studio architecture.

These namespaces must not be merged.

---

# 33. Caching

The Engine may cache analysis results.

Cache keys must include all authoritative inputs.

Minimum conceptual key:

```text
documentHash
analysisMode
knowledgePackageHash
runtimeVersion
solverVersion
numericPolicy
requestedOutputs
```

A cached result may only be reused when the key proves semantic equivalence.

Cache hits must not alter the analysis identity rules for persisted evidence unless explicitly defined by the persistence implementation.

---

# 34. Determinism

The same:

```text
document snapshot
+
knowledge package
+
runtime
+
solver
+
numeric policy
```

must produce the same authoritative result.

Determinism applies to:

- topology ordering;
- node identifiers;
- equation selection;
- solver assembly;
- result ordering;
- constraint ordering;
- derivation ordering;
- provenance ordering;
- serialization;
- hashes.

Floating-point behavior must follow the numeric policy established by AP-EK-016 and related runtime specifications.

---

# 35. Negative Tests

The first vertical slice is not complete until failure behavior is tested.

Minimum negative fixtures:

### Missing resistance

```text
R = missing
```

Expected:

```text
INSUFFICIENT_DATA
```

### Invalid resistance unit

```text
R = 10 V
```

Expected:

```text
INVALID_INPUT
```

### No reference node

Expected:

```text
INVALID_INPUT
```

or the precise established topology failure status.

### Unsupported nonlinear component in linear mode

Expected:

```text
UNSUPPORTED
```

### Invalid knowledge package

Expected:

```text
Package activation failure
```

The runtime must not silently fall back to guessed knowledge.

---

# 36. First Integration Test

The first complete integration test should execute the entire chain.

Conceptual fixture:

```text
Fixture:
    knowledge package = electrical-core-1.0.0
    document = circuit-12v-10ohm-v1
```

Execution:

```text
Load package
Verify package
Activate runtime
Load document
Analyze
Persist result
Generate explanation
Reload result
Compare identities
```

Expected:

```text
Analysis Status = SUCCESS
Current = 1.2 A
Power = 14.4 W
```

The persisted and reloaded result must preserve the same engineering evidence.

---

# 37. Reproducibility Test

Execute the same fixture twice using the same runtime snapshot.

Expected:

```text
Result A == Result B
```

where equality applies to the canonical result representation, excluding intentionally unique execution metadata if such metadata is explicitly defined.

The engineering values, derivation, provenance, topology, constraints, and canonical serialization must be identical.

---

# 38. Runtime Upgrade Test

Run:

```text
Analysis A
    runtime/package version 1
```

Activate:

```text
runtime/package version 2
```

Then verify:

```text
Analysis A remains readable
Analysis A retains version-1 identity
New analyses use version 2
```

Existing evidence must never be silently rebound to the newer runtime.

---

# 39. Document Mutation Test

Run:

```text
Document v1
→ Analysis A
```

Modify the resistor:

```text
10 Ω → 20 Ω
```

creating:

```text
Document v2
```

Expected:

```text
Analysis A remains associated with v1
Analysis A is stale for v2
New Analysis B targets v2
```

Expected new current:

```text
I = 12 / 20
I = 0.6 A
```

This proves analysis identity follows document version.

---

# 40. Save / Analyze Separation

The following operations remain independent:

```text
Save Document
Analyze Document
Save Analysis
```

Saving a document does not implicitly analyze it.

Analyzing does not implicitly save engineering document changes.

Persisting an analysis does not mutate the diagram.

This separation is mandatory.

---

# 41. Exchange Integration Boundary

AP-EK-020 does not require the first implementation to depend on the live Engineering Exchange service.

The first package may be locally staged or test-distributed.

The architecture must nevertheless preserve the AP-EK-019 boundary:

```text
Reference Compiler
    ↓
Package
    ↓
Exchange / Distribution
    ↓
Runtime Package Manager
    ↓
Knowledge Runtime
```

For the first vertical slice, a local trusted package source is acceptable.

The package format and identity must remain production-compatible.

---

# 42. Acquisition Boundary

The first vertical slice does not need to perform live acquisition.

The package must nevertheless preserve source lineage originating from the authoritative reference workflow.

The runtime must never treat an arbitrary user-entered engineering statement as equivalent to authoritative reference knowledge.

---

# 43. Security / Trust Boundary

Package activation must distinguish at least:

```text
VALID
INVALID
UNTRUSTED
REVOKED
INCOMPATIBLE
```

An untrusted package must not become an authoritative runtime snapshot merely because its contents parse correctly.

Development/test modes may permit explicitly configured unsigned packages, but that exception must be visible in runtime state.

---

# 44. Implementation Sequence

Implementation should proceed in the following order.

### AP-EK-020.1 — Package Fixture

Create the minimal electrical knowledge package fixture.

Deliver:

```text
manifest
units
dimensions
component models
Ohm's law
power equation
constraints
provenance
```

### AP-EK-020.2 — Runtime Load

Implement package parsing, validation, verification, and immutable activation.

### AP-EK-020.3 — Typed Registry

Implement runtime lookup for units, models, laws, equations, and constraints.

### AP-EK-020.4 — Engine Adapter

Connect the existing Engine analysis pipeline to the runtime registry.

### AP-EK-020.5 — Topology Fixture

Create the canonical 12 V / 10 Ω document fixture.

### AP-EK-020.6 — Linear Analysis

Execute deterministic topology extraction, MNA/linear solving, equation evaluation, and constraint evaluation.

### AP-EK-020.7 — Evidence

Produce derivation, provenance, diagnostics, and reproducibility metadata.

### AP-EK-020.8 — Persistence

Persist and reload AnalysisResult and associated evidence.

### AP-EK-020.9 — Explanation

Generate deterministic engineering explanation from AnalysisResult.

### AP-EK-020.10 — Studio Contract

Expose AnalysisRequest / AnalysisResult through the existing Engine ↔ Studio boundary.

### AP-EK-020.11 — Studio Presentation

Display the first result and traceability information.

### AP-EK-020.12 — Mutation / Stale Test

Prove document versioning and analysis invalidation behavior.

### AP-EK-020.13 — Runtime Upgrade Test

Prove historical analysis remains bound to its original runtime identity.

### AP-EK-020.14 — End-to-End Gate

Run the complete vertical slice from package fixture through Studio-facing result.

---

# 45. Required Test Matrix

| Area | Required Test |
|---|---|
| Package | Valid package loads |
| Package | Invalid package rejected |
| Package | Hash mismatch rejected |
| Package | Trust failure rejected |
| Runtime | Immutable snapshot activation |
| Registry | Unit lookup |
| Registry | Model lookup |
| Registry | Law lookup |
| Registry | Equation lookup |
| Quantity | V / Ω = A |
| Quantity | V × A = W |
| Topology | Correct node extraction |
| Topology | Deterministic ordering |
| Solver | 12 V / 10 Ω |
| Solver | Correct current sign |
| Solver | Correct power |
| Constraint | Positive resistance |
| Constraint | Power balance |
| Provenance | Source lineage retained |
| Derivation | Ohm's law step retained |
| Persistence | Result reload |
| Persistence | Identity preserved |
| Reproducibility | Same inputs → same result |
| Staleness | Document mutation detected |
| Runtime version | Historical result preserved |
| Explanation | Correct calculation narrative |
| DS | Result received without local calculation |
| DS | Component traceability |
| Failure | Missing value |
| Failure | Invalid unit |
| Failure | Missing reference |
| Failure | Unsupported model |

---

# 46. Acceptance Criteria

AP-EK-020 is complete only when all of the following are true.

### Knowledge

- A canonical electrical knowledge fixture exists.
- Units, component models, law, equation, constraints, and provenance are represented structurally.
- No engineering fact is hidden only in executable code.

### Runtime

- Package validation works.
- Package identity is preserved.
- Runtime snapshots are immutable.
- Typed registry lookup works.
- Invalid/untrusted packages cannot silently activate.

### Engine

- Diagram topology is converted into an electrical model.
- Component behavior is resolved through runtime knowledge.
- Ohm's law is resolved through runtime knowledge.
- Deterministic linear analysis executes.
- Constraints execute.
- Power balance is checked.

### Evidence

- AnalysisResult is immutable.
- Derivation is structured.
- Provenance is structured.
- Runtime/package identity is retained.
- Reproducibility metadata is retained.

### Persistence

- Analysis can be saved and reloaded.
- Historical analysis remains associated with its original document/runtime identity.
- Document mutation produces stale analysis semantics rather than mutating history.

### Explanation

- Explanation is generated from AnalysisResult.
- Explanation does not perform independent engineering calculations.
- Explanation remains traceable to derivation/provenance.

### Diagram Studio

- DS can request analysis.
- DS can consume AnalysisResult.
- DS can display component-level results.
- DS does not calculate engineering values.
- DS can distinguish current from stale analysis.

### End-to-End

The canonical fixture must produce:

```text
12 V source
10 Ω resistor
1.2 A current
14.4 W resistor power
```

with complete knowledge/runtime/solver/provenance lineage.

---

# 47. Definition of Done

The AP-EK architecture should be considered **implementation-proven at the first vertical-slice level** when an engineer can perform the following sequence:

```text
1. Obtain the canonical knowledge package.
2. Verify its identity and trust.
3. Activate it in the Knowledge Runtime.
4. Open the canonical 12 V / 10 Ω diagram.
5. Request analysis.
6. Receive a deterministic AnalysisResult.
7. Inspect current and power.
8. Inspect the derivation.
9. Inspect provenance.
10. Persist the analysis.
11. Close/reopen the document.
12. Reload the analysis.
13. Modify the circuit.
14. Observe the previous analysis become stale.
15. Re-analyze.
16. Receive a new analysis identity.
17. Reproduce the same result from the same runtime snapshot.
```

No step may require Diagram Studio to contain engineering-law logic.

---

# 48. Architectural Gate After AP-EK-020

After AP-EK-020, the project should **stop expanding the AP-EK document sequence automatically**.

The next phase should be implementation-driven.

The correct decision point is:

```text
AP-EK-001 … AP-EK-020
        ↓
Architecture Complete Enough
        ↓
Implementation
        ↓
Integration Evidence
        ↓
Gap Audit
        ↓
Only then create additional AP-EK specifications if an actual architectural gap exists.
```

Additional documents should only be created when implementation exposes a real missing contract.

This prevents architecture from becoming an endless documentation exercise disconnected from executable software.

---

# 49. Final Architectural Position

AP-EK-020 establishes the transition from **architecture definition** to **architecture validation through implementation**.

The important achievement is not the ability to calculate:

```text
12 / 10 = 1.2
```

The important achievement is proving the complete chain:

```text
Authoritative Knowledge
        ↓
Canonical Knowledge Representation
        ↓
Deterministic Compilation
        ↓
Trusted Runtime Package
        ↓
Typed Engineering Models
        ↓
Engineering Graph
        ↓
Electrical Topology
        ↓
Deterministic Solver
        ↓
Constraint Evaluation
        ↓
Derivation
        ↓
Provenance
        ↓
Persisted Analysis Evidence
        ↓
Explanation
        ↓
Diagram Studio
```

If this vertical slice works cleanly, the architecture has demonstrated that OEP can turn authoritative engineering knowledge into reproducible engineering computation while preserving the separation between knowledge, runtime, analysis, evidence, explanation, and presentation.

That is the primary architectural purpose of AP-EK-020.
