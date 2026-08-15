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
  card.addEventListener('mousedown', e => {
    if (!editMode) return;
    if (e.target.closest('.t-dot')) return;
    drag = true;
    const r = card.getBoundingClientRect(), sr = scene.getBoundingClientRect();
    ox = (r.left - sr.left) / scale;
    oy = (r.top  - sr.top)  / scale;
    sx = e.clientX; sy = e.clientY;
    card.classList.add('dragging'); card.style.zIndex = 200;
    e.preventDefault(); e.stopPropagation();
  });
  window.addEventListener('mousemove', e => {
    if (!drag) return;
    const nx = Math.round(Math.max(0, ox + (e.clientX - sx) / scale) / 10) * 10;
    const ny = Math.round(Math.max(0, oy + (e.clientY - sy) / scale) / 10) * 10;
    card.style.left = nx + 'px'; card.style.top = ny + 'px';
    positions[modId] = { x: nx, y: ny };
    drawWires();
  });
  window.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = false;
    card.classList.remove('dragging'); card.style.zIndex = '';
    drawWires();
  });
  card.addEventListener('contextmenu', e => {
    e.preventDefault(); e.stopPropagation();
    ctxTarget = { _mid: modId };
    if (editMode) {
      $('ctx-edit').style.display = 'none'; $('ctx-trace').style.display = 'none';
    } else {
      $('ctx-edit').style.display = ''; $('ctx-edit').textContent = '✎ Edit Module';
      $('ctx-trace').style.display = 'none';
    }
    $('ctx-del').textContent = '✕ Delete Module';
    const m = $('ctx');
    m.style.left = e.clientX + 'px'; m.style.top = e.clientY + 'px';
    m.classList.add('open');
  });
  card.addEventListener('click', e => {
    if (editMode || wireMode || routeEditMode) return;
    if (e.target.closest('.t-dot')) return;
    e.stopPropagation();
    selMod(modId, e);
  });
}

// ── Edit mode toggle ──────────────────────────────────────────────

function toggleEdit() {
  editMode = !editMode;
  if (editMode && wireMode) cancelWireMode();
  if (editMode && routeEditMode) exitRouteEditMode();
  vp.classList.toggle('edit-mode', editMode);
  $('edit-btn').classList.toggle('edit-on', editMode);
  $('edit-btn').textContent     = editMode ? '✦ Done' : '✦ Layout';
  $('edit-badge').style.display = editMode ? 'block' : 'none';
  if (editMode) { closePanel(); selW = null; tracedWires.clear(); }
  drawWires();
}

// ── Module panel drawer ───────────────────────────────────────────

function openModPanel()  { mpOpen = !mpOpen; $('mod-panel').classList.toggle('open', mpOpen); if (mpOpen) renderModPanel(); }
function closeModPanel() { mpOpen = false; $('mod-panel').classList.remove('open'); }

const PRESETS = [
  { label:'Battery',      sub:'12V Lead-Acid',   cat:'power',    exit:'up',    terminals:[{n:'B+',c:'R'},{n:'B-',c:'Bl'}] },
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
  { label:'Headlight',    sub:'12V Bulb',         cat:'lighting', exit:'right', bulb:true, terminals:[{n:'HI',c:'Bu'},{n:'LO',c:'W'},{n:'GND',c:'G'}] },
  { label:'Voltage Reg',  sub:'Linear Reg',       cat:'charging', exit:'down',  terminals:[{n:'IN',c:'R'},{n:'OUT',c:'R'},{n:'ADJ',c:'W'},{n:'GND',c:'G'}] },
];
const CONN_PRESETS = [
  { label:'Connector 1P', sub:'Inline 1-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'W|W'}] },
  { label:'Connector 2P', sub:'Inline 2-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'W|W'},{n:'B',c:'Bl|Bl'}] },
  { label:'Connector 3P', sub:'Inline 3-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'}] },
  { label:'Connector 4P', sub:'Inline 4-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'},{n:'D',c:'Y|Y'}] },
  { label:'Connector 6P', sub:'Inline 6-Pin', cat:'connector', exit:'down', connector:true, terminals:[{n:'A',c:'R|R'},{n:'B',c:'W|W'},{n:'C',c:'G|G'},{n:'D',c:'Y|Y'},{n:'E',c:'Bu|Bu'},{n:'F',c:'Bl|Bl'}] },
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
  sec.appendChild(cr); body.appendChild(sec);
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

function openAdd() {
  $('add-modal-title').textContent = 'Add Custom Module';
  $('am-label').value = ''; $('am-sub').value = ''; $('am-cat').value = 'control'; $('am-exit').value = 'down';
  $('term-builder').innerHTML = ''; $('am-is-conn').checked = false;
  $('add-term-btn').style.display = ''; $('add-conn-term-btn').style.display = 'none';
  addTermRow(); addTermRow();
  $('add-modal').classList.add('open');
}
function openAddConn() {
  $('add-modal-title').textContent = 'Add Custom Connector';
  $('am-label').value = 'Custom Connector'; $('am-sub').value = 'Inline'; $('am-cat').value = 'connector'; $('am-exit').value = 'down';
  $('term-builder').innerHTML = ''; $('am-is-conn').checked = true;
  $('add-term-btn').style.display = 'none'; $('add-conn-term-btn').style.display = '';
  addConnTermRow('A','W','W'); addConnTermRow('B','Bl','Bl');
  $('add-modal').classList.add('open');
}
function openAddP(p) {
  $('add-modal-title').textContent = 'Add ' + p.label;
  $('am-label').value = p.label; $('am-sub').value = p.sub; $('am-cat').value = p.cat; $('am-exit').value = p.exit || 'down';
  const isConn = !!p.connector; $('am-is-conn').checked = isConn;
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
  row.innerHTML = `<input class="fi" placeholder="Name (e.g. B+)" value="${n}" data-trn/><input class="fi" placeholder="Color" value="${c}" data-trc style="max-width:60px"/><button class="term-del" onclick="document.getElementById('tr-${i}').remove()">✕</button>`;
  $('term-builder').appendChild(row);
}
function addConnTermRow(n = '', cIn = 'W', cOut = 'W') {
  const i = tIdx++; const row = document.createElement('div'); row.className = 'term-row'; row.id = 'tr-' + i;
  row.innerHTML = `<input class="fi" placeholder="Pin" value="${n}" data-trn style="max-width:40px"/><input class="fi" placeholder="IN color" value="${cIn}" data-trc-in style="max-width:56px" title="Wire color on IN side"/><span style="color:#555;font-size:9px;padding:0 2px">→</span><input class="fi" placeholder="OUT color" value="${cOut}" data-trc-out style="max-width:56px" title="Wire color on OUT side"/><button class="term-del" onclick="document.getElementById('tr-${i}').remove()">✕</button>`;
  $('term-builder').appendChild(row);
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
  if (isConn) m.connector = true;
  MODULES.push(m);
  positions[id] = {
    x: Math.round((vp.offsetWidth  / 2 - tx) / scale / 10) * 10,
    y: Math.round((vp.offsetHeight / 2 - ty) / scale / 10) * 10,
  };
  placeCards(); drawWires(); buildLegend(); closeAddModal(); renderModPanel();
  showToast('Module added: ' + label);
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

// Expose h() for inline oninput handlers
window.hColor = h;

function editModProps(mid) {
  if (mid === undefined) mid = selM;
  if (!mid) return;
  const m = MODULES.find(x => x.id === mid);
  if (!m) return;
  $('mpm-id').value    = mid;
  $('mpm-label').value = m.label || '';
  $('mpm-sub').value   = m.sub   || '';
  $('mpm-cat').value   = m.cat   || 'control';
  $('mpm-exit').value  = m.exit  || 'down';
  $('mpm-notes').value = m.notes || '';
  const tb = $('mpm-terms'); tb.innerHTML = '';
  const isConn = !!m.connector;
  m.terminals.forEach((t, i) => {
    const row = document.createElement('div'); row.className = 'mpm-term-row';
    if (isConn) {
      const parts = t.c.split('|'); const cIn = parts[0] || '', cOut = parts[1] || '';
      row.innerHTML = `<input class="fi" value="${t.n}" data-ti="${i}" data-tf="n" placeholder="Pin" style="max-width:36px" title="Pin name"/><div class="mpm-dot" style="background:${h(cIn)}"></div><input class="fi" value="${cIn}" data-ti="${i}" data-tf="cin" placeholder="IN color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><span style="color:var(--text-lo);font-size:9px">→</span><div class="mpm-dot" style="background:${h(cOut)}"></div><input class="fi" value="${cOut}" data-ti="${i}" data-tf="cout" placeholder="OUT color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove()">✕</button>`;
    } else {
      row.innerHTML = `<input class="fi" value="${t.n}" data-ti="${i}" data-tf="n" placeholder="Name" style="max-width:50px" title="Terminal name"/><div class="mpm-dot" style="background:${h(t.c)}"></div><input class="fi" value="${t.c}" data-ti="${i}" data-tf="c" placeholder="Color" style="max-width:60px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove()">✕</button>`;
    }
    tb.appendChild(row);
  });
  $('mpm-is-conn').checked       = isConn;
  $('mpm-add-term').style.display = isConn ? 'none' : '';
  $('mpm-add-pin').style.display  = isConn ? ''     : 'none';
  $('mpm').classList.add('open');
}

function addMpmTerm() {
  const i = Date.now(); const row = document.createElement('div'); row.className = 'mpm-term-row';
  row.innerHTML = `<input class="fi" value="" data-ti="${i}" data-tf="n" placeholder="Name" style="max-width:50px"/><div class="mpm-dot" style="background:#888"></div><input class="fi" value="" data-ti="${i}" data-tf="c" placeholder="Color" style="max-width:60px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove()">✕</button>`;
  $('mpm-terms').appendChild(row);
}
function addMpmPin() {
  const i = Date.now(); const row = document.createElement('div'); row.className = 'mpm-term-row';
  row.innerHTML = `<input class="fi" value="" data-ti="${i}" data-tf="n" placeholder="Pin" style="max-width:36px"/><div class="mpm-dot" style="background:#888"></div><input class="fi" value="" data-ti="${i}" data-tf="cin" placeholder="IN color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><span style="color:var(--text-lo);font-size:9px">→</span><div class="mpm-dot" style="background:#888"></div><input class="fi" value="" data-ti="${i}" data-tf="cout" placeholder="OUT color" style="max-width:54px" oninput="this.previousElementSibling.style.background=hColor(this.value)"/><button class="term-del" onclick="this.closest('.mpm-term-row').remove()">✕</button>`;
  $('mpm-terms').appendChild(row);
}
function closeMpm() { $('mpm').classList.remove('open'); }

function saveModProps() {
  const mid = $('mpm-id').value;
  const m   = MODULES.find(x => x.id === mid);
  if (!m) return;
  const isConn   = $('mpm-is-conn').checked;
  const rows     = Array.from($('mpm-terms').querySelectorAll('.mpm-term-row'));
  const newTerms = [];
  rows.forEach(row => {
    const n = row.querySelector("[data-tf='n']")?.value.trim();
    if (!n) return;
    if (isConn) {
      const cIn  = row.querySelector("[data-tf='cin']")?.value.trim()  || 'W';
      const cOut = row.querySelector("[data-tf='cout']")?.value.trim() || cIn;
      newTerms.push({ n, c: `${cIn}|${cOut}` });
    } else {
      const c = row.querySelector("[data-tf='c']")?.value.trim() || 'W';
      newTerms.push({ n, c });
    }
  });
  if (!newTerms.length) { showToast('Need at least one terminal', 'warn'); return; }
  m.label     = $('mpm-label').value.trim() || m.label;
  m.sub       = $('mpm-sub').value.trim();
  m.cat       = $('mpm-cat').value;
  m.exit      = $('mpm-exit').value;
  m.notes     = $('mpm-notes').value.trim();
  m.terminals = newTerms;
  m.connector = isConn || undefined;
  rebuildCard(m);
  closeMpm();
  if (selM === mid) renderModInfo(m);
  drawWires();
  showToast(`${m.label} updated`);
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
