# Graph Editing

WORK_PACKAGE_021: the Engineering Engine's first interactive editing
capability. Governed by SDD-024/024A ("Views shall observe graph changes.
Views shall never own engineering state"), SDD-027/027A, and the
provider/registry architecture from ADR-001. See also `docs/UNDO_REDO.md`,
`docs/ROUTING_ENGINE.md`, `docs/SELECTION_MODEL.md`.

---

## Editing philosophy

Every mutation goes through the command system (`docs/UNDO_REDO.md`) — "No
editing operation may bypass the command system." There is no method
anywhere in the public API that mutates a graph directly outside an
`EditingCommand`. This is enforced by convention (there's no other
mutation entry point exposed), not by a runtime guard — `GraphService`'s
`addNode`/`addRelationship`/etc. from Phase 1 remain available for
non-interactive, non-undoable programmatic graph construction (seeding,
tests, importers), which is a deliberately different use case from
interactive editing.

## What's editable (ENGINE-TASK-000079/000085)

| Operation | Command |
|---|---|
| Create / delete a node | `CreateNodeCommand` / `DeleteNodeCommand` |
| Move one / many nodes | `MoveNodeCommand` / `MoveNodesCommand` |
| Duplicate a node | `DuplicateNodeCommand` |
| Create / delete a relationship | `CreateRelationshipCommand` / `DeleteRelationshipCommand` |
| Reconnect a relationship | `ReconnectRelationshipCommand` |
| Update node properties | `UpdateNodePropertiesCommand` |
| Update relationship properties | `UpdateRelationshipPropertiesCommand` |
| Update a port | `UpdatePortCommand` |
| Update an evidence link | `UpdateEvidenceLinkCommand` |
| Rename a node | `RenameNodeCommand` |
| Change a node's category | `ChangeNodeCategoryCommand` |
| Create / ungroup a group | `CreateGroupCommand` / `UngroupCommand` |
| Rename / lock a group | `RenameGroupCommand` / `SetGroupLockedCommand` |
| Batch delete (Cut, multi-select Delete) | `DeleteManyCommand` |
| Paste / duplicate a selection | `PasteCommand` / `DuplicateSelectionCommand` |

**Not editable in this work package:** `Net` and `Confidence` properties
— SDD-027A is still `Status: Proposed`. `UpdateNodePropertiesCommand`
takes a generic `Map<String, Object?>` patch, so adding them later needs
no redesign — see ARCHITECTURE_DECISIONS.md ADR-009/010 (carried over from
WORK_PACKAGE_020) and the new ADR-013 below.

## Movement is layout, not graph, data

WORK_PACKAGE_021 says "Movement updates Engineering Graph coordinates
only," but SDD-024 Architecture Rule 5 (frozen, unamended) says the graph
carries no visual layout. `MoveNodeCommand`/`MoveNodesCommand` operate on
`EditingSession.layout` (a `DiagramLayoutState`), never on
`EngineeringNode` fields. See **ARCHITECTURE_DECISIONS.md ADR-011** for
the full reasoning — this is the single most consequential design
decision in this work package, and the one most worth correcting if the
interpretation is wrong.

## Grouping (ENGINE-TASK-000082)

`EngineeringGroup` (SDD-027) gained two persisted fields — `parentGroupId`
(nesting) and `locked` — plus a `runtime: RuntimeMetadata` field, reusing
the *same* `RuntimeMetadata` type nodes/relationships already carry for
Collapse/Expand (`runtime.expanded`) and Visibility (`runtime.visible`).
Collapse/expand/visibility are deliberately **not** undoable — like
selection, they're transient view state, not engineering edits (see
`EditingService.toggleGroupExpanded`/`setGroupVisible`, which bypass
`CommandHistory` entirely). Lock **is** undoable (`SetGroupLockedCommand`)
— it's a real, persisted engineering decision, not view state.

Ungrouping removes the group but never touches member nodes; nested child
groups are reparented to the removed group's own parent so the rest of
the tree keeps its shape (`UngroupCommand`).

## Clipboard (ENGINE-TASK-000083)

`ClipboardService` orchestrates Copy/Cut/Paste/Duplicate/Clone, but only
Copy is not a command (copying doesn't mutate the graph). Cut and
Paste/Duplicate return `EditingCommand`s for the caller to run through
`EditingService.execute` — `ClipboardService` never executes a command
itself, so there's exactly one place (`EditingService`) responsible for
undo/redo history. A `ClipboardEntry` carries node/relationship/group
data *and* their layout positions (layout lives outside the graph, so it
has to be captured explicitly or a paste would have nowhere sensible to
land). Pasting generates fresh ids for everything and remaps every
relationship/group-membership reference accordingly; a relationship is
only carried over if both its endpoints were in the copied selection
("preserve relationships where possible").

## View synchronization (ENGINE-TASK-000087)

The Demonstration Host subscribes once to `EditingService.sessionChanges`
and rebuilds on every emission — no per-action manual graph rewriting
(Phase 1's pattern). `DiagramView.render` now accepts the live
`DiagramLayoutState`, the current `GraphSelection`, and highlighted-id
sets directly, rather than requiring the graph's own
`runtime.selected`/`highlighted` flags to be kept in sync by hand.
Selection and Navigation keep their own existing streams from Phase 1
(SDD-026) — nothing about "Views observe the graph" required merging
every stream into one; it required removing the *manual* synchronization
Phase 1 had, which is done.

## Scope notes

- "Alignment Preview" is grid-snap-preview only (a live snapped ghost
  position while dragging) — no smart alignment-to-other-elements guides.
  The reference implementation never had this feature either
  (`EKE_FEATURE_INVENTORY.md`), so there's no behavior to preserve beyond
  what's implemented.
- Relationship reconnection (`ReconnectRelationshipCommand`) has no
  dedicated drag-to-reconnect UI in the Demonstration Host — it's fully
  implemented and unit-tested, but exposing an endpoint-dragging
  interaction was judged lower priority than the rest of this work
  package's scope. Flagged as a near-term Demonstration Host follow-up,
  not an engine gap.
