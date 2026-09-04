# AP-EK-009
# Provenance + Derivation
## Deterministic Engineering Evidence, Calculation Trace, and Result Lineage Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 through AP-EK-008  
**Primary consumers:** OEP Engineering Analysis Runtime  
**Presentation consumer:** Diagram Studio

---

## 1. Purpose

Define the provenance and derivation subsystem that makes every authoritative engineering analysis result traceable, reproducible, and auditable.

The subsystem answers:

```text
Where did this value come from?
Which engineering object supplied the input?
Which component model was used?
Which law and equation were applied?
Which runtime/version performed the calculation?
Which assumptions and constraints affected the result?
What deterministic operations produced the result?
```

The goal is not merely to provide an explanation.

The goal is to preserve an **evidence lineage** that can be inspected independently of generated natural-language text.

---

## 2. Architectural Principle

Every authoritative calculated result should have a machine-readable lineage.

Conceptually:

```text
AnalysisResult
      |
      v
Derivation
      |
      +---- Input Quantity
      +---- Component Model
      +---- Engineering Law
      +---- Equation
      +---- Operations
      +---- Intermediate Values
      +---- Constraints
      +---- Runtime Version
      |
      v
Authoritative Source
```

Natural-language explanations may be generated from this lineage, but the lineage itself is authoritative.

---

## 3. Provenance vs Derivation

These are distinct concepts.

### Provenance

Answers:

```text
Where did the knowledge/value originate?
```

Examples:

```text
sourceObjectId
knowledgeVersion
modelVersion
equationVersion
measurement source
design input
```

### Derivation

Answers:

```text
How was this result calculated?
```

Examples:

```text
12 V
÷
10 Ω
=
1.2 A
```

A result may have provenance without derivation, such as a direct reference fact.

A calculated result should normally have both.

---

## 4. Authority Chain

Canonical lineage:

```text
Authoritative Source
       |
       v
Acquisition / Trust Metadata
       |
       v
Reference Library
       |
       v
Compiled Knowledge Runtime
       |
       +---- Component Model
       +---- Engineering Law
       +---- Equation
       +---- Constraint
       |
       v
Engineering Analysis
       |
       v
AnalysisResult
```

The lineage must not bypass the authoritative knowledge pipeline.

---

## 5. Provenance Contract

Conceptual:

```text
ProvenanceRecord
  provenanceId
  sourceType
  sourceObjectId
  sourceReference
  knowledgeVersion
  schemaVersion
  compilerVersion
  contentHash
  recordedAt
```

Not every field is required for every source type.

The schema must explicitly define which combinations are valid.

---

## 6. Source Types

Initial source classifications:

```text
REFERENCE_KNOWLEDGE
ENGINEERING_OBJECT
COMPONENT_MODEL
ENGINEERING_LAW
EQUATION
CONSTRAINT
DESIGN_INPUT
MEASUREMENT
CALCULATED_VALUE
ASSUMPTION
```

These classifications must remain distinct.

A calculated value is not an authoritative reference fact simply because it has been persisted.

---

## 7. Input Provenance

Every analysis input should be traceable.

Example:

```text
R1 resistance = 10 Ω
```

could originate from:

```text
DESIGN_INPUT
```

while:

```text
Resistor model
```

originates from:

```text
REFERENCE_KNOWLEDGE
```

The result must preserve both lineages.

---

## 8. Derived Value Provenance

For:

```text
I = 12 V / 10 Ω
```

the current result provenance contains:

```text
12 V source lineage
10 Ω resistor lineage
Ohm's Law lineage
I = V/R equation lineage
runtime version
```

This makes the calculation auditable.

---

## 9. Derivation Contract

Conceptual:

```text
Derivation
  derivationId
  resultId
  steps[]
```

Each step contains:

```text
DerivationStep
  stepId
  operation
  inputs[]
  output
  equationId
  sequence
```

The derivation must describe the actual deterministic calculation.

---

## 10. Derivation Graph

A linear list may represent simple calculations.

For larger analyses, the canonical representation should support a directed acyclic graph:

```text
Input A ----\
             +--> Equation 1 --> Intermediate X --\
Input B ----/                                      |
                                                  +--> Equation 2 --> Result
Input C ------------------------------------------/
```

This allows shared intermediate values to be referenced without duplicating them.

---

## 11. Deterministic Step Identity

Derivation steps must have stable identity within a derivation.

Step identity must not depend on:

```text
memory address
UI position
random UUID generation
render order
```

A deterministic sequence/content identity should be used.

The exact implementation may use a deterministic hash or canonical sequence identifier.

---

## 12. Operation Record

Each derivation step must record the operation actually executed.

Examples:

```text
DIVIDE
MULTIPLY
ADD
SUBTRACT
POWER
NEGATE
```

or:

```text
EQUATION_EVALUATION
```

when the equation evaluator itself is the atomic operation.

The representation must be sufficient to reconstruct the calculation path.

---

## 13. Equation Reference

Where an equation drives a step:

```text
equationId
equationVersion
```

must be recorded.

Example:

```text
equation:
electrical.ohms_law.current

version:
1.x
```

The exact identifier is defined by the authoritative knowledge package.

---

## 14. Law Reference

Where the equation belongs to an Engineering Law, the derivation should preserve:

```text
lawId
lawVersion
```

Example:

```text
electrical.ohms_law
```

This permits the result to be traced at both levels:

```text
Law
  |
  +-- Equation
```

---

## 15. Component Model Reference

Where a component model supplied behavior or parameters, the derivation should retain:

```text
modelId
modelVersion
componentObjectId
```

Example:

```text
R1
model = electrical.resistor
resistance = 10 Ω
```

---

## 16. Runtime Identity

Every analysis result must identify the runtime environment that produced it.

Minimum conceptual fields:

```text
runtimeVersion
knowledgeVersion
schemaVersion
compilerVersion
numericPolicyVersion
```

Where unit/equation/model registries have independent versions, those may also be retained.

---

## 17. Reproducibility

A result should be reproducible when the required inputs remain available.

Reproduction requires:

```text
same graph/version
same component models
same laws/equations
same unit registry
same numeric policy
same analysis context
same runtime semantics
```

A provenance record must therefore contain or reference enough information to identify these dependencies.

---

## 18. Content Hashes

Where the OEP runtime uses content-addressed data, provenance should retain relevant content hashes.

Examples:

```text
knowledgePackageHash
equationDefinitionHash
modelDefinitionHash
inputObjectHash
```

Hashes provide integrity and identity verification.

The existing OEP content-addressing conventions should be reused.

---

## 19. Source References

A provenance record may contain:

```text
sourceObjectId
sourceReference
sourceLocation
```

depending on the source type.

For a large source document, provenance should reference the source rather than duplicating the entire document into every result.

---

## 20. Measurements

Measurement provenance may include:

```text
measurementId
instrument/source
timestamp
quantity
unit
measurementState
```

The provenance subsystem does not determine measurement accuracy.

Measurement quality/uncertainty is a separate capability.

---

## 21. Assumptions

Assumptions materially affecting a result must be represented.

Example:

```text
Assumption:
resistor behaves as an ideal ohmic component
```

The assumption should reference:

```text
assumptionId
source/provenance
scope
```

An assumption must not be hidden only inside generated prose.

---

## 22. Applicability Evidence

When a law/model is selected because applicability conditions are satisfied, the analysis should retain evidence of that decision.

Conceptually:

```text
ApplicabilityEvidence
  ruleId
  inputs
  result
  provenance
```

Example:

```text
Ohm's Law
applicable = true
model = linear resistor
```

---

## 23. Constraint Lineage

Constraint results should remain linked to their:

```text
constraintId
constraintVersion
actual quantity
limit quantity
comparison
status
```

Example:

```text
P = 14.4 W
rating = 10 W
P <= rating
VIOLATED
```

The violation should be traceable to both quantities and the authoritative constraint.

---

## 24. Result Lineage

Conceptual:

```text
AnalysisResult
  |
  +-- result identity
  +-- status
  +-- runtime identity
  +-- node/component results
  +-- derivation
  +-- provenance
  +-- constraints
  +-- diagnostics
```

Each calculated quantity should be traceable to its derivation and source inputs.

---

## 25. Direct Reference Facts

Not all results are calculated.

Example:

```text
component rated voltage = 16 V
```

This may be a direct reference fact.

It should contain provenance but does not require a mathematical derivation.

Classification:

```text
REFERENCE_FACT
```

must remain distinct from:

```text
CALCULATED_VALUE
```

---

## 26. Design Inputs

A user-supplied engineering value may be:

```text
12 V supply
10 Ω resistor
```

The system should classify it as:

```text
INPUT_VALUE
```

or the appropriate input/source classification.

It must not be falsely attributed to a reference document.

---

## 27. Engineering Inference

Some analysis outputs may be inferences rather than direct calculations.

Example:

```text
Circuit is likely overloaded
```

Such a statement must not be represented as a deterministic calculated quantity unless the underlying constraints establish that exact conclusion.

Inference should be explicitly classified.

---

## 28. Hypotheses

AI-assisted or engineer-proposed hypotheses may be represented as:

```text
HYPOTHESIS
```

They are not authoritative results.

The provenance system must preserve their non-authoritative status.

---

## 29. Provenance Immutability

Once an analysis result is committed, its provenance must not silently change.

If the underlying knowledge changes:

```text
new knowledge version
```

must produce a distinguishable analysis result/version.

Historical results must remain interpretable.

---

## 30. Knowledge Evolution

If:

```text
Ohm's Law package version 1
```

is replaced by:

```text
Ohm's Law package version 2
```

existing results retain:

```text
lawVersion = 1
```

New analyses use:

```text
lawVersion = 2
```

unless the engineer explicitly requests historical-runtime reproduction.

---

## 31. Derivation Serialization

Derivations must serialize deterministically.

Equivalent analyses under identical runtime inputs should produce equivalent derivation representations.

Canonical ordering is required for:

```text
steps
inputs
provenance references
equation references
diagnostics
```

---

## 32. Human Explanation Boundary

Natural-language explanation is a presentation capability.

For example:

```text
The resistor current is 1.2 A because 12 V divided by 10 Ω equals 1.2 A.
```

may be generated from the derivation.

However, the generated sentence is not the source of truth.

The authoritative data remains:

```text
equation
inputs
operations
result
provenance
```

---

## 33. AI Explanation Contract

AI may consume provenance/derivation to produce:

```text
engineering explanation
educational walkthrough
diagnostic summary
natural-language report
```

AI output must retain a clear distinction between:

```text
runtime fact
derived result
AI-generated explanation
AI-generated hypothesis
```

AI must not rewrite the underlying lineage.

---

## 34. Evidence Graph

The long-term architecture should expose an evidence graph:

```text
Source
  |
  v
Knowledge Object
  |
  v
Law
  |
  v
Equation
  |
  v
Component Model
  |
  v
Analysis Input
  |
  v
Derivation
  |
  v
Result
  |
  v
Constraint
```

This provides the basis for engineering audit, educational traceability, and future knowledge navigation.

---

## 35. Provenance API

Conceptual:

```text
ProvenanceService
  getProvenance(resultId)
  getSource(provenanceId)
  getLineage(resultId)
  getDerivation(resultId)
  verify(resultId)
```

The service should support traversal in both directions where permitted:

```text
result -> source
source -> dependent results
```

Reverse dependency traversal must not mutate authority.

---

## 36. Verification

A result should be verifiable against its recorded lineage.

Verification may include:

```text
runtime version exists
knowledge package exists
hashes match
equation exists
component model exists
inputs exist
derivation is structurally valid
serialized result is internally consistent
```

A verification failure should not silently mark the engineering result valid.

---

## 37. Tamper Detection

If content hashes are used, changed source/runtime artifacts must be detectable.

Example:

```text
recorded equation hash != current equation hash
```

Result:

```text
PROVENANCE_MISMATCH
```

The historical result remains preserved but cannot be claimed to match the current artifact.

---

## 38. Analysis Snapshot

For committed analyses, the system should be able to identify the complete dependency snapshot:

```text
graph version
knowledge runtime version
component models
laws
equations
constraints
unit registry
numeric policy
analysis context
```

The snapshot may reference immutable content-addressed packages rather than duplicating all content.

---

## 39. Cross-Platform Reproducibility

The provenance system must support verification across:

```text
Windows
Linux
macOS
Android
iOS
```

Identical dependency snapshots must produce equivalent deterministic results.

Platform-specific presentation must not become part of engineering calculation provenance.

---

## 40. Security Boundary

Provenance data is evidence metadata.

It must not execute arbitrary content.

The system must never interpret a provenance field as:

```text
executable script
dynamic code
untrusted expression
LLM instruction
```

---

## 41. Example — Complete Lineage

Input:

```text
R1 = 10 Ω
Vsource = 12 V
```

Component model:

```text
electrical.resistor
```

Law:

```text
electrical.ohms_law
```

Equation:

```text
I = V / R
```

Derivation:

```text
12 V
/
10 Ω
=
1.2 A
```

Result:

```text
I_R1 = 1.2 A
```

Power equation:

```text
P = V × I
```

Derivation:

```text
12 V
×
1.2 A
=
14.4 W
```

The final result references:

```text
source inputs
component model
law
equations
unit registry
knowledge version
runtime version
numeric policy
derivation
constraints
```

---

## 42. Example — Constraint Lineage

Given:

```text
P_R1 = 14.4 W
ratedPower = 10 W
```

Constraint:

```text
P <= ratedPower
```

Result:

```text
VIOLATED
```

Lineage:

```text
P_R1
  |
  +-- V_R1
  +-- I_R1
       |
       +-- Ohm's Law
       +-- resistor model
       +-- source input

ratedPower
  |
  +-- authoritative component data

Constraint
  |
  +-- P <= ratedPower

Result
  |
  +-- VIOLATED
```

---

## 43. Example — Provenance Failure

If the recorded equation hash no longer matches the referenced compiled equation:

```text
PROVENANCE_MISMATCH
```

The system should preserve the original result but clearly indicate that its dependency cannot currently be verified against the referenced artifact.

---

## 44. Storage Boundary

Provenance should be stored with analysis results or through immutable referenced records.

It must not require Diagram Studio local state.

Closing DS must not destroy engineering analysis provenance.

---

## 45. Repository Boundary

Committed engineering analysis results may be persisted through the existing OEP repository architecture.

Repository persistence is responsible for durable storage.

Provenance semantics remain owned by the Knowledge/Analysis architecture.

---

## 46. Performance

The provenance system must not make ordinary analysis impractical.

The architecture should support:

```text
compact references
content hashes
shared immutable records
lazy lineage expansion
```

Large source documents should not be copied into every derivation.

---

## 47. Testing

### Provenance

- source identity retained;
- knowledge version retained;
- model version retained;
- equation version retained;
- constraint version retained.

### Derivation

- deterministic step ordering;
- correct operation records;
- input/output linkage;
- intermediate value linkage.

### Reproduction

Identical dependency snapshots must reproduce equivalent results.

### Verification

- valid hashes pass;
- changed hashes fail;
- missing dependencies produce explicit diagnostics.

### Classification

Correctly distinguish:

```text
REFERENCE_FACT
INPUT_VALUE
CALCULATED_VALUE
INFERENCE
HYPOTHESIS
```

### AI boundary

Generated explanations must not modify authoritative lineage.

---

## 48. Definition of Done

AP-EK-009 is complete when:

1. provenance contract exists;
2. derivation contract exists;
3. source classifications exist;
4. input lineage works;
5. law/equation lineage works;
6. component-model lineage works;
7. constraint lineage works;
8. runtime/version identity is retained;
9. deterministic derivations are serializable;
10. result verification is defined;
11. content-integrity verification is supported where hashes exist;
12. historical knowledge versions remain traceable;
13. DS can consume lineage without owning it;
14. AI can generate explanations from lineage without becoming authoritative;
15. the first electrical vertical slice produces a complete auditable lineage.

---

## 49. Follow-On

```text
AP-EK-010  Engine / Diagram Studio Analysis API
AP-EK-011  Dynamic / Nonlinear Analysis Extension
AP-EK-012  Electrical Analysis Validation Suite
AP-EK-013  Knowledge Runtime Implementation
AP-EK-014  Engineering Explanation / Teaching Layer
```

---

## Architectural Non-Negotiables

1. Provenance and derivation are distinct.
2. Authoritative lineage is machine-readable.
3. Natural-language explanation is never the source of truth.
4. Every authoritative calculated result should be traceable to its inputs and governing knowledge.
5. Runtime/version identity is part of reproducibility.
6. Content hashes are used where appropriate to verify integrity.
7. Historical results retain historical knowledge identity.
8. Missing provenance is an explicit defect, not an invitation to guess.
9. Calculated values remain distinct from reference facts.
10. Design inputs remain distinct from authoritative reference facts.
11. Inferences and hypotheses remain explicitly non-authoritative.
12. AI may explain lineage but may not rewrite it.
13. Provenance data never becomes executable content.
14. Diagram Studio does not own engineering evidence.
15. Repository persistence stores lineage but does not redefine its semantics.
16. The architecture supports compact references and lazy expansion.
17. Equivalent dependency snapshots must yield reproducible results.
18. The complete electrical vertical slice must be auditable from AnalysisResult back to authoritative source.
