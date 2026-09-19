# AP-INGEST-002 — DERIVED ARTIFACTS AND PROVENANCE

**Repository:** `davidmhuitt86/open_engineering_platform`  
**Architecture Domain:** Universal Ingestion Framework  
**Predecessor:** AP-INGEST-001  
**Implementation:** WP-INGEST-002  
**Implementation Commit:** `22d54e943a563c65167c6f28d498bc795c29ca98`  
**Status:** Architecture Reconciliation Specification — FROZEN  
**Acceptance Dataset:** TRX300 Factory Wiring Diagram

---

## 1. Purpose

AP-INGEST-002 defines the first-class Derived Artifact and provenance architecture for the Universal Ingestion Framework (UIF).

The phase establishes that processing products generated from an immutable Reference Vault Object are themselves explicitly represented as engineering evidence products with traceable lineage.

The architecture preserves the distinction between:

```text
source evidence
processing products
engineering findings
knowledge candidates
accepted engineering knowledge
```

This phase does not make Derived Artifacts authoritative over the original Vault Object.

---

## 2. Architectural Position

The frozen ingestion architecture is:

```text
Reference Vault
      ↓
   Vault Object
      ↓
  Ingestion Run
      ↓
 Processing Stages
      ↓
 Derived Artifacts
      ↓
 Findings / Candidates
      ↓
 Knowledge Studio
      ↓
 Human Review
      ↓
 Engineering Repository
```

The Reference Vault remains the system of record for source engineering evidence.

UIF consumes that evidence and produces processing results.

---

## 3. Derived Artifact Definition

A `DerivedArtifact` is a first-class representation of an artifact or processing product generated during UIF execution.

Conceptually:

```text
DerivedArtifact
    derivedArtifactId
    runId
    vaultObjectId
    stage
    artifactType
    contentHash
    createdAt
    processorId
    processorVersion
    provenance
```

A Derived Artifact is downstream of the source Vault Object.

It does not replace the source artifact.

---

## 4. Source Evidence vs Derived Evidence

The architecture distinguishes:

### Source Evidence

```text
Reference Vault Object
```

The authoritative engineering evidence supplied to UIF.

### Derived Evidence

Examples include:

```text
page image
OCR page
OCR text
structural representation
entity extraction result
candidate representation
relationship extraction result
```

The derived product retains lineage to the source.

---

## 5. Provenance Chain

The minimum provenance chain is:

```text
Vault Object
    ↓
Acquisition Record
    ↓
Ingestion Run
    ↓
Processing Stage
    ↓
Derived Artifact
    ↓
Evidence Location
```

This chain must remain reconstructable.

A processing product without source lineage is not an acceptable UIF artifact.

---

## 6. Ingestion Provenance

`IngestionProvenance` carries the processing lineage needed by the current implementation.

The architecture includes:

```text
vaultObjectId
acquisitionRecordIds
ingestionRunId
stage
processorId
processorVersion
parserId
parserVersion
pipelineVersion
page
sourceFingerprint
```

Evidence coordinates and locations remain represented by the existing evidence/entity structures where applicable.

AP-INGEST-002 does not duplicate bounding boxes, character offsets, or other evidence-location structures into the provenance object.

---

## 7. Processing Identity

An `IngestionRun` identifies one processing attempt against one immutable Vault Object.

Processing identity incorporates:

```text
Vault Object identity
+
source content/version
+
pipeline version
+
parser identity/version
+
processor identity/version
+
processing configuration
```

The ingestion run is therefore distinct from:

```text
Vault Object identity
Acquisition Record identity
Derived Artifact identity
Knowledge Candidate identity
```

---

## 8. Derived Artifact Identity

The implementation uses a deterministic Derived Artifact identifier based on:

```text
runId
+
stage
+
processorId
+
processorVersion
+
contentHash
+
page where page-scoped
```

This permits deterministic artifact identity within an equivalent processing run.

Different runs remain historically distinguishable.

The artifact identifier must not be interpreted as the Vault Object identifier.

---

## 9. Content Hash Semantics

Content hashes use SHA-256 in the current implementation.

Two different concepts must remain distinct:

```text
Vault Object contentHash
    = integrity/identity of source evidence

DerivedArtifact contentHash
    = integrity/identity of a processing product
```

Metadata-only processing products may have hash semantics appropriate to their serialized representation rather than raw source bytes.

The implementation explicitly documents this distinction.

---

## 10. Processing Stages

The UIF stage vocabulary established by AP-INGEST-001 includes:

```text
IDENTIFY
PARSER_SELECTION
METADATA_EXTRACTION
CONTENT_EXTRACTION
STRUCTURAL_ANALYSIS
OCR
ENTITY_EXTRACTION
RELATIONSHIP_EXTRACTION
CHUNK_GENERATION
EMBEDDING_GENERATION
CANDIDATE_GENERATION
```

The first implementation does not require every stage for every artifact.

Stage execution is capability-driven.

---

## 11. First-Slice Artifact Production

The first implementation produces Derived Artifacts for the applicable processing stages:

```text
CONTENT_EXTRACTION
STRUCTURAL_ANALYSIS
OCR
ENTITY_EXTRACTION
CANDIDATE_GENERATION
RELATIONSHIP_EXTRACTION
```

The following stages intentionally do not create a Derived Artifact in the first slice:

```text
IDENTIFY
PARSER_SELECTION
METADATA_EXTRACTION
```

These stages may provide processing state or diagnostics without producing a separate artifact.

---

## 12. Stage Linkage

Each produced Derived Artifact must be linked back to its originating `StageResult`.

The relationship is:

```text
IngestionRun
    ↓
StageResult
    ↓
DerivedArtifact
```

`StageResult.derivedArtifactIds` provides the stage-level linkage.

This prevents Derived Artifacts from becoming detached processing records.

---

## 13. IngestionResult

The UIF `IngestionResult` contains:

```text
IngestionRun
normalized structural data
SourceMaterial
DerivedArtifacts
OCR results
Engineering Entities
evidence
Knowledge Candidates
Relationship Candidates
candidate provenance
```

Derived Artifacts are therefore part of the processing result and can be consumed by downstream curation workflows.

---

## 14. Existing OCR Reuse

UIF does not create a second OCR subsystem.

The existing:

```text
OcrPipelineService.processSource
```

remains the OCR execution mechanism.

UIF orchestrates that service.

The OCR outputs are represented in the ingestion result and, for successful pages, as Derived Artifacts.

This preserves one OCR implementation.

---

## 15. Existing Entity Extraction Reuse

UIF does not create a parallel entity-extraction subsystem.

The existing:

```text
EngineeringEntityExtractionService
```

remains the deterministic entity extraction mechanism.

Engineering Entities remain findings.

They are not automatically Engineering Objects.

---

## 16. Candidate Generation

Candidate generation remains downstream of extraction.

A generated Knowledge Candidate:

```text
status = pending
```

until human review.

The candidate retains evidence/provenance linking it back through the ingestion result to the source Vault Object.

UIF does not approve candidates.

---

## 17. Relationship Extraction

The first implementation represents relationship extraction using the existing relationship-candidate model.

The current TRX300 first slice uses a same-page proximity heuristic in which consecutive candidates on the same page may receive:

```text
RelationshipType.references
```

This is explicitly a first-slice representation.

It is not equivalent to recovered electrical topology.

It must not be treated as authoritative wiring knowledge.

---

## 18. Logical Stage Ordering vs Implementation Dependency

The logical architecture places:

```text
RELATIONSHIP_EXTRACTION
```

before final candidate consumption conceptually.

The current implementation generates candidates before relationships because the existing `RelationshipCandidate` model requires Knowledge Candidate IDs.

Therefore:

```text
logical processing concept
    ≠
current object-construction dependency
```

This is an implementation dependency, not a change to the conceptual UIF architecture.

Future implementation may separate relationship extraction from candidate identifier assignment.

---

## 19. Partial Processing

UIF preserves successful intermediate products when later processing fails.

Example:

```text
Page 1 → success
Page 2 → success
Page 3 → failure
Page 4 → success
Page 5 → success
```

The run may become:

```text
PARTIAL
```

while preserving successful artifacts.

A page-level failure must not unnecessarily destroy successful processing products.

---

## 20. Failure Semantics

The architecture distinguishes:

```text
stage failure
page-level failure
processing-run failure
```

An engine-wide failure may result in a failed stage and a partial or failed overall run depending on what earlier stages successfully completed.

Successful intermediate artifacts remain available in the result.

---

## 21. Deterministic Reprocessing

Where processing is deterministic, equivalent processing inputs should produce equivalent artifact content and processing results.

The implementation tests deterministic behavior while excluding values that are expected to vary, such as:

```text
runtime IDs where appropriate
timestamps
```

The source artifact itself remains unchanged.

---

## 22. Historical Separation

Different processing definitions must not overwrite prior processing history.

Changes to:

```text
pipeline version
parser version
processor version
processing configuration
```

produce a distinct processing history.

The architecture therefore supports historical comparison of processing results.

---

## 23. No Vault Mutation

UIF-derived artifact production does not modify the source Vault Object.

The direction remains:

```text
Reference Vault
       ↓
      read
       ↓
      UIF
       ↓
Derived Artifact
```

There is no:

```text
UIF → update Vault
UIF → delete Vault
UIF → replace Vault artifact
```

path.

---

## 24. Persistence Boundary

AP-INGEST-002 does not authorize a new permanent Derived Artifact database.

The current implementation keeps Derived Artifacts in the transient `IngestionResult`.

This is intentional.

The durable ownership model remains:

```text
Reference Vault
    = durable source evidence

IngestionResult
    = current processing result

KnowledgeSessionRecord
    = Studio curation workspace

Engineering Repository
    = accepted engineering knowledge
```

If durable Derived Artifact storage becomes necessary, it requires a separate architecture decision/work package.

---

## 25. Knowledge Session Boundary

The UIF result is bridged into the existing `KnowledgeSessionRecord`.

The bridge must preserve existing review state.

UIF does not replace the Knowledge Studio session model.

The curation boundary remains:

```text
UIF
 ↓
IngestionResult
 ↓
KnowledgeSessionRecord
 ↓
Human Review
```

---

## 26. Repository Boundary

Derived Artifact generation must not invoke:

```text
CommitTransactionService
CommitPlanService
FoundationBridge
Engineering Repository write APIs
```

The repository write boundary remains downstream of human review.

Correct:

```text
UIF
 ↓
Candidate
 ↓
Knowledge Studio
 ↓
Review
 ↓
CommitTransactionService
 ↓
Engineering Repository
```

---

## 27. No Parallel Processing Systems

This phase explicitly prohibits creation of parallel:

```text
OCR engine
entity extractor
candidate generator
commit mechanism
electrical solver
Vault
```

The existing services remain the canonical implementations where already established.

---

## 28. TRX300 Acceptance

The TRX300 acceptance path is:

```text
TRX300 Source PDF
       ↓
VaultObjectInput
       ↓
UIF
       ↓
IngestionRun
       ↓
Processing Stages
       ↓
DerivedArtifacts
       ↓
OCR / Entities
       ↓
Knowledge Candidates
       ↓
Knowledge Studio
```

The source PDF and ground-truth dataset remain unchanged.

---

## 29. Electrical Validation Boundary

Derived Artifact production does not create an independent electrical scoring engine.

The existing live TRX300 electrical solver remains the sole behavioral authority for electrical validation.

UIF extracts evidence and candidates.

It does not decide electrical truth.

---

## 30. Acceptance Tests

WP-INGEST-002 established tests covering:

```text
TEST-DA-001 through TEST-DA-012
```

including:

- Derived Artifact creation.
- Stage linkage.
- Run linkage.
- Vault Object linkage.
- Processor identity/version.
- Provenance.
- Content hashing.
- Source immutability.
- Partial processing preservation.
- Deterministic reprocessing.
- Historical separation.
- Real OCR integration path where the environment permits it.

The original WP-INGEST-001 ingestion tests remain unchanged.

---

## 31. Environment Limitation

The real OCR integration test may be unavailable when Tesseract is not installed in the test environment.

That environmental limitation does not authorize a second OCR implementation.

The production architecture remains dependent on the existing OCR service.

---

## 32. Frozen Implementation Result

WP-INGEST-002 implemented:

```text
DerivedArtifactFactory
```

and integrated artifact production into:

```text
IngestionOrchestrator
```

The existing `DerivedArtifact` and `IngestionProvenance` models remained intact.

No database or persistence schema was introduced.

The implementation produced the expected Derived Artifacts and connected them to the corresponding stage results.

---

## 33. Acceptance Criteria

AP-INGEST-002 is satisfied when:

```text
[✓] Derived Artifact is a first-class UIF model.
[✓] Derived Artifact preserves Vault Object identity.
[✓] Derived Artifact preserves Ingestion Run identity.
[✓] Derived Artifact records processing stage.
[✓] Derived Artifact records processor identity/version.
[✓] Derived Artifact carries provenance.
[✓] Derived Artifact carries content hash.
[✓] StageResult links to produced artifacts.
[✓] IngestionResult exposes produced artifacts.
[✓] Existing OCR service is reused.
[✓] Existing entity extraction service is reused.
[✓] Existing candidate model is reused.
[✓] Candidates remain pending.
[✓] Partial processing preserves successful products.
[✓] Deterministic processing behavior is tested.
[✓] Source artifact remains immutable.
[✓] Knowledge Studio remains the curation boundary.
[✓] Repository commit remains downstream.
[✓] No second Vault is introduced.
[✓] No second database is introduced.
[✓] No second OCR subsystem is introduced.
[✓] TRX300 source and ground truth remain unchanged.
```

---

## 34. Frozen Status

AP-INGEST-002 is **FROZEN**.

The corresponding implementation work package:

```text
WP-INGEST-002
```

was independently audited against commit:

```text
22d54e943a563c65167c6f28d498bc795c29ca98
```

and accepted as complete.

No corrective implementation is authorized by this document.

Future improvements to durable Derived Artifact storage, richer evidence-location provenance, or other downstream capabilities must be handled as separate architectural work.

---

## 35. Relationship to AP-INGEST-003

AP-INGEST-002 establishes what UIF produces from processing.

AP-INGEST-003 establishes how UIF obtains its authoritative source input.

Therefore:

```text
AP-INGEST-002
    = processing-product architecture

AP-INGEST-003
    = production source-input boundary
```

They are intentionally separate.

The combined architecture is:

```text
             REFERENCE VAULT
             authoritative
               evidence
                   │
                   ▼
          AP-INGEST-003
       production input boundary
                   │
                   ▼
            VaultObjectInput
                   │
                   ▼
                  UIF
                   │
          AP-INGEST-002
                   │
                   ▼
          Derived Artifacts
          Findings / Candidates
                   │
                   ▼
           Knowledge Studio
                   │
                   ▼
       Engineering Repository
```

---

# FINAL PRINCIPLE

```text
THE VAULT OWNS THE SOURCE EVIDENCE.

UIF OWNS THE PROCESSING EXECUTION.

DERIVED ARTIFACTS RECORD WHAT PROCESSING PRODUCED.

PROVENANCE RECORDS HOW IT WAS PRODUCED.

KNOWLEDGE STUDIO DECIDES WHAT IS ACCEPTED.

THE ENGINEERING REPOSITORY STORES ACCEPTED KNOWLEDGE.
```

AP-INGEST-002 exists to make that separation explicit, deterministic, traceable, and enforceable.
