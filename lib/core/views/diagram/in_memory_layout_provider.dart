import '../../interfaces/layout_provider.dart';
import 'diagram_layout_state.dart';

/// Phase-2 (WORK_PACKAGE_021) [LayoutProvider]: layouts live in memory,
/// keyed by graph id, defaulting to [DiagramLayoutState.empty] the first
/// time a graph is seen.
class InMemoryLayoutProvider implements LayoutProvider {
  final Map<String, DiagramLayoutState> _layouts = {};

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
}
