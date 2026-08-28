/**
 * ui/graph-inspector.js
 *
 * Debug panel: displays graph statistics and validation results.
 * Hidden behind developer mode (toggled with Ctrl+Shift+G).
 *
 * Shows:
 *   Node count, edge count
 *   Circuit islands
 *   Disconnected components
 *   Validation errors and warnings
 *
 * Reads from: EKE.graph, EKE.validationResults
 * No electrical calculations. No editing logic.
 */

const GraphInspector = {

  _results: [],
  _visible: false,
  _el:      null,

  /**
   * Called by bootstrap after validation runs.
   * @param {ValidationResult[]} results
   */
  setResults(results) {
    this._results = results || [];
    if (this._visible) this.render();
    // Log summary to console always
    const s = GraphValidators.summary(this._results);
    if (s.total > 0) {
      console.warn(`[EKE Graph] ${s.errors} error(s), ${s.warnings} warning(s)`);
      this._results.forEach(r => {
        const fn = r.severity === 'error' ? console.error : console.warn;
        fn(`[${r.type}] ${r.message}`);
      });
    } else {
      console.log('[EKE Graph] Validation passed — no issues found.');
    }
  },

  /** Toggle the panel. Bound to Ctrl+Shift+G in app.js. */
  toggle() {
    this._visible = !this._visible;
    if (this._visible) { this._ensureEl(); this.render(); this._el.style.display = 'block'; }
    else if (this._el)  { this._el.style.display = 'none'; }
  },

  render() {
    const graph = EKE.graph;
    if (!this._el) return;

    const s = GraphValidators.summary(this._results);
    const islands = graph ? CircuitGraph.islands() : [];

    this._el.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
        <b style="font-size:9px;letter-spacing:.08em;text-transform:uppercase;color:#94a3b8">Graph Inspector</b>
        <button onclick="GraphInspector.toggle()" style="background:none;border:none;color:#64748b;cursor:pointer;font-size:11px">✕</button>
      </div>

      <div style="font-size:8px;color:#64748b;margin-bottom:6px;line-height:1.8">
        <div>Nodes: <b style="color:#e2e8f0">${graph ? graph.nodes.size : 0}</b></div>
        <div>Edges: <b style="color:#e2e8f0">${graph ? graph.edges.size : 0}</b></div>
        <div>Islands: <b style="color:${islands.length > 1 ? '#f59e0b' : '#22d3ee'}">${islands.length}</b></div>
      </div>

      <div style="font-size:7.5px;letter-spacing:.06em;text-transform:uppercase;color:#475569;margin-bottom:4px">
        Validation — ${s.errors} error${s.errors !== 1 ? 's' : ''}, ${s.warnings} warning${s.warnings !== 1 ? 's' : ''}
      </div>

      ${!this._results.length
        ? '<div style="font-size:8px;color:#22d3ee">✓ No issues</div>'
        : this._results.map(r => `
            <div style="font-size:7.5px;line-height:1.5;padding:3px 0;border-bottom:1px solid #1e293b;color:${r.severity === 'error' ? '#f87171' : '#f59e0b'}">
              <span style="font-weight:700">[${r.type}]</span> ${r.message}
            </div>`).join('')
      }
    `;
  },

  _ensureEl() {
    if (this._el) return;
    const el = document.createElement('div');
    el.id = 'graph-inspector';
    el.style.cssText = [
      'position:fixed', 'bottom:16px', 'left:16px', 'z-index:9999',
      'background:#0f172a', 'border:1px solid #334155', 'border-radius:6px',
      'padding:12px', 'min-width:280px', 'max-width:360px', 'max-height:420px',
      'overflow-y:auto', 'font-family:monospace', 'box-shadow:0 8px 24px rgba(0,0,0,.5)',
      'display:none',
    ].join(';');
    document.body.appendChild(el);
    this._el = el;
  },
};
