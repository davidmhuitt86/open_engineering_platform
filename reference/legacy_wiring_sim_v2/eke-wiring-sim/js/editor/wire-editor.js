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

function setupTermClicks(card) {
  card.querySelectorAll('.t-dot').forEach(dot => {
    dot.addEventListener('click', e => {
      e.stopPropagation();
      const mid = dot.dataset.mid, tn = dot.dataset.tn;
      if (!mid || !tn) return;
      if (wireMode)      { handleWireTerm(mid, tn, dot); return; }
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
    dot.addEventListener('mouseenter', () => { if ((wireMode && wireSrc) || leadPlaceMode) dot.classList.add('wh'); });
    dot.addEventListener('mouseleave', () => dot.classList.remove('wh'));
  });
}

// ── Wire mode ─────────────────────────────────────────────────────

function toggleWireMode() {
  wireMode = !wireMode;
  if (wireMode && editMode) toggleEdit();
  if (wireMode && routeEditMode) exitRouteEditMode();
  vp.classList.toggle('wire-mode', wireMode);
  $('wire-btn').classList.toggle('wire-on', wireMode);
  $('wire-btn').textContent     = wireMode ? '⚡ Done' : '⚡ Wire';
  $('wire-badge').style.display = wireMode ? 'block'  : 'none';
  $('wep').classList.toggle('open', wireMode);
  if (!wireMode) { wireSrc = null; clearSrcHL(); }
  else $('wep-status').textContent = 'Click a source terminal';
  drawWires();
}

function cancelWireMode() {
  wireMode = false; wireSrc = null;
  vp.classList.remove('wire-mode');
  $('wire-btn').classList.remove('wire-on');
  $('wire-btn').textContent     = '⚡ Wire';
  $('wire-badge').style.display = 'none';
  $('wep').classList.remove('open');
  clearSrcHL(); drawWires();
}

function clearSrcHL() {
  document.querySelectorAll('.t-dot.wf').forEach(d => d.classList.remove('wf'));
  document.querySelectorAll('.mod-card.wire-src').forEach(c => c.classList.remove('wire-src'));
}

function handleWireTerm(mid, tn, dot) {
  if (!wireSrc) {
    wireSrc = { m: mid, t: tn };
    clearSrcHL(); dot.classList.add('wf');
    const card = cardEls[mid]; if (card) card.classList.add('wire-src');
    $('wep-status').textContent = `FROM: ${mid.replace(/-/g, ' ')} · ${tn}  →  click destination`;
    drawWires();
  } else {
    if (wireSrc.m === mid && wireSrc.t === tn) {
      clearSrcHL(); wireSrc = null;
      $('wep-status').textContent = 'Click a source terminal';
      drawWires(); return;
    }
    const dup = WIRES.find(w =>
      (w.from.m === wireSrc.m && w.from.t === wireSrc.t && w.to.m === mid && w.to.t === tn) ||
      (w.to.m   === wireSrc.m && w.to.t   === wireSrc.t && w.from.m === mid && w.from.t === tn)
    );
    if (dup) { showToast('Wire already exists', 'warn'); clearSrcHL(); wireSrc = null; $('wep-status').textContent = 'Click a source terminal'; return; }
    const nw = {
      id: 'wire-' + Date.now(), c: 'W', lbl: 'New Wire',
      from: { m: wireSrc.m, t: wireSrc.t }, to: { m: mid, t: tn },
      desc: 'User-created wire',
      R: Array.from({ length: 4 }, (_, i) => ({ VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:['Key off','Key on','Cranking','Running'][i] })),
    };
    WIRES.push(nw);
    clearSrcHL(); wireSrc = null;
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
    // The properties modal (#wpm) is a full-screen overlay, so it still
    // makes sense to offer it right after creation (rename from "New
    // Wire", set a color code) — closing it leaves Route Edit already
    // active underneath, so the very next thing the user can do is drag
    // the route with no extra clicks.
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
// Reachable two ways:
//   1. In Wire mode, click a point on an existing wire (not a terminal) —
//      handleWireClickOnExistingWire, wired into drawWires()'s wireMode
//      hit-path branch (renderer.js).
//   2. "Splice" in the Add Module panel — openAddSplice() (module-editor.js)
//      — places a freestanding splice the user then wires up normally.

function insertSpliceOnWire(w, point) {
  const id = 'splice-' + Date.now();
  const spliceMod = {
    id, label: 'Splice', sub: '', cat: 'splice', splice: true, location: '',
    exit: 'up', terminals: [{ n: 'SPLICE', c: w.c || 'W' }], _user: true,
  };
  MODULES.push(spliceMod);
  // Center the splice's dot (see buildSpliceCard: a bare 10x10 circle,
  // no card padding) exactly on the clicked point on the wire.
  positions[id] = { x: Math.round(point.x - 5), y: Math.round(point.y - 5) };
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
  const spliceId = insertSpliceOnWire(w, hit.point);
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
  const KN = ['Off/Off', 'On/Off', 'Cranking', 'Running'];
  $('wpm-body').innerHTML = KN.map((kn, i) => {
    const r = w.R && w.R[i] ? w.R[i] : { VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:'' };
    return `<tr style="color:#ccc"><td style="color:#555;font-size:7px;padding:3px 2px">${kn}</td>
      ${['VDC','VAC','CONT','RES','DIODE'].map(f => `<td><input class="fi" style="width:56px;padding:2px 3px;font-size:8px" data-ri="${i}" data-rf="${f}" value="${r[f]||''}"/></td>`).join('')}
      <td><input class="fi" style="width:80px;padding:2px 3px;font-size:8px" data-ri="${i}" data-rf="note" value="${r.note||''}"/></td></tr>`;
  }).join('');
  $('wpm').classList.add('open');
}

function closeWPM() { $('wpm').classList.remove('open'); }

function saveWireProps() {
  if (!selW) return; const w = selW;
  w.c   = $('wpm-color').value.trim() || w.c;
  w.lbl = $('wpm-label').value.trim() || w.lbl;
  w.desc = $('wpm-desc').value.trim();
  if (!w.R) w.R = [{},{},{},{}];
  document.querySelectorAll('#wpm-body input').forEach(inp => {
    const ri = +inp.dataset.ri, rf = inp.dataset.rf;
    if (!w.R[ri]) w.R[ri] = {};
    w.R[ri][rf] = inp.value;
  });
  closeWPM(); drawWires(); updatePanel(w);
  showToast('Wire properties saved');
}
