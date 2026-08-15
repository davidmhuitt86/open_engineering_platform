# Studio Engine Host

`lib/diagram_studio/host/engine_host.dart` (WORK_PACKAGE_024,
ENGINE-TASK-000109).

## Purpose

`EngineHost` is the *only* place Diagram Studio creates or tears down
an `EngineeringEngine`. It exists so `DiagramStudioPage` doesn't
inline Engine bootstrapping — not to wrap, reinterpret, or add
behavior to the Engine.

```dart
class EngineHost {
  final EngineeringEngine engine;

  static Future<EngineHost> create() async { ... }
  EditingSession beginSession(EngineeringGraph graph) => engine.beginEditingSession(graph);
  Future<void> dispose() => engine.shutdown();
}
```

`create()` does exactly two things:

1. `EngineeringEngine.create()` + `await engine.initialize()` — the
   same call the Demonstration Host makes, with default providers
   (in-memory graph/layout/clipboard, `JsonFileSerializationProvider`,
   `SymbolLibrary`, `ValidationService`, `NavigationService`,
   `SelectionService`, JSON import/export, `NoOpSimulationProvider`,
   `OrthogonalRoutingProvider`, `ViewStateService`, `SearchService`).
2. Loads the 14 seed symbols through Flutter's asset bundle
   (`rootBundle.loadString('packages/engineering_engine/assets/
   symbols/$id.json')`) — `SymbolLibrary` itself stays Flutter-
   independent (SDD-025/026) and normally scans a directory with
   `dart:io`, which doesn't work for a bundled Flutter app. This is the
   one place a Studio-specific loading mechanism is needed; it's
   identical to what the Demonstration Host's own
   `symbol_bundle_loader.dart` does.

## Why a session always starts blank

Unlike the Demonstration Host (which seeds a fixed demo graph for
verification), `DiagramStudioPage` begins every Engine instance with
`EngineeringEngine.beginEditingSession(EngineeringGraph.empty(...))` —
an empty graph — because Diagram Studio's actual starting content comes
from `DiagramDocument.open()` (an existing file) or stays empty for a
brand-new, unsaved diagram. Workspace persistence (`docs/
WORKSPACE_INTEGRATION.md`) restores the last-open document's content on
launch when one exists; `EngineHost` itself has no opinion about that.

## Lifecycle

`DiagramStudioPage` creates exactly one `EngineHost` in `initState`
(via an async `_bootstrap()`) and disposes it in `dispose()`. Engine
identity is 1:1 with the workspace page's own widget lifetime — closing
the Diagram Studio route and reopening it creates a fresh Engine, the
same way navigating away from and back to Knowledge Studio doesn't
preserve in-memory Knowledge Studio state either (workspace
*persistence* is what survives that, not the running Engine instance).

## What `EngineHost` deliberately does not do

* No editing logic — every editing/selection/routing/search call goes
  straight through `EngineHost.engine.*`, never through a wrapper method
  added here.
* No Studio-side state — no document path, no dirty flag, no ViewState
  cache. Those live in `DiagramDocument` and `DiagramStudioPage` itself.
* No Foundation awareness — `EngineHost` never touches
  `FoundationRuntimeNotifier`; the two are wired together only inside
  `DiagramStudioPage` (Property Inspector bridging) and `DiagramDocument`
  (ambient repository metadata display, read-only).
