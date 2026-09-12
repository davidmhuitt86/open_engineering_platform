import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../electrical/studio_electrical_solver.dart';
import '../simulation/diagram_simulation_service.dart';

/// PRODUCT-READINESS-009 — the Diagram Studio side of the interactive
/// electrical trace feature. Pure orchestration: every path/diagnostic
/// shown by the Trace Inspector comes from [TraceEngine.trace] (§1/§41 —
/// "reuse TraceEngine," never a second traversal engine). This controller
/// decides WHEN to (re)trace (target/mode/operating-context/topology
/// change) and holds the transient UI-facing [TraceResult] — never
/// engineering document data (§20, never persisted into
/// `DiagramDocument`).
///
/// For [TraceMode.conducting]/[TraceMode.currentFlow], a real
/// [SolvedElectricalState] is produced via the caller-supplied
/// [ElectricalSolver] first (the same authoritative solve the DMM
/// instrument uses — §22: shared terminal identity, no dependency on
/// [MultimeterController]). [TraceMode.physical] never solves — it is
/// independent of electrical operating state by definition (§6/§17).
class TraceController extends ChangeNotifier {
  /// §9 -- defaults to [buildStudioTraceEngine] (the real, shared TRX300
  /// reference-behavior configuration), not a bare `TraceEngine()` -- see
  /// that function's own doc comment for why `TraceEngine.behaviorResolver`
  /// must be supplied explicitly. A caller (tests) may still inject its
  /// own [engine].
  TraceController({TraceEngine? engine}) : _engine = engine ?? buildStudioTraceEngine();

  final TraceEngine _engine;

  /// §31 generation semantics — one monotonic counter for the lifetime of
  /// this controller, matching the same per-consumer-owned-counter
  /// convention `MultimeterController`/`OipHostBridgeService` already
  /// established.
  final ElectricalSolutionGenerationCounter generationCounter = ElectricalSolutionGenerationCounter();

  TraceTarget? _target;
  TraceTarget? get target => _target;

  TraceMode _mode = TraceMode.physical;
  TraceMode get mode => _mode;

  TraceResult? result;

  /// PRODUCT-READINESS-010 §12/§31 — the [SolvedElectricalState] that
  /// produced [result], kept ONLY so [CircuitSummary.derive] can surface
  /// a genuinely solved source-terminal voltage (§13). `null` for a
  /// physical-mode result (which never solves at all) or before any
  /// trace has run. Never used for anything beyond that read -- the
  /// controller itself performs no additional electrical computation.
  SolvedElectricalState? lastSolvedState;

  /// §9/§30-equivalent stale-result protection (the same correlation
  /// pattern `MultimeterController._electricalRequestSeq` already
  /// established): a trace superseded by a newer target/mode/context
  /// change while its own solve was "in flight" must never overwrite a
  /// newer result.
  int _requestSeq = 0;

  void setTarget(TraceTarget? newTarget) {
    if (_target == newTarget) return;
    _target = newTarget;
    _invalidate();
  }

  void setMode(TraceMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    _invalidate();
  }

  /// §29/§30 — clears the target as well as the result, returning the
  /// Trace Inspector to its empty state and the diagram to its
  /// unhighlighted state.
  void clear() {
    _target = null;
    _invalidate();
  }

  void _invalidate() {
    result = null;
    lastSolvedState = null;
    _requestSeq++;
    notifyListeners();
  }

  /// §4/§14/§18/§19 — (re)computes the trace against the CURRENT graph and
  /// operating context. A caller (the Trace Inspector panel) is
  /// responsible for calling this again whenever the target, mode,
  /// operating context, or topology (graph identity) actually changes —
  /// this method itself performs no debouncing or change-detection; see
  /// `TraceInspectorPanel._maybeScheduleTrace` for that (the same
  /// trigger-level pattern the DMM panel already established).
  void runTrace({
    required EngineeringGraph graph,
    required ElectricalSolver solver,
    ElectricalOperatingContext operatingContext = ElectricalOperatingContext.none,
  }) {
    final t = _target;
    if (t == null) return;
    final requestSeq = ++_requestSeq;

    SolvedElectricalState? solvedState;
    if (_mode != TraceMode.physical) {
      solvedState = solver.solve(graph, operatingContext, generationCounter: generationCounter);
    }

    final traceResult = _engine.trace(
      graph: graph,
      target: t,
      mode: _mode,
      solvedState: solvedState,
      operatingContext: operatingContext,
    );

    // §9-equivalent stale-result guard: if `setTarget`/`setMode`/`clear`
    // (or another `runTrace` call) ran while this trace was "in flight,"
    // `_requestSeq` has already moved on -- discard this now-superseded
    // answer rather than overwrite a newer one.
    if (requestSeq != _requestSeq) return;
    result = traceResult;
    lastSolvedState = solvedState;
    notifyListeners();
  }
}

/// PRODUCT-READINESS-009 §21 — scoped the same way
/// `multimeterRuntimeServiceProvider` is (gated on a live diagram
/// simulation session existing at all): a single, app-session-lived
/// controller, never a global singleton independent of whether a diagram
/// is even open. Today's Diagram Studio hosts exactly one primary
/// diagram/WebView session at a time (the same `primaryDiagramInstanceId`
/// single-instance reality PRODUCT-READINESS-008 already documented for
/// the DMM/operating-context providers) -- this provider follows that
/// same, already-established scoping rather than inventing a new one.
final traceRuntimeServiceProvider = ChangeNotifierProvider<TraceController?>((ref) {
  final simulation = ref.watch(diagramSimulationServiceProvider);
  if (simulation == null) return null;
  return TraceController();
});
