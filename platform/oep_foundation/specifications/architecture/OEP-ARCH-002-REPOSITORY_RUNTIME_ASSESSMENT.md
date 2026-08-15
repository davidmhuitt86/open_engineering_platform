# OEP-ARCH-002
# Repository Runtime Architectural Assessment

**Version:** 1.1
**Status:** Draft — For Review
**Scope:** `oep_foundation`, `oep_exchange`, `oep_studio`
**Purpose:** Pre-implementation architecture review requested to define the Repository Runtime work package roadmap. No code changes accompany this document.

**Revision note (v1.1):** Confirmed — the Repository stays part of Foundation; no new `oep_repository` repository. §5 is rewritten around a **vertical-slice philosophy**: the roadmap no longer sequences whole engines (Merge, then Registry, then Transactions, ...) to completion one at a time before anything is real. Instead, **WP-REP-001** cuts one thin, real path through every layer at once — install, register, index, and open `engineering-demo.oep` — deferring every horizontal concern (dependency resolution, signing, update/remove, network reachability) to explicitly-named follow-on slices. §0 is expanded with concrete, actionable terminology decisions rather than just naming the collision.

---

# 0. Terminology Standardization

Before any WP-REP work package is written, the vocabulary collision below needs to be resolved — not just named. Two decisions are proposed, both **free** (zero migration cost) because nothing currently implemented depends on the names being changed.

## 0.1 The collision, restated

**"Repository" and "Exchange" each already name two unrelated things** in this codebase.

| Term as used | Where | What it actually is |
|---|---|---|
| "Repository" (Foundation Repository) | `oep_foundation`, OEP-SPEC-002 | A local, on-disk workshop directory (`repository/`, `workspace/`, `packages/`, `cache/`, `logs/`, `exports/`, `settings/`) that `oep init` generates and Studio opens. This is what `FoundationRuntime::open_repository()` operates on. |
| "Repository Fragment" | PKG-001 §7 | The Engineering-Objects/Relationships/Metadata payload *inside* a `.oep` package archive — not a repository itself, a transport container's content. |
| "Engineering Exchange" (`oep_exchange`) | `oep_exchange` | The Postgres-backed marketplace (publishers, packages, search, download, install-request) built across TASK-EXC-0001–0009. |
| "Exchange" (Foundation) | `oep_foundation/platform/exchange` | Repository export/import/template capture — a single deterministic **JSON** document, explicitly **not** the `.oep` ZIP format (`platform/exchange/README.md`: "not a compressed/binary container"). Backup/restore/scaffolding, unrelated to marketplace distribution. |

## 0.2 Recommended renames

**Status: Applied in WP-REP-002.** Both renames below were ratified and implemented — `platform/exchange` is now `platform/archive` (directory, `oep::archive` namespace, `oep_archive` CMake target); PKG-001 §5's in-archive `repository/` is now `fragment/` (spec, `@oep-exchange/package-cli`, and `platform/installer`, which also accepts the legacy name for already-built archives). The recommendation text below is retained for historical context.

**(a) Rename `oep_foundation/platform/exchange` → `platform/archive`.**
This module has never had anything to do with the Engineering Exchange marketplace — it captures/restores/templates a Foundation Repository as a deterministic JSON document. "Archive" is what it does. This is a **free** rename: nothing outside `oep_foundation` links against this module by name (Studio's `dart:ffi` bridge does not expose export/import/template at all — `oep_api.h` has no such functions today), and nothing inside it is part of a ratified public spec title (OEP-SPEC-017/018/019 are already correctly titled "REPOSITORY_EXPORT"/"REPOSITORY_IMPORT"/"REPOSITORY_TEMPLATES" — no "Exchange" in any spec name, only in the directory path). Recommended scope: rename the directory, the `oep::exchange` C++ namespace, and update `platform/runtime`'s includes (`oep/exchange/*.hpp` → `oep/archive/*.hpp`) and its own README cross-references. No spec renumbering required.

**(b) Rename PKG-001 §5's `repository/` directory (inside a `.oep` archive) → `fragment/`.**
PKG-002 §21 and PKG-001 §3 already call this the package's "Repository Fragment" in prose — only the physical directory name still says bare `repository/`, which is the actual collision point once engineers start saying "put it in the repository" and meaning two different directories. This is also a **free** rename today: no implemented code reads or writes `manifest/../repository/` inside an archive yet (`packages/manifest` in `oep_exchange` only ever reads `manifest/package.json`; the merge engine that will read the Fragment doesn't exist yet — see §3). Recommended: amend PKG-001 §5's tree diagram and §7 to use `fragment/` (or `content/`, `fragment/` reads more precisely given §7's own "Repository Fragment" prose), before `platform/installer` (§4.3) is built against the old name. `oep-package create`/`build` (`oep_exchange/packages/package_cli`) would need the same one-line path update — cheap, and it hasn't produced any real package other than `engineering-demo.oep` yet.

**(c) Do not rename `oep_exchange` itself, and do not overload "Package Manager."**
The marketplace repository's name is correct and matches the platform's own vocabulary ("Engineering Exchange") — the collision was Foundation's *internal* reuse of the word, not the top-level repository name. Separately: `platform/packages`' existing `PackageManager` class already owns a narrower, discovery-only meaning (OEP-SPEC-010). The new install/merge/registry capability should **not** be shoehorned into a class also called `PackageManager` or `Runtime` (avoiding a `Runtime`-vs-`FoundationRuntime` collision too) — implement it as new methods directly on `FoundationRuntime` (§4.3), backed by a new `platform/installer` module with its own distinctly-named class (e.g. `PackageInstaller`). "Repository Runtime" is the *program/roadmap* name for this initiative (as the user has already established it), not a new C++ class.

**(d) Minor note: "package" is also three things** (a `.oep` marketplace package; an OEP-SPEC-010 local Studio/SDK/Extension/Theme package under a repository's own `packages/` directory; an npm workspace package in the TypeScript monorepos). No rename recommended — context disambiguates this one in practice, and OEP-SPEC-010's scope note ("Package installation... deferred to future specifications") already signals it's aware of and subordinate to the marketplace package concept. Flagged for awareness only.

## 0.3 Vocabulary going forward

- **"Foundation Repository"** (or bare "Repository" when context is unambiguous) — the local on-disk workshop directory only.
- **"Repository Fragment"** — always, never bare "repository," for a `.oep` package's internal Engineering-Objects/Relationships/Metadata payload.
- **"Repository Runtime"** — the program name for this entire initiative (WP-REP-*), not a class name.
- **"Archive"** (post-rename) — Foundation's own export/import/template subsystem. Never "Exchange" when talking about `oep_foundation` internals.
- **"Engineering Exchange"** — reserved exclusively for the `oep_exchange` marketplace.

---

# 1. Current Repository Architecture

## 1.1 What "the Repository" is today

A Foundation Repository is a directory on disk, generated by `oep init` (OEP-SPEC-002), opened by `FoundationRuntime::open_repository()` (OEP-SPEC-011), and manipulated exclusively through Foundation's own subsystems — never directly by any application. There is **no database anywhere in this layer**: every Engineering Object, Relationship, and Audit Event is a flat JSON file on disk, read/written through a minimal internal JSON parser (`platform/repository/src/json_value.cpp`), with atomic writes. This is a deliberate, offline-first design choice (CLAUDE.md: "Offline-first architecture"), not an oversight — and it is architecturally distinct from `oep_exchange`'s own Postgres-backed catalog, which is the correct split: the Exchange indexes *many publishers' packages for discovery*; the Repository *is one engineer's actual engineering data*.

## 1.2 Layering, as built

```
Filesystem (flat JSON files, one per Object/Relationship/AuditEvent)
  ↓
platform/repository  — ObjectStore, RelationshipStore, AuditStore, GraphEngine, RepositoryValidator
platform/search      — SearchEngine
platform/packages    — PackageManager (discover/load/validate only)
platform/exchange    — Export/Import/Template (a different archive format, see §0)
  ↓
platform/runtime     — FoundationRuntime (the one orchestrator; subsystems never locate each other directly)
  ↓
platform/api         — oep_api.h, a pure C ABI (OEP_API_VERSION 4, OEP_ABI_VERSION 1)
  ↓
oep_studio's dart:ffi bridge (in-process, same machine — no network hop)
```

This matches OEP-SPEC-011 §10 exactly ("The Runtime coordinates them. It does not replace them.") and OEP-SPEC-021's "one stable native interface" mandate.

## 1.3 What reaches this layer today, and how

- **`oep` CLI** (`platform/cli`) — the C++ executable, links `oep_cli_core` directly against `FoundationRuntime`.
- **OEP Studio** — `lib/core/foundation/foundation_bridge.dart` + `oep_api_bindings.dart` bind the *entire* current C API surface via `dart:ffi`, including the full mutation/transaction/batch functions added in Work Package 014 (`oep_object_create`, `oep_transaction_begin`, etc. are already looked up and called). Studio already has full local read **and write** access to an opened Foundation Repository.
- **Nothing else.** There is no HTTP server, no network listener, no remote-procedure surface anywhere in `oep_foundation`. The Public C API is explicit about this (OEP-SPEC-021 §2: "This specification does not define... Network APIs. Remote Foundation.").

## 1.4 The `.oep` package format's relationship to all of this

PKG-001 §3 states it plainly: *"When installed, [a package's] contents become Engineering Objects within a Repository... The package itself is never the engineering database. It is a transport container."* This directly confirms the user's observation #4: the Repository — specifically `platform/repository`'s `ObjectStore`/`RelationshipStore` — is the long-term owner of engineering content; a `.oep` package is only ever a way to *get* content there.

---

# 2. Existing Implementations

## 2.1 Specifications (all in `oep_foundation/specifications/platform/`)

Fully specified and **implemented**: OEP-SPEC-001 (CLI), 002 (Foundation Repository structure), 003 (Repository Metadata), 004 (Engineering Object Model), 005 (Object Relationship Model), 006 (Repository Search), 007 (Graph Traversal), 008 (Repository Audit Log), 009 (Repository Validation), 010 (Package System — *discovery only*, see §2.3), 011 (Foundation Runtime), 012 (CLI Command Framework), 013–016 (CLI command groups), 017–019 (Export/Import/Templates), 020 (Batch Operations), 021 (Public C API), 022 (Foundation Bridge Support).

Fully specified and **entirely unimplemented** (all in `oep_exchange/docs/specifications/package/`, all dependency-chained off PKG-001/002): **PKG-003** (Package Transaction Engine — install/update/repair/remove/rollback, "no component may bypass the PTE"), **PKG-004** (Dependency Resolution Engine), **PKG-005** (Trust & Digital Signature), **PKG-006** (Repository Merge & Object Ownership), **PKG-007** (Package Content Model), **PKG-008** (Package Registry). This is a complete, coherent, already-written specification for exactly the capability being scoped now — nobody needs to design it from scratch, only implement it.

## 2.2 Services

| Service | Repository | Status |
|---|---|---|
| `ObjectStore` / `RelationshipStore` / `AuditStore` | `oep_foundation/platform/repository` | Real, tested, full CRUD |
| `GraphEngine` | `oep_foundation/platform/repository` | Real (neighbors, BFS/DFS, path-existence) |
| `SearchEngine` | `oep_foundation/platform/search` | Real |
| `RepositoryValidator` | `oep_foundation/platform/validation` | Real |
| `PackageManager` | `oep_foundation/platform/packages` | Real, but **discovery/load/validate only** — no install |
| `FoundationRuntime` | `oep_foundation/platform/runtime` | Real orchestrator; transactions and batch mutation added in Work Package 014 |
| `RepositoryClient` (interface) | `oep_exchange/packages/interfaces` | Real interface, two implementations: |
| `StubRepositoryClient` | `oep_exchange/packages/installer` | Real, but a no-op — accepts every install, writes nothing, fabricates a `repositoryPackageId` string |
| `HttpRepositoryClient` | `oep_exchange/packages/installer` | Real HTTP client code, but **calls an endpoint (`POST {baseUrl}/api/v1/packages/install`) that does not exist anywhere** — this is a client with no server |
| `InstallationService` | `oep_exchange/apps/exchange-api` | Real; records install *attempts* (Postgres `installations` table) but delegates the actual work entirely to whichever `RepositoryClient` is configured |

## 2.3 Database structures

**Two, entirely separate, by design:**

1. **`oep_foundation`**: none. Flat JSON files under `<repository>/repository/{objects,relationships,audit}/`.
2. **`oep_exchange`**: PostgreSQL (`publishers`, `packages`, `package_versions`, `package_files`, `installations`, `downloads`, `audit_log`, `search_index`). This tracks *marketplace* state (what's published, what's been requested for install) — it has no knowledge of what actually landed inside any given Foundation Repository, because nothing today makes that connection.

There is no database that plays the role PKG-008 (Package Registry) specifies: *"the authoritative inventory of every package installed within an Open Engineering Platform Repository."* That inventory does not exist in any form today, database or otherwise.

## 2.4 Repository APIs

- **Local/native**: `oep_api.h` — comprehensive (runtime lifecycle, repository status/statistics, object/relationship CRUD, search, transactions, batch mutation). Zero install-related functions.
- **Network/HTTP**: **none exist.** `HttpRepositoryClient` was written anticipating one (`POST /api/v1/packages/install`, JSON body with `packageId`/`version`/`sha256`/`fileName`/`artifactBase64`, response `{accepted, repositoryPackageId?, message?}`) — this is real, already-authored evidence of the expected shape, but nothing on the other end of that URL exists.

## 2.5 Repository object model implementations

`EngineeringObject` (`object_id`, `object_type`, `name`, `description`, timestamps, `version`, `author`, `tags[]`) and `Relationship` are both real, validated, JSON-serializable, and exposed through the C API as fixed-layout structs (`oep_object_info_t`, `oep_relationship_info_t`) specifically designed for cross-language Bridge consumption (OEP-SPEC-022). This model is mature and does not need rework for package installation — it needs a *writer* that can populate it from a `.oep` archive's Repository Fragment, which does not exist (that's PKG-006's job).

---

# 3. Missing Components

In order of dependency (each blocks the ones below it):

1. **Package Content Model & Merge Engine (PKG-006/007)** — nothing extracts a `.oep` archive's `repository/objects|relationships|metadata` payload and writes it into a live Foundation Repository's `ObjectStore`/`RelationshipStore`. This is the single largest gap; everything else assumes it exists.
2. **Package Transaction Engine (PKG-003)** — no atomic install/update/repair/remove/rollback orchestration. `FoundationRuntime` already has the primitive it would be built on (`begin_transaction`/`commit_transaction`/`rollback_transaction`, added Work Package 014) — the PTE is "apply the merge engine's output inside a transaction," not a new persistence mechanism.
3. **Dependency Resolution Engine (PKG-004)** — no version-constraint or capability-requirement checking before install. `packages/dependency_resolver` in `oep_exchange` is a one-line scaffold.
4. **Trust & Digital Signature verification (PKG-005)** — manifest `signatures` are read but never checked, on either side. `@oep-exchange/signing` is a one-line scaffold; Foundation has no signature-verification code at all.
5. **Package Registry (PKG-008)** — no record of what's installed, at what version, from where, or when, distinct from `PackageManager`'s directory-scan-on-demand.
6. **Install/Update/Remove operations on `FoundationRuntime` and `oep_api.h`** — the Runtime and C API have every primitive except these; no `install_package`, `update_package`, `remove_package`, or `list_installed_packages` exists anywhere in the stack.
7. **A network-reachable Repository Runtime.** This is the largest *structural* gap and easy to miss: **Foundation has never been a network service.** Everything above, even once built, would only be reachable by a process running on the same machine, in the same process, via `dart:ffi` or direct C++ linkage. `oep_exchange`'s `HttpRepositoryClient` cannot reach a Repository that has no HTTP surface, regardless of how complete the install logic underneath becomes.
8. **The connection between Exchange installations and Repository installs.** `apps/exchange-api`'s `installations` table and Foundation's (currently nonexistent) Package Registry are two separate records of "was this installed" with no shared identity today (`InstallationDto.repositoryPackageId` is the only bridge, and today it's a fabricated stub string).
9. **Studio's "Open Installed Package" / "Open in Engineering Workspace."** Already identified and documented as best-effort in WP-EXC-010 (`oep_studio/docs`-equivalent, `oep_exchange/docs/guides/STUDIO_INTEGRATION_GUIDE.md`) — correctly, since nothing upstream produces real installed content to open yet.

---

# 4. Recommended Runtime Architecture

## 4.1 Where should the Repository Runtime live?

**Inside `oep_foundation`, not a new `oep_repository` repository.** Reasoning:

- CLAUDE.md is explicit and load-bearing here: *"The Repository is the product... Never design features that bypass the Repository"* and *"Never duplicate Engineering Object data."* `ObjectStore`/`RelationshipStore`/`GraphEngine`/`RepositoryValidator`/transactions already exist in `oep_foundation` and are exactly what a package installer needs to write through — building a second implementation in a new repository would either duplicate this logic or force a new repository to depend on `oep_foundation` in a way the platform doesn't otherwise do (Studio depends on Foundation via a compiled bridge, not a source dependency; Exchange depends on nothing in Foundation at all, per `DEPENDENCY_GRAPH.md` §5).
- PKG-003 through PKG-008 are already framed as extensions of the existing `platform/packages` subsystem's territory ("Package installation... deferred to future specifications" — `platform/packages/README.md` — this *is* that future specification arriving).
- The "frozen" architecture (CLAUDE.md) already designates C++ as the Repository/Runtime language and Foundation as the sole place Repository logic lives. A separate `oep_repository` repo would either re-fragment that (if it reimplements Repository logic) or become a thin, oddly-scoped wrapper (if it just calls into Foundation) — neither is worth the coordination overhead of a fourth repository.

**Recommendation: add new modules to `oep_foundation`** — `platform/installer` (or extend `platform/packages`) for PKG-003/004/006/007/008, following the exact pattern `platform/exchange` and `platform/validation` already establish (a focused module, a public header-only interface, `FoundationRuntime` as the only consumer-facing entry point).

## 4.2 The one real open question: does the Repository Runtime need a network face?

Yes — and this is the part of "build the Repository Runtime" that isn't just "finish the C++ work already underway." `oep_exchange` is architecturally required to reach the Repository only over the network (`DEPENDENCY_GRAPH.md` §5: *"a network call (REST/HTTP)... never a source-level import"*), and `HttpRepositoryClient` already assumes this. Today, nothing in `oep_foundation` can ever be reached that way — it is a linked library and an FFI target, not a service.

Two shapes are viable; **this report recommends the first** but flags it as the item most needing explicit sign-off (CLAUDE.md: *"AI does not introduce major technologies without approval"*):

- **(a) A thin HTTP façade inside `oep_foundation`** (e.g. `platform/api_server`), linking directly against `FoundationRuntime` and exposing the same install/status operations `oep_api.h` exposes locally, just over HTTP for the one caller (the Exchange installer) that cannot link against it directly. Keeps "the Repository is one product, one repository" intact; the only new thing is a transport, not new business logic.
- **(b) A separate lightweight service repository** whose only job is translating HTTP to the C API, keeping `oep_foundation` itself network-free. This avoids adding an HTTP server dependency to the core Foundation build, at the cost of a fourth repository and one more moving part between Exchange and Foundation.

Either way: **the underlying install/merge/transaction/resolution logic belongs in `oep_foundation` regardless of which shape wins** — this question only decides where the network *edge* sits, not where Repository logic lives.

## 4.3 Install / version / update / remove / resolve — target flow

```
.oep archive (already validated, already parseable — see oep-package CLI)
  ↓
Trust & Signature verification (PKG-005)         — new
  ↓
Dependency Resolution (PKG-004)                    — new, stateless, produces a report; never mutates
  ↓
Package Transaction Engine (PKG-003)               — new, wraps the steps below in one FoundationRuntime transaction
  ├─ Repository Merge (PKG-006)                     — new: Repository Fragment → ObjectStore/RelationshipStore writes,
  │                                                     preserving object identity/provenance, per PKG-006 §2
  └─ Package Registry update (PKG-008)               — new: record identity/version/install time/source
  ↓
FoundationRuntime.install_package(...)              — new orchestration method (mirrors execute_batch_create's shape)
  ↓
oep_package_install(...)                            — new Public C API function
  ↓
Studio's foundation_bridge.dart (new binding) / Repository Runtime HTTP surface (new, for Exchange)
```

**Update** = resolve the new version, diff against the Registry's recorded version (PKG-001 §17 "Updates are Repository-aware... added/modified/removed/deprecated objects"), run the same merge/transaction path with a diff-aware Repository Merge step. **Remove** = the Transaction Engine's reverse path, respecting PKG-001 §16's cross-package dependency check before deleting shared objects. Both reuse the same PTE/transaction primitives as install — this is one engine with three entry points, not three engines.

## 4.4 Exposing installed content to Studio and the Engineering Workspace

**This is largely already built.** Once install actually writes into `ObjectStore`/`RelationshipStore`, Studio's existing read path — `FoundationRuntimeNotifier`, `RepositoryPage`, `ObjectsPage`, `EngineeringObjectRuntime`, the full `oep_object_store_list`/statistics C API surface — picks it up with **no new Studio-side reading capability required**. Concretely: `FoundationRuntimeNotifier.refreshRepository()` (added in WP-EXC-010, `oep_studio/lib/core/services/foundation_runtime_service.dart`) is *already* the exact hook the Exchange Studio workspace calls after an install; it currently refreshes a repository that an install never actually changed. Once a real install path exists, this call starts doing something real with zero Studio-side changes.

What Studio *would* still need, once the Repository Runtime exists: (1) new `dart:ffi` bindings for the new install/update/remove/list-installed C API functions (mechanical, following the exact pattern `oep_object_create` etc. already establish), and (2) a real "Open Installed Package" implementation — replacing WP-EXC-010's documented best-effort navigation with something that resolves a `repositoryPackageId`/Package Registry entry to the specific Engineering Object(s) it installed and opens them in the Engineering Workspace (Project Explorer/Diagram Studio/Objects), rather than the destination-only navigation that exists today.

---

# 5. Proposed Work Package Roadmap — Vertical Slices

**Numbering:** `WP-REP-*`, per the program name established in §0.3 — this supersedes v1.0's suggestion to reuse `oep_foundation`'s bare Work-Package-NNN sequence. `oep_foundation`'s own `TASK.md`/`CURRENT_SPRINT.md` should reference the `WP-REP-*` id in their Context sections when work lands (the same way `oep_studio` tasks in this program have cited `WP-EXC-*` ids), rather than running two competing numbering schemes.

**Philosophy change from v1.0:** the previous roadmap sequenced whole engines to completion, one at a time (finish Merge, then Registry, then Transactions, then Dependency Resolution...) before anything end-to-end was real. That front-loads risk into the least-observable parts of the system and defers the first real proof that any of it works. The revised roadmap instead cuts one **thin, real, vertical slice** through every layer immediately — install, register, index, and open one already-built, already-validated package — and treats every horizontal concern (multi-package conflicts, dependency resolution, signing, update/remove, network reachability) as a named, deliberately deferred follow-on slice, not a prerequisite.

## WP-REP-001 — Vertical Slice: Install, Register, Index, Open

**Objective:** `engineering-demo.oep` — the real, already-built, PKG-001/002-conformant artifact from the Repository Fragment investigation — can be installed into a real Foundation Repository, becomes a real `ObjectStore` entry, is recorded in a new minimal Package Registry, is findable through the existing `SearchEngine`, and is visible when the repository is opened from OEP Studio. All for the first time, using only architecture that already exists plus the minimum necessary new code.

**Repositories:** `oep_foundation` (primary — nearly all new work). `oep_studio` (verification touch only: new `dart:ffi` bindings for the new C API functions, plus confirming the *already-built* `RepositoryPage`/`ObjectsPage`/`refreshRepository()` correctly display real installed content with no other Studio change). `oep_exchange`: **not touched.** `engineering-demo.oep` is supplied as an artifact already on disk — this slice does not require a live network call from the Exchange, deliberately (see Deferred, below, and §4.2).

**In scope:**
- New `platform/installer` module (C++), implementing PKG-006/007's non-overlapping-install case: extract a validated archive's Repository Fragment (§0.2 rename: `fragment/`) and write its Engineering Objects/Relationships into the open repository's `ObjectStore`/`RelationshipStore`, preserving the archive's declared `object_id`s.
- A minimal Package Registry (PKG-008's minimal case): one JSON record per installed package under `<repository>/packages/<packageId>/registry.json` — `packageId`, `version`, a manifest snapshot, `installed_utc`, `source` (`"local"` for this slice), and the object/relationship IDs it contributed. Query surface limited to "is this installed" / "list installed" — no update/remove query shape yet.
- `FoundationRuntime::install_package(archive_path)` — new orchestration method, wrapping the merge + registry write in the *existing* `begin_transaction`/`commit_transaction`/`rollback_transaction` primitives (Work Package 014) for atomicity. No new rollback mechanism is introduced.
- Manifest validation, re-implemented natively (Foundation is C++; it cannot import `@oep-exchange/manifest`) but held to PKG-002 §5/§20's identical rule set — cross-checked in this work package's own tests against a manifest `oep-package validate` (`oep_exchange`) also accepts, so the two implementations can never silently drift on what "valid" means.
- New CLI command `oep package install <archive.oep>` (`platform/cli`, following its own documented `Command`-interface extension pattern) — the trigger for this slice's demonstration. Distinguished by name from the existing read-only `oep packages [repository]`.
- New Public C API functions, minimally `oep_package_install` and `oep_package_list_installed` (OEP-SPEC-021/022-compliant: opaque result struct, no STL/exceptions crossing the boundary), plus the corresponding `dart:ffi` bindings in `oep_studio`.
- `platform/api/README.md` updated per OEP-SPEC-021 §9's own documentation requirement.

**Explicitly deferred (naming these is the point of a vertical slice):**
- Dependency Resolution Engine (PKG-004) — `engineering-demo.oep` declares zero dependencies; this slice exercises no resolution logic.
- Trust & Digital Signature verification (PKG-005) — `engineering-demo.oep` is unsigned (already documented, `oep_exchange`'s own `KNOWN_ISSUES.md`); WP-REP-001 installs unsigned packages, matching the Exchange's own current unsigned-by-default posture, and does not add verification.
- Update / Repair / Remove — only Install ships. The rest of PKG-003's lifecycle is later work.
- Any network-reachable Repository Runtime surface, and the `StubRepositoryClient` → `HttpRepositoryClient` swap — this slice proves the Foundation-side capability exists; making the Exchange able to reach it over a network is the explicit subject of §4.2's still-open shape decision and a later slice, not something resolved by shipping this one first.
- Multi-package installs, cross-package object-ID collisions, shared-reference integrity — correctly out of scope for a single, non-overlapping demo package (§6 risk, retained).
- Any `oep_exchange` code change at all.

**Exit criteria:** `oep package install engineering-demo.oep` succeeds against a real `oep init`-generated repository; `oep object list` / `oep status` show the installed object and updated counts; `oep packages` reports it `Loaded`; opening the same repository in OEP Studio shows the object on `RepositoryPage`/`ObjectsPage` with no Studio-side change beyond the new FFI bindings; re-installing the same package/version is rejected (idempotency, mirroring the Exchange's own "version already exists" rule); full build and test suite pass in both `oep_foundation` and `oep_studio`.

## Follow-on slices (backlog, not yet detailed)

Each is its own future vertical slice — a real, demonstrable capability added to what WP-REP-001 already proved works end-to-end, not a return to horizontal engine-completion:

- **WP-REP-002 — Dependency Resolution.** Implements PKG-004; exercised against a second demo package that actually declares a dependency on the first.
- **WP-REP-003 — Update & Remove.** Completes PKG-003's lifecycle on top of WP-REP-001's transaction/registry foundation.
- **WP-REP-004 — Trust & Signing.** PKG-005, both sides: Foundation-side verification and a real `@oep-exchange/signing` implementation, shipped together since an unsigned-package policy decision affects both.
- **WP-REP-005 — Repository Runtime network surface.** Resolves §4.2's open shape decision, implements it, swaps `oep_exchange` to a real `HttpRepositoryClient` target, and reconciles the Exchange's `installations` table with the Package Registry (§3 item 8). First slice that requires an `oep_exchange` change.
- **WP-REP-006 — Studio deepening** (`oep_studio`, own `WP-STUDIO-*` task numbering, cross-referenced against `WP-REP-006`). Replaces WP-EXC-010's documented best-effort "Open Installed Package"/"Open in Engineering Workspace" navigation with real resolution to installed Engineering Objects, and adds an "Installed Packages" panel (list/update/remove) to `RepositoryPage`.

---

# 6. Risks

- **Terminology drift if §0's renames aren't applied before WP-REP-001 starts.** Both renames are free today and become progressively more expensive the more code references the old names — `platform/exchange`→`platform/archive` and PKG-001's `repository/`→`fragment/` should land *before* `platform/installer` is written, not after.
- **Merge/ownership complexity is historically where package managers get hard.** PKG-006's promise ("preserving object identity, ownership, provenance, and referential integrity") is straightforward for a fresh, non-overlapping install (WP-REP-001's exact scope) and materially harder once two packages can reference the same object. WP-REP-001's explicit deferral of that case (above) is the mitigation, not a gap to close immediately.
- **Do not read WP-REP-001 as "the Repository Runtime is done."** It proves the Foundation-side path works for one unsigned, dependency-free, locally-supplied package. Real Exchange-triggered installs, updates, removals, signed packages, and multi-package repositories all remain future slices — worth stating plainly given how demonstrable WP-REP-001 itself will be.
- **The network-surface decision (§4.2) still has schedule risk if deferred past WP-REP-005.** Nothing blocks WP-REP-001 through WP-REP-004 either way, but a real end-to-end Exchange-to-Repository install stays impossible until it's made.
- **Signing is a genuine trust gap today, not just an unfinished feature.** Every package this platform can currently build or install is, and will remain, unsigned and unverified until WP-REP-004 lands. Fine for RC1's stated scope; should not be allowed to quietly persist once real third-party publishers are anticipated.
- **`FoundationRuntime`'s "only one repository open at a time" constraint (OEP-SPEC-011 §5)** is fine for WP-REP-001 (CLI-triggered, single process, single repository) and will need revisiting only once WP-REP-005's network surface is reached by concurrent installs.
- **Process/velocity mismatch.** `oep_foundation` tracks work as a strict, sequential Sprint/Work-Package/Task pipeline (`TASK.md`/`CURRENT_SPRINT.md`, currently at Work Package 014) with its own AI-assistance discipline. `WP-REP-001` should be handed to that process as its own entry in that sequence (its `CURRENT_SPRINT.md`/`TASK.md` citing `WP-REP-001` the way this program's other repositories cross-reference each other's work package ids), not run as a parallel, uncoordinated track.

---

# 7. Architectural Observations and Recommendations

1. **The user's four stated observations are all confirmed, precisely.** (1) Exchange handles publish/search/download/install-initiation — confirmed, and it's solid: 316 passing tests, real Postgres schema, real REST API. (2) Repository Runtime does not exist — confirmed at every layer (no install logic, no network surface, no registry). (3) `StubRepositoryClient` has served its purpose — confirmed: it correctly let `InstallationService`, the REST API, and now Studio's Exchange workspace be built and tested end-to-end without waiting on a Repository that didn't exist yet, exactly as its own doc comment says. (4) PKG-001's "Repository Fragment" framing does confirm the Repository, not the Exchange, is the long-term content owner — this is stated outright in the spec's own §3 ("The package itself is never the engineering database").
2. **Terminology is now resolved, not just flagged (§0.2/§0.3) — apply both renames before `platform/installer` is written.** `platform/exchange` → `platform/archive`; PKG-001 §5's in-archive `repository/` → `fragment/`. Both are zero-cost today and become real migrations the longer they're deferred.
3. **Confirmed: no `oep_repository`.** Build inside `oep_foundation` (§4.1), as directed. If a network surface is wanted without adding an HTTP dependency to Foundation's core build, a *thin* sibling service is defensible for §4.2/WP-REP-005 — but it should be understood as a transport adapter with no business logic of its own, not a second Repository implementation.
4. **Confirmed: Exchange feature work is paused; this is the right moment.** Every remaining unimplemented piece of the Exchange's own roadmap (real signing, real Repository install, dependency resolution) is downstream of Foundation capability that doesn't exist yet — further Exchange feature work would be building against `StubRepositoryClient` indefinitely, exactly the "placeholder that stops accurately representing the final architecture" CLAUDE.md's Placeholder Philosophy warns against.
5. **WP-REP-001 needs `oep_studio` only for its verification touch, not as a dependency.** The new FFI bindings and the `RepositoryPage`/`ObjectsPage` verification pass are part of WP-REP-001's own exit criteria (§5), not a separate follow-on — but they're the *last* piece of it, and almost all of the slice's real engineering is `oep_foundation`-internal.
6. **The `.oep` package format itself needs no changes**, beyond the one terminology rename in §0.2(b). PKG-001/002 already fully describe what the Repository Runtime consumes; `@oep-exchange/package-cli` already produces conformant archives, including `engineering-demo.oep`, the exact artifact WP-REP-001 installs. This work package program is entirely about the *installer* side, not the format.
7. **Vertical-slice sequencing (§5) trades "engines finished in isolation" for "one real path, then widen it."** The risk this accepts (WP-REP-001's install/merge logic will likely need revisiting once WP-REP-002's dependency resolution or WP-REP-003's update path land) is smaller than the risk it removes (building four unobservable engines before anyone can watch a real package land in a real repository). Recommend keeping this philosophy for WP-REP-002 onward rather than reverting to horizontal phases once WP-REP-001 succeeds.
