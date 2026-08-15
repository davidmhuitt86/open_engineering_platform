# API

Status: Foundation (Public C API + Bridge Support + Repository Content Exposure + Search + Mutation + Package Installation)

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

**Explicitly out of scope for this Work Package** (see `platform/installer/README.md` for the full rationale): dependency resolution, merge/ownership logic, digital signature verification, networking, and update. Transactions/atomicity and uninstall were later added by WP-REP-003 and WP-REP-005 respectively — see "Repository Transaction Engine" and "Package Uninstallation" below.

`oep_package_list_installed` returns every Repository Registry record for the open repository (package ID, version, title, install timestamp, source, object/relationship counts), sorted deterministically by `package_id` (ascending, byte-wise), matching the sorting convention every other list-returning function in this API already follows.

## Package Uninstallation (WP-REP-005)

The inverse of `oep_package_install`: removes a package's contribution from the open repository entirely.

```c
oep_package_uninstall_result_t uninstall_result;
oep_result_t result = oep_package_uninstall(runtime, "engineering-demo", &uninstall_result);
if (result.success) {
    printf("Uninstalled %s %s: %d objects, %d relationships removed\n",
           uninstall_result.package_id, uninstall_result.version,
           uninstall_result.objects_deleted, uninstall_result.relationships_deleted);
}
```

`oep_package_uninstall` delegates entirely to `FoundationRuntime::uninstall_package`, which: looks up `package_id` in the Repository Registry (`OEP_ERROR_NOT_FOUND` if it is not installed), deletes every Relationship then every Engineering Object the registry recorded for it via the same `RelationshipStore::remove`/`ObjectStore::remove` paths `oep_relationship_delete`/`oep_object_delete` already use, removes the Repository Registry record, and rebuilds the Search/Graph indexes — the same final step `oep_package_install` performs.

**Atomic**, exactly like `oep_package_install` since WP-REP-003: the whole uninstall runs inside one Repository Transaction, so a failure partway through rolls back every delete already performed, leaving the package installed exactly as before. Does not delete or otherwise touch the source `.oep` archive the package was originally installed from (it is transport, not installed content — see "Trust & Signing" and `oep_package_verify`'s own `archive_available` field for the same distinction). Dependency-aware cascading uninstall (removing packages that depend on the one being uninstalled) is not part of this surface — see OEP-ARCH-002 for the roadmap.

## Package Lifecycle Queries (WP-REP-002, Repository Registry & Lifecycle)

Read-only queries over the Repository Registry — the authoritative inventory of every `.oep` package installed in the open Foundation Repository. Nothing here mutates; update and activation remain out of scope (uninstall is now covered by WP-REP-005, above).

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

**Memory ownership:** `oep_package_install`/`oep_package_uninstall` allocate nothing beyond the caller-supplied `oep_package_install_result_t`/`oep_package_uninstall_result_t` they fill. `oep_package_list_installed` allocates one heap array (`oep_installed_package_list_t::items`), released with exactly one call to `oep_installed_package_list_release` — same ownership model as every other `*_list_t` in this API.

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

## Handle Ownership

- `oep_runtime_create` returns an owning handle; the caller must release it with exactly one call to `oep_runtime_destroy`. Returns `NULL` on invalid input or allocation failure — callers must check for `NULL` before use.
- `oep_runtime_destroy` closes an open repository first if necessary (mirroring `FoundationRuntime::shutdown`), then frees the handle. It is safe to call with `NULL` (a no-op) and safe to call on any state, including one with a repository still open.
- `oep_result_t` is a plain value type (a `struct` returned by value, containing only an `int`, two `enum`s, and a fixed `char[256]` buffer). It owns no heap memory and requires no release function.
- `oep_repository_status_t`, `oep_object_info_t`, `oep_repository_statistics_t`, `oep_relationship_info_t`, `oep_object_search_result_t`, and `oep_relationship_search_result_t` are likewise plain, pointer-free value types — safe to copy with `memcpy` and safe to convert directly into a language-native model by a Bridge.
- `oep_object_list_t`, `oep_relationship_list_t`, `oep_object_search_result_list_t`, `oep_relationship_search_result_list_t`, `oep_batch_create_objects_result_t`, `oep_batch_create_relationships_result_t`, and `oep_installed_package_list_t` each carry one Foundation-owned heap array (`items`/`created.items`); `oep_repository_search_result_t` carries two (one per embedded list). Every allocating structure is paired with exactly one matching release function — `oep_object_list_release`, `oep_relationship_list_release`, `oep_object_search_result_list_release`, `oep_relationship_search_result_list_release`, `oep_repository_search_result_release`, `oep_batch_create_objects_result_release`, `oep_batch_create_relationships_result_release`, and `oep_installed_package_list_release` respectively — see "Engineering Object Enumeration", "Engineering Relationship Enumeration", "Repository Search", "Package Installation", and [MUTATION_API.md](MUTATION_API.md) above for the exact ownership contract of each. `oep_package_install_result_t` is a plain, pointer-free value type like `oep_repository_status_t` — no release function needed.
- `oep_object_create_spec_t`/`oep_relationship_create_spec_t` (batch mutation input) are the one exception that goes the other direction: their `const char*` fields point to **caller**-owned memory. Foundation only reads them for the duration of the batch call; there is no ownership transfer and nothing to release.
- Aside from the allocating output structures above, no function in this API returns a heap-allocated string or buffer the caller must free. Every other string-valued output is either a pointer into static storage (documented as such at each function, e.g. `oep_foundation_version`, `oep_runtime_state_to_string`) or copied into a caller-supplied fixed buffer embedded in a result/status structure.

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
- `oep_api_version()` — `OEP_API_VERSION`, incremented for any addition or change to this API's functions or structures. Currently `9`: bumped 1 → 2 by Work Package 012 (Engineering Object Enumeration, Repository Statistics), 2 → 3 by Work Package 013 (Engineering Relationship Enumeration, Repository Search), 3 → 4 by Work Package 014 (Object/Relationship Mutation, Transactions, Batch Mutation), 4 → 5 by WP-REP-001 (Package Installation), 5 → 6 by WP-REP-002 (Package Lifecycle Queries), 6 → 7 by WP-REP-003 (Repository Transaction Engine), 7 → 8 by WP-REP-004 (Trust & Signing), and 8 → 9 by WP-REP-005 (Package Uninstallation, `oep_package_uninstall`) — every bump purely additive in signature terms; behavior changes (atomic install, commit's possible journal-write error, trust verification before install) are documented in their own sections.
- `oep_abi_version()` — `OEP_ABI_VERSION`, incremented only when a change would break binary compatibility with a previously compiled caller (e.g. a struct layout change). Distinct from `OEP_API_VERSION` because a source-compatible addition need not be an ABI break. Still `1` — no work package through WP-REP-005 has changed the layout of any existing structure; each added only new functions and new structures (`oep_installed_package_info_t` and `oep_package_details_t` in particular were deliberately left unchanged when WP-REP-004 needed to expose trust status — that became the new `oep_package_trust_status_t` and `oep_package_get_trust_status` instead; `oep_package_uninstall_result_t` is likewise a new structure, not a modification of `oep_package_install_result_t`).

Applications and Bridges should check `oep_abi_version()` against the version they were built against before relying on any struct layout in this header.

## Bridge Integration Guidance (OEP-SPEC-022)

A Bridge is any language-neutral adapter that exposes this API to a non-C++ host (Flutter/Dart, C#, Python, Java, etc.). Foundation provides the primitives every Bridge needs; it does not implement any Bridge itself:

- **Runtime state** — `oep_runtime_get_state`/`oep_runtime_state_to_string` give a Bridge a deterministic, five-value state machine to mirror in its own language-native model (e.g. a Dart enum or a C# enum), without needing to infer state from error text.
- **Error translation** — `error_code`/`error_category` are stable enums suitable for mapping onto language-native exception types or result unions; `error_message` is suitable for direct display or logging without further processing.
- **Data conversion** — `oep_repository_status_t`, `oep_object_info_t`, `oep_repository_statistics_t`, `oep_relationship_info_t`, `oep_object_search_result_t`, and `oep_relationship_search_result_t` are all fixed-layout, pointer-free C structs: no `std::string`, no `std::vector`, no owning pointers. A Bridge can copy any of them directly into a native struct/record field-by-field without any Foundation-provided marshaling code, and doing so is deterministic — the same repository state and query always produce the same structure contents. `oep_object_list_t`, `oep_relationship_list_t`, `oep_object_search_result_list_t`, `oep_relationship_search_result_list_t`, `oep_batch_create_objects_result_t`, and `oep_batch_create_relationships_result_t` are the exceptions carrying an owned pointer; a Bridge should convert each element into its native collection type and then call the matching release function promptly, rather than holding the array open indefinitely. `oep_object_create_spec_t`/`oep_relationship_create_spec_t` go the other direction — a Bridge populates them (typically from a native array/list it already owns) purely as call input; Foundation never retains a pointer from them past the call.
- **Compatibility** — a Bridge should check `oep_abi_version()` at startup and refuse to load (or warn loudly) if it was generated against/tested with a different ABI version, since a struct layout it depends on may have changed.

This module does not implement a Flutter, C#, Python, or Java Bridge — those are explicitly out of scope for both OEP-SPEC-021 and OEP-SPEC-022 and belong to future, separately ratified tasks. Work Packages 012 and 013 added read-only surfaces (enumeration, statistics, search) with no mutation and no server-side filtering (author/tag/type remain a Studio-side responsibility applied to returned results). Work Package 014 is the first work package to add mutation — object/relationship create/update/delete, transactions, and batch mutation; see [MUTATION_API.md](MUTATION_API.md) for its full reference, including the exact transaction/rollback semantics and error classification table. WP-REP-001 is the first work package to add package installation — see "Package Installation" above for its full reference.
