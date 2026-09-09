/**
 * editor/selection-manager.js
 *
 * Owns wire and module selection state.
 * Coordinates card highlight classes, panel open/close, and lead placement.
 *
 * Reads from: MODULES, WIRES, cardEls globals.
 * Writes to:  selW, selM, leadR, leadB, tracedWires globals.
 */

// AP-MASTER-EDIT-001 — used to also refuse while `editMode` was on, back
// when Layout Edit mode was ONLY ever about dragging modules and wires
// were simply untouchable/uninspectable there. Per direct request, Edit
// Mode is now the one merged mode that covers module reposition, wire
// route editing, AND clicking to inspect either — so a wire click has to
// actually work while it's on. `wireMode` alone is excluded here still:
// clicking a wire in Wire mode means something else entirely (insert a
// splice on it via handleWireClickOnExistingWire, wire-editor.js), never
// "select this wire."
function selWire(w, evt) {
  if (wireMode) return;
  const same = selW && selW.id === w.id;
  selW = same ? null : w;
  document.querySelectorAll('.mod-card').forEach(c => c.classList.remove('wire-selected'));
  if (selW) {
    const fc = cardEls[w.from.m], tc = cardEls[w.to.m];
    if (fc) fc.classList.add('wire-selected');
    if (tc) tc.classList.add('wire-selected');
    autoPlaceLeads(selW);
    showPanel(w, evt);
  } else {
    closePanel();
    leadR = null; leadB = null;
    clearLeadDots();
    tracedWires.clear();
    stopFlowAnim();
  }
  drawWires();
}
