# AP-EK-010
# Engine / Diagram Studio Analysis API
## Deterministic Engineering Analysis Consumption Contract

**Status:** Architecture Phase — Proposed  
**Parent:** AP-ENGINEERING-KNOWLEDGE-001  
**Predecessors:** AP-EK-002 through AP-EK-009  
**Primary consumers:** OEP Engine / Diagram Studio  
**Boundary:** Engine owns analysis; Studio consumes and presents results

---

## 1. Purpose

Define the API boundary between the deterministic Engineering Analysis Runtime and Diagram Studio.

The contract ensures that:

```text
Diagram Studio
    requests analysis

OEP Engine
    performs analysis

Diagram Studio
    presents immutable results
```

Diagram Studio must never become part of the authoritative engineering calculation path.

---

## 2. Architectural Principle

The boundary is intentionally one-directional for engineering truth:

```text
DS Engineering State
        |
        v
Analysis Request
        |
        v
OEP Engine
        |
        v
AnalysisResult
        |
        v
Diagram Studio
```

DS may initiate another analysis request after engineering state changes.

DS does not directly manipulate:

```text
laws
equations
unit definitions
component models
constraints
solver matrices
derivation records
```

---

## 3. Ownership

### OEP Engine owns

```text
analysis orchestration
topology extraction
component/model resolution
law selection
equation execution
constraint evaluation
provenance
derivation
diagnostics
result identity
```

### Diagram Studio owns

```text
analysis invocation UI
analysis-result presentation
visual overlays
selection/highlighting
diagnostic navigation
provenance navigation UI
user interaction
workspace state
```

---

## 4. Analysis Request

Conceptual:

```text
AnalysisRequest
  requestId
  documentId
  documentVersion
  analysisMode
  requestedOutputs
  analysisContext
  numericPolicy
  knowledgeRuntimeVersion
```

The request must identify the engineering state being analyzed.

---

## 5. Document Identity

The request must reference authoritative engineering identity.

At minimum:

```text
documentId
documentVersion
```

The API must not use:

```text
file path
tab index
widget key
screen position
WebView instance
```

as engineering identity.

---

## 6. Analysis Modes

Initial:

```text
DC_STEADY_STATE_LINEAR
```

Future:

```text
DC_STEADY_STATE_NONLINEAR
AC_FREQUENCY_DOMAIN
TRANSIENT
THERMAL
MULTI_DOMAIN
```

Unsupported modes return an explicit status.

---

## 7. Requested Outputs

The caller may request subsets of available analysis outputs.

Examples:

```text
NODE_VOLTAGES
BRANCH_CURRENTS
COMPONENT_VOLTAGES
COMPONENT_CURRENTS
COMPONENT_POWER
CONSTRAINT_RESULTS
DERIVATION
PROVENANCE
DIAGNOSTICS
```

The engine may return additional required information, but must not silently omit requested outputs without a structured status.

---

## 8. Analysis Context

Conceptual:

```text
AnalysisContext
  referenceNode
  operatingState
  knownInputs
  requestedScope
  tolerancePolicy
  additionalParameters
```

Context must be explicit and serializable.

---

## 9. Request Determinism

For identical:

```text
documentVersion
knowledgeRuntimeVersion
analysisMode
analysisContext
numericPolicy
```

the analysis request must produce an equivalent result.

---

## 10. Request Lifecycle

Initial lifecycle:

```text
CREATED
QUEUED
RUNNING
COMPLETED
FAILED
CANCELLED
```

For synchronous execution, the implementation may collapse intermediate states internally.

The public contract should nevertheless support asynchronous execution.

---

## 11. Cancellation

Long-running analysis should support cancellation.

Cancellation must be cooperative and deterministic from the API perspective.

A cancelled request must not produce a result that is presented as a valid completed engineering analysis.

---

## 12. Analysis Result

Conceptual:

```text
AnalysisResult
  analysisId
  requestId
  status
  documentIdentity
  runtimeIdentity
  topology
  nodeResults
  branchResults
  componentResults
  equationResults
  constraintResults
  diagnostics
  derivation
  provenance
```

The result is immutable.

---

## 13. Result Identity

Every completed analysis has:

```text
analysisId
```

This identity must remain stable for the lifetime of the stored result.

It must not be tied to a DS widget or tab.

---

## 14. Result Status

At minimum:

```text
SUCCESS
SUCCESS_WITH_WARNINGS
INCOMPLETE
FAILED
CANCELLED
UNSUPPORTED
```

A result with warnings remains a valid analysis result when its engineering calculations completed successfully.

---

## 15. Engineering State Version

The result must identify exactly which engineering state was analyzed.

Conceptually:

```text
documentId
documentVersion
graphVersion
```

where available.

This prevents DS from displaying a result from an earlier circuit state as if it belonged to the current state.

---

## 16. Stale Result Detection

DS should compare:

```text
currentDocumentVersion
```

against:

```text
analysis.documentVersion
```

If they differ:

```text
analysis result = STALE
```

A stale result may remain visible for comparison/history but must not be presented as current truth.

---

## 17. Result Immutability

An AnalysisResult must not be edited in place.

If engineering state changes:

```text
new document version
        |
        v
new analysis request
        |
        v
new AnalysisResult
```

This preserves historical reproducibility.

---

## 18. Analysis Cache

The engine may cache results by a deterministic request/dependency identity.

Conceptual cache identity:

```text
documentVersion
knowledgeRuntimeVersion
analysisMode
analysisContext
numericPolicy
requestedOutputs
```

Cached and freshly computed results must be observationally equivalent.

---

## 19. Analysis Service API

Conceptual:

```text
AnalysisService
  analyze(request)
  getAnalysis(analysisId)
  cancel(requestId)
  verify(analysisId)
```

Optional:

```text
subscribe(requestId)
listAnalyses(documentId)
```

The actual transport may be:

```text
in-process API
local service
IPC
HTTP
```

The engineering contract remains transport-independent.

---

## 20. Transport Independence

The API must not embed Flutter, Dart, WebView, or platform-specific types.

Use domain-neutral serialized contracts.

This permits the same analysis runtime to serve:

```text
Windows
Linux
macOS
Android
iOS
CLI
future services
```

---

## 21. DS Invocation

Conceptually:

```text
User selects Analyze
       |
       v
DS captures current authoritative document version
       |
       v
DS creates AnalysisRequest
       |
       v
Engine analyzes
       |
       v
DS receives AnalysisResult
       |
       v
DS updates presentation state
```

DS must not freeze or mutate the engineering graph merely to perform analysis.

---

## 22. Result Presentation

DS may render:

```text
node voltage labels
branch current labels
component power
constraint warnings
violations
analysis status
```

These are projections of AnalysisResult.

The displayed values are not separately calculated by DS.

---

## 23. Visual Overlay Model

Analysis visualization should be treated as presentation state.

Conceptual:

```text
AnalysisOverlayState
  analysisId
  selectedResults
  visibleLayers
  highlightedObjects
```

It is not part of the engineering document.

Closing/reopening DS must not modify engineering analysis truth.

---

## 24. Selection

Selecting an analysis result may identify:

```text
componentObjectId
nodeId
branchId
equationId
constraintId
diagnosticId
```

DS uses these identifiers to navigate/highlight relevant objects.

The Engine does not control DS selection.

---

## 25. Highlighting

Example:

```text
Constraint violation
  target = R1
```

DS may highlight:

```text
R1
```

The highlight is transient UI state.

It must not create or modify an engineering relationship.

---

## 26. Diagnostic Navigation

A diagnostic should expose machine-readable targets.

Example:

```text
diagnostic:
  code = POWER_LIMIT_EXCEEDED
  targetObjectId = R1
```

DS can navigate to the component and display the diagnostic.

---

## 27. Provenance Navigation

When the user requests:

```text
Why is this value 1.2 A?
```

DS should navigate through:

```text
AnalysisResult
    ↓
Derivation
    ↓
Equation
    ↓
Law
    ↓
Component Model
    ↓
Input
    ↓
Source
```

The navigation is presentation behavior.

The underlying provenance remains Engine-owned.

---

## 28. Derivation Presentation

DS may present a derivation such as:

```text
I = V / R
I = 12 V / 10 Ω
I = 1.2 A
```

The displayed derivation must be generated from structured derivation data.

DS must not reconstruct calculations from displayed text.

---

## 29. Explanation Boundary

An optional explanation layer may consume:

```text
AnalysisResult
Derivation
Provenance
Diagnostics
```

to generate human-readable explanations.

The explanation is not authoritative.

The underlying structured result remains authoritative.

---

## 30. AI Boundary

AI may be invoked by DS or another presentation layer for:

```text
explanation
education
summarization
diagnostic assistance
```

AI must not:

```text
modify AnalysisResult
modify equation definitions
modify constraints
override diagnostics
change provenance
```

If AI proposes a corrective action, it remains a recommendation until independently validated.

---

## 31. Result Verification

DS should be able to request result verification.

Example:

```text
verify(analysisId)
```

The Engine checks:

```text
runtime availability
knowledge package identity
hashes
derivation consistency
source references
```

Verification failure should be visible as a structured status.

---

## 32. Analysis History

The architecture should permit multiple historical analyses for one document:

```text
Document v1
  Analysis A

Document v2
  Analysis B

Document v3
  Analysis C
```

DS may expose analysis history.

Historical results must remain immutable.

---

## 33. Multi-Instance DS

Multiple Diagram Studio instances may analyze independently.

Analysis identity must therefore be independent of:

```text
WorkspaceTab.id
DiagramTabsController
WebSurfaceTabsController
Flutter widget instance
```

A result belongs to an engineering document/analysis request, not a visual tab.

---

## 34. Workspace Integration

The Workspace may provide the active Diagram Studio surface.

It must not become an engineering-analysis authority.

Conceptually:

```text
Workspace
   |
   +-- Diagram Surface
          |
          +-- Analysis Request
                 |
                 v
              Engine
```

---

## 35. Save Boundary

Analysis execution must not implicitly save engineering changes.

Likewise:

```text
Save
```

must not automatically imply:

```text
Analyze
```

unless explicitly configured as a future user preference.

This prevents persistence and computation from becoming coupled.

---

## 36. Dirty State

Analysis visualization changes should not mark the engineering document dirty.

Examples:

```text
show current overlays
highlight violation
open derivation panel
display provenance
```

are UI state.

Changing engineering inputs/components must mark the document dirty according to existing document lifecycle rules.

---

## 37. Open/Reopen

When a document is reopened:

```text
engineering state
```

is restored independently of:

```text
analysis presentation state
```

Historical analysis results may be reloaded by identity.

The system must not silently claim that an old result represents a newly loaded document version.

---

## 38. Save As

Save As creates a new engineering document identity according to existing OEP document/repository semantics.

Existing analysis results remain associated with the original document identity/version.

A Save As result must not accidentally transfer analysis authority to the new document.

---

## 39. Export

Analysis results may eventually be exported to:

```text
PDF
report
JSON
engineering package
```

Exports are derived representations.

They do not become the authoritative analysis source.

---

## 40. API Errors

Structured API errors should include:

```text
INVALID_REQUEST
DOCUMENT_NOT_FOUND
DOCUMENT_VERSION_NOT_FOUND
RUNTIME_NOT_AVAILABLE
KNOWLEDGE_VERSION_NOT_FOUND
UNSUPPORTED_ANALYSIS_MODE
INVALID_CONTEXT
ANALYSIS_FAILED
ANALYSIS_CANCELLED
RESULT_NOT_FOUND
RESULT_STALE
VERIFICATION_FAILED
```

---

## 41. Security

The API must accept only validated domain data.

It must not execute arbitrary code supplied by DS.

DS-provided strings must not become:

```text
executable equations
runtime scripts
model definitions
constraint definitions
```

---

## 42. Performance

For interactive DS use, the API should support:

```text
fast repeated analysis
incremental recalculation
result caching
selective outputs
asynchronous execution
```

Optimization must never change authoritative results.

---

## 43. Incremental Analysis

Future implementations may identify unchanged portions of the graph and reuse deterministic intermediate results.

Any incremental result must be equivalent to a clean full analysis.

This is an optimization, not a separate calculation semantics.

---

## 44. Result Scoping

Analysis may target:

```text
whole document
selected circuit
selected component neighborhood
specific node
specific branch
```

The scope must be explicit in the request.

A partial analysis must not be presented as a complete circuit analysis.

---

## 45. Requested Scope

Conceptual:

```text
AnalysisScope
  type
  objectIds[]
  nodeIds[]
  branchIds[]
```

Only relevant fields should be populated.

The Engine determines whether the requested scope is sufficient for the selected analysis mode.

---

## 46. Current Vertical Slice

DS sends:

```text
documentId
documentVersion
analysisMode = DC_STEADY_STATE_LINEAR
```

for:

```text
12 V source
10 Ω resistor
reference
```

Engine returns:

```text
V_R1 = 12 V
I_R1 = 1.2 A
P_R1 = 14.4 W
```

plus:

```text
Ohm's Law
Power equation
derivation
provenance
constraint results
```

DS renders those values.

---

## 47. Error Vertical Slice

For:

```text
10 Ω resistor
no valid reference node
```

Engine returns:

```text
INCOMPLETE / FAILED
NO_REFERENCE_NODE
```

DS displays the diagnostic and identifies the affected topology.

DS does not invent a reference.

---

## 48. Stale Result Vertical Slice

Initial state:

```text
R1 = 10 Ω
```

Analysis:

```text
I = 1.2 A
```

User changes:

```text
R1 = 20 Ω
```

Document becomes:

```text
version + 1
```

Existing result is:

```text
STALE
```

New analysis:

```text
I = 0.6 A
```

Both historical results may remain available.

---

## 49. API Contract Testing

Contract tests must verify:

### Request

- valid request accepted;
- missing identity rejected;
- unsupported mode rejected.

### Result

- immutable structure;
- correct document identity;
- correct runtime identity;
- requested outputs present.

### Staleness

- document change invalidates current-result status.

### Provenance

- derivation and provenance remain reachable.

### DS boundary

- DS cannot directly execute equations or modify runtime knowledge through the API.

---

## 50. Definition of Done

AP-EK-010 is complete when:

1. AnalysisRequest contract exists;
2. AnalysisResult contract exists;
3. analysis lifecycle is defined;
4. document/version identity is enforced;
5. analysis modes are defined;
6. request scope is defined;
7. result staleness is defined;
8. result immutability is defined;
9. Engine-owned analysis boundary is enforced;
10. DS presentation boundary is enforced;
11. structured diagnostics are exposed;
12. provenance/derivation are consumable;
13. cancellation is defined;
14. verification is defined;
15. historical analysis is supported;
16. Save/Save As boundaries are defined;
17. multi-instance DS behavior is independent of analysis identity;
18. first electrical vertical slice can be displayed by DS without DS performing calculations.

---

## 51. Follow-On

```text
AP-EK-011  Dynamic / Nonlinear Analysis Extension
AP-EK-012  Electrical Analysis Validation Suite
AP-EK-013  Knowledge Runtime Implementation
AP-EK-014  Engineering Explanation / Teaching Layer
AP-EK-015  Analysis Result Persistence
```

---

## Architectural Non-Negotiables

1. Engineering analysis belongs to OEP Engine/runtime.
2. Diagram Studio is a consumer/presenter of analysis results.
3. Analysis requests reference authoritative document identity/version.
4. Analysis results are immutable.
5. Stale results are explicitly detectable.
6. DS never implements authoritative engineering calculations.
7. DS never owns laws, equations, units, models, constraints, or provenance.
8. Analysis identity is independent of workspace/tab/widget identity.
9. UI overlays are not engineering state.
10. Analysis does not implicitly save.
11. Save does not implicitly analyze.
12. Historical analysis results remain immutable and traceable.
13. AI may explain results but cannot modify authoritative results or knowledge.
14. API contracts are transport-independent.
15. Unsupported analysis must fail explicitly rather than approximate silently.
16. Partial analysis must be explicitly scoped.
17. Incremental analysis must be equivalent to clean full analysis.
18. Provenance and derivation remain Engine-owned evidence.
19. The API must remain usable by non-Flutter clients.
20. The first electrical vertical slice must cross the complete Engine → DS boundary without duplicating engineering logic in Studio.
