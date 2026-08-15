# Fault Injection

**Architecture Phase:** AP-DS-005. Describes the fault model (`oep_engine/lib/core/simulation/models/simulation_fault.dart`) and how faults integrate with sessions (`SimulationSession`) and propagation (`SignalPropagator`).

## The fault-as-overlay pattern

A fault never mutates `EngineeringGraph`. It is tracked in a `FaultOverlay` — a keyed collection of `SimulationFault`s — consulted by `SignalPropagator` during traversal, never applied to the graph's own nodes/relationships. This is a direct, deliberate retention of the single cleanest pattern found in the legacy reference (`SIMULATION_TRACEABILITY_MATRIX.md`: `FaultInjector` → Retain): the base design stays pristine, and a fault scenario is trivially resettable — clearing the overlay restores identical behavior to a fault-free run (proven by `signal_propagator_verification_test.dart`).

## `SimulationFaultType`

Ten fault types, matching the governing spec's own Fault Injection list exactly:

`openCircuit`, `shortCircuit`, `disconnectedConnector`, `brokenWire`, `incorrectWire`, `missingGround`, `missingPower`, `relayFailure`, `fuseFailure`, `connectorFailure`.

This taxonomy is retained as vocabulary from the legacy reference's own `FailureModes` catalog (open/short-to-ground/short-to-power/high-resistance/bad-ground/blown-fuse/corrosion/failed-relay/failed-sensor) — a reasonable, real-world-grounded set, reimplemented as a single Dart enum rather than the legacy project's two coexisting, differently-shaped fault representations (`SIMULATION_TRACEABILITY_MATRIX.md`: `EKEFault` → Reject — "exactly the kind of inconsistency a fresh design must avoid by having one fault representation, not two").

## `SimulationFault`

```dart
class SimulationFault {
  final String id;
  final SimulationFaultType type;
  final String targetId;       // node id, or relationship id if isRelationship
  final String? targetPortId;
  final bool isRelationship;
  final DateTime injectedAt;
  final String? label;
}
```

A fault targets either a node or a relationship (`isRelationship` distinguishes them) — e.g. `openCircuit`/`brokenWire`/`incorrectWire` typically target a relationship (a wire), while `relayFailure`/`fuseFailure`/`missingGround`/`missingPower`/`connectorFailure` typically target a node (a component).

## `FaultOverlay`

A collection type: `inject(fault)`, `clear(faultId)`, `clearAll()`, `active` (the current fault list), `isEmpty`, `faultsFor(id)`, `hasOpenCircuitOn(relationshipId)`, `hasShortOn(relationshipId)`. `SignalPropagator._isBlocked` consults `hasOpenCircuitOn` and `faultsFor` directly — this is the entire integration surface between the fault model and propagation.

## How faults integrate with sessions

`SimulationSession` does not store a mutable `FaultOverlay` field directly. Instead, `injectFault`/`clearFault`/`restoreNormal` each append a `SimulationEvent` (`faultInjected`/`faultCleared`/`allFaultsCleared`) to the session's event history, and `SimulationSession.activeFaults` is derived on read by replaying every fault-related event from the start of history up to the current playback position:

```dart
FaultOverlay get activeFaults => _faultsAt(_playbackPosition);
```

This means the active fault set can never drift out of sync with the timeline — `reset()`, `jumpToBookmark()`, and `replay()` are all correct for free, since they only move `playbackPosition` and call `recompute()`, which re-derives faults from history at that position. See `SIMULATION_ARCHITECTURE.md` and the session model in `simulation_session.dart` for the full playback model.

## Diagram Studio's role

Diagram Studio's Fault Injection UI (`oep_studio/lib/diagram_studio/simulation/`) lets a user pick a target (node or relationship on the canvas, or from a list) and a `SimulationFaultType`, then calls `SimulationEngine.injectFault(sessionId, fault)`. It never decides what a fault *means* — it only presents the vocabulary above and forwards the call. Clearing/restoring works the same way through `clearFault`/`restoreNormal`.
