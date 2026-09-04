# Migration Record — MONOREPO-INTEGRATION-001

Status: subtree imports complete, verified independently buildable/testable where the source repo's own toolchain permits. Not yet pushed to `origin/main` (pending explicit authorization — see "Push" below).

## 1. Scope

Imports three previously-separate GitHub repositories into `open_engineering_platform` as history-preserving `git subtree` imports, each isolated under its own path prefix with no code moved into `oep_engine`/`oep_foundation`/`oep_studio`:

| Source repo | Source remote | Source HEAD | Target path | Import commit |
|---|---|---|---|---|
| `oep_acqusition` | `github.com/davidmhuitt86/oep_acqusition.git` | `d062bb4051162e3cd14d3b2d7795995649aeaf90` | `services/acquisition/` | `af5c6ec` |
| `oep_reference_library` | `github.com/davidmhuitt86/oep_reference_library.git` | `88f56d0a2492bb62a9b1a7dd9f79ab909ff12618` | `knowledge/reference_library/` | `c13628f` |
| `oep_exchange` | `github.com/davidmhuitt86/oep_exchange.git` | `c6dbb752e0f1cbf2260460b87f38960c821a33b2` | `services/exchange/` | `e21d80f` |

Pre-migration safety tag: `pre-monorepo-integration-001` at `8df1d3531fbab5a3e43edd6006dd8b08e93e41e1` (monorepo `main` immediately before the first subtree import).

This is separate from, and additive to, the earlier AP-REPO-001 migration (`docs/MONOREPO_MIGRATION_PLAN.md`) that already brought `oep_foundation`, `oep_engine`, `oep_studio` into `platform/` — those paths were not touched by this work.

## 2. Mechanism

`git subtree add --prefix=<target> <local-remote> main` (no `--squash`), run once per repository from a clean `main`. This is the standard-Git, no-external-tool mechanism: each import is a single merge commit whose second parent is the source repo's own history in full, rewritten under the target prefix. Verified per-repo (see §4).

Temporary remotes `acquisition-src`, `reflib-src`, `exchange-src` were added, fetched, used for the subtree import, and removed immediately after. No GitHub remote other than `origin` was touched; no source repository was modified.

## 3. Why subtree, not squash-merge or copy

Chosen for the same reasons recorded in `docs/MONOREPO_MIGRATION_PLAN.md` §13 for the prior migration: it preserves full original commit history (authorship, dates, messages) under a path prefix in one reviewable operation, requires no extra tooling beyond stock Git, and needs no history rewriting of the source repositories. A plain copy-and-commit was rejected because it would discard history; a squash was rejected because the work package requires "meaningful Git history preserved."

## 4. History-preservation verification

For each import commit, `git log -1 --format=%P <commit>` shows two parents: the prior monorepo `main` tip, and the source repo's original HEAD SHA exactly. Walking the second parent recovers the full original commit list:

- `af5c6ec^2` (acquisition): 15 original commits reachable, e.g. `ed60f20 Implement WORK_PACKAGE-009: Engineering Reference Vault (Milestone 1 complete)`.
- `c13628f^2` (reference library): 4 original commits reachable.
- `e21d80f^2` (exchange): 5 original commits reachable.

Plain `git log -- <path>` on the merge commit itself shows only 1 entry (the import commit) — this is git's normal history-simplification behavior on a merge boundary, not lost history; the full history is present and recoverable via the second-parent walk or `git log <merge>^2 -- <path-relative-to-source-root>`, both demonstrated above.

Authorship/dates were not rewritten — confirmed the original commit authors/timestamps are intact on the walked commits (only the merge commit itself is authored by the migration operator, as expected).

No tags existed on any of the three source repositories; none needed migrating. All three source repos have a single branch (`main`); no other branches were imported.

## 5. Dependency matrix (post-migration)

| Subsystem | Depends on (build/source) | Depended on by |
|---|---|---|
| `platform/oep_foundation` | — | `platform/oep_engine` (FFI), `platform/oep_studio` (CMake sibling path) |
| `platform/oep_engine` | `platform/oep_foundation` (native bridge) | `platform/oep_studio` (Dart `path:` dep) |
| `platform/oep_studio` | `platform/oep_engine`, `platform/oep_foundation`, `platform/oep_instruments` | — |
| `services/acquisition` | none (self-contained CMake/C++, own PostgreSQL schema) | `platform/oep_studio` via HTTP (`lib/acquisition/services/acquisition_api_client.dart`) |
| `knowledge/reference_library` | none (self-contained Python package) | none discovered (no importer found under `platform/` or `services/`) |
| `services/exchange` | none (self-contained npm/TypeScript workspace) | `platform/oep_studio` via HTTP (`lib/exchange/services/exchange_api_client.dart`) |

All cross-subsystem coupling between the three newly-migrated services and the existing `platform/` tree is at the **API/network client level only** (`*_api_client.dart` files under `platform/oep_studio/lib/{acquisition,exchange}/`), never a source-tree import. This matches each source repo's own stated integration model (README: "integrates with the rest of OEP only through published interfaces, not source-tree coupling").

## 6. Forbidden cross-import audit

Searched `services/acquisition`, `knowledge/reference_library`, `services/exchange` for any reference to `oep_engine`, `oep_foundation`, `oep_studio`, `engineering_engine` in source files (`.cpp .hpp .h .py .ts .json .toml .cmake`): **zero matches.**

Searched `platform/` for any reference to `oep_acqusition`/`oep_acquisition`/`oep_reference_library`/`oep_exchange`: matches found only under `platform/oep_studio/lib/{acquisition,exchange}/` — all HTTP API-client code (`*_api_client.dart`, wizard/model DTOs), not source imports of the migrated repos' code. No `path:` pubspec dependency, no `include_directories`, no direct import of migrated source exists in either direction.

**Result: PASS.** Rules A–H (no direct source dependency from Exchange/Reference Library/Acquisition onto Engine/Foundation/Studio, and vice versa) hold.

## 7. Path/file collision audit

`git show <import-commit> --stat --name-only | grep -E "^services/|^knowledge/"` against the pre-import tree returned no matches — `services/` and `knowledge/` did not exist before this migration, so no file at any path was overwritten, merged, or renamed by the subtree imports. **Result: PASS, zero collisions.**

## 8. Generated/anomalous files audit

`services/acquisition/` contains two anomalous root-level files carried over unchanged from the source repo, exactly as they existed there: `eam frozen docs.zip` (76,185 bytes) and `server.log` (1,102 bytes). These were present in the source repository at HEAD and are preserved as-is per the migration's "preserve existing implementations" constraint — **not deleted, not investigated further, flagged for the owner to decide** whether they were meant to be committed (a runtime log and an unlabeled zip at repo root are unusual, but removing them is a content decision outside migration scope).

No other generated-artifact anomalies (build output, `node_modules`, `.venv`, etc.) were found committed in any of the three imports — each source repo's own `.gitignore` already excluded the expected build directories.

## 9. Discrepancy: `services/exchange/packages/*` referenced but absent

The work package's own description of `oep_exchange` (and the repo's own `package.json` `workspaces: ["packages/*", "apps/*"]` and every `apps/*/tsconfig.json`'s `references`) name 14 packages (`core`, `api-contracts`, `manifest`, `signing`, `search`, `package_manager`, `package_cli`, `exchange_client`, `dependency_resolver`, `installer`, `update_service`, `licensing`, `payments`, `reviews`, `interfaces`). **None of these exist anywhere in the source repository's tracked history** — confirmed via `git ls-tree -r -d exchange-src/main` before any migration action was taken, i.e. this is not something the migration broke.

This is reported as a factual finding, not silently fixed: the migration's job is to carry the repository over exactly as it is, not to invent the missing `packages/` tree or repoint the config to make the build pass. See §10 for the resulting build/test status.

## 10. Build/test verification per subsystem (own native toolchain)

| Subsystem | Toolchain | Result |
|---|---|---|
| `knowledge/reference_library` | Python 3 venv, `pip install -e ".[dev]"`, `pytest` | **PASS** — 98/98 tests pass in an isolated venv, no changes needed. |
| `services/exchange` | `npm install`, `npm run build` (tsc -b), `npm run test` (vitest) | **PRE-EXISTING FAILURE**, not migration-induced. `npm run build` fails with `TS6053`/`TS5083` on all 14 missing `packages/*` (§9). `npm run test`: 39/39 individual tests pass across the 19 test files that don't import the missing packages; the other 41 test files fail for the same missing-package reason. Root cause confirmed identical before and after migration (the packages never existed in source history). |
| `services/acquisition` | CMake + C++23 (FetchContent: spdlog, TOML, nlohmann/json, Catch2) | **BLOCKED — tool unavailable in this environment.** No `cmake` executable found on this machine (checked PATH and common install locations). Could not run `cmake -B build && cmake --build build && ctest`. This is an environment limitation of the migration session, not a finding about the repository; the owner should run the existing `tests/CMakeLists.txt`/Catch2 suite locally to confirm. |

No test suite anywhere regressed as a result of the migration itself — the one genuine failure (Exchange build/41 test files) is reproducible identically against the un-migrated source repository and is therefore classified **PRE-EXISTING**, not **MIGRATION-INDUCED**, per the work package's own classification requirement.

## 11. Validation matrix

| Check | Result |
|---|---|
| All 3 repos reachable, default branch confirmed `main` | PASS |
| Safety tag created before first mutation | PASS (`pre-monorepo-integration-001`) |
| History preserved (authorship/dates/messages, no squash) | PASS |
| No path collisions with existing monorepo content | PASS |
| No forbidden cross-imports (either direction) | PASS |
| No code moved into `oep_engine`/`oep_foundation`/`oep_studio` | PASS |
| No source repo modified | PASS |
| No language rewrites, no API/schema changes | PASS |
| Reference Library builds + tests | PASS |
| Exchange builds + tests | PRE-EXISTING FAILURE (§9, §10) |
| Acquisition builds + tests | BLOCKED — cmake unavailable in this environment (§10) |
| Anomalous committed files (acquisition zip/log) | FLAGGED, not resolved (§8) |
| Pushed to `origin/main` | **NOT DONE — pending explicit authorization** |

## 12. Push

Per this session's own operating rules, pushing to `origin/main` is a visible, shared-state action requiring the user's explicit confirmation each time, regardless of what a work package's Definition of Done lists as a completion requirement. The three import commits (`af5c6ec`, `c13628f`, `e21d80f`) plus this documentation are committed locally on `main` and ready to push once authorized.

## 13. Rollback

Source repositories were never modified. To roll back before push: `git reset --hard pre-monorepo-integration-001`. After push (not yet done), rollback would require a revert commit or force-push, to be decided explicitly with the owner at that time.
