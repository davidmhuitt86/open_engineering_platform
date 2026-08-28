/**
 * ui/meter-panel.js
 *
 * Multimeter LCD display, key-position buttons, meter mode buttons,
 * and lead placement controls.
 *
 * Reads from: selW, MODULES, WIRES, keyPos, meterMode, leadR, leadB globals.
 * Writes to:  keyPos, meterMode, leadR, leadB, leadMode, leadPlaceMode globals.
 *
 * No electrical calculations. No wire routing. No diagram rendering.
 */

const ML  = { VDC: 'DC VOLTAGE', VAC: 'AC VOLTAGE', CONT: 'CONTINUITY', RES: 'RESISTANCE', DIODE: 'DIODE TEST' };
const MU  = { VDC: 'V', VAC: 'V~', CONT: '', RES: 'Ω', DIODE: 'V' };
const LM_DESC = {
  ends:   'Leads auto-placed at wire endpoints',
  gnd:    'Red=wire FROM end · Black=chassis ground (short-to-GND test)',
  pwr:    'Red=battery B+ · Black=wire TO end (short-to-PWR test)',
  manual: 'Click any terminal to place leads manually',
};

function setKey(k) {
  keyPos = k;
  document.querySelectorAll('.key-btn,.fp-kb').forEach(b => b.classList.toggle('active', +b.dataset.key === k));
  if (selW) { autoPlaceLeads(selW); updateMeter(); }
  updateBulbs();
  drawWires();
  if (typeof Sidebar !== 'undefined') Sidebar.onMeterChange();
}

function setMode(m) {
  meterMode = m;
  const L = { VDC: 'DC V', VAC: 'AC V', CONT: 'Cont', RES: 'Ω', DIODE: 'Diode' };
  document.querySelectorAll('.m-btn').forEach(b => b.classList.toggle('active', b.textContent.trim() === L[m]));
  if (selW && leadMode !== 'manual') setLeadMode('ends', false);
  if (selW) updateMeter();
  drawWires();
  if (typeof Sidebar !== 'undefined') Sidebar.onMeterChange();
}

function setLeadMode(mode, doToast = true) {
  leadMode = mode;
  document.querySelectorAll('.lm-btn').forEach(b => b.classList.remove('active'));
  const btn = $('lm-' + mode);
  if (btn) btn.classList.add('active');
  const desc = $('lead-mode-desc');
  if (desc) desc.textContent = LM_DESC[mode] || '';
  if (mode !== 'manual' && selW) autoPlaceLeads(selW);
  if (doToast) showToast(LM_DESC[mode]);
  updateLeadBtns();
  updateMeter();
  drawWires();
}

function autoPlaceLeads(w) {
  clearLeadDots();
  if (leadMode === 'manual') return;
  if (leadMode === 'ends') {
    leadR = { m: w.from.m, t: w.from.t };
    leadB = { m: w.to.m,   t: w.to.t   };
  } else if (leadMode === 'gnd') {
    leadR = { m: w.from.m, t: w.from.t };
    const gndMod = MODULES.find(m => m.cat === 'ground');
    leadB = (gndMod && gndMod.terminals.length) ? { m: gndMod.id, t: gndMod.terminals[0].n } : null;
  } else if (leadMode === 'pwr') {
    const batMod = MODULES.find(m => m.cat === 'power' && m.terminals.some(t => t.n === 'B+'));
    if (batMod) { const bt = batMod.terminals.find(t => t.n === 'B+') || batMod.terminals[0]; leadR = { m: batMod.id, t: bt.n }; }
    else leadR = null;
    leadB = { m: w.to.m, t: w.to.t };
  }
  restoreLeadDots();
  updateLeadLocDisplay();
}

function updateMeter() {
  if (!selW) return;
  const rd = (window.SWPACK && SWPACK.getReading(selW.id, keyPos)) || (selW.R ? selW.R[keyPos] : null);
  if (!rd) return;
  const val = rd[meterMode] || '0.00';
  let dv = val, dc = 'var(--lcd-fg)';
  if (meterMode === 'CONT') {
    if (val === '000' || val === '0.00') { dv = '· · ·'; dc = '#22d3ee'; }
    else if (val === 'OPN')              { dv = 'OPN';   dc = '#ff6b6b'; }
  }
  $('lcd-mode').textContent  = ML[meterMode];
  $('lcd-val').textContent   = dv;
  $('lcd-val').style.color   = dc;
  $('lcd-unit').textContent  = meterMode === 'CONT' ? '' : MU[meterMode];
  $('lcd-range').textContent = 'AUTO RANGE';
  $('lcd-note').textContent  = rd.note || '';
  updateLeadLocDisplay();
  if (typeof Sidebar !== 'undefined') Sidebar.onMeterChange();
}

function updateBulbs() {
  document.querySelectorAll('.bgl').forEach(g => {
    if (keyPos >= 1) { g.setAttribute('fill', '#fef9c3'); g.style.filter = 'drop-shadow(0 0 4px #fbbf24)'; }
    else             { g.setAttribute('fill', '#fffde7'); g.style.filter = ''; }
  });
}

function updateLeadLocDisplay() {
  const rl = $('lead-r-loc'), bl = $('lead-b-loc');
  if (rl) rl.textContent = leadR ? modTermLabel(leadR.m, leadR.t) : '—';
  if (bl) bl.textContent = leadB ? modTermLabel(leadB.m, leadB.t) : '—';
  // Sync sidebar versions
  const srl = $('si-lead-r-loc'), sbl = $('si-lead-b-loc');
  if (srl) srl.textContent = leadR ? modTermLabel(leadR.m, leadR.t) : '—';
  if (sbl) sbl.textContent = leadB ? modTermLabel(leadB.m, leadB.t) : '—';
  // Draw lead wires on diagram
  if (typeof Sidebar !== 'undefined') Sidebar.drawLeadWires();
}

function modTermLabel(mid, tn) {
  const m = MODULES.find(x => x.id === mid);
  return (m ? m.label : mid.replace(/-/g, ' ')) + ' · ' + tn;
}

function clearLeadDots()   { document.querySelectorAll('.t-dot').forEach(d => d.classList.remove('lead-r', 'lead-b')); }

function restoreLeadDots() {
  if (leadR) { const d = document.getElementById('d_' + sid(`${leadR.m}::${leadR.t}`)); if (d) d.classList.add('lead-r'); }
  if (leadB) { const d = document.getElementById('d_' + sid(`${leadB.m}::${leadB.t}`)); if (d) d.classList.add('lead-b'); }
}

function placeLead(color) {
  if (leadMode !== 'manual') setLeadMode('manual', false);
  if (leadPlaceMode === color) { leadPlaceMode = null; vp.classList.remove('lead-place-mode'); updateLeadBtns(); return; }
  leadPlaceMode = color;
  vp.classList.add('lead-place-mode');
  showToast(`Click any terminal — ${color === 'R' ? 'RED (+)' : 'BLACK (−)'} lead`);
  updateLeadBtns();
}

function clearLeads() {
  leadR = null; leadB = null; leadPlaceMode = null;
  vp.classList.remove('lead-place-mode');
  clearLeadDots(); updateMeter(); drawWires(); updateLeadBtns();
  if (typeof Sidebar !== 'undefined') Sidebar.onLeadsChanged();
}

function updateLeadBtns() {
  const rb = $('lead-place-r'), bb = $('lead-place-b');
  if (rb) rb.classList.toggle('lead-btn-active', leadPlaceMode === 'R');
  if (bb) bb.classList.toggle('lead-btn-active', leadPlaceMode === 'B');
}
