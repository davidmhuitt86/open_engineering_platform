import 'instrument_lifecycle_state.dart';

/// OIP-LIFECYCLE-001 §19 — validates every lifecycle transition rather
/// than trusting callers, mirroring [InstrumentOperationalStateMachine]'s
/// own discipline. §19's own named illegal-transition examples (`ready
/// -> destroyed` without unloading, `notInstalled -> connected`,
/// `shutdown` [operational] `-> measuring` without initialization) are
/// exactly the class of mistake this table prevents by construction —
/// nothing outside this class can set [current] directly.
class InstrumentLifecycleStateMachine {
  InstrumentLifecycleStateMachine({InstrumentLifecycleState initial = InstrumentLifecycleState.notInstalled})
      : _current = initial;

  InstrumentLifecycleState _current;
  InstrumentLifecycleState? _previous;
  DateTime? _transitionTime;

  InstrumentLifecycleState get current => _current;
  InstrumentLifecycleState? get previous => _previous;
  DateTime? get transitionTime => _transitionTime;

  /// Built directly from OIP-LIFECYCLE-001 §4's ordered state list, plus
  /// the explicit "returns to Installed if the plugin remains available"
  /// note in §16 (Destroyed) and "may Disconnect/Reconnect/Resume without
  /// restarting its lifecycle" note in §20 (a Connected/Active/Paused
  /// instrument can cycle back to Disconnected and, on reconnect, back
  /// to Connected without re-walking Loaded/Initializing).
  static const Map<InstrumentLifecycleState, Set<InstrumentLifecycleState>> _legalTransitions = {
    InstrumentLifecycleState.notInstalled: {InstrumentLifecycleState.installed},
    InstrumentLifecycleState.installed: {InstrumentLifecycleState.discovered},
    InstrumentLifecycleState.discovered: {InstrumentLifecycleState.loaded},
    InstrumentLifecycleState.loaded: {InstrumentLifecycleState.initializing, InstrumentLifecycleState.unloaded},
    InstrumentLifecycleState.initializing: {InstrumentLifecycleState.ready, InstrumentLifecycleState.unloaded},
    InstrumentLifecycleState.ready: {InstrumentLifecycleState.connected, InstrumentLifecycleState.unloaded},
    InstrumentLifecycleState.connected: {
      InstrumentLifecycleState.active,
      InstrumentLifecycleState.disconnected,
      InstrumentLifecycleState.unloaded,
    },
    InstrumentLifecycleState.active: {
      InstrumentLifecycleState.paused,
      InstrumentLifecycleState.disconnected,
      InstrumentLifecycleState.unloaded,
    },
    InstrumentLifecycleState.paused: {
      InstrumentLifecycleState.active,
      InstrumentLifecycleState.disconnected,
      InstrumentLifecycleState.unloaded,
    },
    InstrumentLifecycleState.disconnected: {
      InstrumentLifecycleState.connected, // reconnect, per §20
      InstrumentLifecycleState.unloaded,
    },
    InstrumentLifecycleState.unloaded: {InstrumentLifecycleState.destroyed},
    InstrumentLifecycleState.destroyed: {
      InstrumentLifecycleState.installed, // §16: returns to Installed if the plugin remains available
    },
  };

  bool canTransitionTo(InstrumentLifecycleState next) =>
      _legalTransitions[_current]?.contains(next) ?? false;

  void transitionTo(InstrumentLifecycleState next) {
    if (!canTransitionTo(next)) {
      throw StateError('Illegal lifecycle state transition: $_current -> $next.');
    }
    _previous = _current;
    _current = next;
    _transitionTime = DateTime.now();
  }
}
