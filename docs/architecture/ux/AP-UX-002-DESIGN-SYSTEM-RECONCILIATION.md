# AP-UX-002 — OEP UX Design System Reconciliation

## 1. Status

**COMPLETE.** This document resolves AP-UX-001's seven contradictions (C1–C7) and documents its two gaps (G1–G2). C1 and C2 required an explicit design-owner decision; C2 was already given explicitly during AP-UX-001 (the user's own instruction, "Start With this Exact Wireframe and its Pixel Measurments," attached to a specific file); C1 was asked directly during this work package and answered. Neither was inferred or manufactured.

## 2. Baseline

```text
git rev-parse HEAD   -> 8b2109177a4531ad18691c487703e6b709be7cf3
git status --short   -> pre-existing unrelated working-tree material only (see §4)
```

HEAD matched the required baseline (`8b21091`) exactly. No discrepancy.

## 3. Mission

Resolve the design-system and shell contradictions AP-UX-001 identified, consolidate the authoritative UX documentation, and establish the canonical visual/design authority for subsequent implementation — without discarding the existing UX architecture, inventing a new UX paradigm, beginning Flutter implementation, or modifying application source code. This document, `AP-UX-001-UX-DESIGN-RECOVERY.md`, and the documents it amends together constitute the reconciled authority.

## 4. Evidence Reviewed

Re-inspected directly for this reconciliation (beyond what AP-UX-001 already recorded):

- Exact "Storage:" self-references in all 8 second-generation top-level documents — confirmed exactly 4 are wrong (C6), matching AP-UX-001's count precisely.
- Section headers of `EAM-ACQUISITION-WORKSPACE-SPEC.md` (197 lines, 15 sections) vs. `02_EAM_ACQUISITION_WORKSPACE_SPEC.md` (161 lines, 13 sections) — confirmed same subject, different structure, the hyphenated document more complete (explicit Studio Navigation, Workflow Rail, and Failure/Attention-States sections the underscored one lacks).
- `EAM_INTERACTION_STATE_SPEC.md`'s own "Storage:" line, which — unlike the other three C6 cases — already pointed at `EAM-INTERACTION-STATE-SPEC.md` (the canonical document), not at itself. Treated as the original author's own evidence of intended subordination, not a fourth instance of the same filename bug.
- `platform/oep_studio/lib/` searched directly (read-only) for real shell-component locations: confirmed `app/studio_shell.dart`, `workspace/workspace_tab.dart`, `workspace/workspace_tabs_controller.dart`, `workspace/workspace_tabs_storage.dart`, `workspace/home/home_dashboard_page.dart` exist. No file matching an Application Header, Studio Tab Bar, Toolbar, or Status Bar component was found by name search — recorded as NOT LOCATED in §18 rather than guessed.
- The user's own working-tree curation from AP-UX-001 (which render options were kept vs. removed) — treated as evidence of intent for C1, presented to the user rather than acted on unilaterally.

No other document was newly discovered beyond AP-UX-001's inventory; this reconciliation operates entirely on the corpus that audit already catalogued.

## 5. Authority Hierarchy

Confirmed, unchanged from the work package's own starting principle — no repository evidence requires an exception to it:

```text
OEP Architecture / Constitution
        ↓
UX Architecture                          (OEP-UX-ARCHITECTURE.md)
        ↓
UX Interaction / Information Architecture (same document, §§2/6/7/9;
                                            01_/03_ restate it, §16 below)
        ↓
OEP Design System / Design Tokens        (design-system/*)
        ↓
Studio-specific UX Specification         (eam/*, implementation/DS-GOLDEN-WORKSPACE-SPEC.md)
        ↓
Canonical Render / Visual Reference      (OEP_UX_RENDER_REFERENCE_INDEX.md)
        ↓
Implementation
```

A render must not silently introduce behavior, navigation, ownership, or architecture absent from the authoritative specification. This rule was not violated by any artifact AP-UX-001 or this reconciliation found (AP-UX-001 §13) and is not changed here.

---

## 6. C1 — Accent Architecture

**FACT:** `OEP-DESIGN-TOKENS.md` §2 (original), `OEP-UX-ARCHITECTURE.md` §10 (original), `DS-GOLDEN-WORKSPACE-SPEC.md` §5, and `OEP_UX_RENDER_REFERENCE_INDEX.md`'s baseline-aesthetic line all stated a single, global `oep.accent` (`#2F81F7`) as *the* interaction accent, with no per-Studio variation.

**DESIGN EVIDENCE:** `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`'s COLOR RULE section, and two renders in the design-owner-curated wireframe set (`studio tab bar use option 3.png`, `workspace context tab bar.png`), establish a per-Studio accent: Diagram Studio blue, EAM green/teal, Knowledge Studio gold, Engineering Exchange purple, Instruments red, Settings slate — inherited from Studio Bar tabs down into Workspace Bar tabs. The design-owner-selected Toolbar option (`toolbar 7 use option 3.png`, "Grouped Sections") is monochrome, not per-Studio-colored, even though the same image's header strip shows the per-Studio-colored Studio Bar.

**CONFLICT:** whole-application single accent vs. per-Studio accent — genuinely irreconcilable as stated; a specific scope decision was required (AP-UX-001 C1).

**DESIGN CONSIDERATIONS:** the user's own file curation during AP-UX-001 (removing 14 unselected/exploratory renders, keeping exactly one selected option per shell component) is evidence of actual current intent, but AP-UX-001 explicitly declined to treat file-curation alone as a sufficient decision — this reconciliation put the question directly rather than inferring it.

**DESIGN-OWNER DECISION** (given directly in this work package): **Hybrid** — per-Studio accent color in the Studio Bar and Workspace Bar only; a single global `oep.accent` everywhere else (toolbar, controls, focus states, borders, links). This matches the design-owner's own kept-render selections exactly: the per-Studio color renders they kept are both navigation-tab renders; the toolbar render they kept is deliberately monochrome.

**AUTHORITATIVE RULE:**

- Studio Bar tab (active/inactive) and Workspace Bar tab → that Studio's identity color.
- Everything else → `oep.accent` (`#2F81F7`), unchanged from the original single-accent value.
- Semantic status colors (success/warning/error/info) are never replaced by a Studio identity color, and vice versa.
- The Studio identity color set is closed (7 entries: Home/Diagram Studio/EAM/Knowledge Studio/Exchange/Instruments/Settings) — adding an 8th requires a further design-owner decision, not an implementer's judgment call.

**AFFECTED DOCUMENTS:** `design-system/OEP-DESIGN-TOKENS.md` (new §2A, §5 amended, §7 amended), `OEP-UX-ARCHITECTURE.md` (§3, §10 amended), `design-system/OEP-SHELL-COMPONENTS.md` (§3, §4, §6 amended) — all updated by this reconciliation, see §15/§16 below for the resulting rules.

**AFFECTED RENDERS:** `OEP_UX_RENDER_REFERENCE_INDEX.md` rewritten (G1, §13) to mark `studio tab bar use option 3.png`/`workspace context tab bar.png` (pattern only) as CANONICAL for this rule, and the three single-accent composite renders (`oep-home/home.png`, `oep-shell/oep.png`, `eam/EAM.png`) as CURRENT REFERENCE for everything *except* their now-superseded single-color Studio Bar treatment — their region content and layout remain valid reference material.

**IMPLEMENTATION CONSEQUENCE:** an implementer building the Studio Bar or Workspace Bar must consume the new `oep.studio.*` tokens (§2A); every other control continues to use the pre-existing `oep.accent` token unchanged. No control anywhere should be recolored per-Studio without checking this rule first.

**OPEN ISSUE:** whether a Studio's *internal* screens (beyond Studio Bar/Workspace Bar) ever use their own identity color is explicitly left undecided — no evidence in the corpus shows this, and this reconciliation does not invent it (§2A's own "Open, not decided" note).

---

## 7. C2 — Shell Geometry

**FACT:** `OEP-SHELL-COMPONENTS.md` §1 (original) nested the Toolbar inside the middle column, above the Primary Engineering Surface. `OEP-DESIGN-TOKENS.md` §3 (original) set `oep.toolbar.height` = 40px and `oep.workspace.height` = 36px.

**DESIGN EVIDENCE:** `Start With this Exact Wireframe and its Pixel Measurments.png` — a render the design owner curated into the repository during AP-UX-001 under a folder explicitly titled "Use These First Before moving on to the other section," with this specific file's own name stating "Start With this Exact Wireframe and its Pixel Measurments" — places the Toolbar as a full-width row *below* the Context-Nav/Surface/Inspector three-column split, and gives explicit pixel values for all 8 regions.

**CONFLICT AND EVIDENCE TABLE:**

| Element | Existing Specification | Pixel Wireframe | Other Evidence | Conflict |
|---|---:|---:|---|---|
| Application Header height | not specified | 58px | — | Gap, not conflict — wireframe adopted |
| Global Studio Bar height | not specified (32px `oep.control.height` is a plausible but unstated proxy) | 56px | — | Gap, not conflict — wireframe adopted |
| Workspace/Context Bar height | `oep.workspace.height` = 36px | 42px | — | **Conflict** |
| Toolbar height | `oep.toolbar.height` = 40px | 60px | — | **Conflict** |
| Status Bar height | not specified | 36px | `SECTION-8-STATUS-BAR-SPEC.md` describes the component but states no height | Gap, not conflict — wireframe adopted |
| Toolbar placement | Nested inside the middle column (`OEP-SHELL-COMPONENTS.md` §1 original diagram) | Full-width row below the 3-column split | `.claude/skills/oep-ui/SKILL.md`'s section sequence numbers the toolbar `07`, after `04`/`05`/`06` (Context Nav/Surface/Inspector) and before `08` (Status) — consistent with a below-the-split row, not a nested one | **Conflict**, resolved in the wireframe's favor by the skill's own independent section ordering |

**DESIGN CONSIDERATIONS:** the design owner's own instruction, attached directly to this specific file, is as explicit a design-owner decision as this reconciliation is likely to receive without a fresh question — re-asking would have been redundant given the file's own name states the intended use plainly. The skill's independent section numbering (00–08) corroborates the wireframe's placement rather than the original anatomy diagram's, which increases confidence this is not an isolated one-off render.

**DESIGN-OWNER DECISION:** adopt the pixel wireframe's geometry and toolbar placement as authoritative, in full.

**AUTHORITATIVE RULE:** the 8-region shell (Header 58px / Studio Bar 56px / Workspace-Context Bar 42px / [Context Nav (240px, variable) | Primary Surface (~1040px, variable) | Inspector (640px, variable)] / Toolbar 60px, full-width / Status Bar 36px) is the reference geometry at the 1920×1080 baseline. Side-region widths are resizable; every height is fixed.

**AFFECTED DOCUMENTS:** `design-system/OEP-DESIGN-TOKENS.md` §3 (two token values corrected, three new tokens added), `design-system/OEP-SHELL-COMPONENTS.md` §1 (anatomy diagram redrawn, toolbar-placement rule stated explicitly).

**AFFECTED RENDERS:** none reclassified — no render actually showed the old nested-toolbar geometry as its own subject; the disagreement was between two *specifications*, not a render vs. a specification.

**IMPLEMENTATION CONSEQUENCE:** any future Diagram Studio (or other Studio) shell-integration work must target the corrected heights and the full-width toolbar row, not the original nested position — this directly affects `WP-UI-DS-001-PROMPT.md`, which predates this correction (§18/§19).

**OPEN ISSUE:** none — both disputed heights and the placement question are now resolved with one answer each.

---

## 8. C3 — EAM Historical Render

**FACT:** `renders/eam/EAM.png` panel 1 is labeled "EAM – Dashboard," uses a KPI-tile landing page as EAM's own entry point, and its Studio Bar reads `Engineering | EAM | Exchange | Knowledge | Settings` — omitting Home, Diagram Studio, and Instruments.

**DESIGN EVIDENCE AGAINST IT REMAINING AUTHORITATIVE:** `OEP-UX-ARCHITECTURE.md` §4 states "A global Dashboard is not a first-class Studio destination," and `README.md`'s own reconciliation table already carries a confirmed-applied supersession notice on `platform/oep_studio/docs/DASHBOARD.md` pointing at the same rule. No document anywhere authorizes this render's specific Studio-Bar omission or justifies its Dashboard-as-landing pattern under the narrow "Studio-specific dashboards may still exist when justified by workflow" carve-out that same rule allows.

**DESIGN-OWNER DECISION:** not required — this is a documentation-error-shaped resolution (a render clearly, specifically contradicted by already-ratified text, with no competing evidence in its favor), not a genuine two-sided design tradeoff like C1/C2.

**AUTHORITATIVE RULE:** `renders/eam/EAM.png` is classified **HISTORICAL / SUPERSEDED**. EAM's landing/navigation must follow `OEP → EAM Studio → EAM Workspace → contextual acquisition workflow` (the model every other EAM artifact already shows), not `Dashboard → EAM`.

**AFFECTED DOCUMENTS:** `OEP_UX_RENDER_REFERENCE_INDEX.md` (entry added, §13/G1).

**AFFECTED RENDERS:** `renders/eam/EAM.png` only. The file itself was not deleted — its content (workflow stepper, acquisition list, extract/review/publish screens) remains useful reference material for everything except its landing pattern and Studio Bar, and the index entry says so explicitly.

**IMPLEMENTATION CONSEQUENCE:** none directly — no implementation currently exists to correct.

---

## 9. C4 — EAM Specification Consolidation

**FACT:** `eam/EAM-ACQUISITION-WORKSPACE-SPEC.md` (197 lines, 15 sections, README-listed authority) and `eam/02_EAM_ACQUISITION_WORKSPACE_SPEC.md` (161 lines, 13 sections) cover the same acquisition-workspace model. `eam/EAM-INTERACTION-STATE-SPEC.md` (139 lines, README-listed authority) and `eam/EAM_INTERACTION_STATE_SPEC.md` (87 lines) cover the same interaction/state model — confirmed by direct diff (AP-UX-001 §8) to share the same workflow (`SOURCE→DOWNLOAD→VERIFY→EXTRACT→REVIEW→PUBLISH`) and the same workspace/workflow-state separation rule, independently worded.

**DESIGN EVIDENCE:** no substantive behavioral disagreement was found in either pair — this is duplication, not contradiction. `EAM_ACQUISITION_WORKFLOW_SPEC.md`, `EAM_INFORMATION_ARCHITECTURE.md`, `EAM_POST_ACQUISITION_UX_FLOW.md`, and `EAM_WORKSPACE_SCREEN_SPEC.md` have no hyphenated counterpart at all and are additive detail, not duplicates.

**DESIGN-OWNER DECISION:** not required — resolved by completeness and pre-existing README authority, not by a genuine content tradeoff.

**AUTHORITATIVE RULE:** `EAM-ACQUISITION-WORKSPACE-SPEC.md` and `EAM-INTERACTION-STATE-SPEC.md` (the hyphenated pair) are canonical. `02_EAM_ACQUISITION_WORKSPACE_SPEC.md` and `EAM_INTERACTION_STATE_SPEC.md` are retained for historical/migration reference, each now carrying an explicit banner pointing to its canonical counterpart. The four additive underscored documents remain in effect as supplementary detail beneath the canonical pair, not as competitors to it.

**AFFECTED DOCUMENTS:** both canonical files (banner added), both historical files (banner added), `README.md` (authority table corrected, §11 below).

**IMPLEMENTATION CONSEQUENCE:** a future EAM implementation WP should read the two canonical files first; the historical pair is optional background reading only.

**RESIDUAL NOTE:** this reconciliation did not perform an exhaustive line-by-line merge to confirm the historical documents contain zero unique detail absent from their canonical counterparts — a full read found none, but this is recorded as a residual, low-confidence risk rather than a certainty, consistent with not fabricating completeness.

---

## 10. C5 — Documentation Authority / README

**FACT:** `README.md`'s "Authority" file tree, before this reconciliation, listed only 9 files (`OEP-UX-ARCHITECTURE.md`, 3 design-system docs, 4 implementation docs, 2 of the 8 EAM docs) and did not mention any of the 8 second-generation top-level documents, the 6 second-generation EAM documents, or the curated render folder.

**DESIGN-OWNER DECISION:** not required — this is a factual staleness correction (comparing the document's claims against `find docs/architecture/ux -type f`), not a design tradeoff.

**AUTHORITATIVE RULE:** `README.md` now lists every current file, explicitly marks which are CANONICAL vs. supplementary vs. historical, and points to this reconciliation document and `AP-UX-001-UX-DESIGN-RECOVERY.md` at the top.

**AFFECTED DOCUMENTS:** `README.md` (fully rewritten Authority section and Current Design Work section; navigation model, UI Implementation Kit, and Existing Documentation Reconciliation table preserved unchanged — they were not found stale).

---

## 11. C6 — Self-Reference Corrections

**FACT:** exactly 4 documents' own "Storage:" header line named a hyphenated path that does not exist on disk, instead of their own actual underscored filename: `OEP_STUDIO_TAB_WORKSPACE_SPEC.md`, `OEP_CONTEXTUAL_CAPABILITY_SPEC.md`, `OEP_HOME_UX_SPEC.md`, `OEP_UX_RENDER_REFERENCE_INDEX.md`. (A 5th file, `eam/EAM_INTERACTION_STATE_SPEC.md`, has a similar-looking line but it points at a *different, real* file — its canonical counterpart — not at a nonexistent path; handled under C4, not here.)

**AUTHORITATIVE RULE:** all 4 corrected to name their own actual filename, with a note explaining the fix.

**AFFECTED DOCUMENTS:** the 4 files listed above.

**NOT DONE:** a repository-wide standardization on one naming convention (hyphenated vs. underscored) was considered and explicitly declined — the work package instructed "do not perform broad unrelated documentation rewrites," and the two conventions, while inconsistent, do not create any behavioral ambiguity once each file correctly names itself. This is recorded as a deferred, cosmetic cleanup opportunity, not resolved here.

---

## 12. C7 — Studio Naming

**FACT:** `OEP-UX-ARCHITECTURE.md`'s original Studio Bar list uses "Instruments." `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` and the curated render set use "Tools" for the same navigation slot instead, and drop "Engineering Intelligence" from the Studio Bar entirely.

**DESIGN EVIDENCE:** `platform/oep_studio` (the real, already-implemented application) has a distinct, real subsystem named `platform/oep_instruments`, documented as its own section ("13. OEP INSTRUMENTS") in `OEP_PROJECT_STATUS.md`. The Toolbar Action Matrix's own "TOOLS" command group content (DMM, Signal Generator, CAN Analyzer, Oscilloscope, Pinout Lookup, Calculator, Conversion Tools) is squarely within that same real subsystem's domain (instrument bridge, DMM). No evidence anywhere suggests "Tools" refers to something Instruments does not already cover.

**DESIGN-OWNER DECISION:** not required — "Instruments" already matches a real, named, already-implemented subsystem; "Tools" is best read as an informal relabeling introduced during the newer render exploration, not a deliberate rename with its own rationale.

**AUTHORITATIVE RULE:** "Instruments" is the canonical Studio Bar label. "Tools" is a legacy/informal alternate label from the second-generation exploration and should be treated as referring to the same destination, not a different one.

**AFFECTED DOCUMENTS:** none required correction beyond a cross-reference — `OEP-UX-ARCHITECTURE.md` already used "Instruments" and was not wrong; `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` and the render filenames were not edited (out of the explicit "expected candidates" list for this reconciliation, and editing render filenames risks breaking the render index's own just-corrected references) — this rule is recorded here and in the render index instead.

**OPEN ISSUE, EXPLICITLY NOT RESOLVED:** whether "Engineering Intelligence" remains a distinct Studio Bar entry, separate from "Engineering"/Diagram Studio, is genuinely undetermined by the evidence — no specification or render clearly argues either way, and this reconciliation does not invent an answer. Left open for a future decision.

---

## 13. G1 — Canonical Render Index

`OEP_UX_RENDER_REFERENCE_INDEX.md` was rewritten in full. Summary (full table with Purpose/Authority/Related-Specification/Last-Known-Design-State columns is in that file, not duplicated here):

| Render | Status |
|---|---|
| `oep-home/home.png` | CURRENT REFERENCE |
| `oep-shell/oep.png` | CURRENT REFERENCE |
| `eam/EAM.png` | HISTORICAL / SUPERSEDED (C3) |
| `App Header with OEP Logo.png` | CANONICAL |
| `Start With this Exact Wireframe and its Pixel Measurments.png` | CANONICAL |
| `Status bar use option 2.png` | CANONICAL |
| `studio tab bar use option 3.png` | CANONICAL |
| `toolbar 7 use option 3.png` | CANONICAL |
| `workspace context tab bar.png` | EXPERIMENTAL (pattern retained, EAM example content is placeholder) |

No render was labeled CANONICAL on visual appeal alone — each CANONICAL entry above is either the design-owner's explicitly selected option (filename says "use option N") or, for the two composite renders, the only current reference for Home/EAM region layout (their now-superseded single-accent Studio Bar treatment is called out, not silently ignored).

---

## 14. G2 — Diagram Studio Integration Render Requirement

**Not generated in this work package**, per its own explicit instruction. Requirement, for a future AP to satisfy:

A render demonstrating Diagram Studio operating inside the reconciled OEP shell, showing at minimum:

```text
OEP Application Shell (Header 58px)
    ↓
Global Studio Bar (56px) — Diagram Studio active, identity color per §2A
    ↓
Workspace Bar (42px) — open diagram(s) as workspace tabs, Diagram Studio identity color
    ↓
Context Navigation (240px, variable) — diagram/document tree
    ↓
Toolbar (60px, full-width row below the 3-column split, per C2) — Diagram Studio command set
    ↓
Primary Engineering Surface (~1040px, variable) — the real wiring/diagram surface, per DS-GOLDEN-WORKSPACE-SPEC.md §4 (existing renderer, not a mockup)
    ↓
Inspector (640px, variable) — selection/property detail
    ↓
Status / Context Bar (36px)
```

This must be produced against the C1/C2-reconciled geometry and color rules above, not the pre-reconciliation shell. It is the one concrete visual gap AP-UX-001 found (§9) that this reconciliation does not itself close — recorded as remaining work (§19), not silently dropped.

---

## 15. Final Design-System Rules

(Full detail lives in the amended `design-system/OEP-DESIGN-TOKENS.md`; this section summarizes what changed.)

**Color:** `oep.bg`, `oep.surface.1/2/3`, `oep.border`/`.strong`, `oep.text.primary/secondary/muted` — unchanged. `oep.accent`/`.hover` — unchanged value, scope clarified (§2A: not the Studio Bar/Workspace Bar identity color). `oep.success/warning/error/info` — unchanged. **New:** `oep.studio.{home,diagram,eam,knowledge,exchange,instruments,settings}` — the closed, 7-entry per-Studio identity set (C1).

**Geometry:** radius/spacing scale/`oep.control.height`(.compact) — unchanged. **New:** `oep.header.height` (58px), `oep.studiobar.height` (56px), `oep.statusbar.height` (36px). **Corrected:** `oep.workspace.height` 36px → 42px, `oep.toolbar.height` 40px → 60px (C2).

**Typography:** unchanged — no contradiction was found here.

**Visual constraints:** the full prohibited-pattern list (purple/pink AI gradients, glassmorphism, oversized cards, giant hero areas, browser chrome, excessive shadows, generic SaaS/Bootstrap styling, excessive whitespace, competing decorative illustrations) is preserved unchanged. "Arbitrary new accent colors" is now explicitly scoped: the 7-entry Studio identity set is closed, not an invitation to add more.

## 16. Final Shell Rules

The 8-region anatomy (§7 above) is now pixel-dimensioned and the Toolbar's full-width, below-the-split placement is explicit. Per-region ownership rules (`OEP-SHELL-COMPONENTS.md` §2–§10) are otherwise unchanged from AP-UX-001's recovery — Application Header quiet/no Studio nav; Global Studio Bar native tabs with Studio-identity active state (C1); Workspace Bar tabs inheriting Studio identity color (C1); Context Navigation Studio/workspace-scoped; Toolbar single global accent (C1), never a second nav bar; Main Engineering Surface owned by the Studio, shell does not dictate its rendering; Inspector contextual/compact; Status Bar concise, never a dashboard; component ownership ("Studio host owns shell composition, owning Studio owns workspace/contextual-tool contents, Engine owns engineering model/rendering where established") unchanged.

## 17. Legacy / Historical Artifact Classification

| Document/artifact | Classification | Unchanged from AP-UX-001? |
|---|---|---|
| `platform/oep_studio/docs/DASHBOARD.md` | SUPERSEDED (confirmed still applied) | Yes |
| `platform/oep_studio/docs/OEP_INTERACTION_MODEL.md` | MIGRATION MATERIAL | Yes |
| `platform/oep_studio/docs/OEP_SURFACE_ARCHITECTURE.md` | MIGRATION MATERIAL | Yes |
| `platform/oep_studio/docs/DESIGN_LANGUAGE.md` | HISTORICAL, retained pending reconciliation | Yes |
| `renders/eam/EAM.png` | HISTORICAL / SUPERSEDED | **New this WP** (C3) |
| `eam/02_EAM_ACQUISITION_WORKSPACE_SPEC.md` | RETAINED FOR HISTORICAL/MIGRATION REFERENCE | **New this WP** (C4) |
| `eam/EAM_INTERACTION_STATE_SPEC.md` | RETAINED FOR HISTORICAL/MIGRATION REFERENCE | **New this WP** (C4) |
| 10 dated `ChatGPT Image...` renders + 4 unselected option sheets | HISTORICAL (removed from disk by the user during AP-UX-001; recorded, not restored) | Carried forward from AP-UX-001 §10 |

The superseded Dashboard-landing model is no longer ambiguous anywhere in this corpus: `DASHBOARD.md` (Studio-layer) and `renders/eam/EAM.png` (UX-layer) are both now explicitly marked, for the same underlying rule.

## 18. Design-to-Code Preparation

Not implementation. Repository-inspected (read-only), not fabricated:

| Shell component | Flutter implementation location | Current state | Design conformance status | Known divergence | Required future change |
|---|---|---|---|---|---|
| Shell composition root | `platform/oep_studio/lib/app/studio_shell.dart` (confirmed to exist) | Not inspected beyond confirming the file exists — reading its contents in detail is implementation-adjacent inspection this WP did not perform | UNKNOWN | UNKNOWN | AP-UX-004 (or a re-issued WP-UI-DS-001) must open this file and produce the actual design-to-code map §17 of AP-UX-001 found missing (G1 there) |
| Workspace tabs | `platform/oep_studio/lib/workspace/workspace_tab.dart`, `workspace_tabs_controller.dart`, `workspace_tabs_storage.dart` (confirmed to exist) | Not inspected in detail | UNKNOWN | UNKNOWN | Same as above |
| Home | `platform/oep_studio/lib/workspace/home/home_dashboard_page.dart` (confirmed to exist) | Not inspected in detail | UNKNOWN | UNKNOWN | Same as above |
| Application Header | **NOT LOCATED** by filename search | — | — | — | AP-UX-004 must locate it (may be inline inside `studio_shell.dart` rather than a separate file) or confirm it does not yet exist as a separate component |
| Global Studio Bar | **NOT LOCATED** by filename search | — | — | — | Same as above |
| Toolbar / Action Strip | **NOT LOCATED** by filename search | — | — | — | Same as above |
| Inspector | **NOT LOCATED** by filename search | — | — | — | Same as above |
| Status Bar | **NOT LOCATED** by filename search | — | — | — | Same as above |

This table is intentionally incomplete where evidence is incomplete — per this work package's own instruction not to fabricate locations, and per the broader control principle (WP-CTRL-002) that documentation should preserve uncertainty rather than paper over it.

## 19. Remaining UX Work

1. **G2** — the Diagram Studio shell-integration render (§14) does not yet exist.
2. **Design-to-code map** — §18's table has five UNKNOWN/NOT LOCATED rows; a real implementation-inspection pass (not source modification) is needed before any Studio's shell integration can be safely scoped.
3. **`WP-UI-DS-001-PROMPT.md`** should have its "Read first" list re-verified against the reconciled document set before it is executed — it currently references only the pre-reconciliation documents.
4. **C7's open issue** — "Engineering Intelligence" as a Studio Bar entry, undecided.
5. **C6's deferred item** — the hyphenated-vs-underscored naming-convention split across the directory remains, cosmetically, even though every file now correctly names itself.
6. Everything AP-UX-001 §16 already listed as not-yet-designed and not addressed by this reconciliation: dedicated UX depth for Knowledge Studio, Engineering Exchange, Engineering Intelligence, Settings, and Search beyond a Studio Bar entry and (for some) a toolbar command list; responsive/tablet design.

## 20. Verification

```text
git diff --check      -> clean (exit 0)
git status --short    -> only this reconciliation's own changes plus the
                          pre-existing, unrelated working-tree material
                          (unchanged, untouched, see §2/§4)
git diff --stat        -> 9 files changed (see commit)
```

Checklist against this work package's own §23:

1. No source-code changes — confirmed, only `docs/architecture/ux/**` touched.
2. No unrelated files staged — confirmed.
3. User render curation untouched — confirmed, no file under `renders/` was added, removed, or moved by this reconciliation; only two Markdown index files that describe it were rewritten.
4. C1–C7 explicitly resolved (C1, C2 via explicit design-owner decision; C3, C4, C5, C6 via evidence-based, non-discretionary correction) or formally left open (C7's "Engineering Intelligence" sub-question).
5. G1/G2 documented — G1 fully (new render index), G2 as a defined, not-yet-produced requirement.
6. README authority accurate — rewritten against the actual current file list.
7. No contradictory document remains falsely marked authoritative — the two EAM duplicate pairs and the historical EAM render are now explicitly marked.
8. Changed Markdown references checked by direct re-read after editing; no broken relative link introduced.
9. Design tokens agree with shell geometry — both now state 42px/60px for the same two regions.
10. Shell specification agrees with canonical design direction — anatomy diagram redrawn to match the design-owner-designated wireframe.
11. EAM has two canonical documents (workspace + interaction/state, matching the two distinct subjects AP-UX-001 found), not four competing ones.
12. Historical EAM Dashboard render clearly classified — HISTORICAL/SUPERSEDED, with rationale, in the render index.
13. Studio naming resolved to "Instruments," with the "Engineering Intelligence" question explicitly left open rather than silently dropped.
14. No browser-style navigation reintroduced — not touched by this reconciliation, and nothing in it proposes this.
15. `git diff --check` exits 0 — confirmed above.

## 21. AAR

See the Final AAR delivered in the work-package response.
