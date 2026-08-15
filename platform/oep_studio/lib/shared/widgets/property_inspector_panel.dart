import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../acquisition/inspector/acquisition_properties.dart';
import '../../acquisition/services/acquisition_runtime_service.dart';
import '../../acquisition/services/acquisition_selection.dart';
import '../../core/models/engineering_inspectable.dart';
import '../../core/models/engineering_object_summary.dart';
import '../../core/models/relationship_summary.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../diagram_studio/inspector/diagram_annotation_properties.dart';
import '../../diagram_studio/inspector/diagram_layer_properties.dart';
import '../../diagram_studio/inspector/engineering_evidence_link_properties.dart';
import '../../diagram_studio/inspector/engineering_group_properties.dart';
import '../../diagram_studio/inspector/engineering_node_properties.dart';
import '../../diagram_studio/inspector/engineering_port_properties.dart';
import '../../diagram_studio/inspector/engineering_relationship_properties.dart';
import '../../diagram_studio/inspector/wire_override_properties.dart';
import '../../knowledge/inspector/ai_suggestion_properties.dart';
import '../../knowledge/inspector/engineering_context_properties.dart';
import '../../knowledge/inspector/engineering_entity_properties.dart';
import '../../knowledge/inspector/evidence_link_entries.dart';
import '../../knowledge/inspector/evidence_region_properties.dart';
import '../../knowledge/inspector/knowledge_candidate_properties.dart';
import '../../knowledge/inspector/procedure_step_properties.dart';
import '../../knowledge/inspector/relationship_candidate_properties.dart';
import '../../knowledge/inspector/session_properties.dart';
import '../../knowledge/inspector/source_material_properties.dart';
import '../../knowledge/models/evidence_link.dart';
import '../../knowledge/models/evidence_region.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/ocr_processing_status.dart';
import '../../knowledge/models/source_material.dart';
import 'property_field.dart';

/// Whether the Property Inspector is shown in `StudioShell`'s layout --
/// toggled from the Menu Bar's View menu, mirroring
/// `outputPanelVisibleProvider`'s pattern in `output_panel.dart`.
final propertyInspectorVisibleProvider = StateProvider<bool>((ref) => true);

/// The Property Inspector (SDD-004, introduced as a placeholder in
/// Work Package 003; live Object data in Work Package 004; Relationship
/// mode in Work Package 005; Knowledge Candidate/Session modes in Work
/// Package 007; Relationship Candidate/Source Material modes in Work
/// Package 008; Evidence Region mode in Work Package 009).
/// Automatically switches between modes based on the Connection
/// Manager's Current Selection — Evidence Region, Knowledge Candidate,
/// Relationship Candidate, Source Material, Object, and Relationship
/// selection are mutually exclusive (see
/// `FoundationRuntimeNotifier.selectObject`/`selectRelationship`/
/// `selectKnowledgeCandidate`/`selectRelationshipCandidate`/
/// `selectSourceMaterial`/`selectEvidenceRegion`); Session mode is shown
/// only as a fallback, when a Knowledge Curation Session exists but
/// nothing more specific is selected. Display only — no editing here,
/// per SDD-011 and every work package since (candidate/region editing
/// happens through the Engineering Review panel/Evidence Browser
/// instead).
class PropertyInspectorPanel extends ConsumerWidget {
  const PropertyInspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final selectedAiSuggestion = foundation.selectedAiSuggestion;
    final selectedContext = foundation.selectedContext;
    final selectedEntity = foundation.selectedEntity;
    final selectedEvidenceRegion = foundation.selectedEvidenceRegion;
    final selectedCandidate = foundation.selectedCandidate;
    final selectedProcedureStep = foundation.selectedProcedureStep;
    final selectedRelationshipCandidate = foundation.selectedRelationshipCandidate;
    final selectedSourceMaterial = foundation.selectedSourceMaterial;
    final selectedObject = foundation.selectedObject;
    final selectedRelationship = foundation.selectedRelationship;
    final selectedEngineeringInspectable = foundation.selectedEngineeringInspectable;
    final knowledgeSession = foundation.knowledgeSession;

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(left: BorderSide(color: StudioColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Property Inspector',
              style: TextStyle(
                color: StudioColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          // Engineering Acquisition selection takes precedence when
          // present: it comes from EAM's REST API and has no Foundation
          // representation at all, so it can't participate in the
          // Foundation-selection switch below (see
          // `AcquisitionSelection`'s own doc comment). Selecting
          // anything in an Acquisition panel is always the engineer's
          // most recent, most specific intent.
          if (!ref.watch(acquisitionSelectionProvider).isEmpty)
            Expanded(child: _acquisitionProperties(ref))
          else
          Expanded(
            child: switch ((
              selectedAiSuggestion,
              selectedContext,
              selectedEntity,
              selectedEvidenceRegion,
              selectedCandidate,
              selectedProcedureStep,
              selectedRelationshipCandidate,
              selectedSourceMaterial,
              selectedObject,
              selectedRelationship,
              selectedEngineeringInspectable,
              knowledgeSession,
            )) {
              (final suggestion?, _, _, _, _, _, _, _, _, _, _, _) => AiSuggestionProperties(
                suggestion: suggestion,
                sourceName: _sourceName(foundation.sourceMaterials, suggestion.sourceId),
                supportingEntities: foundation.supportingEntitiesFor(suggestion.id),
                supportingContexts: foundation.supportingContextsFor(suggestion.id),
                conversation: foundation.currentAiConversation,
              ),
              (_, final context?, _, _, _, _, _, _, _, _, _, _) => EngineeringContextProperties(
                context: context,
                sourceName: _sourceName(foundation.sourceMaterials, context.sourceId),
                statistics: foundation.contextStatisticsFor(context.id),
                childEntities: foundation.childEntitiesFor(context.id),
                parentContext: foundation.parentContextOf(context.id),
                validation: foundation.contextValidation[context.id],
              ),
              (_, _, final entity?, _, _, _, _, _, _, _, _, _) => EngineeringEntityProperties(
                entity: entity,
                sourceName: _sourceName(foundation.sourceMaterials, entity.sourceId),
                pattern: foundation.patternFor(entity.id),
                validation: foundation.entityValidation[entity.id],
              ),
              (_, _, _, final region?, _, _, _, _, _, _, _, _) => EvidenceRegionProperties(
                region: region,
                sourceName: _sourceName(foundation.sourceMaterials, region.sourceId),
                links: _linkedCandidates(foundation.evidenceLinks, foundation.candidates, region.id),
              ),
              (_, _, _, _, final candidate?, _, _, _, _, _, _, _) => KnowledgeCandidateProperties(
                candidate: candidate,
                links: _linkedRegions(
                  foundation.evidenceLinks,
                  foundation.evidenceRegions,
                  foundation.sourceMaterials,
                  candidate.id,
                ),
              ),
              (_, _, _, _, _, final step?, _, _, _, _, _, _) => ProcedureStepProperties(step: step),
              (_, _, _, _, _, _, final relationship?, _, _, _, _, _) => RelationshipCandidateProperties(
                relationship: relationship,
                sourceName: _candidateName(foundation.candidates, relationship.sourceCandidateId),
                targetName: _candidateName(foundation.candidates, relationship.targetCandidateId),
              ),
              (_, _, _, _, _, _, _, final source?, _, _, _, _) => SourceMaterialProperties(
                source: source,
                evidenceRegionCount: foundation.evidenceRegions
                    .where((region) => region.sourceId == source.id)
                    .length,
                selectedPages:
                    foundation.pageSelections
                        .where((selection) => selection.sourceId == source.id)
                        .map((selection) => selection.page)
                        .toList()
                      ..sort(),
                ocrStatus: foundation.ocrProcessingStatus[source.id] ?? OcrProcessingStatus.notProcessed,
                ocrResults: foundation.ocrResultsForSource(source.id),
                ocrAverageConfidence: foundation.ocrAverageConfidenceFor(source.id),
              ),
              (_, _, _, _, _, _, _, _, final object?, _, _, _) => _ObjectProperties(object: object),
              (_, _, _, _, _, _, _, _, _, final relationship?, _, _) => _RelationshipProperties(relationship: relationship),
              (_, _, _, _, _, _, _, _, _, _, final inspectable?, _) =>
                _engineeringInspectableProperties(inspectable),
              (_, _, _, _, _, _, _, _, _, _, _, final session?) => SessionProperties(
                session: session,
                sourceCount: foundation.knowledgeSourceCount,
                candidateCount: foundation.knowledgeCandidateCount,
                acceptedCount: foundation.knowledgeAcceptedCount,
                rejectedCount: foundation.knowledgeRejectedCount,
                pendingCount: foundation.knowledgePendingCount,
                relationshipCandidateCount: foundation.knowledgeRelationshipCandidateCount,
                health: foundation.sessionHealth,
                commitPlan: foundation.commitPlan,
                latestCommitReport: foundation.latestCommitReport,
              ),
              _ => const _NoSelection(),
            },
          ),
        ],
      ),
    );
  }

  /// Dispatches a Diagram Studio selection to its own `*Properties`
  /// widget (WORK_PACKAGE_024, ENGINE-TASK-000110) — the single tuple
  /// slot bridging Engine-owned Selection into this otherwise
  /// Knowledge-Studio-flavored Property Inspector.
  static Widget _engineeringInspectableProperties(EngineeringInspectable inspectable) {
    switch (inspectable.kind) {
      case EngineeringInspectableKind.node:
        return EngineeringNodeProperties(node: inspectable.node!);
      case EngineeringInspectableKind.relationship:
        return EngineeringRelationshipProperties(
          relationship: inspectable.relationship!,
          sourceNodeName: inspectable.relationship!.sourceNode,
          targetNodeName: inspectable.relationship!.targetNode,
        );
      case EngineeringInspectableKind.group:
        return EngineeringGroupProperties(group: inspectable.group!);
      case EngineeringInspectableKind.port:
        return EngineeringPortProperties(
          port: inspectable.port!,
          ownerNodeId: inspectable.portOwnerNodeId!,
        );
      case EngineeringInspectableKind.layer:
        return DiagramLayerProperties(layer: inspectable.layer!);
      case EngineeringInspectableKind.annotation:
        return DiagramAnnotationProperties(annotation: inspectable.annotation!);
      case EngineeringInspectableKind.wireOverride:
        return WireOverrideProperties(
          relationshipId: inspectable.wireOverrideRelationshipId!,
          points: inspectable.wireOverridePoints!,
        );
      case EngineeringInspectableKind.evidenceLink:
        return EngineeringEvidenceLinkProperties(
          link: inspectable.evidenceLink!,
          ownerId: inspectable.evidenceLinkOwnerId!,
        );
    }
  }

  static String _candidateName(List<KnowledgeCandidate> candidates, String candidateId) {
    for (final candidate in candidates) {
      if (candidate.id == candidateId) return candidate.name;
    }
    return candidateId;
  }

  /// Engineering Acquisition modes -- Official Source, Acquisition Job,
  /// or Reference Vault Artifact, whichever the engineer last selected.
  Widget _acquisitionProperties(WidgetRef ref) {
    final selection = ref.watch(acquisitionSelectionProvider);
    final acquisition = ref.watch(acquisitionRuntimeServiceProvider);

    String? nameOfSource(String sourceId) {
      for (final source in acquisition.sources) {
        if (source.id == sourceId) return source.name;
      }
      return null;
    }

    if (selection.source != null) return OfficialSourceProperties(source: selection.source!);
    if (selection.job != null) {
      return AcquisitionJobProperties(job: selection.job!, sourceName: nameOfSource(selection.job!.sourceId));
    }
    return VaultArtifactProperties(
      artifact: selection.artifact!,
      sourceName: nameOfSource(selection.artifact!.sourceId),
    );
  }

  static String _sourceName(List<SourceMaterial> sources, String sourceId) {
    for (final source in sources) {
      if (source.id == sourceId) return source.originalFileName;
    }
    return sourceId;
  }

  static List<LinkedCandidateEntry> _linkedCandidates(
    List<EvidenceLink> links,
    List<KnowledgeCandidate> candidates,
    String regionId,
  ) {
    final entries = <LinkedCandidateEntry>[];
    for (final link in links) {
      if (link.regionId != regionId) continue;
      for (final candidate in candidates) {
        if (candidate.id == link.candidateId) {
          entries.add(LinkedCandidateEntry(link: link, candidate: candidate));
          break;
        }
      }
    }
    return entries;
  }

  static List<LinkedRegionEntry> _linkedRegions(
    List<EvidenceLink> links,
    List<EvidenceRegion> regions,
    List<SourceMaterial> sources,
    String candidateId,
  ) {
    final entries = <LinkedRegionEntry>[];
    for (final link in links) {
      if (link.candidateId != candidateId) continue;
      for (final region in regions) {
        if (region.id == link.regionId) {
          entries.add(LinkedRegionEntry(link: link, region: region, sourceName: _sourceName(sources, region.sourceId)));
          break;
        }
      }
    }
    return entries;
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No Object Selected',
          textAlign: TextAlign.center,
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

class _ObjectProperties extends StatelessWidget {
  const _ObjectProperties({required this.object});

  final EngineeringObjectSummary object;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Name', value: object.name),
        PropertyField(label: 'Object ID', value: object.objectId, monospace: true),
        PropertyField(label: 'Object Type', value: object.category.label),
        PropertyField(label: 'Author', value: object.author),
        PropertyField(label: 'Version', value: object.version),
        PropertyField(label: 'Description', value: object.description.isEmpty ? '—' : object.description),
        PropertyField(label: 'Tags', value: object.tags.isEmpty ? '—' : object.tags.join(', ')),
      ],
    );
  }
}

class _RelationshipProperties extends StatelessWidget {
  const _RelationshipProperties({required this.relationship});

  final RelationshipSummary relationship;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Relationship ID', value: relationship.relationshipId, monospace: true),
        PropertyField(label: 'Relationship Type', value: relationship.type.label),
        PropertyField(label: 'Source Object', value: relationship.sourceObjectName),
        PropertyField(label: 'Target Object', value: relationship.targetObjectName),
        PropertyField(label: 'Author', value: relationship.author),
        PropertyField(label: 'Description', value: relationship.description.isEmpty ? '—' : relationship.description),
        PropertyField(label: 'Created Date', value: relationship.createdUtc.isEmpty ? '—' : relationship.createdUtc),
      ],
    );
  }
}
