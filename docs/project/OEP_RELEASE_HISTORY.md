# OEP Release History

Canonical chronological release/implementation history for the Open Engineering Platform (OEP). See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) for current status and [`OEP_MILESTONE_ROADMAP.md`](OEP_MILESTONE_ROADMAP.md) for what comes next.

Last audited: 2026-09-13.

**This document distinguishes, at every entry, exactly which of these four categories it falls into**:

1. **GITHUB MAIN** — verified present on `origin/main`, the shared/pushed state.
2. **LOCAL / NOT PUSHED** — a real commit exists on this machine's local `main` branch, verified via `git log`, but has not been pushed to `origin/main`.
3. **LOCAL WORKING TREE** — uncommitted changes present in the working directory, not yet a commit at all.
4. **PROPOSED / FUTURE WORK** — not yet implemented in any form.

No entry in this document should be read as implying a commit is on GitHub main unless explicitly labeled GITHUB MAIN.

---

## Current GitHub main

Verified via `git log origin/main -1 --oneline` on 2026-09-13:

```
78ee8b0  Boot the Workspace to a real Home/Dashboard surface instead of empty
```

**This is the current, verified state of the shared repository.** Everything below this line, until explicitly marked GITHUB MAIN again in a future audit, is local-only.

---

## Local commits ahead of GitHub main (verified via `git rev-list --count origin/main..HEAD`; was 7 on the original 2026-09-13 audit, since grown as further local-only work landed the same day — see the entries below for each addition)

Listed oldest to newest (the order they'd be pushed in):

### PR-014 — Stabilize Diagram Studio WebView lifetime

**Status: LOCAL / NOT PUSHED.**
**Commit:** `1a97358`
**Message:** "PR-014: stabilize Diagram Studio WebView lifetime"

**Root cause found**: `DiagramWithComparePane` reconstructed/repositioned the primary `LegacyV2WebViewPage` through different conditional widget branches, causing the WebView to be recreated (and its expensive load/seed state lost) merely because a side panel's visibility changed.

**Fix**: the primary Legacy V2 WebView is now permanently mounted in one unconditional location in the widget tree, independent of Compare-pane visibility.

**Verified**: a Windows debug launch showed one CREATE / INIT / LOAD / SEED and no DISPOSE during the tested startup sequence (lifecycle instrumentation logging).

**Remaining**: human interactive validation is still required — this was verified via a single instrumented debug launch sequence, not via any automated lifecycle regression test. No automated lifecycle regression test suite exists for this behavior.

### PR-015 — Diagram Studio human UX/UI acceptance test system

**Status: LOCAL / NOT PUSHED.**
**Commit:** `8634276`
**Message:** "PR-015: add Diagram Studio human UX/UI acceptance test system"

Created:
- `platform/oep_studio/docs/testing/DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST.md`
- `platform/oep_studio/docs/testing/DIAGRAM-STUDIO-HUMAN-UX-UI-ACCEPTANCE-TEST-FORM.md`
- `platform/oep_studio/docs/testing/PRODUCT-READINESS-015-HUMAN-UX-UI-TEST-REPORT.md`

The human acceptance test itself has **not** been executed. Status is READY FOR HUMAN TEST, not PASSED.

### PR-016 — Prepare Diagram Studio human acceptance testing

**Status: LOCAL / NOT PUSHED.**
**Commit:** `5c231b5`
**Message:** "PR-016: prepare Diagram Studio human acceptance testing"

Created `platform/oep_studio/docs/testing/DIAGRAM-STUDIO-HUMAN-UX-UI-TESTER-START-GUIDE.md`.

### PR-016A — Interactive Diagram Studio human acceptance tester

**Status: LOCAL / NOT PUSHED.**
**Commit:** `84564de`
**Message:** "PR-016A: add interactive Diagram Studio human acceptance tester"

Created a standalone, interactive HTML acceptance-test tool (`diagram-studio-human-acceptance-test.html`) as a lighter-weight alternative to the markdown test form.

### Sidebar nav-order fix

**Status: LOCAL / NOT PUSHED.**
**Commit:** `bead021`
**Message:** "Fix HTML acceptance tester sidebar nav order (N between M and O)"

Small bugfix to the PR-016A HTML tool.

### WP-017 — EAM / Reference Vault Completion & M2 Readiness audit

**Status: LOCAL / NOT PUSHED.**
**Commit:** `8c6185c`
**Message:** "WP-017: EAM/Reference Vault implementation audit and hardening"

**Description**: a complete engineering audit and hardening pass of the Engineering Acquisition Manager (EAM) and Reference Vault implementation.

**Result: READY WITH CONDITIONS.**

**Findings**:
- HttpConnector performs real outbound HTTP, contradicting the documented WP-005/WP-006 "no real network communication" exclusion and README's own claims — SSRF-shaped gap, no host-allowlisting against the Official Source Registry. Documented in `services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md`, presenting three options; **not resolved**.
- Reference Vault publish orphan-file race (filesystem copy + DB insert not atomic) — **fixed**, with regression tests.
- `reference_vault`'s foreign keys were missing indexes — **fixed** via additive migration V9, with a regression test.
- Two test-fixture defects (non-idempotent scratch paths across process runs) — **fixed**, discovered by actually executing the suite twice.

**Test results, verified twice consecutively against real PostgreSQL 18**: 221/221 test cases, 981/981 assertions, 0 skipped, 0 failed.

### WP-018 — Acquisition Record & Provenance Foundation

**Status: LOCAL / NOT PUSHED.**
**Commit:** `0494e25`
**Message:** "WP-018: implement Acquisition Record and provenance foundation"

**Description**: implements the Acquisition Record entity WP-017 identified as the largest architecture-vs-implementation gap in EAM — a durable, queryable identity anchoring one acquisition event (keyed 1:1 on Download Session ID) across Source/Job/Execution/Download/Verification/Metadata/Vault, with a new `acquisition_records` table (additive migration V10) and a new `GET /acquisition-records/{id}/provenance` route reconstructing the full chain by traversal — zero changes to `DownloadService`, `IntegrityVerificationService`, `MetadataExtractionService`, `ReferenceVaultService`, or `reference_vault` itself.

**Test results, verified twice consecutively against real PostgreSQL 18**: 235/235 test cases, 1090/1090 assertions, 0 skipped, 0 failed (up from WP-017's 221/981 — 14 new test cases, 109 new assertions, all added by WP-018).

**Not implemented** (explicitly deferred): rich per-acquisition metadata (Workstation, DNS, TLS, Referrer/Redirect Chain, licensing), SHA-512/BLAKE3, a full chain-of-custody event log, the `Archived` lifecycle state. Full detail: `services/acquisition/docs/audits/ACQUISITION_RECORD_IMPLEMENTATION_AUDIT.md` and `WP-018-IMPLEMENTATION-REPORT.md`.

### Project-control documentation system

**Status: LOCAL / NOT PUSHED.**
**Commit:** `1474c0e`
**Message:** "Establish canonical OEP project-control, versioning & master status system"

Created this documentation hierarchy (`OEP_PROJECT_STATUS.md` and everything under `docs/project/`). No source code changed.

### OEP Release Boundary & Repository Integrity Audit

**Status: LOCAL / NOT PUSHED.**
**Commit:** `b44f860`
**Message:** "Add OEP release boundary & repository integrity audit"

Audited whether the 8 preceding local commits are ready to become the next baseline (yes, at the Git level — pure fast-forward, zero conflicts) and independently re-confirmed (by fetching the original `oep_exchange` upstream repository directly) that its `packages/*` workspace was deleted in that repository's own final commit before the monorepo migration ever touched it. Recommended a dedicated Exchange workspace-reconstruction work package. See `docs/project/audits/2026-09-13-OEP-RELEASE-BOUNDARY-AUDIT.md`. No source code changed.

### WP-EXC-011 — Exchange Workspace Reconstruction

**Status: LOCAL / NOT PUSHED.**
**Commit:** `55c4a4c`
**Message:** "WP-EXC-011: reconstruct Exchange workspace"

**Description**: restored all 14 documented `services/exchange/packages/*` workspace packages byte-for-byte from the last known good upstream commit (`18484e3`, before their undocumented deletion in that repository's own final commit `c6dbb75`). Removed one dangling workspace reference (`package_cli`, which never had any implementation in either repository's history). Result: `npm install`/`tsc -b`/lint all pass with zero errors; `apps/exchange-api` and `apps/exchange-admin` build and typecheck cleanly; 83 test files now execute (up from 19 before restoration). One confirmed, historically-unrecoverable gap remains: `apps/publisher-portal` depends on a real `@oep-exchange/exchange-client` implementation that was never committed anywhere (TASK-EXC-0007's own scope, never completed upstream) — 7 test files / 12 tests fail for this one diagnosed reason. This is Exchange RC1's workspace *foundation*, not Exchange RC1 itself, which remains not started.

---

## Uncommitted local working-tree changes (as of 2026-09-13, not yet committed)

**Status: LOCAL WORKING TREE, not even a commit.**

- `OEP_PROJECT_STATUS.md`, `docs/project/` (this documentation system) — the work this very audit produced.
- `platform/oep_instruments/platform/oep_instruments/build/test_cache/build/*.cache.dill.track.dill` — a pre-existing, unrelated build-cache artifact modification; not part of any documentation or feature work, left untouched.
- `platform/oep_studio/docs/testing/.~lock.DIAGRAM-STUDIO-HUMAN-UX-UI-TESTER-START-GUIDE.md#` — a LibreOffice lock file, pre-existing, unrelated; left untouched.

---

## Proposed / future work (PROPOSED — not yet implemented in any form)

- **WP-EXC-010** — Exchange RC1 plus OEP Studio integration. Priority: CRITICAL, per Exchange's own program planning. See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) Section 12.
- **ADR-0003 resolution** — a decision (not new code by default) on HttpConnector's scope/SSRF posture, one of three options already documented in `services/acquisition/docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md`.
- **Diagram Studio human UX/UI acceptance test execution** — infrastructure exists (PR-015/016/016A), the test itself has not been run.
- **Broader EAM M2** — rich per-acquisition provenance metadata, connector security policy, custody events (all classified FUTURE/DEFERRED in the WP-018 audit, pending upstream producers that do not exist yet).

---

## Superseded / historical status documents

The following documents predate this canonical documentation system and are retained for historical/subsystem context. Each has been annotated with a supersession notice pointing back to [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md):

- `platform/oep_foundation/PROJECT_STATUS.md`
- `platform/oep_foundation/CURRENT_SPRINT.md`
- `platform/oep_foundation/docs/review/FINAL_RECOMMENDATION.md`
- `platform/oep_foundation/docs/review/PLATFORM_SNAPSHOT.md`
- `platform/oep_foundation/docs/review/TECHNICAL_DEBT.md`

See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) Section 16 for why the credential-exposure claim in the three `docs/review/` documents above is treated as documentation drift rather than a corroborated current finding.
