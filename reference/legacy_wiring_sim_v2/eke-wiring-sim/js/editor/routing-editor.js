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
    // AP-MASTER-EDIT-001 — used to always exit Edit Mode on entry, back
    // when the two were meant to be mutually exclusive. Now that Edit
    // Mode itself can drag a selected wire's segments too
    // (wireEditCapable, renderer.js), Route Edit is just the BROADER
    // version of that (every wire, not just the selected one — reported
    // directly as a real workflow need: "move any wire around not just
    // that one") — turning it on no longer needs to turn Edit Mode off.
    if (wireMode) cancelWireMode();
    $('wep').classList.add('open');
    $('wep-status').textContent = 'Drag any wire\'s segment to move it · ↑↓←→ nudge selected segment · R reset route';
    const cancelBtn = $('wep-cancel');
    if (cancelBtn) cancelBtn.textContent = '✓ Done';
    vp.classList.add('route-edit-mode');
  } else {
    exitRouteEditMode();
  }
  drawWires();
}

// AP-MASTER-EDIT-001 — the Wire Properties modal's own "↔ Edit Route"
// button. Closes the modal first (so it isn't sitting over the canvas
// blocking the very segments you'd want to drag) and turns Route Edit
// on if it wasn't already — reusing toggleRouteEditMode() rather than
// duplicating its setup, but only calling it when actually needed so a
// re-open of an already-active Route Edit doesn't accidentally toggle
// it back off. No "Done" step is required to use it: dragging a segment
// already saves live (wireRoutes is written on every move, same as
// before), so clicking a different wire, a module, or empty canvas
// afterward just does whatever it would normally do — there's nothing
// left to separately confirm. The existing "✓ Done" button in the
// bottom #wep panel still works too, for anyone who wants an explicit
// "I'm finished" action, but it was never meant to be mandatory.
function wpmEditRoute() {
  closeWPM();
  if (!routeEditMode) toggleRouteEditMode();
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

function resetWireRoute() {
  if (!selW) return;
  delete wireRoutes[selW.id];
  selSeg = null;
  drawWires(); showToast('Route reset');
}
