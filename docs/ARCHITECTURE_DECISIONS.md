# Architecture Decisions

A living Architecture Decision Record for `oep_engine`. The SDDs (024–029)
define the architecture and are frozen; this document records *why*
specific implementation decisions were made within that architecture, so
future engineers (and future AI sessions) don't have to rediscover the
reasoning.

Each entry: context, decision, status.

---

## ADR-001 — Provider Interface + EngineRegistry Architecture

**Context.** SDD-029 requires that extensions "never modify Core" and
"register through Engine." A naive implementation would have
`EngineeringEngine` construct and hold concrete service instances directly,
which means every new implementation (a Marketplace package, an alternate
graph backend, a test double) requires changing the engine's constructor.

**Decision.** Every capability (`GraphProvider`, `SymbolProvider`,
`ValidationProvider`, `NavigationProvider`, `SelectionProvider`,
`ImportProvider`, `ExportProvider`, `SimulationProvider`) is defined as an
abstract interface under `lib/core/interfaces/`. `EngineeringEngine` never
resolves one directly — it owns an `EngineRegistry`, and all resolution
goes through it:

```
EngineeringEngine -> EngineRegistry -> {GraphProvider, SymbolProvider, ...}
```

Registration is by interface `Type`, not by concrete class. Concrete
Phase 1 implementations (`InMemoryGraphProvider`, `SymbolLibrary`,
`ValidationService`, ...) register against the interface. A future
Marketplace package or alternate implementation registers the same way —
`EngineeringEngine`'s core never changes.

**Status.** Accepted. See `lib/core/engine_registry.dart`,
`lib/core/engineering_engine.dart`.

---

## ADR-002 — Engineering Graph as Canonical Runtime

**Context.** SDD-024/025/027 are explicit that the Engineering Graph
represents engineering knowledge, and that visual layout is not
engineering knowledge.

**Decision.** `EngineeringNode`/`EngineeringRelationship`/
`EngineeringGroup` (SDD-027) carry no position, color, rotation, or zoom —
only `RuntimeMetadata` (selected/visible/expanded/highlighted), which is
explicitly transient and excluded from `toJson()`. Anything visual belongs
to a View (see ADR-003).

**Status.** Accepted. See `lib/core/graph/models/`.

---

## ADR-003 — Rendering as a View, Not a Top-Level Engine Subsystem

**Context.** The original Phase 1 proposal treated rendering as a
top-level `DiagramService` alongside `GraphService`, `SymbolLibrary`, etc.
Formal review (2026-07-13) corrected this: the Graph is the single
canonical center of the architecture, and a diagram is only one of several
possible visualizations of it (Harness, Diagnostic, Physical Layout,
Simulation, Print — SDD-024/025).

**Decision.** Rendering lives under `lib/core/views/`, with `Diagram View`
as the first View (`lib/core/views/diagram/`). `EngineeringView<TScene>`
is the shared contract: `TScene render(EngineeringGraph graph)` — stateless,
read-only, produces a scene description, never mutates the graph and never
becomes a second source of truth. Future Views are added as sibling
folders under `lib/core/views/` without the Graph or existing Views
changing. `DiagramView` itself stays free of `dart:ui`/Flutter — it
produces a `DiagramScene` (plain Dart data: `DiagramNodeVisual`,
`DiagramWireVisual`); actual painting happens in the Demonstration Host
(see ADR-005).

**Status.** Accepted. See `lib/core/views/`, `lib/diagrams/diagrams.dart`.

---

## ADR-004 — No Foundation Bridge Implementation in Phase 1

**Context.** SDD-025/026 require the Engineering Engine to talk to
Foundation "exclusively through the existing Foundation Bridge." No
reusable Dart Foundation Bridge package exists outside `oep_studio`'s
internal FFI code, and `OEP-SPEC-022 (Foundation Bridge Support)` in
`oep_foundation` is still `Draft`. SDD-025 explicitly allows this: "Engineering
Engine shall operate without an open Repository where practical. Temporary
Engineering Graphs may exist before Repository Commit." This is a
documented dependency gap, not a blocker — building a real Bridge
implementation would mean modifying `oep_foundation` and/or `oep_studio`,
which is out of scope for this work package.

**Decision.** `FoundationBridgePort` (`lib/core/bridge/foundation_bridge_port.dart`)
is defined as an abstract interface only — no implementation ships.
`GraphService` persistence is backed instead by `InMemoryGraphProvider` +
`JsonFileSerializationProvider` (local JSON), which is sufficient for
Phase 1 verification. `SerializationProvider` is a separate, storage-
independent abstraction specifically so a future Foundation-backed
serializer can be substituted without `GraphService` or `GraphProvider`
changing.

**Status.** Accepted; **flagged as an open dependency for architectural
review** before any real Foundation integration is attempted.

---

## ADR-005 — `lib/core/` vs. Top-Level Public Folders

**Context.** The pre-existing empty scaffold under `lib/` contained
parallel folders — both `lib/core/graph/` and `lib/graph/`, both
`lib/core/symbols/` and `lib/symbols/`, etc. — with no documentation
disambiguating them.

**Decision.** `lib/core/` holds the actual implementation (SDD-026: "No
Flutter Widgets. No BuildContext. No Widget dependencies" — the entire
`lib/core/` tree is plain Dart, verified by `flutter analyze` finding zero
Flutter imports there). The top-level folders (`lib/graph/`,
`lib/symbols/`, `lib/exporters/`, `lib/importers/`, `lib/simulation/`,
`lib/diagrams/`, `lib/bridge/`, `lib/services/`, `lib/shared/`) are thin
barrel files re-exporting the public surface, matching SDD-026's
public/private split ("Studio shall never depend upon Engineering
implementation details"). `lib/engineering_engine.dart` is the single root
entry point consumers import. No scaffolded folder was deleted or moved;
folders not yet populated in Phase 1 (`lib/models/`, `lib/public/`,
`lib/extensions/*`) remain reserved for later phases.

**Status.** Accepted, documented for correction if this interpretation
turns out to be wrong.

---

## ADR-006 — Demonstration Host, Not Diagram Studio

**Context.** STUDIO-TASK-000063 originally described a "Diagram Studio
Shell." Formal review (2026-07-13) corrected this: Diagram Studio belongs
to `oep_studio`, which this work package is explicitly forbidden from
modifying, and SDD-025/026 forbid Flutter Widgets in the Engineering
Engine itself.

**Decision.** `example/` is a standard Flutter-package example app — an
**Engineering Engine Demonstration Host**, not Diagram Studio. It exists
only to verify the Engineering Engine end-to-end (`flutter build windows`,
manual verification, the `integration_test/` suite) and consumes only the
public API (`package:engineering_engine/engineering_engine.dart`). It
implements a renderer for `DiagramView`'s scene output, Graph Explorer,
Property Inspector, Evidence Panel, Validation Panel, and Status Bar
panels purely as verification surface. Nothing here is intended to be
reused as Diagram Studio's implementation — only the underlying Engineering
Engine behavior it exercises is.

**Status.** Accepted.

---

## ADR-007 — Symbol Loading: `dart:io` for Core, `rootBundle` for the Host

**Context.** `SymbolLibrary` (engine core) must stay Flutter-independent,
but the Demonstration Host bundles symbol JSON/SVG as Flutter assets,
which aren't addressable as loose files at runtime.

**Decision.** `SymbolLibrary.initialize()` scans a real filesystem
directory via `dart:io` — correct for plain-Dart contexts (unit tests,
future tooling) where `assets/symbols` is a real path. A separate,
narrow method, `SymbolLibrary.registerFromJson(String)`, lets any host
that can only produce raw JSON text (like a Flutter app reading via
`rootBundle`) register the same symbol data without the core needing to
know about Flutter's asset system. The Demonstration Host's
`symbol_bundle_loader.dart` is the only place this is used.

**Status.** Accepted.

---

## ADR-008 — Provider/Registry Architecture Validated, No Code Change Required (WORK_PACKAGE_020)

**Context.** WORK_PACKAGE_020's complete architectural analysis of
`engine_reference_only/` (see `docs/EKE_*.md`) surfaced several concrete
future capabilities the Engineering Engine doesn't yet implement:
directional power/ground path tracing, system/topology recognition,
orthogonal wire routing, confidence scoring, and others (full list in
`docs/EKE_MIGRATION_MATRIX.md`). The work package's own scope explicitly
allows (but does not require) adding "missing interfaces, missing
extension points, missing abstractions" if analysis reveals a genuine
structural gap.

**Finding.** No such gap was found. `EngineRegistry.register<T extends
Object>()` (ADR-001) is fully generic — a future `SystemRecognitionProvider`,
a confidence-scoring service, or any other new capability registers the
same way `GraphProvider`/`SymbolProvider`/etc. already do, with zero
changes to `EngineRegistry` or `EngineeringEngine` itself.
`DiagramRendererRegistry` (ADR-003) is likewise already an open
registration point for new renderers (e.g. a future orthogonal-routing-
aware painter). `ValidationProvider`'s contract (`validate(graph) ->
ValidationReport`) doesn't need to change to add new rules — new checks
are additions to `ValidationService`'s private rule list, not interface
changes.

**Decision.** No Engineering Engine code changes are made as part of
WORK_PACKAGE_020. The provider/registry architecture designed in Phase 1
(ADR-001) is confirmed, under real scrutiny against a mature reference
implementation, to already accommodate every extension point this
analysis identified. Feature migration itself (implementing any of the
above) remains explicitly out of scope for this work package and awaits
separate authorization per item, per `docs/EKE_MIGRATION_MATRIX.md`.

**Status.** Confirmed.

---

## ADR-009 — Confidence as a Future Object-Model Field (proposed, not implemented)

**Context.** `docs/EKE_GRAPH_COMPARISON.md` identifies that the reference
implementation threads a `confidence` value through nearly every object
(components, wires, systems, topology matches), while SDD-027's
`EngineeringNode`/`EngineeringRelationship` have no dedicated confidence
field — it would currently have to be smuggled into the untyped
`metadata` map. This matters because the Engineering Engine's own future
Import Engine (OCR/vision-derived nodes) will need it for exactly the
same reason the reference does: extracted data is often uncertain, and
uncertainty needs a home that validation, rendering, and review UI can
all rely on consistently.

**Decision.** Not implemented. This would be an amendment to SDD-027,
which is `Frozen` — the correct process is architectural review, not a
Phase-2-analysis-driven code change. Flagged here explicitly so it isn't
lost, and cross-referenced from `docs/EKE_GRAPH_COMPARISON.md` and
`docs/EKE_MIGRATION_MATRIX.md`.

**Status.** Proposed — awaiting architectural review.

---

## ADR-010 — Electrical-Equivalence `Net` Concept (proposed, not implemented)

**Context.** `docs/EKE_GRAPH_COMPARISON.md` identifies the reference's
`Net` object (many wires/connectors that are all the same electrical
node, e.g. "battery positive" spanning several physical wires) as a real
gap in SDD-027: nothing today distinguishes "these nodes are organized
together" (`EngineeringGroup` — a Circuit/Harness/Assembly/Subsystem/
Module) from "these relationships are electrically the same point,"
which is a different, narrower claim.

**Decision.** Not implemented. Like ADR-009, this is a candidate SDD-027
amendment, not a Phase-2-analysis code change — it needs architectural
review to decide whether it's a new node category, a new top-level graph
concept, or an extension of `EngineeringGroup`.

**Status.** Proposed — awaiting architectural review.

---

## ADR-011 — Movement Is Layout Data, Never Graph Data (WORK_PACKAGE_021)

**Context.** WORK_PACKAGE_021's Move System (ENGINE-TASK-000081) says
"Movement updates Engineering Graph coordinates only." SDD-024
Architecture Rule 5 (frozen, **not** amended by SDD-024A, which
reaffirms "Views... shall never own engineering state" without adding any
position concept to the object model) states "Layout is not Engineering
Knowledge... The graph contains no visual layout information." Storing
x/y directly on `EngineeringNode` would violate that frozen rule.

**Decision.** Position lives in a new sibling concept —
`DiagramLayoutState`, tracked by a `LayoutProvider` resolved through
`EngineRegistry` exactly like `GraphProvider` — not as fields on
`EngineeringNode`. `EditingSession { graph, layout }` bundles both under
one command/undo-redo history, so "movement updates the Engineering
Engine's canonical editing session" is true in spirit, while
`EngineeringGraph` itself stays entirely layout-free. SDD-024 Rule 5
stays intact; layout becomes its own registry-resolved provider, which is
also consistent with "layout belongs to the renderer" (SDD-024) — it
isn't the *View's* state either, it's the engine's, just not the
*Graph's*.

**Status.** Accepted. Flagged prominently at plan time and left
uncorrected through implementation — reversible if this reading of the
tension turns out to be wrong.

---

## ADR-012 — Routing Confirms the Provider Architecture Extends Cleanly (WORK_PACKAGE_021)

**Context.** ADR-008 (WORK_PACKAGE_020) predicted that any future
capability the EKE analysis identified — including a routing engine —
would register through `EngineRegistry` with zero changes to
`EngineRegistry` or `EngineeringEngine` itself, since `register<T extends
Object>()` is already fully generic.

**Decision/Finding.** Confirmed in practice: `RoutingProvider` +
`OrthogonalRoutingProvider` (ENGINE-TASK-000086 — the one capability this
work package explicitly requires to be Marketplace-replaceable) were
added exactly like `GraphProvider`/`SymbolProvider`/etc., with the only
change to `EngineRegistry` being one new typed convenience getter
(`registry.routing`) — a pure addition, not a modification of existing
behavior. `LayoutProvider` and `ClipboardProvider` followed the identical
pattern. This is now the second work package in a row where the
provider/registry design absorbed new requirements without architectural
strain.

**Status.** Confirmed.

---

## ADR-013 — Property Editing Excludes Net/Confidence (WORK_PACKAGE_021)

**Context.** ENGINE-TASK-000085 explicitly gates two properties: "Net (if
approved through SDD amendments)" and "Confidence (if approved through
SDD amendments)." SDD-027A remains `Status: Proposed` as of this work
package — not accepted.

**Decision.** `UpdateNodePropertiesCommand`/`UpdateRelationshipPropertiesCommand`
support arbitrary property patches today (Node/Relationship/Port/Group/
Evidence Link), but neither `Net` nor `Confidence` is implemented,
consistent with ADR-009/ADR-010 remaining `Proposed`. Because the
property-update commands take a generic `Map<String, Object?>` patch
rather than named fields, adding Net/Confidence later (once SDD-027A is
accepted) requires no redesign of the command layer — only the SDD-027
object-model amendment itself, reviewed on its own.

**Status.** Accepted (as a scoping decision) — Net/Confidence editing
remains blocked on SDD-027A's approval, tracked in ADR-009/ADR-010.

---

## ADR-014 — ViewState as a Fifth, Permanently Separate Runtime Concern (WORK_PACKAGE_022)

**Context.** WORK_PACKAGE_022 introduces zoom/pan/viewport size/visible
layers/grid/guides-visible/theme/render options/hovered-port — none of
which is Engineering Graph knowledge (SDD-024/025), Diagram Layout
(ADR-011), or `GraphSelection`/`FocusState` (`docs/SELECTION_MODEL.md`).
The spec is explicit: "Maintain the architectural separation between:
Engineering Graph, Diagram Layout, ViewState, Selection, Undo/Redo... Do
not merge responsibilities between these systems... ViewState and
Selection shall never pass through the Command system."

**Decision.** `ViewState`/`ViewStateProvider`/`ViewStateService`
(`docs/VIEW_STATE.md`) are built structurally identical to
`SelectionService` — a single live value, a change stream, explicit
setters, resolved through `EngineRegistry` (`registry.viewState`) exactly
like every other capability (ADR-001) — and never touch
`CommandHistory`/`EditingService`. This makes five runtime systems, each
with one job and one boundary:

```
Engineering Graph  — knowledge
Diagram Layout     — node positions
ViewState          — viewport/grid/guides/theme/hover (new)
Selection          — GraphSelection/FocusState
Undo/Redo          — CommandHistory over {graph, layout} only
```

The precedent wasn't new to invent — WORK_PACKAGE_021 already established
that Selection and group collapse/expand/visibility stay outside command
history because they're runtime view concerns, not engineering edits
(`docs/UNDO_REDO.md`, "What's deliberately outside undo/redo"). ViewState
is the same argument applied to a new category of runtime state.

**Status.** Accepted. See `lib/core/viewstate/`, `lib/viewstate/viewstate.dart`.

---

## ADR-015 — Port Hover/Identity Stays View-Layer, Confirming the ADR-012 Boundary (WORK_PACKAGE_022)

**Context.** ENGINE-TASK-000092 asks for port hover/highlight/drag-to-port
interaction. The obvious naive approach — giving
`EngineeringRelationship` named `sourcePort`/`targetPort` fields — would
be an SDD-027 object-model change, and SDD-027 is frozen.
`docs/ROUTING_ENGINE.md` (WORK_PACKAGE_021) already flagged this exact
tension for routing's "nearest port" behavior and deliberately scoped
around it rather than amending SDD-027.

**Decision.** `PortReference{nodeId, portId}` (`docs/PORT_INTERACTION.md`)
is a View-layer-only value type — never added to
`EngineeringRelationship`. `ViewState.hoveredPort` carries hover;
`FocusState.port` (unchanged, WORK_PACKAGE_021) continues to carry
selection. Drag-to-connect/reconnect commits through the **existing**
`CreateRelationshipCommand`/`ReconnectRelationshipCommand` — no new
command type, because the underlying graph mutation isn't new, only the
gesture that triggers it is.

**Status.** Accepted — consistent with, and reconfirming, the WORK_PACKAGE_021
port-snapping scoping decision in `docs/ROUTING_ENGINE.md`. If a future
work package needs true named-port binding on relationships, that remains
a separate SDD-027 amendment, reviewed on its own.

---

## ADR-016 — Routing Determinism and Shared Trunks Confirm the Provider Architecture Again (WORK_PACKAGE_022)

**Context.** ADR-012 confirmed the provider/registry architecture absorbed
`RoutingProvider` cleanly in WORK_PACKAGE_021. WORK_PACKAGE_022 adds a
harder requirement: "Given identical Engineering Graph, Diagram Layout and
routing configuration, identical routing output shall always be
produced" — applying not just to today's `OrthogonalRoutingProvider` but
to every future `RoutingProvider` implementation.

**Decision/Finding.** Confirmed achievable with no interface-breaking
change: the determinism contract is documented directly on
`RoutingProvider` (`lib/core/interfaces/routing_provider.dart`) so it
travels with the interface, `DiagramView.render` sorts relationships by
`id` before routing (closing a `Map`-iteration-order determinism leak that
had nothing to do with any specific routing algorithm), and "Shared
Trunks" was added via one new **optional** field
(`RoutingRequest.trunkKey`) plus one new `RoutingContext` method
(`allocateTrunkColumn`) — existing callers and any future provider that
ignores `trunkKey` see no behavior change. See
`docs/ROUTING_ARCHITECTURE.md`.

**Status.** Confirmed. Third work package in a row (after ADR-008,
ADR-012) where a new requirement was absorbed by the existing
provider/registry design without structural strain.

---

## ADR-017 — Ephemeral Guides vs. Undoable Align/Distribute: Two Different Kinds of "Alignment" (WORK_PACKAGE_022)

**Context.** ENGINE-TASK-000091 bundles two behaviors under "Alignment &
Guides" that are easy to conflate but architecturally distinct: smart
guides shown *while dragging* (a visual hint, discarded the instant the
drag ends) and Align/Distribute *actions* (a deliberate, explicit,
permanent layout mutation the user invokes from a menu).

**Decision.** `AlignmentGuideComputer` (pure function: dragged bounds +
sibling bounds + threshold → guide lines, and a `snapToGuides` helper) is
**not** a command and produces no history entry — it's recomputed on
every drag frame and never stored, exactly like `GridComputer`'s snap
math (`docs/GRID_SYSTEM.md`). `AlignNodesCommand`/`DistributeNodesCommand`,
by contrast, are real `EditingCommand` implementations following the same
capture-previous-position/apply/revert shape as WORK_PACKAGE_021's
`MoveNodesCommand` — because they permanently change `DiagramLayoutState`
and the user must be able to undo them. The dividing line is not "does
this involve alignment," it's "does this durably change layout state" —
the same test that already separates hover (ViewState) from a committed
connection (a command), per ADR-014/ADR-015.

**Status.** Accepted. See `lib/core/views/diagram/alignment_guide_computer.dart`,
`lib/core/editing/commands/align_nodes_command.dart`,
`lib/core/editing/commands/distribute_nodes_command.dart`.

---

## ADR-018 — Wire Overrides, Annotations, Layers, and Transforms Join Diagram Layout (WORK_PACKAGE_023)

**Context.** WORK_PACKAGE_023 needs four new pieces of visual state:
manual wire routes (ENGINE-TASK-000099), annotations
(ENGINE-TASK-000100), layers (ENGINE-TASK-000101), and per-node rotation/
mirror transforms (ENGINE-TASK-000102). The work package is explicit:
"No new architectural subsystems shall be introduced." SDD-024 itself
lists Rotation/Layer/Visibility as example Visual Layout data, alongside
Position — the same category ADR-011 already put `positions` in.

**Decision.** All four become new sibling maps on `DiagramLayoutState`
(`wireOverrides`, `annotations`, `layers`/`layerAssignments`,
`transforms`), following `positions`' exact shape: plain data, `withX`/
`withoutX` accessors, `toJson`/`fromJson`. None of it touches
`EngineeringGraph`. This is the fourth work package running the ADR-011
pattern (position → layout, not graph) against new kinds of visual
state, each time confirming the same container absorbs it without
strain.

**Status.** Accepted. See `lib/core/views/diagram/diagram_layout_state.dart`,
`docs/WIRE_EDITING.md`, `docs/ANNOTATION_SYSTEM.md`, `docs/LAYER_SYSTEM.md`.

---

## ADR-019 — Productivity Features Stay Host-Side; `EditingCommand`'s Interface Is Not Touched (WORK_PACKAGE_023)

**Context.** ENGINE-TASK-000105 asks for "Repeat Last Command," "Recent
Commands," "Favorites," "Custom Tool Palette," "Keyboard Shortcut
Manager," and "Context Menus." The obvious implementation of "Repeat
Last Command" would add a `repeat()` method to `EditingCommand`. Dart's
`implements` clause never inherits behavior — every one of the ~25
existing command classes uses `implements EditingCommand`, so adding any
new method to that interface, even with a default body written on the
abstract class, would force an edit to all ~25 files to satisfy the
interface contract.

**Decision.** `EditingCommand` is unchanged. `CommandHistory`/
`EditingService` gained one additive getter, `recentDescriptions` (built
from the *existing* undo stack, not a new tracking structure) for Recent
Commands. Everything else — Repeat, Favorites, Custom Tool Palette,
Keyboard Shortcut Manager, Context Menus — is Demonstration Host UI that
reuses the host's own existing action methods (each of which already
calls `engine.editing.execute(...)`), which is "reuse the existing
Command architecture" read literally rather than as a gap to fill with
new engine surface.

**Status.** Accepted — a scoping decision favoring a contained, additive
change over a mechanical edit to every command file for a
productivity nice-to-have. See `lib/core/editing/command_history.dart`.

---

## ADR-020 — `SearchProvider` Implements an SDD-026 Service That Was Never Built (WORK_PACKAGE_023)

**Context.** SDD-026 (frozen) already names a "Search Engine" and a
public `SearchService` in its Public Interface list — this predates
WORK_PACKAGE_023 entirely. WP019–022 never implemented it. WP023
(ENGINE-TASK-000104) requires Engineering Graph + Diagram Layout search
with Next/Previous/Zoom-To/Select/Center Result navigation.

**Decision.** `SearchProvider`/`SearchService`, registered through
`EngineRegistry` exactly like every other capability (ADR-001) — the one
new registry entry this work package adds, flagged explicitly here for
the reviewer even though it is implementing a spec entry that already
existed, not introducing new architecture. Result navigation
(Next/Previous/current) was added to the existing `NavigationService`
rather than invented as new state, since it's the same category of
runtime, non-persisted index `NavigationService` already tracked for
highlight paths. "Zoom To/Select/Center Result" were **not** built as
new engine methods — they're Demonstration Host compositions of
`ViewStateService.centerSelection`/`SelectionService.selectNode`, so
there is exactly one implementation of "select and center on this
thing," not two to keep in sync.

**Status.** Accepted. See `lib/core/interfaces/search_provider.dart`,
`lib/core/search/`, `docs/SEARCH_AND_NAVIGATION.md`.

---

## ADR-021 — Editing Constraints Are Advisory, Living in ViewState Like GridSettings (WORK_PACKAGE_023)

**Context.** ENGINE-TASK-000103 asks for Orthogonal Movement, Axis Lock,
Angle Constraint, Snap Priority, Connection Protection, and Minimum Wire
Length. The naive implementation would have commands (`MoveNodesCommand`,
wire-editing) read constraint state and conditionally change their own
behavior — which would mean `EditingCommand`s depending on `ViewState`,
breaking the boundary this entire work package (and WP022 before it) is
built to hold: Command History owns Graph/Layout mutations, ViewState is
a separate, permanently non-command runtime concern.

**Decision.** `EditingConstraints` lives on `ViewState` (identical role
to `GridSettings`, WORK_PACKAGE_022). `ConstraintMath`'s pure functions
(`applyOrthogonalLock`, `lockToAxis`, `snapAngle`,
`hasProtectedConnections`, `resolveDragPosition`) are called by the
Demonstration Host *before* it constructs a command — the command itself
never reads a constraint, never rejects anything, and stays exactly what
it has always been: a pure, unconditional function of its
`EditingSession`. Layer lock (ADR-018/`docs/LAYER_SYSTEM.md`) follows the
identical advisory pattern for the same reason.

**Status.** Accepted. See `lib/core/editing/editing_constraints.dart`,
`lib/core/editing/constraint_math.dart`, `docs/EDITING_CONSTRAINTS.md`.

---

## ADR-022 — Layout-Mutating Commands Must Resolve a Fallback Position, Not Assume a Tracked One (WORK_PACKAGE_023)

**Context.** While building and integration-testing the new Rotate/
Mirror/Array-Place commands, array-placing a node from the unmodified
seed graph silently produced no duplicate. The root cause turned out to
predate this work package: `AlignNodesCommand`/`DistributeNodesCommand`
(WORK_PACKAGE_022) read `DiagramLayoutState.positionOf(id)` directly and
silently skipped any node where it returned `null` — which is every node
that has never been dragged, since `DiagramLayoutState.positions` starts
empty and `DiagramView` only ever *renders* the auto-layout fallback
(`DiagramLayout.compute`) without persisting it back into the layout.
`CommandHistory.execute` pushes onto the undo stack unconditionally, so
undo becoming enabled never proved the operation actually did anything —
this dormant no-op had gone unnoticed since WORK_PACKAGE_022.

**Decision.** Added `DiagramLayout.resolvePosition(graph, layout,
nodeId)` — tracked position if present, else the identical fallback
`DiagramView` already renders with — and switched all five affected
commands (`AlignNodesCommand`, `DistributeNodesCommand`,
`RotateNodesCommand`, `MirrorNodesCommand`, `ArrayPlaceCommand`) to use
it. Fixed the two WORK_PACKAGE_022 commands as well as the three new
ones, rather than leaving an inconsistency where old and new
layout-mutating commands behave differently on a never-moved node.

**Status.** Accepted — a bug fix within the existing architecture, not a
new subsystem. See `lib/core/views/diagram/diagram_layout.dart`,
`docs/GRAPH_EDITING.md`. Regression-tested in
`test/editing/align_distribute_commands_test.dart` and
`test/editing/placement_commands_test.dart` ("Never-moved nodes" groups).

## ADR-023 — Canvas Presentation Widgets Promoted to `lib/views/`; Demonstration Host Downgraded to Regression-Only (WORK_PACKAGE_024)

**Context.** WORK_PACKAGE_024 integrated the Engineering Engine into
`oep_studio` as "Diagram Studio," the production diagram-editing
workspace. The plan going in assumed no Engine code changes would be
needed — Diagram Studio would consume only the existing public API.
While building Diagram Studio's canvas, it became clear that the
Demonstration Host's own `GraphViewPanel` (plus its ten supporting
painters/widgets: `WirePainter`, `GridPainter`, `GuidesPainter`,
`OriginIndicator`, `ConnectionPreviewPainter`, `SymbolNodeWidget`,
`ReconnectHandle`, `WireEditHandles`, `AnnotationWidget`,
`geometry_utils.dart`) and three of its dialogs (`array_placement_dialog.dart`,
`grid_settings_dialog.dart`, `named_layouts_dialog.dart`) had **zero**
Demonstration-Host-specific dependencies — every one imports only
`package:flutter/material.dart` (plus `flutter_svg`) and
`package:engineering_engine/engineering_engine.dart`. They existed only
in `example/lib/`, which is not part of the published package and
cannot be imported by `oep_studio`.

**Decision.** Rather than hand-duplicating ~1,000 lines of rendering and
dialog code into `oep_studio` (a second, drifting copy of how a
`DiagramScene`/`ViewState` gets painted), these files were promoted into
the Engine package itself, under new non-`core` directories
`lib/views/widgets/` and `lib/views/dialogs/`, exported from
`package:engineering_engine/engineering_engine.dart`, and removed from
`example/lib/`. The Demonstration Host now consumes them via the public
API exactly like Diagram Studio does. `lib/core/` itself is untouched —
it still contains no Flutter Widgets (SDD-025/026); the promoted widgets
sit in a Flutter-dependent, non-core presentation layer, which is
consistent with the ownership model's own "Rendering model" being listed
under Engine ownership. `flutter_svg` was added to this package's own
`pubspec.yaml` (previously only `example/pubspec.yaml` depended on it)
since `SymbolNodeWidget` needs it.

This is the one deviation from the original WP024 plan text ("no engine
code changes are anticipated") — an "unavoidable issue discovered
during implementation" in the sense WORK_PACKAGE_023's own frozen-
architecture instruction anticipated: additive, non-`core`, doesn't
touch any of the five permanently-separate runtime systems, and avoids
a much worse outcome (two independently-maintained diagram renderers).

Separately, the Demonstration Host's own doc comments (`main.dart`) and
`docs/DIAGRAM_STUDIO.md` were updated to state its narrowed purpose
explicitly: regression testing, architectural validation, and Engine
development support, never the production user experience now that one
genuinely exists. No functional changes were made to the Demonstration
Host beyond the import updates the promotion required — its own test
suite (`example/integration_test/app_test.dart`) still passes unmodified.

**Status.** Accepted. See `lib/views/widgets/widgets.dart`,
`lib/views/dialogs/dialogs.dart`, `docs/DIAGRAM_STUDIO.md`,
`oep_studio/docs/REPOSITORY_INTEGRATION.md`. Regression-tested: the full
existing `flutter test` suite (191 tests) and `example`'s own
`flutter analyze`/tests pass unchanged after the move.

## ADR-024 — `EngineHost` Ownership Hoisted Out of `DiagramStudioPage` Into a Shared, App-Lifetime Service (WORK_PACKAGE_025)

**Context.** WORK_PACKAGE_025 unifies Knowledge Studio and Diagram
Studio into synchronized views of one Engineering Project. A global
Validation page, a unified Search page, and a new Project Explorer
workspace all need to read — and, for selection, sometimes write — the
same live `EngineeringEngine` instance, editing session, selection, and
validation report Diagram Studio already maintains. Through
WORK_PACKAGE_024, `DiagramStudioPage` created its own `EngineHost` in
`initState` and disposed it in `dispose`, making all of that state
unreachable from any route other than `/diagram`.

This is a Studio-side (`oep_studio`) architectural decision — no Engine
code changed. It is recorded here, rather than left undocumented in
`oep_studio`, because `oep_studio` has no architecture decision log of
its own (see `docs/ENGINEERING_PROJECT.md` in that repository) and this
platform's Constitution treats this file as the one place load-bearing
architectural reasoning gets recorded, regardless of which repository's
code embodies it.

**Decision.** `EngineHost`, `DiagramDocument`, and mirrors of the
Engine's own `EditingSession`/`GraphSelection`/`ViewState`/
`ValidationReport` streams moved from `DiagramStudioPage`'s private
`State` into a new, app-lifetime Riverpod `Notifier`
(`EngineeringProjectNotifier`/`engineeringProjectServiceProvider`),
sibling to the pre-existing `foundationRuntimeServiceProvider`.
`ensureEngineStarted()` is idempotent, so `DiagramStudioPage` can call
it every time it mounts without recreating anything; the Engine keeps
running when the user navigates to any other workspace.
`DiagramStudioPage` became a *reader* of this shared state rather than
an *owner* — its own previously-private fields became plain getters
reading through the provider, which meant its existing ~900 lines of
gesture/editing-action code needed no changes to their bodies, only to
how six values are obtained.

This changes nothing about the Engine's own public API or the
Provider Architecture rules that API already satisfies (Graph/Layout/
ViewState/Selection/Commands remain exactly as SDD-024 through SDD-030
define them) — it changes only *which Studio-side object holds the
reference* to an `EngineeringEngine` instance, a decision the Engine
itself has no opinion about.

**Status.** Accepted. See `oep_studio/lib/core/services/
engineering_project_service.dart`, `oep_studio/docs/
WORKSPACE_SYNCHRONIZATION.md`. Regression-tested: full `oep_studio`
`flutter analyze`/`flutter test` suite passes, including a new
composition test (`test/workflow/unified_workflow_test.dart`) exercising
selection/validation/evidence/AI/history across a full multi-workspace
navigation sequence.

## ADR-025 — `EngineeringProject` Is Studio-Side Reference Data, Never a New Engine or Foundation Concept (WORK_PACKAGE_025)

**Context.** WORK_PACKAGE_025 introduces the idea of an "Engineering
Project" coordinating Knowledge, Diagrams, Evidence, Validation, and AI
Sessions. Three repositories could plausibly own this concept:
Foundation (repository-of-record), the Engineering Engine (owns Graph/
Layout/Commands), or Studio (owns orchestration/UI/persistence).

**Decision.** `EngineeringProject` lives in `oep_studio` only, as
reference data: an id, a name, and three independently-nullable
pointers (`repositoryPath`, `knowledgeSessionId`, `diagramDocumentPath`)
into systems that already own that data. It is never a container that
duplicates Knowledge Session, Engineering Graph, or Evidence content.
Foundation is read-only and has no concept of a Knowledge Session, so a
Project referencing one would be meaningless to it. The Engineering
Engine owns Graph/Layout/ViewState/Commands/Search/Validation — none of
which are Foundation- or Knowledge-Session-aware — so putting
`EngineeringProject` there would force the Engine to learn about
Studio-only concepts it has no other reason to know about, weakening
the ownership boundary this Constitution otherwise keeps clean.

**Status.** Accepted. No Engine code changed as a result of this
decision — it is recorded here per the same reasoning as ADR-024. See
`oep_studio/lib/core/models/engineering_project.dart`,
`oep_studio/docs/ENGINEERING_PROJECT.md`.

## ADR-026 — `UnifiedSearchResult` Wraps, Rather Than Merges, Two Pre-Existing `SearchResult` Types (WORK_PACKAGE_025)

**Context.** `oep_studio` and `oep_engine` each already ship an
unrelated, same-named `SearchResult` type: Studio's own (decoding
Foundation's native FFI search structs, two kinds) and the Engine's own
`SearchProvider` result (SDD-026, five kinds — node/relationship/
symbol/annotation/layer). WORK_PACKAGE_025 requires one unified search
page covering both, and requires results to identify Object Type,
Owning Workspace, and Repository Location — none of which either
source type carries today.

**Decision.** Neither source `SearchResult` type was renamed, merged,
or extended. A new wrapper class, `UnifiedSearchResult`
(`oep_studio/lib/core/models/unified_search_result.dart`), carries
`.fromFoundation()`/`.fromEngine()` factories and a new,
unambiguous `UnifiedSearchResultCategory` enum computed once at
construction time, so every consumer of unified search results
switches on that one category rather than on either wrapped, same-named
`SearchResultKind` enum directly. This keeps both existing,
already-shipped search implementations (Foundation's native search,
the Engine's `SearchProvider`, implementing SDD-026) completely
untouched — WORK_PACKAGE_025 adds a presentation-layer merge, not a
protocol-level one.

**Status.** Accepted. Engine-side `SearchResult`/`SearchProvider`
(`oep_engine/lib/core/search/`) unchanged. See `oep_studio/docs/
UNIFIED_SEARCH.md`.

## ADR-027 — `EvidenceLink.sourceReference`/`locator` Get a Studio-Side Interpretation Convention, Not a Schema Change (WORK_PACKAGE_025)

**Context.** `EvidenceLink` (`lib/core/graph/models/evidence_link.dart`)
declares `sourceReference` and `locator` as deliberately opaque to the
Engine — "interpreted by whatever produced the evidence" and
"producer-defined shape," respectively (SDD-024 Architecture Rule 7:
evidence is never edited, only referenced). WORK_PACKAGE_025's Evidence
Integration needs a concrete way to navigate from an `EvidenceLink` on
a graph node to the actual Knowledge Session material it references.

**Decision.** Rather than adding Studio-specific fields to
`EvidenceLink` or teaching the Engine about `SourceMaterial`/
`EvidenceRegion` (both Studio-only concepts), WORK_PACKAGE_025
establishes a convention, enforced only by the Studio-side code that
reads it, never by the Engine: `sourceReference` holds a Knowledge
Session `SourceMaterial.id`; `locator['regionId']`, when present, holds
an `EvidenceRegion.id`. `EvidenceLink` itself is unchanged — this ADR
records an interpretation of two fields whose shape was already
declared producer-defined, not a new capability. Two pre-existing
Engine hooks with no callers anywhere in Studio before this work
package — `SelectionService.focusEvidence(String)` and
`NavigationService.syncEvidence(String)` — are reused as-is to mirror
the resolved evidence reference onto the diagram canvas.

**Status.** Accepted. No Engine code changed. See
`oep_studio/lib/shared/navigation/evidence_navigation.dart`,
`oep_studio/docs/WORKFLOW_ARCHITECTURE.md`.
