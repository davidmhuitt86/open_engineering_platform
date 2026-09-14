# Server Repository Service — Architectural Contract

**Status: CONTRACT. No implementation exists. No implementation is authorized by this document.**

This document defines the architectural contract and boundary for a future *Server Repository Service* — the server-resident counterpart to the existing, local-only Foundation Repository. It is a specification of what such a service would own, how it would relate to everything already built, and what must remain undecided until a dedicated ADR resolves it. **It does not create, modify, or schedule that service.**

Every claim below is labeled:

- **IMPLEMENTED** — exists in this repository today, verified by reading the actual code/spec.
- **CONTRACT** — established by this document as a requirement a future Server Repository Service must satisfy.
- **FUTURE** — anticipated, named, but deliberately not designed here.
- **UNDECIDED** — an open question this document does not answer, requiring its own ADR.

---

## 1. Purpose

Formally separate two concepts that this repository's own history shows are easy to conflate: the **local Foundation Repository** (in-process, filesystem-backed, offline-first, real and working today) and a **Server Repository** (a server-resident authority for engineering state, named in [`docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md`](../../server/OEP_REFERENCE_SERVER_REQUIREMENTS.md) as "Engineering Object Repository" and in [ADR-0001](../decisions/ADR-0001-OEP-REFERENCE-SERVER-BOUNDARY-AND-ARTIFACT-CONTRACT.md) §13 as Gap G8 — *not yet designed, not yet built*).

Both are called "the Repository" in different parts of this codebase and its documentation. That collision is exactly why this contract exists: to give the future Server Repository Service a defined boundary *before* anyone builds it, so it is designed as its own service rather than as a side effect of making something else (Foundation, EAM's Vault, or Exchange) do double duty.

## 2. Architectural Status

**IMPLEMENTED, today:**
- A local Foundation Repository (`platform/oep_foundation`) — in-process C++ library, filesystem-backed, no network surface of any kind.
- EAM's own PostgreSQL persistence (`services/acquisition`) — real, but owns acquisition/verification/metadata/Vault/provenance data, not Engineering Objects (see §17).
- Engineering Exchange's own PostgreSQL persistence (`services/exchange`) — real, but owns package distribution/publication metadata, not Engineering Objects (see §18).

**NOT IMPLEMENTED, anywhere, today:**
- A Server Repository Service of any kind.
- Any PostgreSQL schema, table, or migration for Engineering Objects or Relationships.
- Any HTTP route, in this repository, that serves or mutates an Engineering Object or Relationship.
- Any synchronization mechanism between local Foundation and any server.
- A server-side Foundation (explicitly ruled *undecided*, not ruled out, by ADR-0001 §4.6/§13).

This document does not change any of the above. It only names the shape the missing piece must eventually take.

## 3. Definitions

| Term | Meaning in this document | Status |
|---|---|---|
| **Foundation Repository** | The existing local, filesystem-backed, in-process repository (`platform/oep_foundation/platform/repository`): `ObjectStore`, `RelationshipStore`, `AuditStore`, `GraphEngine`, `RepositoryValidator`, orchestrated by `FoundationRuntime`, exposed only through the Public C API (`OEP-SPEC-021`). | IMPLEMENTED |
| **Server Repository (Service)** | The subject of this document: a future, server-resident authority for engineering state, reachable over a network, as a distinct logical service under the OEP Reference Server (alongside EAM, Knowledge services, and Exchange, per ADR-0001 §2). | CONTRACT / FUTURE |
| **Remote Foundation** | A *rejected framing*: converting `FoundationRuntime` itself into a network service. This document does not define this and explicitly treats it as a different, unwanted shape (§9). | Explicitly not this contract |
| **Engineering Object** | The canonical unit of engineering knowledge, per [`OEP-SPEC-004`](../../../platform/oep_foundation/specifications/platform/OEP-SPEC-004-ENGINEERING_OBJECT_MODEL.md): a permanent UUIDv4 `object_id`, an `ObjectType` (Document/Diagram/Component/Procedure/Project/Image), name/description/author/tags/timestamps, a free-text `version` string, and an opaque `content` payload the Repository does not interpret. Defined in code at `platform/oep_foundation/platform/repository/include/oep/repository/engineering_object.hpp`. | IMPLEMENTED (locally) |
| **Relationship** | A directional link between two Engineering Objects, per [`OEP-SPEC-005`](../../../platform/oep_foundation/specifications/platform/OEP-SPEC-005-OBJECT_RELATIONSHIP_MODEL.md): a permanent UUIDv4 `relationship_id`, `source_object_id`, `target_object_id`, a `RelationshipType` (References/Contains/DependsOn/ConnectedTo/Documents/Implements), author, timestamp. | IMPLEMENTED (locally) |
| **`.oep` package** | Foundation's own package/archive transport format (PKG-001/PKG-002), installed today via Exchange's install-bridge (WP-EXC-013). A transport container, never itself "the repository." | IMPLEMENTED (as a format; its install path exists per WP-EXC-013) |
| **`.oerp` package** | The Knowledge Runtime's own, unrelated compiled package format (Reference Library → compiler → `.oerp` → Knowledge Runtime). A different family from `.oep`, with a different runtime. See §16. | IMPLEMENTED (its own pipeline; unrelated to this contract) |
| **Revision** | A specific, addressable historical state of an Engineering Object or Relationship at the server boundary. Does not exist today in any form (§11). | CONTRACT (defined here as a concept, not built) |
| **Reference Server** | The logical grouping of EAM + Knowledge services + Engineering Exchange (+ a future Server Repository Service) behind a shared API/authentication boundary, per ADR-0001 §2-3 and ADR-0002. Not a single physical process. | IMPLEMENTED as a boundary concept (ADR-0001); partially realized (EAM only, so far) |

## 4. Server Repository Identity

**CONTRACT.** A Server Repository Service, once it exists, must have its own identity, distinct from:

- The local Foundation Repository's identity (a local directory + `repository.json`, per `OEP-SPEC-002`) — a server repository is not "a Foundation repository that happens to be reachable over HTTP." It is a separate resource with its own identifier.
- An Engineering Object's identity (§6) — a repository is not an object, and does not share the object identity space.
- A PostgreSQL database name — the identity is a logical/architectural one; its eventual physical representation is **UNDECIDED** (§20).

This document does not assign a concrete identifier shape (UUID, slug, URL path segment, etc.) to "a server repository" — that is implementation detail properly left to the ADR that actually designs the service (§23).

## 5. Ownership

**CONTRACT.** The Server Repository Service is the potential authority for **server-resident** engineering state. At minimum, it must distinguish the following concepts (per the WP's own instruction: distinguish, do not invent unnecessary fields):

| Concept | Owned by Server Repository? | Notes |
|---|---|---|
| Server repository identity | Yes | §4 |
| Engineering Object identity | Consumed, not invented | Must reuse Foundation's existing UUIDv4 `object_id` shape (§6) — a server repository does not mint a second, incompatible identity scheme. |
| Relationship identity | Consumed, not invented | Must reuse Foundation's existing UUIDv4 `relationship_id` shape (§7). |
| Object revisions | Yes | §11 — does not exist today anywhere. |
| Relationship revisions | Yes | §11. |
| Repository membership | Yes | Which objects/relationships belong to which server repository — a server-only concept; Foundation's local repository has no equivalent "membership" registry beyond "is this file present in this directory." |
| Repository metadata | Yes | Name, description, and similar descriptive attributes of the server repository itself — not of any object inside it. |
| Audit history | Yes, at the server boundary | Distinct from Foundation's own local `AuditStore` (which already exists and is unaffected by this contract) and distinct from EAM's provenance (§15/§17) — the server repository's audit history covers mutations *to server-resident engineering state specifically*. |
| Ownership metadata (who owns this repository / object) | Yes, conceptually | Concrete access-control mechanics are explicitly **UNDECIDED** (§14/§23) — this document only establishes that the concept must exist, not its rules. |
| Access-control metadata | Yes, conceptually | Same caveat as above. |

**Not owned by the Server Repository Service:**
- Source acquisition evidence, verification, metadata extraction, Vault artifacts (EAM's domain — §17).
- Package distribution, publication, discovery, commercial operations (Exchange's domain — §18).
- Knowledge package validation/activation/execution (Knowledge Runtime's domain — §19).
- The authentication mechanism itself (ADR-0002's bearer-token boundary remains the outer gate — §14).

## 6. Engineering Object Boundary

**CONTRACT**, grounded in **IMPLEMENTED** fact (`OEP-SPEC-004`, `engineering_object.hpp`):

- **Canonical object identity**: a permanent UUIDv4 `object_id`, assigned once, never reused, never changed. A Server Repository Service **must** consume this exact identity scheme — it must not invent a second, server-local object identity (e.g. a database auto-increment integer as the *primary* identity) that would require a translation layer between "the object as Foundation knows it" and "the object as the server knows it." A server-side surrogate key (for internal database indexing) is an implementation detail that may exist *underneath* the canonical `object_id`, never *instead of* it.
- **Canonical object type**: the existing `ObjectType` enumeration (Document, Diagram, Component, Procedure, Project, Image). A Server Repository Service does not define its own object-type taxonomy.
- **Canonical relationship to repository membership**: an Engineering Object belongs to exactly one server repository at a time, in the same way it belongs to exactly one local Foundation repository today (`OEP-SPEC-011` §5: only one repository open per Runtime instance, at present — there is no existing multi-repository-membership concept to extend). Cross-repository object membership is **UNDECIDED** and not assumed by this contract.
- **Serialization boundary**: the wire representation of an Engineering Object crossing the local/server boundary is **UNDECIDED** (JSON is the obvious candidate, consistent with every other OEP Reference Server contract to date — ADR-0001 §5-6, EAM's own JSON API — but this document does not mandate it, since no such boundary is being built here).
- **Revision boundary**: see §11. An Engineering Object's *content* identity (its `object_id`) and its *revision* identity are distinct concepts — this contract requires that distinction to exist, without designing the revision mechanism itself.

**This document does not modify** `engineering_object.hpp`, `OEP-SPEC-004`, or any Foundation code. The Engineering Object Model is treated as a fixed input, not a variable this WP is allowed to touch.

## 7. Relationship Boundary

**CONTRACT**, grounded in **IMPLEMENTED** fact (`OEP-SPEC-005`):

- **Relationship identity**: a permanent UUIDv4 `relationship_id`. Consumed, not reinvented — same rule as §6.
- **Source object / target object**: `source_object_id` / `target_object_id`, both referencing Engineering Objects by their canonical `object_id`. A Server Repository Service must preserve directionality exactly as Foundation already defines it (source → target, not a symmetric edge).
- **Relationship type**: the existing `RelationshipType` enumeration (References, Contains, DependsOn, ConnectedTo, Documents, Implements). Not redesigned or extended by this contract.
- **Repository membership**: a Relationship belongs to the same server repository as its endpoints, by construction — this document does not define what happens if a future capability ever allows cross-repository relationships (out of scope, **UNDECIDED**).
- **Revision semantics**: see §11 — a Relationship's mutation history is subject to the same revision contract as an Engineering Object's.
- **Integrity requirement**: a Server Repository Service must not persist a Relationship whose `source_object_id`/`target_object_id` do not both resolve to real, currently-known Engineering Objects within the same server repository. (Note for traceability: Foundation's own local `RelationshipStore::create` today does *not* enforce this — referential integrity against object existence is the API layer's job at creation time, not the store's, per the existing code's own documented convention. This contract does not require the Server Repository Service to inherit that specific permissiveness; it states the integrity requirement as a "must," leaving it to the future implementing ADR to decide whether that is enforced at the API layer or the persistence layer.)

**This document does not modify** the Relationship Model, `OEP-SPEC-005`, or any Foundation code.

## 8. Local Foundation Boundary

**CONTRACT** (an invariant, not a new capability):

> **A local Foundation Repository must remain usable without a Server Repository Service.**

Concretely, none of the following may ever be made to depend on a Server Repository Service existing, being reachable, or being healthy:

- Offline local Engineering Object creation.
- Offline local Engineering Object editing.
- Offline local validation (`RepositoryValidator`).
- Offline local persistence (`ObjectStore`/`RelationshipStore`/`AuditStore`, all local-disk, all real today).
- Offline local `.oep` package installation (the existing Foundation-package install path, WP-EXC-013).

This is consistent with, and does not change, the existing architecture: Foundation already has zero network dependency today (confirmed — no HTTP client, no socket, no RPC surface anywhere in `oep_foundation`), and `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` §3 already states this as a requirement independently ("The server architecture must not eliminate offline/local operation"). This contract does not introduce that requirement; it re-affirms it as binding on any future Server Repository Service design.

## 9. Server Repository Boundary

**CONTRACT.** The Server Repository Service is explicitly **not**:

- **Remote Foundation.** `FoundationRuntime` is not to be made network-reachable by this contract or any implementation of it. `OEP-SPEC-011` §5's single-open-repository-per-Runtime-instance constraint, `OEP-SPEC-021` §2's explicit exclusion of "Network APIs. Remote Foundation," and ADR-0001 §4.6's explicit statement that server-side Foundation is a *separate, undecided* question are all binding here. If a Server Repository Service is ever built, it is a new, distinct service — not `FoundationRuntime` wrapped in an HTTP listener.
- **Engineering Exchange.** Exchange owns distribution/publication/discovery/commercial package operations (§18). It has its own, already-real `RepositoryClient` abstraction (`services/exchange/packages/interfaces/src/repository-client.ts`) that names a *future* install target — but that interface's `install()` call, and Exchange's own Postgres schema, are Exchange concepts (package installation attempts, publisher/package/version metadata), not Engineering Object/Relationship concepts. A Server Repository Service, if built, could plausibly become the thing Exchange's `HttpRepositoryClient` eventually talks to for `.oep` package installation — but that is a **FUTURE** integration possibility this document records, not a design it commits to.
- **EAM's Reference Vault.** EAM's Vault (`services/acquisition/src/vault`) owns immutable, content-addressed artifact storage tied to acquisition provenance (§17). It has no concept of Engineering Objects or Relationships and is not repurposed by this contract.
- **A `.oerp` package or its runtime.** See §16.

## 10. Local/Server Interaction

**CONTRACT** (conceptual only — no operation below is implemented or scheduled by this document):

The following concepts are distinct and must not be treated as synonyms in any future design:

| Term | Meaning |
|---|---|
| **Local write** | A mutation to the local Foundation Repository's own on-disk state. Already real, already happens without any server involvement. |
| **Server write** | A mutation accepted and durably recorded by a Server Repository Service. Does not exist today. |
| **Publication** | An explicit, deliberate act of sending locally-authored engineering state *to* a Server Repository Service, becoming a server write. Conceptually similar in shape to `git push`, not automatic. |
| **Synchronization** | A *bidirectional*, potentially automatic or scheduled, reconciliation of local and server state. **Explicitly NOT defined by this contract** — see §17 of the enumerated questions below. Listed as a future capability in `OEP-SPEC-002` §10, `OEP-SPEC-005`/`004` §2, `OEP-SPEC-011` §2 (all: "future extension point," none implemented), and in `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` (listed repeatedly as an eventual capability, never specified). |
| **Import** | Bringing external data into a repository (already a real, existing Foundation CLI concept — `oep import`, per `platform/runtime/CLI_USAGE.md`, which explicitly documents that it does *not* support "merge operations, or conflict resolution"). Distinct from publication: import can be local-to-local, with no server involved at all. |
| **Export** | The inverse of import — extracting repository content into a portable form. Also a real, existing local Foundation capability, unrelated to any server. |

Conceptually possible **FUTURE** operations at the local/server boundary (named, not designed): `publish`, `fetch`, `retrieve`, `commit`, `inspect`, `validate`. None of these are implemented by this document, and none are assigned a wire protocol, HTTP verb, or route here (§21).

### Is synchronization defined?

**No. Explicitly not.** Synchronization (bidirectional, automatic reconciliation between local Foundation and a Server Repository Service) is named as an eventual platform capability in multiple places (CLAUDE.md lists "Synchronization" as a C++ runtime responsibility; `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` lists it repeatedly as a future server service) but is specified nowhere, in any document, at any level of detail. This contract deliberately does not invent it. A future ADR must define synchronization before it is built (§23).

## 11. Revision Semantics

**CONTRACT.** None of this exists today. Foundation's `EngineeringObject.version` is a free-text, author-set string (default `"1.0.0"`) with no compare-and-swap semantics, no monotonic guarantee, and no repository-managed increment — it is not a revision mechanism, it is a label.

This contract establishes the **minimum** architectural requirements a Server Repository Service must eventually satisfy:

- **Server state is mutable.** A Server Repository Service is not a write-once archive.
- **Historical state must be retained.** A successful mutation must not destructively overwrite the prior state without a recoverable trace of what it replaced.
- **Every successful mutation creates a revision.** "Revision" here means: a distinct, addressable, retrievable historical state of a specific Engineering Object or Relationship, ordered relative to that object/relationship's own prior revisions.
- **An old revision must be retrievable**, not merely logged. (This document does not specify retention duration/pruning policy — **UNDECIDED**, §23.)
- **A client must be able to state the revision it started from** ("I edited revision N") as part of any mutation request.
- **The server must detect staleness explicitly.** If the server's current revision for that object/relationship is already past what the client started from (i.e. the server is at N+1 or later while the client says N), the server must reject the mutation as a conflict rather than silently applying it as if it were the latest write. **Silent last-write-wins is explicitly disallowed by this contract.**

**Not specified by this contract**: the storage representation of a revision (append-only log? row versioning? event sourcing?), the exact conflict response shape, or any conflict-resolution algorithm (automatic merge, three-way merge, etc.). All of the above are implementation decisions for the ADR that actually designs this service (§23).

## 12. Transaction Semantics

**CONTRACT.**

- An operation that affects multiple Engineering Objects and/or Relationships within a single server repository **must** have clearly defined atomicity semantics — a future implementation must state, explicitly, whether such an operation is all-or-nothing and how a partial failure is surfaced.
- A partial server commit **must never be silently presented to the caller as a complete success.** (This directly parallels a real, already-fixed defect class in this repository: WP-SRV-005 found and fixed a case where `ReferenceVaultService` could leave orphaned state on partial failure — that lesson generalizes here as a hard requirement, not a suggestion.)
- **Local Foundation transactions remain local.** `FoundationRuntime`'s existing transaction support (begin/commit/rollback, real today) is a single-process, single-repository mechanism. This contract explicitly forbids treating a local Foundation transaction and a Server Repository transaction as one distributed transaction. **No distributed transaction is defined or implied by this document.** If a future operation needs to affect both local and server state, that operation's atomicity story (or explicit lack of one) is a separate, future design question — not solved here.

## 13. Concurrency Requirements

**CONTRACT.**

- The initial architecture for a Server Repository Service should **prefer optimistic concurrency**, consistent with §11's revision-based conflict detection, unless a future ADR finds concrete evidence requiring something stronger (e.g. pessimistic locking for a specific high-contention operation). No such evidence exists in this repository today.
- Defined concepts (per §11, restated here for clarity as concurrency-specific terms):
  - **Expected revision** — the revision a client believed was current when it began a mutation.
  - **Accepted revision** — the revision the server actually applied the mutation against and produced.
  - **Stale revision** — a client-supplied expected revision that is no longer current.
  - **Conflict** — the state produced when expected revision ≠ current server revision at the moment of mutation; must be surfaced to the caller explicitly, not resolved automatically.
- **Not defined here**: how a conflict is resolved (three-way merge, manual reconciliation UI, reject-and-retry, etc.), and no UI behavior of any kind is specified — this is a server-boundary contract, not a client experience design.
- **Precedent worth noting** (traceability, §25): the only place optimistic concurrency actually exists in this codebase today is Exchange's own Postgres schema (`row_version` columns, per `services/exchange/docs/architecture/REPOSITORY_STRUCTURE.md`). That precedent is available to a future implementer as a proven pattern already in production in this codebase — this document notes it, without mandating its reuse.

## 14. Security Requirements

**CONTRACT.**

A Server Repository Service must eventually require:

- An **authenticated caller** — reusing, not replacing, the existing Reference Server authentication boundary. ADR-0002's bearer-token mechanism (`Authorization: Bearer <OEP_API_TOKEN>`, checked once at the server boundary) is the established outer gate for this platform's server-side services (EAM today; ADR-0002 §3 already states this is designed so "future Knowledge and Exchange APIs can use the same server boundary" — a Server Repository Service is exactly such a future consumer of that same contract, whether physically co-located with EAM or its own process).
- **Authorization** (what an authenticated caller may actually do) — **explicitly not implemented by this WP, and explicitly identified here as future work.** No role hierarchy, no permission model, is defined by this document.
- **Repository-level access control** — who may read/write a given server repository at all. **UNDECIDED**, future.
- **Object/relationship-level access control**, where required — finer-grained than repository-level, for cases where not every object in a repository is equally accessible. **UNDECIDED**, future; this document does not assume it is always necessary, only that the possibility must not be architecturally foreclosed.
- **Ownership semantics** — who is recorded as the owner of a server repository (and, potentially, of individual objects). **UNDECIDED** in detail; established here only as a required concept (§5).
- **Auditability** — every mutation must be attributable (§15).
- **Provenance preservation** — see §15/§17.

**Explicitly not done by this document**: authorization implementation, tenancy implementation (multi-tenant isolation model), or any role hierarchy. These are named as required future work, not designed.

## 15. Audit and Provenance

**CONTRACT.** The Server Repository Service must preserve, as architecturally distinct concepts that must never collapse into one another:

| Distinction | Owner |
|---|---|
| Who **acquired** something (sourced a document/artifact from the outside world) | EAM (`acquisition_records`, real today) |
| Who **published** something (made a package/artifact available for distribution) | Engineering Exchange (publisher/package metadata, real today) |
| Who **created/modified engineering state** (authored or edited an Engineering Object/Relationship) | Server Repository Service (future) / local Foundation's own `AuditStore` (real today, locally) |
| Which **artifact/package supplied data** | Traceable via EAM's Vault (`sha256_hash`, `metadata_id` chain, real today) and/or `.oep`/`.oerp` package identity, depending on the path data took |
| Which **revision is authoritative** | Server Repository Service's revision mechanism (§11, future) |

**Hard requirements**: EAM's existing provenance model (`acquisition_records`, its full provenance chain — source → job → download → verification → metadata → vault entry, real and tested, per WP-SRV-005) must **not** be replaced or subsumed by a future Server Repository Service's own audit metadata. Conversely, Engineering Exchange's publication metadata (who published a package, when) must **not** become, or be conflated with, engineering provenance (who actually created the engineering content). These are answers to different questions and must remain separately queryable.

## 16. `.oerp` Boundary

**CONTRACT**, grounded in **IMPLEMENTED** fact.

`.oerp` is the Knowledge Runtime's own package format (Reference Library → compiler → `.oerp` → Knowledge Runtime, an entirely separate pipeline from `.oep`/Foundation). It is:

- A transport/package artifact — a deterministic, compiled ZIP archive.
- **Not** the server database.
- **Not** the local Foundation repository.
- **Not** a future Server Repository.
- **Not** a synchronization protocol.

A future package-installation path *may* eventually transfer content from a `.oerp` (or `.oep`) package into a Server Repository Service or a local Foundation Repository — but that transfer mechanism, and whether `.oerp` content ever becomes Engineering Objects at all, is **FUTURE** and explicitly out of this document's scope. This document changes nothing about `.oerp`'s format, its compiler, or Knowledge Runtime's consumption of it.

## 17. EAM Boundary

**CONTRACT**, restating and reinforcing existing, ratified fact (ADR-0001 §4.1, WP-SRV-002/003/004/005).

EAM remains responsible for, and only for:

- Acquisition (Official Sources, Acquisition Jobs, Connectors).
- Source evidence (Download Sessions).
- Verification (Integrity Verifications, SHA-256).
- Metadata extraction (Artifact Metadata).
- The Reference Vault (immutable, content-addressed artifact storage — real, tested against a live PostgreSQL instance as of WP-SRV-005).
- Acquisition Records / provenance (the full chain above).

**EAM does not become the Engineering Object repository.** This was already true architecturally before this document (EAM's schema, audited in full during WP-SRV-005, has no `object_id`/`relationship_id`/Engineering-Object-shaped table anywhere) and this contract makes it explicit and binding for any future work: a future Server Repository Service consumes EAM's Vault artifacts as *input* (per the requirements document's own pipeline sketch, §16: Vault → Knowledge Extraction → Engineering Objects → Relationships → Provenance → Persistent Repository), it does not fold EAM's own tables into itself, and EAM's own API/schema is not modified by this document.

## 18. Engineering Exchange Boundary

**CONTRACT**, restating and reinforcing existing, ratified fact.

Exchange remains the distribution/commercial boundary. It may:

- Publish packages.
- Index packages.
- Distribute packages.
- Record installation requests/attempts (already real: `POST /packages/{id}/install`, `GET /installations/{id}`, backed by Postgres with `row_version` optimistic concurrency).

**Exchange does not become the authoritative engineering repository.** Exchange's own `RepositoryClient` abstraction (`services/exchange/packages/interfaces/src/repository-client.ts`) is real, type-only, and deliberately isolates Exchange from ever depending on Foundation/Repository internals directly — its `install()` call describes a *future* network target's shape (`RepositoryInstallRequest`/`RepositoryInstallResult`), which a Server Repository Service could plausibly become. Today, `HttpRepositoryClient`'s real, tested HTTP client code POSTs to `{baseUrl}/api/v1/packages/install`, an endpoint that **does not exist anywhere in this repository** (confirmed independently by three prior audits) — Exchange's production wiring uses `StubRepositoryClient` (a no-op that fabricates a `repositoryPackageId`) by default. This document references that existing abstraction as evidence of a plausible future integration boundary. **It does not implement, modify, or redesign `RepositoryClient`, `HttpRepositoryClient`, or `StubRepositoryClient`.**

## 19. Knowledge Boundary

**CONTRACT.**

- Engineering Objects are engineering data — the Server Repository Service's domain (once it exists).
- Knowledge Runtime is the authority for validation, activation, and consumption of executable knowledge packages (`.oerp`) — an entirely separate authority, unaffected by this document.

This document does not create a server-side Knowledge Runtime, and does not create a second knowledge repository. The relationship between server-resident Engineering Objects and Knowledge Runtime's own package consumption is **UNDECIDED** beyond the general pipeline sketch already present in `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` §16 (Vault → Knowledge Extraction → Engineering Objects → Relationships → Provenance → Persistent Repository) — that sketch is cited as existing authoritative-document context, not designed further here.

## 20. Persistence Requirements

**CONTRACT — requirements only, no technology selected.**

This document explicitly does **not** select or design:

- A PostgreSQL schema.
- Any migration.
- Any table.
- An ORM.
- A filesystem-based server repository implementation.
- An object-storage-based repository implementation.

What this document does establish as requirements a future persistence design must satisfy:

- Must support the identity/ownership distinctions in §5.
- Must support revision retention per §11 (historical state retained, not overwritten).
- Must support the transaction/atomicity requirements of §12.
- Must not require PostgreSQL to be reachable from any untrusted network (consistent with the existing, already-established Reference Server topology — EAM's own PostgreSQL is loopback-only today, per WP-SRV-001A/WP-SRV-004/WP-SRV-005; a Server Repository Service would be expected to follow the identical posture, not a weaker one).

Choice of actual persistence technology is **UNDECIDED**, deferred to the implementing ADR (§23).

## 21. Conceptual API Surface

**CONTRACT — categories only. No route, no HTTP verb, no schema is defined or implemented here.**

Plausible future API categories for a Server Repository Service (named for architectural completeness, not specified):

- Repository discovery (what server repositories exist / are accessible to this caller).
- Repository metadata (name, description, and similar attributes of a specific server repository).
- Object retrieval (fetch a specific Engineering Object, or a specific revision of one).
- Relationship retrieval (fetch relationships, e.g. by object).
- Revision retrieval (fetch the revision history of an object/relationship).
- Object mutation (create/update an Engineering Object, subject to §11's revision/conflict rules).
- Relationship mutation (create/update a Relationship, same rules).
- Commit (the operation that finalizes a set of mutations as a new revision — see §12 for its atomicity requirement).
- Validation (checking a proposed mutation without committing it — conceptually parallel to Foundation's own existing `RepositoryValidator`, not a redesign of it).
- Audit/history (querying the audit trail established in §15).

**No implementation of any of the above exists, and none is authorized by this document.** Whatever the eventual implementation is (REST, following the existing EAM/Exchange precedent, or something else) is a decision for the ADR that actually builds this service.

## 22. Explicit Non-Goals

The following are explicitly outside WP-SRV-007 and were not performed:

- Implementation of any kind.
- Database design.
- Database migrations.
- A Server Repository process.
- HTTP routes.
- Modifications to `oep_foundation`.
- Foundation network support of any kind.
- Synchronization design or implementation.
- A conflict-resolution engine.
- Collaboration UI.
- Tenancy implementation.
- Authorization implementation.
- Distributed transactions.
- Package-installation implementation.
- Changes to Engineering Exchange.
- Changes to EAM.
- Changes to Knowledge Runtime.
- Changes to the `.oerp` format.
- Changes to ADR-0001 or ADR-0002 (both were read, neither was modified).

## 23. Future ADRs Required

This document identifies, and deliberately does not resolve, the following as requiring their own dedicated architectural decisions before any implementation begins:

1. **Does Foundation ever get a server-side existence, and if so, what shape** (a thin HTTP façade linking directly against `FoundationRuntime`, vs. a wholly separate service that only translates HTTP ↔ the existing Public C API)? This is ADR-0001's own Gap G8, still open, and the single largest undecided question this contract depends on without resolving.
2. **Synchronization** — whether, when, and how local Foundation state and Server Repository state ever reconcile automatically. Not defined anywhere in this repository today (§10).
3. **Conflict resolution** — the actual algorithm/UX for resolving a detected conflict (§11/§13 establish that conflicts must be *detected*, not how they are *resolved*).
4. **Authorization and tenancy** — the actual permission/role model and multi-tenant isolation story (§14).
5. **Persistence technology selection** (§20).
6. **Concrete wire protocol / API design** (§21) — REST route shapes, request/response schemas, error taxonomy.
7. **Cross-repository relationships and cross-repository object membership** — whether these are ever allowed (§6/§7 flag as undecided).
8. **Revision retention/pruning policy** — how long old revisions are kept (§11).
9. **The concrete relationship between `.oep`/`.oerp` package installation and Server Repository content** (§16/§18) — whether/how installed package content ever becomes server-resident Engineering Objects.

## 24. Architectural Invariants

Binding on any future implementation of a Server Repository Service, regardless of how the open questions in §23 are eventually resolved:

1. Local Foundation Repository operation must never depend on a Server Repository Service (§8).
2. A Server Repository Service must consume, not reinvent, Foundation's existing Engineering Object and Relationship identity/type schemes (§6/§7).
3. A Server Repository Service is not Remote Foundation, not Engineering Exchange, not EAM's Vault, and not a `.oerp` runtime (§9).
4. Silent last-write-wins is disallowed — conflicting concurrent mutation must be detected and surfaced (§11/§13).
5. A partial server-side commit must never be presented as a complete success (§12).
6. No distributed transaction spanning local Foundation and a Server Repository Service is implied or required (§12).
7. The existing ADR-0002 authentication boundary is the outer gate for any future Server Repository API — a Server Repository Service does not invent its own, separate authentication mechanism (§14).
8. EAM provenance and Exchange publication metadata are never conflated with engineering-state audit history (§15).
9. PostgreSQL (or whatever persistence a Server Repository Service eventually uses) must never be directly reachable from an untrusted network (§20), consistent with every prior Reference Server work package's own established posture.

## 25. Traceability to Existing Architecture

- **CLAUDE.md** (`platform/oep_foundation/CLAUDE.md`, ratified project constitution): "Repository First — The Repository is the product... Everything ultimately exists inside a Repository." Lists "Synchronization" as an eventual C++ runtime responsibility (not yet built). Establishes the Five Primitive Rule (Engineering Object, Relationship, Operation, Event, Capability) this contract's Engineering Object/Relationship boundaries (§6/§7) are bound by, and explicitly forbids introducing a sixth primitive — this contract introduces none.
- **ADR-0001** §2-3 (Reference Server as a logical grouping), §4.6 (Foundation has no server-side existence; Gap G8 explicitly undecided), §13 (server-side Foundation flagged as a future reconsideration criterion, not resolved) — the single most load-bearing piece of existing ratified architecture this contract depends on and does not contradict.
- **ADR-0002** §3 (authentication boundary explicitly designed so future Knowledge/Exchange/other server APIs can reuse it without a separate implementation) — the precedent this contract's §14 relies on.
- **ADR-0003** (TLS boundary) — read for completeness; not directly load-bearing here, since no transport is being designed.
- **`OEP-SPEC-002`/`004`/`005`/`011`/`021`** — the existing, real, local Foundation Repository/Object/Relationship/Runtime/Public-API specifications this contract's Engineering Object and Relationship boundaries are drawn directly from, unmodified.
- **`OEP-ARCH-002`** — the existing architectural assessment that first raised "does the Repository Runtime need a network face?" as an open question (§4.2, two candidate shapes, neither chosen) and documented the real `RepositoryClient`/`HttpRepositoryClient`/`StubRepositoryClient` chain this contract's §9/§18 rely on. Note for future readers: this document is dated relative to `oep_foundation`'s own `docs/tasks/WP-REP-002` through `WP-REP-008` (which post-date it and have since implemented trust verification, dependency resolution, and merge-engine capability ARCH-002 itself still describes as missing) — its specific "what's unimplemented" claims about the installer layer should not be taken as current without a fresh check; its higher-level framing (no network surface, terminology, the open "does Foundation need a server?" question) is corroborated independently by every other document read for this contract and remains accurate.
- **`docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md`** (user-owned, Divad Technology Group) — independently corroborates this contract's core premise: §1/§15/§42 all list "Engineering Object Repository"/"Repository" as a distinct, planned, core Reference Server service alongside EAM/Knowledge/Exchange, not folded into any of them. §3 independently states the same offline-must-remain-possible requirement this contract's §8 restates. §45 explicitly calls for reconciliation against "Repository architecture" as a named, separate concern — this document is offered as a first step toward that reconciliation, not a claim that it is complete. No contradiction was found between this requirements document and the rest of the evidence base; where it uses "Repository" without qualification, this contract's own terminology table (§3) is offered as the disambiguation.
- **WP-SRV-005 audit** (`docs/project/audits/2026-09-14-WP-SRV-005-*.md`) — the prior work package that first identified, live, that EAM's schema has no Engineering-Object-shaped table and that building one would contradict ADR-0001 §4.6; this contract is the direct, requested follow-up to that finding.
