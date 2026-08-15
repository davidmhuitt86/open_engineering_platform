# SDD-006

# Foundation Bridge

Version: 1.0

Status: Draft

---

# Purpose

The Foundation Bridge isolates Flutter from the native Foundation implementation.

The Bridge provides a stable interface between Studio and Foundation.

---

# Architecture

Flutter Widgets

↓

Studio Services

↓

Foundation Bridge

↓

Foundation Runtime

↓

Repository

---

# Responsibilities

The Foundation Bridge shall:

* Initialize Foundation Runtime
* Open repositories
* Close repositories
* Execute commands
* Translate native errors
* Convert Foundation data into Flutter models

The Bridge shall not contain engineering business logic.

---

# Platform Independence

The Foundation Bridge abstracts:

* Windows
* Linux
* macOS
* Android

Future platforms may be supported without modifying Studio features.

---

# Error Translation

Native Foundation errors shall be converted into user-friendly Studio messages.

Internal implementation details shall never be displayed.

---

# Future Expansion

The Bridge shall support:

* FFI
* Native plugins
* Remote Foundation instances

without requiring changes to Studio features.

---

# Engineering Principle

Studio depends on the Foundation Bridge.

The Foundation Bridge depends on Foundation.

Studio shall never depend directly upon Foundation.

---

# Implementation (Work Package 002)

Implemented in `lib/core/foundation/`:

* `oep_api_native_types.dart` — `dart:ffi` struct/typedef layer mirroring
  `oep_api.h` field-for-field. The only file besides `oep_api_bindings.dart`
  that references native layout details.
* `oep_api_bindings.dart` — loads `oep_foundation_bridge.dll` and exposes
  one typed Dart function per `oep_api.h` function. No marshaling beyond
  what `dart:ffi` does automatically.
* `oep_api_types.dart` — plain Dart enums/classes
  (`FoundationRuntimeState`, `FoundationErrorCode`,
  `FoundationErrorCategory`, `RepositoryStatus`) decoded once from native
  structs. Nothing above this layer touches a `Pointer`.
* `foundation_bridge_exception.dart` — translates `(error_code,
  error_category)` into a curated, user-facing message. The native
  `error_message` is kept as `technicalDetail` for logging only and is
  never shown in the UI.
* `foundation_bridge.dart` — the public `FoundationBridge` class: owns
  one native `OEP_Runtime` handle, exposes `initialize`/`openRepository`/
  `closeRepository`/`shutdown`/`getRepositoryStatus`/`dispose` plus the
  three version getters. Every fallible call funnels through
  `_checkResult`, which throws `FoundationBridgeException` on failure —
  callers never see a raw `oep_result_t`.

`lib/core/services/foundation_runtime_service.dart` is the sole owner of
a `FoundationBridge` instance (a Riverpod `Notifier`); no other file
constructs one.

## Public C API Usage

Only `oep_api.h`'s declared functions are called, in this order for a
typical session:

```
oep_runtime_create(oep_foundation_version())   -> OEP_Runtime
oep_runtime_initialize(runtime)                -> Initialized
oep_runtime_open_repository(runtime, path)     -> RepositoryOpen
oep_runtime_get_repository_status(runtime, &status)
oep_runtime_close_repository(runtime)          -> RepositoryClosed
oep_runtime_shutdown(runtime)                  -> Shutdown
oep_runtime_destroy(runtime)
```

`FoundationBridge.create()` reads `oep_foundation_version()` itself and
passes that value straight into `oep_runtime_create`, so the version
string is never hardcoded on the Studio side.

## Native DLL

Foundation's own build (`oep_foundation/platform/api/CMakeLists.txt`)
only produces `oep_api` as a static library — correct for a C++
consumer like the CLI, but unusable by `dart:ffi`, which requires a
dynamic library. `native/foundation_bridge/` (in this repository) builds
`oep_foundation_bridge.dll`: it compiles Foundation's existing CMake
modules unmodified (as a sibling-repository reference,
`OEP_FOUNDATION_SOURCE_DIR`, overridable) and links `oep_api` into a
shared library. The exported symbol list comes from
`oep_foundation_bridge.def` — CMake's `WINDOWS_EXPORT_ALL_SYMBOLS` was
tried first but only scans a target's own object files, not ones pulled
in from a linked static library, so it produced an empty export table.
`windows/CMakeLists.txt` and `windows/runner/CMakeLists.txt` build this
DLL as part of `flutter build windows` and copy it next to
`oep_studio.exe`.

No `oep_foundation` source file is modified by any of this.

## Ownership Rules

* `native/foundation_bridge/` may reference Foundation's CMake modules
  and `oep_api.h` (build-time plumbing only).
* `lib/core/foundation/` may reference only `oep_api.h`'s declared
  surface (mirrored into the native-types file) — no other Foundation
  header, and no Foundation C++ type.
* `lib/core/services/` and everything in `lib/features/` may reference
  only `lib/core/foundation`'s public Dart types
  (`FoundationBridge`, `FoundationRuntimeState`, `RepositoryStatus`,
  `FoundationBridgeException`) — never `dart:ffi` directly.

## Data Conversion

`oep_repository_status_t` is decoded once, in `RepositoryStatus.fromNative`,
into an immutable Dart object with no native memory attached. Fixed
`char[]` fields are decoded by scanning for the first NUL byte and UTF-8
decoding the bytes before it (`decodeFixedCString`), matching the C
API's guarantee that every string field is NUL-terminated and truncated
(never overflowed) by Foundation.

---

# Extension (Work Package 004): Object Enumeration + Statistics

`oep_api.h` gained Engineering Object Enumeration and Repository
Statistics (Foundation's own Work Package 012) between Work Packages
003 and 004; `OEP_API_VERSION` moved from 1 to 2. Studio consumed the
new surface without any Foundation change.

## New Public C API Surface Consumed

* `oep_object_type_to_string`
* `oep_object_store_get_count`
* `oep_object_store_get_by_id`
* `oep_object_store_list` / `oep_object_list_release`
* `oep_runtime_get_repository_statistics`

All six are added to `native/foundation_bridge/oep_foundation_bridge.def`
(verified with `dumpbin /EXPORTS` — 20 symbols total) and to
`oep_api_native_types.dart`/`oep_api_bindings.dart` following the exact
pattern the existing functions established.

## New Native Structs

* `OepObjectInfoNative` mirrors `oep_object_info_t`, including the one
  new pattern this work package introduced: a 2D fixed array
  (`char tags[16][64]`), declared as `@Array(16, 64) external
  Array<Array<Uint8>> tags`. Indexing it (`native.tags[i]`) requires
  `dart:ffi`'s `ArrayArray` extension, which — unlike the type itself —
  is **not** visible transitively through another file's import; any
  file that indexes a nested `Array<Array<T>>` needs its own `import
  'dart:ffi';`, even if the struct type came from elsewhere.
* `OepObjectListNative` mirrors `oep_object_list_t` — the one struct in
  this API with a Foundation-owned heap pointer (`items`). Always
  paired with `oep_object_list_release`; never `malloc.free`'d.
* `OepRepositoryStatisticsNative` mirrors `oep_repository_statistics_t`,
  including `object_count_by_type[6]` (`@Array(6) external
  Array<Int32> objectCountByType`), decoded into a
  `Map<ObjectCategory, int>` keyed by `ObjectCategory.nativeValue`.

## New FoundationBridge Methods

`getRepositoryStatistics()`, `getObjectCount()`, `getObjectById(id)`,
`listObjects()` — same pattern as the Work Package 002 methods
(`malloc` an out-parameter, call, decode, `malloc.free` in `finally`),
except `listObjects()`, which additionally calls
`oep_object_list_release` on the Foundation-owned array before freeing
the out-parameter struct itself.

## Enumeration Workflow

```
FoundationRuntimeNotifier.openRepository(path)
  -> bridge.openRepository(path)          [must succeed, or the whole call throws]
  -> bridge.getRepositoryStatus()         [must succeed, or the whole call throws]
  -> _refreshRepositoryData(bridge):
       -> bridge.getRepositoryStatistics()  [failure is non-fatal — see below]
       -> bridge.listObjects()              [failure is non-fatal — see below]
```

Opening the repository itself is the only step whose failure aborts the
whole operation (rethrown so the Dashboard can show a dialog).
Statistics and enumeration are fetched immediately afterward but their
failure only clears the corresponding state field
(`repositoryStatistics`/`objectList` become `null`) — per Work Package
004's error handling rule, a failed enumeration degrades to an
empty-state message, it does not fail repository opening or crash the
app.

## Statistics Workflow

`RepositoryStatistics.objectCountByCategory` is a `Map<ObjectCategory,
int>` built once from `object_count_by_type[6]`, keyed by
`ObjectCategory.nativeValue` (not Dart enum declaration order, which is
the required *display* order — Components, Documents, Diagrams,
Procedures, Images, Projects — and intentionally differs from
`oep_object_type_t`'s ordinal order). The Repository Explorer reads
this map directly; it never counts `objectList` entries itself, per
"Studio must never recompute these values itself" (`platform/api/README.md`).

## Object Selection Lifecycle

`selectCategory`/`selectObject`/`clearObjectSelection` on the
Connection Manager (`lib/core/services/foundation_runtime_service.dart`)
are pure local state mutations — no Foundation call. `objectList`
already contains full object detail (name, author, version,
description, tags), so selecting a row never needs a follow-up
`oep_object_store_get_by_id` call; that function is only exposed for a
future direct-lookup use case (e.g. resolving a Relationship's
target), not used yet.

## UI Update Lifecycle

Every consumer (`Dashboard`, `RepositoryPage`, `ObjectsPage`,
`PropertyInspectorPanel`, `StudioStatusBar`) is a `ConsumerWidget`
watching `foundationRuntimeServiceProvider`; none re-fetch or cache
data themselves. A single `openRepository` call updates
`repositoryStatus`/`repositoryStatistics`/`objectList` together, and
every watcher rebuilds from that one state change — there is no
separate "refresh objects" action in this work package.

---

# Work Package 005: No Bridge Changes

Work Package 005 (Relationship Explorer, Search Workspace) made **no**
changes to `native/foundation_bridge/`, `oep_api_bindings.dart`,
`oep_api_native_types.dart`, or `foundation_bridge.dart` — the Public C
API exposes no relationship enumeration or search function yet (see
`docs/CONNECTION_MANAGER.md` § Missing Public API for the exact
functions this work package identified as needed and did not
implement, per its "document it, do not implement it" rule).
`RelationshipSummary` and `SearchResult`
(`lib/core/models/relationship_summary.dart`,
`lib/core/models/search_result.dart`) are plain Dart models with no
`fromNative` constructor, unlike `EngineeringObjectSummary`'s — there
is no native struct yet for either to decode.

---

# Extension (Work Package 006): Engineering Relationship Enumeration + Repository Search

`oep_api.h` gained Engineering Relationship Enumeration (TASK-000025)
and Repository Search (TASK-000026) between Work Packages 005 and 006
(Foundation's own Work Package 013); `OEP_API_VERSION` moved from 2 to
3. Studio consumed the new surface without any Foundation change,
resolving every gap Work Package 005 had documented in
`docs/CONNECTION_MANAGER.md` § Missing Public API.

## New Public C API Surface Consumed

* `oep_relationship_type_to_string`
* `oep_relationship_store_get_count`
* `oep_relationship_store_get_by_id`
* `oep_relationship_store_list` / `oep_relationship_list_release`
* `oep_match_location_to_string`
* `oep_search_repository` / `oep_repository_search_result_release`
* `oep_search_objects` / `oep_object_search_result_list_release`
* `oep_search_relationships` / `oep_relationship_search_result_list_release`

All twelve are added to `native/foundation_bridge/oep_foundation_bridge.def`
(verified with `dumpbin /EXPORTS` — 32 symbols total; several
release-function RVAs collapse to the same address in the Release
build, which is the MSVC linker's identical-code-folding optimization
for byte-identical function bodies, not a build error). `oep_relationship_type_to_string`,
`oep_relationship_store_get_by_id`, and `oep_match_location_to_string`
are bound (mirroring how `oep_object_type_to_string` and
`oep_object_store_get_by_id` were bound in Work Package 004) but
unused — Studio decodes `relationship_type`/`match_location` via its
own `RelationshipType.fromNative`/`SearchMatchLocation.fromNative`
(mirroring `ObjectCategory.fromNative`), and no code path needs a
single-relationship lookup since `relationshipList` already carries
full detail.

## New Native Structs

* `OepRelationshipInfoNative` mirrors `oep_relationship_info_t`.
* `OepRelationshipListNative` mirrors `oep_relationship_list_t` — same
  Foundation-owned-heap-array ownership model as `oep_object_list_t`.
* `OepObjectSearchResultNative`/`OepObjectSearchResultListNative` and
  `OepRelationshipSearchResultNative`/`OepRelationshipSearchResultListNative`
  mirror `oep_object_search_result_t`/`_list_t` and
  `oep_relationship_search_result_t`/`_list_t`.
* `OepRepositorySearchResultNative` mirrors `oep_repository_search_result_t`,
  whose two C members (`oep_object_search_result_list_t objects`,
  `oep_relationship_search_result_list_t relationships`) are each just
  `{pointer; int32;}`. Rather than nesting the two list structs as
  struct-typed fields, this flattens both into four top-level fields in
  the same declaration order — the platform ABI lays out nested
  structs-by-value as their members concatenated in order, so this
  produces an identical byte layout without depending on dart:ffi
  struct-of-struct field support (untested in this codebase before now).

## New FoundationBridge Methods

`getRelationshipCount()`, `getRelationshipById()`, `listRelationships()`
follow the Work Package 004 object-enumeration pattern exactly.
`searchObjects()`, `searchRelationships()`, and `searchRepository()`
follow the same `malloc`/call/decode/release/`malloc.free` pattern;
`searchRepository()` returns a single `List<SearchResult>` — every
object hit followed by every relationship hit, each group in exactly
Foundation's own order (never interleaved or re-sorted), matching
`oep_repository_search_result_t`'s own two-list shape and `oep
search`'s CLI presentation convention.

### Relationship Name Resolution

`oep_relationship_info_t`/`oep_relationship_search_result_t` carry only
`source_object_id`/`target_object_id` — no display name, unlike
`oep_object_search_result_t::display_name`. `RelationshipSummary.fromNative`
and `SearchResult.fromNativeRelationship` both accept an
`objectNamesById` map (built by `FoundationRuntimeNotifier._objectNamesById()`
from the already-fetched Current Object List) to resolve display names,
falling back to the raw ID if the object can't be found there (e.g. the
object list fetch failed independently). This is a presentation-layer
join across two already-Foundation-returned lists, not independent
business logic — see `docs/CONNECTION_MANAGER.md` § Foundation
Interaction.

## Relationship Enumeration Workflow

```
FoundationRuntimeNotifier._refreshRepositoryData(bridge):
     -> bridge.getRepositoryStatistics()  [failure non-fatal]
     -> bridge.listObjects()              [failure non-fatal]
     -> bridge.listRelationships(objectNamesById: _objectNamesById())  [failure non-fatal]
```

Relationships are fetched *after* objects specifically so name
resolution has the freshest object list available; if the object fetch
itself failed, relationships still get fetched, just with source/target
names falling back to raw IDs rather than the whole operation failing.

## Search Workflow

```
SearchPage._runSearch(query)
  -> FoundationRuntimeNotifier.search(query, scope: SearchScope.{repository,objects,relationships})
       -> bridge.searchRepository/searchObjects/searchRelationships(...)
       -> state.copyWith(searchQuery: query, searchResults: results)  [only on success]
```

Unlike relationship retrieval, a failed search does not touch
`searchQuery`/`searchResults` — it rethrows so `SearchPage` can show
`showFoundationErrorDialog` (Work Package 006: "If search fails:
Display a professional error dialog"), per `docs/CONNECTION_MANAGER.md`
§ Error Handling.

---

# Extension (Work Package 012): Object/Relationship Mutation + Transactions

`oep_api.h` gained Object Mutation, Relationship Mutation, Transactions,
and Batch Mutation (Foundation's own Work Package 014) between Studio's
Work Packages 011 and 012; `OEP_API_VERSION` moved from 3 to 4. Unlike
Work Packages 004/006 above, this surface did **not** already exist
when this work package began — its absence was reported as a hard
architectural blocker and resolved externally by Foundation adding it
mid-work-package. See `docs/REPOSITORY_COMMIT.md` § Why Repository
Commit Was Blocked, Then Unblocked for the full account.

## New Public C API Surface Consumed

* `oep_object_create`
* `oep_relationship_create`
* `oep_transaction_begin` / `oep_transaction_commit` /
  `oep_transaction_rollback` / `oep_transaction_is_active`

**Not consumed**, deliberately: `oep_object_update`/`oep_object_delete`/
`oep_relationship_update`/`oep_relationship_delete` (Repository Commit
only needed create), and `oep_batch_create_objects`/
`oep_batch_create_relationships` (the batch functions can't interleave
object-then-relationship creation while resolving a same-commit
object's freshly-assigned id as a relationship endpoint — see
`docs/REPOSITORY_COMMIT.md` § Transaction Model).

All six are added to `native/foundation_bridge/oep_foundation_bridge.def`.

## New Native Types

No new structs — `oep_object_create`/`oep_relationship_create` populate
an `oep_object_info_t`/`oep_relationship_info_t` (the same structs
`EngineeringObjectSummary.fromNative`/`RelationshipSummary.fromNative`
already decode for the read APIs), so no new native-type declarations
were needed beyond the function typedefs themselves
(`OepObjectCreateNative`/`Dart`, `OepRelationshipCreateNative`/`Dart`,
`OepTransactionBegin/Commit/Rollback/IsActiveNative`/`Dart`).

**New marshaling pattern**: `oep_object_create`'s `const char* const*
tags` is the first `Pointer<Pointer<Utf8>>` parameter this codebase has
marshaled — every prior function only ever took single strings.
`FoundationBridge._allocateTagArray`/`_freeTagArray` handle it,
including the `tags` may be `NULL` iff `tag_count` is `0` contract.

## New FoundationBridge Methods

`createObject(...)`, `createRelationship(...)`, `beginTransaction()`,
`commitTransaction()`, `rollbackTransaction()`, `isTransactionActive`
follow the existing `_assertNotDisposed()` → marshal → `_checkResult(...)`
→ decode-and-return → `finally { malloc.free(...) }` pattern every
prior Bridge method uses. See `docs/REPOSITORY_COMMIT.md` § Foundation
Integration and § Transaction Model for the full reference and the
orchestration that calls them.
