/**
 * editor/selection-manager.js
 *
 * Owns wire and module selection state.
 * Coordinates card highlight classes, panel open/close, and lead placement.
 *
 * Reads from: MODULES, WIRES, cardEls globals.
 * Writes to:  selW, selM, leadR, leadB, tracedWires globals.
 */

function selWire(w, evt) {
  if (editMode || wireMode) return;
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
