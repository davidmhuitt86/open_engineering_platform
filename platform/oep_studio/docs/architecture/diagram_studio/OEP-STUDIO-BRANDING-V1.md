# OEP-STUDIO-BRANDING-V1 — OEP Header + Diagram Studio Toolbar Branding

**Status: V1 pilot.** Applies only to Diagram Studio (and, by extension,
its Simulation view — the same Studio, same document). Not yet propagated
to Repairers Studio, Maintainers Studio, Engineers Studio, Exchange
Studio, Knowledge Studio, or OEP DMM.

See `PRODUCT-READINESS-012-IMPLEMENTATION-REPORT.md` for the toolbar
information-architecture refinement pass that followed this branding
pilot, including the full before/after toolbar structure and per-command
accounting.

## 1. OEP master identity

Assets in `platform/oep_studio/assets/branding/` are supplied, pre-approved
artwork (`OEP_Branding_V1_SVG_Assets`), used directly and verbatim — none
of them were traced, redrawn, or approximated from the concept-board
renders. The renders remain references for layout/proportion only.

- `oep_logo.svg` — full lockup (mark + "OPEN ENGINEERING PLATFORM"
  wordmark baked into the SVG).
- `oep_logo_compact.svg` — the same mark without the wordmark, used at
  header size (a second, Flutter-rendered caption would duplicate what the
  full logo already says).
- `diagram_studio_mark.svg` / `simulation_studio_mark.svg` — the two
  Studio marks: shared hexagon container, blue vs. teal.
- `oep_view_swap.svg` — the swap symbol: the same hexagon, two opposing
  directional paths through it.

## 2. Header

`OepStudioHeader` (`lib/diagram_studio/header/oep_studio_header.dart`) is
the shared application header: master logo, the active Studio's own
identity mark/title/subtitle, and the OEP-branded view-swap control. It
sits above the real, reached tabbed workspace
(`workspace/engineering_workspace_page.dart`), scoped to render only while
the active tab is a Diagram tab.

**Why one header, not two Studio pages:** there is no separate
"Simulation Studio" route. Diagram Studio is the one real screen; the
"Simulation view" (`OepStudioView.simulation`,
`oepStudioViewProvider`) is a perspective of that same open
document/session, matching V2's own already-real `toggleSimPanel()` state
(`js/ui/sim-panel.js`) — never a new authority. The header is presentation
only; real state lives in `oepStudioViewProvider` and
`legacyV2ToggleSimulationViewProvider` (`legacy_v2_webview.dart`).

## 3. Engineering toolbar

Rendered inside the Legacy V2 webview itself
(`reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html`,
`css/oep-branding.css`, `js/ui/toolbar.js`) — the real, current production
diagram renderer, restyled in place rather than replaced. Icons are a
small inline SVG sprite (feather-style line icons) defined once at the
top of `index.html` and referenced via `<use>`; no icon framework, no
emoji for primary commands.

The current toolbar structure, and the reasoning behind each button being
direct vs. a dropdown, is documented in
`PRODUCT-READINESS-012-IMPLEMENTATION-REPORT.md` §5–§7 — that is the
authoritative, current account; treat anything here as historical
background only.

### Commands NOT implemented (by design, not oversight)

The original visual reference renders (`assets/New Oep Design Renders and
logos/`) depict a richer command set than this app actually has. The
following are deliberately absent from every dropdown, because no real
implementation exists anywhere in this codebase: Auto-Route wires, Curved
(Bezier) wires, Set Wire Gauge, component By-Category browsing,
Multi-Pin/Weatherproof connectors, T-/Y-Splice types, Zoom to Area, Auto
Arrange/Align/Distribute/Snap to Grid/Clean Up Diagram (no auto-layout
engine), Export PNG/PDF/BOM/to-.oep-Package (SVG is the only real export
format), and Object Properties/Copy Reference/Add to Favorites beyond the
real Property Inspector/Legend. If any of these become real features,
they get a real toolbar entry then — not before.

## 4. Bridge: `engineeringCommand`

A small number of toolbar commands need real Flutter logic that V2's own
JavaScript cannot reach (File document lifecycle; Trace/Measure modes
driven by `TraceController`/`MultimeterController`; Analyze's Analysis/
Compare Diagrams shortcuts). These are sent as one fixed-vocabulary string
through `window.__oepBridgePostMessage` (the same cross-platform outbound
channel every other bridge message already uses) and dispatched by
`LegacyV2BridgeTransport.onEngineeringCommand` /
`_WindowsLegacyV2WebViewPageState._handleEngineeringCommand`
(`legacy_v2_webview.dart`) to the exact same pre-existing controllers and
provider toggles the Workspace Actions panels already use. This is
presentation wiring, not a new authority — see PR-012 §4/§11 for the full
accounting of what each command reaches.

## 5. Deferred

Repairers Studio, Maintainers Studio, Engineers Studio, Exchange Studio,
Knowledge Studio, and OEP DMM keep their existing branding. This system
propagates to them only after the pilot is evaluated and approved.
