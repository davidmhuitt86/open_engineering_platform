# WP-INGEST-004 — Reference Vault Ingestion Workflow

## IMPLEMENTATION AUTHORITY

Repository:
    davidmhuitt86/open_engineering_platform

Current baseline:
    5e5935cdeb9ce280cbe6bdd595895ff819328e51

Baseline commit:
    feat(ingestion): connect UIF to Reference Vault boundary

This work package follows:

    AP-INGEST-001 — Universal Ingestion Framework
    WP-INGEST-001 — First UIF vertical slice
    WP-INGEST-002 — Derived Artifact / Provenance
    AP-INGEST-003 — Reference Vault → UIF Boundary
    WP-INGEST-003 — Reference Vault boundary implementation

Read and obey the repository's applicable engineering/UI skills before modifying code.

======================================================================
1. OBJECTIVE
======================================================================

Implement the missing PRODUCTION WORKFLOW connecting the already-existing:

    Reference Vault
        ↓
    AcquisitionApiClient
        ↓
    ReferenceVaultAdapter
        ↓
    VaultObjectInput
        ↓
    IngestionOrchestrator
        ↓
    IngestionResult
        ↓
    Knowledge Session
        ↓
    Knowledge Studio Review

The purpose of this work package is workflow integration.

This is NOT a new ingestion engine.

This is NOT a Reference Vault redesign.

This is NOT a Knowledge Studio redesign.

This is NOT a repository persistence implementation.

The underlying systems already exist.

The missing piece is the production application workflow that invokes them together and presents the resulting ingestion session to Knowledge Studio.

======================================================================
2. ARCHITECTURAL INVARIANTS
======================================================================

These are HARD constraints.

DO NOT violate them.

### 2.1 Ownership

EAM owns:

    acquisition
    source verification
    Reference Vault custody
    Acquisition Records

Reference Vault owns:

    permanent evidence artifacts
    immutable evidence identity

UIF owns:

    identification
    parsing
    extraction
    normalization
    ingestion orchestration
    candidate generation
    derived-artifact production
    ingestion provenance

Knowledge Studio owns:

    human inspection
    curation
    review
    accept/reject/edit decisions

Engineering Repository owns:

    accepted Engineering Objects
    accepted Relationships
    revisions
    commits

The workflow being implemented must not transfer ownership between these systems.

----------------------------------------------------------------------
2.2 UIF MUST REMAIN SOURCE-AGNOSTIC
----------------------------------------------------------------------

The UIF must continue consuming:

    VaultObjectInput

It must NOT know about:

    AcquisitionApiClient
    ReferenceVaultAdapter
    EAM HTTP
    Knowledge Studio widgets
    Foundation persistence
    Repository commits

The new workflow may call the adapter and then pass the resulting
VaultObjectInput into the existing IngestionOrchestrator.

Do not modify UIF merely to accommodate the workflow unless a genuine
integration defect is discovered.

----------------------------------------------------------------------
2.3 NO SECOND IMPLEMENTATION
----------------------------------------------------------------------

Do NOT create:

    another OCR pipeline
    another parser
    another candidate generator
    another Reference Vault client
    another Vault storage layer
    another ingestion orchestrator
    another Knowledge Session model
    another review subsystem
    another repository commit path

Reuse the existing implementations.

----------------------------------------------------------------------
2.4 NO UIF → FOUNDATION DIRECT PATH
----------------------------------------------------------------------

The allowed conceptual boundary is:

    UIF
      ↓
    IngestionResult
      ↓
    Knowledge Studio/session bridge
      ↓
    Human review
      ↓
    Existing commit pipeline

There must be NO:

    UIF → FoundationBridge
    UIF → Repository
    UIF → CommitTransactionService

The ingestion workflow must not bypass human review.

======================================================================
3. EXISTING COMPONENTS — DO NOT DUPLICATE
======================================================================

The following already exist and must be reused.

### Reference Vault

Existing production boundary:

    AcquisitionApiClient
    ReferenceVaultAdapter
    DownloadedVaultArtifact

The adapter already:

    retrieves Vault Entry metadata
    downloads the artifact
    verifies X-Checksum-Sha256
    cross-checks the Vault Entry SHA-256
    resolves Acquisition Record provenance
    materializes a temporary artifact
    constructs VaultObjectInput
    maps MIME type to ArtifactType
    preserves immutable metadata snapshot
    provides temporary cleanup

Reuse it.

Do not move EAM HTTP behavior into the new workflow.

----------------------------------------------------------------------
### UIF

Existing:

    IngestionOrchestrator
    VaultObjectInput
    IngestionRun
    IngestionResult
    DerivedArtifact
    IngestionProvenance
    stage processing
    PDF parser
    OCR reuse
    engineering entity extraction
    relationship candidate generation
    Knowledge Candidate generation

Reuse the existing orchestrator.

Do not reproduce its internal stages in the workflow.

----------------------------------------------------------------------
### Knowledge Session

Existing:

    KnowledgeSession
    KnowledgeSessionRecord
    KnowledgeSessionStorage
    KnowledgeSessionService
    FoundationRuntimeNotifier
    FoundationServiceState
    IngestionKnowledgeSessionBridge

The repository already has the integration model which converts
IngestionResult into the existing Knowledge Studio session representation.

Reuse it.

Do not create a parallel ingestion-session model.

----------------------------------------------------------------------
### Knowledge Studio

Existing production workspace:

    KnowledgeStudioPage

Existing panels include:

    Import Queue
    Source Viewer
    AI Suggestions
    Repository Matches
    Engineering Review
    Commit Summary

Do not redesign this workspace as part of this WP.

======================================================================
4. TARGET WORKFLOW
======================================================================

The production workflow shall be:

    User selects Reference Vault artifact
                ↓
    Workflow receives vaultObjectId
                ↓
    ReferenceVaultAdapter.materialize(...)
                ↓
    VaultObjectInput
                ↓
    IngestionOrchestrator.run(...)
                ↓
    IngestionResult
                ↓
    IngestionKnowledgeSessionBridge
                ↓
    Existing Knowledge Session state
                ↓
    Knowledge Studio
                ↓
    Human review

The workflow should preserve the distinction:

    Vault Object
        ≠
    Ingestion Run
        ≠
    Knowledge Session

The relationship is:

    Vault Object
        ↓
    Ingestion Run
        ↓
    Ingestion Result
        ↓
    Knowledge Session

======================================================================
5. FIRST TASK — REPOSITORY RECONNAISSANCE
======================================================================

Before modifying code:

1. Inspect the current implementations of:

       ReferenceVaultAdapter
       AcquisitionApiClient
       VaultObjectInput
       IngestionOrchestrator
       IngestionResult
       IngestionKnowledgeSessionBridge
       KnowledgeSession
       KnowledgeSessionStorage
       FoundationRuntimeNotifier
       KnowledgeStudioPage

2. Search all production call sites for:

       IngestionOrchestrator.run
       IngestionKnowledgeSessionBridge
       ReferenceVaultAdapter.materialize
       VaultObjectInput.fromFile
       attachSourceMaterial
       createKnowledgeSession

3. Determine the cleanest existing application-level insertion point.

4. Do NOT create a new architecture merely because an existing class name
   seems imperfect.

5. Report the discovered integration point before implementation in your
   implementation notes/commit description.

The repository is the source of truth.

======================================================================
6. PRODUCTION WORKFLOW SERVICE
======================================================================

If no existing suitable orchestration service exists, introduce ONE
small application-level workflow service.

A suitable conceptual responsibility is:

    Reference Vault Ingestion Workflow

The final class name should follow existing repository naming conventions.

Its responsibility is ONLY:

    Vault Entry ID
        ↓
    ReferenceVaultAdapter
        ↓
    IngestionOrchestrator
        ↓
    IngestionKnowledgeSessionBridge
        ↓
    Knowledge Session

It may coordinate these components.

It must NOT absorb their responsibilities.

----------------------------------------------------------------------
Required behavior
----------------------------------------------------------------------

The workflow must:

1. Accept a Reference Vault object identity.

2. Materialize the immutable Vault artifact through:

       ReferenceVaultAdapter.materialize(...)

3. Pass the resulting:

       VaultObjectInput

   to:

       IngestionOrchestrator.run(...)

4. Receive:

       IngestionResult

5. Convert/bridge the result through the existing:

       IngestionKnowledgeSessionBridge

6. Populate the existing Knowledge Session model/state.

7. Make the resulting session available to Knowledge Studio.

8. Clean up the temporary materialized artifact after processing when
   appropriate.

9. Preserve partial ingestion results when the existing orchestrator
   reports PARTIAL.

10. Preserve all existing provenance and artifact information.

======================================================================
7. KNOWLEDGE SESSION SEMANTICS
======================================================================

The workflow must NOT silently destroy an unrelated active session.

Determine how the existing Knowledge Session lifecycle handles:

    active session
    new session
    replacement
    persistence
    session identity

Then implement the smallest behavior consistent with those existing
semantics.

If the existing bridge is explicitly designed to create/populate a
session from IngestionResult, use that mechanism.

Do not invent a second session lifecycle.

If a new session is required for each ingestion, use the existing
KnowledgeSession construction/storage mechanisms.

If an existing session can receive ingestion results, preserve that
architecture.

Do not modify session persistence schema for this WP unless absolutely
required by an existing architectural contract.

======================================================================
8. UI INTEGRATION
======================================================================

The user needs a production entry point to initiate Reference Vault
ingestion.

Use an existing appropriate Knowledge Studio / Reference Vault surface
if one exists.

Do NOT create an entire new Studio.

Do NOT redesign Knowledge Studio.

Do NOT create a second Import Queue architecture.

The intended UX concept is:

    Reference Vault artifact
          ↓
    "Ingest into Knowledge Studio"
          ↓
    ingestion progress/result
          ↓
    Knowledge Studio session

The exact widget/location must follow the existing UI architecture and
repository patterns.

If the current Reference Vault UI does not have a suitable production
entry point, create the smallest appropriate entry point.

The new UI must call the application workflow service rather than
directly chaining:

    Adapter
    Orchestrator
    Bridge

inside a widget.

UI should orchestrate user interaction.

The workflow service should orchestrate ingestion.

======================================================================
9. INGESTION STATE / ERROR HANDLING
======================================================================

The workflow must distinguish at minimum:

    loading/materializing
    ingesting
    completed
    partial
    failed

Do not introduce a new global state architecture if the repository
already has an appropriate operation/progress mechanism.

Use existing OperationManager or equivalent infrastructure where
appropriate.

Errors must preserve useful technical distinctions.

Examples:

    Reference Vault retrieval failure
    checksum/integrity failure
    unsupported MIME / ArtifactType
    Acquisition Record/provenance failure
    parser failure
    OCR partial failure
    entity extraction failure
    candidate generation failure
    session bridge failure

Do not catch everything and convert it to an opaque generic error.

A failed ingestion must not be presented as successfully ingested.

A PARTIAL ingestion must remain identifiable as PARTIAL.

======================================================================
10. TEMPORARY ARTIFACT LIFECYCLE
======================================================================

ReferenceVaultAdapter currently materializes artifacts into temporary
storage.

The workflow owns the lifecycle of the materialized temporary input
after the adapter returns it.

Ensure cleanup occurs:

    after successful ingestion
    after partial ingestion
    after failure

Use try/finally semantics or the repository's equivalent.

Do not delete anything from Reference Vault.

Do not modify the original Vault artifact.

Do not treat the temporary materialization as permanent evidence.

======================================================================
11. IDEMPOTENCY / REPEAT INGESTION
======================================================================

Do not invent a new persistence table for idempotency.

The existing ingestion architecture already defines logical identity
around Vault identity/content/version/pipeline/parser/processor/config.

Respect the existing model.

For this WP:

    repeated invocation must not mutate the Vault artifact
    repeated invocation must not corrupt an existing session
    repeated invocation must produce an independent IngestionResult unless
    existing session semantics explicitly dictate otherwise

Do not add persistence merely to claim idempotency.

======================================================================
12. REPOSITORY BOUNDARY
======================================================================

This WP MUST NOT commit Engineering Objects or Relationships.

The resulting path is:

    IngestionResult
        ↓
    Knowledge Studio
        ↓
    Human Review
        ↓
    Existing Commit Pipeline

The workflow may populate candidate/session state.

It must NOT automatically call:

    CommitTransactionService
    CommitPlanService
    FoundationBridge repository write APIs

unless an already-existing user-initiated review action explicitly
does so after the ingestion workflow completes.

Ingestion itself is not approval.

======================================================================
13. REFERENCE VAULT PROVENANCE
======================================================================

Preserve the existing provenance chain:

    Vault Object
        ↓
    Acquisition Record
        ↓
    Ingestion Run
        ↓
    Stage
        ↓
    Derived Artifact
        ↓
    Evidence Location

Do not flatten this into:

    "source = PDF"

The Knowledge Session representation must retain enough information
for existing Evidence Browser / Provenance Explorer functionality to
continue working.

======================================================================
14. TRX300 VERTICAL SLICE
======================================================================

The existing TRX300 PDF remains the canonical first production-style
test fixture.

The end-to-end test should exercise:

    Vault artifact representation
        ↓
    ReferenceVaultAdapter
        ↓
    VaultObjectInput
        ↓
    real IngestionOrchestrator
        ↓
    IngestionResult
        ↓
    existing Knowledge Session bridge

Mock only external transport where necessary.

Do NOT mock the UIF itself.

Do NOT create a fake second ingestion implementation.

The test should prove the production application workflow, not merely
repeat existing unit tests.

======================================================================
15. TEST REQUIREMENTS
======================================================================

Add focused tests for:

### TEST-004-001
Workflow accepts a Vault Object ID.

### TEST-004-002
Workflow invokes ReferenceVaultAdapter.

### TEST-004-003
Adapter-produced VaultObjectInput reaches the existing
IngestionOrchestrator.

### TEST-004-004
IngestionResult reaches the existing Knowledge Session bridge.

### TEST-004-005
Knowledge Session contains the resulting candidates/source/evidence
expected from the existing ingestion pipeline.

### TEST-004-006
Reference Vault integrity failure prevents ingestion.

### TEST-004-007
Unsupported artifact type prevents ingestion.

### TEST-004-008
PARTIAL ingestion remains PARTIAL and preserves existing intermediate
results.

### TEST-004-009
Temporary materialization is cleaned up on success.

### TEST-004-010
Temporary materialization is cleaned up on failure.

### TEST-004-011
No repository commit occurs during ingestion.

### TEST-004-012
Existing Knowledge Studio session/review structures remain compatible.

### TEST-004-013
TRX300 end-to-end production workflow using mocked EAM transport.

### TEST-004-014
Repeated ingestion does not mutate the immutable Reference Vault
artifact.

Use existing test seams and conventions.

Do not weaken existing tests merely to make the new tests pass.

======================================================================
16. DO NOT MODIFY
======================================================================

Unless an actual integration defect makes it unavoidable, do not modify:

    Reference Vault server
    EAM database schema
    acquisition-record schema
    UIF stage architecture
    OCR implementation
    parser implementation
    Engineering Entity Extraction
    DerivedArtifact model
    repository persistence
    Foundation repository APIs
    commit transaction architecture
    Knowledge Studio review architecture
    existing Knowledge Session persistence schema
    Diagram Studio
    global OEP shell architecture

In particular:

    NO second Vault
    NO second OCR
    NO second ingestion pipeline
    NO direct repository writes
    NO new persistence database
    NO new repository tables
    NO redesign of Knowledge Studio

======================================================================
17. UI ARCHITECTURE RULE
======================================================================

If UI changes are required, first read:

    .claude/skills/oep-ui/SKILL.md

Follow the current OEP Studio shell architecture.

Do not introduce competing navigation/chrome.

Do not add another Studio.

The Reference Vault ingestion command should fit into the existing
Studio/workspace architecture.

======================================================================
18. ACCEPTANCE CRITERIA
======================================================================

WP-INGEST-004 is COMPLETE only if all are true:

[ ] A production application workflow can initiate ingestion from a
    Reference Vault object.

[ ] The workflow uses ReferenceVaultAdapter.

[ ] The workflow uses the existing IngestionOrchestrator.

[ ] The workflow uses the existing IngestionKnowledgeSessionBridge.

[ ] The resulting Knowledge Session is available to Knowledge Studio.

[ ] Existing Knowledge Studio review surfaces can operate on the
    resulting session.

[ ] No duplicate ingestion subsystem was introduced.

[ ] No Reference Vault ownership moved into UIF or Studio.

[ ] No repository write occurs automatically.

[ ] Integrity verification remains mandatory.

[ ] PARTIAL ingestion remains distinguishable from COMPLETE.

[ ] Temporary materialization is cleaned up.

[ ] Provenance remains intact.

[ ] TRX300 end-to-end workflow test passes.

[ ] Focused workflow tests pass.

[ ] Existing ingestion tests remain passing.

[ ] Existing acquisition tests remain passing.

[ ] No new analyzer errors are introduced.

[ ] Windows debug build succeeds.

[ ] No unrelated architecture was modified.

======================================================================
19. REQUIRED VALIDATION
======================================================================

Run:

    flutter test

    dart analyze

    flutter build windows --debug

Also run the focused ingestion/acquisition test suites independently.

Report:

    baseline test count
    new test count
    final test count
    failures
    whether failures are pre-existing
    analyzer baseline vs final
    Windows build result

Do not claim a clean test suite if pre-existing failures remain.

======================================================================
20. REQUIRED FINAL REPORT
======================================================================

Before committing, report:

1. Files changed.

2. Files added.

3. Files deleted.

4. Production workflow entry point.

5. Workflow sequence.

6. Knowledge Session integration point.

7. Error/state handling.

8. Temporary-file lifecycle.

9. Repository-write boundary confirmation.

10. Tests added.

11. Test results.

12. Analyzer results.

13. Build results.

14. Any architectural deviations.

15. Any follow-up work discovered.

======================================================================
21. COMMIT DISCIPLINE
======================================================================

Make ONE focused commit for WP-INGEST-004.

Suggested commit message:

    feat(ingestion): add Reference Vault ingestion workflow

Do not bundle unrelated changes.

Do not modify unrelated files.

Before committing:

    git status
    git diff --stat
    git diff

Confirm that every changed file belongs to WP-INGEST-004.

======================================================================
22. FINAL ARCHITECTURE
======================================================================

The completed architecture must remain:

                    EAM
                     │
                     ▼
              Reference Vault
                     │
                     │ authenticated API
                     ▼
           AcquisitionApiClient
                     │
                     ▼
           ReferenceVaultAdapter
                     │
                     ▼
              VaultObjectInput
                     │
                     ▼
           IngestionOrchestrator
                     │
                     ▼
              IngestionResult
                     │
                     ▼
       IngestionKnowledgeSessionBridge
                     │
                     ▼
            Knowledge Session
                     │
                     ▼
             Knowledge Studio
                     │
                     ▼
             Human Review
                     │
                     ▼
          Existing Commit Pipeline
                     │
                     ▼
           Engineering Repository

The critical ownership boundary remains:

    EAM owns evidence custody.
    UIF processes evidence.
    Knowledge Studio curates evidence-derived candidates.
    Human review determines acceptance.
    Repository receives accepted engineering knowledge.

Do not collapse these boundaries.

======================================================================
23. IMPLEMENTATION DIRECTIVE
======================================================================

Implement the smallest complete production vertical slice that makes
the above workflow executable.

Prefer composition over modification.

Prefer existing services over new abstractions.

Prefer existing state/session mechanisms over new state stores.

Prefer existing UI surfaces over new screens.

Do not solve future Reference Vault search, indexing, licensing,
replication, embeddings, repository matching, or other deferred work.

Do not expand scope.

When uncertain, stop and inspect the existing repository architecture
rather than inventing a new mechanism.

After implementation, provide the required final report and commit hash.