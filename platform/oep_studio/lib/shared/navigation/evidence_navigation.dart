import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/models/recent_history_entry.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';

/// Evidence Integration (WORK_PACKAGE_025, ENGINE-TASK-000123) — lets an
/// Engineering Graph object (a node or relationship's `EvidenceLink`)
/// navigate directly to whatever Studio-side evidence it references:
/// an image, PDF, OCR result, note, or specification, all already
/// modeled by Knowledge Studio's `SourceMaterial`/`EvidenceRegion`.
///
/// ## The `sourceReference`/`locator` convention
///
/// `EvidenceLink.sourceReference` is Engine-owned and deliberately
/// opaque ("Identifier of the Source Material this evidence traces to
/// ... Opaque to the Engineering Engine — interpreted by whatever
/// produced the evidence"). This function establishes the concrete,
/// Studio-side convention used to interpret it: [EvidenceLink.sourceReference]
/// holds a Knowledge Session `SourceMaterial.id`; when the evidence
/// concerns a specific region of that source,
/// `EvidenceLink.locator['regionId']` holds an `EvidenceRegion.id`
/// (`locator` is likewise already documented as "producer-defined"
/// shape — this is Studio's chosen shape for it). This is a Studio-side
/// convention only, not a Foundation schema change: Foundation remains
/// unaware of both `EvidenceLink` and `SourceMaterial`/`EvidenceRegion`.
///
/// No UI exists to *create* an `EvidenceLink` from Diagram Studio — see
/// `docs/ENGINEERING_PROJECT.md` for why that's out of this work
/// package's scope ("No new engineering editing features").
Future<void> goToEvidence(BuildContext context, WidgetRef ref, EvidenceLink link) async {
  final foundation = ref.read(foundationRuntimeServiceProvider);
  final sourceMaterial = foundation.sourceMaterials.where((s) => s.id == link.sourceReference).firstOrNull;
  if (sourceMaterial == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That evidence could not be found in the active Knowledge Session.')),
    );
    return;
  }

  final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
  notifier.selectSourceMaterial(sourceMaterial);

  final regionId = link.locator['regionId'] as String?;
  if (regionId != null) {
    final region = foundation.evidenceRegions.where((r) => r.id == regionId).firstOrNull;
    if (region != null) notifier.selectEvidenceRegion(region);
  }

  // Mirrors the same evidence reference on the diagram canvas, reusing
  // hooks the Engine already exposed for exactly this (WORK_PACKAGE_021
  // Selection/Navigation) but that had no caller anywhere in Studio
  // until this work package.
  final engine = ref.read(engineeringProjectServiceProvider).engine;
  engine?.registry.selection.focusEvidence(link.id);
  engine?.registry.navigation.syncEvidence(link.id);

  context.go(StudioDestination.knowledge.path);

  ref.read(engineeringProjectServiceProvider.notifier).recordHistory(RecentHistoryEntry(
        id: link.id,
        label: sourceMaterial.originalFileName,
        workspaceLabel: StudioDestination.knowledge.label,
        route: StudioDestination.knowledge.path,
        timestamp: DateTime.now(),
      ));
}
