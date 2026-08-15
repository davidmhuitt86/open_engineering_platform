# CURRENT_SPRINT
# CURRENT_SPRINT.md
## Open Engineering Platform (OEP)

Sprint: WP-REP-004 (Repository Runtime — Repository Trust & Signing Subsystem)

Status: Complete — awaiting user review/approval

---

# Sprint Name

Repository Templates & Batch Operations (Work Package 010)

---

# Sprint Objective

Implement Repository Graph CLI Commands per OEP-SPEC-016-GRAPH_COMMANDS: `oep graph neighbors|traverse|path`, backed exclusively by Foundation Runtime and the existing `GraphEngine`.

The goal is not to build graph visualization, shortest-path algorithms, or interactive exploration.

The goal is to make the connections between Engineering Objects navigable from the CLI, while all graph algorithms stay owned by the Repository subsystem.

---

# Primary Deliverable

`GraphCommand` + `FoundationRuntime::graph_engine()`

`FoundationRuntime` gains a sixth registered service (`GraphEngine`, built the same way `SearchEngine` already is); `GraphCommand` is a thin layer over it.

---

# Sprint Scope

This sprint includes:

- `FoundationRuntime::graph_engine()`
- `graph neighbors <object-id>` / `graph traverse <object-id> [--algorithm bfs|dfs]` / `graph path <source> <target>`
- Updated `platform/runtime/CLI_USAGE.md`
- Unit tests

---

# Out of Scope

The following items are explicitly excluded from this sprint:

- Graph visualization
- Shortest-path algorithms
- Weighted traversal
- Interactive graph exploration
- Graph editing
- Runtime
- SDK
- Studios
- Exchange
- Networking
- Authentication
- Plugin System
- GUI

If implementation of these items appears necessary, document the dependency and continue working within the current sprint boundaries.

---

# Acceptance Criteria

This sprint is complete when:

- The project builds successfully.
- Neighbor discovery, BFS traversal, DFS traversal, and path detection all execute successfully.
- Runtime integration is preserved; the CLI never constructs `GraphEngine` directly.
- Help lists the `graph` command.
- `CLI_USAGE.md` is updated.
- Unit tests covering neighbor discovery, BFS/DFS traversal, disconnected graphs, invalid object IDs, path detection, empty repositories, and Runtime integration pass.
- Documentation is updated.

---

# Definition of Success

At the conclusion of this sprint:

A new developer should be able to clone the repository, build the CLI, execute it, understand the architecture, and be prepared to begin implementing additional commands.

---

# Engineering Principles

During this sprint:

Build only what is necessary.

Avoid feature creep.

Preserve architectural boundaries.

Favor maintainability over speed.

Prefer modularity over convenience.

Do not optimize prematurely.

---

# Deliverables

- OEP CLI executable
- Command registry
- Command interface
- Version command
- Help command
- Initial template framework
- Updated documentation

---

# Risks

Primary risks during this sprint:

- Over-engineering
- Introducing unnecessary dependencies
- Expanding sprint scope
- Breaking architectural boundaries

If any of these occur, stop and reevaluate before continuing.

---

# Next Sprint Preview

Sprint 002

Foundation Generator

Objectives:

- Implement `oep init`
- Generate complete OEP repositories
- Create official repository template
- Validate generated repository
- Prepare for OEP Shell development

This section is informational only and shall not influence implementation during the current sprint.

---

# Completion Review

Before closing the sprint, verify:

✓ Project builds

✓ Documentation updated

✓ Architecture preserved

✓ Repository cleaner than before

✓ Acceptance criteria satisfied

Only then may the sprint be considered complete.

---

# Task 000001 — Verified Complete

`oep --help` and `oep version` were built with MSVC 19.51 (Visual Studio Build Tools 18) via CMake/Ninja and executed successfully (exit code 0 for both). Sprint 001 acceptance criteria are satisfied.

---

# Task 000002 — Verified Complete

`oep init my-workshop` was built and executed with MSVC 19.51 via CMake/Ninja. The generated repository matched OEP-SPEC-002-FOUNDATION_REPOSITORY exactly: `repository/`, `workspace/`, `packages/`, `cache/`, `logs/`, `exports/`, `settings/`, plus `README.md`, `.gitignore`, `repository.json`, and `workspace.json` with a valid UUIDv4 repository ID. Re-running `init` against the same (now non-empty) directory failed safely with exit code 1 and made no changes. Sprint 002 acceptance criteria are satisfied.

---

# Task 000003 — Verified Complete

The `platform/repository` metadata module (schema, loader, writer, validation, internal JSON parser/serializer) was built with MSVC 19.51 via CMake/Ninja. `oep_repository_tests` (6 cases covering valid load, invalid JSON, missing fields, bad UUID, save/round-trip with timestamp refresh, and rejection of invalid metadata) passed via CTest. `oep init` now populates `repository.json` through the new metadata writer, verified end-to-end to match OEP-SPEC-003's schema with no leftover temporary file. Sprint 003 acceptance criteria are satisfied.

---

# Task 000004 — Verified Complete

Added `EngineeringObject`, `ObjectType`, validation, JSON serialization, and a Create/Read/Update/Delete `ObjectStore` to `platform/repository`. UUID generation/validation and UTC timestamp formatting — previously duplicated between the CLI generator and the metadata module — were consolidated into shared `oep/repository/uuid.hpp` and `oep/repository/timestamp.hpp`; the CLI's local `uuid.cpp`/`uuid.hpp` were removed. Built with MSVC 19.51 via CMake/Ninja; `oep_engineering_object_tests` (8 cases: create assigns id/timestamps, load round-trip, missing-object load failure, update preserving immutable fields and refreshing lastModifiedUtc, remove, and validation rejections) passed via CTest alongside the existing metadata tests (2/2 suites). `oep init` re-verified end-to-end after the refactor. Sprint 004 acceptance criteria are satisfied.

---

# Task 000005 — Verified Complete

Added `Relationship`, `RelationshipType`, validation, JSON serialization, and a Create/Read/Update/Delete/Enumerate `RelationshipStore` to `platform/repository`, validated against an `ObjectStore` so relationships can only be created between Engineering Objects that actually exist. Built with MSVC 19.51 via CMake/Ninja; `oep_relationship_tests` (9 cases: create succeeds for existing objects, create fails for a missing object, create fails when source equals target, load round-trip, update preserving immutable fields, remove, enumerate-by-object in both directions, and two validation rejections) passed via CTest alongside the existing metadata and object test suites (3/3 suites). `oep init` re-verified unaffected. Sprint 005 acceptance criteria are satisfied.

---

# Task 000006 — Verified Complete

Filled in `platform/search` (previously a scaffolded, empty module) with `SearchEngine`: `build_index`, `clear_index`, `search_objects`, `search_relationships`, and result types with match location and score. Added `ObjectStore::list_all` and `RelationshipStore::list_all` to `platform/repository` to support index construction, and refactored `list_by_object` to reuse `list_all` rather than duplicating enumeration. Built with MSVC 19.51 via CMake/Ninja; `oep_search_engine_tests` (covering exact/partial/case-insensitive matches across name, description, author, tags, and object type for objects and relationship type/description/author for relationships, missing-index and empty-repository handling, empty-query rejection, determinism across repeated searches, and index rebuild after object removal) passed via CTest alongside the existing three suites (4/4 suites). `oep init` re-verified unaffected. Sprint 006 acceptance criteria are satisfied.

---

# Task 000007 — Verified Complete

Added `GraphEngine` to `platform/repository` (no dedicated `platform/graph` module exists in the frozen architecture, and the spec frames this as a Repository capability): `build_graph`, `clear_graph`, `get_neighbors`, `traverse_breadth_first`, `traverse_depth_first`, `path_exists`, built from `ObjectStore`/`RelationshipStore` via their existing `list_all`. Relationships are treated as connecting their two objects bidirectionally for traversal purposes while preserving the original relationship type/ID on each edge; relationships referencing a missing object are excluded from the graph. Built with MSVC 19.51 via CMake/Ninja; `oep_graph_engine_tests` (covering neighbor discovery with relationship-type preservation, an isolated node, BFS/DFS over a 3-node cycle without infinite looping, determinism across repeated traversals, path existence for connected/disconnected/self pairs, nonexistent-object handling, graph rebuild after object removal, `clear_graph` isolation from repository state, and an empty repository) passed via CTest alongside the existing four suites (5/5 suites). `oep init` re-verified unaffected. Sprint 007 acceptance criteria are satisfied.

---

# Task 000008 — Verified Complete

Added `AuditEvent`/`AuditEventType` and `AuditStore` to `platform/repository`, then changed `ObjectStore`'s and `RelationshipStore`'s constructors to require an `AuditStore`, so every successful create/update/remove automatically records `ObjectCreated`/`ObjectUpdated`/`ObjectDeleted` or `RelationshipCreated`/`RelationshipUpdated`/`RelationshipDeleted` — applications cannot bypass the audit trail by construction. Audit recording is best-effort and never causes an otherwise-successful operation to fail. `AuditEventType::RepositoryCreated` is supported but intentionally not wired into `oep init`, since OEP-SPEC-002's frozen repository layout doesn't define where an audit log lives on disk. Built with MSVC 19.51 via CMake/Ninja; `oep_audit_store_tests` (record/list/list-for-object, validation rejections, `clear`, and two integration tests confirming `ObjectStore` and `RelationshipStore` each auto-record exactly one event per create/update/remove) passed via CTest alongside the existing five suites (6/6 suites). `oep init` re-verified unaffected. Sprint 008 acceptance criteria are satisfied.

---

# Task 000009 — Verified Complete

Filled in `platform/validation` (previously a scaffolded, empty module) with `RepositoryValidator`: `validate_metadata`, `validate_objects`, `validate_relationships`, and `validate_repository`, producing a deterministic `ValidationReport` (Severity/Category/Message/ObjectId findings, plus error/warning/information counts and a Healthy/Unhealthy status). Extended `ObjectStore`/`RelationshipStore`'s `list_all` to report which stored files failed to parse and why (`invalid_entries`), since they previously discarded that information silently — without this, "no invalid object/relationship types exist" could not actually be checked. Built with MSVC 19.51 via CMake/Ninja; `oep_repository_validator_tests` (12 cases covering a healthy repository, each of the ten integrity rules individually via targeted corruption — including cases requiring raw file writes to simulate corruption unreachable through the normal store APIs — validation continuing past multiple simultaneous errors, and report determinism) passed via CTest alongside the existing six suites (7/7 suites). `oep init` re-verified unaffected. Sprint 009 acceptance criteria are satisfied.

---

# Task 000010 — Verified Complete

Added a new `platform/packages` module (no pre-scaffolded placeholder existed for it, unlike Search/Validation) with `PackageManifest`/`PackageType`, validation, and `PackageManager` (`discover_packages`/`load_package`/`list_packages`), per OEP-SPEC-010-PACKAGE_SYSTEM. Promoted `platform/repository`'s internal JSON parser (`src/json_value.hpp`) to a public header (`include/oep/repository/json_value.hpp`) so packages could parse `package.json` without a second JSON implementation. Foundation-version compatibility is checked at major.minor granularity against a version supplied to `PackageManager` by its caller, since no canonical "current Foundation version" constant exists yet. Duplicate packageId detection is implemented in `list_packages` (the only operation with visibility across sibling packages), demoting every package after the first to claim an ID to Invalid. Built with MSVC 19.51 via CMake/Ninja; `oep_package_manager_tests` (9 cases: deterministic discovery, valid load, missing/malformed/invalid-field manifests, unsupported Foundation version, `.disabled` marker handling, duplicate packageId detection, and an invalid package not blocking a valid sibling) passed via CTest alongside the existing seven suites (8/8 suites). `oep init` re-verified unaffected. Sprint 010 acceptance criteria are satisfied.

---

# Task 000011 — Verified Complete

Filled in `platform/runtime` (previously a scaffolded, empty module) with `FoundationRuntime`, per OEP-SPEC-011-FOUNDATION_RUNTIME: `RuntimeState` (Uninitialized/Initialized/RepositoryOpen/RepositoryClosed/Shutdown), deterministic `initialize`/`open_repository`/`close_repository`/`shutdown` transitions, Repository Context accessors (current repository/metadata/package set), and a Service Registry exposing `ObjectStore`/`RelationshipStore`/`AuditStore`/`SearchEngine`/`RepositoryValidator`/`PackageManager` — all constructed and coordinated, none reimplemented. `open_repository` establishes, for the first time, where Engineering Objects/Relationships/Audit Events live within an opened repository (`repository/objects`, `repository/relationships`, `repository/audit`); this is deliberately not wired into `oep init` in this task. Built with MSVC 19.51 via CMake/Ninja; `oep_foundation_runtime_tests` (8 cases: initialize/reinitialize, open-before-initialize rejection, full open/close lifecycle, missing-metadata rejection leaving state unchanged, rejecting a second concurrent open while preserving the first as current, reopening a different repository after close, all six services and all three context accessors being available only while a repository is open, and shutdown idempotency/auto-close/post-shutdown rejection) passed via CTest alongside the existing eight suites (9/9 suites). `oep init` re-verified unaffected. Sprint 011 acceptance criteria are satisfied.

---

# Task 000012 — Verified Complete

Refactored `platform/cli` into a static library (`oep_cli_core`) plus a thin executable, so command logic is directly unit-testable without spawning the built binary as a subprocess. Added `open`/`validate`/`packages`/`status`, each obtaining services exclusively through `FoundationRuntime` (initialize → open_repository → do the work → shutdown), per OEP-SPEC-012-CLI_COMMAND_FRAMEWORK. Extended `Command` with a `usage()` method and `HelpCommand` to print Name/Syntax/Description for every registered command. Consolidated the Foundation version string — previously duplicated between `VersionCommand` and the Foundation Generator — into one `oep::cli::kFoundationVersion` constant, now also passed to every `FoundationRuntime` a command constructs. Wrote `platform/runtime/CLI_USAGE.md` per the spec's Definition-of-Done requirement. Built with MSVC 19.51 via CMake/Ninja; `oep_cli_commands_tests` (9 cases: open succeeding/failing/reporting a descriptive non-crash-looking error, validate reporting Healthy and failing gracefully for a missing repository, packages reporting none discovered, status reporting a fully-populated open-repository summary and a graceful no-repository summary, and help listing every command with syntax and description) passed via CTest alongside the existing nine suites (10/10 suites). Manually smoke-tested every new command plus an invalid-repository case. `oep init` re-verified unaffected. Sprint 012 acceptance criteria are satisfied.

---

# Task 000013 — Verified Complete

Added `oep object create|list|show|delete` to `platform/cli`, per OEP-SPEC-013-ENGINEERING_OBJECT_COMMANDS, each subcommand a thin layer over `FoundationRuntime`/`ObjectStore` with no duplicated business logic. `create` accepts `--type`/`--name` (required) plus `--description`/`--author`/`--tags`; `list` prints Object ID/Type/Name/Version sorted by ID for determinism; `show` prints every field including both timestamps; `delete` removes through the existing `ObjectStore::remove`, which already auto-records an `ObjectDeleted` Audit Event (no new audit wiring needed — confirmed by a dedicated test reading the event back out of the `AuditStore`). Repository selection uses an optional `--repository <path>` flag (defaulting to cwd) rather than a positional argument, since `show`/`delete` already use their one positional slot for the object ID. Updated `platform/runtime/CLI_USAGE.md` with the new command table, example workflow, and limitations, per the spec's Definition-of-Done requirement. Built with MSVC 19.51 via CMake/Ninja; `oep_object_command_tests` (7 cases: missing required create fields, an unrecognized object type, a full create→list→show→delete→show-after-delete lifecycle, the automatic audit event on delete, show failing for a nonexistent ID, list reporting none for an empty repository, and an unknown subcommand being rejected) passed via CTest alongside the existing ten suites (11/11 suites). Manually smoke-tested the full lifecycle against a real generated repository. `oep init` re-verified unaffected. Sprint 013 acceptance criteria are satisfied.

---

# Task 000014 — Verified Complete

Added `oep relationship create|list|show|delete` to `platform/cli`, per OEP-SPEC-014-RELATIONSHIP_COMMANDS, mirroring `ObjectCommand` exactly and backed by `RelationshipStore`. Factored the `--repository <path>` extraction helper (previously duplicated logic if copy-pasted) into a shared `repository_path_option.hpp/.cpp` used by both `object` and `relationship`. `create` requires `--source`/`--target`/`--type` and relies entirely on `RelationshipStore::create`'s existing validation (object existence, source ≠ target, valid type) — no CLI-side re-validation. `delete` removes through the existing `RelationshipStore::remove`, which already auto-records a `RelationshipDeleted` Audit Event, confirmed by a dedicated test. Updated `platform/runtime/CLI_USAGE.md` with the relationship command table, supported types, a full object+relationship workflow, and a validation-rejection example with real captured error text. Built with MSVC 19.51 via CMake/Ninja; `oep_relationship_command_tests` (8 cases: missing required create fields, unrecognized relationship type, nonexistent object reference, matching source/target rejection, a full create→list→show→delete→show-after-delete lifecycle, the automatic audit event on delete, list reporting none for an empty repository, and an unknown subcommand being rejected) passed via CTest alongside the existing eleven suites (12/12 suites). Manually smoke-tested the full lifecycle, including building a two-object relationship, against a real generated repository. `oep init` re-verified unaffected. Sprint 014 acceptance criteria are satisfied.

---

# Task 000015 — Verified Complete

Added `oep search [objects|relationships] <query>` to `platform/cli`, per OEP-SPEC-015_SEARCH_COMMANDS, exposing the existing `SearchEngine` through `FoundationRuntime` with no independent CLI ranking — filtering happens after `SearchEngine` returns results and only ever removes entries, never reorders them. Reused the shared `--repository` helper from Sprint 014. `--type`/`--author` filter both object and relationship results by loading each hit's full record; `--tag` only applies to objects, since `Relationship` has no tags field (documented rather than silently ignored or erroring). Updated `platform/runtime/CLI_USAGE.md` with the search command/filter tables and a full example session with real captured output. Built with MSVC 19.51 via CMake/Ninja; `oep_search_command_tests` (10 cases: object search, relationship search, a bare query searching both, the three filters each individually excluding a non-matching entry, no-match handling, an empty repository, an invalid repository, and a missing query) passed via CTest alongside the existing twelve suites (13/13 suites). Manually smoke-tested bare/objects/relationships forms, a type filter, and an invalid-repository case against a real generated repository. `oep init` re-verified unaffected. Sprint 015 acceptance criteria are satisfied.

---

# Task 000016 — Verified Complete

Extended `FoundationRuntime` with a sixth registered service, `graph_engine()`, built via `GraphEngine::build_graph` during `open_repository` exactly the way `SearchEngine` already is — this was a real gap: the spec required graph commands to never construct `GraphEngine` directly, but Runtime never exposed one at all until now. Added `oep graph neighbors|traverse|path` to `platform/cli`, per OEP-SPEC-016-GRAPH_COMMANDS, each subcommand a thin layer over the new accessor: `neighbors` lists directly connected objects with their relationship type; `traverse` supports `--algorithm bfs` (default) / `dfs`, delegating entirely to `GraphEngine`'s existing traversal; `path` reports only Path Found / No Path Found. Updated `platform/runtime/CLI_USAGE.md` and `platform/runtime/README.md` (service list) with the graph command/filter tables and a full four-object example session with real captured output, including a disconnected node. Built with MSVC 19.51 via CMake/Ninja; `oep_graph_command_tests` (10 cases: neighbor listing, an isolated object reporting none, BFS and DFS traversal over a connected component that correctly excludes a disconnected node, path found/not-found, an invalid object ID, an empty repository, an invalid repository, and an unknown subcommand) passed via CTest alongside the existing thirteen suites (14/14 suites). Manually smoke-tested neighbors/traverse (both algorithms)/path against a real four-object, two-relationship graph, including the disconnected-node case. `oep init` re-verified unaffected. Sprint 016 acceptance criteria are satisfied.

---

# Work Package 009 (Task 000017 + Task 000018) — Verified Complete

Filled in `platform/exchange` (previously a scaffolded, empty module matching PROJECT_MEMORY's "Exchange distributes Repository content" description) with `ExportManifest`, `export_repository`, and `import_repository`, per OEP-SPEC-017-REPOSITORY_EXPORT and OEP-SPEC-018-REPOSITORY_IMPORT. The export archive is a single deterministic JSON document (metadata, objects, relationships, audit log, optional package manifests, and the export manifest itself) rather than a zip/tar, avoiding a new compression-library dependency while still satisfying "a single archive."

Along the way, added `restore()` to `ObjectStore`, `RelationshipStore`, and `AuditStore` (additive-only — existing `create`/`update`/`remove`/`list_all` signatures and behavior are unchanged). This was necessary, not optional: `create()` always regenerates `lastModifiedUtc` and would corrupt round-trip fidelity if reused for import, so faithful reconstruction needed a write-exactly-as-given path that records no audit event (restoring history is not creating new history).

Extended `FoundationRuntime` with `export_repository` (requires an open repository, delegates entirely to `oep::exchange::export_repository`) and `import_repository` (does not require or use an open repository — it targets a destination to create — but is still exposed on the Runtime so import continues to execute "entirely through Foundation Runtime" as both specs require, rather than the CLI reconstructing repository contents directly).

Added `oep export <output-file> [--include-packages] [--repository <path>]` and `oep import <archive-file> [--destination <path>] [--overwrite]` to `platform/cli`. Generalized the `--repository`-only flag helper (from Sprint 014) into `extract_path_option`/`extract_flag`, non-breaking, so `--include-packages`, `--destination`, and `--overwrite` all share the same primitive `extract_repository_path` is now built on.

Updated `platform/runtime/CLI_USAGE.md` (export/import command tables, archive format and validation-order explanation, a full export→import round-trip example with real captured output including exact ID/timestamp preservation, overwrite-rejection and invalid-archive examples, and new limitations), `platform/runtime/README.md` (service list), `platform/cli/README.md`, and `platform/exchange/README.md` (from Placeholder to Foundation).

Built with MSVC 19.51 via CMake/Ninja after a full clean rebuild (`rm -rf build` then reconfigure); `oep_repository_exporter_tests` (4 cases), `oep_repository_importer_tests` (7 cases: successful import preserving identity, overwrite rejection/acceptance, invalid JSON, missing archive, corrupted manifest, unsupported export version, package restoration), `oep_export_command_tests` (4 cases), and `oep_import_command_tests` (5 cases, including a full round-trip through the real CLI commands) all passed via CTest alongside the existing fourteen suites (18/18 suites). One test bug was caught and fixed during verification: a test helper's `sample_metadata()` never set `last_modified_utc`, correctly tripping `validate_metadata`'s required-field check during import — not an exchange-module bug. Manually smoke-tested the complete export→import round trip (exact object ID/author/tags/timestamps preserved), overwrite protection, and invalid-archive rejection against real generated repositories. `oep init` re-verified unaffected. Sprint 017/018 acceptance criteria are satisfied.

---

# Work Package 010 (Task 000019 + Task 000020) — Verified Complete

**Task 000019 — Repository Templates.** Added `TemplateManifest` (Template ID, Name, Version, Description, Author, Tags, Foundation Version) and `TemplateStore` (`create_template`/`list_templates`/`instantiate_template`) to `platform/exchange`, per OEP-SPEC-019-REPOSITORY_TEMPLATES. A template is a single JSON file reusing the same archive codec Export/Import already produce (extended with `TemplateManifest` marshaling) rather than a new format — a template is "a named, reusable archive with its own manifest." `create_template` validates the manifest before writing; `list_templates` silently excludes any file that fails validation rather than crashing the listing; `instantiate_template` fully loads and validates the template *before* touching the destination, rejects a non-empty existing destination, generates a **new** repository ID for the instantiated copy while restoring every object/relationship with its **exact original ID** via the `restore()` path added in Work Package 009. Extended `FoundationRuntime` with `create_template`/`list_templates`/`instantiate_template`, all delegating entirely to `TemplateStore`. Added `oep template create|list|instantiate` to `platform/cli`, reusing the shared `--repository`/path-option helpers and a new shared `split_csv` (extracted from `object_command`'s previously-duplicated `split_tags`, per the work package's pre-authorized shared refactoring).

**Task 000020 — Batch Operations.** Added `BatchProcessor` to `platform/repository` (not `platform/exchange` — bulk CRUD against an *already-open* repository is Repository-domain business logic, like `RepositoryValidator`/`GraphEngine`, distinct from Export/Import/Templates' whole-repository packaging concern), per OEP-SPEC-020-BATCH_OPERATIONS. Defines a deterministic JSON batch format for both create (`objects`/`relationships`, with a batch-local `ref` alias so a relationship can reference an object created earlier in the same batch) and delete (`objectIds`/`relationshipIds`). `validate_batch_create_request` runs before any execution and reports duplicate refs, missing names, unresolvable source/target references, and self-referencing relationships, deterministically; `execute_batch_create`/`execute_batch_delete` both validate fully before writing anything — a batch with any problem creates or deletes **nothing**. Extended `FoundationRuntime` with `execute_batch_create`/`execute_batch_delete`/`validate_batch_create`, all requiring an open repository and taking raw JSON text so the CLI never touches parsed repository types directly. Added `oep batch create|delete|validate <input-file>` to `platform/cli`.

Updated `platform/runtime/CLI_USAGE.md` (template and batch command tables, JSON format documentation, full example sessions with real captured output, new limitations for both), `platform/runtime/README.md`, `platform/cli/README.md`, `platform/repository/README.md`, and `platform/exchange/README.md`.

Built with MSVC 19.51 via CMake/Ninja after a full clean rebuild (`rm -rf build` then reconfigure): 95/95 build steps succeeded. `oep_repository_template_tests` (5 cases: full create→list→instantiate workflow verifying new repository ID with preserved object IDs, instantiate rejecting a nonexistent template, instantiate rejecting an invalid manifest without partially creating the destination, list excluding a corrupt template file, list handling an empty/nonexistent directory), `oep_template_command_tests` (5 cases including a full CLI-level round trip), `oep_batch_processor_tests` (9 cases: malformed JSON rejection for both create and delete, unrecognized type rejection, successful create with in-batch ref resolution, duplicate-ref validation, unknown-reference validation, a failed validation creating nothing, successful delete, a failed delete deleting nothing), and `oep_batch_command_tests` (6 cases covering the full CLI surface) all passed via CTest alongside the existing eighteen suites (22/22 suites, 100% pass). Two compile-time issues were caught and fixed: a missing `#include "oep/repository/timestamp.hpp"` in `repository_template.cpp`, and a missing `#include <map>` plus a wrong include path for `json_value.hpp` in `batch_processor.cpp` (fixed proactively before the first build, based on the equivalent mistake's fix pattern from earlier in the session). Manually smoke-tested template create/list/instantiate (confirming the new repository ID while the object kept its original ID) and batch create/validate/delete (including in-batch ref resolution, duplicate-ref detection, and unknown-reference detection) against real generated repositories. `oep init` re-verified unaffected. Sprint 019/020 acceptance criteria are satisfied.

---

# Work Package 011 (Task 000021 + Task 000022) — Verified Complete

**Task 000021 — Public C API.** Created the `platform/api` subsystem (previously an unspecified placeholder module), per OEP-SPEC-021-PUBLIC_C_API: a pure C ABI (`include/oep/api/oep_api.h`, `extern "C"`, no C++ classes, no STL types) wrapping `oep::runtime::FoundationRuntime`. Opaque handle `OEP_Runtime`; lifecycle functions `oep_runtime_create/destroy/initialize/open_repository/close_repository/shutdown`; `oep_runtime_get_state` mirroring the five `RuntimeState` values; `oep_runtime_get_repository_status` returning a fixed-layout `oep_repository_status_t`; versioning via `oep_foundation_version`/`oep_api_version`/`oep_abi_version`. Every function returns `oep_result_t` (success flag, error code, error category, fixed error-message buffer) rather than throwing; every exported function wraps its body in `try`/`catch (...)` so no native exception ever crosses the boundary, satisfying the spec's ABI-safety requirement directly rather than by convention. Implementation lives in `src/oep_api.cpp` against a private `src/oep_api_internal.hpp` (the concrete struct behind `OEP_Runtime`, never installed), so consumers linking `oep_api` only ever see `oep_api.h` — they cannot reach `platform/runtime`'s C++ types even by accident.

**Task 000022 — Foundation Bridge Support.** Extended the same `oep_api.h`/`oep_api.cpp` (built together with Task 000021, per the work package's authorization for shared refactoring, since both specs describe one coherent ABI surface rather than two separable layers) with the Bridge-facing primitives OEP-SPEC-022 requires: `oep_error_category_t` (a coarse `Validation`/`State`/`IO`/`Internal` grouping over the finer `oep_error_code_t`, so a Bridge can branch on a small stable set without tracking every individual code), `oep_runtime_state_to_string`/`oep_error_code_to_string`/`oep_error_category_to_string` for deterministic, stable names suitable for logging or direct display, and `oep_repository_status_t` as a fixed-layout, pointer-free structure explicitly documented as safe to `memcpy` or convert field-by-field into a language-native model. `platform/api/README.md` documents the full lifecycle, ownership rules, thread-safety guarantees (a single handle is not safe for concurrent use; distinct handles are fully independent), error handling, versioning, and Bridge integration guidance in one place, satisfying both specs' identical "update `platform/api/README.md`" documentation requirement without duplicating content across two files.

Also performed a small pre-authorized shared refactor: consolidated the previously CLI-private Foundation version string (`oep::cli::kFoundationVersion`, a literal `"0.1.0"`) into a new canonical `oep::runtime::kFoundationVersion` (`platform/runtime/include/oep/runtime/foundation_version.hpp`), which both `platform/cli` (unchanged public constant, now delegating) and `platform/api`'s `oep_foundation_version()` reference — so the CLI and the Public C API can never silently drift apart on which Foundation version they report. No public interface changed: `oep::cli::kFoundationVersion` still exists with the same name and value.

Wired `platform/api` into the top-level `CMakeLists.txt` (as a static library, `oep_api`, linked privately against `oep_runtime` so its own consumers never need Runtime's C++ headers) and added `tests/api`, following the existing per-module test directory pattern.

Built with MSVC 19.51 via CMake/Ninja after a full clean rebuild (`rm -rf build` then reconfigure): 99/99 build steps succeeded. `oep_api_tests` (11 cases: version reporting, deterministic state/error-code/error-category stringification, `NULL`-argument rejection for both handle creation and handle-taking calls without crashing, a full initialize→open→status→close→shutdown lifecycle with re-entry-into-wrong-state rejections at every step, opening a nonexistent repository reporting `OEP_ERROR_NOT_FOUND`/`OEP_ERROR_CATEGORY_IO`, a `NULL` repository path reporting `OEP_ERROR_INVALID_ARGUMENT`, repository-status failing safely (and zero-initializing its output) without an open repository, and destroying a handle that still has a repository open) passed via CTest alongside the existing twenty-two suites (23/23 suites, 100% pass). No compile-time or test-runtime bugs were encountered. Manually smoke-tested `oep init`/`oep status` to confirm the Foundation-version-constant refactor introduced no regression. Sprint 021/022 acceptance criteria are satisfied.

---

# Work Package 012 (Task 000023 + Task 000024) — Verified Complete

**Task 000023 — Engineering Object Enumeration API.** Extended `platform/api/include/oep/api/oep_api.h`/`oep_api.cpp` with `oep_object_store_get_count`, `oep_object_store_get_by_id`, and `oep_object_store_list`, per OEP-SPEC-021/022's established pattern and Work Package 012's explicit requirement that all new functionality live in `platform/api/oep_api.h` with no internal Foundation headers exposed. `oep_object_info_t` is a new fixed-layout structure (object ID, type, name, author, version, description, up to `OEP_MAX_OBJECT_TAGS` tags) — no pointers, no STL. `oep_object_store_list` sorts its results deterministically by `object_id` (ascending), mirroring the same client-side sort `ObjectCommand` has always applied, since the underlying `ObjectStore::list_all()` itself has no defined order (filesystem iteration order). This was a real gap worth noting: "deterministic enumeration" could not simply mean "pass through whatever `list_all()` returns" — the API layer had to impose the ordering itself, exactly as the CLI already does.

`oep_object_store_list` is the one function in the entire Public C API that allocates heap memory it hands to the caller (`oep_object_list_t::items`), so a new release function, `oep_object_list_release`, was added alongside it — every other function either writes into a caller-supplied fixed structure or returns a pointer to static storage. Ownership is documented at both the struct and the function.

**Task 000024 — Repository Statistics API.** Added `oep_runtime_get_repository_statistics` and a new fixed-layout `oep_repository_statistics_t` (repository identity, total object count, object counts by type indexed by `oep_object_type_t`, relationship count, package count). Computed entirely from existing `FoundationRuntime` accessors (`object_store()->list_all()`, `relationship_store()->list_all()`, `current_package_set()`) — no new `FoundationRuntime` surface was needed, since Work Package 012's objective was to expose repository contents through the *Public API*, not to change what Foundation Runtime itself coordinates. `package_count` deliberately counts every discovered package regardless of Loaded/Invalid/Disabled state, distinct from the pre-existing `oep_repository_status_t::loaded_package_count` (Loaded only) — documented explicitly at the struct to avoid the two being confused.

Both tasks share one underlying design decision, made once and applied consistently: Studio must never recompute object counts, per-type breakdowns, or relationship/package counts itself by enumerating and counting client-side — Foundation computes and exposes them directly, per the work package's explicit "Studio shall not calculate these values itself" requirement.

`OEP_API_VERSION` was bumped from 1 to 2 (purely additive: new functions and new structures, no existing structure's layout changed) — `OEP_ABI_VERSION` remains 1, since nothing previously compiled against this API would break.

Updated `platform/api/README.md` (new "Engineering Object Enumeration" and "Repository Statistics" sections covering usage, memory ownership, performance considerations, and updated Handle Ownership/Thread Safety/Versioning/Bridge-guidance sections to reference the new structures) and `platform/runtime/README.md` (a note that this work package added no new `FoundationRuntime` surface — the C API layer built its enumeration/statistics functions entirely from Runtime's existing accessors). `CLI_USAGE.md` was not modified: this work package added no CLI-visible command, per its own scope ("through platform/api/oep_api.h" only) — the CLI's `object list` remains a separate, unaffected consumer of `ObjectStore` directly.

Built with MSVC 19.51 via CMake/Ninja after a full clean rebuild (`rm -rf build` then reconfigure): 99/99 build steps succeeded. `oep_api_tests` grew from 11 to 25 cases, adding: object count/list/lookup-by-id success paths, sorted-and-deterministic-across-repeated-calls enumeration, tag/author/type field fidelity, `oep_object_list_release` safety (including double-release and `NULL`), lookup-by-nonexistent-ID reporting `OEP_ERROR_NOT_FOUND`, `NULL`-argument rejection for the new functions, enumeration/statistics both failing with `OEP_ERROR_INVALID_STATE` (and zero-initializing their outputs) without an open repository, statistics reporting correct per-type counts/relationship count/package count against a populated fixture repository, and `oep_object_type_to_string` stringification — all passed via CTest alongside the existing twenty-two suites (23/23 suites, 100% pass). No compile-time or test-runtime bugs were encountered. Manually smoke-tested `oep init`/`oep status` to confirm no regression. Work Package 012's Definition of Done is satisfied: Engineering Objects are enumerable and repository statistics are available through the Public C API alone, with documentation complete and all tests passing.

---

# Work Package 013 (Task 000025 + Task 000026) — Verified Complete

**Task 000025 — Engineering Relationship Enumeration API.** Extended the same `platform/api/include/oep/api/oep_api.h`/`oep_api.cpp` with `oep_relationship_store_get_count`, `oep_relationship_store_get_by_id`, and `oep_relationship_store_list`, mirroring Engineering Object Enumeration (Work Package 012) exactly. `oep_relationship_info_t` is a new fixed-layout structure (relationship ID, source/target object IDs, relationship type, author, description, created timestamp). `oep_relationship_store_list` sorts deterministically by `relationship_id` (ascending) for the same reason `oep_object_store_list` does — `RelationshipStore::list_all()` itself has no defined order, so the API boundary imposes one, matching the CLI's own client-side sort in `RelationshipCommand`. `oep_relationship_list_release` follows the identical ownership contract established for `oep_object_list_release`.

**Task 000026 — Repository Search Public API.** Added three search entry points — `oep_search_repository`, `oep_search_objects`, `oep_search_relationships` — each a thin, allocation-only projection of `oep::search::SearchEngine::search_objects`/`search_relationships` into new fixed-layout `oep_object_search_result_t`/`oep_relationship_search_result_t` structures (plus a new `oep_match_location_t` enum mirroring `MatchLocation`). `oep_search_repository` returns **two independent lists** (`oep_repository_search_result_t::objects`/`::relationships`) rather than one merged/interleaved list — deliberately, since `SearchEngine` itself never merges objects and relationships into a single ranking, and inventing a cross-type ranking at the API boundary would have violated the spec's explicit "the Public API shall never reorder search results" requirement by introducing an ordering Foundation's Search Engine never produced. Per the work package's explicit scope, author/tag/type filtering is **not** implemented in this API — it remains a Studio-side responsibility applied to returned results, exactly as `oep search`'s own `--type`/`--author`/`--tag` flags already work.

Both tasks share the same allocation/ownership pattern established for Engineering Object Enumeration: every function either writes into a caller-supplied fixed structure (no allocation) or allocates exactly one Foundation-owned heap array paired with exactly one matching release function (`oep_relationship_list_release`, `oep_object_search_result_list_release`, `oep_relationship_search_result_list_release`, and — since `oep_repository_search_result_t` embeds two lists — `oep_repository_search_result_release`, which releases both together).

`OEP_API_VERSION` was bumped from 2 to 3 (purely additive: new functions and structures, no existing structure's layout changed); `OEP_ABI_VERSION` remains 1.

Updated `platform/api/README.md` (new "Engineering Relationship Enumeration" and "Repository Search" sections covering usage, memory ownership, performance considerations; updated Handle Ownership/Thread Safety/Versioning/Bridge-guidance sections to reference all five new structures and their release functions) and `platform/runtime/README.md` (confirming this work package, like Work Package 012, added no new `FoundationRuntime` surface — search reads the same `SearchEngine` instance `search_engine()` already returns, built once by `build_index` during `open_repository`). Per the work package's own rule ("CLI documentation shall only be updated if user-visible CLI behavior changes"), `CLI_USAGE.md` was not modified — `oep relationship` and `oep search` were re-run manually and produce byte-identical output to before this work package.

Built with MSVC 19.51 via CMake/Ninja after a full clean rebuild (`rm -rf build` then reconfigure): 99/99 build steps succeeded. `oep_api_tests` grew from 25 to 46 cases, adding: relationship count/list/lookup-by-id success paths, sorted-and-deterministic-across-repeated-calls relationship enumeration, `oep_relationship_list_release` safety (double-release, `NULL`), lookup-by-nonexistent-ID reporting `OEP_ERROR_NOT_FOUND`, `NULL`-argument rejection for every new function, relationship enumeration and all three search functions failing with `OEP_ERROR_INVALID_STATE` without an open repository, object/relationship/combined search returning correct match counts and fields against a populated fixture repository, an empty-query search failing distinctly from a valid-but-non-matching query, and `oep_relationship_type_to_string`/`oep_match_location_to_string` stringification — all passed via CTest alongside the existing twenty-two suites (23/23 suites, 100% pass). No compile-time or test-runtime bugs were encountered beyond one self-caught issue during implementation: an anonymous namespace containing C++-typed helper functions was initially nested inside the `extern "C" { ... }` block, then moved to file scope before the block opens, to avoid any ambiguity about linkage-specification nesting — caught and fixed before the first build attempt. Manually re-ran `oep init`, `oep relationship create/list`, and `oep search`/`oep search objects`/`oep search relationships` against a real generated repository and confirmed byte-identical output to prior work packages — no CLI regression. Work Package 013's Definition of Done is satisfied: Engineering Relationships are enumerable and Repository Search is available through the Public C API alone, with documentation complete, all tests passing, and existing CLI behavior unchanged.

---

# Work Package 014 (Task 000027 + Task 000028 + Task 000029 + Task 000030) — Verified Complete

The first write-capable surface of the Public C API. Before implementing, the existing Foundation architecture, `FoundationRuntime`, and the Public C API built across Work Packages 011–013 were reviewed; no architectural conflict, ambiguity, or missing Runtime capability was found that required stopping for review — the gap this work package needed to fill (Runtime had no mutation entry points at all, only read-only-oriented `object_store()`/`relationship_store()` accessors) was exactly the gap the work package's own architectural guidance ("every Public C API mutation function shall delegate through Foundation Runtime," "stores shall never become directly accessible through the Public API") anticipated and instructed Runtime to fill.

**TASK-000027 — Public Object Mutation API.** Added `oep_object_create`/`oep_object_update`/`oep_object_delete` to `oep_api.h`, backed by three new `FoundationRuntime` methods (`create_object`/`update_object`/`delete_object`) that delegate entirely to the existing `ObjectStore::create`/`update`/`remove` — no validation rule is duplicated; `name == nullptr` is the only check the API layer performs itself (an ABI-safety requirement), while an empty name is left to fail `validate_object` exactly as it always has. `update_object` preserves `object_type`/`object_id`/creation timestamp, matching `ObjectStore::update`'s existing immutability contract precisely.

**TASK-000028 — Public Relationship Mutation API.** Added `oep_relationship_create`/`oep_relationship_update`/`oep_relationship_delete`, mirroring object mutation exactly and backed by three new `FoundationRuntime` methods delegating to `RelationshipStore`. `update_relationship` only accepts author/description, matching `RelationshipStore::update`'s existing immutability contract (source/target/type/created are fixed).

**TASK-000029 — Public Transaction API.** Added `oep_transaction_begin`/`_commit`/`_rollback`/`_is_active`. The key design decision, made once `FoundationRuntime` was found to have no staged-write concept at all (every `ObjectStore`/`RelationshipStore` write is immediate and independently atomic, but nothing before this work package grouped multiple writes into one reversible unit): rather than inventing a second, parallel persistence mechanism, a transaction is an in-memory compensating-action log (`FoundationRuntime::TransactionLogEntry`, private) recorded alongside each immediate write while a transaction is active. `commit_transaction` discards the log (every mutation is already durable); `rollback_transaction` replays it in reverse using the same `remove`/`update`/`restore` methods a normal mutation already uses — `restore()` in particular is the exact mechanism Import and Templates (Work Package 009) already established for reconstructing an object/relationship's exact prior identity, reused here rather than re-invented. Only one transaction may be active per handle (no nesting). Per the spec's explicit "Failures shall: Abort transaction, Roll back changes," any mutation failure while a transaction is active triggers automatic rollback and deactivation before the failure is returned to the caller. `FoundationRuntime::reset_repository_context()` (shared by `close_repository()` and `shutdown()`) now rolls back an active transaction first, so closing a repository can never strand one open.

**TASK-000030 — Public Batch Mutation.** Added `oep_batch_create_objects`/`oep_batch_create_relationships`, deliberately implemented as a thin convenience layer over the transaction primitives from TASK-000029 rather than a separate rollback mechanism: every spec is created in array order (the required deterministic execution order) inside a transaction — begun and committed automatically if the caller had none active, or participating in the caller's existing transaction otherwise, in which case a failure rolls back everything in that transaction, not just the batch's own entries. `oep_batch_create_objects_result_t`/`oep_batch_create_relationships_result_t::created` are deliberately left in execution order rather than sorted by ID (unlike `oep_object_store_list`/`oep_relationship_store_list`), since preserving that order is exactly the guarantee this task requires.

All new mutation error classification (duplicate/missing-object/invalid-relationship/etc.) flows through one new shared helper, `classify_mutation_error` (private to `oep_api.cpp`), pattern-matching the small, stable set of message substrings `ObjectStore`/`RelationshipStore` actually produce — the same substring-classification approach already established for `oep_runtime_open_repository` in Work Package 011, applied consistently rather than inventing a second classification style.

`OEP_API_VERSION` was bumped 3 → 4 (purely additive: new functions and structures only); `OEP_ABI_VERSION` remains 1, since no existing structure's layout changed.

**Verification.** Per the work package's explicit instruction, a standalone C API test program was written and is the centerpiece of manual verification: `platform/api/manual_test/capi_manual_test.c`, compiled as **plain C** (the top-level `CMakeLists.txt` was extended to `LANGUAGES CXX C` for this purpose) against only `oep_api.h`, exercising object create/update/delete, relationship create/update/delete, explicit transaction rollback, automatic rollback on mid-transaction failure, and batch mutation (both full success and rollback-on-failure) — 54/54 checks passed. Compiling and linking a genuine `.c` translation unit against `oep_api` is itself part of the verification: it demonstrates the Public C API is a real, consumable C ABI rather than a C-styled header only C++ happens to be able to call.

Built with MSVC 19.51 via CMake/Ninja after a full clean rebuild (`rm -rf build` then reconfigure — the project directory had also moved since Work Package 013, requiring a fresh configure regardless): 101/101 build steps succeeded, including the new `oep_capi_manual_test` executable. `oep_api_tests` grew from 46 to 68 cases, adding: object create/update/delete (including NULL-argument and NOT_FOUND paths), relationship create/update/delete, transaction commit (including rejecting a nested begin and a commit/rollback with none active), transaction rollback (undoing a create and an update together), automatic rollback on a mid-transaction validation failure, batch object creation (success, execution-order preservation, and rollback-on-failure with correct `failed_index`), batch relationship creation, and a batch participating in and being rolled back as part of a caller-supplied transaction — all passed via CTest alongside the existing twenty-two suites (23/23 suites, 100% pass). Two bugs were caught and fixed during implementation, both documented for the record: (1) two `foundation_runtime.cpp` return statements returned a store-level result type (`ObjectResult`/`RelationshipResult`) directly where `RuntimeResult` was expected — a same-shape-different-type compile error, fixed by explicit field construction; (2) a literal `*/` appearing inside prose inside a `oep_api.h` block comment (`oep_object_*/oep_relationship_*`) terminated the comment early, corrupting subsequent header parsing — fixed by rewording the sentence to avoid the character sequence. Both were caught by the build, not by inspection. One test-authoring bug in the manual C program itself was caught by its own first run (reusing an output struct across a subsequent deliberately-failing call, which zeroes it) and fixed before the verification run recorded above. Manually re-ran `oep init`, `oep object create/list`, `oep relationship create/list`, `oep search`, `oep batch create`, `oep validate`, `oep export`, `oep version`, and `oep --help` against a real generated repository — all produced unchanged output, confirming no CLI regression (the CLI does not consume `platform/api` and remains, as in prior work packages, an unaffected, separate consumer of `FoundationRuntime`). Work Package 014's Definition of Done is satisfied: object mutation, relationship mutation, transactions, and batch mutation all function through the Public C API alone; documentation is complete; the clean rebuild, complete regression suite, and manual verification all succeeded.

---

# Work Package WP-REP-001 (Task 000031) — Verified Complete, Awaiting Review

The first Foundation Repository Runtime work package, and the first to use the `WP-REP-###` naming convention (Repository Runtime initiative, distinct from Foundation's original sequential `Work Package NNN` numbering). Preceded by a paused Engineering Exchange (Release Candidate 1, WP-EXC-011 explicitly not started) and an architectural assessment (`OEP-ARCH-002-REPOSITORY_RUNTIME_ASSESSMENT.md`) confirming the Repository remains part of Foundation rather than becoming a new repository.

Delivered a real, end-to-end package installation path: a new `platform/installer` module (`ZipReader` — a hand-rolled, ZIP-"Stored"-only reader, no third-party dependency added, consistent with this codebase's established convention; `oep_package_manifest` parsing against PKG-002's 16 required fields; `PackageRegistry`, one JSON record per installed package at `<repo>/packages/<packageId>/registry.json`; `extract_package`, parsing a Repository Fragment's objects/relationships). Extended `FoundationRuntime` with `install_package`/`list_installed_packages`/`package_registry()` — `install_package` extracts the archive, creates every object/relationship via the existing, unchanged `ObjectStore::create`/`RelationshipStore::create` (archive-declared IDs preserved, never remapped), rebuilds Search/Graph indexes, and records the install. Extended the Public C API (`oep_package_install`/`oep_package_list_installed`/`oep_installed_package_list_release`, `OEP_API_VERSION` 4 → 5, `OEP_ABI_VERSION` unchanged) and added `oep package install|list` to the CLI. Extended OEP Studio's Foundation Bridge (Dart FFI) with matching bindings.

Per the user's explicit scope exclusions, **`install_package` is deliberately not transactional** — a partial failure leaves prior successful creates in place, proven by a dedicated test rather than silently narrowed from the original architectural design (which had proposed wrapping installation in the existing transaction primitives). Dependency resolution, merge/ownership logic, signature verification, networking, update, and uninstall were all likewise deliberately excluded, per OEP-ARCH-002 §5's own WP-REP-001 specification.

`engineering-demo.oep` (built via `oep_exchange`'s `@oep-exchange/package-cli`) needed two corrections to install successfully, both self-discovered and self-fixed before any user-facing failure: its object JSON used snake_case field names, but Foundation's actual on-disk convention (confirmed by reading `object_store.cpp`) is camelCase — PKG-001 does not formally specify this, a gap worth ratifying in a future spec revision; and it was DEFLATE-compressed, incompatible with the new Stored-only `ZipReader` — rebuilt with every entry forced to Stored via a one-off script reusing the real `buildPackage()` pipeline. A second Engineering Object and a Relationship were added to the demo package so installation would exercise both registration paths.

Built via WSL Ubuntu's CMake/g++ 13.3.0 toolchain (no Windows-native C++ toolchain — MSVC/CMake/MinGW/LLVM — was found anywhere on the host in this environment, unlike every prior work package; this is recorded honestly as an environmental limitation, not a claim of MSVC verification). Full configure + build succeeded with no errors. Regression suite: all pre-existing CTest suites continued passing, plus four new suites (`oep_zip_reader_tests`, `oep_package_manifest_tests`, `oep_package_registry_tests`, `oep_package_installer_tests`) and one new runtime-level suite (`oep_package_installation_tests`), 28 new test cases, all passing — including `test_a_failure_partway_through_is_not_rolled_back`, proving the no-transactions decision behaves as documented. End-to-end CLI validation installed `engineering-demo.oep` into a freshly generated repository and confirmed both objects and the relationship were registered, indexed, and searchable (11/11 verification steps passed). `flutter analyze` (Studio): 0 new issues. `flutter test` (Studio): all 460 tests passed, 2 skipped (pre-existing, unrelated) — zero regressions from the new FFI bindings; a live rebuild of `oep_foundation_bridge.dll` and a runtime FFI call against it were not performed, for the same no-Windows-toolchain reason noted above.

Updated `platform/installer/README.md` (new), `platform/api/README.md` (new "Package Installation" section, `OEP_API_VERSION` bump, Handle Ownership/Thread Safety/Bridge-guidance updates), `platform/runtime/README.md` (new "Package Installation" section), `platform/cli/README.md` (new `package install`/`package list` command entries), `TASK.md`, and this file.

**Remaining work, explicitly deferred, not part of this work package's own deliverables:** the OEP-ARCH-002 §0 terminology renames (`platform/exchange`→`platform/archive`, in-archive `repository/`→`fragment/`) remain unratified recommendations, not applied; a native Windows MSVC build/DLL rebuild was not independently verified in this environment; WP-REP-002 through WP-REP-006 (per OEP-ARCH-002 §5's backlog) await separate user approval before any work begins. Stopping here per the user's explicit instruction: "Wait for approval before beginning WP-REP-002."

---

# Work Package WP-REP-002 (Task 000032) — Verified Complete, Awaiting Review

Repository Runtime, Vertical Slice 2: **Repository Registry & Lifecycle**, plus the now-**ratified** terminology migration.

**Terminology migration (applied, least-disruptive path):** `platform/exchange` → `platform/archive` throughout `oep_foundation` (directory, `oep::archive` namespace, includes, `oep_archive` CMake target, READMEs) — internal-only, since no CLI command, spec title, or C API symbol referenced "exchange". PKG-001 §5's in-archive `repository/` → `fragment/`: spec amended, `@oep-exchange/package-cli` (`create`/`validate`, src + recompiled dist) updated, `engineering-demo-src` renamed and `engineering-demo.oep` rebuilt via the real build pipeline (Stored-only re-pack). `platform/installer`'s `extract_package` prefers `fragment/` but **accepts the legacy `repository/` layout as a documented, tested backward-compatibility fallback**, so already-built archives remain installable. OEP-ARCH-002 §0.2 marked Applied.

**Repository Registry:** WP-REP-001's minimal `PackageRegistry`/`InstalledPackageRecord` renamed and expanded to `RepositoryRegistry`/`RepositoryRegistryEntry` (same on-disk location, `<repo>/packages/<packageId>/registry.json`), now carrying the full WP-REP-002 §4 field set: manifest metadata (title/summary/category/schema version/engineering domains), publisher id/name, installation date/source/path, a SHA-256 package hash (new hand-rolled FIPS 180-4 implementation, NIST-vector-tested, no dependency added — an integrity fingerprint only, explicitly NOT a trust mechanism; signing is PKG-005/WP-REP-004), a `runtime_state` field (always `"Installed"` — other PKG-008 §6 states need update/uninstall/activation, all excluded), and contribution IDs. New registry queries: `find_owner` (reverse entity→package lookup) and `search_packages` (case-insensitive metadata match).

**Lifecycle query services (read-only):** `FoundationRuntime::get_installed_package` / `find_package_owner` / `verify_package` / `search_installed_packages` + renamed `repository_registry()` accessor. `verify_package` checks every recorded contribution against the live stores and re-hashes the source archive when still present (a deleted archive is informational, not a failure). `search_installed_packages` also matches the live names of installed objects via `ObjectStore` — object data is never duplicated into the registry.

**Public C API:** `oep_package_get_info`/`_get_contents`/`_locate`/`_verify`/`_search`, with new `oep_package_details_t`/`oep_package_owner_t`/`oep_package_verify_result_t`/`oep_owned_entity_kind_t`. Purely additive: `OEP_API_VERSION` 5 → 6, `OEP_ABI_VERSION` still 1, `oep_installed_package_info_t` and every WP-REP-001 function unchanged. `_get_contents` reuses the existing object/relationship list types and release functions.

**CLI:** `oep package info|contents|verify|locate|search` added; `list` enriched (publisher, runtime state); command class renamed `PackageInstallCommand` → `PackageCommand` (user-facing name unchanged).

**Studio:** Foundation Bridge FFI bindings for all five new functions (native structs, bindings, Dart models `PackageDetails`/`PackageOwner`/`PackageVerifyResult`/`OwnedEntityKind`, and five `FoundationBridge` methods). No UI redesign.

**Verification:** WSL CMake/g++ 13.3.0 full clean rebuild — success (same no-Windows-toolchain limitation as Task 000031; MSVC not independently re-verified). 30/30 CTest suites pass (new: `oep_sha256_tests`, `oep_repository_registry_tests`, `oep_package_command_tests`). Two test-only fixes: a one-hex-digit typo in the new sha256 NIST-vector test, and a **pre-existing** 1-second-timestamp-resolution flake in `oep_engineering_object_tests` (fixed with an explicit wait; unrelated to this work package). End-to-end CLI validation: 12/12 steps against the regenerated `engineering-demo.oep` in a fresh `oep init` repository, including verify-OK with matching hash, locate, and search by installed-object name. Studio: `flutter analyze` 0 new issues; `flutter test` 460/460 passed.

**Excluded, per instruction:** dependency resolution, transactions, merge, trust & signing, update, uninstall, HTTP services. Stopping per the user's instruction: "Wait for approval before beginning WP-REP-003."

---

# Work Package WP-REP-003 (Task 000033) — Verified Complete, Awaiting Review

Repository Runtime, Vertical Slice 3: the **Repository Transaction Engine** — the install-scope subset of PKG-003, built by upgrading Work Package 014's existing transaction primitives in place (every signature unchanged) rather than inventing a second mechanism.

**Engine:** every transaction now has a UUIDv4 id and, on close, writes one permanent record to the new Transaction Journal (`platform/runtime/transaction_journal.hpp/.cpp`, persisted at `<repository>/logs/transactions/<id>.json`, inside OEP-SPEC-002 §5's existing `logs/` directory) — state (`Committed`/`RolledBack`/`Failed`, a deliberate subset of PKG-003 §5), description, open/close timestamps, and one entry per operation with target and previous/new state (PKG-003 §15/§26). The journal records history; WP-014's in-memory compensating-action undo log — reused unchanged — performs the actual rollback. A journal problem never prevents a rollback from restoring repository state.

**All writes through transactions:** every Runtime mutation outside an explicit transaction runs inside an implicit one, journaled like any other write. Mid-implementation finding, caught by the new CLI test's first run: the CLI's `object`/`relationship` commands were still writing via `ObjectStore`/`RelationshipStore` directly (a pre-WP-014 pattern) — migrated to the Runtime's mutation methods, so CLI writes are journaled exactly like Public-C-API writes. Documented boundaries: `BatchProcessor` (OEP-SPEC-020) keeps its own validate-then-execute atomicity; `import_repository`/`instantiate_template` create new repositories rather than writing to the open one.

**Atomic installer:** `install_package` runs inside one Repository Transaction — any failure (invalid object, dangling relationship, failed Repository Registry write) rolls back every create and journals RolledBack; success journals Committed (objects + relationships + a final `PackageRecorded` entry). WP-REP-001's dedicated no-rollback test was **inverted** (`test_a_failure_partway_through_is_rolled_back`) to prove the change. Install inside a caller's explicit transaction is rejected (no nesting). Two documented behavior changes, both honest improvements: failed installs now report 0 created; `commit_transaction` can fail in exactly one new way (journal record unwritable — mutations already persisted, only the audit trail incomplete).

**Public C API:** `oep_transaction_get_info` + `oep_transaction_history`/`oep_transaction_record_list_release`, with `oep_transaction_info_t`/`oep_transaction_record_t`/`_list_t`. `OEP_API_VERSION` 6 → 7, `OEP_ABI_VERSION` still 1, every existing signature unchanged.

**CLI:** new read-only `oep transaction list|show <id>`; `package install`'s obsolete "NOT rolled back" failure note removed.

**Studio:** Foundation Bridge FFI bindings (`TransactionInfo`/`TransactionRecordSummary`, `getTransactionInfo`/`listTransactionHistory`). `flutter analyze` 0 new issues; `flutter test` 460/460 passed.

**Verification:** WSL CMake/g++ full build, no errors (same no-Windows-toolchain limitation as prior tasks). 32/32 CTest suites pass (new: `oep_transaction_journal_tests`, `oep_transaction_command_tests`; extended: package installation, api). End-to-end CLI: 7/7 steps — atomic install, `transaction list`/`show` displaying the install's 4 journaled operations with previous/new states, an implicit-transaction journal record from `object create`, verify still OK.

**Excluded, per instruction:** dependency resolution, merge logic, updates, uninstall, trust/signing, networking; also explicitly deferred: journal-based crash recovery/repair (PKG-003 §21), cross-process repository locking (§6), install preview/approval (§13), activation events (§18/§25). Stopping per the user's instruction: "Wait for approval before beginning WP-REP-004."

---

# Work Package WP-REP-004 (Task 000034) — Verified Complete, Awaiting Review

Repository Runtime, Vertical Slice 4: the **Repository Trust & Signing Subsystem**, implementing PKG-005.

**Crypto foundation:** hand-rolled SHA-512 (`sha512.hpp/.cpp`) and Ed25519 signature *verification* (`ed25519.hpp/.cpp`, RFC 8032) — no third-party dependency, matching this codebase's own convention. Verify-only by design: Foundation never signs, never holds a private key. Both validated against published NIST/RFC test vectors, including RFC 8032 §7.1's own signature test cases and explicit malleability/tamper rejection checks, before anything was built on top.

**Trust Store:** `TrustStore` (`trust_store.hpp/.cpp`) — locally trusted publisher certificates under `<repository>/settings/trust/`, entirely offline (PKG-005 §3: no certificate authority, no online revocation feed). Add/get/list/revoke (kept, marked revoked, per §12/§13) plus a repository-wide `require_signatures` policy (default `false`, preserving every earlier work package's unsigned-install behavior).

**Verification pipeline:** `verify_package_trust` (`package_verifier.hpp/.cpp`) implements PKG-005 §11: structure → content hashes (every archive entry outside `signatures/`, §9/§10 — nothing exempt) → certificate → Ed25519 signature → `TrustState` (`Trusted`/`Unsigned`/`UnknownPublisher`/`ExpiredCertificate`/`RevokedCertificate`/`InvalidSignature`/`Tampered`).

**Installation pipeline integration — the user's explicit, load-bearing requirement:** `FoundationRuntime::install_package` now verifies trust immediately after confirming the package isn't already installed and **strictly before `open_transaction_internal` is ever called**. A `Tampered`/`InvalidSignature`/`UnknownPublisher`/`ExpiredCertificate`/`RevokedCertificate` result rejects the install with nothing extracted and no transaction ever opened — proven by a dedicated test asserting the transaction journal stays empty. `Unsigned` proceeds exactly as before unless the policy requires signatures. On success, the resolved state and certificate fingerprint are recorded on the `RepositoryRegistryEntry` (`trust_status`/`trust_fingerprint`) and returned via `RuntimeInstallResult::trust_status`.

**Foundation Runtime:** `trust_store()` accessor plus six pass-through methods (`trust_add_certificate`/`trust_get_certificate`/`trust_list_certificates`/`trust_revoke_certificate`/`trust_get_policy`/`trust_set_policy`) — local writes to `settings/trust/`, never Repository Transactions.

**Public C API:** seven new functions (`oep_trust_add_certificate`/`_get_certificate`/`_list_certificates`+release/`_revoke_certificate`/`_get_policy`/`_set_policy`, `oep_package_get_trust_status`) plus `oep_trust_state_to_string`, with new `oep_trust_state_t`/`oep_publisher_certificate_t`/`oep_certificate_list_t`/`oep_package_trust_status_t`. `OEP_API_VERSION` 7 → 8, `OEP_ABI_VERSION` unchanged — `oep_package_install_result_t` and `oep_package_details_t` (WP-REP-002) were deliberately left untouched; trust status is a new function/struct, not a modification.

**CLI:** new `oep trust trust|list|revoke|policy`; `oep package info` now shows Trust Status and fingerprint; the obsolete "install is not transactional" failure note (stale since WP-REP-003) was removed.

**Studio:** Foundation Bridge FFI bindings for all seven new functions (`PublisherCertificate`/`PackageTrustStatus`/`TrustState` Dart models, seven `FoundationBridge` methods). `flutter analyze` 0 new issues; `flutter test` 460/460 passed.

**Two real bugs found and fixed during this Work Package, both caught by tests/end-to-end validation rather than left latent:**
1. **`oep_foundation`'s shared JSON serializer never wrote `Bool`/`Number` values** (`platform/repository/json_value.cpp`) — a silent no-op present since the module was first written, undiscovered because nothing had serialized a boolean before `TrustStore`'s `revoked` field. Fixed; caught immediately by `oep_trust_store_tests`' first run.
2. **`@oep-exchange/signing`'s file-sort used locale-aware comparison** instead of the byte-wise order Foundation's C++ verifier reconstructs, so a genuinely signed `engineering-demo.oep` failed as `InvalidSignature` until fixed — found during real end-to-end validation (signing and installing an actual archive), not unit testing alone. A regression test now pins the correct order.

**Verification:** WSL CMake/g++ full build, no errors (same no-Windows-toolchain limitation as prior tasks). 38/38 CTest suites pass (new: `oep_sha512_tests`, `oep_ed25519_tests`, `oep_trust_store_tests`, `oep_package_verifier_tests`, `oep_trust_integration_tests`, `oep_trust_command_tests`). `@oep-exchange/signing`: 12/12 vitest cases pass. End-to-end CLI, using a real generated key pair and a genuinely signed `engineering-demo.oep`: install rejected as `UnknownPublisher` with an empty transaction journal; trusted and reinstalled successfully (`Trusted`, correct fingerprint, one Committed transaction); a revoked publisher's package rejected as `RevokedCertificate` in a second repository.

**Excluded, per instruction:** dependency resolution, update, uninstall, merge, networking, online trust services; also explicitly deferred: certificate authority chains/enterprise policy (PKG-005 §14), multiple signatures per package (§15), repository-wide re-audit of already-installed packages (§16), repair transactions (§17). Stopping per the user's instruction: "Wait for approval before beginning WP-REP-005."