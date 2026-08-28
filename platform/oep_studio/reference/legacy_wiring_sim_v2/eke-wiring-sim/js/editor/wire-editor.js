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
    $('wep-status').textContent = 'Click a source terminal';
    selW = nw; drawWires();
    showToast('Wire created — edit properties');
    setTimeout(() => editWireProps(), 300);
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
