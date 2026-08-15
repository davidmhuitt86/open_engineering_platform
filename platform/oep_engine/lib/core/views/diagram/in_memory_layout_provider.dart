import '../../interfaces/layout_provider.dart';
import 'diagram_layout_state.dart';

/// [LayoutProvider]: the active layout per graph lives in memory, plus
/// any number of named saved layouts per graph (WORK_PACKAGE_021's
/// current-layout tracking, extended in WORK_PACKAGE_022 with
/// ENGINE-TASK-000089's named-layout persistence). Defaults to
/// [DiagramLayoutState.empty] the first time a graph is seen.
class InMemoryLayoutProvider implements LayoutProvider {
  final Map<String, DiagramLayoutState> _layouts = {};
  final Map<String, Map<String, DiagramLayoutState>> _namedLayouts = {};

  @override
  DiagramLayoutState currentLayout(String graphId) {
    return _layouts[graphId] ?? DiagramLayoutState.empty;
  }

  @override
  Future<DiagramLayoutState> updateLayout(
    String graphId,
    DiagramLayoutState layout,
  ) async {
    _layouts[graphId] = layout;
    return layout;
  }

  @override
  Future<void> saveNamedLayout(
    String graphId,
    String layoutName,
    DiagramLayoutState layout,
  ) async {
    final graphLayouts = _namedLayouts.putIfAbsent(graphId, () => {});
    graphLayouts[layoutName] = layout;
  }

  @override
  DiagramLayoutState? loadNamedLayout(String graphId, String layoutName) {
    return _namedLayouts[graphId]?[layoutName];
  }

  @override
  List<String> listNamedLayouts(String graphId) {
    return _namedLayouts[graphId]?.keys.toList(growable: false) ?? const [];
  }

  @override
  Future<void> deleteNamedLayout(String graphId, String layoutName) async {
    _namedLayouts[graphId]?.remove(layoutName);
  }

  @override
  Future<DiagramLayoutState> resetLayout(String graphId) async {
    _layouts[graphId] = DiagramLayoutState.empty;
    return DiagramLayoutState.empty;
  }
}
