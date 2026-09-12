import '../graph/models/engineering_graph.dart';
import '../simulation/measurement/measurement_types.dart';

/// PRODUCT-READINESS-010 §8 — one terminal-level search match. [terminal]
/// is the SAME [ProbePoint] identity used everywhere else in this codebase
/// (measurement, trace, DMM probes) — never a new terminal address type.
///
/// A small, deliberately separate addition alongside [SearchService]
/// (rather than a new [SearchResultKind] variant on the shared
/// `SearchResult`/`SearchResultKind` pair): those types are consumed by
/// several exhaustive `switch` statements across both `oep_engine`'s own
/// example app and `oep_studio`'s cross-scope `UnifiedSearchResult`
/// mapping, so widening that enum would ripple well beyond this
/// diagram-scoped feature. Terminal search lives here as its own small,
/// focused result type instead — still Engine-owned (§45), still reusing
/// the graph's own real node/port data, never a duplicate terminal
/// identity model.
class TerminalSearchMatch {
  const TerminalSearchMatch({
    required this.terminal,
    required this.componentName,
    required this.terminalName,
    required this.matchedField,
    required this.rank,
  });

  final ProbePoint terminal;
  final String componentName;
  final String terminalName;

  /// `'terminalName'`, `'componentName'`, or `'combined'` — which text
  /// actually matched the query, mirroring [SearchResult.matchedField]'s
  /// own "show *why* a result matched" convention.
  final String matchedField;

  /// Lower is a better match — see [searchTerminals]'s own doc comment
  /// for the exact, deterministic ranking (§27: no ML ranking, a
  /// predictable order).
  final int rank;
}

/// PRODUCT-READINESS-010 §8/§27 — resolves a query like `"Headlight LO"`
/// to the real `(component, terminal)` pair it names, over the real
/// [EngineeringGraph]'s own `EngineeringNode.ports` — never a duplicated
/// port index. Deterministic ranking (§27's own priority list, narrowed
/// to what is meaningful for a terminal):
///
/// 0. exact "`componentName` `terminalName`" match (case-insensitive)
/// 1. exact terminal name match on its own (e.g. querying just `"LO"`)
/// 2. the combined "`componentName` `terminalName`" string starts with
///    the query
/// 3. the combined string merely contains the query
///
/// Results are sorted by [TerminalSearchMatch.rank], then by component
/// display name, then by terminal name — never by insertion/iteration
/// order, so repeated searches over the same graph are deterministic.
List<TerminalSearchMatch> searchTerminals(EngineeringGraph graph, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final matches = <TerminalSearchMatch>[];
  for (final node in graph.nodes.values) {
    for (final port in node.ports) {
      final componentName = node.displayName;
      final terminalName = port.name;
      final combined = '$componentName $terminalName'.toLowerCase();
      final terminalOnly = terminalName.toLowerCase();

      int? rank;
      String matchedField;
      if (combined == needle) {
        rank = 0;
        matchedField = 'combined';
      } else if (terminalOnly == needle) {
        rank = 1;
        matchedField = 'terminalName';
      } else if (combined.startsWith(needle)) {
        rank = 2;
        matchedField = 'combined';
      } else if (combined.contains(needle)) {
        rank = 3;
        matchedField = 'combined';
      } else {
        continue;
      }

      matches.add(TerminalSearchMatch(
        terminal: ProbePoint(nodeId: node.id, portId: port.id),
        componentName: componentName,
        terminalName: terminalName,
        matchedField: matchedField,
        rank: rank,
      ));
    }
  }

  matches.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final byComponent = a.componentName.compareTo(b.componentName);
    if (byComponent != 0) return byComponent;
    return a.terminalName.compareTo(b.terminalName);
  });
  return matches;
}
