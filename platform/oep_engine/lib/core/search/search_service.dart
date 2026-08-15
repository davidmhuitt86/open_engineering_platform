import '../graph/models/engineering_graph.dart';
import '../interfaces/search_provider.dart';
import '../interfaces/symbol_provider.dart';
import '../views/diagram/diagram_layout_state.dart';
import 'search_result.dart';

/// The SDD-026 "Search Engine" / `SearchService`, implemented for the
/// first time in WORK_PACKAGE_023 (ENGINE-TASK-000104) — case-insensitive
/// substring matching across the Engineering Graph and Diagram Layout,
/// indexed independently per spec.
class SearchService implements SearchProvider {
  final SymbolProvider symbols;

  SearchService({required this.symbols});

  @override
  List<SearchResult> search(EngineeringGraph graph, DiagramLayoutState layout, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    final results = <SearchResult>[];

    for (final node in graph.nodes.values) {
      if (node.displayName.toLowerCase().contains(needle)) {
        results.add(SearchResult(
          id: node.id,
          kind: SearchResultKind.node,
          label: node.displayName,
          matchedField: 'displayName',
        ));
      } else if (node.category.name.toLowerCase().contains(needle)) {
        results.add(SearchResult(
          id: node.id,
          kind: SearchResultKind.node,
          label: node.displayName,
          matchedField: 'category',
        ));
      } else if (node.symbolId != null && node.symbolId!.toLowerCase().contains(needle)) {
        results.add(SearchResult(
          id: node.id,
          kind: SearchResultKind.node,
          label: node.displayName,
          matchedField: 'symbolId',
        ));
      }
    }

    for (final relationship in graph.relationships.values) {
      if (relationship.relationshipType.name.toLowerCase().contains(needle) ||
          relationship.id.toLowerCase().contains(needle)) {
        results.add(SearchResult(
          id: relationship.id,
          kind: SearchResultKind.relationship,
          label: relationship.relationshipType.name,
          matchedField:
              relationship.id.toLowerCase().contains(needle) ? 'id' : 'relationshipType',
        ));
      }
    }

    for (final symbol in symbols.search(needle)) {
      results.add(SearchResult(
        id: symbol.identifier,
        kind: SearchResultKind.symbol,
        label: symbol.name,
        matchedField: 'name',
      ));
    }

    for (final annotation in layout.annotations.values) {
      if (annotation.text.toLowerCase().contains(needle)) {
        results.add(SearchResult(
          id: annotation.id,
          kind: SearchResultKind.annotation,
          label: annotation.text,
          matchedField: 'text',
        ));
      }
    }

    for (final layer in layout.layers.values) {
      if (layer.name.toLowerCase().contains(needle)) {
        results.add(SearchResult(
          id: layer.id,
          kind: SearchResultKind.layer,
          label: layer.name,
          matchedField: 'name',
        ));
      }
    }

    return results;
  }
}
