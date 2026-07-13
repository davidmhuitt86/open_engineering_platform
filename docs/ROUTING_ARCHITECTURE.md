# Routing Architecture (WORK_PACKAGE_022 additions)

WORK_PACKAGE_022, ENGINE-TASK-000094: "Routing Improvements" — Shared
Trunks, corner cleanup for both axes, and an explicit determinism
contract. This document covers what changed; `docs/ROUTING_ENGINE.md`
(WORK_PACKAGE_021) remains the base description of `RoutingProvider`,
`OrthogonalRoutingProvider`, and the port-snapping scoping decision — it
is unchanged and not superseded.

---

## The determinism contract (now explicit on the interface)

> Given identical Engineering Graph, Diagram Layout, and routing
> configuration, identical routing output shall always be produced.

This applies to `RoutingProvider` as an interface — every current and
future implementation, not just `OrthogonalRoutingProvider` — and is now
documented directly on `lib/core/interfaces/routing_provider.dart` so it
travels with the contract, not just this work package's notes.

Two things make it true in practice:

1. **`route()` itself is a pure function** of its `RoutingRequest` and the
   caller-supplied `RoutingContext` — no wall-clock, no randomness, no
   static mutable state anywhere outside that context.
2. **`DiagramView.render` sorts relationships by `id`** before routing
   them, rather than iterating `graph.relationships.values` in raw `Map`
   insertion order. Dart's `Map` doesn't guarantee iteration order is
   stable across equivalent-but-differently-constructed graphs (e.g. two
   graphs with the same relationships added in a different sequence), so
   without this sort, otherwise-identical graphs could route differently
   purely by insertion-order accident — a real determinism leak that has
   nothing to do with the routing algorithm itself. Sorting by `id`
   closes it.

Verified directly: `test/views/routing_test.dart` asserts that calling
`OrthogonalRoutingProvider.route()` twice with the same request and two
independently-constructed `RoutingContext`s produces identical output, and
that `DiagramView().render()` called twice on the same unchanged
graph/layout produces byte-identical wire point lists.

## Corner cleanup for both axes

WORK_PACKAGE_021's shortcut only recognized a direct 2-point line when
source and target shared a **row** (`sameRow`). WORK_PACKAGE_022 adds the
symmetric **column** check (`sameColumn`) — two anchors that are already
vertically aligned now also get a clean 2-point line instead of an
unnecessary 4-point dogleg through a corner column that happens to sit at
the same x as both endpoints.

```dart
final sameRow = (source.dy - target.dy).abs() < 0.5;
final sameColumn = (source.dx - target.dx).abs() < 0.5;
if (sameRow || sameColumn) return [source, target];
```

## Shared Trunks

When several relationships share a source node (a component fanning out
to multiple downstream nodes), routing each independently through
`RoutingContext.allocateColumn` gives each its own offset lane — visually
correct but busier than necessary, and more prone to crossings than a
harness-style trunk look.

`RoutingRequest.trunkKey` (new, optional) lets `DiagramView` mark which
requests should share a column: it passes `relationship.sourceNode` as
the trunk key for every relationship. `RoutingContext.allocateTrunkColumn`
allocates a column for the first request bearing a given key (via the
ordinary `allocateColumn`, so it still doesn't collide with unrelated
wires) and **memoizes** that column for every subsequent request sharing
the key, instead of giving each an independently-offset lane:

```dart
double allocateTrunkColumn(String trunkKey, double preferredX) {
  return _trunkColumns.putIfAbsent(trunkKey, () => allocateColumn(preferredX));
}
```

`OrthogonalRoutingProvider.route` uses `allocateTrunkColumn` whenever
`request.trunkKey != null`, falling back to plain `allocateColumn`
otherwise — existing callers that never set `trunkKey` see no behavior
change. Determinism holds for shared trunks the same way it holds for
individual columns: `RoutingContext` is stateful only within one `render`
pass, created fresh each time.

## Still a replaceable provider — no interface break

None of the above required a breaking change to `RoutingProvider`,
`RoutingContext`, or `EngineRegistry`. `RoutingRequest.trunkKey` is an
additive, optional field; a routing provider that ignores it entirely
(e.g. a future curved-routing implementation with a different crossing-
reduction strategy) remains a fully valid, swappable `RoutingProvider`
per ADR-008/ADR-012. This is the third work package in a row confirming
the provider/registry architecture absorbs new requirements without
structural strain.

## Verification

`test/views/routing_test.dart` (extended this work package): direct line
when already vertical, shared `trunkKey` requests landing on the same
column, distinct `trunkKey`s not sharing a column, `route()` determinism
across fresh contexts, `DiagramView.render()` determinism across repeated
calls, and relationships sharing a source node sharing a routing trunk
column end-to-end through `DiagramView`.
