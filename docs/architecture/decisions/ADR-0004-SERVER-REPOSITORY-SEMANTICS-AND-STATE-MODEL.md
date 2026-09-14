# ADR-0004 — Server Repository Semantics & State Model

## 1. Status

**Accepted, architecture-only. No implementation exists. No implementation is authorized by this document.**

This ADR resolves the semantic questions [`SERVER-REPOSITORY-SERVICE-CONTRACT.md`](../contracts/SERVER-REPOSITORY-SERVICE-CONTRACT.md) (WP-SRV-007) deliberately left open, before any persistence technology, database schema, synchronization mechanism, or HTTP API is selected for a future Server Repository Service. It does not implement that service. It does not create a database table, a migration, an HTTP endpoint, or any runtime code.

## 2. Context

WP-SRV-007 established *that* a Server Repository Service is architecturally distinct from local Foundation, EAM's Vault, Engineering Exchange, and `.oerp`/Knowledge Runtime, and named the categories of question that remained open (revision semantics, commit semantics, concurrency, publication, retrieval, synchronization status). It deliberately did not answer most of them in detail. This ADR answers them, at the semantic level, grounded in the actual local Foundation implementation — not invented independently of it.

Three concrete facts from the real, existing Foundation implementation shape every decision below, and are stated here once rather than repeated in every section:

1. **Local repository identity already exists and is reusable.** `RepositoryMetadata` (`platform/oep_foundation/platform/repository/include/oep/repository/metadata.hpp`, per `OEP-SPEC-003-REPOSITORY_METADATA`) already defines a `repository_id` (UUIDv4, validated), `repository_name`, `repository_version`, `foundation_version`, `template_version`, timestamps, `description`, `author`, `organization`, and `tags` — a complete, real repository-identity shape, persisted at `repository.json`. This ADR does not invent a new repository-identity concept; it extends this one.
2. **Local mutation is unconditional overwrite — no revision, no compare-and-swap.** `ObjectStore::update` (`platform/oep_foundation/platform/repository/src/object_store.cpp:234-260`) reads the existing object, preserves only `object_id`/`object_type`/`created_utc`, sets `last_modified_utc`, validates, and writes — directly overwriting the prior file. There is no check that the caller's view of the object was current. This is safe locally only because Foundation is single-process, single-writer, one-repository-open-at-a-time (`OEP-SPEC-011` §5). **This exact behavior is not safe at a server boundary with multiple remote clients, and is the reason this ADR requires something Foundation itself does not have.**
3. **A real, separate local Audit Log already exists and already establishes the "history record ≠ source of truth" pattern this ADR reuses at the server.** `AuditEvent` (`audit_event.hpp`) is explicit: *"The Audit Log is a historical record, not the source of truth: an AuditEvent never modifies the Engineering Object or Relationship it describes."* This ADR's revision/audit distinction (§10) is the direct server-side analogue of this already-ratified local pattern, not a new invention.

## 3. Decision

A Server Repository Service, if and when built, **MUST** conform to the semantic model defined in this document. This model is deliberately the smallest one that satisfies WP-SRV-007's own requirements (historical revisions retained, no silent last-write-wins, atomicity clearly bounded) — it does not introduce branching, merging, distributed transactions, or any mechanism beyond what those requirements demand.

## 4. Repository Identity

- A Server Repository's identity **MUST** be a `repository_id`, reusing the exact UUIDv4 shape already validated by `validate_metadata` for local `RepositoryMetadata.repository_id`. This is not a new identity scheme — it is the same one, at a different tier.
- Repository identity **MUST** be immutable for the lifetime of the repository — a `repository_id`, once assigned, is never reassigned or reused, mirroring `EngineeringObject.object_id`'s own immutability guarantee.
- Metadata conceptually associated with repository identity **SHOULD** mirror the fields already established by local `RepositoryMetadata` where they make sense at the server tier: `repository_name`, `description`, `author`/`organization` (as *creation* attribution, distinct from ongoing ownership — see §6), `created_utc`, `tags`. `foundation_version`/`template_version` are local-Foundation-specific concepts and **MAY NOT** transfer meaningfully to a server repository; this ADR does not decide whether an analogous "schema/compatibility version" is needed (**UNDECIDED**, §21).
- Repository identity **MUST** survive server restarts. This is a durability requirement on whatever persistence a future implementation selects (§19 of the WP-SRV-007 contract already establishes this class of requirement; this ADR does not weaken it).
- One server **MUST** be able to host multiple Server Repositories. Nothing in the actual `FoundationRuntime` "one repository open per Runtime instance" constraint (`OEP-SPEC-011` §5) applies here — that constraint is about a single local process holding one open repository at a time, not about how many repositories a multi-tenant server process may serve concurrently. A Server Repository Service is not bound by Foundation's single-open-repository limitation.
- Whether a repository can be moved between server instances is **UNDECIDED**. This is inseparable from the persistence-technology decision this ADR explicitly does not make (§19).
- Server location (which physical server/instance currently hosts a repository) is **NOT** part of repository identity. Identity (`repository_id`) and location (which server answers for it) **MUST** remain independently addressable concepts, so that a future move-between-servers capability (if ever built) does not require reissuing identity.

## 5. Repository Membership

This is the most consequential correction this ADR makes relative to WP-SRV-007's original text, so it is addressed in full, with the required validation against the actual Foundation model.

**WP-SRV-007's original statement** (§6-7 of the contract): *"An Engineering Object belongs to exactly one server repository at a time... A Relationship belongs to the same server repository as its endpoints."*

**Validation against the actual Foundation model**: Foundation's own local model provides no direct precedent either way — a local Foundation Repository does not track "membership" as a first-class concept at all; an object simply *is* a JSON file inside a specific repository's `ObjectStore` directory, and `FoundationRuntime`'s one-repository-open-at-a-time constraint means a running Foundation instance never has to reason about an object belonging to more than one repository simultaneously. There is no existing counter-example of an object legitimately existing in two local repositories at once, and no existing mechanism that would let one.

**Decision: the WP-SRV-007 statement is correct and remains in force, with the qualification below.**

- An Engineering Object **MUST** belong to exactly one Server Repository at any given time. The same `object_id` **MUST NOT** independently exist as a distinct engineering entity in two different Server Repositories simultaneously — that would fork identity without forking the UUID, which violates `object_id`'s own permanence guarantee (`OEP-SPEC-004`, unmodified by this or any prior ADR).
- A Relationship **MUST** belong to the same Server Repository as both of its endpoint objects. This ADR does not permit cross-repository relationships (an edge whose `source_object_id` and `target_object_id` resolve to objects in two different Server Repositories) — reinforcing WP-SRV-007's integrity requirement (§7), not merely repeating it. Rationale: a Relationship's own integrity check (do both endpoints currently exist) is meaningless if "exist" has to be answered against a foreign repository's authority, which this ADR does not define a mechanism for.
- **The qualification**: membership, as defined above, describes the *authoritative* server-side home of an object — it says nothing about whether a *copy* of that object's data may legitimately exist elsewhere (e.g. in a local Foundation Repository that published it, or received it — §11/§12). Local Foundation copies are not "membership" in the Server Repository sense; they are the local/server boundary's own concept, kept deliberately separate (§8's terminology already established this distinction and is reused here, not redefined).
- Repository membership **MUST** be treated as mutable in principle (an object could conceivably move between server repositories in the future) but **this ADR does not define a move-between-repositories operation**. Until such an operation is defined by a future ADR, membership **SHOULD** be treated as fixed at creation time in any initial implementation.
- Membership itself is **NOT** independently revisioned by this ADR. A move-between-repositories event, if ever implemented, would itself need to be a revisioned mutation (§7) of some kind — but since the operation itself is undefined here, this is **UNDECIDED** (§21), not designed.

## 6. Object and Relationship Ownership

Distinguishing the six concepts the WP-SRV-008 task itself named, so they are never conflated in a future implementation:

| Concept | Definition | Tracked by |
|---|---|---|
| **Repository ownership** | Which Server Repository an object/relationship belongs to (§5). | Membership, as above. |
| **Engineering authorship** | Who actually authored/edited the engineering content — the direct server-side analogue of `EngineeringObject.author`/`Relationship.author`, both real fields today. | Carried on the object/relationship itself, as already established locally. |
| **User ownership** | Which authenticated user (per ADR-0002's bearer-token boundary) is recorded as responsible for a given object, distinct from who most recently *edited* it (authorship may pass through many editors; ownership need not). | **UNDECIDED** in detail — this ADR establishes the concept must exist (per WP-SRV-007 §5/§14) without defining transfer rules, defaults, or storage. |
| **Organizational ownership** | Which organization a repository or object is associated with — the server-tier analogue of `RepositoryMetadata.organization`/`EngineeringObject`'s implicit organizational context. | **UNDECIDED** in detail; named as a real, distinct concept from user ownership, not designed further. |
| **Authorization** | What an authenticated caller is permitted to *do* to a given object/relationship/repository. | **Explicitly future work.** ADR-0002 remains the outer authentication boundary (is this caller who they claim to be); it does not answer authorization (what may they do). No role hierarchy is defined here. |
| **Publication authority** | Who is permitted to publish local state *into* a given Server Repository at all (a gate on the operation defined in §11, not on the resulting object). | **UNDECIDED** in detail; distinct from authorization above because it gates a boundary-crossing operation, not an in-repository mutation. |

This ADR does **not** define a complete tenancy or authorization model. It establishes that these six concepts are architecturally distinct and must never be collapsed into one field or one check, so that a future authorization ADR has clean seams to design against.

## 7. Revision Model

The smallest semantic model that satisfies WP-SRV-007's own requirement (historical state retained, no silent last-write-wins) — deliberately not Git-like branching, since nothing in the existing architecture requires it and WP-SRV-008's own instructions caution against it unless required.

- Every successful mutation to an Engineering Object or Relationship within a Server Repository **MUST** create a new revision. A "successful mutation" that does not produce a new, retrievable prior-state trace is not compliant with this ADR.
- A revision is **object-scoped or relationship-scoped, not repository-wide**, as the *unit of history* — each Engineering Object and each Relationship has its own independent revision sequence, exactly mirroring how `object_id`/`relationship_id` are independently permanent identities today. Repository-wide revisioning (a single incrementing counter describing "the whole repository's state at once," Git-commit-style) is **NOT** required by this ADR and is explicitly the kind of unnecessary complexity §21/§22 of the WP-SRV-008 task instructs against inventing without cause.
- A single **commit** (§8) **MAY** advance the revision of multiple objects and relationships atomically in one operation — this is the mechanism by which a repository-wide notion of "state at a point in time" can still be derived (as the union of each affected item's latest revision after that commit) without requiring a first-class repository-wide revision counter to exist as its own object.
- A revision **MUST** identify the complete resulting state of the specific object or relationship it belongs to — not merely a diff. (This does not mandate a storage representation — a diff-based storage layer that reconstructs full state on read would still satisfy this semantic requirement; §19 leaves that undecided.)
- A client **MUST** be able to request a specific historical revision of an object or relationship it has access to.
- Revision identity **MUST** be immutable — once created, a revision's content and its place in that object's/relationship's history never change.
- Revisions **MUST NOT** be deleted as an ordinary operation. (Whether an administrative purge/pruning capability ever exists for storage-management reasons is **UNDECIDED**, explicitly named as a non-goal in §19 and §21 — "MUST NOT be deleted as an ordinary operation" leaves room for that future, separately-decided exception without permitting casual deletion today.)
- **Branching is NOT supported by this model.** There is no concept of a named, divergent line of history per object.
- **Merging is NOT supported by this model.** There is no concept of combining two divergent revisions into one. (Conflict *detection*, not merging, is what optimistic concurrency provides — §10.)

## 8. Commit Model

- A Server Repository Service **MUST** conceptually support a `BEGIN … mutation(s) … COMMIT` grouping — a set of object/relationship mutations submitted and either all accepted together or none accepted at all (§9). Every mutation being independently, individually committed (no grouping capability at all) does **NOT** satisfy WP-SRV-007's own atomicity requirement (§12) for the case where a caller genuinely needs several objects/relationships to change together (e.g. creating an object and the relationship that connects it to an existing one, in the same logical step).
- **Atomicity boundary**: a commit's boundary is exactly the set of mutations the caller submitted together in one commit request. A commit **MUST NOT** partially apply — either every mutation in it is accepted and revisioned, or the commit as a whole is rejected and the repository's prior state (for every object/relationship the commit touched) is unchanged.
- **Success semantics**: a successful commit **MUST** produce exactly one new revision (§7) for each object/relationship it mutated, all logically simultaneous from an external caller's point of view (no other caller can observe a state where some-but-not-all of the commit's mutations are visible).
- **Failure semantics**: a failed commit (whether due to a validation failure, an optimistic-concurrency conflict on any one of its mutations — §10, or an internal error) **MUST** leave every object/relationship the commit attempted to touch exactly as it was before the commit was submitted. A failure response **MUST** clearly distinguish "nothing was applied" from any other outcome — silently applying a subset and reporting overall failure is **explicitly disallowed**, reinforcing WP-SRV-007 §12's own "a partial server commit must never be silently presented as complete" requirement, now made binding on the commit primitive itself.
- **Revision creation**: as stated above — one new revision per mutated object/relationship, created only on a successful commit, never on a failed one.
- **Audit relationship**: a successful commit **MUST** produce at least one corresponding audit record (§17) describing that the commit occurred, who performed it, and which objects/relationships it revisioned. A commit and its audit trail are related but distinct: the commit produces new *authoritative state* (a revision per affected item); the audit record produces a *historical explanation* of that state change — exactly the same distinction Foundation's own `AuditEvent` already draws locally ("a historical record, not the source of truth").
- **Visibility to other clients**: a committed mutation **MUST** become visible to other callers only after the commit fully succeeds — no other caller may observe an in-progress, uncommitted mutation from within a `BEGIN…COMMIT` grouping.

This ADR does **not** create a transaction API, a request/response schema, or any wire representation of `BEGIN`/`COMMIT` — these are semantic requirements a future API design must satisfy, not an interface.

## 9. Atomicity

(Restated and made precise, consolidating the atomicity requirements scattered through §7-8, per WP-SRV-008 Task 5's explicit ask.)

- The atomicity boundary **MUST** be exactly one commit (§8) — not the whole repository, not a single field within an object.
- A multi-object/multi-relationship commit **MUST** be all-or-nothing.
- Local Foundation's own transactions (`FoundationRuntime`'s begin/commit/rollback, real today) remain entirely local and single-process. **This ADR does not create, and explicitly forbids treating any future local-to-server operation as, a distributed transaction spanning a local Foundation transaction and a Server Repository commit.** If a future capability needs both a local write and a server commit to "happen together," that capability's own atomicity story (which may legitimately be "no atomicity guarantee across the boundary, only within each side") is a separate future design question, not answered or implied here.

## 10. Optimistic Concurrency

- A Server Repository Service **MUST** use optimistic concurrency as its baseline concurrency-control strategy, per WP-SRV-007 §13. No evidence anywhere in this repository (local Foundation, EAM, or Exchange) demonstrates a need for pessimistic locking at this layer, and Exchange's own precedent (`row_version` columns, real and in production) is itself an optimistic-concurrency pattern, not a pessimistic one — reinforcing this choice rather than contradicting it.
- **The conflict check is object-scoped or relationship-scoped, not repository-wide** — directly following from §7's decision that revisions themselves are object/relationship-scoped, not repository-wide. A mutation to object A **MUST NOT** be rejected merely because some unrelated object B changed since the client last read the repository; the client's expected revision (§7) is evaluated only against the specific object(s)/relationship(s) that specific mutation touches.
- For a multi-mutation commit (§8) touching several objects/relationships at once, **the conflict check MUST be evaluated independently per affected item, and the commit as a whole MUST be rejected if any single item's expected revision has gone stale** — consistent with §8's all-or-nothing commit semantics. A commit does not "partially succeed" by accepting the non-stale items and rejecting only the stale one.
- Semantic contract (restating WP-SRV-007's own example, made binding): a client reads revision R of an object/relationship, submits a mutation stating "I edited revision R." The server **MUST** accept the mutation only if R is still the current revision at commit time. If the server's current revision for that item is not R (i.e. someone else's mutation was already committed), the server **MUST** reject the mutation, **MUST** leave its own state unchanged, and **MUST** report the conflict to the client explicitly (not silently, not as an ambiguous generic error) so the client can reconcile.
- This ADR does **not** design a conflict-resolution algorithm (automatic merge, three-way merge, or otherwise) and does **not** design any client-facing reconciliation UI — both remain future work (§19/§21), consistent with WP-SRV-008's own explicit instruction.

## 11. Local → Server Publication

**Publication is explicitly and categorically distinct from synchronization** — this distinction is load-bearing for the rest of this section and restated wherever it matters.

- Publication **MUST** be an explicit, deliberate action initiated by a user/engineer (or an automated process acting on their behalf under their authority) — never an automatic, continuous, or background operation. This is the defining difference from synchronization (§12): publication is a single, bounded, intentional act; synchronization (undefined by this ADR — §12) would imply ongoing, potentially automatic reconciliation.
- Publication **MUST** transmit an explicitly selected set of Engineering Objects and Relationships — not "the entire local repository, always." What selection mechanism exists (the whole local repository as a default selection, a manual pick-list, a filtered export) is an interface-design question this ADR does not answer; the semantic requirement is only that the set is well-defined and known to the publisher before the operation begins.
- A successful publication **MUST** create a new Server Repository revision (§7) for each published object/relationship — publication is itself a commit (§8) from the server's point of view, subject to every atomicity/success/failure requirement already defined there.
- Publication **MUST** preserve the original `object_id`/`relationship_id` UUIDs exactly as they exist locally. **The server MUST NOT mint new engineering identities for published content** — this directly satisfies WP-SRV-007 §7's "prefer no [new identity], unless architecture requires it" guidance, and no evidence found during this ADR's research requires an exception. Preserving identity across the boundary is what makes "the same object, published, then later fetched back" a coherent, well-defined operation at all (§12).
- **If server state changed since the local state being published was last read/known**: publication **MUST** be treated as an ordinary mutation for optimistic-concurrency purposes (§10). If the object/relationship being published already exists server-side at a revision the publishing client did not account for, the publication **MUST** be rejected as a conflict, exactly as any other stale-revision mutation would be — publication is not a special, conflict-immune path. (Whether the *first* publication of a never-before-published local object is instead treated as an unconditional create, with no "expected revision" to check, is the natural, expected shape — there is nothing to conflict with — but this ADR does not need a special rule for it beyond noting that "expected revision" for a not-yet-published object is simply "does not yet exist server-side.")
- **Publication MUST NOT mutate the local Foundation Repository as a side effect**, beyond whatever local bookkeeping (e.g. "this object has been published, as of this local timestamp") a future implementation might choose to record. The engineering content itself — the object's fields, a relationship's endpoints — is not silently altered by the act of publishing it. (Whether any such bookkeeping is required at all is **UNDECIDED**, §21.)
- Publication **obviously cannot transmit while offline** — but the offline-first invariant (§13) requires that the local work being prepared for eventual publication remains completely valid, usable, and durable while offline. Publication is something that happens *after* local work is already complete and valid on its own terms, never a precondition for local work to be considered valid.
- **Publication SHOULD be idempotent** (Task 13, §18) — republishing the same local object at the same local state it was already successfully published at previously **SHOULD** be safely repeatable (e.g. because a network failure left the client uncertain whether the first attempt succeeded) without creating a duplicate, spurious revision or being misinterpreted as a new conflicting edit. The precise mechanism (a client-supplied idempotency token, content-hash-based deduplication, or something else) is **UNDECIDED** and explicitly left to the future API-design ADR (§19 of the WP-SRV-007 contract already named "concrete wire protocol/API design" as future work; this is the same deferral, applied specifically to idempotency mechanics) — only the *requirement* that repeated, otherwise-identical publication attempts must not silently corrupt history is established here.

## 12. Server → Local Retrieval

Per WP-SRV-008's own instruction, terminology is chosen from what the existing architecture already supports rather than invented.

- The operation of bringing Server Repository content into a local Foundation Repository is **retrieval** (this ADR's chosen term) or, where the object did not previously exist locally, **materialization** — it is the direct converse of publication (§11): identity-preserving, explicit, and bounded to a selected set of objects/relationships.
- It is **NOT synchronization** (§12 continues to reinforce the same distinction as §11 — retrieval is a single, bounded, explicit act, not ongoing reconciliation).
- It is **NOT "checkout"** in the Git/branching sense — there is no branch to check out (§7 explicitly rules out branching), so this ADR avoids that term to prevent implying version-control semantics this model does not have.
- It is conceptually closest to, but not identical to, **installation** in the sense Foundation already uses for `.oep` packages (PKG-001/PKG-002) — both bring externally-sourced content into a local repository — but installation (as it exists today) operates on a *package artifact*, while retrieval as defined here operates directly on Server Repository objects/relationships with no packaging step in between. This ADR does not equate the two mechanisms, only notes the conceptual kinship for a future implementer's benefit.
- Retrieved content **MUST** preserve its original `object_id`/`relationship_id` — the same identity-preservation requirement as publication (§11), for the same reason (a coherent publish/retrieve round trip requires it).
- Retrieval **MUST NOT** introduce a permanent server dependency into `FoundationRuntime` or any part of local Foundation's own operation. Retrieval is something a local Foundation Repository may optionally do, when online and when a user chooses to; it is never something local Foundation requires to function (§13).

## 13. Offline-First Invariant

Restated as a binding invariant, exactly as WP-SRV-007 §8 already established it, because WP-SRV-008 explicitly requires it to remain intact:

> **A local Foundation Repository MUST remain fully usable without access to the OEP Reference Server.**

Concretely and without exception: offline local object/relationship creation, offline local editing, offline local validation (`RepositoryValidator`), offline local persistence (`ObjectStore`/`RelationshipStore`/`AuditStore`, all real, all already fully local), and offline local `.oep` package installation **MUST NOT** ever be made to depend on a Server Repository Service being reachable, configured, or healthy. Nothing in this ADR's publication (§11) or retrieval (§12) model requires or implies otherwise — both are optional, explicit, online-only operations layered *on top of* an already-complete offline-capable local system, never a prerequisite for it.

## 14. `.oep`/`.oerp` Boundary

Unchanged from WP-SRV-007 §16/§9, restated here because WP-SRV-008 explicitly requires the relationship among all five concepts to be stated in this document too:

- **Foundation Repository**: the real, local, filesystem-backed repository of Engineering Objects/Relationships/Audit events. Unmodified by this ADR.
- **Server Repository**: this ADR's subject — a future, server-resident authority for the same kind of engineering state (Engineering Objects/Relationships), reached only through publication/retrieval (§11/§12), never through package installation.
- **`.oep` package**: Foundation's own transport/archive format (PKG-001/PKG-002). A package is never itself "the repository," per the existing, unmodified principle (*"The package itself is never the engineering database. It is a transport container"*). `.oep` installation and Server Repository publication/retrieval are two independent paths content can take into or out of a local Foundation Repository — this ADR does not merge them, and does not make one imply or require the other.
- **`.oerp` package**: Knowledge Runtime's own, entirely separate compiled package format (Reference Library → compiler → `.oerp` → Knowledge Runtime). Not modified, not touched, and not made into a Server Repository concept by this ADR.
- **Engineering Exchange**: the distribution/commercial boundary for `.oep` packages (§16 below). Not a package storage mechanism for either format, and not the Server Repository.

**The Server Repository MUST NOT become an implicit package runtime** — it does not parse, install, or execute `.oep` or `.oerp` packages. Its only interactions with engineering content are the object/relationship-level operations defined in §7-§12.

## 15. EAM Boundary

Confirmed unchanged, consistent with WP-SRV-007 §17 and the WP-SRV-005 audit's own direct finding (EAM's real PostgreSQL schema, audited in full, has no Engineering-Object-shaped table anywhere):

- **EAM owns**: acquisition (Official Sources, Jobs, Connectors), source evidence (Download Sessions), verification (SHA-256 Integrity Verifications), metadata extraction (Artifact Metadata), Vault publication (immutable, content-addressed artifact storage — a completely different "publication" from §11's Server Repository publication; the two uses of the word "publish" in this platform, EAM's `POST /vault` and this ADR's local→server object publication, are **not the same operation** and this ADR explicitly does not conflate them), and acquisition provenance (Acquisition Records, the full source→job→download→verification→metadata→vault-entry chain, real and tested).
- **Server Repository owns**: server-resident Engineering Objects, server-resident Relationships, repository revisions (§7), repository membership (§5), and repository history (§17).
- **Nothing in the existing architecture establishes EAM as a producer of Engineering Objects.** `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` §16 sketches an eventual conceptual pipeline (*Vault → Knowledge Extraction → Engineering Objects → Relationships → Provenance → Persistent Repository*) that implies some future process turns Vault artifacts into Engineering Objects — but that process ("Knowledge Extraction") is named, not designed, nowhere in this repository today, and is explicitly not EAM itself performing object creation. This ADR does not design that extraction step and does not grant EAM Engineering-Object-producing behavior.

## 16. Exchange Boundary

Confirmed unchanged, consistent with WP-SRV-007 §18:

- Exchange **publishes** packages (its own, unrelated sense of "publish" — a publisher making a `.oep` package available in the marketplace, distinct from both EAM's Vault publication and this ADR's §11 local→server publication; three different operations share the English word "publish" in this platform and this ADR does not merge any of them).
- Exchange **distributes** packages (search, download, installation-request recording — all real today).
- Exchange **does reference** a future Server Repository conceptually, through its own already-real `RepositoryClient`/`RepositoryInstallRequest`/`RepositoryInstallResult` abstraction (`services/exchange/packages/interfaces/src/repository-client.ts`) — but that interface describes installing a `.oep` package artifact, not creating or mutating an Engineering Object/Relationship directly. Whether a Server Repository Service, once built, is ever the thing behind that interface's `install()` call is a real, plausible future integration this ADR notes without deciding (§21/§22 of WP-SRV-007's own contract already flagged this; this ADR does not resolve it further).
- Exchange **installs packages into local Foundation repositories** today via the existing WP-EXC-013 install bridge — a `.oep`-package-specific path, unrelated to and unmodified by this ADR's publication/retrieval model.
- **Exchange does not become the Server Repository.** No implementation, integration, or redesign of Exchange is performed by this ADR.

## 17. Audit Semantics

- A **mutation** is a single change to one Engineering Object or Relationship (a create, update, or the conceptual equivalent of a delete — see the existing `AuditEventType` enum's own `ObjectDeleted`/`RelationshipDeleted` cases for local precedent, unmodified here).
- A **commit** (§8) is a set of one or more mutations submitted and accepted together, atomically.
- A **revision** (§7) is the resulting, retrievable historical state each mutated object/relationship reaches as a direct consequence of a successful commit — one new revision per mutated item, per commit.
- An **audit event**, at the server tier, **MUST** be a historical record *about* a commit (who performed it, when, which objects/relationships it touched, and which revisions resulted) — exactly the same "record, not source of truth" relationship Foundation's own local `AuditEvent` already has to `ObjectStore`/`RelationshipStore` (§2, fact 3). A server-side audit event **MUST NOT** itself be mutable, and **MUST NOT** ever be treated as the authoritative current state of anything it describes.
- The Server Repository **MUST** retain sufficient historical information — the combination of its revision history (§7) and its audit trail (this section) — to fully explain how its state reached its current shape: what changed, when, by whom, and (via revision retrieval, §7) what the state was immediately before and after. This ADR does not design the storage representation of that requirement (§19).

## 18. Idempotency

- Publication (§11) **SHOULD** be idempotent with respect to safe retry after a network failure or client timeout: if a client cannot determine whether a previously-attempted publication actually succeeded server-side (e.g. the connection dropped after the server accepted the commit but before the client received confirmation), retrying the identical publication attempt **SHOULD NOT** produce a duplicate revision or be misinterpreted as a new, independent edit — it **SHOULD** either be recognized as "already applied" (a no-op success) or fail as an ordinary stale-revision conflict (§10) if the server has since moved on, either of which is a safe, well-defined outcome. Silently applying the same content twice as two separate revisions is the specific failure mode this requirement rules out.
- Repeated publication of the *same* `object_id`/`relationship_id` at the *same* revision **SHOULD** be safely repeatable per the above. Repeated publication of the same `object_id` at a *newer* local state than what the server has **MUST** be treated as an ordinary new mutation, subject to the same optimistic-concurrency rules as any other (§10) — idempotency concerns retrying an *identical* attempt, not conflating two genuinely different edits.
- This ADR does **not** invent a request-ID field, an idempotency-key header, or any other transport-level mechanism. The requirement above is semantic; its concrete realization is deferred to the future API-design ADR (§21/§23 of this document, and §21 of the WP-SRV-007 contract, both already name "concrete wire protocol/API design" as future work).

## 19. Explicit Non-Goals

This ADR does **not** decide, design, or implement any of the following:

- Persistence technology (PostgreSQL, another database, filesystem, object storage, or otherwise).
- Any PostgreSQL schema, table, or migration.
- Any HTTP API, route, or wire protocol.
- Any authentication mechanism beyond reaffirming that ADR-0002's existing bearer-token boundary remains the outer gate.
- Authorization or tenancy implementation (only named as distinct required concepts, §6).
- A synchronization algorithm (synchronization itself remains undefined — see the explicit statement below).
- Conflict-resolution UX or algorithm (only conflict *detection* is defined, §10).
- Merge or branching support (explicitly ruled out of this model, §7).
- Revision pruning/retention policy specifics (only "MUST NOT be deleted as an ordinary operation" is established, §7).
- Server-side Foundation (`FoundationRuntime` becoming network-reachable) — still ADR-0001's own open Gap G8, not resolved here or by this document's existence.
- Distributed consensus of any kind.
- High-availability/cluster architecture.
- The concrete `.oep`/`.oerp` package-installation-to-Server-Repository protocol (only the conceptual boundary is restated, §14).
- Cross-repository relationship protocol (explicitly disallowed at the semantic level, §5 — there is no protocol to design because the capability does not exist in this model).

**Synchronization, specifically, remains explicitly undefined by this ADR**, exactly as WP-SRV-007 already stated. Publication (§11) and retrieval (§12) are the only local↔server operations this ADR defines, and both are explicit, bounded, one-directional, single-transfer acts — neither is, nor implies, an ongoing, automatic, bidirectional reconciliation mechanism.

## 20. Consequences

- A future Server Repository Service implementation has a concrete, unambiguous semantic target to build against for identity, membership, revisions, commits, concurrency, and the local/server boundary — closing most of the ambiguity WP-SRV-007 deliberately left open.
- Because local Foundation's own `ObjectStore::update` has no revision or conflict-detection concept today (§2, fact 2), **the Server Repository's revision/concurrency machinery is necessarily new, additive infrastructure — not an extension of anything Foundation already has locally.** A future implementing ADR must design this from the ground up (informed by this document), not by generalizing existing Foundation code.
- Because this ADR reuses Foundation's existing `repository_id`/`RepositoryMetadata` shape (§4) rather than inventing a new one, a future Server Repository's identity model has a direct, natural mapping back to local repository identity — easing whatever future retrieval/publication implementation is eventually built.
- Because branching/merging are explicitly ruled out (§7), a future implementation is materially simpler than a Git-like model would require — this is a deliberate complexity-avoidance decision, not an oversight, and should not be silently "upgraded" to a branching model without a new ADR explicitly justifying why the object/relationship-scoped revision model proved insufficient.

## 21. Open Questions

Explicitly unresolved by this ADR, each requiring either a future ADR or a specific implementation-time decision informed by one:

1. Whether a repository can be moved between server instances, and what happens to its identity if so (§4).
2. Whether an analogous "schema/compatibility version" concept is needed at the server tier, given that `foundation_version`/`template_version` do not transfer meaningfully (§4).
3. The full transfer/default rules for user ownership and organizational ownership (§6).
4. Publication-side local bookkeeping (does a local Foundation Repository record "this object has been published," and if so, how) (§11).
5. The concrete mechanism realizing the idempotency requirement (§18).
6. Revision pruning/retention specifics, beyond "not deleted as an ordinary operation" (§7).
7. A move-between-repositories operation for objects/relationships, and whether it is ever built at all (§5).
8. Whether/how a Server Repository ever becomes the thing behind Exchange's `RepositoryClient.install()` call (§16).
9. Whether/how EAM Vault content ever becomes Server Repository content via some future "Knowledge Extraction" process named but not designed in `docs/server/OEP_REFERENCE_SERVER_REQUIREMENTS.md` §16 (§15).

## 22. Future ADRs Required

Restating, and not expanding beyond, the list WP-SRV-007 §23 already established (this ADR resolves the *semantics* layer that list depended on; it does not shrink or grow that list):

1. Whether/how Foundation ever gets a server-side existence (ADR-0001 Gap G8 — still the largest, still open).
2. Synchronization design (explicitly still undefined, §19).
3. Conflict-resolution algorithm/UX (detection is defined here, §10; resolution is not).
4. Authorization and tenancy model (§6 names the concepts; does not design them).
5. Persistence technology selection (§19).
6. Concrete wire protocol / API design, including the idempotency mechanism (§18/§19).
7. Cross-repository relationships and cross-repository object membership (ruled out by this model, §5 — any future change to that ruling needs its own ADR, not a quiet reinterpretation).
8. Revision retention/pruning policy (§7).
9. The concrete relationship between `.oep`/`.oerp` package installation and Server Repository content (§14/§16).
