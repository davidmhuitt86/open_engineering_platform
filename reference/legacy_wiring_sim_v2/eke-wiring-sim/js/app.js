/**
 * app.js — Application bootstrap
 *
 * Responsibilities:
 *   1. Load vehicle data via VehicleLoader
 *   2. Populate shared globals (MODULES, WIRES, MEASUREMENTS, DEFAULT_POS)
 *   3. Call each subsystem initializer in order
 *   4. Handle keyboard shortcuts (global, belongs in bootstrap)
 *   5. Handle theme (global persistent preference)
 *   6. Handle panel manager (global drag/resize/remember for all floating panels)
 *
 * This file must NOT contain:
 *   rendering logic       → js/diagram/renderer.js
 *   wire/module editing   → js/editor/
 *   meter / lead logic    → js/ui/meter-panel.js
 *   inspector panels      → js/ui/inspector.js
 *   save / load           → js/storage/project-saver.js, project-loader.js
 *   toast                 → js/ui/notifications.js
 */

// ── Shared globals ────────────────────────────────────────────────
// Populated by initVehicle() before any subsystem runs.
// Every subsystem reads these; only the loader writes them at startup.

let MODULES      = [];
let WIRES        = [];
let MEASUREMENTS = {};
let DEFAULT_POS  = {};
let positions    = {};
let wireRoutes   = {};

// ── Runtime state ─────────────────────────────────────────────────
// Mode flags and selection state read by renderer.js and editor modules.

let scale = 1, tx = 20, ty = 20;
let editMode = false, wireMode = false, routeEditMode = false;
let wireSrc = null, selW = null, selSeg = null;
// AP-WIRE-EXIT-OVERRIDE-001 — while in Wire mode (before the destination
// terminal is clicked), the arrow keys set which side the new wire's
// first bend should leave the SOURCE terminal from, overriding that
// module/splice's own fixed `exit` side for this one wire only (see
// route() in renderer.js). Reset to null every time a wire is finalized
// or wire mode is cancelled — an override is a one-shot, per-wire choice,
// not a standing change to the module's own exit side.
let pendingWireExit = null;
// Reconnect-an-existing-wire-endpoint mode (§ startReconnectWireEnd in
// wire-editor.js): { wireId, end: 'from'|'to' } while active, else null.
// Reuses wireMode's own visuals/badge/cancel — see handleWireTerm's own
// short-circuit for this.
let reconnectTarget = null;
let keyPos = 0, meterMode = 'VDC';
let leadR = null, leadB = null, leadPlaceMode = null, leadMode = 'ends';
let panActive = false, panSX = 0, panSY = 0, panOX = 0, panOY = 0;
let pinch = { active:false, d0:0, cx:0, cy:0, s0:0, tx0:0, ty0:0 };
// Right-click-canvas "Add Module" — the canvas point (module-editor.js's
// own coordinate space, matching `positions[id]`) a module should be
// placed at next, set by the background context menu and consumed (then
// cleared) by whichever add path actually runs next (commitAddModule/
// openAddSplice) instead of their own viewport-center default.
let pendingAddPosition = null;
// The world-space (canvas coordinate, matching `positions[id]`) point a
// right-click's "+ Add Splice" should place/insert relative to — set by
// whichever contextmenu handler opened #ctx (background canvas, a wire,
// or a terminal dot — module-editor.js/renderer.js/wire-editor.js) right
// alongside `ctxTarget`, and read by ctxAddSplice() (wire-editor.js) to
// decide which of its three placement modes applies.
let ctxClickPoint = null;
let tracedWires = new Set(), ctxTarget = null, mcX = 0, mcY = 0;
// PRODUCT-READINESS-009 — set only by the native OEP bridge
// (window.__oepBridgeApplyTraceHighlight, legacy_v2_bridge_script.dart)
// while a native TraceMode.currentFlow trace is actively displayed: a
// Map<wireId, +1|-1> of wires that genuinely carry solved current, in
// which direction. `null` the rest of the time, in which case
// wireHasFlow()/wireFlowDir() (diagram/renderer.js) fall back to their
// original, unmodified legacy behavior untouched -- this never changes
// any behavior for V2's own manual wire-tracer panel.
let nativeFlowWires = null;
let kbhOpen = false, mpOpen = false, srchOpen = false, legOpen = false;
let selM = null;
const fp   = $('fp');
const NUDGE = 6;

// ── Bootstrap ─────────────────────────────────────────────────────
// Orchestration is handled by js/core/bootstrap.js.
// app.js calls Bootstrap.run() and handles any top-level failure display.

async function bootstrap() {
  try {
    await Bootstrap.run('trx300');
  } catch (err) {
    console.error('[EKE] bootstrap failed:', err);
    EKE.setError(err);
    const viewport = document.getElementById('viewport');
    if (viewport) viewport.innerHTML = `
      <div style="color:#f87171;padding:40px;font-family:monospace;font-size:11px">
        <b>Vehicle load failed</b><br><br>${err.message}<br><br>
        If opening as a local file, ensure diagrams/trx300/data-bundle.js is loaded.<br>
        If running on HTTP, check that diagrams/trx300/*.json files are accessible.
      </div>`;
  }
}

// ── Shared UI helpers ─────────────────────────────────────────────

function toggleKbh()    { kbhOpen = !kbhOpen; $('kbh').classList.toggle('open', kbhOpen); }
function toggleSearch() { srchOpen = !srchOpen; $('srch').classList.toggle('open', srchOpen); if (srchOpen) { $('srch-in').value = ''; $('srch-res').innerHTML = ''; $('srch-in').focus(); } }
function toggleLegend() { legOpen  = !legOpen;  $('legend').classList.toggle('open', legOpen); if (legOpen) buildLegend(); }
function buildLegend()  {
  const b = $('leg-body');
  b.innerHTML = "<div style='font-size:7px;letter-spacing:.12em;text-transform:uppercase;color:#555;margin-bottom:5px'>Categories</div>";
  Object.entries(CAT_CLR).forEach(([k, v]) => {
    const row = document.createElement('div'); row.className = 'lg-row';
    row.innerHTML = `<div class="lg-dot" style="background:${v}"></div><div class="lg-lbl">${k}</div>`;
    b.appendChild(row);
  });
}

function doSearch(q) {
  q = q.toLowerCase().trim();
  const res = $('srch-res'); res.innerHTML = '';
  if (!q) return;
  const results = [];
  MODULES.forEach(m => { if (m.label.toLowerCase().includes(q) || (m.sub||'').toLowerCase().includes(q) || m.id.includes(q)) results.push({ type:'module', label:m.label, sub:m.sub, id:m.id }); });
  WIRES.forEach(w   => { if (w.lbl.toLowerCase().includes(q)   || (w.desc||'').toLowerCase().includes(q) || w.c.toLowerCase().includes(q)) results.push({ type:'wire', label:w.lbl, sub:w.c+' — '+(w.desc||''), id:w.id, wire:w }); });
  results.slice(0, 14).forEach(r => {
    const row = document.createElement('div'); row.className = 'sr';
    row.innerHTML = `<span class="sr-type">${r.type}</span><div><div style="font-size:8px">${r.label}</div><div style="font-size:6.5px;color:#555">${r.sub||''}</div></div>`;
    row.onclick = () => {
      srchOpen = false; $('srch').classList.remove('open');
      if (r.type === 'module') scrollToMod(r.id);
      else { selW = r.wire; showPanel(r.wire, { clientX: vp.offsetWidth/2, clientY: vp.offsetHeight/2 }); drawWires(); }
    };
    res.appendChild(row);
  });
  if (!results.length) { const nr = document.createElement('div'); nr.style.cssText = 'padding:8px 12px;font-size:8px;color:#444'; nr.textContent = 'No results'; res.appendChild(nr); }
}
function srchKey(e)     { if (e.key === 'Escape') toggleSearch(); }
function scrollToMod(id) {
  const pos = positions[id] || DEFAULT_POS[id]; if (!pos) return;
  tx = vp.offsetWidth / 2 - pos.x * scale;
  ty = vp.offsetHeight / 2 - pos.y * scale;
  applyT();
  const card = cardEls[id];
  if (card) { card.classList.add('sel-flash'); setTimeout(() => card.classList.remove('sel-flash'), 1500); }
}

function traceCircuit() {
  if (!selW) return;
  // Delegate to CircuitTracer which consumes EKE.graph
  tracedWires = CircuitTracer.traceFromWire(selW.id);
  const related = CircuitTracer.getWires(tracedWires);
  renderTracerPanel(related);
  $('tracer').classList.add('open');
  drawWires();
}
function renderTracerPanel(wires) {
  const body = $('tr-body'); body.innerHTML = '';
  wires.forEach(w => {
    const row = document.createElement('div');
    row.className = 'tr-w' + (w.id === selW?.id ? ' act' : '');
    row.innerHTML = `<div class="tr-dot" style="background:${h(w.c)}"></div><div><div class="tr-lbl">${w.lbl}</div><div class="tr-ft">${w.from.m.replace(/-/g,' ')} → ${w.to.m.replace(/-/g,' ')}</div></div>`;
    row.onclick = () => { selW = w; updatePanel(w); drawWires(); renderTracerPanel(wires); };
    body.appendChild(row);
  });
}
function closeTracer() { $('tracer').classList.remove('open'); tracedWires.clear(); drawWires(); }

// Opens #ctx (the right-click context menu) anchored at (x, y), clamped
// to stay fully on screen instead of running off whichever edge is
// closest — a right-click low in the window used to always anchor the
// menu's TOP at the cursor, so a menu taller than the remaining space
// below just extended past the bottom edge and got clipped/obscured
// with no way to reach its lower items. #ctx has to actually be visible
// (`.open` added) before its real size can be measured (getBoundingClientRect
// on a `display:none` element is always 0×0), so this opens it
// provisionally at the click point first, measures it, then repositions
// only if it would overflow — flipping to anchor the opposite edge at
// the cursor (menu appears above/left of the click) rather than
// sliding to an arbitrary on-screen spot, so it still reads as "the
// menu for what you clicked," just growing the other direction.
function openCtxAt(x, y) {
  const m = $('ctx');
  m.style.left = x + 'px'; m.style.top = y + 'px';
  m.classList.add('open');
  const r = m.getBoundingClientRect();
  // The actual "menu opens in the wrong place" cause turned out to be
  // #ctx having UI-scale `zoom` applied to itself while being positioned
  // via raw `style.left`/`top` from a click coordinate — see main.css's
  // own comment on why #ctx is excluded from that now. `document
  // .documentElement.clientWidth/clientHeight` (falling back to
  // `window.innerWidth/innerHeight`, and skipping the overflow check
  // entirely if even that comes back non-positive) is kept here anyway
  // as the more robust of the two viewport-size reads, independent of
  // that fix — no reason to prefer the less reliable one now that both
  // are known.
  const vw = document.documentElement.clientWidth || window.innerWidth;
  const vh = document.documentElement.clientHeight || window.innerHeight;
  let left = x, top = y;
  if (vw > 0 && r.right > vw) left = Math.max(4, x - r.width);
  if (vh > 0 && r.bottom > vh) top = Math.max(4, y - r.height);
  m.style.left = left + 'px'; m.style.top = top + 'px';
}
function hideCtx() { $('ctx').classList.remove('open'); $('ctx-add-module').style.display = 'none'; $('ctx-add-splice').style.display = 'none'; $('ctx-add-diode').style.display = 'none'; $('ctx-edit').style.display = ''; $('ctx-edit').textContent = '✎ Edit Wire Props'; $('ctx-trace').style.display = ''; $('ctx-route').style.display = ''; $('ctx-rotate').style.display = 'none'; $('ctx-del').style.display = ''; $('ctx-del').textContent = '✕ Delete Wire'; ctxTarget = null; ctxClickPoint = null; }
function ctxEdit()   { if (!ctxTarget) return; if (ctxTarget._mid) editModProps(ctxTarget._mid); else { selW = ctxTarget; editWireProps(); } hideCtx(); }
function ctxTrace()  { if (ctxTarget && !ctxTarget._mid) { selW = ctxTarget; traceCircuit(); } hideCtx(); }
function ctxRoute()  { if (ctxTarget && !ctxTarget._mid) { selW = ctxTarget; if (!routeEditMode) toggleRouteEditMode(); else drawWires(); } hideCtx(); }
// Right-click on empty canvas -> "+ Add Module": stashes the clicked
// point (§ `pendingAddPosition`'s own doc comment) and opens the same
// module panel the toolbar's own "+" button already uses, so every
// existing preset/custom/connector/splice add path is reused verbatim —
// only where the result gets placed changes.
function ctxAddModule() {
  if (!ctxTarget || !ctxTarget._bg) { hideCtx(); return; }
  pendingAddPosition = { x: ctxTarget.x, y: ctxTarget.y };
  hideCtx();
  openModPanel();
}
function ctxRotate() { if (ctxTarget && ctxTarget._mid) { rotateModule(ctxTarget._mid); } hideCtx(); }
function ctxDelete() { if (!ctxTarget) return; if (ctxTarget._mid) { const mid = ctxTarget._mid; hideCtx(); delModule(mid); } else { selW = ctxTarget; hideCtx(); deleteSelectedWire(); } }
document.addEventListener('click', e => { if (!e.target.closest('#ctx')) hideCtx(); });

// ── Keyboard shortcuts ────────────────────────────────────────────

window.addEventListener('keydown', e => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') return;
  // Route-edit arrow nudge
  if (routeEditMode && selSeg) {
    if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.key)) {
      e.preventDefault();
      // AP-WIRE-GRID-ALIGN-001 — the step is now GRID itself (20px, not
      // the old 6px NUDGE), and the result is snapped to the nearest
      // grid multiple rather than just added — so a segment that starts
      // already grid-aligned (the common case after this whole fix)
      // moves in clean, exact grid steps, and one that doesn't (an older
      // saved diagram) gets corrected onto the grid by its very first
      // nudge instead of drifting further off it. Mirrors the same
      // mouse/touch-drag snap in renderer.js's setupTermClicks-adjacent
      // segment-drag handlers — either input method lands on the same
      // grid.
      const step = e.shiftKey ? GRID * 2 : GRID;
      const w = WIRES.find(x => x.id === selSeg.wid);
      const rt = w && route(w);
      if (!rt) return;
      const seg = getMovableSegs(rt.pts)[selSeg.segIdx];
      if (!seg) return;
      const p = rt.pts[seg.i1];
      if (!wireRoutes[selSeg.wid]) wireRoutes[selSeg.wid] = {};
      const cur = wireRoutes[selSeg.wid][selSeg.segIdx] || 0;
      let delta = 0;
      if (selSeg.axis === 'y' && e.key === 'ArrowUp')    delta = -step;
      if (selSeg.axis === 'y' && e.key === 'ArrowDown')  delta =  step;
      if (selSeg.axis === 'x' && e.key === 'ArrowLeft')  delta = -step;
      if (selSeg.axis === 'x' && e.key === 'ArrowRight') delta =  step;
      if (delta !== 0) {
        const natural = (selSeg.axis === 'y' ? p.y : p.x) - cur;
        const rawAbs = natural + cur + delta;
        wireRoutes[selSeg.wid][selSeg.segIdx] = Math.round(rawAbs / GRID) * GRID - natural;
        drawWires();
      }
      return;
    }
  }
  // AP-WIRE-EXIT-OVERRIDE-001 — arrow keys while actively drawing a wire
  // (source picked, destination not clicked yet) set/override the exit
  // side for just this wire, so a wire whose module/splice's own default
  // exit side would route it behind another module can be pointed the
  // other way on the fly instead of needing a manual route drag after
  // the fact. Deliberately gated on `wireSrc` (not just `wireMode`) so
  // arrow keys still do nothing until a source is actually chosen.
  if (wireMode && !reconnectTarget &&
      ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) {
    e.preventDefault();
    pendingWireExit = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' }[e.key];
    updateWireExitStatus();
    return;
  }
  if (routeEditMode && (e.key === 'r' || e.key === 'R')) { resetWireRoute(); return; }
  if (e.key === 'e' || e.key === 'E') { toggleEdit();     return; }
  if (e.key === 'w' || e.key === 'W') { toggleWireMode(); return; }
  if (e.key === 'f' || e.key === 'F') { zReset();         return; }
  if (e.key === '/' || e.key === '?') { e.preventDefault(); toggleSearch(); return; }
  if (e.key === 'l' || e.key === 'L') { toggleLegend();   return; }
  if (e.key === 'G' && e.ctrlKey && e.shiftKey) { e.preventDefault(); GraphInspector.toggle(); return; }
  if (e.key === 'Escape') {
    if (leadPlaceMode) { leadPlaceMode = null; vp.classList.remove('lead-place-mode'); updateLeadBtns(); return; }
    if (routeEditMode) { exitRouteEditMode(); return; }
    if (wireMode)      { cancelWireMode();   return; }
    if ($('mpm').classList.contains('open'))       { closeMpm();      return; }
    if ($('add-modal').classList.contains('open')) { closeAddModal(); return; }
    if ($('wpm').classList.contains('open'))       { closeWPM();      return; }
    if ($('view-settings-modal').classList.contains('open')) { closeViewSettings(); return; }
    if (srchOpen)  { toggleSearch(); return; }
    if (selM)      { closeModInfo(); drawWires(); return; }
    if (selW)      { selW = null; closePanel(); leadR = null; leadB = null; clearLeadDots(); tracedWires.clear(); drawWires(); }
  }
  if (e.key === 'Delete' && selW && !editMode) deleteSelectedWire();
  if (e.key >= '0' && e.key <= '3' && !e.ctrlKey && !e.metaKey) setKey(+e.key);
});

// ── Viewport persistence ──────────────────────────────────────────
// Remembers the diagram's pan/zoom across sessions (renderer.js's
// initViewport/applyT), so opening the app doesn't always land on a
// full-diagram fit-to-view that's too small to read — see initViewport's
// own doc comment for why that used to happen on every load.

const VIEWPORT_KEY = 'wiring-sim-viewport';
let _viewportSaveTimer = null;
function loadViewportState() {
  try { return JSON.parse(localStorage.getItem(VIEWPORT_KEY) || 'null'); } catch { return null; }
}
function persistViewportState() {
  clearTimeout(_viewportSaveTimer);
  _viewportSaveTimer = setTimeout(() => {
    localStorage.setItem(VIEWPORT_KEY, JSON.stringify({ scale, tx, ty }));
  }, 250);
}

// ── UI scale ──────────────────────────────────────────────────────
// The chrome (topbar, panels, modals, labels) is a very dense, small
// technical UI by design (see main.css) — legible at arm's length on a
// large monitor, but too small to read comfortably in most day-to-day
// use. Rather than rewriting every hardcoded font-size/padding value,
// `zoom` uniformly rescales layout, text and hit-testing together (this
// app only ever runs inside a Chromium-based WebView2 host, where `zoom`
// is fully supported), and click coordinates (clientX/clientY,
// getBoundingClientRect) stay internally consistent since they're all
// expressed in the same already-zoomed CSS pixel space.
const UI_SCALE_KEY = 'wiring-sim-ui-scale';
const UI_SCALE_MIN = 0.9, UI_SCALE_MAX = 2, UI_SCALE_DEFAULT = 1.3;
// AP-VIEW-SETTINGS-001 — "nothing remembered yet" used to always fall
// back to the hardcoded UI_SCALE_DEFAULT (1.3). A user-configured
// default (⚙ Zoom & Scale Defaults panel, saveViewSettings() below) now
// takes priority over that constant, same idea as initViewport()'s own
// default-zoom fallback (renderer.js).
function loadUiScale() {
  const v = parseFloat(localStorage.getItem(UI_SCALE_KEY));
  if (Number.isFinite(v)) return v;
  const def = loadDefaultUiScalePct();
  return def != null ? def / 100 : UI_SCALE_DEFAULT;
}
function setUiScale(v) {
  const clamped = Math.min(UI_SCALE_MAX, Math.max(UI_SCALE_MIN, v));
  // Sets --ui-zoom, which main.css applies (zoom:var(--ui-zoom)) only to
  // the named chrome elements — never to <html>/<body> or #viewport. See
  // the comment above that CSS rule for why: zoom on an ancestor of
  // #viewport, even when mathematically cancelled back out on #viewport
  // itself, broke real-mouse wire selection in the WebView2 host.
  document.documentElement.style.setProperty('--ui-zoom', String(clamped));
  localStorage.setItem(UI_SCALE_KEY, String(clamped));
  // AP-VIEW-SETTINGS-001 — `#ui-scale-display` went from a read-only
  // <span> to an editable <input> (per direct user request); `.value`,
  // not `.textContent`, is what changes an <input>'s displayed text.
  const disp = document.getElementById('ui-scale-display');
  if (disp) disp.value = Math.round(clamped * 100) + '%';
}
// AP-VIEW-SETTINGS-001 — the topbar's UI-scale % input's own onblur
// handler (index.html) — mirrors setZoomPctFromInput (renderer.js).
function setUiScalePctFromInput(input) {
  const n = parseFloat(input.value);
  if (Number.isFinite(n)) setUiScale(n / 100);
  else input.value = Math.round(loadUiScale() * 100) + '%';
}

// ── Default zoom / UI-scale settings ────────────────────────────────
// The "remembered last view" above (VIEWPORT_KEY/UI_SCALE_KEY) is what
// applies on an ordinary reopen. These are a SEPARATE, explicit starting
// point the user configures once via the ⚙ Zoom & Scale Defaults panel
// — used only when nothing has been remembered yet (a genuinely first
// launch, or right after "Reset to these now" clears the remembered
// state) — reported directly as a real gap: no way to see or set what
// that starting point actually was, short of reading source constants.
const DEFAULT_ZOOM_KEY = 'wiring-sim-default-zoom-pct';
const DEFAULT_UI_SCALE_KEY = 'wiring-sim-default-ui-scale-pct';
function loadDefaultZoomPct() {
  const v = parseFloat(localStorage.getItem(DEFAULT_ZOOM_KEY));
  return Number.isFinite(v) ? v : null;
}
function loadDefaultUiScalePct() {
  const v = parseFloat(localStorage.getItem(DEFAULT_UI_SCALE_KEY));
  return Number.isFinite(v) ? v : null;
}
function openViewSettings() {
  const zoomPct = loadDefaultZoomPct();
  const uiPct = loadDefaultUiScalePct();
  $('vs-zoom').value = zoomPct != null ? Math.round(zoomPct) : '';
  $('vs-ui-scale').value = uiPct != null ? Math.round(uiPct) : '';
  $('view-settings-modal').classList.add('open');
}
function closeViewSettings() { $('view-settings-modal').classList.remove('open'); }
// Shared by both modal actions — writes whatever's currently typed into
// the two fields, without any toast/close side effect of its own, so
// resetViewToDefaults() below can reuse it without producing two toasts.
function _storeViewSettingsFields() {
  const zoomPct = parseFloat($('vs-zoom').value);
  const uiPct = parseFloat($('vs-ui-scale').value);
  if (Number.isFinite(zoomPct)) localStorage.setItem(DEFAULT_ZOOM_KEY, String(Math.min(300, Math.max(15, zoomPct))));
  else localStorage.removeItem(DEFAULT_ZOOM_KEY);
  if (Number.isFinite(uiPct)) localStorage.setItem(DEFAULT_UI_SCALE_KEY, String(Math.min(UI_SCALE_MAX * 100, Math.max(UI_SCALE_MIN * 100, uiPct))));
  else localStorage.removeItem(DEFAULT_UI_SCALE_KEY);
}
function saveViewSettings() {
  _storeViewSettingsFields();
  closeViewSettings();
  showToast('Zoom & scale defaults saved');
}
// Jumps the CURRENT view to the configured defaults right now, without
// waiting for the next fresh launch — the direct "get back to my usual
// view" action, since typing something into the settings fields alone
// doesn't otherwise change anything until "nothing is remembered" is
// true again.
function resetViewToDefaults() {
  _storeViewSettingsFields();
  const zoomPct = loadDefaultZoomPct();
  const uiPct = loadDefaultUiScalePct();
  if (zoomPct != null) setZoomPct(zoomPct);
  if (uiPct != null) setUiScale(uiPct / 100);
  closeViewSettings();
  showToast('View reset to defaults');
}
function uiScaleBy(delta) { setUiScale(loadUiScale() + delta); }
setUiScale(loadUiScale());

// ── Theme ─────────────────────────────────────────────────────────

(function () {
  const THEME_KEY = 'wiring-sim-theme';
  const saved = localStorage.getItem(THEME_KEY) || 'dark';
  document.documentElement.dataset.theme = saved;
  function syncBtn() {
    const isDark = document.documentElement.dataset.theme === 'dark';
    const icon = $('theme-toggle-icon'), lbl = $('theme-toggle-lbl');
    if (icon) icon.textContent = isDark ? '☾' : '☀';
    if (lbl)  lbl.textContent  = isDark ? 'Dark' : 'Light';
  }
  syncBtn();
  window.toggleTheme = function () {
    const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    localStorage.setItem(THEME_KEY, next);
    syncBtn();
    if (typeof drawWires === 'function') drawWires();
  };
})();

// ── Panel manager ─────────────────────────────────────────────────

(function () {
  const STORE_PREFIX = 'wiring-panel-';
  const DRAG_MAP = { 'fp':'fp-drag', 'mip':'mip-drag', 'swpack-panel':'swpack-hd', 'tracer':'tr-hd', 'sim-panel':'sim-panel-hd' };
  const RESIZABLE_IDS = Object.keys(DRAG_MAP);

  function saved(id) { try { return JSON.parse(localStorage.getItem(STORE_PREFIX + id) || 'null'); } catch { return null; } }
  function save(id, state) { localStorage.setItem(STORE_PREFIX + id, JSON.stringify(state)); }
  function applySaved(el, id) {
    const s = saved(id); if (!s) return;
    if (s.left  != null) el.style.left   = s.left  + 'px';
    if (s.top   != null) el.style.top    = s.top   + 'px';
    if (s.width != null) el.style.width  = s.width + 'px';
    if (s.height!= null) el.style.height = s.height+ 'px';
    if ((id === 'swpack-panel' || id === 'sim-panel') && s.left != null) el.style.transform = 'none';
  }
  function getState(el) { return { left:el.offsetLeft, top:el.offsetTop, width:el.offsetWidth, height:el.offsetHeight }; }
  function clamp(el) {
    const vw = window.innerWidth, vh = window.innerHeight;
    el.style.left = Math.max(0, Math.min(el.offsetLeft, vw - 60)) + 'px';
    el.style.top  = Math.max(0, Math.min(el.offsetTop,  vh - 60)) + 'px';
  }
  function attachDrag(panelEl, handleEl) {
    let drag = false, ox = 0, oy = 0;
    handleEl.addEventListener('mousedown', e => {
      if (e.target.closest('.panel-menu-btn') || e.target.closest('.panel-menu')) return;
      if (e.target.tagName === 'BUTTON' && e.target !== handleEl) return;
      drag = true;
      const r = panelEl.getBoundingClientRect();
      panelEl.style.left = r.left + 'px'; panelEl.style.top = r.top + 'px'; panelEl.style.transform = 'none';
      ox = e.clientX - panelEl.offsetLeft; oy = e.clientY - panelEl.offsetTop;
      e.preventDefault();
    });
    handleEl.addEventListener('touchstart', e => {
      if (e.target.closest('.panel-menu-btn')) return;
      const t = e.touches[0], r = panelEl.getBoundingClientRect();
      panelEl.style.left = r.left + 'px'; panelEl.style.top = r.top + 'px'; panelEl.style.transform = 'none';
      drag = true; ox = t.clientX - panelEl.offsetLeft; oy = t.clientY - panelEl.offsetTop;
      e.preventDefault();
    }, { passive: false });
    const onMove = (cx, cy) => { if (!drag) return; panelEl.style.left = (cx - ox) + 'px'; panelEl.style.top = (cy - oy) + 'px'; };
    window.addEventListener('mousemove', e => onMove(e.clientX, e.clientY));
    window.addEventListener('touchmove', e => onMove(e.touches[0].clientX, e.touches[0].clientY), { passive: false });
    const onUp = () => { if (!drag) return; drag = false; clamp(panelEl); };
    window.addEventListener('mouseup', onUp); window.addEventListener('touchend', onUp);
  }
  function attachResize(panelEl) {
    const handle = document.createElement('div');
    handle.className = 'resize-handle'; handle.title = 'Drag to resize';
    panelEl.style.overflow = 'hidden'; panelEl.appendChild(handle);
    let active = false, sx = 0, sy = 0, sw = 0, sh = 0;
    handle.addEventListener('mousedown', e => { active = true; sx = e.clientX; sy = e.clientY; sw = panelEl.offsetWidth; sh = panelEl.offsetHeight; e.preventDefault(); e.stopPropagation(); });
    window.addEventListener('mousemove', e => {
      if (!active) return;
      panelEl.style.width  = Math.max(parseInt(getComputedStyle(panelEl).minWidth)  || 180, sw + (e.clientX - sx)) + 'px';
      panelEl.style.height = Math.max(parseInt(getComputedStyle(panelEl).minHeight) || 140, sh + (e.clientY - sy)) + 'px';
    });
    window.addEventListener('mouseup', () => { active = false; });
  }
  const menuEl = document.createElement('div');
  menuEl.className = 'panel-menu'; menuEl.id = 'panel-menu-global';
  document.body.appendChild(menuEl);
  let menuPanelId = null;
  document.addEventListener('click', e => { if (!e.target.closest('#panel-menu-global') && !e.target.closest('.panel-menu-btn')) menuEl.classList.remove('open'); });
  window.panelMenuOpen = function (id, btn) {
    menuPanelId = id;
    const panel = document.getElementById(id); if (!panel) return;
    menuEl.innerHTML = `<div class="panel-menu-i" onclick="panelMenuCmd('default')">📌 Set as Default Position</div><div class="panel-menu-i" onclick="panelMenuCmd('reset')">↺ Reset to Default</div><div class="panel-menu-i" onclick="panelMenuCmd('center')">⊡ Re-center Panel</div><div class="panel-menu-i" onclick="panelMenuCmd('resetSize')">⤡ Reset Size</div>`;
    const r = btn.getBoundingClientRect();
    menuEl.style.top = (r.bottom + 4) + 'px'; menuEl.style.left = (r.left - 140) + 'px';
    menuEl.classList.toggle('open');
  };
  window.panelMenuCmd = function (cmd) {
    menuEl.classList.remove('open');
    const panel = document.getElementById(menuPanelId); if (!panel) return;
    if (cmd === 'default')   { save(menuPanelId, getState(panel)); showToast('Default position saved'); }
    else if (cmd === 'reset')    { localStorage.removeItem(STORE_PREFIX + menuPanelId); panel.style.cssText = ''; if (menuPanelId === 'swpack-panel' || menuPanelId === 'sim-panel') panel.style.transform = 'translateX(-50%)'; showToast('Position reset'); }
    else if (cmd === 'center')   { panel.style.left = ((window.innerWidth - panel.offsetWidth) / 2) + 'px'; panel.style.top = ((window.innerHeight - panel.offsetHeight) / 2) + 'px'; panel.style.transform = 'none'; }
    else if (cmd === 'resetSize'){ panel.style.width = ''; panel.style.height = ''; showToast('Size reset'); }
  };
  function boot() {
    Object.entries(DRAG_MAP).forEach(([panelId, handleId]) => {
      const panel = document.getElementById(panelId), handle = document.getElementById(handleId);
      if (!panel || !handle) return;
      applySaved(panel, panelId); attachDrag(panel, handle);
    });
    RESIZABLE_IDS.forEach(id => { const panel = document.getElementById(id); if (panel) attachResize(panel); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
  function updateModPanelTop() { const tw = document.getElementById('topbar-wrap'), mp = document.getElementById('mod-panel'); if (tw && mp) mp.style.top = tw.offsetHeight + 'px'; }
  window.addEventListener('resize', updateModPanelTop);
  setTimeout(updateModPanelTop, 200);
})();

// ── Start ─────────────────────────────────────────────────────────

// Deliberately NOT re-fitting the whole diagram on resize anymore — that
// silently discarded the user's own zoom/pan (and the whole point of
// initViewport() above is to stop resetting their view unexpectedly).
// Wires/minimap still need to redraw since the viewport's pixel size and
// scroll clamping can change.
window.addEventListener('resize', () => { drawWires(); updateMinimap(); });
bootstrap();
