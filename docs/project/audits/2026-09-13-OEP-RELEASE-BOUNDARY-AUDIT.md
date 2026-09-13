# OEP Release Boundary & Repository Integrity Audit — 2026-09-13

Point-in-time audit. Companion to [`/OEP_PROJECT_STATUS.md`](../../../OEP_PROJECT_STATUS.md) and [`2026-09-13-OEP-MASTER-AUDIT.md`](2026-09-13-OEP-MASTER-AUDIT.md). This audit's purpose is narrower and more operational than the master audit: determine whether the 8 local, unpushed commits should become the next official baseline, and what — if anything — must happen before pushing them to `origin/main`.

**No commits were pushed. No history was rewritten. No production source code was modified. No versions were bumped.**

---

## 1. Executive Summary

The 8 local commits are a linear, dependency-ordered, non-overlapping sequence spanning three genuinely separate bodies of work: a Diagram Studio WebView lifecycle fix + its human-acceptance-test scaffolding (PR-014 through PR-016A/bead021), an EAM/Reference Vault audit-and-hardening pass (WP-017), an EAM Acquisition Record foundation (WP-018), and a project-control documentation system (this session's own prior commit). All 8 are individually well-formed, individually low-risk, and collectively free of merge conflicts, file collisions, or contradictory changes — verified via direct diff inspection, not inferred from commit messages.

They do **not**, however, represent one single coherent "release" in the sense of one planned unit of work — they are four independent work streams that happen to be adjacent in history because they were done in sequence in one session. This is not a defect; it means the release-boundary question has more than one correct answer depending on what "the release" is defined to include (see Section 7).

The most consequential finding of this audit is **not** about any of the 8 commits themselves: it is that Exchange's own architecture documentation describes a 14-package npm workspace that has never existed in the current repository, and was in fact deleted from the *upstream* `oep_exchange` source repository's own final commit (`c6dbb75`, message: "v2", no stated rationale) before the monorepo migration ever touched it. This is independently re-confirmed by this audit (not merely re-cited) by fetching the original upstream repository directly and diffing it. It is unrelated to any of the 8 local commits and does not block pushing them, but it is a release-relevant fact the founder should know before treating Exchange as workable.

**Recommendation, in one sentence**: the 8 commits are safe to push as-is once two documentation-accuracy conditions are met (both already largely satisfied — see Section 17), but "push" and "declare 0.2.x" are two different decisions, and this audit answers only the first one favorably; 0.2.x itself remains NOT YET READY (Section 8).

## 2. Audit Scope

Git history, working-tree state, diffs of all 8 local commits, the Exchange package-history question, the credential-exposure claim, ADR-0003/ADR-0008 status, current version fields, and the project-control documentation's accuracy against the state described above. No test suites were re-executed (WP-017's and WP-018's own test runs, 221/981 and 235/1090 respectively, were already performed and recorded in this same session with real PostgreSQL 18; nothing has changed in any tested file since — confirmed below — so re-running would reproduce identical results at real time cost for no new information).

## 3. Repository Baseline

Verified directly, 2026-09-13:

```
$ git status --short --branch
## main...origin/main [ahead 8]
 M platform/oep_instruments/platform/oep_instruments/build/test_cache/build/400b043068ba1fc43c2a688da95fc6a1.cache.dill.track.dill
?? platform/oep_studio/docs/testing/.~lock.DIAGRAM-STUDIO-HUMAN-UX-UI-TESTER-START-GUIDE.md#

$ git rev-parse HEAD
1474c0e1b57f38e45986d93577a8f0a66360e426

$ git rev-parse origin/main
78ee8b06cbb397b7c7c02998923858a609ddac68

$ git merge-base HEAD origin/main
78ee8b06cbb397b7c7c02998923858a609ddac68        (= origin/main itself: no divergence, pure fast-forward)

$ git rev-list --left-right --count origin/main...HEAD
0    8
```

**Working tree**: not clean, but both modifications are pre-existing, unrelated, and not part of any of the 8 commits:
- `platform/oep_instruments/.../*.cache.dill.track.dill` — a Dart build-cache artifact, modified by simply having built/run the Instruments app at some point; not source, not staged, not committed by this or any prior session.
- `platform/oep_studio/docs/testing/.~lock.DIAGRAM-STUDIO-HUMAN-UX-UI-TESTER-START-GUIDE.md#` — a LibreOffice lock file from someone having that document open; harmless, untracked.

No staged changes. No submodules (`git submodule status` returns nothing). No build artifacts were found committed in any of the 8 commits (spot-checked via each commit's own file list, Section 5).

## 4. Remote vs. Local State

`origin/main` = `78ee8b0`, confirmed the actual current remote tip (not assumed from the task prompt — independently verified via `git rev-parse origin/main` against a fetched remote-tracking ref). Local `main` is a **pure linear fast-forward** ahead of it by exactly 8 commits — `git merge-base HEAD origin/main` equals `origin/main` itself, meaning there is no divergence, no rebase needed, and pushing would be a trivial fast-forward with zero conflict risk at the Git level. This is the simplest possible push topology.

## 5. Commit-by-Commit Analysis

Each entry: hash, parent (confirmed linear — each commit's sole parent is the immediately preceding one), files changed (from `git show --stat`), and findings from reading the actual diff, not the message.

### `1a97358` — PR-014: stabilize Diagram Studio WebView lifetime
**Parent**: `78ee8b0` (origin/main tip). **Files**: 5 (1 new doc, 4 modified Dart files — the only production-source changes in the entire 8-commit range).
**Production impact**: `diagram_with_compare_pane.dart` — the actual fix. Confirmed by direct diff: the widget tree previously branched into `compareEnabled ? Row(...) : analysisEnabled ? Row(...) : ... : const LegacyV2WebViewPage()`, where the final "no panel" branch built a bare, unwrapped `LegacyV2WebViewPage()` while every other branch wrapped it in a `Row`. Flutter's element reconciliation keys on `runtimeType` at a given tree position; toggling between "no panel" and "any panel" flipped the type at that position (`Row` vs. `LegacyV2WebViewPage`), which Flutter treats as "cannot update," forcing a full State dispose/recreate of the Primary WebView. The fix makes the `Row` and the Primary's `Expanded(LegacyV2WebViewPage())` unconditional, with only the trailing side-panel children varying — verified against the actual diff, not the commit message.
`compare_legacy_v2_webview.dart`, `legacy_v2_state_adapter.dart`, `legacy_v2_webview.dart` — confirmed to be purely additive lifecycle-logging instrumentation (`logV2WebviewLifecycle('CREATE'/'INIT'/'LOAD'/'SEED'/'REINITIALIZE'/'DISPOSE', ...)`), no behavioral changes.
**Test files changed**: none. **Migrations**: none. **Architecture impact**: none — a targeted bugfix within existing widget-tree structure, no new abstraction introduced.
**Dependency on earlier local commits**: none (first commit).
**Self-contained**: yes. **Safe to push**: yes. **Belongs in next baseline**: yes.

### `8634276` — PR-015: add Diagram Studio human UX/UI acceptance test system
**Parent**: `1a97358`. **Files**: 3, all new markdown (test spec, fillable form, a "human test report" template). **Production/test/migration files changed**: none — pure documentation/process scaffolding.
**Dependency**: soft, documentation-only — this test spec is written to validate PR-014's fix, but nothing about this commit requires PR-014's diff to exist to apply cleanly; it is a dependency of *purpose*, not of *mechanics*.
**Self-contained**: yes. **Safe to push**: yes. **Belongs in next baseline**: yes, though see Section 7 on whether it belongs in the *same* release unit as PR-014's code fix or is better understood as its own artifact.

### `5c231b5` — PR-016: prepare Diagram Studio human acceptance testing
**Parent**: `8634276`. **Files**: 1 new markdown (tester start guide). **Dependency**: documentation-only, on PR-015 (references the test form/spec it introduces). **Self-contained**: yes. **Safe to push**: yes.

### `84564de` — PR-016A: add interactive Diagram Studio human acceptance tester
**Parent**: `5c231b5`. **Files**: 2 (one new HTML tool, one modified — the start guide, updated to reference the new tool). **Dependency**: documentation-only, on PR-016 (extends the same start guide). **Self-contained**: yes. **Safe to push**: yes.

### `bead021` — Fix HTML acceptance tester sidebar nav order
**Parent**: `84564de`. **Files**: 1 modified (the PR-016A HTML tool). **Dependency**: hard — this is a bugfix to code introduced in `84564de`; it cannot be reordered before it and has no independent meaning without it. **Self-contained**: no (by design — it's a fixup). **Safe to push**: yes. **Belongs in the baseline**: yes, though a case exists for squashing it into `84564de` (see Section 15) since it fixes a defect in a commit two positions earlier in the same local-only history, with no intervening push to make history rewriting risky.

### `8c6185c` — WP-017: EAM/Reference Vault implementation audit and hardening
**Parent**: `bead021`. **Files**: 11 — 4 new audit/decision documents, 1 new migration (`V9__reference_vault_fk_indexes.sql`), 1 production file (`reference_vault_service.cpp`, the orphan-file-race fix), 4 test files (2 new, 2 modified), 1 test-fixture file modified (`vault_test_support.cpp`).
**Production impact, verified by diff** (already reviewed in the session that produced this commit, re-confirmed here by re-reading the diff): `ReferenceVaultService::publish` now tracks whether *this call* performed the vault-file copy and removes it if the subsequent repository insert throws, without ever touching a file a dedup hit legitimately reuses. `V9` is additive-only (adds 3 missing indexes to `reference_vault`, does not touch `V8` or any other prior migration).
**Test evidence**: 221/221 test cases, 981/981 assertions, 0 skipped, 0 failed, against real PostgreSQL 18, confirmed across two consecutive runs (recorded in `services/acquisition/docs/audits/EAM_REFERENCE_VAULT_M2_READINESS.md`, produced by this same commit).
**Dependency**: soft — depends on the pre-existing EAM codebase (already on `origin/main` via the WP-001–009 work, which predates this entire local range), not on any of the preceding 5 local commits (PR-014–bead021), which are Studio/Diagram-Studio-only and touch no shared files.
**Self-contained**: yes. **Safe to push**: yes. **Belongs in baseline**: yes.

### `0494e25` — WP-018: implement Acquisition Record and provenance foundation
**Parent**: `8c6185c`. **Files**: many (new `provenance` module — 5 headers, 5 source files, 1 CMakeLists; 1 new migration `V10`; 3 new docs; 4 modified files: `CMakeLists.txt`, `include/.../api/server.hpp`, `src/api/server.cpp`, `src/api/CMakeLists.txt`, `src/app/main.cpp`).
**Verified, per this audit's own fresh `git show --stat` + `grep` pass (not merely re-cited from the implementing session)**: this commit's diff contains **zero** occurrences of `download_service`, `integrity_verification_service`, `metadata_extraction_service`, `reference_vault_service`, or `V8__` — confirming the governing constraint ("no modifications to the four existing acquisition pipeline services," "no Reference Vault V8 modification") was actually honored, not merely claimed. It also contains zero occurrences of any `oep_studio`, `http_connector`, or ADR file path (the one textual match for "ADR-0003" is inside the commit *message*, explaining what was deliberately *not* touched — not a file path).
**Test evidence**: 235/235 test cases, 1090/1090 assertions, 0 skipped, 0 failed, against real PostgreSQL 18, twice consecutively (14 new test cases beyond WP-017's 221, all newly added by this commit — confirmed by `grep -c TEST_CASE` across the 4 new acquisition-record test files: 10+1+2+1 = 14, matching).
**Dependency**: hard, on `8c6185c` — the `provenance` module's CMakeLists links against `oep_acquisition_vault` (established/hardened by WP-017) and the new tests seed data through the same vault test-support helpers WP-017 modified. Reordering these two would not apply cleanly.
**Self-contained**: yes, as a unit with `8c6185c`. **Safe to push**: yes. **Belongs in baseline**: yes.

### `1474c0e` — Establish canonical OEP project-control, versioning & master status system
**Parent**: `0494e25`. **Files**: 11, all markdown (`OEP_PROJECT_STATUS.md` + 5 new `docs/project/` files + 5 modified pre-existing Foundation documents, each receiving only a short supersession/cross-reference notice).
**Verified**: zero non-`.md` files in this commit (confirmed via `git show --name-only 1474c0e | grep -v '\.md$'` returning nothing beyond the commit message itself).
**Dependency**: soft — this commit's content *describes* WP-017/WP-018/PR-014-016A's actual state, so it is logically downstream of all 7 prior commits, but it does not touch any file any of them touch and would apply cleanly regardless of order.
**Self-contained**: yes. **Safe to push**: yes. **Belongs in baseline**: arguably a different kind of "belongs" than the other 7 — see Section 7.

## 6. Dependency Analysis

**Hard dependencies** (order matters, cannot be reordered without conflict or breakage):
- `bead021` → `84564de` (fixes a defect introduced there)
- `0494e25` → `8c6185c` (links against and reuses test infrastructure WP-017 established/modified)

**Soft dependencies** (logically related, would not conflict if reordered, but reordering would be confusing):
- `8634276`/`5c231b5`/`84564de` each softly depend on the one before (documentation cross-references a prior document), and all three softly depend on `1a97358` (they exist to validate its fix).
- `1474c0e` softly depends on everything before it (it describes their state).

**Documentation-only dependencies**: all of PR-015/016/016A's inter-dependencies, and `1474c0e`'s dependency on everything.

**Independent commits** (touch disjoint files, no relationship beyond adjacency in history): `1a97358`+`8634276`+`5c231b5`+`84564de`+`bead021` (the Diagram Studio thread) are entirely independent of `8c6185c`+`0494e25` (the EAM thread) — **zero file overlap**, confirmed via `git diff --name-status` per commit. Nothing about the EAM work required the Diagram Studio work to exist first, or vice versa; they are adjacent in this history purely because of session ordering, not because of any real dependency.

**Commits that can be safely separated**: the Diagram Studio thread (5 commits) and the EAM thread (2 commits) could be pushed, reverted, or cherry-picked independently of each other with zero conflict, if a future decision required that. `1474c0e` cannot be cleanly separated from the other 7 without becoming factually wrong (it describes their state).

The task's own suggested conceptual chain (PR-014 → PR-015 → PR-016 → PR-016A → WP-017 → WP-018 → Project Control, all as one dependency line) is **partially correct and partially misleading**: the ordering is correct as *history*, but it is not correct as a *dependency graph* — WP-017/WP-018 do not depend on PR-014 through PR-016A in any technical sense, and are only sequenced after them because that is the order the work happened to be done in.

## 7. Release Boundary Analysis

Evaluating the five stated classifications against the evidence in Sections 5–6:

**(A) One coherent release increment** — not accurate. The Diagram Studio thread and the EAM thread share no files, no dependency, and no common objective beyond both being OEP work.

**(B) Several logically separate increments that should remain separate** — partially accurate. There are, in fact, at least three logically separate bodies of work here (Diagram Studio lifecycle+testing, EAM/Vault+Acquisition-Record, project-control documentation). But "should remain separate" as a *Git* matter is a different question from whether they should remain separate as a *push* matter — see below.

**(C) A mixture of release work and project-control work** — accurate, and the most precise available label. Commits 1–6 (`1a97358` through `0494e25`) are release/feature-adjacent engineering work (a bugfix + its test scaffolding, and a full audited feature addition). Commit 7 (`1474c0e`) is pure project-control/documentation work describing the state the first six produced. This is not a problem — it is the correct order for project-control documentation to be written (after the state it describes exists, not before) — but it does mean "this local branch" is not a single homogeneous unit of one kind of work.

**(D) Something that should NOT yet be pushed** — not supported by the evidence in this section alone. Nothing found in Sections 5–6 makes any of the 8 commits individually unsafe to push (no broken build, no contradictory changes, no merge risk — the merge-base is a pure fast-forward). Section 8 and Section 17 identify separate, real reasons a push might reasonably be delayed, but those reasons are about *readiness of what the commits represent* (human acceptance not run, ADR-0003 open), not about *defects in the commits themselves*.

**Conclusion**: **(C)**, with the practical implication that pushing all 8 is safe at the Git-mechanics level (Section 4), while declaring them "the 0.2.x release" would overstate what they collectively accomplish (Section 8). These are two separate decisions and this audit recommends making them separately (Section 15).

## 8. 0.2.x Readiness

Per `docs/project/OEP_MILESTONE_ROADMAP.md`'s own M1/0.2.x exit criteria, re-checked against current evidence:

| Subsystem | State | Evidence |
|---|---|---|
| Foundation | Substantially reached, version identity not build-enforced | `platform/oep_foundation/CMakeLists.txt` has no `VERSION` argument |
| EKE | Internal v1.0 freeze, documented, not re-verified by this audit | Carried from prior state; this audit did not re-run EKE's own suite (out of scope) |
| Engineering Engine | Present, `0.1.0`, tied to Diagram Studio's own maturity | `platform/oep_engine/pubspec.yaml` |
| Studio | Functional foundation, known gaps (FFI mutation depth, placeholders) | Prior audits, unchanged this pass |
| Diagram Studio | Functional vertical slice; PR-014 fix verified present and unique in history (Section 5); **human acceptance not executed** | `git log` for the file, Section 9-10 below |
| Electrical runtime / DMM / Trace / Circuit Intelligence | Present, bounded, unchanged this pass | Not re-verified in this narrow audit; no local commit touches these |
| Knowledge Runtime | Core path present; Ed25519/BLAKE3 not implemented | Unchanged this pass |
| EAM M1 | Complete, WP-017 hardening applied | Section 11 |
| Reference Vault M1 | Complete, WP-017 hardening applied | Section 11 |
| Acquisition Record | **Now complete**, LOCAL / NOT PUSHED | Section 12 |
| Exchange foundation | App scaffolds present; **confirmed broken build** (`packages/*` missing) | Section 13 |
| Application shell | Present (PR-013, already on `origin/main`) | Unchanged this pass |
| Security | Credential claim reclassified as documentation drift, not resolved; ADR-0003 open | Section 14 |
| Performance | No benchmark suite | Unchanged this pass |
| Documentation/release control | This system exists and is, per this audit, accurate | Sections 16-17 |
| Human UX validation | **Not executed** | Section 10 |

**Decision: NOT YET READY**, with two specific, named gates (ADR-0003, human UX/UI acceptance execution) standing between the current state and a credible 0.2.x declaration — not a long, vague list. Both gates are already correctly identified in the existing roadmap; this audit did not discover a *new* 0.2.x blocker, it confirmed the existing ones are still open and found one *additional*, previously-under-specified fact (Exchange's confirmed broken build) that does not block 0.2.x itself (Exchange was only ever scoped to reach "basic foundation" for 0.2.x, not a working build) but should be recorded precisely rather than left as "foundation exists."

## 9. Diagram Studio Status

PR-014's fix is confirmed present, unique in history (only commit touching these files across the entire local range — Section 5), and unmodified by any later commit. The fix itself is a small, well-reasoned, low-risk widget-tree restructuring, verified from the actual diff. **This audit did not modify any Studio production code**, per its own constraints, and did not re-run any Studio test to re-verify the fix's runtime behavior beyond what was already recorded (a single instrumented Windows debug launch showing one CREATE/INIT/LOAD/SEED, no DISPOSE) — that original verification stands as-is; no new evidence was added or needed for this narrower audit.

## 10. Human Acceptance Status

**Not executed.** Verified: `platform/oep_studio/docs/testing/` contains the test spec, form, start guide, and interactive HTML tool (all present, all committed) but **no test-report file with actual recorded human observations exists** — `PRODUCT-READINESS-015-HUMAN-UX-UI-TEST-REPORT.md` is a template/report shell created alongside the test system itself (same commit, `8634276`), not a filled-in result. No commit in this range adds or modifies a document recording an actual completed test session. **Status: READY FOR HUMAN TEST, not PASSED, not FAILED, not PARTIAL** — the correct classification is simply that the test has not yet been run, and this audit makes no claim beyond that.

## 11. EAM / WP-017 Status

Re-verified, not merely re-cited: `services/acquisition/docs/audits/EAM_REFERENCE_VAULT_M2_READINESS.md` (added by `8c6185c`) records 221/221 test cases, 981/981 assertions, 0 skipped, 0 failed, twice consecutively, against real PostgreSQL 18 — this audit did not re-run these tests (Section 2) but did re-confirm the commit's file-level diff matches the claims made about it (the orphan-file-race fix, the additive `V9` migration). ADR-0003 (documented by the same commit) remains **unresolved** — confirmed by `git log` showing exactly one commit ever touched that file (its creation) and zero commits modifying `http_connector.cpp`/`.hpp` anywhere in the local range. **WP-017's `READY WITH CONDITIONS` classification remains justified** — nothing in this narrower audit changes any of its three original conditions.

## 12. WP-018 Status

Re-verified via fresh `git show --stat` + targeted `grep` against the actual commit diff (Section 5): confirmed zero touches to the four pipeline services, zero touches to `V8`, zero touches to Studio, zero touches to `HttpConnector`/ADR files. The `provenance` module, `V10` migration, new REST routes, and 4 new test files (14 new `TEST_CASE`s) are all present exactly as documented. **WP-018 should be considered complete** for the scope it defined for itself (see `services/acquisition/docs/audits/WP-018-IMPLEMENTATION-REPORT.md`'s own Gap Classification for what remains deliberately deferred — rich per-acquisition metadata, SHA-512/BLAKE3, custody events, the `Archived` lifecycle state). ADR-0008 remains **absent** — a fresh `find . -iname "*ADR-0008*"` across the full repository returned zero results, unchanged from every prior audit.

## 13. Exchange Package Investigation

**This is the audit's most significant finding, and it is independently re-verified in this pass, not merely re-cited from `docs/migrations/MONOREPO-INTEGRATION-001.md`.**

Methodology: `git log --all` / `--follow` against `services/exchange/packages` in the current monorepo (zero results, confirming the directory has never existed in *this* repository's history, on any ref). Then, because that alone cannot establish what happened in the *original* `oep_exchange` source repository before it was subtree-imported, this audit **fetched the original upstream repository directly** (`https://github.com/davidmhuitt86/oep_exchange.git`, temporary remote, removed immediately after use — no residue left in this repository's configuration) and inspected its own 5-commit history directly:

```
c6dbb75 v2                        <- imported as this migration's source HEAD
18484e3 backend complete
75f5d4d wp004
d4bad3f amendments
1da19f1 file structure complete
```

`git diff --name-status 18484e3 c6dbb75 -- packages/` shows the entire `packages/` tree (`core`, `api-contracts`, and all other packages — 118+ files in the two packages alone that this audit spot-checked, matching the prior migration record's count of 214 across all 14) deleted with git status `D`. `git ls-tree -r c6dbb75 -- packages/` confirms zero files remain at that commit. **`c6dbb75`'s own commit message is the single word "v2"** — no stated rationale exists anywhere in this repository's or the upstream repository's own git history.

Answering the task's 12 questions directly:

1. **Did the packages ever exist in this repository?** Not in `open_engineering_platform` (the monorepo) — only inside the imported second-parent history reachable from the subtree-merge commit `e21d80f^2`, i.e. as part of what was imported, not as a live directory at any point after import.
2. **If yes, when?** In the upstream `oep_exchange` repository, at every commit before its own final commit (`1da19f1` through `18484e3`).
3. **In which commit (were they removed)?** `c6dbb75` ("v2"), the upstream repository's own final/HEAD commit — the exact commit that was imported as this migration's source.
4. **When were they removed?** At/immediately before that final upstream commit, before the monorepo migration ever touched this code.
5. **Why, if git history documents why?** **Git history does not establish a reason.** The commit message is "v2" with no body. This audit does not invent one.
6. **Was the deletion intentional or accidental?** **Cannot be established with certainty.** The mechanical pattern — deleting all 14 packages in the same commit that adds the `publisher-portal` app and its API-client wiring, while *not* updating `package.json`'s `workspaces` array or any `tsconfig.json` `references` that still point at the now-deleted packages — is more consistent with an incomplete refactor than a deliberate architectural decision, but this is an inference from circumstantial evidence, not a proven fact. Classified **PRE-EXISTING UNKNOWN** for intent specifically, while the *fact* of what happened and when is fully established.
7. **Did monorepo migration contribute?** **No.** Confirmed by this audit's own direct fetch of the upstream repository: the deletion predates the migration entirely and reproduces identically against the un-migrated source.
8. **What current files still reference them?** `services/exchange/package.json` (`workspaces: ["packages/*", "apps/*"]`) and every `apps/*/tsconfig.json`'s `references` array, plus `apps/exchange-api/package.json`'s `dependencies` (`@oep-exchange/core`, `@oep-exchange/api-contracts`, `@oep-exchange/installer`, confirmed by direct read).
9. **Does the current Exchange build depend on them?** Yes — confirmed via `apps/exchange-api/package.json`'s real dependency declarations on the missing packages.
10. **Is Exchange currently buildable?** No — per `docs/migrations/MONOREPO-INTEGRATION-001.md` §9-10's own build run (not re-run by this narrower audit, since the missing-files evidence alone is already conclusive and reproducing it would add no new information): `npm run build` fails `TS6053`/`TS5083` on all 14 missing packages; `npm run test` passes 39/39 in the 19 test files that do not depend on a missing package, and fails the other 41.
11. **Is the discrepancy blocking WP-EXC-010?** Effectively yes — `core` and `api-contracts` are the foundational dependencies nearly everything else in the workspace (including the one real, working `exchange-api` app) depends on; no further Exchange work package can build or test cleanly until they exist again.
12. **Does it require a dedicated repair/reconstruction work package?** Yes, recommended (see Section 19).

**Classification: PRE-EXISTING (confirmed via direct upstream inspection), CURRENT BUILD BLOCKER.** Not migration-related in the causal sense (Section 7's answer), though it was *carried over by* the migration, faithfully, exactly as the migration's own job required (§9 of that record explicitly declines to silently fix it — a decision this audit endorses as correct). Not documentation-only — this is a real, reproducible build failure, not merely a stale claim.

## 14. Security Investigation

**Credential-exposure claim, re-verified fresh in this pass**: `find . -iname "*anthropic_api_key*"` (repository-scoped) returns nothing; `git log --all --diff-filter=A --name-only` across every commit in this repository's history, filtered for the filename, returns nothing except this session's own prior commit's *message text* referencing the filename in prose (not a file addition). **Classification: FALSE / DOCUMENTATION DRIFT relative to the current repository** — not verified as a current issue, and not marked "resolved," because this audit (like the prior one) cannot inspect other machines, clones, or exposure surfaces (chat logs, screen shares, cloud sync) outside this one checkout. The founder should still personally confirm and rotate if in doubt, exactly as previously recommended.

**HttpConnector**: confirmed unmodified in the entire local range (`git log --oneline origin/main..HEAD` for its source files returns nothing). Real outbound HTTP behavior is unchanged from WP-017's own finding (this audit did not re-read the connector's full implementation again — WP-017's finding already established this precisely, and the file's absence from every local commit's diff confirms nothing about that finding has changed). **ADR-0003 remains unresolved** (Section 11).

## 15. Version Audit

Re-verified fresh: `OEP_API_VERSION 21`, `OEP_ABI_VERSION 1` (`platform/oep_foundation/platform/api/include/oep/api/oep_api.h`, lines 41/47). `platform/oep_studio/pubspec.yaml` and `platform/oep_engine/pubspec.yaml` both `version: 0.1.0`. `platform/oep_foundation/CMakeLists.txt` has no enforced version field (unchanged finding from the prior master audit). No document was found in this pass asserting API 19/20 as *current* (the orphaned worktree's stale header and the three historical Foundation review documents, already carrying supersession notices from the prior session, are the only places 19/20 appear, and both are already correctly contextualized as historical). **No version was changed by this audit**, as required.

## 16. Documentation Audit

`OEP_PROJECT_STATUS.md` was re-read in full for this audit. It **already correctly** distinguishes GitHub main (`78ee8b0`) from local main, already lists WP-018 as `COMPLETE — LOCAL / NOT PUSHED (commit 0494e25)` (Section 11.2, and cross-referenced in the repository-baseline section, the priority order, and the current-master-state section), and already correctly labels the credential claim as documentation drift rather than resolved. **No material inaccuracy was found this pass** — see Section 18 for why `OEP_PROJECT_STATUS.md` was therefore **not** modified by this audit.

`docs/project/OEP_VERSIONING_POLICY.md`, `OEP_MILESTONE_ROADMAP.md`, `OEP_RELEASE_HISTORY.md`, and `docs/project/README.md` were spot-checked for internal consistency with the above; no contradiction found. All internal relative links in the previously-created documentation system were verified once already (prior session); this audit adds one new file (this one) and does not disturb any existing link.

## 17. Release Blockers

**MUST FIX BEFORE PUSH**: none identified. Pushing the 8 commits as-is introduces no defect, no broken build (Studio/EAM build and test independently of Exchange's own pre-existing issue), and no history-integrity problem (Section 4).

**SHOULD FIX BEFORE PUSH**: nothing new — the two open 0.2.x gates (ADR-0003, human UX/UI acceptance execution) are pre-existing, already-tracked conditions, not created by these 8 commits, and are not, on their own, reasons to withhold a push of documentation/audit/foundation work that is honest about their being open. Withholding the push does not resolve either gate.

**CAN DEFER AFTER PUSH**: Exchange `packages/*` reconstruction (pre-existing, unrelated to these 8 commits, does not regress by pushing them); broader EAM M2 scope (rich provenance metadata, custody events); performance benchmarking.

**DOCUMENTATION ONLY**: the credential-exposure claim (already correctly downgraded, not a code change); API 19/20 references in historical documents (already correctly contextualized).

**KNOWN / ACCEPTED LIMITATION**: Diagram Studio human acceptance not yet executed; Exchange build broken; no benchmark suite — all pre-existing, all already disclosed in the current documentation system, none hidden or newly discovered by pushing.

## 18. Push Strategy

**Recommended: push all 8 commits as-is, fast-forward, no squashing, no history rewriting.** Reasoning:
- The merge-base is a pure fast-forward (Section 4) — the lowest-risk possible push topology.
- Each commit is individually well-formed and independently reviewable (Section 5) — squashing would destroy that reviewability for no safety benefit, since there is no conflict to resolve by squashing.
- `bead021` fixing a defect in `84564de` two commits earlier is the one place a squash would arguably improve history cleanliness (folding the fixup into the commit it fixes) — this audit flags it as a **legitimate, optional** cleanup, not a requirement, and explicitly did not perform it (rewriting history is outside this audit's own charter, and the commits are already coherent as-is).
- No release branch is necessary — there is no divergent work on `origin/main` to protect against, and creating one would add process overhead with no corresponding risk reduction given the fast-forward topology.

**This audit did not execute a push.** The recommendation above is for the founder's own decision.

## 19. Recommended Next Work

**Recommended: WP-EXC-011 — Exchange Workspace Reconstruction.**

- **Objective**: recreate (or deliberately, explicitly re-scope away) the 14 missing `packages/*` workspace members so `services/exchange` builds and its full test suite (currently 39/60 passing files) runs, before any further Exchange feature work is attempted.
- **Reason**: this audit independently confirmed (Section 13) that Exchange's own architecture documentation describes a materially more complete, working state than exists in the repository, and that the gap is a genuine, reproducible build blocker predating this monorepo entirely — not a documentation nit, not something WP-EXC-010 (Exchange RC1 + Studio integration) can responsibly build on top of as-is.
- **Prerequisites**: none technical; a founder decision on whether to reconstruct the packages from the specifications each still-present README describes, or to formally re-scope Exchange's documentation to match a smaller, currently-real surface.
- **Should NOT include**: Exchange RC1 feature work (WP-EXC-002 through WP-EXC-010's own remaining scope), Studio integration, licensing/payments/reviews (still explicitly excluded per WP-EXC-001's own scope), any change to `apps/exchange-api`'s one working route.
- **Expected milestone**: a prerequisite to 0.3.x's Exchange-integration scope, not itself a 0.3.x deliverable.
- **Exit criteria**: `npm run build` succeeds with no `TS6053`/`TS5083` errors; `npm run test` runs all test files (not just the 19 that currently avoid the missing packages) with a real, current pass/fail count recorded.

This is offered as the most evidence-supported next step this specific audit surfaced — not a default continuation of WP-018 (already done) or a default jump to Exchange RC1 (which this audit found to rest on a broken foundation) or security remediation (which this audit did not newly substantiate as more urgent than the pre-existing, already-tracked ADR-0003/human-UX gates). The founder may reasonably choose differently — e.g., resolving ADR-0003 or running the human UX/UI acceptance test first, since both are also fully unblocked and arguably higher-value for 0.2.x specifically. This audit surfaces the evidence; it does not mandate the choice.

## 20. Final Decision

**These 8 commits are ready to become the next official baseline, as a Git operation.** They do not, by themselves, constitute "OEP 0.2.x" — that milestone requires ADR-0003's resolution and an executed (not merely prepared) human UX/UI acceptance test, both already correctly identified as open in the existing project-control documentation, both untouched by this audit's own findings. The Exchange `packages/*` gap is real, significant, and worth acting on soon, but it is independent of these 8 commits and does not, on its own, block pushing them.

**Founder's decision, framed as requested**: *"These commits are ready to become the next official baseline"* — yes, at the Git level. *"We need to fix these specific things first"* — only if the goal is to declare 0.2.x itself, in which case the two items above (not any defect in the 8 commits) are what remain.
