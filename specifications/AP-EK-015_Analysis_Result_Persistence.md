# AP-EK-015
# Analysis Result Persistence
## Persistence, History, Reproducibility, Invalidation, and Engineering Evidence

**Status:** Architecture Phase — Implementation Specification  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-001 through AP-EK-014  
**Primary objective:** Define how deterministic Engineering Analysis results are persisted as historical, reproducible engineering evidence without contaminating authoritative engineering data, Diagram Studio UI state, or temporary workspace state.

---

## 1. Purpose

AP-EK-015 defines persistence for:

```text
AnalysisRequest
AnalysisResult
Derivation
Provenance
ConstraintResults
Analysis diagnostics
Knowledge/runtime identity
```

The objective is to make analysis results:

```text
reproducible
traceable
versioned
historical
queryable
comparable
auditable
```

while preserving the architectural separation already established throughout OEP.

---

## 2. Fundamental Persistence Rule

Analysis results are derived engineering evidence.

They are not the authoritative engineering design itself.

Therefore:

```text
DiagramDocument
    = authoritative engineering design state

AnalysisResult
    = derived result from a specific design/version + knowledge/runtime context
```

An analysis result must never silently overwrite the source engineering object.

---

## 3. Four Existing Persistence Domains

The architecture must preserve the established separation:

```text
1. Engineering Data
   DiagramDocument

2. Analysis Evidence
   AnalysisRequest / AnalysisResult / Derivation / Provenance

3. Workspace / Tab State
   DiagramWorkspaceState / DiagramTabsStorage

4. User Preferences
   DiagramStudioSettings
```

Analysis persistence belongs to domain #2.

It must not be stored as UI state merely because DS displays it.

---

## 4. Analysis Snapshot

Every persisted analysis represents an immutable snapshot.

Conceptually:

```text
AnalysisSnapshot
  analysisId
  requestId
  documentIdentity
  documentVersion
  inputSnapshot
  knowledgeIdentity
  runtimeIdentity
  solverIdentity
  analysisMode
  numericPolicy
  result
  derivation
  provenance
  constraints
  diagnostics
  createdUtc
```

The snapshot is the reproducibility boundary.

---

## 5. Why Snapshotting Is Required

A future document may change after an analysis.

Therefore:

```text
Document v1
    ↓
Analysis A
```

must remain distinguishable from:

```text
Document v2
    ↓
Analysis B
```

Analysis A must not silently mutate when Document v2 changes.

---

## 6. Analysis Identity

Every analysis receives a stable:

```text
analysisId
```

The ID identifies one immutable analysis execution/result snapshot.

It is not equivalent to:

```text
documentId
relationshipId
objectId
```

---

## 7. Request Identity

Every analysis invocation has:

```text
requestId
```

This identifies the request that produced an analysis.

Multiple requests may produce equivalent results.

Therefore:

```text
requestId != analysisId
```

by definition.

---

## 8. Document Identity

The analysis must preserve:

```text
documentId
documentVersion
```

or the equivalent authoritative Engineering Object identity/version established by the existing document model.

If the document has no stable version identifier, the analysis persistence layer must use an explicit content/version fingerprint.

---

## 9. Input Fingerprint

A deterministic input fingerprint should be stored.

Conceptual:

```text
analysisInputHash
```

It represents the canonical analysis input snapshot.

This provides an independent way to determine whether two analyses used equivalent engineering inputs.

---

## 10. Knowledge Identity

The analysis must record:

```text
knowledgePackageId
knowledgePackageVersion
knowledgePackageHash
schemaVersion
compilerVersion
```

where available.

This is mandatory for reproducibility.

---

## 11. Runtime Identity

The analysis must record:

```text
runtimeVersion
runtimeBuild
```

and, where applicable:

```text
analysisEngineVersion
solverVersion
```

A result without runtime/solver identity is not fully reproducible.

---

## 12. Analysis Mode

Persist:

```text
analysisMode
```

Examples:

```text
DC_STEADY_STATE_LINEAR
DC_STEADY_STATE_NONLINEAR
TRANSIENT
AC_FREQUENCY_DOMAIN
SMALL_SIGNAL
```

This prevents a historical result from being misinterpreted as belonging to another solver mode.

---

## 13. Numeric Policy

Persist relevant numeric policy:

```text
precision
tolerance
rounding
convergence criteria
maximum iterations
time-step policy
```

Only applicable fields need to be stored for a given analysis mode.

---

## 14. Analysis Request Persistence

Conceptual:

```text
AnalysisRequestRecord
  requestId
  documentId
  documentVersion
  requestedMode
  requestedOutputs
  context
  numericPolicy
  knowledgeSelection
  createdUtc
```

The persisted request provides the execution intent.

---

## 15. Analysis Result Persistence

Conceptual:

```text
AnalysisResultRecord
  analysisId
  requestId
  status
  documentIdentity
  analysisIdentity
  results
  constraints
  diagnostics
  derivationRef
  provenanceRef
```

The result record references immutable supporting evidence.

---

## 16. Result Status

At minimum:

```text
COMPLETED
PARTIAL
FAILED
INVALID_INPUT
UNSUPPORTED
CANCELLED
STALE
```

A failed analysis may be persisted if it contains useful diagnostics.

---

## 17. Stale Results

An analysis becomes stale relative to a document when:

```text
documentVersion(current) != documentVersion(analysis)
```

Stale does not mean invalid.

It means:

```text
historically valid for an earlier document state
```

The system must preserve the result.

---

## 18. Result Invalidation

Results should not be physically deleted merely because they are stale.

Instead:

```text
current document
    ↓
new analysis required
```

Historical analyses remain available.

---

## 19. Reanalysis

A new document version should create a new analysis identity.

Do not mutate:

```text
Analysis A
```

into:

```text
Analysis B
```

Instead:

```text
Analysis A → Document v1
Analysis B → Document v2
```

---

## 20. Analysis Lineage

The system should support:

```text
Analysis B
  derivedFrom
Analysis A
```

where useful.

This supports:

```text
before/after comparison
design iteration
diagnostic progression
engineering review
```

Lineage must not imply that B is numerically derived from A unless that actually occurred.

---

## 21. Reproducibility

A result is reproducible when the system can reconstruct:

```text
same engineering input
same knowledge package
same runtime/solver semantics
same analysis mode
same numeric policy
```

and obtain the same deterministic result.

---

## 22. Reproducibility Record

Conceptual:

```text
ReproducibilityDescriptor
  documentHash
  knowledgePackageHash
  runtimeIdentity
  solverIdentity
  analysisMode
  numericPolicy
```

This descriptor should be sufficient to locate required historical inputs.

---

## 23. Deterministic Result Hash

A canonical result representation may receive:

```text
analysisResultHash
```

The hash should cover the canonical result and required semantic identity.

It should not depend on:

```text
UI layout
panel state
theme
tab order
selection
```

---

## 24. Result Immutability

Once persisted:

```text
AnalysisResult
```

is immutable.

Corrections are represented by a new analysis.

Historical data must remain auditable.

---

## 25. Derivation Persistence

The derivation graph must be persisted or addressably recoverable.

Conceptual:

```text
DerivationRecord
  derivationId
  analysisId
  steps[]
  graph
  version
```

Each step references:

```text
equation
law
model
input
result
```

---

## 26. Provenance Persistence

Persist the provenance required by AP-EK-009:

```text
source identity
knowledge identity
versions
content hashes
model identity
equation identity
law identity
constraint identity
```

Provenance must remain immutable.

---

## 27. Constraint Persistence

Persist constraint results including:

```text
constraintId
constraintVersion
status
severity
evaluatedValue
limit
tolerance
applicability
```

A historical constraint result must remain tied to the exact analysis that evaluated it.

---

## 28. Diagnostics Persistence

Persist meaningful diagnostics:

```text
diagnosticCode
severity
message/template reference
affected entities
evidence references
```

Do not treat arbitrary UI log text as the authoritative diagnostic record.

---

## 29. Measurement Persistence

Measurements used by analysis must be distinguishable from calculated values.

Example:

```text
Measurement:
1.15 A

Calculated:
1.20 A
```

The analysis snapshot should reference the measurement identity/value/version used.

---

## 30. Assumption Persistence

Persist assumptions that materially affected analysis.

Examples:

```text
ideal source
steady-state condition
ambient temperature
switch state
nominal component parameter
```

Each assumption should be classified explicitly.

---

## 31. Missing Information

If required information is absent:

```text
INSUFFICIENT_DATA
```

may be persisted.

The system must not persist an invented substitute as if it were input data.

---

## 32. Failed Analyses

Failed analyses may be persisted when useful.

Example:

```text
status = INVALID_INPUT

diagnostic:
No valid reference node identified.
```

This creates useful engineering history and diagnostic evidence.

---

## 33. Partial Results

A solver may produce partial results.

If persisted:

```text
status = PARTIAL
```

must be explicit.

Partial results must identify which outputs are valid and which remain unresolved.

---

## 34. Storage Model

The initial implementation may use the existing OEP Foundation persistence/repository mechanisms.

The architecture must not require a separate database solely for analysis results.

Conceptual repository boundary:

```text
AnalysisRepository
  saveRequest()
  saveResult()
  getAnalysis()
  listAnalyses()
  findByDocument()
  findByDocumentVersion()
  findByInputHash()
```

---

## 35. Repository Ownership

Analysis persistence should belong to the platform/repository layer rather than Diagram Studio UI.

DS requests persistence through an application/service boundary.

---

## 36. No UI Coupling

Persisted analysis must not contain:

```text
Flutter widget state
window dimensions
dock state
selected tab
zoom
theme
panel visibility
```

These remain UI/workspace concerns.

---

## 37. No Diagram Mutation

Running analysis must not automatically modify:

```text
DiagramDocument
nodes
relationships
wire routes
layout
```

unless an explicitly separate engineering operation is invoked.

---

## 38. Save vs Analyze

The operations remain separate:

```text
Save
  = persist engineering design

Analyze
  = calculate derived engineering evidence

Save Analysis
  = persist derived analysis evidence
```

A user may invoke them independently.

---

## 39. Automatic Analysis Persistence

The system may automatically persist analysis results if configured.

If so, it must still create a distinct analysis record.

Automatic persistence must not imply that the analysis is part of the authoritative document.

---

## 40. Document Save Interaction

When a document is saved:

```text
document version changes
```

existing analyses remain associated with their prior document versions.

The system may mark them stale relative to the new document version.

---

## 41. Save As Interaction

Save As creates a new document identity/version according to the existing document persistence contract.

Historical analysis from the source document must not silently become authoritative for the new document.

A new analysis should be required for the new identity unless an explicit immutable snapshot relationship exists.

---

## 42. Multi-Instance Studio

Two DS instances may analyze independently:

```text
Studio A → Analysis A
Studio B → Analysis B
```

Analysis identity must not depend on the current UI tab identity.

---

## 43. Caching

A deterministic analysis cache may use:

```text
documentHash
knowledgePackageHash
runtimeVersion
solverVersion
analysisMode
numericPolicy
requestedOutputs
```

A cache hit may produce a new request referencing an existing immutable result, depending on API semantics.

---

## 44. Cache vs Historical Record

Do not confuse:

```text
cache
```

with:

```text
historical evidence
```

Cache entries may be discarded.

Historical analysis records require explicit persistence semantics.

---

## 45. Analysis Comparison

The persistence layer should support comparison between analyses.

Example:

```text
Analysis A
Document v1
I = 1.20 A

Analysis B
Document v2
I = 0.95 A
```

Comparison may identify:

```text
input changes
topology changes
model changes
result changes
constraint changes
```

Comparison belongs to a future analysis/comparison service, not the persistence repository itself.

---

## 46. Querying

Initial query capabilities:

```text
by analysisId
by documentId
by documentVersion
by knowledgePackageId
by status
by creation time
by result hash
```

Future:

```text
by component
by constraint
by diagnostic
by equation
by provenance source
```

---

## 47. Historical Timeline

A document may expose:

```text
Analysis History
```

showing:

```text
timestamp
document version
analysis status
knowledge version
solver version
important result summary
constraint summary
```

This is a presentation concern over persisted evidence.

---

## 48. Engineering Review

A reviewer should be able to inspect:

```text
what was analyzed
when
against which document
using which knowledge
using which solver
what results were produced
which constraints passed/failed
how the result was derived
```

This is a major purpose of analysis persistence.

---

## 49. Auditability

Historical analysis records should be tamper-evident where required.

At minimum:

```text
canonical hashes
immutable identity
source/version lineage
```

may establish integrity.

Signed analysis artifacts may be added later.

---

## 50. Export

Future analysis export may support:

```text
JSON
OEP package
engineering report
PDF
structured evidence bundle
```

Export is a representation of persisted analysis, not a replacement for repository persistence.

---

## 51. Import

Imported historical analyses must retain:

```text
original analysis identity
original provenance
original knowledge identity
original runtime identity
```

if the source format supports them.

Missing provenance must be represented as missing.

---

## 52. Cross-Version Runtime

A historical analysis may depend on an older runtime.

The system should not silently recompute it under a newer runtime and label it equivalent.

Instead distinguish:

```text
historical result
recomputed result
```

---

## 53. Recompute

Conceptual:

```text
recompute(analysisId, runtimeSelection)
```

produces:

```text
new analysisId
```

and records the relationship:

```text
recomputedFrom = originalAnalysisId
```

This preserves historical evidence.

---

## 54. Semantic Equivalence

Two analyses may produce identical numbers while using different:

```text
knowledge versions
solver versions
assumptions
models
```

They must not automatically be treated as the same analysis.

Numerical equality is not identity.

---

## 55. Result Fingerprints

A result fingerprint may support fast comparison:

```text
same input
same knowledge
same runtime
same solver
same output
```

This can identify deterministic equivalence.

The fingerprint is derived data.

---

## 56. Persistence Failure

If engineering analysis succeeds but persistence fails:

```text
analysis success
persistence failure
```

must remain distinguishable.

The system must not report:

```text
analysis failed
```

merely because persistence failed.

---

## 57. Transaction Boundary

Where practical:

```text
AnalysisResult
Derivation
Provenance
ConstraintResults
Diagnostics
```

should be persisted as one logical evidence transaction.

A partial persistence state must either be recoverable or explicitly marked incomplete.

---

## 58. Crash Recovery

After a crash, the system must not expose a partially written analysis as a completed immutable result.

Use:

```text
staging
commit
finalization
```

or an equivalent atomic repository mechanism.

---

## 59. Retention

Retention policy is a repository/business concern.

The architecture should support:

```text
retain indefinitely
retain N versions
archive
export then remove
```

without changing analysis semantics.

---

## 60. Privacy / Sensitive Inputs

Some analysis inputs may contain sensitive engineering information.

Persistence must respect existing OEP repository access controls.

Analysis evidence should inherit appropriate ownership/access semantics from its engineering context where applicable.

---

## 61. Ownership

Analysis should preserve ownership/reference to the originating engineering object/document.

A derived result should not accidentally become globally public merely because the analysis runtime can calculate it.

---

## 62. Provenance Graph Storage

The system may store provenance as normalized records or as a content-addressed graph.

The representation is implementation-specific.

The semantic requirement is:

```text
result
→ derivation
→ equation/law/model
→ knowledge package
→ authoritative source
```

must remain reconstructable.

---

## 63. Result Navigation

A persisted result should support navigation back to:

```text
document
component
terminal
relationship
equation
law
constraint
source
```

where identities exist.

---

## 64. Explanation Integration

AP-EK-014 may consume persisted analysis directly.

Example:

```text
AnalysisResult
   ↓
ExplanationService
   ↓
EngineeringExplanation
```

The explanation stores the analysis identity it explains.

---

## 65. Teaching Integration

A teaching artifact may reference:

```text
analysisId
```

as a worked example.

The underlying analysis remains immutable.

---

## 66. Exchange Integration

Engineering Exchange may eventually distribute:

```text
analysis evidence bundles
worked examples
validated teaching examples
```

Exchange owns distribution/licensing.

Analysis persistence owns historical evidence.

---

## 67. Security

Persistence implementation must defend against:

```text
tampered result records
hash mismatch
broken references
malformed serialized results
unauthorized access
partial commits
cross-document identity confusion
```

---

## 68. Testing

### Identity

- unique analysis ID;
- request/result separation;
- document version association.

### Immutability

- persisted result cannot be mutated;
- reanalysis creates a new identity.

### Reproducibility

- same snapshot reproduces same deterministic result.

### Provenance

- all required lineage resolves.

### Versioning

- old knowledge/runtime remains identifiable.

### Staleness

- document change marks old result stale without deleting it.

### Persistence failure

- analysis and persistence failure states remain distinct.

### Crash recovery

- incomplete writes are never exposed as completed results.

### DS boundary

- UI state is absent from analysis persistence.

---

## 69. First Acceptance Scenario

Given:

```text
Document v1
12 V source
10 Ω resistor
```

Run analysis.

Persist:

```text
Analysis A
I = 1.2 A
P = 14.4 W
```

Modify document to:

```text
20 Ω resistor
```

Save as:

```text
Document v2
```

Run analysis again.

Persist:

```text
Analysis B
I = 0.6 A
P = 7.2 W
```

Expected:

```text
Analysis A remains unchanged.
Analysis A remains associated with Document v1.
Analysis B is associated with Document v2.
```

---

## 70. First Reproducibility Acceptance

For Analysis A, reconstruct:

```text
document input snapshot
knowledge package
runtime
solver
numeric policy
```

Re-run.

Expected:

```text
same deterministic result
same semantic derivation
same relevant provenance
```

---

## 71. First Explanation Acceptance

Persist Analysis A.

Request:

```text
Explain why current = 1.2 A.
```

Explanation must resolve:

```text
Analysis A
Ohm's Law
I = V/R
12 V
10 Ω
1.2 A
```

No calculation may be independently invented by the explanation layer.

---

## 72. Implementation Sequence

```text
1. define analysis persistence domain types
2. define AnalysisRepository interface
3. define canonical serialization
4. implement identity/version records
5. implement analysis input snapshot
6. implement result persistence
7. implement derivation persistence
8. implement provenance persistence
9. implement constraint/diagnostic persistence
10. implement atomic commit
11. implement historical queries
12. implement stale detection
13. implement reproducibility descriptor
14. implement deterministic result hashing
15. integrate Analysis API
16. integrate Explanation Layer
17. add AP-EK-012 validation
```

---

## 73. Recommended Repository Boundary

Conceptually:

```text
platform/
  oep_engine/
    analysis/
      persistence/
        analysis_repository
        analysis_records
        analysis_serialization
        analysis_identity
        analysis_history
```

Exact placement must follow the existing Engine taxonomy after repository inspection.

No competing persistence subsystem should be created.

---

## 74. Definition of Done

AP-EK-015 is complete when:

1. AnalysisRequest has a persistence contract;
2. AnalysisResult has an immutable persistence contract;
3. analysis identity is separate from document identity;
4. document version is preserved;
5. input fingerprint is preserved;
6. knowledge identity is preserved;
7. runtime/solver identity is preserved;
8. numeric policy is preserved;
9. derivation is persisted or recoverable;
10. provenance is persisted or recoverable;
11. constraint results are persisted;
12. diagnostics are persisted;
13. stale historical results remain accessible;
14. reanalysis creates a new identity;
15. reproducibility can be verified;
16. deterministic result hashing is supported;
17. Save and Analyze remain separate operations;
18. UI/workspace state does not enter analysis persistence;
19. partial persistence cannot masquerade as completed analysis;
20. AP-EK-012 persistence/reproducibility tests pass.

---

## 75. Architectural Non-Negotiables

1. AnalysisResult is derived engineering evidence.
2. DiagramDocument remains authoritative engineering design state.
3. Analysis cannot silently mutate the document.
4. Analysis identity is distinct from document identity.
5. Historical results are immutable.
6. Stale does not mean invalid.
7. Reanalysis creates a new analysis identity.
8. Knowledge version is part of reproducibility.
9. Runtime/solver identity is part of reproducibility.
10. Numeric policy is part of reproducibility.
11. Provenance and derivation remain attached to the result.
12. Measurements and calculated values remain distinct.
13. Assumptions remain explicit.
14. Unknown information remains unknown.
15. Cache is not historical evidence.
16. Save and Analyze remain separate operations.
17. UI state never becomes engineering analysis state.
18. Persistence failure must remain distinct from analysis failure.
19. Historical evidence must never be silently recomputed under a newer runtime.
20. The persistence system exists to make engineering reasoning historically inspectable and reproducible, not merely to remember the last displayed number.
