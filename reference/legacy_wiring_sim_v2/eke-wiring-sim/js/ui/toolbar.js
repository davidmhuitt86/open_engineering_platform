/**
 * ui/toolbar.js
 *
 * Generic contextual-dropdown controller for the engineering toolbar
 * (index.html): click a `.tb-icon-btn[data-dropdown-for]`, its matching
 * `#dd-*` panel opens beneath it; click outside, or Escape, closes it.
 *
 * Owns ONLY open/close/position state for these dropdowns. Every action
 * inside one is a plain onclick= calling an existing global function
 * (app.js et al) — no new diagram/editing behavior lives here.
 */

let _openDropdownId = null;

function toolbarToggleDropdown(id, btnEl) {
  const dd = document.getElementById(id);
  if (!dd) return;
  const alreadyOpen = dd.classList.contains('open');
  toolbarCloseAllDropdowns();
  if (alreadyOpen) return;
  const r = btnEl.getBoundingClientRect();
  dd.style.left = Math.round(r.left) + 'px';
  dd.style.top = Math.round(r.bottom + 4) + 'px';
  dd.classList.add('open');
  btnEl.classList.add('tb-dd-open');
  _openDropdownId = id;
}

function toolbarCloseAllDropdowns() {
  document.querySelectorAll('.tb-dropdown.open').forEach(d => d.classList.remove('open'));
  document.querySelectorAll('.tb-icon-btn.tb-dd-open').forEach(b => b.classList.remove('tb-dd-open'));
  _openDropdownId = null;
}

document.addEventListener('click', (e) => {
  if (!_openDropdownId) return;
  const dd = document.getElementById(_openDropdownId);
  const trigger = document.querySelector(`[data-dropdown-for="${_openDropdownId}"].tb-icon-btn`);
  if (dd && dd.contains(e.target)) return; // a click on an action inside the dropdown is handled by that action's own onclick=
  if (trigger && trigger.contains(e.target)) return; // its own trigger toggles itself
  toolbarCloseAllDropdowns();
}, true);

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && _openDropdownId) toolbarCloseAllDropdowns();
});

/**
 * Sends one fixed-vocabulary command string to the Flutter side (File/
 * Trace/Measure/Analyze toolbar items that need real Flutter logic, not
 * a V2-native function) via `window.__oepBridgePostMessage` — the same
 * cross-platform outbound channel every other bridge message uses.
 * Handled by `_handleEngineeringCommand` (legacy_v2_webview.dart).
 */
function toolbarSendEngineeringCommand(command) {
  toolbarCloseAllDropdowns();
  if (typeof window.__oepBridgePostMessage === 'function') {
    window.__oepBridgePostMessage(JSON.stringify({ type: 'engineeringCommand', payload: { command } }));
  }
}
