# ADR-0005 — Server Repository API & Persistence Boundary

## 1. Status

**Accepted, architecture-only. No implementation exists. No implementation is authorized by this document.**

This ADR decides the minimum viable service boundary, conceptual API surface, transport, and persistence-capability requirements for a future Server Repository Service, building directly on [ADR-0004](ADR-0004-SERVER-REPOSITORY-SEMANTICS-AND-STATE-MODEL.md)'s semantic model. It does not implement anything. **A separate, future work package must explicitly authorize implementation before any code is written against this document.**

## 2. Context

ADR-0004 answered *what a Server Repository means* (identity, membership, revisions, commits, concurrency, publication/retrieval) without touching how any of it is exposed or stored. This ADR is the next, still-architecture-only layer: given that semantic model, what is the smallest service boundary, API shape, and persistence-capability set that satisfies it — and, specifically, is PostgreSQL (already running for EAM, per WP-SRV-005) the right choice, or merely the convenient one?

## 3. Existing Architecture Evidence

Everything below was read directly from the repository, not assumed:

- **EAM's real HTTP API** (`services/acquisition`): `cpp-httplib`-embedded, plain REST-shaped JSON routes with **no version prefix at all** (`/vault`, `/sources`, `/health`, etc.), authenticated by ADR-0002's bearer-token pre-routing handler, TLS-terminated externally by nginx (ADR-0003). No gRPC, no protobuf, anywhere in this service.
- **Exchange's real HTTP API** (`services/exchange/apps/exchange-api`): Fastify 5, REST-shaped JSON routes **under an explicit `/api/v1/` prefix** (confirmed directly: `/api/v1/packages/{id}/download`, `/api/v1/packages/{id}/install`, `/api/v1/health`), with an `EXCHANGE_API_VERSION` constant reported by its own health check, and OpenAPI spec generation (`spec.paths[...]`, tested directly). Also PostgreSQL-backed, with `row_version` optimistic-concurrency columns (WP-SRV-005/WP-SRV-008's own cited precedent).
- **EAM and Exchange disagree on URI versioning convention** — one has no version prefix, the other does. This ADR does not silently resolve that inconsistency by picking one as "the OEP convention"; it is noted as a real, existing divergence (§17).
- **Foundation's Public C API already has its own, separate, real version counter**: `oep_api_version()` (`platform/oep_foundation/platform/api/include/oep/api/oep_api.h`), incremented whenever the C ABI's function/type surface changes — a working, existing precedent for "API contract version" as a distinct concept from any data-model version (§17).
- **Exchange's `RepositoryClient`/`RepositoryInstallRequest`/`RepositoryInstallResult`** (`services/exchange/packages/interfaces/src/repository-client.ts`) is real, type-only, and already shaped around a future HTTP install target — its `HttpRepositoryClient` implementation is real, tested code that POSTs JSON to `{baseUrl}/api/v1/packages/install`, an endpoint that exists nowhere in this repository today (confirmed independently across WP-SRV-007/008 and the underlying `oep_exchange` architecture docs).
- **Zero gRPC/protobuf dependency anywhere in this repository** (`grep` across build/dependency manifests: no hits). Both existing server-side services (EAM, Exchange) are plain REST-over-HTTP/JSON.
- **PostgreSQL 18 already runs on the Reference Server VM**, provisioned and verified end-to-end for EAM in WP-SRV-005 (least-privilege `oep_acquisition` role, own database, migrations via Flyway, real `pg_dump`/`pg_restore` backup/restore cycle already proven).
- **Foundation's own persistence model is deliberately filesystem-based, not relational** — every Engineering Object, Relationship, and Audit Event is a flat, individually-addressable JSON file (`ObjectStore`/`RelationshipStore`/`AuditStore`, `platform/oep_foundation/platform/repository/src`), with no database anywhere in `oep_foundation`. `ObjectStore::update` performs a direct, unconditional overwrite with no revision or compare-and-swap check (re-confirmed from ADR-0004 §2 — restated here because it bears directly on this ADR's persistence-capability analysis, §11).
- **`docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md`** lists "Android client connects remotely" (§40 checklist) as a real target, and describes the Reference Server's intended transport as `HTTPS / OEP API` (§2's own diagram) without mandating REST specifically, gRPC, or any other concrete protocol.

## 4. Decision

The Server Repository Service, if and when implemented, **MUST** be:

- A distinct **logical service** under the OEP Reference Server (ADR-0001 §2), not a repurposing of EAM, Exchange, or Foundation.
- Exposed over **HTTP, using REST-shaped JSON resources**, consistent with the two existing, real, OEP server-side precedents (EAM, Exchange) and the zero-gRPC/protobuf evidence above.
- Persisted using a technology that satisfies the capability requirements in §11, with PostgreSQL identified as **architecturally appropriate but not exclusively mandated** (§12) — reusing the Reference Server's existing, already-operational PostgreSQL instance is permitted and reasonable, provided the Server Repository's own data remains logically and credential-isolated from EAM's (own database/role, mirroring WP-SRV-005's own established pattern), not merely convenient proximity.

Deployment topology (separate process, shared process, container, etc.) is **explicitly not decided by this ADR** (§23) — the logical service boundary above is binding; how it is physically deployed is deferred.

## 5. Service Boundary

- The Server Repository Service **IS** a standalone logical service, in the same sense EAM and Exchange already are: it has its own authoritative data, its own API surface, and is reachable independently of the other two, even if all three eventually share physical infrastructure (a host, a reverse proxy, an authentication token issuer).
- It **IS** a subsystem of the OEP Reference Server, in ADR-0001's sense (§2's logical grouping — EAM, Knowledge services, Exchange, and now this service, behind a shared boundary), not a peer platform component outside that grouping.
- **Authoritative responsibilities** (restating and not expanding ADR-0004 §3's decision): server repository identity (§4 of ADR-0004), server-resident Engineering Object/Relationship state, revisions (object/relationship-scoped), commit boundaries (atomic multi-mutation groupings), and server-side audit history.
- **Explicitly outside it**: acquisition/verification/metadata/Vault/provenance (EAM's domain), package distribution/publication/discovery/commercial operations (Exchange's domain), knowledge-package validation/activation (Knowledge Runtime's domain), authentication mechanics beyond consuming ADR-0002's existing boundary (§16), and the local Foundation Repository itself (untouched, unmodified, offline-capable independent of this service — ADR-0004 §13).
- It **DOES** expose repository operations directly (§6) — there is no intermediary "gateway service" reinterpreting its semantics; a caller that reaches the Server Repository Service's API is talking to the authority itself.
- It **DOES** own repository identity, object/relationship state, revisions, commit boundaries, and audit history, exactly as ADR-0004 already decided. This ADR does not re-litigate that — it only adds the exposure/persistence layer on top.
- **"Logical service" and "deployment process" are explicitly distinct here**: this ADR decides the former only. Whether the Server Repository Service ends up as its own OS process, a module inside a shared Reference Server process, or something else is a deployment-topology decision this document defers (§23).

## 6. API Semantic Boundary

Per WP-SRV-009's own explicit instruction, not every operation named below is assumed to need its own endpoint — this section defines the **minimum semantic operation set**, deferring wire-level endpoint design entirely.

**Repository**: create a repository; retrieve a specific repository's metadata; enumerate repositories the caller can access. All three are required — without creation there is no way to establish a new repository at all; without metadata retrieval, a caller cannot resolve `repository_id` → descriptive information; without enumeration, a caller has no way to discover what it may work with.

**Objects**: create an object; retrieve the current (latest-revision) state of an object; retrieve a specific historical revision of an object (ADR-0004 §7 requires this be possible); update an object (subject to §9's concurrency contract); enumerate/query objects within a repository (required — a caller must be able to discover what exists, not only fetch objects whose id it already knows). Delete: see §21 (Task 18) — **deferred**, not assumed.

**Relationships**: the same five operations, mirrored — create; retrieve current; retrieve historical revision; update; enumerate/query (at minimum "relationships touching a given object," the operation Foundation's own local `RelationshipStore` already supports today). Delete: same deferral as objects.

**Commit**: submit an atomic mutation set (§8); retrieve the result of a specific commit (which revisions it produced, or why it was rejected) — required directly by ADR-0004 §8's success/failure semantics, which are meaningless if a caller cannot learn the outcome.

**Concurrency**: every mutating operation (object/relationship create or update, and every mutation within a commit) **MUST** be able to carry the caller's expected revision (ADR-0004 §10); the server **MUST** be able to reject a mutation as stale. This is not a separate operation category with its own endpoints — it is a required property of every mutating operation above.

**History**: retrieve revision history for a specific object/relationship (the ordered list of past revisions); retrieve a specific historical revision's full state (subsumed by "retrieve historical object/relationship revision" above — listed separately here only because WP-SRV-009 named it separately; this ADR treats it as the same underlying capability, not a sixth operation).

**Publication**: accept a caller-selected set of local Engineering Objects/Relationships and commit them server-side, preserving their UUIDs exactly (ADR-0004 §11). Semantically, this is **not a new primitive** — it is the "submit an atomic mutation set" (Commit, above) operation, called with locally-originated content as its payload. This ADR does not define a separate "publish" endpoint category distinct from Commit; publication is a *usage* of the commit operation, not a different operation.

**Retrieval**: obtain a selected set of server-resident objects/relationships (at their current or a specific historical revision) for local materialization. Semantically, this is the same underlying capability as "retrieve current/historical object/relationship" above, used by a local Foundation client rather than an arbitrary caller — again, not a distinct sixth primitive.

**Net minimum semantic operation set** (collapsing the above): *create repository, get repository, list repositories, create/update object (unified as "mutate," carrying expected revision), get current object, get historical object revision, list/query objects, create/update relationship (same "mutate" shape), get current relationship, get historical relationship revision, list/query relationships, submit commit (the vehicle for all multi-item mutation, including publication), get commit result.* Roughly a dozen semantic operations, not dozens of endpoints — deliberately smaller than a naive one-endpoint-per-bullet reading of the WP-SRV-009 task text would produce, because publication/retrieval/history collapse into operations already required for other reasons.

## 7. Transport Decision

Evaluated against the four options WP-SRV-009 named:

**A. HTTP/REST-style API — SELECTED**, for the initial architecture.
**B. RPC-style API over HTTP** (e.g. a single POST endpoint dispatching by method name, or gRPC) — evaluated, not selected (rationale below).
**C. Another existing OEP-compatible transport** — none exists; EAM and Exchange are both plain HTTP/JSON, and no other transport (message queue, gRPC, custom binary protocol) appears anywhere in this codebase's real, running services.
**D. Intentionally deferred** — not selected; deferring transport entirely would leave §6's operation set unable to be validated against real constraints (payload size, auth header propagation, client library availability), so this ADR makes the call now, using the evidence in §3.

**Rationale, evidence-based, not fashion-based**:
- **Existing OEP networking conventions**: both real server-side services (EAM, Exchange) already use plain HTTP/JSON. Introducing a third transport technology for a third service would fragment client-side networking code across three different protocols for no demonstrated benefit — directly contrary to CLAUDE.md's own dependency philosophy ("Every dependency increases long-term maintenance cost... would this dependency still be appropriate ten years from now?").
- **Exchange's `RepositoryClient`**: already assumes HTTP/JSON (`RepositoryInstallRequest`/`Result`, a POST with a JSON body) — if the Server Repository Service is ever the thing behind that interface (ADR-0004 §16, still undecided *whether*, but the *shape* Exchange already committed to is HTTP/JSON), HTTP/REST is the only transport that requires no change to that already-real code.
- **Desktop (Windows/Linux) and Android client requirements**: `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` explicitly lists Android as a target client (§40 checklist: "Android client connects remotely") and describes the transport as "HTTPS / OEP API" without mandating a specific protocol. HTTP/JSON has universal, mature client support on every one of OEP's target platforms (Windows, Android, Linux, and Studio's own Dart/Flutter stack) with zero new native dependencies; gRPC would require a protobuf toolchain and gRPC client libraries on every platform, none of which exist in this codebase today.
- **ADR-0002's authentication boundary**: already designed as an HTTP bearer-token pre-routing check, explicitly "designed so future Knowledge and Exchange APIs can use the same server boundary" (ADR-0002 §3). HTTP/REST lets a Server Repository Service reuse that exact mechanism with zero adaptation; a non-HTTP transport would require either a parallel auth mechanism or an HTTP-to-other-protocol gateway, adding complexity ADR-0002 already anticipated avoiding.
- **Future compatibility, observability, testability**: HTTP/JSON is directly observable with tools already used elsewhere in this repository (`curl`, browser devtools, the nginx access logs already established in WP-SRV-004), and every existing test suite in this codebase (EAM's `httplib::Client`-based tests, Exchange's `app.inject()`-based tests) already exercises this exact pattern — a Server Repository Service's own tests could follow either precedent directly.
- **Simplicity**: fewer moving parts than introducing a new RPC framework, consistent with WP-SRV-009's own instruction to "select the smallest architecture that satisfies actual OEP requirements," not the most fashionable one.

**HTTP transport is distinguished from REST resource design**, per WP-SRV-009's own explicit instruction: this ADR selects HTTP/JSON as the wire transport and states that the resource shape should be REST-*style* (resources addressed by identity, standard verbs for CRUD-shaped operations, a dedicated action-style endpoint for the non-CRUD "submit commit" operation — mirroring EAM's own precedent of using a non-resource action path for `/jobs/{id}/execute`). **No endpoint path, HTTP verb-to-operation mapping, or URI scheme is defined here** — that is wire-level design, explicitly deferred to a future implementation-design work package.

## 8. Commit Representation

ADR-0004 §8 requires atomic, all-or-nothing multi-mutation commits. This ADR establishes the conceptual shape a future API must represent, without serializing it:

- **Mutations MUST be submitted together**, as a single logical request representing one commit — not as several independent requests the server is expected to correlate after the fact.
- **Every mutation within a commit that targets an existing object/relationship MUST carry that item's expected revision** (ADR-0004 §10) — this is how the server evaluates concurrency per-item within the commit.
- **A create operation has no prior state to be "expected"** — for a create, "expected state" is inherently "does not yet exist" (ADR-0004 §11 already established this for the first-publication case; it generalizes to every create, not only publication). A create mutation therefore does not carry an expected revision in the same sense an update does, but **MAY** need to signal "this must not already exist" if idempotent-retry safety (§10 of this ADR / ADR-0004 §18) requires distinguishing "already created by a prior, successfully-retried attempt" from "a genuine duplicate-identity conflict."
- **Deletes participate in the same atomic commit**, if/when deletion is supported at all (§21 — currently deferred). This ADR does not grant deletes special atomicity treatment distinct from creates/updates.
- **Relationship creation CAN occur within the same commit as the object creation it depends on** — this is a direct, required consequence of ADR-0004 §8's own example use case (creating an object and the relationship connecting it to an existing one, atomically). A commit is not required to reference only pre-existing objects.
- **Validation failure** (a mutation within the commit fails structural/semantic validation — e.g. a relationship whose endpoint doesn't exist, per ADR-0004 §7's integrity requirement) **MUST** cause the entire commit to be rejected, with the specific failing mutation(s) identified. This is a distinct failure category from concurrency failure (§9/§16).
- **Concurrency failure** (one or more mutations' expected revisions are stale, ADR-0004 §10) **MUST** likewise reject the entire commit, and **MUST** be distinguishable, in whatever the response representation eventually is, from a validation failure — a caller needs to know whether to re-read-and-retry (concurrency) or fix its request (validation), and conflating the two would defeat ADR-0004 §10's own requirement that conflicts be "reported to the client explicitly."

No serialized format (JSON schema, field names, HTTP status code assignment) is defined here — this section establishes the semantic shape a future wire-format design must satisfy.

## 9. Concurrency Boundary

Directly restating ADR-0004 §10 in this ADR's own API-boundary terms, not redeciding it:

- The conflict check the API must support is **per-object/per-relationship**, not repository-wide, matching ADR-0004 §10's own decision.
- Every mutating operation in §6/§8 **MUST** accept an expected-revision value and **MUST** be capable of returning a distinct `CONCURRENCY_CONFLICT`-shaped outcome (§19) rather than either silently succeeding or returning an indistinguishable generic failure.
- This ADR does not add anything beyond what ADR-0004 already decided; it exists here only to confirm the API surface (§6/§8) is actually capable of carrying the concurrency contract ADR-0004 requires.

## 10. Idempotency Requirement

ADR-0004 §18 established the semantic requirement (safe retry after an uncertain network failure) without choosing a mechanism. This ADR resolves the mechanism at the semantic level, per WP-SRV-009's own explicit instruction to defer wire representation:

- **A client-generated, caller-supplied operation identity is required.** Reasoning: the specific failure case named by WP-SRV-009 (client submits a commit, server accepts it, the connection drops before the client learns the outcome, client retries) cannot be resolved safely by *server-generated* identity alone — a server-generated commit ID is only knowable *after* a successful commit, which is exactly the information the client is missing in this failure case. Only a client-supplied identity, chosen *before* the request is sent, lets the server recognize "this is the same commit attempt as before" on retry.
- This identity is a property of **the commit as a whole** (§8), not of each individual mutation within it — a retried commit is retrying the entire atomic group, not individual pieces of it.
- Semantic contract: if the server receives a commit request whose caller-supplied operation identity matches one it has already successfully applied, it **MUST** treat the retry as a no-op success (returning the original outcome) rather than either re-applying the mutations a second time or rejecting the retry as a conflict against its own already-applied result.
- If the server receives a commit request whose operation identity matches one that is genuinely still in-flight (a true concurrent duplicate, not a retry after uncertainty), the specific behavior (block until the first completes, reject the second, etc.) is **UNDECIDED** — this ADR establishes the requirement for retry-safety, not full request-deduplication semantics under genuine concurrency.
- **No specific field name, header, or storage mechanism is chosen.** Whether this is realized as an HTTP header, a JSON body field, or something else is deferred to the future wire-protocol design (§17 of ADR-0004, restated as still-future here).

## 11. Persistence Requirements

What persistence **must provide**, independent of which technology provides it:

- **Repository identity durability** — a `repository_id` and its associated metadata (ADR-0004 §4) must survive process/server restart.
- **Current object/relationship state** — the latest revision of every Engineering Object/Relationship must be efficiently retrievable by its canonical UUID.
- **Historical revisions** — every past revision (ADR-0004 §7) must remain retrievable, not merely the latest.
- **Relationships** — directional links between two objects, addressable independently of either endpoint (so "what relationships touch object X" is answerable without scanning every relationship).
- **Atomic multi-object commit** — the persistence layer must support committing a set of object/relationship mutations such that either all are durably applied or none are (ADR-0004 §8/§9) — this is a hard requirement on whatever storage technology is chosen, not an optional nicety.
- **Optimistic concurrency** — the persistence layer must support "apply this mutation only if the current stored revision matches the expected one" as an atomic check-and-write, not a separate read-then-write with a race window.
- **Audit history** — a durable, append-only (in practice, if not enforced at the storage layer, at minimum never-mutated-in-place) record of commits and their effects (ADR-0004 §17).
- **Retrieval of historical state** — not merely retention; the ability to reconstruct and return a specific past revision's full content on request.
- **Durability across restart** — all of the above must survive an ordinary process restart, matching the durability bar EAM's own PostgreSQL persistence already meets (WP-SRV-005's restart test).
- **Backup/restore compatibility** — the persisted state must be independently exportable and re-importable without requiring the live service to be running in a specific state (mirroring WP-SRV-005's own proven `pg_dump`/`tar`-based EAM backup pattern — not mandating that exact mechanism, but requiring an equivalent capability exist).
- **Integrity validation** — a way to verify that persisted state has not been silently corrupted (at minimum, an equivalent of Foundation's own local `RepositoryValidator` concept, re-targeted at server-side storage — not a redesign of that validator, an architectural expectation that something analogous must exist).

## 12. PostgreSQL Evaluation

Explicitly evaluated against the four possible outcomes WP-SRV-009 named, reasoning from requirements (§11) rather than from convenience or from Foundation's own filesystem precedent:

**Finding: PostgreSQL is architecturally appropriate, not merely convenient — with specific conditions stated below, and with the technology choice itself still formally deferred to the implementing work package rather than irreversibly locked in here.**

Reasoning:
- **The Server Repository's data model is genuinely relational in the ways that matter for §11's requirements.** Relationships are literally graph edges between two identity-bearing rows (source/target object references) — a shape relational databases handle natively via foreign keys and joins, unlike Foundation's own local model, which gets away with flat files precisely *because* it is single-process/single-writer/no-concurrent-conflict (ADR-0004 §2, fact 2) and does not need query-time relationship traversal at scale.
- **Transactional/atomicity requirements (§9/§11) map directly onto a mature, already-proven capability.** PostgreSQL's own transaction support is exactly the "atomic multi-object commit" primitive §11 requires, with zero new engineering needed to provide it — Exchange's own `row_version`-based optimistic concurrency (real, in production) is direct, already-working evidence this exact pattern is viable on PostgreSQL in this specific codebase, not a hypothetical.
- **Revision history is a natural fit for relational storage** — either as an explicit revision table (one row per historical revision, foreign-keyed to the object/relationship it belongs to) or an event-sourced append-only table, both well-understood PostgreSQL patterns, unlike Foundation's local flat-file model, which has no revision concept to begin with and would need one invented from nothing regardless of which storage technology is chosen.
- **Backup/restore is already solved, concretely, for exactly this environment**: WP-SRV-005 already provisioned a least-privilege PostgreSQL role/database, applied real migrations, and proved a full `pg_dump`/`pg_restore` cycle end-to-end on this Reference Server's own PostgreSQL 18 instance. Choosing PostgreSQL for the Server Repository reuses operational knowledge and tooling that already exists and is already validated in this exact deployment, rather than requiring a second backup/restore story to be invented for a different technology.
- **Operational complexity**: adding a second database technology (e.g. a document store, an embedded key-value store) to a Reference Server that already runs PostgreSQL for EAM increases operational surface (a second thing to back up, monitor, secure, patch) for no capability PostgreSQL cannot already provide, per the requirements in §11.
- **Foundation's filesystem-oriented model is not evidence against PostgreSQL here** — Foundation's choice is correct *for Foundation's own constraints* (single local process, offline-first, no concurrent writers, ADR-0004 §2/§13), none of which apply to a server handling multiple remote, potentially concurrent clients. WP-SRV-009's own instruction not to reject PostgreSQL merely because Foundation is filesystem-based is honored directly: the rejection would have been the wrong inference, and this ADR does not make it.
- **The one genuine caution, stated explicitly**: PostgreSQL being *already installed* for EAM is not, by itself, a justification — reusing it is justified here only because §11's actual requirements (relational structure, transactions, mature backup tooling already proven in this environment) independently point the same direction. If a future implementer finds the Server Repository's actual query patterns don't need relational joins at all (e.g. if it turns out to be dominated by simple key-value lookups with no relationship-traversal queries), that would be new evidence potentially warranting reconsideration — not something this ADR forecloses.

**What is decided**: PostgreSQL is an architecturally sound choice for Server Repository persistence, satisfying §11's requirements without forcing new, unproven infrastructure into this environment.
**What remains undecided**: whether the Server Repository's PostgreSQL database is the *same* PostgreSQL instance/cluster as EAM's (sharing hardware, distinct database + role, mirroring WP-SRV-005's own EAM/EAM-test separation pattern) or a genuinely separate instance; the exact schema; whether any *non*-relational storage is used alongside PostgreSQL for any specific sub-concern (e.g. large object payloads, if that ever becomes relevant — no evidence today suggests it will). **Both are deferred to the implementing work package.**

## 13. Foundation Interaction

- **Foundation itself does not call the server.** `FoundationRuntime`'s Public C API (`OEP-SPEC-021`) explicitly excludes network APIs and remote Foundation (re-confirmed directly from the header: no HTTP client, no socket code anywhere in `oep_foundation`). This ADR does not add any such capability. **Foundation's C API surface is not expanded by this ADR** — nothing here requires a new `oep_*` function.
- **A higher-level client/service calls both** — the natural shape, consistent with how Studio already works today (Foundation loaded in-process via `dart:ffi`, per ADR-0001 §1) and how a future publication/retrieval feature would plausibly work: a Studio-level (or CLI-level) component that already has access to Foundation's local repository *and* can make an authenticated HTTP call to the Server Repository Service, orchestrating both, without either side needing to know about the other directly.
- **Publication is not a Foundation primitive.** It is a capability of whatever client/service layer sits above Foundation, using Foundation's existing local read operations (already real) plus a new (future, unimplemented) HTTP call to the Server Repository. Foundation itself gains no new "publish" function.
- **Retrieval is not a Foundation primitive**, for the same reason — a client/service layer receives server data over HTTP and then calls Foundation's *already-existing* local create/update operations to materialize it locally. No new Foundation-side "retrieve" function is implied.
- **Synchronization is not represented anywhere in this ADR or in any API surface it defines** — reaffirming ADR-0004 §19's own explicit statement, not merely repeating it: no polling loop, no background reconciliation, no client-side sync agent is designed here.
- **Foundation MUST remain able to operate without server access.** Every capability named above (publication, retrieval) is additive, optional, and layered on top of an already-complete, already-offline-capable local system (ADR-0004 §13) — never a precondition for local operation.

## 14. Exchange Interaction

- Exchange's `RepositoryClient` abstraction (`services/exchange/packages/interfaces/src/repository-client.ts`) is **conceptually compatible** with a future Server Repository Service being the thing behind it — both this ADR (§6/§8) and Exchange's own interface assume HTTP/JSON, a POST-shaped "install/submit" operation, and an accept/reject-with-reason result shape.
- **Whether it should eventually target the Server Repository Service is not decided here.** That is precisely the open question ADR-0004 §16 and the WP-SRV-007 contract §18 already flagged and left open — this ADR does not resolve it, only confirms the two designs are not mutually incompatible at the shape level.
- **Its current HTTP client assumptions are not sufficient as-is**, and this is documented as a real gap rather than silently patched: `RepositoryInstallRequest` carries a `.oep` package artifact (`packageId`, `version`, `artifact: Buffer`, `sha256`, `fileName`) — a package-shaped payload, not an Engineering-Object/Relationship-shaped commit (§6/§8 of this ADR). If Exchange's `RepositoryClient` is ever pointed at a Server Repository Service, either (a) the Server Repository Service would need to accept and unpack `.oep` packages into Engineering Objects itself (which ADR-0004 §14 already forbids — "the Server Repository MUST NOT become an implicit package runtime"), or (b) a translation layer between "Exchange's package-install request" and "a Server Repository commit" would be needed somewhere else in the architecture. **Neither option is decided here.**
- **A separate client abstraction may be required** to actually reach a Server Repository Service (Exchange's `RepositoryClient` as it exists today is shaped for package installation specifically, not general object/relationship CRUD) — **UNDECIDED**, and explicitly not designed by this ADR.
- **This decision is deferred.** No Exchange code is modified, and no conflict is silently resolved — the mismatch between Exchange's package-shaped `RepositoryClient` and this ADR's object/relationship-shaped commit API is recorded as a real, open architectural question for whichever future ADR actually connects the two (§27).

## 15. EAM Interaction

Confirmed directly, consistent with every prior WP-SRV-005/007/008 finding (EAM's real PostgreSQL schema has no Engineering-Object-shaped table anywhere):

- The Server Repository API **does not** accept Engineering Objects directly *from EAM* as a first-class integration — EAM has no code path that produces Engineering Objects today, and this ADR does not create one.
- The Server Repository API **does not** accept EAM Vault artifacts directly. A Vault artifact (an immutable, content-addressed byte stream, EAM's domain) is not an Engineering Object (a structured, typed record with `object_id`/`ObjectType`/relationships) — accepting raw Vault bytes as if they were Engineering Objects would collapse a distinction ADR-0004 §15 explicitly requires stay intact.
- The Server Repository API **does not** accept Knowledge Packages (`.oerp`) — reaffirming ADR-0004 §14/§9.
- The Server Repository API **does not** accept publication from an external compiler as a distinct integration path — no such path is named by any evidence gathered for this or any prior WP-SRV-00x work.
- **The Server Repository API only owns already-defined Engineering Objects/Relationships**, created via the commit operation (§6/§8), by whatever caller is authorized to do so (a Studio client publishing local Foundation content, per §13 — the only concrete producer this ADR's evidence actually supports).
- **No EAM → Server Repository conversion pipeline is introduced.** The "Knowledge Extraction" step sketched conceptually in `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` §16 (Vault → Knowledge Extraction → Engineering Objects) remains exactly what ADR-0004 §15 already called it: named, not designed, and explicitly not EAM's own responsibility. This ADR does not narrow or resolve that open question further.

## 16. Security Boundary

```
Transport/API
    ↓
Authentication  (ADR-0002's existing bearer-token boundary — reused, not replaced)
    ↓
Authorization   (future — not designed here)
    ↓
Server Repository operation
```

- **Authentication is not authorization**, restated as a binding distinction for this ADR's own API surface: a request passing ADR-0002's bearer-token check establishes *that the caller holds a valid token*, nothing about *what that caller may do*.
- **What the Server Repository API requires semantically from an authenticated caller**: at minimum, enough context to evaluate the ownership/authorization concepts ADR-0004 §6 already named as required-but-undesigned (repository-level access, and potentially object/relationship-level access) — but this ADR does not specify how that context is carried (a claim in the token, a separate lookup, etc.), consistent with ADR-0004 §6's own deferral.
- **No users, roles, tenants, ACL tables, or permission APIs are designed by this ADR.** Nothing in the evidence gathered for this work package (ADR-0002, the requirements document, existing EAM/Exchange code) establishes a concrete authorization model that would make designing one now anything other than invention — so none is invented. These remain explicitly future authorization architecture (ADR-0004 §19/§22 already named this; this ADR does not narrow it further).

## 17. Versioning

Five distinct version concepts, per WP-SRV-009's own explicit instruction not to conflate them:

1. **Repository data model version** — describes the *shape* of what a repository conceptually contains (this ADR's own operation/entity model, §6). Versioning this is only meaningful once the model itself changes; **UNDECIDED** whether/how this is tracked, since the model described here is the first version of itself.
2. **API contract version** — the wire-level request/response shape a client and server agree on. **Not designed here** (no URI scheme, no header scheme chosen), but this ADR notes the existing, real divergence between EAM (no version prefix) and Exchange (`/api/v1/` prefix, an `EXCHANGE_API_VERSION` constant) as evidence that this platform does not yet have one consistent convention to inherit — a future implementation work package must make an explicit choice rather than silently copying one or the other. Foundation's own `oep_api_version()` integer-counter pattern is additional, independent evidence of a working local precedent for "a single incrementing number describing API surface changes," offered as a candidate, not mandated.
3. **Object schema/type version** — `EngineeringObject.version`, the existing free-text field Foundation already has (ADR-0004 §2, fact 1's sibling fact: this field describes the *engineering content's* own version, set by its author — e.g. "this document is at revision 2.1 of the underlying engineering work" — a completely different concept from #4 below, and unmodified by this ADR).
4. **Persistence schema version** — the version of whatever concrete database schema (§12) eventually stores Server Repository data. **Not designed here** — this is implementation detail belonging to the future persistence-design work package, tracked however that technology conventionally tracks schema versions (e.g. Flyway migration numbers, following EAM's own already-proven WP-SRV-005 precedent, if PostgreSQL is the eventual choice).
5. **Foundation compatibility version** — whether a given local Foundation installation's data model is compatible with a given Server Repository API version, relevant only once publication/retrieval (§13) actually exist. **UNDECIDED**, future.

**Decided now**: these five are formally distinct and must never be represented by one shared version number. **Deferred**: the concrete mechanism for #2, #4, and #5; #1 and #3 already exist in their current, first forms and need no new decision yet.

## 18. API Evolution

Principles, not mechanisms — no version number or URI scheme is fixed here:

- **Backwards compatibility SHOULD be preserved** for any change that does not alter the meaning of an existing operation — adding an optional field, adding a new operation, is preferred over changing an existing one's meaning.
- **Additive changes SHOULD be the default evolution path** — new operations, new optional fields, new error categories (§19) can be introduced without breaking existing callers, consistent with how Foundation's own `oep_api_version()` precedent already treats "does this change the existing surface" as the trigger for a version bump, not every change.
- **Removal/deprecation MUST be explicit and MUST NOT be silent** — an operation or field a future client still relies on must not simply disappear; some deprecation signal (the concrete mechanism is undecided, consistent with #2 in §17) must precede removal.
- **Client capability detection SHOULD be possible** — a client should be able to determine what the server currently supports (at minimum, an API version it can compare against its own expectations, mirroring Exchange's own real `/api/v1/health` reporting `EXCHANGE_API_VERSION`) rather than discovering incompatibility only via a runtime failure.
- **Server/client version mismatch MUST fail clearly**, not silently — an incompatible client and server pairing should produce an explicit, diagnosable error rather than subtly corrupt or misinterpreted data. The concrete mechanism (a version-negotiation handshake, a version header checked per-request, etc.) is **UNDECIDED**, deferred to the implementing work package.

## 19. Error Model

Evaluated against WP-SRV-009's own candidate list; smallest useful set selected, grounded in what this ADR and ADR-0004 actually require a caller be able to distinguish:

**Required** (each corresponds to a distinct outcome this ADR's own decisions already require be distinguishable):
- `AUTHENTICATION_REQUIRED` — no/invalid bearer token (ADR-0002's existing category, reused here, not reinvented — ADR-0002 §8 already defines this exact outcome for EAM; a Server Repository Service reusing the same authentication boundary reuses the same failure category).
- `NOT_FOUND` — a referenced repository, object, or relationship does not exist (or the caller cannot see it — see §16's authentication-vs-authorization note; whether "not found" and "not authorized to see" are ever deliberately conflated for information-hiding reasons is **UNDECIDED**, a future authorization-design question).
- `VALIDATION_FAILED` — a mutation fails structural/semantic validation (§8), distinct from a concurrency conflict.
- `CONCURRENCY_CONFLICT` — a mutation's expected revision is stale (§9/ADR-0004 §10) — **must** be distinguishable from `VALIDATION_FAILED`, per §8's own requirement.
- `COMMIT_REJECTED` — a general category for "the atomic commit as a whole did not apply," potentially the parent/summary category a specific `VALIDATION_FAILED` or `CONCURRENCY_CONFLICT` is nested under, rather than a fifth independent thing — **this ADR treats `COMMIT_REJECTED` as the outer envelope and `VALIDATION_FAILED`/`CONCURRENCY_CONFLICT` as the specific reason inside it**, avoiding an ambiguous fourth category that duplicates the other two.
- `INTERNAL_FAILURE` — an unexpected server-side error, reported generically (mirroring the established, already-real EAM precedent, WP-SRV-005 §13's fixed leak: a generic, path-free, credential-free message, never raw internal detail).

**Evaluated, not adopted as separate categories**:
- `AUTHORIZATION_DENIED` — a real, necessary future category once authorization (§16) is actually designed, but inventing it now, with no authorization model behind it, would be a category with nothing to populate it — **named here as required future work, not adopted as an active category yet.**
- `DUPLICATE_IDENTITY` — subsumed by `VALIDATION_FAILED` (a create whose UUID already exists is a validation failure of the mutation, not a distinct top-level category) unless a future implementer finds a concrete reason callers need to distinguish it specifically — **not adopted as separate, deferred**.
- `INVALID_RELATIONSHIP` — subsumed by `VALIDATION_FAILED` for the same reason (a relationship whose endpoint doesn't exist, ADR-0004 §7, is a validation failure of that specific mutation) — **not adopted as separate, deferred**.
- `REPOSITORY_NOT_FOUND` — subsumed by the general `NOT_FOUND` category (a repository is one of the three resource kinds — repository, object, relationship — `NOT_FOUND` already covers) — **not adopted as separate, deferred**.

**Decided**: stable, machine-readable error categories are required (WP-SRV-009's own question, answered yes) — a caller must be able to programmatically distinguish "retry with a fresh read" (`CONCURRENCY_CONFLICT`) from "fix your request" (`VALIDATION_FAILED`) from "you're not allowed to do this at all" (`AUTHENTICATION_REQUIRED`, and eventually `AUTHORIZATION_DENIED`) from "something is broken" (`INTERNAL_FAILURE`). **Not decided**: the wire representation of these categories (an HTTP status code mapping, a JSON `error` field's exact shape) — deferred, consistent with every other wire-level deferral in this ADR.

## 20. Query/Search Boundary

- **Direct object retrieval, relationship retrieval, and repository enumeration are required** — already established as part of the minimum operation set (§6); without them the API cannot satisfy even ADR-0004's own basic requirements.
- **Object enumeration (listing/querying objects within a repository) is required**, for the same reason given in §6 — a caller needs a way to discover content, not only fetch by already-known ID.
- **Filtering** (enumeration narrowed by some criterion — object type, tag, author) **SHOULD** be supported eventually but its concrete shape is **UNDECIDED** — this ADR does not design a query language.
- **Text search, graph traversal, and semantic search are explicitly NOT required by this ADR**, and this ADR explicitly distinguishes **repository query** (simple, structural: "give me objects of this type," "give me relationships touching this object" — mirroring capabilities Foundation's own local `GraphEngine`/`SearchEngine` already provide *locally*, real today) from **engineering knowledge search** (semantic, content-aware search — Knowledge Runtime's domain, per ADR-0004 §14/WP-SRV-007 §19, not this service's). **The Server Repository Service MUST NOT import or reimplement Knowledge Engine search semantics.**
- Per WP-SRV-009's own instruction to prefer deferral where actual requirements do not justify implementation: graph-traversal-style server-side queries (mirroring Foundation's local `GraphEngine`) are named as a plausible future capability, not committed to now — no evidence gathered for this ADR demonstrates an immediate need for server-side graph traversal beyond simple object/relationship lookup.

## 21. Delete/Tombstone Semantics

**Deferred, per WP-SRV-009's own explicit permission to defer where it cannot be safely decided now.**

What is established:
- ADR-0004 §7 already establishes that revisions themselves **MUST NOT** be deleted as an ordinary operation — this is unaffected by whatever delete-of-current-state semantics are eventually decided.
- Foundation's own local audit model already distinguishes `ObjectDeleted`/`RelationshipDeleted` as real event types (`audit_event.hpp`) — establishing that "an object/relationship can be deleted" is at least a locally-precedented concept, even though local `ObjectStore`'s actual delete behavior (`remove()`, confirmed by direct code inspection during ADR-0004's own research) is a hard filesystem delete with no tombstone or soft-delete mechanism today, and `OEP-SPEC-004` §9 itself only says delete "shall be soft-delete capable **in future revisions**" — i.e. even locally, soft-delete/tombstoning is not yet real, only anticipated.

What is deferred, explicitly, rather than decided:
- Whether an Engineering Object/Relationship can be deleted at the Server Repository at all.
- Whether deletion creates a revision (if deletion is supported, it plausibly **SHOULD**, for consistency with every other mutation type per §7/§8 — but this ADR does not commit to that without first deciding *whether* deletion exists).
- Whether deletion is permanent or requires a tombstone (a marker revision indicating "this item was deleted, as of revision N," preserving history without preserving current-state visibility).
- What happens to relationships when an endpoint object is deleted (cascade-delete the relationship? leave a dangling reference and let retrieval fail meaningfully? reject the object deletion while relationships still reference it?) — **UNDECIDED**, and genuinely consequential enough that inventing an answer without dedicated analysis would risk exactly the kind of "invent destructive behavior" WP-SRV-009 explicitly warns against.
- Whether a deleted object/relationship can be restored from history (plausible, given revisions are retained per §7 of ADR-0004, but not decided).

**This ADR takes no position on whether delete support is even in-scope for a first Server Repository implementation** — it may be entirely reasonable for a first version to support only create/update, with delete deferred to a later capability. That scoping decision itself is left to the implementing work package.

## 22. Backup/Restore Requirements

- Server Repository data (current state, full revision history, and audit history — §11) **MUST** be independently exportable from whatever underlying persistence engine stores it, mirroring the requirement §11 already states and the concrete, already-proven pattern WP-SRV-005 established for EAM (`pg_dump`/`tar`, real, tested, including a full restore-into-a-throwaway-database verification).
- Backup and restore **MUST NOT** require the live service to be in any specific state (e.g. quiesced, read-only) beyond whatever the chosen persistence technology's own standard backup tooling already requires (PostgreSQL's `pg_dump`, if §12's evaluation is followed, already satisfies this — it does not require downtime).
- **No backup tool, schedule, retention policy, or automation is selected or implemented by this ADR.** This section states the capability requirement only, exactly as §11 does for persistence generally.

## 23. Deployment Boundary

- **Not decided by this ADR**: whether the Server Repository Service runs as a separate executable, a module inside a shared Reference Server process, a separate container, a library linked into something else, or on a separate host. None of the evidence gathered for this work package (existing EAM/Exchange deployment, the VM infrastructure established across WP-SRV-001A through WP-SRV-005) requires this decision to be made now, and WP-SRV-009's own instructions explicitly forbid deciding it "unless existing architecture requires it" — it does not.
- **The logical service boundary (§5) is explicitly distinct from deployment topology.** Everything this ADR decides (API shape, persistence requirements, PostgreSQL appropriateness) holds regardless of which deployment topology a future implementation ultimately picks.
- **This ADR does not authorize the Reference Server to acquire a new runtime service.** No process is started, no container is defined, no systemd unit or deployment configuration is created or implied by this document's existence.

## 24. Explicit Non-Goals

This ADR does **not**:

- Implement anything.
- Create any C/C++, Dart/Flutter, TypeScript, or other source code.
- Create any SQL, database schema, or migration.
- Create any HTTP endpoint, route, or handler.
- Create any database access code.
- Modify Foundation, EAM, or Exchange in any way.
- Create or modify any deployment configuration (Docker, systemd, nginx, or otherwise).
- Select a concrete wire protocol (URI scheme, JSON field names, HTTP status code mapping).
- Design authorization, tenancy, or any role/permission model.
- Design a conflict-resolution algorithm or UI (only conflict detection is addressed, inherited from ADR-0004).
- Design synchronization of any kind (explicitly reaffirmed as still undefined).
- Decide deployment topology (§23).
- Resolve whether Exchange's `RepositoryClient` ever targets this service (§14 — documented as an open mismatch, not resolved).
- Decide delete/tombstone semantics (§21 — explicitly deferred).

## 25. Consequences

- A future implementation work package has a concrete, evidence-grounded target for the API's semantic operation set (§6), transport (§7), commit representation (§8), idempotency mechanism's semantic requirement (§10), and persistence-capability checklist (§11) — closing most of the remaining ambiguity between ADR-0004's semantics and an actual buildable service.
- Because PostgreSQL is identified as architecturally appropriate (§12) using the same operational pattern WP-SRV-005 already proved for EAM (least-privilege role, own database, Flyway migrations, `pg_dump`/`pg_restore`), a future implementation can reuse proven operational knowledge rather than inventing a second persistence story from scratch — while remaining free to choose differently if new evidence emerges.
- Because HTTP/REST-style JSON is selected (§7) using the same pattern both EAM and Exchange already use, a future implementation's client-side integration work (Studio, CLI, or any future Android client) has two working precedents to draw from rather than needing to build support for a new transport technology.
- Because the API/URI-versioning inconsistency between EAM and Exchange is documented rather than silently resolved (§17), a future implementation work package is warned not to assume either existing service's convention is "the" OEP convention without an explicit decision.
- Because Exchange's `RepositoryClient` payload shape (`.oep` package bytes) does not match this ADR's commit shape (Engineering Object/Relationship mutations), the Exchange↔Server-Repository integration question (ADR-0004 §16) remains explicitly open rather than falsely appearing resolved by this ADR's existence — a future implementer will not discover this mismatch only after starting to build the integration.

## 26. Open Questions

1. Whether the Server Repository's PostgreSQL database shares an instance/cluster with EAM's, or is fully separate (§12).
2. The concrete wire protocol: URI scheme, JSON field names, HTTP status code mapping, versioning header/scheme (§7/§17/§18).
3. The concrete authorization/tenancy model (§16, restating ADR-0004 §6/§19's own deferral).
4. Whether/how Exchange's `RepositoryClient` is ever adapted or replaced to target a Server Repository Service, given the package-vs-object payload mismatch identified in §14.
5. Delete/tombstone semantics in full (§21).
6. Whether the Server Repository ever needs server-side graph traversal or filtering beyond simple lookup (§20).
7. The concrete idempotency mechanism's wire representation (§10).
8. Deployment topology (§23).
9. Foundation compatibility versioning, once publication/retrieval are actually built (§17, item 5).

## 27. Future ADRs

Carried forward from ADR-0004 §22 and WP-SRV-007 §23 where still unresolved, plus new items this ADR itself surfaced:

1. Whether/how Foundation ever gets a server-side existence (ADR-0001 Gap G8 — still unresolved by any ADR to date, including this one).
2. Synchronization design (still explicitly undefined).
3. Conflict-resolution algorithm/UX (detection only is defined, across ADR-0004 and this ADR).
4. Authorization and tenancy model (§16).
5. Concrete persistence schema design, if/when PostgreSQL (§12) is formally adopted for implementation.
6. Concrete wire protocol / API design (§7/§17/§18/§19 collectively).
7. Cross-repository relationships and cross-repository object membership (still ruled out by ADR-0004 §5; unchanged here).
8. Revision retention/pruning policy (ADR-0004 §7; unchanged here).
9. The concrete relationship between `.oep`/`.oerp` package installation and Server Repository content, including resolving the Exchange `RepositoryClient` payload mismatch this ADR identified (§14/§26 item 4).
10. Delete/tombstone semantics (§21).
11. **Implementation authorization** — a dedicated future work package, separate from any of the above, must explicitly authorize beginning Server Repository implementation. Neither this ADR nor ADR-0004 nor the WP-SRV-007 contract does so, and none of them may be read as implicitly doing so.
