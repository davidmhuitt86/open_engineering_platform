# Repository Commit

Introduced in Work Package 012 (STUDIO-TASK-000030 Commit Plan,
STUDIO-TASK-000031 Candidate Conversion, STUDIO-TASK-000032
Transactional Repository Commit, STUDIO-TASK-000033 Commit Report,
including Property Inspector Commit Plan/Commit Report support). This
is the first Knowledge Studio feature that calls the
Foundation Bridge — every prior work package (007–011) was
deliberately Studio-only. Supersedes Work Package 008's `CommitPreview`
entirely (see § Commit Plan for why superseding rather than extending
was the right call).

For the workspace layout and general Knowledge Studio state ownership,
see `docs/KNOWLEDGE_STUDIO.md`. This document covers the Commit
pipeline itself: Commit Plan, Candidate Conversion, Foundation
integration, the Transaction Model, Provenance transfer, the Commit
Report, and this work package's architectural observations.

## Why Repository Commit Was Blocked, Then Unblocked

As of Work Package 011, Foundation's Public C API
(`oep_api.h`, versions through 3) was **deliberately read-only** —
runtime lifecycle, repository status/statistics, object/relationship
enumeration and get-by-id, and search, with zero create/write/commit/
transaction functions. This was not an oversight: Foundation's own
`platform/api/README.md` and `TASK.md` explicitly listed "object/
relationship mutation through the Public C API" as a non-goal through
Work Package 013. Foundation's underlying C++ runtime *did* have
`ObjectStore::create`/`RelationshipStore::create` (used by Foundation's
own CLI, which links the C++ runtime directly), but Foundation's own
architecture-freeze document (`oep_foundation/CLAUDE.md`) forbids a
Studio from bypassing the Public SDK to reach Runtime internals or
using hidden APIs — so that path was never an option here, regardless
of what the C++ layer could technically do.

This was reported as a hard architectural blocker, not resolved with
an independent workaround, per this work package's own instruction:
"If implementation reveals an architectural conflict, ambiguity, or
omission, document it and stop for architectural review." It was
subsequently resolved externally — Foundation's own Work Package 014
("Add Object Mutation, Relationship Mutation, Transactions, and Batch
Mutation to the Public C API") added exactly the missing surface,
confirmed by re-reading the updated `oep_api.h` (`OEP_API_VERSION 4`)
before any Work Package 012 code was written.

## Commit Plan

`CommitPlan` (`lib/knowledge/models/commit_plan.dart`), computed on
demand by `CommitPlanService.computeCommitPlan`
(`lib/knowledge/services/commit_plan_service.dart`) — pure, stateless,
no Foundation I/O — from the Connection Manager's current session,
candidates, relationship candidates, repository-open state, Current
Object List, and Repository Statistics. Never stored, following the
same derived-not-stored discipline every computed model in this
project has used since `CandidateValidationResult` (Work Package 010):
recomputed fresh on every read, exposed as `FoundationServiceState`'s
`commitPlan` getter.

**Supersedes, does not extend, `CommitPreview`.** `CommitPreview`
existed specifically because "Commit remains disabled" (Work Package
008 — Repository Commit was out of scope). Now that a real Commit
exists, one real plan of what a commit will do replaces a separate
simulated preview of what it would have done; keeping both would mean
two overlapping "what would committing do" concepts with no
architectural reason for the split. `commit_preview.dart` was deleted;
`KnowledgeSessionService.computeCommitPreview` was removed entirely
(not deprecated) — all of its logic is superseded by
`CommitPlanService.computeCommitPlan`.

**Fields:**

* `newObjects` — accepted Knowledge Candidates that will become new
  Engineering Objects: not already committed, and of a type Foundation
  has an `oep_object_type_t` entry for (see § Architectural
  Observations).
* `newRelationships` — Relationship Candidates that will become new
  Foundation Relationships: not already committed, with both endpoints
  resolvable to a Foundation object id, either newly committing in this
  same plan or already committed by an earlier commit of this session.
* `existingObjectCount` — how many Engineering Objects already exist in
  the open repository (context, not something this commit touches).
* `mergeOperationCount` — always `0`; no repository-matching/
  duplicate-detection capability exists, the same honest-zero
  `CommitPreview.mergedObjectCount` already used, for the same reason.
* `validationErrors` — blocking findings (no open repository; the open
  repository's name doesn't match the session's `repositoryName`). A
  non-empty list means `canCommit` is `false` regardless of how much
  there is to commit.
* `warnings` — non-blocking findings: candidates still pending review,
  candidates rejected, candidates excluded because their type has no
  Foundation object type, candidates/relationships already committed in
  a previous commit of this session, relationship candidates excluded
  because an endpoint isn't resolvable, and a name that collides with
  an existing Engineering Object (Foundation does not enforce object
  name uniqueness, so this is advisory, not rejected).
* `currentStatistics` — the open repository's `RepositoryStatistics`
  exactly as Foundation reported them, `null` if no repository is open
  or statistics haven't loaded.
* `canCommit` — `true` only when there are no blocking errors *and*
  there is at least one new object or relationship to commit ("Commit
  shall remain disabled until validation succeeds"); an empty plan has
  nothing meaningful to commit even though it isn't, strictly, invalid.

## Candidate Conversion

`CommitConversionService` (`lib/knowledge/services/commit_conversion_service.dart`)
— pure, stateless, no Foundation I/O — computes the exact argument
bundles (`ObjectCreateArgs`/`RelationshipCreateArgs`) a later call to
`FoundationBridge.createObject`/`createRelationship` needs. Kept
separate from `CommitTransactionService` so the conversion rules
(what a candidate's fields become) can be unit-tested without a real
Bridge or repository.

* **Type mapping.** `KnowledgeCandidateType.foundationCategory`
  (`ObjectCategory?`) drives which Foundation object type a candidate
  becomes — see § Architectural Observations for the six types with no
  mapping.
* **Notes preservation.** Foundation's Engineering Object model has no
  field distinct from `description` for `KnowledgeCandidate.notes`
  ("Preserve: ... Notes"). Notes are appended to the description
  (`"$description\n\nNotes: $notes"`, degrading gracefully when either
  is empty) rather than dropped — lossless within Foundation's existing
  fields, since modifying Foundation to add a dedicated field is out of
  scope ("Do not modify OEP Foundation").
* **Author preservation with session fallback.**
  `candidate.author.trim().isEmpty ? sessionAuthor : candidate.author`.
  `RelationshipCandidate` has no author field at all (never added since
  Work Package 008), so relationships always use the session's author
  directly.
* **Provenance via tags.** `oep_object_info_t`/`oep_object_create` has
  no dedicated "provenance" field, so "Only provenance references
  transfer" is satisfied by adding two tags to every created object:
  `knowledge-candidate:<candidateId>` and
  `knowledge-session:<sessionId>` (`CommitConversionService.candidateTagPrefix`/
  `sessionTagPrefix`). No Evidence Region coordinate, Source Material
  file, PDF, or other Workspace-only data ever crosses into Foundation
  — see § Provenance Transfer.

## Foundation Integration

Work Package 012 extends the native bridge and FFI layer with exactly
six new functions — no more (`oep_object_update`/`delete` and
`oep_relationship_update`/`delete`, added by Foundation alongside these
in the same Work Package 014, are not wired into Studio: out of scope,
create is all this work package needed):

| Function | Studio wrapper |
|---|---|
| `oep_object_create` | `FoundationBridge.createObject` |
| `oep_relationship_create` | `FoundationBridge.createRelationship` |
| `oep_transaction_begin` | `FoundationBridge.beginTransaction` |
| `oep_transaction_commit` | `FoundationBridge.commitTransaction` |
| `oep_transaction_rollback` | `FoundationBridge.rollbackTransaction` |
| `oep_transaction_is_active` | `FoundationBridge.isTransactionActive` |

`native/foundation_bridge/oep_foundation_bridge.def` is a plain EXPORTS
list — no C++ wrapper code was needed (`bridge_stub.cpp` stays empty);
adding a function means adding its name to this list, since the DLL
statically links `oep_api` and the `.def` file re-exports whatever
symbol lands in the link. `native/foundation_bridge/CMakeLists.txt`
builds Foundation's modules fresh from the sibling `oep_foundation`
checkout on every build, so Foundation's Work Package 014 commit was
picked up with zero CMake changes.

**New Dart FFI marshaling pattern**: `oep_object_create`'s
`const char* const* tags` parameter is the first `Pointer<Pointer<Utf8>>`
this codebase has marshaled — every prior FFI call only ever marshaled
single strings. `FoundationBridge._allocateTagArray(List<String> tags)`
returns `nullptr` for an empty list (matching the API's "`tags` may be
NULL iff `tag_count` is 0" contract) or allocates and individually
`toNativeUtf8()`'s each element; `_freeTagArray` releases each element
then the array, safe to call with `nullptr`.

## Transaction Model

`CommitTransactionService.execute` (`lib/knowledge/services/commit_transaction_service.dart`)
is the only place that actually calls the Foundation Bridge for a
commit — `CommitPlanService`/`CommitConversionService` remain pure.
Orchestration:

1. Fetch `statisticsBefore` (best-effort).
2. Pre-seed `objectIdByCandidateId`/`objectNameById` from already-
   committed candidates (needed so a relationship whose endpoint was
   committed in an *earlier* commit of this session still resolves).
3. `bridge.beginTransaction()`.
4. For each `CommitPlan.newObjects` candidate: build `ObjectCreateArgs`
   via `CommitConversionService.toObjectCreateArgs`, call
   `bridge.createObject`, record the resulting `object_id`.
5. For each `CommitPlan.newRelationships` relationship: resolve both
   endpoints (from step 4's new objects or step 2's already-committed
   ones — a defensive `StateError` if either is unresolved, since that
   would violate "The Commit Plan represents exactly what Foundation
   will receive"), build `RelationshipCreateArgs`, call
   `bridge.createRelationship`.
6. `bridge.commitTransaction()`.
7. Fetch `statisticsAfter`, return a successful `CommitReport`.

**Explicit transaction primitives, not the batch convenience
functions.** Foundation's Work Package 014 also added
`oep_batch_create_objects`/`oep_batch_create_relationships`, deliberately
not used here: the batch functions only accept homogeneous, pre-known
argument arrays and can't interleave object-then-relationship creation
while capturing each newly-created object's real `object_id` to use as
a *subsequent* relationship's endpoint — a relationship between two
objects being created in the *same* commit needs the first object's
just-assigned id. Explicit `oep_transaction_begin`/sequential creates/
`commit`-or-`rollback` gives full control and directly matches
"Repository Commit shall execute as one logical transaction" as its
own explicit task, distinct from conversion.

**Automatic rollback.** Foundation's documented contract: only one
transaction is active per Runtime handle at a time; every mutation
still writes immediately (Foundation's stores have no staged/
uncommitted concept), but a transaction records undo-info. If any
mutation fails while a transaction is active, Foundation automatically
rolls back and deactivates the transaction before returning the
failure — the caller does not need to (but safely may) call
`oep_transaction_rollback()` itself afterward. `CommitTransactionService`
still calls `_safeRollback` in its `catch` block (checking
`bridge.isTransactionActive` first, swallowing any exception from the
rollback call itself) as defense in depth, not because it's required
for correctness on every failure path.

On any `FoundationBridgeException` or other exception:
`_safeRollback(bridge)`, then a failed `CommitReport` with
`errors: [error.message]` for a `FoundationBridgeException` (never the
raw `technicalDetail`) or a generic professional message otherwise.
`objectsCreated`/`relationshipsCreated` are always empty on failure —
the transaction left the repository unchanged.

## Provenance Transfer

"Only provenance references transfer" (this work package's own text):
every committed Engineering Object carries
`knowledge-candidate:<candidateId>`/`knowledge-session:<sessionId>`
tags (see § Candidate Conversion) tracing it back to the Knowledge
Curation Session that produced it. No Evidence Region coordinate,
Source Material file, PDF content, or any other Workspace-only data
ever crosses into Foundation — Evidence remains entirely within the
Knowledge Workspace, exactly as this work package's architectural
guidance requires.

**Commit tracking, not just provenance.** `KnowledgeCandidate` gained
`committedObjectId: String?`/`committedTime: DateTime?` (+
`isCommitted`); `RelationshipCandidate` gained
`committedRelationshipId: String?`/`committedTime: DateTime?` (+
`isCommitted`) — both persisted with backward-compatible JSON defaults
(`null` when absent, so pre-Work-Package-012 session files still
load). This is how "Knowledge Candidates remain Knowledge Workspace
artifacts after Commit" avoids creating *duplicate* Foundation objects
on a second commit of the same session: "Sessions become historical
engineering records" implies a session may be committed multiple times
over its life, with later commits only touching newly-eligible
(not-yet-committed) candidates/relationships.

`KnowledgeSessionService.buildDuplicate` carries `committedObjectId`/
`committedRelationshipId` over **unchanged**, same as every other
field. This is a deliberate judgment call, not an oversight: the
underlying Foundation object genuinely already exists, so a duplicated
session's already-committed candidates should still read as committed
— re-committing them on the duplicate would create a spurious second
Foundation object for the same real-world thing.

## Commit Report

`CommitReport` (`lib/knowledge/models/commit_report.dart`) is the
permanent record of one commit attempt (success or failure) — unlike
`CommitPlan`, it is **stored, not derived**:
`FoundationServiceState.commitReports: List<CommitReport>` is a real,
append-only list (mirroring `ReviewDecision`'s Work Package 008
audit-log pattern), persisted via `KnowledgeSessionRecord.commitReports`
(backward-compatible default `[]`). `latestCommitReport` is a derived
convenience getter (`commitReports.isEmpty ? null : commitReports.last`).

Fields: `objectsCreated: List<CommittedObjectRecord>` (candidate id,
object id, name, category), `relationshipsCreated: List<CommittedRelationshipRecord>`
(relationship candidate id, relationship id, source/target object id,
type), `objectsMergedCount` (always `0`, same reasoning as
`CommitPlan.mergeOperationCount`), `warnings`, `errors`, `durationMs`,
`statisticsBefore`/`statisticsAfter` (`RepositoryStatistics?`, gained
`toJson`/`fromJson` this work package specifically so a `CommitReport`
can round-trip through `session.json` — this model previously had no
serialization at all, only ever decoded fresh from native structs),
`timestamp`.

`lib/knowledge/workspaces/commit_report_dialog.dart`
(`showCommitReportDialog`) displays the full report and offers "Export
as JSON" via `package:file_selector`'s `getSaveLocation()` — already a
project dependency (used elsewhere for `openFile()`/`getDirectoryPath()`),
so no new package decision was needed; confirmed its exact API shape
(`Future<FileSaveLocation?> getSaveLocation({...})`,
`FileSaveLocation.path`) by reading the installed package source
directly before using it.

The Commit Summary panel (`lib/knowledge/workspaces/commit_preview_panel.dart`
— same file/class name as Work Package 008's, now backed by `CommitPlan`
instead of `CommitPreview`) shows a confirmation dialog before calling
`commitToFoundation()` (a real, hard-to-reverse Foundation write), and
opens the Commit Report dialog automatically once the attempt
completes.

## Architectural Observations

* **The `KnowledgeCandidateType` → `ObjectCategory` mapping gap is now
  load-bearing.** Foundation's `oep_object_type_t` has exactly 6
  values (Document/Diagram/Component/Procedure/Project/Image, mirrored
  by `ObjectCategory`), but `KnowledgeCandidateType` has 10 (Work
  Package 010 added Specification/Tool/Material/Fluid/Warning/
  Measurement). Only 4 map 1:1. This gap was first flagged as an
  architectural observation in Work Package 008 and restated in Work
  Package 010's docs, but neither work package needed a real answer —
  no actual conversion existed yet. Work Package 012 makes it
  load-bearing: real Commit needs a real answer for every candidate,
  every time. Resolved by adding a nullable
  `KnowledgeCandidateType.foundationCategory` getter (`ObjectCategory?`,
  `null` for the six unmapped types) rather than modifying Foundation's
  fixed enum (forbidden) or inventing a lossy substitute mapping (e.g.
  Tool → Component, which would misrepresent what the candidate
  actually is). `CommitPlanService` excludes candidates with
  `foundationCategory == null` from "New Engineering Objects" with an
  explicit warning, never silently reinterpreting them. The underlying
  taxonomy mismatch remains open for whoever extends Foundation's
  object types next.
* **Notes preservation via description-merge is lossless-within-
  existing-fields, not a perfect fit.** A future engineer reading a
  committed object's description will see `"Notes: ..."` appended
  rather than a distinct field — an acceptable trade-off given
  modifying Foundation's Engineering Object model is out of scope, but
  worth knowing if `description`-based search or display ever assumes
  the field contains *only* the candidate's description.
  `RelationshipCandidate` was never given a `notes` field in any prior
  work package, so this only applies to objects.
  `docs/KNOWLEDGE_SESSION_FORMAT.md`.
* **`buildDuplicate`'s commit-tracking carry-over is a judgment call,
  not an oversight.** See § Provenance Transfer above for the
  reasoning; flagged here explicitly since it's easy to assume
  "duplicate" should mean "fully independent, uncommitted copy" and it
  deliberately does not for already-committed candidates.
* **Explicit transaction primitives over batch functions** — see
  § Transaction Model. This is the one place this work package chose
  *which* native API functions to use rather than which package to add
  (no Flutter package was needed for Repository Commit itself).
* **Manual verification's `integration_test` run completed the real
  commit successfully — twice — but the test harness itself stalled
  afterward before reporting results**, timing out at the 5-minute
  mark on both attempts even though the `oep_studio.exe` process had
  already exited normally with no crash and no lock file left behind.
  Direct inspection of the scratch repository's persisted JSON
  (`repository/objects/*.json`, `repository/relationships/*.json`) and
  independent cross-checks against Foundation's own CLI
  (`oep object list`/`oep relationship list --repository <path>`)
  both confirmed the commits were correct in every detail (name, type,
  author, provenance tags, resolved relationship endpoints) — this is
  a `flutter test ... -d windows` `integration_test` reporting
  reliability issue in this environment, consistent with this
  project's other documented Windows-desktop test-tooling friction
  (native folder-picker dialogs, `computer-use` access), not a Studio
  defect. Recommendation for future work packages needing to verify a
  real Foundation write: cross-check the repository's on-disk state
  and/or Foundation's own CLI directly, rather than relying solely on
  the `integration_test` process's own pass/fail reporting.

## Flutter Package Decisions

No new Flutter package was added for Repository Commit itself — the
Commit Report's "Export as JSON" reuses `package:file_selector`
(already a dependency since Work Package 002/008), and every other
piece of this work package is either pure Dart logic
(`CommitPlanService`/`CommitConversionService`) or Foundation Bridge
FFI calls (`CommitTransactionService`), for which "prefer Flutter
framework widgets / a mature package" doesn't apply — there is no
third-party package for calling a project's own native DLL.
