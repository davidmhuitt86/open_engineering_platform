# ADR-0001 — OEP Reference Server Boundary & Remote Artifact Contract

**Status:** Accepted (architecture/contract definition — no implementation)
**Date:** 2026-09-13
**Work package:** WP-SRV-001
**Scope:** Documentation/architecture only. No production code, endpoint, database, or storage layout is created or changed by this ADR.
**Location convention:** This is this repository's first *cross-service* ADR — it spans EAM, Exchange, Knowledge Runtime, and Foundation, none of which individually own the concept it defines, so it is filed at `docs/architecture/decisions/` (repository root) rather than under any single service's own `docs/decisions/` (Acquisition) or `docs/architecture/adr/` (Exchange) convention, both of which remain in place for their own service-local decisions.

---

## 1. Context

Every existing OEP subsystem was designed, and today operates, as if the whole platform runs on one machine:

- **Foundation** (`platform/oep_foundation`) is loaded by Studio as an in-process native library via `dart:ffi` (`DynamicLibrary.open('oep_foundation_bridge.dll')`, `platform/oep_studio/lib/core/foundation/oep_api_bindings.dart:19`). It has **no network boundary of any kind** — there is no `oep_foundation` server, no socket, no RPC surface. "Opening a repository" means opening a local filesystem directory from the same process.
- **EAM** (`services/acquisition`) does have a real HTTP server boundary (`httplib::Server`, binding `0.0.0.0:8080` by default per `config/config.toml`), and Studio already talks to it purely over HTTP (`AcquisitionApiClient`, `AcquisitionSettings.apiBaseUrl`) — a real, working client/server separation. But two of its response bodies (`Download.local_storage_path`, `VaultEntry.vault_path`) directly serialize a server-local filesystem path (confirmed: `src/vault/vault_entry_json.cpp:12`, `entry.vault_path = vault_path.string()` computed from `storage_config_.root_path` in `src/vault/reference_vault_service.cpp:104`), with the unstated expectation that whoever reads that JSON can also read that path from the same disk. Studio's own code already knows this is broken for anything but same-machine use: `platform/oep_studio/lib/acquisition/inspector/acquisition_properties.dart:87-92`'s own doc comment states *"`VaultEntryRecord.vaultPath` is stored relative to the backend's own working directory ... which Studio can't resolve on its own — so file actions are honestly disabled rather than silently opening the wrong path"* — and indeed, `vaultRoot` is never set anywhere in the codebase, so this feature is permanently inert today, by design, rather than silently wrong.
- **Exchange** (`services/exchange`) already has a real download route with a real, byte-correct artifact-transfer contract (`GET /packages/{id}/download`, `X-Checksum-Sha256` header, confirmed and exercised end-to-end in WP-EXC-013/014) — this is the one subsystem that already gets artifact transfer right, and this ADR reuses its shape rather than inventing a new one.
- **Knowledge Runtime / Compiler / Reference Library / Exchange package distribution** already have an extensive, ratified specification — `specifications/AP-EK-019_Knowledge_Package_Distribution_Exchange_Integration.md` (100 sections, its own Definition of Done and Architectural Non-Negotiables) — covering package identity, signing, hashing, staging, activation, licensing, and the Exchange/Runtime boundary in detail. **This ADR does not redefine any of that.** It cites AP-EK-019 as the authoritative source for those boundaries and only clarifies how they sit inside the Local/Remote/Hybrid topology this ADR introduces.
- No subsystem has authentication. EAM: confirmed zero middleware in `src/api/server.cpp` (no `set_pre_routing_handler`, no `Authorization` check anywhere). Exchange: confirmed the same in prior work (WP-EXC-010 audit). This is an existing, known, separately-tracked gap (EAM API authentication remains open per `OEP_PROJECT_STATUS.md` Section 16) — **this ADR does not add authentication**; it defines where an authentication boundary belongs so a future work package can add one without redesigning everything above it.

The open architectural question this ADR resolves: **what does "OEP talking to a reference server instead of everything running on one machine" actually mean**, precisely enough that a future implementation work package has an unambiguous contract to build against — without building any of it now.

## 2. Server Identity

**The long-term server is the OEP Reference Server. EAM is one subsystem of it, not the whole of it.**

```
OEP REFERENCE SERVER
    API / Authentication boundary (future)
    ├── EAM             (acquisition, provenance, Reference Vault publication)
    ├── Knowledge services  (Reference Library, Compiler output, package catalog/distribution surface)
    └── Exchange        (distribution, commercial boundary, package acquisition/install path)
            ↓
    PostgreSQL + Artifact/Object Storage
```

This is a **logical model only**. No component above is implemented, merged, or re-hosted by this ADR. Today, EAM and Exchange remain two entirely separate, independently deployed services (`services/acquisition`, `services/exchange`) with their own databases and their own processes — nothing here requires or implies merging them into one physical service. "OEP Reference Server" names the *logical* role a deployment topology can play; it is not a mandate to build a monolith. A future implementation could equally realize this logical model as several independently-deployed services behind one API gateway, or as EAM/Exchange remaining exactly as separate as they are today, each independently reachable — this ADR takes no position on physical deployment topology, only on the client-facing contract shape.

## 3. Boundary Model

**A client of the OEP Reference Server (Studio, or any future client) communicates only through stable API/domain contracts. It never needs:**

- a server filesystem path (`C:\...`, `/srv/...`, or any other OS path)
- a direct PostgreSQL connection
- knowledge of which physical service (EAM vs. Exchange vs. a future Knowledge service) happens to own a given contract, beyond the contract's own documented boundary
- any internal service implementation detail (table names, storage sharding scheme, connection pooling, etc.)

This is not a new principle — it is the literal, already-working shape of Studio's own `AcquisitionApiClient`/`ExchangeApiClient` (both plain HTTP clients hitting documented REST routes, confirmed in prior work this session) for everything **except** the two filesystem-path fields identified in Section 1. This ADR's job is to close that one remaining gap and make the "clients only ever see stable contracts" rule *complete*, not to invent client/server separation from nothing.

## 4. Ownership Model (subsystem boundaries)

Each of the following is stated as a firm boundary. None of them are changed by this ADR — they are recorded here so the Reference Server's own contract layer has an unambiguous map of who is authoritative for what.

### 4.1 EAM
**Owns**: acquisition (Official Source → Job → Execution → Connector → Download), integrity verification, metadata extraction, Reference Vault **publication**, the Acquisition Record, and provenance reconstruction.
**Does NOT become**: the canonical knowledge model, the knowledge graph, an OCR engine, a semantic classification engine, the Knowledge Compiler, or the Knowledge Runtime. EAM's job ends at "a verified artifact is durably, immutably published to the Reference Vault with full provenance" — it does not interpret that artifact's engineering content.

### 4.2 Reference Library
**Owns**: canonical engineering knowledge, canonical schema, canonical relationships, canonical source lineage (per AP-EK-019 §4). Does not depend on Exchange, EAM, or the Reference Server's own transport for its own authority — it is a knowledge authority, not a network service.
**Does NOT become**: absorbed into EAM. EAM feeds Reference Vault artifacts as raw acquired material; how (or whether) a given Vault artifact becomes canonical Reference Library content is a separate, currently-unimplemented handoff (Section 8, Gap G7) — EAM publishing an artifact is not the same act as that artifact becoming canonical knowledge.

### 4.3 Knowledge Compiler
**Owns**: the transformation of canonical Reference Library knowledge into a distributable, validated `.oerp` runtime package — schema validation, semantic validation, normalization, content hashing, deterministic package generation (AP-EK-019 §5). This ADR does not redefine the compiler; it only notes that the compiler's own inputs/outputs are unaffected by whether the Reference Server is local or remote.

### 4.4 Knowledge Runtime
**Owns**: package validation, integrity/signature verification, installation compatibility, activation, registry construction, and runtime consumption (AP-EK-019 §3/§17-25). **The Reference Server must never bypass Knowledge Runtime's own trust/verification pipeline** — whether a `.oerp` package arrives via Exchange, a local file import, an enterprise mirror, or (in the future) directly from a Reference Server knowledge-distribution surface, it passes through the exact same Runtime validation (AP-EK-019 §16: "Runtime Does Not Trust Transport"). This ADR does not add a second, server-side trust mechanism that could compete with or shortcut Knowledge Runtime's own.

### 4.5 Engineering Exchange
**Owns**: publication, package catalog, distribution, licensing, entitlements, payments, reviews, publisher identity, discovery, and delivery (AP-EK-019 §3). Remains the distribution/commercial boundary — it does **not** become the authoritative engineering-knowledge repository (AP-EK-019 §2, "Engineering Exchange is a distribution and commercial boundary. It does not become the authority for engineering truth.").

### 4.6 Foundation
**Owns**: OEP package installation and repository-side installation semantics (`oep_package_install`, trust verification, Repository Registry, Engineering Object/Relationship creation — WP-EXC-013's own authoritative chain). **Foundation today has no server-side existence at all** — it is an in-process native library (Section 1). This ADR does **not** propose a server-side Foundation, a remote installer, or any replacement for `oep_package_install`. If a future work package ever needs Foundation-equivalent installation semantics to run against a remote repository rather than a local one, that is an explicit, separate architectural decision this ADR does not make — it is recorded as an open question (Section 8, Gap G8), not answered here.

## 5. Remote Artifact Identity (storage-independent)

**A Vault (or, in the future, Knowledge package) artifact is identified publicly by its logical/content identity — never by a physical storage locator.**

The minimum identity a client-facing contract may expose:

| Field | Meaning | Already exists today? |
|---|---|---|
| `id` | The Vault entry's (or package's) externally-visible UUID | Yes — `VaultEntry.id` |
| `sha256` | The artifact's content hash (hex) | Yes — `VaultEntry.sha256_hash` |
| `mimeType` | The artifact's declared content type | Yes — `VaultEntry.mime_type` |
| `sizeBytes` | The artifact's byte length | Yes — `VaultEntry.file_size_bytes` |
| `status` | Lifecycle/publication status | Yes — `VaultEntry.status` (currently always `Published`, per its own doc comment) |

**A server-local path (`vault_path`, `local_storage_path`, or any equivalent) is never part of the public contract.** It may continue to exist as a private, server-internal repository field (exactly as it does today) — the change this ADR calls for is only that it must not be the mechanism a remote client uses to obtain bytes. The physical storage layout (content-addressed sharded directory, a future object-storage bucket, anything else) remains entirely swappable behind this identity, exactly as AP-EK-019 §48 already establishes for Knowledge packages ("An enterprise installation may use an internal package mirror ... Package identity remains determined by canonical package content").

## 6. Canonical Remote Artifact Retrieval Contract

This is the concrete gap this ADR is required to close (Section 1). The contract below is the **minimum** sufficient for a production-quality remote client, deliberately reusing the shape Exchange's own download route already proves works end-to-end (WP-EXC-013/014) rather than inventing a new pattern.

```
GET /vault/{id}                 -> metadata only (existing route, unchanged)
                                     { id, sha256, mimeType, sizeBytes, status, ... }
                                     -- no vault_path/local_storage_path in the public body

GET /vault/{id}/artifact         -> the artifact BYTES (new -- not built by this ADR)
                                     Response headers:
                                       Content-Type: <mimeType>
                                       Content-Length: <sizeBytes>
                                       X-Checksum-Sha256: <sha256>
                                     Response body: raw bytes
```

Answering the task's own required questions directly:

- **How is an artifact identified?** By its Vault entry `id` (Section 5) — never a filesystem path.
- **How is metadata discovered?** The existing `GET /vault/{id}` route, corrected to omit the internal path field (Section 5).
- **How are bytes requested?** `GET /vault/{id}/artifact` — a sibling route to the existing metadata route, mirroring Exchange's own `/packages/{id}/download` shape exactly (same "metadata route + sibling bytes route" pattern, same header contract).
- **Byte-range/resume behavior?** Not required for the minimum contract. AP-EK-019 §46 already anticipates "resumable transfers" as an optional future enhancement for Knowledge package distribution specifically; the same optional `Range`/`Accept-Ranges` support could be added later to this route without changing its identity or header contract. Not adding it now is deliberate — "do not invent unnecessary complexity."
- **Content length?** `Content-Length` header, matching `VaultEntry.file_size_bytes`.
- **MIME?** `Content-Type` header, matching `VaultEntry.mime_type`.
- **SHA-256?** `X-Checksum-Sha256` header — the exact header name and semantics Exchange's own download route already uses (`apps/exchange-api/src/routes/download.ts`'s `sendArtifact`), so a client library that already knows how to verify an Exchange download (Studio's `ExchangeApiClient.downloadArtifact`/`ExchangeInstallBridge`, WP-EXC-013) needs no new verification logic to also verify a Vault artifact fetch.
- **How does the client verify integrity?** Compute SHA-256 over the received bytes; compare, case-insensitively, against `X-Checksum-Sha256`. Reject on mismatch before doing anything else with the bytes — exactly `ExchangeInstallBridge.install`'s own existing logic (WP-EXC-013), reused, not reinvented.
- **How are errors represented?** The existing EAM error envelope (`{"error": {"code", "message"}}`, confirmed in `server.cpp`'s `respond_error`) — `404` for an unknown `id`, and (once EAM authentication exists — a separate gap, Section 4.6/8) `401`/`403` for an unauthenticated/unauthorized request. No new error taxonomy is introduced.
- **How does the server prevent disclosure of storage paths?** By never including one in either route's response body — this is a response-shaping decision, not a new access-control mechanism.
- **Bytes directly, or a transfer URL?** **Bytes directly**, for the minimum contract — matching Exchange's own proven pattern and avoiding a second, more complex indirection layer (a signed-URL/pre-authorized-transfer scheme) that nothing in the current architecture needs yet. If a future deployment moves artifact storage to genuine object storage (S3-compatible or otherwise) behind this same logical contract, the route can be reimplemented as a redirect to a time-limited, signed transfer URL **without changing the client-facing identity or header contract above** — that is exactly why the contract is defined at the "GET this id's bytes" level rather than at the storage-implementation level. This ADR does not decide that migration now (see Non-Goals).
- **Trust/integrity properties of a transfer URL, if ever used?** Would need to be short-lived, single-purpose, and non-guessable (per general signed-URL practice) — but since no transfer-URL mechanism exists today and none is being built by this ADR, this is recorded as a future consideration only, not a requirement being adopted now.

## 7. Local / Remote / Hybrid Model

**What remains local, unconditionally:**
- Foundation's own in-process Repository operations (object/relationship CRUD, Engineering Object queries) — Foundation has no remote existence today (Section 4.6), and this ADR does not create one.
- Knowledge Runtime's own package activation/consumption — AP-EK-019 §79/§95 already mandate that engineering analysis, once a package is activated, must not require any network connectivity.

**What can be remote (already, or after the gaps in Section 8 are closed):**
- EAM's own REST surface (already remote-capable — it is already a real HTTP service, reachable from a different machine than Studio's, once its bind address/port are network-reachable and — separately — once authentication exists).
- Reference Vault artifact retrieval, once the contract in Section 6 is implemented.
- Exchange's package catalog/discovery/download/install-bridge path — already proven remote-capable end to end (WP-EXC-013/014).
- A future Knowledge-package distribution surface, per AP-EK-019's own already-defined `ExchangeClient`/`PackageManager`/`KnowledgePackageStore` boundary (AP-EK-019 §68-70) — not built by this ADR (Section 8, Gap G2).

**Where synchronization occurs:** at each subsystem's own existing boundary — EAM's REST API is the sync point for acquisition/provenance/Vault metadata; Exchange's REST API is the sync point for package catalog/distribution; Foundation's local Repository is the sync point for installed Engineering Objects. This ADR does not introduce a new, separate synchronization layer or a new "OEP Reference Server sync protocol" — each subsystem keeps its own already-established client/server contract, and the Reference Server is the logical grouping of those contracts, not a new mechanism layered on top of them.

**What happens when remote connectivity disappears:**
- Foundation: unaffected — it was never remote.
- Knowledge Runtime: unaffected for already-activated packages (AP-EK-019 §71/§77: `NETWORK_UNAVAILABLE` is distinct from `PACKAGE_INVALID`; the runtime continues using installed, valid packages).
- EAM: any in-flight remote acquisition/vault-publish operation fails cleanly (the existing `DownloadService`/`ReferenceVaultService` error paths already report failure rather than silently succeeding); no partial/corrupted Vault entry is left behind, since Vault publication is already all-or-nothing (`ReferenceVaultService::publish`'s existing atomic-copy-then-create behavior).
- Exchange: install attempts fail cleanly with the existing, already-tested error categories (WP-EXC-013's `CHECKSUM_MISMATCH`/`TRUST_FAILURE`/`INSTALL_FAILURE`/`ALREADY_INSTALLED`).

**Offline operation is, and remains, a fully valid architecture** — nothing in this ADR requires a Reference Server to exist at all. A single-machine, fully local OEP installation (Foundation + a locally-run EAM + no Exchange connectivity) is exactly as valid a deployment as a fully remote one; the Reference Server model is additive, not a replacement for local-only operation.

## 8. Integrity Contract

**SHA-256 remains the authoritative compatibility/integrity mechanism everywhere the current implementation already depends on it.** This ADR does not weaken, replace, or duplicate it:

- **Server-provided digest**: `VaultEntry.sha256_hash` (EAM, already exists), `X-Checksum-Sha256` (Exchange, already exists; Section 6 extends the identical header to the new Vault artifact route).
- **Client-computed digest**: computed by the client over the received bytes exactly as `ExchangeInstallBridge.install` (WP-EXC-013) already does for Exchange downloads — this ADR specifies the same pattern apply to a future Vault artifact client.
- **Mismatch handling**: reject before any further processing (never install, never activate, never present as valid) — exactly WP-EXC-013's own established `CHECKSUM_MISMATCH` behavior, reused as the model for any future Vault artifact client.

Where AP-EK-019 additionally calls for BLAKE3 with SHA-256 as "required fallback" (§13) for Knowledge packages specifically, this ADR does not change that; it is scoped to EAM/Vault artifacts, which today have only SHA-256, and this ADR does not add BLAKE3 to EAM's own model.

## 9. Storage Abstraction Requirement

Restated for emphasis, since it is the ADR's core structural requirement: the physical storage implementation behind Reference Vault (or any future artifact store) must remain swappable — content-addressed local filesystem today, potentially object storage tomorrow — **without the public contract in Sections 5-6 changing**. No client, present or future, is entitled to assume a particular physical storage technology; the contract is the interface, not the implementation.

## 10. Anti-Coupling Rules — the Server Must Not Become a "God Service"

The Reference Server (as a logical concept) must never absorb:

- Studio UI logic
- Engine graph logic / electrical solver logic
- Knowledge Runtime's own internal validation/trust/activation machinery
- Foundation's own repository internals
- EAM's own internal database schema/implementation details
- Exchange's own commercial rules (licensing, entitlements, payments, reviews)

The server exposes **stable contracts over subsystem capabilities** — it is a boundary, not a reimplementation of what sits behind it. Every ownership statement in Section 4 exists specifically to make this enforceable: if a future change would require the Reference Server itself to know, e.g., how Exchange computes entitlements, that change belongs inside Exchange's own service, exposed through Exchange's own contract — not absorbed into a shared "server" layer.

## 11. Explicit Non-Goals

This ADR does not, and this work package (WP-SRV-001) did not:

- Build the OEP Reference Server, or any part of it.
- Add any endpoint to any running service.
- Implement authentication, OAuth, JWT, or API keys.
- Add object storage, S3, MinIO, Redis, Kafka, Elasticsearch, Kubernetes, or any Docker-architecture dependency.
- Create a new database, or migrate the existing Reference Vault filesystem layout.
- Implement OCR, AI ingestion, or semantic classification.
- Implement remote Knowledge Runtime, remote package distribution, or any part of AP-EK-019's own still-unimplemented sections.
- Redesign Exchange, Foundation, or EAM's existing database/service implementation.
- Modify `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` (the user's own, separate, in-progress document — read for context awareness only, not incorporated or altered).

## 12. Consequences

- A future implementation work package can now build the `GET /vault/{id}/artifact` route (Section 6) against an unambiguous contract, reusing Exchange's own already-proven header/verification pattern, without re-litigating "how should a remote client get bytes."
- `VaultEntry`'s/`Download`'s existing `vault_path`/`local_storage_path` fields can remain in the internal domain model and database exactly as they are today — no schema migration is implied by this ADR — but any future response-shaping work should stop including them in client-facing JSON, or clearly mark them internal-only.
- Studio's own `VaultArtifactProperties` (Section 1) has a documented, correct path forward: once `GET /vault/{id}/artifact` exists, its "file actions honestly disabled" fallback can be replaced with a real byte-fetch-and-open flow, without Studio ever needing to resolve a `vaultRoot` again.
- Nothing about Foundation, Knowledge Runtime, or Exchange's existing architecture changes as a result of this ADR — their own already-ratified boundaries (WP-EXC-013's authoritative chain, AP-EK-019's non-negotiables) are reaffirmed, not superseded.

## 13. Future Reconsideration Criteria

This ADR should be revisited if:
- A concrete requirement emerges for genuinely large artifacts (multi-gigabyte) where a direct-bytes response becomes impractical and the signed-transfer-URL alternative (Section 6) needs to move from "documented option" to "adopted mechanism."
- Object storage is actually adopted for Vault/package artifacts, at which point Section 9's abstraction is exercised for the first time and should be validated against the real implementation.
- Foundation ever needs a server-side existence (Section 4.6, Gap G8) — that is a separate, larger architectural decision this ADR deliberately does not make.
- EAM API authentication (a prerequisite for safely exposing any of this remotely in practice) is implemented — at which point this ADR's Section 4/6 error-handling text should be revisited to specify the exact `401`/`403` contract.
