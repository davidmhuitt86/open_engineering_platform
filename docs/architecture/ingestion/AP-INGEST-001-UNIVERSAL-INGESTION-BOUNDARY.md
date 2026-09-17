# AP-INGEST-001 — UNIVERSAL INGESTION BOUNDARY

**Document Type:** Architecture Phase Specification  
**Architecture Phase:** AP-INGEST-001  
**Status:** Proposed for Ratification  
**Implementation Status:** NOT AUTHORIZED  
**Primary Domain:** Universal Ingestion Framework (UIF)  
**Scope:** Reference Vault → Ingestion → Knowledge Studio → Engineering Repository  
**First Acceptance Vertical Slice:** TRX300 Factory Wiring Diagram

---

## 1. Purpose

AP-INGEST-001 establishes the architectural boundary, contracts, lifecycle, provenance model, processing model, and acceptance criteria for the Open Engineering Platform Universal Ingestion Framework (UIF).

The purpose of UIF is to transform immutable engineering evidence held by the Reference Vault into structured engineering information and Engineering Knowledge Candidates that can be inspected and curated by Knowledge Studio.

UIF is an extraction and orchestration system.

UIF does **not** determine engineering truth, approve engineering knowledge, create accepted Engineering Objects, or commit directly to the Engineering Repository.

This specification formalizes the boundary identified during the AP-INGEST-001 architecture audit and provides the contract that must be frozen before implementation work begins.

---

# 2. Architectural Position

The canonical information flow is:

```text
Official / External Source
        │
        ▼
Engineering Acquisition Manager (EAM)
        │
        ▼
Reference Vault
        │
        │ immutable engineering evidence
        ▼
Universal Ingestion Framework (UIF)
        │
        ├── Artifact Identification
        ├── Parser Selection
        ├── Metadata Extraction
        ├── Content Extraction
        ├── Structural Analysis
        ├── OCR
        ├── Entity Extraction
        ├── Relationship Extraction
        ├── Chunk Generation
        └── Candidate Generation
        │
        ▼
Ingestion Result / Candidate Graph
        │
        ▼
Knowledge Studio
        │
        ├── inspect
        ├── compare
        ├── review
        ├── accept
        └── reject
        │
        ▼
Commit Pipeline
        │
        ▼
Engineering Repository
        │
        ▼
Accepted Engineering Objects / Relationships
```

The following ownership boundaries are authoritative for this architecture phase:

| System | Primary Responsibility | Explicit Non-Responsibility |
|---|---|---|
| EAM | Acquisition, source verification, custody, acquisition metadata, provenance, integrity | Engineering extraction, engineering truth, engineering approval |
| Reference Vault | Permanent evidence custody and retrieval | Engineering truth, engineering review |
| UIF | Identification, parsing, extraction, normalization, orchestration, candidate production | Engineering approval, repository commit, truth determination |
| Knowledge Studio | Human inspection, curation, review, acceptance/rejection | Permanent evidence custody, acquisition |
| Engineering Repository | Accepted Engineering Objects, Relationships, revisions, commits | Raw acquisition custody, unreviewed extraction |

---

# 3. Governing Architectural Rules

The following rules are frozen for AP-INGEST-001:

1. UIF consumes Reference Vault Objects.
2. Reference Vault remains the system of record for engineering evidence.
3. UIF owns ingestion orchestration, not evidence custody.
4. Format-specific parsers are modular and replaceable.
5. Parser output is normalized into common UIF structures.
6. Existing OCR functionality is reused rather than duplicated.
7. Existing Engineering Entity Extraction is reused rather than duplicated.
8. Derived artifacts are first-class ingestion products.
9. Derived products retain complete provenance to their originating evidence.
10. An extraction finding is not engineering truth.
11. UIF produces Engineering Knowledge Candidates, not accepted Engineering Objects.
12. Knowledge Studio owns human curation and review.
13. CommitTransactionService remains the repository write boundary.
14. The Engineering Repository remains the system of record for accepted engineering knowledge.
15. Processing should be deterministic and idempotent where the underlying processor permits it.
16. Partial processing preserves successful intermediate results.
17. TRX300 is the first end-to-end acceptance vertical slice.
18. The existing electrical solver remains the authority for electrical behavior validation.
19. Embeddings are an extensible UIF stage but are not required for the first vertical slice.
20. No parallel OCR, candidate, repository-commit, or electrical-solver subsystem shall be introduced.

---

# 4. Boundary Between Acquisition and Ingestion

## 4.1 EAM

EAM establishes trusted custody of an acquired engineering artifact.

Its responsibility ends at producing an evidence object that can be consumed downstream.

The EAM acquisition sequence is conceptually:

```text
Acquire
  ↓
Verify Source
  ↓
Capture Metadata
  ↓
Hash Artifact
  ↓
Create Acquisition Record
  ↓
Verify Integrity
  ↓
Publish to Reference Vault
```

EAM does not transform the artifact into engineering knowledge.

## 4.2 Reference Vault

The Reference Vault is authoritative for the evidence itself.

A Vault Object represents immutable engineering evidence and may have derived evidence associated with it, including:

- OCR output
- page images
- text extraction
- thumbnails
- structural representations
- embeddings
- translated text
- normalized metadata

Derived evidence remains linked to its originating Vault Object.

The Vault does not become an Engineering Knowledge Object merely because UIF extracts information from it.

## 4.3 UIF

UIF consumes the Vault Object and performs controlled processing.

UIF does not:

- modify the original artifact;
- take ownership of the evidence;
- determine engineering truth;
- directly create accepted Engineering Objects;
- directly commit repository revisions;
- replace Knowledge Studio review.

---

# 5. UIF Input Contract

The conceptual UIF input is a `VaultObjectInput`.

```text
VaultObjectInput
├── vaultObjectId
├── acquisitionRecordIds[]
├── artifactType
├── mimeType
├── contentHash
├── storageReference
└── immutableMetadataSnapshot
```

### 5.1 `vaultObjectId`

Permanent identity of the Reference Vault object being processed.

### 5.2 `acquisitionRecordIds`

References the acquisition history associated with the evidence.

Multiple acquisition records may be relevant where the Vault model associates multiple acquisition events with the same evidence identity.

### 5.3 `artifactType`

Logical artifact classification.

Examples may include:

```text
PDF
IMAGE
CAD
OFFICE_DOCUMENT
CSV
XML
JSON
YAML
ENGINEERING_LOG
FIRMWARE
SOFTWARE_ARCHIVE
AUDIO
VIDEO
```

The artifact taxonomy remains extensible.

### 5.4 `mimeType`

The detected or recorded MIME type.

### 5.5 `contentHash`

Content identity used for integrity, reproducibility, and ingestion identity.

### 5.6 `storageReference`

An implementation-level reference that permits UIF to obtain the immutable content.

UIF shall not depend on a particular physical storage implementation.

### 5.7 `immutableMetadataSnapshot`

Metadata supplied with the Vault Object at ingestion time.

UIF may derive additional metadata but shall not rewrite the Vault Object's immutable evidence record.

---

# 6. Ingestion Run

An `IngestionRun` represents one processing attempt against one immutable Vault Object.

Conceptual structure:

```text
IngestionRun
├── runId
├── vaultObjectId
├── startedAt
├── completedAt
├── status
├── pipelineVersion
├── parserId
├── parserVersion
├── processorVersions
├── processingConfiguration
└── stageResults[]
```

## 6.1 Run Status

The canonical state vocabulary is:

```text
QUEUED
RUNNING
COMPLETED
PARTIAL
FAILED
CANCELLED
```

`PARTIAL` is mandatory because an ingestion run may successfully process some portions of an artifact while another portion fails.

Example:

```text
PDF
├── Page 1 → OCR success
├── Page 2 → OCR success
├── Page 3 → OCR failure
├── Page 4 → OCR success
└── Page 5 → OCR success

Run Status → PARTIAL
```

Successful intermediate products must remain available.

## 6.1.1 Execution Lifecycle (WP-INGEST-007)

An `IngestionRun` is created, persisted, and transitioned through this
vocabulary as a durable lifecycle -- not constructed only after
execution finishes:

```text
CREATE RUN
    ↓
  QUEUED  (persisted before any stage executes)
    ↓
  RUNNING (persisted before stage execution proceeds)
    ↓
STAGE EXECUTION
    ↓
┌──────────┬─────────┬────────┬───────────┐
↓          ↓         ↓        ↓
COMPLETED   PARTIAL   FAILED   CANCELLED
└──────────┴─────────┴────────┴───────────┘
    ↓
PERSISTED HISTORY (KnowledgeSessionRecord.ingestionRuns)
```

Legal transitions, enforced by `IngestionRunStatus.canTransitionTo`
and `IngestionRun.transitionTo` (throws `StateError` on an illegal
transition):

```text
QUEUED  -> RUNNING, FAILED, CANCELLED
RUNNING -> COMPLETED, PARTIAL, FAILED, CANCELLED
```

`COMPLETED`/`PARTIAL`/`FAILED`/`CANCELLED` are terminal: none of them
may transition to anything else, in particular never back to
`RUNNING`.

**Execution identity vs. processing identity.** `runId` identifies one
*execution attempt*; `processingIdentity` (§ 22) identifies the
*processing definition + evidence combination* that attempt used. A
retry is a new `runId` against the same evidence/processing
definition, and therefore may legitimately share its
`processingIdentity` with the run it retries -- this is not
deduplication, and no run is ever skipped, merged, or auto-retried
because a matching `processingIdentity` already exists. Every
execution attempt, including a FAILED or CANCELLED one, remains a
separate, permanent entry in `KnowledgeSessionRecord.ingestionRuns`;
retrying never overwrites or deletes the run it retries.

**Interruption semantics.** If the application terminates while a run
is QUEUED/RUNNING, the run is not left in that state forever and is
never silently resumed, retried, or marked completed. The next real
load of its Knowledge Session (`KnowledgeSessionStorage.load`)
reconciles any non-terminal run it finds to FAILED, appending
`IngestionRun.interruptionDiagnostic` ("Execution interrupted before
completion.") to that run's `diagnostics` -- a diagnostic that
distinguishes an interrupted execution from an ordinary stage failure.
This reconciliation happens on every real load, not as a separate
step callers must remember to invoke.

**Cancellation.** An `IngestionCancellationToken`, created and held by
the caller and passed to `IngestionOrchestrator.run`, is the whole
cancellation mechanism -- checked at stage boundaries only, never
mid-stage. `QUEUED -> CANCELLED` (before any stage runs) and
`RUNNING -> CANCELLED` (at the next stage boundary, preserving every
already-completed stage's results) are both legal; CANCELLED is never
conflated with FAILED.

---

# 7. Processing Pipeline

The canonical UIF stage vocabulary is:

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

Not every artifact executes every stage.

Stage execution is capability-driven.

For example:

```text
PDF
  → IDENTIFY
  → PARSER_SELECTION
  → METADATA_EXTRACTION
  → CONTENT_EXTRACTION
  → STRUCTURAL_ANALYSIS
  → OCR
  → ENTITY_EXTRACTION
  → RELATIONSHIP_EXTRACTION
  → CANDIDATE_GENERATION
```

Chunk and embedding generation may be added later without changing the preceding contracts.

---

# 8. Parser Contract

UIF requires a generalized parser abstraction.

Conceptually:

```text
Parser
├── parserId
├── version
├── supportedArtifactTypes[]
├── supportedMimeTypes[]
├── canParse(input)
└── parse(input)
```

`parse()` produces normalized extraction data rather than writing directly to application databases.

## 8.1 Parser Restrictions

A parser shall not:

- write PostgreSQL directly;
- create Engineering Objects;
- commit Knowledge Candidates;
- modify Reference Vault evidence;
- perform engineering approval;
- perform engineering validation as a source of truth.

A parser may identify and describe what exists in the source.

The distinction is:

```text
Parser:
    "The document contains this."

Engineering Review:
    "This is accepted as engineering knowledge."
```

---

# 9. Artifact Identification

Artifact identification determines the characteristics required to select a processing pipeline.

The identification result may include:

```text
format
mimeType
encoding
language
documentClass
engineeringDomain
```

Identification is descriptive.

It does not establish engineering truth.

---

# 10. Metadata Extraction

UIF metadata extraction operates on descriptive document metadata.

The target vocabulary includes:

```text
title
author
organization
publicationDate
revision
keywords[]
productFamily
manufacturer
documentIdentifiers[]
language
documentType
```

Metadata extraction is deterministic where source information permits.

Metadata extracted during ingestion must remain distinguishable from immutable acquisition metadata.

---

# 11. Content and Structural Extraction

Content extraction transforms the source into machine-readable content.

Structural analysis preserves relationships within the source document.

The normalized structural model may represent:

```text
Document
├── Pages
├── Sections
├── Headings
├── Paragraphs
├── Tables
├── Figures
├── Equations
├── Diagrams
├── Captions
└── References
```

Structural information shall retain source location whenever available.

---

# 12. OCR Integration

Existing OEP OCR functionality is the OCR implementation used by the first UIF vertical slice.

UIF shall orchestrate the OCR stage rather than create a second OCR engine.

The existing OCR path currently provides per-page results including:

```text
sourceId
page
words
imageWidth
imageHeight
sourceFingerprint
engineVersion
processedTime
success
errorMessage
```

Conceptual integration:

```text
UIF
  ↓
OCR Stage
  ↓
Existing OcrPipelineService
  ↓
OcrPageResult[]
```

The existing per-page failure behavior supports the UIF `PARTIAL` run state.

---

# 13. Engineering Entity Extraction

Existing Engineering Entity Extraction is also reused.

The extraction system currently identifies engineering entities such as:

- torque
- voltage
- resistance
- pressure
- temperature
- dimensions
- fastener sizes
- part numbers
- tool references
- fluids
- fuse ratings
- connector IDs
- wire colors
- wire gauges

An `EngineeringEntity` remains a workspace extraction artifact.

It is not automatically an Engineering Object.

Conceptually:

```text
UIF
  ↓
ENTITY_EXTRACTION
  ↓
Existing Engineering Entity Extraction
  ↓
EngineeringEntity[]
  ↓
Candidate Generation
```

Acceptance into the Engineering Repository remains downstream of human review.

---

# 14. Relationship Extraction

Relationship extraction identifies relationships supported by source evidence.

Relationships remain candidates until reviewed.

Examples may include:

```text
component → connected_to → connector
component → references → specification
document → describes → component
wire → terminates_at → connector
component → associated_with → vehicle
```

The exact relationship vocabulary remains governed by the existing OEP Relationship Model.

UIF must not silently promote extracted relationships into accepted repository relationships.

---

# 15. Derived Artifact Model

Derived artifacts are first-class outputs of processing.

Conceptual model:

```text
DerivedArtifact
├── derivedArtifactId
├── runId
├── vaultObjectId
├── stage
├── artifactType
├── contentHash
├── createdAt
├── processorId
├── processorVersion
└── provenance
```

Examples:

```text
Original PDF
    ↓
Page Image
    ↓
OCR Page
    ↓
OCR Text
    ↓
Structural Representation
    ↓
Engineering Entity Extraction
    ↓
Chunk
    ↓
Embedding
```

The first vertical slice does not require every derived artifact type to be implemented.

The model must nevertheless support them without redesigning the architecture.

---

# 16. Provenance Contract

Every derived product must be traceable through the processing chain.

Canonical provenance hierarchy:

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

Evidence location may include:

```text
page
region
boundingBox
characterRange
source coordinates
structural path
```

Where applicable, provenance shall also identify:

```text
processorId
processorVersion
parserId
parserVersion
pipelineVersion
processing configuration
```

The goal is to answer:

> What evidence produced this result, through which processing path, using which software definition?

---

# 17. Candidate Model

UIF produces Engineering Knowledge Candidates.

Conceptual candidate:

```text
EngineeringKnowledgeCandidate
├── candidateId
├── candidateType
├── extractedValue
├── sourceEvidence[]
├── confidence
├── provenance
└── status
```

A candidate is an extracted proposition awaiting engineering review.

The lifecycle is:

```text
EXTRACTED
    ↓
PENDING_REVIEW
    ├── ACCEPTED
    └── REJECTED
```

Additional states may be introduced later if required by the review architecture.

The critical rule is:

```text
Candidate ≠ Engineering Object
```

---

# 18. Ingestion Result

The UIF output is an `IngestionResult`.

Conceptually:

```text
IngestionResult
├── run
├── metadata
├── structuralData
├── derivedArtifacts[]
├── engineeringEntities[]
├── relationshipCandidates[]
├── chunks[]
├── embeddings[]
└── knowledgeCandidates[]
```

The first TRX300 implementation may omit chunk and embedding products while preserving the extensible result contract.

---

# 19. Knowledge Studio Boundary

Knowledge Studio consumes the UIF result.

Canonical flow:

```text
UIF
  ↓
IngestionResult
  ↓
Knowledge Studio Session
  ↓
Evidence Inspection
  ↓
OCR / Entity / Relationship Review
  ↓
Accept / Reject
  ↓
Commit Plan
  ↓
CommitTransactionService
  ↓
Engineering Repository
```

The existing Knowledge Curation Session is the appropriate workspace boundary.

It already persists:

```text
candidates
relationshipCandidates
sources
reviewDecisions
evidenceRegions
evidenceLinks
pageSelections
procedureSteps
specificationDetails
commitReports
ocrPageResults
engineeringEntities
engineeringContexts
aiSuggestions
ingestionRuns
derivedArtifacts
```

UIF must not create a parallel review/session subsystem.

**WP-INGEST-006 update.** `ingestionRuns`/`derivedArtifacts` were added by
WP-INGEST-006 to make the *processing execution itself* — which run,
which pipeline/parser/processor versions, which stages
succeeded/partially succeeded/failed/were skipped, and which derived
products (by reference/content hash, not bytes) resulted — durable
alongside the extraction findings this section already documented as
persisted. `ingestionRuns` holds one `IngestionRun` (§ 6) per ingestion
that contributed to a session, including its deterministic processing
identity (§ 22) and full `StageResult[]` history. `derivedArtifacts`
holds each `DerivedArtifact`'s (§ 15) durable metadata/provenance
record — `DerivedArtifact` has never carried the derived product's
actual bytes, only identity and a content hash, so this was already
metadata/reference persistence, not a new claim of durable artifact
bytes.

---

# 20. Engineering Repository Boundary

UIF shall not directly write accepted engineering knowledge.

The repository write path remains:

```text
Candidate
    ↓
Knowledge Studio Review
    ↓
Commit Plan
    ↓
CommitTransactionService
    ↓
Foundation / Repository Boundary
    ↓
Engineering Repository
```

This preserves the existing separation between:

```text
Extraction
Review
Commit
```

No UIF implementation may bypass that sequence.

---

# 21. Persistence Domains

AP-INGEST-001 recognizes three distinct persistence domains.

## 21.1 Domain A — Reference Vault

Purpose:

```text
Evidence
Custody
Integrity
Acquisition history
Derived evidence artifacts
```

System of record:

**Reference Vault**

## 21.2 Domain B — Ingestion / Knowledge Session

Purpose:

```text
Processing work
OCR results
Extraction findings
Structural findings
Candidates
Evidence mappings
Review decisions
Processing metadata
```

This is mutable work-in-progress state.

System of record:

**Knowledge Studio / Ingestion Session domain**

## 21.3 Domain C — Engineering Repository

Purpose:

```text
Accepted Engineering Objects
Accepted Relationships
Revisions
Commits
Repository history
```

System of record:

**Engineering Repository**

These domains must not be collapsed into one persistence model.

---

# 22. Idempotency and Processing Identity

The logical identity of an ingestion result should incorporate:

```text
Vault Object identity
+
content/version identity
+
pipeline version
+
parser versions
+
processor versions
+
processing configuration
```

Therefore:

```text
Same Evidence
+
Same Processing Definition
=
Same Logical Ingestion Result
```

A change in parser, processor, pipeline definition, or relevant processing configuration creates a new processing identity.

The original evidence remains unchanged.

Implementation note (INGEST-FOLLOWUP-003): the processing identity is computed as the SHA-256 digest of a deterministic *canonical structured JSON representation* of the identity tuple above — each field serialized as its own properly JSON-encoded value, map keys sorted recursively, list order preserved — not a delimiter-joined string. A delimiter-joined string is structurally ambiguous (a delimiter character occurring inside one input value can make two different tuples serialize identically); the structured representation avoids that ambiguity by construction.

---

# 23. Failure Semantics

Failure at one processing stage shall not unnecessarily destroy successful prior results.

Examples:

```text
Parser succeeds
OCR partially succeeds
Entity extraction succeeds on available OCR
Candidate generation proceeds on available evidence
Run = PARTIAL
```

or:

```text
Parser fails
No normalized content exists
Run = FAILED
```

The system must preserve diagnostics sufficient to determine which stage failed and why.

---

# 24. Determinism

UIF processing should be deterministic wherever the underlying processor is deterministic.

For deterministic processors:

```text
Same Input
+
Same Processor Version
+
Same Configuration
=
Same Output
```

Non-deterministic processors must identify that characteristic in processing metadata.

Determinism is required for benchmark comparison and reproducibility.

---

# 25. Non-Destructive Processing

UIF processing shall never modify the source evidence.

The source PDF, image, CAD file, or other Vault Object remains immutable.

All processing output is:

```text
new derived artifact
or
new ingestion result
or
new candidate
```

Never:

```text
overwrite source evidence
```

---

# 26. TRX300 First Vertical Slice

The Honda TRX300 factory wiring diagram is the first formal end-to-end acceptance dataset.

The existing reference package provides:

```text
Source PDF
Ground Truth Snapshot
Object Inventory
Relationship Inventory
PDF-to-OEP Correspondence
Visual Annotations
Validation Categories
Electrical Validation Cases
Provenance Model
Benchmark Contract
```

The existing ground truth contains:

```text
47 verified objects
80 verified relationships
```

The benchmark contract defines the intended future flow:

```text
SOURCE PDF
    ↓
INGESTION
    ↓
CANDIDATE GRAPH
    ↓
COMPARATOR
    ↓
ACCURACY REPORT

GROUND TRUTH
    ───────────────► COMPARATOR
```

The benchmark comparator and numerical accuracy methodology are not part of this implementation phase unless separately authorized.

---

# 27. TRX300 Acceptance Criteria

The first vertical slice shall demonstrate:

### AC-001 — Vault Input

UIF can consume the TRX300 source as a Reference Vault-style immutable input.

### AC-002 — Artifact Identification

The pipeline correctly identifies the source artifact type and processing capability.

### AC-003 — Parser Selection

A deterministic parser is selected for the source format.

### AC-004 — Metadata

Available document metadata is extracted into normalized UIF structures.

### AC-005 — Content

Document content is extracted without modifying the source.

### AC-006 — Structure

Pages and relevant structural locations remain traceable.

### AC-007 — OCR

Existing OCR functionality is invoked through UIF orchestration.

### AC-008 — Entity Extraction

Existing Engineering Entity Extraction is invoked through UIF orchestration.

### AC-009 — Relationship Candidates

Relevant relationships can be represented as candidate relationships with provenance.

### AC-010 — Candidate Graph

The resulting extracted information can be represented as a candidate graph without creating accepted Engineering Objects.

### AC-011 — Provenance

Candidate information can be traced back to source evidence and processing history.

### AC-012 — Knowledge Studio

The ingestion result can be consumed by the existing Knowledge Studio curation model.

### AC-013 — Review Boundary

Candidates remain uncommitted until human review.

### AC-014 — Repository Boundary

Accepted knowledge reaches the Engineering Repository only through the existing commit pipeline.

### AC-015 — Electrical Validation

Electrical behavior remains validated by the existing live electrical solver rather than a new ingestion scoring engine.

### AC-016 — Partial Processing

A controlled processing failure preserves successful intermediate results and reports the run as `PARTIAL` where appropriate.

### AC-017 — Reproducibility

Repeated processing with the same processing definition produces a reproducible result for deterministic stages.

---

# 28. Benchmark Boundary

The TRX300 benchmark is an acceptance mechanism, not an ingestion subsystem.

The benchmark shall not:

- redefine engineering truth;
- replace the ground truth package;
- introduce a second electrical solver;
- silently modify `diagram7.json`;
- modify the source PDF;
- invent an independent scoring authority.

The existing live electrical solver remains the behavioral authority.

The benchmark comparator and formal numerical scoring remain future work unless separately specified.

---

# 29. Existing Implementation Reuse Requirements

The first implementation shall reuse the following existing capabilities:

```text
Existing OCR Pipeline
        ↓
OcrPipelineService
        ↓
OcrPageResult

Existing Engineering Entity Extraction
        ↓
EngineeringEntity

Existing Knowledge Session
        ↓
KnowledgeSessionRecord

Existing Commit Planning
        ↓
CommitPlanService

Existing Commit Transaction
        ↓
CommitTransactionService

Existing Repository / Foundation Boundary
```

No replacement subsystem is authorized merely to satisfy the UIF architecture.

---

# 30. Architectural Gaps Explicitly Accepted for Future Work

The following are not required to block the first vertical slice:

- full multi-format parser catalog;
- CAD topology extraction;
- PCB/schematic recognition;
- handwriting recognition;
- speech processing;
- multimodal extraction;
- translation;
- embedding generation;
- enterprise-scale indexing;
- distributed ingestion execution;
- replication;
- archival infrastructure;
- advanced lifecycle management;
- benchmark numerical weighting methodology;
- full automated comparator implementation.

These capabilities must remain architecturally compatible with the UIF boundary.

---

# 31. Known Reference Vault Considerations

The existing Reference Vault audit identified several areas that remain future maturity work:

- richer descriptive metadata;
- explicit Acquisition Record modeling alignment;
- version history;
- related Vault Objects;
- derived-artifact persistence;
- search;
- indexing;
- operational fixity checking;
- storage abstraction beyond filesystem.

These issues do not justify moving evidence custody into UIF.

If later Reference Vault work changes its contract, the UIF input contract shall be versioned rather than silently changed.

---

# 32. Security and Integrity Boundary

UIF consumes trusted Vault evidence.

Integrity verification belongs to the acquisition/evidence boundary.

UIF must retain the source content identity used for processing and must record processing provenance.

UIF shall not treat extracted text, OCR, inferred relationships, or candidate confidence as equivalent to cryptographic evidence integrity.

These are separate concepts:

```text
Integrity:
    "Is this the same evidence?"

Extraction:
    "What information can be obtained from it?"

Engineering Review:
    "What should be accepted as engineering knowledge?"
```

---

# 33. Versioning

The following versions are independently significant:

```text
Vault Object version / content identity
Ingestion Pipeline version
Parser version
Processor version
Processing configuration
Candidate model version
```

Changing one of these must not mutate prior ingestion history.

Prior ingestion results remain historical processing records.

---

# 34. Extensibility

The architecture shall permit future stages without changing the fundamental boundaries.

Future examples include:

```text
CAD_TOPOLOGY
PCB_EXTRACTION
SCHEMATIC_RECOGNITION
SYMBOL_RECOGNITION
HANDWRITING_RECOGNITION
MULTIMODAL_ANALYSIS
TRANSLATION
SIMULATION_MODEL_EXTRACTION
```

These remain UIF processing capabilities.

They do not gain authority to:

```text
approve engineering truth
```

---

# 35. Prohibited Architectural Shortcuts

The following are explicitly prohibited under AP-INGEST-001:

### 35.1 Direct UIF Repository Commit

```text
UIF → Repository
```

without Knowledge Studio review is prohibited.

### 35.2 Vault Mutation

```text
UIF → modify original Vault Object
```

is prohibited.

### 35.3 Parallel OCR

A second OCR implementation may not be introduced to replace or duplicate the existing OCR pipeline without a separately approved architecture decision.

### 35.4 Parallel Candidate System

A second candidate/review architecture may not be created outside the existing Knowledge Studio model.

### 35.5 Parallel Electrical Solver

Ingestion validation must not create a competing electrical behavior authority.

### 35.6 Truth by Confidence

A high extraction confidence value does not constitute engineering approval.

### 35.7 Evidence Loss

Processing must never discard the source provenance necessary to reconstruct how a candidate was produced.

---

# 36. Architectural State Machine

The high-level lifecycle is:

```text
VAULT_OBJECT_AVAILABLE
        ↓
INGESTION_QUEUED
        ↓
IDENTIFYING
        ↓
PARSER_SELECTED
        ↓
PROCESSING
        │
        ├── COMPLETED
        │
        ├── PARTIAL
        │
        └── FAILED
        ↓
INGESTION_RESULT_AVAILABLE
        ↓
KNOWLEDGE_STUDIO_REVIEW
        │
        ├── CANDIDATE_ACCEPTED
        └── CANDIDATE_REJECTED
        ↓
COMMIT_PIPELINE
        ↓
ENGINEERING_REPOSITORY
```

The ingestion lifecycle and engineering review lifecycle are intentionally separate.

---

# 37. Architecture Decision Summary

AP-INGEST-001 establishes the following canonical architecture:

```text
EAM
  =
acquire + verify + custody

Reference Vault
  =
immutable evidence + derived evidence

UIF
  =
identify + parse + extract + normalize + orchestrate + produce candidates

Knowledge Studio
  =
inspect + curate + review

Engineering Repository
  =
accepted engineering knowledge
```

The resulting system preserves the central OEP distinction:

```text
Evidence
    ≠
Extraction
    ≠
Engineering Knowledge
```

---

# 38. Ratification Criteria

AP-INGEST-001 is ready for ratification when the architecture owner confirms:

- UIF ownership is accepted.
- Reference Vault remains the evidence system of record.
- The `VaultObjectInput` boundary is accepted.
- `IngestionRun` lifecycle is accepted.
- Parser abstraction is accepted.
- Derived Artifact model is accepted.
- Provenance hierarchy is accepted.
- Candidate boundary is accepted.
- Knowledge Studio remains the review boundary.
- CommitTransactionService remains the repository write boundary.
- TRX300 is accepted as the first vertical slice.
- Existing OCR and Engineering Entity Extraction are accepted as reusable implementations.
- Embeddings are deferred from the first vertical slice.
- No implementation begins until the specification is frozen.

---

# 39. Implementation Authorization

**Current state: NOT AUTHORIZED.**

This document defines the architecture contract.

The next implementation artifact, after ratification, shall be a dedicated implementation work package containing:

1. exact repository locations;
2. exact interfaces/classes to create or modify;
3. database/persistence requirements, if any;
4. test requirements;
5. TRX300 vertical-slice acceptance tests;
6. explicit files that must not be changed;
7. build/analyze/test commands;
8. commit requirements;
9. AAR requirements.

No implementation agent should infer additional architectural authority from implementation convenience.

---

# 40. Final Architecture Statement

AP-INGEST-001 establishes UIF as the controlled boundary between preserved engineering evidence and engineering knowledge curation.

The architecture is intentionally layered:

```text
SOURCE
  ↓
EAM
  ↓
REFERENCE VAULT
  ↓
UIF
  ↓
INGESTION RESULT
  ↓
KNOWLEDGE CANDIDATES
  ↓
KNOWLEDGE STUDIO
  ↓
ENGINEERING REVIEW
  ↓
COMMIT TRANSACTION
  ↓
ENGINEERING REPOSITORY
```

The architecture preserves evidence, makes extraction reproducible, maintains provenance, prevents extraction from becoming truth by accident, and allows the existing OEP Knowledge Studio and repository infrastructure to remain the downstream authority.

**AP-INGEST-001 therefore defines the Universal Ingestion boundary without authorizing its implementation.**