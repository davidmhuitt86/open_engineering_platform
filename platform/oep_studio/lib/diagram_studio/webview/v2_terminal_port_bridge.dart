import 'package:engineering_engine/engineering_engine.dart';

/// PRODUCT-READINESS-006 §7/§37 — the production fix for the real gap
/// PRODUCT-READINESS-005 discovered and explicitly declined to work around
/// with a test-only reconstruction: every real V2-bridged
/// [EngineeringNode] persists `"ports": []` — its actual terminal data
/// lives ONLY in `metadata['v2Terminals']` (a list of `{n, c}` name/color
/// pairs, PRODUCT-READINESS-002's own established V2 authoring
/// convention), a format PRODUCT-READINESS-004/005's terminal-centric
/// model (`Port`, `ProbePoint`) never reads.
///
/// This is the ONE canonical place that gap is closed for already-saved
/// documents (§37: "prove: actual diagram -> actual EngineeringNode/Port
/// model... without a test-only reconstruction layer") — called from both
/// [DiagramDocument.open] and [DiagramDocument.recoverFrom], the two
/// choke points every loaded document passes through, so every diagram
/// this app opens (old or new) gets real, addressable [Port]s without
/// requiring every existing saved file to be re-saved first.
///
/// **Port id convention**: 1-based index into `v2Terminals`, as a string
/// (`"1"`, `"2"`, ...) — the SAME convention `metadata['sourcePort']`/
/// `['targetPort']` already use on this exact file's own relationships
/// (confirmed: PRODUCT-READINESS-002's bridge code establishes bare
/// pin-index strings as the terminal reference convention; PRODUCT-
/// READINESS-005's own TRX300 test adapter used this identical mapping —
/// this function makes that mapping the real, single, canonical
/// production identity rather than a parallel test-only one).
///
/// **Idempotent and non-destructive**: a node that already has real
/// [Port]s (created after a future write-side fix populates them
/// directly) is left completely untouched — this function only fills a
/// gap, it never overwrites already-correct data. A node with no
/// `v2Terminals` metadata at all (a non-V2-bridged node, or one
/// genuinely authored with zero terminals) is also left untouched — never
/// fabricating a terminal that was never authored.
EngineeringGraph backfillV2TerminalPorts(EngineeringGraph graph) {
  final updatedNodes = <String, EngineeringNode>{};
  var changedAny = false;
  for (final entry in graph.nodes.entries) {
    final node = entry.value;
    if (node.ports.isNotEmpty) {
      updatedNodes[entry.key] = node;
      continue;
    }
    final v2Terminals = node.metadata['v2Terminals'];
    if (v2Terminals is! List || v2Terminals.isEmpty) {
      updatedNodes[entry.key] = node;
      continue;
    }
    final ports = <Port>[
      for (var i = 0; i < v2Terminals.length; i++)
        Port(
          id: '${i + 1}',
          name: _terminalName(v2Terminals[i], fallback: '${i + 1}'),
        ),
    ];
    updatedNodes[entry.key] = node.copyWith(ports: ports);
    changedAny = true;
  }
  if (!changedAny) return graph;
  return graph.copyWith(nodes: updatedNodes);
}

String _terminalName(Object? rawTerminal, {required String fallback}) {
  if (rawTerminal is Map) {
    final name = rawTerminal['n'];
    if (name is String && name.isNotEmpty) return name;
  }
  return fallback;
}
