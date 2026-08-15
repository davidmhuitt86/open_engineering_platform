# Simulation Architecture

**Architecture Phase:** AP-DS-005. Describes the Engineering Verification & Simulation subsystem's structure, its place in the three-repository architecture, and the architectural boundary it enforces. Companion documents: `SIMULATION_REFERENCE_REVIEW.md` (what was learned from the legacy reference), `SIMULATION_TRACEABILITY_MATRIX.md` (per-capability decisions), `VERIFICATION_ENGINE.md`, `SIGNAL_PROPAGATION.md`, `FAULT_INJECTION.md`, `SIMULATION_USER_GUIDE.md`.

## Governing principle

> Diagram Studio remains responsible for: Visualization, User Interaction, Playback, Presentation. No engineering logic shall exist inside Diagram Studio.

Every fact about the engineering design — is this node powered, is this relationship broken, what does this fault mean, what is the root cause — is computed inside the Simulation Engine (`oep_engine`) or, for reasoning/recommendations, the Engineering Intelligence Platform (reached only via `DiagramIntelligenceService`). Diagram Studio never computes an engineering fact; it only renders facts the engine already computed, and forwards user interaction back to engine calls.

## Where the Simulation Engine lives

```
oep_engine/lib/core/simulation/
  models/
    signal_types.dart        SignalType, SignalState, SimulationStateSnapshot
    simulation_fault.dart    SimulationFaultType, SimulationFault, FaultOverlay
  propagation/
    signal_propagator.dart   SignalPropagator (deterministic BFS-flood)
  verification/
    verification_finding.dart  VerificationCheck, VerificationSeverity, VerificationFinding, VerificationReport
    verification_engine.dart   VerificationEngine
  diagnostics/
    diagnostics_models.dart  FaultReport, PropagationReport, PowerReport/GroundReport, SimulationReport
    diagnostics_engine.dart  DiagnosticsEngine
    power_distribution.dart  PowerDistributionCalculator
  session/
    simulation_event.dart    SimulationEvent, SimulationEventType
    simulation_session.dart  SimulationSession, SimulationBookmark
    simulation_compare_result.dart  SimulationCompareResult, SimulationNodeDiff
  simulation_engine.dart     SimulationEngine (top-level facade)
```

All exported from the package barrel `oep_engine/lib/simulation/simulation.dart`, reachable from `oep_studio` via `package:engineering_engine/engineering_engine.dart`, and registered in `EngineRegistry` (`registry.simulationEngine`).

This is entirely Dart, no FFI, no dependency on Foundation's native runtime — the Simulation Engine executes purely against the in-memory `EngineeringGraph`/`EngineeringNode`/`EngineeringRelationship`/`Port` model already owned by `oep_engine`.

## What the Simulation Engine is not

Per the spec's explicit exclusions, confirmed by the legacy reference review (`SIMULATION_REFERENCE_REVIEW.md`):

- **Not SPICE, not analog circuit simulation, not physics-based modeling.** There is no resistive-network solve, no Kirchhoff's-laws current calculation, no voltage division. Propagation is deterministic logical reachability (flood-fill BFS), not electrical computation — matching what the legacy reference's own "voltage propagator" actually did despite its name.
- **Not a reasoning/recommendation engine.** Ranking causes, explaining root cause with natural-language reasoning, and producing recommendations is Engineering Intelligence Platform's job (`ReasoningEngine`/`AnalysisEngine`, WP-EKE-006), consumed via `DiagramIntelligenceService`. The Simulation Engine's Diagnostics module produces facts (which node lost power, which fault blocks what, which path was taken) — never a ranked recommendation.
- **Not a second graph representation.** Execution is based exclusively on `EngineeringGraph`/`EngineeringNode`/`EngineeringRelationship` — the same model the rest of the platform uses. No parallel "simulation graph."

## The four modules

1. **Signal Propagation** (`SignalPropagator`) — deterministic, fault-gated, multi-signal-type reachability. See `SIGNAL_PROPAGATION.md`.
2. **Verification** (`VerificationEngine`) — static and state-dependent design-correctness checks (connectivity, continuity, ground, power, relationship, dependency, package, harness, connector). See `VERIFICATION_ENGINE.md`.
3. **Fault Injection** (`FaultOverlay`/`SimulationFault`, session-scoped) — faults as a pure overlay, never mutating the base graph. See `FAULT_INJECTION.md`.
4. **Diagnostics + Sessions** (`DiagnosticsEngine`, `SimulationSession`, `SimulationEngine`) — Fault/Propagation/Power/Ground/Verification/Simulation reports, deterministic playback/timeline/bookmarks/replay, session lifecycle (create/duplicate/compare/delete/export/import).

## The `SimulationEngine` facade

The single entry point Diagram Studio depends on (`oep_engine/lib/core/simulation/simulation_engine.dart`). Sessions own the fault overlay, event history, playback position, and current computed state; every mutating call (`injectFault`, `step`, `reset`, ...) appends an event and recomputes deterministically. `run`/`step` return `Future<...>` (a disclosed deviation from an earlier draft contract, made so a Studio-side caller can `await` without blocking a frame); `play` returns a `Stream<SimulationStateSnapshot>` that the caller drives with its own timer.

## Diagram Studio's role

Diagram Studio (`oep_studio/lib/diagram_studio/simulation/`) owns exactly:

- **Visualization** — overlay layer rendering power/ground/signal state, faults, warnings, propagation paths, dependencies (per `SIGNAL_PROPAGATION.md`/`FAULT_INJECTION.md`'s data, never recomputed).
- **Interaction** — fault injection UI, session management UI, all forwarding directly to `SimulationEngine` calls.
- **Playback** — play/pause/resume/reset/step/timeline/bookmarks/replay controls, reflecting `SimulationSession` state, never independently tracked.
- **Presentation** — diagnostics report display, reusing AP-DS-003's shared intelligence-panel widgets for visual consistency.

Diagram Studio's canvas/document-model architecture (frozen since AP-DS-001) is untouched — the simulation overlay is an additive layer, following the same pattern AP-DS-003's `DiagramIntelligenceOverlay` established.
