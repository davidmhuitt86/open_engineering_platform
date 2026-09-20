// ignore_for_file: avoid_print
//
// Manual/CI verification (WP-EKE-014) against a REAL compiled package -- not
// a `flutter test`, for the same reason as `verify_oerp_reader.dart`: SDD-R010
// §16 forbids committing compiler output. Run:
//
//   cd knowledge/reference_library && python -m compiler.cli core_reference
//   cd ../../platform/oep_engine && dart run tool/verify_reference_discovery.dart
//
// Proves Reference Library -> Compiler -> .oerp -> OerpReader ->
// KnowledgeRuntime -> ReferenceDiscovery on genuinely compiled content, and
// that every discovery result resolves through the authoritative runtime.
import 'dart:io';

import 'package:engineering_engine/core/knowledge/discovery/reference_discovery.dart';
import 'package:engineering_engine/core/knowledge/knowledge_runtime.dart';
import 'package:engineering_engine/core/knowledge/oerp/oerp_reader.dart';

var _failures = 0;

void check(bool ok, String what) {
  print('${ok ? "PASS" : "FAIL"}  $what');
  if (!ok) _failures++;
}

void main() {
  final sep = Platform.pathSeparator;
  final file = File(
    '${Directory.current.path}$sep..$sep..${sep}knowledge${sep}reference_library'
    '${sep}dist${sep}core_reference_v1.oerp',
  );
  if (!file.existsSync()) {
    stderr.writeln('No compiled package at ${file.path}.');
    stderr.writeln('Run: cd knowledge/reference_library && python -m compiler.cli core_reference');
    exit(1);
  }

  const reader = OerpReader();
  final runtime = KnowledgeRuntime.activate(
    reader.readFile(file),
    allowUnsignedDevelopmentPackages: true,
  );
  final discovery = ReferenceDiscovery.create(
    runtime,
    reader.readDiscoveryIndexesFile(file),
  );
  final c = discovery.capabilities;
  print(
    'Package ${runtime.identity.packageId}@${runtime.identity.packageVersion}; '
    'discovery: ${c.indexedTermCount} terms over ${c.indexedObjectCount} objects, '
    '${c.graphEdgeCount} edges (index v${c.searchIndexVersion}/v${c.graphIndexVersion})',
  );

  // 1. A real term resolves to real authoritative object ids.
  final hits = discovery.search('resistor');
  print('search("resistor") -> ${hits.map((h) => h.objectId).toList()}');
  check(hits.isNotEmpty, 'a real search term returns results');
  check(
    hits.any((h) => h.objectId == 'component.passive.resistor'),
    'the component appears among the results',
  );
  for (final h in hits) {
    check(runtime.getObject(h.objectId).id == h.objectId, '  ${h.objectId} resolves via KnowledgeRuntime.getObject');
  }

  // 2. Multi-term ranking, alias/standard tokens, empty/no-match behaviour.
  final ranked = discovery.search('fixed resistor');
  print('search("fixed resistor") -> ${ranked.map((h) => "${h.objectId}${h.matchedTerms}").toList()}');
  check(ranked.first.score >= ranked.last.score, 'results are ranked by matched-token count');
  check(discovery.search('iec 60115').any((h) => h.objectId == 'component.passive.resistor'), 'a standards-reference token resolves');
  check(discovery.search('').isEmpty && discovery.search('zzzz').isEmpty, 'empty query / no match are valid empty results');

  // 3. A real graph relationship is discovered and resolves authoritatively.
  final edges = discovery.outgoing('component.passive.resistor');
  print('outgoing(component.passive.resistor) -> ${edges.map((e) => "${e.relationshipType}->${e.targetObjectId}").toList()}');
  check(edges.isNotEmpty, 'a real object has discoverable relationships');
  for (final e in edges) {
    final rel = runtime.getRelationship(e.relationshipId);
    check(
      rel.sourceObjectId == e.sourceObjectId && rel.targetObjectId == e.targetObjectId && rel.relationshipType == e.relationshipType,
      '  ${e.relationshipId} resolves via KnowledgeRuntime.getRelationship and agrees',
    );
    check(runtime.getObject(e.targetObjectId).id == e.targetObjectId, '  target ${e.targetObjectId} resolves via getObject');
  }
  check(
    discovery.relatedObjectIds('component.passive.resistor').contains('symbol.iec.resistor'),
    'the Reference symbol is reachable as a Reference object id (no Engine SymbolDefinition mapping made)',
  );
  check(discovery.outgoing('unit.ohm').isEmpty, 'an object with no outgoing relationships returns []');

  // 4. Determinism: an independently built discovery gives identical output.
  final again = ReferenceDiscovery.create(runtime, reader.readDiscoveryIndexesFile(file));
  String render(ReferenceDiscovery d) => [
    for (final q in ['resistor', 'fixed resistor', 'ohm', 'volt ampere', 'iec'])
      '$q=>${d.search(q).map((h) => "${h.objectId}${h.matchedTerms}").join(",")}',
    for (final o in ['component.passive.resistor', 'equation.ohms_law'])
      '$o=>${d.outgoing(o).map((e) => e.relationshipId).join(",")}',
  ].join('|');
  check(render(discovery) == render(again), 'results and ordering are identical across independent instances');

  print(_failures == 0 ? '\nVERIFICATION PASSED' : '\nVERIFICATION FAILED ($_failures)');
  exit(_failures == 0 ? 0 : 1);
}
