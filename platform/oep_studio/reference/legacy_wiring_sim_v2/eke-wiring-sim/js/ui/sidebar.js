/**
 * ui/sidebar.js
 *
 * Left sidebar: Inspector tab and Meter tab.
 * Rubber-band zoom on the diagram canvas.
 * Lead wire SVG lines from meter jacks to terminal dots.
 * Popout / dock-back for each tab.
 *
 * DESIGN RULE: this file never redefines any function declared in another file.
 * It exposes a Sidebar object that other files call into as hooks.
 * The original functions (setMode, setKey, showPanel, selMod, etc.) are
 * patched non-destructively by appending a call to Sidebar.notify() at
 * the end of each function in their own source files.
 */

const Sidebar = {

  // ── Tab switching ───────────────────────────────────────────────

  tab(name) {
    document.querySelectorAll('.sidebar-tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.sidebar-pane').forEach(p => p.classList.remove('active'));
    const tab  = document.getElementById('tab-'      + name);
    const pane = document.getElementById('sidebar-'  + name);
    if (tab)  tab.classList.add('active');
    if (pane) pane.classList.add('active');
  },

  // ── Wire selection → inspector tab ─────────────────────────────

  onWireSelected(w) {
    Sidebar._renderInspector(w);
    Sidebar._syncMeter();
    Sidebar.drawLeadWires();
  },

  onWireDeselected() {
    Sidebar._renderInspector(null);
    Sidebar._syncMeter();
    Sidebar.drawLeadWires();
  },

  onMeterChange() {
    Sidebar._syncMeter();
    Sidebar.drawLeadWires();
  },

  onLeadsChanged() {
    Sidebar._syncMeter();
    Sidebar.drawLeadWires();
  },

  // ── Inspector render ────────────────────────────────────────────

  _renderInspector(w) {
    const empty   = document.getElementById('si-empty');
    const content = document.getElementById('si-content');
    const info    = document.getElementById('si-info');
    if (!empty || !content) return;

    if (!w) {
      empty.style.display   = '';
      content.style.display = 'none';
      return;
    }

    empty.style.display   = 'none';
    content.style.display = '';

    if (info) {
      const fM = MODULES.find(m => m.id === w.from.m);
      const tM = MODULES.find(m => m.id === w.to.m);
      const sc = h(w.c), tc = trH(w.c);
      const sw = tc ? `background:linear-gradient(180deg,${sc} 50%,${tc} 50%)` : `background:${sc}`;
      info.innerHTML = `
        <div class="fpr"><span class="fpk">Wire</span><span class="fpv"><span class="fpsw" style="${sw}"></span>${w.c} — ${cn(w.c)}</span></div>
        <div class="fpr"><span class="fpk">Label</span><span class="fpv">${w.lbl}</span></div>
        <div class="fpr"><span class="fpk">From</span><span class="fpv">${fM ? fM.label : w.from.m} · ${w.from.t}</span></div>
        <div class="fpr"><span class="fpk">To</span><span class="fpv">${tM ? tM.label : w.to.m} · ${w.to.t}</span></div>
        ${w.desc ? `<div class="fpr"><span class="fpk">Desc</span><span class="fpv" style="font-size:8px;line-height:1.4">${w.desc}</span></div>` : ''}
      `;
    }

    document.querySelectorAll('#si-ks .fp-kb').forEach(b =>
      b.classList.toggle('active', +b.dataset.key === keyPos)
    );

    Sidebar.tab('inspector');
  },


  // ── Module info in sidebar ──────────────────────────────────────

  _renderModInfoInSidebar(m) {
    const empty   = document.getElementById('si-empty');
    const content = document.getElementById('si-content');
    const info    = document.getElementById('si-info');
    if (!empty || !content || !info) return;

    empty.style.display   = 'none';
    content.style.display = '';

    const catColor = CAT_CLR[m.cat] || '#888';
    const wires    = WIRES.filter(w => w.from.m === m.id || w.to.m === m.id);

    info.innerHTML = `
      <div class="fpr" style="margin-bottom:4px">
        <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:${catColor};margin-right:5px;vertical-align:middle"></span>
        <b style="font-size:10px;color:var(--text-hi)">${m.label}</b>
        ${m.sub ? `<span style="color:var(--text-lo);font-size:8px;margin-left:4px">${m.sub}</span>` : ''}
      </div>
      <div class="fpr"><span class="fpk">Category</span><span class="fpv">${m.cat}</span></div>
      <div style="font-size:8px;color:var(--text-lo);letter-spacing:.06em;text-transform:uppercase;margin:6px 0 3px;font-weight:700">Wires (${wires.length})</div>
      ${wires.slice(0,6).map(w => {
        const other = w.from.m === m.id ? MODULES.find(x => x.id === w.to.m) : MODULES.find(x => x.id === w.from.m);
        const sc = h(w.c);
        return `<div style="display:flex;align-items:center;gap:5px;padding:2px 0;border-bottom:1px solid var(--border-0);cursor:pointer" onclick="selWire(WIRES.find(x=>x.id==='${w.id}'),null)">
          <div style="width:8px;height:8px;border-radius:50%;background:${sc};flex-shrink:0"></div>
          <span style="font-size:8px;color:var(--text-md)">${w.lbl}</span>
          <span style="font-size:7.5px;color:var(--text-lo);margin-left:auto">${other ? other.label : '?'}</span>
        </div>`;
      }).join('')}
      ${wires.length > 6 ? `<div style="font-size:8px;color:var(--text-faint);padding-top:3px">+${wires.length-6} more</div>` : ''}
    `;

    // Hide the action buttons that are wire-specific, show module-appropriate ones
    const acts = document.getElementById('si-acts');
    if (acts) acts.innerHTML = `
      <button class="fp-act" onclick="editModProps('${m.id}')">✎ Edit</button>
      <button class="fp-act del" onclick="delModule('${m.id}')">✕ Del</button>
    `;
  },

  // ── Meter SVG sync ──────────────────────────────────────────────

  DIAL_ANGLES: { VDC: 0, VAC: 35, RES: 65, CONT: 95, DIODE: 125 },

  _syncMeter() {
    // Mirror the hidden #lcd-val into the visible SVG display
    const srcVal  = document.getElementById('lcd-val');
    const srcUnit = document.getElementById('lcd-unit');
    const srcMode = document.getElementById('lcd-mode');
    const mVal    = document.getElementById('m-lcd-val');
    const mUnit   = document.getElementById('m-lcd-unit');
    const mMode   = document.getElementById('m-lcd-mode');
    const mNote   = document.getElementById('m-lcd-note-svg');

    if (mVal  && srcVal)  { mVal.textContent  = srcVal.textContent; mVal.setAttribute('fill', srcVal.style.color || '#39ff14'); }
    if (mUnit && srcUnit) mUnit.textContent = srcUnit.textContent;
    if (mMode && srcMode) mMode.textContent = srcMode.textContent;

    const noteEl = document.getElementById('lcd-note');
    if (mNote && noteEl) mNote.textContent = noteEl.textContent;

    // Rotate dial pointer
    const angle = Sidebar.DIAL_ANGLES[meterMode] || 0;
    const ptr = document.getElementById('dial-pointer');
    if (ptr) ptr.setAttribute('transform', `rotate(${angle},110,185)`);

    // Update SVG mode buttons
    ['VDC','VAC','CONT','RES','DIODE'].forEach(mode => {
      const rect = document.getElementById('mbtn-' + mode);
      const txt  = document.getElementById('mbtn-txt-' + mode);
      if (!rect) return;
      const active = (mode === meterMode);
      rect.setAttribute('fill',   active ? '#7c1515' : '#1a0808');
      rect.setAttribute('stroke', active ? '#f59e0b' : '#555');
      if (txt) txt.setAttribute('fill', active ? '#fde68a' : '#94a3b8');
    });

    // Sync lead locations into sidebar
    const fR  = document.getElementById('lead-r-loc');
    const fB  = document.getElementById('lead-b-loc');
    const siR = document.getElementById('si-lead-r-loc');
    const siB = document.getElementById('si-lead-b-loc');
    if (siR && fR) siR.textContent = fR.textContent;
    if (siB && fB) siB.textContent = fB.textContent;

    // Sync key buttons in sidebar inspector
    document.querySelectorAll('#si-ks .fp-kb').forEach(b =>
      b.classList.toggle('active', +b.dataset.key === keyPos)
    );
  },

  // ── Lead wire SVG lines ─────────────────────────────────────────

  drawLeadWires() {
    const wsvg = document.getElementById('wire-layer');
    if (!wsvg) return;
    // Remove old lead lines
    wsvg.querySelectorAll('.lead-wire-r, .lead-wire-b, .lead-probe-dot').forEach(el => el.remove());
    if (!leadR && !leadB) return;

    const vpEl = document.getElementById('viewport');
    if (!vpEl) return;
    const vpRect = vpEl.getBoundingClientRect();

    const drawOne = (lead, jackId, colorClass, probeColor, label) => {
      if (!lead) return;
      const jackEl = document.getElementById(jackId);
      const dotEl  = document.getElementById('d_' + sid(lead.m + '::' + lead.t));
      if (!jackEl || !dotEl) return;

      const jr = jackEl.getBoundingClientRect();
      const dr = dotEl.getBoundingClientRect();

      // Jack center in viewport-relative coords
      const x1 = jr.left + jr.width  / 2 - vpRect.left;
      const y1 = jr.top  + jr.height / 2 - vpRect.top;
      // Dot center in viewport-relative coords
      const x2 = dr.left + dr.width  / 2 - vpRect.left;
      const y2 = dr.top  + dr.height / 2 - vpRect.top;

      // Bezier control point — curve out left then across
      const cx = x1 - 40;
      const cy = (y1 + y2) / 2;

      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', `M${x1.toFixed(0)},${y1.toFixed(0)} C${cx.toFixed(0)},${y1.toFixed(0)} ${cx.toFixed(0)},${cy.toFixed(0)} ${x2.toFixed(0)},${y2.toFixed(0)}`);
      path.classList.add(colorClass);
      wsvg.appendChild(path);

      const dot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      dot.setAttribute('cx', x2.toFixed(0));
      dot.setAttribute('cy', y2.toFixed(0));
      dot.setAttribute('r', '5');
      dot.setAttribute('fill', probeColor);
      dot.setAttribute('stroke', '#fff');
      dot.setAttribute('stroke-width', '1.5');
      dot.classList.add('lead-probe-dot');
      wsvg.appendChild(dot);

      const txt = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      txt.setAttribute('x', x2.toFixed(0));
      txt.setAttribute('y', y2.toFixed(0));
      txt.setAttribute('text-anchor', 'middle');
      txt.setAttribute('dominant-baseline', 'middle');
      txt.setAttribute('fill', '#fff');
      txt.setAttribute('font-size', '6');
      txt.setAttribute('font-weight', '700');
      txt.setAttribute('pointer-events', 'none');
      txt.textContent = label;
      txt.classList.add('lead-probe-dot');
      wsvg.appendChild(txt);
    };

    drawOne(leadR, 'jack-V',   'lead-wire-r', '#dc2626', '+');
    drawOne(leadB, 'jack-COM', 'lead-wire-b', '#1e293b', '−');
  },

  // ── Popout / dock ───────────────────────────────────────────────

  popOut(name) {
    if (name === 'inspector') {
      // Show #fp floating
      const panel = document.getElementById('fp');
      if (!panel) return;
      panel.style.display = 'flex';
      panel.style.left = Math.max(10, window.innerWidth / 2 - 160) + 'px';
      panel.style.top  = '100px';
      // Dim sidebar pane
      const pane = document.getElementById('sidebar-inspector');
      if (pane) pane.style.opacity = '0.35';
      showToast('Inspector popped out — ⊟ to dock');
    } else if (name === 'meter') {
      const pop = document.getElementById('meter-popout');
      if (!pop) return;
      pop.style.display = 'flex';
      pop.style.left = (window.innerWidth - 270) + 'px';
      pop.style.top  = '100px';
      const pane = document.getElementById('sidebar-meter');
      if (pane) pane.style.opacity = '0.35';
      showToast('Meter popped out — ⊟ to dock');
    }
  },

  dockIn(name) {
    if (name === 'inspector') {
      const panel = document.getElementById('fp');
      if (panel) panel.style.display = 'none';
      const pane = document.getElementById('sidebar-inspector');
      if (pane) pane.style.opacity = '';
    } else if (name === 'meter') {
      const pop = document.getElementById('meter-popout');
      if (pop) pop.style.display = 'none';
      const pane = document.getElementById('sidebar-meter');
      if (pane) pane.style.opacity = '';
    }
  },
};

// ── Expose global helpers called from HTML onclick ────────────────

function sidebarTab(name)   { Sidebar.tab(name);       }
function popOut(name)       { Sidebar.popOut(name);     }
function dockIn(name)       { Sidebar.dockIn(name);     }
function setMeterMode(mode) { setMode(mode);             }  // setMode defined in meter-panel.js

// ── Rubber-band zoom ─────────────────────────────────────────────

(function() {
  const vpEl  = document.getElementById('viewport');
  const rbBox = document.getElementById('zoom-box');
  if (!vpEl || !rbBox) return;

  let active = false, startX = 0, startY = 0;

  vpEl.addEventListener('mousedown', e => {
    // Ctrl+drag or Shift+drag to rubber-band zoom
    if (!e.ctrlKey && !e.shiftKey) return;
    if (e.target.closest('.mod-card')) return;
    if (editMode || wireMode || routeEditMode) return;
    e.preventDefault(); e.stopPropagation();
    active = true;
    const r = vpEl.getBoundingClientRect();
    startX = e.clientX - r.left;
    startY = e.clientY - r.top;
    rbBox.style.cssText = `display:block;left:${startX}px;top:${startY}px;width:0;height:0`;
  });

  window.addEventListener('mousemove', e => {
    if (!active) return;
    const r    = vpEl.getBoundingClientRect();
    const curX = e.clientX - r.left;
    const curY = e.clientY - r.top;
    const x = Math.min(startX, curX), y = Math.min(startY, curY);
    const w = Math.abs(curX - startX), h = Math.abs(curY - startY);
    rbBox.style.left = x + 'px'; rbBox.style.top = y + 'px';
    rbBox.style.width = w + 'px'; rbBox.style.height = h + 'px';
  });

  window.addEventListener('mouseup', e => {
    if (!active) return;
    active = false;
    rbBox.style.display = 'none';
    const r    = vpEl.getBoundingClientRect();
    const endX = e.clientX - r.left;
    const endY = e.clientY - r.top;
    const selW = Math.abs(endX - startX);
    const selH = Math.abs(endY - startY);
    if (selW < 20 || selH < 20) return;

    const selLeft = Math.min(startX, endX);
    const selTop  = Math.min(startY, endY);

    // Canvas coords of box
    const cx1 = (selLeft       - tx) / scale;
    const cy1 = (selTop        - ty) / scale;
    const cx2 = (selLeft + selW - tx) / scale;
    const cy2 = (selTop  + selH - ty) / scale;

    const newScale = Math.min(3, Math.max(0.15,
      Math.min(vpEl.offsetWidth  / (cx2 - cx1),
               vpEl.offsetHeight / (cy2 - cy1)) * 0.88
    ));

    scale = newScale;
    tx = vpEl.offsetWidth  / 2 - ((cx1 + cx2) / 2) * scale;
    ty = vpEl.offsetHeight / 2 - ((cy1 + cy2) / 2) * scale;
    applyT(); drawWires();
  });
})();
