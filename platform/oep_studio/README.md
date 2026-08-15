# OEP Studio

The graphical desktop application for the Open Engineering Platform.

OEP Studio is a Flutter presentation layer. It contains no engineering
business logic — every engineering operation executes through OEP
Foundation, a separate repository, via the Foundation Bridge. See
`docs/ARCHITECTURE.md` (SDD-001) for the full architecture.

## Status

Work Packages 001–018 are implemented: Application Shell + Dashboard,
Foundation Bridge + Open Repository Workflow, the Repository Explorer
/ Object Explorer / Property Inspector / Connection Manager, the
Relationship Explorer / Search Workspace, — across Work Packages
007–016 and 018 — **Knowledge Studio** (SDD-013), and — as of Work
Package 017 — the **Settings Workspace** (SDD-023). Repository Explorer
through
Search Workspace are backed by **live** Foundation data (Engineering
Object enumeration and statistics since Work Package 004; Engineering
Relationship enumeration and repository search since Work Package
006's consumption of Foundation Work Package 013's `oep_api.h`
surface). The Relationship Explorer shows every relationship in the
open repository with sort/filter and "Go To Source"/"Go To Target"
navigation; the Search Workspace performs live Repository/Object/
Relationship search against Foundation's Search Engine, in
Foundation's own result order.

Knowledge Studio, by contrast, remains **Studio-only for everything
except Repository Commit, OCR, and (as of Work Package 016) a
provider-independent AI infrastructure layer with no production AI
integration** — but is no longer
in-memory-only. It supports manually-created Knowledge Candidates
(across ten types) and Relationship Candidates reviewed within a
Knowledge Curation Session that **persists locally across restarts**
(`%APPDATA%/oep_studio/knowledge_sessions/`, see
`docs/KNOWLEDGE_SESSION_FORMAT.md`), and a Session Browser (Open/
Duplicate/Archive/Delete). As of Work Package 012, Repository Commit is
real: a Commit Plan shows exactly what will happen, and a transactional
Commit creates real Engineering Objects and Relationships in the open
Foundation repository, with automatic rollback on failure and a
persisted Commit Report per attempt (see `docs/REPOSITORY_COMMIT.md`).
As of Work Package 013, attached PDF/PNG/JPG/TIFF Source Material can
be run through a real, local OCR pipeline (Tesseract, invoked as an
external process — requires a system-installed `tesseract` on PATH)
producing per-word text, confidence, bounding boxes, and reading order;
an OCR Layer Viewer displays the original page with a toggleable word-
box overlay and confidence heat map, and OCR text is searchable
(Find/Find Next/Highlight) — see `docs/OCR_PIPELINE.md`. OCR results
are Evidence, exactly like Evidence Regions — never Knowledge
Candidates, never sent to Foundation. Attached PDF Source Material gets
a real, interactive viewer (page navigation, zoom, fit, rotate,
continuous scrolling) with manual Evidence Region drawing and Page
Selection, and Knowledge Candidates can be linked to Evidence Regions
with bidirectional highlighting (see `docs/EVIDENCE_MODEL.md`). As of Work
Package 010, Knowledge Candidates also carry Notes/Author/Tags and can
be created directly from Source Material, a Page Selection, or an
Evidence Region; a Procedure Builder supports ordered, reorderable
steps; a Specification Editor supports Type/Value/Unit/Notes; and
every candidate shows a computed Validation Status (duplicate names,
missing evidence, empty procedures, incomplete specifications, stale
relationships/references) alongside filter/sort/duplicate in the
Candidate List (see `docs/KNOWLEDGE_CANDIDATES.md`). As of Work
Package 011, the active session can be visualized as an interactive
Knowledge Session Graph (pan/zoom/fit/center/select, independent of
Foundation Graph), and every Knowledge Candidate's Property Inspector
gains Provenance (Candidate → Evidence Region → Page Selection →
Source Material) and Dependency (referenced by/references/
relationships/procedure and specification usage/evidence count/
validation) tabs, alongside a Session Health Dashboard of informational
engineering-quality metrics (see `docs/KNOWLEDGE_GRAPH.md`). As of Work
Package 014, OCR text can be analyzed with deterministic pattern
matching to recognize fourteen kinds of engineering value (torque
specs, voltages, part numbers, wire colors, and more) as Engineering
Entities — Workspace artifacts, one layer above OCR text, never
Knowledge Candidates until explicit engineer acceptance; an Entity
Review Workspace supports filter/sort/search/accept/ignore/navigate-
to-source, and every entity gets a computed Validation (duplicates,
impossible values, malformed units, low OCR confidence) — see
`docs/ENGINEERING_ENTITY_EXTRACTION.md`. As of Work Package 015,
extracted entities can be grouped into logical Engineering Contexts
(a Torque Specifications section, a Parts List, a Warning callout)
using deterministic document structure alone — heading/callout
keywords, relative line height, and entity proximity, with major
sections (Procedure, Component, Torque Table, etc.) nesting minor
annotations (Warning, Note, Figure, Diagram) detected inside their own
range; a Context Explorer supports an expandable tree view,
filter/sort/search, and Accept/Ignore/Split/Merge/Navigate-to-Source,
with computed Validation (empty/duplicate/overlapping contexts,
orphaned entities, invalid hierarchy) — see
`docs/ENGINEERING_CONTEXT.md`. As of Work Package 016, a complete,
provider-independent AI infrastructure layer exists — a common
`AiProvider` interface, a Prompt Construction Service, and a full
Accept/Edit/Reject/Defer review workflow. An AI Review Workspace lets
an engineer run analysis and review suggestions the same way
Entity/Context review already work; accepting a suggestion creates a
normal Knowledge Candidate, never automatically — see
`docs/AI_PROVIDER_ARCHITECTURE.md`. As of Work Package 017, Studio has
a real **Settings Workspace** — a dedicated navigation destination
(not a modal dialog) with eleven core pages (General, Appearance,
Workspace, Repository, Knowledge Studio, Artificial Intelligence,
Plugins, Updates, Diagnostics, Security, About), full-text search over
every setting, and a versioned, automatically-migrated User
Configuration persisted to `%APPDATA%/oep_studio/settings.json`. A
`SettingsRegistry` lets future subsystems (AI Providers, Plugins)
register their own settings pages without modifying the Settings
Workspace itself. Most pages bind real, validated, persisted values; a
handful (Plugins, several Appearance/Workspace/Diagnostics controls)
are honest placeholders where the underlying subsystem doesn't exist
yet — see `docs/STUDIO_SETTINGS.md`. As of Work Package 018, Studio has
its first production AI provider: **`AnthropicProvider`**, using
Anthropic's Messages API. API keys are stored in Windows Credential
Manager through a new, reusable `CredentialStore` abstraction
(`lib/core/security/`, implemented with `dart:ffi` calls directly to
`advapi32.dll` — no ATL, no COM, no third-party plugin) — never in
Settings, a Repository, or a Knowledge Session. The Artificial
Intelligence settings page now has a real provider picker, a real API
Key field, and a real Test Connection button (Connected/Authentication
Failed/Network Error/Provider Error). `MockAiProvider` remains the
default for every automated test — see `docs/ANTHROPIC_PROVIDER.md`.
As of Work Package 024, Studio has **Diagram Studio** (SDD-024 through
SDD-030) — the second major Primary Workspace, and the production
diagram-editing experience for the Open Engineering Platform's
Engineering Engine (`oep_engine`, a separate repository). Diagram
Studio is built entirely on the Engineering Engine's public API: node/
relationship editing, multi-selection, undo/redo, clipboard, orthogonal
routing, manual wire editing, annotations, drafting layers, placement
tools (rotate/mirror/array-place/replace-symbol), advisory editing
constraints, and Engineering Graph + Diagram Layout search, all wired
into Studio's own toolbars, dockable panels (Diagram Explorer, Layer,
Search, Validation, Annotation, Recent Commands), and the shared
Property Inspector (one new bridging field, `selectedEngineeringInspectable`,
rather than a duplicated selection system). Diagram documents
(Engineering Graph + Diagram Layout together) persist independently of
the Foundation repository, mirroring Knowledge Studio's own
Studio-owned-persistence-plus-ambient-Foundation-repository precedent —
see `docs/DIAGRAM_STUDIO_INTEGRATION.md`, `STUDIO_ENGINE_HOST.md`,
`WORKSPACE_INTEGRATION.md`, `PROPERTY_INSPECTOR_INTEGRATION.md`, and
`REPOSITORY_INTEGRATION.md`.
As of Work Package 025, Knowledge Studio and Diagram Studio are
synchronized views of one **Engineering Project** rather than two
independent workspaces: the Engineering Engine instance was hoisted out
of Diagram Studio's own page into a shared, app-lifetime service, so
selection, validation, and recent history stay live and consistent no
matter which workspace is active. A new **Project Explorer** workspace
(`/project`, second item in the Navigation Rail) gives one tree view
across Knowledge, Diagrams, Evidence, Components, Validation, and AI
Sessions. The Search Workspace now searches both Foundation and the
Engineering Engine and no longer requires an open repository. Evidence
Links gained their own Property Inspector mode with a "Go to Evidence"
action navigating to the Knowledge Session material/region they
reference. The global Validation page is real (previously a stub),
sharing its findings list and Suggested Fixes with Diagram Studio's own
validation panel, with click-to-navigate and an "Ask AI" entry point
that adds validation and evidence context to the same AI request
pipeline Diagram Studio already used. No new engineering editing
features, repository features, Marketplace, or Simulation were added —
see `docs/ENGINEERING_PROJECT.md`, `WORKSPACE_SYNCHRONIZATION.md`,
`UNIFIED_SEARCH.md`, `PROJECT_EXPLORER.md`, and
`WORKFLOW_ARCHITECTURE.md`.

Diagram Studio's architecture is frozen as of **AP-DS-001** (Constitution,
Architecture Specification, Interaction/Document/Engineering Models,
Canvas/Editing Architecture, Performance Targets, Roadmap — all under
`docs/architecture/diagram_studio/`), refined by **AP-DS-001A** (Editor
Completion & UX Refinement): resize support, multi-node alignment
guides, a real Reset View + coordinate display, Align/Distribute
toolbar wiring, an OS-clipboard fallback, viewport culling +
`RepaintBoundary` adoption, and — closing the largest gap — real
document Autosave, Recent Files, Recovery, and metadata, all within the
existing local-JSON document model (still no Foundation Repository
persistence, still no Engineering Intelligence Platform integration —
both remain explicitly out of scope until AP-DS-002/AP-DS-003). See
`docs/IMPLEMENTATION_STATUS.md`'s AP-DS-001A section for the full,
independently-verified list of what changed and what remains open.

**AP-DS-001B** (Professional UX & Performance) is the final refinement
phase before Foundation integration: a real interaction-test harness
for the canvas's drag/box-select/connect/resize gestures (previously
only exercised indirectly), a benchmark suite covering 10 to 100,000
objects (`docs/architecture/diagram_studio/PERFORMANCE_REPORT.md`) that
found and fixed a ~113x rendering cost (unculled wire painting) and a
real crash bug, an `EditActionsToolbar` closing the toolbar-discoverability
gap for Undo/Redo/Cut/Copy/Paste/Duplicate/Delete, and a full keyboard-
shortcut inventory. Diagram Studio is declared ready for Foundation
Runtime integration (AP-DS-002) — a small set of editor-polish items
(inspector multi-selection audit, full accessibility certification, a
short-window panel-overflow bug, live GPU profiling) are honestly
carried forward as non-blocking, independent of the persistence layer
AP-DS-002 introduces. See `docs/IMPLEMENTATION_STATUS.md`'s AP-DS-001B
sections and `docs/architecture/diagram_studio/IMPLEMENTATION_ROADMAP.md`.

**AP-DS-002** (Engineering Repository Integration) replaced Diagram
Studio's local-JSON-only persistence with real Foundation Runtime
integration: a small, additive Foundation-side schema extension (an
opaque `content` field on `EngineeringObject`, `OEP_API_VERSION` 20,
ABI unchanged), real Engineering Object/Relationship decomposition for
every diagram node and wire (see
`docs/architecture/diagram_studio/ENGINEERING_MAPPING.md`), a
`DiagramRepositoryService` consuming `FoundationBridge` exclusively,
migration from legacy local documents with verification and disclosed
rollback limitations (`docs/architecture/diagram_studio/
MIGRATION_GUIDE.md`), and new Project/Repository Browser and Package
Management UI. Six previously-unbound C API functions (including
`oep_object_update`/`oep_object_delete`, a real gap this session's own
platform review had flagged) are now wired through Dart FFI. Local
JSON is not removed — it remains legitimate for Autosave/Recovery and
as the migration source format; see `docs/IMPLEMENTATION_STATUS.md`'s
AP-DS-002 section for the full, honest exit-criteria assessment,
including what's disclosed as not-yet-diffed or not-yet-atomic rather
than silently claimed complete.

**AP-DS-003** (Engineering Intelligence Workspace) connected Diagram
Studio to the Engineering Intelligence Platform for live validation,
analysis, reasoning, and recommendations while authoring — through
exactly one class, `DiagramIntelligenceService`
(`lib/diagram_studio/intelligence/`), which contains zero engineering
logic of its own. A canvas overlay shows validation/analysis markers;
five embedded panels (Recommendation, Engineering Explorer, Knowledge
Graph, Query Console, Knowledge Sessions) adapt the pre-existing
read-only Engineering Intelligence pages (WP-EKE-008) rather than
reinventing their rendering; canvas and panel selection stay
bidirectionally synchronized. A debounced sync path feeds EIP
independently of AP-DS-002's still-open document-bar Save gap. See
`docs/architecture/diagram_studio/ENGINEERING_WORKSPACE.md` and
`docs/IMPLEMENTATION_STATUS.md`'s AP-DS-003 section for the full
account, including disclosed limitations (no cross-isolate async FFI,
no live-scale latency profiling, the local structural validation panel
and EIP's `ValidationEngine` remain two separate systems).

**AP-DS-004** (Engineering Publishing & Deliverables) added a complete
publishing pipeline: professional PDF/SVG/PNG diagram export (true
vector, not a rasterized screenshot), print preview, six tabular
engineering reports (Bill of Materials, Wire List, Connector Report,
Harness Report, Relationship Report, Engineering Object Report) with
CSV/Markdown/PDF export, Validation and Reasoning reports sourced
exclusively from `DiagramIntelligenceService` (never computed
locally), title blocks with revision management, and an Engineering
Exchange readiness checklist — verified to contain no networking or
upload code, per the spec's explicit "preparation only" requirement.
Reachable via a new "Publishing…" button in the document bar. See
`docs/architecture/diagram_studio/PUBLISHING_AND_DELIVERABLES.md` and
`docs/IMPLEMENTATION_STATUS.md`'s AP-DS-004 section for the full
account, including a real gap found during independent verification
(a print-preview dialog that existed but had no reachable UI entry
point until this pass added one) and disclosed limitations (no true
multi-sheet Drawing/Installation/Service Packages, no Page Setup
dialog, node-level-only connector connectivity, unbenchmarked
100,000-object performance).

**AP-DS-005** (Engineering Verification & Simulation) added a real,
deterministic logical Simulation Engine (`oep_engine`) reached
exclusively through `DiagramSimulationService` — sessions, step/pause/
resume/replay playback, fault injection, and Verification/Fault/
Propagation/Power/Ground/Simulation reports, all visualized on the
canvas via `SimulationStateOverlay`. See
`docs/architecture/diagram_studio/SIMULATION_USER_GUIDE.md` and this
work's own architecture docs (`SIMULATION_ARCHITECTURE.md`,
`SIGNAL_PROPAGATION.md`, `VERIFICATION_ENGINE.md`,
`FAULT_INJECTION.md`).

**WP-DS-005A** (Engineering Instruments Framework & Digital
Multimeter) added a permanent Instrument Dock (bottom dock, floating
window, resize, auto-hide, tabs, layout persistence) hosting the first
Engineering Instrument: a Digital Multimeter with every
`MeasurementType` wired to the real Simulation Engine (voltage DC/AC,
resistance, continuity, current, diode, frequency, duty cycle, power,
ground potential; capacitance/temperature shown as not-yet-supported),
a two-probe click-to-place/drag/snap system reusing the canvas's own
node hit-testing, Manual/Expected/Comparison/Live-Simulation/Historical
measurement modes, automatic Continuity path highlighting, JSON-backed
Measurement History (replay/clear/export) and Bookmarks, and a
light-touch Verification-findings integration. Zero engineering
computation lives in the Instruments Framework — every reading is
requested from, and only rendered from, the real engine. See
`docs/ENGINEERING_INSTRUMENTS.md`, `docs/DIGITAL_MULTIMETER.md`,
`docs/MEASUREMENT_SYSTEM.md`, and `docs/IMPLEMENTATION_STATUS.md`'s
WP-DS-005A section for the full account, including disclosed gaps
(only one of ten planned instruments built; probe snapping is
node-level only; Hover Measurements, Repository-backed persistent
measurements, and most of the broader Engineering Integration list
were deferred).

**WP-DS-006** (Engineering Workbench Shell, Phase 1) transformed Diagram
Studio's own route into an application shell: Diagram Studio becomes the
Diagram Perspective inside a new Engineering Workbench
(`lib/workbench/`), hosted one level inside `StudioShell` — not a
replacement for it (see `docs/architecture/diagram_studio/ENGINEERING_WORKBENCH.md`
for that scope decision). The Workbench owns a Perspective Manager (10
pluggable Perspectives: Home, Dashboard, Diagram, Inspection,
Engineering, Simulation, Instruments, Publishing, Library, Review — each
with an independently-persisted layout), a generic Dock Manager (Left/
Right/Bottom/Floating/Hidden/Auto-hide/Tabbed docks, `DockManager`/
`DockRegion`/`DockPanelClient`), and thin Theme/Command Manager
accessors over this codebase's existing `StudioColors` and
`CommandRegistry`. `DiagramStudioPage` is embedded completely unchanged
inside the Diagram Perspective — no engineering functionality
regressed. The Instruments Perspective demonstrates the new generic Dock
Manager with a real, independent adapter (`InstrumentDockPanelClient`)
around WP-DS-005A's own, untouched `EngineeringInstrument` contract,
while disclosing an honest constraint: it has no live diagram session of
its own to construct a real Digital Multimeter against, so it shows a
clearly-labeled empty state rather than fabricating data. The other 8
non-Diagram Perspectives are real, registered, switchable, but their
workspace content is an honest "not yet built" placeholder — Phase 1 is
shell-only, per the governing spec. See
`docs/architecture/diagram_studio/ENGINEERING_WORKBENCH.md` and
`PERSPECTIVE_FRAMEWORK.md`.

`docs/IMPLEMENTATION_STATUS.md` has the full picture of what exists
today and what is still a placeholder (object/relationship *update*
and *delete* are now bound and exposed as of AP-DS-002 — this was
previously true and is corrected here; repository creation/
deletion remain entirely unexposed; Knowledge Studio's Repository
Matches panel remains placeholder content (the "AI Suggestions" panel
is now a real session-wide status summary as of Work Package 016 — the
review workflow itself lives in the AI Review Workspace dialog); PDF
text extraction/selection, non-rectangle Evidence Region shapes, a
generalized Source-Material-/Page-Selection-level Evidence Link, OCR
result editing, true on-screen TIFF preview, Engineering Entity pattern
editing, Engineering Context pattern/keyword editing, any AI provider
beyond Anthropic (OpenAI, Gemini, Ollama, LM Studio, OpenRouter), and
any Plugin implementation are out of scope).

The desktop window has a minimum size of 1000×700 logical pixels
(`windows/runner/win32_window.cpp`) — below that, the Navigation Rail
and Property Inspector don't leave enough room for the Primary
Workspace.

## Getting Started

Requires the Flutter stable channel and, for Windows builds, Visual
Studio Build Tools with the "Desktop development with C++" workload.

Studio expects `oep_foundation` to be checked out as a sibling
directory (`../oep_foundation` relative to this repository) — see
`native/foundation_bridge/CMakeLists.txt` (`OEP_FOUNDATION_SOURCE_DIR`)
if your checkout is laid out differently.

OCR (Work Package 013) requires a system-installed
[Tesseract OCR](https://github.com/tesseract-ocr/tesseract) with
`tesseract` on `PATH` (e.g. `winget install --id UB-Mannheim.TesseractOCR`
on Windows) — unlike every other native dependency, it is not bundled
by `flutter build windows`. Everything else works without it; only the
OCR Layer Viewer needs it. See `docs/OCR_PIPELINE.md` § Architectural
Observations.

```
flutter pub get
flutter run -d windows
```

## Documentation

Studio Design Documents live under `docs/`:

* `ARCHITECTURE.md` (SDD-001) — Studio/Foundation boundary
* `DESIGN_LANGUAGE.md` (SDD-002) — visual identity
* `NAVIGATION_FRAMEWORK.md` (SDD-003) — navigation rail, status bar
* `WORKSPACE_FRAMEWORK.md` (SDD-004) — workspace layout and lifecycle
* `FOUNDATION_BRIDGE.md` (SDD-006) — Studio/Foundation integration boundary
* `DASHBOARD.md` (SDD-007) — Dashboard requirements
* `CONNECTION_MANAGER.md` — Runtime/Repository/Selection state ownership
* `SEARCH_WORKSPACE.md` — search workflow, relationship workflow, search history
* `KNOWLEDGE_STUDIO.md` — workspace layout, session lifecycle, state ownership
* `KNOWLEDGE_SESSION_FORMAT.md` — persisted session file format, Source Material/Relationship Candidate models
* `EVIDENCE_MODEL.md` — PDF Source Viewer, Evidence Region/Evidence Link/Page Selection models
* `KNOWLEDGE_CANDIDATES.md` — Knowledge Candidate/Procedure/Procedure Step/Specification/Validation models
* `ENGINEERING_INSTRUMENTS.md` — Engineering Instruments Framework + Instrument Dock (WP-DS-005A)
* `DIGITAL_MULTIMETER.md` — Digital Multimeter instrument (WP-DS-005A)
* `MEASUREMENT_SYSTEM.md` — Probes, Measurement Modes, History, Bookmarks (WP-DS-005A)
* `KNOWLEDGE_GRAPH.md` — Knowledge Session Graph/Provenance/Dependency/Session Health models
* `REPOSITORY_COMMIT.md` — Commit Plan/Candidate Conversion/Transaction Model/Commit Report
* `OCR_PIPELINE.md` — OCR architecture/cache/overlay/search/confidence models
* `ENGINEERING_ENTITY_EXTRACTION.md` — Pattern engine/Entity model/Pattern library/Validation model/Review workflow
* `ENGINEERING_CONTEXT.md` — Context model/Detection rules/Navigation/Validation model/Persistence
* `AI_PROVIDER_ARCHITECTURE.md` — Provider abstraction/registry/Prompt Service/Mock provider/Review workflow
* `STUDIO_SETTINGS.md` — Settings architecture/Registry/Search/Storage/Versioning/Migration
* `ANTHROPIC_PROVIDER.md` — Provider implementation/Authentication/Secure credential storage/Prompt execution/Error handling
* `DIAGRAM_STUDIO_INTEGRATION.md` — Diagram Studio overview, ownership boundary, module layout, reuse-vs-duplication decisions
* `architecture/diagram_studio/ENGINEERING_WORKBENCH.md` — Engineering Workbench shell architecture, the 8 managers (WP-DS-006)
* `architecture/diagram_studio/PERSPECTIVE_FRAMEWORK.md` — how to add a Perspective, PerspectiveManager/WorkbenchLayoutManager/DockManager how-to (WP-DS-006)
* `STUDIO_ENGINE_HOST.md` — `EngineHost`'s role, lifecycle, and what it deliberately does not do
* `WORKSPACE_INTEGRATION.md` — routing, toolbars, panels, settings, workspace persistence
* `PROPERTY_INSPECTOR_INTEGRATION.md` — the `EngineeringInspectable` bridge and the seven new inspector modes
* `REPOSITORY_INTEGRATION.md` — `DiagramDocument`, the Foundation schema gap, and how it's resolved
* `ENGINEERING_PROJECT.md` — what an Engineering Project is and why it lives in Studio
* `WORKSPACE_SYNCHRONIZATION.md` — the shared Engine service, and what does/doesn't stay synchronized across workspaces
* `UNIFIED_SEARCH.md` — `UnifiedSearchResult`, merging Foundation and Engine search without touching either source type
* `PROJECT_EXPLORER.md` — the `/project` workspace's tree structure and its "New Project" flow
* `WORKFLOW_ARCHITECTURE.md` — Evidence/Validation/AI integration, and the composed cross-workspace workflow test
* `UI_MOCKUPS.md` — authoritative visual references
* `IMPLEMENTATION_STATUS.md` — current implementation status
