import 'instrument_operational_state.dart';

/// OIP-STATE-001 §15/§19 — the deterministic finite state machine
/// governing one instrument's operational behavior. "At any moment an
/// instrument occupies one and only one operational state... Undefined
/// transitions are prohibited" (§2). This class is the single place that
/// enumerates every legal transition; nothing in this package changes
/// [current] except through [transitionTo], which enforces that table.
class InstrumentOperationalStateMachine {
  InstrumentOperationalStateMachine({InstrumentOperationalState initial = InstrumentOperationalState.idle})
      : _current = initial;

  InstrumentOperationalState _current;
  InstrumentOperationalState? _previous;
  DateTime? _transitionTime;

  InstrumentOperationalState get current => _current;
  InstrumentOperationalState? get previous => _previous;
  DateTime? get transitionTime => _transitionTime;

  /// The legal transition table, built directly from OIP-STATE-001 §15's
  /// worked examples plus every state's own documented entry/exit
  /// meaning (§5-§14). Deliberately conservative — a transition not
  /// listed here is illegal by default (§19), matching the spec's own
  /// "Only documented transitions are permitted."
  static const Map<InstrumentOperationalState, Set<InstrumentOperationalState>> _legalTransitions = {
    InstrumentOperationalState.idle: {
      InstrumentOperationalState.waiting,
      InstrumentOperationalState.measuring,
      InstrumentOperationalState.shutdown,
      InstrumentOperationalState.fault,
    },
    InstrumentOperationalState.waiting: {
      InstrumentOperationalState.measuring,
      InstrumentOperationalState.idle,
      InstrumentOperationalState.shutdown,
      InstrumentOperationalState.fault,
    },
    InstrumentOperationalState.measuring: {
      InstrumentOperationalState.holding,
      InstrumentOperationalState.recording,
      InstrumentOperationalState.waiting,
      InstrumentOperationalState.idle,
      InstrumentOperationalState.shutdown,
      InstrumentOperationalState.fault,
    },
    InstrumentOperationalState.holding: {
      InstrumentOperationalState.measuring,
      InstrumentOperationalState.shutdown,
      InstrumentOperationalState.fault,
    },
    InstrumentOperationalState.recording: {
      InstrumentOperationalState.playback,
      InstrumentOperationalState.measuring,
      InstrumentOperationalState.paused,
      InstrumentOperationalState.shutdown,
      InstrumentOperationalState.fault,
    },
    InstrumentOperationalState.playback: {
      InstrumentOperationalState.paused,
      InstrumentOperationalState.idle,
      InstrumentOperationalState.shutdown,
      InstrumentOperationalState.fault,
    },
    InstrumentOperationalState.paused: {
      InstrumentOperationalState.playback,
      InstrumentOperationalState.recording,
      InstrumentOperationalState.measuring,
      InstrumentOperationalState.idle,
      InstrumentOperationalState.shutdown,
      InstrumentOperationalState.fault,
    },
    InstrumentOperationalState.fault: {
      InstrumentOperationalState.recovering,
      InstrumentOperationalState.shutdown,
    },
    InstrumentOperationalState.recovering: {
      InstrumentOperationalState.idle,
      InstrumentOperationalState.fault,
      InstrumentOperationalState.shutdown,
    },
    InstrumentOperationalState.shutdown: {},
  };

  bool canTransitionTo(InstrumentOperationalState next) =>
      _legalTransitions[_current]?.contains(next) ?? false;

  /// Attempts the transition; throws [StateError] on an illegal one
  /// rather than silently ignoring it or corrupting [current] (§19:
  /// "Illegal transitions shall be rejected.").
  void transitionTo(InstrumentOperationalState next) {
    if (!canTransitionTo(next)) {
      throw StateError('Illegal operational state transition: $_current -> $next.');
    }
    _previous = _current;
    _current = next;
    _transitionTime = DateTime.now();
  }
}
