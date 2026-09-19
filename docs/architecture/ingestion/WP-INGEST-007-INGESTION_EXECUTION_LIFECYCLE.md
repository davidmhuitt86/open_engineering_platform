# WP-INGEST-007 — INGESTION EXECUTION LIFECYCLE

## IMPLEMENTATION PROMPT

You are implementing the next controlled work package in the Open Engineering Platform (OEP) Universal Ingestion Framework.

This is an architecture-controlled implementation.

Do not expand the scope beyond what is explicitly authorized below.

---

# 0. WORK PACKAGE IDENTITY

Work Package:

WP-INGEST-007

Title:

Ingestion Execution Lifecycle

Architecture Phase:

AP-INGEST

Baseline commit:

81602a173da0f9c98ed514c342893ae6e36ddf03

Baseline description:

INGEST-FOLLOWUP-003 — Processing Identity Canonicalization Hardening

The baseline processing identity implementation is considered architecturally correct and frozen.

Do not regress it.

---

# 1. MISSION

The purpose of WP-INGEST-007 is to make ingestion execution a durable lifecycle.

The current Universal Ingestion Framework already has:

- IngestionRun
- IngestionRunStatus
- StageResult
- DerivedArtifact
- IngestionResult
- deterministic processingIdentity
- KnowledgeSessionRecord.ingestionRuns
- KnowledgeSessionStorage
- IngestionOrchestrator
- ReferenceVaultIngestionWorkflow
- IngestionKnowledgeSessionBridge

The architectural gap is that the current IngestionOrchestrator creates the meaningful IngestionRun record only after execution has already occurred.

Therefore, an application interruption during ingestion can cause the execution attempt to disappear without durable execution history.

The target is to change the lifecycle from:

    EXECUTE
        ↓
    BUILD FINAL RUN
        ↓
    PERSIST

to:

    CREATE RUN
        ↓
    QUEUED
        ↓
    RUNNING
        ↓
    EXECUTE STAGES
        ↓
    TERMINAL STATE
        ↓
    PERSISTED HISTORY

The implementation must remain within the existing OEP architecture.

---

# 2. CURRENT ARCHITECTURE

The existing conceptual flow is:

    Reference Vault
          │
          ▼
    VaultObjectInput
          │
          ▼
    IngestionOrchestrator
          │
          ├── processingIdentity
          ├── IngestionRun
          ├── StageResult
          ├── DerivedArtifact
          │
          ▼
    IngestionResult
          │
          ▼
    Knowledge Session
          │
          ▼
    KnowledgeSessionStorage
          │
          ▼
    Knowledge Studio Review
          │
          ▼
    Explicit Commit
          │
          ▼
    Engineering Repository

This architecture remains unchanged.

WP-INGEST-007 only makes the ingestion execution lifecycle durable.

---

# 3. CONFIRMED GAP

The current implementation has this behavior:

    IngestionOrchestrator.run()
            │
            ├── execute ingestion
            │
            ├── create final IngestionRun
            │
            └── return IngestionResult

This means:

    APP TERMINATES DURING EXECUTION
            ↓
    In-memory execution disappears
            ↓
    No durable RUNNING execution exists
            ↓
    Execution history is lost

The implementation must close this gap.

---

# 4. REQUIRED TARGET LIFECYCLE

The required lifecycle is:

    CREATE RUN
        ↓
      QUEUED
        ↓
      RUNNING
        ↓
    STAGE EXECUTION
        ↓
    ┌──────────┬─────────┬────────┬───────────┐
    ↓          ↓         ↓        ↓
 COMPLETED   PARTIAL   FAILED   CANCELLED
    │          │         │        │
    └──────────┴─────────┴────────┴───────────┘
                    ↓
          PERSISTED HISTORY

All execution attempts must become historical records.

---

# 5. EXISTING RUN STATES

The existing IngestionRunStatus values are:

    QUEUED
    RUNNING
    COMPLETED
    PARTIAL
    FAILED
    CANCELLED

Preserve these values.

Do not rename them.

Do not remove them.

Do not replace the existing lifecycle vocabulary.

Terminal states are:

    COMPLETED
    PARTIAL
    FAILED
    CANCELLED

---

# 6. RUN STATE TRANSITIONS

Define and enforce legal lifecycle transitions.

At minimum:

    QUEUED → RUNNING

    RUNNING → COMPLETED
    RUNNING → PARTIAL
    RUNNING → FAILED
    RUNNING → CANCELLED

It is acceptable to support:

    QUEUED → FAILED
    QUEUED → CANCELLED

if required by the implementation.

Terminal states must remain terminal.

These transitions must not be permitted:

    COMPLETED → RUNNING
    COMPLETED → FAILED
    COMPLETED → CANCELLED

    PARTIAL → RUNNING
    PARTIAL → FAILED

    FAILED → RUNNING
    FAILED → COMPLETED

    CANCELLED → RUNNING
    CANCELLED → COMPLETED

Do not create unrestricted status mutation.

If the current model requires a transition helper or validation method, implement the smallest appropriate mechanism.

Keep it inside the existing ingestion domain.

Do not create a general-purpose state-machine framework.

---

# 7. RUN MUST EXIST BEFORE EXECUTION

This is one of the primary acceptance requirements.

A run must be created before meaningful ingestion execution begins.

The conceptual sequence must become:

    create IngestionRun
        status = QUEUED
        persist

            ↓

    transition to RUNNING
        persist

            ↓

    execute stage

            ↓

    record stage result/history

            ↓

    execute next stage

            ↓

    terminal state

            ↓

    persist

The exact implementation may batch persistence where safe, but it must no longer be dependent on constructing the IngestionRun only after ingestion completes.

---

# 8. KNOWLEDGE SESSION IS THE PERSISTENCE DOMAIN

Use the existing Knowledge Session persistence domain.

The existing objects are:

    KnowledgeSessionRecord
    KnowledgeSessionStorage
    KnowledgeSessionService

The ingestion history already belongs to:

    KnowledgeSessionRecord.ingestionRuns

Continue using that architecture.

Do NOT create:

    IngestionRunRepository
    IngestionDatabase
    IngestionRunStore
    IngestionPersistenceService
    PostgreSQL ingestion tables
    SQLite ingestion tables
    another JSON database
    another session database

unless inspection of the existing architecture demonstrates an unavoidable requirement.

The expected solution is to extend the existing persistence path.

---

# 9. PERSISTED INFORMATION

Durable ingestion execution history must preserve enough information to reconstruct the execution.

At minimum preserve:

    runId
    vaultObjectId
    contentHash
    startedAt
    completedAt
    status
    pipelineVersion
    parserId
    parserVersion
    processorVersions
    processingConfiguration
    processingIdentity constituents
    stageResults
    stage diagnostics
    derived artifact provenance references

Do not necessarily persist a separate processingIdentity field.

The existing architecture derives processingIdentity from its canonical constituent inputs.

Preserve that design.

---

# 10. PROCESSING IDENTITY IS FROZEN

The previous work package hardened processing identity.

Do not replace it with a new scheme.

The processing identity consists of exactly these seven conceptual inputs:

    1. vaultObjectId
    2. contentHash
    3. pipelineVersion
    4. parserId
    5. parserVersion
    6. processorVersions
    7. processingConfiguration

The identity is generated using deterministic structured canonical JSON and SHA-256.

The following MUST NOT influence processingIdentity:

    runId
    startedAt
    completedAt
    status
    sessionId
    random execution identifiers

This distinction is mandatory.

---

# 11. EXECUTION IDENTITY VS PROCESSING IDENTITY

There are two different concepts.

## Execution identity

    runId

Every execution attempt receives its own runId.

Example:

    Run A
        runId = A
        processingIdentity = X

    Run B
        runId = B
        processingIdentity = X

This is valid.

Run B is a new execution attempt of the same processing definition.

---

## Processing identity

    processingIdentity = X

This describes what evidence and processing definition were used.

It does NOT identify a particular execution attempt.

Therefore:

    same evidence
    +
    same processing definition
    =
    same processingIdentity

even when:

    runId differs

This relationship must remain intact.

---

# 12. RETRY SEMANTICS

A retry is a new execution attempt.

Example:

    Run A
       ↓
    FAILED

    explicit retry
       ↓

    Run B
       ↓
    COMPLETED

The persisted session must contain BOTH:

    Run A = FAILED
    Run B = COMPLETED

Run A must not be overwritten.

Run A must not be deleted.

Run A must not be converted into Run B.

Run A must remain historical.

Run B receives a new runId.

If the evidence and processing definition have not changed, Run B may have the same processingIdentity as Run A.

That is correct.

---

# 13. DO NOT IMPLEMENT AUTOMATIC DEDUPLICATION

This work package does NOT authorize deduplication.

Do not implement behavior such as:

    "processingIdentity already exists, therefore do not run"

Do not implement:

    cache
    result reuse
    automatic skip
    automatic merge
    automatic replacement
    automatic retry
    execution coalescing

Identical processing identities are an architectural identity concept only.

They are not an instruction to skip execution.

---

# 14. INTERRUPTION SEMANTICS

This work package must define what happens when the application terminates while ingestion is running.

The selected architecture is:

    persisted RUNNING run
            ↓
    application/session reload
            ↓
    no live execution exists
            ↓
    reconcile to FAILED

Use the existing FAILED status.

Do NOT introduce ABANDONED.

The reason is:

- FAILED already exists.
- An interrupted execution did not successfully complete.
- CANCELLED represents intentional cancellation.
- No additional lifecycle vocabulary is required.
- The historical execution should remain visible.

The resulting run must contain an explicit diagnostic indicating that execution was interrupted.

For example:

    Execution interrupted before completion.

Exact wording may vary.

The important requirement is that the diagnostic clearly identifies interruption rather than ordinary stage failure.

---

# 15. DO NOT AUTOMATICALLY RESUME

A persisted interrupted run must NOT automatically resume.

Do not:

    restart it
    rerun it
    clone it automatically
    mark it completed
    discard it

If the user later explicitly requests a retry, create a new run.

Example:

    Run A
        RUNNING
        ↓
    application terminates
        ↓
    reload
        ↓
    Run A = FAILED / interrupted
        ↓
    user explicitly retries
        ↓
    Run B = QUEUED
        ↓
    Run B = RUNNING

This preserves execution history.

---

# 16. STAGE LIFECYCLE

The existing StageResult model contains:

    stage
    status
    startedAt
    completedAt
    diagnostics
    derivedArtifactIds

Preserve those fields and their current meaning.

The current problem is that stage history is generally recorded after the stage has completed.

A durable lifecycle must allow the system to know that a stage was in progress when execution was interrupted.

Use the smallest appropriate solution.

If necessary, stage results may have lifecycle states equivalent to:

    QUEUED
    RUNNING
    COMPLETED
    PARTIAL
    FAILED
    CANCELLED

However, do not create a separate stage persistence system.

The persisted run contains the stage history.

---

# 17. STAGE INTERRUPTION

If a stage is persisted as RUNNING when the application terminates, it must not remain falsely represented as actively running after reload.

Reconcile it consistently with the interrupted run.

For example:

    Run:
        RUNNING
        ↓
        FAILED / interrupted

    Current stage:
        RUNNING
        ↓
        FAILED / interrupted

Preserve the historical stage start time and diagnostics where available.

Do not fabricate a successful completion time.

Do not claim the stage succeeded.

---

# 18. FAILURE SEMANTICS

Existing failure behavior must remain intact.

Example:

    IDENTIFY              SUCCESS
    PARSER_SELECTION      SUCCESS
    METADATA_EXTRACTION   SUCCESS
    CONTENT_EXTRACTION   SUCCESS
    OCR                   FAILURE

The historical execution must preserve:

    successful stages
    failed stage
    diagnostics
    derived artifact references already produced

Do not collapse the execution into one generic error.

---

# 19. PARTIAL EXECUTION

PARTIAL must continue to mean that meaningful processing occurred but the complete pipeline did not successfully finish.

For example:

    stage 1 SUCCESS
    stage 2 SUCCESS
    stage 3 PARTIAL
    stage 4 not executed

The resulting run may be:

    PARTIAL

and must retain the stage history already produced.

Do not discard partial results merely because execution did not reach the final stage.

---

# 20. CANCELLATION

The current architecture already contains:

    IngestionRunStatus.cancelled

but the current orchestrator does not have a real cancellation API/control path.

Implement the smallest coherent explicit cancellation mechanism required for this lifecycle.

Requirements:

1. Cancellation must be explicitly requested.
2. Cancellation must not be confused with failure.
3. A cancelled run must remain historical.
4. A cancelled run must persist as CANCELLED.
5. Cancellation must not modify Reference Vault evidence.
6. Cancellation must not write to Engineering Repository.

A lightweight cancellation token/request mechanism scoped to the ingestion execution is acceptable.

Do not create a general-purpose application cancellation framework.

Do not build a job scheduler.

Do not build distributed cancellation.

---

# 21. CANCELLATION BEFORE EXECUTION

If the implementation supports cancellation while QUEUED:

    QUEUED → CANCELLED

is acceptable.

The run must remain persisted.

No ingestion stage should execute after cancellation has been honored.

---

# 22. CANCELLATION DURING EXECUTION

If cancellation is requested while RUNNING:

    RUNNING → CANCELLED

The execution should stop at the next safe cancellation point.

Do not pretend that already completed stages did not execute.

Preserve their historical stage results.

Do not roll back successful read-only ingestion work merely to make the state cleaner.

---

# 23. HISTORICAL IMMUTABILITY

Historical runs must remain historical.

Example:

    Run A = FAILED

Explicit retry:

    Run B = QUEUED
    Run B = RUNNING
    Run B = COMPLETED

Final history:

    Run A = FAILED
    Run B = COMPLETED

Do not change Run A to COMPLETED.

Do not delete Run A.

Do not replace the run list with only the latest execution.

---

# 24. DERIVED ARTIFACTS

Preserve the WP-INGEST-006 decision.

DerivedArtifact provenance metadata is durable through the Knowledge Session.

Derived artifact BYTES remain transient unless an existing implementation already persists those bytes.

Do not expand WP-INGEST-007 into artifact storage.

Do not create:

    DerivedArtifactRepository
    ArtifactDatabase
    ArtifactVault
    second artifact store

The work package is about execution lifecycle, not artifact storage.

---

# 25. REFERENCE VAULT BOUNDARY

Reference Vault remains authoritative for acquired evidence.

WP-INGEST-007 must not modify:

    Reference Vault records
    Reference Vault metadata
    Reference Vault artifacts
    Reference Vault custody

The ingestion execution only consumes verified evidence.

The boundary remains:

    Reference Vault
          ↓
    VaultObjectInput
          ↓
    UIF

No reverse ownership is introduced.

---

# 26. ENGINEERING REPOSITORY BOUNDARY

The UIF does not directly commit Engineering Objects or Relationships.

The existing architecture remains:

    UIF
      ↓
    Knowledge Candidate
      ↓
    Knowledge Studio
      ↓
    Human Review
      ↓
    Commit Pipeline
      ↓
    Engineering Repository

Do not introduce:

    UIF → Repository

Do not call FoundationBridge directly from the ingestion orchestrator.

Do not create automatic candidate commits.

---

# 27. KNOWLEDGE SESSION INTEGRATION

The ingestion execution lifecycle must integrate with the existing Knowledge Session architecture.

Inspect:

    KnowledgeSessionRecord
    KnowledgeSessionStorage
    KnowledgeSessionService
    IngestionKnowledgeSessionBridge

before editing.

Do not assume their current implementation.

Understand:

    session creation
    persistence
    serialization
    deserialization
    reload
    merge behavior

before implementing the lifecycle.

---

# 28. IMPORTANT SESSION-OWNERSHIP CONSIDERATION

A run needs a durable Knowledge Session context in order to persist execution state.

Determine how the existing workflow creates or receives the session.

Do not create a new session subsystem.

If the existing workflow already has a session context, use it.

If a minimal API adjustment is required to make execution persistence possible, make that adjustment within the existing Knowledge Session architecture.

Do not redesign session ownership.

---

# 29. PRODUCTION WORKFLOW

The existing production workflow is conceptually:

    ReferenceVaultAdapter.materialize()
        ↓
    IngestionOrchestrator.run()
        ↓
    IngestionKnowledgeSessionBridge
        ↓
    Knowledge Session

The lifecycle implementation must preserve this flow.

Do not move ingestion into:

    EAM server
    Foundation server
    Repository
    Reference Vault

The execution remains Studio/UIF-side.

---

# 30. REQUIRED TESTS

Create focused tests for the lifecycle.

Use these identifiers.

## TEST-007-001

A new ingestion execution creates a persisted IngestionRun before execution has completed.

---

## TEST-007-002

A newly created run can transition:

    QUEUED → RUNNING

---

## TEST-007-003

Successful ingestion persists:

    COMPLETED

---

## TEST-007-004

Partial ingestion persists:

    PARTIAL

---

## TEST-007-005

Failed ingestion persists:

    FAILED

---

## TEST-007-006

Explicit cancellation persists:

    CANCELLED

---

## TEST-007-007

A persisted run survives Knowledge Session reload.

---

## TEST-007-008

Persisted stage history survives Knowledge Session reload.

---

## TEST-007-009

A persisted RUNNING execution that no longer has a live execution is reconciled to:

    FAILED

after reload.

---

## TEST-007-010

The interrupted execution contains an explicit interruption diagnostic.

---

## TEST-007-011

A retry receives a new runId.

---

## TEST-007-012

A retry does not erase the previous run.

---

## TEST-007-013

Same evidence + same processing definition produces the same processingIdentity across separate execution attempts.

---

## TEST-007-014

Changing runId does not change processingIdentity.

---

## TEST-007-015

Changing the processing definition changes processingIdentity.

---

## TEST-007-016

Terminal run states cannot transition back into active states.

---

## TEST-007-017

No Reference Vault mutation occurs during execution lifecycle handling.

---

## TEST-007-018

No Engineering Repository write occurs during execution lifecycle handling.

---

## TEST-007-019

Knowledge Session JSON round-trip preserves complete ingestion execution history.

---

## TEST-007-020

Adding a retry preserves all previous historical runs.

---

# 31. ADDITIONAL CANCELLATION TESTS

If cancellation is implemented with a cancellation request/token, add focused tests covering:

    cancellation before execution
    cancellation during execution
    cancellation persistence
    cancellation history
    cancellation does not become FAILED

Only add tests relevant to the actual implementation.

---

# 32. PROCESSING IDENTITY TESTING

Do not weaken the existing processing identity tests.

The following must remain true:

    runId difference
        ≠
    processingIdentity difference

and:

    timestamp difference
        ≠
    processingIdentity difference

and:

    status difference
        ≠
    processingIdentity difference

while:

    contentHash difference
        =
    processingIdentity difference

    pipeline version difference
        =
    processingIdentity difference

    parser difference
        =
    processingIdentity difference

    processor version difference
        =
    processingIdentity difference

    processing configuration difference
        =
    processingIdentity difference

Do not change the canonicalization algorithm from FOLLOWUP-003.

---

# 33. NO DEDUPLICATION TEST

Explicitly ensure that:

    processingIdentity already exists

does NOT cause a new explicit execution to be skipped.

A new execution must still receive a new runId.

---

# 34. PERSISTENCE TESTING

Do not merely construct objects in memory and assert their fields.

Exercise the actual existing Knowledge Session persistence path.

The important scenario is:

    create
        ↓
    persist
        ↓
    reload
        ↓
    inspect
        ↓
    modify lifecycle
        ↓
    persist
        ↓
    reload

Use the existing session storage implementation.

---

# 35. INTERRUPTION TESTING

The interruption scenario is especially important.

Simulate:

    RUN created
        ↓
    QUEUED persisted
        ↓
    RUNNING persisted
        ↓
    stage begins
        ↓
    application/execution disappears
        ↓
    Knowledge Session reload
        ↓
    RUNNING execution reconciled to FAILED
        ↓
    interruption diagnostic preserved

Do not simulate this only by directly changing the final status.

Test the persistence/reload semantics.

---

# 36. RETRY TESTING

Test:

    Run A
       ↓
    FAILED

then:

    explicit retry
       ↓
    Run B

Assert:

    A.runId != B.runId

and:

    A remains in session history

and, where processing inputs are identical:

    A.processingIdentity == B.processingIdentity

---

# 37. TERMINAL STATE TESTING

Test that terminal states cannot become active.

At minimum:

    COMPLETED → RUNNING = invalid
    PARTIAL → RUNNING = invalid
    FAILED → RUNNING = invalid
    CANCELLED → RUNNING = invalid

The exact error mechanism is an implementation detail.

---

# 38. CODE QUALITY REQUIREMENTS

Follow the repository's existing Dart/Flutter style.

Do not introduce unnecessary abstractions.

Do not add speculative architecture.

Do not refactor unrelated code.

Do not rename unrelated classes.

Do not alter existing UI architecture.

Do not alter existing Engine behavior.

Do not modify EAM server code.

Do not modify Repository code.

---

# 39. REQUIRED INSPECTION BEFORE EDITING

Before making changes, inspect the current implementation of:

    platform/oep_studio/lib/ingestion/services/ingestion_orchestrator.dart

    platform/oep_studio/lib/ingestion/models/ingestion_run.dart

    platform/oep_studio/lib/ingestion/models/ingestion_run_status.dart

    platform/oep_studio/lib/ingestion/models/stage_result.dart

    platform/oep_studio/lib/ingestion/models/derived_artifact.dart

    platform/oep_studio/lib/ingestion/services/knowledge_session_bridge.dart

    platform/oep_studio/lib/knowledge/models/knowledge_session_record.dart

    platform/oep_studio/lib/knowledge/services/knowledge_session_storage.dart

    platform/oep_studio/lib/knowledge/services/knowledge_session_service.dart

    platform/oep_studio/lib/acquisition/services/reference_vault_ingestion_workflow.dart

Also inspect the existing ingestion tests.

Determine the minimum implementation surface from the actual repository.

---

# 40. DO NOT ASSUME FILE CONTENT

The repository is authoritative.

If current code differs from this prompt:

1. preserve the architectural intent
2. inspect the actual implementation
3. avoid destructive refactoring
4. report any contradiction before expanding scope

Do not invent nonexistent classes or APIs.

---

# 41. DOCUMENTATION

Update the existing ingestion architecture documentation only as necessary.

Document:

    run lifecycle
    legal transitions
    terminal states
    interruption semantics
    retry semantics
    cancellation semantics
    execution identity
    processing identity

Explicitly document:

    runId identifies an execution attempt

and:

    processingIdentity identifies the processing definition/evidence combination

Also document:

    interrupted RUNNING executions are reconciled to FAILED after reload

Do not create unnecessary duplicate documentation.

---

# 42. NO ARCHITECTURAL DRIFT

This work package must NOT result in:

    a second ingestion framework
    a job system
    a queue system
    a server ingestion service
    an ingestion database
    a repository integration
    an artifact vault
    an AI ingestion system
    a generalized parser framework

The architecture remains:

    UIF = processing/orchestration/candidate production

    Knowledge Studio = human inspection/curation/review

    Engineering Repository = accepted engineering truth

    Reference Vault = authoritative acquired evidence

---

# 43. REQUIRED VALIDATION

Run:

    flutter test

    dart analyze

    flutter build windows --debug

Also run the focused WP-INGEST-007 tests separately.

Record:

    focused test result
    full test result
    skipped tests
    failed tests
    pre-existing failures
    analyzer issue count
    analyzer baseline comparison
    Windows build result

Do not misclassify pre-existing failures as regressions.

---

# 44. REGRESSION STANDARD

The current repository has known unrelated UX test failures.

If those remain unchanged:

    report them as pre-existing

Do not modify UX code to make the ingestion work package appear cleaner.

Do not alter unrelated tests.

---

# 45. BUILD STANDARD

The Windows debug build must complete successfully.

Command:

    flutter build windows --debug

If the build fails:

1. capture the failure
2. determine whether it is caused by WP-INGEST-007
3. fix only if caused by this work package
4. otherwise report it as pre-existing/environmental

Do not make unrelated changes solely to obtain a clean build.

---

# 46. ANALYZER STANDARD

Run:

    dart analyze

Report:

    baseline issue count
    final issue count
    new issues
    resolved issues

The objective is:

    zero new analyzer issues

Do not rewrite unrelated code simply to eliminate pre-existing analyzer issues.

---

# 47. GIT DISCIPLINE

Before implementation:

    verify current HEAD
    verify clean/expected working tree
    confirm baseline

During implementation:

    keep changes scoped
    inspect git diff
    inspect git status

Before commit:

    review every changed file
    verify no unrelated files are included
    run required validation

Commit only the intended WP-INGEST-007 implementation.

Use a clear commit message such as:

    feat(ingestion): implement execution lifecycle

or another repository-consistent equivalent.

---

# 48. FINAL DIFF REQUIREMENT

Before reporting completion, inspect:

    git diff --stat

    git diff

and verify that every changed file belongs to the work package.

Do not include:

    generated files
    build output
    temporary files
    unrelated documentation
    unrelated UX changes
    unrelated repository changes

---

# 49. FINAL AAR REPORT

When implementation is complete, provide an AAR-style report.

Use this exact structure.

## WP-INGEST-007 — Ingestion Execution Lifecycle

### 1. Result

State:

    COMPLETE

or:

    COMPLETE WITH DISCLOSED LIMITATION

or:

    INCOMPLETE

Do not claim COMPLETE unless all acceptance criteria are satisfied.

---

### 2. Baseline

Provide the full baseline SHA:

    81602a173da0f9c98ed514c342893ae6e36ddf03

---

### 3. Final SHA

Provide the full resulting commit SHA.

---

### 4. Commit

Provide:

    commit SHA
    commit message

---

### 5. Files Changed

Provide the exact list of changed files.

---

### 6. Lifecycle Model

Document the implemented run states and transitions.

Example:

    QUEUED
       ↓
    RUNNING
       ↓
    COMPLETED / PARTIAL / FAILED / CANCELLED

---

### 7. Interruption Semantics

Explain exactly how a persisted RUNNING execution is handled after reload.

Confirm:

    RUNNING → FAILED

when the execution no longer exists.

Explain the diagnostic recorded.

---

### 8. Stage Lifecycle

Explain how stage history is persisted.

Explain how an interrupted in-progress stage is represented.

---

### 9. Cancellation

Explain:

    cancellation request
    cancellation state
    persistence
    historical behavior

---

### 10. Retry

Explain:

    new runId
    old run preserved
    processingIdentity relationship

---

### 11. Identity Model

Explicitly document:

    runId = execution identity

    processingIdentity = processing-definition identity

Confirm processingIdentity excludes:

    runId
    timestamps
    status
    session ID
    random execution identifiers

---

### 12. Persistence

Explain:

    where the run is persisted
    how it is reloaded
    how stage history is persisted
    how historical attempts are retained

Confirm that the existing Knowledge Session persistence domain is used.

---

### 13. Derived Artifacts

Explicitly state:

    metadata/provenance persistence status

and:

    whether derived bytes remain transient

Do not claim byte persistence unless actually implemented.

---

### 14. Reference Vault Boundary

Explicitly confirm:

    no Reference Vault mutation

---

### 15. Engineering Repository Boundary

Explicitly confirm:

    no Engineering Repository write

---

### 16. Deduplication Boundary

Explicitly confirm:

    no automatic deduplication
    no automatic retry
    no processing-result reuse

---

### 17. Persistence Architecture

Explicitly confirm:

    no second persistence subsystem

---

### 18. Tests

List:

    TEST-007-001
    ...
    TEST-007-020

with pass/fail status.

Also list any additional cancellation tests.

---

### 19. Regression

Report:

    flutter test

with:

    passed
    skipped
    failed

Identify pre-existing failures separately.

---

### 20. Analyzer

Report:

    dart analyze

and baseline comparison.

---

### 21. Windows Build

Report:

    flutter build windows --debug

result.

---

### 22. Documentation

List documentation changed.

---

### 23. Known Limitations

List every remaining limitation.

Do not hide limitations.

---

### 24. Architectural Disposition

State one:

    COMPLETE

    COMPLETE WITH DISCLOSED LIMITATION

    INCOMPLETE

---

# 50. FINAL ARCHITECTURAL CONTRACT

After WP-INGEST-007, the ingestion architecture should conceptually be:

    ┌──────────────────────────┐
    │     Reference Vault      │
    │ authoritative evidence  │
    └────────────┬─────────────┘
                 │
                 ▼
    ┌──────────────────────────┐
    │      VaultObjectInput     │
    └────────────┬─────────────┘
                 │
                 ▼
    ┌──────────────────────────┐
    │ Ingestion Execution      │
    │                          │
    │ QUEUED                   │
    │   ↓                      │
    │ RUNNING                  │
    │   ↓                      │
    │ terminal state           │
    │                          │
    │ Run History              │
    │ Stage History            │
    │ Provenance               │
    │ Processing Identity      │
    └────────────┬─────────────┘
                 │
                 ▼
    ┌──────────────────────────┐
    │     IngestionResult      │
    └────────────┬─────────────┘
                 │
                 ▼
    ┌──────────────────────────┐
    │    Knowledge Session     │
    │                          │
    │ durable execution history│
    └────────────┬─────────────┘
                 │
                 ▼
    ┌──────────────────────────┐
    │    Knowledge Studio      │
    │ human review/curation    │
    └────────────┬─────────────┘
                 │
                 ▼
    ┌──────────────────────────┐
    │    Explicit Commit       │
    └────────────┬─────────────┘
                 │
                 ▼
    ┌──────────────────────────┐
    │ Engineering Repository   │
    │ accepted truth           │
    └──────────────────────────┘

The critical identity relationship is:

    execution attempt
        = runId

    processing definition/evidence
        = processingIdentity

Therefore:

    retry
        = new runId

while:

    same evidence
    +
    same processing definition
        =
    same processingIdentity

The critical interruption relationship is:

    persisted RUNNING
        +
    application termination
        +
    reload
        =
    FAILED / interrupted

The critical ownership relationships remain:

    Reference Vault
        = evidence custody

    UIF
        = ingestion processing/orchestration

    Knowledge Studio
        = human inspection/review

    Engineering Repository
        = accepted engineering truth

Implement only the smallest complete change necessary to establish this contract.