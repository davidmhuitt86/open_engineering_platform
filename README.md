# Engineering Engine

The Engineering Engine runtime for the Open Engineering Platform (OEP):
the Engineering Graph, Symbol Library, Views, validation, navigation,
selection, import/export, and a simulation framework placeholder.

Status: **Phase 1 (WORK_PACKAGE_019) implemented.** Phase 2 (EKE
architectural analysis + feature migration) not started — gated pending
formal review of this delivery.

Governed by SDD-024 through SDD-029 (frozen). Implementation reasoning
that isn't in the SDDs themselves is recorded in
`docs/ARCHITECTURE_DECISIONS.md`.

---

## Quick start

```dart
import 'package:engineering_engine/engineering_engine.dart';

final engine = EngineeringEngine.create();
await engine.initialize();

final graph = await engine.graph.create(id: 'demo');
final report = engine.validate(graph);

await engine.shutdown();
```

See `docs/ENGINEERING_ENGINE.md` for the full public API.

## Documentation

| Doc | Covers |
|---|---|
| `docs/ENGINEERING_ENGINE.md` | Runtime architecture, entry point, package layout |
| `docs/ENGINEERING_GRAPH.md` | Graph object model, building, querying, validation |
| `docs/SYMBOL_LIBRARY.md` | Symbol Definition schema, the 14 seed symbols, loading |
| `docs/DIAGRAM_STUDIO.md` | The View layer, Diagram View, and the Demonstration Host (**not** Diagram Studio) |
| `docs/ARCHITECTURE_DECISIONS.md` | Why — the ADR log for implementation decisions |
| `docs/specifications/SDD-0{24..29}-*.md` | The frozen architecture itself |
| `docs/tasks/WORK_PACKAGE_019.md` | The governing work package |

## Reference implementation

`platform/engine_reference_only/` is the mature HTML/JS Electrical
Knowledge Engine — the official *behavioral* reference for workflows,
interaction model, and algorithm concepts. No HTML/CSS/JavaScript/DOM/SVG
implementation from it has been migrated; only architectural ideas are
preserved, reimplemented from scratch in Dart. See `docs/DIAGRAM_STUDIO.md`
and `docs/ENGINEERING_GRAPH.md` for what was and wasn't carried over.

## Verification

```
flutter analyze
flutter test

cd example
flutter analyze
flutter test integration_test/app_test.dart -d windows
flutter build windows
```

## Repository boundaries

This package owns Engineering Engine runtime behavior only. It never owns
Repository persistence (`oep_foundation`) or Studio user interface
(`oep_studio`) — see SDD-025/026. `example/` is a verification harness for
this package, not a preview of Diagram Studio.
