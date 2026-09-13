# WP-EXC-011

Title:
Exchange Workspace Reconstruction

Status:
Complete with conditions

Milestone:
Prerequisite to OEP 0.3.x Exchange integration scope; not itself a 0.3.x deliverable.

Dependencies:

- `docs/project/audits/2026-09-13-OEP-RELEASE-BOUNDARY-AUDIT.md` (the audit that discovered this gap)
- `docs/migrations/MONOREPO-INTEGRATION-001.md` §9 (the first record of the discrepancy)
- The original `oep_exchange` upstream repository (`github.com/davidmhuitt86/oep_exchange.git`), consulted directly for this WP

---

# 1. Objective

Restore the `services/exchange/packages/*` npm workspace so the current Exchange service architecture is internally coherent and buildable — not to add features, not to implement Exchange RC1, and not to improve on the historical implementation.

# 2. Historical problem

The OEP Release Boundary & Repository Integrity Audit (2026-09-13) confirmed that Exchange's own architecture documentation (`docs/architecture/REPOSITORY_STRUCTURE.md`, `ADR-0001-Repository-Structure.md`) describes a 14-package npm workspace as already implemented, while the actual `services/exchange/packages/` directory did not exist anywhere in this repository's history. This work package re-investigated that finding directly against the original upstream `oep_exchange` repository (not merely re-citing the prior migration record) and established the following, precisely:

- The upstream repository has exactly 5 commits: `1da19f1` ("file structure complete"), `d4bad3f` ("amendments"), `75f5d4d` ("wp004"), `18484e3` ("backend complete"), `c6dbb75` ("v2").
- All 14 documented packages exist, complete, at `18484e3` — this is the last known good state.
- `c6dbb75` ("v2") — the upstream repository's own final commit, and the exact commit imported into this monorepo as the Exchange subtree source — **deletes all 14 packages** (confirmed via `git diff --name-status 18484e3 c6dbb75 -- packages/`, showing every file under `packages/` as deleted, and `git ls-tree -r c6dbb75 -- packages/` returning zero files) while, in the same commit, adding new `publisher-portal` frontend pages/hooks (`ExchangeApiClientContext.tsx`, several page components) that assume a **real** `@oep-exchange/exchange-client` implementation (`ExchangeApiClient`, `ExchangeApiError`) that was never actually committed anywhere — `exchange_client` at `18484e3` (the last state before deletion) was still only its original TASK-EXC-0001 scaffold (`export const PACKAGE_NAME = ...`), per its own doc comment: "Real implementation arrives in TASK-EXC-0007 (Download API)."
- `c6dbb75`'s commit message is the single word "v2" — **no rationale is recorded anywhere**, in either the upstream repository or this monorepo's own history.
- The current monorepo's root `tsconfig.json` additionally references a 15th path, `packages/package_cli`, which **was added by `c6dbb75` itself** (confirmed via `git diff 18484e3 c6dbb75 -- tsconfig.json`) — the same commit that deleted everything else — but which **never existed as an implementation in any commit, in either repository, ever**. `package-lock.json` (already present in this monorepo before this WP) independently corroborates that `@oep-exchange/package-cli` was once *planned* (it carries a stale dependency-shape record for it), but no source was ever committed.

**Conclusion on intent**: the evidence (simultaneous mass deletion + new, dependent frontend code + a new, never-implemented package reference, all in one undocumented "v2" commit) is more consistent with an incomplete, interrupted refactor than a deliberate architectural decision — but this is an inference from circumstantial evidence, not a fact established by git history. This is stated plainly rather than guessed at further.

# 3. Scope

Restoring the 14 historically-real packages from their last known good state (`18484e3`), repairing the one dangling workspace reference (`package_cli`), and verifying the resulting workspace builds, typechecks, lints, and runs its test suite. See the Implementation Report for exact results.

# 4. Out of scope

Exchange RC1, WP-EXC-010, Studio integration, licensing/payments/reviews functionality (their packages are restored as the same inert scaffolds they always were — see §8 below — not implemented), a real `@oep-exchange/exchange-client` `ExchangeApiClient`/`ExchangeApiError` implementation (this is TASK-EXC-0007's own scope, never historically completed — see §14), any new API, any architectural redesign.

# 5. Package inventory

| Package | Documented | Existed historically | Currently exists (pre-WP) | Currently referenced | Historical impl. recoverable | Current build requires | Current tests require | Intended status | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| `core` | Yes | Yes (`18484e3`) | No | Yes (root tsconfig, all apps) | Yes (full) | Yes | Yes | **RESTORE** | `git ls-tree 18484e3 packages/core` — 13 real source files |
| `api-contracts` | Yes | Yes | No | Yes | Yes (full) | Yes | Yes | **RESTORE** | 14 files, depends only on `core` |
| `manifest` | Yes | Yes | No | Yes | Yes (full) | Yes | Yes | **RESTORE** | 10 files, real parse/extract logic |
| `signing` | Yes | Yes | No | Yes (transitively, via `package_manager`) | Yes (full) | Yes | Yes | **RESTORE** | 6 files |
| `search` | Yes | Yes | No | Yes | Yes (full) | Yes | Yes | **RESTORE** | 10 files |
| `package_manager` | Yes | Yes | No | Yes (`exchange-api`) | Yes (full) | Yes | Yes | **RESTORE** | 12 files, real upload-pipeline orchestration |
| `exchange_client` | Yes | Yes | No | Yes (`exchange-admin`, `publisher-portal`) | Partial — only the pre-TASK-EXC-0007 scaffold exists in any commit | Yes (scaffold satisfies `exchange-admin`; does not satisfy `publisher-portal`'s newer consumer code) | Partial | **RESTORE (scaffold only)** | Real `ExchangeApiClient`/`ExchangeApiError` was never committed anywhere — see §14, a confirmed unrecoverable gap |
| `installer` | Yes | Yes | No | Yes (`exchange-api`) | Yes (full) | Yes | Yes | **RESTORE** | 10 files |
| `interfaces` | Yes | Yes | No | Yes (`installer`) | Yes (full) | Yes | Yes | **RESTORE** | 7 files, defines `RepositoryClient` |
| `dependency_resolver` | Yes | Yes | No | No (not a dependency of any current app) | Yes (scaffold) | No | No | **RESTORE (scaffold, not build-required)** | 6 files, explicitly deferred past MVP per its own README |
| `update_service` | Yes | Yes | No | No | Yes (scaffold) | No | No | **RESTORE (scaffold, not build-required)** | 6 files, same as above |
| `licensing` | Yes | Yes | No | No | Yes (scaffold) | No | No | **RESTORE (scaffold, not build-required)** | 6 files, explicitly excluded from WP-EXC-001 scope per its own doc comment |
| `payments` | Yes | Yes | No | No | Yes (scaffold) | No | No | **RESTORE (scaffold, not build-required)** | same |
| `reviews` | Yes | Yes | No | No | Yes (scaffold) | No | No | **RESTORE (scaffold, not build-required)** | same |
| `package_cli` | Referenced only (root `tsconfig.json`) | **No — never existed in any commit, either repository** | No | Yes, but only as a dangling `tsconfig.json` reference, and only added in the same `c6dbb75` commit that deleted everything else | **No — nothing to recover** | No (nothing depends on it) | No | **REMOVE FROM ARCHITECTURE** (the dangling reference) | `git log --all -- packages/package_cli` returns nothing in either repository; `package-lock.json` carries a stale, never-realized dependency-shape record corroborating it was planned but never built |

All 14 real packages are restored byte-for-byte from `18484e3` — none were reimplemented, improved, or modernized. `package_cli`'s dangling reference is removed from `services/exchange/tsconfig.json`, not fabricated.

# 6. Historical recovery evidence

Recovery was performed by fetching `https://github.com/davidmhuitt86/oep_exchange.git` directly (temporary remote, removed immediately after use — no residue left in this repository's git configuration) and extracting `packages/` at commit `18484e3` via `git archive 18484e3 packages | tar -x`. Every restored file is therefore byte-identical to its last committed state in the authoritative upstream history, not reconstructed from documentation or memory. `apps/exchange-api`'s own source was confirmed unchanged between `18484e3` and `c6dbb75` (`git diff --name-status` returns nothing), and confirmed identical to the currently-checked-out version — meaning the restored packages are guaranteed compatible with the consumer code that actually exists today, for every consumer except `publisher-portal`'s newer, TASK-EXC-0007-dependent pages (§14).

# 7. Restored packages

`core`, `api-contracts`, `manifest`, `signing`, `search`, `package_manager`, `exchange_client`, `installer`, `interfaces`, `dependency_resolver`, `update_service`, `licensing`, `payments`, `reviews` — all 14, restored verbatim from `18484e3`. 118 files total.

# 8. Re-scoped/deferred packages

None of the 14 required re-scoping — each was restored exactly as it existed historically, including the five that are (and always were, by their own original scope) inert scaffolds (`dependency_resolver`, `update_service`, `licensing`, `payments`, `reviews`). `package_cli` is the one item re-scoped: from "referenced as a future workspace member" to **removed from the workspace reference list**, since it never had an implementation to restore.

# 9. Build configuration

No change to `services/exchange/package.json`'s scripts, `tsconfig.base.json`, or `vitest.config.ts` — all confirmed byte-identical (after CRLF normalization) to their `18484e3` state; none were touched by the upstream deletion commit or needed any change here. The single configuration change made: removing the `packages/package_cli` entry from `services/exchange/tsconfig.json`'s `references` array (§5, §8). `package-lock.json` was regenerated by `npm install` against the restored workspace (a 1-insertion/4-deletion diff — the `package-cli` workspace link removed, that entry flagged `extraneous` — no other change).

# 10. Test configuration

No new test framework introduced. All restored packages carry their own pre-existing Vitest test files (part of the 118 restored files) — these were not written for this WP, they are the historical tests, restored as-is. No new test file was authored by this WP; per its own governing instructions ("do not invent a large new test suite... add only the minimum regression coverage required to prove the restored workspace functions"), the pre-existing, now-executable historical test suite already satisfies that requirement without any addition.

# 11. Architecture impact

None. No package boundary was collapsed, no new package was introduced, no Exchange functionality was moved into or out of any other OEP subsystem. The dependency graph (`core` at the root; `api-contracts`/`manifest`/`signing` depending only on `core`; `search`/`exchange_client`/`reviews` depending on `core`+`api-contracts`; `package_manager` depending on `core`+`manifest`+`signing`; `dependency_resolver` depending on `core`+`manifest`; `installer`/`update_service` depending on `core`+`exchange_client`(+`interfaces` for `installer`)) is exactly the graph that existed at `18484e3`, unmodified.

# 12. Documentation reconciliation

`services/exchange/docs/architecture/REPOSITORY_STRUCTURE.md`, `ADR-0001-Repository-Structure.md`, and `COMPONENT_GUIDE.md` are **not modified by this WP** — their description of the 14-package workspace is now accurate again (the workspace they describe exists), so no correction is owed to them. `OEP_PROJECT_STATUS.md` and `docs/project/OEP_RELEASE_HISTORY.md` are updated (see the Implementation Report) to record that the workspace foundation is now restored, distinct from Exchange RC1 remaining not started.

# 13. Security considerations

No security-sensitive behavior was introduced. The restored packages are the same code that existed historically; none of them perform new network I/O, new file-system access, or new trust decisions beyond what already existed. ADR-0003 (HttpConnector, an unrelated EAM subsystem) was not touched. No new unrestricted network behavior was added anywhere in Exchange.

# 14. Known remaining gaps

**`@oep-exchange/exchange-client`'s real implementation (`ExchangeApiClient`, `ExchangeApiError`) was never committed anywhere, in either repository, at any commit.** `publisher-portal`'s pages/hooks that consume it (`ExchangeApiClientContext.tsx`, `use-async.ts`, and several page components — all added in `c6dbb75`, unchanged since) reference symbols that do not exist in the restored (historically accurate) `exchange_client` scaffold. This is **not a restoration failure** — there is nothing further to restore; the real implementation genuinely does not exist in git history anywhere. Implementing it now would mean writing TASK-EXC-0007 ("Download API") from scratch, which is explicitly out of scope for this WP (§4) and would constitute new Exchange feature work. This gap is the sole cause of `publisher-portal`'s build/typecheck failure and 12 test failures (§ Implementation Report). `exchange-api` and `exchange-admin` are unaffected — both build, typecheck, and (for exchange-admin) test cleanly.

# 15. Verification

See `services/exchange/docs/audits/WP-EXC-011-IMPLEMENTATION-REPORT.md` for exact commands and results.

# 16. Exit criteria

- [x] Historical Exchange package state established (upstream `oep_exchange`, commit `18484e3`, directly fetched and inspected).
- [x] Missing package history investigated (deletion isolated to `c6dbb75`, no rationale found).
- [x] Each documented package given an explicit disposition (§5).
- [x] Recoverable authoritative implementation restored (14/14 real packages, byte-identical).
- [x] Workspace configuration coherent (one dangling reference removed).
- [x] Current Exchange build succeeds — **for 13 of 14 real packages plus `exchange-api`/`exchange-admin`; `publisher-portal` fails for the one confirmed-unrecoverable reason in §14.**
- [x] Current Exchange test suite executes — 83 test files discovered (up from 60 pre-restoration), 59 passed / 7 failed / 17 skipped (pre-existing, Postgres-gated, unrelated to this WP); 420 tests, 284 passed / 12 failed / 124 skipped. All 12 failures and all 7 failing files are `publisher-portal`, all trace to the single gap in §14.
- [x] TypeScript composite build (`tsc -b`, covering all restored packages + `exchange-api`) succeeds with zero errors.
- [x] Package dependencies resolve (`npm install` succeeds, 398 packages installed, workspace links resolve).
- [x] No unrelated OEP subsystem modified.
- [x] No Exchange RC1 features implemented.
- [x] Documentation accurately reflects reality (this document + the Implementation Report; no claim of `publisher-portal` passing).
- [x] Remaining gaps explicitly documented (§14).
- [x] WP-EXC-010 remains untouched and separate.
- [x] A dedicated WP-EXC-011 commit created.
- [x] Nothing pushed.

# 17. Final disposition

**COMPLETE WITH CONDITIONS.** The Exchange workspace foundation is restored to a verified, historically-authentic, buildable state for 13 of 14 real packages and 2 of 3 apps. The one remaining gap (`publisher-portal`'s dependency on a never-implemented `exchange_client` API) is precisely diagnosed, proven unrecoverable from git history, and correctly out of scope for this WP rather than papered over. WP-EXC-010 may proceed against this foundation once a decision is made about how to close the `exchange_client`/TASK-EXC-0007 gap — that decision and its implementation belong to a future work package, not this one.
