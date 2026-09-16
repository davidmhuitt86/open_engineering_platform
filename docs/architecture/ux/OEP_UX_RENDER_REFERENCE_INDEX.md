# OEP UX Render Reference Index

**Status:** Design reference
**Storage:** `docs/architecture/ux/OEP_UX_RENDER_REFERENCE_INDEX.md` (corrected AP-UX-002 C6 — this line previously named `docs/architecture/ux/renders/README.md`, a path that does not exist on disk)
**Reconciled by:** AP-UX-002 (G1), updated by AP-UX-005 — this index was rewritten against the actual current render files. The previous version named seven renders as `DR-UX-001` through `DR-UX-007`; no file on disk was ever named that way. See `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md` §13 and `AP-UX-005-VISUAL-DESIGN-COMPLETION.md`.

## Purpose

Define the visual references used to communicate the intended OEP/EAM UX direction. Renders are visual references and do not replace behavioral specifications (`OEP-UX-ARCHITECTURE.md` §12).

## Canonical render index

| Render | Purpose | Resolution | Status | Authority | Related specification | Demonstrates |
|---|---|---|---|---|---|---|
| `renders/Section 1,2,3, 7,8 of Wireframe UI Use These First Before moving on to the otheer section/App Header with OEP Logo.png` | Application Header region (01) | 2078×105 | **CANONICAL** | Design-owner designated (AP-UX-002 C2) | `design-system/OEP-SHELL-COMPONENTS.md` §2 | Header content/geometry; source for the header asset embedded in the shell composite below |
| `.../Start With this Exact Wireframe and its Pixel Measurments.png` | Full 8-region pixel-dimensioned shell frame | 1920×1080 | **CANONICAL** | Design-owner designated (AP-UX-002 C2) — the geometry authority `OEP-DESIGN-TOKENS.md` §3 and `OEP-SHELL-COMPONENTS.md` §1 were corrected to match | `design-system/OEP-DESIGN-TOKENS.md` §3, `design-system/OEP-SHELL-COMPONENTS.md` §1 | Region heights/widths for all 8 shell regions |
| `.../Status bar use option 2.png` | Status Bar (08) option comparison, decided option highlighted (of 5 shown) | 2078×757 | **CANONICAL** (source) | Design-owner selected ("use option 2") | `SECTION-8-STATUS-BAR-SPEC.md` | Option comparison; superseded for isolated use by `oep-shell/status-bar.svg` below |
| `.../studio tab bar use option 3.png` | Studio Tab Bar (02) option comparison, decided option highlighted (of 5 shown) | 2079×756 | **CANONICAL** (source) | Design-owner selected ("use option 3"); AP-UX-002 C1 | `design-system/OEP-DESIGN-TOKENS.md` §2A | Option comparison; superseded for isolated use by `oep-shell/global-studio-bar.svg` below |
| `.../toolbar 7 use option 3.png` | Toolbar/Action Strip (07) option comparison, decided option highlighted (of 6 shown) | 2079×756 | **CANONICAL** (source) | Design-owner selected ("use option 3"); AP-UX-002 C1 | `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` | Option comparison; superseded for isolated use by `oep-shell/toolbar.svg` below |
| `.../workspace context tab bar.png` | Workspace/Context Bar (03) — demonstrates Studio-color inheritance pattern, 6 Studio rows | 2078×757 | **EXPERIMENTAL** — styling pattern only | Pattern confirmed (AP-UX-002 C1); EAM row content is not authoritative | `design-system/OEP-DESIGN-TOKENS.md` §2A | Color-inheritance pattern; Diagram Studio row reused (not EAM row — placeholder, `AP-UX-001` §10/§14 row 6) by `oep-shell/workspace-bar.svg` below |
| `renders/oep-shell/global-studio-bar.svg` | Global Studio Bar (02), isolated single-purpose canonical asset | 1920×56 | **CANONICAL** | Derived exactly from `studio tab bar use option 3.png`, with "Tools"→"Instruments" corrected (AP-UX-005 §5/§6) | `design-system/OEP-DESIGN-TOKENS.md` §2A, §3 | 7-entry Studio inventory, active/inactive Studio treatment, per-Studio identity color |
| `renders/oep-shell/workspace-bar.svg` | Workspace Bar (03), isolated single-purpose canonical asset, Diagram Studio scenario | 1920×42 | **CANONICAL** | Derived exactly from the Diagram Studio row of `workspace context tab bar.png` | `design-system/OEP-DESIGN-TOKENS.md` §2A | Studio-color inheritance on workspace tabs, `+`/overflow affordances |
| `renders/oep-shell/toolbar.svg` | Toolbar / Action Strip (07), isolated single-purpose canonical asset | 1920×60 | **CANONICAL** | Derived exactly from the "Grouped Sections" option of `toolbar 7 use option 3.png` | `design-system/OEP-SHELL-COMPONENTS.md` §6 | Grouped monochrome toolbar, global-accent-only interaction |
| `renders/oep-shell/status-bar.svg` | Status / Context Bar (08), isolated single-purpose canonical asset | 1920×36 | **CANONICAL** | Derived exactly from the "Compact (Low Profile)" option of `Status bar use option 2.png` | `design-system/OEP-SHELL-COMPONENTS.md` §9 | Compact status/context fields, monochrome with status-only color |
| `renders/oep-shell/context-navigation.svg` | Context Navigation (04), dedicated reference | 360×1080 | **CANONICAL** | New for AP-UX-005 — behavior per `03_OEP_CONTEXTUAL_NAVIGATION_SPEC.md` | `design-system/OEP-SHELL-COMPONENTS.md` §5 | Active Workspace → Engineering Context → Contextual View; workspace-scoped, not Studio-scoped, no Studio-identity color |
| `renders/oep-shell/inspector.svg` | Inspector / Contextual Panel (06), dedicated reference | 360×1080 | **CANONICAL** | New for AP-UX-005 | `design-system/OEP-SHELL-COMPONENTS.md` §8 | Selected object → object info → related info → contextual actions; oep.accent only |
| `renders/diagram-studio/oep-diagram-studio-shell.svg` | **OEP + Diagram Studio full shell composite** — the primary AP-UX-005 deliverable; self-contained (header embedded as base64, all other regions inlined, no external references) | 1920×1080 | **CANONICAL** | Composes all of the above accepted regions plus a new Diagram Studio engineering surface | All shell/design-system documents; fills the gap AP-UX-001 G2 / AP-UX-002 §14 / AP-UX-004 Completion Inventory #17 left open | All 8 shell regions operating together; Diagram Studio engineering surface with selection, wiring, viewport controls; Context Nav/Inspector consistency with the selected object |
| `renders/responsive/1600x900-layout-pressure.svg` | Responsive layout-pressure schematic | 1600×900 | **EXPERIMENTAL** — schematic only, not full-fidelity content | New for AP-UX-005 §9 | AP-UX-004 §15/§20 | Engineering Surface compressed to 680px if side regions are held at reference width; flags a DESIGN-OWNER DECISION REQUIRED banner rather than inventing collapse behavior |
| `renders/responsive/1280x800-layout-pressure.svg` | Responsive layout-pressure schematic | 1280×800 | **EXPERIMENTAL** — schematic only, not full-fidelity content | New for AP-UX-005 §9 | AP-UX-004 §15/§20 | Engineering Surface compressed to an unworkable 360px if side regions are held at reference width; strongest evidence yet that a collapse/overlay/dock decision is required |

**Superseded/removed (recorded for history; files no longer present on disk):** 10 dated `ChatGPT Image Sep 15, 2026, *.png` exploration renders; an earlier, unselected `Status bar.png` / `studio tab bar.png` / `workspace context tab bar.png` / `wireframe.png` (removed during `AP-UX-001`); and, removed by the user during `AP-UX-005`'s render curation, `renders/oep-home/home.png` (4-panel OEP Home + EAM composite), `renders/oep-shell/oep.png` (6-panel iteration of the same), and `renders/eam/EAM.png` (the already-`HISTORICAL/SUPERSEDED` 6-panel EAM composite, AP-UX-002 C3). No render index entry now depends on any of these; their removal broke no reference in this table.

**Gaps still open after AP-UX-005 (recorded, not filled — see `AP-UX-005-VISUAL-DESIGN-COMPLETION.md` §19):** no shell-integrated render exists yet for EAM, Home, Knowledge Studio, Engineering Exchange, Instruments, or Settings. The Diagram Studio gap (AP-UX-001 G2 / AP-UX-002 §14) is now closed by `renders/diagram-studio/oep-diagram-studio-shell.svg` above.

## Render usage rules

1. Use renders for visual hierarchy and spatial intent.
2. Use specifications for behavior.
3. Do not infer backend architecture from mockups.
4. Do not add a global destination solely because a subsystem exists.
5. Reconcile render/spec conflicts before implementation (as of this reconciliation, C1/C2/C3 are resolved — see `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md`).
6. A render's status in the table above may only be changed by a future reconciliation pass, not silently by an implementation WP.

## Baseline aesthetic

Dark engineering-tool aesthetic; one restrained blue interaction accent plus a closed set of per-Studio identity colors used only in the Studio Bar and Workspace Bar (AP-UX-002 C1); restrained status colors; compact typography; thin borders; structured panels; high information density; OEP-native navigation.
