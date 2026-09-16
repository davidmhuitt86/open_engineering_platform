# AP-UX-004 — Target UX Architecture Completion

## 1. Status

**Status:** Active target UX architecture — design-only completion pass. This document does not authorize, describe, or record any Flutter implementation change.

**Baseline:** `deb4eccb79456593a30a7d2bd7281a4d4251d18b` (post `AP-UX-003-DESIGN-TO-CODE-INSPECTION.md`).

**Relationship to prior work:** `docs/architecture/ux/` is the active target UX architecture, still being designed. The shipped Flutter implementation (`AP-OEP-WORKSPACE-AS-PRIMARY-UI-001`, inspected in `AP-UX-003-DESIGN-TO-CODE-INSPECTION.md`) is an **implementation baseline** the target will eventually migrate toward — not a competing architecture, and not a choice the design owner is being asked to make between "current" and "future." This document does not ask that question and does not redesign the active UX from scratch; it completes gaps and contradictions that AP-UX-001/002/003 identified but did not close.

## 2. Mission

Finish the active UX architecture sufficiently that implementation can eventually proceed against a complete, internally consistent design. This means: close remaining structural gaps in the target shell/navigation model, classify the completeness of every major design area, define what has not yet been defined (responsive behavior, design-to-code contract template), and separate what is genuinely finished from what still requires a render, a decision, or further work — without inventing content that has no basis in the existing corpus or in an explicit design-owner decision made in this session.

## 3. Current Implementation vs. Target Design

No new inspection was performed for this section; it restates the AP-UX-003 finding as load-bearing context for every section below. The shipped application (`StudioShell` → `EngineeringWorkspacePage`) has no persistent Application Header, Global Studio Bar, Toolbar, Inspector region, or Status Bar — only a single 36px workspace tab strip whose "+" menu is the entire navigation surface. The target architecture defined in this directory is an 8-region shell (Header, Studio Bar, Workspace Bar, Context Nav, Toolbar, Engineering Surface, Inspector, Status Bar) that does not yet exist in code. This gap is expected and is not evidence of a design defect; it is the reason this document exists.

## 4. Active UX Corpus (as of this baseline)

Canonical: `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md`, `OEP-UX-ARCHITECTURE.md`, `design-system/OEP-DESIGN-TOKENS.md`, `design-system/OEP-SHELL-COMPONENTS.md`, `design-system/OEP-UI-RULES.md`, `OEP_UX_RENDER_REFERENCE_INDEX.md`, `eam/EAM-ACQUISITION-WORKSPACE-SPEC.md`, `eam/EAM-INTERACTION-STATE-SPEC.md`.

Supplementary (additive, not superseded): `01_OEP_SHELL_UX_DESIGN_SPEC.md`, `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`, `OEP_CONTEXTUAL_CAPABILITY_SPEC.md`, `OEP_HOME_UX_SPEC.md`, `OEP_STUDIO_TAB_WORKSPACE_SPEC.md`, `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`, `SECTION-8-STATUS-BAR-SPEC.md`, `implementation/DS-GOLDEN-WORKSPACE-SPEC.md`, `eam/EAM_ACQUISITION_WORKFLOW_SPEC.md`, `eam/EAM_INFORMATION_ARCHITECTURE.md`, `eam/EAM_POST_ACQUISITION_UX_FLOW.md`, `eam/EAM_WORKSPACE_SCREEN_SPEC.md`.

Historical/migration reference only: `eam/02_EAM_ACQUISITION_WORKSPACE_SPEC.md`, `eam/EAM_INTERACTION_STATE_SPEC.md`.

Audit trail (not itself design authority): `AP-UX-001-UX-DESIGN-RECOVERY.md`, `AP-UX-003-DESIGN-TO-CODE-INSPECTION.md`.

## 5. Design-Owner Decision Recorded in This Work Package

**Question (carried open from AP-UX-002 C7 / AP-UX-003 / this document's own §11 evidence gathering):** does "Engineering Intelligence" remain a distinct entry in the Global Studio Bar?

**Decision (design owner, this session):** No. Engineering Intelligence is **not** a Global Studio. It is an underlying OEP intelligence/platform capability consumed by Studios and contextual workflows — an internal OEP Engine capability, not a top-level navigation destination.

**Effect on the corpus:** `OEP-UX-ARCHITECTURE.md` (Studio Bar list), `design-system/OEP-SHELL-COMPONENTS.md` ("may include... Engineering Intelligence"), and `OEP_HOME_UX_SPEC.md` (§ Available Studios example) each named Engineering Intelligence as a Studio; this decision supersedes those specific references without altering anything else those documents say. The current Flutter `engineeringIntelligence` `StudioDestination` (AP-UX-003 evidence) is implementation-baseline reality, not target-design authority — it is the kind of divergence AP-UX-003 catalogued as expected, not a reason to keep the entry. This resolves the item; it is removed from the "unresolved" list for the remainder of this document, and the 7-entry Studio Bar (Home, Diagram Studio, EAM, Knowledge Studio, Engineering Exchange, Tools, Settings) established by the newer-generation render/toolbar-matrix is confirmed as the target Studio Inventory, matching what AP-UX-002 already reconciled for Instruments→Tools.

## 6. Completion Inventory

Classification key: COMPLETE / PARTIALLY COMPLETE / DESIGNED BUT UNRENDERED / RENDERED BUT NOT SPECIFIED / CONCEPTUAL / UNRESOLVED / NOT YET DESIGNED.

| # | Area | Classification | Basis |
|---|---|---|---|
| 1 | Application Header | COMPLETE | Geometry (58px), content rules in `OEP-SHELL-COMPONENTS.md`; render `App Header with OEP Logo.png` |
| 2 | Global Studio Bar structure | COMPLETE | Geometry (56px), per-Studio accent tokens (AP-UX-002 §2A); render `studio tab bar use option 3.png` |
| 3 | Global Studio Bar inventory | COMPLETE (this document) | §5/§11 — resolved to 7 entries this session |
| 4 | Workspace Bar | COMPLETE | Geometry (42px), tab model in `OEP_STUDIO_TAB_WORKSPACE_SPEC.md`; render `workspace context tab bar.png` |
| 5 | Context Navigation region | PARTIALLY COMPLETE | Behavioral rules in `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`; no dedicated render isolates this region alone (only visible inside composite renders) |
| 6 | Toolbar | COMPLETE | Geometry (60px, full-width row below 3-column split — AP-UX-002 C2), action matrix in `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`; render `toolbar 7 use option 3.png` |
| 7 | Engineering Surface (generic contract) | CONCEPTUAL | `OEP-UX-ARCHITECTURE.md` defines it as Studio-owned content area; no generic-level render exists (by design — it is Studio-specific) |
| 8 | Inspector region | PARTIALLY COMPLETE | Named and bounded in `OEP-SHELL-COMPONENTS.md` and `DS-GOLDEN-WORKSPACE-SPEC.md` §3; no dedicated inspector-content render exists |
| 9 | Status Bar | COMPLETE | Geometry (36px), content in `SECTION-8-STATUS-BAR-SPEC.md`; render `Status bar use option 2.png` |
| 10 | Accent color model | COMPLETE | AP-UX-002 §2A/C1, design-owner decision recorded |
| 11 | Shell geometry (all 5 regions) | COMPLETE | AP-UX-002 §3/C2 |
| 12 | Design tokens (color/typography) | COMPLETE | `OEP-DESIGN-TOKENS.md` |
| 13 | Design tokens (geometry) | COMPLETE | `OEP-DESIGN-TOKENS.md` §3, corrected by AP-UX-002 |
| 14 | Navigation hierarchy (OEP→Studio→Workspace→Context→Object) | COMPLETE | `OEP-UX-ARCHITECTURE.md`, `README.md` |
| 15 | Destination-vs-capability rule | COMPLETE | `OEP-UX-ARCHITECTURE.md`, `OEP_CONTEXTUAL_CAPABILITY_SPEC.md` |
| 16 | Home | COMPLETE | `OEP_HOME_UX_SPEC.md`; render `oep-home/home.png` |
| 17 | Diagram Studio shell-integration render | DESIGNED BUT UNRENDERED | `DS-GOLDEN-WORKSPACE-SPEC.md` fully specifies target regions/behavior; no render exists showing Diagram Studio inside the full 8-region shell (confirmed again this session, §13 below) |
| 18 | EAM workflow/workspace/interaction | COMPLETE | `eam/EAM-ACQUISITION-WORKSPACE-SPEC.md`, `eam/EAM-INTERACTION-STATE-SPEC.md` + 4 supplementary docs; render `eam/EAM.png` |
| 19 | Knowledge Studio | NOT YET DESIGNED | Named as a Studio Bar destination only; no dedicated spec or render exists anywhere in the corpus |
| 20 | Engineering Exchange | NOT YET DESIGNED | Named as a Studio Bar destination only; no dedicated spec or render exists |
| 21 | Tools (Instruments) Studio | NOT YET DESIGNED | Named as a Studio Bar destination (post Instruments→Tools rename, AP-UX-002 C6); no dedicated spec or render exists |
| 22 | Settings Studio | NOT YET DESIGNED | Named as a Studio Bar destination only; no dedicated spec or render exists |
| 23 | Engineering Intelligence | RESOLVED — NOT A STUDIO (this document) | §5 — reclassified as an internal capability, out of Studio Inventory scope |
| 24 | Responsive/window-size behavior | NOT YET DESIGNED | No document in the corpus addresses behavior below the 1920×1080 baseline before this document's §16 |
| 25 | Render coverage vs. corpus | PARTIALLY COMPLETE | §17 below — 9 current renders cover Header/Studio Bar/Toolbar/Status Bar/Workspace context bar/Home/EAM/a full wireframe baseline, but not Diagram Studio-in-shell, Knowledge, Exchange, Tools, or Settings |
| 26 | Design-to-code contract template | NOT YET DESIGNED | `implementation/OEP-UI-IMPLEMENTATION-RULES.md` and `OEP-UI-SECTIONAL-IMPLEMENTATION.md` define *process*; no per-region contract template existed before §18 below |

## 7. Target Application Shell — Region Definitions

Restated as a single authoritative summary (values unchanged from AP-UX-002; no redesign performed here):

| Region | Height | Ownership | Identity color |
|---|---|---|---|
| Application Header | 58px | OEP application-level identity/controls | `oep.accent` only |
| Global Studio Bar | 56px | Studio-level navigation (7 entries, §5/§11) | per-Studio accent |
| Workspace Bar | 42px | Open-work-item tabs within the active Studio | per-Studio accent (inherits active Studio) |
| Toolbar | 60px | Full-width row, below the 3-column split, not nested in any column | `oep.accent` only |
| Context Navigation (left column) | fills remaining height | Studio-owned structural/document navigation | `oep.accent` only |
| Engineering Surface (center column) | fills remaining height | Studio-owned primary work content | n/a (content-defined) |
| Inspector (right column) | fills remaining height | Contextual property/selection detail | `oep.accent` only |
| Status Bar | 36px | Concise, non-dashboard status/context | `oep.accent` only |

This table is the authoritative region contract for design-to-code work (see §18); it introduces no new values.

## 8. Target Navigation Architecture — Concrete Per-Studio Examples

`OEP-UX-ARCHITECTURE.md` states the abstract hierarchy (`OEP → Studio → Workspace → Contextual Views → Objects`). Concrete instances, drawn only from what each Studio's own spec already defines:

- **Diagram Studio:** Studio Bar → Diagram Studio; Workspace Bar → open diagram (e.g. a wiring diagram document); Context Nav → diagram/document tree; Engineering Surface → wiring diagram canvas; Inspector → selected symbol/wire properties. (`DS-GOLDEN-WORKSPACE-SPEC.md` §2.)
- **EAM:** Studio Bar → EAM; Workspace Bar → open acquisition (e.g. "Honda TRX300 Service Manual"); Context Nav → acquisition-scoped contextual views list (Overview, Document View, Metadata, Detected Content, Objects, Relationships, Validation, Evidence, History); Engineering Surface → the selected contextual view's content; Inspector → selection detail within that view. (`eam/EAM-ACQUISITION-WORKSPACE-SPEC.md`, `02_EAM_ACQUISITION_WORKSPACE_SPEC.md`.)
- **Home:** Studio Bar → Home (default landing, not a "Studio" in the workflow sense but occupies the same Studio Bar slot); no Workspace Bar tab (Home is navigation, not open work — `EAM_INTERACTION_STATE_SPEC.md` "Returning Home"); Engineering Surface → Continue Working / Recent Work / Available Studios. (`OEP_HOME_UX_SPEC.md`.)
- **Knowledge Studio, Engineering Exchange, Tools, Settings:** hierarchy applies structurally (each occupies a Studio Bar slot and would open Workspace Bar tabs for its own work items) but no Studio-specific Workspace/Context Nav/Engineering Surface content is designed yet (Completion Inventory #19–22, NOT YET DESIGNED). This document does not invent that content.

Destination-vs-capability rule applied concretely: within any Studio, Objects/Relationships/Graph/Validation/Evidence/Provenance/History/Packages surface as contextual views scoped to the open workspace (as EAM already demonstrates), never as their own Global Studio Bar entries. This confirms `AP-UX-003`'s D-series finding that the current Flutter `StudioDestination` enum's flat treatment of `objects`, `relationships`, `graph`, `validation`, `packages`, `search` as first-class destinations is implementation-baseline divergence from target, not a target-design ambiguity — the target rule was already unambiguous before this document.

## 9. Studio Inventory (final)

Seven Global Studio Bar entries, per the newer-generation render/toolbar-matrix (`studio tab bar use option 3.png`, `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`) reconciled by AP-UX-002 C6 and closed by this document's §5 decision:

1. Home
2. Diagram Studio
3. EAM
4. Knowledge Studio
5. Engineering Exchange
6. Tools
7. Settings

Engineering Intelligence is explicitly excluded from this inventory (§5). No other Studio names appear anywhere in the active corpus's Studio Bar renders or toolbar matrix; this inventory is therefore treated as closed, not merely provisional, for the remainder of the active design cycle.

## 10. Home

No gaps found beyond what AP-UX-001/002 already recorded. `OEP_HOME_UX_SPEC.md` is complete and consistent with the reconciled shell; render `oep-home/home.png` is classified CANONICAL by `OEP_UX_RENDER_REFERENCE_INDEX.md`. No further completion work needed here.

## 11. Diagram Studio Shell-Integration Render — Specification (not generation)

This section defines what the still-missing render (Completion Inventory #17) must contain when produced. It does not generate the render.

The render must show Diagram Studio as an open Workspace Bar tab inside the full 8-region target shell, at the 1920×1080 baseline, satisfying every region in §7 simultaneously:

- Application Header visible and generic (not Diagram-Studio-specific content);
- Global Studio Bar visible with Diagram Studio in its active per-Studio accent color;
- Workspace Bar visible showing at least one open diagram tab, using the same active accent;
- Toolbar as a full-width row below the 3-column split, populated with diagram-relevant actions consistent with `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`'s Diagram Studio row;
- Context Navigation (left) showing a diagram/document tree per `DS-GOLDEN-WORKSPACE-SPEC.md` §3 "Left Context Region";
- Engineering Surface (center) showing real wiring-diagram content — symbols, wire paths, labels — not a placeholder, per `DS-GOLDEN-WORKSPACE-SPEC.md` §4 (this is a design/render requirement, not license to alter the actual Engine-backed renderer, which remains out of scope for design work);
- Inspector (right) showing selection/property detail for a selected diagram entity;
- Status Bar visible with concise, non-dashboard status content.

This render's purpose (per `DS-GOLDEN-WORKSPACE-SPEC.md` §Purpose/§9) is to validate shell reuse and visual QA once implementation begins; it is a prerequisite render for `WP-UI-DS-001-PROMPT.md` execution, not for this document.

## 12. EAM Completion

No gaps found. EAM has one canonical acquisition-workspace spec, one canonical interaction/state spec, four supplementary additive documents, and a CANONICAL render (`eam/EAM.png`). This is the most complete Studio in the corpus and requires no further design work at this time.

## 13. Other Studios — Maturity Assessment

| Studio | Maturity | What exists | What is missing |
|---|---|---|---|
| Knowledge Studio | NOT YET DESIGNED | Name only, in Studio Bar inventory/renders | Workflow model, contextual views, workspace content, render |
| Engineering Exchange | NOT YET DESIGNED | Name only, in Studio Bar inventory/renders | Workflow model, contextual views, workspace content, render |
| Tools | NOT YET DESIGNED | Name only (post Instruments→Tools rename), toolbar-matrix row exists but only for the icon strip, not workspace content | Workflow model, contextual views, workspace content, render |
| Settings | NOT YET DESIGNED | Name only, in Studio Bar inventory/renders | Workflow model, contextual views, workspace content, render |

This document does not design any of these Studios. Each is recorded as a concrete future AP-UX candidate (see §22).

## 14. Design System Completeness

`OEP-DESIGN-TOKENS.md` (color, per-Studio accent, geometry, typography) and `OEP-SHELL-COMPONENTS.md` (anatomy, region ownership) are complete for every region defined in §7. `OEP-UI-RULES.md`'s 10 implementation rules and prohibited-drift list are unchanged and sufficient. No token or rule gaps were found in this pass beyond what AP-UX-002 already closed.

## 15. Responsive / Window-Size Behavior

This is new: no prior document in the corpus addresses window sizes other than the 1920×1080 golden baseline. This document defines target *behavior*, not new visual specs, at three additional reference sizes the platform is expected to support (desktop application, resizable window):

- **1920×1080 (baseline):** as specified throughout the corpus — all 8 regions persistent, Context Nav and Inspector at their designed widths, Engineering Surface receives remaining space (`DS-GOLDEN-WORKSPACE-SPEC.md` §6 applied generally).
- **1600×900:** all 8 regions remain persistent. Context Nav and Inspector widths may compress toward a defined minimum (not specified numerically by any existing document — DESIGN-OWNER DECISION REQUIRED if a hard minimum is needed before implementation); Engineering Surface continues to receive remaining space per the existing "resize rather than clip" rule.
- **1280×800:** all 8 regions remain persistent in principle, but Context Nav and/or Inspector may need to become collapsible/toggleable rather than fixed-persistent to preserve a usable Engineering Surface width. No existing document specifies a collapse affordance or trigger threshold — this is NOT YET DESIGNED and is flagged for a future AP, not decided here.
- **Smaller than 1280×800:** out of scope. No document in the corpus, including this one, defines behavior below this size; the platform is a desktop engineering application and no evidence in the corpus suggests support for smaller windows is a target requirement.

This section intentionally stops at identifying what exists vs. what is undefined; it does not invent collapse thresholds, breakpoints, or minimum-width pixel values that no design-owner evidence supports.

## 16. Render Coverage Audit

Current curated renders (per `OEP_UX_RENDER_REFERENCE_INDEX.md`, re-confirmed against the live directory listing this session):

| Render | Region/area covered | Status |
|---|---|---|
| `oep-shell/App Header with OEP Logo.png` | Application Header | CANONICAL |
| `oep-shell/studio tab bar use option 3.png` | Global Studio Bar | CANONICAL |
| `oep-shell/toolbar 7 use option 3.png` | Toolbar | CANONICAL |
| `oep-shell/Status bar use option 2.png` | Status Bar | CANONICAL |
| `oep-shell/workspace context tab bar.png` | Workspace Bar | CANONICAL (EAM-domain example content is placeholder, not authoritative — per user clarification during AP-UX-001) |
| `oep-shell/Start With this Exact Wireframe and its Pixel Measurments.png` | Full shell wireframe baseline | CANONICAL — primary pixel-measurement reference |
| `oep-home/home.png` | Home | CANONICAL |
| `eam/EAM.png` | EAM workspace | CANONICAL |

Gaps confirmed: no render exists for Context Navigation or Inspector in isolation, for the full 8-region shell with Diagram Studio integrated (§11), or for Knowledge Studio, Engineering Exchange, Tools, or Settings (§13). These gaps are consistent with, not contradictory to, the Completion Inventory (§6).

## 17. Design-to-Code Contract Template

No prior document defined a reusable per-region contract for implementation agents; `OEP-UI-IMPLEMENTATION-RULES.md` and `OEP-UI-SECTIONAL-IMPLEMENTATION.md` define *process* (how to work section by section) but not a per-region *acceptance contract*. This document defines one, built directly from §7's table and existing token/rule documents — no new values are introduced:

For each of the 8 regions, an implementation agent's design-to-code map must state:
1. **Region name and source spec(s)** (cite the canonical document(s));
2. **Geometry** — exact height/width tokens from `OEP-DESIGN-TOKENS.md` §3, with the implemented value measured and compared;
3. **Color** — which token(s) apply (`oep.accent` or the specific per-Studio token from §2A), with implemented value compared;
4. **Content ownership** — what this region is and is not responsible for rendering, per `OEP-SHELL-COMPONENTS.md`;
5. **Reference render(s)** — cite the specific file(s) from §16 that constrain this region's appearance, or state "no render exists" if true (per §16's gap list — an agent must not fabricate a reference render);
6. **P0/P1/P2 divergence classification** per `OEP-VISUAL-QA-PROTOCOL.md` for any mismatch found.

This template is a completion of an existing gap, not a new process; it slots directly into the existing `OEP-UI-SECTIONAL-IMPLEMENTATION.md` workflow.

## 18. Legacy / Historical Material — Preserved Classification

No change from AP-UX-002. `eam/02_EAM_ACQUISITION_WORKSPACE_SPEC.md` and `eam/EAM_INTERACTION_STATE_SPEC.md` remain RETAINED FOR HISTORICAL/MIGRATION REFERENCE. `platform/oep_studio/docs/DESIGN_LANGUAGE.md` and the current `StudioColors` Flutter token class remain retained pending design-system reconciliation at implementation time (AP-UX-001 §12, AP-UX-003 D-series) — this document does not perform that reconciliation, since it is implementation-time work, not target-design work.

## 19. Design Completion Matrix

| Item | Classification |
|---|---|
| Application Header | COMPLETE |
| Global Studio Bar (structure) | COMPLETE |
| Global Studio Bar (inventory) | COMPLETE |
| Workspace Bar | COMPLETE |
| Context Navigation | PARTIALLY COMPLETE |
| Toolbar | COMPLETE |
| Engineering Surface (generic contract) | CONCEPTUAL |
| Inspector | PARTIALLY COMPLETE |
| Status Bar | COMPLETE |
| Accent color model | COMPLETE |
| Shell geometry | COMPLETE |
| Design tokens | COMPLETE |
| Navigation hierarchy | COMPLETE |
| Destination-vs-capability rule | COMPLETE |
| Home | COMPLETE |
| Diagram Studio shell-integration render | DESIGNED BUT UNRENDERED |
| EAM | COMPLETE |
| Knowledge Studio | NOT YET DESIGNED |
| Engineering Exchange | NOT YET DESIGNED |
| Tools | NOT YET DESIGNED |
| Settings | NOT YET DESIGNED |
| Engineering Intelligence (Studio question) | RESOLVED (not a Studio) |
| Responsive behavior ≥1280×800 | PARTIALLY DESIGNED (this document) |
| Responsive behavior <1280×800 | NOT YET DESIGNED (out of scope) |
| Design-to-code contract template | COMPLETE (this document) |

## 20. Remaining Design Decisions

1. Minimum widths / collapse behavior for Context Nav and Inspector at 1600×900 and 1280×800 (§15) — DESIGN-OWNER DECISION REQUIRED before implementation targets those sizes.
2. Whether Studio-internal accent use extends beyond Studio Bar/Workspace Bar into any Studio-owned content (an open note carried from AP-UX-002 §2A, not blocking, not resolved here since no new evidence arose).

No other open design-owner questions were found in this pass.

## 21. Next Render Work (candidates, not commitments)

1. Diagram Studio full-shell integration render, per §11's specification.
2. Context Navigation and Inspector, in isolation, at minimum for Diagram Studio and EAM.
3. Knowledge Studio, Engineering Exchange, Tools, and Settings — each requires design work (§13) before a render is meaningful.

## 22. Next Implementation Readiness

Diagram Studio and EAM are the two areas with the most complete target design. Diagram Studio implementation readiness is blocked specifically on the missing shell-integration render (§11); `WP-UI-DS-001-PROMPT.md` itself is unchanged by this document and remains classified REQUIRES REVISION per `AP-UX-003-DESIGN-TO-CODE-INSPECTION.md` until that render exists and its own "Read first" list is re-verified against this reconciled index. EAM has no equivalent shell-integration render either (Completion Inventory does not list one as existing) and would need the same treatment before implementation. No other Studio is ready for implementation planning at this time (§13).

## 23. Verification

- `git rev-parse HEAD` confirmed `deb4eccb79456593a30a7d2bd7281a4d4251d18b` before this document was created.
- `git status --short` confirmed only the same pre-existing unrelated working-tree material tracked since WP-CTRL-002 (acquisition-service files, the user's render curation deletions/additions) — none of it touched by this work package.
- This document introduces no Flutter, C++, SQL, test, or configuration changes.
- `WP-UI-DS-001-PROMPT.md` was not modified by this document; its classification (REQUIRES REVISION) is unchanged and is restated, not altered, in §22.
- C1 (accent model) and C2 (shell geometry) were not reopened; no evidence surfaced in this pass contradicted AP-UX-002's reconciliation of either.
- The only design-owner decision made in this session (Engineering Intelligence, §5) was obtained via explicit question to the design owner, not inferred or manufactured.

## 24. After-Action Report

**Recovered:** nothing new — no additional pre-existing design material was discovered in this pass beyond what AP-UX-001/002/003 already catalogued.

**Completed / newly defined in this document:** the Studio Inventory (closed to 7 entries, §9); the Engineering Intelligence question (§5, resolved as not a Studio); a full Completion Inventory across 26 items (§6); concrete per-Studio navigation examples (§8); a Diagram Studio shell-integration render specification, not the render itself (§11); an initial responsive/window-size behavior definition for ≥1280×800 (§15); a render coverage audit (§16); a design-to-code contract template (§17); a consolidated Design Completion Matrix (§19).

**Already authoritative, unchanged:** Application Header, Global Studio Bar structure, Workspace Bar, Toolbar, Status Bar, accent color model, shell geometry, design tokens, navigation hierarchy, destination-vs-capability rule, Home, and EAM — all COMPLETE prior to this document and left as-is.

**Unresolved (explicitly, not silently):** minimum-width/collapse behavior for Context Nav and Inspector below 1920×1080 (§20 item 1); the open note on Studio-accent scope beyond Studio Bar/Workspace Bar (§20 item 2).

**Needs a render:** Diagram Studio full-shell integration (§11, §21); Context Navigation and Inspector in isolation (§21).

**Needs design-owner input before implementation:** the two items in §20; and, before any of Knowledge Studio/Engineering Exchange/Tools/Settings can be implemented, their entire workflow/workspace/interaction design (§13) — none of which this document invents.

**Ready for implementation planning:** none of the four undesigned Studios. Diagram Studio and EAM are the closest, but both remain blocked on a missing shell-integration render before an implementation WP should be executed against them.
