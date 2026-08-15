# DOCUMENTATION_AUDIT.md

## Inventory

- **`oep_foundation/` root**: `README.md`, `TASK.md`, `CURRENT_SPRINT.md`, `PROJECT_STATUS.md`, `CLAUDE.md`, `PROJECT_MEMORY.md`, `CHANGELOG.md`, `CONTRIBUTING.md`.
- **`docs/architecture/`** — the 8 frozen v1.0 documents (Constitution, Architecture, Public API Specification, Integration/Performance/Validation Reports, Known Issues, Future Roadmap v2). All 8 present as named.
- **`docs/tasks/`** — 19 work-package spec files across 3 incompatible numbering schemes (see below).
- **`specifications/`** — a SECOND, separate architecture/spec tree (`adr/`, `architecture/` OEP-ARCH-001/002, `platform/` OEP-SPEC-001 through 022, `standards/` OEP-STD-001–005). Coexists with `docs/architecture/` without an explicit document explaining how the two relate.
- **Per-module `README.md`** — present for all 16 directories under `platform/`, including the 6 empty stub modules (whose README is their only content).
- Sibling repositories (`oep_studio`, `oep_engine`, `oep_acquisition`, `oep_architecture`, `oep_exchange`, `oep_reference`, `engine_reference_only`) each maintain their own separate `docs/` trees, not indexed from `oep_foundation`.

## Missing documents
No subsystem under `oep_foundation/platform/` lacks documentation entirely — every module has at least a README. The gap is not absence but **inconsistency between documents that do exist** (see below) and the **lack of any index reconciling `docs/architecture/`, `docs/tasks/`, and `specifications/`** into one coherent map of "where do I look for X."

## Outdated documents
- **`PROJECT_STATUS.md` is severely outdated.** It describes `Current Milestone: Foundation Drop 001`, `Sprint 001 — OEP CLI Foundation`, with "Out of Scope: Repository engine, Runtime, SDK, Exchange, Studios, Plugins, Networking, Authentication" — a description of the project's very first sprint, despite a header claim of "Architecture Status: FROZEN" (which would only make sense post-v1.0). This file appears to have never been updated past initial bootstrap.
- **`CURRENT_SPRINT.md` is internally self-contradictory**, not merely outdated: its header states `Sprint: WP-EKE-005`, its body's first "Sprint Name" section describes an unrelated "Repository Templates & Batch Operations (Work Package 010)" sprint, and its later sections (confirmed in this session) correctly describe WP-EKE-008. Three different work packages are represented in one file with no clear indication of which section is current.

## Conflicting documents
- **Root status docs conflict with each other outright**: `TASK.md` says WP-EKE-008/v1.0 complete; `CURRENT_SPRINT.md`'s header says WP-EKE-005; `PROJECT_STATUS.md` says Sprint 001; `README.md` says "Foundation v1.0 / Active Development" — a fourth, vaguer characterization matching none of the other three precisely. **A reader consulting these four files in sequence would receive four different pictures of project maturity.** `TASK.md` and `docs/architecture/*` (verified cross-consistent with each other and with the actual `OEP_API_VERSION` in code) are the reliable sources; the other two should be brought into line or explicitly marked historical.
- **Numbering-scheme conflict in `docs/tasks/`**: `WORK_PACKAGE_012–014.md` (bare numeric IDs, no visible 001–011 predecessors), `WP-REP-001..008.md`, `WP-EKE-001..008.md` — three schemes, no index, no explanation of the transition or of what happened to `WORK_PACKAGE_001–011`.

## Duplicate documents
- **`oep_studio/docs/tasks/` contains ~12 duplicate-looking file pairs** for WP-STUDIO-021 through WP-STUDIO-032 — a title-cased space-separated filename and a canonical uppercase-underscore filename for the same work package (e.g. `WP-STUDIO-021 Studio Registry Framework.md` and `WP-STUDIO-021-STUDIO_REGISTRY_FRAMEWORK.md`), plus one misspelled filename (`WORK_PAGKAGE_002.md`). This should be reconciled — determine which is canonical and remove the other, or confirm they're genuinely different content and rename to disambiguate.

## Architecture drift
None found **within** the 8 frozen `docs/architecture/` documents — they are internally consistent with each other and with the code (spot-checked: `OEP_API_VERSION 19` / `OEP_ABI_VERSION 1` claims match the actual header exactly). Drift exists **between** the frozen architecture set and the root status docs (`PROJECT_STATUS.md` in particular describes a pre-Repository-engine state that flatly contradicts the frozen architecture's existence).

## Roadmap drift
`docs/tasks/` documents an incomplete roadmap history — the `WORK_PACKAGE_012–014` mini-series exists with no visible predecessor work packages 001–011, meaning either those were done outside this directory, never existed under that scheme, or were lost/renamed at some point without a record. This is a real gap in the project's documented history, not merely a formatting inconsistency.

## Specification drift
The coexistence of `docs/architecture/` (WP-EKE-008's frozen output) and `specifications/` (a pre-existing, separately-maintained OEP-SPEC/OEP-ARCH/OEP-STD numbered series) was not found to directly contradict each other in the portions sampled, but neither document set references the other, so it is not possible to confirm they stay synchronized as either evolves. This is a structural risk (two sources of truth with no cross-linking) rather than a confirmed conflict today.

## Recommendations
1. Rewrite `PROJECT_STATUS.md` from scratch to reflect actual current state, or retire it in favor of `TASK.md` + `docs/architecture/` as the canonical status sources.
2. Fix or clearly section-date `CURRENT_SPRINT.md` so its header and body agree, and old sprint sections are visually distinguished from the current one (e.g. move history to an archive file).
3. Create one `docs/tasks/INDEX.md` reconciling the three numbering schemes and explaining what, if anything, happened to `WORK_PACKAGE_001–011`.
4. Reconcile the ~12 duplicate `oep_studio/docs/tasks/WP-STUDIO-0NN` file pairs and fix the misspelled filename.
5. Add a short cross-reference note in both `docs/architecture/` and `specifications/` explaining how the two relate (one supersedes the other? complementary scopes? historical vs. current?).
