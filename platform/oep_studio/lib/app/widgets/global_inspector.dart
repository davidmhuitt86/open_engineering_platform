import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/engineering_inspectable.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/oep_tokens.dart';
import '../../diagram_studio/inspector/diagram_annotation_properties.dart';
import '../../diagram_studio/inspector/diagram_layer_properties.dart';
import '../../diagram_studio/inspector/engineering_evidence_link_properties.dart';
import '../../diagram_studio/inspector/engineering_group_properties.dart';
import '../../diagram_studio/inspector/engineering_node_properties.dart';
import '../../diagram_studio/inspector/engineering_port_properties.dart';
import '../../diagram_studio/inspector/engineering_relationship_properties.dart';
import '../../diagram_studio/inspector/wire_override_properties.dart';
import '../active_studio.dart';

/// The OEP Global Inspector (target shell region 06/09,
/// `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md` §8;
/// canonical reference `docs/architecture/ux/renders/oep-shell/inspector.svg`).
///
/// WP-UI-DS-009 — a GLOBAL, persistent right-side shell region (structural
/// sibling of the Main Engineering Surface, hosted by
/// `EngineeringWorkspacePage`, not embedded in `LegacyV2WebViewPage` and
/// not part of the renderer). Its CONTAINER is global; its CONTENT is
/// Studio/selection-scoped via [activeStudioProvider] and the existing
/// selection-bridge state described below.
///
/// **Reused, not reinvented:** Diagram Studio already has a complete,
/// currently-*unhosted* selection bridge —
/// `DiagramStudioController._syncPropertyInspectorSelection` (still live,
/// listening to `engine.registry.selection.changes`) already pushes the
/// single selected node/relationship/group/port/layer/annotation/
/// evidence-link/wire-override into
/// `FoundationServiceState.selectedEngineeringInspectable`
/// (`selectEngineeringInspectable`/`clearEngineeringInspectableSelection`,
/// `foundation_runtime_service.dart`) every time the live diagram selection
/// changes. The 8 real, existing "per-kind Property Inspector mode" widgets
/// (`lib/diagram_studio/inspector/*.dart` — `EngineeringNodeProperties`,
/// `EngineeringRelationshipProperties`, `EngineeringGroupProperties`,
/// `EngineeringPortProperties`, `DiagramLayerProperties`,
/// `DiagramAnnotationProperties`, `EngineeringEvidenceLinkProperties`,
/// `WireOverrideProperties`) already existed, display-only, unchanged by
/// this section — the widget that used to host them (`PropertyInspectorPanel`)
/// was part of the now-retired Workbench/Perspective architecture (AP-UX-006
/// §21) and no longer exists. This widget is that host, rebuilt fresh
/// against the target shell, not a rewrite of the inspection widgets
/// themselves. No new selection provider, no new inspection logic, no
/// duplicate state store was introduced.
///
/// **Other six Studios:** no existing global selection/context source was
/// found for EAM, Knowledge Studio, Engineering Exchange, Instruments,
/// Settings, or Home (verified by direct inspection, not assumed) — no
/// fabricated inspection content is shown for them.
///
/// **Width and visibility (post-review adjustment, your direction):** the
/// canonical width token is [OepGeometry.inspectorWidth] (360px), but this
/// region instead uses [_width] (280px, matching the Context Navigation
/// reference width already used elsewhere) — a deliberate, disclosed
/// deviation from the token, not a change to the token itself, since
/// narrowing it was specific to how this region reads at the current
/// window size, not a re-ratification of the canonical spec. The region
/// also collapses to zero width (`SizedBox.shrink()`) whenever there is
/// nothing real to inspect, rather than always reserving space for an
/// empty panel — this is content-driven visibility (is there something to
/// show right now?), not the viewport-size-driven responsive/collapse
/// behavior OD-002 still blocks; no breakpoint or window-size logic was
/// added.
class GlobalInspector extends ConsumerWidget {
  const GlobalInspector({super.key});

  /// Deliberately narrower than [OepGeometry.inspectorWidth] (360px) — see
  /// this class's own doc comment.
  static const double _width = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStudio = ref.watch(activeStudioProvider);
    final inspectable = activeStudio == ActiveStudio.diagram
        ? ref.watch(foundationRuntimeServiceProvider).selectedEngineeringInspectable
        : null;

    if (inspectable == null) {
      // Nothing real to inspect right now — collapse rather than reserve
      // 280px for an empty panel.
      return const SizedBox.shrink();
    }

    return Container(
      width: _width,
      decoration: const BoxDecoration(
        color: OepColors.surface2,
        border: Border(left: BorderSide(color: OepColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'INSPECTOR',
              style: TextStyle(
                color: OepColors.textMuted,
                fontFamily: OepTypography.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const Divider(height: 1, color: OepColors.border),
          Expanded(child: _DiagramInspectorContent(inspectable: inspectable)),
        ],
      ),
    );
  }
}

class _DiagramInspectorContent extends ConsumerWidget {
  const _DiagramInspectorContent({required this.inspectable});

  final EngineeringInspectable inspectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(engineeringProjectServiceProvider).session;

    switch (inspectable.kind) {
      case EngineeringInspectableKind.node:
        return EngineeringNodeProperties(node: inspectable.node!);
      case EngineeringInspectableKind.relationship:
        final relationship = inspectable.relationship!;
        final sourceName = session?.graph.nodes[relationship.sourceNode]?.displayName ?? relationship.sourceNode;
        final targetName = session?.graph.nodes[relationship.targetNode]?.displayName ?? relationship.targetNode;
        return EngineeringRelationshipProperties(
          relationship: relationship,
          sourceNodeName: sourceName,
          targetNodeName: targetName,
        );
      case EngineeringInspectableKind.group:
        return EngineeringGroupProperties(group: inspectable.group!);
      case EngineeringInspectableKind.port:
        return EngineeringPortProperties(port: inspectable.port!, ownerNodeId: inspectable.portOwnerNodeId!);
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
}

