/**
 * editor/routing-editor.js
 *
 * Route-edit mode: select wire segments, nudge with arrow keys, reset routes.
 *
 * Reads/writes: routeEditMode, selSeg, wireRoutes, selW globals.
 * Calls: drawWires, showToast, toggleEdit, cancelWireMode.
 *
 * No electrical calculations. No rendering geometry.
 */

function toggleRouteEditMode() {
  if (!selW) { showToast('Select a wire first', 'warn'); return; }
  routeEditMode = !routeEditMode;
  selSeg = null;
  const btn = $('route-edit-btn');
  if (btn) { btn.classList.toggle('route-on', routeEditMode); btn.textContent = routeEditMode ? '↔ Done Routing' : '↔ Edit Route'; }
  if (routeEditMode) {
    if (editMode) toggleEdit();
    if (wireMode) cancelWireMode();
    $('wep').classList.add('open');
    $('wep-status').textContent = 'Click any wire to route it · ↑↓←→ nudge · R reset route';
    const cancelBtn = $('wep-cancel');
    if (cancelBtn) cancelBtn.textContent = '✓ Done';
    vp.classList.add('route-edit-mode');
  } else {
    exitRouteEditMode();
  }
  drawWires();
}

function exitRouteEditMode() {
  routeEditMode = false; selSeg = null;
  const btn = $('route-edit-btn');
  if (btn) { btn.classList.remove('route-on'); btn.textContent = '↔ Edit Route'; }
  $('wep').classList.remove('open');
  const cancelBtn = $('wep-cancel');
  if (cancelBtn) cancelBtn.textContent = 'Cancel (Esc)';
  vp.classList.remove('route-edit-mode');
  drawWires();
}

// The `#wep` bottom-center panel is shared between Wire mode and Route
// Edit mode; its own Cancel/Done button must dispatch to whichever mode
// is actually active rather than always assuming Wire mode. Finishing a
// route edit ("Done") also saves immediately, so route adjustments are
// never left sitting unsaved after the user says they're finished with
// them -- `saveLayout` is the same intercepted Save entry point the
// toolbar's own Save button uses (see legacy_v2_bridge_script.dart).
function wepCancelClicked() {
  if (routeEditMode) {
    if (typeof saveLayout === 'function') saveLayout();
    exitRouteEditMode();
  } else {
    cancelWireMode();
  }
}

// Lets the user click ANY wire while already in Route Edit mode and
// immediately edit its route, without leaving and re-entering the mode.
// Mirrors `selWire`'s own "select a wire" branch (selection-manager.js)
// but stays in Route Edit mode throughout instead of toggling it.
function selWireForRouteEdit(w, evt) {
  if (!routeEditMode || (selW && selW.id === w.id)) return;
  selW = w;
  selSeg = null;
  document.querySelectorAll('.mod-card').forEach(c => c.classList.remove('wire-selected'));
  const fc = cardEls[w.from.m], tc = cardEls[w.to.m];
  if (fc) fc.classList.add('wire-selected');
  if (tc) tc.classList.add('wire-selected');
  if (typeof showPanel === 'function') showPanel(w, evt);
  drawWires();
}

function resetWireRoute() {
  if (!selW) return;
  delete wireRoutes[selW.id];
  selSeg = null;
  drawWires(); showToast('Route reset');
}
