import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart'
    show primaryDiagramInstanceId;
import '../../settings/services/settings_storage.dart';
import '../controller/diagram_studio_controller_provider.dart';
import 'analysis_ui_state.dart';

/// The activated Knowledge Runtime Diagram Studio's analysis panel
/// requests analysis through — one shared, immutable snapshot per app
/// session (AP-EK-013 §11), not rebuilt per analysis call.
///
/// **Disclosed scope boundary:** this activates the Dart
/// `electrical-core` fixture package
/// (`engineering_engine`'s `buildElectricalCorePackage()`), not a
/// `.oerp` read through `OerpReader`. The real Reference Library →
/// Compiler → `.oerp` → `OerpReader` → `KnowledgeRuntime` path is fully
/// implemented and verified (`platform/oep_engine/tool/
/// verify_oerp_reader.dart`), but shipping a compiled `.oerp` as a
/// Studio application asset is a packaging/distribution decision (build
/// config, asset bundling, update strategy) outside this presentation
/// task's scope — see the AP-EK-020 final report. Swapping this
/// provider's body for `OerpReader().readFile(bundledAsset)` is the
/// entire migration once that packaging decision is made; nothing else
/// in this file (or the panel) depends on which source produced the
/// [KnowledgePackage].
final electricalCoreRuntimeProvider = Provider<KnowledgeRuntime>((ref) {
  return KnowledgeRuntime.activate(buildElectricalCorePackage(),
      allowUnsignedDevelopmentPackages: true);
});

/// Per-tab analysis persistence store — evidence lives under
/// `%APPDATA%/oep_studio/analysis/`, entirely separate from
/// `DiagramDocument`/`DiagramWorkspaceState`/`DiagramTabsStorage`/
/// `DiagramStudioSettings` (AP-EK-020 §26/§40): saving or loading an
/// analysis never touches diagram engineering data, and vice versa.
final analysisPersistenceStoreProvider =
    Provider<AnalysisPersistenceStore>((ref) {
  return AnalysisPersistenceStore(Directory(
      '${SettingsStorage.root().path}${Platform.pathSeparator}analysis'));
});

/// Per-tab analysis UI state and the "Analyze" action itself
/// (AP-EK-020 Part B9/B10), keyed by [WorkspaceTab.id] the same way
/// `diagramStudioControllerFamily` is.
final diagramAnalysisFamily =
    NotifierProvider.family<AnalysisNotifier, AnalysisUiState, String>(
  AnalysisNotifier.new,
);

/// The primary tab's alias, mirroring `diagramStudioControllerProvider`.
final diagramAnalysisProvider = diagramAnalysisFamily(primaryDiagramInstanceId);

class AnalysisNotifier extends FamilyNotifier<AnalysisUiState, String> {
  @override
  AnalysisUiState build(String arg) => const AnalysisUiState();

  /// AP-EK-020 §17 orchestration, invoked from Studio: build an
  /// [AnalysisRequest] from the active tab's current diagram, submit it
  /// to [AnalysisEngine], persist the result, and generate its
  /// explanation. Never recalculates anything itself — every
  /// engineering value in the resulting state comes from the
  /// [AnalysisResult] the Engine returned.
  ///
  /// Analyzing never saves the diagram document (AP-EK-020 §40 "Save/
  /// Analyze Separation") — [documentVersion] is a content hash of the
  /// graph exactly as it stands in memory right now, whether or not
  /// that state has ever been written to disk.
  Future<void> analyze() async {
    state = state.copyWith(phase: AnalysisUiPhase.analyzing, clearError: true);

    final controller =
        await ref.read(diagramStudioControllerFamily(arg).future);
    final graph = controller.session?.graph;
    if (graph == null) {
      state = state.copyWith(
          phase: AnalysisUiPhase.failure,
          errorMessage: 'No diagram is open to analyze.');
      return;
    }

    final documentVersion = sha256Hex(utf8.encode(jsonEncode(graph.toJson())));
    state = state.copyWith(currentDocumentVersion: documentVersion);

    final runtime = ref.read(electricalCoreRuntimeProvider);
    final request = AnalysisRequest(
      requestId: 'req-${DateTime.now().microsecondsSinceEpoch}',
      documentId: graph.id,
      documentVersion: documentVersion,
      knowledgePackageId: runtime.identity.packageId,
    );

    final result = const AnalysisEngine()
        .analyze(request: request, graph: graph, runtime: runtime);

    try {
      await ref.read(analysisPersistenceStoreProvider).save(result);
    } on StateError {
      // Re-running "Analyze" with no document change reproduces the
      // same requestId-derived analysisId only in the astronomically
      // unlikely case of a microsecond collision; a genuine identical
      // re-analysis is expected to (and does) mint a new analysisId,
      // so this is not treated as a user-facing failure.
    }

    final explanation = const ExplanationService().explain(result);
    state = state.copyWith(
      phase: result.status == AnalysisStatus.success
          ? AnalysisUiPhase.success
          : AnalysisUiPhase.failure,
      result: result,
      explanation: explanation,
      currentDocumentVersion: documentVersion,
    );
  }
}
