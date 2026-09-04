// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/core/graph/models/engineering_graph.dart';
import 'package:engineering_engine/core/views/diagram/diagram_layout_state.dart';

Future<void> main() async {
  final path =
      '${Directory.current.path}${Platform.pathSeparator}samples${Platform.pathSeparator}trx300.json';
  final raw = await File(path).readAsString();
  final decoded = jsonDecode(raw) as Map<String, Object?>;

  final graph = EngineeringGraph.fromJson(decoded['graph'] as Map<String, Object?>);
  final layout = DiagramLayoutState.fromJson(decoded['layout'] as Map<String, Object?>);

  print('Parsed OK. schemaVersion=${decoded['schemaVersion']} documentId=${decoded['documentId']}');
  print('Nodes: ${graph.nodes.length}, Relationships: ${graph.relationships.length}, Positions: ${layout.positions.length}');

  // Check every relationship references a node that actually exists.
  final danglingSource = <String>[];
  final danglingTarget = <String>[];
  for (final rel in graph.relationships.values) {
    if (!graph.nodes.containsKey(rel.sourceNode)) danglingSource.add('${rel.id}: ${rel.sourceNode}');
    if (!graph.nodes.containsKey(rel.targetNode)) danglingTarget.add('${rel.id}: ${rel.targetNode}');
  }
  if (danglingSource.isNotEmpty) print('DANGLING SOURCE refs: $danglingSource');
  if (danglingTarget.isNotEmpty) print('DANGLING TARGET refs: $danglingTarget');

  // Check every node has a v2ModuleId and every node id has a position.
  final missingV2Id = <String>[];
  final missingPosition = <String>[];
  for (final node in graph.nodes.values) {
    if (node.metadata['v2ModuleId'] == null) missingV2Id.add(node.id);
    if (!layout.positions.containsKey(node.id)) missingPosition.add(node.id);
  }
  if (missingV2Id.isNotEmpty) print('MISSING v2ModuleId: $missingV2Id');
  if (missingPosition.isNotEmpty) print('MISSING position: $missingPosition');

  if (danglingSource.isEmpty && danglingTarget.isEmpty && missingV2Id.isEmpty && missingPosition.isEmpty) {
    print('ALL CHECKS PASSED.');
  }
}
