import 'dart:async';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../simulation/diagram_simulation_service.dart';
import '../bookmarks/measurement_bookmark.dart';
import '../bookmarks/measurement_bookmark_store.dart';
import '../history/measurement_history_entry.dart';
import '../history/measurement_history_store.dart';

/// Measurement types the real [MeasurementEngine] does not yet compute
/// (the spec's own "Future placeholders" for the Digital Multimeter) —
/// the mode selector shows these but disables "Measure" for them.
const Set<MeasurementType> unsupportedMeasurementTypes = {
  MeasurementType.capacitance,
  MeasurementType.temperature,
};

/// WP-DS-005A Digital Multimeter — owns probe placement, the selected
/// measurement type/mode, the live [MeasurementResult], history, and
/// bookmarks. Zero engineering computation lives here: every reading
/// comes from [DiagramSimulationService.measure], which is itself a thin
/// pass-through to the real `SimulationEngine`/`MeasurementEngine`
/// (`oep_engine`). This class only orchestrates *when* to ask and *how*
/// to display what comes back — matching the governing spec's
/// "Architectural Principles" section verbatim.
///
/// **Performance** (spec "Instrument updates shall remain asynchronous"):
/// every measurement, including each tick of Live Simulation mode, goes
/// through `DiagramSimulationService.measure` which returns a `Future` —
/// there is no synchronous engine call anywhere in this controller, live
/// mode included, so this was async from the first line written, not
/// retrofitted.
class MultimeterController extends ChangeNotifier {
  MultimeterController({required DiagramSimulationService simulationService})
      : _simulationService = simulationService;

  final DiagramSimulationService _simulationService;

  ProbePoint? probeA;
  ProbePoint? probeB;

  MeasurementType selectedType = MeasurementType.voltageDc;
  MeasurementMode selectedMode = MeasurementMode.manual;

  MeasurementResult? latestResult;

  /// Set only in [MeasurementMode.historical]: the history entry the
  /// live/manual result is being compared against.
  String? historicalCompareEntryId;

  bool get isLiveMode => selectedMode == MeasurementMode.liveSimulation;
  bool _liveActive = false;
  bool get liveActive => _liveActive;
  Timer? _liveTimer;

  bool busy = false;
  String? lastError;

  List<MeasurementHistoryEntry> history = [];
  List<MeasurementBookmark> bookmarks = [];

  /// The engineering path of the most recent reachable result — fed
  /// straight into `SimulationStateOverlay.propagationPathNodeIds` by the
  /// host page for Continuity Mode path highlighting (WP-DS-005A
  /// "Continuity Mode": "Automatically highlight the measured path").
  Set<String> get highlightedPathNodeIds => latestResult == null ? const {} : latestResult!.path.toSet();

  bool _disposed = false;

  Future<void> loadPersisted() async {
    final loadedHistory = await MeasurementHistoryStore.load();
    final loadedBookmarks = await MeasurementBookmarkStore.load();
    // OEP Context & Capability Service -- Phase 2: this controller is
    // now shared/longer-lived (`multimeterRuntimeServiceProvider`)
    // rather than always torn down promptly with the page that created
    // it. `loadPersisted`'s two `await`s can now finish after whatever
    // held this controller has already disposed it (confirmed by a
    // real test failure: "A MultimeterController was used after being
    // disposed" from exactly this `notifyListeners()` call) --
    // guarding here is a real robustness fix this promotion exposed,
    // not a pre-existing bug in the page-owned-lifetime world where
    // disposal essentially never raced this load.
    if (_disposed) return;
    history = loadedHistory;
    bookmarks = loadedBookmarks;
    notifyListeners();
  }

  void setProbeA(ProbePoint? point) {
    probeA = point;
    notifyListeners();
  }

  void setProbeB(ProbePoint? point) {
    probeB = point;
    notifyListeners();
  }

  void setType(MeasurementType type) {
    selectedType = type;
    notifyListeners();
  }

  void setMode(MeasurementMode mode) {
    selectedMode = mode;
    if (mode != MeasurementMode.liveSimulation) stopLive();
    notifyListeners();
  }

  bool get canMeasure =>
      probeA != null && probeB != null && !unsupportedMeasurementTypes.contains(selectedType) && !busy;

  /// Takes one reading (Manual / Expected / Comparison / Historical modes
  /// all funnel through this — they differ only in which
  /// [MeasurementMode] is passed to the engine and how the result is
  /// displayed/diffed afterward, per the spec's own "difference is just
  /// reading `MeasurementResult.difference`" shape).
  Future<void> measure() async {
    final a = probeA;
    final b = probeB;
    if (a == null || b == null) return;
    if (unsupportedMeasurementTypes.contains(selectedType)) {
      lastError = '${selectedType.name} is not yet supported by the Simulation Engine.';
      notifyListeners();
      return;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final effectiveMode = selectedMode == MeasurementMode.historical ? MeasurementMode.manual : selectedMode;
      final result = await _simulationService.measure(
        probeA: a,
        probeB: b,
        type: selectedType,
        mode: effectiveMode,
      );
      latestResult = result;
      _recordHistory(result);
    } on StateError catch (e) {
      lastError = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _recordHistory(MeasurementResult result) {
    final entry = MeasurementHistoryEntry(id: '${DateTime.now().microsecondsSinceEpoch}', result: result);
    history = [entry, ...history];
    unawaited(MeasurementHistoryStore.save(history));
  }

  // ---- Live Simulation mode (WP-DS-005A "Live Simulation") --------------

  void startLive({Duration interval = const Duration(milliseconds: 500)}) {
    if (selectedMode != MeasurementMode.liveSimulation || _liveActive) return;
    _liveActive = true;
    notifyListeners();
    _liveTimer = Timer.periodic(interval, (_) => unawaited(measure()));
  }

  void stopLive() {
    _liveTimer?.cancel();
    _liveTimer = null;
    if (_liveActive) {
      _liveActive = false;
      notifyListeners();
    }
  }

  // ---- Historical comparison (WP-DS-005A "Historical comparison") -------

  /// The stored entry currently selected for historical comparison, or
  /// `null`.
  MeasurementHistoryEntry? get historicalCompareEntry {
    final id = historicalCompareEntryId;
    if (id == null) return null;
    for (final entry in history) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  void setHistoricalCompareEntry(String? entryId) {
    historicalCompareEntryId = entryId;
    notifyListeners();
  }

  /// Difference between the current [latestResult] and the selected
  /// historical entry's measured value — `null` if either is missing or
  /// non-numeric. This is read-only local comparison (no new engine call,
  /// no engineering computation): the spec's "Historical comparison"
  /// scoped to comparing *against a stored history entry*, which is what
  /// this does.
  num? get historicalDifference {
    final current = latestResult?.measuredValue;
    final stored = historicalCompareEntry?.result.measuredValue;
    if (current == null || stored == null) return null;
    return current - stored;
  }

  // ---- History management (WP-DS-005A "Measurement History") -----------

  Future<void> clearHistory() async {
    history = [];
    await MeasurementHistoryStore.save(history);
    notifyListeners();
  }

  /// Replays a history entry — sets it as the active result and restores
  /// its probe placement/type/mode, without issuing a new engine call
  /// (spec: "Replay" of a stored result, not a re-measure).
  void replay(MeasurementHistoryEntry entry) {
    latestResult = entry.result;
    probeA = entry.result.probeA;
    probeB = entry.result.probeB;
    selectedType = entry.result.type;
    notifyListeners();
  }

  String exportHistoryJson() => MeasurementHistoryStore.exportJson(history);

  // ---- Bookmarks (WP-DS-005A "Measurement Bookmarks") --------------------

  Future<void> addBookmark(String name, {String group = 'Ungrouped'}) async {
    final a = probeA;
    final b = probeB;
    if (a == null || b == null) return;
    final bookmark = MeasurementBookmark(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      group: group,
      probeA: a,
      probeB: b,
      type: selectedType,
    );
    bookmarks = [...bookmarks, bookmark];
    await MeasurementBookmarkStore.save(bookmarks);
    notifyListeners();
  }

  Future<void> removeBookmark(String id) async {
    bookmarks = bookmarks.where((b) => b.id != id).toList();
    await MeasurementBookmarkStore.save(bookmarks);
    notifyListeners();
  }

  /// Quick recall — restores probe placement/type from a bookmark.
  void recallBookmark(MeasurementBookmark bookmark) {
    probeA = bookmark.probeA;
    probeB = bookmark.probeB;
    selectedType = bookmark.type;
    notifyListeners();
  }

  // ---- Engineering Integration (WP-DS-005A "Engineering Integration") ---

  /// Light-touch integration with Verification: findings whose `nodeId`
  /// lies on the current result's engineering path. Read-only — this
  /// controller never recomputes verification, it only filters a
  /// [VerificationReport] the host page already obtained from
  /// `DiagramSimulationService.verify()`. This is the "result can
  /// reference a VerificationReport finding" slice of the spec's broader
  /// "Diagnostics / Reasoning / Recommendations / Publishing / Reports"
  /// integration list — the rest is deferred (see IMPLEMENTATION_STATUS.md).
  List<VerificationFinding> relatedFindings(VerificationReport? report) {
    final result = latestResult;
    if (result == null || report == null) return const [];
    final pathIds = result.path.toSet()..addAll([result.probeA.nodeId, result.probeB.nodeId]);
    return [
      for (final finding in report.findings)
        if (finding.nodeId != null && pathIds.contains(finding.nodeId)) finding,
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    _liveTimer?.cancel();
    super.dispose();
  }
}

/// The Context & Capability Service's Phase 2 extraction (Part 1/Part
/// 3): promotes what was previously a page-private instance
/// (`DiagramStudioPage._multimeter`, constructed once in `initState`)
/// into one shared, authoritative provider. Same constructor call
/// (`MultimeterController(simulationService: ...)`), same
/// `loadPersisted()` call the page always made right after
/// construction -- just reachable outside `DiagramStudioPage` now.
///
/// **Deliberately NOT `.autoDispose`**: `DiagramStudioPage` only ever
/// `ref.read`s this provider (see that page's own doc comment on why
/// -- it must not `ref.watch` and rebuild the whole page on every
/// measurement), and a plain `ref.read` creates no keep-alive
/// subscription. An `.autoDispose` provider with no watcher would be
/// torn down (or never even cached) between reads, silently producing
/// a fresh `MultimeterController` -- and losing probe/history state --
/// on every access, exactly the "two divergent runtime instances"
/// outcome this phase must prevent. Living for the app's session,
/// exactly like `engineeringProjectServiceProvider` itself already
/// does ("outlives any single route"), is what makes one authoritative
/// instance possible.
final multimeterRuntimeServiceProvider = ChangeNotifierProvider<MultimeterController?>((ref) {
  final simulation = ref.watch(diagramSimulationServiceProvider);
  if (simulation == null) return null;
  final controller = MultimeterController(simulationService: simulation);
  unawaited(controller.loadPersisted());
  return controller;
});
