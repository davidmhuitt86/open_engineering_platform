/**
 * ui/toolbar.js
 *
 * OEP-STUDIO-BRANDING-V1 — the generic contextual-dropdown controller for
 * the restyled top toolbar (`#topbar-actions` in index.html): click a
 * `.tb-icon-btn[data-dropdown-for]`, its matching `#dd-*` panel opens
 * directly below it; click anywhere outside the open dropdown (including
 * its own trigger button again, or Escape) and it closes. Exactly the
 * "click tool -> dropdown, select action -> dropdown can close, click
 * empty space -> collapses" behavior asked for — no intrusive modal
 * windows, no Close button.
 *
 * Deliberately owns ONLY open/close/position state for these dropdowns.
 * Every action inside a dropdown is still a plain onclick= calling an
 * existing global function (zBy, toggleEdit, toggleSearch, ...) defined
 * elsewhere (app.js et al) — this file adds no new diagram/editing
 * behavior of its own, matching this file's own pre-existing doc-comment
 * scope ("No electrical logic. No rendering of diagram elements.").
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
 * OEP-STUDIO-BRANDING-V1 — the engineering toolbar's TRACE/MEASURE
 * dropdown items are the only ones backed by real FLUTTER logic
 * (TraceController/MultimeterController — the same controllers the
 * Trace Circuit/Multimeter workspace-action panels already use), not a
 * V2-native function. This posts one small, fixed-vocabulary command
 * string through `window.__oepBridgePostMessage` — the SAME cross-
 * platform (Windows/Android) outbound function the injected bridge
 * script itself already defines and uses for every other message this
 * app sends (legacy_v2_bridge_script.dart), rather than reaching for
 * `window.chrome.webview.postMessage` directly, which would only work
 * on Windows. `LegacyV2BridgeTransport.onEngineeringCommand` (Windows)
 * / the Android transport's own identical handling dispatches this to
 * real provider actions on the Dart side
 * (`_WindowsLegacyV2WebViewPageState._handleEngineeringCommand`,
 * legacy_v2_webview.dart). Closes whichever dropdown is open first,
 * same as any other toolbar action.
 */
function toolbarSendEngineeringCommand(command) {
  toolbarCloseAllDropdowns();
  if (typeof window.__oepBridgePostMessage === 'function') {
    window.__oepBridgePostMessage(JSON.stringify({ type: 'engineeringCommand', payload: { command } }));
  }
}
