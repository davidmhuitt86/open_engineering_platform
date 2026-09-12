/**
 * editor/module-editor.js
 *
 * Module drag (layout edit), add/delete/edit modules,
 * the module panel drawer, and module property modal.
 *
 * Reads/writes: MODULES, WIRES, positions, cardEls globals.
 * Calls: placeCards, drawWires, buildLegend, showToast, rebuildCard (renderer).
 *
 * No electrical calculations. No wire routing. No simulation.
 */

// ── Drag (layout edit) ────────────────────────────────────────────

function setupDrag(card, modId) {
  let drag = false, ox = 0, oy = 0, sx = 0, sy = 0;
  // AP-MASTER-EDIT-001 — `moved`/`downEvt` are what let a single mousedown
  // in Edit Mode serve BOTH click (show properties) and hold-drag
  // (reposition) instead of forcing a separate toggle for each, per
  // direct request: "single click... property panel pops up, if i single
  // click and hold... it will allow me to reposition it." `moved` flips
  // true only once the pointer has actually travelled past
  // DRAG_CLICK_THRESHOLD; until then nothing about the module's position
  // changes at all, so a plain click never nudges it even by a stray
  // pixel of mouse jitter.
  let moved = false, downEvt = null;
  const DRAG_CLICK_THRESHOLD = 4; // px, raw screen space (pre-scale)
  // Splice-only alignment guide (direct user request): drag a splice
  // near another terminal and hold there briefly, and its X or Y
  // (whichever the cursor is already closer to matching) locks onto
  // that terminal's exact coordinate, shown as a live dashed guide line
  // — you can then keep moving the splice further along that same line
  // to wherever you actually want it before releasing, and only that
  // one axis snaps to the terminal on drop. Only meaningful for a
  // splice: it's the one module whose whole job is sitting exactly
  // in-line with something else, and it's the only module type dense
  // enough (see the .t-dot drag exemption just above) that click-and-
  // hold-to-drag even applies directly to its terminal dot.
  // Dwell timing runs off requestAnimationFrame + performance.now(), not
  // setTimeout — confirmed live that a setTimeout scheduled mid-drag can
  // sit throttled well past its requested delay (a standard browser
  // background/inactive-page timer policy), which would make "hold
  // still for ~1.2s" sometimes just never fire, reading as "hovering
  // over a terminal does nothing." rAF polling re-checks elapsed real
  // time every frame instead of depending on one timer callback ever
  // firing on schedule.
  let hoverCandidate = null, hoverSince = 0, alignLock = null, curNx = 0, curNy = 0, rafId = null;
  const ALIGN_DWELL_MS = 1200, ALIGN_HOVER_RADIUS = 22;
  function clearAlignGuide() { const g = document.getElementById('align-guide'); if (g) g.remove(); }
  function alignTick() {
    if (!drag) return;
    if (hoverCandidate && !(alignLock && alignLock.mid === hoverCandidate.mid && alignLock.tn === hoverCandidate.tn)
        && performance.now() - hoverSince >= ALIGN_DWELL_MS) {
      const termPos = getPos(hoverCandidate.mid, hoverCandidate.tn);
      if (termPos) {
        const dxAbs = Math.abs(curNx - termPos.x), dyAbs = Math.abs(curNy - termPos.y);
        alignLock = { mid: hoverCandidate.mid, tn: hoverCandidate.tn, axis: dxAbs < dyAbs ? 'x' : 'y' };
        drawAlignGuide();
      }
    }
    rafId = requestAnimationFrame(alignTick);
  }
  function drawAlignGuide() {
    if (!alignLock) { clearAlignGuide(); return; }
    const termPos = getPos(alignLock.mid, alignLock.tn);
    if (!termPos) { clearAlignGuide(); return; }
    let line = document.getElementById('align-guide');
    if (!line) {
      line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      line.id = 'align-guide';
      line.setAttribute('stroke', '#22d3ee'); line.setAttribute('stroke-width', '1.5');
      line.setAttribute('stroke-dasharray', '5 4'); line.style.pointerEvents = 'none';
      wsvg.appendChild(line);
    }
    if (alignLock.axis === 'x') {
      line.setAttribute('x1', termPos.x); line.setAttribute('y1', termPos.y);
      line.setAttribute('x2', termPos.x); line.setAttribute('y2', curNy);
    } else {
      line.setAttribute('x1', termPos.x); line.setAttribute('y1', termPos.y);
      line.setAttribute('x2', curNx); line.setAttribute('y2', termPos.y);
    }
  }
  card.addEventListener('mousedown', e => {
    if (!editMode) return;
    // A splice's ENTIRE visible card is its one terminal dot
    // (buildSpliceCard, renderer.js — a bare circle, no other surface) —
    // excluding any click that lands on `.t-dot` (below, so a terminal
    // click can start a wire instead of a drag) left a splice with
    // literally no clickable area left to drag it BY, since it has
    // nothing else to click. Wiring is already gated off in edit mode
    // (setupTermClicks's own `if (editMode) return`), so a terminal-dot
    // click can only mean "drag" here for a splice specifically — every
    // other module still keeps its own separate draggable card body.
    const mod = MODULES.find(m => m.id === modId);
    if (e.target.closest('.t-dot') && !(mod && mod.splice)) return;
    drag = true; moved = false; downEvt = e;
    const r = card.getBoundingClientRect(), sr = scene.getBoundingClientRect();
    ox = (r.left - sr.left) / scale;
    oy = (r.top  - sr.top)  / scale;
    sx = e.clientX; sy = e.clientY;
    e.preventDefault(); e.stopPropagation();
  });
  window.addEventListener('mousemove', e => {
    if (!drag) return;
    // AP-MASTER-EDIT-001 — nothing about the module's position (or the
    // splice alignment-guide machinery below) engages until the pointer
    // has actually moved past DRAG_CLICK_THRESHOLD — see this function's
    // own doc comment on `moved`/`downEvt` for why.
    if (!moved) {
      if (Math.hypot(e.clientX - sx, e.clientY - sy) < DRAG_CLICK_THRESHOLD) return;
      moved = true;
      hoverCandidate = null; alignLock = null; clearAlignGuide();
      cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(alignTick);
      card.classList.add('dragging'); card.style.zIndex = 200;
    }
    // AP-WIRE-GRID-ALIGN-001 — snaps to GRID (20px, renderer.js — matches
    // #canvas's own visible grid), not the old 10px increment. Every card
    // type now places its terminals at a fixed GRID-multiple offset from
    // this exact anchor point (buildStdCard/buildConnCard/buildBulbCard),
    // so snapping the anchor itself to GRID is what makes every terminal
    // land on a real grid intersection — see GRID's own doc comment.
    const nx = Math.round(Math.max(0, ox + (e.clientX - sx) / scale) / GRID) * GRID;
    const ny = Math.round(Math.max(0, oy + (e.clientY - sy) / scale) / GRID) * GRID;
    curNx = nx; curNy = ny;
    card.style.left = nx + 'px'; card.style.top = ny + 'px';
    positions[modId] = { x: nx, y: ny };
    drawWires(); // wipes/rebuilds #wire-layer, so the guide below is (re)drawn AFTER this every tick

    const mod = MODULES.find(m => m.id === modId);
    if (mod && mod.splice) {
      let best = null, bestD = Infinity;
      document.querySelectorAll('.t-dot').forEach(d => {
        if (d.dataset.mid === modId) return; // never align a splice to its own dot
        const r = d.getBoundingClientRect();
        const dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
        const dist = Math.hypot(dx, dy);
        if (dist < bestD) { bestD = dist; best = { mid: d.dataset.mid, tn: d.dataset.tn }; }
      });
      const cand = (best && bestD <= ALIGN_HOVER_RADIUS) ? best : null;
      const sameAsPending = cand && hoverCandidate && cand.mid === hoverCandidate.mid && cand.tn === hoverCandidate.tn;
      if (!sameAsPending) {
        // Cursor moved onto a different terminal (or off all of them) —
        // restart the dwell clock (alignTick's rAF loop reads
        // hoverSince); a lock already in effect from a PREVIOUS terminal
        // deliberately stays live until this new dwell completes, not
        // the instant the cursor leaves it, so drifting slightly off
        // target mid-drag doesn't throw away an alignment you're
        // actively using.
        hoverCandidate = cand;
        hoverSince = performance.now();
      }
      if (alignLock) drawAlignGuide(); else clearAlignGuide();
    }
  });
  window.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = false;
    // AP-MASTER-EDIT-001 — mouseup without ever crossing the drag
    // threshold means this was a plain click, not a reposition. selMod()
    // alone only shows a READ-ONLY summary in the sidebar (with its own
    // separate "✎ Edit" button buried inside it) — reported directly as
    // not actually being what "the property panel pops up... in order to
    // edit it" meant. Opening editModProps() directly is the real,
    // editable panel this whole feature was asked for; selMod() is still
    // called first for its own side effects (card highlight, clearing
    // any active wire selection) that editModProps() alone doesn't do.
    if (!moved) { selMod(modId, downEvt); editModProps(modId); return; }
    cancelAnimationFrame(rafId);
    card.classList.remove('dragging'); card.style.zIndex = '';
    if (alignLock) {
      const termPos = getPos(alignLock.mid, alignLock.tn);
      if (termPos) {
        const p = positions[modId];
        if (alignLock.axis === 'x') p.x = Math.round(termPos.x); else p.y = Math.round(termPos.y);
        card.style.left = p.x + 'px'; card.style.top = p.y + 'px';
      }
    }
    clearAlignGuide(); alignLock = null; hoverCandidate = null;
    drawWires();
  });
  card.addEventListener('contextmenu', e => {
    e.preventDefault(); e.stopPropagation();
    ctxTarget = { _mid: modId };
    $('ctx-add-module').style.display = 'none';
    $('ctx-add-splice').style.display = 'none';
    $('ctx-del').style.display = '';
    $('ctx-route').style.display = 'none';
    if (editMode) {
      $('ctx-edit').style.display = 'none'; $('ctx-trace').style.display = 'none';
    } else {
      $('ctx-edit').style.display = ''; $('ctx-edit').textContent = '✎ Edit Module';
      $('ctx-trace').style.display = 'none';
    }
    const mod = MODULES.find(x => x.id === modId);
    // AP-MODULE-LAYOUT-001 — Rotate used to only show for a connector
    // (the only type that supported a vertical layout); available for
    // any non-splice module now.
    $('ctx-rotate').style.display = (mod && !mod.splice && !editMode) ? '' : 'none';
    $('ctx-del').textContent = '✕ Delete Module';
    openCtxAt(e.clientX, e.clientY);
  });
  card.addEventListener('click', e => {
    if (editMode || wireMode || routeEditMode) return;
    // A splice's ENTIRE visible card is its one terminal dot
    // (buildSpliceCard, renderer.js) — the same reason this mousedown
    // handler above already exempts splices from the `.t-dot` drag
    // exclusion. Without the same exemption here, EVERY click on a
    // splice hit this `.t-dot` guard and returned before ever calling
    // selMod(), so a splice could never be selected/inspected at all —
    // reported directly ("click a splice and it doesn't show anything
    // in the property inspector").
    const mod = MODULES.find(m => m.id === modId);
    if (e.target.closest('.t-dot') && !(mod && mod.splice)) return;
    e.stopPropagation();
    selMod(modId, e);
  });
}

// Right-click on empty canvas space -> "+ Add Module" — every module
// card's own contextmenu handler above, and every wire's own (renderer.js
// buildConnCard's wire-hit path), call e.stopPropagation(), so this only
// ever fires for a genuine background click, never bubbles from either.
canvas.addEventListener('contextmenu', e => {
  if (e.target !== canvas) return;
  e.preventDefault();
  const cr = canvas.getBoundingClientRect();
  // AP-WIRE-GRID-ALIGN-001 — `_takeAddPosition()` re-snaps to GRID
  // unconditionally regardless; rounding to the same unit here too is
  // just for clarity, not load-bearing.
  const x = Math.round((e.clientX - cr.left) / scale / GRID) * GRID;
  const y = Math.round((e.clientY - cr.top)  / scale / GRID) * GRID;
  ctxTarget = { _bg: true, x, y };
  ctxClickPoint = { x, y };
  $('ctx-edit').style.display = 'none';
  $('ctx-trace').style.display = 'none';
  $('ctx-route').style.display = 'none';
  $('ctx-rotate').style.display = 'none';
  $('ctx-del').style.display = 'none';
  $('ctx-add-module').style.display = '';
  $('ctx-add-splice').style.display = '';
  openCtxAt(e.clientX, e.clientY);
});

// ── Edit mode toggle ──────────────────────────────────────────────

function toggleEdit() {
  editMode = !editMode;
  if (editMode && wireMode) cancelWireMode();
  // AP-MASTER-EDIT-001 — Edit Mode no longer exits routeEditMode on
  // entry: it now covers wire route editing itself (wireEditCapable,
  // renderer.js), so the two are meant to coexist, not cancel each
  // other. `routeEditMode` staying off during editMode is fine — it
  // remains a separate, narrower toggle mostly relevant when Edit Mode
  // itself is off.
  vp.classList.toggle('edit-mode', editMode);
  $('edit-btn').classList.toggle('edit-on', editMode);
  // OEP-STUDIO-BRANDING-V1 — targets the label span, not the whole
  // button: #edit-btn (now the toolbar's direct "Select" button) also
  // has a real SVG icon child, which a plain `.textContent =`
  // assignment here would silently delete.
  const editBtnLbl = $('edit-btn').querySelector('.tb-icon-btn-lbl');
  if (editBtnLbl) editBtnLbl.textContent = editMode ? 'Done' : 'Select';
  else $('edit-btn').textContent = editMode ? '✦ Done' : '✦ Select';
  $('edit-badge').style.display = editMode ? 'block' : 'none';
  // AP-MASTER-EDIT-001 — used to unconditionally clear the current wire
  // selection/panel the moment Edit Mode turned on, back when Edit Mode
  // ("Layout Edit") had nothing to do with wires at all. Now that a
  // selected wire's segments become draggable as soon as Edit Mode is on
  // (per direct request), clearing the selection here would immediately
  // hide the very panel/handles someone turned Edit Mode on to use.
  // Selection now persists across this toggle in both directions.
  drawWires();
}

// ── Module panel drawer ───────────────────────────────────────────

function openModPanel()  { mpOpen = !mpOpen; $('mod-panel').classList.toggle('open', mpOpen); if (mpOpen) renderModPanel(); }
function closeModPanel() { mpOpen = false; $('mod-panel').classList.remove('open'); }

const PRESETS = [
  // AP-POWER-POST-001 — restyled to the box-with-two-posts look (per
  // direct request: "maybe the battery should be similarly shaped" as
  // the new starter solenoid/motor symbols) — `battery:true` switches
  // buildCard (renderer.js) to buildBatteryCard instead of the generic
  // std-card layout; `post:true` on each terminal drops its pin-number
  // label in favor of the customizable `n` field ("+"/"−" here).
  { label:'Battery',      sub:'12V Lead-Acid',   cat:'power',    exit:'up',    battery:true, terminals:[{n:'+',c:'R',post:true},{n:'−',c:'Bl',post:true}] },
  { label:'Fuse Block',   sub:'ATC Fuses',        cat:'power',    exit:'down',  terminals:[{n:'IN',c:'R'},{n:'F1',c:'R'},{n:'F2',c:'R'},{n:'F3',c:'R'}] },
  { label:'Relay SPDT',   sub:'12V 30A',          cat:'control',  exit:'up',    terminals:[{n:'85',c:'Bl'},{n:'86',c:'R'},{n:'87',c:'G'},{n:'87A',c:'Y'},{n:'30',c:'R'}] },
  { label:'Ground Point', sub:'Chassis',          cat:'ground',   exit:'up',    terminals:[{n:'GND',c:'G'}] },
  { label:'Switch SPST',  sub:'On/Off',           cat:'switch',   exit:'up',    terminals:[{n:'IN',c:'W'},{n:'OUT',c:'W'}] },
  { label:'Switch DPDT',  sub:'6-Terminal',       cat:'switch',   exit:'up',    terminals:[{n:'C1',c:'W'},{n:'NO1',c:'Y'},{n:'NC1',c:'R'},{n:'C2',c:'W'},{n:'NO2',c:'Y'},{n:'NC2',c:'R'}] },
  { label:'LED Indicator',sub:'12V',              cat:'indicator',exit:'down',  terminals:[{n:'+',c:'R'},{n:'-',c:'Bl'}] },
  { label:'Sensor 2W',    sub:'Sig+GND',          cat:'control',  exit:'up',    terminals:[{n:'SIG',c:'W'},{n:'GND',c:'G'}] },
  { label:'Sensor 3W',    sub:'Pwr+Sig+GND',      cat:'control',  exit:'up',    terminals:[{n:'PWR',c:'R'},{n:'SIG',c:'W'},{n:'GND',c:'G'}] },
  { label:'DC Motor',     sub:'12V',              cat:'starter',  exit:'up',    terminals:[{n:'B+',c:'R'},{n:'GND',c:'G'}] },
  { label:'Solenoid',     sub:'12V Pull',         cat:'control',  exit:'up',    terminals:[{n:'+',c:'R'},{n:'-',c:'G'}] },
  // AP-POWER-POST-001 — starter motor: circle body + "M", one main power
  // post and a real, wireable chassis-ground terminal (buildStarterMotorCard,
  // renderer.js) — per direct request + reference photo, distinct from
  // the generic "DC Motor" preset above (no pin-number labels on either
  // terminal here; both are `post:true`).
  { label:'Starter Motor',sub:'12V Cranking',     cat:'starter',  exit:'up',    starterMotor:true, terminals:[{n:'B+',c:'R',post:true},{n:'GND',c:'Bl',post:true}] },
  // AP-POWER-POST-001 — starter solenoid/relay switch: two main power
  // posts (no pin-number label) plus a coil that drops to a normal,
  // pin-numbered control terminal (buildSolenoidCard, renderer.js) — per
  // direct request + reference photo, distinct from the generic "pull"
  // Solenoid preset above.
  // AP-POWER-POST-001 — per reference photo correction: BAT/MTR posts
  // with the two coil pins IN BETWEEN them (not off on their own), real
  // left-to-right order, all four terminals exiting the same direction.
  { label:'Starter Solenoid',sub:'Relay Switch',  cat:'control',  exit:'up',    solenoid:true, terminals:[{n:'BAT',c:'R',post:true},{n:'C1',c:'Y'},{n:'C2',c:'Y'},{n:'MTR',c:'R',post:true}] },
  // AP-GROUNDED-SWITCH-001 — a switch whose body is grounded to the
  // chassis: per direct request, a normal pin-numbered terminal on top
  // and a `post`-style GND terminal on the bottom (buildGroundedSwitchCard,
  // renderer.js), reusing the same chassis-ground hatch glyph as Starter
  // Motor's GND post.
  { label:'Switch',        sub:'Chassis Grounded',  cat:'control',  exit:'up',    groundedSwitch:true, terminals:[{n:'SW',c:'W'},{n:'GND',c:'Bl',post:true}] },
  // AP-GROUNDED-SWITCH-001 — same shell as the grounded Switch above
  // (normal pin on top, chassis-grounded `post` pin on bottom), with a
  // thermistor/temp-sensor symbol in the middle (buildThermistorCard,
  // renderer.js) — per direct follow-up request.
  { label:'Temp Sensor',   sub:'Thermistor',        cat:'accessory', exit:'up',    thermistor:true, terminals:[{n:'SIG',c:'W'},{n:'GND',c:'Bl',post:true}] },
  // AP-BODY-GROUND-SYMBOL-001 — a single signal pin on top; the body
  // ground (bolted straight to the crankcase/chassis) is a decorative
  // symbol only, not a second terminal (buildPulseGeneratorCard,
  // renderer.js) — per direct correction, unlike Switch/Temp Sensor
  // above, whose GND post IS a real wireable connection their own
  // simulation behavior depends on.
  { label:'Pulse Generator', sub:'Pickup Coil',      cat:'ignition',  exit:'up',    pulseGenerator:true, terminals:[{n:'SIG',c:'W'}] },
  // AP-ALTERNATOR-001/AP-BODY-GROUND-SYMBOL-001 — 5 terminals per direct
  // request, all 5 numbered stator winding leads in one top row
  // (buildAlternatorCard, renderer.js); the body ground is a decorative
  // symbol only, not one of the 5.
  { label:'Alternator',   sub:'Stator',              cat:'charging',  exit:'up',    alternator:true, terminals:[{n:'1',c:'W'},{n:'2',c:'Y'},{n:'3',c:'Y'},{n:'4',c:'W'},{n:'5',c:'G'}] },
  // AP-BULB-GENERIC-001 — 3-terminal bulb (dual filament: HI/LO + shared
  // GND), incandescent white-to-amber glow style — per direct request,
  // "the most a bulb would have on them would be 3 terminal[s] and that
  // would either be a headlight with 2 filaments, one for hi beam and
  // one for low beam."
  { label:'Headlight',    sub:'Dual-Filament',    cat:'lighting', exit:'right', bulb:true, bulbStyle:'incandescent', terminals:[{n:'HI',c:'Bu'},{n:'LO',c:'W'},{n:'GND',c:'G'}] },
  // AP-BULB-GENERIC-001 — 2-terminal bulb (single filament + GND),
  // selectable colored-lens style — per direct request, "indicator lights
  // would normally be single filament," with a color choice ("reverse
  // light red, neutral light is green... but I should have a few colors
  // to choose from"). Same underlying card/flags as Headlight above
  // (buildBulbCard, renderer.js) — just a different terminal count and
  // `bulbStyle`/`bulbColor`, both editable afterward (Edit Module).
  { label:'Indicator Light', sub:'Single-Filament', cat:'indicator', exit:'up', bulb:true, bulbStyle:'color', bulbColor:'red', terminals:[{n:'SIG',c:'W'},{n:'GND',c:'G'}] },
  { label:'Voltage Reg',  sub:'Linear Reg',       cat:'charging', exit:'down',  terminals:[{n:'IN',c:'R'},{n:'OUT',c:'R'},{n:'ADJ',c:'W'},{n:'GND',c:'G'}] },
];
const CONN_PRESETS = [
  { label:'Connector 1P', sub:'Inline 1-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'W|W'}] },
  { label:'Connector 2P', sub:'Inline 2-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'W|W'},{n:'B',c:'Bl|Bl'}] },
  { label:'Connector 3P', sub:'Inline 3-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'}] },
  { label:'Connector 4P', sub:'Inline 4-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'},{n:'D',c:'Y|Y'}] },
  { label:'Connector 6P', sub:'Inline 6-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'},{n:'D',c:'Y|Y'},{n:'E',c:'Bu|Bu'},{n:'F',c:'Bl|Bl'}] },
  { label:'Connector 4P Vertical', sub:'IN left / OUT right', cat:'connector', exit:'down', connector:true, vertical:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'},{n:'D',c:'Y|Y'}] },
  { label:'Connector 6P Vertical', sub:'IN left / OUT right', cat:'connector', exit:'down', connector:true, vertical:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'},{n:'D',c:'Y|Y'},{n:'E',c:'Bu|Bu'},{n:'F',c:'Bl|Bl'}] },
];

function renderModPanel() {
  const body = $('mp-body'); body.innerHTML = '';
  const sec = document.createElement('div'); sec.className = 'cat-sec';
  const hd  = document.createElement('div'); hd.className  = 'cat-hd'; hd.textContent = 'Preset Templates'; sec.appendChild(hd);
  PRESETS.forEach(p => {
    const row = document.createElement('div'); row.className = 'mi';
    const pS  = JSON.stringify(p).replace(/"/g, '&quot;');
    row.innerHTML = `<div class="mi-dot" style="background:${CAT_CLR[p.cat]||'#888'}"></div><div><div class="mi-nm">${p.label}</div><div class="mi-sb">${p.sub}</div></div><button class="mi-add" onclick="event.stopPropagation();openAddP(${pS})">＋</button>`;
    sec.appendChild(row);
  });
  const cr = document.createElement('div'); cr.className = 'mi'; cr.style.marginTop = '8px';
  cr.innerHTML = `<div class="mi-dot" style="background:#555"></div><div><div class="mi-nm">Custom Module</div><div class="mi-sb">Define from scratch</div></div><button class="mi-add" onclick="openAdd()">＋</button>`;
  sec.appendChild(cr);
  const spl = document.createElement('div'); spl.className = 'mi';
  spl.innerHTML = `<div class="mi-dot" style="background:#94a3b8;border-radius:50%"></div><div><div class="mi-nm">Splice</div><div class="mi-sb">Wire joint / shared ground or power tap</div></div><button class="mi-add" onclick="openAddSplice()">＋</button>`;
  sec.appendChild(spl); body.appendChild(sec);
  const csec = document.createElement('div'); csec.className = 'cat-sec';
  const chd  = document.createElement('div'); chd.className  = 'cat-hd'; chd.style.color = '#0e7490'; chd.textContent = 'Inline Connectors'; csec.appendChild(chd);
  CONN_PRESETS.forEach(p => {
    const row = document.createElement('div'); row.className = 'mi';
    const pS  = JSON.stringify(p).replace(/"/g, '&quot;');
    row.innerHTML = `<div class="mi-dot" style="background:${CAT_CLR.connector}"></div><div><div class="mi-nm">${p.label}</div><div class="mi-sb">${p.sub}</div></div><button class="mi-add" onclick="event.stopPropagation();openAddP(${pS})">＋</button>`;
    csec.appendChild(row);
  });
  const cc = document.createElement('div'); cc.className = 'mi';
  cc.innerHTML = `<div class="mi-dot" style="background:#0e7490"></div><div><div class="mi-nm">Custom Connector</div><div class="mi-sb">Any pin count</div></div><button class="mi-add" onclick="openAddConn()">＋</button>`;
  csec.appendChild(cc); body.appendChild(csec);
  const uMods = MODULES.filter(m => m._user);
  if (uMods.length) {
    const us = document.createElement('div'); us.className = 'cat-sec';
    const uh = document.createElement('div'); uh.className = 'cat-hd'; uh.textContent = 'Your Modules'; us.appendChild(uh);
    uMods.forEach(m => {
      const row = document.createElement('div'); row.className = 'mi';
      row.innerHTML = `<div class="mi-dot" style="background:${CAT_CLR[m.cat]||'#888'}"></div><div><div class="mi-nm">${m.label}</div><div class="mi-sb">${m.sub||''}</div></div><button class="mi-add" style="color:#f87171;border-color:#7f1d1d" onclick="delModule('${m.id}')">✕</button>`;
      us.appendChild(row);
    });
    body.appendChild(us);
  }
}

// ── Add module modal ──────────────────────────────────────────────

// AP-POWER-POST-001 — the Add Module modal is a generic form (Label/
// Sub/Category/Exit/Connector/Vertical/Terminals-as-name+color) with no
// field of its own for a preset's special rendering flags (`bulb`,
// `battery`, `starterMotor`, `solenoid`, `diode`, or a terminal's own
// `post`) — commitAddModule() below only ever built the final module
// from those generic fields, so a preset carrying any of these silently
// lost them the moment it went through this modal (confirmed live: the
// existing "Headlight" preset's own `bulb:true` had this exact bug
// already, predating this task — added via the panel, it rendered as a
// plain card, never the bulb symbol). Stashed here at open time, applied
// back onto the built module in commitAddModule(), and cleared by both
// "custom" entry points below so a from-scratch module never inherits
// flags left over from whichever preset was open last.
let pendingPresetFlags = null;
function openAdd() {
  pendingPresetFlags = null;
  $('add-modal-title').textContent = 'Add Custom Module';
  $('am-label').value = ''; $('am-sub').value = ''; $('am-cat').value = 'control'; $('am-exit').value = 'down';
  $('term-builder').innerHTML = ''; $('am-is-conn').checked = false;
  $('am-vertical-row').style.display = 'none'; $('am-vertical').checked = false;
  $('add-term-btn').style.display = ''; $('add-conn-term-btn').style.display = 'none';
  addTermRow(); addTermRow();
  $('add-modal').classList.add('open');
}
function openAddConn() {
  pendingPresetFlags = null;
  $('add-modal-title').textContent = 'Add Custom Connector';
  $('am-label').value = 'Custom Connector'; $('am-sub').value = 'Inline'; $('am-cat').value = 'connector'; $('am-exit').value = 'down';
  $('term-builder').innerHTML = ''; $('am-is-conn').checked = true;
  $('am-vertical-row').style.display = 'flex'; $('am-vertical').checked = false;
  $('add-term-btn').style.display = 'none'; $('add-conn-term-btn').style.display = '';
  addConnTermRow('A','W','W'); addConnTermRow('B','Bl','Bl');
  $('add-modal').classList.add('open');
}
function openAddP(p) {
  pendingPresetFlags = {
    bulb: p.bulb, bulbStyle: p.bulbStyle, bulbColor: p.bulbColor,
    battery: p.battery, starterMotor: p.starterMotor,
    solenoid: p.solenoid, diode: p.diode, groundedSwitch: p.groundedSwitch,
    thermistor: p.thermistor, pulseGenerator: p.pulseGenerator, alternator: p.alternator,
    terminalPost: p.terminals.map(t => !!t.post),
  };
  $('add-modal-title').textContent = 'Add ' + p.label;
  $('am-label').value = p.label; $('am-sub').value = p.sub; $('am-cat').value = p.cat; $('am-exit').value = p.exit || 'down';
  const isConn = !!p.connector; $('am-is-conn').checked = isConn;
  $('am-vertical-row').style.display = isConn ? 'flex' : 'none'; $('am-vertical').checked = !!p.vertical;
  $('add-term-btn').style.display = isConn ? 'none' : '';
  $('add-conn-term-btn').style.display = isConn ? '' : 'none';
  $('term-builder').innerHTML = '';
  if (isConn) p.terminals.forEach(t => { const parts = t.c.split('|'); addConnTermRow(t.n, parts[0]||'W', parts[1]||parts[0]||'W'); });
  else        p.terminals.forEach(t => addTermRow(t.n, t.c));
  $('add-modal').classList.add('open');
}
function closeAddModal() { $('add-modal').classList.remove('open'); }

let tIdx = 0;
function addTermRow(n = '', c = '') {
  const i = tIdx++; const row = document.createElement('div'); row.className = 'term-row'; row.id = 'tr-' + i;
  row.innerHTML = `${_pinBadge(0)}<input class="fi" placeholder="Label (e.g. B+)" value="${n}" data-trn/><input class="fi" placeholder="Color" value="${c}" data-trc style="max-width:60px"/><button class="term-del" onclick="document.getElementById('tr-${i}').remove();renumberTermBuilderPins()">✕</button>`;
  $('term-builder').appendChild(row);
  renumberTermBuilderPins();
}
function addConnTermRow(n = '', cIn = 'W', cOut = 'W') {
  const i = tIdx++; const row = document.createElement('div'); row.className = 'term-row'; row.id = 'tr-' + i;
  row.innerHTML = `${_pinBadge(0)}<input class="fi" placeholder="Label" value="${n}" data-trn style="max-width:40px"/><input class="fi" placeholder="IN color" value="${cIn}" data-trc-in style="max-width:56px" title="Wire color on IN side"/><span style="color:#555;font-size:9px;padding:0 2px">→</span><input class="fi" placeholder="OUT color" value="${cOut}" data-trc-out style="max-width:56px" title="Wire color on OUT side"/><button class="term-del" onclick="document.getElementById('tr-${i}').remove();renumberTermBuilderPins()">✕</button>`;
  $('term-builder').appendChild(row);
  renumberTermBuilderPins();
}
function renumberTermBuilderPins() {
  document.querySelectorAll('#term-builder .term-row .mpm-pin-badge').forEach((el, i) => { el.textContent = i + 1; });
}

// A right-click-canvas "+ Add Module" (module-editor.js's own background
// contextmenu listener, below) stashes exactly where the user clicked in
// `pendingAddPosition`; every add path (a preset, a custom module, a
// connector, a splice) reads it here — once, then clears it — instead of
// its own viewport-center default, and falls back to that default when
// nothing was stashed (the toolbar/module-panel "+" flow, unchanged).
// AP-WIRE-GRID-ALIGN-001 — every module/splice placement path funnels
// through here, so this is the one place that needs to snap to GRID for
// ALL of them: a right-click "Add Module"/"Add Splice" stashes the exact
// (unsnapped) click point in `pendingAddPosition`, and the toolbar/panel
// "+" flow's own viewport-center fallback below wasn't grid-exact either
// (the old /10*10 rounding — a finer grid than the canvas's own visible
// one, and no longer meaningful now that every card type places its
// terminals at a fixed GRID-multiple offset from this anchor).
function _takeAddPosition() {
  if (pendingAddPosition) {
    const p = pendingAddPosition; pendingAddPosition = null;
    return { x: Math.round(p.x / GRID) * GRID, y: Math.round(p.y / GRID) * GRID };
  }
  return {
    x: Math.round((vp.offsetWidth  / 2 - tx) / scale / GRID) * GRID,
    y: Math.round((vp.offsetHeight / 2 - ty) / scale / GRID) * GRID,
  };
}

function commitAddModule() {
  const label = $('am-label').value.trim();
  if (!label) { showToast('Enter a label', 'warn'); return; }
  const id = 'mod-' + label.toLowerCase().replace(/[^a-z0-9]/g, '-') + '-' + Date.now();
  const isConn = $('am-is-conn').checked;
  const terminals = [];
  if (isConn) {
    document.querySelectorAll('#term-builder .term-row').forEach(row => {
      const n = row.querySelector('[data-trn]')?.value.trim();
      const cIn  = row.querySelector('[data-trc-in]')?.value.trim()  || 'W';
      const cOut = row.querySelector('[data-trc-out]')?.value.trim() || cIn;
      if (n) terminals.push({ n, c: `${cIn}|${cOut}` });
    });
  } else {
    document.querySelectorAll('#term-builder .term-row').forEach(row => {
      const n = row.querySelector('[data-trn]').value.trim();
      const c = row.querySelector('[data-trc]').value.trim() || 'W';
      if (n) terminals.push({ n, c });
    });
  }
  if (!terminals.length) { showToast('Add at least one terminal', 'warn'); return; }
  const m = { id, label, sub: $('am-sub').value.trim(), cat: $('am-cat').value, exit: $('am-exit').value, terminals, _user: true };
  if (isConn) { m.connector = true; if ($('am-vertical').checked) m.vertical = true; }
  // AP-POWER-POST-001 — re-applies whatever special rendering flags
  // openAddP() stashed from the ORIGINAL preset object, since the
  // generic form fields above have no way to carry them through on
  // their own (see pendingPresetFlags' own doc comment for the
  // pre-existing "Headlight" bug this same mechanism also fixes).
  if (pendingPresetFlags) {
    const f = pendingPresetFlags;
    if (f.bulb) m.bulb = true;
    if (f.bulbStyle) m.bulbStyle = f.bulbStyle;
    if (f.bulbColor) m.bulbColor = f.bulbColor;
    if (f.battery) m.battery = true;
    if (f.starterMotor) m.starterMotor = true;
    if (f.solenoid) m.solenoid = true;
    if (f.diode) m.diode = true;
    if (f.groundedSwitch) m.groundedSwitch = true;
    if (f.thermistor) m.thermistor = true;
    if (f.pulseGenerator) m.pulseGenerator = true;
    if (f.alternator) m.alternator = true;
    terminals.forEach((t, i) => { if (f.terminalPost[i]) t.post = true; });
  }
  pendingPresetFlags = null;
  MODULES.push(m);
  positions[id] = _takeAddPosition();
  placeCards(); drawWires(); buildLegend(); closeAddModal(); renderModPanel();
  // A module you just placed should be immediately repositionable, not
  // require a separate trip to the ✦ Layout button first — dragging is
  // gated on editMode (setupDrag's own mousedown check), so entering it
  // automatically here is what actually makes that true, the same way
  // wire creation already flows straight into Route Edit mode (§
  // handleWireTerm's own comment in wire-editor.js).
  if (!editMode) toggleEdit();
  showToast('Module added: ' + label);
}

// A freestanding splice, for placing one before it's wired up (the more
// common path — clicking a point on an existing wire while in Wire mode
// — is handleWireClickOnExistingWire in wire-editor.js, which inserts
// one already spliced into that wire).
// `exit` defaults to 'up' (the toolbar/module-panel path, no particular
// wire to line up with yet) but is overridable — ctxAddSplice()
// (wire-editor.js) passes the axis of whatever terminal/wire the splice
// was requested from, so it renders already lined up with that run
// instead of needing a manual straighten afterward.
function openAddSplice(exit = 'up') {
  const id = 'splice-' + Date.now();
  const m = { id, label: 'Splice', sub: '', cat: 'splice', splice: true, location: '', exit, terminals: [{ n: 'SPLICE', c: 'W' }], _user: true };
  MODULES.push(m);
  positions[id] = _takeAddPosition();
  placeCards(); drawWires(); closeModPanel(); renderModPanel();
  if (!editMode) toggleEdit();
  showToast('Splice added — set its Location, then wire it up');
  editModProps(id);
  return id;
}

function delModule(modId) {
  if (!confirm('Delete module and all its wires?')) return;
  MODULES = MODULES.filter(m => m.id !== modId);
  WIRES   = WIRES.filter(w => w.from.m !== modId && w.to.m !== modId);
  removeCard(modId);
  delete positions[modId];
  drawWires(); renderModPanel(); buildLegend();
  showToast('Module deleted');
}

// ── Edit module properties modal ──────────────────────────────────

// Expose swatchBg() for inline oninput handlers — a two-color code's live
// preview dot should split stripe/main the same way every other terminal
// dot in the app does (§ renderer.js's own swatchBg doc comment); falls
// back to a plain solid color for a single-color code same as before.
window.hColor = swatchBg;

function editModProps(mid) {
  if (mid === undefined) mid = selM;
  if (!mid) return;
  const m = MODULES.find(x => x.id === mid);
  if (!m) return;
  $('mpm-id').value    = mid;
  $('mpm-label').value = m.label || '';
  $('mpm-sub').value   = m.sub   || '';
  $('mpm-label-justify').value = m.labelJustify || '';
  $('mpm-cat').value   = m.cat   || 'control';
  $('mpm-exit').value  = m.exit  || 'down';
  $('mpm-notes').value = m.notes || '';
  $('mpm-location').value = m.location || '';
  // A splice has exactly one fixed terminal ("SPLICE") that every wire
  // attached to it depends on by name — the terminal editor and the
  // connector/vertical toggles (which are about pin layout, meaningless
  // for a single-dot junction) don't apply to it. Location is the field
  // that matters for a splice, so it stays visible either way.
  $('mpm-terms-section').style.display = m.splice ? 'none' : '';
  $('mpm-is-conn-row').style.display   = m.splice ? 'none' : 'flex';
  // AP-MODULE-LAYOUT-001 — "Vertical Pin Layout" used to only apply to
  // connectors (the only card type that supported a stacked layout at
  // all); any module can stand vertical now (buildStdCard, renderer.js),
  // so this only stays hidden for a splice (a single dot with no
  // meaningful "layout" of its own) — not gated on Inline Connector
  // anymore. § the `mpm-is-conn` change listener at the bottom of
  // index.html, which used to be the only other place this row's
  // visibility was controlled.
  $('mpm-vertical-row').style.display = m.splice ? 'none' : 'flex';
  $('mpm-layout-section').style.display = m.splice ? 'none' : '';
  // AP-BULB-GENERIC-001 — flip side + color only make sense for a bulb.
  $('mpm-bulb-row').style.display = m.bulb ? 'flex' : 'none';
  $('mpm-bulb-color-row').style.display = m.bulb ? '' : 'none';
  $('mpm-flipped').checked = !!m.flipped;
  $('mpm-bulb-color').value = m.bulbStyle === 'incandescent' ? '' : (m.bulbColor || '');
  $('mpm-label-pos').value = m.labelPos || '';
  $('mpm-pin-label-pos').value = m.pinLabelPos || '';
  $('mpm-sub-label-pos').value = m.subLabelPos || '';
  const tb = $('mpm-terms'); tb.innerHTML = '';
  const isConn = !!m.connector;
  m.terminals.forEach((t, i) => {
    const row = document.createElement('div'); row.className = 'mpm-term-row';
    // AP-MODULE-LAYOUT-001 — `showLabel` (per terminal) is a plain
    // checkbox, not a new text field: `t.n` already exists on every
    // terminal (the "Label" input right beside it — previously only ever
    // used for the tooltip, never rendered on the card itself now that
    // the pin NUMBER is the primary on-card label), so checking this box
    // just also renders that same text as a second, opposite-side label
    // (buildStdCard, renderer.js) — per direct user request, no
    // duplicate/second text field needed.
    const showLabelBox = `<input type="checkbox" data-ti="${i}" data-tf="showLabel" ${t.showLabel ? 'checked' : ''} title="Also show this pin's Label on the diagram, opposite the pin number" style="accent-color:#0e7490;margin:0 2px"/>`;
    if (isConn) {
      const parts = t.c.split('|'); const cIn = parts[0] || '', cOut = parts[1] || '';
      row.innerHTML = `${_pinBadge(i)}<input class="fi" value="${t.n}" data-ti="${i}" data-tf="n" placeholder="Label" style="max-width:36px" title="Pin label (may repeat — the Pin # to the left is the real identity)"/>${showLabelBox}<div class="mpm-dot" style="background:${swatchBg(cIn)}"></div><input class="fi" value="${cIn}" data-ti="${i}" data-tf="cin" placeholder="IN color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><span style="color:var(--text-lo);font-size:9px">→</span><div class="mpm-dot" style="background:${swatchBg(cOut)}"></div><input class="fi" value="${cOut}" data-ti="${i}" data-tf="cout" placeholder="OUT color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove();renumberMpmPins()">✕</button>`;
    } else {
      row.innerHTML = `${_pinBadge(i)}<input class="fi" value="${t.n}" data-ti="${i}" data-tf="n" placeholder="Label" style="max-width:50px" title="Pin label (may repeat — the Pin # to the left is the real identity)"/>${showLabelBox}<div class="mpm-dot" style="background:${swatchBg(t.c)}"></div><input class="fi" value="${t.c}" data-ti="${i}" data-tf="c" placeholder="Color" style="max-width:60px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove();renumberMpmPins()">✕</button>`;
    }
    tb.appendChild(row);
  });
  $('mpm-is-conn').checked       = isConn;
  $('mpm-vertical').checked      = !!m.vertical;
  $('mpm-add-term').style.display = isConn ? 'none' : '';
  $('mpm-add-pin').style.display  = isConn ? ''     : 'none';
  $('mpm').classList.add('open');
}

// Every terminal row's Pin # badge is purely a live display of the row's
// current position (1-based) among its siblings — it is never itself an
// input, so it can't collide or need validating. It's what makes the
// numbering-never-repeats guarantee visible while you edit: add or
// remove a row and every badge after it re-numbers immediately. The
// actual identity used for wires/DOM ids is computed the same way at
// save time (saveModProps's `newIdx`), so what's shown here always
// matches what gets saved.
function _pinBadge(i) {
  return `<span class="mpm-pin-badge fpk" style="min-width:18px;text-align:center;flex-shrink:0;color:var(--amber)" title="Pin number — auto-assigned, always unique on this module">${i + 1}</span>`;
}
function renumberMpmPins() {
  document.querySelectorAll('#mpm-terms .mpm-term-row .mpm-pin-badge').forEach((el, i) => { el.textContent = i + 1; });
}

function addMpmTerm() {
  const i = Date.now(); const row = document.createElement('div'); row.className = 'mpm-term-row';
  const showLabelBox = `<input type="checkbox" data-ti="${i}" data-tf="showLabel" title="Also show this pin's Label on the diagram, opposite the pin number" style="accent-color:#0e7490;margin:0 2px"/>`;
  row.innerHTML = `${_pinBadge(0)}<input class="fi" value="" data-ti="${i}" data-tf="n" placeholder="Label" style="max-width:50px"/>${showLabelBox}<div class="mpm-dot" style="background:#888"></div><input class="fi" value="" data-ti="${i}" data-tf="c" placeholder="Color" style="max-width:60px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove();renumberMpmPins()">✕</button>`;
  $('mpm-terms').appendChild(row);
  renumberMpmPins();
}
function addMpmPin() {
  const i = Date.now(); const row = document.createElement('div'); row.className = 'mpm-term-row';
  const showLabelBox = `<input type="checkbox" data-ti="${i}" data-tf="showLabel" title="Also show this pin's Label on the diagram, opposite the pin number" style="accent-color:#0e7490;margin:0 2px"/>`;
  row.innerHTML = `${_pinBadge(0)}<input class="fi" value="" data-ti="${i}" data-tf="n" placeholder="Label" style="max-width:36px"/>${showLabelBox}<div class="mpm-dot" style="background:#888"></div><input class="fi" value="" data-ti="${i}" data-tf="cin" placeholder="IN color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><span style="color:var(--text-lo);font-size:9px">→</span><div class="mpm-dot" style="background:#888"></div><input class="fi" value="" data-ti="${i}" data-tf="cout" placeholder="OUT color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove();renumberMpmPins()">✕</button>`;
  $('mpm-terms').appendChild(row);
  renumberMpmPins();
}
function closeMpm() { $('mpm').classList.remove('open'); }

// AP-MODULE-LAYOUT-001 — the ⇄ button between "Pin Number Position" and
// "Sub-Label Position": a straight swap of the two dropdowns' current
// values, so re-siding both labels (e.g. pin number was on top, sub-label
// on bottom -> flip to pin number on bottom, sub-label on top) is one
// click instead of two separate dropdown changes. Purely a form-field
// swap — doesn't touch `m` until Save is clicked, same as every other
// field in this modal.
function swapMpmPinSubLabelPos() {
  const a = $('mpm-pin-label-pos'), b = $('mpm-sub-label-pos');
  const tmp = a.value; a.value = b.value; b.value = tmp;
}

function saveModProps() {
  const mid = $('mpm-id').value;
  const m   = MODULES.find(x => x.id === mid);
  if (!m) return;
  const isConn   = $('mpm-is-conn').checked;
  const wasConn  = !!m.connector; // connector-ness at the time oldTerms' wires were created — see the _IN/_OUT expansion below
  const oldTerms = m.terminals; // captured before m.terminals is overwritten below, so WIRES can be reconciled against it
  const rows     = Array.from($('mpm-terms').querySelectorAll('.mpm-term-row'));
  const newTerms = [];
  // Each surviving row's `data-ti` is the index it had in `oldTerms` at
  // `editModProps()` time (a row added since via addMpmTerm()/addMpmPin()
  // carries a Date.now() `data-ti` instead, which never matches an
  // `oldTerms` index). Track which old indices survived — and at what
  // new index (= new pin number - 1) — so wires can be renumbered/
  // removed to match, below. Wires are keyed by PIN NUMBER (1-based
  // position — see renderer.js's pinKey doc comment), never by the
  // free-text name/color fields, which are allowed to repeat.
  const survivedOldIdx = new Set();
  const pinRenumberMap = {}; // old pin number (string) -> new pin number (string)
  rows.forEach(row => {
    const nField = row.querySelector("[data-tf='n']");
    const n = nField?.value.trim();
    if (!n) return;
    // `data-ti` lives on the name input itself, not the row div (see the
    // template strings in editModProps()/addMpmTerm()/addMpmPin() below).
    const ti = Number(nField.dataset.ti);
    const newIdx = newTerms.length; // this row's position in the array being built below
    if (Number.isInteger(ti) && ti >= 0 && ti < oldTerms.length) {
      survivedOldIdx.add(ti);
      if (ti !== newIdx) pinRenumberMap[pinKey(ti)] = pinKey(newIdx);
    }
    // AP-MODULE-LAYOUT-001 — per-pin "also show this Label on the
    // diagram" opt-in (buildStdCard, renderer.js). Stored as the string
    // '1' (not a real boolean `true`) and OMITTED (not `false`) when
    // unchecked: terminals round-trip through the OEP bridge as a
    // `Map<String,String>` (legacy_v2_bridge_transport.dart's
    // `_parseTerminals`), which coerces every value via `.toString()` —
    // a real `false` would come back as the STRING `"false"`, which is
    // truthy in JS and would silently turn every restored terminal's
    // label back on regardless of its original state. A short, non-empty
    // truthy string sidesteps that boundary entirely.
    const showLabel = row.querySelector("[data-tf='showLabel']")?.checked ? '1' : undefined;
    // AP-STARTER-SOLENOID-001 — a "post" terminal (the big unlabeled
    // power-post dots on the battery/solenoid/starter-motor cards,
    // buildBatteryCard/buildSolenoidCard/buildStarterMotorCard) is a
    // property of the ORIGINAL terminal, not something this editor form
    // exposes a checkbox for — carried forward from `oldTerms[ti]` when
    // this row survived from that old index, same way its wire
    // attachments already get carried forward by `pinRenumberMap`.
    // Without this, saving ANY change on one of these modules (even just
    // renaming its label) silently downgraded its posts back into
    // ordinary numbered pins on the next render.
    const post = (Number.isInteger(ti) && ti >= 0 && ti < oldTerms.length) ? oldTerms[ti].post : undefined;
    // AP-TERMINAL-EXIT-001 — a terminal's own exit-side override
    // (set via its module's sidebar inspector, setTerminalExit(),
    // wire-editor.js) is carried forward the exact same way `post` is
    // above — this form has no field for it either, so without this,
    // saving ANY change here would silently wipe every terminal's
    // exit-side override back to "Auto" on the next render.
    const exit = (Number.isInteger(ti) && ti >= 0 && ti < oldTerms.length) ? oldTerms[ti].exit : undefined;
    if (isConn) {
      const cIn  = row.querySelector("[data-tf='cin']")?.value.trim()  || 'W';
      const cOut = row.querySelector("[data-tf='cout']")?.value.trim() || cIn;
      newTerms.push({ n, c: `${cIn}|${cOut}`, showLabel, post, exit });
    } else {
      const c = row.querySelector("[data-tf='c']")?.value.trim() || 'W';
      newTerms.push({ n, c, showLabel, post, exit });
    }
  });
  if (!newTerms.length) { showToast('Need at least one terminal', 'warn'); return; }

  // Reconcile WIRES attached to this module's renumbered/removed pins.
  // Without this, a wire whose pin moved position or was deleted here
  // keeps pointing at a pin number that now belongs to a different
  // terminal (or none at all) — route()/getPos() (renderer.js) then
  // either resolve to the wrong dot or silently fail, and drawWires()
  // drops a failing one from the SVG layer entirely (no path, no hit
  // zone, no context menu), which is exactly why "Edit Route" appears to
  // stop showing up after a module edit or terminal deletion. A
  // repositioned pin's wires follow it; a genuinely removed pin's wires
  // are deleted, mirroring delModule()'s own wire cleanup for a deleted
  // module.
  const removedPins = new Set(
    oldTerms.map((t, i) => pinKey(i)).filter((_, i) => !survivedOldIdx.has(i)),
  );
  // Connector modules attach wires to `${pin}_IN`/`${pin}_OUT`, not the
  // bare pin number (see renderer.js's terminal-dot ids and exitDir's own
  // "_IN"/"_OUT" checks) — a wire's `.t` field is literally "2_IN", never
  // "2". Expand the plain renumber/removal sets built above to cover both
  // suffixed forms for a connector, using `wasConn` (this module's
  // connector-ness *before* this save) since that's what the existing
  // wires were actually created under.
  const wireRenameMap = {};
  Object.entries(pinRenumberMap).forEach(([oldPin, newPin]) => {
    if (wasConn) { wireRenameMap[`${oldPin}_IN`] = `${newPin}_IN`; wireRenameMap[`${oldPin}_OUT`] = `${newPin}_OUT`; }
    else wireRenameMap[oldPin] = newPin;
  });
  const wireRemovedNames = new Set();
  removedPins.forEach(pin => {
    if (wasConn) { wireRemovedNames.add(`${pin}_IN`); wireRemovedNames.add(`${pin}_OUT`); }
    else wireRemovedNames.add(pin);
  });
  let removedWireCount = 0;
  if (Object.keys(wireRenameMap).length || wireRemovedNames.size) {
    WIRES = WIRES.filter(w => {
      let drop = false;
      if (w.from.m === mid) {
        if (wireRenameMap[w.from.t] !== undefined) w.from.t = wireRenameMap[w.from.t];
        else if (wireRemovedNames.has(w.from.t)) drop = true;
      }
      if (w.to.m === mid) {
        if (wireRenameMap[w.to.t] !== undefined) w.to.t = wireRenameMap[w.to.t];
        else if (wireRemovedNames.has(w.to.t)) drop = true;
      }
      if (drop) {
        removedWireCount++;
        delete wireRoutes[w.id];
        if (selW && selW.id === w.id) { selW = null; if (routeEditMode) exitRouteEditMode(); }
      }
      return !drop;
    });
  }

  // AP-MODULE-LABEL-WRAP-001 — `.value` on a <textarea> (Label/Sub-label
  // used to be single-line <input>s) preserves whatever line breaks the
  // user typed (Enter) verbatim; `.trim()` only strips leading/trailing
  // whitespace across the whole block, same as it always did for the
  // single-line case, never the internal `\n`s.
  m.label     = $('mpm-label').value.trim() || m.label;
  m.sub       = $('mpm-sub').value.trim();
  m.labelJustify = $('mpm-label-justify').value || undefined;
  m.cat       = $('mpm-cat').value;
  m.exit      = $('mpm-exit').value;
  m.notes     = $('mpm-notes').value.trim();
  m.location  = $('mpm-location').value.trim();
  m.terminals = newTerms;
  m.connector = isConn || undefined;
  // AP-MODULE-LAYOUT-001 — no longer gated on `isConn`: any module can
  // stand vertical now (buildStdCard, renderer.js), not just a connector.
  m.vertical  = $('mpm-vertical').checked || undefined;
  // AP-BULB-GENERIC-001 — only ever read/written for a bulb (the row is
  // hidden otherwise, so these controls can't have been touched by a
  // non-bulb module's edit) — harmless no-op for everything else.
  if (m.bulb) {
    m.flipped = $('mpm-flipped').checked || undefined;
    const chosenColor = $('mpm-bulb-color').value;
    m.bulbStyle = chosenColor ? 'color' : 'incandescent';
    m.bulbColor = chosenColor || undefined;
  }
  m.labelPos    = $('mpm-label-pos').value || undefined;
  m.pinLabelPos = $('mpm-pin-label-pos').value || undefined;
  m.subLabelPos = $('mpm-sub-label-pos').value || undefined;
  rebuildCard(m);
  closeMpm();
  if (selM === mid) renderModInfo(m);
  drawWires();
  showToast(removedWireCount
    ? `${m.label} updated — ${removedWireCount} wire${removedWireCount === 1 ? '' : 's'} removed (terminal deleted)`
    : `${m.label} updated`);
}

// Quick toggle for a module's orientation (context menu ⟳ Rotate) — the
// same `m.vertical` flag the Edit modal's "Vertical Pin Layout" checkbox
// sets, so a module rotated this way is indistinguishable from one
// authored vertical from the start. AP-MODULE-LAYOUT-001 — used to only
// apply to connectors (the only card type that supported a vertical
// layout at all); any module can stand vertical now, so this only
// excludes a splice (a single dot with no meaningful orientation).
function rotateModule(modId) {
  const m = MODULES.find(x => x.id === modId);
  if (!m || m.splice) return;
  m.vertical = !m.vertical || undefined;
  rebuildCard(m);
  drawWires();
  showToast(m.vertical ? `${m.label} rotated vertical` : `${m.label} rotated horizontal`);
}

function rebuildCard(m) {
  const old = cardEls[m.id];
  const pos = positions[m.id] || { x: 50, y: 50 };
  if (old) old.remove();
  const card = buildCard(m);
  card.style.left = pos.x + 'px'; card.style.top = pos.y + 'px';
  canvas.appendChild(card);
  cardEls[m.id] = card;
  setupDrag(card, m.id);
  setupTermClicks(card);
  if (selM === m.id) card.classList.add('mod-selected');
}
