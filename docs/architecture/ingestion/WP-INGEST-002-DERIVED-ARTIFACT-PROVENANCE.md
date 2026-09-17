# WP-INGEST-002 — DERIVED ARTIFACT & PROVENANCE
## Implementation Work Package

**Target Repository:** `davidmhuitt86/open_engineering_platform`  
**Architecture Basis:** Ratified `AP-INGEST-001 — Universal Ingestion Boundary`  
**Predecessor:** `WP-INGEST-001` — accepted/frozen at `b327b047ec0c57f5e56ebef9be80173f55d30bdf`  
**Status:** IMPLEMENTATION AUTHORIZED  
**Scope:** Operationalize Derived Artifact and processing provenance  
**Primary Acceptance Dataset:** TRX300 Factory Wiring Diagram

---

# 1. Mission

Operationalize the `DerivedArtifact` and `IngestionProvenance` contracts established by AP-INGEST-001 and implemented structurally by WP-INGEST-001.

The objective is NOT to redesign UIF.

The objective is to make derived processing products first-class, traceable, and reproducible within the existing ingestion result/session architecture.

The target is:

```text
Reference Evidence
      ↓
Ingestion Run
      ↓
Processing Stage
      ↓
Derived Artifact
      ↓
Evidence Location
```

with sufficient metadata to answer:

```text
What evidence produced this result?
Which ingestion run produced it?
Which processing stage produced it?
Which processor/parser/version produced it?
Where in the source did it originate?
```

---

# 2. FROZEN PREDECESSOR

`WP-INGEST-001` is accepted and frozen.

Do NOT reopen or redesign:

```text
VaultObjectInput
IngestionRun
IngestionParser
PdfIngestionParser
IngestionOrchestrator
OcrPipelineService
EngineeringEntityExtractionService
KnowledgeCandidate
KnowledgeSessionRecord
CommitPlanService
CommitTransactionService
TRX300 ground truth
```

unless the audit demonstrates a direct contract defect.

If a predecessor defect is discovered:

```text
STOP
Document the defect.
Do not silently repair architecture outside this work package.
```

---

# 3. FIRST ACTION — READ-ONLY AUDIT

Before modifying anything:

```text
git status --short
git rev-parse HEAD
git branch --show-current
```

Confirm the current WP-INGEST-001 implementation exists.

Inspect:

```text
platform/oep_studio/lib/ingestion/
platform/oep_studio/test/ingestion/
platform/oep_studio/lib/knowledge/
services/acquisition/
reference/ingestion/trx300/
docs/architecture/ingestion/
```

Specifically locate and inspect:

```text
DerivedArtifact
IngestionProvenance
IngestionResult
IngestionRun
StageResult
IngestionOrchestrator
OcrPageResult
EngineeringEntity
EvidenceRegion
EvidenceLink
KnowledgeCandidate
KnowledgeSessionRecord
KnowledgeSessionStorage
```

Also search repository-wide for existing persistence/caching mechanisms that could already own derived products.

Do not create persistence until this audit is complete.

---

# 4. WORKING-TREE SAFETY

There are known unrelated OEP Studio UX changes in the working tree.

Do not:

```text
reset
clean
checkout unrelated files
revert unrelated changes
format unrelated files
overwrite user work
```

Preserve all pre-existing changes.

At completion report:

```text
starting SHA
ending SHA
files changed by WP-INGEST-002
pre-existing unrelated changes
```

---

# 5. ARCHITECTURAL OBJECTIVE

The current WP-INGEST-001 implementation contains a `DerivedArtifact` model, but the audit identified that the orchestrator does not yet operationally populate:

```text
IngestionResult.derivedArtifacts
```

This work package addresses that gap.

The target is:

```text
IngestionResult
├── run
├── structuralData
├── source
├── derivedArtifacts[]
├── ocrPageResults[]
├── engineeringEntities[]
├── evidenceRegions[]
├── evidenceLinks[]
├── knowledgeCandidates[]
└── relationshipCandidates[]
```

Do not duplicate existing product models merely to populate this collection.

---

# 6. DERIVED ARTIFACT DEFINITION

A Derived Artifact is a processing product produced from immutable engineering evidence.

Conceptual contract:

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

This contract is authoritative.

Existing implementation naming may be retained where compatible.

---

# 7. DERIVED ARTIFACT IDENTITY

A derived artifact must have a stable logical identity sufficient to distinguish:

```text
source evidence
+
processing run
+
processing stage
+
processor identity/version
+
derived content
```

Do not make wall-clock timestamps the sole identity mechanism.

Do not require random UUIDs for reproducibility.

Existing application-generated IDs may remain for workspace objects, but the derived-artifact contract must retain content and processing identity.

---

# 8. CONTENT HASH

Every persisted/represented Derived Artifact must have a content hash.

Use the repository's established hashing convention where possible.

Do not introduce a second hashing algorithm without architectural justification.

The hash must represent the actual derived product content where the product has material content.

For metadata-only processing records where there is no separate materialized byte artifact, explicitly document what the `contentHash` represents.

Do not fabricate a hash.

---

# 9. PROCESSOR IDENTITY

Each derived product must identify the processor that produced it.

At minimum:

```text
processorId
processorVersion
```

Where applicable also retain:

```text
parserId
parserVersion
pipelineVersion
```

Use the existing `IngestionProvenance` model rather than introducing a second processor-version model.

---

# 10. PROVENANCE

The canonical chain remains:

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

Do not collapse these levels.

A Derived Artifact must retain enough provenance to trace it to:

```text
vaultObjectId
runId
stage
processor
processorVersion
parser
parserVersion
pipelineVersion
```

Where applicable, source evidence location must retain:

```text
page
boundingBox
characterStart
characterEnd
sourceFingerprint
```

Reuse existing source-location structures.

---

# 11. DO NOT DUPLICATE PROVENANCE

Existing models already contain evidence provenance.

Examples:

```text
OcrPageResult
EngineeringEntity
EvidenceRegion
EvidenceLink
```

Do not add redundant provenance fields to all of these models unless required by an actual contract gap.

The preferred model is:

```text
DerivedArtifact
    ↓
IngestionProvenance
    ↓
existing evidence-location model
```

rather than several competing provenance systems.

---

# 12. PRODUCT MAPPING

Determine which first-slice outputs qualify as Derived Artifacts.

At minimum audit these:

```text
NormalizedDocument
OCR results
Engineering Entity extraction
Candidate generation
Relationship extraction
```

Do not automatically classify every object as a Derived Artifact.

The implementation must document the mapping.

A reasonable first-slice mapping may be:

```text
CONTENT_EXTRACTION
    → normalized content artifact

STRUCTURAL_ANALYSIS
    → normalized structural artifact

OCR
    → OCR-derived artifact(s)

ENTITY_EXTRACTION
    → entity extraction artifact

RELATIONSHIP_EXTRACTION
    → relationship extraction artifact

CANDIDATE_GENERATION
    → candidate-generation artifact
```

Use the actual repository models and actual materialized products rather than inventing byte artifacts where none exist.

---

# 13. OCR PRODUCT HANDLING

Reuse:

```text
OcrPageResult
```

Do not replace it.

If an OCR page result qualifies as a Derived Artifact, establish the association without creating a duplicate OCR result model.

The relationship should be conceptually:

```text
DerivedArtifact
    └── references / represents
          ↓
       OcrPageResult
```

The implementation may choose a repository-native representation, provided it does not duplicate the OCR model.

The original `OcrPageResult` behavior must remain unchanged.

---

# 14. ENGINEERING ENTITY PRODUCT HANDLING

Reuse:

```text
EngineeringEntity
```

Do not create:

```text
UifEngineeringEntity
```

or an equivalent duplicate.

A Derived Artifact or derived-product record may identify the entity extraction result while the actual entities remain the existing Knowledge Studio model.

Preserve:

```text
sourceId
page
boundingBox
sourceFingerprint
```

and the new processing provenance.

---

# 15. CANDIDATE PRODUCT HANDLING

Candidates remain:

```text
KnowledgeCandidateStatus.pending
```

They are not Engineering Objects.

Derived-artifact representation must never imply candidate acceptance.

The boundary remains:

```text
Extraction
    ↓
Candidate
    ↓
Human Review
    ↓
Commit
```

No new commit dependency may be introduced.

---

# 16. RELATIONSHIP PRODUCT HANDLING

Preserve the existing relationship representation.

The current first slice uses deterministic same-page candidate relationships because the existing `RelationshipCandidate` model requires candidate IDs.

Do not turn the heuristic into a claim of actual engineering topology.

The Derived Artifact/provenance work must preserve the existing disclosed limitation.

Do not implement schematic topology extraction in this work package.

---

# 17. INGESTION RESULT

Operationally populate:

```text
IngestionResult.derivedArtifacts
```

for the products selected by the product-mapping audit.

Every populated artifact must have:

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

If a product cannot legitimately satisfy those fields, do not force it into the Derived Artifact collection.

Document the reason.

---

# 18. STAGE RESULT LINKAGE

Where a Derived Artifact is created by a stage:

```text
StageResult.derivedArtifactIds[]
```

must contain its identifier.

Therefore the linkage becomes:

```text
IngestionRun
  ↓
StageResult
  ↓
DerivedArtifact
```

This must work bidirectionally at the data-model level:

```text
StageResult → artifact IDs
DerivedArtifact → run/stage
```

Do not create circular object references merely for convenience.

Use identifiers.

---

# 19. KNOWLEDGE SESSION BOUNDARY

Do not automatically make every Derived Artifact a new `KnowledgeSessionRecord` field.

First determine whether the existing session model already has an appropriate place for the derived products.

The current session contains:

```text
ocrPageResults
engineeringEntities
evidenceRegions
evidenceLinks
candidates
relationshipCandidates
```

Preserve this existing contract.

If the Derived Artifact itself needs session persistence for provenance/reproducibility, introduce the smallest compatible extension.

Do not create:

```text
UifSession
IngestionReviewSession
DerivedArtifactSession
```

or another parallel session system.

---

# 20. PERSISTENCE DECISION

This work package does NOT authorize creating a new database automatically.

Determine ownership first:

```text
Reference Vault
    Evidence / durable derived evidence

Ingestion Domain
    Processing records / ingestion identity

Knowledge Session
    Mutable curation workspace

Engineering Repository
    Accepted engineering knowledge
```

If the first vertical slice can operate correctly with serialized/in-memory `IngestionResult` plus existing Knowledge Session persistence, prefer that over adding PostgreSQL.

If durable Derived Artifact persistence is genuinely required:

1. identify the owning subsystem;
2. document why existing persistence is insufficient;
3. define schema ownership;
4. define migration impact;
5. preserve immutability/versioning;
6. obtain an architecture stop/decision if this exceeds AP-INGEST-002.

Do not create a second Foundation database.

---

# 21. REPRODUCIBILITY

Processing identity must preserve:

```text
contentHash
pipelineVersion
parserId
parserVersion
processorId
processorVersion
processingConfiguration
```

Repeated deterministic processing should produce equivalent derived content.

Generated IDs and timestamps do not need to be identical if the actual derived content and processing identity are equivalent.

Tests must compare meaningful output, not incidental runtime identity.

---

# 22. REGENERATION

Define the rule:

```text
Same source evidence
+
same processor definition
+
same configuration
=
eligible for reuse
```

A change to:

```text
source content
parser
parser version
processor
processor version
pipeline
processing configuration
```

must invalidate/reclassify the previous result as appropriate.

Do not silently overwrite a historical result.

---

# 23. IMMUTABILITY

Once a Derived Artifact is created, do not mutate its historical meaning.

If regeneration occurs:

```text
old DerivedArtifact
      +
new processing identity
      ↓
new DerivedArtifact
```

Do not overwrite the previous result.

The original source evidence remains immutable.

---

# 24. TRX300 ACCEPTANCE

Use the existing:

```text
reference/ingestion/trx300/
```

dataset.

Do not modify:

```text
source/trx300_factory_wiring_diagram.pdf
ground_truth/
mappings/
annotations/
validation/
```

The acceptance run must demonstrate:

```text
TRX300 PDF
    ↓
IngestionRun
    ↓
Processing Stages
    ↓
DerivedArtifacts[]
    ↓
Provenance
    ↓
Knowledge Candidates
```

The test must be able to identify at least one derived product and trace it through the processing chain.

---

# 25. REQUIRED TESTS

Add focused automated tests.

### TEST-DA-001 — Derived Artifact Creation

A successful TRX300 ingestion produces the expected Derived Artifact records.

### TEST-DA-002 — Stage Linkage

Each created Derived Artifact is linked from its originating `StageResult`.

### TEST-DA-003 — Run Linkage

Each Derived Artifact points to the correct `runId`.

### TEST-DA-004 — Vault Identity

Each Derived Artifact points to the correct `vaultObjectId`.

### TEST-DA-005 — Processor Identity

Each Derived Artifact identifies the processor/version that produced it.

### TEST-DA-006 — Provenance

A Derived Artifact can be traced:

```text
Vault Object
→ Ingestion Run
→ Stage
→ Derived Artifact
→ Source Location
```

where a source location exists.

### TEST-DA-007 — Content Identity

Derived Artifact content hashes are non-empty and correspond to the represented derived product where material content exists.

### TEST-DA-008 — No Source Mutation

TRX300 source bytes remain unchanged.

### TEST-DA-009 — Partial Run Preservation

The existing partial-processing behavior continues to preserve successful Derived Artifacts.

### TEST-DA-010 — Deterministic Reprocessing

Equivalent deterministic runs produce equivalent derived content/processing identity.

### TEST-DA-011 — Historical Separation

A changed processing identity does not overwrite the previous derived result.

### TEST-DA-012 — Knowledge Session Compatibility

Existing Knowledge Studio session integration continues to work without losing existing OCR/entity/candidate/evidence state.

---

# 26. TEST ENVIRONMENT

Do not make Tesseract installation a code requirement.

The existing OCR integration already supports injected test runners.

Use:

```text
real OCR integration test
+
deterministic fake OCR tests
```

as appropriate.

If Tesseract is unavailable, report that environment limitation rather than altering production OCR behavior.

---

# 27. ANALYSIS AND BUILD

After focused tests:

```text
flutter test
dart analyze
flutter build windows --debug
```

Use the repository's actual working commands if they differ.

Report:

```text
pre-existing issues
new issues
test results
build result
```

Do not classify pre-existing analyzer issues as regressions.

---

# 28. FILE DISCIPLINE

Prefer:

```text
new/modified files inside platform/oep_studio/lib/ingestion/
new/modified focused tests
```

Avoid modifying existing Knowledge models unless the audit proves a necessary compatibility extension.

Do not modify:

```text
TRX300 ground truth
electrical solver
OCR implementation
Engineering Entity Extraction implementation
CommitTransactionService
Reference Vault source artifacts
unrelated OEP Studio UX work
```

without a demonstrated contract requirement.

---

# 29. DOCUMENTATION

Document only implementation details necessary to explain:

- Derived Artifact mapping;
- provenance linkage;
- identity/hash rules;
- persistence ownership;
- regeneration semantics;
- known limitations.

Do not rewrite AP-INGEST-001 from the implementation.

If the implementation reveals an architecture contradiction:

```text
STOP
Report it.
Do not silently amend AP-INGEST-001.
```

---

# 30. STOP CONDITIONS

Stop and report if:

1. Derived Artifact persistence requires a new database architecture.
2. Reference Vault integration becomes necessary to complete the work.
3. Existing Knowledge Session models cannot represent the required state without architectural redesign.
4. Existing OCR/entity models must be replaced.
5. Commit infrastructure must be changed.
6. TRX300 ground truth must be modified.
7. A new competing provenance system is required.
8. The implementation requires broad refactoring outside UIF.
9. The approved AP-INGEST-001 contract must change.

Use:

```text
BLOCKED

Condition:
Evidence:
Affected boundary:
Minimal decision required:
```

---

# 31. AAR REQUIREMENT

At completion produce:

## Baseline

```text
starting SHA
branch
working-tree state
```

## Implementation

List:

```text
files created
files modified
models changed
services changed
tests added
```

## Derived Artifact Mapping

Explicitly document:

```text
stage
→ derived product
→ representation
→ provenance
```

for every first-slice product.

## Provenance Verification

Demonstrate:

```text
Vault Object
→ Run
→ Stage
→ Derived Artifact
→ Evidence Location
```

## Persistence Decision

State exactly where the Derived Artifact information lives and why.

## Regeneration

Document the processing identity and reuse/invalidation rule.

## TRX300

Report:

```text
source
run
stages
derived artifacts
provenance
partial behavior
```

## Validation

Report exact commands:

```text
flutter test
dart analyze
flutter build windows --debug
```

and results.

## Working Tree

Separate:

```text
WP-INGEST-002 changes
pre-existing changes
unrelated changes
```

## Commit

Create one focused commit after validation succeeds.

Suggested commit convention:

```text
feat(ingestion): operationalize derived artifacts and provenance
```

Do not push unless explicitly instructed.

---

# 32. FINAL ACCEPTANCE GATE

WP-INGEST-002 is complete only when:

```text
[ ] DerivedArtifact is operationally populated.
[ ] StageResult links to DerivedArtifact IDs.
[ ] DerivedArtifact links to run/stage.
[ ] Vault identity is preserved.
[ ] Processor identity is preserved.
[ ] Provenance is complete for represented products.
[ ] Content identity is meaningful.
[ ] Existing OCR model is reused.
[ ] Existing EngineeringEntity model is reused.
[ ] Existing KnowledgeCandidate model is reused.
[ ] Existing KnowledgeSessionRecord remains the review boundary.
[ ] No repository commit path was introduced.
[ ] Source evidence remains immutable.
[ ] Regeneration semantics are defined.
[ ] TRX300 acceptance passes.
[ ] Partial processing remains intact.
[ ] Deterministic reprocessing is verified.
[ ] No unrelated changes are reverted.
[ ] AAR is produced.
[ ] Focused commit is created.
```

---

# 33. FINAL PRINCIPLE

This work package is about making provenance and derived products **real**, not merely modeled.

The desired architecture is:

```text
IMMUTABLE EVIDENCE
        ↓
INGESTION RUN
        ↓
PROCESSING STAGE
        ↓
DERIVED ARTIFACT
        ↓
EVIDENCE LOCATION
        ↓
KNOWLEDGE CANDIDATE
        ↓
HUMAN REVIEW
        ↓
ENGINEERING REPOSITORY
```

Do not turn derived extraction into engineering truth.

Do not create parallel persistence systems without architectural authorization.

Do not reopen the completed UIF vertical slice.

**Operationalize the existing contract, prove it with TRX300, preserve provenance, and keep the architecture narrow.**
