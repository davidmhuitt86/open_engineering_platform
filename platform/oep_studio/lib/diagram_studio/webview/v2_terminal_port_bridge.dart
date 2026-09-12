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

/// PRODUCT-READINESS-008 §16 — the production-path counterpart to
/// [backfillV2TerminalPorts]: real V2-authored relationship metadata
/// writes a connector pin reference as `"<pin>_IN"`/`"<pin>_OUT"`, and a
/// splice endpoint as the literal sentinel `"SPLICE"` (confirmed directly
/// on the real `samples/diagram7.json`, e.g. `node_hm2wkv7mtt_9hiy30`'s
/// own two wires) — neither matches [backfillV2TerminalPorts]'s own bare
/// 1-based pin-index `Port.id` convention. This was previously normalized
/// ONLY inside a test-only loader (`electrical_solver_trx300_test.dart`'s
/// own `normalizePort`, PRODUCT-READINESS-006/006B) — PRODUCT-READINESS-006B's
/// own report disclosed this as "test-side only, not yet in the
/// production bridge." This function closes that gap in the ONE real
/// production path every diagram load goes through
/// ([DiagramDocument.open]/[DiagramDocument.recoverFrom]), so a real
/// solve against a production-loaded graph resolves connector/splice
/// terminal identity correctly, not just a test's own hand-rolled loader.
///
/// **Second, real gap found and closed in the same pass (PRODUCT-READINESS-008,
/// found via the real `diagram7.json` acceptance test)**: some real nodes
/// (e.g. the real `ignition-switch`/`left-handlebar-switch`) already have
/// a non-empty `ports` field on disk whose `Port.id`s are the terminal
/// NAME itself (`'BAT1'`, `'BAT2'`, ...) — [backfillV2TerminalPorts]
/// leaves an already-non-empty `ports` list untouched (by design: never
/// overwrite already-real data), so these nodes never get the 1-based
/// numeric ids [backfillV2TerminalPorts] would otherwise assign. Their
/// own relationships' `sourcePort`/`targetPort`, however, still use the
/// numeric 1-based-index-into-`v2Terminals` convention every other real
/// wire in this file uses — a genuine mismatch: a bare `"4"` reference
/// does not equal the real `Port.id` `"BAT3"` (this node's 4th declared
/// terminal), even though they name the same physical pin. Resolved by
/// [_resolvePortId]: when a raw reference does not already match one of
/// the node's own real `Port.id`s, and it parses as a 1-based index, that
/// index is looked up in the node's own `v2Terminals` metadata for the
/// terminal's real NAME, which is then matched (case-insensitively)
/// against the node's own real `Port.name`s to recover the real `Port.id`
/// — never fabricated, always resolved from this exact node's own real,
/// already-authored data.
///
/// Idempotent and non-destructive: a reference that is already correct
/// passes through unchanged; a relationship with no `sourcePort`/
/// `targetPort` metadata at all, or whose endpoint node cannot be found,
/// is left untouched.
EngineeringGraph normalizeV2RelationshipPortReferences(EngineeringGraph graph) {
  String? resolvePortId(EngineeringNode? node, String? rawPort) {
    if (rawPort == null) return null;
    var ref = rawPort == 'SPLICE' ? '1' : rawPort.replaceFirst(RegExp(r'_(IN|OUT)$'), '');
    if (node == null) return ref;
    if (node.ports.any((p) => p.id == ref)) return ref; // already the node's own real Port.id.

    final index = int.tryParse(ref);
    if (index != null) {
      final v2Terminals = node.metadata['v2Terminals'];
      if (v2Terminals is List && index >= 1 && index <= v2Terminals.length) {
        final terminalName = _terminalName(v2Terminals[index - 1], fallback: '');
        if (terminalName.isNotEmpty) {
          for (final port in node.ports) {
            if (port.name.toUpperCase() == terminalName.toUpperCase()) return port.id;
          }
        }
      }
    }
    return ref; // Best effort -- left as the (possibly still-mismatched) normalized reference, never fabricated further.
  }

  final updatedRelationships = <String, EngineeringRelationship>{};
  var changedAny = false;
  for (final entry in graph.relationships.entries) {
    final relationship = entry.value;
    final sourcePort = relationship.metadata['sourcePort'] as String?;
    final targetPort = relationship.metadata['targetPort'] as String?;
    final resolvedSource = resolvePortId(graph.nodes[relationship.sourceNode], sourcePort);
    final resolvedTarget = resolvePortId(graph.nodes[relationship.targetNode], targetPort);
    if (resolvedSource == sourcePort && resolvedTarget == targetPort) {
      updatedRelationships[entry.key] = relationship;
      continue;
    }
    updatedRelationships[entry.key] = relationship.copyWith(metadata: {
      ...relationship.metadata,
      if (resolvedSource != null) 'sourcePort': resolvedSource,
      if (resolvedTarget != null) 'targetPort': resolvedTarget,
      // AP-DIAGRAM-V2-BRIDGE-PORT-SUFFIX-001 — a real second consumer of
      // this same metadata (`LegacyV2StateAdapter.initializeFromDocument`,
      // feeding V2's own `restoreWire`) needs the ORIGINAL, un-normalized
      // reference: a connector-type V2 module renders TWO separate visual
      // dots per logical pin ("<pin>_IN"/"<pin>_OUT" -- confirmed live
      // against the real diagram7.json: a wire whose stored `targetPort`
      // had already been normalized here to bare "1" could no longer find
      // either dot on a 3-pin connector, silently failing to route -- the
      // exact bug this stashes the fix for), and that IN/OUT distinction
      // is exactly what stripping the suffix above (for the solver's
      // Port.id-shaped match) throws away. Stashed only when normalization
      // actually changed something, so an already-bare/already-correct
      // reference never grows this key at all.
      if (resolvedSource != sourcePort && sourcePort != null) 'v2RawSourcePort': sourcePort,
      if (resolvedTarget != targetPort && targetPort != null) 'v2RawTargetPort': targetPort,
    });
    changedAny = true;
  }
  if (!changedAny) return graph;
  return graph.copyWith(relationships: updatedRelationships);
}
