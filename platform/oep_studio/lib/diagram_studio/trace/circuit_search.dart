import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-010 §4/§5/§6 — one search result, retaining its real
/// engineering identity (§6: "Do not flatten everything into a string
/// result"). Wraps EITHER a real [SearchResult] (node/relationship/
/// symbol/annotation/layer, from the existing, Engine-owned
/// [SearchService]) OR a real [TerminalSearchMatch] (§8) — never a copy,
/// never a third, independent identity model.
class CircuitSearchEntry {
  const CircuitSearchEntry.fromSearchResult(this.searchResult) : terminalMatch = null;
  const CircuitSearchEntry.terminal(this.terminalMatch) : searchResult = null;

  final SearchResult? searchResult;
  final TerminalSearchMatch? terminalMatch;

  bool get isTerminal => terminalMatch != null;
  bool get isNode => searchResult?.kind == SearchResultKind.node;
  bool get isRelationship => searchResult?.kind == SearchResultKind.relationship;

  /// The real engineering id this entry points at — a node id, a
  /// relationship id, or (for a terminal) its own component's node id
  /// (§7/§8: selecting a terminal result still navigates to the real
  /// component; the DMM-probe path additionally uses the exact terminal).
  String get targetId => terminalMatch?.terminal.nodeId ?? searchResult!.id;

  String get label {
    final terminal = terminalMatch;
    if (terminal != null) return '${terminal.componentName} · ${terminal.terminalName}';
    return searchResult!.label;
  }
}

/// PRODUCT-READINESS-010 §4/§5/§26/§27 — the one, diagram-scoped search
/// entry point Circuit Intelligence uses: reuses the existing, Engine-
/// owned [SearchService] (node/relationship/symbol/annotation/layer) and
/// [searchTerminals] (§8) directly against the CURRENTLY OPEN diagram's
/// own [EngineeringGraph]/[DiagramLayoutState] -- never a duplicated
/// index, never a new search engine, never cross-diagram (§25 — the
/// caller supplies only the active diagram's own graph/layout).
///
/// Ordering: terminal matches first (rank-sorted, §27 already applied by
/// [searchTerminals]), then node/relationship/symbol/annotation/layer
/// matches in [SearchService]'s own emitted order -- a component
/// (`SearchResultKind.node`) and its own terminal are therefore adjacent
/// in the result list whenever both match, matching §5's own mockup
/// ("COMPONENT: Headlight" directly above "TERMINALS: LO, HI").
List<CircuitSearchEntry> searchCircuitEntities({
  required EngineeringGraph graph,
  required DiagramLayoutState layout,
  required SymbolProvider symbols,
  required String query,
}) {
  final needle = query.trim();
  if (needle.isEmpty) return const [];

  final entries = <CircuitSearchEntry>[];
  for (final match in searchTerminals(graph, needle)) {
    entries.add(CircuitSearchEntry.terminal(match));
  }
  // §4's own scope for Circuit Intelligence is component/terminal/
  // relationship/splice/connector -- all real graph NODES/RELATIONSHIPS
  // (splices/connectors are just nodes with those categories). Symbol
  // library entries and layout annotations/layers ARE real
  // `SearchService` result kinds, but out of scope here (not engineering
  // objects a circuit trace can target) -- filtered out rather than
  // mislabeled.
  for (final result in SearchService(symbols: symbols).search(graph, layout, needle)) {
    if (result.kind == SearchResultKind.node || result.kind == SearchResultKind.relationship) {
      entries.add(CircuitSearchEntry.fromSearchResult(result));
    }
  }
  return entries;
}
