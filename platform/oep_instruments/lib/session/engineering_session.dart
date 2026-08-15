import 'engineering_session_state.dart';

/// OIP-SESSION-001 — "the authoritative runtime context for
/// communication, synchronization, measurement state, playback state,
/// instrument configuration, and client coordination" (§1). One Host
/// owns a Session (§8); many Clients/Instruments may join (§9/§10).
///
/// This class owns SESSION identity and participant bookkeeping only —
/// no engineering computation (§4: "No engineering calculations."). The
/// actual measurement/simulation/fault state a session synchronizes
/// (§11) is produced by the Host and merely referenced here, not
/// computed.
class EngineeringSession {
  EngineeringSession({
    required this.id,
    required this.hostId,
    required this.owner,
    DateTime? createdAt,
    this.projectId,
    this.diagramId,
    this.simulationId,
    this.playbackId,
    EngineeringSessionState state = EngineeringSessionState.created,
  })  : createdAt = createdAt ?? DateTime.now(),
        _state = state {
    _lastActivity = this.createdAt;
  }

  final String id;
  final String hostId;
  final String owner;
  final DateTime createdAt;
  late DateTime _lastActivity;

  final String? projectId;
  final String? diagramId;
  final String? simulationId;
  final String? playbackId;

  EngineeringSessionState _state;
  EngineeringSessionState get state => _state;

  DateTime get lastActivity => _lastActivity;

  final Set<String> _connectedClientIds = {};
  final Set<String> _connectedInstrumentIds = {};

  List<String> get connectedClientIds => List.unmodifiable(_connectedClientIds);
  List<String> get connectedInstrumentIds => List.unmodifiable(_connectedInstrumentIds);

  /// OIP-SESSION-001 §5 — the only legal state transitions. Kept small
  /// and inline (rather than a separate state-machine class like the two
  /// instrument state machines) since a Session's own lifecycle is
  /// linear with just two branch points (paused<->resumed), not a graph
  /// worth a dedicated table.
  static const Map<EngineeringSessionState, Set<EngineeringSessionState>> _legalTransitions = {
    EngineeringSessionState.created: {EngineeringSessionState.authenticated, EngineeringSessionState.destroyed},
    EngineeringSessionState.authenticated: {EngineeringSessionState.initialized, EngineeringSessionState.destroyed},
    EngineeringSessionState.initialized: {EngineeringSessionState.running, EngineeringSessionState.destroyed},
    EngineeringSessionState.running: {
      EngineeringSessionState.paused,
      EngineeringSessionState.completed,
      EngineeringSessionState.destroyed,
    },
    EngineeringSessionState.paused: {EngineeringSessionState.resumed, EngineeringSessionState.destroyed},
    EngineeringSessionState.resumed: {
      EngineeringSessionState.running,
      EngineeringSessionState.paused,
      EngineeringSessionState.completed,
      EngineeringSessionState.destroyed,
    },
    EngineeringSessionState.completed: {EngineeringSessionState.archived, EngineeringSessionState.destroyed},
    EngineeringSessionState.archived: {EngineeringSessionState.destroyed},
    EngineeringSessionState.destroyed: {},
  };

  void transitionTo(EngineeringSessionState next) {
    if (!(_legalTransitions[_state]?.contains(next) ?? false)) {
      throw StateError('Illegal session state transition: $_state -> $next.');
    }
    _state = next;
    _touch();
  }

  /// OIP-SESSION-001 §9 — "Clients may freely disconnect without
  /// terminating the Session."
  void addClient(String clientId) {
    _connectedClientIds.add(clientId);
    _touch();
  }

  void removeClient(String clientId) {
    _connectedClientIds.remove(clientId);
    _touch();
  }

  /// OIP-SESSION-001 §10 — a Session may contain many instrument
  /// instances, including several of the same type.
  void addInstrument(String instrumentId) {
    _connectedInstrumentIds.add(instrumentId);
    _touch();
  }

  void removeInstrument(String instrumentId) {
    _connectedInstrumentIds.remove(instrumentId);
    _touch();
  }

  void _touch() => _lastActivity = DateTime.now();
}
