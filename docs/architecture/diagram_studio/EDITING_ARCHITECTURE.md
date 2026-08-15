# Diagram Studio — Editing Architecture

**Architecture Phase:** AP-DS-001 (superseding update from AP-DS-001A below)

> **AP-DS-001A update.** The editor-completion phase closed several items this document originally listed as debt: resize is now implemented (`ResizeNodeCommand`), the `MoveNodeCommand`/`MoveNodesCommand` duplication was resolved (the unused singular command was removed), `AlignNodesCommand`/`DistributeNodesCommand` now have real toolbar triggers, and the in-process-only clipboard gained an OS-clipboard fallback. See `oep_studio/docs/IMPLEMENTATION_STATUS.md`'s AP-DS-001A section for full detail and verification. The sections below are left as originally written (historical record of what AP-DS-001 found), with the closure noted here rather than silently rewritten.

## 1. Command architecture (the core mutation mechanism — genuinely complete)

`EditingCommand` (`oep_engine/lib/core/editing/editing_command.dart`) is an abstract base with `apply(EditingSession)`/`revert(EditingSession)`/`description`. All mutation flows through it. **33 concrete command classes** exist under `oep_engine/lib/core/editing/commands/`, and every one of them was confirmed invoked at least once from `diagram_studio_page.dart` — this is a real, exhaustive, wired command surface, not scaffolding:

`AlignNodesCommand`, `ArrayPlaceCommand`, `AssignLayerCommand`, `ChangeNodeCategoryCommand`, `CreateAnnotationCommand`, `CreateGroupCommand`, `CreateLayerCommand`, `CreateNodeCommand`, `CreateRelationshipCommand`, `DeleteAnnotationCommand`, `DeleteLayerCommand`, `DeleteManyCommand`, `DeleteNodeCommand`, `DeleteRelationshipCommand`, `DistributeNodesCommand`, `DuplicateNodeCommand`, `DuplicateSelectionCommand`, `MirrorNodesCommand`, `MoveNodesCommand`, `MoveNodeCommand`, `PasteCommand`, `ReconnectRelationshipCommand`, `RenameGroupCommand`, `RenameNodeCommand`, `ReplaceSymbolCommand`, `RotateNodesCommand`, `SetGroupLockedCommand`, `SetWireRouteCommand`, `UngroupCommand`, `UpdateAnnotationCommand`, `UpdateEvidenceLinkCommand`, `UpdateLayerCommand`, `UpdateNodePropertiesCommand`, `UpdatePortCommand`, `UpdateRelationshipPropertiesCommand`.

**Debt item, reported not fixed**: both `MoveNodesCommand` (plural) and `MoveNodeCommand` (singular) exist. Whether this is intentional (bulk vs. single-node optimized paths) or legacy duplication was not conclusively determined in this review and should be a first, cheap item in AP-DS-002.

**Debt item, reported not fixed**: `AlignNodesCommand`/`DistributeNodesCommand` exist as real command classes but no confirmed UI trigger (toolbar button, menu item, keyboard shortcut) was located wiring them in during this review's read of `diagram_toolbars.dart`/`diagram_studio_page.dart`. If genuinely unwired, this is a small, low-risk feature-completion item, not new-feature work — closing a gap between an already-built command and already-expected UI, which is within this phase's "refine, don't redesign" mandate for follow-up.

## 2. Undo/redo architecture (genuinely complete, correctly wired)

`CommandHistory` (`oep_engine/lib/core/editing/command_history.dart`): a proper dual-stack undo/redo, `maxDepth: 100`, `execute()` pushes and clears the redo stack, `undo()`/`redo()` call `command.revert()`/`.apply()`. Bound to Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z via `CallbackShortcuts`, confirmed calling `_commands!.undo()`/`.redo()` plus `_markDirty()` in `diagram_studio_page.dart`. This is a textbook, working Command-pattern undo/redo implementation — no debt found here.

## 3. Selection

See `CANVAS_ARCHITECTURE.md` §8 and `INTERACTION_MODEL.md` §2. Multi-kind (`GraphSelection`), correctly generalized across nodes/relationships/groups/annotations, real hit-testing.

## 4. Move / Rotate / Resize

- **Move**: real two-phase implementation — live drag preview via `_effectiveLayout()` (an ephemeral overlay on the committed layout), committed on drag-end via `MoveNodesCommand`. Grid snap + single-node alignment guides applied during the preview phase.
- **Rotate**: real — `RotateNodesCommand`, 90°/180°/arbitrary angle via dialog.
- **Mirror**: real — `MirrorNodesCommand`.
- **Resize**: **does not exist.** No per-node resize handle or command was found; `_nodeSize = 100` is a fixed constant. Symbol size changes only indirectly, via `ReplaceSymbolCommand` (swapping the symbol) or `ArrayPlaceCommand`.

## 5. Grouping

Real — `CreateGroupCommand`/`UngroupCommand`, backed by `EngineeringGroup.memberNodeIds`. `SetGroupLockedCommand`/`RenameGroupCommand` provide the expected supporting operations.

## 6. Alignment and distribution

Command classes exist (`AlignNodesCommand`, `DistributeNodesCommand`) — see the debt item in §1 regarding unconfirmed UI wiring.

## 7. Clipboard

Real but **in-process only**, not the OS/cross-app clipboard. `ClipboardEntry` is a plain in-memory Dart object; `ClipboardExtraction.extract(session, selection)` builds it from the live selection (filtering relationships to those with both endpoints selected). No `Clipboard.setData`/`SystemChannels.clipboard` usage was found. Copy/paste works only within the running Engine instance/session — not across separate app launches, and not into/from other applications. This is a real, user-visible limitation worth naming explicitly in the roadmap rather than leaving implicit.

## 8. Tool architecture — the one clear structural gap in this document

There is **no `Tool`/`SelectTool`/`WireTool` abstraction**. Every interaction mode (select, connect, box-select, wire-edit, reconnect, annotate) is implemented as ad hoc boolean/nullable fields directly on the 1,441-line `_DiagramStudioPageState` class (`_wireEditModeActive`, `_connectFromPort`, `_boxSelectRect`, `_reconnectRelationshipId`, etc.). Functionally, every one of these modes works correctly and is fully implemented (verified per-mode in `INTERACTION_MODEL.md` §1) — **this is not a functional gap, it is a structural one.** Extending the interaction surface today means adding more fields and branches to an already-large state class rather than implementing a pluggable interface.

This is named here as the primary refinement candidate for the "editing architecture" per the work package's own instruction to identify architectural drift and opportunities for refinement — **not** as something this phase redesigns. A future phase should evaluate whether formalizing a `Tool` interface (with `onPointerDown`/`onPointerMove`/`onPointerUp`/`onKeyEvent` hooks and a `currentTool` field replacing the scattered booleans) is worth the migration cost, given every existing mode already works correctly under the current approach.

## 9. Summary

Editing is the most mature part of Diagram Studio: command pattern, undo/redo, selection, and nearly every direct-manipulation operation are genuinely complete, correctly wired, and require no rework. The two real gaps are structural (no Tool abstraction) and functional-but-narrow (no resize, in-process-only clipboard, two possibly-unwired alignment commands, a possible duplicate move-command pair) — all bounded, all named, none requiring architectural redesign to close.
