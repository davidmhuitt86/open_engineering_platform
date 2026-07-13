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
