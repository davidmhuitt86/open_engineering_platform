# Signal Propagation

**Architecture Phase:** AP-DS-005. Describes `SignalPropagator` (`oep_engine/lib/core/simulation/propagation/signal_propagator.dart`), the deterministic logical signal-propagation core of the Simulation Engine.

## What it is

A deterministic, multi-source, fault-gated breadth-first flood-fill over `EngineeringGraph`. Given a graph, a `FaultOverlay`, and a set of seed nodes, it computes the set of nodes a signal reaches — nothing more. There is exactly one traversal loop (`_propagate`), parameterized by `SignalType`; every signal type (power, ground, digital high/low, analog state, PWM state, CAN, LIN, discrete state) shares the same mechanism.

## What it is not

Not a resistive-network or Kirchhoff's-laws solve. No voltage division, no current calculation. This is a deliberate exclusion (AP-DS-005's own scope boundary) and matches what the legacy reference's own "voltage propagator" actually did despite the name — flood-fill reachability, not electrical math (`SIMULATION_REFERENCE_REVIEW.md` §What the legacy project actually is).

## Power and ground: two independent passes

`propagatePowerAndGround(graph, faults)` runs two separate BFS passes:

- **Power sources**: every node that is the source of a `RelationshipType.suppliesPower` relationship.
- **Ground sources**: every node that is the source of a `RelationshipType.grounds` relationship, OR any node whose `NodeCategory` is `ground` (a chassis-ground point is a source even with no explicit `grounds` relationship).

The two passes are never merged into a single "net" concept — `SimulationStateSnapshot.isFunctional(nodeId) == isPowered(nodeId) && isGrounded(nodeId)`. This directly retains the legacy reference's one genuinely correct architectural choice (`SIMULATION_TRACEABILITY_MATRIX.md`: `GroundPropagator` → Retain).

## Generalized signal propagation

`propagateSignal(graph, faults, type, seedNodeIds, {seedValue})` runs the same BFS from a caller-supplied seed set, carrying `seedValue` unchanged to every node reached (a flood-fill value propagation — not a per-node transformation, since this engine does no analog computation). The caller controls what counts as a source for a given signal type; the propagator does not infer seeding policy.

## What blocks propagation (`_isBlocked`)

An edge is blocked, and the flood does not cross it, when:

1. **An active open-circuit-class fault sits on the relationship itself** (`FaultOverlay.hasOpenCircuitOn(relationshipId)`).
2. **A fault sits directly on the neighbor node** — any fault type except `shortCircuit` on the target node blocks it from receiving/forwarding the signal.
3. **Behavioral gating via `RelationshipType.controls`** — if any `controls` relationship targets the neighbor node and its controlling source node currently has an active fault, the neighbor is blocked. This generalizes the legacy reference's relay-coil-gates-contacts pattern (`RelayBehavior` → Retain, per the traceability matrix): a `controls` relationship means "the target only conducts if the source is functional," not just for relays specifically.

`controls` relationships themselves never conduct a signal (they gate, they don't wire) — they're skipped as a direct propagation edge but consulted for gating.

## A disclosed scope boundary

The `controls` gating check is a single-hop check on the controller's own fault state, not a full recursive functional-chain evaluation. A controller that is itself unpowered (rather than directly faulted) is not detected by this check alone — but its own propagation pass will independently fail to reach it, and `VerificationEngine`/`DiagnosticsEngine` check that separately. This is a deliberate, disclosed boundary of the flood-fill (not resistive-network) approach, not a bug.

## Faults never mutate the graph

`FaultOverlay` is consulted during propagation but never changes `EngineeringGraph`. Clearing every fault (`FaultOverlay.clearAll()`) restores identical propagation results to a fault-free run — proven directly by `signal_propagator_verification_test.dart`'s "clearing a fault restores propagation" test. This is the direct retention of the legacy reference's one unambiguously good pattern (`FaultInjector` → Retain).

## Determinism

Given the same graph and the same fault overlay, propagation always produces the same `SimulationStateSnapshot` — no randomness, no wall-clock dependence. This is what makes `SimulationSession.recompute()` (a full re-solve at the session's current playback position) safe to call repeatedly and what makes `replay()` reproduce a scenario exactly.
