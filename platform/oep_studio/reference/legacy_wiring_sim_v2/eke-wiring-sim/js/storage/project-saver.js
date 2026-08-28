/**
 * storage/project-saver.js
 *
 * Save layout + user wires/modules to a JSON file download.
 * Export wire-layer SVG.
 *
 * No electrical calculations. No rendering. No loading logic.
 */

function saveLayout() {
  const data = JSON.stringify({
    positions,
    wireRoutes,
    userConns: WIRES.filter(w => w.id.startsWith('wire-')),
    userMods:  MODULES.filter(m => m._user),
  }, null, 2);
  const blob = new Blob([data], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'trx300-layout.json';
  a.click();
  URL.revokeObjectURL(a.href);
  showToast('Layout saved');
}

function exportSVG() {
  const blob = new Blob([wsvg.outerHTML], { type: 'image/svg+xml' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'trx300-diagram.svg';
  a.click();
  URL.revokeObjectURL(a.href);
  showToast('SVG exported');
}
