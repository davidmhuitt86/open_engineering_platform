# Engineering Engine

Status: Phase 1 (WORK_PACKAGE_019) implemented. Phase 2 not started.

Governed by SDD-024, SDD-025, SDD-026, SDD-027, SDD-028, SDD-029 (frozen).
See `docs/ARCHITECTURE_DECISIONS.md` for implementation-level reasoning
not covered by the SDDs.

---

## What this package is

`engineering_engine` (`platform/oep_engine`) is the Engineering Engine
runtime for the Open Engineering Platform: the Engineering Graph, Symbol
Library, Views (rendering), validation, navigation, selection, import/
export, and a simulation framework placeholder. It is a Flutter package,
but its `lib/core/` implementation is 100% plain Dart — no Flutter
Widgets, no `BuildContext`, no Widget dependencies (SDD-025/026).

It owns engineering *behavior*. It does not own:

- Repository persistence (Foundation's job)
- Studio user interface / navigation (Studio's job)
- Marketplace distribution

## Entry point

```dart
import 'package:engineering_engine/engineering_engine.dart';

final engine = EngineeringEngine.create(); // wires Phase 1 default providers
await engine.initialize();                 // loads the Symbol Library

final graph = await engine.graph.create(id: 'my-graph');
final report = engine.validate(graph);
final scene = engine.diagramView.render(graph);

await engine.shutdown();
```

`EngineeringEngine.create()` is the Phase 1 convenience factory. It wires:

| Interface | Phase 1 implementation |
|---|---|
| `GraphProvider` | `InMemoryGraphProvider` |
| `SerializationProvider` | `JsonFileSerializationProvider` |
| `SymbolProvider` | `SymbolLibrary` |
| `ValidationProvider` | `ValidationService` |
| `NavigationProvider` | `NavigationService` |
| `SelectionProvider` | `SelectionService` |
| `ImportProvider` | `JsonImportProvider` |
| `ExportProvider` | `JsonExportProvider` |
| `SimulationProvider` | `NoOpSimulationProvider` |

You can also construct `EngineeringEngine(EngineRegistry registry)`
directly with your own registry (e.g. fakes/mocks for testing, or a future
Foundation-backed `GraphProvider`).

## Runtime architecture

```
EngineeringEngine
    -> EngineRegistry
        -> GraphProvider        (Graph Engine)
        -> SymbolProvider       (Symbol Engine)
        -> ValidationProvider   (Validation Engine)
        -> NavigationProvider   (Navigation Engine)
        -> SelectionProvider    (Selection Engine)
        -> ImportProvider       (Import Engine)
        -> ExportProvider       (Export Engine)
        -> SimulationProvider   (Simulation Engine — no-op in Phase 1)
    -> Views (DiagramView, ...)
```

`EngineeringEngine` never resolves a provider directly — everything goes
through `EngineRegistry`, keyed by interface type. This is the sole
extension point: a future Marketplace package, an alternate backend, or a
test double registers the same way (SDD-029) without `EngineeringEngine`'s
core changing (ADR-001).

## Package layout

- `lib/core/` — implementation. Plain Dart only.
  - `interfaces/` — the eight provider contracts.
  - `graph/` — Engineering Graph model, `GraphService`, `GraphBuilder`,
    traversal/query algorithms, serialization.
  - `symbols/` — Symbol Library model + loader.
  - `validation/` — `ValidationService` and report/finding types.
  - `navigation/`, `selection/` — runtime coordination services.
  - `importers/`, `exporters/` — JSON round-trip (Phase 1 scope).
  - `simulation/` — `NoOpSimulationProvider` placeholder.
  - `bridge/` — `FoundationBridgePort` (interface only — see ADR-004).
  - `views/` — the View layer; `views/diagram/` is Diagram View.
  - `events/` — internal `EngineEventBus` (not part of the public API).
- `lib/*.dart` (top-level folders) — public barrel exports. See ADR-005
  for why both exist.
- `lib/engineering_engine.dart` — the single import consumers need.
- `assets/symbols/` — the 14 seed Symbol Definitions (JSON + SVG).
- `example/` — the Engineering Engine Demonstration Host (see
  `docs/DIAGRAM_STUDIO.md` and ADR-006). **Not** Diagram Studio.

## What's deliberately not here yet

- Real Foundation Bridge integration (ADR-004) — documented dependency,
  not a Phase 1 blocker.
- PDF/image/SVG import (OCR-dependent — Phase 2/EKE migration scope).
- Any simulation engine (explicitly out of scope — "no simulation yet").
- The full EKE architectural analysis and feature migration
  (STUDIO-TASK-000064/000065) — gated by WORK_PACKAGE_019 itself pending
  formal review of this Phase 1 delivery.

## Verification

```
flutter analyze          # from platform/oep_engine
flutter test              # unit tests
cd example
flutter test integration_test/app_test.dart -d windows
flutter build windows
```
