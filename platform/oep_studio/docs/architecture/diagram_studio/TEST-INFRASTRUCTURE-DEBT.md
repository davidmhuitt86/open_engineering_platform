# Test Infrastructure Debt Register

PRODUCT-READINESS-011 §22. Tracks every currently-known flaky test relevant
to the PR-005 through PR-011 series. Each entry below reflects an ACTUAL
re-run investigation performed during PRODUCT-READINESS-011 (isolated runs
plus at least one full-suite run), not an assumption carried forward from
an earlier report.

## Investigation method

For each of the five failures PR-010 disclosed, this pass:
1. Ran the file in isolation 3 times back-to-back.
2. Ran the entire `oep_studio` `flutter test` suite once (1,141 total
   tests) and recorded whether the file failed as part of that run.

## Findings

### `test/diagram_studio/bridge/diagram_repository_commit_action_test.dart`
— test case `11/persistence. commit persists the updated DiagramDocument
(AP-OEP-DIAGRAM-REPOSITORY-001) full continuity: commit -> persisted save
-> reopen recovers diagramRepositoryId, without re-enumerating`

- **Observed failure**: intermittent `expect` failure comparing
  `reopenedGraph.diagramRepositoryId`/`repositoryObjectId` after a real
  `DiagramDocument().open(path)` reopen.
- **Reproduces in isolation**: YES — failed 1 of 3 isolated runs, and
  failed again in the subsequent full-suite run (2 failures across 4
  observed attempts this session).
- **Deterministic**: NO.
- **Root cause (confirmed by reading the test, `:402-439`)**: the test
  performs a real disk write (`document.saveAs`), a real commit action via
  a real tapped button, then a **fixed** `tester.pump(const
  Duration(milliseconds: 50))` as its only synchronization before
  re-reading the file back from disk with a fresh `DiagramDocument().open`.
  50ms is not a deterministic upper bound on real disk I/O completion under
  system load — this is a classic bounded-sleep race, not an application
  defect.
- **Touches production code**: NO — the race is entirely inside the test's
  own synchronization, not in `DiagramDocument`/`EngineHost`/the commit
  action itself (all of which behave identically on the passing runs).
- **Classification**: **TEST INFRASTRUCTURE FLAKE** (confirmed by
  investigation, not merely asserted).
- **Recommended remediation**: replace the fixed 50ms `pump` with a
  deterministic wait — poll for the commit action's own completion signal
  (e.g., the button state transitioning away from "Commit Diagram to
  Repository", or an explicit `Future` returned by the commit path awaited
  directly inside `tester.runAsync`) rather than a bounded sleep.
- **Current status**: OPEN. Not fixed this pass (out of PRODUCT-READINESS-011's
  scope — the offending file is a PR-009-era Repository Bridge test, and
  this phase's mandate is additive Windows E2E infrastructure, not
  retrofitting earlier tests). Documented per §22/§23 rather than silently
  ignored.

### `test/diagram_studio/tabs/diagram_tabs_controller_test.dart`
- **Observed failure (PR-010)**: reported ×2 failures.
- **Reproduces in isolation**: NO — passed 14/14 in all 3 isolated runs.
- **Reproduces in full suite**: NO — passed 14/14 in the full-suite run.
- **Deterministic**: could not be determined; failure not reproduced this
  session (0 of 4 attempts).
- **Touches production code**: N/A (not reproduced).
- **Classification**: **TEST INFRASTRUCTURE FLAKE (unreproduced this
  session)** — retained in this register rather than removed, since a
  failure PR-010 genuinely observed is not disproven by a later session's
  clean runs; environment/timing-sensitive flakes can be intermittent
  across sessions, not just within one.
- **Recommended remediation**: none actionable without a reproduction;
  re-run under load (parallel test execution, CI-equivalent machine
  pressure) if it resurfaces.
- **Current status**: MONITOR.

### `test/settings_service_test.dart`
- **Observed failure (PR-010)**: reported ×2 failures.
- **Reproduces in isolation**: NO — passed 8/8 in all 3 isolated runs.
- **Reproduces in full suite**: NO — passed 8/8 in the full-suite run.
- **Deterministic**: could not be determined; failure not reproduced this
  session (0 of 4 attempts).
- **Touches production code**: N/A (not reproduced).
- **Classification**: **TEST INFRASTRUCTURE FLAKE (unreproduced this
  session)** — same reasoning as above.
- **Recommended remediation**: none actionable without a reproduction.
- **Current status**: MONITOR.

## Full-suite result this pass

1,132 passed, 8 skipped (pre-existing, unrelated to this register), 1
failed (`diagram_repository_commit_action_test.dart`'s "full continuity"
case, documented above) — total 1,141 tests. No other file failed.

## What this register is NOT

This register does not classify anything as `PRODUCT FAILURE` or
`ENVIRONMENT FAILURE` — no finding this session met that bar. If a future
investigation reproduces a `PRODUCT FAILURE` in any of the above (i.e., the
application itself, not the test's own synchronization, is wrong), this
document must be updated to say so explicitly, and the underlying defect
fixed outside of "test debt."
