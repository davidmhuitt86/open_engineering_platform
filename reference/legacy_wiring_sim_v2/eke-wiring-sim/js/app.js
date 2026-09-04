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
let keyPos = 0, meterMode = 'VDC';
let leadR = null, leadB = null, leadPlaceMode = null, leadMode = 'ends';
let panActive = false, panSX = 0, panSY = 0, panOX = 0, panOY = 0;
let pinch = { active:false, d0:0, cx:0, cy:0, s0:0, tx0:0, ty0:0 };
let tracedWires = new Set(), ctxTarget = null, mcX = 0, mcY = 0;
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

function hideCtx() { $('ctx').classList.remove('open'); $('ctx-edit').style.display = ''; $('ctx-edit').textContent = '✎ Edit Wire Props'; $('ctx-trace').style.display = ''; $('ctx-route').style.display = ''; $('ctx-rotate').style.display = 'none'; $('ctx-del').textContent = '✕ Delete Wire'; ctxTarget = null; }
function ctxEdit()   { if (!ctxTarget) return; if (ctxTarget._mid) editModProps(ctxTarget._mid); else { selW = ctxTarget; editWireProps(); } hideCtx(); }
function ctxTrace()  { if (ctxTarget && !ctxTarget._mid) { selW = ctxTarget; traceCircuit(); } hideCtx(); }
function ctxRoute()  { if (ctxTarget && !ctxTarget._mid) { selW = ctxTarget; if (!routeEditMode) toggleRouteEditMode(); else drawWires(); } hideCtx(); }
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
      const step = e.shiftKey ? NUDGE * 4 : NUDGE;
      if (!wireRoutes[selSeg.wid]) wireRoutes[selSeg.wid] = {};
      const cur = wireRoutes[selSeg.wid][selSeg.segIdx] || 0;
      let delta = 0;
      if (selSeg.axis === 'y' && e.key === 'ArrowUp')    delta = -step;
      if (selSeg.axis === 'y' && e.key === 'ArrowDown')  delta =  step;
      if (selSeg.axis === 'x' && e.key === 'ArrowLeft')  delta = -step;
      if (selSeg.axis === 'x' && e.key === 'ArrowRight') delta =  step;
      if (delta !== 0) { wireRoutes[selSeg.wid][selSeg.segIdx] = cur + delta; drawWires(); }
      return;
    }
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
    if (srchOpen)  { toggleSearch(); return; }
    if (selM)      { closeModInfo(); drawWires(); return; }
    if (selW)      { selW = null; closePanel(); leadR = null; leadB = null; clearLeadDots(); tracedWires.clear(); drawWires(); }
  }
  if (e.key === 'Delete' && selW && !editMode) deleteSelectedWire();
  if (e.key >= '0' && e.key <= '3' && !e.ctrlKey && !e.metaKey) setKey(+e.key);
});

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
  const DRAG_MAP = { 'fp':'fp-drag', 'mip':'mip-drag', 'swpack-panel':'swpack-hd', 'tracer':'tr-hd' };
  const RESIZABLE_IDS = Object.keys(DRAG_MAP);

  function saved(id) { try { return JSON.parse(localStorage.getItem(STORE_PREFIX + id) || 'null'); } catch { return null; } }
  function save(id, state) { localStorage.setItem(STORE_PREFIX + id, JSON.stringify(state)); }
  function applySaved(el, id) {
    const s = saved(id); if (!s) return;
    if (s.left  != null) el.style.left   = s.left  + 'px';
    if (s.top   != null) el.style.top    = s.top   + 'px';
    if (s.width != null) el.style.width  = s.width + 'px';
    if (s.height!= null) el.style.height = s.height+ 'px';
    if (id === 'swpack-panel' && s.left != null) el.style.transform = 'none';
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
    else if (cmd === 'reset')    { localStorage.removeItem(STORE_PREFIX + menuPanelId); panel.style.cssText = ''; if (menuPanelId === 'swpack-panel') panel.style.transform = 'translateX(-50%)'; showToast('Position reset'); }
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

window.addEventListener('resize', () => { zReset(); drawWires(); updateMinimap(); });
bootstrap();
