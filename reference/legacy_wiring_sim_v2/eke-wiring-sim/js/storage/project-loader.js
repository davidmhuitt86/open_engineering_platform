/**
 * storage/project-loader.js
 *
 * Load a saved project JSON file (layout + user wires + user modules).
 *
 * No electrical calculations. No rendering. No save logic.
 */

function loadLayoutFile() { $('lfi').click(); }

function onLayoutFile(e) {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = ev => {
    try {
      const data = JSON.parse(ev.target.result);
      // AP-WIRE-GRID-ALIGN-001 — a layout file saved before every module/
      // splice placed its terminals at a fixed GRID-multiple offset from
      // this anchor (renderer.js) won't have grid-exact positions of its
      // own; snapping here is idempotent (already-aligned positions are
      // unchanged), so it's safe to run unconditionally on every load.
      if (data.positions) {
        Object.assign(positions, data.positions);
        Object.keys(data.positions).forEach(id => {
          positions[id].x = Math.round(positions[id].x / GRID) * GRID;
          positions[id].y = Math.round(positions[id].y / GRID) * GRID;
        });
      }
      if (data.wireRoutes) Object.assign(wireRoutes, data.wireRoutes);
      if (data.userConns)  data.userConns.forEach(c => { if (!WIRES.find(x => x.id === c.id))   WIRES.push(c); });
      if (data.userMods)   data.userMods.forEach(m  => { if (!MODULES.find(x => x.id === m.id)) { m._user = true; MODULES.push(m); } });
      placeCards(); drawWires(); buildLegend();
      showToast('Layout loaded');
    } catch (err) {
      showToast('Invalid file', 'err');
    }
  };
  reader.readAsText(file);
  e.target.value = '';
}
