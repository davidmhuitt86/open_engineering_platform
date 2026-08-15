import 'dart:async';

import '../graph/algorithms/graph_traversal.dart';
import '../graph/models/engineering_graph.dart';
import '../interfaces/navigation_provider.dart';
import '../search/search_result.dart';
import 'navigation_event.dart';

/// Navigation/highlight/evidence-sync coordination (SDD-026
/// `NavigationEngine`).
///
/// Computes highlight sets from graph traversal but never mutates the
/// graph and never touches rendering — that split (traversal vs. paint) is
/// the one architectural behavior deliberately carried over from the
/// reference implementation's `path-highlighter.js` (traversal-only) vs.
/// its renderer (paint-only).
///
/// WORK_PACKAGE_023, ENGINE-TASK-000104 adds search-result navigation:
/// [searchResults]/[currentResult] track *which* result of the last
/// search is current — purely an index into that list, runtime-only, not
/// persisted, not a command, the same category as the existing
/// highlight-path state above. "Zoom To Result"/"Select Result"/"Center
/// Result" are deliberately not implemented here — they're host-level
/// combinations of [currentResult] with the existing
/// `ViewStateService.fitSelection`/`SelectionService.selectNode`, so
/// there is no duplicate zoom/select/center logic to maintain.
class NavigationService implements NavigationProvider {
  final StreamController<NavigationEvent> _controller =
      StreamController<NavigationEvent>.broadcast();

  List<SearchResult> _searchResults = const [];
  int _currentResultIndex = -1;

  @override
  Stream<NavigationEvent> get events => _controller.stream;

  List<SearchResult> get searchResults => _searchResults;

  SearchResult? get currentResult =>
      _currentResultIndex >= 0 && _currentResultIndex < _searchResults.length
          ? _searchResults[_currentResultIndex]
          : null;

  /// Replaces the tracked result set (a fresh search) and resets to the
  /// first result, if any.
  void setSearchResults(List<SearchResult> results) {
    _searchResults = results;
    _currentResultIndex = results.isEmpty ? -1 : 0;
  }

  void nextResult() {
    if (_searchResults.isEmpty) return;
    _currentResultIndex = (_currentResultIndex + 1) % _searchResults.length;
  }

  void previousResult() {
    if (_searchResults.isEmpty) return;
    _currentResultIndex =
        (_currentResultIndex - 1 + _searchResults.length) % _searchResults.length;
  }

  @override
  void focusNode(String nodeId) {
    _controller.add(NavigationEvent(
      kind: NavigationEventKind.focusNode,
      focusedNodeId: nodeId,
    ));
  }

  @override
  void highlightPath(List<String> nodeIds, List<String> relationshipIds) {
    _controller.add(NavigationEvent(
      kind: NavigationEventKind.highlightPath,
      highlightedNodeIds: nodeIds,
      highlightedRelationshipIds: relationshipIds,
    ));
  }

  /// Convenience: finds the shortest path between two nodes in [graph] and
  /// highlights it. Returns `true` if a path was found.
  bool highlightPathBetween(
    EngineeringGraph graph,
    String sourceNodeId,
    String targetNodeId,
  ) {
    final path = GraphTraversal.findPath(graph, sourceNodeId, targetNodeId);
    if (path == null) return false;
    final relationshipIds = <String>[];
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      final match = graph.relationships.values.firstWhere(
        (r) =>
            (r.sourceNode == a && r.targetNode == b) ||
            (r.sourceNode == b && r.targetNode == a),
      );
      relationshipIds.add(match.id);
    }
    highlightPath(path, relationshipIds);
    return true;
  }

  @override
  void clearHighlight() {
    _controller.add(const NavigationEvent(kind: NavigationEventKind.clearHighlight));
  }

  @override
  void syncEvidence(String evidenceId) {
    _controller.add(NavigationEvent(
      kind: NavigationEventKind.evidenceSync,
      evidenceId: evidenceId,
    ));
  }

  Future<void> dispose() => _controller.close();
}
