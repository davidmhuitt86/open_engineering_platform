import '../graph/models/engineering_graph.dart';
import '../search/search_result.dart';
import '../views/diagram/diagram_layout_state.dart';

/// Engineering Graph + Diagram Layout search (SDD-026 "Search Engine" /
/// `SearchService` — named in the frozen spec, implemented for the first
/// time in WORK_PACKAGE_023, ENGINE-TASK-000104).
///
/// "Search indexes Engineering Graph and Diagram Layout independently" —
/// [search] takes both explicitly rather than assuming one implies the
/// other, and a result's [SearchResult.kind] records which side it came
/// from.
abstract class SearchProvider {
  List<SearchResult> search(EngineeringGraph graph, DiagramLayoutState layout, String query);
}
