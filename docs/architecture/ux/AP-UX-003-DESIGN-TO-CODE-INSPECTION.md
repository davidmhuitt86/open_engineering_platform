# AP-UX-003 — OEP UX Design-to-Code & Shell Implementation Inspection

## 1. Status

**COMPLETE.** Read-only repository inspection. No Dart/C++/test/configuration/render file was modified.

## 2. Baseline

```text
git rev-parse HEAD   -> 1591ceb44e4f48e10853a1b5bfb0cb43e23f4036
git status --short   -> pre-existing unrelated working-tree material only (unchanged, see §26)
```

HEAD matched the required baseline (`1591ceb`) exactly. No discrepancy.

## 3. Mission

Establish a factual design-to-code map between the reconciled UX authority (AP-UX-001, AP-UX-002) and the current Flutter implementation — what is implemented, partially implemented, embedded, legacy, missing, or unknown — without changing any implementation and without resolving any remaining UX question.

**Headline finding, stated up front because it governs every section below:** the reconciled 8-region shell (Application Header / Global Studio Bar / Workspace Bar / Context Nav / Toolbar / Surface / Inspector / Status Bar) **does not currently exist in the implementation as a persistent, always-mounted structure.** `StudioShell` — the actual application root — carries its own doc comment stating that all persistent chrome (menu bar, toolbar, breadcrumb bar, sidebar, property inspector, output panel, status bar) was deliberately removed by a prior work package (`AP-OEP-WORKSPACE-AS-PRIMARY-UI-001`), and that the entire application is now a single tabbed workspace whose own "+" menu **is** the navigation. This is not a partial-implementation gap in the reconciled shell; it is a different, already-built, already-shipped navigation architecture that predates AP-UX-001/002 and that neither of those documents was aware existed.

## 4. Authority Used

`docs/architecture/ux/AP-UX-001-UX-DESIGN-RECOVERY.md`, `AP-UX-002-DESIGN-SYSTEM-RECONCILIATION.md`, `OEP-UX-ARCHITECTURE.md`, `design-system/OEP-DESIGN-TOKENS.md` (post-AP-UX-002, incl. §2A and the corrected §3 geometry), `design-system/OEP-SHELL-COMPONENTS.md` (post-AP-UX-002 anatomy), `design-system/OEP-UI-RULES.md`, `OEP_UX_RENDER_REFERENCE_INDEX.md`, `implementation/DS-GOLDEN-WORKSPACE-SPEC.md`, `implementation/WP-UI-DS-001-PROMPT.md`, `.claude/skills/oep-ui/SKILL.md`. No older, pre-reconciliation UX material was substituted for these.

## 5. Repository / Flutter Areas Inspected

Read directly (full or partial file reads, not assumed from filenames):

```text
platform/oep_studio/lib/app/studio_shell.dart                         (full)
platform/oep_studio/lib/app/oep_boot_app.dart                         (grep only)
platform/oep_studio/lib/workspace/engineering_workspace_page.dart     (full, 665 lines)
platform/oep_studio/lib/diagram_studio/header/oep_studio_header.dart  (partial, ~70/210 lines)
platform/oep_studio/lib/core/theme/studio_colors.dart                 (full)
platform/oep_studio/lib/core/routing/studio_destination.dart          (partial — enum entries)
platform/oep_studio/lib/core/surfaces/surface_registry.dart           (partial — ~190/many lines)
platform/oep_studio/lib/workspace/home/home_dashboard_page.dart       (existence + import graph confirmed, not fully read)
```

Searched (ripgrep/Grep tool, confirming presence or absence, not assumed):

```text
class \w*Sidebar\w*                    -> zero matches anywhere in platform/oep_studio
"sidebar"/"Sidebar" (case-insensitive) -> comment-only references in 13 files, no class
class .*StudioBar / WorkspaceBar / ApplicationHeader / StudioTabBar / Shell -> 3 files (see §6)
"*workspace_tab*" / "*status_bar*" / "*toolbar*" (filenames)  -> only workspace_tab*.dart; no status_bar or toolbar file found by name
"*home*screen*" / "*home*page*" (filenames)                   -> home_dashboard_page.dart only
```

Not inspected in this pass (recorded as a boundary, not silently skipped): the internal implementation of `HomeDashboardPage`, `AcquisitionStudioPage`, `KnowledgeStudioPage`, `ExchangeStudioPage`, `EngineeringIntelligencePage`, `SettingsWorkspacePage`, the `workbench/perspectives/` directory, and `DiagramWithComparePane`'s own internal region composition — each is confirmed to *exist* (§18–19) but its own internal layout was not read line-by-line. This is an explicit scope boundary, not an oversight — a full per-Studio internal audit is a larger task than one inspection AP.

## 6. Actual Shell Composition

Reconstructed from `studio_shell.dart` and `engineering_workspace_page.dart` directly — **not forced into the reconciled 8-region template**, per this work package's own instruction:

```text
OEP Application
└── StudioShell  (platform/oep_studio/lib/app/studio_shell.dart)
    │   No persistent chrome. build() returns a bare Scaffold whose
    │   body is one of three things depending on `selected`:
    │
    ├── [selected == diagram]    Scaffold(body: WebSurfacesHostPage)   (legacy route, "no longer
    │                                                                    reachable via any UI
    │                                                                    element" per its own comment)
    ├── [selected == workspace]  Scaffold(body: EngineeringWorkspacePage)  <- the actual, only
    │   │                                                                    reachable production UI
    │   └── EngineeringWorkspacePage (platform/oep_studio/lib/workspace/engineering_workspace_page.dart)
    │       └── Column
    │           ├── OepStudioHeader           <- ONLY rendered when the active tab isDiagram;
    │           │                                otherwise absent entirely (not just hidden)
    │           ├── _WorkspaceTabStrip (height: 36)  <- ONE bar, combining:
    │           │       - open-work tab chips (_WorkspaceTabChip, one per open tab)
    │           │       - a single "+" PopupMenuButton listing: Diagram Studio, Browser,
    │           │         then every SurfaceRegistry.all entry (Home first, then every
    │           │         StudioDestination-backed native Surface, Browser last)
    │           └── Expanded
    │               └── _WorkspaceContent (IndexedStack / Row-split of open tabs' own content,
    │                     each tab's content being that Surface's own page widget, e.g.
    │                     HomeDashboardPage, AcquisitionStudioPage, DiagramWithComparePane)
    │
    └── [selected == anything else]  Scaffold(body: widget.child)  <- fallback branch, per
                                                                        studio_shell.dart's own
                                                                        comment "never actually
                                                                        reached via the UI"
```

**No separate Global Studio Bar. No separate Workspace Bar. No Context Navigation region. No Toolbar region. No Inspector region. No Status Bar region.** The single `_WorkspaceTabStrip` is the entire persistent navigation surface, and each open tab's own page widget is independently responsible for anything resembling toolbar/inspector/status content inside itself — there is no shell-level contract for those regions at all.

## 7. Application Header

**DIVERGENT.** No OEP-wide Application Header exists. The only widget with a similar name, `OepStudioHeader` (`platform/oep_studio/lib/diagram_studio/header/oep_studio_header.dart`), is scoped exclusively to Diagram Studio: its own doc comment states it "sits above `WebSurfacesHostPage`'s tab strip," and `EngineeringWorkspacePage.build()` (line 173) gates its rendering on `activeTab?.isDiagram ?? false` — it is entirely absent, not merely hidden, for every non-Diagram tab. Its purpose is also different in kind from the reconciled spec: it toggles between "Diagram" and "Simulation" *views* of the current Diagram document (`OepStudioView` enum), not OEP-wide identity/search/notifications/account/window controls. Its height is responsive (72px / 60px / 48px by breakpoint, `oep_studio_header.dart` lines 52–55), not the reconciled fixed 58px. Colors are local hard-coded values (`Color(0xFF4C8DFF)` / `Color(0xFF22D3C7)`), not `oep.accent` or any `oep.studio.*` token.

## 8. Global Studio Bar

**NOT IMPLEMENTED as a persistent, dedicated region.** No class named `*StudioBar*` exists (confirmed by direct class-name search). The nearest equivalent is the "+" `PopupMenuButton` inside `_WorkspaceTabStrip` (`engineering_workspace_page.dart` lines 460–502) — a dropdown menu, not a persistent, always-visible row of Studio tabs. It is populated from `SurfaceRegistry.all`, which in turn derives from `StudioDestination` (`core/routing/studio_destination.dart`) — a materially larger inventory than the reconciled 7/8-entry Studio Bar: `dashboard`, `workspace`, `projectExplorer`, `knowledge`, `diagram`, `acquisition`, `repository`, `objects`, `relationships`, `search`, `graph`, `validation`, `packages`, `engineeringIntelligence`, `exchange`, `copilot`, `engineeringWorkbench`, `instrumentsWorkbench`, `settings` — 19 entries. This directly confirms, with code evidence, **AP-UX-001's C7 open question has real substance**: `engineeringIntelligence` exists in code today as its own destination — this doesn't resolve the open question (this inspection is not authorized to), but it is material evidence for whoever does resolve it. It also shows the reconciled "Destination vs. Capability Rule" (Objects/Relationships/Graph/Validation/Packages should normally be contextual) is **not currently honored at the code-architecture level** — all five exist as first-class `StudioDestination` entries alongside genuine Studios, exposed through the same flat "+" menu. No active/inactive Studio-Bar visual state exists to inspect, because no persistent bar exists. No `oep.studio.*` token or equivalent is referenced anywhere in `studio_colors.dart` (§17).

## 9. Workspace Bar

**PARTIALLY IMPLEMENTED, merged with the Studio Bar's role.** `_WorkspaceTabStrip` (`engineering_workspace_page.dart` lines 406–508) is a real, working, persistent tab strip — it does implement open-work tabs, active/inactive tab state (`_WorkspaceTabChip`, `active: tab.id == activeId`), close (`onClose`), and "+" to open more work (`onOpenDiagram`/`onOpenBrowser`/`onOpenSurface`) — genuinely equivalent in *function* to the reconciled Workspace Bar. Its height is a hard-coded `36` (line 430) — coincidentally close to, but not sourced from, the reconciled `oep.workspace.height` = 42px token (that token does not exist in code at all, §17). It is not modeled independently from Studio navigation — opening a new Studio *is* opening a new workspace tab here, which is the merged-bar architecture already described in §6/§8, not a bug in this one widget. No Studio-identity-color inheritance exists (`_WorkspaceTabChip` uses `StudioColors.selection`, a single global color, for its active state — confirmed by reading the surrounding `_WorkspaceTabStrip`/`_WorkspaceTabChip` source).

## 10. Contextual Navigation

**NOT LOCATED AFTER SEARCH as a shell-level region.** No dedicated Context Navigation widget/class was found at the `EngineeringWorkspacePage`/`StudioShell` level. The `Studio → Workspace → Contextual View → Capability` concept may exist *inside* individual Studio page widgets (e.g. `AcquisitionStudioPage`, `KnowledgeStudioPage`) — this inspection confirmed those files exist (§5) but did not read their internal composition, so this is recorded as **UNKNOWN inside each Studio**, not as a confirmed absence there. At the shell level, specifically, there is no such region — the reconciled architecture's "left rail changes with context" concept has no shell-owned implementation to point to.

## 11. Toolbar

**NOT LOCATED AFTER SEARCH as a shell-level region**, and therefore the AP-UX-002 C2 geometry/placement correction (full-width row below the 3-column split, 60px) has nothing to be compared against at the shell level — there is no persistent Toolbar row in `StudioShell` or `EngineeringWorkspacePage` at all. No file matching `*toolbar*` exists anywhere under `platform/oep_studio/lib/` (confirmed by filename search). If a Studio-specific toolbar exists, it is embedded inside that Studio's own page widget (not inspected in this pass, §5) — recorded as UNKNOWN per-Studio, DIVERGENT at the shell level (the shell provides no toolbar contract of any kind, so no Studio can currently "conform" to the reconciled placement even if it wanted to).

```text
CURRENT:     no shell-level toolbar region exists
EXPECTED:    full-width row below Context-Nav/Surface/Inspector, 60px (AP-UX-002 C2)
DIVERGENCE:  total — not a geometry mismatch, an absent region
```

## 12. Main Engineering Surface

**IMPLEMENTED, and its ownership boundary is exactly as `DS-GOLDEN-WORKSPACE-SPEC.md` describes.** For Diagram Studio specifically: `_buildTabContent` (`engineering_workspace_page.dart` lines 213–260) renders `DiagramWithComparePane` for the primary Diagram tab and `_DiagramInstanceTab` for any secondary instance — both, per the surrounding doc comments, wrap the real, existing `LegacyV2WebViewPage`/Engine bridge, explicitly *not* re-implemented or mocked for this shell. This is a clean, confirmed **MATCH** with the reconciled Engine/Legacy-V2-owns-rendering boundary (AP-UX-001 §9) — the one region where the reconciled UX's own stated principle and the actual code agree without qualification. Engine-side rendering/selection/zoom/pan internals were not further inspected (out of this AP's scope — that is Engine-layer, not shell-layer, and DS-GOLDEN-WORKSPACE-SPEC.md §8 already forbids touching it).

## 13. Inspector / Contextual Panel

**NOT LOCATED AFTER SEARCH as a shell-level region.** No dedicated Inspector class was found outside Diagram Studio's own internals (which, per §5, were not read in this pass). Per this work package's own §13 instruction, no requirement for a permanent shell-level inspector is inferred here — the reconciled specification itself only calls for a contextual one, so its absence at the shell level is consistent with "contextual," not necessarily a defect; whether one exists inside individual Studios is UNKNOWN, not confirmed absent.

## 14. Status / Context Bar

**NOT LOCATED AFTER SEARCH.** No file matching `*status_bar*` exists anywhere under `platform/oep_studio/lib/`, and no status-bar-shaped widget was found in `studio_shell.dart` or `engineering_workspace_page.dart`. `studio_shell.dart`'s own doc comment explicitly lists "Status Bar" among the chrome types removed by `AP-OEP-WORKSPACE-AS-PRIMARY-UI-001` (§3/§6) — this is the one region where the implementation's own commit history directly documents its own removal, not merely an inspection failing to find it.

## 15. Design Token Implementation

**NOT IMPLEMENTED against `OEP-DESIGN-TOKENS.md`.** A real, actively-used token class exists — `StudioColors` (`platform/oep_studio/lib/core/theme/studio_colors.dart`) — but it is sourced from a *different*, older, already-known-and-classified document ("SDD-002 Design Language," per its own doc comment — the same `platform/oep_studio/docs/DESIGN_LANGUAGE.md` AP-UX-001 §12 already classified as "retained pending design-system reconciliation," not superseded). Direct value comparison:

| Concept | `OEP-DESIGN-TOKENS.md` (reconciled) | `StudioColors` (actual, implemented) | Match? |
|---|---|---|---|
| Background | `oep.bg` `#0B0F14` | `background` `#0D1117` | Close, not equal |
| Primary surface | `oep.surface.1` `#111720` | `surface` `#11161D` | Close, not equal |
| Border | `oep.border` `#2A3542` | `border` `#232B36` | Close, not equal |
| Interaction accent | `oep.accent` `#2F81F7` | `selection` `#3B82F6` | Close, not equal |
| Text primary | `oep.text.primary` `#E7EDF4` | `textPrimary` `#E6E9EE` | Close, not equal |
| Success/Warning/Error | `#39B56B`/`#D9A441`/`#D95C5C` | `#22C55E`/`#EAB308`/`#EF4444` | Close, not equal |
| Toolbar/workspace/header/studiobar/statusbar height tokens | `oep.toolbar.height`=60, `oep.workspace.height`=42, `oep.header.height`=58, `oep.studiobar.height`=56, `oep.statusbar.height`=36 | none of these exist; `_WorkspaceTabStrip` hard-codes `height: 36` locally | Not implemented |
| Per-Studio identity (`oep.studio.*`) | 7-entry closed set (AP-UX-002 §2A) | Does not exist | Not implemented |

**Classification: PARTIALLY IMPLEMENTED, but against the wrong source.** The overall visual intent (dark, blue-accent, restrained) is honored by `StudioColors`; the *specific* reconciled token names and exact values are not referenced anywhere in code. No hard-coded value in the codebase was found to correspond exactly (to the pixel or the hex) to a reconciled AP-UX-002 token.

## 16. Accent Implementation

`StudioColors.selection` (`#3B82F6`) is the one and only accent color used for active/selected state throughout the inspected code (`_WorkspaceTabChip`'s active state, per its own reference to `StudioColors.selection` used the same way elsewhere in this file). **No per-Studio identity color exists anywhere in the implementation** — `oep.studio.*` (AP-UX-002 C1) has zero code references. This means the current implementation is, today, factually closer to the *original* (pre-AP-UX-002) single-global-accent model than to the reconciled hybrid model — not because it was built against the hybrid model and simplified, but because it predates both AP-UX-001 and AP-UX-002 entirely and has not been touched since. `ThemeData`/`ColorScheme` (Flutter's own theming primitives) were searched for only via the general "theme" pattern implied by this AP's §18 instruction; a dedicated `ThemeData` construction was not located in the files this inspection actually opened — recorded as **NOT LOCATED AFTER SEARCH**, not confirmed absent, since a repository-wide `ThemeData` search was not separately run.

## 17. Diagram Studio Integration

Diagram Studio is reachable two ways in the current code: the legacy `StudioDestination.diagram` route through `WebSurfacesHostPage` (per `studio_shell.dart`'s own comment, "no longer reachable from ordinary production navigation"), and the real, current path — a Workspace tab whose content is `DiagramWithComparePane`, opened via `openDiagramTab` (`engineering_workspace_page.dart` lines 85–90). The engine-rendering boundary is a confirmed MATCH (§12). Contextual navigation, a dedicated toolbar, and an inspector *specific to this shell* were not located (§10/§11/§13) — if they exist, they are internal to `DiagramWithComparePane`/`LegacyV2WebViewPage`, not inspected in this pass. **No dedicated Diagram Studio shell-integration render exists** — confirmed by direct inspection of the current render index (`OEP_UX_RENDER_REFERENCE_INDEX.md`, itself already rewritten by AP-UX-002): no entry for one exists, matching AP-UX-002 G2's own finding exactly. **AP-UX-002's finding is confirmed, not corrected.**

## 18. EAM Shell Integration

EAM enters the shell through exactly the same generic mechanism as every other Studio: a `SurfaceRegistry` entry (`acquisition_studio_page.dart` → `AcquisitionStudioPage`, imported into `surface_registry.dart` line 5) reached via the "+" menu, opened as an ordinary Workspace tab. No EAM-specific shell code exists at the `StudioShell`/`EngineeringWorkspacePage` level — this is consistent with AP-UX-001 §8's finding that EAM introduces no independent chrome, though the *mechanism* by which that's true (a flat tab-strip "+" menu, not a persistent Studio Bar) is different from what AP-UX-001/002 assumed. `AcquisitionStudioPage`'s own internal workflow/navigation/toolbar composition was not read in this pass (§5) — recorded as UNKNOWN, not absent.

## 19. Home Shell Integration

**CONFIRMED MATCH with the reconciled model, and confirms AP-UX-001's own finding was correct.** `SurfaceRegistry._homeSurface()` (lines 152–165) explicitly inserts `HomeDashboardPage` (`workspace/home/home_dashboard_page.dart`) first in the Surface list, with its own doc comment calling it "the application-shell landing surface." A separate, older `features/dashboard/dashboard_page.dart` also exists and is still imported by `surface_registry.dart` (line 9) — but the Surface-building loop explicitly `continue`s past `StudioDestination.diagram`/`.workspace`, and `_homeSurface()` is inserted independently of that loop, using `HomeDashboardPage`, not `DashboardPage` — i.e., the legacy Dashboard page is still present in the codebase (imported, presumably still reachable via its own raw `StudioDestination.dashboard` route) but is **not** what Home actually renders through the real, current tab-based path. This directly corroborates `platform/oep_studio/docs/DASHBOARD.md`'s already-confirmed supersession notice (AP-UX-001 §12) with fresh code evidence rather than merely re-citing the doc's own claim.

## 20. Design-to-Code Matrix

| UX Region | Authoritative Requirement | Flutter Location | Widget/Class | Current State | Conformance | Divergence / Notes |
|---|---|---|---|---|---|---|
| Application Header | 58px | `diagram_studio/header/oep_studio_header.dart` | `OepStudioHeader` | EMBEDDED (Diagram-only, not global) | DIVERGENT | Scoped to Diagram tabs only; responsive height 48–72px, not fixed 58px; serves a Diagram/Simulation view toggle, not app identity/search/account |
| Studio Bar | 56px | *(none)* | *(none — nearest is the "+" menu inside `_WorkspaceTabStrip`)* | NOT IMPLEMENTED | NOT IMPLEMENTED | No persistent bar; a dropdown menu instead; 19-entry `StudioDestination` inventory vs. reconciled 7/8 |
| Workspace Bar | 42px | `workspace/engineering_workspace_page.dart` | `_WorkspaceTabStrip` | PARTIALLY IMPLEMENTED | PARTIAL MATCH | Functionally equivalent, merged with Studio-launch role; height hard-coded 36px, not from `oep.workspace.height`; no Studio-identity-color inheritance |
| Context Navigation | contextual | *(not found at shell level)* | *(none)* | NOT LOCATED AFTER SEARCH | UNKNOWN | May exist inside individual Studio pages (not inspected) |
| Toolbar | 60px / full-width | *(not found anywhere)* | *(none)* | NOT IMPLEMENTED | NOT IMPLEMENTED | No file matching `*toolbar*` exists in `platform/oep_studio/lib/` |
| Main Surface | Studio-owned | `workspace/engineering_workspace_page.dart` (`_buildTabContent`) + `diagram_studio/compare/diagram_with_compare_pane.dart` | `DiagramWithComparePane`, `_DiagramInstanceTab` | IMPLEMENTED | MATCH | Engine/Legacy-V2 rendering ownership confirmed intact |
| Inspector | contextual | *(not found at shell level)* | *(none)* | NOT LOCATED AFTER SEARCH | UNKNOWN | May exist inside individual Studio pages (not inspected); no requirement inferred for one to exist at shell level |
| Status Bar | 36px | *(none — explicitly removed per `studio_shell.dart`'s own doc comment)* | *(none)* | NOT IMPLEMENTED | NOT IMPLEMENTED | Confirmed removed, not merely unfound |

Of the 8 rows: 1 MATCH, 1 PARTIAL MATCH, 2 DIVERGENT/EMBEDDED, 3 NOT IMPLEMENTED, 2 UNKNOWN (Context Nav and Inspector overlap the "may exist per-Studio" category, counted once each). This resolves AP-UX-002 §18's 5-of-8 UNKNOWN rows: 3 are now definitively NOT IMPLEMENTED at the shell level (Toolbar, Status Bar, and Studio Bar as a persistent region), 2 remain genuinely UNKNOWN pending a per-Studio internal read (Context Nav, Inspector) — not because this inspection failed to look, but because that answer lives one layer deeper than the shell files this AP's own scope reached.

## 21. Implementation Divergence Matrix

| ID | Design Requirement | Current Implementation | Divergence | Impact | Future Action |
|---|---|---|---|---|---|
| D1 | 8-region persistent shell (Header/Studio Bar/Workspace Bar/Context Nav/Toolbar/Surface/Inspector/Status Bar) | Single tabbed workspace; only the Workspace Bar's function exists, merged with Studio launching | Architectural — the reconciled shell was designed without knowledge of `AP-OEP-WORKSPACE-AS-PRIMARY-UI-001`, which already removed persistent chrome for reasons of its own | High — any future shell-integration WP must either reconcile *with* the tabbed-workspace architecture or explicitly decide to reintroduce persistent chrome over it | DESIGN DECISION REQUIRED |
| D2 | Global Studio Bar, per-Studio identity color, 7/8-entry inventory | No persistent bar; 19-entry flat `StudioDestination` enum including capability-shaped entries (Objects/Relationships/Graph/Validation/Packages) the reconciled Destination-vs-Capability rule says should be contextual | Structural + inventory | Medium-High — implementing the reconciled Studio Bar as designed would require deciding what happens to the other 11 `StudioDestination` entries not on that list | DESIGN DECISION REQUIRED |
| D3 | `oep.*` design tokens (color + geometry) | `StudioColors` (different values, different source document, no per-Studio tokens, no geometry tokens at all) | Values differ; naming scheme entirely absent | Medium — any future implementation work needs the reconciled tokens actually added to code before it can "implement the design system," not merely approximate its intent | IMPLEMENT (introduce the token set; retire or alias `StudioColors` once done) |
| D4 | Toolbar (60px, full-width row) | Does not exist at the shell level | Total absence | Medium — blocks any WP that assumes a toolbar region to build into | IMPLEMENT (once D1 is resolved — building a toolbar into a shell structure that may itself be redesigned would be wasted work) |
| D5 | Status Bar (36px) | Explicitly removed by a prior WP, per that WP's own documentation | Total absence, deliberate | Low-Medium — no user-facing regression is implied (it was a deliberate prior decision, not a bug), but the reconciled spec still describes one | DESIGN DECISION REQUIRED (was its removal meant to be permanent, or specific to the workspace-as-primary-UI transition?) |
| D6 | Engine/Legacy-V2 rendering ownership boundary | Confirmed intact | None | None | RETAIN |
| D7 | Home replaces Dashboard as the landing surface | Confirmed — `HomeDashboardPage` is the real landing surface; the legacy `DashboardPage`/`StudioDestination.dashboard` route still exists in code but is not what Home renders through | None (the legacy file's continued presence is not itself a divergence — AP-UX-001/README's own reconciliation policy already permits retaining legacy files) | None | RETAIN |

## 22. WP-UI-DS-001 Revalidation

**REQUIRES REVISION.** `WP-UI-DS-001-PROMPT.md`'s own Step 1 design-to-code map template (Application Header / Global Studio Bar / Workspace Bar / Context Navigation / Toolbar / Diagram Surface / Inspector / Status Bar, each mapped to "Studio host" or "Diagram Studio" as owner) presupposes the reconciled 8-region shell already exists as a persistent structure that Diagram Studio integrates *into*. Per §6–§14 above, that structure does not exist — five of its eight target rows (Header as global, Studio Bar, Toolbar, Inspector-as-shell-region, Status Bar) have no current implementation to integrate *with*. Executing the prompt as written today would very quickly hit its own Step 1 instruction — "If this inspection reveals an architectural conflict, STOP and report it before modifying code" — and that STOP would happen almost immediately, on the shell's basic structure, not on some deep Diagram-specific detail. The prompt's *content* (hard prohibitions, QA protocol, priority order for the regions that do have something to integrate into) remains sound and should not be discarded — but it needs a D1 (§21) resolution first, and its own "Read first" list needs the reconciled AP-UX-001/002/003 documents added (already flagged by AP-UX-002 §19/README.md).

## 23. UI Skill Validation

`.claude/skills/oep-ui/SKILL.md`'s section sequence (00 Frame/Geometry, 01 Application/Top Panel, 02 Global Studio Tab Bar, 03 Workspace Tab Bar/Context Bar, 04 Context Nav, 05 Primary Surface, 06 Inspector, 07 Toolbar, 08 Status/Bottom Row) is well-formed *as a general method* and its hard constraints (Studios are destinations; Objects/Relationships/Graph/Validation/Evidence/Provenance/History/Packages are normally contextual; no browser-style nav; do not silently change Engine contracts; escalate rather than invent) remain fully compatible with AP-UX-002's reconciled rules — nothing in this inspection contradicts them. **The stale assumption is the same one affecting `WP-UI-DS-001-PROMPT.md`:** the skill's section sequence implicitly assumes there is an existing shell to slot each numbered section into ("Select ONE SECTION → Inspect code → Map to components → Implement..."), which presupposes the 8-region structure §6–§14 found does not exist. The skill itself needs no rewrite — its "Escalation rule" ("If a render appears to require behavior that is not present in the specification... stop and report the conflict") already covers exactly this situation. It was not modified in this AP, per instruction.

## 24. Remaining Unknowns

1. Internal composition of `HomeDashboardPage`, `AcquisitionStudioPage`, `KnowledgeStudioPage`, `ExchangeStudioPage`, `EngineeringIntelligencePage`, `SettingsWorkspacePage`, `workbench/perspectives/*` — do any of these implement their own Context Navigation, Toolbar, or Inspector internally? UNKNOWN, not inspected.
2. Whether a `ThemeData`/`ColorScheme` construction exists anywhere in the app that centralizes theming beyond the static `StudioColors` constants — NOT LOCATED AFTER SEARCH, but a full repository-wide `ThemeData` search was not separately run.
3. AP-UX-002 C7's open issue (Engineering Intelligence Studio-Bar status) — **not resolved here**, per instruction; §8 records that `engineeringIntelligence` exists as a real `StudioDestination` today, as evidence for whoever does resolve it.
4. Whether `StudioDestination.dashboard`'s route (`/`) is still reachable through any UI path at all, or is genuinely dead code — `studio_shell.dart`'s own comment says the fallback branch rendering it is "never actually reached via the UI," which is strong evidence but was not independently verified by tracing every navigation call site.
5. Whether `AP-OEP-WORKSPACE-AS-PRIMARY-UI-001` (the work package that removed persistent chrome) has its own design rationale document somewhere in the repository that should be read before any D1 decision is made — not searched for in this pass.

## 25. Recommended Next Work Package

Not a controlled implementation WP yet. The evidence in §6, §8, §11, §14, and D1/D2 (§21) shows the reconciled shell and the actual, already-shipped tabbed-workspace architecture are not merely "partially implemented" — they are two different navigation models, and no amount of further inspection resolves which one is meant to govern going forward. That is a design-owner decision, structurally identical in kind to AP-UX-002's own C1/C2 (a real, deliberate, existing design choice on each side), not a defect to fix.

**Proposed AP-UX-004 — OEP Shell Architecture Decision: Reconciled 8-Region Shell vs. Tabbed-Workspace-as-Primary-UI.** Purpose: present both architectures side by side (the reconciled AP-UX-001/002 shell, and the shipped `AP-OEP-WORKSPACE-AS-PRIMARY-UI-001` model this AP recovered) with their respective rationale, and obtain an explicit design-owner decision on one of: (a) reconcile the UX documents to describe the tabbed-workspace model instead, (b) reintroduce persistent shell chrome around/above the tabbed workspace, or (c) a hybrid neither AP-UX-002 nor the current code anticipated. Only after that decision should `WP-UI-DS-001` be revised and reissued, or a new implementation WP begun. Remaining unknowns (§24, item 1 especially) should be closed as part of scoping that decision, since "what does each Studio already do internally" materially affects which of (a)/(b)/(c) is cheapest and safest.

## 26. Verification

```text
git diff --check      -> clean (exit 0)
git status --short    -> only this AP's own new file plus the same, unchanged,
                          pre-existing unrelated working-tree material found at
                          the start of this work package (see §2)
git diff --stat        -> 1 file changed (new)
git rev-parse HEAD     -> 1591ceb (unchanged until this AP's own commit)
```

Checklist against this work package's own §30:

1. Only AP-UX-003 documentation was changed — confirmed, one new file under `docs/architecture/ux/`.
2. No source files changed — confirmed; every file cited above was opened with the Read tool only.
3. No user files changed — confirmed; `platform/oep_studio/lib/acquisition/*`, `services/acquisition/config/config.toml`, and both EAM runtime data directories are untouched.
4. No render files changed — confirmed; nothing under `docs/architecture/ux/renders/` was touched.
5. No pre-existing working-tree material was staged — confirmed by `git status --short` before staging (§2) matching after.
6. Documentation references are valid — every file path cited above was confirmed to exist via direct Read or Grep/find before being cited; none was assumed from a filename alone.
7. Implementation locations cited in the report actually exist — confirmed per item 6; the handful of locations that could *not* be confirmed are explicitly marked NOT LOCATED AFTER SEARCH or UNKNOWN, never asserted as fact.
8. Baseline is correct — confirmed (§2).
9. `git diff --check` is clean — confirmed above.

## 27. AAR

See the Final AAR delivered in the work-package response.
