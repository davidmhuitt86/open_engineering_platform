import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../services/engineering_project_service.dart';
import '../services/foundation_runtime_service.dart';
import 'engineering_object_summary.dart';
import 'relationship_summary.dart';

/// A minimal, reusable snapshot of "what is the engineer currently
/// looking at" (Phase 8, AI Engineering Copilot) — deliberately not a
/// general AI framework, just the plain data every field of which is
/// read directly from an already-real, already-shared provider
/// (`foundationRuntimeServiceProvider`, `engineeringProjectServiceProvider`).
/// Every field is nullable/empty by default and stays that way when the
/// underlying state genuinely has nothing -- this type never invents a
/// value to fill a field. Intended for reuse by any future AI service,
/// not just the Copilot page that introduces it.
class AiEngineeringContext {
  const AiEngineeringContext({
    this.repositoryName,
    this.activeProjectName,
    this.documentPath,
    this.selectedObject,
    this.selectedRelationship,
    this.selectedNodeIds = const {},
    this.selectedRelationshipIds = const {},
    this.validationReport,
    this.knowledgeSessionName,
  });

  final String? repositoryName;
  final String? activeProjectName;
  final String? documentPath;
  final EngineeringObjectSummary? selectedObject;
  final RelationshipSummary? selectedRelationship;
  final Set<String> selectedNodeIds;
  final Set<String> selectedRelationshipIds;
  final ValidationReport? validationReport;
  final String? knowledgeSessionName;

  bool get hasAnySelection =>
      selectedObject != null || selectedRelationship != null || selectedNodeIds.isNotEmpty || selectedRelationshipIds.isNotEmpty;

  bool get hasActiveDocument => documentPath != null || selectedNodeIds.isNotEmpty || selectedRelationshipIds.isNotEmpty;

  /// Reads a fresh snapshot from the app's real, shared state. Called on
  /// demand (not watched/cached) -- the Copilot page re-reads this each
  /// time it needs current context, exactly like `UnifiedAiContextService`
  /// already does for the AI request itself.
  factory AiEngineeringContext.fromRef(WidgetRef ref) {
    final foundation = ref.read(foundationRuntimeServiceProvider);
    final project = ref.read(engineeringProjectServiceProvider);

    return AiEngineeringContext(
      repositoryName: foundation.repositoryStatus?.repositoryName,
      activeProjectName: project.activeProject?.name,
      documentPath: project.document.path,
      selectedObject: foundation.selectedObject,
      selectedRelationship: foundation.selectedRelationship,
      selectedNodeIds: project.selection.nodeIds,
      selectedRelationshipIds: project.selection.relationshipIds,
      validationReport: project.validationReport,
      knowledgeSessionName: foundation.knowledgeSession?.name,
    );
  }
}
