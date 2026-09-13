# OEP Milestone Roadmap

Canonical future milestone plan for the Open Engineering Platform (OEP). See [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) for current verified status, [`OEP_VERSIONING_POLICY.md`](OEP_VERSIONING_POLICY.md) for the versioning rules this roadmap's version numbers follow, and [`OEP_RELEASE_HISTORY.md`](OEP_RELEASE_HISTORY.md) for what has actually happened so far.

Last audited: 2026-09-13.

**No milestone below is claimed complete unless its Exit Criteria are explicitly checked off with repository evidence cited.** An unchecked exit criterion means the milestone has not been reached, regardless of how much related work exists.

---

## M0 / 0.1.x — Foundation and architectural establishment

**Status: substantially reached (current state).**

**Objective**: establish the platform's core architecture — Foundation runtime, Public C API, EKE, Engineering Engine, Studio shell, Diagram Studio vertical slice, Engineering Acquisition M1, Knowledge Runtime core — as independently working pieces, without requiring them to be release-integrated or production-hardened yet.

**Major included subsystems**: Foundation Repository Runtime (WP-REP-001–008), Public C API (currently version 21), EKE (WP-EKE-001–008, internal v1.0 freeze), Engineering Engine, Studio shell, Diagram Studio (through PR-016A), Electrical Runtime, DMM, Trace, Circuit Intelligence/Search foundations, Knowledge Runtime/Reference Library, EAM M1 (WP-001–009), Reference Vault M1, Acquisition Record foundation (WP-018), OEP Instruments/OIP foundation, Exchange skeleton.

**Major exclusions**: Exchange RC1, production security hardening, performance baselines, cross-platform release validation, human UX/UI acceptance sign-off, ADR-0003 resolution.

**Entry criteria**: none — this is the starting state.

**Exit criteria** (all must show repository evidence; see [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) for the evidence behind each):
- [x] Foundation Repository Runtime implemented (WP-REP-001–008)
- [x] Public C API reaches a stable-enough surface for Studio to build against (API 21)
- [x] EKE reaches its internal v1.0 architecture freeze
- [x] Engineering Engine package exists and Diagram Studio builds against it
- [x] Diagram Studio reaches a functional vertical slice (workspace, electrical runtime, DMM, Trace, Search, Export)
- [x] EAM M1 (WP-001–009) implemented and tested
- [x] Knowledge Runtime core path (Reference Library → `.oerp` → Studio) implemented and tested
- [ ] Human UX/UI acceptance of the Diagram Studio vertical slice (READY FOR HUMAN TEST, not yet executed)
- [ ] ADR-0003 resolved

**Known blockers**: none blocking M0 itself — the remaining unchecked items above are the actual bridge into M1/0.2.x, not blockers on M0's own substantially-reached state.

**Release confidence**: HIGH that the architectural foundation itself is sound; the unchecked items above are exactly what M1/0.2.x exists to close.

---

## M1 / 0.2.x — Integrated Engineering Platform Foundation

**Status: NOT REACHED.** This is the next release target, defined explicitly as "a coherent, internally consistent, testable foundation," **not feature completeness**.

**Objective**: move OEP from "several independently-working pieces" (M0) to "one coherent, integrated platform foundation" — resolving the cross-cutting gaps that don't belong to any single subsystem (version/release identity, documentation coherence, security baseline for known issues, human acceptance of the flagship vertical slice).

**Major included subsystems**: everything from M0, integrated — plus the explicit exit gates below, which are cross-cutting rather than subsystem-local.

**Major exclusions**: Exchange RC1 (Exchange only needs to reach a documented "basic foundation" state for 0.2.0, not RC1), broader EAM M2 (rich provenance metadata, connector security policy beyond ADR-0003's own resolution, custody events), feature-complete beta scope (0.5.x), performance/security production hardening beyond the specific gates below.

**Entry criteria**: M0's exit criteria substantially met (they are, per above).

**Exit criteria**:
- [ ] Credible, canonical project/version control established (this documentation system — `OEP_PROJECT_STATUS.md`, this roadmap, the versioning policy, the release history, and the master audit — is the mechanism; it must additionally be kept up to date going forward, not merely created once)
- [ ] Resolved release-blocking security issues:
  - [ ] ADR-0003 (HttpConnector scope/SSRF) resolved
  - [ ] Credential-exposure claim (see [`OEP_PROJECT_STATUS.md`](../../OEP_PROJECT_STATUS.md) Section 16) personally confirmed closed by the founder
- [ ] Diagram Studio human UX/UI acceptance test executed (using `samples/diagram7.json`, a release build) — currently READY FOR HUMAN TEST, not PASSED
- [x] Foundation runtime, EKE, Engineering Engine, Studio, Diagram Studio vertical slice, electrical runtime, DMM, Trace, basic Circuit Intelligence/Search, application shell, Reference Library/Knowledge Runtime, EAM M1, Reference Vault M1, basic Exchange foundation — all present with evidence (see `OEP_PROJECT_STATUS.md`)
- [ ] Documented architecture boundaries reconciled (stale `PROJECT_STATUS.md`/`CURRENT_SPRINT.md` superseded, API 19/20 references identified as historical — in progress via this same documentation task, see Section 26 of this repository's stale-document handling)
- [ ] Local commits (PR-014 through WP-018) merged to GitHub main, or an explicit decision recorded for why not yet

**Known blockers**: ADR-0003 resolution requires a human/architectural decision this documentation task cannot make on its own; human UX/UI acceptance requires an actual human tester session.

**Release confidence**: MEDIUM — the remaining gates are well-understood and mostly project-control/decision work rather than undiscovered engineering, but none are complete yet.

---

## M2 / 0.3.x — Acquisition/provenance/Exchange/knowledge lifecycle integration

**Status: PARTIALLY STARTED.** The Acquisition Record foundation (WP-018) that this milestone was originally going to require has already been implemented (LOCAL / NOT PUSHED, commit `0494e25`) — ahead of M1/0.2.x formally closing, since it was independently scoped and audited as its own work package. This does not mean M2 as a whole is reached; the rest of its scope (below) is untouched.

**Objective**: the next major integration expansion — richer Acquisition/provenance capability, Exchange integration, deeper Studio integration, and Knowledge Lifecycle expansion, plus continued security hardening and the beginning of real performance measurement.

**Major included subsystems**: EAM M2 broader scope (rich per-acquisition metadata, connector security policy, custody events — all currently classified FUTURE/DEFERRED per the WP-018 audit), Exchange integration (WP-EXC-010 and associated Exchange work), deeper Studio↔Engine integration (closing FFI mutation gaps), Knowledge ingestion/provenance/candidate-review boundary maturity, broader security hardening, initial performance measurement.

**Major exclusions**: feature-complete beta scope (0.5.x), full production hardening (0.6.x–0.8.x), release-candidate stabilization (0.9.x).

**Entry criteria**: M1/0.2.x's exit criteria met (not yet the case — see above).

**Exit criteria**:
- [x] Acquisition Record foundation implemented (WP-018 — LOCAL / NOT PUSHED)
- [ ] Rich per-acquisition provenance metadata (Workstation, DNS, TLS, Referrer/Redirect Chain) — requires upstream connector producers that do not exist yet
- [ ] Exchange RC1 and Studio integration (WP-EXC-010)
- [ ] Chain-of-custody event log, if still judged necessary once `acquisition_job_execution_history`'s existing coverage is reassessed
- [ ] Security hardening beyond ADR-0003's own resolution
- [ ] Initial, real performance measurement (not yet a full baseline — that is 0.6.x–0.8.x's scope)

**Known blockers**: Exchange RC1 is a large, currently-early-foundation-stage program (see `OEP_PROJECT_STATUS.md` Section 12); rich provenance metadata is blocked on connector work that itself depends on ADR-0003's resolution.

**Release confidence**: LOW-MEDIUM — this milestone has barely begun outside the Acquisition Record foundation.

---

## Beta expansion — 0.4.x

**Status: NOT STARTED.**

**Objective**: broader integrated beta expansion — wider validation, broader user-facing capability, without yet requiring feature completeness.

**Major exclusions**: anything not already reached by 0.3.x.

**Entry criteria**: 0.3.x exit criteria met.

**Exit criteria**: to be defined in detail once 0.3.x is underway — recorded here as a placeholder milestone per the requested roadmap structure, not yet elaborated with specific gates, since doing so before 0.3.x's own shape is known would be speculative.

**Known blockers**: depends entirely on 0.2.x/0.3.x completion.

**Release confidence**: N/A — too early to assess.

---

## Feature-complete beta — 0.5.x

**Status: NOT STARTED.**

**Objective**: the feature-complete beta target — every planned OEP capability exists in at least a usable form, even if not yet production-hardened.

**Entry criteria**: 0.4.x exit criteria met.

**Exit criteria**: to be defined in detail once 0.4.x is underway.

**Known blockers**: depends entirely on prior milestones.

**Release confidence**: N/A — too early to assess.

---

## Hardening/integration — 0.6.x–0.8.x

**Status: NOT STARTED.**

**Objective**: integration, ecosystem, reliability, performance, and production hardening across the whole feature-complete beta surface.

**Entry criteria**: 0.5.x exit criteria met.

**Exit criteria**: a real, established performance baseline; a completed security audit; cross-platform validation; ecosystem (Exchange) readiness — to be elaborated in detail once 0.5.x is reached.

**Known blockers**: depends entirely on prior milestones.

**Release confidence**: N/A — too early to assess.

---

## RC — 0.9.x

**Status: NOT STARTED.**

**Objective**: release candidate stabilization — no new capability, only defect closure and release-readiness verification against the full 1.0.0 gate list (see [`OEP_VERSIONING_POLICY.md`](OEP_VERSIONING_POLICY.md) Section 4).

**Entry criteria**: 0.6.x–0.8.x exit criteria met.

**Exit criteria**: every 1.0.0 gate verifiable, pending only final sign-off.

**Known blockers**: depends entirely on prior milestones.

**Release confidence**: N/A — too early to assess.

---

## Stable — 1.0.0

**Status: NOT STARTED.**

**Objective**: a stable, supported engineering platform. See [`OEP_VERSIONING_POLICY.md`](OEP_VERSIONING_POLICY.md) Section 4 for the full gate list (stable public APIs, documented compatibility policy, stable package/protocol formats, release reproducibility, security baseline, performance baseline, appropriate test coverage, migration/update strategy, documentation completeness, cross-platform validation, reliable installation, recovery/error behavior, operational supportability, ecosystem readiness).

**Entry criteria**: 0.9.x RC gates all verified.

**Known blockers**: everything above this milestone.

**Release confidence**: N/A — this is the terminal target of the entire roadmap, not a near-term assessment.
