# WP-INGEST-005 — Ingestion Source Material Persistence

## Mission

Fix the Knowledge Studio source-material lifecycle for Reference Vault ingestion.

Reference Vault ingestion currently performs:

    Reference Vault
        ↓
    verified temporary artifact
        ↓
    UIF / IngestionOrchestrator
        ↓
    IngestionResult
        ↓
    KnowledgeSessionRecord
        ↓
    temporary artifact cleanup

The problem is that the KnowledgeSessionRecord currently receives a SourceMaterial whose localPath points to the temporary ingestion file.

ReferenceVaultIngestionWorkflow then deletes that temporary file in its finally block.

Result:

    Knowledge Session survives
    Candidates survive
    Evidence survives
    Provenance survives
    SourceMaterial record survives
    BUT
    SourceMaterial.localPath points to a deleted file

This makes the Source Viewer unable to reopen the ingested source.

The fix MUST use the existing Knowledge Studio source persistence mechanism.

---

# ARCHITECTURAL RULE

The authoritative source remains the Reference Vault.

The Knowledge Session receives a managed working copy of the source for UI/session use.

The lifecycle must become:

    Reference Vault
        ↓
    authenticated artifact download
        ↓
    checksum verification
        ↓
    temporary materialization
        ↓
    UIF processing
        ↓
    IngestionResult
        ↓
    Knowledge Session creation
        ↓
    COPY source bytes into KnowledgeSessionStorage
        ↓
    SourceMaterial.localPath → managed session copy
        ↓
    delete temporary ingestion file

Do NOT change this ownership model.

Reference Vault remains authoritative evidence custody.

Knowledge Studio owns the session-local working copy.

UIF remains processing/candidate-generation infrastructure.

---

# SCOPE

Implement ONLY the source-material persistence integration required to make a Reference Vault ingestion-created Knowledge Session reopenable.

The implementation must:

1. Preserve the existing ReferenceVaultAdapter.
2. Preserve temporary artifact cleanup.
3. Preserve UIF behavior.
4. Preserve the existing KnowledgeSessionRecord model unless a strictly necessary field correction is discovered.
5. Reuse SourceMaterialService.
6. Reuse KnowledgeSessionStorage.
7. Ensure the session-local source file exists after ingestion completes.
8. Ensure SourceMaterial.localPath points to that session-local copy.
9. Ensure the Source Viewer can open the source after ingestion.
10. Preserve existing candidate/evidence/provenance relationships.
11. Preserve PARTIAL ingestion behavior.
12. Prevent orphaned source files on FAILED ingestion.
13. Do not perform repository commits.
14. Do not modify Reference Vault server persistence.
15. Do not create a second artifact repository or Vault.
16. Do not modify UIF architecture.
17. Do not remove the temporary-file cleanup in ReferenceVaultAdapter.

---

# FIRST: INSPECT EXISTING IMPLEMENTATION

Before changing code, inspect the current implementations of:

- ReferenceVaultIngestionWorkflow
- ReferenceVaultAdapter
- VaultObjectInput
- IngestionResult
- IngestionKnowledgeSessionBridge
- KnowledgeSessionRecord
- SourceMaterial
- SourceMaterialService
- KnowledgeSessionStorage
- Knowledge Studio source loading/reloading
- SourceViewerPanel
- Foundation/session persistence and reload paths

Determine exactly how existing external sources are copied into:

    KnowledgeSessionStorage.sourcesDirectory(sessionId)

Do NOT invent a new source-storage mechanism if the existing mechanism can be reused.

---

# REQUIRED DESIGN

The ingestion workflow must ensure that a successful or partial ingestion has a persistent session-owned source.

Preferred conceptual sequence:

    materialize()
        ↓
    input.tempFile
        ↓
    orchestrator.run(input)
        ↓
    IngestionResult
        ↓
    create KnowledgeSessionRecord
        ↓
    persist source into session storage
        ↓
    update/construct SourceMaterial.localPath
        ↓
    return outcome
        ↓
    finally cleanup temporary input

The important invariant is:

    temporary ingestion path != Knowledge Session source path

After workflow completion:

    temporary path may be deleted
    session source path MUST remain valid

---

# SOURCE PERSISTENCE

Use the existing SourceMaterialService / KnowledgeSessionStorage mechanism.

If SourceMaterialService.attach() is currently the canonical way to copy external source files into session storage, reuse it rather than duplicating its logic.

The resulting SourceMaterial must reference the managed session-local file.

Example conceptual state:

    SourceMaterial {
        id: ...
        localPath:
            <KnowledgeSessionStorage>/sources/<session>/<filename>
        ...
    }

Do not leave:

    localPath:
        <system temp>/oep_vault_artifact_...

---

# IMPORTANT BRIDGE CONSIDERATION

The current IngestionKnowledgeSessionBridge directly places the IngestionResult source into:

    KnowledgeSessionRecord.sources

Do not blindly preserve that behavior if doing so leaves the temporary path embedded in the session.

Instead, introduce the smallest localized integration needed so that:

    IngestionResult.source
        ↓
    session-owned SourceMaterial
        ↓
    KnowledgeSessionRecord.sources

The bridge should remain responsible for transforming ingestion output into session data.

Source persistence may be performed by the workflow immediately before/after session creation, depending on the existing persistence API.

Follow existing project conventions.

Do not introduce unnecessary abstraction.

---

# PARTIAL INGESTION

PARTIAL ingestion is still usable.

If UIF returns:

    IngestionStatus.PARTIAL

but the source artifact was successfully materialized and a Knowledge Session is created, the source MUST be persisted to session storage exactly like a COMPLETE ingestion.

The user must be able to inspect the source and any successfully generated candidates/evidence.

Therefore:

    PARTIAL
        → persistent source
        → persistent session
        → available for inspection

---

# FAILED INGESTION

FAILED ingestion requires careful handling.

If ingestion fails before a Knowledge Session is successfully created:

    no session-owned source should remain orphaned

If a session has already been created before a failure occurs, use existing lifecycle/cleanup mechanisms where available.

Do NOT invent a broad session-deletion system.

The acceptance requirement is specifically:

    FAILED ingestion does not leave an orphaned session source.

---

# TEMPORARY FILE CLEANUP

Keep:

    ReferenceVaultAdapter.cleanupTemporaryFile(input)

in the workflow finally block.

The final lifecycle must prove:

    temporary file exists during processing
    ↓
    source copied to session storage
    ↓
    workflow finishes
    ↓
    temporary file deleted
    ↓
    session source still exists

Do not weaken cleanup merely to make the Source Viewer work.

---

# SOURCE VIEWER

Verify the existing SourceViewerPanel behavior.

It expects SourceMaterial.localPath to resolve to an existing local file.

Do not redesign SourceViewerPanel.

The correct fix is to make the SourceMaterial path valid.

---

# RELOAD / PERSISTENCE

Verify the source survives:

1. creation of the Knowledge Session
2. completion of ingestion
3. temporary-file cleanup
4. session reload
5. application restart, if the existing session persistence infrastructure supports restart testing

After reload:

    KnowledgeSessionRecord
        ↓
    SourceMaterial.localPath
        ↓
    existing managed source file

must still resolve.

Do not introduce a new persistence database or source registry.

---

# TEST REQUIREMENTS

Add focused tests.

## TEST-005-001 — Source becomes session-owned

Given a valid Reference Vault artifact:

- perform Reference Vault ingestion
- create the Knowledge Session
- verify SourceMaterial.localPath is inside KnowledgeSessionStorage
- verify it is NOT the temporary adapter path

## TEST-005-002 — Managed source exists

After successful ingestion:

- resolve SourceMaterial.localPath
- verify file exists
- verify file contents match the Reference Vault artifact

## TEST-005-003 — Temporary file cleaned

After workflow completion:

- verify the temporary ingestion artifact no longer exists

while:

- session-managed source still exists

## TEST-005-004 — Source Viewer compatibility

Using the resulting SourceMaterial:

- verify SourceMaterialService.exists(source) succeeds
- verify the existing SourceViewer path can resolve the source

Do not require UI automation if project infrastructure does not support it; test the same underlying source-resolution contract.

## TEST-005-005 — Session reload

Persist the session.

Reload it through the existing session-loading mechanism.

Verify:

- session loads
- source loads
- localPath resolves
- source file exists

## TEST-005-006 — Reloaded source content

After reload:

- read the source file
- verify its SHA-256 matches the original Vault artifact

## TEST-005-007 — Candidate evidence survives

Verify ingestion-generated candidates/evidence remain associated with the session after source persistence changes.

## TEST-005-008 — Provenance survives

Verify:

    Vault Object
        ↓
    Acquisition Record
        ↓
    Ingestion Run
        ↓
    derived/evidence data

remains intact.

## TEST-005-009 — Reference Vault immutability

Verify the workflow does not modify the Reference Vault artifact.

No PUT/PATCH/DELETE or equivalent Vault mutation may occur.

## TEST-005-010 — No repository write

Verify ingestion still does not invoke:

- commit
- Foundation repository write
- CommitTransactionService
- Repository persistence

The user must still explicitly commit accepted engineering knowledge.

## TEST-005-011 — PARTIAL ingestion

Force/produce PARTIAL ingestion.

Verify:

- session is created according to existing workflow rules
- managed source exists
- source is viewable
- available candidates/evidence remain present
- temporary artifact is cleaned

## TEST-005-012 — FAILED ingestion cleanup

Force ingestion failure.

Verify:

- no orphaned managed source remains
- temporary artifact is cleaned
- no repository write occurs

---

# CONTENT INTEGRITY

The session-managed source must be an exact byte-for-byte copy of the verified Vault artifact.

Verify:

    SHA256(sessionSource)
        ==
    SHA256(ReferenceVaultArtifact)

Do not reserialize, transform, recompress, OCR, or otherwise modify the source file.

The Knowledge Session copy is a working copy, not a new evidence artifact.

---

# ARCHITECTURAL NON-GOALS

Do NOT:

- modify Reference Vault server architecture
- modify ReferenceVaultAdapter checksum behavior
- modify AcquisitionApiClient
- modify UIF pipeline stages
- modify DerivedArtifact architecture
- modify candidate generation
- modify OCR architecture
- modify repository architecture
- add repository writes
- add embeddings
- add new persistence systems
- add a second Vault
- change SourceViewerPanel architecture
- redesign Knowledge Studio
- create a new SourceMaterial abstraction
- remove temporary cleanup
- make the temporary directory permanent
- store Vault artifacts directly inside UIF
- store Vault artifacts directly inside Foundation Repository

---

# ACCEPTANCE INVARIANTS

The implementation is accepted only if all of these are true:

1. Reference Vault remains authoritative.
2. Artifact checksum is still verified before ingestion.
3. UIF receives the verified Vault artifact.
4. UIF remains read-only with respect to Vault and Repository.
5. Knowledge Session receives a persistent session-owned source copy.
6. SourceMaterial.localPath points to the session-owned copy.
7. Temporary ingestion files are still deleted.
8. Source Viewer can resolve the source after ingestion.
9. Source remains available after session reload.
10. Candidate/evidence/provenance data remains intact.
11. PARTIAL ingestion remains inspectable.
12. FAILED ingestion leaves no orphaned session source.
13. Reference Vault artifact is not modified.
14. No Repository commit occurs.
15. Existing source-storage infrastructure is reused.
16. No new architectural ownership boundary is introduced.

---

# VALIDATION

Run focused tests first.

Then run:

    flutter test

Then:

    dart analyze

Then:

    flutter build windows --debug

Compare analyzer/test failures against the baseline.

Do not claim unrelated pre-existing failures are caused by this WP.

Report:

- focused test count
- full test count
- skipped tests
- pre-existing failures
- analyzer result
- build result
- files changed
- architectural impact

---

# CHANGE DISCIPLINE

Keep the patch minimal.

Before editing, establish the current HEAD.

Do not modify unrelated files.

Do not reformat unrelated code.

Do not change architecture outside this WP.

Do not commit unrelated cleanup.

If the existing APIs make the required lifecycle impossible without a broader change, STOP and report the architectural blocker rather than expanding scope silently.

---

# REQUIRED FINAL REPORT

Return:

## WP-INGEST-005 Implementation Report

### Baseline
- starting commit

### Final Commit
- commit SHA
- commit message

### Files Changed
- exact list

### Source Lifecycle
Show the implemented lifecycle:

    Reference Vault
      ↓
    verified temp artifact
      ↓
    UIF
      ↓
    IngestionResult
      ↓
    Knowledge Session
      ↓
    session-owned source
      ↓
    temp cleanup

### Tests
List TEST-005-001 through TEST-005-012 and results.

### Validation
- flutter test
- dart analyze
- flutter build windows --debug

### Architecture
State explicitly whether:
- Reference Vault ownership changed
- UIF architecture changed
- Repository boundary changed
- Knowledge Session source lifecycle changed

### Limitations
List only actual remaining limitations.

### Final Disposition
State one of:

    COMPLETE

or

    BLOCKED

Do not declare COMPLETE if any acceptance invariant is unmet.