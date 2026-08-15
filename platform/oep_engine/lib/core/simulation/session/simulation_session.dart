import '../../graph/models/engineering_graph.dart';
import '../models/signal_types.dart';
import '../models/simulation_fault.dart';
import '../propagation/signal_propagator.dart';
import '../state/operating_state.dart';
import '../state/state_condition_resolver.dart';
import 'simulation_event.dart';

/// The reserved [SimulationEvent.conditionKey] this session uses for
/// operating-state changes (see [SimulationSession.setOperatingState]).
/// Input-state changes use `'input:<inputId>'` (see [setInputState]) --
/// both reuse the existing, already-deterministic-replay-aware
/// `conditionChanged` event (Phase 9 Part 24: "use the existing event
/// architecture where appropriate") rather than adding new
/// [SimulationEventType] values for what is, structurally, the same
/// "a named condition changed" fact `conditionChanged`'s own doc
/// comment already anticipates ("e.g. an ignition state change").
const String _operatingStateConditionKey = 'operatingState';
const String _inputStateConditionKeyPrefix = 'input:';

/// A named position in a session's event timeline.
class SimulationBookmark {
  const SimulationBookmark({required this.label, required this.position, required this.createdAt});

  final String label;

  /// Playback position (index into the event history, 0 = before any
  /// event has been applied) this bookmark points at.
  final int position;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {'label': label, 'position': position, 'createdAt': createdAt.toIso8601String()};

  factory SimulationBookmark.fromJson(Map<String, Object?> json) => SimulationBookmark(
        label: json['label'] as String,
        position: json['position'] as int,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// AP-DS-005 Simulation Session — owns an id, name, fault overlay, event
/// history, current playback position, bookmarks, and the current
/// computed [SimulationStateSnapshot].
///
/// **Deterministic execution**: [recompute] is the single, clearly-named
/// method that performs a FULL re-solve from the graph + the fault overlay
/// active at [playbackPosition] (never an incremental patch) — a
/// deliberate, disclosed scope boundary per
/// `SIMULATION_TRACEABILITY_MATRIX.md`'s "full re-solve is acceptable, but
/// the seam for incremental updates later should exist" guidance. Given
/// the same graph + the same ordered event history + the same playback
/// position, [recompute] always produces bit-identical results — no
/// randomness, no wall-clock dependence in the computed result itself.
///
/// Faults are derived from replaying [history] up to [playbackPosition],
/// not stored as separate mutable state — this is what makes
/// [reset]/[replay]/[jumpToBookmark] all trivially correct: they just move
/// `playbackPosition` and call [recompute].
class SimulationSession {
  SimulationSession({
    required this.id,
    required this.name,
    required this.graph,
    List<SimulationEvent>? history,
    int playbackPosition = 0,
    List<SimulationBookmark>? bookmarks,
    SignalPropagator propagator = const SignalPropagator(),
    List<OperatingStateDefinition> availableOperatingStates = const [],
    List<InputStateDefinition> availableInputStates = const [],
  })  : _history = history ?? [],
        _playbackPosition = playbackPosition,
        _bookmarks = bookmarks ?? [],
        _propagator = propagator,
        availableOperatingStates = List.unmodifiable(availableOperatingStates),
        availableInputStates = List.unmodifiable(availableInputStates) {
    _state = recompute();
  }

  final String id;
  String name;

  /// The operating states this session's engineering system can be
  /// placed in, e.g. a caller-supplied "Vehicle Operating Profile"
  /// (Part 10) -- empty by default. This engine defines no states of
  /// its own; it only provides the framework the caller's domain data
  /// populates (Part 4/10). Runtime-only for this phase (Part 21) --
  /// not read from or written to the graph/.oep package.
  final List<OperatingStateDefinition> availableOperatingStates;

  /// The individual control/input signals this session's engineering
  /// system exposes (Part 7/8) -- empty by default, same runtime-only
  /// scope as [availableOperatingStates].
  final List<InputStateDefinition> availableInputStates;

  /// The graph this session simulates against. Never mutated by this
  /// session (SDD-024: no layout/session state lives on the graph itself).
  final EngineeringGraph graph;

  final SignalPropagator _propagator;

  final List<SimulationEvent> _history;
  int _playbackPosition;
  final List<SimulationBookmark> _bookmarks;
  late SimulationStateSnapshot _state;

  /// Paused is a playback-mode flag only — it does not affect [recompute]
  /// (the computed result is a pure function of graph + history position
  /// regardless of pause state); it exists so a Studio-side auto-`play`
  /// driver knows whether to keep stepping.
  bool _paused = false;

  List<SimulationEvent> get history => List.unmodifiable(_history);
  int get playbackPosition => _playbackPosition;
  List<SimulationBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  SimulationStateSnapshot get state => _state;
  bool get isPaused => _paused;

  /// The fault overlay active AT THE CURRENT PLAYBACK POSITION — derived by
  /// replaying faultInjected/faultCleared/allFaultsCleared events from the
  /// start of [history] up to [playbackPosition]. Never stored directly, so
  /// it can never drift out of sync with the timeline.
  FaultOverlay get activeFaults => _faultsAt(_playbackPosition);

  FaultOverlay _faultsAt(int position) {
    final overlay = FaultOverlay();
    for (var i = 0; i < position && i < _history.length; i++) {
      final event = _history[i];
      switch (event.type) {
        case SimulationEventType.faultInjected:
          if (event.fault != null) overlay.inject(event.fault!);
          break;
        case SimulationEventType.faultCleared:
          if (event.fault != null) overlay.clear(event.fault!.id);
          break;
        case SimulationEventType.allFaultsCleared:
          overlay.clearAll();
          break;
        case SimulationEventType.stepExecuted:
        case SimulationEventType.conditionChanged:
        case SimulationEventType.sessionCreated:
          break;
      }
    }
    return overlay;
  }

  /// The active operating state's id AT THE CURRENT PLAYBACK POSITION --
  /// derived the same way [activeFaults] is: by replaying
  /// `conditionChanged` events (keyed [_operatingStateConditionKey]) up
  /// to [playbackPosition] and taking the latest value. `null` before
  /// any [setOperatingState] call has been made (or after [reset]) --
  /// the honest "no operating state selected yet" default, never a
  /// fabricated implicit state. Never stored as separate mutable
  /// state, so it can never drift out of sync with the timeline (Part
  /// 26: one authoritative runtime state, no page-local cache).
  String? get activeOperatingStateId => _conditionsAt(_playbackPosition)[_operatingStateConditionKey] as String?;

  /// The active input states AT THE CURRENT PLAYBACK POSITION, keyed by
  /// input id -- derived identically to [activeOperatingStateId], one
  /// entry per distinct `input:<id>` condition key that has been set.
  Map<String, Object?> get activeInputStates {
    final conditions = _conditionsAt(_playbackPosition);
    final result = <String, Object?>{};
    for (final entry in conditions.entries) {
      if (entry.key.startsWith(_inputStateConditionKeyPrefix)) {
        result[entry.key.substring(_inputStateConditionKeyPrefix.length)] = entry.value;
      }
    }
    return result;
  }

  /// Replays every `conditionChanged` event up to [position], keeping
  /// only the latest value recorded for each condition key -- the same
  /// "replay history to derive current derived state" pattern
  /// [_faultsAt] already establishes for faults.
  Map<String, Object?> _conditionsAt(int position) {
    final conditions = <String, Object?>{};
    for (var i = 0; i < position && i < _history.length; i++) {
      final event = _history[i];
      if (event.type == SimulationEventType.conditionChanged && event.conditionKey != null) {
        conditions[event.conditionKey!] = event.conditionValue;
      }
    }
    return conditions;
  }

  /// The relationship ids currently blocked by real input state (Phase 10),
  /// derived the same way [activeOperatingStateId]/[activeInputStates] are
  /// -- always fresh from [availableInputStates] + [activeInputStates],
  /// never cached. Exposed so callers that need to gate a computation by
  /// the SAME condition [recompute] itself uses -- e.g.
  /// [SimulationEngine.measure], which cannot go through [recompute]/[state]
  /// because it computes a different, probe-specific
  /// [SignalPropagator.propagateSignal] pass -- do not have to
  /// re-derive it themselves.
  Set<String> get blockedRelationshipIds =>
      const StateConditionResolver().resolveBlockedRelationshipIds(graph, availableInputStates, activeInputStates);

  /// Sets the active operating state. `stateId` must match an id in
  /// [availableOperatingStates] when that list is non-empty (real
  /// validation against the caller's own domain data); when the list is
  /// empty (no domain profile has been supplied yet), any id is
  /// accepted -- there is nothing yet to validate against.
  void setOperatingState(String stateId) {
    if (availableOperatingStates.isNotEmpty && !availableOperatingStates.any((s) => s.id == stateId)) {
      throw ArgumentError.value(stateId, 'stateId', 'Not one of this session\'s availableOperatingStates.');
    }
    changeCondition(_operatingStateConditionKey, stateId);
  }

  /// Sets a single input's value. `inputId` is validated the same way
  /// [setOperatingState] validates `stateId`.
  void setInputState(String inputId, Object? value) {
    if (availableInputStates.isNotEmpty && !availableInputStates.any((s) => s.id == inputId)) {
      throw ArgumentError.value(inputId, 'inputId', 'Not one of this session\'s availableInputStates.');
    }
    changeCondition('$_inputStateConditionKeyPrefix$inputId', value);
  }

  /// The single, clearly-named full-recompute seam (see class doc). A
  /// future incremental-update optimization is a contained change: replace
  /// this method's body, keep the same signature and call sites.
  SimulationStateSnapshot recompute() {
    _state = _propagator.propagatePowerAndGround(graph, activeFaults, blockedRelationshipIds: blockedRelationshipIds);
    return _state;
  }

  void _append(SimulationEvent event) {
    // Any new event truncates redo-style forward history beyond the
    // current playback position (matching standard undo/timeline
    // semantics) before appending, then advances playback to the end.
    if (_playbackPosition < _history.length) {
      _history.removeRange(_playbackPosition, _history.length);
    }
    _history.add(event);
    _playbackPosition = _history.length;
    recompute();
  }

  void injectFault(SimulationFault fault) {
    _append(SimulationEvent(type: SimulationEventType.faultInjected, timestamp: DateTime.now(), fault: fault));
  }

  void clearFault(String faultId) {
    final resolved = activeFaults.active.where((f) => f.id == faultId).toList();
    _append(SimulationEvent(
      type: SimulationEventType.faultCleared,
      timestamp: DateTime.now(),
      fault: resolved.isNotEmpty ? resolved.first : null,
    ));
  }

  void restoreNormal() {
    _append(SimulationEvent(type: SimulationEventType.allFaultsCleared, timestamp: DateTime.now()));
  }

  void changeCondition(String key, Object? value) {
    _append(SimulationEvent(
      type: SimulationEventType.conditionChanged,
      timestamp: DateTime.now(),
      conditionKey: key,
      conditionValue: value,
    ));
  }

  /// Step Execution — advances playback by one recorded event (does not
  /// create a new event; use for replaying/scrubbing forward through
  /// existing history). If already at the end and there is nothing to
  /// step through, records a no-op `stepExecuted` marker event so the
  /// timeline shows an explicit step occurred (e.g. "advance simulation
  /// clock with no state change"), then advances past it.
  void step() {
    if (_playbackPosition < _history.length) {
      _playbackPosition++;
    } else {
      _history.add(SimulationEvent(type: SimulationEventType.stepExecuted, timestamp: DateTime.now()));
      _playbackPosition = _history.length;
    }
    recompute();
  }

  void pause() => _paused = true;

  void resume() => _paused = false;

  /// Reset — returns playback to position 0 (no faults, no events
  /// applied) without discarding the recorded history, so [replay] can
  /// step back through it.
  void reset() {
    _playbackPosition = 0;
    _paused = false;
    recompute();
  }

  void addBookmark(String label) {
    _bookmarks.add(SimulationBookmark(label: label, position: _playbackPosition, createdAt: DateTime.now()));
  }

  void jumpToBookmark(String label) {
    final bookmark = _bookmarks.lastWhere((b) => b.label == label, orElse: () => throw StateError('No bookmark named "$label"'));
    _playbackPosition = bookmark.position;
    recompute();
  }

  /// Replay — re-runs the event history from the start (or from a named
  /// bookmark) to reproduce a scenario deterministically. Since state is
  /// always derived by full recompute at the target position (never
  /// incrementally patched), this is equivalent to, and implemented as, a
  /// single jump to that position.
  void replay({String? fromBookmark}) {
    if (fromBookmark != null) {
      jumpToBookmark(fromBookmark);
      return;
    }
    _playbackPosition = _history.length;
    recompute();
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'graphId': graph.id,
        'history': _history.map((e) => e.toJson()).toList(),
        'playbackPosition': _playbackPosition,
        'bookmarks': _bookmarks.map((b) => b.toJson()).toList(),
        'paused': _paused,
        'availableOperatingStates': availableOperatingStates.map((s) => s.toJson()).toList(),
        'availableInputStates': availableInputStates.map((s) => s.toJson()).toList(),
      };

  /// Rebuilds a session's non-graph state (history/position/bookmarks)
  /// from an export produced by [toJson] against [graph] (the caller
  /// supplies the graph — sessions never serialize the graph itself, per
  /// this engine's "operate exclusively on EngineeringGraph, never a
  /// parallel model" constraint).
  factory SimulationSession.fromJson(Map<String, Object?> json, EngineeringGraph graph) {
    final session = SimulationSession(
      id: json['id'] as String,
      name: json['name'] as String,
      graph: graph,
      history: (json['history'] as List? ?? const [])
          .map((e) => SimulationEvent.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      playbackPosition: json['playbackPosition'] as int? ?? 0,
      bookmarks: (json['bookmarks'] as List? ?? const [])
          .map((b) => SimulationBookmark.fromJson(Map<String, Object?>.from(b as Map)))
          .toList(),
      availableOperatingStates: (json['availableOperatingStates'] as List? ?? const [])
          .map((s) => OperatingStateDefinition.fromJson(Map<String, Object?>.from(s as Map)))
          .toList(),
      availableInputStates: (json['availableInputStates'] as List? ?? const [])
          .map((s) => InputStateDefinition.fromJson(Map<String, Object?>.from(s as Map)))
          .toList(),
    );
    if (json['paused'] == true) session.pause();
    return session;
  }
}
