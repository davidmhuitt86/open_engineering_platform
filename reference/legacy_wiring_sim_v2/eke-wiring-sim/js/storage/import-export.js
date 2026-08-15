/**
 * storage/import-export.js
 *
 * File-level import and export utilities.
 *
 * Phase 1: exportSVG() lives in app.js.
 * Phase 2 goal: ImportExport module with all file I/O here.
 *
 * Exports:
 *   exportSVG(svgElement, filename)       → download .svg
 *   exportJSON(data, filename)            → download .json
 *   importJSON()                          → Promise<object> (file picker)
 *
 * No rendering. No electrical logic.
 */

const ImportExport = {
  /**
   * Trigger a download of the wire-layer SVG.
   * @param {SVGElement} svgElement
   * @param {string} [filename]
   */
  exportSVG(svgElement, filename = 'diagram.svg') {
    const blob = new Blob([svgElement.outerHTML], { type: 'image/svg+xml' });
    const a    = document.createElement('a');
    a.href     = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    URL.revokeObjectURL(a.href);
  },

  /**
   * Trigger a download of a JSON object.
   * @param {object} data
   * @param {string} [filename]
   */
  exportJSON(data, filename = 'export.json') {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const a    = document.createElement('a');
    a.href     = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    URL.revokeObjectURL(a.href);
  },

  /**
   * Open a file picker and parse JSON.
   * @returns {Promise<object>}
   */
  importJSON() {
    return new Promise((resolve, reject) => {
      const input    = document.createElement('input');
      input.type     = 'file';
      input.accept   = '.json,application/json';
      input.onchange = () => {
        const file = input.files && input.files[0];
        if (!file) { reject(new Error('No file selected')); return; }
        const reader = new FileReader();
        reader.onload  = ev => {
          try   { resolve(JSON.parse(ev.target.result)); }
          catch { reject(new Error('Invalid JSON')); }
        };
        reader.onerror = () => reject(new Error('Read error'));
        reader.readAsText(file);
      };
      input.click();
    });
  },
};
