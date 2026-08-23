import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../acquisition/services/acquisition_runtime_service.dart';
import '../../core/models/recent_history_entry.dart';
import '../../core/models/unified_search_result.dart';
import '../../core/objects/engineering_object_runtime.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../exchange/services/exchange_runtime_service.dart';
import 'explorer_navigation.dart';
import 'workspace_aware_navigation.dart';

/// Platform-wide navigation (WORK_PACKAGE_025, ENGINE-TASK-000120) —
/// built *on top of* the existing `explorer_navigation.dart`
/// (`goToObject`/`goToRelationship`), not a replacement for it. Every
/// function here ends by activating the owning `StudioDestination` and
/// recording a [RecentHistoryEntry] (ENGINE-TASK-000119 "Shared recent
/// history"), which is what makes history shared across workspaces
/// rather than each workspace keeping its own separate list.
void _record(WidgetRef ref, {required String id, required String label, required StudioDestination destination}) {
  ref.read(engineeringProjectServiceProvider.notifier).recordHistory(RecentHistoryEntry(
        id: id,
        label: label,
        workspaceLabel: destination.label,
        route: destination.path,
        timestamp: DateTime.now(),
      ));
}

/// Navigates to a Knowledge Object (an Engineering Object, in the
/// Repository Explorer sense) or a manually-created Knowledge
/// Candidate — [id] is looked up against both lists since the two are
/// visually similar but distinct concepts.
///
/// Also implements "Shared active object" (ENGINE-TASK-000119) for the
/// one case with a principled correspondence today: if the object maps
/// to a `repositoryObjectId` on a node in the currently-open diagram,
/// that node is selected too — a real cross-reference already recorded
/// on the graph, not a fuzzy name-matching heuristic.
void goToKnowledgeObject(BuildContext context, WidgetRef ref, String id) {
  final foundation = ref.read(foundationRuntimeServiceProvider);
  final object = EngineeringObjectRuntime.instance.objectById(id);
  if (object != null) {
    goToObject(context, ref, id);
    _record(ref, id: id, label: object.name, destination: StudioDestination.objects);
    _selectCorrespondingDiagramNode(ref, repositoryObjectId: id);
    return;
  }
  final candidate = foundation.candidates.where((c) => c.id == id).firstOrNull;
  if (candidate != null) {
    ref.read(foundationRuntimeServiceProvider.notifier).selectKnowledgeCandidate(candidate);
    openOrActivateDestination(context, ref, StudioDestination.knowledge);
    _record(ref, id: id, label: candidate.name, destination: StudioDestination.knowledge);
  }
}

/// Navigates to a Relationship — Engineering Object relationships only
/// (Knowledge Candidate relationships are shown inline in Knowledge
/// Studio's own review UI, not via a standalone navigation target).
void goToKnowledgeRelationship(BuildContext context, WidgetRef ref, String relationshipId) {
  final relationship = EngineeringObjectRuntime.instance.relationshipById(relationshipId);
  if (relationship == null) return;
  goToRelationship(context, ref, relationshipId);
  _record(
    ref,
    id: relationshipId,
    label: '${relationship.sourceObjectName} → ${relationship.targetObjectName}',
    destination: StudioDestination.relationships,
  );
}

void _selectCorrespondingDiagramNode(WidgetRef ref, {required String repositoryObjectId}) {
  final projectState = ref.read(engineeringProjectServiceProvider);
  final engine = projectState.engine;
  final graph = projectState.session?.graph;
  if (engine == null || graph == null) return;
  for (final node in graph.nodes.values) {
    if (node.repositoryObjectId == repositoryObjectId) {
      engine.registry.selection.selectNode(node.id);
      return;
    }
  }
}

/// Navigates to a diagram node or relationship (whichever one of
/// [nodeId]/[relationshipId] is given) — the one genuinely new
/// navigation capability WORK_PACKAGE_025 adds: before
/// ENGINE-TASK-000118 hoisted the Engine out of `DiagramStudioPage`'s
/// own private `State`, nothing outside that page could reach
/// `engine.registry.selection` at all.
///
/// AP-OEP-WORKSPACE-CONTEXT-001/002 — the selection itself (above)
/// already lands on the one shared, Engine-owned authority
/// (`engineeringProjectServiceProvider`'s `GraphSelection`) that both
/// the standalone `/diagram` route and the Workspace's own embedded
/// Diagram tab read from — no object or id is copied anywhere. The only
/// thing this changes is *how* the destination becomes visible — see
/// `openOrActivateDestination`'s own doc comment.
void goToDiagramElement(BuildContext context, WidgetRef ref, {String? nodeId, String? relationshipId}) {
  final projectState = ref.read(engineeringProjectServiceProvider);
  final engine = projectState.engine;
  if (engine == null) return;
  if (nodeId != null) {
    engine.registry.selection.selectNode(nodeId);
    final label = projectState.session?.graph.nodes[nodeId]?.displayName ?? nodeId;
    openOrActivateDestination(context, ref, StudioDestination.diagram);
    _record(ref, id: nodeId, label: label, destination: StudioDestination.diagram);
  } else if (relationshipId != null) {
    engine.registry.selection.selectRelationship(relationshipId);
    openOrActivateDestination(context, ref, StudioDestination.diagram);
    _record(ref, id: relationshipId, label: relationshipId, destination: StudioDestination.diagram);
  }
}

/// Navigates to a Validation finding (ENGINE-TASK-000120/000125) —
/// resolves [finding.subjectId] against the active diagram graph first
/// (Validation is Engine-owned and most findings concern a node or
/// relationship), falling back to a Knowledge Object lookup, and
/// finally to the bare Validation page if neither resolves.
void goToValidationResult(BuildContext context, WidgetRef ref, ValidationFinding finding) {
  final subjectId = finding.subjectId;
  if (subjectId != null) {
    final graph = ref.read(engineeringProjectServiceProvider).session?.graph;
    if (graph != null) {
      if (graph.nodes.containsKey(subjectId)) {
        goToDiagramElement(context, ref, nodeId: subjectId);
        return;
      }
      if (graph.relationships.containsKey(subjectId)) {
        goToDiagramElement(context, ref, relationshipId: subjectId);
        return;
      }
    }
    if (EngineeringObjectRuntime.instance.hasObject(subjectId)) {
      goToKnowledgeObject(context, ref, subjectId);
      return;
    }
  }
  openOrActivateDestination(context, ref, StudioDestination.validation);
  _record(ref, id: finding.code, label: finding.message, destination: StudioDestination.validation);
}

/// Navigates to an EAM Source, Job, or Vault entry (WP-PLAT-020) — EAM
/// has no cross-references analogous to a diagram node's
/// `repositoryObjectId`, so unlike [goToKnowledgeObject] this is just a
/// destination switch plus, for a Job, selecting it (driving the
/// Pipeline panel), mirroring how [goToDiagramElement] selects a node.
void goToAcquisitionResult(BuildContext context, WidgetRef ref, UnifiedSearchResult result) {
  if (result.category == UnifiedSearchResultCategory.acquisitionJob) {
    ref.read(acquisitionRuntimeServiceProvider.notifier).selectJob(result.id);
  }
  openOrActivateDestination(context, ref, StudioDestination.acquisition);
  _record(ref, id: result.id, label: result.label, destination: StudioDestination.acquisition);
}

/// Navigates to an Exchange package or publisher (WP-EXC-010) — mirrors
/// [goToAcquisitionResult]'s own reasoning: the Exchange has no
/// cross-references analogous to a diagram node's `repositoryObjectId`,
/// so this is a destination switch plus selecting the matched
/// package/publisher so Package Detail/Publisher Profile shows
/// immediately, the same way [goToAcquisitionResult] selects a Job.
void goToExchangeResult(BuildContext context, WidgetRef ref, UnifiedSearchResult result) {
  final notifier = ref.read(exchangeRuntimeServiceProvider.notifier);
  if (result.category == UnifiedSearchResultCategory.exchangePublisher) {
    notifier.selectPublisher(result.id);
  } else {
    notifier.selectPackage(result.id);
  }
  openOrActivateDestination(context, ref, StudioDestination.exchange);
  _record(ref, id: result.id, label: result.label, destination: StudioDestination.exchange);
}

/// Navigates to a unified search result (ENGINE-TASK-000120/000121) —
/// switches on [UnifiedSearchResult.category] rather than either
/// wrapped, same-named `SearchResultKind` enum directly (see
/// `unified_search_result.dart`'s own doc comment for why).
void goToSearchResult(BuildContext context, WidgetRef ref, UnifiedSearchResult result) {
  switch (result.category) {
    case UnifiedSearchResultCategory.knowledgeObject:
      goToKnowledgeObject(context, ref, result.id);
    case UnifiedSearchResultCategory.knowledgeRelationship:
      goToKnowledgeRelationship(context, ref, result.id);
    case UnifiedSearchResultCategory.diagramNode:
      goToDiagramElement(context, ref, nodeId: result.id);
    case UnifiedSearchResultCategory.diagramRelationship:
      goToDiagramElement(context, ref, relationshipId: result.id);
    case UnifiedSearchResultCategory.acquisitionSource:
    case UnifiedSearchResultCategory.acquisitionJob:
    case UnifiedSearchResultCategory.acquisitionVaultEntry:
      goToAcquisitionResult(context, ref, result);
    case UnifiedSearchResultCategory.exchangePackage:
    case UnifiedSearchResultCategory.exchangePublisher:
      goToExchangeResult(context, ref, result);
    case UnifiedSearchResultCategory.symbol:
    case UnifiedSearchResultCategory.annotation:
    case UnifiedSearchResultCategory.layer:
      // No standalone navigation target for these today (mirrors the
      // Demonstration Host's own Search Panel, which likewise treats
      // symbol/layer results as informational only) — just switch to
      // Diagram Studio, where the result was found.
      openOrActivateDestination(context, ref, StudioDestination.diagram);
      _record(ref, id: result.id, label: result.label, destination: StudioDestination.diagram);
  }
}
