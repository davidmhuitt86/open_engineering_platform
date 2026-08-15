/**
 * editor/undo-redo.js
 *
 * Command stack for undo/redo of diagram edits.
 *
 * Phase 1 placeholder — undo/redo not yet implemented.
 *
 * Phase 2 goal: command pattern.
 *
 * Each edit creates a Command object:
 *   { execute(), undo(), label }
 *
 * Supported commands (Phase 2):
 *   MoveModuleCommand    — drag module to new position
 *   AddModuleCommand     — add new module
 *   DeleteModuleCommand  — remove module + cascade wires
 *   AddWireCommand       — create wire between terminals
 *   DeleteWireCommand    — remove wire
 *   EditWireCommand      — change wire color/label/readings
 *   NudgeSegmentCommand  — adjust wire segment offset
 *
 * Max stack depth: 50 commands.
 *
 * No rendering. No electrical logic.
 */

class UndoRedoStack {
  constructor(maxDepth = 50) {
    this.maxDepth   = maxDepth;
    this._undoStack = [];
    this._redoStack = [];
  }

  execute(cmd) {
    cmd.execute();
    this._undoStack.push(cmd);
    if (this._undoStack.length > this.maxDepth) this._undoStack.shift();
    this._redoStack = [];
  }

  undo() {
    const cmd = this._undoStack.pop();
    if (!cmd) return;
    cmd.undo();
    this._redoStack.push(cmd);
    return cmd;
  }

  redo() {
    const cmd = this._redoStack.pop();
    if (!cmd) return;
    cmd.execute();
    this._undoStack.push(cmd);
    return cmd;
  }

  canUndo() { return this._undoStack.length > 0; }
  canRedo() { return this._redoStack.length > 0; }
  clear()   { this._undoStack = []; this._redoStack = []; }
}
