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
    $('wep-status').textContent = 'Click a wire segment · ↑↓←→ nudge · R reset route';
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
  vp.classList.remove('route-edit-mode');
  drawWires();
}

function resetWireRoute() {
  if (!selW) return;
  delete wireRoutes[selW.id];
  selSeg = null;
  drawWires(); showToast('Route reset');
}
