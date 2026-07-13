# Engineering Graph

Governed by SDD-024 (Engineering Graph Architecture) and SDD-027
(Engineering Graph Object Model). See `docs/ARCHITECTURE_DECISIONS.md`
ADR-002.

---

## Philosophy

The Engineering Graph is the canonical runtime representation of
engineering knowledge — it is not a diagram, and it carries no visual
layout. Diagrams (and any other View) visualize the graph; they never
replace it.

```
Foundation Repository -> Engineering Graph -> View (e.g. Diagram View)
```

## Object model (`lib/core/graph/models/`)

| Type | Contains |
|---|---|
| `EngineeringGraph` | `nodes`, `relationships`, `groups`, `metadata` |
| `EngineeringNode` | `id`, `category`, `displayName`, `symbolId`, `repositoryObjectId`, `metadata`, `evidenceLinks`, `properties`, `ports`, optional `extensionData`, transient `runtime` |
| `EngineeringRelationship` | `id`, `relationshipType`, `sourceNode`, `targetNode`, `repositoryRelationshipId`, `metadata`, `evidenceLinks`, transient `runtime` |
| `EngineeringGroup` | `id`, `kind` (circuit/harness/assembly/subsystem/module), `memberNodeIds` (references only — never duplicates nodes) |
| `Port` | `id`, `name`, `direction`, `type`, `metadata` — no position (that's Symbol/rendering data, see `SYMBOL_LIBRARY.md`) |
| `EvidenceLink` | `id`, `kind`, `sourceReference`, `locator`, `confidence` — immutable, traceable back to Source Material |
| `RuntimeMetadata` | `selected`, `visible`, `expanded`, `highlighted` — **never persisted** (excluded from `toJson()`) |

`EngineeringGraph` is an immutable value container. Every mutation
(`withNode`, `withoutNode`, `withRelationship`, `withoutRelationship`,
`withGroup`) returns a new instance — this keeps event notification and
future undo/redo straightforward. `withoutNode` cascades: it removes any
relationship referencing the deleted node and prunes it from group
membership.

## Building a graph

`GraphBuilder` is a fluent, in-memory construction API — conceptually
parallel to the reference implementation's `GraphEditor`
(`addComponent`/`connect`/`build()` chaining), reimplemented from scratch
against the SDD-027 model:

```dart
final graph = (GraphBuilder(id: 'demo')
      ..addNode(id: 'battery', category: NodeCategory.component, displayName: 'Battery', symbolId: 'battery')
      ..addNode(id: 'ground', category: NodeCategory.ground, displayName: 'Ground', symbolId: 'ground')
      ..connect('battery', 'ground', type: RelationshipType.grounds))
    .build();
```

## Querying and traversal (`lib/core/graph/algorithms/`)

`GraphQuery` is a read-only wrapper — no mutation methods — conceptually
parallel to the reference implementation's `QueryEngine`:

- `nodesByCategory`, `nodesBySymbol`, `relationshipsBetween`
- `neighborsOf`, `reachableFrom`, `findPath` (delegates to `GraphTraversal`)
- `isolatedNodes`, `membersOf(groupId)`

`GraphTraversal` provides the underlying BFS algorithms
(`neighbors`, `reachableFrom`, `findPath`, `isolatedNodes`), usable
independently of `GraphQuery` (e.g. by `NavigationService`).

## Service layer (`lib/core/graph/services/graph_service.dart`)

`GraphService` is the SDD-026 public `GraphService`: create/open/close/
save/load/query/update/validate. It delegates storage to a `GraphProvider`
and validation to a `ValidationProvider` (both resolved through
`EngineRegistry`), and emits `EngineEvent`s (`graphChanged`,
`relationshipAdded`) on every mutation.

## Persistence

`GraphService` never talks to a storage medium directly — it goes through
`GraphProvider`, which in Phase 1 is `InMemoryGraphProvider` (graphs live
in memory for the engine's lifetime) backed by `JsonFileSerializationProvider`
for `save`/`load`. Both are swappable; see `docs/ARCHITECTURE_DECISIONS.md`
ADR-004 for why no Foundation-backed provider ships yet.

## Validation

See `docs/ENGINEERING_ENGINE.md` and `ValidationService`
(`lib/core/validation/validation_service.dart`) for the deterministic
checks run against a graph: missing/unknown symbols, broken relationships,
duplicate nodes (by shared `repositoryObjectId`), duplicate ports,
floating nodes, and invalid evidence mappings. Validation never mutates
the graph it checks.
