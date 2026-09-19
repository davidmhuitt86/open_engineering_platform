# AP-INGEST-003 — PRODUCTION REFERENCE VAULT → UIF BOUNDARY

**Repository:** `davidmhuitt86/open_engineering_platform`  
**Architecture Domain:** Universal Ingestion Framework  
**Predecessors:** AP-INGEST-001, WP-INGEST-001, WP-INGEST-002  
**Status:** Architecture Specification — Implementation Not Yet Authorized  
**Primary Boundary:** Reference Vault → Universal Ingestion Framework  
**Primary Acceptance Dataset:** TRX300 Factory Wiring Diagram

## 1. Purpose

Establish the production boundary through which UIF consumes an immutable engineering artifact from the Reference Vault.

The objective is to replace the first-slice filesystem stand-in represented by `VaultObjectInput.fromFile(...)` with a production-grade Reference Vault consumption boundary.

This phase does not redesign UIF, Reference Vault, or create a second artifact repository.

## 2. Frozen Architecture

```text
EAM
 ↓
Reference Vault
 ↓
UIF
 ↓
Knowledge Candidates
 ↓
Knowledge Studio
 ↓
Engineering Review
 ↓
Engineering Repository
```

Ownership remains:

- **EAM:** acquisition, source verification, custody, acquisition provenance.
- **Reference Vault:** authoritative engineering evidence and durable evidence.
- **UIF:** identification, parsing, extraction, normalization, orchestration, candidate production.
- **Knowledge Studio:** human inspection, curation, review.
- **Engineering Repository:** accepted engineering objects, relationships, revisions.

UIF does not become the owner of Vault evidence.

## 3. First-Slice Condition

WP-INGEST-001 established `VaultObjectInput` as the conceptual UIF input contract. The first implementation uses a filesystem-backed stand-in. WP-INGEST-002 operationalized Derived Artifacts while retaining transient per-run results.

The target becomes:

```text
Reference Vault
 ↓
Vault Object access boundary
 ↓
VaultObjectInput
 ↓
IngestionOrchestrator
```

The filesystem fixture must not become production architecture.

## 4. Production Input Contract

UIF shall receive, at minimum:

```text
vaultObjectId
acquisitionRecordIds
artifactType
mimeType
contentHash
storageReference
immutableMetadataSnapshot
```

These values must originate from authoritative Reference Vault information. UIF must not reconstruct them from arbitrary filesystem metadata.

## 5. Ownership and Read-Only Consumption

Reference Vault owns:

```text
artifact bytes
Vault Object identity
immutable evidence metadata
artifact content hash
durable evidence provenance
artifact lifecycle
artifact version relationships
```

UIF owns:

```text
processing execution
parser selection
normalized extraction
processing-stage results
DerivedArtifact representations
candidate generation
processing provenance
```

UIF may materialize a working copy for processing, but that copy never becomes authoritative evidence.

The production boundary is read-only from UIF's perspective. UIF shall not update/delete/replace Vault objects, alter acquisition records, change licensing state, or change Vault lifecycle state.

## 6. Existing EAM / Reference Vault Capability

The existing repository contains a Vault artifact retrieval capability associated with:

```text
/vault/{id}/artifact
```

Before implementation, trace the actual route, service, repository, storage, metadata, authentication, authorization, integrity, and error semantics.

Do not create another artifact-download API if the existing capability satisfies the contract.

Do not assume an HTTP endpoint is automatically the final architecture.

## 7. Boundary Location

The production adapter belongs at the UIF consumption boundary:

```text
Reference Vault Adapter
 ↓
VaultObjectInput
 ↓
IngestionOrchestrator
 ↓
Parser
```

The parser must remain unaware of HTTP, PostgreSQL, EAM, authentication, and Reference Vault implementation details.

Preferred dependency direction:

```text
UIF
 ↓
Vault Input Provider abstraction
 ↓
Reference Vault implementation
```

not:

```text
PdfParser
 ↓
EAM HTTP
```

## 8. No Second Vault

Do not create:

```text
UifVaultRepository
LocalReferenceVault
IngestionVault
StudioVault
Second artifact database
Second artifact registry
```

unless an explicit architecture decision demonstrates that the existing boundary cannot satisfy production requirements.

A disposable processing cache, if needed, is not authoritative.

```text
Reference Vault = source of truth
Cache = disposable processing copy
```

## 9. Artifact Bytes

The boundary must support actual artifact bytes. The implementation may use bytes, streams, temporary files, or another strategy appropriate to existing parser requirements.

If temporary materialization is required:

```text
Vault
 ↓
read-only retrieval
 ↓
temporary processing materialization
 ↓
Parser
```

The temporary file is not a Vault Object.

## 10. Content Hash and Integrity

The authoritative artifact content hash comes from Reference Vault.

UIF may recompute the hash for integrity verification.

Distinguish:

```text
Vault contentHash
    = source evidence identity/integrity

DerivedArtifact contentHash
    = processing-product identity/integrity
```

If retrieved bytes do not match the authoritative Vault hash:

```text
STOP processing
record integrity failure
do not create trusted downstream candidates
do not mutate Vault
```

## 11. Immutable Metadata and Acquisition Provenance

Reference Vault must provide the immutable metadata snapshot required by UIF, using only fields actually present in the current Vault contract.

UIF must preserve acquisition record identifiers supplied by Reference Vault:

```text
Vault Object
 ↓
Acquisition Record(s)
 ↓
Ingestion Run
```

UIF must not manufacture Acquisition Records.

## 12. Authentication and Authorization

Use the existing authorized Reference Vault/EAM access mechanism.

Do not embed credentials, tokens, API keys, or database credentials in source code or ingestion configuration.

If a production authorization mechanism does not exist, mark the architecture **BLOCKED** rather than inventing one.

## 13. Network Boundary

Respect the existing server boundary.

Reference Vault/EAM network services remain service-side concerns. UIF consumes a service contract.

Do not move TLS termination, database access, Vault repository implementation, or EAM authentication into Flutter ingestion.

## 14. Error Semantics

The production boundary must distinguish, using existing repository conventions where possible:

```text
NOT_FOUND
UNAUTHORIZED
FORBIDDEN
NETWORK_ERROR
TIMEOUT
INVALID_RESPONSE
INTEGRITY_FAILURE
UNSUPPORTED_ARTIFACT
STORAGE_FAILURE
```

Do not turn every Vault failure into a parser failure.

## 15. Revision Semantics

If Reference Vault exposes revisions, UIF must identify the actual immutable version being processed.

Do not silently substitute one revision for another.

If revision identity is not currently exposed, document that limitation rather than inventing revision semantics.

## 16. Ingestion Identity and Idempotency

`IngestionRun` remains a processing identity and does not replace Vault or Acquisition identities.

Processing identity remains:

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

Do not use filesystem path, filename, or download timestamp as the authoritative processing identity.

## 17. Retry Semantics

Transient retrieval failures may be retried.

Conceptually:

```text
network timeout        → retry eligible
temporary service fail → retry eligible
not found              → no blind retry
unauthorized            → no blind retry
integrity mismatch     → stop/investigate
```

Follow existing repository conventions.

## 18. Large Artifacts

Do not prematurely optimize the first vertical slice.

The abstraction should nevertheless permit streamed retrieval or another large-artifact strategy later. The TRX300 PDF may remain a simple first acceptance fixture.

## 19. UIF Purity

The conceptual API is:

```text
VaultObjectProvider
    getVaultObject(vaultObjectId)
        → VaultObjectInput
```

Actual naming may follow repository conventions.

The returned object is an input contract, not a repository handle.

Do not expose PostgreSQL connections, HTTP clients, EAM service objects, or filesystem repositories to parsers.

## 20. Knowledge Studio Boundary

Knowledge Studio continues to consume `IngestionResult`.

The ingestion path remains:

```text
Vault
 ↓
UIF
 ↓
IngestionResult
 ↓
Knowledge Studio
```

Knowledge Studio must not bypass UIF for this ingestion workflow.

## 21. Derived Artifact Interaction

WP-INGEST-002 is frozen.

Production Vault integration must preserve:

```text
Vault source contentHash
 ↓
IngestionRun
 ↓
DerivedArtifact
```

Do not collapse source and derived hashes or identities.

## 22. TRX300 Acceptance

The first production acceptance path is:

```text
Reference Vault
 ↓
TRX300 Vault Object
 ↓
VaultObjectInput
 ↓
UIF
 ↓
IngestionRun
 ↓
DerivedArtifacts
 ↓
OCR / Entities / Candidates
 ↓
Knowledge Studio
```

The TRX300 source PDF and ground truth remain unchanged.

## 23. Required Tests

Implement focused tests for:

```text
TEST-VB-001  Vault Object Retrieval
TEST-VB-002  Identity Preservation
TEST-VB-003  Metadata Preservation
TEST-VB-004  Byte Retrieval
TEST-VB-005  Hash Verification
TEST-VB-006  Integrity Failure
TEST-VB-007  Not Found
TEST-VB-008  Authorization Failure
TEST-VB-009  UIF Boundary Isolation
TEST-VB-010  TRX300 End-to-End
TEST-VB-011  Provenance
TEST-VB-012  No Vault Mutation
```

If the existing server can be exercised deterministically, add a focused integration test. Do not make the complete Flutter unit suite dependent on a running server unless that is already repository convention.

## 24. Security

Verify:

```text
credentials are not stored in VaultObjectInput
credentials are not logged
artifact bytes are not logged
authorization failures are not converted to empty artifacts
```

Do not add new credential storage.

## 25. Observability

Boundary diagnostics may identify:

```text
vaultObjectId
ingestionRunId
operation
failure category
```

Never log credentials, authorization tokens, or entire engineering documents.

## 26. Persistence

AP-INGEST-003 does not authorize permanent persistence of ingestion results.

The existing architecture remains:

```text
Reference Vault
    = durable evidence

IngestionResult
    = processing result

KnowledgeSessionRecord
    = curation workspace

Engineering Repository
    = accepted engineering knowledge
```

If production operation demonstrates that DerivedArtifacts require durable storage, that becomes a separate architectural decision/work package.

## 27. Stop Conditions

Stop and report if:

1. Reference Vault has no usable production retrieval contract.
2. Existing EAM retrieval cannot safely expose immutable objects.
3. Authentication/authorization is undefined.
4. Artifact integrity cannot be established.
5. Revision identity is ambiguous in a way that threatens traceability.
6. Integration requires a new database.
7. Integration requires a second Vault.
8. UIF must directly access PostgreSQL.
9. UIF must modify Vault state.
10. Knowledge Studio must bypass UIF.
11. AP-INGEST-001 ownership rules must change.
12. WP-INGEST-002 must be reopened.

Use:

```text
BLOCKED

Condition:
Evidence:
Affected boundary:
Minimal architecture decision required:
```

## 28. Implementation Authorization

Do not implement AP-INGEST-003 until this specification is explicitly approved.

After approval, implementation shall be a focused:

```text
WP-INGEST-003
Production Reference Vault → UIF Boundary
```

The implementation must make the smallest possible change necessary to replace the filesystem stand-in while preserving the existing UIF pipeline.

## 29. Architecture Acceptance Gate

Before implementation:

```text
[ ] Reference Vault ownership confirmed.
[ ] Existing artifact retrieval path confirmed.
[ ] Vault Object metadata contract confirmed.
[ ] Acquisition provenance path confirmed.
[ ] Artifact integrity mechanism confirmed.
[ ] Authentication boundary confirmed.
[ ] Authorization boundary confirmed.
[ ] Revision semantics confirmed or explicitly bounded.
[ ] UIF input adapter boundary defined.
[ ] Parser remains transport-independent.
[ ] No second Vault.
[ ] No second database.
[ ] No UIF → Vault mutation path.
[ ] TRX300 acceptance path defined.
[ ] Error semantics defined.
[ ] Retry semantics defined.
[ ] AP-INGEST-001 unchanged.
[ ] WP-INGEST-001 frozen.
[ ] WP-INGEST-002 frozen.
```

## 30. Final Architectural Principle

```text
REFERENCE VAULT OWNS THE EVIDENCE.

UIF BORROWS THE EVIDENCE FOR PROCESSING.

UIF OWNS THE PROCESSING RESULT.

KNOWLEDGE STUDIO OWNS HUMAN CURATION.

ENGINEERING REPOSITORY OWNS ACCEPTED KNOWLEDGE.
```

Therefore:

```text
             AUTHORITATIVE
                 EVIDENCE
                    │
                    ▼
            REFERENCE VAULT
                    │
             READ-ONLY ACCESS
                    │
                    ▼
            VaultObjectInput
                    │
                    ▼
                  UIF
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
   Derived Artifacts     Candidates
          │                   │
          └─────────┬─────────┘
                    ▼
            KNOWLEDGE STUDIO
                    │
             HUMAN REVIEW
                    │
                    ▼
       ENGINEERING REPOSITORY
```

The boundary exists to preserve ownership, provenance, integrity, and architectural separation—not merely to replace a file path with an API call.
