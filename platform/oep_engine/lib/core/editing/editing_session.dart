import '../graph/models/engineering_graph.dart';
import '../views/diagram/diagram_layout_state.dart';

/// The unit of state every [EditingCommand] operates on.
///
/// Bundles the Engineering Graph with its sibling [DiagramLayoutState] so
/// a single command history covers both graph edits (create/delete/
/// property changes) and layout edits (move) without blurring the two —
/// `graph` never carries position (SDD-024 Rule 5); see
/// docs/ARCHITECTURE_DECISIONS.md ADR-011.
class EditingSession {
  final EngineeringGraph graph;
  final DiagramLayoutState layout;

  const EditingSession({required this.graph, required this.layout});

  factory EditingSession.initial(EngineeringGraph graph) =>
      EditingSession(graph: graph, layout: DiagramLayoutState.empty);

  EditingSession copyWith({EngineeringGraph? graph, DiagramLayoutState? layout}) {
    return EditingSession(
      graph: graph ?? this.graph,
      layout: layout ?? this.layout,
    );
  }
}
