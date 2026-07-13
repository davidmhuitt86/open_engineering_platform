# Undo / Redo

WORK_PACKAGE_021, ENGINE-TASK-000084: "Implement deterministic command
history... Undo/Redo shall operate on Engineering Graph mutations." See
also `docs/GRAPH_EDITING.md`.

---

## The command model

```dart
abstract class EditingCommand {
  String get description;
  EditingSession apply(EditingSession session);
  EditingSession revert(EditingSession session);
}
```

Pure and side-effect-free, mirroring the immutable, copy-on-write style
`EngineeringGraph` already used in Phase 1 — `apply`/`revert` return a
*new* `EditingSession`, never mutate the one they're given. A command
instance is single-use: it captures whatever state it needs to precisely
reverse itself the first time `apply` runs (e.g. `DeleteNodeCommand`
snapshots the removed node, its relationships, and the *entire*
`graph.groups` map before deleting — because deleting a node also strips
it from every surviving group's membership list, not just groups that get
deleted outright; reverting has to restore that too, or undo would be
subtly wrong).

## `EditingSession`

```dart
class EditingSession {
  final EngineeringGraph graph;
  final DiagramLayoutState layout;
}
```

The unit every command operates on. Bundling `graph` and `layout`
together means one command history covers both graph edits (create/
delete/property changes) and layout edits (move) without blurring the
two — `graph` never carries position (see `docs/GRAPH_EDITING.md` /
ARCHITECTURE_DECISIONS.md ADR-011).

## `CommandHistory`

Two stacks (undo/redo), a bounded depth (default 100), and three
operations:

- `execute(command, session)` — applies the command, pushes it onto the
  undo stack, **clears the redo stack** (the standard rule: doing
  something new after an undo discards the redone-away future).
- `undo(session)` — pops the undo stack, calls `revert`, pushes onto redo.
- `redo(session)` — pops the redo stack, calls `apply`, pushes onto undo.

## `EditingService`

The object a host actually talks to. Wraps `CommandHistory` plus the live
`EditingSession`, and exposes `execute`/`undo`/`redo`/`canUndo`/`canRedo`
plus `Stream<EditingSession> sessionChanges` — the single subscription
Views observe to satisfy "no manual refreshes" (ENGINE-TASK-000087; see
`docs/GRAPH_EDITING.md`).

## What's deliberately outside undo/redo

Selection changes are never commands — ENGINE-TASK-000084's own history
list (Create/Delete/Move/Property Change/Relationship/Grouping/Clipboard)
never mentions selection, and `SelectionService` never touches
`CommandHistory`. The same reasoning extends to group collapse/expand/
visibility (`EditingService.toggleGroupExpanded`/`setGroupVisible`) —
transient view state, not an engineering edit, exactly like selection.
Group **lock** is the one exception that *is* undoable
(`SetGroupLockedCommand`) — it's a real, persisted engineering decision,
not view state, so it belongs in history.

## What the reference implementation got wrong here (and this corrects)

`EKE_INTERACTION_MODEL.md` documents that the reference sketched a
complete, correctly-designed `UndoRedoStack` (Command pattern, max depth
50) — and then never wired it up. No edit action anywhere in that
codebase ever creates a command or pushes to that stack; every edit is an
immediate, irreversible global-state mutation. This work package is the
first place in either codebase where the Command pattern is actually
connected to every editing operation, not just sketched.
