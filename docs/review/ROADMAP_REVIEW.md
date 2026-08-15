# ROADMAP_REVIEW.md

## What is complete

- **Foundation Repository Runtime**, WP-REP-001 through WP-REP-008: package install, registry, transactions, trust/signing, dependency resolution, `RuntimeService` orchestration, uninstall/update, merge engine. All 8 packages verified built, tested, and documented; no gaps found beyond the pre-existing, never-in-scope stub modules (authentication/filesystem/licensing/logging/telemetry).
- **Engineering Knowledge Engine**, WP-EKE-001 through WP-EKE-008: the 8-layer engine stack plus the v1.0 integration/optimization/freeze package. Verified complete against its own exit criteria, with two disclosed gaps (GraphML export placeholder; shallow Studio-side test depth) that do not block the freeze but should be tracked, not forgotten.
- **A separate, earlier, undocumented mini-series**: `docs/tasks/WORK_PACKAGE_012.md` through `014.md` — Public API exposure work (repository contents, relationships/search, object/relationship mutation) that predates the WP-REP series and has no visible 001–011 predecessors in this repository. These were evidently completed (their functionality is present in the current C API) but are not part of either frozen v1.0 narrative and are not indexed anywhere that explains their relationship to WP-REP-001 onward.

## What remains

1. **Studio integration depth.** The 8 new Engineering Intelligence pages are read-only and smoke-tested only. If Studio is meant to be a real consumption surface (not just a demonstration that the wiring works), a follow-up pass adding genuine interaction tests and closing the FFI mutation gap (object/relationship update/delete, batch-create) is real, not yet scheduled, work.
2. **GraphML export.** Currently a self-documented placeholder shipped as a stable, versioned public C API function. Either finish it or explicitly re-scope it out of v1.0 in the public specification — leaving it as-is inside a "frozen" API is the one place this session's freeze claim is weaker than it states.
3. **The five never-started Foundation stub modules** (authentication, filesystem, licensing, logging, telemetry) and the stale `transactions` placeholder directory. These were out of scope for both v1.0 efforts, but they are visible in the module list and will eventually need either real implementation or formal removal from the tree — leaving empty READMEs indefinitely is itself a form of debt.
4. **`AnalysisEngine`'s missing dedicated test file** — a real gap in an otherwise fully-tested engine; cheap to close, currently untracked as its own item.
5. **Documentation reconciliation** — `PROJECT_STATUS.md` is severely stale (describes Sprint 001) and `CURRENT_SPRINT.md` is internally self-contradictory (header claims WP-EKE-005, body describes an unrelated earlier sprint). Both should be fixed before onboarding anyone new to the project, or before further work packages compound the drift.
6. **`docs/tasks/` numbering hygiene** — three incompatible ID schemes (`WORK_PACKAGE_NNN`, `WP-REP-NNN`, `WP-EKE-NNN`) coexist with no index explaining the transition, and an unexplained 11-item gap in the oldest scheme. Low urgency, but will actively confuse anyone auditing history the way this review just did.

## Whether priorities should change

Given the two backend architectures (Foundation Runtime, Engineering Knowledge Engine) are now genuinely frozen and stable, and given the applications this platform exists to enable (Engineering Acquisition, Exchange, Explorer, Diagram Studio, Diagnostic Studio, Engineering AI) all currently sit downstream of a Studio layer that is itself unevenly built — **the highest-leverage next priority is not a new backend engine, and not immediately jumping to a new flagship application, but closing the specific, named Studio/API gaps above first.** Building a new application studio on top of an FFI layer that cannot update or delete objects, or on top of a Studio codebase where roughly half the visible surface is a placeholder, would compound today's debt into tomorrow's foundation. This is a recommendation, not a certainty — see `FINAL_RECOMMENDATION.md` for the fuller argument.

## Whether work packages should be merged, split, or reordered

- **Split**: any future "Studio Integration" work package should be split from its accompanying backend work package the way WP-EKE-008 implicitly discovered it needed to be (the Studio UI agent ran as a genuinely separate effort from the C++ engine work). Bundling "build the engine" and "build the UI for the engine" into one work package, as the earlier WP-EKE-001 through 007 packages did (each explicitly deferring UI), created a large UI backlog that then had to be paid off in one oversized WP-EKE-008. A steadier cadence — UI work shipped closer to each engine layer, rather than deferred 7 times and then batched — would likely have caught the FFI mutation gap and the placeholder density earlier.
- **Merge candidate**: the undocumented `WORK_PACKAGE_012–014` mini-series should be formally folded into the WP-REP or WP-EKE narrative (whichever it actually preceded) so the project has one continuous, explainable history rather than three disconnected numbering schemes.
- **Reorder**: promote "close the FFI mutation gap" and "resolve the GraphML placeholder" to their own small, explicitly-scoped work packages ahead of any new application-studio work package, given both are concrete, bounded, and currently invisible in the roadmap.

## Recommendations

1. Do not start a new major engine or application program before running one focused "v1.0.1 cleanup" work package: FFI mutation bindings, GraphML export resolution or re-scoping, `AnalysisEngine` test coverage, and documentation reconciliation (`PROJECT_STATUS.md`/`CURRENT_SPRINT.md`).
2. Formally decide the fate of the 6 empty Foundation stub modules — implement, defer with an explicit roadmap entry, or delete the placeholder directories. Their current state (present but empty, unindexed) is itself a maintenance cost.
3. Establish one `docs/tasks/INDEX.md` reconciling all three numbering schemes before adding a fourth for whatever program comes next.
4. Treat Studio UI work as a per-layer deliverable going forward, not a batched catch-up package, to avoid repeating WP-EKE-008's UI backlog pattern.
