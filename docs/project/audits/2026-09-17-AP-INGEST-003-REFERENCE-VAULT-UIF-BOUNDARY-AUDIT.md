# AP-INGEST-003 — Reference Vault → UIF Boundary Audit

**Date:** 2026-09-17  
**Repository:** `davidmhuitt86/open_engineering_platform`  
**Audited ref:** `22d54e943a563c65167c6f28d498bc795c29ca98`  
**Mode:** Read-only architecture audit  
**Implementation authorized:** NO

## 1. Executive Result

**AP-INGEST-003: NOT YET IMPLEMENTATION-READY.**

The repository now contains a real EAM/Reference Vault artifact retrieval route, authenticated by the existing server-wide bearer-token boundary, and the route returns the artifact bytes with an `X-Checksum-Sha256` response header. The Vault public JSON deliberately excludes the server-local `vault_path` and exposes Vault identity plus metadata/verification/download/source references.

The existing Vault implementation is therefore substantially closer to the AP-INGEST-003 contract than the first UIF filesystem stand-in suggests.

However, two production-boundary gaps remain before WP-INGEST-003 should be authorized:

1. **There is no single production Vault Object read contract that supplies the complete `VaultObjectInput` semantics.** The current API requires composition of the Vault entry, artifact bytes, and related metadata/provenance resources.
2. **The current public Vault/metadata model does not provide the full immutable descriptive metadata snapshot defined by AP-INGEST-001.** The existing `ArtifactMetadata` is primarily technical/container metadata (filename, extension, MIME, size, hash, PDF properties, timestamps), while AP-INGEST-001 also names fields such as title, organization, publication date, revision, keywords, product family, manufacturer, and document identifiers.

No second Vault, second database, or UIF-to-PostgreSQL path is warranted by this audit.

## 2. Authoritative Vault Identity

The Reference Vault `VaultEntry` has an externally visible UUID-like `id` and retains references to `metadata_id`, `verification_id`, `download_session_id`, and `source_id`. The model also retains the internal `vault_path`, but that path is intentionally not serialized into the public API.

The public JSON representation includes:

```text
id
metadata_id
verification_id
download_session_id
source_id
sha256_hash
mime_type
file_size_bytes
status
published_at
created_at
updated_at
```

This is consistent with the architectural requirement that physical storage paths remain server-side concerns.

## 3. Artifact Retrieval

The existing server exposes:

```text
GET /vault/{id}/artifact
```

The implementation is already present in the audited repository state. Existing comments and tests establish that the route returns raw artifact bytes and supplies the authoritative SHA-256 through `X-Checksum-Sha256`; callers are expected to hash the received body and reject a mismatch.

This route is the correct existing starting point for production UIF retrieval. **Do not create a second artifact-download route.**

## 4. Authentication Boundary

The EAM/acquisition API has a server-wide bearer-token authentication gate. The artifact route is therefore behind the existing authentication boundary rather than requiring a new ingestion-specific credential mechanism.

The public health route is the documented exception; the Vault artifact route is not exempt.

This satisfies the architectural direction of keeping authentication outside parser/UIF logic.

## 5. Artifact Storage Ownership

`ReferenceVaultService` writes artifacts into a content-addressed filesystem location derived from the SHA-256 and stores the corresponding Vault Entry in PostgreSQL. The Vault repository interface has no update method, structurally enforcing post-publication immutability.

The server does not expose the local `vault_path` to API callers. This is an important boundary property: UIF should consume a Vault Object through the API and must not be given a server filesystem path.

## 6. Integrity

The publication path recomputes SHA-256 and compares it against the Verification record before publishing. The retrieval API also supplies the stored checksum to the client through `X-Checksum-Sha256`.

The production UIF adapter should therefore perform the final client-side check:

```text
retrieved bytes SHA-256
        ==
Vault-provided authoritative SHA-256
```

A mismatch must become an integrity failure and must not continue into trusted candidate generation.

## 7. Acquisition Record Relationship

The repository contains a durable Acquisition Record implementation and exposes:

```text
GET /acquisition-records
GET /acquisition-records/{id}
GET /acquisition-records/{id}/provenance
```

The acquisition-record implementation deliberately leaves `reference_vault` unmodified. The owning Acquisition Record is reconstructed through the existing relationship:

```text
acquisition_records.download_session_id
        =
reference_vault.download_session_id
```

This means the production adapter must not invent an `acquisition_record_id` column or create a parallel provenance table merely to make UIF integration convenient.

## 8. Metadata Gap

The current `ArtifactMetadata` model provides:

```text
verification_id
file_name
file_extension
mime_type
file_size_bytes
sha256_hash
file_created_at
file_modified_at
pdf_version
pdf_page_count
status
extracted_at
error_message
created_at
updated_at
```

AP-INGEST-001's conceptual immutable metadata snapshot is broader and may include:

```text
title
author / organization
publication date
revision
keywords
document type
language
product family
manufacturer
document identifiers
```

Those richer descriptive fields are not established as a complete current Reference Vault wire contract by the audited implementation.

**Classification:** architecture boundary gap, not a UIF defect.

WP-INGEST-003 must not silently fabricate these fields or map unrelated technical fields into them.

## 9. Artifact Type Gap

`VaultEntry` does not contain a dedicated `artifact_type` field. The current public contract supplies MIME type and file size, while the underlying metadata model also supplies filename/extension and PDF properties.

UIF's `ArtifactType` is an explicit domain classification.

The implementation decision required before production integration is whether:

1. the UIF adapter derives `ArtifactType` deterministically from the authoritative MIME/extension contract; or
2. the Reference Vault wire contract is extended with an explicit artifact classification.

Do not make this choice implicitly during implementation.

For the TRX300 PDF, deterministic PDF classification is straightforward, but the production architecture must remain extensible beyond PDF.

## 10. Storage Reference

AP-INGEST-001 defines `storageReference` as an implementation-level reference that permits UIF to obtain immutable content.

The current server deliberately does not expose `vault_path` publicly. Therefore:

```text
storageReference != server filesystem path
```

For production UIF, the storage reference should represent the authorized retrieval operation or another opaque reference, not a path that UIF can use to reach the EAM host filesystem.

## 11. Correct Production Boundary

The audited repository supports this architecture:

```text
Reference Vault
      │
      ├── GET /vault/{id}
      │       → Vault identity + technical metadata/references
      │
      ├── GET /vault/{id}/artifact
      │       → immutable artifact bytes + checksum
      │
      └── Acquisition/provenance resources
              → acquisition identity and provenance
      │
      ▼
Reference Vault Adapter
      │
      ▼
VaultObjectInput
      │
      ▼
IngestionOrchestrator
```

The adapter, not the parser, owns transport and response composition.

## 12. What Must NOT Be Built

Do not build:

```text
UIF → PostgreSQL
UIF → EAM database
UIF → server filesystem
second Vault repository
second artifact API
second acquisition/provenance store
parallel integrity database
parser-specific HTTP clients
```

## 13. Required Architecture Decision Before WP-INGEST-003

Resolve the following two items explicitly:

### OD-INGEST-003-A — Vault Object Read Contract

Decide whether the production adapter composes existing read endpoints or whether a single read-oriented Vault Object endpoint should expose the complete logical input contract.

The default architectural preference is to reuse the existing endpoints if composition can be made deterministic and authoritative without creating excessive coupling.

### OD-INGEST-003-B — Artifact Type / Metadata Contract

Define how UIF obtains:

```text
artifactType
immutableMetadataSnapshot
```

from authoritative Reference Vault data.

No implementation should silently invent missing descriptive metadata.

## 14. Implementation Readiness Gate

```text
[✓] Reference Vault exists.
[✓] Durable Vault identity exists.
[✓] Artifact bytes are retrievable.
[✓] Retrieval is authenticated.
[✓] Vault storage path is not exposed publicly.
[✓] SHA-256 integrity information is exposed.
[✓] Vault publication is immutable by repository interface.
[✓] Acquisition Record exists.
[✓] Acquisition provenance exists.
[✓] Existing read APIs can be reused.
[✓] No second Vault is required.
[✓] No second database is required.
[ ] Complete VaultObjectInput contract is exposed authoritatively.
[ ] ArtifactType production semantics are frozen.
[ ] Complete immutable metadata snapshot semantics are frozen.
[ ] Production adapter boundary is implemented and tested.
[ ] TRX300 end-to-end production-boundary test passes.
```

## 15. Decision

**AP-INGEST-003 remains ARCHITECTURE-IN-PROGRESS.**

The audit does **not** authorize WP-INGEST-003 yet.

The existing EAM/Reference Vault service is the correct authoritative source and the existing artifact route is the correct retrieval mechanism to build upon. The remaining work is to freeze the logical read contract and metadata/artifact-type semantics, then implement the smallest adapter required to translate that authoritative contract into `VaultObjectInput`.

## 16. Next Step

Create the two small architecture decisions identified above, reconcile them into AP-INGEST-003, and only then issue the implementation work package:

```text
WP-INGEST-003
Production Reference Vault → UIF Boundary
```

The scope should remain strictly limited to replacing the filesystem stand-in with the authorized production boundary.
