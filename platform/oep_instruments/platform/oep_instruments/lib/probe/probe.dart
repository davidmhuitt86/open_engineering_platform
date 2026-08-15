import 'probe_type.dart';

/// OIP-PROBE-001 — "A probe represents a measurement endpoint. A probe
/// never performs measurements. A probe establishes where a measurement
/// is requested. Engineering computation remains the responsibility of
/// the Host" (§4). This class carries only placement/identity/state —
/// it holds no measured value itself (see [Measurement] for that).
class Probe {
  const Probe({
    required this.id,
    required this.displayName,
    required this.type,
    required this.color,
    required this.state,
    this.currentTargetId,
    this.sessionId,
  });

  final String id;
  final String displayName;
  final ProbeType type;

  /// A color identifier (e.g. `'black'`/`'red'`), matching OIP-PROBE-001
  /// §6's standard Black/Red measurement pair convention — kept as a
  /// plain string rather than a `Color` type so this pure-Dart runtime
  /// package has no Flutter UI dependency; instrument UI layers map this
  /// to an actual paint color.
  final String color;

  final ProbeState state;

  /// OIP-PROBE-001 §9 — the wire/connector/terminal/pin/... id this
  /// probe is currently attached to, or `null` if unattached.
  final String? currentTargetId;

  final String? sessionId;

  Probe copyWith({ProbeState? state, String? currentTargetId, bool clearTarget = false}) => Probe(
        id: id,
        displayName: displayName,
        type: type,
        color: color,
        state: state ?? this.state,
        currentTargetId: clearTarget ? null : (currentTargetId ?? this.currentTargetId),
        sessionId: sessionId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'type': type.name,
        'color': color,
        'state': state.name,
        if (currentTargetId != null) 'currentTargetId': currentTargetId,
        if (sessionId != null) 'sessionId': sessionId,
      };
}
