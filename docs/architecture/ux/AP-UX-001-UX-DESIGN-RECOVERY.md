# AP-UX-001 — OEP UX Design Recovery & Consolidation

**Status:** Audit / consolidation record. Not an architecture decision. Not a design ratification.
**Baseline:** `7e09770` (repository HEAD at start of this audit).
**Scope:** `docs/architecture/ux/` and its direct references, cross-checked against `platform/oep_studio/docs/` and `.claude/skills/oep-ui/SKILL.md`.

This document does not redesign OEP. It establishes what has already been designed, what visual language and interaction architecture have already been established, which artifacts are authoritative, where they disagree, and what the next UX design work actually is.

---

## 1. Executive Finding

OEP already has a substantial, mostly coherent UX design system: a four-level navigation model (Studio → Workspace → Contextual View → Capability), an explicit destination-vs-capability rule, a documented interaction grammar, a token-based dark/compact visual language, a reusable shell-component contract, an implementation skill, and multiple rounds of design renders for Home, the application shell, and EAM. This is not a blank slate, and it is not something that needs to be redesigned from first principles.

It is, however, **two generations of the same design effort that have not been reconciled with each other**, plus one implementation-ready work package (`WP-UI-DS-001-PROMPT.md`) that was written against the *older* generation and does not know the newer one exists.

The single most important, concrete, evidence-backed disagreement is the **accent-color model**: the earlier generation (`OEP-DESIGN-TOKENS.md`, `OEP-UX-ARCHITECTURE.md`, `DS-GOLDEN-WORKSPACE-SPEC.md`, and the `oep-home/`/`oep-shell/`/`eam/` composite renders) establishes **one** restrained blue accent for the whole application. The newer generation (`OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` and the curated `Section 1,2,3, 7,8 of Wireframe UI...` render set, which the user has since narrowed to one selected option per component) establishes a **per-Studio accent color** (Diagram Studio blue, EAM green/teal, Knowledge gold, Exchange purple, Tools red, Settings slate), inherited down into workspace tabs. Both are internally consistent; they are not consistent with each other, and no document says which one wins.

A second concrete disagreement is **shell geometry**: the pixel-precise wireframe the user pointed to as primary (`Start With this Exact Wireframe and its Pixel Measurments.png`) places the Toolbar/Action Strip as a full-width row *below* the Context-Nav/Surface/Inspector three-column split, and gives the Toolbar 60px and the Workspace/Context Bar 42px — while `OEP-SHELL-COMPONENTS.md`'s anatomy diagram nests the toolbar *inside* the middle column (above the surface, not full-width), and `OEP-DESIGN-TOKENS.md` sets `oep.toolbar.height` = 40px and `oep.workspace.height` = 36px.

Neither disagreement is a sign of confused thinking — each side is a legitimate, deliberate design pass. What is missing is the reconciliation step. That reconciliation, not a new round of visual exploration and not Flutter implementation, is the actual next UX design work (Section 17).

---

## 2. Repository Baseline

Verified before any inspection began:

```text
git rev-parse HEAD           -> 7e0977084a18a87f0a4c20f5dbcef4875bea8b42
git branch --show-current    -> main
git status --short           -> pre-existing unrelated working-tree changes only (see below)
```

HEAD matched the required baseline (`7e09770`) exactly. No discrepancy to report.

**Mid-audit change, observed and preserved, not caused by this audit:** during this session the user removed 14 exploratory render files (`ChatGPT Image Sep 15, 2026, *.png`, `Status bar.png`, `studio tab bar.png`, `wireframe.png`, `workspace context tab bar.png`) and added a new, curated folder:

```text
docs/architecture/ux/renders/Section 1,2,3, 7,8 of Wireframe UI Use These First Before moving on to the otheer section/
    App Header with OEP Logo.png
    Start With this Exact Wireframe and its Pixel Measurments.png
    Status bar use option 2.png
    studio tab bar use option 3.png
    toolbar 7 use option 3.png
    workspace context tab bar.png
```

This is uncommitted working-tree state, exactly as the prior control reconciliation (WP-CTRL-002) found other pre-existing unrelated UX material. **This audit inspected the curated set as the current state of the repository and reports on it accordingly, but did not stage, commit, or otherwise alter these deletions/additions** — that remains the user's own file management action. Also still present, unrelated to this audit, and left untouched: `platform/oep_studio/lib/acquisition/...` (2 files), `services/acquisition/config/config.toml`, and two `services/acquisition/data/...` working directories.

---

## 3. UX Artifact Inventory

Full `docs/architecture/ux/` tree at the time of this audit (44 files: 27 Markdown, 17 image renders before the mid-audit curation; 33 files — 27 Markdown, 6 image renders — after it):

```text
docs/architecture/ux/
├── README.md                                    -- directory index / authority pointer (STALE, see §14)
├── OEP-UX-ARCHITECTURE.md                        -- master navigation/interaction architecture
├── 01_OEP_SHELL_UX_DESIGN_SPEC.md                 -- second-generation restatement of the above
├── 03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md           -- second-generation restatement of destination/capability rule
├── OEP_CONTEXTUAL_CAPABILITY_SPEC.md              -- additive: concrete per-capability contextual behavior
├── OEP_HOME_UX_SPEC.md                            -- additive: concrete Home region-by-region spec
├── OEP_STUDIO_TAB_WORKSPACE_SPEC.md               -- additive: concrete Studio/Workspace tab mechanics
├── OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md   -- additive: full per-Studio command matrix + per-Studio color rule
├── SECTION-8-STATUS-BAR-SPEC.md                   -- additive: customizable status-bar concept
├── OEP_UX_RENDER_REFERENCE_INDEX.md               -- render index (STALE filenames, see §10)
├── design-system/
│   ├── OEP-DESIGN-TOKENS.md                       -- color/geometry/typography tokens (single-accent model)
│   ├── OEP-SHELL-COMPONENTS.md                    -- shell anatomy + region ownership/rules
│   └── OEP-UI-RULES.md                            -- 10 numbered implementation rules + prohibited patterns
├── implementation/
│   ├── OEP-UI-IMPLEMENTATION-RULES.md             -- implementation-agent contract
│   ├── OEP-VISUAL-QA-PROTOCOL.md                  -- P0/P1/P2 visual-diff protocol
│   ├── OEP-SCREEN-IMPLEMENTATION-TEMPLATE.md       -- blank per-screen template
│   ├── OEP-UI-SECTIONAL-IMPLEMENTATION.md          -- section-by-section implementation workflow (00-08)
│   ├── DS-GOLDEN-WORKSPACE-SPEC.md                 -- Diagram Studio golden-screen target (`DS-WORKSPACE-A`)
│   └── WP-UI-DS-001-PROMPT.md                      -- READY-TO-EXECUTE Diagram Studio integration WP (see §17)
├── eam/  (on-disk casing; git also tracks an "EAM/" casing -- same directory, case-insensitive filesystem)
│   ├── EAM-ACQUISITION-WORKSPACE-SPEC.md          -- first-generation EAM workspace spec (README-listed authority)
│   ├── EAM-INTERACTION-STATE-SPEC.md              -- first-generation EAM state spec (README-listed authority)
│   ├── 02_EAM_ACQUISITION_WORKSPACE_SPEC.md        -- second-generation, overlapping, NOT README-listed
│   ├── EAM_ACQUISITION_WORKFLOW_SPEC.md            -- second-generation, additive workflow detail
│   ├── EAM_INFORMATION_ARCHITECTURE.md             -- second-generation, additive IA detail
│   ├── EAM_INTERACTION_STATE_SPEC.md               -- second-generation, PARALLEL to EAM-INTERACTION-STATE-SPEC.md (§8)
│   ├── EAM_POST_ACQUISITION_UX_FLOW.md             -- second-generation, additive post-acquisition detail
│   └── EAM_WORKSPACE_SCREEN_SPEC.md                -- second-generation, additive screen-level detail
└── renders/                                        -- see §10
```

Also inspected, outside `docs/architecture/ux/`:

- `.claude/skills/oep-ui/SKILL.md` — the implementation skill (§12).
- `platform/oep_studio/docs/DASHBOARD.md`, `OEP_INTERACTION_MODEL.md`, `OEP_SURFACE_ARCHITECTURE.md`, `DESIGN_LANGUAGE.md` — pre-existing Studio-layer documents `README.md` names in its own reconciliation table. `DASHBOARD.md` already carries a supersession notice pointing at `OEP-UX-ARCHITECTURE.md`, consistent with what `README.md` claims; the other three are unmodified, retained-pending-reconciliation drafts, consistent with `README.md`'s own table.
- `platform/oep_studio/docs/diagram_studio/`, `platform/oep_studio/docs/architecture/diagram_studio/`, and the dozen `DIAGRAM_STUDIO_V2_*` implementation documents — pre-existing, extensive, **implementation/bridge-architecture** documentation, not UX/visual documentation. No document under `docs/architecture/ux/` corresponds to a `docs/architecture/ux/Diagram Studio/` directory — no such directory exists. Diagram Studio's only *UX-layer* (as opposed to implementation-layer) document is `implementation/DS-GOLDEN-WORKSPACE-SPEC.md`.
- Repository-wide search for `OEP UX`, `OEP-UX`, `design render`, `render series`, `UX architecture`, `design system`, `Studio Bar`, `Workspace Bar`, `Contextual Navigation`, `EAM workspace`, `Diagram Studio UX` — matches are confined to `docs/architecture/ux/`, `.claude/skills/oep-ui/`, `OEP_PROJECT_STATUS.md`/`OEP_RELEASE_HISTORY.md`'s own entries recording the UX-001 commits (WP-CTRL-002), and the `platform/oep_studio/docs/` files already accounted for above. No independent, undiscovered UX design corpus exists elsewhere in the repository.

---

## 4. Existing UX Architecture

Source: `docs/architecture/ux/OEP-UX-ARCHITECTURE.md` (**Status: Proposed — design authority for new OEP UX work pending formal ratification** — this is stated in the document itself; it is not yet a ratified ADR).

Four concepts, exactly as the work-package brief describes:

1. **Application / Studio** — an intentional destination.
2. **Workspace** — an open piece of engineering work or reference content.
3. **Contextual view** — a view of the current workspace or selected entity.
4. **Capability / operation** — something the user can do to the current context.

Navigation hierarchy (verbatim structure, recovered, not altered):

```text
OEP
│
├── Global Studio Bar
│     ├── Home
│     ├── Diagram Studio
│     ├── EAM
│     ├── Knowledge Studio
│     ├── Engineering Exchange
│     ├── Engineering Intelligence
│     ├── Instruments
│     └── Settings
│
├── Workspace Bar
│     ├── open artifact / acquisition / project
│     ├── open artifact / acquisition / project
│     └── +
│
└── Contextual Navigation
      ├── views
      ├── inspections
      ├── tools
      └── workflow stages
```

Interaction grammar (recovered verbatim):

```text
OPEN WORK -> SELECT / FOCUS -> INSPECT -> VIEW RELATED ENGINEERING CONTEXT -> PERFORM CONTEXTUAL OPERATION -> VALIDATE / VERIFY
```

**Destination vs. capability rule** (§7 of the source document): before adding a global destination, ask whether it is independently meaningful, intentionally browsable, has an independent lifecycle, and whether making it contextual would make a common task harder. If mostly no, it is contextual. Objects, Relationships, Graph, Validation, Evidence, Provenance, History, and Packages are named as normally-contextual; Repository browsing is the one named exception (a repository is itself a persistent, intentionally-browsable resource).

This architecture is corroborated, not contradicted, by `README.md`'s own navigation model and by the second-generation `01_OEP_SHELL_UX_DESIGN_SPEC.md` and `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`, which restate it with different wording and additional worked examples (Diagram Studio, Knowledge Studio, EAM contextual trees) but no substantive disagreement. No contradiction found here — this is the one part of the corpus that is genuinely stable across both generations. See §16 for why this content is nonetheless duplicated rather than consolidated.

---

## 5. Existing Design System

Source: `design-system/OEP-DESIGN-TOKENS.md`, `OEP-SHELL-COMPONENTS.md`, `OEP-UI-RULES.md` (all **Status: Proposed implementation baseline**).

**Color** (single-accent model):

| Token | Value | Use |
|---|---|---|
| `oep.bg` | `#0B0F14` | application background |
| `oep.surface.1` | `#111720` | primary panels |
| `oep.surface.2` | `#151D27` | raised panels/inspectors |
| `oep.surface.3` | `#1B2531` | selected/hovered surfaces |
| `oep.border` / `.strong` | `#2A3542` / `#394858` | panel borders / active separators |
| `oep.text.primary/secondary/muted` | `#E7EDF4` / `#9AA8B7` / `#667585` | text hierarchy |
| `oep.accent` / `.hover` | `#2F81F7` / `#4A94FF` | **the one** active-Studio/primary-action/focus color |
| `oep.success/warning/error/info` | `#39B56B` / `#D9A441` / `#D95C5C` / `#5DA9E9` | status only, never decorative |

**Geometry:** radii 0/3/5/7px; spacing scale 4/8/12/16/20/24/32px; `oep.control.height` 32px (28px compact); `oep.toolbar.height` **40px**; `oep.workspace.height` **36px**. (Compare §6/§14 — the newer wireframe disagrees with both height figures.)

**Typography:** application title 18–20px semibold; Studio title 14–16px semibold; workspace/tab label 12–13px medium; body/UI 12–13px; metadata/status 10–11px; monospace engineering values 11–12px. System sans-serif unless an approved OEP font already exists — no new font "solely for visual effect."

**Desktop baseline:** 1920×1080, 16:9, full application window, for every primary render and visual-QA capture.

**Prohibited visual drift** (verbatim list): purple/pink AI-style gradients, glassmorphism, oversized rounded cards, giant empty hero areas, browser-like chrome, excessive shadows, arbitrary new accent colors, generic Material/Bootstrap dashboard styling, excessive whitespace hiding engineering information, decorative illustrations competing with engineering content.

`OEP-SHELL-COMPONENTS.md` defines the reusable shell anatomy (region list, ownership, rules per region) — recovered in full in §6. `OEP-UI-RULES.md` adds 10 numbered rules (implement the system not the screenshot; Studios are destinations; no invented navigation; preserve domain behavior; reuse the shell; explicit geometry beats approximation; visual density is intentional; selection drives context; state must be visible; accessibility remains structural) plus the same prohibited-patterns list.

**This is the baseline unless a documented contradiction is discovered.** One is: see §14, Contradiction C1 (accent color) and C2 (toolbar/workspace-bar height).

---

## 6. Existing Shell Architecture

Source: `design-system/OEP-SHELL-COMPONENTS.md`.

Recovered anatomy (verbatim structure):

```text
┌──────────────────────────────────────────────────────────────────┐
│ Application Header                                                │
├──────────────────────────────────────────────────────────────────┤
│ Global Studio Bar                                                 │
├──────────────────────────────────────────────────────────────────┤
│ Workspace Bar                                                     │
├───────────────┬───────────────────────────────────┬──────────────┤
│ Context Nav   │ Toolbar / Context Actions          │ Inspector    │
│               ├───────────────────────────────────  │              │
│               │ Primary Engineering Surface        │              │
├───────────────┴───────────────────────────────────┴──────────────┤
│ Status / Context Bar                                              │
└──────────────────────────────────────────────────────────────────┘
```

Ownership, ratified in this document:

- **Application Header** — quiet, application identity + controls, no Studio navigation, no browser address-bar metaphor.
- **Global Studio Bar** — switches OEP destinations; native tabs, not browser tabs; no backend capability names as global tabs; inactive Studios remain visible.
- **Workspace Bar** — identifies open work inside the active Studio; closing a workspace ≠ closing the Studio; `+` opens another workspace.
- **Context Navigation** — views/workflow stages meaningful to the current workspace; never promoted to global nav merely because it has a route.
- **Toolbar** — actions for the current selection/workspace; selection-dependent actions disable rather than disappear "when discoverability matters"; must not become a second navigation bar.
- **Main Engineering Surface** — belongs to the owning Studio (diagram canvas, document viewer, acquisition workflow, editor, table, etc.); the shell does not dictate its internal rendering implementation.
- **Inspector** — contextual, compact, structured fields, not a duplicate object browser; selection changes update it without touching global navigation.
- **Status/Context Bar** — concise state only; explicitly must not become a dashboard.
- **Component ownership rule** — "The OEP Studio host owns shell composition. The owning Studio owns the contents of its workspace and contextual tools. Engine remains authoritative for engineering model, graph/layout/commands/validation/search/editing/navigation/rendering where established by the architecture." This is the ownership-boundary statement the work-package brief asked to be recovered rather than reinvented (§10 applies this specifically to Diagram Studio's rendering pipeline).

**Difference found between specification and render (recorded, not resolved — see §14 C2):** the newer, user-selected pixel wireframe (`Start With this Exact Wireframe and its Pixel Measurments.png`) places the Toolbar as a full-width row **below** the Context-Nav/Surface/Inspector split, not nested inside the middle column as the ASCII diagram above shows. It also gives explicit pixel heights the token document's own values (§5) do not match.

**Difference between specification and current Flutter implementation:** not assessed in numeric/structural detail by this audit — no code was read for this purpose, per the work package's own "do not modify source code" instruction, and no prior WP-CTRL or implementation report in this repository documents a section-by-section comparison. This is itself a finding: **nobody has yet produced the design-to-code map §17/§19 depend on.**

---

## 7. Studio Inventory

| Studio / destination | Classification | Evidence |
|---|---|---|
| Home | **DESIGNED** | `OEP_HOME_UX_SPEC.md` (full spec), `OEP-UX-ARCHITECTURE.md` §4, both composite renders (`oep-home/home.png`, `oep-shell/oep.png`) |
| Diagram Studio | **DESIGNED** (UX layer) / **IMPLEMENTED** (application layer, pre-existing, see `OEP_PROJECT_STATUS.md` §9) | `implementation/DS-GOLDEN-WORKSPACE-SPEC.md`, `WP-UI-DS-001-PROMPT.md`, `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`'s worked example |
| EAM (Engineering Acquisition Manager) | **DESIGNED**, but fragmented across two generations of spec (§8, §16) | `eam/*` (8 files), `eam/EAM.png`, `oep-home/home.png`, `oep-shell/oep.png` |
| Knowledge Studio | **CONCEPTUAL** | named consistently in every navigation list and the toolbar matrix's command groups; no dedicated workspace/screen specification exists anywhere in the corpus |
| Engineering Exchange | **CONCEPTUAL** (UX layer) / separately **PARTIALLY IMPLEMENTED** (application layer — see `OEP_PROJECT_STATUS.md` §12, unrelated to this UX corpus) | named in every list; toolbar matrix defines a command set (Discover/Asset/Publish/License/Package); no workspace/screen spec |
| Engineering Intelligence | **CONCEPTUAL**, and inconsistently named (see below) | named only in `OEP-UX-ARCHITECTURE.md`'s Studio Bar list and `OEP_HOME_UX_SPEC.md`'s Available-Studios example |
| Instruments | **CONCEPTUAL**, and inconsistently named ("Tools" in the newer generation) | present in `OEP-UX-ARCHITECTURE.md`'s list; the toolbar matrix and the new render series both call this destination **"Tools"** instead |
| Settings | **DESIGNED** at the command-matrix level only | `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` §07; no workspace/screen specification |
| Repository (Browser) | **DESIGNED** as a contextual-but-persistent destination, not a Studio | `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md` "Repository Exception", both composite renders' "Repository Browser" panel, toolbar matrix §08 |
| Search | **DESIGNED** at the command-matrix level only | `OEP_HOME_UX_SPEC.md` §10 (global search), toolbar matrix §09 |

**Naming inconsistency found (not previously documented):** `OEP-UX-ARCHITECTURE.md`'s canonical Studio Bar list uses **"Engineering Intelligence"** and **"Instruments"**. The newer generation (`OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`, `SECTION-8-STATUS-BAR-SPEC.md`'s absence of it, and every render in the curated wireframe set) uses **"Tools"** in the Studio Bar and drops "Engineering Intelligence" from the bar entirely (folding it, if anywhere, into "Engineering"/"Diagram Studio"). This is a small but real naming/inventory drift between generations, separate from the accent-color and geometry contradictions.

**True Studios vs. contextual capabilities:** per the destination-vs-capability rule (§4), the corpus is internally consistent that Objects, Relationships, Graph, Validation, Evidence, Provenance, History, and Packages are capabilities, not Studios — this rule is never violated by a written specification anywhere in the corpus. It is arguably violated by one render (see §14 C3, the EAM Dashboard render).

---

## 8. EAM UX

Source: `docs/architecture/ux/eam/*` (8 files — see §3 for the full split), `renders/eam/EAM.png`, and the EAM panels inside `renders/oep-home/home.png` / `renders/oep-shell/oep.png`.

**Recovered acquisition workspace model** (consistent across both generations of spec and all three EAM-bearing renders):

- **Workflow stages:** `SOURCE → DOWNLOAD → VERIFY → EXTRACT → REVIEW → PUBLISH`, rendered as a horizontal stepper with complete/in-progress/pending states, plus a `COMPLETE`/`FAILED`/attention state per `EAM_INTERACTION_STATE_SPEC.md`.
- **Navigation:** `Home / Sources / Acquisitions / Reference Vault` as the EAM-local left rail (per `01_OEP_SHELL_UX_DESIGN_SPEC.md`, `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`, and both composite renders), with an "Active Acquisitions" / "Completed" grouped list beneath it.
- **Workspace = one acquisition**, opened as a workspace tab (e.g. "Honda TRX300 Service Manual"), consistent with the Studio/Workspace model in §4 — EAM does not present acquisitions as a flat list-only page; an open acquisition is a first-class workspace with its own contextual navigation (`Overview / Document View / Metadata / Detected Content / Objects / Relationships / Validation / Evidence / History`).
- **Contextual tools inside a step:** e.g. the Extract step shows a document preview, extraction progress, and a running checklist (parsed / text extracted / analyzing diagrams / identifying specifications / …), consistent across `eam/EAM.png` and the two composite renders.
- **Inspection:** a "Knowledge Candidate" detail view (e.g. "Ignition Coil") with Overview/Source Evidence/Relationships/Graph/Validation/Properties/History tabs and Accept/Modify/Reject actions — recovered identically in `renders/oep-home/home.png` panel 3 and `renders/oep-shell/oep.png` panel 3.
- **Evidence/provenance:** page-level evidence thumbnails (diagram + photo) attached directly to the object being reviewed, matching `OEP_CONTEXTUAL_CAPABILITY_SPEC.md` §7's rule that evidence must be reachable directly from the object, not a separate destination.
- **Status:** per-acquisition status chips (Extracting / Pending Review / Verifying / Published / Queued / Failed) recovered consistently in `eam/EAM.png` panel 2 and both composite renders.
- **Validation:** `Run Validation`, pass/fail checklist with specific failure reasons (e.g. "Confidence below auto-accept threshold (94% < 95%)"), recovered in the object-detail panel of both composite renders.
- **Relationship to the global OEP shell:** in every render and every spec, EAM sits *inside* the standard OEP shell (Application Header / Studio Bar / Workspace Bar / Context Nav / Surface / Inspector) — EAM introduces no independent chrome, confirming `OEP-UI-RULES.md` Rule 5 ("do not create a Studio-specific imitation of the OEP shell") is honored by every EAM artifact this audit found.

**EAM is correctly treated as a Studio/workspace implementation of the broader OEP UX architecture, not an independent application**, exactly as the work package instructed to verify — this is true of every EAM artifact in the corpus without exception.

**One render is the outlier:** `renders/eam/EAM.png` panel 1 is labeled "EAM – Dashboard" and uses a KPI-tile landing page (Active Acquisitions / Awaiting Review / Published Today / Total Sources) as EAM's own entry point, and its own global Studio Bar reads `Engineering | EAM | Exchange | Knowledge | Settings` — omitting Home, Diagram Studio, and Instruments entirely. This is the oldest-looking artifact in the EAM render set (see §10, §14 C3) and is flagged as **HISTORICAL VISUAL REFERENCE**, not current direction.

**Fragmentation, not contradiction, in the written specs:** `EAM-ACQUISITION-WORKSPACE-SPEC.md`/`EAM-INTERACTION-STATE-SPEC.md` (README-listed authority) and their `EAM_*` counterparts describe the *same* workflow/state model in different words and different structure, confirmed by direct diff of the two "Interaction and State" documents (they share the same title, the same `SOURCE→DOWNLOAD→VERIFY→EXTRACT→REVIEW→PUBLISH` workflow, and the same workspace/workflow-state separation rule, but are independently written, 139 vs. 87 lines, organized differently). Neither document is wrong; neither supersedes the other in writing. See §14 C4 and §16.

---

## 9. Diagram Studio UX

Source: `implementation/DS-GOLDEN-WORKSPACE-SPEC.md` (Screen ID `DS-WORKSPACE-A`), cross-checked against `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md`'s worked example and the pre-existing `platform/oep_studio/docs/DIAGRAM_STUDIO_*` implementation-architecture corpus (inspected for boundary language only, not re-derived).

**Recovered screen hierarchy:**

```text
OEP Application
└── Diagram Studio
    └── Open Diagram Workspace
        ├── Context Navigation / diagram tree
        ├── Diagram Toolbar
        ├── Wiring Diagram Surface
        └── Property / Selection Inspector
```

**Recovered ownership boundary (the specific thing the work package asked to be recovered, not reinvented):** `DS-GOLDEN-WORKSPACE-SPEC.md` §3 and §4 state plainly that "existing diagram data, interaction model, renderer, command behavior, and Engine bridge remain authoritative," and §8's non-goals explicitly forbid "replacing the Legacy V2 renderer solely for visual reasons," changing the diagram data model, or changing bridge protocols. In the vocabulary the work package uses:

- **ENGINEERING STATE** (diagram data, commands, Engine bridge) — owned by Engine/Legacy V2, untouched by any UX work in this corpus.
- **VIEW STATE / SELECTION / LAYOUT / RENDERING** — the diagram surface's internal concern, hosted (not owned, not reimplemented) inside the new shell's Primary Engineering Surface region.
- **Studio's own scope** is limited to *where* that existing surface sits inside the new shell (Context Navigation, Workspace Bar, Inspector, Toolbar chrome around it) — not what it renders or how.

This is the same boundary `OEP-SHELL-COMPONENTS.md` §7/§10 states in general terms ("the shell must not dictate the internal rendering implementation... Engine remains authoritative for... rendering where established by the architecture"), applied specifically to Diagram Studio. No contradiction found between the general shell rule and Diagram Studio's own spec.

**Interaction rules recovered:** selecting a diagram entity updates contextual inspection; contextual tools stay near the work they affect; opening another work item uses the Workspace Bar, not a new top-level Studio; Objects/Relationships/Graph/Validation remain contextual, not global, inside Diagram Studio too.

**Visual target recovered:** "restrained blue active state" (singular) — Diagram Studio's own spec is written entirely in terms of the single-accent model (§5), predating the per-Studio-color generation. It has not been updated to say whether Diagram Studio's chrome should now use "Diagram Studio blue" (which happens to already be blue in the new per-Studio scheme, so this specific Studio's own color would not visibly change either way — but the *document* itself has not been reconciled).

**No render exists that is specific to Diagram Studio's shell integration.** The composite renders and the curated wireframe set both show Diagram Studio only as an *inactive* tab in the global Studio Bar, or (in `oep-shell/oep.png` panel 5, "Diagram Studio Integration") as a small preview strip. No DR-UX-001..007-equivalent render exists for `DS-WORKSPACE-A` itself. This is a genuine gap, not a contradiction — see §17.

---

## 10. Render Inventory

**Current set** (post user curation, mid-audit — see §2):

| File | Classification | Contents |
|---|---|---|
| `renders/oep-home/home.png` | **CURRENT VISUAL REFERENCE** | 4-panel composite: OEP Home, EAM Acquisition Workspace (Extract step), EAM Contextual Views (Object/Relationship/Validation), Repository Browser. Single blue accent throughout. |
| `renders/oep-shell/oep.png` | **CURRENT VISUAL REFERENCE**, appears to be a later/more complete iteration of `oep-home/home.png` (same scenario data — Honda TRX300, GL1200, Ford Ranger PCM — more chrome: notification bell, avatar, richer stepper icons, added panels 5-6 "Diagram Studio Integration" and "Visual Workflow Summary") | 6-panel composite. Single blue accent throughout — no per-Studio color anywhere in this file. |
| `renders/eam/EAM.png` | **HISTORICAL VISUAL REFERENCE** (see §8, §14 C3) | 6-panel EAM-only composite: Dashboard, Acquisition List, Acquisition Workspace, Extract Metadata, Engineer Review, Publish. Global Studio Bar omits Home/Diagram Studio/Instruments. Single blue accent. |
| `.../App Header with OEP Logo.png` | **CURRENT VISUAL REFERENCE** (Section 01 of the numbered wireframe series) | Application Header region only: logo, search, system status, notifications, account, window controls. |
| `.../Start With this Exact Wireframe and its Pixel Measurments.png` | **CURRENT VISUAL REFERENCE**, explicitly designated primary by the user for layout/geometry | 8-region pixel-dimensioned frame diagram (see §6, §14 C2 for the exact numbers and where they disagree with the token document). |
| `.../Status bar use option 2.png` | **CURRENT VISUAL REFERENCE** (decided option, of 5 shown) | "COMPACT (LOW PROFILE) / Minimal Height / Essential" — the option filename records as selected. |
| `.../studio tab bar use option 3.png` | **CURRENT VISUAL REFERENCE** (decided option, of 5 shown) | "DUAL-TONE ANGLED (PREMIUM)" — angled/chamfered tab geometry, **per-Studio accent color** (Home neutral, Diagram Studio blue, EAM green/teal, Knowledge gold, Exchange purple, Tools red, Settings slate). This is the source of the color rule also written into `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`. |
| `.../toolbar 7 use option 3.png` | **CURRENT VISUAL REFERENCE** (decided option, of 6 shown) | "GROUPED SECTIONS / Clean Organized / Labeled Groups" — command groups labeled (FILE/EDIT/VIEW/TOOLS/SIMULATION/DIAGRAM/MORE), monochrome button styling (does **not** use the rainbow per-group coloring shown in that same sheet's Option 4). |
| `.../workspace context tab bar.png` | **EXPERIMENTAL / styling reference only, not behavioral authority** (confirmed with the user directly during this audit) | Demonstrates "tabs inherit parent Studio accent color" applied down to the workspace-tab level, across all Studios. The EAM row's example tab labels ("ECU Programming," "Module Configuration," "DTC Library," "Flash Files," "Calibration Data") describe an automotive ECU-tuning/diagnostic tool and do **not** correspond to EAM's actual acquisition-pipeline domain (§8) — placeholder content, not a design requirement. The color-inheritance *pattern* itself is a real, usable finding; the EAM *content* shown is not. |

**Superseded/removed during this audit (recorded for history, no longer present on disk):** 10 numbered `ChatGPT Image Sep 15, 2026, HH_MM_SS AM.png` files (01:58–04:06 AM, a single continuous exploration session), an earlier `Status bar.png` (5-option sheet, superseded by the "use option 2" file above, though visually identical content — the earlier file had no option selected, the current one is the same sheet recorded as decided), an earlier `studio tab bar.png` and `workspace context tab bar.png`, and a generic `wireframe.png`. This audit viewed the earlier `Status bar.png` before removal and confirmed it is the same design sheet as the retained `Status bar use option 2.png` — the removal did not lose any distinct design content for that component, only removed the file before its filename recorded which option was chosen. The 10 `ChatGPT Image...` files were not re-inspected after removal; no written specification depends on them, and the render index (`OEP_UX_RENDER_REFERENCE_INDEX.md`) never named them individually (see below).

**`OEP_UX_RENDER_REFERENCE_INDEX.md` is stale relative to the actual files on disk.** It names 7 renders as `DR-UX-001` through `DR-UX-007` (OEP Home, OEP Studio Shell, EAM Acquisition Workspace, Object Detail, Diagram Integration, Validation, Repository Browser) — none of the actual files on disk are named `DR-UX-00N`. The described *content* maps reasonably well onto panels **within** `oep-home/home.png` and `oep-shell/oep.png` (both are multi-panel composites bundling several of the seven concepts into one file), but the index was written as if seven separate, individually-named files existed, and it predates the entire curated wireframe series (§2) — it names nothing from that set at all. This index needs to be rewritten against the actual current file set, not merely re-pointed.

---

## 11. Render / Specification Reconciliation

| Render | Specification | Visual elements present | Behavior implied | Behavior specified | Differences | Authority | Disposition |
|---|---|---|---|---|---|---|---|
| `oep-home/home.png`, `oep-shell/oep.png` | `OEP_HOME_UX_SPEC.md`, `OEP-UX-ARCHITECTURE.md` §4 | Continue Working, Recent Work, Available Studios, System Status | Matches spec region-for-region | Matches | None found | Both agree | No action |
| `oep-home/home.png` / `oep-shell/oep.png` EAM panels | `eam/EAM-ACQUISITION-WORKSPACE-SPEC.md`, `eam/EAM_ACQUISITION_WORKFLOW_SPEC.md` | Stepper (Source→Download→Verify→Extract→Review→Publish), workflow rail, per-acquisition status | Matches spec workflow model | Matches | None found | Both agree | No action |
| `eam/EAM.png` | `OEP-UX-ARCHITECTURE.md` §4 ("A global Dashboard is not a first-class Studio destination"), README.md's DASHBOARD.md supersession note | "EAM Dashboard" KPI-tile landing page as EAM's entry point; Studio Bar omits Home/Diagram Studio/Instruments | Implies Dashboard-as-landing is still current for at least EAM | Explicitly superseded for the *global* landing model; Studio-specific dashboards are conditionally permitted "where they provide genuine workflow value" but no document actually authorizes *this* one, and the missing Studio Bar entries are unexplained by any spec | Render shows a pattern the architecture text calls superseded, without the "genuine workflow value" justification the carve-out requires being written anywhere | Architecture text (per the stated hierarchy, §13) | **HISTORICAL** — do not build against this render's Studio Bar or landing pattern without a fresh, explicit decision |
| `studio tab bar use option 3.png`, `workspace context tab bar.png` (color inheritance), `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` COLOR RULE | `OEP-DESIGN-TOKENS.md` §2 (single `oep.accent`), `OEP-UX-ARCHITECTURE.md` §10, `OEP_UX_RENDER_REFERENCE_INDEX.md` "blue primary interaction accent" | Explicit per-Studio accent palette, angled/chamfered tab geometry | Multi-color Studio identity system | Single restrained blue accent, no "arbitrary new accent colors" | Direct disagreement — see §14 C1 | **Unresolved — see §14 C1's recommendation** | Needs an explicit decision before implementation |
| `Start With this Exact Wireframe...png` | `OEP-SHELL-COMPONENTS.md` §1 anatomy, `OEP-DESIGN-TOKENS.md` §3 geometry | Toolbar as full-width row below the 3-column split; 42px workspace/context bar; 60px toolbar | Different structural position and different measured heights | Toolbar nested inside the middle column; 36px/40px | Direct disagreement — see §14 C2 | **Unresolved — see §14 C2's recommendation** | Needs an explicit decision before implementation |
| `workspace context tab bar.png` EAM row content | `eam/*` (all 8 files) | "ECU Programming / DTC Library / Flash Files / Calibration Data" | Implies EAM does ECU tuning/flashing | EAM is a document/knowledge acquisition pipeline (Source→Download→Verify→Extract→Review→Publish for engineering documents) | Content mismatch, confirmed with the user as placeholder | Specification | **No action needed** — already classified EXPERIMENTAL, content disposable, styling pattern retained |
| `toolbar 7 use option 3.png` command groups | `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` §02 (Diagram Studio command matrix) | FILE/EDIT/VIEW/TOOLS/SIMULATION/DIAGRAM/MORE | Matches | Matches | None found | Both agree | No action |

---

## 12. Legacy vs. Current UX

| Assumption / document | Classification | Evidence |
|---|---|---|
| `platform/oep_studio/docs/DASHBOARD.md` (Dashboard-as-landing) | **SUPERSEDED** | Already carries its own supersession notice pointing at `OEP-UX-ARCHITECTURE.md`; confirmed unmodified since. |
| `platform/oep_studio/docs/OEP_INTERACTION_MODEL.md` | **MIGRATION MATERIAL** | `README.md`'s own table: "Retain. Behavioral interaction findings remain useful. Navigation assumptions must be reconciled against the new OEP UX architecture before new UX work." Confirmed status line: "Proposed architectural specification — not yet ratified." Not superseded, not current authority either — genuinely in between. |
| `platform/oep_studio/docs/OEP_SURFACE_ARCHITECTURE.md` | **MIGRATION MATERIAL** | Same table entry: "Retain as historical/derived architecture... new global navigation should follow this UX architecture." Self-declared "DERIVED/PROPOSED — NOT RATIFIED." |
| `platform/oep_studio/docs/DESIGN_LANGUAGE.md` (SDD-002) | **LEGACY, pending reconciliation** | `README.md`: "Retain pending design-system reconciliation. It should not be treated as a complete replacement for the new visual baseline." Self-declared "Draft." Not inspected in depth by this audit beyond its header (out of scope: this is a Studio-layer document, not part of the `docs/architecture/ux/` corpus itself). |
| `renders/eam/EAM.png`'s Dashboard-first EAM landing + truncated Studio Bar | **LEGACY / SUPERSEDED** (by the architecture text, not by an explicit render revision) | See §11 row 3, §14 C3. |
| Browser-style tabs, route-per-destination architecture | **CURRENT (explicitly prohibited)** — not found as an active design assumption anywhere in this corpus; called out defensively and repeatedly (`OEP-UX-ARCHITECTURE.md` §3, `OEP-SHELL-COMPONENTS.md` §3/§4, `OEP-UI-RULES.md` prohibited patterns, `.claude/skills/oep-ui/SKILL.md` hard constraints) | Every document that mentions this pattern does so only to forbid it. No document or render in this corpus proposes it. |
| Permanent left navigation, "destination-driven navigation" (every subsystem as a top-level route) | **CURRENT (explicitly prohibited)** as a *global* pattern; **CURRENT and required** as a *Studio-local* Context Navigation pattern | The destination-vs-capability rule (§4) is precisely the mechanism that keeps this distinction intact — global nav is Studio-only, left navigation *inside* an active Studio is expected and specified everywhere (EAM's own left rail, Diagram Studio's context tree). |

No legacy document was deleted, rewritten, or had its status changed by this audit.

---

## 13. UX Authority Model

The work package's starting hierarchy —

```text
Architecture -> UX/interaction specification -> Design system/tokens -> Studio-specific specification -> Design render -> Implementation
```

— is **confirmed as the correct model** by direct textual evidence: `OEP-UX-ARCHITECTURE.md` §12 states its own source-of-truth rule ("Architecture/specification defines behavior and hierarchy. Design renders define visual reference and spatial intent. A render must not silently introduce behavior that is absent from the specification."), and `OEP_UX_RENDER_REFERENCE_INDEX.md` restates the same rule independently ("Renders are visual references and do not replace behavioral specifications... Reconcile render/spec conflicts before implementation").

**One repository-specific refinement, not an exception:** within "Design render," this audit found the corpus itself distinguishes **decided** renders from **exploratory option sheets** — the curated wireframe folder's file names (`... use option 2`, `... use option 3`) are themselves a real, if informal, authority signal: they record a decision made *among* renders, which the plain five-level hierarchy above doesn't have a slot for. This audit treats a "use option N" filename as higher authority than an un-selected option sheet, but still subordinate to written specification.

**One place the hierarchy is currently ambiguous, not exceptioned:** where two *specification-level* documents disagree (§14 C1, C2), the stated hierarchy gives no tiebreaker — both are "UX/interaction specification" or "design system/tokens" tier. This audit does not invent a tiebreaker rule; §14 records both sides and recommends resolution by explicit decision, not by silently picking one.

**No document anywhere claims a render can override written behavior.** The hierarchy is intact; it has not been violated by any artifact in this corpus. What is missing is a mechanism for resolving disagreement *between* documents at the same tier — see §17.

---

## 14. Contradictions and Gaps

| ID | Location | Conflict | Evidence | Classification | Likely authority | Recommended resolution |
|---|---|---|---|---|---|---|
| **C1** | `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` COLOR RULE + `studio tab bar use option 3.png` + `workspace context tab bar.png` **vs.** `OEP-DESIGN-TOKENS.md` §2 + `OEP-UX-ARCHITECTURE.md` §10 + `OEP_UX_RENDER_REFERENCE_INDEX.md` + `DS-GOLDEN-WORKSPACE-SPEC.md` §5 | Per-Studio accent color system vs. single restrained-blue-accent system | Direct textual/visual comparison, §5 vs. §10/§14 above | **SIGNIFICANT** (visible on every screen, but resolvable by documentation update alone — no code exists yet to migrate) | Genuinely unresolved — three older, independent documents agree on single-accent; two newer, user-curated artifacts agree on per-Studio, and the user directly selected "studio tab bar use option 3" (the per-Studio version) during this audit, which is itself evidence of current intent | Do not silently pick one. Ask the design owner explicitly: is the per-Studio accent system the new direction? If yes, `OEP-DESIGN-TOKENS.md` §2 and `OEP-UX-ARCHITECTURE.md` §10 need a documented update (new tokens per Studio) before any implementation WP references them. If no, the toolbar matrix's COLOR RULE section and the two renders need to be marked historical. |
| **C2** | `Start With this Exact Wireframe and its Pixel Measurments.png` **vs.** `OEP-SHELL-COMPONENTS.md` §1 anatomy + `OEP-DESIGN-TOKENS.md` §3 (`oep.toolbar.height`=40px, `oep.workspace.height`=36px) | Toolbar position (full-width row below the 3-column split vs. nested inside the middle column) and two measured heights (60px vs. 40px toolbar; 42px vs. 36px workspace/context bar) | Direct pixel comparison, §6/§11 above | **SIGNIFICANT** (structural layout, but again purely a documentation gap, not yet built) | The user explicitly designated this wireframe as the starting point ("Start With this Exact Wireframe") during this audit's own file curation, which is direct evidence of current intent, but `OEP-SHELL-COMPONENTS.md`/`OEP-DESIGN-TOKENS.md` have not been updated to match | Update `OEP-DESIGN-TOKENS.md`'s two height tokens and `OEP-SHELL-COMPONENTS.md`'s anatomy diagram to match the wireframe, or explicitly reject the wireframe's numbers — do not leave both in the corpus as if they agree. |
| **C3** | `renders/eam/EAM.png` panel 1 ("EAM – Dashboard") + its own Studio Bar | Dashboard-as-landing pattern the architecture text calls superseded; Studio Bar omits Home, Diagram Studio, Instruments | §8, §11 above | **SIGNIFICANT** for EAM specifically; **MINOR** platform-wide (this is the only artifact with this problem) | Architecture text (`OEP-UX-ARCHITECTURE.md` §4, README's DASHBOARD.md note) — this render is the oldest-looking artifact with no filename evidence of being a "decided option" | Mark `renders/eam/EAM.png` as historical in `OEP_UX_RENDER_REFERENCE_INDEX.md` once that index is rewritten (§10); do not use its landing pattern or Studio Bar as a reference for new work. |
| **C4** | `eam/EAM-INTERACTION-STATE-SPEC.md` (README-listed authority) **vs.** `eam/EAM_INTERACTION_STATE_SPEC.md` (not README-listed) | Two independently-authored documents, same title, same subject (workflow + workspace state model), different structure/length, neither marked superseded | Direct diff, §8 above | **MINOR** (no found behavioral disagreement between them — the underlying state model is actually the same; the problem is duplication, not conflict) | Both, jointly — neither invalidates the other | Merge into one document, or explicitly designate one as canonical and mark the other historical, before further EAM UX work. The same applies to `EAM-ACQUISITION-WORKSPACE-SPEC.md` vs. `02_EAM_ACQUISITION_WORKSPACE_SPEC.md`, which this audit did not diff line-by-line but confirmed cover overlapping ground (§3, §8). |
| **C5** | `README.md` "Authority" file tree | Lists only the original 9 files (`OEP-UX-ARCHITECTURE.md`, the 3 design-system docs, the 4 implementation docs, and 2 of the 8 EAM docs); does not mention any of the 8 second-generation files (`01_`, `03_`, `OEP_CONTEXTUAL_CAPABILITY_SPEC.md`, `OEP_HOME_UX_SPEC.md`, `OEP_STUDIO_TAB_WORKSPACE_SPEC.md`, `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md`, `SECTION-8-STATUS-BAR-SPEC.md`, `OEP_UX_RENDER_REFERENCE_INDEX.md`) or the 6 second-generation EAM docs, or the curated render folder | Direct comparison of `README.md`'s tree against `find docs/architecture/ux -type f` | **SIGNIFICANT** — this is the document a new implementation agent is told to read first, and it is silent about roughly half the corpus | Second-generation files are real, current, and (per C1/C2) sometimes in direct tension with what README points to — README is simply out of date, not wrong about what it does list | Rewrite `README.md`'s Authority tree to include the full current file set, and have it explicitly state the C1/C2/C4 open questions rather than implying a single, settled document set. |
| **C6** | Self-referential "Storage:" paths in `OEP_STUDIO_TAB_WORKSPACE_SPEC.md`, `OEP_CONTEXTUAL_CAPABILITY_SPEC.md`, `OEP_HOME_UX_SPEC.md`, `OEP_UX_RENDER_REFERENCE_INDEX.md` | Each file's own header states a hyphenated storage path (e.g. `OEP-STUDIO-TAB-WORKSPACE-SPEC.md`) that does not match its actual underscored on-disk filename | Direct inspection of each file's own line 4 | **COSMETIC** | N/A | Fix the four header lines to match actual filenames, or standardize the whole corpus on one naming convention (the newer generation is entirely underscored; the older generation is entirely hyphenated) — this is a good opportunity to also resolve the naming-convention split itself. |
| **C7** | `OEP-UX-ARCHITECTURE.md` Studio Bar list ("Engineering Intelligence", "Instruments") **vs.** `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` / curated renders ("Tools", no separate "Engineering Intelligence") | Studio-name/inventory drift, §7 above | Direct comparison | **MINOR** | Unresolved | Decide the final Studio Bar inventory and naming once, in one document, and have every other document reference it rather than restate it. |
| **G1** | No design-to-code comparison exists anywhere in the repository | `WP-UI-DS-001-PROMPT.md` Step 1 requires one to be produced; none has been, per `git log`/file search | N/A — absence, not conflict | Gap | N/A | See §17/§19. |
| **G2** | No render or spec exists for Knowledge Studio, Engineering Exchange, Engineering Intelligence, Settings, or Search beyond a Studio Bar entry and (for some) a toolbar command list | Repository-wide search, §7 | N/A — absence | Gap | N/A | Out of scope for the recommended next WP (§17); recorded for future planning. |

---

## 15. What Is Already Designed

```text
GLOBAL OEP
    Navigation hierarchy (Studio/Workspace/Contextual/Capability)   DESIGNED
    Destination-vs-capability rule                                  DESIGNED
    Interaction grammar (OPEN->SELECT->INSPECT->...->VALIDATE)      DESIGNED
    Application shell anatomy + region ownership                    DESIGNED (two disagreeing geometries, C2)
    Design tokens (color/geometry/typography)                       DESIGNED (color model contested, C1)
    Application Header                                              DESIGNED (render exists)
    Global Studio Bar                                                DESIGNED (two disagreeing color/geometry treatments)
    Workspace Bar / Studio Tab mechanics                            DESIGNED (persistence, overflow, cross-Studio transitions)
    Status Bar                                                       DESIGNED (customizable concept; one option selected)
    Toolbar / Action Strip, per-Studio command matrix                DESIGNED (one option selected)
    Home                                                             DESIGNED (spec + 2 renders)
    Contextual capability behavior (Objects/Relationships/Graph/
        Validation/Evidence/Provenance/History/Packages)             DESIGNED
    Implementation skill + sectional workflow + visual QA protocol  DESIGNED

EAM
    Acquisition workspace / workflow model                          DESIGNED (fragmented across 2 generations, C4)
    Navigation / contextual tree                                    DESIGNED
    Object/relationship/evidence/validation inspection               DESIGNED
    Repository Browser                                               DESIGNED

DIAGRAM STUDIO
    Screen hierarchy / region composition                           DESIGNED
    Engine/Studio rendering-ownership boundary                      DESIGNED (recovered, not reinvented)
    Visual target                                                    DESIGNED (not yet reconciled with C1)
    Dedicated integration render                                     NOT DESIGNED (gap, see §14 G2's sibling note in §9)
```

Nothing above is marked designed merely because code exists — this audit did not inspect Flutter/Dart source to make any of these determinations; every line above is backed by a specification document, a render, or both, cited in §4–§11.

---

## 16. What Remains to Be Designed

1. **A single, reconciled accent-color decision** (C1) — resolve or explicitly ratify the per-Studio color system, and update the token/architecture documents to match whichever way it goes.
2. **A single, reconciled shell-geometry decision** (C2) — resolve the toolbar position and the three disputed pixel heights.
3. **EAM specification consolidation** (C4) — one canonical acquisition-workspace spec and one canonical interaction/state spec, not two of each.
4. **A rewritten `README.md` authority index and `OEP_UX_RENDER_REFERENCE_INDEX.md`** (C5, §10) reflecting the actual current file set and actual current renders.
5. **A dedicated Diagram Studio shell-integration render** (§9, §14 G2) — every other Studio with real UX depth (Home, EAM) has at least one composite render; Diagram Studio's only visual reference is a small preview strip inside `oep-shell/oep.png` panel 5.
6. **A design-to-code map for the current Flutter implementation** (§14 G1) — required by `WP-UI-DS-001-PROMPT.md` itself, not yet produced by any prior work in this repository.
7. **Studio-name/inventory finalization** (C7) — "Instruments" vs. "Tools," and whether "Engineering Intelligence" remains a distinct Studio Bar entry.
8. Genuinely **not yet begun**, and out of scope for the immediate next step (§17): dedicated UX depth for Knowledge Studio, Engineering Exchange, Engineering Intelligence, Settings, and Search beyond their Studio Bar entry and (for some) a toolbar command list; responsive/tablet design; Inspector cross-Studio visual consolidation beyond the one shared component-ownership rule already written.

**What does not need to be designed again:** the navigation hierarchy, the destination-vs-capability rule, the interaction grammar, the Home spec, the EAM workflow model's substance (only its document structure needs merging), the shell's region *list* and ownership rules (only its geometry needs reconciling), and the implementation skill/protocol. Redesigning any of these from scratch would discard real, working, internally-consistent design work in order to solve a documentation-reconciliation problem — exactly what this work package was instructed not to do.

---

## 17. Recommended Next UX Work Package

The evidence does not support "redesign the shell" or "design Home" — both are already designed, in two consistent-with-themselves generations that disagree with each other in specific, enumerable ways (C1, C2), plus a smaller set of duplication/staleness problems (C4, C5, C6, C7) that are pure documentation work. It also does not support "existing renders are already sufficient, begin implementation" — `WP-UI-DS-001-PROMPT.md` is genuinely ready to execute *by its own text*, but it was written against the single-accent, nested-toolbar generation, and beginning implementation now risks building the wrong (or soon-to-be-revised) version of the shell chrome, then redoing it once C1/C2 are settled.

**The actual next UX design problem is reconciliation, not new visual design and not implementation.** This is a natural, proposed **AP-UX-002**:

```text
AP-UX-002 — OEP UX Design System Reconciliation

Purpose:
    Resolve the specific, enumerated contradictions and staleness
    problems this audit (AP-UX-001) found, so that a single, internally
    consistent design baseline exists before any implementation WP
    (including the already-written WP-UI-DS-001) is executed or
    re-issued.

Problem:
    Two generations of OEP UX design work coexist and disagree on:
    accent-color model (single blue vs. per-Studio), toolbar
    position/height, and workspace/context-bar height (C1, C2). EAM has
    two independently-written specifications for the same behavior
    (C4). The directory's own authority index (README.md) and render
    index (OEP_UX_RENDER_REFERENCE_INDEX.md) do not reflect roughly
    half of the actual current file set (C5, §10).

Scope:
    - Decide C1 (accent-color model) and update OEP-DESIGN-TOKENS.md /
      OEP-UX-ARCHITECTURE.md / DS-GOLDEN-WORKSPACE-SPEC.md accordingly.
    - Decide C2 (toolbar position, the three disputed pixel heights)
      and update OEP-SHELL-COMPONENTS.md / OEP-DESIGN-TOKENS.md
      accordingly.
    - Merge or explicitly supersede the duplicate EAM specifications
      (C4), and the duplicate OEP-level shell/navigation specs
      (01_/03_ vs. OEP-UX-ARCHITECTURE.md, which this audit found
      consistent in substance but still worth merging to remove the
      duplication itself).
    - Rewrite README.md's Authority tree and
      OEP_UX_RENDER_REFERENCE_INDEX.md against the actual current file
      set (post this audit's curation).
    - Fix the C6 filename self-references and pick one naming
      convention for the directory going forward.
    - Resolve C7 (Studio Bar naming/inventory).

Inputs:
    This document (AP-UX-001-UX-DESIGN-RECOVERY.md), every file listed
    in its §3 inventory, and an explicit design-owner decision on C1/C2
    (this cannot be resolved by an agent alone -- both sides are
    legitimate, deliberate design work; picking one silently would be
    exactly the kind of arbitrary redesign this audit was told not to
    do).

Outputs:
    Updated design-system/shell/EAM documents with contradictions
    removed; a rewritten README.md and render index; no new renders,
    no new architecture, no Flutter changes.

Out of scope:
    Any Flutter/Dart implementation; any new visual exploration beyond
    what already exists; Knowledge Studio / Exchange / Intelligence /
    Settings / Search UX depth (G2); a Diagram Studio integration
    render (item 5 in §16 -- worth doing, but is new design work, not
    reconciliation, and should be sequenced after AP-UX-002 or folded
    into a revised WP-UI-DS-001).

Acceptance criteria:
    - C1 and C2 each have exactly one documented answer, referenced
      consistently across every document that currently states a
      position on them.
    - EAM has exactly one acquisition-workspace spec and one
      interaction/state spec.
    - README.md's Authority tree lists every current file; no file
      exists in docs/architecture/ux/ that README.md doesn't know about.
    - OEP_UX_RENDER_REFERENCE_INDEX.md names the actual current render
      files, not a filename convention that does not exist on disk.
    - WP-UI-DS-001-PROMPT.md's "Read first" list is re-verified against
      the reconciled document set (it may need one line added if C1/C2
      resolution produces a new canonical document).
```

**AP-UX-002 is proposed, not begun.** No file under `design-system/`, `implementation/`, `eam/`, `README.md`, or the render index was modified by this audit beyond the creation of this one recovery document.

---

## 18. Design Principles to Preserve

Regardless of how C1/C2 resolve, the following are corroborated by every generation of the corpus and should not be relitigated by AP-UX-002 or any later work:

1. Studios are destinations; backend capabilities (Objects, Relationships, Graph, Validation, Evidence, Provenance, History, Packages) are contextual, with Repository as the one named, deliberate exception.
2. The interaction grammar (OPEN WORK → SELECT/FOCUS → INSPECT → VIEW RELATED CONTEXT → PERFORM CONTEXTUAL OPERATION → VALIDATE/VERIFY) applies across every Studio.
3. Native OEP tabs, never browser-style chrome, at either the Studio or Workspace level.
4. The shell does not own or reimplement a Studio's engineering surface — Diagram Studio's Engine/Legacy-V2 bridge boundary (§9) is the concrete instance of a general rule (§6).
5. Dark, compact, information-dense, "professional engineering workstation" identity — explicitly not a consumer SaaS dashboard, not glassmorphism, not purple/AI gradients, not oversized hero content.
6. Design renders are visual reference; written specification is behavioral authority; a render must never silently introduce undocumented behavior (§13).
7. 1920×1080 as the explicit desktop baseline for every primary render and every visual-QA capture.
8. Explicit geometry beats approximation — every region should have a stated pixel target, not an inferred one, once C2 is resolved.

---

## 19. Implementation Readiness

**Not ready to begin general Flutter implementation.** Two specification-level contradictions (C1, C2) are directly visible in whatever screen is built first, and building against either generation right now means redoing that work once the contradiction is resolved.

**`WP-UI-DS-001-PROMPT.md` specifically is well-written and largely usable, but stale in one concrete way:** its own "Read first" list (8 documents) does not include any of the eight second-generation files, and its priority order ("correct region geometry" as step 3, "OEP visual tokens" as step 4) assumes there is one settled geometry and one settled token set to implement against — which is not yet true (C1, C2). It should be re-issued (not necessarily rewritten from scratch — its structure, prohibitions, and QA protocol are sound) once AP-UX-002 produces a reconciled baseline for it to reference.

**The implementation skill (`.claude/skills/oep-ui/SKILL.md`) is sufficient as written.** Its mandatory-reading list, section sequence (00–08, matching the wireframe's own 01–08 numbering and `SECTION-8-STATUS-BAR-SPEC.md`'s numbering), hard constraints, and escalation rule are all consistent with the rest of the corpus and require no competing skill or modification to execute AP-UX-002's own documentation work or a future, reconciled WP-UI-DS-001. No gap was found in it.

**No design-to-code map exists yet** (§14 G1) — this is required by `WP-UI-DS-001-PROMPT.md` itself as its first step, not something AP-UX-001 was scoped to produce (it requires inspecting the current Flutter implementation, which this audit's own instructions prohibited).

---

## 20. AAR

```text
AP-UX-001 — OEP UX Design Recovery & Consolidation

RESULT:
COMPLETE

BASELINE:
7e09770 (verified via git rev-parse HEAD before any work began; matched
the required baseline exactly, no discrepancy)

FINAL COMMIT:
recorded in the work-package response, created immediately after this
file

UX ARTIFACTS INSPECTED:
27 Markdown documents, 9 render images (post user curation), 1
implementation skill file, plus 4 Studio-layer documents in
platform/oep_studio/docs/ inspected for reconciliation-status only.
Major categories: master UX architecture (1), second-generation shell/
navigation specs (2), design-system/tokens (3), implementation
contracts (5, incl. the ready-to-execute WP-UI-DS-001-PROMPT.md), EAM
specs (8, split across two generations), render index (1).

RENDERS RECOVERED:
9 current: oep-home/home.png, oep-shell/oep.png, eam/EAM.png (historical,
see below), App Header with OEP Logo.png, Start With this Exact
Wireframe and its Pixel Measurments.png, Status bar use option 2.png,
studio tab bar use option 3.png, toolbar 7 use option 3.png, workspace
context tab bar.png (experimental/styling-only, EAM content is
placeholder, confirmed with the user). 14 exploratory renders were
removed by the user during this audit (10 dated ChatGPT-generated
images plus 4 unselected/superseded option sheets) after this audit had
already inspected the equivalent content; no distinct design content
was lost.

EXISTING UX ARCHITECTURE:
Four-level navigation model (Studio/Workspace/Contextual View/
Capability), destination-vs-capability rule, and the OPEN->SELECT->
INSPECT->VIEW CONTEXT->PERFORM->VALIDATE interaction grammar are all
established, internally consistent, and corroborated across both
generations of the corpus. Status: "Proposed... pending formal
ratification" per its own header -- not yet an ADR.

EXISTING DESIGN SYSTEM:
Full color/geometry/typography token set (design-system/OEP-DESIGN-
TOKENS.md) plus a 10-rule implementation contract and prohibited-
pattern list. Single-accent color model. Contested by a newer,
user-selected per-Studio accent model (C1) and by a newer, user-
designated wireframe's differing toolbar/workspace-bar pixel heights
(C2) -- both are real, deliberate design passes, neither yet reconciled
with the token document.

EXISTING SHELL:
8-region anatomy (Header/Studio Bar/Workspace Bar/Context Nav/Surface/
Inspector/Toolbar/Status Bar) with explicit per-region ownership rules,
recovered in full. Structural disagreement with the newer pixel
wireframe on toolbar placement (nested vs. full-width row) -- see C2.

STUDIOS RECOVERED:
Home (DESIGNED), Diagram Studio (DESIGNED at UX layer, separately
IMPLEMENTED at application layer per prior WP-CTRL work), EAM
(DESIGNED, fragmented across two spec generations), Knowledge Studio /
Engineering Exchange / Engineering Intelligence / Settings / Search
(CONCEPTUAL -- named consistently, no dedicated workspace spec),
Instruments (CONCEPTUAL, also inconsistently renamed "Tools" in the
newer generation), Repository (DESIGNED as a persistent, non-Studio
destination).

EAM:
DESIGNED and correctly treated as a Studio/workspace implementation of
the broader OEP architecture in every artifact without exception. Two
independently-written specifications exist for the same workflow/state
model (not contradictory in substance, just duplicated) and one older
render (eam/EAM.png) uses a superseded Dashboard-as-landing pattern and
an incomplete Studio Bar.

DIAGRAM STUDIO:
DESIGNED at the UX/ownership-boundary layer (DS-GOLDEN-WORKSPACE-SPEC.md
recovers, rather than reinvents, the Engine/Legacy-V2-owns-rendering
boundary). No dedicated shell-integration render exists -- a real,
recorded gap, not a contradiction.

LEGACY UX:
platform/oep_studio/docs/DASHBOARD.md already carries its own
supersession notice (confirmed applied). OEP_INTERACTION_MODEL.md and
OEP_SURFACE_ARCHITECTURE.md are retained migration material, both
self-declared not-yet-ratified. DESIGN_LANGUAGE.md is a retained draft
pending reconciliation. Browser-style/route-per-destination navigation
is explicitly and consistently prohibited everywhere it is mentioned in
this corpus -- never proposed.

CONTRADICTIONS:
7 documentation contradictions (C1-C7) plus 2 gaps (G1-G2) identified
and evidenced. Significant: C1 (accent-color model: single blue vs.
per-Studio), C2 (toolbar position + 3 disputed pixel heights), C3
(one historical EAM render's superseded Dashboard/Studio-Bar pattern),
C5 (README.md's authority index omits roughly half the actual current
files). Minor/cosmetic: C4 (duplicate EAM specs, no substantive
conflict), C6 (4 files self-reference the wrong filename), C7 (Studio
naming drift, "Instruments" vs. "Tools").

WHAT IS ALREADY DESIGNED:
Navigation architecture, interaction grammar, destination/capability
rule, design tokens, shell anatomy, Home, EAM's workflow substance,
Diagram Studio's ownership boundary, the implementation skill/QA
protocol, and a ready-to-execute (if currently stale) Diagram Studio
implementation prompt. None of this needs to be redesigned.

WHAT REMAINS TO BE DESIGNED:
Reconciliation of C1/C2 (an explicit decision, not an agent-invented
default), consolidation of duplicate EAM/shell specs, a rewritten
README.md/render index, a dedicated Diagram Studio integration render,
and a design-to-code map against the current Flutter implementation.
Genuinely not started: Knowledge Studio / Exchange / Intelligence /
Settings / Search UX depth; responsive/tablet design.

RECOMMENDED NEXT WORK PACKAGE:
AP-UX-002 — OEP UX Design System Reconciliation (proposed, not begun;
full definition in Section 17 of this document). Purpose: resolve C1/
C2/C4/C5/C6/C7 so a single consistent baseline exists before
implementation begins or WP-UI-DS-001 is re-issued. Explicitly requires
a design-owner decision on C1/C2 that this audit does not make on its
own authority.

SOURCE CODE CHANGED:
NO

IMPLEMENTATION CHANGED:
NO

VERIFICATION:
- git diff --check: run before commit, clean
- git status --short: only this new file plus the pre-existing,
  unrelated working-tree material (2 Studio/EAM client files, 1 EAM
  config file, 2 EAM runtime data directories, and the user's own
  render curation, §2) -- none of it staged or committed by this audit
- Re-confirmed HEAD == 7e09770 before writing this document; no other
  commit landed on the branch during this audit

NOTES:
The user actively curated the render set mid-audit (removing 14
exploratory files, adding a folder of 6 decided-option files) and
confirmed directly that the workspace/context-tab-bar render's EAM
content ("ECU Programming," "DTC Library," etc.) is placeholder, not a
real EAM requirement. Both are treated as authoritative signals of
current intent in this document (§2, §10) rather than as noise. This
curation is itself evidence supporting C1's recommended resolution path
(the per-Studio color model is more likely to represent current
intent, precisely because the user selected it during this session)
but this document deliberately stops short of declaring C1 resolved --
that decision belongs to the design owner, explicitly, not to an
inference drawn from which files survived a cleanup pass.
```
