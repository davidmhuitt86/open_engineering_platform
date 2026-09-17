# WP-INGEST-001 — UNIVERSAL INGESTION FRAMEWORK
## Implementation Work Package — TRX300 First Vertical Slice

**Target Repository:** `davidmhuitt86/open_engineering_platform`  
**Architecture Contract:** `AP-INGEST-001-UNIVERSAL-INGESTION-BOUNDARY.md`  
**Authorization:** IMPLEMENTATION AUTHORIZED  
**Scope:** First end-to-end Universal Ingestion vertical slice  
**Primary Acceptance Dataset:** TRX300 Factory Wiring Diagram

---

# 1. Mission

Implement the first production-shaped vertical slice of the Universal Ingestion Framework (UIF) strictly according to the ratified AP-INGEST-001 architecture contract.

The implementation must establish the missing orchestration boundary:

```text
Reference Vault Object
        ↓
UIF
        ↓
Ingestion Run
        ↓
Parser / Extraction Stages
        ↓
Derived / Extracted Results
        ↓
Engineering Knowledge Candidates
        ↓
Existing Knowledge Studio Session
        ↓
Existing Commit Pipeline
        ↓
Engineering Repository
```

This work package is intentionally limited to the first complete vertical slice.

Do not expand the work into a generalized enterprise ingestion platform, distributed processing system, embedding infrastructure, AI system, or new review/commit architecture.

---

# 2. NON-NEGOTIABLE ARCHITECTURAL RULES

These rules are mandatory.

1. UIF consumes Reference Vault evidence.
2. Reference Vault remains the evidence system of record.
3. UIF does not modify source evidence.
4. UIF owns ingestion orchestration.
5. UIF does not determine engineering truth.
6. UIF produces candidates, not accepted Engineering Objects.
7. Existing OCR must be reused.
8. Existing Engineering Entity Extraction must be reused.
9. Existing Knowledge Studio session infrastructure must be reused.
10. Existing `CommitTransactionService` remains the repository write boundary.
11. No direct UIF → repository commit path.
12. No second OCR implementation.
13. No second candidate/review subsystem.
14. No second electrical solver.
15. Provenance must survive every processing stage.
16. Partial processing must preserve successful intermediate results.
17. TRX300 is the first acceptance vertical slice.
18. Embeddings are NOT required for this first implementation.
19. Do not modify the TRX300 source PDF or authoritative ground truth.
20. Do not make unrelated changes to the repository.

If an implementation convenience conflicts with these rules, stop and report the conflict rather than changing the architecture.

---

# 3. FIRST STEP — REPOSITORY AUDIT

Before changing any source file:

```text
git status --short
git rev-parse HEAD
git branch --show-current
```

Read the ratified architecture document:

```text
docs/architecture/ingestion/AP-INGEST-001-UNIVERSAL-INGESTION-BOUNDARY.md
```

Then inspect the existing implementations for:

```text
services/acquisition/
platform/oep_studio/lib/knowledge/
platform/oep_studio/lib/core/services/foundation_runtime_service.dart
platform/oep_studio/lib/knowledge/services/ocr_pipeline_service.dart
platform/oep_studio/lib/knowledge/models/ocr_page_result.dart
platform/oep_studio/lib/knowledge/models/knowledge_session_record.dart
platform/oep_studio/lib/knowledge/models/engineering_entity.dart
platform/oep_studio/lib/knowledge/services/commit_plan_service.dart
platform/oep_studio/lib/knowledge/services/commit_transaction_service.dart
reference/ingestion/trx300/
```

Confirm actual current interfaces before implementing.

Do NOT assume names or paths from this work package if the current repository has deliberately evolved them.

---

# 4. WORKING-TREE SAFETY

There may be unrelated user changes in the working tree.

Rules:

- Do not revert unrelated changes.
- Do not reset the repository.
- Do not clean the working tree.
- Do not overwrite user work.
- Do not reformat unrelated files.
- Do not modify unrelated acquisition/UI work.
- Keep the implementation diff narrowly scoped.

At the beginning and end, report:

```text
git status --short
```

and identify all files changed by this work package.

---

# 5. IMPLEMENTATION BOUNDARY

Implement the minimum architecture necessary to establish:

```text
VaultObjectInput
        ↓
IngestionRun
        ↓
Parser Selection
        ↓
Normalized Extraction
        ↓
OCR Integration
        ↓
Engineering Entity Integration
        ↓
Relationship Candidate Representation
        ↓
Knowledge Candidate Generation
        ↓
IngestionResult
        ↓
Knowledge Studio-compatible session data
```

Do not implement the full future UIF stage catalog.

The first executable stages are:

```text
IDENTIFY
PARSER_SELECTION
METADATA_EXTRACTION
CONTENT_EXTRACTION
STRUCTURAL_ANALYSIS
OCR
ENTITY_EXTRACTION
RELATIONSHIP_EXTRACTION
CANDIDATE_GENERATION
```

These may be represented internally with explicit stage state even if some stages are initially thin adapters.

Do NOT make these first-slice prerequisites:

```text
CHUNK_GENERATION
EMBEDDING_GENERATION
CAD topology
multimodal AI
distributed workers
enterprise queueing
```

---

# 6. REQUIRED DOMAIN CONTRACTS

Create or adapt domain models as necessary.

Do not create duplicate models if an existing model already satisfies the contract.

## 6.1 VaultObjectInput

Minimum conceptual fields:

```text
vaultObjectId
acquisitionRecordIds[]
artifactType
mimeType
contentHash
storageReference
immutableMetadataSnapshot
```

The implementation may use repository-native naming, but all required semantics must exist.

The physical storage mechanism must remain behind the Reference Vault boundary.

---

## 6.2 IngestionRun

Minimum fields:

```text
runId
vaultObjectId
startedAt
completedAt
status
pipelineVersion
parserId
parserVersion
processorVersions
processingConfiguration
stageResults[]
```

Required status values:

```text
QUEUED
RUNNING
COMPLETED
PARTIAL
FAILED
CANCELLED
```

Use an existing OEP enum/value convention if one already exists.

Do not create multiple competing run-state models.

---

## 6.3 Stage Result

Each processing stage must be able to report at least:

```text
stage
status
startedAt
completedAt
diagnostics
derivedArtifactIds[]
```

A stage failure must be distinguishable from a successful stage.

---

## 6.4 Parser Contract

Create or adapt a parser abstraction supporting:

```text
parserId
version
supportedArtifactTypes[]
supportedMimeTypes[]
canParse(input)
parse(input)
```

Parser output must be normalized.

The parser must not:

```text
write PostgreSQL
create Engineering Objects
commit candidates
modify Reference Vault
perform engineering approval
```

For the first slice, implement only the parser required for the TRX300 PDF.

Do not create a large parser catalog.

---

# 7. NORMALIZED EXTRACTION MODEL

Define a minimal normalized representation capable of carrying:

```text
document identity
pages
text
structural locations
figures/diagrams where available
source locations
metadata
```

Every normalized item must retain enough provenance to identify its originating Vault Object and source location.

Do not design a second document database.

Keep the model lightweight and extensible.

---

# 8. DERIVED ARTIFACT CONTRACT

Implement or adapt a first-class derived artifact representation.

Minimum semantics:

```text
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

For the first slice, expected useful products include:

```text
page image
OCR page result
OCR text
normalized structural/content result
engineering entity extraction result
candidate result
```

Do not require every future derived artifact type.

Do not alter the original Vault Object.

---

# 9. PROVENANCE

Implement a common provenance representation.

The minimum trace must be:

```text
Vault Object
    ↓
Acquisition Record
    ↓
Ingestion Run
    ↓
Processing Stage
    ↓
Derived Artifact / Finding
    ↓
Evidence Location
```

Evidence location should support the forms already present in OEP, including where applicable:

```text
page
boundingBox
characterStart
characterEnd
source fingerprint
```

Reuse existing `OcrPageResult` and `EngineeringEntity` provenance fields rather than replacing them.

The implementation must make it possible to answer:

```text
Which source produced this finding?
Which ingestion run produced it?
Which stage produced it?
Which processor/version produced it?
Where in the source did it come from?
```

---

# 10. OCR INTEGRATION

Do NOT build OCR.

Use the existing:

```text
OcrPipelineService
OcrPageResult
```

through a UIF stage adapter/orchestrator.

The desired flow is:

```text
UIF
 ↓
OCR stage
 ↓
existing OcrPipelineService
 ↓
OcrPageResult[]
```

Existing OCR behavior must remain intact.

Per-page OCR failures must be preserved.

Example:

```text
Page 1 success
Page 2 success
Page 3 failure
Page 4 success

IngestionRun = PARTIAL
```

Do not convert a partial OCR failure into total data loss.

---

# 11. ENGINEERING ENTITY EXTRACTION INTEGRATION

Do NOT build a second entity extractor.

Reuse the existing Engineering Entity Extraction implementation.

The UIF integration should produce or collect:

```text
EngineeringEntity[]
```

with existing source provenance intact.

Remember:

```text
EngineeringEntity
    ≠
Engineering Object
```

and:

```text
EngineeringEntity
    ↓
Candidate Generation
```

must remain an explicit boundary.

---

# 12. RELATIONSHIP EXTRACTION

Implement the minimum relationship candidate representation required to connect extracted entities/information.

Do not create accepted repository relationships.

Use the existing OEP Relationship Model where possible.

If relationship extraction is not yet sufficiently generalized for the TRX300 benchmark, implement the adapter/representation necessary to preserve candidate relationships and clearly document any remaining extraction limitation.

Do not invent a competing relationship taxonomy.

---

# 13. CANDIDATE GENERATION

Create candidates from extraction findings.

Candidate semantics must include:

```text
candidateId
candidateType
extractedValue
sourceEvidence[]
confidence
provenance
status
```

Required conceptual lifecycle:

```text
EXTRACTED
    ↓
PENDING_REVIEW
    ├── ACCEPTED
    └── REJECTED
```

Do not automatically commit candidates.

Do not call repository creation APIs from the candidate-generation stage.

---

# 14. INGESTION RESULT

Create/adapt an `IngestionResult` containing the products of the run.

Minimum conceptual content:

```text
run
metadata
structuralData
derivedArtifacts[]
engineeringEntities[]
relationshipCandidates[]
knowledgeCandidates[]
```

Chunk and embedding fields may exist as extensibility points but must not be required for the TRX300 first slice.

---

# 15. KNOWLEDGE STUDIO INTEGRATION

Do not create a new review application.

Use the existing Knowledge Curation Session architecture.

The integration must preserve the current session model containing, where applicable:

```text
sources
candidates
relationshipCandidates
reviewDecisions
evidenceRegions
evidenceLinks
pageSelections
ocrPageResults
engineeringEntities
```

The ingestion result should be capable of becoming/feeding a Knowledge Studio session without losing provenance.

Keep the distinction:

```text
UIF:
    extraction

Knowledge Studio:
    curation/review

CommitTransactionService:
    repository write
```

---

# 16. REPOSITORY WRITE BOUNDARY

This is a hard architectural constraint.

The following is prohibited:

```text
UIF → FoundationBridge → create object
```

The permitted path remains:

```text
UIF
 ↓
Knowledge Candidate
 ↓
Knowledge Studio
 ↓
Review
 ↓
CommitPlanService
 ↓
CommitTransactionService
 ↓
Foundation / Repository
```

Do not modify the repository commit architecture unless an existing interface genuinely blocks the approved contract. If blocked, stop and report the exact conflict.

---

# 17. TRX300 VERTICAL SLICE

Use:

```text
reference/ingestion/trx300/
```

as the acceptance dataset.

Do not modify:

```text
source/trx300_factory_wiring_diagram.pdf
ground_truth/
mappings/
annotations/
validation/
ingestion_benchmark_contract.md
provenance_model.md
```

The source and ground truth are authoritative test inputs.

The target flow is:

```text
TRX300 source
    ↓
UIF
    ↓
IngestionResult
    ↓
Candidate Graph
    ↓
Knowledge Studio-compatible representation
```

Do not implement the benchmark comparator unless the current repository already contains one and the integration is strictly required.

Do not invent a numerical accuracy score.

---

# 18. TRX300 ACCEPTANCE TESTS

At minimum, implement automated tests demonstrating:

### TEST-001 — Input

A TRX300 source can be presented to UIF as a Vault Object input.

### TEST-002 — Identification

The PDF is correctly identified.

### TEST-003 — Parser

The PDF parser is selected and produces normalized output.

### TEST-004 — Metadata

Available metadata is represented.

### TEST-005 — Content

Source content is extracted.

### TEST-006 — Structure

Page/source locations are preserved.

### TEST-007 — OCR

Existing OCR is invoked through UIF rather than duplicated.

### TEST-008 — Entity Extraction

Existing Engineering Entity Extraction is invoked.

### TEST-009 — Provenance

An extracted entity can be traced back to:

```text
Vault Object
→ Ingestion Run
→ Stage
→ Source Page/Location
```

### TEST-010 — Candidate

At least one extracted engineering finding can become a Knowledge Candidate.

### TEST-011 — No Direct Commit

Candidate generation cannot directly commit an Engineering Object.

### TEST-012 — Partial Processing

A controlled stage/page failure produces `PARTIAL` while preserving successful results.

### TEST-013 — Determinism

Repeated processing with identical deterministic inputs/configuration produces equivalent results.

### TEST-014 — Session Integration

The resulting extraction products can populate the existing Knowledge Studio session representation.

---

# 19. TESTING RULES

Run the narrowest relevant tests first.

Then run the broader project validation appropriate to the affected code.

At minimum:

```text
dart analyze
flutter build windows --debug
```

For C++ components, use the repository's existing CMake/test procedure.

Do not change build infrastructure merely to make the tests pass.

If pre-existing analyzer/build failures exist, distinguish them from failures introduced by this work.

---

# 20. PERFORMANCE / SCOPE

Do not optimize prematurely.

The first objective is architectural correctness and traceability.

Avoid:

```text
new caching architecture
distributed execution
background job infrastructure
database sharding
embedding indexes
AI model orchestration
```

unless the existing code already requires one for the narrow vertical slice.

---

# 21. DATABASE RULE

Do not introduce a new PostgreSQL schema merely because persistence is convenient.

Before adding persistence:

1. inspect existing Foundation/Repository persistence;
2. inspect existing acquisition persistence;
3. inspect Knowledge Studio session persistence;
4. determine whether the required state already has an appropriate owner.

If durable UIF persistence is genuinely required by the implementation, document exactly:

```text
what is persisted
which system owns it
why existing persistence is insufficient
migration impact
```

Do not create a second Foundation database.

Do not move Vault custody into the Studio.

---

# 22. FILE-CHANGE DISCIPLINE

Prefer the smallest possible implementation surface.

Before editing, identify exact files.

Do not modify:

```text
OEP Constitution
Reference Vault architecture
Engineering Repository architecture
TRX300 ground truth
electrical solver
existing OCR implementation
existing commit transaction semantics
unrelated Studio UI work
```

unless a direct, demonstrated contract mismatch requires it.

Any such mismatch must be reported in the AAR.

---

# 23. DOCUMENTATION

Add implementation documentation only where necessary to explain:

- UIF entry point;
- parser contract;
- ingestion lifecycle;
- provenance;
- TRX300 vertical slice;
- test invocation.

Do not duplicate the AP-INGEST-001 architecture specification.

If an implementation detail differs from the approved architecture, do not silently update the architecture document. Report it.

---

# 24. ACCEPTANCE GATE

The work is complete only when all of the following are true:

```text
[ ] UIF consumes a Vault Object contract.
[ ] IngestionRun exists with required lifecycle semantics.
[ ] Parser abstraction exists.
[ ] TRX300 PDF parser works.
[ ] Normalized extraction exists.
[ ] Existing OCR is integrated.
[ ] Existing entity extraction is integrated.
[ ] Relationship candidates are represented.
[ ] Knowledge Candidates are generated.
[ ] Provenance survives the complete extraction path.
[ ] Partial processing preserves successful results.
[ ] Knowledge Studio session integration works.
[ ] UIF does not directly commit repository objects.
[ ] Existing CommitTransactionService remains the write boundary.
[ ] TRX300 source/ground truth remain unchanged.
[ ] Automated tests pass.
[ ] Analysis passes with no newly introduced issues.
[ ] Windows debug build succeeds.
[ ] No unrelated working-tree changes are reverted.
[ ] AAR is produced.
```

---

# 25. AAR REQUIREMENT

At completion, produce an Architecture After-Action Report containing:

## Baseline

```text
starting commit SHA
branch
working-tree state
```

## Implemented

Exact:

```text
files created
files modified
interfaces added
models added
tests added
```

## Architecture Verification

Explicitly demonstrate:

```text
EAM boundary preserved
Reference Vault boundary preserved
UIF boundary implemented
Knowledge Studio boundary preserved
Repository commit boundary preserved
OCR reused
Entity extraction reused
Electrical solver untouched
```

## TRX300 Result

Report:

```text
input
stages executed
successful stages
partial/failed stages
candidate output
provenance verification
test results
```

Do not invent accuracy percentages unless an existing approved comparator provides them.

## Validation

Report exact commands and results:

```text
dart analyze
flutter build windows --debug
relevant test commands
```

## Working Tree

Report all remaining changes and distinguish:

```text
this work package
pre-existing user work
unrelated work
```

## Commit

Create a focused commit only after validation succeeds.

Commit message should follow the repository's established convention and clearly identify WP-INGEST-001.

Do not push unless explicitly instructed.

---

# 26. STOP CONDITIONS

Stop implementation and report if any of the following occurs:

1. The Reference Vault contract does not provide enough information to construct `VaultObjectInput`.
2. Existing OCR cannot be cleanly adapted without changing its architectural ownership.
3. Existing Engineering Entity Extraction cannot be reused without creating a duplicate subsystem.
4. Knowledge Studio cannot consume UIF output without violating the approved boundary.
5. Repository commit requires bypassing `CommitTransactionService`.
6. A database architecture decision becomes necessary that is not covered by AP-INGEST-001.
7. TRX300 ground truth must be changed to make tests pass.
8. The implementation requires changing the electrical solver.
9. The implementation requires broad unrelated refactoring.
10. The implementation would require changing the ratified architecture.

When a stop condition occurs, do not improvise.

Report:

```text
BLOCKED
Condition:
Evidence:
Affected architecture boundary:
Minimal decision required:
```

---

# 27. FINAL IMPLEMENTATION PRINCIPLE

Build the smallest complete vertical slice.

The target is not:

```text
"Build UIF."
```

The target is:

```text
"Prove the UIF boundary end-to-end with real OEP evidence,
real OCR, real engineering extraction, real provenance,
real candidates, and the existing Knowledge Studio/repository
boundaries."
```

The completed architecture should demonstrate:

```text
SOURCE EVIDENCE
      ↓
REFERENCE VAULT
      ↓
UIF
      ↓
STRUCTURED INFORMATION
      ↓
ENGINEERING KNOWLEDGE CANDIDATES
      ↓
KNOWLEDGE STUDIO
      ↓
ENGINEERING REVIEW
      ↓
COMMIT TRANSACTION
      ↓
ENGINEERING REPOSITORY
```

Do not broaden the mission.

Do not invent missing architecture.

Do not replace working OEP subsystems.

**Implement only what is necessary to prove this boundary.**
