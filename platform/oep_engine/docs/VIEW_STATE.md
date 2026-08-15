# ViewState

WORK_PACKAGE_022: "Maintain the architectural separation between:
Engineering Graph, Diagram Layout, ViewState, Selection, Undo/Redo... Do
not merge responsibilities between these systems... ViewState and
Selection shall never pass through the Command system." See also
ARCHITECTURE_DECISIONS.md ADR-014.

---

## The four-way (now five-way) separation

```
Engineering Graph  — knowledge (SDD-024/025/027, unchanged this WP)
Diagram Layout     — node positions (WORK_PACKAGE_021, DiagramLayoutState/LayoutProvider)
ViewState          — zoom/pan/viewport/grid/guides/theme/render options/hover (NEW, this WP)
Selection          — GraphSelection/FocusState (WORK_PACKAGE_021, unchanged)
Undo/Redo          — CommandHistory over EditingSession{graph, layout} only
```

`ViewState` is a **fifth**, permanently separate runtime concern. It never
mutates `EngineeringGraph` or `DiagramLayoutState`, and it never flows
through `EditingCommand`/`CommandHistory` — architecturally it is built to
be indistinguishable in shape from `SelectionService` (see
`docs/SELECTION_MODEL.md`), which already established the precedent that
runtime view concerns stay outside the command system.

## `ViewState`

```dart
class ViewState {
  final double zoom;
  final Point2D pan;
  final double viewportWidth;
  final double viewportHeight;
  final Set<String> visibleLayers;
  final GridSettings grid;
  final bool guidesVisible;
  final ViewTheme theme;
  final Map<String, Object?> renderOptions;
  final PortReference? hoveredPort;
}
```

A single immutable value (`copyWith`, `toJson`/`fromJson`, `static const
initial`) — serializable independently of the graph and layout, per spec,
so a future Studio workspace can persist/restore "how you were looking at
it" separately from "what it is" and "where things are."

## `ViewStateProvider` / `ViewStateService`

```dart
abstract class ViewStateProvider {
  ViewState get current;
  Stream<ViewState> get changes;
  void setZoom(double zoom);
  void setPan(Point2D pan);
  void setViewportSize(double width, double height);
  void setVisibleLayers(Set<String> layers);
  void setGridSettings(GridSettings grid);
  void toggleGrid();
  void toggleSnap();
  void setGuidesVisible(bool visible);
  void setTheme(ViewTheme theme);
  void setRenderOption(String key, Object? value);
  void hoverPort(PortReference? port);
}
```

Registered in `EngineRegistry` exactly like every other capability
(ADR-001) — `registry.viewState`. `ViewStateService implements
ViewStateProvider`, mirroring `SelectionService`'s own shape: a live
value, a change stream, explicit setters, zero interaction with
`CommandHistory`/`EditingService`. `EngineeringEngine.create()` registers
a `ViewStateService` by default; `shutdown()` disposes it.

## Viewport navigation (on `ViewStateService`, not the interface)

`ViewStateService` additionally exposes concrete convenience methods not
part of the abstract `ViewStateProvider` contract: `fitAll`,
`fitSelection`, `centerSelection`, `zoomToCursor`, `goBack`, `goForward`,
`canGoBack`, `canGoForward`. These delegate to the pure functions in
`lib/core/viewstate/viewport_math.dart` (see
`docs/GRID_SYSTEM.md`/`docs/ROUTING_ARCHITECTURE.md` siblings for the
other pure-computation modules this work package added) and to
`NavigationHistory`, a bounded (default depth 50) back/forward stack of
`ViewportTarget{zoom, pan}` snapshots. `fitAll`/`fitSelection`/
`centerSelection` record history before applying; `zoomToCursor`/`goBack`/
`goForward` do not (recording every incremental zoom-to-cursor step, or
recording the act of navigating history itself, would make the back/
forward stack useless).

Smooth animation between the current and target viewport is explicitly
**not** engine code — `ViewportMath` returns a target instantly; the
Demonstration Host owns any `AnimationController` tweening toward it, per
SDD-026 ("No Flutter Widgets... no BuildContext" in `lib/core/`).

## Serialization

`JsonFileViewStateSerializer.write/read` mirrors
`JsonFileSerializationProvider` (graph) and `JsonFileLayoutSerializer`
(layout) exactly — see `docs/LAYOUT_SYSTEM.md` for why these are three
separate, non-shared-interface classes rather than one generic
serializer.

## Verification

`test/viewstate/view_state_service_test.dart` covers: initial state,
every setter's state change + stream emission, `hoverPort` set/clear,
`setRenderOption` merging without clobbering other keys, `fitAll`/
`fitSelection`/`centerSelection` computing a zoom/pan that fits the
target bounds, `zoomToCursor` keeping the scene point under the cursor
fixed, navigation history back/forward round-tripping a prior viewport,
and `JsonFileViewStateSerializer` round-tripping a `ViewState`.
