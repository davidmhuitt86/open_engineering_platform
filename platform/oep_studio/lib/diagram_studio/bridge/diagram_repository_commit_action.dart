import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import 'engine_graph_commit_service.dart';

/// AP-OEP-DIAGRAM-REPOSITORY-001 — the one commit trigger used by both
/// `EngineeringNodeProperties` and `EngineeringRelationshipProperties`'s
/// existing "Repository Object"/"Repository Relationship" rows, so the
/// wiring/feedback logic exists exactly once rather than being
/// duplicated across both inspector widgets.
///
/// Flow: `EngineGraphCommitService.commit()` (already-existing, already-
/// tested — AP-OEP-FOUNDATION-BRIDGE-001) → `EditingService.
/// applyExternalGraphUpdate` (writes the result onto the *live* session
/// so the Inspector/canvas reflect it immediately, without touching undo
/// history) → `EngineeringProjectNotifier.persistCommittedGraph`
/// (AP-OEP-DIAGRAM-REPOSITORY-001 — writes the updated graph, including
/// `diagramRepositoryId`, through the existing `DiagramDocument` save
/// path so it survives close/reopen per AP-OEP-DIAGRAM-PERSISTENCE-001;
/// a no-op for a document that has never been saved) →
/// `FoundationRuntimeNotifier.refreshRepository()` (the same existing,
/// already-public refresh Knowledge Studio's own commit flow calls after
/// a successful commit, `foundation_runtime_service.dart`'s
/// `commitToFoundation`) — this is what makes the freshly-committed ids
/// immediately resolvable by `goToObject`/`goToRelationship`, both of
/// which look objects up via `EngineeringObjectRuntime`'s cache, fed
/// from exactly the state this refresh call updates.
///
/// Feedback is a single `SnackBar` via the existing `ScaffoldMessenger`
/// pattern already used for command failures (`studio_ribbon.dart`) —
/// no new notification architecture.
Future<void> commitDiagramToRepository(BuildContext context, WidgetRef ref) async {
  final projectState = ref.read(engineeringProjectServiceProvider);
  final engine = projectState.engine;
  final session = projectState.session;
  if (engine == null || session == null) {
    _showSnack(context, 'No active diagram to commit.');
    return;
  }
  final bridge = engine.registry.foundationBridge;
  if (bridge == null) {
    _showSnack(context, 'No Foundation repository is open — open a repository before committing.');
    return;
  }

  try {
    final outcome = await EngineGraphCommitService.commit(
      bridge: bridge,
      graph: session.graph,
      graphService: engine.graph,
    );
    engine.editing.applyExternalGraphUpdate(outcome.graph);
    // AP-OEP-DIAGRAM-REPOSITORY-001 — persists the newly-assigned
    // repositoryObjectId/repositoryRelationshipId/diagramRepositoryId
    // through the existing save path, so a committed diagram's identity
    // (AP-OEP-DIAGRAM-PERSISTENCE-001) actually survives close/reopen
    // rather than living only in the in-memory session until the user's
    // next unrelated Save. A no-op for a never-saved document — see
    // `persistCommittedGraph`'s own doc comment.
    await ref.read(engineeringProjectServiceProvider.notifier).persistCommittedGraph(outcome.graph);
    ref.read(foundationRuntimeServiceProvider.notifier).refreshRepository();

    if (!context.mounted) return;
    _showSnack(context, _summarize(outcome.result));
  } catch (error) {
    if (!context.mounted) return;
    // Truthful failure reporting (AP-OEP-DIAGRAM-REPOSITORY-001 step 5):
    // `EngineGraphCommitService.commit()` never writes anything back on
    // failure, so nothing here needs to be, or was, reverted — the
    // message must not imply otherwise.
    _showSnack(context, 'Commit to Repository failed — nothing was persisted. ${_shortMessage(error)}');
  }
}

String _summarize(GraphCommitResult result) {
  final committedNodes = result.nodeRepositoryIds.length;
  final committedRelationships = result.relationshipRepositoryIds.length;
  final unmappedNodes = result.unmappedNodeIds.length;
  final unmappedRelationships = result.unmappedRelationshipIds.length;

  if (committedNodes == 0 && committedRelationships == 0 && unmappedNodes == 0 && unmappedRelationships == 0) {
    return 'Nothing new to commit — every object/relationship is already in the Repository.';
  }

  final parts = <String>[];
  if (committedNodes > 0 || committedRelationships > 0) {
    parts.add('Committed $committedNodes object${committedNodes == 1 ? '' : 's'}, '
        '$committedRelationships relationship${committedRelationships == 1 ? '' : 's'}.');
  } else {
    parts.add('Nothing new to commit.');
  }
  if (unmappedNodes > 0) {
    parts.add('$unmappedNodes node${unmappedNodes == 1 ? '' : 's'} skipped — no matching Repository object type.');
  }
  if (unmappedRelationships > 0) {
    parts.add(
      '$unmappedRelationships relationship${unmappedRelationships == 1 ? '' : 's'} skipped — no matching Repository relationship type.',
    );
  }
  return parts.join(' ');
}

String _shortMessage(Object error) {
  final text = error.toString();
  return text.length > 160 ? '${text.substring(0, 160)}…' : text;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
