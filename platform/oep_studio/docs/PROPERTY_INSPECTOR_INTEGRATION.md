# Property Inspector Integration

WORK_PACKAGE_024, ENGINE-TASK-000110.

## The problem

`PropertyInspectorPanel` (`lib/shared/widgets/property_inspector_panel.dart`)
is one global widget, docked at the `StudioShell` level, driven by a
tuple `switch` over `FoundationServiceState`'s mutually-exclusive
`selected*` fields — eleven of them before this work package, all
Knowledge-Studio/Foundation-object flavored (`selectedObject`,
`selectedRelationship`, `selectedCandidate`, ...).

Diagram Studio needs the same shared inspector to show whichever
Engineering node/relationship/group/port/layer/annotation/wire-override
is currently selected on its canvas. But Selection is explicitly
Engine-owned (WORK_PACKAGE_024's ownership model: "Engineering Engine —
... Selection ..."), and the Engineering Engine already has a complete,
tested `SelectionProvider`/`GraphSelection`/`FocusState` system
(WORK_PACKAGE_021). Adding seven new hardcoded `selected*` fields —
mirroring the Knowledge Studio pattern once per Engineering object kind
— would mean Studio silently reimplementing Selection state a second
time, in direct conflict with "No engineering behavior shall migrate
into Studio."

## The resolution: one field, one sum type

`FoundationServiceState` gains exactly **one** new field:

```dart
final EngineeringInspectable? selectedEngineeringInspectable;
```

`EngineeringInspectable` (`lib/core/models/engineering_inspectable.dart`)
is a small sum-type value: an `EngineeringInspectableKind` enum plus
exactly one non-null typed payload per kind (`node`, `relationship`,
`group`, `port` + `portOwnerNodeId`, `layer`, `annotation`,
`wireOverrideRelationshipId` + `wireOverridePoints`). It carries
**display data only** — a snapshot of whichever Engine object is
selected, not a live reference into Engine state.

`FoundationRuntimeNotifier` gets two new methods, following the exact
same `clearSelected*`-sibling-fields pattern every other selection kind
already uses:

```dart
void selectEngineeringInspectable(EngineeringInspectable inspectable) { ... }
void clearEngineeringInspectableSelection() { ... }
```

`selectEngineeringInspectable` sets the new field and clears every
other selection field (mutual exclusivity, same as `selectObject`,
`selectCandidate`, etc.); `clearEngineeringInspectableSelection` clears
only this one field.

## Who calls it

`DiagramStudioPage._syncPropertyInspectorSelection()` listens to
`engine.registry.selection.changes` (the Engine's own stream — Studio
never polls or duplicates it) and, whenever exactly one item is
selected, resolves it against the current `EditingSession.graph`/
`.layout` and calls `selectEngineeringInspectable(...)` with the
matching `EngineeringInspectable`. Any other selection shape (nothing
selected, or more than one item) clears the field instead — the shared
inspector shows "No Object Selected" rather than guessing which of
several selected items to display, exactly like the existing
Object/Relationship modes already behave for multi-selection.

Layer selection (from the Layer panel, which isn't part of
`GraphSelection` at all) calls `selectEngineeringInspectable` directly
with `EngineeringInspectable.layer(...)`.

`DiagramStudioPage.dispose()` calls
`clearEngineeringInspectableSelection()` so navigating away from
Diagram Studio doesn't leave a stale Engineering selection showing in
the Property Inspector for whichever workspace opens next.

## The Panel side: one more tuple case

`PropertyInspectorPanel`'s tuple `switch` gained a twelfth position
(`selectedEngineeringInspectable`), placed immediately before
`knowledgeSession` (the existing fallback case) since Diagram Studio's
own selection should take priority over Knowledge Studio's
session-level fallback, matching the existing ordering intent ("Session
mode is shown only as a fallback"). Its case dispatches to a private
static helper, `_engineeringInspectableProperties`, which switches on
`EngineeringInspectableKind` and returns one of seven new widgets under
`lib/diagram_studio/inspector/`:

`EngineeringNodeProperties`, `EngineeringRelationshipProperties`,
`EngineeringGroupProperties`, `EngineeringPortProperties`,
`DiagramLayerProperties`, `DiagramAnnotationProperties`,
`WireOverrideProperties`.

Each is a `PropertyField`-based `StatelessWidget`, styled and shaped
exactly like the existing `_ObjectProperties`/`_RelationshipProperties`
private widgets in the same file — display-only, no editing (property
editing goes through Diagram Studio's own toolbar/canvas actions, which
execute Engine Commands, never through this panel — the same rule every
other Property Inspector mode already follows: "no editing here").

## Known display-quality gap

`EngineeringRelationshipProperties` receives `sourceNodeName`/
`targetNodeName` — but `_engineeringInspectableProperties` is a static
helper with no `EngineeringGraph` reference, so today it passes the raw
`sourceNode`/`targetNode` id strings rather than resolved display names.
Resolving this would mean either threading the graph through the
dispatch helper or having `EngineeringInspectable.relationship` itself
carry pre-resolved names at construction time (where
`DiagramStudioPage` does have graph access) — left as a follow-up
rather than complicating the sum type for a cosmetic improvement.
