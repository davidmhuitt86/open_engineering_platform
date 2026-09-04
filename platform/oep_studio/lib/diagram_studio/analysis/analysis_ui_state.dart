import 'package:engineering_engine/engineering_engine.dart';

/// Diagram Studio's own presentation-lifecycle status for the analysis
/// panel (AP-EK-020 Part B10) — distinct from [AnalysisStatus] (the
/// Engine's own result status). This one only ever describes "what is
/// Studio doing right now", never an engineering outcome.
enum AnalysisUiPhase { idle, analyzing, success, failure }

/// Per-tab analysis presentation state (AP-EK-020 Part B10). One
/// instance per Diagram Studio tab (`diagramAnalysisFamily`, keyed by
/// `WorkspaceTab.id`, mirrors `diagramStudioControllerFamily`'s own
/// per-tab keying) — analysis identity is never conflated with
/// workspace/tab identity (AP-EK-020 §32).
///
/// [AnalysisEngine] remains the sole authority for every engineering
/// value inside [result] — this class only tracks *which* result is
/// currently shown and whether Studio considers it current or stale.
class AnalysisUiState {
  final AnalysisUiPhase phase;
  final AnalysisResult? result;
  final Explanation? explanation;
  final String? errorMessage;

  /// The content-hash `documentVersion` of the diagram graph as it
  /// exists *right now* — read fresh on every rebuild, independent of
  /// [result]. When this differs from `result.documentVersion`, the
  /// diagram has changed since [result] was produced: [result] is
  /// historical/stale for the current document, not wrong or deleted
  /// (AP-EK-020 §27) — [isStale] surfaces that comparison for the UI.
  final String? currentDocumentVersion;

  const AnalysisUiState({
    this.phase = AnalysisUiPhase.idle,
    this.result,
    this.explanation,
    this.errorMessage,
    this.currentDocumentVersion,
  });

  bool get isStale =>
      result != null &&
      currentDocumentVersion != null &&
      result!.documentVersion != currentDocumentVersion;

  AnalysisUiState copyWith({
    AnalysisUiPhase? phase,
    AnalysisResult? result,
    Explanation? explanation,
    String? errorMessage,
    bool clearError = false,
    String? currentDocumentVersion,
  }) {
    return AnalysisUiState(
      phase: phase ?? this.phase,
      result: result ?? this.result,
      explanation: explanation ?? this.explanation,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentDocumentVersion:
          currentDocumentVersion ?? this.currentDocumentVersion,
    );
  }
}
