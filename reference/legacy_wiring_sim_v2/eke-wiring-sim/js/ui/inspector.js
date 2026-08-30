/**
 * ui/inspector.js
 *
 * Wire inspector panel (#fp) and module info panel (#mip).
 * Reads from MODULES, WIRES globals. Calls updateMeter() from meter-panel.js.
 *
 * No electrical calculations. No editing logic. No save logic.
 */

// ── Wire inspector panel ──────────────────────────────────────────

function showPanel(w, evt) {
  // Primary: update the sidebar inspector
  if (typeof Sidebar !== 'undefined') Sidebar.onWireSelected(w);
  // If #fp is popped out, also position and update it
  if (fp && fp.style.display === 'flex') {
    const vr = vp.getBoundingClientRect();
    let px = (evt ? evt.clientX - vr.left : 300) + 16;
    let py = (evt ? evt.clientY - vr.top  : 200) - 20;
    if (px + 310 > vp.offsetWidth)  px -= 326;
    if (py + 500 > vp.offsetHeight) py  = vp.offsetHeight - 510;
    if (py < 0) py = 8;
    fp.style.left = px + 'px';
    fp.style.top  = py + 'px';
    updatePanel(w);
  }
}

function updatePanel(w) {
  if (!w) return;
  const fM = MODULES.find(m => m.id === w.from.m);
  const tM = MODULES.find(m => m.id === w.to.m);
  const sc = h(w.c), tc = trH(w.c);
  const sw = tc
    ? `background:linear-gradient(180deg,${sc} 50%,${tc} 50%)`
    : `background:${sc}`;
  $('fp-info').innerHTML = `
    <div class="fpr"><span class="fpk">Property Type</span><span class="fpv">Wire</span></div>
    <div class="fpr"><span class="fpk">Wire</span><span class="fpv"><span class="fpsw" style="${sw}"></span>${w.c} — ${cn(w.c)}</span></div>
    <div class="fpr"><span class="fpk">Label</span><span class="fpv">${w.lbl}</span></div>
    <div class="fpr"><span class="fpk">From</span><span class="fpv">${fM?.label || w.from.m} · ${w.from.t}</span></div>
    <div class="fpr"><span class="fpk">To</span><span class="fpv">${tM?.label || w.to.m} · ${w.to.t}</span></div>
    <div class="fpr" style="margin-top:2px"><span class="fpk">Desc</span><span class="fpv" style="font-size:8px;line-height:1.4">${w.desc || '—'}</span></div>`;
  updateMeter();
}

function closePanel() {
  if (fp) fp.style.display = 'none';
  if (typeof Sidebar !== 'undefined') Sidebar.onWireDeselected();
}

// ── Module info panel ─────────────────────────────────────────────

function selMod(mid, evt) {
  if (selW) { selW = null; leadR = null; leadB = null; clearLeadDots(); tracedWires.clear(); }
  document.querySelectorAll('.mod-card').forEach(c => c.classList.remove('wire-selected', 'mod-selected'));
  const same = selM === mid;
  selM = same ? null : mid;
  if (selM) {
    const card = cardEls[selM];
    if (card) card.classList.add('mod-selected');
    showModInfo(selM, evt);
  } else {
    closeModInfo();
  }
  drawWires();
}

function showModInfo(mid, evt) {
  const m = MODULES.find(x => x.id === mid);
  if (!m) return;
  // Show module info in the sidebar inspector tab
  if (typeof Sidebar !== 'undefined') {
    Sidebar._renderModInfoInSidebar(m);
    Sidebar.tab('inspector');
  }
  // Also populate #mip for popout use if it's already floating
  const mip = $('mip');
  if (mip && mip.style.display === 'flex') {
    renderModInfo(m);
  }
}

function renderModInfo(m) {
  const catColor = CAT_CLR[m.cat] || '#888';
  const wires    = WIRES.filter(w => w.from.m === m.id || w.to.m === m.id);
  $('mip-title').textContent       = m.label;
  $('mip-stripe').style.background = catColor;
  let html = `
    <div class="fpr"><span class="fpk">Property Type</span><span class="fpv">${capitalizeCat(m.cat)}</span></div>
    <div class="fpr"><span class="fpk">Label</span><span class="fpv">${m.label}</span></div>
    <div class="fpr"><span class="fpk">Sub</span><span class="fpv">${m.sub || '—'}</span></div>
    <div class="fpr"><span class="fpk">Category</span><span class="fpv"><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${catColor};margin-right:4px;vertical-align:middle"></span>${m.cat}</span></div>
    <div class="fpr"><span class="fpk">Exit</span><span class="fpv">${m.exit || 'down'}</span></div>`;
  if (m.notes) html += `<div class="fpr"><span class="fpk">Notes</span><span class="fpv" style="font-size:7.5px;line-height:1.5;white-space:pre-wrap">${m.notes}</span></div>`;
  html += `<div class="mip-section-hd">Terminals</div><div class="mip-terms">`;
  m.terminals.forEach(t => {
    const parts     = t.c.split('|');
    const cIn       = parts[0], cOut = parts[1];
    const connWires = wires.filter(w => (w.from.m === m.id && w.from.t === t.n) || (w.to.m === m.id && w.to.t === t.n));
    html += `<div class="mip-term">
      <div class="mip-term-dot" style="background:${h(cIn)}"></div>
      <div class="mip-term-body">
        <div class="mip-term-name">${t.n}${cOut ? ` <span style="color:var(--text-lo)">→</span> <span style="color:${h(cOut)}">${cOut}</span>` : ''}</div>
        <div class="mip-term-color">${cn(cIn)}${cOut && cOut !== cIn ? ` → ${cn(cOut)}` : ''}</div>
        ${connWires.map(w => {
          const other  = w.from.m === m.id ? MODULES.find(x => x.id === w.to.m) : MODULES.find(x => x.id === w.from.m);
          const otherT = w.from.m === m.id ? w.to.t : w.from.t;
          const wsc = h(w.c), wtc = trH(w.c);
          const wsw = wtc ? `background:linear-gradient(90deg,${wsc} 50%,${wtc} 50%)` : `background:${wsc}`;
          return `<div class="mip-wire-link" onclick="selWire(WIRES.find(x=>x.id==='${w.id}'),{clientX:parseInt($('mip').style.left)+260,clientY:parseInt($('mip').style.top)+60});closeModInfo();">
            <span class="mip-wire-sw" style="${wsw}"></span>
            <span class="mip-wire-lbl">${w.lbl}</span>
            <span class="mip-wire-dest">→ ${other?.label || '?'} · ${otherT}</span>
          </div>`;
        }).join('')}
        ${!connWires.length ? `<div class="mip-wire-link" style="color:var(--text-faint);font-style:italic">no connections</div>` : ''}
      </div>
    </div>`;
  });
  html += '</div>';
  $('mip-body').innerHTML = html;
}

function closeModInfo() {
  $('mip').style.display = 'none';
  selM = null;
  document.querySelectorAll('.mod-card').forEach(c => c.classList.remove('mod-selected'));
}
