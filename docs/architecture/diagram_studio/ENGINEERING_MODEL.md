# Diagram Studio — Engineering Model

**Architecture Phase:** AP-DS-001 (superseded by AP-DS-002 below for §1-2's core claims)

> **AP-DS-003 update.** §3's finding that Engineering Intelligence Platform integration "does not exist" is now superseded — it exists, via `DiagramIntelligenceService` (see `ENGINEERING_WORKSPACE.md` for the full account). This does not relitigate this document's original architectural analysis (which correctly predicted the integration point Studio would need); it records that the integration named as future work is now built.

> **AP-DS-002 update.** §1's "Verified conclusion: no entity type currently creates, references, or synchronizes with a real Foundation `EngineeringObject`" and §2's description of `FoundationBridgePort` as the unimplemented resolution mechanism are both superseded. Real Foundation persistence now exists via `DiagramRepositoryService`, NOT via `FoundationBridgePort` (that interface — see §2 below — remains unimplemented and has zero consumers; it was not the mechanism AP-DS-002 ultimately used, since Studio's own `FoundationBridge` FFI layer was the more direct, already-proven path). See `ENGINEERING_MAPPING.md` for the complete, current mapping — every node now genuinely becomes a Foundation `EngineeringObject`, every wire a `Relationship`, per the design that resolves this document's own original tension between "everything has engineering meaning" and Foundation's fixed-field schema. §3's Engineering Intelligence Platform integration finding remains accurate and unchanged — AP-DS-002 explicitly excluded EIP integration (deferred to AP-DS-003). §4's Simulation finding also remains accurate and unchanged. Sections below are left as originally written, describing the pre-AP-DS-002 state accurately as history.

## 1. Entity type inventory (verified against `EngineeringNode`'s `NodeCategory` enum and related types)

| Entity | Engineering meaning | Backing Engineering Object? |
|---|---|---|
| `component` | Generic engineering component | No — local graph only |
| `connector` | Electrical/physical connector | No |
| `wire` | Electrical conductor | No |
| `circuit` | Logical circuit grouping | No |
| `harness` | Wire harness | No |
| `module` | Functional module | No |
| `relay` | Relay | No |
| `fuse` | Fuse/protection device | No |
| `switchNode` | Switch | No |
| `ground` | Ground reference | No |
| `sensor` | Sensor | No |
| `actuator` | Actuator | No |
| `measurementPoint` | Measurement/test point | No |
| `procedure` | Referenced engineering procedure | No |
| `specification` | Referenced engineering specification | No |
| `unknown` | Fallback | No |
| `EngineeringRelationship` (e.g. `connectedTo`) | Physical/logical connection between two nodes | No |
| `EngineeringGroup` | Logical grouping of nodes (`GroupKind.other`, etc.) | No |
| `Port` / `PortReference` | Connection endpoint on a node | No |
| `EvidenceLink` | Reference to supporting evidence | No |
| `DiagramAnnotation` | Text/callout label | N/A — deliberately graphics-only, by design (see Constitution §3.2) |
| `DiagramLayer` | Intra-diagram z-order/visibility group | N/A — deliberately a view-layer construct |

**Verified conclusion: no entity type currently creates, references, or synchronizes with a real Foundation `EngineeringObject` or `Relationship`.** Every node/relationship/group/annotation is created purely through `engine.editing.execute(CreateNodeCommand(...))` (and equivalents) against the in-memory `InMemoryGraphProvider`-backed `EngineeringGraph`. No path in `_addNode`, `_addAnnotation`, `_groupSelection`, or any command constructor calls the Foundation C API or `FoundationBridge` service. `EngineeringNode.repositoryObjectId` exists and is always `null`.

This is a **direct contradiction of the work package's own stated principle** ("no graphics-only entities — everything shall have engineering meaning") **at the persistence layer**, even though it is fully honored at the *type-system* layer (every node has a real `NodeCategory`, drawn from real engineering vocabulary, not an arbitrary shape enum). The distinction matters: Diagram Studio's entities are engineering-*typed*, but not engineering-*backed*. This document records that distinction precisely rather than glossing over it, because closing this gap is the single highest-priority item for the next Architecture Phase.

## 2. The Foundation Bridge (the mechanism that would close the gap — currently unimplemented)

`FoundationBridgePort` (`oep_engine/lib/core/bridge/foundation_bridge_port.dart`) is an abstract interface reserved for exactly this purpose. Its own doc comment states plainly: *"No implementation exists yet — and none is provided in Phase 1... Nothing in Phase 1 constructs or calls it."* The barrel file `lib/bridge/bridge.dart` corroborates: *"Public surface for the (not-yet-implemented) Foundation Bridge integration... See ADR-004 for why no implementation ships in Phase 1."*

This is architecturally significant and positive, not merely a gap: the *interface* was designed with real engineering discipline (an ADR exists explaining the deferral), meaning the eventual bridge implementation has a clear contract to fulfill rather than needing to be designed from scratch. AP-DS-002 (or whichever phase tackles this) should locate and read ADR-004 before beginning bridge work.

## 3. Engineering Intelligence Platform integration

**Does not exist.** Grep across both packages found zero functional cross-references between `lib/diagram_studio/`/`oep_engine` and `lib/engineering_intelligence/` (the EIP consumer built in WP-EKE-008). The one hit found was an incidental doc-comment sentence in an unrelated file, not an integration point.

Concretely, none of the following exist today:
- **Validation**: Diagram Studio has its own local `DiagramValidationPanel` and `oep_engine/core/validation/` — this validates the *local graph* (structural graph checks), not anything through `ValidationEngine`/`EngineeringIntelligencePlatform`. Do not conflate the two "validation" systems when reading other documentation — they are unrelated implementations with the same name.
- **Analysis / Reasoning / Recommendations**: no calls into `AnalysisEngine`/`ReasoningEngine`/`EngineeringIntelligencePlatform` exist anywhere in Diagram Studio.
- **Knowledge Sessions**: no session creation/consumption from Diagram Studio.

**Per the work package's own "No bypasses" rule**, this is not a violation today (there is nothing to bypass — there is no connection at all), but it does mean Diagram Studio currently cannot deliver on the "Engineering Intelligence" section of its own governing spec. This is named explicitly, not implied, as future-phase scope in `IMPLEMENTATION_ROADMAP.md`.

## 4. Simulation

`NoOpSimulationProvider` (`oep_engine/lib/core/simulation/no_op_simulation_provider.dart`) is a self-documented placeholder: *"a placeholder — see WORK_PACKAGE_019 Phase 1 scope."* Subdirectories exist for electrical/hydraulic/mechanical/pneumatic simulation but contain no working implementation reachable from Diagram Studio today. Simulation integration is Not Started, honestly reflected as such.

## 5. Summary

Diagram Studio's engineering *vocabulary* is real and well-formed — every node type maps to a genuine, named engineering concept, and the command/type system enforces this consistently. What is missing is the *connection* of that vocabulary to the rest of the platform: no Foundation persistence, no Engineering Intelligence Platform consumption, no simulation. This is the correct, honest characterization of "engineering model" for Phase 1: **typed but disconnected.**
