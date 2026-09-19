# WP-INGEST-003 — Production Reference Vault → Universal Ingestion Framework Boundary

You are implementing WP-INGEST-003 in the Open Engineering Platform monorepo.

Repository:
    davidmhuitt86/open_engineering_platform

Architecture:
    AP-INGEST-003 — Production Reference Vault → UIF Boundary

This is an implementation work package.

Do not redesign the architecture.
Do not expand the scope.
Do not invent replacement subsystems.
Do not make assumptions where the repository can answer the question.

Your first responsibility is to inspect the repository and reconcile this work package against the actual current implementation before changing anything.

======================================================================
1. MISSION
======================================================================

Connect the existing Universal Ingestion Framework (UIF) to the real
Engineering Acquisition Manager (EAM) Reference Vault.

The current UIF contains a filesystem-based stand-in:

    VaultObjectInput.fromFile(...)

That stand-in is acceptable for isolated tests and fixtures, but the
production ingestion path must be capable of consuming an actual immutable
Reference Vault artifact through the existing authenticated EAM API.

The target production path is:

    EAM Reference Vault
          |
          | GET /vault/{id}
          | GET /vault/{id}/artifact
          v
    AcquisitionApiClient
          |
          | authenticated transport
          | artifact checksum verification
          v
    Studio-side Reference Vault Adapter
          |
          v
    VaultObjectInput
          |
          v
    IngestionOrchestrator
          |
          v
    Existing UIF pipeline

The UIF itself must remain source-agnostic.

The UIF must continue to consume VaultObjectInput rather than acquiring
knowledge of HTTP, EAM authentication, EAM routes, or Reference Vault
storage.

======================================================================
2. ARCHITECTURAL AUTHORITY
======================================================================

The following boundaries are FROZEN.

Do not reinterpret them.

----------------------------------------------------------------------
EAM / REFERENCE VAULT
----------------------------------------------------------------------

EAM owns:

    - engineering artifact acquisition
    - source identity
    - source verification
    - acquisition provenance
    - acquisition records
    - immutable Reference Vault custody
    - Vault Entry identity
    - artifact integrity metadata
    - artifact retrieval

The Reference Vault is the permanent evidence system of record.

The public EAM API intentionally does not expose the server's local
filesystem path.

Do not introduce a client dependency on vault_path.

----------------------------------------------------------------------
ACQUISITION API CLIENT
----------------------------------------------------------------------

AcquisitionApiClient owns:

    - authenticated communication with EAM
    - Vault Entry retrieval
    - artifact retrieval
    - HTTP response handling
    - transport errors
    - SHA-256 verification of downloaded artifact bytes

It must use the existing authentication mechanism.

Do not create a second authentication mechanism.

----------------------------------------------------------------------
REFERENCE VAULT ADAPTER
----------------------------------------------------------------------

A Studio-side adapter may translate the EAM Reference Vault representation
into the UIF's existing VaultObjectInput.

It owns translation/materialization only.

It does NOT become another Vault.

It must NOT:

    - create a database
    - persist a second copy as system-of-record evidence
    - modify EAM data
    - create acquisition records
    - modify Vault Entries
    - create Engineering Objects
    - commit Knowledge Candidates
    - call FoundationBridge
    - call CommitTransactionService
    - bypass EAM

----------------------------------------------------------------------
UNIVERSAL INGESTION FRAMEWORK
----------------------------------------------------------------------

UIF owns:

    - artifact identification
    - parser selection
    - metadata extraction
    - content extraction
    - structural analysis
    - OCR orchestration
    - entity extraction
    - relationship candidate generation
    - chunk generation when enabled
    - embedding generation when enabled
    - Knowledge Candidate generation
    - ingestion provenance
    - derived artifact production
    - IngestionResult generation

UIF does NOT own:

    - Reference Vault custody
    - EAM acquisition
    - acquisition records
    - Vault persistence
    - repository persistence
    - Engineering Knowledge Object commits
    - engineering truth/validation

----------------------------------------------------------------------
KNOWLEDGE STUDIO
----------------------------------------------------------------------

Knowledge Studio owns human inspection and curation.

The existing path remains:

    UIF
      |
      v
    Knowledge Candidates
      |
      v
    Knowledge Studio
      |
      v
    Review
      |
      v
    CommitTransactionService
      |
      v
    Engineering Repository

WP-INGEST-003 must not bypass this boundary.

----------------------------------------------------------------------
ENGINEERING REPOSITORY
----------------------------------------------------------------------

The Engineering Repository remains the system of record for accepted
Engineering Knowledge Objects and Relationships.

No UIF repository write path is part of this work package.

======================================================================
3. ARCHITECTURAL BASELINE
======================================================================

The preceding ingestion work is already implemented.

Relevant existing concepts include:

    VaultObjectInput
    IngestionRun
    IngestionResult
    DerivedArtifact
    DerivedArtifactFactory
    IngestionOrchestrator
    OcrPipelineService
    EngineeringEntityExtractionService
    CandidateGenerationService
    IngestionKnowledgeSessionBridge

WP-INGEST-001 established the first UIF vertical slice.

WP-INGEST-002 operationalized DerivedArtifact creation and provenance.

WP-INGEST-003 now connects that UIF to the production Reference Vault
boundary.

Do not replace those implementations.

Do not create parallel versions of them.

======================================================================
4. CURRENT REFERENCE VAULT CONTRACT
======================================================================

The current EAM API provides these relevant routes:

    GET /vault
    GET /vault/{id}
    GET /vault/{id}/status
    GET /vault/{id}/artifact
    POST /vault

For this work package the critical routes are:

    GET /vault/{id}

and:

    GET /vault/{id}/artifact

The artifact route returns the actual immutable artifact bytes.

The server provides:

    Content-Type
    Content-Length
    X-Checksum-Sha256

The client is expected to calculate SHA-256 over the received bytes and
verify the result against X-Checksum-Sha256.

The EAM API uses the existing bearer-token authentication mechanism.

Do not bypass it.

Do not introduce an alternate token store.

======================================================================
5. FIRST STEP — REPOSITORY RECONNAISSANCE
======================================================================

Before editing anything, inspect the actual repository.

At minimum inspect:

    platform/oep_studio/lib/acquisition/
    platform/oep_studio/lib/ingestion/
    services/acquisition/
    existing ingestion tests
    existing EAM API client
    existing authentication implementation
    existing Vault JSON representations
    existing VaultObjectInput
    existing production ingestion entry points

Search for all uses of:

    VaultObjectInput.fromFile
    VaultObjectInput(
    AcquisitionApiClient
    /vault/
    X-Checksum-Sha256

Determine:

    1. How AcquisitionApiClient currently performs authenticated requests.
    2. How Vault entries are currently represented on the Studio side.
    3. Whether an existing model can represent a Vault Entry.
    4. Whether an existing HTTP response abstraction can represent artifact
       bytes and headers.
    5. Where SHA-256 utilities already exist.
    6. Where production ingestion currently obtains its Vault input.
    7. Whether a temporary-file/materialization abstraction already exists.
    8. Whether an existing adapter pattern should be reused.
    9. How current tests mock HTTP/API behavior.
   10. Whether any existing code already solves part of this boundary.

DO NOT duplicate existing infrastructure.

If the repository already has an appropriate class, extend it rather than
creating another equivalent class.

======================================================================
6. REQUIRED CLIENT CAPABILITY — VAULT ENTRY
======================================================================

Extend AcquisitionApiClient with the capability to retrieve one Vault Entry.

Conceptually:

    Future<VaultEntry> getVaultEntry(String vaultObjectId)

The exact name and return type may differ if repository conventions require
another naming scheme.

Follow the existing codebase conventions.

The operation must:

    - use existing EAM authentication
    - call GET /vault/{id}
    - parse the authoritative server representation
    - preserve the Vault Entry UUID
    - preserve SHA-256
    - preserve MIME type
    - preserve file size
    - preserve status
    - preserve available provenance identity
    - preserve available metadata

Do not invent fields.

Do not fabricate Acquisition Record IDs.

If a value is not present in GET /vault/{id}, determine whether an existing
authoritative EAM route already exposes it.

Do not create a fake local provenance relationship.

======================================================================
7. REQUIRED CLIENT CAPABILITY — ARTIFACT DOWNLOAD
======================================================================

Extend AcquisitionApiClient with the capability to retrieve the actual
artifact bytes.

Conceptually:

    Future<DownloadedVaultArtifact> downloadVaultArtifact(
        String vaultObjectId
    )

The exact name may follow repository conventions.

The implementation must:

    1. Authenticate using the existing EAM credential mechanism.
    2. Request GET /vault/{id}/artifact.
    3. Check the HTTP response.
    4. Read the response bytes exactly as returned.
    5. Read X-Checksum-Sha256.
    6. Calculate SHA-256 over the exact received bytes.
    7. Compare local SHA-256 to the server checksum.
    8. Reject the artifact on mismatch.
    9. Return only a verified artifact to the next layer.

The client must not silently continue after checksum failure.

======================================================================
8. CHECKSUM REQUIREMENT
======================================================================

Integrity verification is mandatory.

The rule is:

    SHA256(downloaded bytes)
        ==
    X-Checksum-Sha256

Hexadecimal case differences must not cause a false mismatch.

The exact bytes received from the HTTP response must be hashed.

Do NOT:

    - hash a decoded/re-encoded representation
    - hash a transformed PDF
    - hash text extracted from the PDF
    - trust Content-Length as integrity verification
    - trust the Vault metadata alone
    - skip verification when the header is absent
    - silently accept mismatches
    - modify the artifact before hashing

If X-Checksum-Sha256 is missing when the existing API contract requires it,
treat that as an integrity/contract failure rather than silently accepting
the artifact.

======================================================================
9. DOWNLOAD RESULT MODEL
======================================================================

If an appropriate existing model does not exist, create a small focused
transport result model.

It should contain only what the adapter needs.

Conceptually:

    DownloadedVaultArtifact

with information such as:

    bytes
    checksum
    contentType
    contentLength

Do not put ingestion behavior into this model.

Do not make the model responsible for:

    - OCR
    - parsing
    - candidate generation
    - persistence
    - repository commits

======================================================================
10. VAULT ADAPTER
======================================================================

Create or extend a focused adapter that converts the authoritative EAM
Vault representation plus verified artifact into the existing
VaultObjectInput.

Conceptual operation:

    Vault Entry
        +
    Verified Artifact
        |
        v
    Vault Adapter
        |
        v
    VaultObjectInput

VaultObjectInput remains the UIF boundary.

The adapter must preserve:

    vaultObjectId
    acquisitionRecordIds
    artifactType
    mimeType
    contentHash
    storageReference
    immutableMetadataSnapshot

Do not change VaultObjectInput's architecture merely to accommodate EAM.

======================================================================
11. VAULT OBJECT IDENTITY
======================================================================

The authoritative Vault Entry UUID must become:

    VaultObjectInput.vaultObjectId

Therefore:

    EAM Vault Entry UUID
        ==
    VaultObjectInput.vaultObjectId

Do not generate a replacement UUID.

Do not use a local filename as identity.

Do not use a hash as the Vault Object ID.

The SHA-256 remains the content identity/integrity value.

======================================================================
12. CONTENT HASH
======================================================================

The content hash in VaultObjectInput must correspond to the verified
artifact bytes.

Therefore:

    SHA256(downloaded artifact bytes)
        ==
    VaultObjectInput.contentHash

This must be tested explicitly.

======================================================================
13. MIME / ARTIFACT TYPE
======================================================================

Use the authoritative MIME type from the EAM representation/response.

The first production vertical slice supports PDF.

For example:

    application/pdf
        ->
    ArtifactType.pdf

Do not classify an unknown MIME type as PDF merely to make ingestion run.

If the existing ArtifactType implementation already has a mapping function,
reuse it.

If unsupported artifact types are encountered, fail clearly at the
appropriate boundary.

Do not add a complete universal MIME taxonomy in this work package.

======================================================================
14. STORAGE REFERENCE
======================================================================

The public EAM API intentionally does not expose the server's local
vault_path.

Do not expose or reconstruct that path.

If existing UIF parsing/OCR requires a local filesystem path, use a
temporary/local materialization mechanism at the Studio boundary.

The conceptual flow is:

    Reference Vault
        |
        | artifact bytes
        v
    Studio
        |
        | temporary materialization
        v
    VaultObjectInput.storageReference
        |
        v
    UIF

The local file is a working representation only.

It is NOT:

    - the Reference Vault
    - a new evidence system of record
    - a persistent duplicate Vault
    - a replacement for EAM

Use an existing temporary-file abstraction if one exists.

If none exists, implement the smallest isolated materialization mechanism
required by the existing parser/OCR pipeline.

It must have appropriate cleanup semantics.

Do not introduce permanent local artifact storage.

======================================================================
15. IMMUTABLE METADATA SNAPSHOT
======================================================================

Populate:

    immutableMetadataSnapshot

from authoritative EAM Reference Vault information available through the
existing API.

Preserve relevant information such as:

    - Vault Entry ID
    - Acquisition identity
    - MIME type
    - SHA-256
    - file size
    - source identity
    - publication information
    - existing artifact metadata

Do not fabricate information.

Do not overwrite EAM metadata.

Do not create a second authoritative metadata model.

The snapshot is an ingestion input representation.

======================================================================
16. ACQUISITION RECORD PROVENANCE
======================================================================

Preserve the existing EAM provenance relationship.

The established conceptual chain is:

    Vault Entry
        |
        v
    Acquisition Record
        |
        +--> Download Session
        +--> Source
        +--> Verification
        +--> Metadata
        +--> Acquisition Job / Execution

If the Vault API exposes Acquisition Record identity, preserve it.

If another existing EAM API endpoint is required to resolve that identity,
use that authoritative endpoint.

Do NOT create a new Studio-side Acquisition Record.

Do NOT duplicate EAM provenance.

If the current API contract does not expose a required relationship,
STOP and document the exact gap rather than inventing it.

======================================================================
17. PRODUCTION INGESTION ENTRY POINT
======================================================================

Locate the current production code path that constructs:

    VaultObjectInput.fromFile(...)

for the TRX300 ingestion vertical slice.

Replace that production source with the Reference Vault adapter.

The resulting flow must be:

    Vault Object ID
        |
        v
    AcquisitionApiClient.getVaultEntry()
        |
        v
    AcquisitionApiClient.downloadVaultArtifact()
        |
        v
    SHA-256 verification
        |
        v
    Reference Vault Adapter
        |
        v
    VaultObjectInput
        |
        v
    IngestionOrchestrator

Do not modify the internals of IngestionOrchestrator unless a demonstrated
interface mismatch makes it unavoidable.

The objective is to change the INPUT SOURCE, not redesign UIF.

======================================================================
18. UIF SOURCE AGNOSTICISM
======================================================================

After this work, UIF must still operate on:

    VaultObjectInput

It must NOT directly depend upon:

    AcquisitionApiClient
    ReferenceVaultService
    EAM HTTP routes
    bearer credentials
    HTTP response types
    EAM database types

The prohibited dependency is:

    UIF
      |
      +--> AcquisitionApiClient

The required dependency direction is:

    AcquisitionApiClient
          |
          v
    Vault Adapter
          |
          v
    VaultObjectInput
          |
          v
    UIF

======================================================================
19. EXISTING UIF PIPELINE MUST REMAIN INTACT
======================================================================

Do not replace:

    OcrPipelineService
    EngineeringEntityExtractionService
    CandidateGenerationService
    DerivedArtifactFactory
    IngestionKnowledgeSessionBridge

Reuse the existing implementations.

The production Reference Vault boundary exists before UIF processing.

The existing UIF sequence remains authoritative.

======================================================================
20. KNOWLEDGE CANDIDATE BOUNDARY
======================================================================

Candidates remain findings pending human review.

The ingestion path must NOT:

    - commit candidates
    - create Engineering Objects
    - create Engineering Relationships in the repository
    - invoke CommitTransactionService
    - invoke FoundationBridge

The existing state remains:

    KnowledgeCandidate
        status = pending
        committedObjectId = null

where applicable.

======================================================================
21. ERROR SEMANTICS
======================================================================

Implement explicit handling for:

----------------------------------------------------------------------
404 — VAULT ENTRY NOT FOUND
----------------------------------------------------------------------

GET /vault/{id} returns 404.

Result:

    retrieval failure

Do not invoke UIF.

----------------------------------------------------------------------
404 — ARTIFACT NOT FOUND
----------------------------------------------------------------------

GET /vault/{id}/artifact returns 404.

Result:

    retrieval failure

Do not invoke UIF.

----------------------------------------------------------------------
500 artifact_missing
----------------------------------------------------------------------

If the EAM API reports:

    artifact_missing

surface it as a Reference Vault retrieval failure.

Do not convert it into a parser failure.

----------------------------------------------------------------------
401 — AUTHENTICATION FAILURE
----------------------------------------------------------------------

Use existing authentication handling.

Do not create a second credential workflow.

----------------------------------------------------------------------
403 — AUTHORIZATION FAILURE
----------------------------------------------------------------------

Surface clearly.

Do not retry indefinitely.

----------------------------------------------------------------------
NETWORK FAILURE
----------------------------------------------------------------------

Surface as transport failure.

Do not construct a partially valid VaultObjectInput.

----------------------------------------------------------------------
MISSING CHECKSUM
----------------------------------------------------------------------

If checksum verification is mandatory by the established contract:

    fail integrity verification.

Do not silently accept the artifact.

----------------------------------------------------------------------
CHECKSUM MISMATCH
----------------------------------------------------------------------

Treat as an integrity failure.

Do not invoke UIF with the artifact.

----------------------------------------------------------------------
UNSUPPORTED MIME TYPE
----------------------------------------------------------------------

Reject at the appropriate input boundary.

Do not falsely classify it as PDF.

======================================================================
22. TESTING — CLIENT
======================================================================

Add focused tests for the Reference Vault client boundary.

At minimum:

TEST-RV-001
    GET /vault/{id} returns a valid Vault Entry.

Verify:

    - UUID
    - SHA-256
    - MIME type
    - size
    - status
    - available metadata

TEST-RV-002
    GET /vault/{id}/artifact returns valid bytes.

Verify:

    - response success
    - bytes received
    - checksum header present
    - local SHA-256 matches server checksum

TEST-RV-003
    Checksum mismatch.

Verify:

    - operation fails
    - artifact is not accepted
    - UIF is not invoked

TEST-RV-004
    Missing checksum.

Verify behavior according to the established integrity contract.

TEST-RV-005
    Vault Entry 404.

Verify:

    - clear retrieval failure
    - UIF is not invoked

TEST-RV-006
    Artifact 404.

Verify:

    - clear retrieval failure
    - UIF is not invoked

TEST-RV-007
    Authentication failure.

Verify existing authentication handling.

TEST-RV-008
    Authorization failure.

Verify clear failure.

======================================================================
23. TESTING — ADAPTER
======================================================================

Add tests for:

TEST-RV-009
    Vault Entry + verified artifact -> VaultObjectInput.

Verify:

    Vault Entry UUID
        ==
    vaultObjectId

    verified SHA-256
        ==
    contentHash

    authoritative MIME
        ==
    mimeType

    acquisition identity preserved

    metadata snapshot populated appropriately

TEST-RV-010
    storageReference is a local working representation only and does not
    contain an EAM server filesystem path.

TEST-RV-011
    Unsupported MIME type is not falsely classified as PDF.

======================================================================
24. TESTING — PRODUCTION VERTICAL SLICE
======================================================================

Add or adapt an integration-level test capable of exercising:

    Reference Vault
        ->
    EAM API
        ->
    AcquisitionApiClient
        ->
    checksum verification
        ->
    Vault Adapter
        ->
    VaultObjectInput
        ->
    IngestionOrchestrator

The TRX300 artifact is the acceptance artifact.

Where a real EAM server/test fixture is unavailable, isolate the HTTP
boundary using the repository's existing test mechanisms and clearly
document what was and was not exercised.

Do not falsely report a mocked test as a live EAM integration test.

======================================================================
25. TRX300 ACCEPTANCE PATH
======================================================================

The intended first production path is:

    TRX300 Reference Vault Artifact
              |
              v
        EAM Reference Vault
              |
              v
        GET /vault/{id}
              |
              v
        GET /vault/{id}/artifact
              |
              v
      SHA-256 Verification
              |
              v
      VaultObjectInput
              |
              v
      IngestionOrchestrator
              |
              +--> identification
              +--> parser selection
              +--> metadata extraction
              +--> content extraction
              +--> structural analysis
              +--> OCR
              +--> entity extraction
              +--> relationship candidates
              +--> Knowledge Candidates
              |
              v
         IngestionResult
              |
              v
       Knowledge Session

Do not modify the TRX300 ground truth.

Do not modify the electrical solver.

The existing live electrical solver remains the sole behavior authority for
electrical correctness.

======================================================================
26. PRESERVE LOCAL FILE TEST SUPPORT
======================================================================

Do not delete:

    VaultObjectInput.fromFile(...)

simply because production now uses EAM.

It remains valuable for:

    - unit tests
    - parser tests
    - OCR tests
    - deterministic fixtures
    - offline development
    - failure isolation

The requirement is:

    production ingestion
        !=
    filesystem stand-in

It is NOT:

    filesystem stand-in
        must be deleted

======================================================================
27. NO DATABASE WORK
======================================================================

WP-INGEST-003 must not introduce:

    - UIF database
    - Studio Vault database
    - local PostgreSQL schema
    - second Reference Vault
    - ingestion persistence database
    - new Flyway migration

Derived artifacts remain governed by the existing UIF architecture.

Do not introduce persistence simply because the production artifact arrives
over HTTP.

======================================================================
28. NO EAM SERVER CHANGES
======================================================================

Do not modify:

    ReferenceVaultService
    IVaultRepository
    VaultEntry
    reference_vault schema
    EAM migrations
    artifact publication semantics
    EAM authentication architecture

The EAM boundary has already been implemented.

If the actual current API proves insufficient for a mandatory requirement:

    STOP.

Do not "fix" the EAM server inside this work package.

Report:

    - exact missing capability
    - file/route involved
    - why it blocks the acceptance criterion
    - recommended follow-up work package

======================================================================
29. NO SECOND VAULT
======================================================================

This is especially important.

Do not create:

    LocalVault
    StudioVault
    UIFVault
    IngestionVault
    CachedReferenceVault

unless an already-existing architecture explicitly requires a temporary
materialization component.

A temporary downloaded file is NOT a Vault.

======================================================================
30. NO SECOND OCR SYSTEM
======================================================================

Do not introduce another OCR implementation.

Use:

    OcrPipelineService

already present in the repository.

======================================================================
31. NO EMBEDDING EXPANSION
======================================================================

Do not make embeddings a prerequisite for this work package.

The first production ingestion slice remains centered on:

    identify
    parser selection
    metadata
    content
    structure
    OCR
    entity extraction
    relationship candidates
    candidate generation

Do not expand WP-INGEST-003 into an embedding architecture project.

======================================================================
32. NO UI REDESIGN
======================================================================

Do not perform unrelated OEP Studio UI work.

Do not alter:

    StudioShell
    Global Studio Bar
    Workspace Bar
    Context Navigation
    Global Toolbar
    Inspector
    Status Bar

unless a specific existing ingestion entry point requires a minimal
integration change.

If UI work becomes necessary beyond the ingestion boundary, stop and report
it as scope expansion.

======================================================================
33. NO ARCHITECTURE REWRITE
======================================================================

Do not:

    - redesign VaultObjectInput
    - redesign IngestionOrchestrator
    - redesign IngestionResult
    - redesign Knowledge Studio
    - redesign EAM
    - redesign Repository
    - redesign provenance
    - introduce dependency injection frameworks solely for this work
    - introduce a new networking stack
    - introduce a new HTTP client if the existing client is adequate

Use the smallest change that establishes the frozen boundary.

======================================================================
34. TEMPORARY MATERIALIZATION RULE
======================================================================

If the existing UIF requires a file path:

    download verified bytes
        ->
    temporary file
        ->
    VaultObjectInput.storageReference

The temporary file must:

    - contain the exact verified bytes
    - not be modified before UIF receives it
    - be safely scoped
    - be cleaned up when its lifecycle ends

Do not hash the temporary file instead of the original response unless the
bytes are guaranteed identical.

Prefer:

    response bytes
        ->
    hash
        ->
    verified
        ->
    write exact bytes
        ->
    UIF

The resulting file must be a byte-for-byte representation of the verified
artifact.

======================================================================
35. SECURITY
======================================================================

Do not log:

    - bearer tokens
    - credentials
    - authorization headers
    - sensitive HTTP headers

Do not include credentials in exceptions.

Do not expose EAM server filesystem paths.

Do not weaken TLS or authentication.

Do not introduce insecure HTTP fallbacks.

======================================================================
36. RESOURCE MANAGEMENT
======================================================================

Pay attention to:

    - response body lifecycle
    - temporary file cleanup
    - stream disposal
    - HTTP client lifecycle
    - memory usage

Do not unnecessarily load very large artifacts into memory if the existing
client architecture supports streaming.

However, do not redesign the transport layer solely for theoretical scale.

Follow existing repository patterns first.

======================================================================
37. IMPLEMENTATION ORDER
======================================================================

Implement in this order:

STEP 1
    Inspect the repository and establish the actual baseline.

STEP 2
    Inspect AcquisitionApiClient and existing authentication.

STEP 3
    Inspect the EAM Vault JSON contract.

STEP 4
    Inspect VaultObjectInput and the current filesystem stand-in.

STEP 5
    Locate production ingestion entry points.

STEP 6
    Reuse existing models/utilities wherever possible.

STEP 7
    Implement Vault Entry retrieval.

STEP 8
    Implement artifact retrieval.

STEP 9
    Implement checksum verification.

STEP 10
    Implement or extend the focused Vault adapter.

STEP 11
    Implement temporary materialization only if the existing UIF requires it.

STEP 12
    Replace the production TRX300 filesystem input path.

STEP 13
    Add focused unit tests.

STEP 14
    Add/adapt integration coverage.

STEP 15
    Run static analysis.

STEP 16
    Run ingestion tests.

STEP 17
    Run broader tests.

STEP 18
    Build Windows debug.

STEP 19
    Inspect git diff and git status.

STEP 20
    Produce the AAR.

STEP 21
    Commit only the scoped changes.

======================================================================
38. TESTING DISCIPLINE
======================================================================

Do not weaken existing tests merely to make the suite pass.

Do not modify unrelated failing tests.

If failures exist before your changes:

    record them as PRE-EXISTING.

If your changes create new failures:

    record them as NEW.

If a failure is ambiguous:

    investigate before classifying it.

Do not claim a clean test suite if the repository has known pre-existing
failures.

======================================================================
39. ANALYZER / BUILD VERIFICATION
======================================================================

Run:

    dart analyze

and the relevant ingestion tests.

Run the broader Studio test suite where practical.

Run:

    flutter build windows --debug

or the repository's established equivalent.

Record exact results.

Do not report only "build successful."

Record:

    analyzer:
    ingestion tests:
    full tests:
    Windows build:

Include pre-existing failures separately.

======================================================================
40. GIT DISCIPLINE
======================================================================

Before implementation record:

    git rev-parse HEAD
    git status

Do not overwrite or discard unrelated user changes.

This repository may contain unrelated working-tree changes.

Do NOT use:

    git reset --hard
    git clean -fd
    destructive checkout operations

to make the repository clean.

Preserve unrelated modifications.

At completion run:

    git diff --stat
    git diff
    git status

Inspect every changed file.

Do not commit unrelated changes.

======================================================================
41. COMMIT
======================================================================

Use one focused commit unless the repository's actual state requires a
different disciplined split.

Recommended commit message:

    feat(ingestion): connect UIF to Reference Vault boundary

Before committing verify:

    - no unrelated files
    - no secrets
    - no generated garbage
    - no temporary artifacts
    - no debug output
    - no accidental architecture documents
    - no unrelated UI changes

After commit report the exact SHA.

======================================================================
42. AAR REQUIREMENT
======================================================================

Produce an After Action Review for WP-INGEST-003.

The AAR must contain:

# WP-INGEST-003 — Implementation AAR

## 1. Baseline

    Baseline commit:
    <SHA>

    Working tree state:
    <summary>

## 2. Objective

Explain the production Reference Vault -> UIF boundary implemented.

## 3. Files Changed

List every file:

    - modified
    - created

For each file explain its role.

## 4. Actual Architecture

Show:

    EAM Reference Vault
        ->
    AcquisitionApiClient
        ->
    Vault Adapter
        ->
    VaultObjectInput
        ->
    UIF

## 5. Vault Identity

Demonstrate:

    Vault Entry UUID
        ==
    VaultObjectInput.vaultObjectId

## 6. Integrity

Demonstrate:

    X-Checksum-Sha256
        ==
    SHA256(downloaded bytes)
        ==
    VaultObjectInput.contentHash

## 7. Provenance

Demonstrate preservation of:

    Vault Entry
        ->
    Acquisition Record
        ->
    Ingestion Run
        ->
    Processing Stage
        ->
    Derived Artifact
        ->
    Evidence

If a link could not be propagated because the current API does not expose
it, state that precisely.

## 8. UIF Boundary

Demonstrate that UIF remains independent of:

    - EAM HTTP
    - EAM authentication
    - Reference Vault persistence

## 9. Repository Boundary

Demonstrate that no UIF path was added to:

    FoundationBridge
    CommitTransactionService
    Engineering Repository

## 10. Test Results

List every new test.

Use:

    PASS
    FAIL
    BLOCKED

with actual evidence.

## 11. Regression Results

Separate:

    PRE-EXISTING
    NEW

failures.

## 12. Static Analysis

Record exact analyzer result.

## 13. Build

Record exact Windows build result.

## 14. Production Vertical Slice

State whether the TRX300 path was actually exercised.

Distinguish:

    live integration
    mocked integration
    unit-only verification

Do not conflate them.

## 15. Limitations

List only real limitations.

Do not hide unresolved issues.

## 16. Scope Compliance

Explicitly confirm whether any of the following were modified:

    - EAM server
    - Reference Vault database
    - UIF architecture
    - Repository commit boundary
    - electrical solver
    - TRX300 ground truth
    - unrelated UI architecture

## 17. Final Determination

Use exactly one:

    COMPLETE

or:

    COMPLETE WITH DISCLOSED LIMITATION

or:

    BLOCKED

Do not claim COMPLETE if a required acceptance criterion was not verified.

======================================================================
43. ACCEPTANCE CRITERIA
======================================================================

WP-INGEST-003 is complete only when:

[ ] AcquisitionApiClient can retrieve a Vault Entry.

[ ] AcquisitionApiClient can retrieve the actual artifact bytes.

[ ] Existing EAM authentication is used.

[ ] X-Checksum-Sha256 is validated against locally calculated SHA-256.

[ ] Checksum mismatch prevents ingestion.

[ ] Missing checksum is handled according to the integrity contract.

[ ] Vault Entry UUID becomes VaultObjectInput.vaultObjectId.

[ ] Verified artifact SHA-256 becomes VaultObjectInput.contentHash.

[ ] MIME type is preserved.

[ ] Artifact type is correctly determined.

[ ] Acquisition identity is preserved where exposed by the authoritative
    EAM contract.

[ ] Immutable metadata snapshot is populated from authoritative EAM data.

[ ] No EAM filesystem path is exposed.

[ ] Temporary materialization, if required, contains the exact verified
    bytes.

[ ] Production ingestion no longer requires the TRX300 filesystem
    stand-in.

[ ] VaultObjectInput remains the UIF boundary.

[ ] UIF has no direct dependency on AcquisitionApiClient.

[ ] UIF has no direct dependency on EAM HTTP.

[ ] UIF has no direct dependency on EAM authentication.

[ ] UIF does not create a second Vault.

[ ] Existing OCR implementation remains authoritative.

[ ] Existing entity extraction remains authoritative.

[ ] Existing candidate generation remains authoritative.

[ ] Existing DerivedArtifact architecture remains intact.

[ ] Existing Knowledge Session bridge remains intact.

[ ] UIF does not commit to the Engineering Repository.

[ ] Existing VaultObjectInput.fromFile test support remains available.

[ ] TRX300 production vertical slice is exercised, or exact environment
    limitations are documented.

[ ] New tests pass.

[ ] Existing regressions are distinguished from pre-existing failures.

[ ] dart analyze result is recorded.

[ ] Windows build result is recorded.

[ ] No unrelated changes are included.

[ ] AAR is produced.

[ ] Focused commit is created.

======================================================================
44. STOP CONDITIONS
======================================================================

STOP and report instead of improvising if:

    1. The EAM API contract differs materially from this specification.
    2. Required provenance cannot be obtained from an authoritative source.
    3. AcquisitionApiClient's authentication architecture cannot support the
       operation without redesign.
    4. VaultObjectInput cannot represent the required boundary without an
       architectural change.
    5. Existing UIF requires a capability that this work package would have
       to redesign.
    6. A server-side EAM modification appears necessary.
    7. A new database appears necessary.
    8. Repository commit integration appears necessary.
    9. The production ingestion path cannot be identified safely.
   10. An unrelated working-tree modification would be overwritten.
   11. A required acceptance test cannot be implemented without expanding
       scope.

When a STOP condition occurs, do not solve it by silently changing the
architecture.

Report:

    - what was found
    - exact file/component
    - why it conflicts
    - what remains possible
    - recommended follow-up work package

======================================================================
45. IMPORTANT DISTINCTION
======================================================================

This work package is NOT:

    "make UIF download PDFs."

It is:

    "establish the production architectural boundary by which UIF consumes
     immutable Reference Vault evidence without taking ownership of that
     evidence."

The distinction is critical.

The correct architecture is:

    EAM owns evidence custody.
    AcquisitionApiClient transports evidence.
    Adapter translates the evidence contract.
    UIF transforms evidence into candidates.
    Knowledge Studio reviews candidates.
    Engineering Repository stores accepted knowledge.

Do not collapse those responsibilities.

======================================================================
46. FINAL ARCHITECTURAL INVARIANT
======================================================================

The completed implementation must preserve:

                         EAM
                          |
                          v
                  REFERENCE VAULT
                          |
             +------------+------------+
             |                         |
       GET /vault/{id}        GET /vault/{id}/artifact
             |                         |
             +------------+------------+
                          |
                          v
                AcquisitionApiClient
                          |
                   authenticated
                          |
                  checksum verified
                          |
                          v
                  Vault Adapter
                          |
                          v
                  VaultObjectInput
                          |
                          v
           UNIVERSAL INGESTION FRAMEWORK
                          |
          +---------------+----------------+
          |               |                |
          v               v                v
      Extraction      Candidates       Evidence
                          |
                          v
                  Knowledge Studio
                          |
                        Review
                          |
                          v
               CommitTransactionService
                          |
                          v
               ENGINEERING REPOSITORY

The Reference Vault remains the system of record for engineering evidence.

The Engineering Repository remains the system of record for accepted
engineering knowledge.

UIF remains the transformation boundary between those systems.

No implementation choice in WP-INGEST-003 may collapse these boundaries.

======================================================================
47. EXECUTION INSTRUCTION
======================================================================

Proceed with implementation.

Do not ask for confirmation for decisions already explicitly resolved by
this work package.

Use repository evidence over assumptions.

Make the smallest correct implementation.

Do not expand scope.

Do not modify unrelated work.

At the end, provide the complete AAR and exact commit SHA.

If all acceptance criteria pass:

    report COMPLETE.

If implementation works but a non-blocking, explicitly documented limitation
remains:

    report COMPLETE WITH DISCLOSED LIMITATION.

If a required boundary cannot be implemented without architectural or
out-of-scope changes:

    report BLOCKED and stop rather than improvising.