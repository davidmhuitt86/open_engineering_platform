import '../models/simulation_fault.dart';

/// AP-DS-005 session event taxonomy — one entry per action taken within a
/// [SimulationSession]. The event HISTORY is the source of truth for
/// deterministic replay: given the same graph + the same ordered event
/// list, recomputing state at any playback position always yields the
/// identical `SimulationStateSnapshot` (no randomness, no wall-clock
/// dependence in the computation itself — `timestamp` is bookkeeping only).
enum SimulationEventType {
  faultInjected,
  faultCleared,
  allFaultsCleared,
  stepExecuted,
  conditionChanged,
  sessionCreated,
}

class SimulationEvent {
  const SimulationEvent({
    required this.type,
    required this.timestamp,
    this.fault,
    this.conditionKey,
    this.conditionValue,
    this.label = '',
  });

  final SimulationEventType type;
  final DateTime timestamp;

  /// Present for [SimulationEventType.faultInjected]/[faultCleared] (the
  /// fault injected, or the fault as it was immediately before being
  /// cleared -- kept so replay can re-derive the exact overlay state at
  /// any position without needing the session's current overlay).
  final SimulationFault? fault;

  /// Present for [SimulationEventType.conditionChanged] (e.g. an ignition
  /// state change "key-off -> on -> cranking", modeled as a named
  /// condition rather than a new event type per condition, since the set
  /// of conditions is graph/domain-specific, not fixed by this engine).
  final String? conditionKey;
  final Object? conditionValue;

  final String label;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        if (fault != null) 'fault': fault!.toJson(),
        if (conditionKey != null) 'conditionKey': conditionKey,
        if (conditionValue != null) 'conditionValue': conditionValue,
        'label': label,
      };

  factory SimulationEvent.fromJson(Map<String, Object?> json) {
    return SimulationEvent(
      type: SimulationEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SimulationEventType.stepExecuted,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      fault: json['fault'] == null ? null : SimulationFault.fromJson(Map<String, Object?>.from(json['fault'] as Map)),
      conditionKey: json['conditionKey'] as String?,
      conditionValue: json['conditionValue'],
      label: json['label'] as String? ?? '',
    );
  }
}
