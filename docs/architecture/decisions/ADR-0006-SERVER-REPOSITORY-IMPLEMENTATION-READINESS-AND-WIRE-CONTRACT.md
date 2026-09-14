# ADR-0006 — Server Repository Implementation Readiness & Wire Contract

## 1. Status

**Accepted, architecture-only. No implementation exists. This ADR authorizes a specific, bounded first implementation slice (§29) — it does not itself implement anything.**

## 2. Context

ADR-0004 defined Server Repository semantics (identity, membership, revisions, commits, concurrency, publication/retrieval). ADR-0005 defined its API/persistence boundary (HTTP/REST-JSON transport, PostgreSQL evaluated as appropriate, a minimum semantic operation set) without fixing concrete paths, schemas, or the remaining implementation-critical decisions it explicitly deferred (idempotency mechanics, delete semantics, authorization boundary, error/status mapping, versioning at the wire, payload limits). This ADR closes that remaining gap — the last architecture-only step before an implementation work package can be authorized.

## 3. Architectural Preconditions

Verified directly against the actual repository before writing a single decision below (not re-derived from summary):

- **EAM's real, established HTTP error/status convention** (`services/acquisition/src/api/server.cpp`, every `respond_error` call site enumerated directly): `400` for malformed request shape (bad JSON, bad query param), `401` for unauthorized, `404` for not-found, `409` for state/business-rule conflicts (`already_published`, `invalid_transition`, `job_not_executable`, etc. — conflicts with the *current state* of something that exists), `422` for semantic validation failures (`unknown_metadata`, `invalid_vault_path`, etc. — references/shapes that don't validate), `500` for unexpected internal/data-integrity failures, `503` for infrastructure unavailability (database down). This is real, existing, in-production OEP convention — this ADR's own HTTP status mapping (§14) is built directly on it, not invented independently.
- Foundation's `EngineeringObject`/`Relationship`/`RepositoryMetadata` identity fields, `ObjectStore::update`'s unconditional-overwrite behavior, and `oep_api_version()`'s existing integer-counter precedent — all re-confirmed present exactly as ADR-0004/ADR-0005 already documented them (unchanged since).
- Exchange's `RepositoryClient`/`RepositoryInstallRequest` payload shape (a `.oep` package artifact, not an Engineering Object/Relationship commit) — re-confirmed unchanged; the mismatch ADR-0005 §14 identified remains open and is not resolved by this ADR.
- No gRPC/protobuf, no new JSON library conventions beyond what EAM (`nlohmann::json`) and Exchange (Fastify's built-in JSON handling) already use — re-confirmed no new wire-format precedent has appeared since ADR-0005.

## 4. Implementation Authorization

**Evaluating the complete chain**, per Task 1:

- **WP-SRV-007** (contract): established the service exists conceptually, its boundary against Foundation/EAM/Exchange/Knowledge/`.oep`/`.oerp`, and named the open questions.
- **WP-SRV-008 / ADR-0004** (state semantics): resolved identity, membership, revision, commit, concurrency, publication/retrieval semantics.
- **WP-SRV-009 / ADR-0005** (API/persistence boundary): resolved the semantic operation set, transport (HTTP/REST-JSON), PostgreSQL's appropriateness, and named the remaining implementation-critical gaps.
- **WP-SRV-010 / this ADR**: resolves the wire contract, endpoint model, commit representation, idempotency mechanics, delete semantics, authorization boundary, error/status mapping, versioning-at-the-wire, payload limits, query semantics, and the first-implementation-slice scope.

**What would otherwise still require architectural invention during coding, and is now resolved by this document**: concrete endpoint paths and HTTP methods (§7), the commit request/response shape (§8), the idempotency key's format and lifecycle (§9), whether delete exists at all in the first slice (§10), what a request needs to be authorized (§11), the final error category list and HTTP status mapping (§13/§14), what "API version" means at the wire (§15), JSON content rules (§16), payload limits (§17), and the minimum list/query surface (§18).

**What remains genuinely open, and is explicitly not blocking**: the concrete persistence schema (§25 — intentionally deferred to whoever implements against PostgreSQL, since ADR-0005 already established the *capability* requirements, and schema design is ordinary implementation work, not an architectural unknown), the full authorization/tenancy model beyond the minimum boundary this ADR defines (§11), and every item ADR-0004/ADR-0005 already named as future work (synchronization, conflict-resolution UX, server-side Foundation, Exchange integration mechanics).

**Answer: YES.** Implementation of the first Server Repository vertical slice is **authorized** after this ADR is accepted, strictly subject to the scope defined in §29 and the constraints defined throughout this document. No broader implementation (delete/tombstone beyond the minimum §10 defines, full authorization/tenancy, synchronization, Exchange integration, server-side Foundation) is authorized by this ADR.

## 5. Service Boundary

Unchanged from ADR-0004/ADR-0005 — restated here only as the invariant this entire wire contract is bound by, not re-decided:

- Server Repository ≠ Foundation Repository, EAM Vault, Engineering Exchange, Knowledge Runtime, `.oep`, or `.oerp`.
- Foundation remains offline-first; a local Foundation Repository **MUST NOT** require the Reference Server to function.
- The Server Repository is a logical service under the OEP Reference Server (ADR-0001 §2); this ADR does not decide its deployment topology (unchanged from ADR-0005 §23 — still undecided, still not required to be decided now).

## 6. Wire Contract

Conceptual identity/representation rules — **illustrative JSON below is non-normative** (shown only to remove ambiguity about shape, not selected as a binding schema) unless a subsection explicitly says otherwise.

- **Resource identity**: every addressable thing (a repository, an object, a relationship) is identified by its canonical UUID — `repository_id`, `object_id`, `relationship_id` — reusing the exact UUIDv4 representation already validated throughout Foundation (`validate_object`, `validate_relationship`, `validate_metadata`). No new identity format is introduced.
- **Request identity**: **UNDECIDED** as a general concept beyond operation identity (§9) — this ADR does not require every request to carry an identity, only mutating commits (§8/§9).
- **Repository identity**: `repository_id` (UUIDv4), immutable, per ADR-0004 §4 — unchanged.
- **Object identity**: `object_id` (UUIDv4), immutable, per ADR-0004 §6/this ADR §20.
- **Relationship identity**: `relationship_id` (UUIDv4), immutable, per ADR-0004 §7.
- **Revision identity**: a revision **MUST** be addressable by the pairing of (the object/relationship's own UUID) + (a revision marker). The revision marker's concrete representation is **UNDECIDED** at the architecture level — a monotonically increasing per-item integer and an opaque server-assigned token are both compliant candidates; this ADR requires only that the marker be stable, comparable for ordering, and never reused once assigned. (Illustrative, non-normative: `{"object_id": "...", "revision": 3}`.)
- **Expected revision**: the same revision-identity shape as above, supplied by the caller on a mutation to state "I am editing based on this revision" (ADR-0004 §10). For a create (no prior revision exists), the expected-revision value's semantic meaning is "must not already exist" (ADR-0005 §8) — this **MAY** be represented as an explicit sentinel (e.g. a `null`/absent expected revision) rather than a real revision marker; the exact representation is **UNDECIDED**, the semantic requirement is not.
- **Commit identity**: a server-assigned identity for a specific, successfully-applied commit, distinct from the client-supplied operation identity (§9) that made retrying that commit attempt safe. **UNDECIDED** representation (opaque string vs. UUID vs. integer) — **SHOULD** be a UUIDv4 for consistency with every other identity in this system, absent evidence otherwise.
- **Operation identity**: the client-generated idempotency key (§9) — **MUST** be a UUID (format decided in §9), distinct from commit identity.
- **Success result**: **MUST** convey at minimum the resulting revision(s) for every object/relationship the operation affected, plus the commit identity (§19). Concrete field names are **UNDECIDED**.
- **Failure result**: **MUST** convey a stable, machine-readable error category (§13), a human-readable message, and, where applicable (validation/concurrency failures), which specific mutation(s) within the commit failed and why. **MUST NOT** convey filesystem paths, credentials, database connection details, or raw internal exception text (directly reusing the already-established, already-fixed EAM precedent from WP-SRV-005's own path-leak correction — this is not a new requirement, it is this system's own established practice, restated as binding here).

## 7. Endpoint Model

Per Task 3's own instruction, this defines the **minimum concrete resource model** — method, path, meaning, auth requirement — without creating routes in code. Path segments below use `{param}` placeholders; they are the actual decided paths for this ADR's authorized scope (§29), not illustrative.

| Operation | Method | Path | Meaning | Auth | Status classes |
|---|---|---|---|---|---|
| Create repository | `POST` | `/repositories` | Create a new Server Repository. | Authenticated + repository-creation-authorized (§11) | `201`, `400`, `401`, `403` |
| Retrieve repository | `GET` | `/repositories/{repository_id}` | Fetch a repository's metadata. | Authenticated + repository-read-authorized | `200`, `401`, `403`, `404` |
| Enumerate repositories | `GET` | `/repositories` | List repositories the caller may access. | Authenticated | `200`, `401` |
| Retrieve current object | `GET` | `/repositories/{repository_id}/objects/{object_id}` | Fetch an object's latest revision. | Authenticated + repository-read-authorized | `200`, `401`, `403`, `404` |
| Retrieve historical object revision | `GET` | `/repositories/{repository_id}/objects/{object_id}/revisions/{revision}` | Fetch a specific past revision (§22). | Authenticated + repository-read-authorized | `200`, `401`, `403`, `404` |
| List objects | `GET` | `/repositories/{repository_id}/objects` | Enumerate objects in a repository (§18). | Authenticated + repository-read-authorized | `200`, `401`, `403` |
| Retrieve current relationship | `GET` | `/repositories/{repository_id}/relationships/{relationship_id}` | Fetch a relationship's latest revision. | Authenticated + repository-read-authorized | `200`, `401`, `403`, `404` |
| Retrieve historical relationship revision | `GET` | `/repositories/{repository_id}/relationships/{relationship_id}/revisions/{revision}` | Fetch a specific past revision. | Authenticated + repository-read-authorized | `200`, `401`, `403`, `404` |
| List relationships | `GET` | `/repositories/{repository_id}/relationships` | Enumerate relationships in a repository, optionally filtered by object (§18). | Authenticated + repository-read-authorized | `200`, `401`, `403` |
| Submit atomic commit | `POST` | `/repositories/{repository_id}/commits` | Submit a multi-mutation atomic commit (§8) — the **only** mutation path (§8's own requirement). | Authenticated + repository-mutation-authorized | `201`, `400`, `401`, `403`, `404`, `409`, `422` |
| Retrieve commit result | `GET` | `/repositories/{repository_id}/commits/{commit_id}` | Fetch the recorded outcome of a specific commit (§19). | Authenticated + repository-read-authorized | `200`, `401`, `403`, `404` |

**No route for direct object/relationship mutation exists** — object/relationship creation, update, and (if authorized, §10) deletion are all expressed as mutations inside a commit (§8/§4 of ADR-0005's own requirement is reaffirmed and now made concrete). This is a deliberate, binding design choice, not an oversight: exposing a separate `PUT /objects/{id}` would let a caller bypass the atomicity/concurrency guarantees the commit endpoint exists specifically to enforce.

**No endpoint is invented beyond what the architecture actually requires** — search, graph traversal, and administrative operations are explicitly not given endpoints here (§18/§11).

## 8. Commit Contract

A commit **MUST** be able to carry, per Task 4:

- Multiple mutations, of both kinds (object and relationship) in the same commit.
- Each mutation is one of: **create** (no expected revision — or an explicit "must not exist" sentinel, §6), **update** (carries the expected revision being edited), or **delete**, **only if §10 authorizes deletion for the first implementation slice** (it does, in a restricted form — see §10).
- Each mutation carries a client operation identity **at the commit level**, not per-mutation (ADR-0005 §10's own decision, reaffirmed) — one operation identity covers the whole commit as a single retryable unit.

**The commit endpoint IS the primary — and only — mutation endpoint.** No separate `create-object`/`update-object`/`delete-object` endpoints are authorized by this ADR, exactly as stated in §7. A single-mutation change is simply a commit containing one mutation — there is no separate "simple" path that would let a caller bypass atomicity semantics for what looks like a trivial edit.

Illustrative, non-normative shape (to remove ambiguity, not to fix field names):

```
POST /repositories/{repository_id}/commits
{
  "operation_id": "<client-generated UUID>",
  "mutations": [
    { "kind": "object_create", "object": { ... } },
    { "kind": "object_update", "object_id": "...", "expected_revision": 3, "object": { ... } },
    { "kind": "relationship_create", "relationship": { ... } },
    { "kind": "object_delete", "object_id": "...", "expected_revision": 5 }
  ]
}
```

This illustration is not the wire schema; it exists only to make §6-§9's semantic requirements unambiguous.

## 9. Idempotency

Resolving ADR-0005 §10's deferred mechanics, per Task 5:

- **Operation identity format**: **MUST** be a UUIDv4, reusing the exact identity format already established throughout this system (repositories, objects, relationships) rather than inventing a second identity type, per Task 5's own explicit instruction to prefer reuse over invention.
- **Uniqueness scope is not one single namespace — it MUST be split by operation kind, because the two kinds of operation this ADR defines do not share a target at the time the operation is first received**:
  - **Repository-creation operation identities are SERVER-SCOPED.** `POST /repositories` (§7/§21) is the operation that *creates* `repository_id` — there is no repository namespace yet for the identity to be scoped into at the moment the server first receives the request. The server **MUST** therefore check a repository-creation operation identity for prior use against a single, server-wide namespace of repository-creation attempts, not against any one repository's own records.
  - **Commit operation identities remain REPOSITORY-SCOPED**, unchanged from the original decision below: a commit always targets an already-existing `repository_id` (it is submitted to `POST /repositories/{repository_id}/commits`, §7/§8), so scoping its idempotency check to that one repository is both correct and, as originally reasoned, keeps the lookup cheap.
  - These are **two distinct namespaces**, not one identity space split by convention — a server-scoped repository-creation operation identity and a repository-scoped commit operation identity are never compared against each other, even if (by coincidence) the same UUID value were ever reused across the two kinds of operation. This ADR does **not** introduce a distributed or global identity service to support the server-scoped namespace — "server-scoped" here means "checked against this one server process's/deployment's own record of repository-creation attempts," the same kind of scope the server already has authority over for everything else in this contract, not a new cross-server coordination mechanism.
  - Original reasoning for the repository-scoped commit case, unchanged: a UUIDv4's own collision probability already makes even-broader uniqueness a practical non-issue, and scoping the check to one repository keeps the implementation's lookup cheap.

  **Required repository-creation retry behavior, made explicit:**
  1. Client sends a repository-creation request carrying operation identity `X`.
  2. Server successfully creates repository `R`.
  3. Client loses the response (any of the failure shapes in §24).
  4. Client retries repository creation with the same operation identity `X`.
  5. Server recognizes `X` in the **server-scoped** repository-creation namespace.
  6. Server returns the original repository-creation result (including `R`'s `repository_id`) as a no-op success, per the same retry rule §9 already establishes for commits.
  7. Server **MUST NOT** create a second repository `R2`.

  If a repository-creation operation identity is reused with materially different request content (e.g. a different `repository_name`), the server **MUST** return `IDEMPOTENCY_CONFLICT` (§13), exactly as an equivalent reuse-with-different-content already does for commits.
- **Lifetime requirement**: the server **MUST** retain enough record of a given operation identity's outcome to answer "was this already applied, and if so, with what result" for at least as long as a reasonable client retry window. This ADR does not fix an exact retention duration (**UNDECIDED** — an implementation detail, not an architectural one) but **MUST NOT** be shorter than a small number of minutes (long enough to cover realistic network-partition/timeout retry behavior) and **SHOULD** be retained indefinitely alongside the commit/audit history it corresponds to (§23), since that history is already required to be retained.
- **May the same operation identity be retried?** Yes — that is the entire purpose of this mechanism. A retry with the **identical** mutation set **MUST** be treated as a no-op success, returning the original result (§19), not reapplied.
- **What happens if the same operation identity is reused with genuinely different content?** This **MUST** be rejected — a new `IDEMPOTENCY_CONFLICT` category (§13) distinct from `VALIDATION_FAILED`/`CONCURRENCY_CONFLICT`, since it represents neither a bad request nor a stale read, but a client-side identity-reuse error. The server **MUST NOT** silently apply the "second" version of a reused identity.
- **Does an already-completed operation return its original result?** Yes, per the retry rule above — this is the exact mechanism that satisfies the failure case named in both ADR-0005 §10 and Task 5/20 of this WP (accept → response lost → client retries → must not double-apply).
- **Do failed operations consume the identity?** **No.** If a commit is rejected (validation failure, concurrency conflict, or a server-side error before commit), its operation identity **MUST NOT** be considered "used" — a client that fixes the underlying problem (re-reads the current revision, corrects a validation error) **MUST** be able to retry with the *same* operation identity and have it treated as a fresh attempt, not blocked as a duplicate of a failed one. Idempotency protects against duplicate *application* of a *successful* commit; it does not lock a client out of retrying after a legitimate failure.

## 10. Delete/Tombstone

Resolving ADR-0005 §21's deferral, per Task 6, choosing the smallest safe model per that task's own instruction:

- **Engineering Objects MAY be deleted**, but deletion **MUST NOT** be a hard delete. Deletion **MUST** be represented as a tombstone: a new revision of the object marking it deleted, not the removal of the object or any of its prior revisions from history.
- **Relationships MAY be deleted**, under the identical tombstone model.
- **Deletion MUST create a revision**, exactly like any other mutation (ADR-0004 §7) — a delete is a specific kind of mutation, not a different, non-revisioned operation.
- **Deleted state MUST remain historically retrievable** — every revision prior to (and including) the tombstone revision remains fetchable via historical revision retrieval (§22), unchanged by the deletion.
- **A deleted object/relationship MAY be restored**, by a subsequent create-shaped mutation that establishes a new, non-tombstoned revision — this is not "undelete" as a distinct operation, it is simply a new revision superseding the tombstone one, consistent with the revision model already established (ADR-0004 §7 disallows branching/merging, not further mutation after a tombstone).
- **When an object is deleted, its relationships are NOT automatically cascade-deleted by this ADR.** Instead: a commit that would delete an object while relationships still reference it as source or target **MUST** be rejected as a validation failure (`VALIDATION_FAILED`/`INVALID_RELATIONSHIP`, §13), **unless** the same commit also deletes (tombstones) those relationships atomically alongside the object — which the commit model already supports (§8). This is the smallest safe rule available: it never silently orphans a relationship pointing at a tombstoned object, and it never silently deletes a relationship the caller didn't explicitly ask to delete.
- **Hard deletion is NOT permitted by this ADR** in the first implementation slice. Whether an administrative, audited, exceptional hard-delete capability (e.g. for legal/compliance reasons) is ever needed is **UNDECIDED** and explicitly out of scope (§30) — the ordinary operational model is tombstone-only.

## 11. Authorization

Resolving the minimum boundary Task 7 requires — **not** a complete IAM system:

- **Repository read authorization**: a caller **MUST** be authorized to read a specific repository before any `GET` against it (metadata, objects, relationships, revisions, commit results) succeeds. Unauthorized read attempts **MUST** return the same outcome as "does not exist" (§13's `NOT_FOUND`, not a distinct `AUTHORIZATION_DENIED`) **for repository-level access specifically** — this prevents repository-ID probing (§24) from distinguishing "exists but you can't see it" from "doesn't exist," a stronger default than leaking existence.
- **Repository mutation authorization**: a caller **MUST** be authorized to mutate a specific repository before any commit against it is accepted. Unlike read, a mutation-authorization failure on an otherwise-visible (readable) repository **MAY** return a distinct `AUTHORIZATION_DENIED` (`403`) rather than `NOT_FOUND`, since the caller already legitimately knows the repository exists (they could read it) — there is no probing risk left to protect against at this point.
- **Repository creation authorization**: **UNDECIDED beyond "MUST be authenticated"** for the first implementation slice — this ADR does not define a fine-grained "who may create repositories" policy, since no existing architecture establishes one. **Temporary, explicit policy for the first implementation slice** (per Task 7's own instruction to define an explicit, safe interim policy rather than leave implementers guessing): **any authenticated caller MAY create a repository.** This is deliberately permissive and explicitly temporary — safe only because the Server Repository Service, in its first-slice deployment (§29), sits behind the same single-shared-token boundary EAM already uses (ADR-0002), which today has exactly one holder of legitimate access (the platform's own operator/developer). This policy **MUST** be revisited before any multi-tenant or externally-facing deployment.
- **Historical revision access**: governed by the same repository-read-authorization rule as current-state access — there is no separate "history" permission tier in this first slice. **UNDECIDED** whether one is ever needed (e.g. an object-level access-control tier finer than repository-level, ADR-0004 §14's own already-named future possibility).
- **Publication authorization**: publication (ADR-0004 §11) is, per ADR-0005 §6, simply a commit — it is governed by ordinary repository-mutation authorization, with no separate "publication-specific" gate. Whether a distinct publication-authority concept (ADR-0004 §6's own named, undesigned concept) is ever needed beyond ordinary mutation authorization is **UNDECIDED**, future.
- **Administrative operations**: none are defined by this ADR's first-slice scope (§29) — there is no delete-a-whole-repository, no administrative override, no cross-tenant visibility operation in this slice. **UNDECIDED**, future, if ever needed.
- **Explicitly not designed**: users, roles, ACL tables, identity providers, or tenancy — none of these exist in this ADR's authorization model. The above is the entire authorization boundary for the first implementation slice, deliberately minimal, deliberately temporary where noted.

## 12. Authentication

Reconciling ADR-0002 with this API, per Task 8 — **ADR-0002 is not modified**:

- **Every request except a health check requires authentication** — reusing ADR-0002's existing bearer-token pre-routing mechanism exactly as EAM already does, and exactly as ADR-0002 §3 already anticipated ("designed so future Knowledge and Exchange APIs can use the same server boundary").
- **Health remains unauthenticated**, mirroring EAM's own `GET /health` precedent (ADR-0002 §7) — a Server Repository Service, if deployed as its own process, **SHOULD** expose an equivalent unauthenticated `GET /health` for the same process-supervision/infrastructure-monitoring reasons ADR-0002 already established; if deployed as a module of an existing process (deployment topology remains undecided, ADR-0005 §23), it **MAY** share that process's existing `/health` route instead of duplicating one.
- **Repository enumeration requires authentication** — unlike EAM's `/health`, listing repositories reveals real engineering-state metadata and **MUST NOT** be reachable without a valid token.
- **All repository mutations require authentication** — no exception; this is the same boundary every EAM mutation route already enforces.
- **Historical access requires authentication** — no distinct rule from current-state access (§11).
- **No modification to ADR-0002 is necessary or made.** This Server Repository API is a new *consumer* of the exact same, unmodified authentication mechanism ADR-0002 already defines — precisely the reuse ADR-0002 §3 already anticipated.

## 13. Error Contract

Final minimum set, evaluated against every category Task 9 named:

| Category | Meaning | Retry appropriate? | State changed? | Client-correctable? |
|---|---|---|---|---|
| `AUTHENTICATION_REQUIRED` | No/invalid bearer token. | Yes, with a valid token. | No. | Yes (supply credentials). |
| `AUTHORIZATION_DENIED` | Authenticated, but not permitted to mutate this repository (§11). | No, not without different credentials/permission. | No. | Not by the client alone. |
| `NOT_FOUND` | Repository/object/relationship/revision/commit does not exist, or the caller cannot see it (§11's probing-resistance rule). | No. | No. | Depends (may be a typo, may be a real access gap). |
| `VALIDATION_FAILED` | A mutation is structurally/semantically invalid (includes what Task 9 separately named `INVALID_RELATIONSHIP` and `DUPLICATE_IDENTITY` — both subsumed here, per ADR-0005 §19's own already-made decision, reaffirmed rather than re-litigated). | No, not without fixing the request. | No — the whole commit is rejected (§8). | Yes. |
| `CONCURRENCY_CONFLICT` | One or more mutations' expected revision is stale. | Yes, after re-reading current state. | No. | Yes (reconcile and retry). |
| `IDEMPOTENCY_CONFLICT` | The operation identity was already used with different content (§9). | No, not with the same operation identity. | No. | Yes (use a new operation identity, or verify which attempt was intended). |
| `COMMIT_REJECTED` | The outer envelope for a rejected commit, carrying one of the two reasons above as its specific cause (ADR-0005 §19's own decision, reaffirmed) — not an independent fourth reason. | Depends on inner cause. | No. | Depends on inner cause. |
| `UNSUPPORTED_OPERATION` | A syntactically valid request for a capability this ADR's first slice does not implement (e.g. hard delete, §10). | No. | No. | Yes (don't request it). |
| `INTERNAL_FAILURE` | Unexpected server-side error. | Maybe, generically. | Unknown — treated as "assume no successful commit occurred" unless a subsequent `GET` on the commit result (§19) proves otherwise via the idempotency mechanism (§9/§20). | No. |

**`REPOSITORY_NOT_FOUND` is explicitly not adopted as separate from `NOT_FOUND`** (ADR-0005 §19's decision, reaffirmed) — a repository is one of the resource kinds `NOT_FOUND` already covers.

**Leakage rule, restated as binding**: no category's message **MUST** ever contain a filesystem path, database connection detail, credential, or raw internal stack trace — directly extending WP-SRV-005's own already-fixed, already-verified EAM precedent to this new API.

## 14. HTTP Status Mapping

Built directly on EAM's own real, established convention (§3), not invented independently:

| Status | Used for |
|---|---|
| `200` | Successful `GET`. |
| `201` | Successful repository creation; successful commit (a commit is conceptually "creating" a new set of revisions). |
| `204` | **Not used** in this first slice — no operation in §7's endpoint model has an empty-body-success shape; reserved for a future operation if one is added (e.g. a future hard-delete-with-no-body-response, itself out of scope, §10). |
| `400` | Malformed request body (unparseable JSON) — mirroring EAM's own `invalid_json` precedent exactly. |
| `401` | `AUTHENTICATION_REQUIRED`. |
| `403` | `AUTHORIZATION_DENIED`. |
| `404` | `NOT_FOUND`. |
| `409` | `CONCURRENCY_CONFLICT`, `IDEMPOTENCY_CONFLICT` — both are "conflicts with current state," mirroring EAM's own `409` usage for `already_published`/`invalid_transition`-shaped conflicts exactly. |
| `422` | `VALIDATION_FAILED` (including the subsumed relationship-integrity/duplicate-identity cases) — mirroring EAM's own `422` usage for `unknown_metadata`/`invalid_vault_path`-shaped semantic-validation failures exactly. |
| `500` | `INTERNAL_FAILURE`. |
| `503` | Infrastructure unavailable (e.g. the persistence layer is unreachable) — mirroring EAM's own `service_unavailable` precedent exactly; **not** a category in §13's table because, like EAM's own equivalent, it represents the *absence* of a meaningful application-level outcome, not an application-level error. |

`UNSUPPORTED_OPERATION` maps to `400` (a malformed-for-this-server request, in the same family as a syntactically invalid one) rather than `422` (which is reserved for engineering-content validation specifically) or `404` (the endpoint exists, the capability within it does not).

**401 vs. 403 vs. 404 vs. 409 vs. 422 are explicitly distinguished**, per Task 10's own explicit requirement, exactly as the table above shows — no category is conflated with another.

## 15. Versioning

Resolving ADR-0005 §17's five-domain list at the wire level, per Task 11:

- **API version**: **MUST** appear at the wire boundary. Concrete mechanism: **UNDECIDED between** a URI prefix (Exchange's own real precedent, `/api/v1/...`) and a response header/field (mirroring Exchange's own `EXCHANGE_API_VERSION`-in-health-response precedent) — this ADR does not resolve the EAM-vs-Exchange convention mismatch ADR-0005 §17 already flagged, and explicitly declines to invent a third convention; the implementing work package **MUST** pick one of these two existing, real precedents rather than a novel scheme.
- **Wire schema version**: for the first implementation slice, **implicitly version 1** of this ADR's own contract (§6-§9) — not separately tracked as its own number distinct from the API version above, since no evidence yet demonstrates they need to diverge independently.
- **Repository compatibility version**: **NOT** exposed at the wire boundary in the first slice — no evidence gathered demonstrates a near-term need for a repository to declare its own compatibility version independent of the API version serving it. **UNDECIDED**, future.
- **Engineering Object type/schema version**: `EngineeringObject.version` (the existing, real, free-text field) is carried through the wire contract as an ordinary object field (part of the object's own content, per §6's identity rules) — **not** a wire-protocol-level version, exactly as ADR-0005 §17 item 3 already distinguished it from API/persistence versioning. Unchanged, not re-decided here.
- **Foundation version**: **NOT** exposed at the wire boundary. Foundation compatibility (ADR-0005 §17 item 5) only becomes relevant once a specific client-side publication/retrieval implementation exists (still future, ADR-0004 §13) — nothing in this ADR's server-side wire contract needs to know what Foundation version a caller is running.
- **Persistence schema version**: **NOT** exposed at the wire boundary — purely an implementation-internal concern (ADR-0005 §17 item 4, unchanged), tracked however the eventual persistence technology conventionally tracks it (e.g. Flyway version numbers, if PostgreSQL per ADR-0005 §12).

**Decided**: API version must be visible at the wire boundary, by one of the two named existing mechanisms. **Deferred**: which of the two, and the wire schema/repository-compatibility/Foundation-version questions beyond what's stated above.

## 16. JSON/Content Contract

- **Media type**: `application/json`, exactly matching both EAM's and Exchange's existing, real convention — no new content type is introduced.
- **Character encoding**: UTF-8, matching JSON's own standard default and both existing services' actual behavior.
- **Required/optional fields**: every mutation **MUST** supply the fields ADR-0004's Engineering Object/Relationship model already requires as non-optional (`object_id` for updates/deletes, `object_type`, `name`, etc., per `OEP-SPEC-004`/`005`, unmodified) — this ADR does not relax or add to those existing field-level requirements, only confirms the wire contract carries them unchanged.
- **Unknown-field behavior**: the server **SHOULD** ignore unknown fields in a request body rather than reject the whole request — this is the conventional, forward-compatible choice (supporting §17's own additive-evolution principle from ADR-0005) and matches how most JSON APIs, including this platform's own, already behave by default (neither EAM's `nlohmann::json` usage nor Exchange's Fastify schema validation is strict-reject-unknown-fields by default, confirmed by inspection of their existing route handlers).
- **Null behavior**: an explicit `null` for an optional field **MUST** be treated as "not set" — the wire contract does not distinguish "absent" from "explicitly null" unless a future, specific field requires that distinction (none is identified in this ADR's scope).
- **Timestamp representation**: ISO 8601 UTC strings, matching the format already used throughout Foundation (`created_utc`, `last_modified_utc`, etc.) and every EAM timestamp field observed across this platform's existing APIs — no new timestamp convention is introduced.
- **UUID representation**: canonical, lowercase, hyphenated UUID string form (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`), matching Foundation's own existing `object_id`/`relationship_id`/`repository_id` string representation exactly — no binary/compact UUID encoding is introduced.
- **Binary content behavior**: **explicitly not introduced.** Per Task 12's own instruction, the Server Repository API's focus is Engineering Object/Relationship *state*, not artifact bytes — binary artifact transfer remains EAM Vault's domain (`GET /vault/{id}/artifact`, unchanged, ADR-0004 §9's own boundary reaffirmed). No object/relationship field in this contract carries raw binary content; `EngineeringObject.content` (the existing, opaque, application-owned field) is a string, not a binary payload, and this ADR does not change that.

## 17. Payload Limits

Per Task 13's own instruction to avoid arbitrary numbers without operational evidence, and to prefer configurable bounds over fixed magic numbers where no evidence justifies a specific figure:

- **Commit mutation count**: a bound **MUST** exist (an unbounded commit is a resource-exhaustion/denial-of-service risk, §24), but the specific number is **UNDECIDED** and **SHOULD** be configurable rather than hard-coded — no operational evidence in this repository establishes a "correct" number today.
- **Object size**: a bound **MUST** exist for the same reason, **SHOULD** be configurable, exact figure **UNDECIDED**.
- **Relationship count** (per commit, and per object as a whole): **SHOULD** be bounded per the same reasoning; exact figures **UNDECIDED**.
- **Request body size**: a bound **MUST** exist at the transport/framework level (both cpp-httplib and Fastify already support this natively, without inventing new mechanism) — **SHOULD** be configurable, exact figure **UNDECIDED**.
- **Historical retrieval size**: bounded implicitly by pagination (§18) once that exists — no separate limit mechanism is needed beyond page size.

**This ADR defines the requirement (bounds must exist, MUST be configurable where no evidence justifies a fixed number) without selecting the numbers themselves** — consistent with Task 13's own explicit preference.

## 18. Query/List Semantics

Per Task 14, evaluated against the smallest set that satisfies §7's endpoint model:

- **List repositories, list objects, list relationships**: all three **are required** for the first implementation slice (§7 already includes them) — simple enumeration, not search.
- **Pagination**: **SHOULD** exist for object/relationship listing (a repository could plausibly contain more items than fit comfortably in one response) — semantics: a caller supplies an optional page-size/cursor and receives a bounded page plus a way to request the next one. **UNDECIDED**: cursor-based vs. offset-based, exact default/maximum page size — implementation detail, not an architectural unknown.
- **Filtering**: **MAY** exist for the first slice (e.g. filtering objects by `ObjectType`, filtering relationships by endpoint object) but is not required — **SHOULD** be considered a natural, low-risk additive enhancement (§17 of ADR-0005's own evolution principles) rather than something the first slice must ship with.
- **Sorting**: **UNDECIDED**, not required for the first slice — simple enumeration order (e.g. creation order) is sufficient absent evidence of a real requirement.
- **Graph traversal**: **explicitly not required or authorized for the first slice** — reaffirming ADR-0005 §20's own deferral. Foundation's own local `GraphEngine` capability is not reimplemented server-side by this ADR.
- **Text search**: **explicitly not required or authorized** — reaffirming ADR-0005 §20's own hard boundary: **the Server Repository Service MUST NOT import or reimplement Knowledge Engine search semantics.**

## 19. Relationship Integrity

Per Task 15, server-side validation rules, binding on the commit-processing implementation:

- **Source object MUST exist** (as a non-tombstoned current object, or be created in the same commit — see below) for a relationship mutation to be accepted.
- **Target object MUST exist** under the identical rule.
- **Both endpoints MUST belong to the same Server Repository** as the relationship itself — reaffirming ADR-0004 §7/§5's cross-repository prohibition, made concrete here as a commit-time validation rule.
- **Relationship identity MUST be unique** within its repository — a create mutation whose `relationship_id` already exists **MUST** fail validation (subsumed under `VALIDATION_FAILED`, §13, not a separate `DUPLICATE_IDENTITY` category, per §13's own consolidation).
- **Relationship type MUST be a valid, known `RelationshipType`** value (the existing, unmodified enum).
- **Expected revisions MUST be respected** for relationship updates/deletes, under the identical optimistic-concurrency rule as objects (§9 of ADR-0004, unchanged).
- **Commit atomicity MUST be preserved**: if a commit creates an object and a relationship referencing it together (explicitly permitted, §8), the relationship's endpoint-existence check **MUST** be evaluated against the commit's own *resulting* state (i.e. "does this object exist after this commit's own creates are applied"), not only against state that existed *before* the commit began — otherwise the exact "create an object and connect it in one atomic step" use case ADR-0004 §8 requires would be impossible to satisfy.

## 20. Object Identity

Confirming, per Task 16, exactly what ADR-0004 §6 already decided, with the remaining implementation-facing specifics resolved:

- **Client-generated identity, for the first implementation slice.** A create mutation **MUST** supply its own `object_id`/`relationship_id` (client-generated UUIDv4) rather than expect the server to mint one. Rationale: this is the only choice compatible with ADR-0004 §11's publication requirement ("the server MUST NOT mint new engineering identities for published content" — a local object being published already has an `object_id`, assigned locally by Foundation at creation time; the server accepting client-supplied identity is what makes publication identity-preserving at all, not a special case of it).
- **UUID preservation during publication**: direct consequence of the above — a published object's `object_id` at the server is bit-for-bit identical to its local `object_id`, with no translation step.
- **Duplicate identity behavior**: a create mutation whose `object_id` already exists in the target repository **MUST** fail as `VALIDATION_FAILED` (§13) — not silently treated as an update, and not silently accepted as a second, shadow object under the same id (which would violate identity's own uniqueness guarantee).
- **Identity immutability**: unchanged from `OEP-SPEC-004`/ADR-0004 — `object_id` never changes once assigned, for the object's entire lifetime including through tombstoning (§10).
- **Identity collision behavior**: a client-generated UUIDv4 collision is treated identically to "duplicate identity" above — this ADR does not special-case the (statistically negligible) accidental-collision scenario differently from a deliberate duplicate-id request; both produce the same `VALIDATION_FAILED` outcome, and it is the client's responsibility to generate a properly random UUIDv4.
- **No second object identity system is created.** The Server Repository consumes exactly the identity scheme Foundation already has, per ADR-0004 §6's own binding requirement, reaffirmed here at the wire-contract level.

## 21. Repository Creation

Per Task 17:

- **Who may create**: per §11's temporary policy, any authenticated caller, for the first implementation slice.
- **`repository_id` is server-generated**, not client-supplied — unlike Engineering Object/Relationship identity (§20), a repository is not something a local Foundation instance already has an existing identity for prior to server-side creation (there is no local "Server Repository" analog Foundation assigns identity to ahead of time), so there is no publication-style identity-preservation requirement pulling this decision the other way. The server minting `repository_id` on creation is both simpler and has no countervailing requirement against it.
- **Metadata requirements at creation**: at minimum a `repository_name` (mirroring the existing, real `RepositoryMetadata.repository_name` requirement) — other fields (`description`, `author`, `organization`, `tags`) **MAY** be supplied and **SHOULD** default sensibly (empty/absent) if not, mirroring `RepositoryMetadata`'s own existing optionality where it already treats fields as optional.
- **Initial revision/state**: a newly created repository **MUST** start with zero objects and zero relationships — there is no "seed content" concept in repository creation.
- **Initial audit event**: repository creation **MUST** produce an audit record (§23, mirroring the existing local precedent — Foundation's own `AuditEventType::RepositoryCreated`, real today, directly reused as the conceptual model for this server-side equivalent).
- **Idempotency**: repository creation **MUST** support the same client-generated-operation-identity *mechanism* as commits (§9) — creating a repository is itself an operation that could be lost-response-then-retried, and the identical retry-safety requirement applies — **but not the same uniqueness *scope***. Per §9's server-scoped/repository-scoped split: a repository-creation operation identity **MUST** be checked against the server-wide repository-creation namespace, not against any individual `repository_id` (none exists yet at the moment the identity is first received). This is the correction that makes repository creation itself retry-safe; see §9 for the full rule and the required retry-behavior sequence.
- **Empty repositories are valid** and remain valid indefinitely — there is no requirement that a repository ever contain any objects/relationships to be considered legitimate.

## 22. Historical Revision Retrieval

Per Task 18:

- **Revision addressing**: by (object/relationship UUID, revision marker) pairing, per §6.
- **Deleted (tombstoned) state IS retrievable** — a tombstone is itself a revision (§10), and every revision, tombstoned or not, remains retrievable per ADR-0004 §7's own "an old revision must be retrievable" requirement.
- **Revision metadata is returned** alongside content — at minimum, when the revision was created and (via the audit association, §23) who/what commit produced it. Exact field shape is **UNDECIDED** (wire-schema detail).
- **Historical revision retrieval MUST NOT affect current state** — a `GET` is read-only by definition; this ADR does not permit any implicit side effect (e.g. "viewing" an old revision does not roll back or otherwise mutate the object).
- **Revision history is immutable**, restating ADR-0004 §7 as binding at the wire-contract level too — no operation in this ADR's endpoint model (§7) permits editing or deleting a specific past revision independent of creating a new one.

## 23. Commit Result

Per Task 19, a successful commit **MUST** return, at minimum:

- **Commit identity** (§6).
- **Operation identity** (echoed back, confirming which client-supplied idempotency key this result corresponds to).
- **Affected object revisions**: for every object the commit mutated, its resulting new revision marker.
- **Affected relationship revisions**: the same, for relationships.
- **Audit identity**: a reference to the corresponding audit record (§23/audit boundary — this section and §27 use "audit identity" for the same concept).
- **Server timestamp**: when the commit was applied.

No JSON DTO/field-naming is created here — this is the semantic content requirement only, per Task 19's own explicit instruction.

## 24. Retry/Network Failure

Per Task 20, explicit recovery paths for every named failure case — this is where §9's idempotency mechanism connects directly to the wire contract:

- **(A) Timeout before server processing** (the request never reached the server, or the server never began work): safe to retry with the same operation identity — nothing was applied, the retry is indistinguishable from a first attempt.
- **(B) Timeout during processing** (the server is actively evaluating the commit when the client gives up waiting): safe to retry with the same operation identity once the client's timeout elapses — if the original attempt eventually completes (success or failure), the retry's outcome is governed by §9's rules (no-op success if it succeeded, a fresh attempt if it failed) regardless of the client having already moved on.
- **(C) Timeout after server acceptance** (the server committed successfully but the response hadn't been sent/received yet when the client's timeout fired): safe to retry with the same operation identity — this is precisely the case §9's no-op-success rule exists for; the retry returns the original, already-applied result rather than reapplying it.
- **(D) Connection loss after server acceptance** (identical in effect to C, different cause): identical recovery path to C.
- **(E) Server returns `5xx` after uncertain processing** (the client cannot tell from a `5xx` alone whether the commit was actually applied before the failure): the client **SHOULD** retry with the same operation identity. If the commit had in fact already succeeded server-side despite the `5xx`, the retry resolves to §9's no-op-success path; if it had not, the retry proceeds as a fresh attempt. **The architecture MUST guarantee this is always safe** — which is exactly why §9 requires idempotency at the commit level rather than leaving `5xx` recovery ambiguous.

**In every case (A-E), retrying with the same operation identity is the single, deterministic, always-safe recovery action** — a client never needs case-by-case logic to decide whether retrying is safe; §9's contract guarantees it always is, for any of these five failure shapes.

## 25. Persistence Boundary

Per Task 21, confirming ADR-0005 §12's PostgreSQL evaluation at the implementation-preparation level:

- **PostgreSQL remains accepted** (ADR-0005 §12, unchanged, not re-litigated here).
- **The Server Repository MUST use a separate database from EAM's** — not merely a separate schema within the same database, a fully separate database, mirroring the exact pattern WP-SRV-005 already established for EAM's own test/production database separation (`oep_acquisition` vs. `oep_acquisition_test`, both distinct databases under the same role). Rationale: EAM and the Server Repository are architecturally distinct services (ADR-0001 §2) with no shared data model — collapsing them into one database's schema namespace would blur a boundary this entire architecture chain (WP-SRV-007 through this ADR) has deliberately kept sharp.
- **Schema ownership MUST be separate** — direct consequence of separate databases.
- **EAM and Server Repository MAY share a single PostgreSQL *installation*** (the same running `postgresql` service/cluster on the same host) **while using separate databases within it** — this is exactly the pattern WP-SRV-005 already operates today (one PostgreSQL 18 instance on the Reference Server VM, multiple databases). Sharing the installation is an operational convenience that does not compromise the logical separation above.
- **Credentials/roles MUST be isolated** — a distinct, least-privilege role for the Server Repository (mirroring `oep_acquisition`'s own `NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION`, WP-SRV-005), owning only its own database, with no access to EAM's.
- **Migrations MUST be independent** — a separate Flyway (or equivalent) migration history for the Server Repository's own schema, not interleaved with EAM's `V1`-`V10` migration sequence.
- **No schema is created by this ADR.** These are constraints an implementation must satisfy, not a design.

## 26. Transaction Boundary

Per Task 22, translating ADR-0004's atomicity into implementation-facing requirements — **no implementation performed**:

- A successful commit **MUST** correspond to one atomic persistence transaction (if PostgreSQL, an ordinary `BEGIN`/`COMMIT` transaction) — or, if a future persistence choice cannot offer native transactions, an implementation mechanism providing **equivalent** all-or-nothing guarantees. PostgreSQL, per §25, natively provides this, so no alternative mechanism is needed for the first slice.
- A failed commit **MUST** leave repository state unchanged — the transaction is rolled back in full on any validation failure, concurrency conflict, or internal error encountered mid-commit.
- **Optimistic concurrency checks MUST occur inside the same atomic boundary that commits the mutation** — a read-then-check-then-write sequence split across multiple transactions (or performed outside any transaction at all) would reopen exactly the race condition optimistic concurrency exists to close. The expected-revision check for every mutation in a commit and the write that applies it **MUST** be part of one transaction.

**Idempotency state MUST be part of that same atomic boundary, not a separate write.** This is a correction to, and a strengthening of, the atomicity contract above — restated here explicitly because it is easy to implement incorrectly as two sequential writes rather than one:

For **every** successful commit, the following **MUST** be persisted within the **same atomic persistence boundary** as the mutation itself — the same transaction named above, not a follow-up write after that transaction commits:

- The object mutations.
- The relationship mutations.
- The resulting object revisions.
- The resulting relationship revisions.
- The commit identity (§6).
- The commit record (§23's content).
- The operation identity (§9).
- The idempotency outcome/result that a future retry of that same operation identity must be able to find and return (§9).
- The required audit association (§27).

**An implementation MUST NOT expose a successful mutation (i.e. return a success response, or make the new revision visible to any other read) before its idempotency outcome is durably associated with that mutation, in the same atomic write.** Concretely, the architecture **MUST** guarantee the following sequence:

1. Client submits a commit carrying operation identity `X`.
2. Server accepts and evaluates the commit.
3. The mutation, its resulting revisions, the commit record, the operation identity, its idempotency outcome, and the audit association **all commit together, atomically**, in one persistence transaction.
4. Client loses the response (any of the failure shapes in §24).
5. Client retries with the same operation identity `X`.
6. Server finds the existing idempotency result (because step 3 already durably recorded it, as part of the same transaction that applied the mutation — it cannot be missing).
7. Server returns the original commit result as a no-op success (§9).
8. The mutation is **not** applied a second time.

**This ADR explicitly prohibits the following failure mode**, which splitting the mutation write from the idempotency-record write across two transactions (or two non-atomic steps) would allow:

1. The mutation commits (durably).
2. The idempotency record does **not** commit (e.g. a crash or error between the two separate writes).
3. The client, having received no response, retries with the same operation identity.
4. The server, finding no idempotency record for that identity, incorrectly treats the retry as a brand-new commit and applies the mutation again.

Preventing exactly this sequence is the entire purpose of requiring one shared atomic boundary rather than two sequential writes — an implementation that writes the mutation first and the idempotency record second (in a separate transaction, "best effort," or "usually right after") does **not** satisfy this ADR, regardless of how rarely the gap between the two writes is actually hit in practice.

No PostgreSQL table layout, SQL statement, locking strategy, or transaction isolation level is prescribed by this requirement — it is a semantic guarantee an implementation must satisfy, by whatever concrete mechanism its chosen persistence technology offers for atomic multi-write commits (an ordinary multi-statement PostgreSQL transaction already satisfies it without requiring any special technique).

## 27. Audit Boundary

Per Task 23, minimum requirements — **not** an enterprise audit subsystem, and **not** a duplicate of EAM's acquisition-provenance model (ADR-0004 §15 already forbids conflating the two; reaffirmed, not re-designed, here):

Per §26's atomicity correction: for a successful commit, this audit association **MUST** be persisted within the same atomic persistence boundary as the mutation and its idempotency outcome — not written separately, and not written after the fact.

A successful commit **MUST** have an auditable association with:

- **Operation identity** (§9).
- **Commit identity** (§6).
- **Authenticated actor** — whatever identity ADR-0002's bearer-token mechanism establishes for the caller (today, a single shared token with no per-caller distinction, per ADR-0002 §13's own already-stated limitation — this ADR does not require per-user identity to exist for the audit record to be valid, only that whatever identity concept *does* exist is captured).
- **Affected entities** — every object/relationship UUID the commit touched.
- **Resulting revisions** — the new revision marker for each affected entity (mirroring §23's commit-result content, since both draw from the same underlying record).
- **Timestamp**.
- **Success/failure outcome, where applicable** — a rejected commit (§8) is not itself required to produce a full audit record in the same sense a successful one does (there is no new state to audit), but per §9's idempotency requirement, the server must still retain enough record of the *attempt* to answer future idempotency checks correctly; this ADR does not require that retention to take the same "audit event" shape as a successful commit's record.

## 28. Security Requirements

Per Task 24, an architecture-level review — **no implementation code**:

- **Authentication**: reuses ADR-0002's already-reviewed mechanism (constant-time comparison, no token in logs/responses, §12 of this ADR) — no new authentication surface is introduced, so no new authentication-specific risk is introduced either.
- **Authorization**: the minimum boundary (§11) is deliberately conservative — `NOT_FOUND` instead of `AUTHORIZATION_DENIED` for unauthorized *reads* specifically prevents repository-ID probing (below) from distinguishing "exists, no access" from "doesn't exist."
- **Replay**: a captured, valid commit request (with a valid operation identity and a valid token) replayed by an attacker who intercepted it would, under §9's rules, either be rejected (if the token/auth context differs — an attacker without the token cannot replay at all) or resolve to the same no-op-success outcome a legitimate retry would — **replay by a party who does not already hold a valid bearer token is prevented by ADR-0002's authentication boundary itself**, which any commit request must pass regardless of operation identity.
- **Idempotency abuse**: an attacker (or misbehaving client) attempting to enumerate/guess operation identities to trigger `IDEMPOTENCY_CONFLICT` responses learns nothing useful (the conflict response, per §13, is not required to reveal the original commit's content) — this ADR requires `IDEMPOTENCY_CONFLICT` responses **MUST NOT** echo back the previously-submitted mutation content of a *different* client's operation identity.
- **Object-ID probing**: mitigated the same way repository-ID probing is (§11) — `NOT_FOUND` for both "doesn't exist" and "exists, not authorized to see," at whatever granularity object-level authorization eventually exists (currently repository-level only, §11).
- **Repository-ID probing**: explicitly addressed in §11 (`NOT_FOUND`, not `403`, for unauthorized reads).
- **Oversized commits**: mitigated by the payload-limit requirement (§17) — a bound **MUST** exist, even though the exact number is deferred.
- **Malformed relationships**: mitigated by §19's integrity rules, enforced inside the atomic commit boundary (§26) — a malformed relationship cannot be partially committed.
- **Historical revision access**: governed by the same authorization boundary as current-state access (§11/§22) — no separate, weaker check exists for historical data that current-state data doesn't already have.
- **Error leakage**: explicitly forbidden by §13's leakage rule (no paths, credentials, connection details, or stack traces in any error category).
- **Audit integrity**: audit records (§27) **MUST NOT** be mutable through any endpoint this ADR defines — no operation in §7's endpoint model provides a way to edit or delete an audit record, mirroring Foundation's own local precedent that "the Audit Log is a historical record, not the source of truth" and is never itself mutated.

## 29. First Implementation Slice

Per Task 25 — **defined here as the scope for a future implementation work package; not implemented in this ADR.**

The first implementation slice **SHOULD** demonstrate, end-to-end, against real PostgreSQL persistence (mirroring WP-SRV-005's own validation rigor for EAM):

1. Server starts, authenticates via ADR-0002's existing bearer-token mechanism.
2. Authenticated repository creation (§21).
3. Repository retrieval (§7).
4. Object creation via commit (§8).
5. Relationship creation via commit, including the same-commit object+relationship case (§19).
6. Atomic commit success/failure behavior (§8/§26), including a deliberately-triggered validation failure.
7. Revision creation as a direct result of a successful commit (§7 of ADR-0004, confirmed at the wire level).
8. Optimistic concurrency rejection — a deliberately stale `expected_revision` produces `CONCURRENCY_CONFLICT` (§9/§13).
9. Idempotent retry — the exact retry-after-uncertain-response scenario (§9/§24) demonstrated directly, not merely asserted.
10. Historical revision retrieval (§22).
11. Audit association — a commit's audit record is retrievable and correctly linked (§27).
12. Restart persistence — server restarted, previously-created repository/object/relationship/revision data confirmed intact (mirroring WP-SRV-005's own restart-test precedent exactly).

**Explicitly deferred from the first implementation slice** (not authorized by this ADR, and not required for the slice above to be considered complete):

- Delete/tombstone (§10) — the *semantics* are decided by this ADR, but the first slice **MAY** omit delete support entirely and still satisfy §29's own scope; delete is authorized architecture, not mandated first-slice functionality.
- Pagination, filtering, sorting (§18) — simple, unbounded-within-payload-limits enumeration is sufficient for the first slice.
- Any authorization beyond §11's temporary "any authenticated caller" policy.
- API versioning's concrete mechanism choice (§15) — the first slice **MUST** pick one of the two named options, but which one is an implementation-time decision, not something this ADR forces.
- Deployment topology (unchanged from ADR-0005 §23 — still undecided).
- Any Exchange or EAM integration.
- Any publication/retrieval client-side tooling (Studio, CLI) — the first slice is the server side only; a client that actually calls it is separate, future work.

## 30. Explicit Non-Goals

This ADR does **not**:

- Implement anything — no C/C++, TypeScript, Dart, SQL, migration, HTTP handler, or database connection code.
- Create Docker/deployment configuration.
- Modify Foundation, EAM, or Exchange.
- Design a complete authorization/tenancy/IAM system (§11's minimum boundary is not one).
- Resolve the Exchange `RepositoryClient` payload mismatch (ADR-0005 §14, still open).
- Design synchronization of any kind (still explicitly undefined, reaffirmed).
- Introduce server-side Foundation.
- Introduce Git-like branching or merging (ADR-0004 §7's prohibition, unchanged).
- Introduce distributed transactions (ADR-0004 §9/§12, unchanged).
- Introduce automatic/continuous replication of any kind.
- Select exact payload-limit numbers, pagination page sizes, or the API-versioning mechanism's final choice between the two named candidates.
- Decide deployment topology.
- Authorize hard deletion.

## 31. Remaining Open Questions

1. API version's concrete wire mechanism: URI prefix vs. response header/field (§15).
2. Exact payload limit numbers (§17).
3. Pagination cursor design (§18).
4. Whether object/relationship-level authorization (finer than repository-level) is ever needed (§11).
5. Whether an administrative hard-delete capability is ever needed (§10).
6. The Exchange `RepositoryClient` payload mismatch (still open, ADR-0005 §14/§26).
7. Deployment topology (still open, ADR-0005 §23).
8. Whether/how Foundation ever gets a server-side existence (ADR-0001 Gap G8 — still open across every ADR to date).
9. Whether repository-creation authorization needs to move beyond the temporary "any authenticated caller" policy before any deployment broader than this platform's current single-operator context.

## 32. Consequences

- A future implementation work package has a complete, concrete, evidence-grounded specification: exact endpoints (§7), exact commit/result shapes at the semantic level (§8/§19/§23), a resolved idempotency mechanism (§9), resolved delete semantics (§10), a minimal but explicit authorization policy (§11), a full error/status mapping grounded in this platform's own existing precedent (§13/§14), and a bounded first-implementation scope (§29) — nothing in that scope requires inventing architecture mid-implementation.
- Because the HTTP status mapping (§14) is built directly on EAM's own already-established, already-in-production convention rather than a fresh design, a future implementer (and any future API consumer) encounters a status-code vocabulary consistent with the rest of this platform, reducing cognitive/integration cost.
- Because delete is resolved as tombstone-only, no-hard-delete (§10), the Server Repository's historical-integrity guarantee (ADR-0004 §7's "revisions MUST NOT be deleted") remains intact even once deletion of current-state visibility is introduced — the two concerns (deleting a *revision* vs. deleting an *object's current visibility*) never conflict.
- Because the temporary repository-creation authorization policy (§11) is stated explicitly, safely, and with an explicit revisit trigger, a future implementer is not left guessing at an unstated assumption, and the policy's own temporariness is documented rather than silently ossifying into a permanent, unreviewed default.

## 33. Future Work Packages

1. **Implementation of the first Server Repository vertical slice** (§29) — the immediate next work package this ADR authorizes.
2. Concrete persistence schema design (once implementation begins), per §25's constraints.
3. Concrete API-versioning mechanism selection (§15/§31 item 1).
4. Full authorization/tenancy model, superseding §11's temporary policy.
5. Synchronization design (still undefined).
6. Conflict-resolution algorithm/UX (still only detection is defined, across every ADR in this chain).
7. Resolving the Exchange `RepositoryClient` payload mismatch (§14/ADR-0005 §14).
8. Whether/how Foundation ever gets a server-side existence (ADR-0001 Gap G8).
9. Deployment topology decision.
10. Client-side publication/retrieval tooling (Studio/CLI), once the server side (§29) exists.
