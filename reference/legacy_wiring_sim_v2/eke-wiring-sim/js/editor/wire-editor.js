/**
 * editor/wire-editor.js
 *
 * Wire mode (draw wires by clicking terminals), wire deletion,
 * terminal click routing, and wire property modal.
 *
 * Reads/writes: WIRES, wireRoutes, selW, wireSrc, wireMode globals.
 * Calls: drawWires, showToast, updatePanel, closePanel, exitRouteEditMode.
 *
 * No electrical calculations. No rendering geometry.
 */

// ── Terminal clicks ───────────────────────────────────────────────

// Terminal dots live inside the same #scene transform the whole diagram
// pans/zooms under, so their on-screen size shrinks with zoom — on a
// module with several terminals zoomed out to see a full harness, dots
// end up sub-2px apart. At that size a real mouse click's pixel-level
// hit-test can land on the browser's nearest DOM element rather than the
// one the user actually aimed for, which reliably resolves to whichever
// terminal happens to be first/leftmost in a now-visually-merged cluster
// — the reported "wire always starts from the same terminal regardless
// of which one was clicked" bug. Fixed by not trusting which literal
// `.t-dot` the browser resolved to: any click landing on or near a
// card's terminal strip is re-resolved to whichever of that card's own
// terminals is geometrically closest to the actual click point, which
// stays accurate at any zoom level since it works from real on-screen
// centers rather than sub-pixel hit-testing.
const TERM_CLICK_RADIUS = 16; // CSS px — generous enough to cover a full-size dot too
// Shared by the click handler and the new right-click-a-terminal handler
// below — resolves ANY event landing near a card's terminal strip to
// whichever of that card's own dots is geometrically closest, exactly
// like the click handler already needed for low-zoom accuracy (see its
// own doc comment above setupTermClicks). Returns the dot element, or
// null if nothing on this card is within TERM_CLICK_RADIUS.
function nearestTermDot(card, evt) {
  const dots = Array.from(card.querySelectorAll('.t-dot'));
  let best = null, bestD = Infinity;
  for (const d of dots) {
    const r = d.getBoundingClientRect();
    const dx = evt.clientX - (r.left + r.width / 2), dy = evt.clientY - (r.top + r.height / 2);
    const dist = Math.hypot(dx, dy);
    if (dist < bestD) { bestD = dist; best = d; }
  }
  return best && bestD <= TERM_CLICK_RADIUS ? best : null;
}
function setupTermClicks(card) {
  card.querySelectorAll('.t-dot').forEach(dot => {
    dot.addEventListener('mouseenter', () => { if ((wireMode && wireSrc) || leadPlaceMode) dot.classList.add('wh'); });
    dot.addEventListener('mouseleave', () => dot.classList.remove('wh'));
  });
  card.addEventListener('click', e => {
    // Deliberately not gated on `e.target.closest('.t-dot')` — at low
    // zoom a real click routinely lands a pixel or two off the dot it
    // was aimed at (see comment above), landing on the strip/card
    // background instead. nearestTermDot's own radius check is what
    // filters out genuinely unrelated clicks; requiring the raw hit
    // target to already be a dot would defeat the fix for exactly the
    // near-miss case it exists to handle.
    const best = nearestTermDot(card, e);
    if (!best) return;
    e.stopPropagation();
    const mid = best.dataset.mid, tn = best.dataset.tn;
    if (!mid || !tn) return;
    if (wireMode)      { handleWireTerm(mid, tn, best); return; }
    if (editMode)      return;
    if (leadPlaceMode) {
      if (leadPlaceMode === 'R') leadR = { m: mid, t: tn };
      else                       leadB = { m: mid, t: tn };
      leadPlaceMode = null;
      vp.classList.remove('lead-place-mode');
      clearLeadDots(); restoreLeadDots(); updateMeter(); drawWires(); updateLeadBtns();
      showToast(leadR && leadB ? 'Both leads placed' : 'Lead placed');
      return;
    }
    if (!selW) return;
    clearLeadDots();
    if (e.shiftKey) leadB = { m: mid, t: tn };
    else            leadR = { m: mid, t: tn };
    restoreLeadDots(); updateMeter(); drawWires();
  });
  // Right-click a terminal -> "+ Add Splice" placed in-line with that
  // terminal's own exit direction, so a splice inserted before a wire
  // even exists yet still lines up straight instead of needing a manual
  // nudge (the same axis-matching idea insertSpliceOnWire already
  // applies when splicing an EXISTING wire — this covers placing one
  // before the wire that will use it has been drawn at all, per direct
  // user request).
  card.addEventListener('contextmenu', e => {
    const best = nearestTermDot(card, e);
    if (!best || editMode || wireMode || routeEditMode) return;
    e.preventDefault(); e.stopPropagation();
    const mid = best.dataset.mid, tn = best.dataset.tn;
    if (!mid || !tn) return;
    ctxTarget = { _term: true, mid, tn };
    ctxClickPoint = null; // ctxAddSplice() computes the splice position itself for this case
    $('ctx-add-module').style.display = 'none';
    $('ctx-add-splice').style.display = '';
    $('ctx-add-diode').style.display = 'none'; // diode only offered on an existing wire (has a real forward direction to preserve) — see insertDiodeOnWire's own doc comment
    $('ctx-edit').style.display = 'none'; $('ctx-trace').style.display = 'none';
    $('ctx-route').style.display = 'none'; $('ctx-rotate').style.display = 'none';
    $('ctx-del').style.display = 'none';
    openCtxAt(e.clientX, e.clientY);
  });
}

// ── Wire mode ─────────────────────────────────────────────────────

// OEP-STUDIO-BRANDING-V1 — #wire-btn now also has a real SVG icon child
// (index.html's #tb-diagram), so a plain `.textContent =` (the three
// call sites below all used to do this) would silently delete it —
// this targets the label span instead, same as toggleEdit's own
// identical fix (module-editor.js).
function _setWireBtnLabel(text) {
  const btn = $('wire-btn');
  if (!btn) return;
  const lbl = btn.querySelector('.tb-icon-btn-lbl');
  if (lbl) lbl.textContent = text; else btn.textContent = '⚡ ' + text;
}

function toggleWireMode() {
  wireMode = !wireMode;
  if (wireMode && editMode) toggleEdit();
  if (wireMode && routeEditMode) exitRouteEditMode();
  vp.classList.toggle('wire-mode', wireMode);
  $('wire-btn').classList.toggle('wire-on', wireMode);
  _setWireBtnLabel(wireMode ? 'Done' : 'Wire');
  $('wire-badge').style.display = wireMode ? 'block'  : 'none';
  $('wep').classList.toggle('open', wireMode);
  pendingWireExit = null;
  if (!wireMode) { wireSrc = null; clearSrcHL(); }
  else $('wep-status').textContent = 'Click a source terminal';
  drawWires();
}

function cancelWireMode() {
  wireMode = false; wireSrc = null; reconnectTarget = null; pendingWireExit = null;
  vp.classList.remove('wire-mode');
  $('wire-btn').classList.remove('wire-on');
  _setWireBtnLabel('Wire');
  $('wire-badge').style.display = 'none';
  $('wep').classList.remove('open');
  clearSrcHL(); drawWires();
}

// AP-WIRE-EXIT-OVERRIDE-001 — reflects the current arrow-key exit
// override (if any) in the wire-mode status line, alongside whatever
// source/destination prompt is already showing there.
const EXIT_ARROW = { up: '↑', down: '↓', left: '←', right: '→' };
function updateWireExitStatus() {
  const el = $('wep-status');
  if (!el) return;
  const base = el.textContent.replace(/\s*· Exit override: .+$/, '');
  el.textContent = pendingWireExit
    ? `${base}  ·  Exit override: ${EXIT_ARROW[pendingWireExit]} ${pendingWireExit} (arrow keys to change, created wire only)`
    : base;
}

function clearSrcHL() {
  document.querySelectorAll('.t-dot.wf').forEach(d => d.classList.remove('wf'));
  document.querySelectorAll('.mod-card.wire-src').forEach(c => c.classList.remove('wire-src'));
}

// Change an already-created wire's source or destination terminal
// without deleting and recreating it — the sidebar/floating inspector's
// "⇄ From"/"⇄ To" buttons call this for the currently-selected wire
// (`selW`). Reuses wire mode's own visuals (badge, Done/Cancel button,
// terminal-click affordance) rather than inventing a second UI — the
// only difference from a normal wire-creation click is that
// `handleWireTerm`'s own top-of-function check below reassigns the one
// endpoint being changed instead of drawing a brand-new wire.
function startReconnectWireEnd(end) {
  if (!selW) return;
  const w = selW;
  reconnectTarget = { wireId: w.id, end };
  wireMode = true; wireSrc = null;
  vp.classList.add('wire-mode');
  $('wire-btn').classList.add('wire-on');
  _setWireBtnLabel('Done');
  $('wire-badge').style.display = 'block';
  $('wep').classList.add('open');
  $('wep-status').textContent =
    `Click the new ${end === 'from' ? 'source' : 'destination'} terminal for "${w.lbl}"`;
  drawWires();
}

function handleWireTerm(mid, tn, dot) {
  if (reconnectTarget) {
    const w = WIRES.find(x => x.id === reconnectTarget.wireId);
    const end = reconnectTarget.end;
    if (w) {
      w[end] = { m: mid, t: tn };
      selW = w;
      showToast(`"${w.lbl}" ${end === 'from' ? 'source' : 'destination'} updated`);
    }
    cancelWireMode();
    document.querySelectorAll('.mod-card').forEach(c => c.classList.remove('wire-selected'));
    if (w) {
      const fc = cardEls[w.from.m], tc = cardEls[w.to.m];
      if (fc) fc.classList.add('wire-selected');
      if (tc) tc.classList.add('wire-selected');
      showPanel(w);
    }
    drawWires();
    return;
  }
  if (!wireSrc) {
    wireSrc = { m: mid, t: tn };
    clearSrcHL(); dot.classList.add('wf');
    const card = cardEls[mid]; if (card) card.classList.add('wire-src');
    $('wep-status').textContent = `FROM: ${mid.replace(/-/g, ' ')} · ${pinLabel(mid, tn)}  →  click destination`;
    updateWireExitStatus();
    drawWires();
  } else {
    if (wireSrc.m === mid && wireSrc.t === tn) {
      clearSrcHL(); wireSrc = null;
      $('wep-status').textContent = 'Click a source terminal';
      updateWireExitStatus();
      drawWires(); return;
    }
    const dup = WIRES.find(w =>
      (w.from.m === wireSrc.m && w.from.t === wireSrc.t && w.to.m === mid && w.to.t === tn) ||
      (w.to.m   === wireSrc.m && w.to.t   === wireSrc.t && w.from.m === mid && w.from.t === tn)
    );
    if (dup) { showToast('Wire already exists', 'warn'); clearSrcHL(); wireSrc = null; $('wep-status').textContent = 'Click a source terminal'; updateWireExitStatus(); return; }
    const nw = {
      id: 'wire-' + Date.now(), c: 'W', lbl: 'New Wire',
      from: { m: wireSrc.m, t: wireSrc.t }, to: { m: mid, t: tn },
      desc: 'User-created wire',
      // AP-WIRE-EXIT-OVERRIDE-001 — `undefined` (not attached at all) when
      // no override was set, so route()/the properties dropdown both fall
      // back to the source module's own `exit` exactly as before.
      fromExit: pendingWireExit || undefined,
      R: Array.from({ length: 4 }, (_, i) => ({ VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:['Key off','Key on','Cranking','Running'][i] })),
    };
    WIRES.push(nw);
    clearSrcHL(); wireSrc = null; pendingWireExit = null;
    selW = nw; drawWires();
    showToast('Wire created — adjust its route, or edit properties');
    // Wire creation flows straight into Route Edit mode for the wire
    // just drawn — the user can drag/nudge its route immediately,
    // without leaving wire-creation flow or saving first. `wireMode` is
    // still true here; `toggleRouteEditMode()` sees that and calls
    // `cancelWireMode()` itself before turning Route Edit on, so this is
    // the same clean handoff `ctxRoute()`/the route-edit button already
    // use elsewhere — not a special case invented for this path.
    toggleRouteEditMode();
    // Closing the properties modal below (Cancel/X or Save both funnel
    // through closeWPM) used to leave Route Edit silently active
    // underneath — the idea being the user could go straight into
    // dragging the route. In practice this stranded people in Route Edit
    // mode with no obvious way out: clicking another wire kept editing
    // routes instead of just selecting/inspecting it, which reads as
    // "wire selection is broken" since the properties modal — the thing
    // that visually looked like it was the whole interaction — is gone
    // and gave no indication anything else was still active underneath.
    // This flag tells closeWPM() to also exit Route Edit for THIS
    // specific auto-opened case, without touching Route Edit entered
    // deliberately via the toolbar/right-click "Edit Route" elsewhere.
    autoRouteEditFromWireCreation = true;
    setTimeout(() => editWireProps(), 300);
  }
}

// ── Splices ───────────────────────────────────────────────────────
//
// A splice is a wire-junction point (a shared ground/power tap, or any
// point where two or more wires are physically joined) — not a pin or
// terminal on a real component. Represented as a MODULES entry with
// `splice:true` and exactly one implicit terminal ("SPLICE"), so it
// reuses the entire existing terminal/wire/routing/save-load pipeline
// unchanged (see buildSpliceCard in renderer.js). `location` is a free-
// text field describing where to physically find it on the vehicle —
// the field the user specifically needs for splices (module-editor.js's
// editModProps()/saveModProps() read/write it like `notes`).
//
// Reachable four ways:
//   1. In Wire mode, click a point on an existing wire (not a terminal) —
//      handleWireClickOnExistingWire, wired into drawWires()'s wireMode
//      hit-path branch (renderer.js).
//   2. "Splice" in the Add Module panel — openAddSplice() (module-editor.js)
//      — places a freestanding splice the user then wires up normally.
//   3/4. Right-click empty canvas, an existing wire, or a terminal ->
//      "+ Add Splice" — ctxAddSplice() below, reachable without ever
//      entering Wire mode. Right-clicking a wire inserts into it exactly
//      like #1; the canvas and terminal cases place a freestanding
//      splice like #2, at the exact click point or in-line with the
//      terminal's own exit direction respectively.

function insertSpliceOnWire(w, point, axis) {
  const id = 'splice-' + Date.now();
  const spliceMod = {
    id, label: 'Splice', sub: '', cat: 'splice', splice: true, location: '',
    // A splice always used to exit "up" regardless of where it actually
    // landed on the wire, which only matched the run's real direction by
    // chance — the rest of the time route() (renderer.js) saw a source
    // exit axis that didn't match the straight line the splice sits on,
    // and inserted an extra 90° bend right at the splice for no
    // electrical reason, needing a manual drag to straighten out every
    // time (worse with more than one wire off the same splice, since
    // each one could bend differently). `axis` — the orientation of the
    // exact route segment clicked (closestPointOnWire, renderer.js) —
    // lets the splice continue straight through the existing run by
    // default; the specific left/right or up/down choice within an axis
    // doesn't matter (exitPt only nudges the stub a few px along that
    // same line either way), only that the axis itself matches.
    exit: axis === 'h' ? 'right' : 'down',
    terminals: [{ n: 'SPLICE', c: w.c || 'W' }], _user: true,
  };
  MODULES.push(spliceMod);
  // AP-WIRE-GRID-ALIGN-001 — snapped to the nearest grid intersection
  // (not the exact clicked point): buildSpliceCard now centers the dot
  // directly ON `positions[id]` (no more +5,+5 offset), and every splice
  // — like every module terminal — needs to land on the canvas grid for
  // wires between it and other terminals to route as clean straight/
  // single-bend lines, and for AP-WIRE-TERMINAL-FAN-001's automatic
  // same-terminal separation to have a consistent geometry to work with.
  positions[id] = { x: Math.round(point.x / GRID) * GRID, y: Math.round(point.y / GRID) * GRID };
  placeCards();

  // Splicing physically means cutting the existing run at this point and
  // joining both cut ends to the new splice — so the wire being clicked
  // becomes two wires meeting at the splice, not one wire re-routed
  // through it. Both halves are created fresh with `wire-` ids (rather
  // than mutating `w` in place and keeping its original id) so both
  // reliably round-trip through saveLayout()/onLayoutFile() — which only
  // persist/restore wires whose id starts with "wire-" (project-saver.js,
  // project-loader.js) — regardless of whether the wire being spliced was
  // itself a user-created wire or one of the vehicle bundle's original
  // wires. The original wire object is removed from WIRES here; if it
  // was a bundle-original wire (not previously saved as a "wire-"
  // entry), this deletion — like any deletion of original bundle content
  // in this app — does not persist across a full reload from the bundle,
  // which reconstructs it fresh (the same pre-existing limitation
  // delModule() already has for a bundle module's wires; not something
  // newly introduced here).
  const from = { m: w.from.m, t: w.from.t };
  const to   = { m: w.to.m,   t: w.to.t   };
  const c = w.c, lbl = w.lbl, desc = w.desc, R = JSON.parse(JSON.stringify(w.R || []));
  WIRES = WIRES.filter(x => x.id !== w.id);
  delete wireRoutes[w.id];
  if (selW && selW.id === w.id) selW = null;
  const w1 = { id: 'wire-' + Date.now() + '-a', c, lbl, from, to: { m: id, t: 'SPLICE' }, desc, R: JSON.parse(JSON.stringify(R)) };
  const w2 = { id: 'wire-' + Date.now() + '-b', c, lbl, from: { m: id, t: 'SPLICE' }, to,   desc, R };
  WIRES.push(w1, w2);
  return id;
}

// AP-DIODE-SYMBOL-001 — inserts a real 2-terminal diode inline on an
// existing wire, mirroring insertSpliceOnWire's own "cut the wire here,
// join both halves to the new component" mechanics exactly — the only
// real difference is a diode has two DISTINCT terminals (Anode/Cathode),
// not one shared one, so the two halves attach to different pins
// instead of both to the same "SPLICE" terminal. The original wire's
// own `from`->`to` direction is preserved as Anode->Cathode (current
// flows from the wire's existing source into the diode's anode, out its
// cathode, and on to the existing destination) rather than an arbitrary
// choice, so the symbol's forward direction actually matches whatever
// direction the wire already represented.
function insertDiodeOnWire(w, point, axis) {
  const id = 'diode-' + Date.now();
  const c = w.c || 'W';
  const diodeMod = {
    id, label: 'Diode', sub: '', cat: 'diode', diode: true,
    vertical: axis === 'v',
    exit: axis === 'h' ? 'right' : 'down',
    terminals: [{ n: 'A', c }, { n: 'K', c }], _user: true,
  };
  MODULES.push(diodeMod);
  // AP-WIRE-GRID-ALIGN-001 — same grid-snap insertSpliceOnWire's own
  // placement uses, and for the same reason (every terminal needs to
  // land on the canvas grid for wires to route as clean straight/
  // single-bend lines).
  positions[id] = { x: Math.round(point.x / GRID) * GRID, y: Math.round(point.y / GRID) * GRID };
  placeCards();

  const from = { m: w.from.m, t: w.from.t };
  const to   = { m: w.to.m,   t: w.to.t   };
  const lbl = w.lbl, desc = w.desc, R = JSON.parse(JSON.stringify(w.R || []));
  WIRES = WIRES.filter(x => x.id !== w.id);
  delete wireRoutes[w.id];
  if (selW && selW.id === w.id) selW = null;
  const w1 = { id: 'wire-' + Date.now() + '-a', c, lbl, from, to: { m: id, t: '1' }, desc, R: JSON.parse(JSON.stringify(R)) };
  const w2 = { id: 'wire-' + Date.now() + '-b', c, lbl, from: { m: id, t: '2' }, to,   desc, R };
  WIRES.push(w1, w2);
  drawWires();
  const toLabel = MODULES.find(x => x.id === to.m)?.label || to.m;
  showToast(`Diode added — forward direction toward ${toLabel}`);
  return id;
}

// The context-menu "+ Add Splice" entry (index.html's #ctx-add-splice) —
// dispatches on the shape of `ctxTarget`/`ctxClickPoint` (both set by
// whichever contextmenu handler opened #ctx: canvas background,
// module-editor.js; a wire, renderer.js; a terminal, setupTermClicks
// above) to whichever of this file's three placement mechanisms applies.
function ctxAddSplice() {
  const target = ctxTarget, point = ctxClickPoint;
  hideCtx();
  if (!target) return;
  if (target._bg) {
    // Empty canvas: a freestanding splice at the exact right-clicked
    // point, same as the Add Module panel's own "Splice" entry but
    // without that extra trip through the panel.
    pendingAddPosition = point;
    openAddSplice();
    return;
  }
  if (target._term) {
    // A terminal: place a freestanding splice offset from it along its
    // OWN exit direction, and give the splice that same axis, so it
    // sits ready to continue a run straight out from that terminal
    // before any wire to it exists yet (§ this file's own doc comment
    // above insertSpliceOnWire for why axis-matching matters here the
    // same way it does when splicing an existing wire).
    const pos = getPos(target.mid, target.tn);
    if (!pos) return;
    const dir = exitDir(target.mid, target.tn);
    const OFFSET = 40; // world units — clear of the terminal's own card, not just its stub
    const delta = dir === 'up' ? { x: 0, y: -OFFSET } : dir === 'down' ? { x: 0, y: OFFSET }
                : dir === 'left' ? { x: -OFFSET, y: 0 } : { x: OFFSET, y: 0 };
    // AP-WIRE-GRID-ALIGN-001 — `_takeAddPosition()` (module-editor.js)
    // re-snaps this to GRID unconditionally anyway; rounding to the same
    // unit here too is just for clarity, not load-bearing.
    pendingAddPosition = { x: Math.round((pos.x + delta.x) / GRID) * GRID, y: Math.round((pos.y + delta.y) / GRID) * GRID };
    openAddSplice(dir === 'left' || dir === 'right' ? 'right' : 'down');
    return;
  }
  // Otherwise `target` is the wire object itself (renderer.js's wire
  // contextmenu sets `ctxTarget = w` directly, same convention ctxEdit/
  // ctxTrace/ctxRoute already rely on) and `point` is closestPointOnWire's
  // own {point, dist, axis} result, captured at right-click time.
  if (!point) return;
  insertSpliceOnWire(target, point.point, point.axis);
  placeCards(); drawWires();
  showToast('Splice added — now wire it up');
}

// AP-DIODE-SYMBOL-001 — the context-menu "+ Add Diode" entry (index.
// html's #ctx-add-diode). Unlike splices, a diode only ever makes sense
// already wired into a circuit (it has a real forward direction to
// preserve), so this only handles the wire case — right-click an
// existing wire's own contextmenu (renderer.js) is the only place this
// menu item is shown at all.
function ctxAddDiode() {
  const target = ctxTarget, point = ctxClickPoint;
  hideCtx();
  if (!target || !point) return;
  insertDiodeOnWire(target, point.point, point.axis === 'h' ? 'h' : 'v');
}

// In Wire mode, clicking a point on an existing wire (rather than a
// terminal) either starts the new wire from a splice inserted there, or
// — if a source terminal/splice was already picked — completes the new
// wire onto a splice inserted there. Mirrors handleWireTerm's own
// two-branch shape.
function handleWireClickOnExistingWire(w, evt) {
  const cr = canvas.getBoundingClientRect();
  const mx = (evt.clientX - cr.left) / scale, my = (evt.clientY - cr.top) / scale;
  const hit = closestPointOnWire(w, mx, my);
  if (!hit) return;
  const spliceId = insertSpliceOnWire(w, hit.point, hit.axis);
  if (!wireSrc) {
    wireSrc = { m: spliceId, t: 'SPLICE' };
    clearSrcHL();
    const card = cardEls[spliceId]; if (card) card.classList.add('wire-src');
    $('wep-status').textContent = 'FROM: Splice  →  click destination';
    drawWires();
    showToast('Splice added — now click the destination');
  } else {
    handleWireTerm(spliceId, 'SPLICE', null);
  }
}

// ── Delete wire ───────────────────────────────────────────────────

function deleteSelectedWire() {
  if (!selW) return;
  if (!confirm(`Delete wire: "${selW.lbl}"?`)) return;
  WIRES = WIRES.filter(w => w.id !== selW.id);
  delete wireRoutes[selW.id];
  selW = null; closePanel();
  leadR = null; leadB = null; clearLeadDots(); tracedWires.clear();
  if (routeEditMode) exitRouteEditMode();
  drawWires(); showToast('Wire deleted');
}

// ── Wire properties modal ─────────────────────────────────────────

function editWireProps() {
  if (!selW) return; const w = selW;
  $('wpm-color').value = w.c   || '';
  $('wpm-label').value = w.lbl || '';
  $('wpm-desc').value  = w.desc || '';
  $('wpm-exit').value  = w.fromExit || '';
  $('wpm-cable').checked = !!w.cable;
  const KN = ['Off/Off', 'On/Off', 'Cranking', 'Running'];
  $('wpm-body').innerHTML = KN.map((kn, i) => {
    const r = w.R && w.R[i] ? w.R[i] : { VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:'' };
    return `<tr style="color:#ccc"><td style="color:#555;font-size:7px;padding:3px 2px">${kn}</td>
      ${['VDC','VAC','CONT','RES','DIODE'].map(f => `<td><input class="fi" style="width:56px;padding:2px 3px;font-size:8px" data-ri="${i}" data-rf="${f}" value="${r[f]||''}"/></td>`).join('')}
      <td><input class="fi" style="width:80px;padding:2px 3px;font-size:8px" data-ri="${i}" data-rf="note" value="${r.note||''}"/></td></tr>`;
  }).join('');
  $('wpm').classList.add('open');
}

// AP-BATTERY-CABLE-001 — a battery cable is only ever Red or Black in
// real automotive wiring (never a striped/two-tone code) — checking the
// box snaps Color Code straight to a valid value instead of leaving it
// free-text and validating on Save, so there's no invalid in-between
// state to hit at all.
function onWpmCableChange() {
  if (!$('wpm-cable').checked) return;
  const cur = $('wpm-color').value.trim();
  if (cur !== 'R' && cur !== 'Bl') $('wpm-color').value = 'R';
}

let autoRouteEditFromWireCreation = false;
function closeWPM() {
  $('wpm').classList.remove('open');
  if (autoRouteEditFromWireCreation) {
    autoRouteEditFromWireCreation = false;
    if (routeEditMode) exitRouteEditMode();
  }
}

function saveWireProps() {
  if (!selW) return; const w = selW;
  const newLbl = $('wpm-label').value.trim() || w.lbl;
  // Wire label isn't used to look up a specific wire anywhere (every wire
  // is matched by its own generated `id`), but it IS the only thing that
  // tells two wires apart in every list that shows label instead of id
  // (the sidebar's own wire list, a module's terminal wire-links, the
  // Wire Properties modal's own title) — leaving two wires on the same
  // label (most often because a new wire never got renamed off "New
  // Wire") makes them indistinguishable there with no indication
  // anything's wrong. Blocked outright rather than just warned, per
  // direct request — a warning was proven too easy to miss/ignore in
  // practice.
  const dupLabel = WIRES.find(x => x.id !== w.id && x.lbl === newLbl);
  if (dupLabel) {
    showToast(`Label "${newLbl}" is already used by another wire ("${dupLabel.desc || dupLabel.id}") — choose a unique label`, 'warn');
    return;
  }
  const newColor = $('wpm-color').value.trim() || w.c;
  // AP-BATTERY-CABLE-001 — blocked outright, same "block don't just
  // warn" convention the label-uniqueness check above already
  // established this session — a real battery cable is never anything
  // but Red or Black, and onWpmCableChange() already prevents this from
  // happening through the checkbox itself; this only catches someone
  // re-typing Color Code by hand afterward.
  const isCable = $('wpm-cable').checked;
  if (isCable && newColor !== 'R' && newColor !== 'Bl') {
    showToast('Battery Cable must be Red ("R") or Black ("Bl") — fix Color Code or uncheck Battery Cable', 'warn');
    return;
  }
  w.c   = newColor;
  w.lbl = newLbl;
  w.desc = $('wpm-desc').value.trim();
  w.cable = isCable || undefined;
  // AP-WIRE-EXIT-OVERRIDE-001 — `''` (Auto) clears any per-wire override
  // and falls back to the module/splice's own exit() side again.
  w.fromExit = $('wpm-exit').value || undefined;
  if (!w.R) w.R = [{},{},{},{}];
  document.querySelectorAll('#wpm-body input').forEach(inp => {
    const ri = +inp.dataset.ri, rf = inp.dataset.rf;
    if (!w.R[ri]) w.R[ri] = {};
    w.R[ri][rf] = inp.value;
  });
  closeWPM(); drawWires(); updatePanel(w);
  showToast('Wire properties saved');
}

// AP-TERMINAL-EXIT-001 — called from a NON-splice module's own sidebar
// inspector (Sidebar._renderModInfoInSidebar) to set ONE terminal's own
// entry/exit direction, without needing to select a wire and open its
// own Wire Properties modal first. Originally per-wire
// (AP-SPLICE-INSPECTOR-001/AP-MODULE-WIRE-EXIT-001); corrected per direct
// feedback to live on the TERMINAL instead — a wire doesn't get to
// choose which side it leaves from, the physical pin does, and storing
// it per-wire meant re-wiring a pin silently dropped whatever direction
// had been set. `pinRef` is the wire endpoint's own stored ref on this
// module (`w.from.t`/`w.to.t` — a bare pin number, or a connector's
// `N_IN`/`N_OUT`); `terminalIdxForRef` (renderer.js) strips any `_IN`/
// `_OUT` suffix to resolve the actual terminal object, since both halves
// of a connector pin share one physical exit point (§ `effectiveExitFor`'s
// own doc comment, renderer.js, for how this interacts with the older,
// still-honored per-wire `fromExit`/`toExit` override).
//
// NOT used for a splice — reported directly as having no effect: a
// splice's terminal ref is always the literal string `"SPLICE"`
// (buildSpliceCard, renderer.js), which `terminalIdxForRef` can't resolve
// to a numeric index at all (silently no-ops), and even if it could, a
// splice's WHOLE JOB is being the one point several DIFFERENT wires
// converge on — they all share that same one terminal, so a per-terminal
// exit would force every wire on the splice to the same side, exactly
// undoing the "each wire needs its own side" reason this control exists
// in the first place. See `setSpliceWireExit` below, which
// Sidebar._renderModInfoInSidebar calls instead whenever `m.splice`.
function setTerminalExit(mid, pinRef, value) {
  const m = MODULES.find(x => x.id === mid);
  if (!m || !m.terminals) return;
  const idx = terminalIdxForRef(pinRef);
  const t = idx >= 0 ? m.terminals[idx] : null;
  if (!t) return;
  t.exit = value || undefined;
  drawWires();
  if (typeof Sidebar !== 'undefined') Sidebar._renderModInfoInSidebar(m);
}

// AP-SPLICE-INSPECTOR-001 — restored per-wire exit control, splice-only:
// unlike setTerminalExit above, a splice's multiple wires genuinely each
// need their OWN independent exit side (that's the entire point of a
// splice — several wires converging on one physical point, never all
// leaving the same direction in real wiring), so this sets `w.fromExit`/
// `w.toExit` directly on the WIRE, exactly like the original
// splice-only version of this feature did, before AP-TERMINAL-EXIT-001
// moved every OTHER module's own exit control onto the terminal instead.
// `mid` is the splice being inspected — whichever end of `wireId`
// actually equals it (from or to) is the end that gets the override
// (§ route()'s own doc comment on `w.toExit` for why both ends need
// this, not just `fromExit`).
function setSpliceWireExit(wireId, mid, value) {
  const w = WIRES.find(x => x.id === wireId);
  if (!w) return;
  if (w.from.m === mid) w.fromExit = value || undefined;
  else if (w.to.m === mid) w.toExit = value || undefined;
  else return;
  drawWires();
  const m = MODULES.find(x => x.id === mid);
  if (m && typeof Sidebar !== 'undefined') Sidebar._renderModInfoInSidebar(m);
}
