# TECHNICAL_DEBT.md

Ranked by severity: **Critical** (fix before further work builds on it) → **High** → **Medium** → **Low**.

## Critical

1. **Plaintext API key committed in `oep_studio/anthropic_api_key.env`.** A live-looking credential sitting in the working tree. Rotate immediately and verify it is git-ignored (not confirmed either way by this review — verify separately). This is a security issue, not merely a code-quality one, and takes priority over everything else in this document.

## High

2. **GraphML export is a shipped, versioned, "frozen" public C API function (`oep_kge_export_graphml_placeholder`) that is explicitly self-documented as incomplete** — "node/edge identity only, no attribute schema" — spanning `graph_serialization.hpp/.cpp`, `knowledge_graph_engine.hpp/.cpp`, `oep_api.h`/`oep_api.cpp`, and the CLI's `engine_command.cpp`. Because `OEP_API_VERSION`/`OEP_ABI_VERSION` are now frozen, any future fix to this function's actual output format risks being a behavior-breaking change for whoever's already consuming it, even though the function name says "placeholder." This should be resolved (implement fully or formally deprecate/relabel) before more consumers depend on today's partial output.
3. **Studio's FFI layer is missing object/relationship update, delete, and batch-create bindings** (`oep_object_update`, `oep_object_delete`, `oep_relationship_update`, `oep_relationship_delete`, `oep_batch_create_objects`, `oep_batch_create_relationships` — all present in the C API, none bound in `oep_api_bindings.dart`). Any Studio feature built today that assumes full CRUD will hit a wall; any feature built today assuming read-only will need retrofitting later. This gap should be closed deliberately, not discovered accidentally by whichever future feature needs it first.
4. **`PROJECT_STATUS.md` is severely stale** — its content describes "Sprint 001 — OEP CLI Foundation" with an explicit "Out of Scope: Repository engine, Runtime, SDK..." list, while the actual codebase has a fully built repository engine, runtime, and 8-layer knowledge engine. Anyone reading this file cold would form a completely wrong picture of the project's maturity.
5. **`CURRENT_SPRINT.md` is internally self-contradictory** — its header claims `Sprint: WP-EKE-005`, its body describes an unrelated, much earlier "Work Package 010" graph-CLI sprint, and neither matches the file's own most recent (WP-EKE-008) sections further down. This file has evidently been partially, not fully, updated across multiple work packages.

## Medium

6. **`AnalysisEngine` has no dedicated unit test file** — the only major engine class in the WP-EKE stack without one. It is exercised indirectly (CLI tests, the end-to-end test, EIP tests) but never verified in isolation.
7. **Four incompatible C API ownership conventions coexist** (per-type list+release, generic string-release, fixed output buffers for session IDs, static never-freed strings) — see `ARCHITECTURAL_REVIEW.md` for detail. Not a correctness bug (each convention is internally consistent), but a real cognitive/documentation cost for every new consumer.
8. **11 test files duplicate the same ZIP-builder test fixture** (`build_stored_zip`/`append_u32`) instead of sharing one utility header — a real, if low-risk, maintenance cost.
9. **`platform/api/src/oep_api.cpp` at 6,673 lines** is by far the largest file in the codebase and will keep growing under the current "one file, purely additive" pattern.
10. **CLI naming collisions**: `package` vs `packages`, `validate` vs `evalidate` — genuine user-facing confusion risk, not a functional bug.
11. **Naming collision between the top-level sibling `platform/oep_engine` repository and the actual built module at `oep_foundation/platform/oep_engine`** — a real discoverability trap for anyone navigating the monorepo, including future review passes like this one.
12. **`docs/tasks/` uses three incompatible numbering schemes** (`WORK_PACKAGE_NNN`, `WP-REP-NNN`, `WP-EKE-NNN`) with an unexplained 11-item gap in the oldest scheme and no index reconciling them.
13. **`oep_studio/docs/tasks/` contains ~12 apparent duplicate file pairs** (e.g. `WP-STUDIO-021 Studio Registry Framework.md` and `WP-STUDIO-021-STUDIO_REGISTRY_FRAMEWORK.md`) for the same work packages, plus at least one misspelled filename (`WORK_PAGKAGE_002.md`).
14. **No dedicated performance/benchmark test suite exists anywhere** — the only timing data in the codebase is informational `std::chrono` output inside a correctness test (`end_to_end_workflow_tests.cpp`), never asserted against a threshold, never repeated/averaged. The single 31.8595ms figure quoted across several documents is a one-off measurement presented with unwarranted precision.
15. **Studio has a materially larger placeholder surface than the backend**: two entire feature pages (Graph, Packages) and the majority of the Knowledge Studio dialog set are self-documented as unimplemented, plus several Settings sub-pages.

## Low

16. **`.claude/worktrees/agent-a560bcb7977f8f129/`** — an orphaned, full git worktree checkout (including its own duplicate `.git`, `CURRENT_SPRINT.md`, `tests/`, etc.) left inside the working tree. Should be pruned via `git worktree remove`.
17. **`.scratch_build/`** at the repo root contains loose, non-CMake build artifacts (`.o` files, ad hoc binaries, test `.oep` archives) that duplicate what `build/`/`build-wsl/` already provide as proper generated directories.
18. **Six empty Foundation stub modules** (`authentication`, `filesystem`, `licensing`, `logging`, `telemetry`, `transactions`) sitting in the module tree as README-only directories not wired into the build — not actively harmful, but a standing "is this built or not?" question for anyone scanning the module list.
19. **`demo-workshop/`** is a live demo repository instance checked directly into source control (`repository.json`, `cache/`, `logs/`, `exports/`) rather than generated into a gitignored location — plausibly intentional (referenced by CLI usage docs) but worth confirming it isn't silently accumulating cruft over time.
20. **A second, separate specifications tree** (`oep_foundation/specifications/`, containing its own `architecture/`, `platform/` OEP-SPEC series, `standards/`) exists alongside `docs/architecture/` — not conflicting in content as far as this review checked, but two "architecture documentation" locations in one repo is itself worth consolidating or cross-linking explicitly.

## Explicitly NOT technical debt (verified, not assumed)

- `OEP_ABI_VERSION` has genuinely never changed across the entire session (verified by direct header inspection, not merely claimed).
- No circular dependencies exist anywhere in the module graph (verified by direct grep, not assumed).
- No disabled/skipped tests exist anywhere in the C++ test suite (verified — zero `GTEST_SKIP`/`DISABLED_`/`xfail` matches).
