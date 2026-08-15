# API

Status: Foundation (Public C API + Bridge Support + Repository Content Exposure + Search + Mutation + Package Installation + Trust & Signing + Dependency Resolution + Runtime Service & Repository Events + Package Uninstall & Update + Merge Engine + Engineering Knowledge Runtime + Engineering Knowledge Graph Engine + Engineering Query Engine + Engineering Rules Engine + Engineering Validation Engine + Engineering Analysis & Reasoning Engine + Engineering Intelligence Platform)

Purpose: The Public C API — Foundation's only supported native interface, per OEP-SPEC-021-PUBLIC_C_API — the primitives external Bridge implementations (Flutter, C#, Python, Java, etc.) build on, per OEP-SPEC-022-FOUNDATION_BRIDGE_SUPPORT, the Engineering Object/Relationship enumeration, repository statistics, and search surface OEP Studio and other consumers need (Work Packages 012–013), the first write-capable surface of this API — object/relationship mutation, transactions, and batch mutation (Work Package 014) — and, per WP-REP-001 (Repository Runtime), `.oep` package installation. Every Studio, SDK, and testing tool that isn't the CLI is expected to reach Foundation through this boundary rather than linking `platform/runtime` or `platform/search` C++ types directly.

See [MUTATION_API.md](MUTATION_API.md) for the full mutation/transaction/batch-mutation reference (Work Package 014). This file documents the API's read-only surface, lifecycle, ownership, and Bridge integration guidance in general.

## Architecture

- `include/oep/api/oep_api.h` — the entire public ABI: a pure C header (`extern "C"`), no C++ classes, no STL types, no exceptions
- `src/oep_api_internal.hpp` — private implementation details (the concrete type behind `OEP_Runtime`, error-result helpers, type converters, the shared mutation-error classifier); never installed or exposed
- `src/oep_api.cpp` — implementation, wrapping `oep::runtime::FoundationRuntime`; every exported function catches all exceptions at the boundary and translates them into an `OEP_ERROR_INTERNAL` result rather than letting them propagate
- `manual_test/capi_manual_test.c` — a standalone program, compiled as **plain C** (not C++), that exercises the API purely through `oep_api.h`. Building and linking a `.c` translation unit against `oep_api` is itself part of Work Package 014's verification: it demonstrates the ABI is genuinely C-callable, not merely C-styled in a way only C++ can actually consume. Run manually (`platform/api/manual_test/oep_capi_manual_test.exe <scratch-directory>`); not part of the CTest regression suite, per Work Package 014's explicit separation of "Complete regression suite" from "Manual verification through a standalone C API test program."

Built as a static library, `oep_api`, linked privately against `oep_runtime` — consumers of `oep_api` only ever see `oep_api.h`; they never need (and cannot easily obtain) `platform/runtime`'s C++ headers.

## API Lifecycle

```c
OEP_Runtime runtime = oep_runtime_create("0.1.0");   /* Uninitialized */
oep_runtime_initialize(runtime);                      /* -> Initialized */
oep_runtime_open_repository(runtime, "/path/to/repo"); /* -> RepositoryOpen */

oep_repository_status_t status;
oep_runtime_get_repository_status(runtime, &status);

oep_runtime_close_repository(runtime);                /* -> RepositoryClosed */
oep_runtime_shutdown(runtime);                         /* -> Shutdown */
oep_runtime_destroy(runtime);
```

State transitions are deterministic and mirror `FoundationRuntime` exactly (per OEP-SPEC-011-FOUNDATION_RUNTIME, re-exposed per OEP-SPEC-022 section 3):

```text
Uninitialized -> Initialized -> RepositoryOpen -> RepositoryClosed -> Shutdown
                                       |__________________________________^
                                        (RepositoryClosed -> RepositoryOpen again is allowed)
```

Calling a lifecycle function from the wrong state never crashes or corrupts state — it returns a failed `oep_result_t` with `error_code == OEP_ERROR_INVALID_STATE`, and the Runtime's state is unchanged.

## Engineering Object Enumeration (Work Package 012, TASK-000023)

While a repository is open, Engineering Objects can be counted, enumerated, and looked up by ID without touching `platform/repository`'s C++ types:

```c
int count = 0;
oep_object_store_get_count(runtime, &count);

oep_object_info_t widget;
oep_object_store_get_by_id(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", &widget);

oep_object_list_t all_objects;
oep_object_store_list(runtime, &all_objects);
for (int i = 0; i < all_objects.count; ++i) {
    printf("%s\t%s\n", all_objects.items[i].object_id, all_objects.items[i].name);
}
oep_object_list_release(&all_objects); /* required after a successful oep_object_store_list */
```

`oep_object_info_t` is a fixed-layout, pointer-free structure (`object_id`, `object_type`, `name`, `author`, `version`, `description`, and up to `OEP_MAX_OBJECT_TAGS` tags) — every string field is a fixed-size buffer, truncated rather than overflowed if the underlying value is longer. `oep_object_store_list` always returns objects sorted deterministically by `object_id` (ascending, byte-wise), so repeated enumeration of an unchanged repository always produces the same order — Bridges and Studio should rely on this instead of re-sorting client-side.

**Memory ownership:** `oep_object_store_get_count` and `oep_object_store_get_by_id` allocate nothing — the former writes an `int`, the latter fills a caller-supplied `oep_object_info_t`. `oep_object_store_list`, however, allocates a heap array (`oep_object_list_t::items`) sized to the repository's object count; on success, the caller owns that array and **must** release it with exactly one call to `oep_object_list_release`, never with `free`/`delete` directly (it was allocated with `new[]` on the Foundation side of the ABI boundary, and only Foundation's own release function is guaranteed to match the allocator that produced it). A list that was never successfully populated (`items == NULL`, `count == 0`) is always safe to pass to `oep_object_list_release` — releasing it is a no-op, not an error.

**Performance:** `oep_object_store_list` performs a full directory enumeration and one heap allocation sized to the object count every call — it is not cached. For a single object, prefer `oep_object_store_get_by_id` over listing everything and searching client-side.

## Repository Statistics (Work Package 012, TASK-000024)

```c
oep_repository_statistics_t statistics;
oep_runtime_get_repository_statistics(runtime, &statistics);

printf("%d objects, %d relationships, %d packages\n",
       statistics.total_object_count, statistics.relationship_count, statistics.package_count);
printf("%d Components\n", statistics.object_count_by_type[OEP_OBJECT_TYPE_COMPONENT]);
```

`oep_repository_statistics_t` is a fixed-layout structure carrying repository identity (`repository_id`/`repository_name`/`repository_version`), `total_object_count`, `object_count_by_type` (indexed by `oep_object_type_t`), `relationship_count`, and `package_count` (every discovered package, regardless of Loaded/Invalid/Disabled state — distinct from `oep_repository_status_t::loaded_package_count`, which counts only `Loaded` packages). Every count is computed by Foundation from the currently open repository; Studio (or any other consumer) must never recompute these values itself by enumerating objects/relationships/packages client-side — doing so would duplicate logic this API already provides deterministically. No allocation is involved; `oep_runtime_get_repository_statistics` fills a caller-supplied structure, same as `oep_runtime_get_repository_status`.

**Performance:** computing statistics requires one full enumeration each of objects, relationships, and packages — proportional to repository size, not cached across calls. Callers that need statistics repeatedly (e.g. a Dashboard polling for updates) should poll at a sensible interval rather than every frame.

## Engineering Relationship Enumeration (Work Package 013, TASK-000025)

Mirrors Engineering Object Enumeration exactly, over Relationships instead of Objects:

```c
int count = 0;
oep_relationship_store_get_count(runtime, &count);

oep_relationship_info_t relationship;
oep_relationship_store_get_by_id(runtime, "a1cc95de-a335-4231-9e59-2ce396f7863c", &relationship);

oep_relationship_list_t all_relationships;
oep_relationship_store_list(runtime, &all_relationships);
for (int i = 0; i < all_relationships.count; ++i) {
    printf("%s -> %s\n", all_relationships.items[i].source_object_id, all_relationships.items[i].target_object_id);
}
oep_relationship_list_release(&all_relationships);
```

`oep_relationship_info_t` is a fixed-layout, pointer-free structure (`relationship_id`, `source_object_id`, `target_object_id`, `relationship_type`, `author`, `description`, `created_utc`). `oep_relationship_store_list` sorts deterministically by `relationship_id` (ascending, byte-wise), for the same reason `oep_object_store_list` does: the underlying `RelationshipStore::list_all()` has no defined order, so the API boundary imposes one.

**Memory ownership:** identical model to Engineering Object Enumeration — `oep_relationship_store_get_count`/`oep_relationship_store_get_by_id` allocate nothing; `oep_relationship_store_list` allocates `oep_relationship_list_t::items` and must be paired with exactly one call to `oep_relationship_list_release`.

**Performance:** same characteristics as `oep_object_store_list` — a full enumeration and one allocation per call, proportional to relationship count, not cached.

## Repository Search (Work Package 013, TASK-000026)

```c
oep_object_search_result_list_t objects;
oep_search_objects(runtime, "ignition", &objects);
for (int i = 0; i < objects.count; ++i) {
    printf("%s (%s, score %.2f)\n", objects.items[i].display_name,
           oep_match_location_to_string(objects.items[i].match_location), objects.items[i].match_score);
}
oep_object_search_result_list_release(&objects);

oep_repository_search_result_t combined;
oep_search_repository(runtime, "ignition", &combined);
/* combined.objects and combined.relationships are populated independently */
oep_repository_search_result_release(&combined);
```

Three search entry points mirror `oep search`'s own three forms exactly:

- `oep_search_repository` — both Engineering Objects and Relationships, returned as **two separate lists** (`oep_repository_search_result_t::objects`/`::relationships`), never merged or interleaved — matching `oep search`'s own "Objects: ... / Relationships: ..." presentation, and sidestepping any question of how to rank an object hit against a relationship hit.
- `oep_search_objects` — Engineering Objects only.
- `oep_search_relationships` — Relationships only.

All three take a single `query` string; per Work Package 013's explicit scope, filtering by author, tag, or object type is **not** part of this API and remains a caller (Studio) responsibility applied to the returned results, exactly as the CLI's `--type`/`--author`/`--tag` flags already do client-side after `SearchEngine` returns.

**Result ordering is never altered by this API.** `oep_object_search_result_t`/`oep_relationship_search_result_t` are returned in exactly the order `oep::search::SearchEngine` produced them (descending match score, then index order for ties) — the Public API performs a direct, one-to-one field conversion into fixed C structures and nothing more. A Bridge or Studio must not re-sort search results and expect them to still reflect Foundation's ranking.

`oep_match_location_t` mirrors `oep::search::MatchLocation` (`Name`/`Description`/`Author`/`Tags`/`ObjectType`/`RelationshipType`); `match_score` is the same `double` `SearchEngine` computes internally.

A `query` that is `NULL` or empty fails with `OEP_ERROR_INVALID_ARGUMENT` (`SearchEngine::search_objects`/`search_relationships` themselves reject an empty query) — this is a genuinely invalid argument case, not a "no results" case, and the two are never conflated: a valid, non-matching query still succeeds and simply returns a zero-length list.

**Memory ownership:** `oep_search_objects`/`oep_search_relationships` each allocate one heap array (`oep_object_search_result_list_t::items` / `oep_relationship_search_result_list_t::items`), released via `oep_object_search_result_list_release`/`oep_relationship_search_result_list_release`. `oep_search_repository` allocates **two** independent arrays inside `oep_repository_search_result_t`, both released together by exactly one call to `oep_repository_search_result_release` — do not release the two lists individually and then call the combined release function, or the second release will be a safe no-op on already-NULL pointers (harmless, but redundant).

**Performance:** each call performs a full search over the in-memory index built at `open_repository` time (see `platform/search`'s `SearchEngine::build_index`) plus one allocation per result list — proportional to repository size and match count, not cached across calls.

## Object/Relationship Mutation, Transactions, Batch Mutation (Work Package 014)

The first write-capable surface of this API. Full reference (usage, exact undo semantics, error classification table, and out-of-scope boundaries) lives in [MUTATION_API.md](MUTATION_API.md); summary:

- **Object mutation** — `oep_object_create`/`oep_object_update`/`oep_object_delete`, delegating to new `FoundationRuntime::create_object`/`update_object`/`delete_object` methods, which delegate to `ObjectStore` unchanged. `object_type`/`object_id`/creation timestamp are immutable on update, matching `ObjectStore::update`'s own contract exactly.
- **Relationship mutation** — `oep_relationship_create`/`oep_relationship_update`/`oep_relationship_delete`, mirroring object mutation exactly; only `author`/`description` are mutable on update, matching `RelationshipStore::update`.
- **Transactions** — `oep_transaction_begin`/`_commit`/`_rollback`/`_is_active`. A transaction groups mutations into one deterministically reversible unit: each mutation still writes immediately (no staged-write concept was added to `ObjectStore`/`RelationshipStore`), but while a transaction is active, `FoundationRuntime` records a compensating action per mutation (the pre-update or pre-delete record, or the created record's ID) and replays that log in reverse on rollback, using the same `remove`/`update`/`restore` methods a normal mutation would use. Only one transaction may be active per handle; any mutation failure while a transaction is active automatically rolls it back.
- **Batch mutation** — `oep_batch_create_objects`/`oep_batch_create_relationships`, a convenience layer over the transaction primitives: every spec is created in array order inside a transaction, committed on full success, rolled back completely on any failure.

Every mutation and transaction method added to `FoundationRuntime` for this section is a thin orchestration layer: it decides which `ObjectStore`/`RelationshipStore` method to call and, when relevant, what to log for rollback — it never re-implements `validate_object`/`validate_relationship` or any other rule Foundation's Repository layer already enforces.

## Package Installation (Work Package WP-REP-001, Repository Runtime)

The first vertical slice of the Foundation Repository Runtime: installing a valid `.oep` package — extracting its Repository Fragment (Engineering Objects and Relationships), registering them into the open repository, updating the Search/Graph indexes, and recording the install in the Package Registry.

```c
oep_package_install_result_t install_result;
oep_package_install(runtime, "/path/to/engineering-demo.oep", &install_result);
printf("Installed %s %s: %d objects, %d relationships\n",
       install_result.package_id, install_result.version,
       install_result.objects_created, install_result.relationships_created);

oep_installed_package_list_t installed;
oep_package_list_installed(runtime, &installed);
for (int i = 0; i < installed.count; ++i) {
    printf("%s %s (%s)\n", installed.items[i].package_id, installed.items[i].version, installed.items[i].source);
}
oep_installed_package_list_release(&installed);
```

`oep_package_install` delegates entirely to `FoundationRuntime::install_package`, which: opens the archive via `oep::installer::ZipReader` (ZIP "Stored"/uncompressed entries only — DEFLATE is rejected), validates and parses `manifest/package.json` per PKG-002, parses every `repository/objects/*.json` and `repository/relationships/*.json` entry, creates each via the existing `ObjectStore::create`/`RelationshipStore::create` (archive-declared IDs are preserved, not remapped), rebuilds the Search and Graph indexes, and records one entry in the Package Registry (`oep::installer::PackageRegistry`, `<repository>/packages/<packageId>/registry.json`).

**Explicitly out of scope for this Work Package** (see `platform/installer/README.md` for the full rationale): dependency resolution, transactions/atomicity (a failure partway through an install is **not** rolled back — prior successful creates remain in place), merge/ownership logic, digital signature verification, networking, update, and uninstall. `oep_package_install` is not wrapped in `oep_transaction_begin`/`commit`/`rollback` — this is a deliberate scope decision, not an oversight.

`oep_package_list_installed` returns every Repository Registry record for the open repository (package ID, version, title, install timestamp, source, object/relationship counts), sorted deterministically by `package_id` (ascending, byte-wise), matching the sorting convention every other list-returning function in this API already follows.

## Package Lifecycle Queries (WP-REP-002, Repository Registry & Lifecycle)

Read-only queries over the Repository Registry — the authoritative inventory of every `.oep` package installed in the open Foundation Repository. Nothing here mutates; update, uninstall, and activation remain out of scope through WP-REP-002.

```c
oep_package_details_t details;
oep_package_get_info(runtime, "com.oep.demo.engineering-showcase", &details);
printf("%s %s by %s — state %s, hash %s\n", details.title, details.version,
       details.publisher_name, details.runtime_state, details.package_hash);

oep_object_list_t objects; oep_relationship_list_t relationships;
oep_package_get_contents(runtime, "com.oep.demo.engineering-showcase", &objects, &relationships);
/* ... */
oep_object_list_release(&objects);
oep_relationship_list_release(&relationships);

oep_package_owner_t owner;
oep_package_locate(runtime, "f8c97088-71d9-4f34-969f-b5d49d951627", &owner);

oep_package_verify_result_t verified;
oep_package_verify(runtime, "com.oep.demo.engineering-showcase", &verified);

oep_installed_package_list_t matches;
oep_package_search(runtime, "ignition", &matches);
oep_installed_package_list_release(&matches);
```

- `oep_package_get_info` — the full Repository Registry record (`oep_package_details_t`: manifest metadata, publisher, installation date/source/path, SHA-256 package hash, runtime state — always `"Installed"` through WP-REP-002 — engineering domains, contribution counts). Plain, pointer-free value type; no release function. The pre-existing `oep_installed_package_info_t` is retained unchanged for ABI compatibility.
- `oep_package_get_contents` — the package's contributed Engineering Objects and Relationships, loaded **live** from the repository's own stores (the registry records only IDs; Engineering Object data is never duplicated into it). Released with the same `oep_object_list_release`/`oep_relationship_list_release` every other object/relationship list already uses.
- `oep_package_locate` — which installed package owns a given Engineering Object or Relationship ID. An unowned ID succeeds with `found == 0` — a normal answer, not an error.
- `oep_package_verify` — checks every recorded contribution still exists, and (when the source archive still exists at its recorded path) that its bytes still hash to the recorded SHA-256. The verification outcome lives in `oep_package_verify_result_t::verified`, not the `oep_result_t` — only operational problems (not installed, no repository open) fail the call. A missing archive is reported via `archive_available == 0`, not treated as a failure. **The hash is an integrity fingerprint, not a signature** — trust/signing is PKG-005, a future work package.
- `oep_package_search` — case-insensitive substring match over registry metadata (ID/title/summary/category/version/publisher/engineering domains) plus the live names of each package's installed objects. Same result type, sorting, and release function as `oep_package_list_installed`.

## Repository Transaction Engine (WP-REP-003)

WP-REP-003 upgraded the Work Package 014 transaction primitives (`oep_transaction_begin`/`_commit`/`_rollback`/`_is_active` — every signature unchanged) into the Repository Transaction Engine: every transaction has a UUIDv4 identity, every Runtime write outside an explicit transaction runs inside an implicit one, every closed transaction writes a permanent journal record under the repository's `logs/transactions/` directory, and **`oep_package_install` is atomic** — a failure rolls back everything it created, superseding WP-REP-001/002's documented non-transactional behavior.

```c
oep_transaction_info_t info;
oep_transaction_get_info(runtime, &info);           /* active == 0 is a normal answer */

oep_transaction_record_list_t history;
oep_transaction_history(runtime, &history);
for (int i = 0; i < history.count; ++i) {
    printf("%s %s (%s, %d ops)\n", history.items[i].transaction_id, history.items[i].state,
           history.items[i].description, history.items[i].journal_entry_count);
}
oep_transaction_record_list_release(&history);
```

- `oep_transaction_get_info` — the active transaction's id, description, and journaled-operation count. Plain value type, no release function.
- `oep_transaction_history` — every journaled (closed) transaction, sorted by opened time then id; states are `"Committed"`, `"RolledBack"`, or `"Failed"`. Released with exactly one call to `oep_transaction_record_list_release`.
- **One documented behavior change:** `oep_transaction_commit` can now fail in exactly one new way — the journal record could not be written. The mutations are already persisted in that case; the error means the audit trail is incomplete, never that data was lost. A journal problem never prevents a rollback from restoring repository state.

**Memory ownership:** `oep_package_install` allocates nothing beyond the caller-supplied `oep_package_install_result_t` it fills. `oep_package_list_installed` allocates one heap array (`oep_installed_package_list_t::items`), released with exactly one call to `oep_installed_package_list_release` — same ownership model as every other `*_list_t` in this API.

**Errors:** an archive that fails to open, fails ZIP parsing, fails manifest validation, fails trust verification (WP-REP-004, see below), or contains an object/relationship that fails `validate_object`/`validate_relationship` fails the call with `OEP_ERROR_OPERATION_FAILED` (or `OEP_ERROR_INVALID_ARGUMENT` for a missing/empty archive path). Since WP-REP-003, a failure partway through the object/relationship creation loop is fully rolled back (atomic install) rather than leaving partial content in place. A `package_id` already present in the Repository Registry fails with `OEP_ERROR_OPERATION_FAILED` — this Work Package has no update path, so installing the same package twice is rejected outright rather than silently overwriting the prior install.

## Trust & Signing (WP-REP-004, Repository Trust & Signing Subsystem)

Per PKG-005: every `.oep` package is verified offline against this repository's own Trust Store, **before** `oep_package_install` opens any Repository Transaction. A package that is `Tampered`, has an `InvalidSignature`, an `UnknownPublisher`, an `ExpiredCertificate`, or a `RevokedCertificate` is rejected outright. An `Unsigned` package installs exactly as in earlier work packages unless the Trust Store's policy requires signatures.

```c
oep_publisher_certificate_t certificate;
oep_trust_add_certificate(runtime, "demo-publisher", "OEP Demo Publisher",
                           "f0d4c9193230152701be5d342a9cbb922d7b641fbf0be7ff554a4a3067291544",
                           NULL, NULL, NULL, NULL, &certificate);

oep_package_install_result_t install_result;
oep_package_install(runtime, "engineering-demo.oep", &install_result); /* now Trusted */

oep_package_trust_status_t status;
oep_package_get_trust_status(runtime, install_result.package_id, &status);
printf("%s\n", oep_trust_state_to_string(status.state));
```

- `oep_trust_add_certificate` — trusts a publisher certificate (`publisher_id`/`public_key_hex` required; the rest may be `NULL`, treated as empty). Fails if the publisher already has a certificate (renewal is out of scope). The fingerprint is always computed locally (SHA-256 of the raw public key), never taken from a caller-supplied field.
- `oep_trust_get_certificate` — fails with `OEP_ERROR_NOT_FOUND` if the publisher has no certificate on file, matching `oep_object_store_get_by_id`'s "get by known ID" convention.
- `oep_trust_list_certificates` — every certificate, trusted and revoked alike (check `revoked`), sorted by `publisher_id`. Released with `oep_certificate_list_release`.
- `oep_trust_revoke_certificate` — marks the certificate revoked (kept, per PKG-005 §12/§13's retained-history model); does not uninstall anything already installed from that publisher.
- `oep_trust_get_policy`/`oep_trust_set_policy` — whether unsigned packages are rejected at install. Default: `0` (unsigned packages install, matching every earlier work package).
- `oep_package_get_trust_status` — the `TrustState` recorded for an already-installed package at install time (not re-verified on demand). Fails with `OEP_ERROR_NOT_FOUND` if the package isn't installed.
- `oep_trust_state_to_string` — deterministic name for an `oep_trust_state_t` (e.g. `"Trusted"`, `"RevokedCertificate"`).

**Memory ownership:** `oep_publisher_certificate_t` and `oep_package_trust_status_t` are plain, pointer-free value types — no release function. `oep_certificate_list_t` follows the standard allocate-once/release-once model (`oep_certificate_list_release`).

**Deliberately unchanged for backward compatibility:** `oep_package_install_result_t` and `oep_package_details_t` (WP-REP-002) were **not** extended with trust fields — doing so would have changed their layout for every existing caller. Trust status is queried separately via `oep_package_get_trust_status`, following this API's established "add a new struct/function, never modify an existing one" convention (see Versioning below).

## Dependency Resolution (WP-REP-005, Repository Dependency Resolution Engine)

Per PKG-004's package-to-package dependency model (the "Virtual Capability" dependency type is out of scope — no Capability primitive exists yet in Foundation): a dry-run, side-effect-free check of whether a candidate `.oep` archive's declared dependencies are satisfiable against the currently open repository, and the same check enforced by `oep_package_install` itself before any Repository Transaction opens.

```c
oep_dependency_resolution_result_t result;
oep_dependency_entry_list_t entries;
oep_package_id_list_t install_order;
oep_package_resolve_dependencies(runtime, "/path/to/engineering-demo.oep",
                                  &result, &entries, &install_order);

printf("resolvable: %d\n", result.resolvable);
for (int i = 0; i < entries.count; ++i) {
    printf("%s requires %s (%s): %s\n", entries.items[i].dependent_package_id,
           entries.items[i].dependency_package_id, entries.items[i].version_constraint,
           oep_dependency_state_to_string(entries.items[i].state));
}
oep_dependency_entry_list_release(&entries);
oep_package_id_list_release(&install_order);
```

- `oep_package_resolve_dependencies` — opens the archive, parses its manifest, and runs the same resolution pass `oep_package_install` runs internally, against the currently open repository's Repository Registry. All three out-parameters (`out_result`, `out_entries`, `out_install_order`) are nullable — pass `NULL` for any the caller does not need. Performs no writes: no transaction, no registry mutation, nothing extracted into the repository.
- `oep_dependency_resolution_result_t` — plain, pointer-free value type: whether the candidate is resolvable overall (`resolvable`), and counts of satisfied/missing/optional/conflicting/cyclic entries. No release function.
- `oep_dependency_entry_t`/`oep_dependency_entry_list_t` — one entry per declared dependency (dependent package ID, dependency package ID, version constraint, `oep_dependency_state_t`, whether it was declared optional). Released with `oep_dependency_entry_list_release`, following this API's standard allocate-once/release-once model.
- `oep_package_id_t`/`oep_package_id_list_t` — the deterministic topological install order the resolver computed, as a plain list of package IDs. Released with `oep_package_id_list_release`.
- `oep_dependency_state_t` — `Satisfied`/`Missing`/`Optional`/`Conflicting`/`Cyclic`/`Unknown`, mirroring `oep::installer::DependencyResolutionReport`'s classification exactly. `oep_dependency_state_to_string` gives a deterministic name for each, for logging or display.

**Installation pipeline integration:** `oep_package_install` now resolves dependencies immediately after trust verification and strictly before any Repository Transaction opens — the pipeline order is extract -> already-installed check -> trust-verify -> dependency-resolve -> open-transaction -> create objects/relationships -> record registry -> commit. A required `Missing` dependency, a `Conflicting` version, an `Unknown` (malformed) constraint, or a `Cyclic` dependency chain rejects the install outright, with nothing extracted and no transaction ever opened — the same rejection guarantee trust verification already provides. An `Optional` missing dependency never blocks the install.

**Memory ownership:** `oep_dependency_resolution_result_t` is a plain, pointer-free value type — no release function. `oep_dependency_entry_list_t` and `oep_package_id_list_t` each carry one Foundation-owned heap array, released with exactly one call to `oep_dependency_entry_list_release`/`oep_package_id_list_release` respectively, matching the ownership model every other `*_list_t` in this API already follows.

**Deliberately out of scope for this Work Package:** automatic downloading of a missing dependency, an update engine, uninstall, merge/ownership logic, federation, remote repositories, and PKG-004's "Virtual Capability" dependency type (no Capability primitive exists yet — see CLAUDE.md's Five Primitive Rule). This module resolves solely against local repository metadata already on disk; a missing dependency is reported, never fetched.

## Repository Events (WP-REP-006)

Per the new `oep::runtime::RuntimeService`/`EventBus` infrastructure (see `platform/runtime/README.md`): the internal `oep_runtime_impl` behind every `OEP_Runtime` handle now holds an `EventBus` alongside its `FoundationRuntime`, and this API exposes that log read-only.

```c
oep_repository_event_list_t events;
oep_runtime_recent_events(runtime, 10, &events); /* 0 = unlimited */
for (int i = 0; i < events.count; ++i) {
    printf("[%lld] %s %s %s (%s)\n", events.items[i].sequence,
           events.items[i].occurred_at_utc, oep_event_type_to_string(events.items[i].type),
           events.items[i].subject_id, events.items[i].detail);
}
oep_repository_event_list_release(&events);
```

- `oep_event_type_t` — mirrors `oep::runtime::EventType` exactly: `ObjectCreated`/`ObjectUpdated`/`ObjectDeleted`, `RelationshipCreated`/`RelationshipUpdated`/`RelationshipDeleted`, `TransactionBegun`/`TransactionCommitted`/`TransactionRolledBack`, `PackageInstalled`/`PackageInstallFailed`, `DependencyResolutionCompleted`. `oep_event_type_to_string` gives a deterministic name for each.
- `oep_repository_event_t` — a fixed-layout, pointer-free structure (`subject_id[256]`, `detail[256]`, `occurred_at_utc[32]`, `sequence` as a `long long`, `type`).
- `oep_runtime_recent_events(runtime, limit, out_list)` — the most recently published events, oldest first, up to `limit` (`0` means unlimited, capped only by the `EventBus`'s own retention). **Valid in any Runtime state** — unlike almost every other function in this API, it does not require an open repository, since the event log is scoped to the process's `EventBus` instance, not to a currently-open repository.

**No subscription or push mechanism exists.** `oep_runtime_recent_events` is a pull-only, point-in-time snapshot of what has already been published — there is no callback registration, no polling helper, and no notification of new events as they occur. A caller that wants near-real-time behavior must poll `oep_runtime_recent_events` itself; Foundation does not push.

**Memory ownership:** `oep_repository_event_list_t` follows the standard allocate-once/release-once model — one Foundation-owned heap array (`items`), released with exactly one call to `oep_repository_event_list_release`.

**Thin Wrappers (WP-REP-006):** six existing mutation functions were migrated in this Work Package to route through the new `RuntimeService` instead of calling `FoundationRuntime` directly — `oep_package_install`, `oep_object_create`, `oep_object_update`, `oep_object_delete`, `oep_relationship_create`, `oep_relationship_update`, `oep_relationship_delete`. Each now publishes exactly one `RepositoryEvent` on success, with no other behavior change — same validation, same error codes, same struct layouts. This is an incremental migration, not a one-shot rewrite: every other function in this API (enumeration, search, statistics, transactions, batch mutation, trust, dependency resolution) is untouched and still calls `FoundationRuntime` directly, and publishes no event. See `platform/api/src/oep_api_internal.hpp`'s comment on `oep_runtime_impl` for the authoritative, up-to-date list of which functions have been migrated.

## Package Lifecycle: Uninstall & Update (WP-REP-007)

Two new package lifecycle operations, each exposed as an impact-analysis (dry-run) function plus a separate mutating function — mirroring the "resolve, then install" split WP-REP-005 already established for dependency resolution:

```c
oep_uninstall_impact_t uninstall_impact;
oep_package_analyze_uninstall_impact(runtime, "com.oep.demo.engineering-showcase", &uninstall_impact);
if (uninstall_impact.removable) {
    oep_package_uninstall_result_t uninstall_result;
    oep_package_uninstall(runtime, "com.oep.demo.engineering-showcase", &uninstall_result);
    printf("removed %d objects, %d relationships\n",
           uninstall_result.objects_removed, uninstall_result.relationships_removed);
}

oep_update_impact_t update_impact;
oep_package_analyze_update_impact(runtime, "/path/to/engineering-demo-v2.oep", &update_impact);
if (update_impact.updatable) {
    oep_package_update_result_t update_result;
    oep_package_update(runtime, "/path/to/engineering-demo-v2.oep", &update_result);
    printf("updated %s -> %s\n", update_result.previous_version, update_result.new_version);
}
```

- `oep_package_analyze_uninstall_impact` — dry-run: reports `found`, the object/relationship counts that would be removed, and any other installed package's blocking required dependency (`blocking_dependents`, an `oep_package_id_list_t` — the existing type WP-REP-005 introduced, reused here rather than inventing a second package-ID-list type), and `removable`. Performs no writes.
- `oep_package_uninstall` — re-runs the same blocking check and, if clear, removes every Object/Relationship the package contributed plus its Repository Registry record, all inside **one** Repository Transaction (the same Transaction Engine `oep_package_install` already uses). Refuses outright — no transaction opened, nothing journaled — if a blocking dependent exists.
- `oep_package_analyze_update_impact` — dry-run: verifies trust and resolves dependencies for the **candidate** archive exactly as `oep_package_install` does internally, and additionally reports `broken_dependents` — any other installed package whose required dependency on this package the candidate version would break — plus current/candidate version, trust state, and `updatable`. Performs no writes. **Scope decision:** the nested per-dependency `dependency_report` that `oep::installer::DependencyResolutionReport` carries internally is deliberately **not** exposed at this C boundary — only the top-level `updatable`/`broken_dependents`/version/trust fields are. A Bridge that needs per-dependency detail should call `oep_package_resolve_dependencies` (WP-REP-005) directly against the same archive.
- `oep_package_update` — re-verifies and, if updatable, replaces the old version's contributions with the new version's, all inside **one** Repository Transaction, so a failure anywhere leaves neither version installed twice nor neither installed at all; the previous version is always restored on failure.

**RuntimeService-exclusive, unlike `oep_package_install`.** All four functions route exclusively through `runtime->service` (`RuntimeService`) — there is no `FoundationRuntime`-backed equivalent exposed at this API boundary the way `oep_package_install` still has one for backward compatibility. This is a deliberate tightening, not an oversight: uninstall and update are new operations with no prior callers to preserve compatibility for, so they were built RuntimeService-only from the start, concretely satisfying "all lifecycle operations execute exclusively through RuntimeService." Each successful mutating call publishes one `RepositoryEvent` (`PackageUninstalled`/`PackageUpdated`, new `oep_event_type_t` values), queryable via `oep_runtime_recent_events` (WP-REP-006).

**Memory ownership:** `oep_uninstall_impact_t`, `oep_package_uninstall_result_t`, and `oep_package_update_result_t` are plain, pointer-free value types — no release function — except that `oep_uninstall_impact_t::blocking_dependents` and `oep_update_impact_t::broken_dependents` are `oep_package_id_list_t`, which **is** allocating and must be released with exactly one call to `oep_package_id_list_release` (the same function and ownership model WP-REP-005 already established for `oep_package_resolve_dependencies`'s install order). `oep_update_impact_t` itself is likewise a plain value type aside from that embedded list.

**Errors:** `oep_package_analyze_uninstall_impact`/`oep_package_uninstall` against a `package_id` not present in the Repository Registry fail with `OEP_ERROR_NOT_FOUND` (`found == 0` is reserved for the analyze call's own report field, not conflated with a failed call — matching the existing "not found is a normal result, not an error" convention used elsewhere, except here the registry lookup itself is the precondition, not the report). `oep_package_uninstall` against a package with a blocking dependent fails with `OEP_ERROR_OPERATION_FAILED` and performs no writes. `oep_package_update`/`oep_package_analyze_update_impact` against an archive whose `package_id` is not currently installed, that fails trust verification, that fails dependency resolution, or whose update would break another installed package's required dependency, all fail with `OEP_ERROR_OPERATION_FAILED` and (for `oep_package_update`) leave the previously installed version untouched.

## Merge Engine (WP-REP-008)

Generalizes `oep_package_install` into an explicit plan-then-apply pipeline that tolerates content another package (or a prior install) already contributed, per PKG-006's cross-package merge/ownership logic:

```c
oep_merge_plan_t plan;
oep_merge_conflict_list_t conflicts;
oep_repository_plan_merge(runtime, "/path/to/engineering-demo-v2.oep", &plan, &conflicts);
if (plan.mergeable) {
    oep_merge_result_t result;
    oep_repository_execute_merge(runtime, "/path/to/engineering-demo-v2.oep", &result);
    printf("merged %s: %d objects, %d relationships created\n",
           result.package_id, result.objects_created, result.relationships_created);
} else {
    for (int i = 0; i < conflicts.count; ++i) {
        printf("conflict: %s %s (%s)\n", conflicts.items[i].entity_id,
               oep_merge_conflict_kind_to_string(conflicts.items[i].kind),
               conflicts.items[i].description);
    }
}
oep_merge_conflict_list_release(&conflicts);
```

- `oep_repository_plan_merge` — dry-run, side-effect-free: sequences trust verification (WP-REP-004) then dependency resolution (WP-REP-005) against the currently installed set exactly as `oep_package_install` does internally, then always computes the object/relationship diff regardless of the trust/dependency verdict, so a caller can inspect what a blocked plan would have done. `oep_merge_plan_t::mergeable` reflects trust, dependency resolution, `already_registered` (a `package_id` already in the Repository Registry blocks mergeability — merge is not update), and the absence of any conflict, combined.
- `oep_repository_execute_merge` — re-derives the same plan, refuses (opens no transaction) unless `mergeable` is true, then applies the change set inside **one** Repository Transaction — the same Transaction Engine `oep_package_install`/`oep_package_uninstall`/`oep_package_update` already use — recording only the objects/relationships this merge actually created as the new package's own registry ownership; pre-existing identical content is never re-claimed.
- `oep_merge_conflict_kind_t` — `ObjectContentConflict`/`RelationshipContentConflict`/`RelationshipMissingEndpoint`, mirroring `oep::installer::MergeConflict`'s classification. Conflicts are always reported in **deterministic, source-declaration order** — replanning the same input twice produces identical conflict ordering.
- `oep_merge_conflict_t`/`oep_merge_conflict_list_t` — one entry per detected conflict (entity ID, kind, human-readable description). Released with `oep_merge_conflict_list_release`, the standard allocate-once/release-once model.
- `oep_merge_plan_t` — plain, pointer-free value type: `mergeable`, `already_registered`, `objects_to_create`, `relationships_to_create`. **Scope decision:** the nested `RepositoryChangeSet` and `DependencyResolutionReport` that `oep::installer::MergePlan`/`FoundationRuntime::plan_merge` carry internally are deliberately **not** exposed at this C boundary — only summary counts. A caller needing per-dependency detail calls `oep_package_resolve_dependencies` (WP-REP-005) directly against the same archive, the same pattern WP-REP-007 established for `oep_update_impact_t`'s omitted `dependency_report`.
- `oep_merge_result_t` — plain, pointer-free value type: `package_id`, `version`, `objects_created`, `relationships_created`.

**RuntimeService-exclusive, like uninstall/update (WP-REP-007).** Both functions route exclusively through `runtime->service` — there is no `FoundationRuntime`-backed equivalent exposed at this boundary, the same deliberate tightening WP-REP-007 applied to uninstall/update rather than the backward-compatibility dual-exposure `oep_package_install` still has. `oep_repository_execute_merge` publishes one `RepositoryEvent` (`RepositoryMerged`, a new `oep_event_type_t` value) on success, queryable via `oep_runtime_recent_events`; `oep_repository_plan_merge` publishes nothing, since it is side-effect-free.

**Memory ownership:** `oep_merge_plan_t` and `oep_merge_result_t` are plain, pointer-free value types — no release function. `oep_merge_conflict_list_t` carries one Foundation-owned heap array (`items`), released with exactly one call to `oep_merge_conflict_list_release`.

## Engineering Validation Engine (WP-EKE-005)

The Engineering Validation Engine (EVE) executes engineering rules against Engineering Objects, Packages, and complete Engineering Contexts, producing immutable Validation Reports. It composes WP-EKE-004's Rules Engine rather than embedding any rule logic of its own — see `platform/oep_engine/README.md`'s "Engineering Validation Engine (WP-EKE-005)" section for the full architectural explanation (the "never embeds rules, only composes `RulesEngine`" principle and the target-narrowing composition design).

```c
oep_validation_profile_t profile = OEP_VALIDATION_PROFILE_COMPLETE;
char session_id[64];
oep_validation_create_session(runtime, profile, session_id, sizeof(session_id));

oep_validation_report_summary_t report;
oep_validation_finding_list_t findings;
oep_validation_validate_object(runtime, session_id, "044ba21d-85b2-4502-a5ea-3787fec41367", &report, &findings);
printf("pass=%d warning=%d error=%d critical=%d\n",
       report.pass_count, report.warning_count, report.error_count, report.critical_count);
for (int i = 0; i < findings.count; ++i) {
    printf("%s: %s (%s)\n", findings.items[i].rule_id, findings.items[i].message,
           oep_rule_severity_to_string(findings.items[i].severity));
}
oep_validation_finding_list_release(&findings);

oep_validation_statistics_t stats;
oep_validation_statistics(runtime, session_id, &stats);
```

- `oep_validation_create_session` — creates a `ValidationSession` for the given `ValidationProfile`, writing its session_id into a caller-supplied buffer.
- `oep_validation_validate_object` / `oep_validation_validate_objects` / `oep_validation_validate_package` / `oep_validation_validate_context` — validate one of the four C-reachable scopes (Single Object, Multiple Objects, Installed Package, Complete Engineering Context), finalizing the named session and returning a summary plus a findings list.
- `oep_validation_report` — re-fetches the most recent report for a known session_id; returns `OEP_ERROR_NOT_FOUND` for an unknown one, not a crash or an empty-but-successful result.
- `oep_validation_statistics` — the session's `ValidationStatistics` (rules_evaluated/passed/failed/not_applicable/errored, execution_time_ms) as a scalar-only struct.
- `oep_validation_profile_to_string`/`oep_rule_severity_to_string` (reused from WP-EKE-004) — deterministic names for logging/display.

**Deliberately omitted finding detail — the same "avoid nested owned-list-of-owned-lists" precedent WP-EKE-004's `oep_rules_evaluate_all` already established.** `oep_validation_finding_t` carries `finding_id`/`rule_id`/`severity`/`category`/`message`/`recommendation` but deliberately **omits** `affected_objects`/`diagnostics` — a finding's own nested lists. A caller wanting that detail calls `oep_rules_evaluate(rule_id)` (WP-EKE-004, already in this API) directly against the same rule_id; re-exposing the same nested detail a second time at this boundary would duplicate `oep_rules_evaluate`'s own shape for no new information.

**Deliberately skipped: `oep_validation_validate_query_result`.** The Runtime API's `validate_query_result()` (Arbitrary Query Result scope) has no C-boundary equivalent — a `QueryResult` isn't naturally passable across the C ABI without significant extra plumbing (it isn't one of this API's existing fixed-layout or list types, and inventing a new marshaled form solely for this one call was judged not worth the complexity for this work package). Callers wanting query-result-scoped validation from C should call `oep_eqe_execute_query` (WP-EKE-003) to obtain the result's object ids, then call `oep_validation_validate_objects` with those ids — composition across two existing calls, rather than a fifth `validate_*` C function.

**Memory ownership:** `oep_validation_report_summary_t` and `oep_validation_statistics_t` are plain, pointer-free, scalar-only value types — no release function, the same precedent WP-EKE-002/WP-EKE-003's statistics structs already established. `oep_validation_finding_list_t` carries one Foundation-owned heap array (`items`), released with exactly one call to `oep_validation_finding_list_release`.

**`oep_runtime_impl` (internal)** gained a `validation_engine` member constructed from `engine_context`/`knowledge_graph_engine`/`engineering_query_engine`/`rules_engine`, never bypassing layers. Sessions are held in-memory for the handle's lifetime, never persisted — the same in-memory-only model WP-EKE-004's rule registry already established.

**Errors:** an archive that fails trust verification or dependency resolution still returns a successful `oep_result_t` from `oep_repository_plan_merge` with `mergeable == 0` — planning itself never fails just because the plan turns out not to be mergeable, mirroring `oep_package_analyze_update_impact`'s "not-mergeable is a normal result, not an error" convention. `oep_repository_execute_merge` against a plan that isn't mergeable fails with `OEP_ERROR_OPERATION_FAILED` and performs no writes.

## Engineering Analysis & Reasoning Engine (WP-EKE-006)

The Engineering Analysis & Reasoning Engine (EARE) analyzes engineering knowledge and derives deterministic, explainable conclusions, built on top of WP-EKE-005's Validation Engine (and, through it, the Knowledge Graph, Query Engine, and Rules Engine). See `platform/oep_engine/README.md`'s "Engineering Analysis & Reasoning Engine (WP-EKE-006)" section for the full architectural explanation (the `AnalysisEngine`/`ReasoningEngine` split, the `execute_reasoning` evidence-based design, and the confidence formula).

```c
oep_dependency_report_t dep_report;
oep_package_id_list_t dep_objects;
oep_analysis_dependencies(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", &dep_report, &dep_objects);
oep_package_id_list_release(&dep_objects);

oep_root_cause_report_t rc_report;
oep_package_id_list_t candidates;
oep_analysis_root_cause(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", &rc_report, &candidates);
oep_package_id_list_release(&candidates);

char session_id[64];
oep_reasoning_create_session(runtime, "Investigate ignition failure", session_id, sizeof(session_id));

const char* starting[] = { "044ba21d-85b2-4502-a5ea-3787fec41367" };
oep_reasoning_summary_t summary;
oep_package_id_list_t conclusion_ids, recommendation_ids;
oep_reasoning_execute(runtime, session_id, starting, 1, &summary, &conclusion_ids, &recommendation_ids);
printf("conclusions=%d recommendations=%d %.3f ms\n", summary.conclusion_count,
       summary.recommendation_count, summary.execution_time_ms);

oep_engineering_conclusion_t conclusion;
oep_reasoning_get_conclusion(runtime, session_id, conclusion_ids.items[0].id, &conclusion);
printf("%s (confidence %.2f)\n", conclusion.statement, conclusion.confidence);

oep_evidence_node_t evidence;
oep_reasoning_get_evidence_node(runtime, session_id, conclusion.supporting_evidence_ids[0], &evidence);

oep_package_id_list_release(&conclusion_ids);
oep_package_id_list_release(&recommendation_ids);
```

- `oep_analysis_dependencies`/`oep_analysis_impact`/`oep_analysis_reachability` — the three self-sufficient `AnalysisEngine` algorithms, each filling a scalar report struct plus an `oep_package_id_list_t` of matched object ids, requiring only a prior successful `oep_kge_build_graph`/`_refresh_graph` (no reasoning session needed).
- `oep_analysis_root_cause` — **routes exclusively through `ReasoningEngine::analyze_root_cause`, the SELF-VALIDATING overload, never `AnalysisEngine`'s two-argument version directly.** This is a meaningful implementation choice worth stating explicitly: the C API boundary only ever exposes the "just works" version, hiding the two-engine composition detail (analysis + an internal `ValidationEngine` pass to derive the finding set) from callers.
- `oep_reasoning_create_session`/`oep_reasoning_execute` — create a `ReasoningSession` for an objective and one or more starting object ids, then run it. `oep_reasoning_execute` returns `oep_reasoning_summary_t` (scalar-only: conclusion_count, recommendation_count, execution_time_ms) plus TWO `oep_package_id_list_t` outputs (conclusion_ids, recommendation_ids) — the established "scalar summary + id-list, fetch detail separately by id" pattern from WP-EKE-004/WP-EKE-005.
- `oep_reasoning_report` — re-fetches the most recent `ReasoningReport` for a known session_id.
- `oep_reasoning_get_conclusion`/`oep_reasoning_get_recommendation` — fetch one `EngineeringConclusion`/`EngineeringRecommendation` **by its stable string id** (`conclusion_id`/`recommendation_id`), not by index — mirroring the precedent `oep_rules_evaluate` (WP-EKE-004) already established (fetch-by-id, not position).
- `oep_reasoning_get_evidence_node` — fetch one `EvidenceNode` by id. **Evidence Graph exposure at the C API is DELIBERATELY MINIMAL** — this is the only Evidence Graph function: no enumeration of all nodes, no `EvidenceRelationship` edge exposure. A documented scope decision, since Studio callers can reconstruct what they need by following the evidence ids already returned on conclusions/recommendations one at a time.

**A known, honestly-disclosed ambiguity: `reasoning_report` cannot distinguish "session never created" from "session created but never executed."** `ReasoningEngine::reasoning_report` returns `std::nullopt` for both a session_id that was never created via `create_reasoning_session` AND a session_id that was created but never passed to `execute_reasoning`. Unlike WP-EKE-005's `ValidationEngine`, which finalizes its session as part of the same `validate_*` call (there is no separate create-then-execute step to leave a session half-formed), `ReasoningEngine` has an explicit two-step `create_reasoning_session()` / `execute_reasoning()` flow, so this ambiguity is a genuine, new manifestation for this work package rather than a restatement of an identical pre-existing one. The C API implementation maps both cases to `OEP_ERROR_NOT_FOUND` — documented here as a known ambiguity, not a bug.

**Memory ownership.** `oep_dependency_report_t`/`oep_impact_report_t`/`oep_reachability_report_t`/`oep_root_cause_report_t` and `oep_reasoning_summary_t` are plain, pointer-free, scalar-only value types — no release function, the same precedent WP-EKE-002/WP-EKE-003/WP-EKE-005's statistics/summary structs already established. Every `oep_analysis_*`/`oep_reasoning_execute` id-list output reuses the existing `oep_package_id_list_t`/`oep_package_id_list_release` type — no new id-list type was introduced for this work package. `oep_engineering_conclusion_t`/`oep_engineering_recommendation_t`/`oep_evidence_node_t` are fixed-layout, pointer-free structs filled by `oep_reasoning_get_conclusion`/`_get_recommendation`/`_get_evidence_node` — no release function.

**`oep_runtime_impl` (internal)** gained a `reasoning_engine` member constructed from `engine_context`/`knowledge_graph_engine`/`engineering_query_engine`/`rules_engine`/`validation_engine` — never bypassing layers. Sessions are held in-memory for the handle's lifetime, never persisted — the same in-memory-only model WP-EKE-004/WP-EKE-005 already established.

**Errors:** every function requires an open repository and a prior successful `oep_kge_build_graph`/`_refresh_graph` on the same handle, failing with `OEP_ERROR_INVALID_STATE` otherwise. `oep_reasoning_execute`/`_report`/`_get_conclusion`/`_get_recommendation`/`_get_evidence_node` additionally require a session_id created (and, for the latter three, executed) on the same handle — an unknown or not-yet-executed session_id fails with `OEP_ERROR_NOT_FOUND` (see the ambiguity note above). `NULL` for a required `runtime`/`object_id`/`session_id`/output-pointer argument fails with `OEP_ERROR_INVALID_ARGUMENT`.

**Not exposed at this boundary, honestly disclosed rather than silently missing:** no enumeration of every `EvidenceNode`/`EvidenceRelationship` in a session's `EvidenceGraph` — only single-node fetch by id (see above). The Studio UI is not part of this work package's scope at all — per the specification's own explicit "UI implementation remains out of scope" statement, only Foundation Bridge FFI bindings for the five named items (Analysis Reports, Reasoning Sessions, Evidence Graphs, Engineering Conclusions, Recommendations) were built, verified via `flutter analyze`/`flutter test`. No Studio UI screens were built for this surface, exactly as none were built for WP-EKE-001 through WP-EKE-005's surfaces above.

## Engineering Intelligence Platform (WP-EKE-007)

The Engineering Intelligence Platform (EIP) is the top-level orchestration façade over all six lower engines (Knowledge Graph, Query, Rules, Validation, Analysis, Reasoning). See `platform/oep_engine/README.md`'s "Engineering Intelligence Platform (WP-EKE-007)" section for the full architectural explanation — in particular the central decision that only the Knowledge Session Manager was implemented as its own separate public class, with Workflow Engine/Service Orchestrator/Context Manager/Shared Cache Manager/Runtime Metrics all realized as `EngineeringIntelligencePlatform`'s own methods.

```c
char session_id[64];
oep_eip_create_session(runtime, session_id, sizeof(session_id));

oep_workflow_result_t result;
oep_package_id_list_t object_ids;
oep_eip_inspect(runtime, session_id, OEP_INSPECTION_TARGET_OBJECT, "044ba21d-85b2-4502-a5ea-3787fec41367",
                &result, &object_ids);
printf("%s success=%d %.3f ms\n", oep_workflow_kind_to_string(result.kind), result.success,
       result.execution_time_ms);
oep_package_id_list_release(&object_ids);

oep_engineering_summary_report_t summary;
oep_eip_engineering_summary(runtime, &summary);

oep_engineering_health_report_t health;
oep_eip_engineering_health(runtime, &health);
printf("health=%.1f/100\n", health.health_score);

oep_package_id_list_t recommendation_messages;
oep_eip_engineering_recommendations(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", &recommendation_messages);
oep_package_id_list_release(&recommendation_messages);

oep_runtime_metrics_t metrics;
oep_eip_runtime_metrics(runtime, &metrics);

oep_eip_invalidate_caches(runtime);
oep_eip_cleanup(runtime);
```

- `oep_eip_create_session`/`_resume_session`/`_clone_session`/`_close_session`/`_switch_session`/`_list_sessions`/`_get_session`/`_export_session_summary` — the Knowledge Session Manager lifecycle (Create/Resume/Clone/Close/Export Summary) plus the Context Manager's session-switching convenience. Session-id output uses the same fixed-buffer convention already established by WP-EKE-005's `oep_validation_create_session`/WP-EKE-006's `oep_reasoning_create_session`. Sessions do NOT require a built graph — the same precedent `oep_reasoning_create_session` already set.
- `oep_eip_query`/`_inspect`/`_validate`/`_analyze`/`_reason`/`_recommend` — the six Workflow Engine functions, each session-scoped (`session_id` must already exist on this handle) and requiring a prior successful `oep_engine_load_graph` + `oep_kge_build_graph`/`_refresh_graph`. Each returns a scalar `oep_workflow_result_t` plus a separate `oep_package_id_list_t` for `object_ids` — the same "scalar summary + id-list, fetch detail separately" precedent every prior EKE work package established.
- `oep_eip_engineering_summary`/`_engineering_health`/`_engineering_recommendations` — three of the eight stateless Service Orchestrator functions (no session required), each requiring a built graph. `inspect_object`/`inspect_package`/`inspect_context` are reached via `oep_eip_inspect`'s Workflow wrapper rather than as separate stateless C functions; `engineering_dependencies`/`engineering_trace` are exposed directly via the existing `oep_analysis_*` functions from WP-EKE-006 rather than duplicated here, since the EIP's own `engineering_dependencies`/`engineering_trace` methods are themselves direct pass-throughs to `AnalysisEngine`.
- `oep_eip_engineering_recommendations` — **returns recommendation MESSAGE STRINGS, not full `EngineeringRecommendation` objects**, via the reused `oep_package_id_list_t` (each `.id` field holding one recommendation's message text). This is a documented scope decision: `EngineeringIntelligencePlatform::engineering_recommendations` creates its own EPHEMERAL, internal `ReasoningSession` each call, which is never exposed and cannot be queried afterward via WP-EKE-006's `oep_reasoning_get_recommendation`. A caller wanting full `EngineeringRecommendation` objects (kind/object_id/evidence) should instead use `oep_reasoning_create_session` + `oep_reasoning_execute` + `oep_reasoning_recommendations`/`oep_reasoning_get_recommendation` directly (WP-EKE-006), over their own session.
- `oep_eip_runtime_metrics` — a snapshot of this handle's platform-wide `RuntimeMetrics`. No session required, no graph-readiness precondition — a fresh handle simply reports all zeros.
- `oep_eip_invalidate_caches` — the Shared Cache Manager: clears the Query Engine's `QueryCache`, the only lower engine that maintains an actual cache today. No session required, no graph-readiness precondition.
- `oep_eip_cleanup` — the Context Manager's Resource Cleanup: closes every open session on this handle and clears every lower engine's cache in one call.

**Memory ownership.** `oep_workflow_result_t`/`oep_engineering_summary_report_t`/`oep_engineering_health_report_t`/`oep_runtime_metrics_t`/`oep_knowledge_session_summary_t` are plain, pointer-free, scalar-only value types — no release function, the same precedent WP-EKE-002/WP-EKE-003/WP-EKE-005/WP-EKE-006's statistics/summary structs already established. Every id-list output (`object_ids`, session id lists, recommendation messages) reuses the existing `oep_package_id_list_t`/`oep_package_id_list_release` type. `oep_eip_export_session_summary` allocates its text summary on the heap, released via `oep_string_release` (WP-EKE-002's precedent).

**`oep_runtime_impl` (internal)** gained an `intelligence_platform` member constructed from the seven existing engine members (`engine_context`/`knowledge_graph_engine`/`engineering_query_engine`/`rules_engine`/`validation_engine`/`analysis_engine`/`reasoning_engine`) — never bypassing layers, never touching `RuntimeService`/`FoundationRuntime` directly.

**Errors.** Every `oep_eip_*` function is only valid from `RepositoryOpen`, failing with `OEP_ERROR_INVALID_STATE` otherwise — this applies uniformly, including `oep_eip_runtime_metrics`/`_invalidate_caches`/`_cleanup`, which have no session or graph-readiness precondition beyond that. (Implementation note, recorded here for honesty: while writing the C API test suite, it was initially assumed these three session-independent functions might be exempt from the `RepositoryOpen` precondition entirely; checking `oep_api.h`'s own header comment corrected this before the tests were finalized.) The five Workflow functions plus `oep_eip_engineering_summary`/`_engineering_health`/`_engineering_recommendations` additionally require a prior successful `oep_engine_load_graph` + `oep_kge_build_graph`/`_refresh_graph`, failing with `OEP_ERROR_INVALID_STATE` otherwise. Every Workflow function requires its `session_id` to already exist on this handle — an unknown session_id is `OEP_ERROR_NOT_FOUND`, checked explicitly at the C API boundary since the underlying `KnowledgeSessionManager` mutation methods silently no-op on an unknown id (see `knowledge_session_manager.hpp`). `NULL` for a required `runtime`/`session_id`/`object_id`/output-pointer argument fails with `OEP_ERROR_INVALID_ARGUMENT`.

**Not exposed at this boundary, honestly disclosed rather than silently missing:** `oep_eip_export_session_summary` exposes only a rendered text summary, not the raw history description lists (`oep_knowledge_session_summary_t` gives history COUNTS only, mirroring every prior WP-EKE-004/005/006 summary-struct precedent). The Studio UI is not part of this work package's scope at all — per the specification's own explicit "No UI work in this package" statement, only Foundation Bridge FFI bindings for the five named items (Knowledge Sessions, Runtime Metrics, Engineering Summary, Workflow Execution, Session Management) were built, verified via `flutter analyze`/`flutter test`. No Studio UI screens were built for this surface, exactly as none were built for WP-EKE-001 through WP-EKE-006's surfaces above.

## Engineering Knowledge Runtime (WP-EKE-001)

The first Public C API surface built for a consumer outside the `platform/runtime`/`platform/installer` Foundation stack: six functions exposing `oep::engine::EngineeringContext` — WP-EKE-001's new Engineering Knowledge Runtime (EKR), an entirely new module (`platform/oep_engine`) sitting *above* Foundation, responsible for engineering semantics (graph queries, traversal, relationship classification) rather than storage. Every function below calls through `runtime`'s `EngineeringContext`, which itself consumes Foundation exclusively through `RuntimeService` — never `FoundationRuntime` directly — matching WP-REP-007/WP-REP-008's RuntimeService-exclusivity pattern.

```c
oep_object_info_t widget;
int found = 0;
oep_engine_load_object(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", &widget, &found);

int objects_loaded = 0, relationships_loaded = 0;
oep_engine_load_graph(runtime, &objects_loaded, &relationships_loaded);

oep_engine_query_request_t request = {0};
request.kind = OEP_ENGINE_QUERY_BY_TYPE;
request.object_type = OEP_OBJECT_TYPE_COMPONENT;
oep_package_id_list_t matches;
oep_engine_query(runtime, &request, &matches, NULL, NULL);
oep_package_id_list_release(&matches);

oep_package_id_list_t traversal;
oep_engine_traverse(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", /* BreadthFirst */ 0,
                     /* has_relationship_filter */ 0, OEP_RELATIONSHIP_TYPE_REFERENCES,
                     /* has_max_depth */ 0, 0, &traversal);
oep_package_id_list_release(&traversal);

oep_package_id_list_t neighbors;
oep_engine_related_objects(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", &neighbors);
oep_package_id_list_release(&neighbors);

oep_package_id_list_t dep_objects, dep_relationships;
oep_engine_dependency_graph(runtime, "044ba21d-85b2-4502-a5ea-3787fec41367", &dep_objects, &dep_relationships);
oep_package_id_list_release(&dep_objects);
oep_package_id_list_release(&dep_relationships);
```

- `oep_engine_load_object` — lazy single-object load via the Object Loader, without touching or requiring the Runtime Graph. A nonexistent `object_id` is a normal result (`*out_found == 0`, `*out_object` zero-initialized), not an API error.
- `oep_engine_load_graph` — batch-loads every Engineering Object and Relationship in the currently open repository and (re)builds this handle's Runtime Graph from that snapshot. **Must succeed before** `oep_engine_query`/`oep_engine_traverse`/`oep_engine_related_objects`/`oep_engine_dependency_graph` — each fails with `OEP_ERROR_INVALID_STATE` (naming the missing call) if invoked first. The built graph is cached on the handle's engine context, not the repository, so it must be (re)loaded once per process/handle and again after any mutation that should be reflected.
- `oep_engine_query` — one discriminated request (`oep_engine_query_request_t`/`oep_engine_query_kind_t`, mirroring `EngineeringContext::QueryRequest`/`QueryKind`) covering Find by ID/Type/Domain/Relationship, Shortest Path, Connected Component, and Subgraph. Only the fields the selected `kind` needs are read. `out_path_exists` is meaningful only for `OEP_ENGINE_QUERY_SHORTEST_PATH`; `out_relationship_ids` is populated only for `OEP_ENGINE_QUERY_SUBGRAPH`. A shortest path that doesn't exist is a normal result (`out_path_exists == 0`), not an error.
- `oep_engine_traverse` — deterministic BFS (`order == 0`) or DFS (`order == 1`) over the loaded Runtime Graph from `start_object_id`, with optional relationship-type filtering (`has_relationship_filter`) and optional max-depth limiting (`has_max_depth`). Cycle-safe: a graph with a cycle back to an already-visited node does not revisit it or infinite-loop.
- `oep_engine_related_objects` — every object directly connected to `object_id`, any relationship type, either direction, sorted and deduplicated (`RelationshipEngine::neighbors`).
- `oep_engine_dependency_graph` — the full transitive closure of `object_id`'s outgoing `DependsOn` Relationships: the object itself, every object reachable by following only `DependsOn` edges outward, and the `DependsOn` relationship ids traversed. **An entirely different thing from WP-REP-005's Dependency Resolution Engine** — this walks Engineering Object `DependsOn` relationships (an engineering-semantics concept), not package manifest dependency declarations; the two share a name in English only. Fails with `OEP_ERROR_NOT_FOUND` if `object_id` is not present in the loaded graph.

**ID-list type reuse decision.** Every id-list output above (`oep_engine_query`'s `out_object_ids`/`out_relationship_ids`, `oep_engine_traverse`'s `out_object_ids`, `oep_engine_related_objects`'s `out_object_ids`, `oep_engine_dependency_graph`'s `out_object_ids`/`out_relationship_ids`) reuses the **existing** `oep_package_id_list_t`/`oep_package_id_list_release` type WP-REP-005 introduced, rather than inventing a new "object id list" or "relationship id list" type. Its layout — a heap array of fixed-size-buffer id structs plus a count — is already exactly a generic "list of ids" container; `oep_package_analyze_uninstall_impact`/`oep_package_analyze_update_impact` (WP-REP-007) already reuse it the same way for dependent *package* ids, not just package-resolution ids. `OEP_MAX_PACKAGE_ID` (256) comfortably exceeds `OEP_MAX_OBJECT_ID`/`OEP_MAX_RELATIONSHIP_ID` (64), so no object or relationship id is ever truncated by the reuse — a deliberate reuse decision, not an oversight, matching this API's established "reuse an existing generic container rather than add a near-duplicate type" convention.

**Memory ownership:** `oep_engine_load_object` allocates nothing beyond the caller-supplied `oep_object_info_t` it fills. `oep_engine_load_graph` allocates nothing — it only writes `int` counts. `oep_engine_query`, `oep_engine_traverse`, `oep_engine_related_objects`, and `oep_engine_dependency_graph` each allocate one or two `oep_package_id_list_t` arrays (as documented per function above); the caller owns each populated list and must release it with exactly one call to `oep_package_id_list_release`, the same ownership model every other `*_list_t` in this API follows.

**Errors:** every function below requires an open repository (`RepositoryOpen`) and fails with `OEP_ERROR_INVALID_STATE` otherwise. `NULL` for a required `runtime`/`object_id`/`request`/`start_object_id` argument fails with `OEP_ERROR_INVALID_ARGUMENT`. Calling `oep_engine_query`/`oep_engine_traverse`/`oep_engine_related_objects`/`oep_engine_dependency_graph` before a successful `oep_engine_load_graph` on the same handle fails with `OEP_ERROR_INVALID_STATE`.

**Not exposed at this boundary, honestly disclosed rather than silently missing:** the Studio UI screens WP-EKE-001's original specification named (Engineering Workspace, Graph Explorer, Relationship Viewer, Object Inspector, Traversal View) were **not built** in this work package — only the Foundation Bridge FFI bindings consuming these six functions were (`oep_api_native_types.dart`/`oep_api_bindings.dart`/`oep_api_types.dart`/`foundation_bridge.dart`, verified via `flutter analyze`/`flutter test`). See `platform/oep_engine/README.md` for the full Engineering Knowledge Runtime this surface exposes.

## Engineering Knowledge Graph Engine (WP-EKE-002)

Ten new functions exposing `oep::engine::KnowledgeGraphEngine` — the canonical Knowledge Graph WP-EKE-002 builds on top of WP-EKE-001's Engineering Knowledge Runtime. `oep_runtime_impl` (internal) gained a `knowledge_graph_engine` member constructed from `engine_context` (never from `service`/`runtime` directly), preserving "consume `EngineeringContext` only" at the API boundary exactly as `engine_context` itself was constructed from `service`, never `runtime`, in WP-EKE-001.

```c
int objects_built = 0, relationships_built = 0;
oep_kge_build_graph(runtime, &objects_built, &relationships_built);

oep_graph_issue_list_t issues;
int valid = 0;
oep_kge_validate_graph(runtime, &valid, &issues);
oep_graph_issue_list_release(&issues);

oep_graph_statistics_t stats;
oep_kge_graph_statistics(runtime, &stats);
printf("density %.3f, max depth %d, avg degree %.2f\n",
       stats.density, stats.max_depth, stats.average_degree);

oep_component_membership_list_t components;
oep_kge_connected_components(runtime, &components);
oep_component_membership_list_release(&components);

int path_exists = 0;
oep_package_id_list_t path;
oep_kge_shortest_path(runtime, "044ba21d-...", "a1cc95de-...", &path_exists, &path);
oep_package_id_list_release(&path);

const char* ids[] = { "044ba21d-...", "a1cc95de-..." };
oep_package_id_list_t sub_objects; oep_package_id_list_t sub_relationships;
oep_kge_subgraph(runtime, ids, 2, &sub_objects, &sub_relationships);
oep_package_id_list_release(&sub_objects);
oep_package_id_list_release(&sub_relationships);

char* json = NULL;
oep_kge_export_json(runtime, &json);
printf("%s\n", json);
oep_string_release(json);
```

- `oep_kge_build_graph`/`oep_kge_refresh_graph` — build (or rebuild) this handle's canonical Knowledge Graph from the currently open repository, reporting the object/relationship counts built. Mirrors `oep_engine_load_graph`'s "must succeed before downstream calls" contract, but for the Knowledge Graph rather than WP-EKE-001's Runtime Graph — the two are cached independently on the handle.
- `oep_kge_validate_graph` — runs `graph_validator::validate_graph` and returns `*out_valid` plus an `oep_graph_issue_list_t` (`oep_graph_issue_kind_t`: `MissingEndpoint`/`DuplicateRelationship`/`SelfReference`/`BrokenReference`/`Cycle`/`InvalidRelationshipType`; `oep_graph_issue_t`: kind, relationship id when applicable, detail text). Released with `oep_graph_issue_list_release`. A valid graph is a normal result (`*out_valid == 1`, empty list), not an error.
- `oep_kge_graph_statistics` — fills a caller-supplied `oep_graph_statistics_t`: object count, relationship count, connected component count, density, maximum depth, average degree. **Scope decision: scalar fields only.** The two distribution vectors `GraphStatistics` computes internally (relationship-type distribution, domain distribution) are deliberately **not** exposed at this C boundary — mirroring WP-REP-007/WP-REP-008's established precedent of trimming nested/open-ended detail from C structs (`oep_update_impact_t`'s omitted `dependency_report`, `oep_merge_plan_t`'s omitted `RepositoryChangeSet`/`DependencyResolutionReport`). A caller needing the full distributions uses the CLI's `oep engine stats`, which talks to `KnowledgeGraphEngine` directly in C++ and is not bound by this scope decision.
- `oep_kge_connected_components` — **a flattened representation**, since C has no natural "list of lists": one `oep_component_membership_t` entry per object (`object_id`, `component_index`) rather than an array of arrays. A caller reconstructs each component client-side by grouping on `component_index`. Released with `oep_component_membership_list_release`.
- `oep_kge_shortest_path` — unweighted BFS shortest path between two object IDs, reusing the existing `oep_package_id_list_t` type (the same reuse decision WP-EKE-001 already established for every other object/relationship id-list output in this API). A path that doesn't exist is a normal result (`*out_path_exists == 0`, empty list), not an error.
- `oep_kge_subgraph` — the induced subgraph over a caller-supplied set of object IDs. **The first multi-string-input function in this API:** takes `const char* const* object_ids, int object_id_count` rather than a single string or a fixed-layout struct, since the requested id set is caller-determined and open-ended. Nonexistent IDs are silently skipped, matching `QueryEngine::subgraph`'s (WP-EKE-001) own convention.
- `oep_kge_export_json`/`oep_kge_export_graphml_placeholder` — the full graph export, as a caller-owned, heap-allocated, NUL-terminated string. **A new ownership convention for this codebase**, released with a new `oep_string_release(char*)` function rather than any of the existing `*_list_release` functions — a deliberate departure from the fixed-buffer-struct/`*_list_t` convention used everywhere else in this API, because export size is genuinely unbounded (a full JSON or GraphML document over an arbitrarily large graph cannot be forced into a fixed-layout struct or a homogeneous array-of-structs the way every other output in this API is). `oep_kge_export_graphml_placeholder`'s output is, per `graph_serialization.hpp`, explicitly a placeholder — well-formed, correct node/edge identity, but not the full GraphML attribute schema real GraphML tooling expects.

**Memory ownership.** `oep_kge_build_graph`/`oep_kge_refresh_graph` allocate nothing beyond the `int` counts they write. `oep_kge_graph_statistics` fills a caller-supplied plain value type — no release function. `oep_kge_validate_graph` allocates `oep_graph_issue_list_t`, released with `oep_graph_issue_list_release`. `oep_kge_connected_components` allocates `oep_component_membership_list_t`, released with `oep_component_membership_list_release`. `oep_kge_shortest_path`/`oep_kge_subgraph` reuse `oep_package_id_list_t`/`oep_package_id_list_release`, the same type and release function WP-EKE-001/WP-REP-005 already established. `oep_kge_export_json`/`oep_kge_export_graphml_placeholder` are the one pair in this whole API returning a raw owned string rather than a struct — release each with exactly one call to `oep_string_release`, never `free`/`delete` directly (same rationale as every other `*_release` function: only Foundation's own release function is guaranteed to match the allocator that produced the string).

**Errors:** every function requires an open repository and fails with `OEP_ERROR_INVALID_STATE` otherwise; `oep_kge_validate_graph`/`_graph_statistics`/`_connected_components`/`_shortest_path`/`_subgraph`/`_export_json`/`_export_graphml_placeholder` additionally require a prior successful `oep_kge_build_graph`/`_refresh_graph` on the same handle, failing with `OEP_ERROR_INVALID_STATE` (naming the missing call) otherwise — mirroring `oep_engine_load_graph`'s precondition exactly. `NULL` for a required `runtime`/`object_ids`/output-pointer argument fails with `OEP_ERROR_INVALID_ARGUMENT`.

**Not exposed at this boundary, honestly disclosed rather than silently missing:** the Studio UI is not part of this work package's scope at all — per the work package specification's own explicit "UI implementation remains out of scope" statement, only Foundation Bridge FFI bindings for the five named items (Graph Statistics, Validation Report, Connected Components, Subgraph Preview, Graph Export) were built, verified via `flutter analyze`/`flutter test`. No Studio UI screens were built for this surface, exactly as none were built for WP-EKE-001's surface above. See `platform/oep_engine/README.md`'s "Engineering Knowledge Graph Engine (WP-EKE-002)" section for the full Knowledge Graph Engine this surface exposes.

## Engineering Query Engine (WP-EKE-003)

Five functions plus a practical bonus, exposing `oep::engine::EngineeringQueryEngine` — the deterministic query layer WP-EKE-003 builds on top of WP-EKE-002's Knowledge Graph Engine. `oep_runtime_impl` (internal) gained an `engineering_query_engine` member constructed from `knowledge_graph_engine` (never from `engine_context`/`service`/`runtime` directly), preserving "consume the Knowledge Graph Engine only" at the API boundary exactly as `knowledge_graph_engine` itself was constructed from `engine_context`, never `service`, in WP-EKE-002.

```c
oep_query_request_t request = {0};
request.category = OEP_QUERY_CATEGORY_TYPE;
request.filter.has_object_type = 1;
request.filter.object_type = OEP_OBJECT_TYPE_COMPONENT;

oep_query_plan_t plan;
oep_package_id_list_t indexes_used, execution_order;
oep_eqe_plan_query(runtime, &request, &plan, &indexes_used, &execution_order);
oep_package_id_list_release(&indexes_used);
oep_package_id_list_release(&execution_order);

oep_package_id_list_t objects, relationships;
oep_query_result_summary_t summary;
oep_eqe_execute_query(runtime, &request, &objects, &relationships, &summary);
printf("results %d, objects examined %d, %.3f ms\n",
       summary.result_count, summary.objects_examined, summary.execution_time_ms);
oep_package_id_list_release(&objects);
oep_package_id_list_release(&relationships);

oep_query_result_summary_t last_stats;
oep_eqe_query_statistics(runtime, &last_stats);

oep_query_cache_info_t cache_info;
oep_eqe_query_cache_info(runtime, &cache_info);
printf("cached plans %d, cached results %d\n", cache_info.plan_count, cache_info.result_count);

oep_eqe_clear_query_cache(runtime);
```

- `oep_eqe_plan_query` — builds (never executes) an immutable `QueryPlan` via `QueryPlanner::plan`, filling `oep_query_plan_t` (category, traversal strategy, estimated cost) plus two `oep_package_id_list_t` outputs: `indexes_used` and `execution_order`, the only place in this API those two string lists are exposed — reusing the existing `oep_package_id_list_t` type from WP-REP-005/WP-EKE-001 rather than inventing a "string list" type, since it is already exactly that.
- `oep_eqe_execute_query` — a convenience, request-based overload: plans then executes in one call, filling two `oep_package_id_list_t` outputs (matching object ids, matching relationship ids) plus a caller-supplied `oep_query_result_summary_t`. There is no separate plan-based `execute` entry point at this C boundary — a caller that already has a plan from `oep_eqe_plan_query` and wants to skip replanning is not accommodated here; the C++ `QueryExecutor::execute(plan, engine)` overload exists but is not separately exposed, since the common Bridge/Studio case is "run this query," not "run this plan."
- `oep_eqe_query_statistics` — the most recently executed query's `QueryStatistics`, as the same `oep_query_result_summary_t` structure `oep_eqe_execute_query` fills inline. A query engine that has executed nothing yet returns a zero-initialized summary, a normal result, not an error.
- `oep_eqe_clear_query_cache` — calls `EngineeringQueryEngine::clear_query_cache()`. **This is the caller-driven cache-invalidation trigger** — see the limitation below.
- `oep_eqe_query_cache_info` — a **bonus function**, not literally named in the work package's five-item Runtime API list, added as a practical necessity so a caller can introspect cache occupancy (`plan_count`/`result_count`) without a full struct dump; it matches `query_cache()`'s intent from the spec even though the spec names only `plan_query`/`execute_query`/`query_statistics`/`query_cache`/`clear_query_cache` as methods, not this specific C-shaped accessor.

**`oep_query_filter_t` — the `has_X` optional-flag convention, plus array-of-strings tags.** Every optional filter field (`object_type`, `knowledge_domain`, `relationship_type`, `publisher`, `package`, `depth`, `direction`) is paired with a `has_<field>` int flag, so a zero-valued enum or `0` depth is never ambiguous with "not set" — the same convention WP-REP-005/WP-EKE-001 already use for optional scalar fields elsewhere in this API. `tags` is the one array-valued filter field: `const char* const* tags, int tag_count`, reusing the same array-of-strings input pattern WP-EKE-002's `oep_kge_subgraph` established (the first multi-string-input function in this API) rather than inventing a second one — matched ANDed, per `QueryFilter::tags`' documented all-must-match rule.

**`oep_query_result_summary_t` — which `QueryStatistics` fields are included, and which are not.** Every `QueryStatistics` scalar is exposed: `execution_time_ms`, `objects_examined`, `relationships_examined`, `traversal_depth`, `result_count`, plus a `traversal_summary` fixed-buffer string. **Deliberately not included:** the `indexes_used`/`execution_order` string *lists* — those are exposed only on `oep_eqe_plan_query`'s output (reusing `oep_package_id_list_t`, as noted above), not duplicated onto the result summary, since a caller that wants that detail already has it from planning and a plan/execute round trip would otherwise report it twice in two different shapes.

**Not exposed at this boundary, honestly disclosed rather than silently missing:** there is no separate "Query Optimizer" function or type — strategy/index/cost selection is folded into `oep_eqe_plan_query` itself (see `platform/oep_engine/README.md`'s WP-EKE-003 section for why no separate optimizer module exists). The Studio UI is not part of this work package's scope at all — per the specification's own explicit "UI implementation remains out of scope" statement, only Foundation Bridge FFI bindings for the five named items (Query execution, Query plans, Query statistics, Query profiles, Query cache) were built, verified via `flutter analyze`/`flutter test`. No Studio UI screens were built for this surface, exactly as none were built for WP-EKE-001/WP-EKE-002's surfaces above.

**Memory ownership.** `oep_eqe_plan_query` allocates two `oep_package_id_list_t` arrays (`indexes_used`, `execution_order`), each released with `oep_package_id_list_release`. `oep_eqe_execute_query` allocates two `oep_package_id_list_t` arrays (matching objects, matching relationships), same release function; its `oep_query_result_summary_t` output is a plain, pointer-free value type with no release function. `oep_eqe_query_statistics` fills a caller-supplied `oep_query_result_summary_t` — no allocation. `oep_eqe_query_cache_info` fills a caller-supplied `oep_query_cache_info_t` (plain value type, `plan_count`/`result_count`) — no allocation. `oep_eqe_clear_query_cache` allocates nothing.

**Errors:** every function requires an open repository and a prior successful `oep_kge_build_graph`/`_refresh_graph` on the same handle (mirroring every WP-EKE-002 `oep_kge_*` function's precondition), failing with `OEP_ERROR_INVALID_STATE` otherwise. `NULL` for a required `runtime`/`request`/output-pointer argument fails with `OEP_ERROR_INVALID_ARGUMENT`.

**Cache invalidation is caller-driven, not automatic — the same documented architectural limitation WP-EKE-002 discloses for incremental Knowledge Graph updates.** `QueryCache` cannot detect a Knowledge Graph rebuild on its own, since `EngineeringContext`/`RuntimeService` still have no event-subscription mechanism. A caller must explicitly call `oep_eqe_clear_query_cache` after `oep_kge_build_graph`/`_refresh_graph` if it wants subsequent queries to reflect the rebuilt graph — nothing in this API does that automatically.

## Engineering Rules Engine (WP-EKE-004)

New functions exposing `oep::engine::RulesEngine` — the data-driven rule evaluation framework WP-EKE-004 builds on top of WP-EKE-003's Engineering Query Engine (and, for scope resolution, WP-EKE-002's Knowledge Graph Engine). `oep_runtime_impl` (internal) gained a `rules_engine` member constructed from `engine_context`/`knowledge_graph_engine`/`engineering_query_engine` — never bypassing any of those layers, matching the "consume this API's own next-lower layer only" pattern every WP-EKE surface has followed since WP-EKE-001.

```c
oep_rule_condition_t conditions[1];
conditions[0].kind = OEP_RULE_CONDITION_REQUIRES_TAG;
strcpy(conditions[0].tag_value, "reviewed");

oep_engineering_rule_t rule = {0};
strcpy(rule.rule_id, "requires-reviewed-tag");
strcpy(rule.name, "Requires Reviewed Tag");
strcpy(rule.message, "Object is missing the 'reviewed' tag.");
rule.category = OEP_RULE_CATEGORY_METADATA;
rule.severity = OEP_RULE_SEVERITY_WARNING;
rule.scope.kind = OEP_RULE_SCOPE_ALL_OBJECTS;
rule.conditions = conditions;          /* caller-owned input array */
rule.condition_count = 1;

oep_rules_register(runtime, &rule);

oep_rule_evaluation_result_t result;
oep_package_id_list_t affected;
oep_rule_diagnostic_list_t diagnostics;
oep_rules_evaluate(runtime, "requires-reviewed-tag", &result, &affected, &diagnostics);
printf("%s (%d affected)\n", oep_rule_evaluation_status_to_string(result.status), affected.count);
oep_package_id_list_release(&affected);
oep_rule_diagnostic_list_release(&diagnostics);

oep_rule_evaluation_summary_list_t summaries;
oep_rules_evaluate_all(runtime, &summaries);
for (int i = 0; i < summaries.count; ++i) {
    printf("%s -> %s\n", summaries.items[i].rule_id,
           oep_rule_evaluation_status_to_string(summaries.items[i].status));
}
oep_rule_evaluation_summary_list_release(&summaries);
```

- `oep_rules_register` — registers an `EngineeringRule` constructed entirely from the caller-supplied `oep_engineering_rule_t`/`oep_rule_condition_t` array. **This is the API's first array-of-STRUCTS input** — every prior array-input function (`oep_kge_subgraph`, WP-EKE-002) took an array of strings; `conditions`/`condition_count` here is the first caller-owned array of a non-string, non-fixed struct type. It extends the array-input precedent `oep_kge_subgraph` established rather than inventing an unrelated mechanism.
- `oep_rules_remove`/`oep_rules_enable`/`oep_rules_disable` — the natural registry completions, mirroring `RuleRegistry`'s C++ surface exactly.
- `oep_rules_list_all`/`oep_rules_list_enabled`/`oep_rules_list_disabled` — **three separate functions rather than one function with a mode flag**, matching the precedent `oep_kge_build_graph`/`oep_kge_refresh_graph` already set (distinct, unambiguous function names over a flag parameter) — each reuses the existing `oep_package_id_list_t` type for its sorted rule-id list, the same generic id-list reuse decision WP-EKE-001/WP-EKE-002/WP-EKE-003 already made repeatedly rather than inventing a "rule id list" type.
- `oep_rules_get` — the full `oep_engineering_rule_t` for one registered rule (`out_found == 0` for an unknown id is a normal result, not an error), plus its conditions via a separate `oep_rule_condition_list_t` output. See the input/output asymmetry below.
- `oep_rules_evaluate` — evaluates one registered rule by id **regardless of its enabled/disabled state** (an explicit request to evaluate a specific rule overrides the enabled flag, which only gates `oep_rules_evaluate_all`), against the built Knowledge Graph. Returns the scalar `oep_rule_evaluation_result_t` (status, message) plus two independently-nullable out-parameters — `out_affected_objects` (`oep_package_id_list_t`) and `out_diagnostics` (`oep_rule_diagnostic_list_t`) — since either can be genuinely empty (e.g. `NotApplicable`) and a caller may only want one of the two.
- `oep_rules_evaluate_all` — evaluates every **enabled** rule, sorted by rule_id, and returns **summaries only** (`oep_rule_evaluation_summary_t`: rule_id, status, message, affected-object count, diagnostic count — not the full affected-object/diagnostic lists). A deliberate scope decision: returning full per-rule detail for every rule at once would require a nested owned-list-of-owned-lists shape with no precedent anywhere in this API (every other list-returning function returns one flat, homogeneous array). A caller wanting full detail for a specific rule calls `oep_rules_evaluate` with a rule_id obtained from `oep_rules_list_enabled`.
- `oep_rule_evaluation_status_to_string`/`oep_rule_category_to_string`/`oep_rule_severity_to_string`/`oep_rule_scope_kind_to_string`/`oep_rule_condition_kind_to_string` — deterministic names for each enum, never returning `NULL`.

**`oep_engineering_rule_t` — used for both input and output, but with a deliberate asymmetric contract.** On **input** (`oep_rules_register`), `conditions`/`condition_count` are a caller-owned array Foundation only reads for the duration of the call — no ownership transfer, nothing to release, matching `oep_object_create_spec_t`/`oep_relationship_create_spec_t`'s existing caller-owned-input convention. On **output** (`oep_rules_get`), those two fields are always `NULL`/`0` — conditions instead come back through a **separate** `oep_rule_condition_list_t` output parameter (`out_conditions`), Foundation-owned and released with `oep_rule_condition_list_release`. This keeps the struct itself ownership-free in both directions: as an input it never allocates, and as an output it never embeds a Foundation-owned pointer a caller might forget to release or might mistakenly try to reuse as input. Worth stating explicitly, since a reader glancing at one struct used for two calls could otherwise assume the same fields behave the same way in both directions.

**Rule model and condition primitives.** `oep_rule_condition_kind_t` mirrors `RuleConditionKind` exactly — ten values: `RequiresRelationship`, `ForbidsRelationship`, `MinRelationshipCount`, `MaxRelationshipCount`, `RequiresTag`, `ForbidsTag`, `HasDescription`, `HasAuthor`, `NoCycles`, `NoIsolatedObjects`. `oep_rule_condition_t` is a single fixed-layout struct carrying every parameter every kind might need (relationship type, tag value, count threshold) — only the fields relevant to `kind` are read, the same "extra fields simply unused" convention `oep_engine_query_request_t`'s discriminated-kind struct already established in WP-EKE-001. `oep_rule_category_t` (Structural/Connectivity/Dependency/Reference/Documentation/Metadata/Package), `oep_rule_severity_t`, and `oep_rule_scope_t`/`oep_rule_scope_kind_t` (AllObjects/ByObjectType/ByDomain/ByPackage/SingleObject) round out the rule model, mirroring `rule_types.hpp` field-for-field. `oep_rule_diagnostic_t` (`object_id`, `detail`) mirrors `RuleDiagnostic` exactly, `object_id` left empty for a graph-level diagnostic such as a `NoCycles` violation.

**Memory ownership.** `oep_rules_register`/`_remove`/`_enable`/`_disable` allocate nothing. `oep_rules_list_all`/`_enabled`/`_disabled` each allocate one `oep_package_id_list_t`, released with `oep_package_id_list_release`. `oep_rules_get` fills a caller-supplied `oep_engineering_rule_t` (no allocation for the struct itself) plus a separate `oep_rule_condition_list_t` output, released with `oep_rule_condition_list_release`. `oep_rules_evaluate` fills a caller-supplied `oep_rule_evaluation_result_t` (a plain, pointer-free value type — status and message only, no release function) plus two independently-nullable, independently-owned outputs — `out_affected_objects` released with `oep_package_id_list_release`, `out_diagnostics` released with `oep_rule_diagnostic_list_release`. `oep_rules_evaluate_all` allocates one `oep_rule_evaluation_summary_list_t` (plain, pointer-free summary structs — no nested allocation, by construction of the summaries-only decision above), released with `oep_rule_evaluation_summary_list_release`.

**Errors:** every function requires an open repository and fails with `OEP_ERROR_INVALID_STATE` otherwise; `oep_rules_evaluate`/`oep_rules_evaluate_all` additionally require a prior successful `oep_engine_load_graph` **and** `oep_kge_build_graph`/`_refresh_graph` on the same handle (the Rules Engine evaluates against the Knowledge Graph, exactly like the Query Engine before it). `oep_rules_get`/`_evaluate`/`_remove`/`_enable`/`_disable` against an unknown `rule_id` fail with `OEP_ERROR_NOT_FOUND` (except `oep_rules_get`, where an unknown id is a normal `out_found == 0` result, not a failure). `NULL` for a required `runtime`/`rule`/`rule_id`/output-pointer argument fails with `OEP_ERROR_INVALID_ARGUMENT`.

**Not exposed at this boundary, honestly disclosed rather than silently missing:** there is no rule-loading or rule-persistence function — rules registered through `oep_rules_register` live only for the lifetime of the `OEP_Runtime` handle, exactly like the CLI's own process-local registry (see `platform/cli/README.md`'s `oep rules` entries for the CLI-level consequence of this). The Studio UI is not part of this work package's scope at all — per the specification's own explicit "UI implementation remains out of scope" statement, only Foundation Bridge FFI bindings for the four named items (Rule Registry, Rule Evaluation, Rule Results, Rule Diagnostics) were built, verified via `flutter analyze`/`flutter test`. No Studio UI screens were built for this surface, exactly as none were built for WP-EKE-001/WP-EKE-002/WP-EKE-003's surfaces above. See `platform/oep_engine/README.md`'s "Engineering Rules Engine (WP-EKE-004)" section for the full Rules Engine this surface exposes, including the central data-driven/no-hardcoded-rules design constraint and the `HasDescription`/`HasAuthor` cross-reference into `EngineeringContext`'s fuller graph.

## Handle Ownership

- `oep_runtime_create` returns an owning handle; the caller must release it with exactly one call to `oep_runtime_destroy`. Returns `NULL` on invalid input or allocation failure — callers must check for `NULL` before use.
- `oep_runtime_destroy` closes an open repository first if necessary (mirroring `FoundationRuntime::shutdown`), then frees the handle. It is safe to call with `NULL` (a no-op) and safe to call on any state, including one with a repository still open.
- `oep_result_t` is a plain value type (a `struct` returned by value, containing only an `int`, two `enum`s, and a fixed `char[256]` buffer). It owns no heap memory and requires no release function.
- `oep_repository_status_t`, `oep_object_info_t`, `oep_repository_statistics_t`, `oep_relationship_info_t`, `oep_object_search_result_t`, and `oep_relationship_search_result_t` are likewise plain, pointer-free value types — safe to copy with `memcpy` and safe to convert directly into a language-native model by a Bridge.
- `oep_object_list_t`, `oep_relationship_list_t`, `oep_object_search_result_list_t`, `oep_relationship_search_result_list_t`, `oep_batch_create_objects_result_t`, `oep_batch_create_relationships_result_t`, `oep_installed_package_list_t`, `oep_dependency_entry_list_t`, `oep_package_id_list_t`, and `oep_repository_event_list_t` each carry one Foundation-owned heap array (`items`/`created.items`); `oep_repository_search_result_t` carries two (one per embedded list). Every allocating structure is paired with exactly one matching release function — `oep_object_list_release`, `oep_relationship_list_release`, `oep_object_search_result_list_release`, `oep_relationship_search_result_list_release`, `oep_repository_search_result_release`, `oep_batch_create_objects_result_release`, `oep_batch_create_relationships_result_release`, `oep_installed_package_list_release`, `oep_dependency_entry_list_release`, `oep_package_id_list_release`, and `oep_repository_event_list_release` respectively — see "Engineering Object Enumeration", "Engineering Relationship Enumeration", "Repository Search", "Package Installation", "Dependency Resolution", "Repository Events", and [MUTATION_API.md](MUTATION_API.md) above for the exact ownership contract of each. `oep_package_install_result_t` and `oep_dependency_resolution_result_t` are plain, pointer-free value types like `oep_repository_status_t` — no release function needed. `oep_uninstall_impact_t` and `oep_update_impact_t` (WP-REP-007) are likewise plain value types, except that each embeds one `oep_package_id_list_t` (`blocking_dependents`/`broken_dependents` respectively) — release that embedded list with `oep_package_id_list_release`, the same function WP-REP-005 already introduced; `oep_package_uninstall_result_t`/`oep_package_update_result_t` are plain, pointer-free value types with no release function.
- `oep_object_create_spec_t`/`oep_relationship_create_spec_t` (batch mutation input) are the one exception that goes the other direction: their `const char*` fields point to **caller**-owned memory. Foundation only reads them for the duration of the batch call; there is no ownership transfer and nothing to release.
- **WP-EKE-002 exception:** `oep_kge_export_json`/`oep_kge_export_graphml_placeholder` are the one pair in this API that return a heap-allocated string directly rather than through a `*_list_t` struct — released with the new `oep_string_release(char*)`, not any of the `*_list_release` functions above. This is a deliberate, narrow departure from the "aside from the allocating output structures above, no function returns a heap-allocated string" rule that otherwise holds for every function documented below, made because export size is genuinely unbounded (see "Engineering Knowledge Graph Engine (WP-EKE-002)" above for the full rationale). `oep_kge_graph_statistics`/`oep_kge_validate_graph`'s `*out_valid`/`oep_kge_connected_components`/`oep_kge_shortest_path`/`oep_kge_subgraph`/`oep_kge_build_graph`/`_refresh_graph` otherwise follow the existing conventions exactly: `oep_graph_statistics_t` is a plain, pointer-free value type with no release function; `oep_graph_issue_list_t` and `oep_component_membership_list_t` each carry one Foundation-owned heap array, released with `oep_graph_issue_list_release`/`oep_component_membership_list_release` respectively; `oep_kge_shortest_path`/`oep_kge_subgraph` reuse `oep_package_id_list_t`/`oep_package_id_list_release` unchanged.
- Aside from the allocating output structures above (and the WP-EKE-002 exception immediately above), no function in this API returns a heap-allocated string or buffer the caller must free. Every other string-valued output is either a pointer into static storage (documented as such at each function, e.g. `oep_foundation_version`, `oep_runtime_state_to_string`) or copied into a caller-supplied fixed buffer embedded in a result/status structure.

## Thread Safety

- A single `OEP_Runtime` handle is **not** safe for concurrent calls — exactly one thread may call functions against a given handle at a time, matching `FoundationRuntime`'s own single-threaded design (it introduces no internal locking).
- **Distinct** `OEP_Runtime` handles are fully independent and may be used concurrently from different threads, since each wraps its own `FoundationRuntime` instance with no shared mutable state.
- Functions that take no `OEP_Runtime` (`oep_foundation_version`, `oep_api_version`, `oep_abi_version`, `oep_runtime_state_to_string`, `oep_error_code_to_string`, `oep_error_category_to_string`, `oep_object_type_to_string`, `oep_relationship_type_to_string`, `oep_match_location_to_string`) are stateless and safe to call from any thread at any time.
- Every `*_release` function (`oep_object_list_release`, `oep_relationship_list_release`, `oep_object_search_result_list_release`, `oep_relationship_search_result_list_release`, `oep_repository_search_result_release`) operates only on the structure passed to it and touches no `OEP_Runtime` state — safe to call from any thread, including one different from the thread that populated the structure, as long as no other thread is concurrently using or releasing the same structure.
- Relationship enumeration (`oep_relationship_store_get_count`/`_get_by_id`/`_list`) and search (`oep_search_repository`/`_objects`/`_relationships`) follow the same single-handle rule as every other `OEP_Runtime`-taking function: not safe for concurrent calls against the *same* handle, fully independent across *distinct* handles. Search additionally reads the in-memory index `SearchEngine::build_index` constructed when the repository was opened — that index is owned by the `FoundationRuntime` behind the handle, so the same single-handle rule covers it without any separate locking concern.
- **Object/relationship mutation and transactions (Work Package 014) introduce no new guarantee beyond the single-handle rule** — they follow it exactly. A transaction's state (`transaction_active_`, its undo log) lives inside the `FoundationRuntime` a given handle wraps, so it is inherently per-handle: two distinct handles have entirely independent transactions, even against the same repository directory. Note that `ObjectStore`/`RelationshipStore` perform no file locking, so concurrent mutation through two handles against the *same* repository is not a supported configuration regardless of transactions — a pre-existing characteristic of the Repository layer, not something this API changes or protects against.
- **Package Installation (WP-REP-001) follows the same single-handle rule**, with the same "no cross-handle file locking" caveat: `oep_package_install` performs multiple sequential writes (object/relationship creation, then a Package Registry record) against the same on-disk repository a plain mutation call would touch, so it is no more and no less safe for concurrent use than any other mutating function in this API.
- Bridge implementations that expose Foundation to a multi-threaded host environment (e.g. a UI event loop plus background workers) must serialize access to a single handle themselves — a mutex or a single dedicated "Foundation thread" per handle are both correct strategies.

## Error Handling

Every function that can fail returns an `oep_result_t`:

```c
typedef struct oep_result_t {
    int success;
    oep_error_code_t error_code;
    oep_error_category_t error_category;
    char error_message[OEP_MAX_ERROR_MESSAGE];
} oep_result_t;
```

`error_code` is one of `OEP_ERROR_NONE` (only on success), `OEP_ERROR_INVALID_ARGUMENT`, `OEP_ERROR_INVALID_STATE`, `OEP_ERROR_NOT_FOUND`, `OEP_ERROR_OPERATION_FAILED`, or `OEP_ERROR_INTERNAL`. `error_category` is a coarser grouping (`OEP_ERROR_CATEGORY_VALIDATION`/`STATE`/`IO`/`INTERNAL`) — per OEP-SPEC-022 section 4, this lets a Bridge branch on a small, stable set of categories without needing to keep its own logic in sync with every individual error code Foundation might add later. `oep_error_code_to_string`/`oep_error_category_to_string` provide stable, English-language names for logging; `error_message` itself is meant for a human (or for a Bridge to pass through to one) — Bridges should switch on `error_code`/`error_category`, not parse `error_message`.

Native C++ exceptions never cross this boundary: every exported function wraps its body in `try`/`catch (...)`, translating any unexpected exception into `OEP_ERROR_INTERNAL` with the exception's `what()` (if available) as the message.

## Versioning

Three independent version signals are exposed, per OEP-SPEC-021 section 8:

- `oep_foundation_version()` — the Foundation version this build implements (e.g. `"0.1.0"`), shared with the CLI (`oep::runtime::kFoundationVersion`, `oep version`/`oep status`) so both layers always agree.
- `oep_api_version()` — `OEP_API_VERSION`, incremented for any addition or change to this API's functions or structures. Currently `19`: bumped 1 → 2 by Work Package 012 (Engineering Object Enumeration, Repository Statistics), 2 → 3 by Work Package 013 (Engineering Relationship Enumeration, Repository Search), 3 → 4 by Work Package 014 (Object/Relationship Mutation, Transactions, Batch Mutation), 4 → 5 by WP-REP-001 (Package Installation), 5 → 6 by WP-REP-002 (Package Lifecycle Queries), 6 → 7 by WP-REP-003 (Repository Transaction Engine), 7 → 8 by WP-REP-004 (Trust & Signing), 8 → 9 by WP-REP-005 (Dependency Resolution), 9 → 10 by WP-REP-006 (Runtime Service, RuntimeContext, Repository Events), 10 → 11 by WP-REP-007 (Package Uninstall & Update), 11 → 12 by WP-REP-008 (Merge Engine), 12 → 13 by WP-EKE-001 (Engineering Knowledge Runtime), 13 → 14 by WP-EKE-002 (Engineering Knowledge Graph Engine), 14 → 15 by WP-EKE-003 (Engineering Query Engine), 15 → 16 by WP-EKE-004 (Engineering Rules Engine), 16 → 17 by WP-EKE-005 (Engineering Validation Engine), 17 → 18 by WP-EKE-006 (Engineering Analysis & Reasoning Engine), and 18 → 19 by WP-EKE-007 (Engineering Intelligence Platform) — every bump purely additive in signature terms; behavior changes (atomic install, commit's possible journal-write error, trust verification before install, dependency resolution before install, six mutation functions now publishing a `RepositoryEvent` on success, uninstall/update as RuntimeService-exclusive atomic operations, merge planning/execution as a further RuntimeService-exclusive atomic operation, a first read-only surface for a consumer entirely outside the Foundation stack, a second, canonical Knowledge Graph surface built on top of that first one, a third, deterministic query surface built on top of that second one, a fourth, data-driven rule evaluation surface built on top of the second and third, a fifth, composition-only validation surface built on top of the second, third, and fourth, a sixth, deterministic analysis-and-reasoning surface built on top of the second through fifth, and now a seventh, top-level orchestration surface composing ALL SIX lower engines behind one unified façade) are documented in their own sections.
- `oep_abi_version()` — `OEP_ABI_VERSION`, incremented only when a change would break binary compatibility with a previously compiled caller (e.g. a struct layout change). Distinct from `OEP_API_VERSION` because a source-compatible addition need not be an ABI break. Still `1` — no work package through WP-EKE-007 has changed the layout of any existing structure; each added only new functions and new structures (`oep_installed_package_info_t` and `oep_package_details_t` in particular were deliberately left unchanged when WP-REP-004 needed to expose trust status — that became the new `oep_package_trust_status_t` and `oep_package_get_trust_status` instead; WP-REP-005 likewise added `oep_dependency_resolution_result_t` and related types rather than modifying any existing structure; WP-REP-006 likewise added `oep_repository_event_t`/`oep_repository_event_list_t` and `oep_runtime_recent_events` rather than modifying any existing structure; WP-REP-007 likewise added `oep_uninstall_impact_t`/`oep_package_uninstall_result_t`/`oep_update_impact_t`/`oep_package_update_result_t` and four new functions rather than modifying any existing structure, also deliberately reusing the existing `oep_package_id_list_t` type from WP-REP-005 rather than inventing a new one for dependent-package lists; WP-REP-008 likewise added `oep_merge_plan_t`/`oep_merge_result_t`/`oep_merge_conflict_t`/`oep_merge_conflict_list_t` and two new functions rather than modifying any existing structure, and deliberately does not expose the nested `RepositoryChangeSet`/`DependencyResolutionReport` at this boundary — only summary counts; WP-EKE-001 likewise added `oep_engine_query_kind_t`/`oep_engine_query_request_t` and six new functions rather than modifying any existing structure, and deliberately reuses the existing `oep_package_id_list_t` type from WP-REP-005 for every object/relationship id-list output rather than inventing a new one; WP-EKE-002 likewise added `oep_graph_issue_kind_t`/`oep_graph_issue_t`/`oep_graph_issue_list_t`/`oep_graph_statistics_t`/`oep_component_membership_t`/`oep_component_membership_list_t` and ten new functions rather than modifying any existing structure — including a new `oep_string_release` function for its two export functions' caller-owned heap strings, a deliberate new ownership convention rather than a change to any existing one; WP-EKE-003 likewise added `oep_query_category_t`/`oep_query_filter_t`/`oep_query_request_t`/`oep_query_plan_t`/`oep_query_result_summary_t`/`oep_query_cache_info_t` and five functions (plus the `oep_eqe_query_cache_info` bonus) rather than modifying any existing structure, reusing `oep_package_id_list_t` for every id-list/string-list output exactly as WP-EKE-001/WP-EKE-002 already do; WP-EKE-004 likewise added `oep_rule_condition_kind_t`/`oep_rule_condition_t`/`oep_rule_category_t`/`oep_rule_severity_t`/`oep_rule_scope_t`/`oep_engineering_rule_t`/`oep_rule_evaluation_status_t`/`oep_rule_evaluation_result_t`/`oep_rule_evaluation_summary_t` and new `oep_rules_*` functions rather than modifying any existing structure — this work package's first array-of-STRUCTS input (`oep_rules_register`'s `conditions`/`condition_count`, extending the array-of-strings precedent `oep_kge_subgraph` established rather than replacing it), a deliberate input/output field asymmetry on the reused `oep_engineering_rule_t` struct rather than two separate struct types, and an `oep_rules_evaluate_all` that returns summaries only rather than a nested owned-list-of-owned-lists with no precedent elsewhere in this API; WP-EKE-005 likewise added `oep_validation_profile_t`/`oep_validation_finding_t`/`oep_validation_finding_list_t`/`oep_validation_report_summary_t`/`oep_validation_statistics_t` and new `oep_validation_*` functions rather than modifying any existing structure, deliberately omitting `affected_objects`/`diagnostics` from `oep_validation_finding_t` (the same nested-detail-trimming precedent `oep_rules_evaluate_all` already established — full detail is one `oep_rules_evaluate` call away) and deliberately skipping a C equivalent of `validate_query_result()` entirely, recommending `oep_eqe_execute_query` + `oep_validation_validate_objects` composition instead; WP-EKE-006 likewise added `oep_dependency_report_t`/`oep_impact_report_t`/`oep_reachability_report_t`/`oep_root_cause_report_t`/`oep_reasoning_summary_t`/`oep_engineering_conclusion_t`/`oep_engineering_recommendation_t`/`oep_evidence_node_t` and new `oep_analysis_*`/`oep_reasoning_*` functions rather than modifying any existing structure, reusing `oep_package_id_list_t` for every id-list output exactly as every prior WP-EKE surface does, routing `oep_analysis_root_cause` exclusively through `ReasoningEngine`'s self-validating overload rather than exposing `AnalysisEngine`'s two-argument version, fetching conclusion/recommendation detail by stable string id rather than index (the same precedent `oep_rules_evaluate` already established), and deliberately exposing only single-node-by-id Evidence Graph access with no full-graph enumeration; WP-EKE-007 likewise added `oep_workflow_kind_t`/`oep_workflow_result_t`/`oep_inspection_target_kind_t`/`oep_knowledge_session_summary_t`/`oep_engineering_summary_report_t`/`oep_engineering_health_report_t`/`oep_runtime_metrics_t` and new `oep_eip_*` functions rather than modifying any existing structure, reusing `oep_package_id_list_t` for every id-list output exactly as every prior WP-EKE surface does — including, for `oep_eip_engineering_recommendations`, reusing it to carry recommendation MESSAGE strings rather than structured recommendation objects, a documented scope decision rather than a new type).

Applications and Bridges should check `oep_abi_version()` against the version they were built against before relying on any struct layout in this header.

## Bridge Integration Guidance (OEP-SPEC-022)

A Bridge is any language-neutral adapter that exposes this API to a non-C++ host (Flutter/Dart, C#, Python, Java, etc.). Foundation provides the primitives every Bridge needs; it does not implement any Bridge itself:

- **Runtime state** — `oep_runtime_get_state`/`oep_runtime_state_to_string` give a Bridge a deterministic, five-value state machine to mirror in its own language-native model (e.g. a Dart enum or a C# enum), without needing to infer state from error text.
- **Error translation** — `error_code`/`error_category` are stable enums suitable for mapping onto language-native exception types or result unions; `error_message` is suitable for direct display or logging without further processing.
- **Data conversion** — `oep_repository_status_t`, `oep_object_info_t`, `oep_repository_statistics_t`, `oep_relationship_info_t`, `oep_object_search_result_t`, and `oep_relationship_search_result_t` are all fixed-layout, pointer-free C structs: no `std::string`, no `std::vector`, no owning pointers. A Bridge can copy any of them directly into a native struct/record field-by-field without any Foundation-provided marshaling code, and doing so is deterministic — the same repository state and query always produce the same structure contents. `oep_object_list_t`, `oep_relationship_list_t`, `oep_object_search_result_list_t`, `oep_relationship_search_result_list_t`, `oep_batch_create_objects_result_t`, and `oep_batch_create_relationships_result_t` are the exceptions carrying an owned pointer; a Bridge should convert each element into its native collection type and then call the matching release function promptly, rather than holding the array open indefinitely. `oep_object_create_spec_t`/`oep_relationship_create_spec_t` go the other direction — a Bridge populates them (typically from a native array/list it already owns) purely as call input; Foundation never retains a pointer from them past the call.
- **Compatibility** — a Bridge should check `oep_abi_version()` at startup and refuse to load (or warn loudly) if it was generated against/tested with a different ABI version, since a struct layout it depends on may have changed.

This module does not implement a Flutter, C#, Python, or Java Bridge — those are explicitly out of scope for both OEP-SPEC-021 and OEP-SPEC-022 and belong to future, separately ratified tasks. Work Packages 012 and 013 added read-only surfaces (enumeration, statistics, search) with no mutation and no server-side filtering (author/tag/type remain a Studio-side responsibility applied to returned results). Work Package 014 is the first work package to add mutation — object/relationship create/update/delete, transactions, and batch mutation; see [MUTATION_API.md](MUTATION_API.md) for its full reference, including the exact transaction/rollback semantics and error classification table. WP-REP-001 is the first work package to add package installation — see "Package Installation" above for its full reference.
