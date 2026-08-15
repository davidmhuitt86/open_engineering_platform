import 'package:engineering_engine/engineering_engine.dart';

import '../../knowledge/models/ai_request.dart';

/// Builds an `AiRequest` from Engine-owned Selection + Engineering Graph
/// data (WORK_PACKAGE_024, ENGINE-TASK-000116) — pure functions, no
/// provider call. Mirrors Knowledge Studio's `PromptService`, but reads
/// Diagram Studio's own domain (`EngineeringNode`/`EngineeringRelationship`/
/// `EvidenceLink`/`GraphSelection`) instead of `SourceMaterial`/
/// `EngineeringEntity`/`EngineeringContext`. Deliberately a *new*, small,
/// local assembler rather than extending `PromptService` itself — bolting
/// Engineering-Graph-shaped branches onto a service hand-written against
/// Knowledge Studio's own models would blur which domain owns it; both
/// assemblers instead call the same generic `AiProvider.complete(AiRequest)`
/// contract independently.
abstract final class DiagramPromptContext {
  static const String _systemPrompt =
      'You are an assistant helping an engineer understand and review a '
      'wiring/schematic diagram. Answer using only the graph data provided; '
      'never invent components, connections, or evidence that are not listed.';

  /// Builds a request asking about whatever is currently selected (one or
  /// more nodes/relationships/groups). [question] is the engineer's own
  /// free-text question; when omitted, a generic "describe this" prompt is
  /// used instead.
  static AiRequest buildSelectionRequest({
    required EngineeringGraph graph,
    required GraphSelection selection,
    String? question,
  }) {
    final referencedNodeIds = <String>[];
    final evidenceLabels = <String, String>{};
    final buffer = StringBuffer();

    buffer.writeln('# Graph Summary');
    buffer.writeln('${graph.nodes.length} node(s), ${graph.relationships.length} relationship(s).');
    buffer.writeln();

    if (selection.nodeIds.isNotEmpty) {
      buffer.writeln('# Selected Nodes');
      for (final nodeId in selection.nodeIds) {
        final node = graph.nodes[nodeId];
        if (node == null) continue;
        referencedNodeIds.add(nodeId);
        evidenceLabels[nodeId] = node.displayName;
        buffer.writeln(
          '- ${node.displayName} (id: ${node.id}, category: ${node.category.name}, '
          'symbol: ${node.symbolId ?? 'none'})',
        );
        for (final link in node.evidenceLinks) {
          buffer.writeln('    evidence: ${link.kind.name} -> ${link.sourceReference}');
        }
      }
      buffer.writeln();
    }

    if (selection.relationshipIds.isNotEmpty) {
      buffer.writeln('# Selected Relationships');
      for (final relationshipId in selection.relationshipIds) {
        final relationship = graph.relationships[relationshipId];
        if (relationship == null) continue;
        final sourceName = graph.nodes[relationship.sourceNode]?.displayName ?? relationship.sourceNode;
        final targetName = graph.nodes[relationship.targetNode]?.displayName ?? relationship.targetNode;
        evidenceLabels[relationshipId] = '$sourceName -> $targetName';
        buffer.writeln(
          '- ${relationship.relationshipType.name}: $sourceName -> $targetName (id: ${relationship.id})',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('# Question');
    buffer.writeln(question?.trim().isNotEmpty == true ? question!.trim() : 'Describe the selected item(s) above.');

    return AiRequest(
      id: EngineIds.generate('ai_request'),
      systemPrompt: _systemPrompt,
      userPrompt: buffer.toString(),
      sourceId: graph.id,
      referencedEntityIds: referencedNodeIds,
      referencedContextIds: const [],
      evidenceLabels: evidenceLabels,
      createdTime: DateTime.now(),
    );
  }
}
