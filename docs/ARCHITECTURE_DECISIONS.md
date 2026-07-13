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
