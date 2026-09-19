# WP-INGEST-006 — Persistent Ingestion Run & Processing Provenance

## Mission

Implement durable ingestion execution history within the existing Knowledge
Session / Ingestion persistence domain.

WP-INGEST-005 established that the source material itself survives ingestion
and temporary-file cleanup.

The next gap is that the actual processing execution remains substantially
transient:

    IngestionRun
    StageResult[]
    DerivedArtifact[]
    pipeline identity
    parser identity/version
    processor identity/version
    processing configuration
    stage diagnostics

These currently exist as part of the in-memory UIF execution/result model,
but the system does not yet establish durable processing history sufficient
to reconstruct how a Knowledge Session's extracted results were produced.

The objective of this WP is NOT to redesign UIF.

The objective is to make the processing execution and its provenance
durable within the existing Knowledge Session / Ingestion persistence domain.

---

# 1. ARCHITECTURAL AUTHORITY

The ratified architecture contract is:

    docs/architecture/ingestion/AP-INGEST-001-UNIVERSAL-INGESTION-BOUNDARY.md

Relevant architectural rules:

    Reference Vault
        = evidence custody / immutable source

    UIF
        = ingestion orchestration / extraction / candidate production

    Knowledge Studio / Ingestion Session
        = mutable processing and review work

    Engineering Repository
        = accepted Engineering Objects / Relationships

The three persistence domains MUST remain separate.

Do not move ingestion history into:

    Reference Vault
    Engineering Repository

The correct conceptual location is:

    Knowledge Studio / Ingestion Session domain

---

# 2. MANDATORY FIRST STEP — REPOSITORY AUDIT

Before changing code:

    git status --short
    git rev-parse HEAD
    git branch --show-current

Record the starting commit.

Then inspect the CURRENT repository implementation, not assumptions from
older work packages.

Read:

    docs/architecture/ingestion/AP-INGEST-001-UNIVERSAL-INGESTION-BOUNDARY.md

Inspect:

    platform/oep_studio/lib/ingestion/models/
    platform/oep_studio/lib/ingestion/services/
    platform/oep_studio/lib/acquisition/services/reference_vault_ingestion_workflow.dart

    platform/oep_studio/lib/knowledge/models/knowledge_session_record.dart
    platform/oep_studio/lib/knowledge/services/knowledge_session_service.dart
    platform/oep_studio/lib/knowledge/services/knowledge_session_storage.dart

    platform/oep_studio/lib/core/services/foundation_runtime_service.dart

Inspect the complete serialization/deserialization path for:

    KnowledgeSessionRecord
    KnowledgeSession
    SourceMaterial
    OCR results
    candidates
    evidence
    engineering entities
    relationship candidates

Determine exactly how session state is persisted and reloaded.

Do NOT begin implementation until the existing persistence model is
understood.

---

# 3. CURRENT ARCHITECTURAL CONTRACT

AP-INGEST-001 defines the canonical processing stages:

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

Not every artifact must execute every stage.

The first TRX300 slice currently executes the subset authorized by
WP-INGEST-001.

Do not expand the executable stage set in this WP.

---

# 4. REQUIRED PERSISTENT INFORMATION

The durable ingestion record must preserve enough information to answer:

    What Vault evidence was processed?

    Which ingestion run produced this session?

    Which pipeline definition was used?

    Which parser and parser version were used?

    Which processor versions were used?

    Which processing configuration was used?

    Which stages executed?

    Which stages succeeded, partially succeeded, failed, or were skipped?

    When did each stage execute?

    What diagnostics were produced?

    Which processing identity does this run belong to?

The exact model shape should follow existing repository conventions.

Do not blindly copy the conceptual model into a new duplicate model if an
existing model can be extended appropriately.

---

# 5. PROCESSING IDENTITY

AP-INGEST-001 defines logical processing identity as incorporating:

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

The implementation must establish this identity explicitly.

Conceptually:

    ProcessingIdentity
        vaultObjectId
        contentHash/version
        pipelineVersion
        parserVersion(s)
        processorVersion(s)
        configuration identity

The implementation may use a deterministic canonical representation and
SHA-256/BLAKE3/etc. only if that follows existing OEP conventions.

Do NOT invent a proprietary hashing scheme.

The identity must be:

    deterministic
    reproducible
    independent of timestamps
    independent of generated session IDs
    independent of random UUIDs

For deterministic inputs:

    same evidence
    +
    same processing definition
    =
    same logical processing identity

A change in processing definition must produce a different identity.

---

# 6. IMPORTANT SCOPE DISTINCTION

This WP establishes processing identity.

This WP does NOT automatically implement a full deduplication policy.

Do NOT automatically:

    reject a second identical ingestion
    reuse an old Knowledge Session
    silently replace an existing run
    merge sessions
    cache ingestion results

unless the existing architecture already explicitly requires that behavior.

For this WP:

    processing identity
        =
    durable identity of the processing definition/input combination

Deduplication policy can be addressed separately.

---

# 7. INGESTION RUN PERSISTENCE

Determine the smallest correct way to persist an IngestionRun within the
existing Knowledge Session domain.

Preferred conceptual relationship:

    KnowledgeSession
        │
        └── IngestionRun
                │
                ├── processing identity
                ├── pipeline metadata
                ├── parser metadata
                ├── processor metadata
                └── StageResult[]

The exact implementation may differ if the existing persistence architecture
provides a better representation.

Do NOT create:

    PostgreSQL ingestion database
    separate ingestion repository
    second session database
    independent ingestion service

unless existing architecture explicitly requires it.

---

# 8. STAGE RESULT PERSISTENCE

Each executed stage should preserve:

    stage
    status
    startedAt
    completedAt
    diagnostics
    relevant processor/parser identity
    derived-artifact references where applicable

Required status semantics remain:

    SUCCESS
    PARTIAL
    FAILED
    SKIPPED

Use the repository's existing enum conventions.

Do not introduce a second stage-status vocabulary.

A stage that failed must remain distinguishable from a stage that was
legitimately skipped.

---

# 9. DERIVED ARTIFACT RELATIONSHIP

WP-INGEST-002 established DerivedArtifact as a first-class ingestion product.

The architecture defines:

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

The current implementation leaves DerivedArtifacts primarily attached to
the transient IngestionResult.

Determine whether this WP should persist:

    A. complete DerivedArtifact records

or

    B. durable references/manifest metadata sufficient to preserve processing
       provenance while leaving the actual derived products transient

Do NOT automatically create filesystem/database persistence for every
derived artifact.

The decision must be based on the current implementation and the actual
architecture contract.

At minimum, durable ingestion history must be able to state which derived
products were produced by which run/stage.

If the actual bytes remain transient, document that explicitly.

Do not claim durable artifact bytes when only metadata is persisted.

---

# 10. PROVENANCE CHAIN

Preserve the canonical chain:

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

Where an existing result already contains evidence locations, do not
duplicate them unnecessarily.

The goal is traceability, not redundant storage.

The final persisted Knowledge Session must retain enough linkage to answer:

    candidate/evidence
        →
    processing stage/run
        →
    source artifact

where the existing models already provide those relationships.

---

# 11. KNOWLEDGE SESSION INTEGRATION

The current flow is:

    ReferenceVaultIngestionWorkflow
        ↓
    IngestionOrchestrator
        ↓
    IngestionResult
        ↓
    IngestionKnowledgeSessionBridge
        ↓
    KnowledgeSessionRecord
        ↓
    Knowledge Studio

Extend this flow minimally.

The resulting session should know which ingestion execution produced its
initial imported state.

Prefer an explicit association rather than embedding unrelated execution
data into arbitrary candidate/evidence fields.

The session should remain the review boundary.

Do not create:

    IngestionReviewSession
    IngestionWorkspaceRecord
    parallel ingestion session model

---

# 12. SESSION RELOAD

After ingestion and session persistence:

    save session
    ↓
    dispose/reload session
    ↓
    restored KnowledgeSessionRecord

the ingestion execution metadata must still be available.

Verify that:

    run identity
    stage history
    processing identity
    source relationship
    candidate/evidence relationships

survive serialization and reload.

---

# 13. FAILURE SEMANTICS

Preserve AP-INGEST-001 semantics.

Example:

    Parser succeeds
    OCR partially succeeds
    Entity extraction succeeds
    Candidate generation succeeds

must remain:

    run = PARTIAL

with successful and failed stage information retained.

If a parser fails before normalized content exists:

    run = FAILED

The failed run's diagnostics must remain available where the session is
created/persisted according to existing workflow semantics.

Do not convert failure into success merely because a Knowledge Session
exists.

---

# 14. PARTIAL PROCESSING

Partial processing is an explicit architectural capability.

Do not discard:

    successful stage results
    successful OCR pages
    successful entities
    successful candidates
    diagnostics

simply because another stage failed.

The persisted run history should accurately represent what happened.

---

# 15. DETERMINISM

Processing identity must not include:

    timestamps
    random session IDs
    random UUIDs
    temporary filesystem paths

unless they are explicitly excluded from the canonical identity.

For identical processing inputs and definitions:

    ProcessingIdentity A == ProcessingIdentity B

For a changed processing definition:

    ProcessingIdentity A != ProcessingIdentity B

Add focused deterministic tests.

---

# 16. NO REPOSITORY WRITE

The ingestion workflow must still NOT call:

    CommitTransactionService
    CommitPlanService
    FoundationBridge repository-write APIs
    Engineering Repository persistence

The sequence remains:

    Extraction
        ↓
    Knowledge Session
        ↓
    Human Review
        ↓
    Commit Plan
        ↓
    CommitTransactionService
        ↓
    Engineering Repository

Ingestion history is processing provenance, not accepted engineering truth.

---

# 17. NO REFERENCE VAULT MUTATION

Reference Vault remains immutable.

This WP must not introduce:

    PUT
    PATCH
    DELETE

or equivalent Vault mutation.

The Vault Object remains the authoritative evidence source.

---

# 18. NO SECOND PERSISTENCE DOMAIN

Do not create a separate:

    ingestion.db
    ingestion repository
    ingestion PostgreSQL schema
    ingestion Vault
    ingestion filesystem root

unless the current architecture explicitly proves one is required.

The intended domain is:

    Knowledge Studio / Ingestion Session persistence

---

# 19. TEST PLAN

Create focused tests appropriate to the existing test architecture.

At minimum:

## TEST-006-001 — Ingestion Run persisted

Perform a valid ingestion.

Verify the resulting Knowledge Session contains durable ingestion-run
information.

## TEST-006-002 — Processing identity exists

Verify a completed run has a non-empty deterministic processing identity.

## TEST-006-003 — Processing identity deterministic

Run equivalent processing twice with identical:

    Vault identity
    content hash
    pipeline version
    parser versions
    processor versions
    configuration

Verify processing identity is identical.

## TEST-006-004 — Processing identity changes with definition

Change one processing-definition component, such as pipeline or processor
version.

Verify identity changes.

## TEST-006-005 — Timestamp independence

Verify changing run timestamps does not change processing identity.

## TEST-006-006 — Stage history persisted

Verify executed stages survive session persistence/reload.

## TEST-006-007 — Stage status preserved

Verify SUCCESS/PARTIAL/FAILED/SKIPPED semantics survive persistence.

## TEST-006-008 — Diagnostics preserved

Verify meaningful stage diagnostics survive session reload.

## TEST-006-009 — Partial run provenance

Force partial OCR or another supported partial condition.

Verify:

    run = PARTIAL

and successful/failed stage information remains available.

## TEST-006-010 — Source/run association

Verify the persisted run remains associated with the correct Vault-derived
SourceMaterial/session source.

## TEST-006-011 — Candidate provenance survives

Verify ingestion candidates remain associated with the session and their
existing evidence/provenance remains intact.

## TEST-006-012 — Derived artifact provenance

Verify each persisted derived-artifact reference/manifest, if implemented,
retains:

    runId
    stage
    vaultObjectId
    content hash
    processor identity/version

## TEST-006-013 — Session reload

Persist the Knowledge Session, reconstruct/reload it using the existing
session persistence mechanism, and verify ingestion metadata remains
available.

## TEST-006-014 — No repository write

Verify ingestion does not invoke repository commit infrastructure.

## TEST-006-015 — Reference Vault remains immutable

Verify the ingestion path performs no Vault mutation.

## TEST-006-016 — Failed processing history

Cause a supported processing failure and verify the resulting state
accurately records the failed stage/status without falsely reporting
COMPLETED.

---

# 20. EXISTING TEST REGRESSION

Run the focused ingestion/knowledge tests first.

Then run:

    flutter test

Then:

    dart analyze

Then:

    flutter build windows --debug

Compare against the established baseline.

Existing unrelated failures must be distinguished from failures introduced
by this WP.

Do not "fix" unrelated failures.

---

# 21. CODE DISCIPLINE

Keep the implementation narrowly scoped.

Do not:

    refactor unrelated services
    rename unrelated models
    reformat unrelated files
    modify UX
    modify Reference Vault server code
    modify the electrical solver
    introduce embeddings
    introduce chunking
    introduce distributed workers
    introduce queues
    introduce AI decision-making
    alter repository commit behavior

If an architectural blocker is discovered:

    STOP

and report the blocker instead of expanding the work package.

---

# 22. DOCUMENTATION

If the implementation establishes a persistent representation that differs
from the current AP-INGEST-001 wording, update/add the minimum architecture
documentation necessary to describe the actual implementation.

Do not rewrite the architecture contract unnecessarily.

Document explicitly:

    what is now durable
    what remains transient
    where ingestion history lives
    how processing identity is calculated
    how session reload restores ingestion history

If DerivedArtifact bytes remain transient, state that clearly.

---

# 23. ACCEPTANCE INVARIANTS

WP-INGEST-006 is COMPLETE only if all applicable invariants are satisfied:

1. Every Knowledge Session created by Reference Vault ingestion can identify
   its originating ingestion run.

2. Processing identity is explicit and deterministic.

3. Processing identity includes the architecture-required processing
   definition components.

4. Processing identity excludes runtime-only values such as timestamps and
   random session IDs.

5. Stage execution history survives Knowledge Session persistence/reload.

6. Stage success/failure/partial/skipped semantics survive persistence.

7. Diagnostics remain available after reload.

8. PARTIAL processing remains accurately represented.

9. Existing candidate/evidence/provenance relationships remain intact.

10. Reference Vault remains immutable.

11. UIF remains responsible for orchestration and extraction.

12. Knowledge Studio remains responsible for review.

13. Engineering Repository remains responsible for accepted engineering
    knowledge.

14. No direct UIF → Repository commit path exists.

15. No second ingestion persistence domain is introduced.

16. No second review/session subsystem is introduced.

17. No automatic deduplication policy is silently introduced.

18. The implementation does not require embeddings/chunking/distributed
    processing.

---

# 24. FINAL VALIDATION REPORT

Return exactly:

## WP-INGEST-006 Implementation Report

### Baseline
- Starting commit
- Branch

### Final Commit
- Commit SHA
- Commit message

### Files Changed
Exact file list.

### Persistent Model
Describe exactly what became durable.

### Processing Identity
Describe:

    inputs
    canonicalization
    hashing/identity mechanism
    determinism guarantees

### Run Lifecycle

Show:

    Reference Vault
        ↓
    IngestionRun
        ↓
    Stage Results
        ↓
    IngestionResult
        ↓
    Knowledge Session
        ↓
    persistent session state

### Derived Artifacts
State explicitly:

    persistent
or
    transient with durable provenance/reference

Do not overstate durability.

### Provenance
Show the actual implemented chain.

### Tests
List:

    TEST-006-001
    ...
    TEST-006-016

with PASS/FAIL.

### Regression
Report:

    flutter test
    dart analyze
    flutter build windows --debug

Include comparison to baseline.

### Architecture Impact

Explicitly state whether each changed:

    Reference Vault
    Acquisition layer
    UIF
    Knowledge Session
    Knowledge Studio
    Engineering Repository

### Limitations

Only actual remaining limitations.

### Final Disposition

Use exactly one:

    COMPLETE

or:

    BLOCKED

Do not declare COMPLETE if an acceptance invariant is unmet.

---

# FINAL RULE

This is an architecture-preserving persistence WP.

The objective is NOT "more ingestion."

The objective is:

    make the ingestion execution itself reconstructable.

Do not expand the scope beyond that.