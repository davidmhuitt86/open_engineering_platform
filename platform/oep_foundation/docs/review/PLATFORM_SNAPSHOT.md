# PLATFORM_SNAPSHOT.md

**Scope of this review.** The top-level `platform/` directory contains multiple independent repositories: `oep_foundation` (C++23 runtime — the primary subject of this review), `oep_studio` (Flutter/Dart client), and several additional siblings discovered during inspection but outside this session's build history: `oep_engine`, `oep_acquisition`, `oep_architecture`, `oep_exchange` (Node/TS marketplace backend), `oep_reference` (Python reference implementation), `engine_reference_only` (a Node/Python prototype), plus `OEP_SNAPSHOT/` and `PLATFORM_CONSTITUTION/` documentation trees. **This document, and the rest of this review, is scoped to `oep_foundation` and `oep_studio`** — the two systems that "Foundation Runtime v1.0" and "Engineering Knowledge Engine v1.0" actually refer to. The sibling repositories are noted where relevant but not audited in depth; see the Documentation Audit for the naming-collision risk this creates (a separate top-level `oep_engine` repo exists alongside `oep_foundation/platform/oep_engine`, the actual built module).

---

## 1. Repository structure

```
oep_foundation/                     (git repo, C++23, CMake)
├── platform/                       — all real C++ source (see §2)
├── tests/                          — CTest suites, 1:1 with tests/<module>/CMakeLists.txt
├── docs/
│   ├── architecture/                — 8 frozen v1.0 documents (WP-EKE-008)
│   └── tasks/                       — work package specs (3 incompatible numbering schemes, see Documentation Audit)
├── specifications/                  — a SECOND, separate spec tree (adr/, architecture/, platform/ OEP-SPEC-001..022, standards/)
├── demo-workshop/                   — a live demo repository instance, checked into source control
├── build/, build-wsl/               — generated CMake build output
├── .scratch_build/                  — loose, non-CMake scratch artifacts at repo root (not a real build dir)
├── .claude/worktrees/agent-.../      — an orphaned full git worktree checkout left in the tree (should be pruned)
├── assets/, examples/, packages/, plugins/, sdk/, studios/, tools/ — sparse/placeholder trees, minimal content
└── README.md, TASK.md, CURRENT_SPRINT.md, PROJECT_STATUS.md, CLAUDE.md, PROJECT_MEMORY.md, CHANGELOG.md, CONTRIBUTING.md

oep_studio/                         (git repo, Flutter/Dart)
├── lib/                            — 312 .dart files (see §4)
├── test/                           — 56 .dart test files
├── native/foundation_bridge/       — thin native FFI shim
├── android/, linux/, macos/, web/, windows/ — Flutter platform shells
├── anthropic_api_key.env           — ⚠ plaintext API key committed in the working tree (flag for immediate rotation/removal)
└── docs/                            — ~45 files (design/SDD, architecture/engineering, tasks)
```

## 2. Major modules (`oep_foundation/platform/`)

| Module | Files | ~LOC | Responsibility |
|---|---|---|---|
| `repository` | 26 | 2,723 | Base data layer: `EngineeringObject`/`Relationship` models, `RepositoryMetadata`, `ObjectStore`/`RelationshipStore`, `GraphEngine` (BFS/DFS/path), `AuditStore`. No internal dependencies. |
| `search` | 4 | 235 | Indexing/query over the object graph, built on `repository`. |
| `validation` | 6 | 331 | `RepositoryValidator` — repository-wide consistency checks. |
| `packages` | 6 | 439 | `PackageManager`/`PackageManifest` — local package metadata concept, distinct from the installer's archive manifest. |
| `archive` | 14 | 1,188 | Export/import/templating: `RepositoryExporter`/`Importer`, `RepositoryTemplate`. |
| `installer` | 28 | 3,735 | `.oep` archive installation: `ZipReader`, manifest parsing, `PackageInstaller`, hand-rolled `sha256`/`sha512`/`ed25519`, `TrustStore`/`PackageVerifier`, `DependencyResolver`, `MergeEngine`. Deliberately never touches `ObjectStore` directly. |
| `runtime` | 13 | 4,054 | `FoundationRuntime` — the aggregation layer; single application entry point coordinating every module above; in-memory transaction/undo log. |
| `oep_engine` | 62 | 6,076 | The Engineering Knowledge Engine (EKE): `EngineeringContext`, `KnowledgeGraphEngine`, `EngineeringQueryEngine`, `RulesEngine`, `ValidationEngine`, `AnalysisEngine`, `ReasoningEngine`, `EngineeringIntelligencePlatform`. Reaches Foundation only through `runtime`. |
| `api` | 8 | 10,146* | Pure C ABI (`extern "C"`), 3,277-line header, 166 functions. The only supported native interface for external consumers. Links `runtime`+`oep_engine` PRIVATE. |
| `cli` | 73 | 6,860 | The `oep` executable — 28 top-level command groups. |

\* inflated by `MUTATION_API.md`/manual_test content alongside the core `.h`/`.cpp`.

**Six stub modules exist but contain only a README, no code, and are not wired into the CMake build**: `authentication`, `filesystem`, `licensing`, `logging`, `telemetry`, `transactions` (transaction support was actually implemented inside `runtime` instead — `platform/transactions/` is a stale placeholder for a concept that moved).

## 3. Current architecture / runtime layering

```
Filesystem
   ↓
repository            (base layer, zero internal deps)
   ├─ search           → repository
   ├─ validation        → repository
   ├─ packages          → repository
   ├─ installer         → repository
   └─ archive           → repository, packages
   ↓
runtime               → repository, search, validation, packages, archive, installer   (aggregator; FoundationRuntime)
   ↓
oep_engine            → runtime only    (Engineering Knowledge Engine, 8 internal layers — see below)
   ↓
api                   → runtime, oep_engine (PRIVATE link — hides both behind oep_api.h)
   ↓
Studio FFI (Dart)  ←  api  (dart:ffi bindings, 158 bound symbols)

cli                   → repository, runtime, search, validation, packages, oep_engine (PUBLIC link — the one documented exception that bypasses the "everyone goes through runtime" rule)
```

**Inside `oep_engine`, the 8-layer Engineering Knowledge Engine stack** (each layer holds its dependencies as non-owning references, growing by one reference per layer):

```
EngineeringContext (wraps RuntimeService&)
   → KnowledgeGraphEngine (EngineeringContext&)
      → EngineeringQueryEngine (KnowledgeGraphEngine&)
         → RulesEngine (EngineeringContext&, KnowledgeGraphEngine&, EngineeringQueryEngine&)
            → ValidationEngine (+ RulesEngine&)
               → AnalysisEngine (KnowledgeGraphEngine& only)
               → ReasoningEngine (EngineeringContext&, KnowledgeGraphEngine&, EngineeringQueryEngine&, RulesEngine&, ValidationEngine&, owns AnalysisEngine by value)
                  → EngineeringIntelligencePlatform (7 references — the facade)
```

This is a verified, clean, acyclic DAG. No lower module includes a higher one; no module reaches into another's private (`src/`) headers.

## 4. Studio (`oep_studio/lib`, 312 Dart files)

| Area | Files | Notes |
|---|---|---|
| `knowledge/` | 123 | Largest feature area by far (>1/3 of all Dart files) — Knowledge Acquisition/Exchange workflow, a separate subsystem from the Engineering Knowledge Engine. |
| `core/` | 44 | Includes `core/foundation/` — the FFI boundary (`foundation_bridge.dart`, `oep_api_bindings.dart`, native types). |
| `settings/` | 35 | |
| `diagram_studio/` | 27 | |
| `exchange/` | 22 | |
| `acquisition/` | 20 | |
| `features/` | 14 | Several files 16–26 lines — thin. Two entire pages (`graph_page.dart`, `packages_page.dart`) render a shared placeholder workspace widget. |
| `engineering_intelligence/` | 10 | New this session (WP-EKE-008) — the 8 EKE dashboard pages. |
| `shared/`, `app/` | 16 | |

## 5. Public APIs (summary — full detail in API_AUDIT.md)

- **Runtime API (C++)**: 9 facade classes, no exceptions cross module boundaries, but three different in-process error-signaling conventions coexist (`{success,error}` structs, `std::optional`, plain `bool`/`void`).
- **Public C API**: 166 `extern "C"` functions, `OEP_API_VERSION` **19**, `OEP_ABI_VERSION` **1** (unchanged since WP-REP-001 — genuinely, verifiably additive-only across the whole session).
- **Studio FFI (Dart)**: 158 of the 166 C functions have bindings. 8 are unbound — notably `oep_object_update`/`_delete`, `oep_relationship_update`/`_delete`, and both batch-create functions. **Studio currently cannot update, delete, or batch-create objects/relationships through FFI**, even though the underlying Runtime and C API support all of it.
- **CLI**: 28 top-level command groups (`oep <verb>`), including two near-collision pairs: `package`/`packages` and `validate`/`evalidate`.
- **REST**: none anywhere in `oep_foundation` or `oep_studio` (confirmed by grep and corroborated by the codebase's own architecture assessment doc). A REST API exists only in the separate `oep_exchange` repository, and at least one of its client calls (`HttpRepositoryClient`'s install endpoint) has no server-side implementation anywhere in the monorepo.

## 6. Overall platform maturity

Foundation Runtime and the Engineering Knowledge Engine are **functionally complete and internally consistent** at the C++/C-API layer: 62/62 CTest suites pass, the dependency graph is genuinely acyclic, the C ABI has never broken across 19 additive API-version increments, and a real end-to-end test exercises the full acquire→install→graph→query→validate→analyze→reason→recommend pipeline in ~20–32ms. **Studio's coverage of that backend is partial and uneven**: the new Engineering Intelligence pages are real but read-only and smoke-tested only; large swaths of the pre-existing Studio codebase (Graph page, Packages page, most Knowledge Studio dialogs, several Settings sub-pages) are self-documented placeholders; and the FFI layer has a real functional gap around object/relationship mutation. Project status documentation is **inconsistent across files** (see Documentation Audit) — `TASK.md` and the frozen `docs/architecture/` set are current and reliable; `PROJECT_STATUS.md` is severely stale (describes Sprint 001, pre-dating the entire Repository/Engine build-out); `CURRENT_SPRINT.md` is internally self-contradictory. Net assessment: the platform's **engine is production-grade for what it claims to do**; its **project record-keeping and Studio UI coverage are not yet at the same bar**.
