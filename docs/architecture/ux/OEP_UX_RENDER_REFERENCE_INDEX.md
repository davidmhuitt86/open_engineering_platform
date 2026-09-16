# OEP UX Render Reference Index

**Status:** Design reference
**Storage:** `docs/architecture/ux/OEP_UX_RENDER_REFERENCE_INDEX.md` (corrected AP-UX-002 C6 — this line previously named `docs/architecture/ux/renders/README.md`, a path that does not exist on disk)
**Reconciled by:** AP-UX-002 (G1) — this index was rewritten against the actual current render files. The previous version named seven renders as `DR-UX-001` through `DR-UX-007`; no file on disk was ever named that way, and the index predated the curated wireframe set below entirely. See `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md` §13.

## Purpose

Define the visual references used to communicate the intended OEP/EAM UX direction. Renders are visual references and do not replace behavioral specifications (`OEP-UX-ARCHITECTURE.md` §12).

## Canonical render index

| Render | Purpose | Status | Authority | Related specification | Last known design state |
|---|---|---|---|---|---|
| `renders/oep-home/home.png` | OEP Home + EAM acquisition/contextual views + Repository Browser (4-panel composite) | **CURRENT REFERENCE** | Visual reference only | `OEP_HOME_UX_SPEC.md`, `eam/EAM-ACQUISITION-WORKSPACE-SPEC.md` | Single global accent (predates AP-UX-002 C1; region content/layout still current) |
| `renders/oep-shell/oep.png` | Same scenario as above, later/more complete iteration (6-panel: adds Diagram Studio Integration + Visual Workflow Summary) | **CURRENT REFERENCE** | Visual reference only | Same as above | Single global accent (predates AP-UX-002 C1; region content/layout still current) |
| `renders/eam/EAM.png` | EAM-only 6-panel composite (Dashboard, Acquisition List, Workspace, Extract, Review, Publish) | **HISTORICAL / SUPERSEDED** (AP-UX-002 C3) | None — do not build against this render's landing pattern or Studio Bar | Contradicted by `OEP-UX-ARCHITECTURE.md` §4 | Uses a Dashboard-as-landing pattern and an incomplete Studio Bar (omits Home/Diagram Studio/Instruments); superseded by Home (see `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md` §8) |
| `renders/Section 1,2,3, 7,8 of Wireframe UI Use These First Before moving on to the otheer section/App Header with OEP Logo.png` | Application Header region (01) | **CANONICAL** | Design-owner designated (AP-UX-002 C2) | `design-system/OEP-SHELL-COMPONENTS.md` §2 | Current |
| `.../Start With this Exact Wireframe and its Pixel Measurments.png` | Full 8-region pixel-dimensioned shell frame | **CANONICAL** | Design-owner designated (AP-UX-002 C2) — this is the geometry authority `OEP-DESIGN-TOKENS.md` §3 and `OEP-SHELL-COMPONENTS.md` §1 were corrected to match | `design-system/OEP-DESIGN-TOKENS.md` §3, `design-system/OEP-SHELL-COMPONENTS.md` §1 | Current |
| `.../Status bar use option 2.png` | Status Bar (08), decided option (of 5 shown) | **CANONICAL** | Design-owner selected ("use option 2" in the filename) | `SECTION-8-STATUS-BAR-SPEC.md` | Current — "COMPACT (LOW PROFILE) / Minimal Height / Essential" |
| `.../studio tab bar use option 3.png` | Studio Tab Bar (02), decided option (of 5 shown) — source of the per-Studio accent color set | **CANONICAL** | Design-owner selected ("use option 3" in the filename); AP-UX-002 C1 | `design-system/OEP-DESIGN-TOKENS.md` §2A | Current — "DUAL-TONE ANGLED (PREMIUM)" |
| `.../toolbar 7 use option 3.png` | Toolbar/Action Strip (07), decided option (of 6 shown) | **CANONICAL** | Design-owner selected ("use option 3" in the filename); AP-UX-002 C1 | `OEP_TOOLBAR_ACTION_STRIP_ACTION_MATRIX_V1.md` | Current — "GROUPED SECTIONS," monochrome, not per-Studio-colored |
| `.../workspace context tab bar.png` | Workspace/Context Bar (03) — demonstrates Studio-color inheritance pattern | **EXPERIMENTAL** — styling pattern only | Pattern confirmed (AP-UX-002 C1); EAM example content is not authoritative | `design-system/OEP-DESIGN-TOKENS.md` §2A | The color-inheritance rule is retained; the EAM row's example tab labels ("ECU Programming," "DTC Library," etc.) are placeholder content, confirmed with the user, and describe a domain EAM does not implement (`AP-UX-001` §10, §14 row 6) |

**Superseded/removed (recorded for history; files no longer present on disk as of this reconciliation):** 10 dated `ChatGPT Image Sep 15, 2026, *.png` exploration renders (01:58–04:06 AM, one continuous session) and an earlier, unselected `Status bar.png` / `studio tab bar.png` / `workspace context tab bar.png` / `wireframe.png`. Removed by the user during `AP-UX-001`; that audit had already inspected the equivalent content before removal. No render index entry ever named these individually, so no reference is broken by their removal.

**Gap (AP-UX-001 G2, restated by AP-UX-002 §14):** no render exists for Diagram Studio operating inside the OEP shell. See `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md` §14 for the precise requirement a future render must satisfy — this index will gain that entry once it exists, not before.

## Render usage rules

1. Use renders for visual hierarchy and spatial intent.
2. Use specifications for behavior.
3. Do not infer backend architecture from mockups.
4. Do not add a global destination solely because a subsystem exists.
5. Reconcile render/spec conflicts before implementation (as of this reconciliation, C1/C2/C3 are resolved — see `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md`).
6. A render's status in the table above may only be changed by a future reconciliation pass, not silently by an implementation WP.

## Baseline aesthetic

Dark engineering-tool aesthetic; one restrained blue interaction accent plus a closed set of per-Studio identity colors used only in the Studio Bar and Workspace Bar (AP-UX-002 C1); restrained status colors; compact typography; thin borders; structured panels; high information density; OEP-native navigation.
