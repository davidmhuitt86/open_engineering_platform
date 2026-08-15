import '../events/platform_event.dart';

/// Where an [Operation] currently stands — mirrors [OperationEventKind]
/// minus [OperationEventKind.progressed], which updates [Operation.fraction]
/// in place rather than changing [Operation.status].
enum OperationStatus { running, completed, failed }

/// One long-running unit of work as `OperationManager` currently sees it
/// — the accumulated, queryable state built from the stream of
/// [OperationEvent]s for a single [id]. Immutable; `OperationManager`
/// replaces its map entry wholesale on every event rather than mutating
/// one in place, the same discipline every other Platform model already
/// follows.
class Operation {
  const Operation({
    required this.id,
    required this.label,
    required this.status,
    this.fraction,
  });

  final String id;
  final String label;
  final OperationStatus status;

  /// `0.0`–`1.0`, or `null` for indeterminate/not-yet-known progress.
  final double? fraction;

  Operation _copyWith({String? label, OperationStatus? status, double? fraction}) => Operation(
        id: id,
        label: label ?? this.label,
        status: status ?? this.status,
        fraction: fraction ?? this.fraction,
      );
}

extension OperationCopy on Operation {
  Operation withEvent(OperationEvent event) {
    switch (event.kind) {
      case OperationEventKind.started:
        return Operation(id: id, label: event.label, status: OperationStatus.running, fraction: event.fraction);
      case OperationEventKind.progressed:
        return _copyWith(label: event.label, fraction: event.fraction);
      case OperationEventKind.completed:
        return _copyWith(status: OperationStatus.completed, fraction: 1.0);
      case OperationEventKind.failed:
        return _copyWith(status: OperationStatus.failed);
    }
  }
}

/// Builds the [Operation] state an [OperationEvent] implies on its own,
/// with no prior [Operation] to update — used for the first event seen
/// for a given id (normally [OperationEventKind.started], but handled
/// for every kind so an out-of-order [OperationEventKind.completed]/
/// [OperationEventKind.failed] — one arriving for an id `OperationManager`
/// never saw a [OperationEventKind.started] for — still records the
/// correct terminal status rather than defaulting to "running".
Operation operationFromEvent(OperationEvent event) {
  final status = switch (event.kind) {
    OperationEventKind.started || OperationEventKind.progressed => OperationStatus.running,
    OperationEventKind.completed => OperationStatus.completed,
    OperationEventKind.failed => OperationStatus.failed,
  };
  return Operation(id: event.id, label: event.label, status: status, fraction: event.fraction);
}
