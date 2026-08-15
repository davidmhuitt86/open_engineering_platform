# Verification Engine

**Architecture Phase:** AP-DS-005. Describes `VerificationEngine` (`oep_engine/lib/core/simulation/verification/verification_engine.dart`), the Simulation Engine's static and state-dependent design-correctness checker.

## What it is

`VerificationEngine.runAll(graph, {state})` runs a fixed set of checks against an `EngineeringGraph`, optionally combined with a computed `SimulationStateSnapshot`, and returns a `VerificationReport`: a flat list of `VerificationFinding`s, each with a `VerificationCheck` (which kind of check produced it), a `VerificationSeverity` (`info`/`warning`/`error`), a human-readable message, and the node/relationship it concerns.

Verification is independent of simulation execution — the structural checks (connectivity, relationship, harness/connector, package) run on graph structure alone, with no `SimulationStateSnapshot` required. This directly retains the legacy reference's one cleanly-separated concern: "verify the design is sound" kept distinct from "simulate its behavior" (`SIMULATION_TRACEABILITY_MATRIX.md`: `GraphValidators` → Retain, reimplemented).

## Severity is ordinal, not decimal

`VerificationSeverity` is exactly `{info, warning, error}`. This is a deliberate rejection of the legacy reference's pattern of presenting hand-tuned decimal "confidence" literals (`0.9`/`0.8`/`0.85`/`0.5`, no derivation given) as if they were calibrated probabilities (`SIMULATION_REFERENCE_REVIEW.md` §Concepts Rejected). Findings here are ranked ordinally (error > warning > info) and never claim invented precision.

## The checks

| Check | Requires `state`? | What it detects |
|---|---|---|
| Connectivity | No | Isolated nodes (no relationships at all) and disconnected sub-circuits (islands beyond the largest, via `GraphTraversal.reachableFrom`/`isolatedNodes`) |
| Relationship | No | Dangling source/target references, self-loop relationships |
| Harness | No | Harness-category nodes with no Contains/PartOf membership |
| Connector | No | Connector-category nodes with no declared ports, or ports never referenced by any relationship's `sourcePort`/`targetPort` metadata |
| Package | No | Nodes with a non-null but empty `repositoryObjectId` |
| Power | Yes | Nodes targeted by a `suppliesPower` relationship but not reachable from any power source under current fault conditions |
| Ground | Yes | Nodes targeted by a `grounds` relationship (or expecting one) but not reachable from any ground source |
| Continuity | Yes | Nodes reached by exactly one of power/ground, not both — a distinct "partial circuit, check for an open circuit" signal |
| Dependency | Yes | Single points of failure — a functioning node whose path from *every* checked power source passes through exactly one common upstream node |

Open Circuit and Short Circuit checks (named in the governing spec's Engineering Verification list) surface as Continuity/Power/Ground findings plus `FaultReport` (Diagnostics) rather than a separate check category — an open circuit's effect is exactly "expected power/ground path broken," which the Power/Ground/Continuity checks already detect; a dedicated `openCircuit`/`shortCircuit` `VerificationCheck` enum value exists for callers that want to filter specifically by fault-caused (vs. structural) findings.

## Reuses `GraphTraversal`, never a second BFS

Connectivity and Dependency checks call `GraphTraversal.reachableFrom`/`isolatedNodes`/`findPath` — the same traversal primitives the rest of `oep_engine` already uses. No check in this file reimplements graph traversal. This is the direct fix for the legacy reference's own self-documented flaw: two independent, non-interoperating graph implementations across its two engines (`SIMULATION_TRACEABILITY_MATRIX.md`: `GraphTraversal` → Replace).

## The Dependency check fixes a real legacy bug

The legacy reference's `DependencyTracker.whatFailsIf` only checked paths from the *first* power source found, under-reporting redundancy on multi-source graphs. `VerificationEngine._dependency` checks paths from **every** power source in the graph via repeated `GraphTraversal.findPath` calls, and only flags a node as a single point of failure if exactly one non-endpoint node appears across every path from every source. Covered directly by `signal_propagator_verification_test.dart`'s "dependency verification identifies a single point of failure across all power sources" test.

## Package Verification's scope boundary

Package Verification here checks only local graph consistency (a non-empty `repositoryObjectId` where one is present) — it is explicitly not a reimplementation of Foundation's own `FoundationBridge.verifyPackage` (trust/signing verification), which remains Foundation's responsibility.

## Harness/Connector Verification's scope boundary

Scoped to what the `EngineeringGraph` itself can express — harness-category nodes and Contains/PartOf relationships, connector ports and their relationship-metadata references — not `DiagramLayoutState` layer membership, which is a Diagram Studio presentation-layer concept the Simulation Engine has no dependency on (per AP-DS-005's own "base all execution exclusively on Engineering Objects and Relationships" boundary).
