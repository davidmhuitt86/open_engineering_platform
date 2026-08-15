/**
 * storage/vehicle-loader.js
 *
 * Loads a vehicle by id from diagrams/{id}/.
 *
 * Works on BOTH file:// and http://:
 *   - On file://  → reads from window.EKE_BUNDLE[id] (pre-loaded by data-bundle.js)
 *   - On http://  → fetches the 5 JSON files directly
 *
 * Returns:
 *   vehicle.metadata      — project.json fields
 *   vehicle.modules       — runtime module objects (legacy field names for app.js/renderer.js)
 *   vehicle.wires         — runtime wire objects (legacy field names + R[] readings merged)
 *   vehicle.measurements  — raw measurements keyed by wireId
 *   vehicle.layout        — { moduleId: { x, y } }
 *
 * No DOM. No rendering. No electrical logic.
 */

const VehicleLoader = {

  /**
   * Load a vehicle by id.
   * Automatically selects bundle or fetch based on protocol.
   *
   * @param {string} vehicleId  e.g. "trx300"
   * @returns {Promise<object>}
   */
  async load(vehicleId) {
    const raw = location.protocol === 'file:'
      ? VehicleLoader._fromBundle(vehicleId)
      : await VehicleLoader._fromFetch(vehicleId);

    return {
      metadata:     raw.project,
      modules:      VehicleLoader._buildModules(raw.modules),
      wires:        VehicleLoader._buildWires(raw.wires.wires, raw.measurements),
      measurements: raw.measurements,
      layout:       raw.layout,
    };
  },

  // ── Bundle reader (file://) ───────────────────────────────────────

  _fromBundle(vehicleId) {
    const bundle = window.EKE_BUNDLE && window.EKE_BUNDLE[vehicleId];
    if (!bundle) {
      throw new Error(
        `No bundle found for vehicle "${vehicleId}". ` +
        `Ensure diagrams/${vehicleId}/data-bundle.js is loaded in index.html.`
      );
    }
    return bundle;
  },

  // ── Fetch reader (http://) ────────────────────────────────────────

  async _fromFetch(vehicleId) {
    const base    = `diagrams/${vehicleId}`;
    const project = await VehicleLoader._fetch(`${base}/project.json`);

    const [modules, wires, measurements, layout] = await Promise.all([
      VehicleLoader._fetch(`${base}/${project.modules}`),
      VehicleLoader._fetch(`${base}/${project.wires}`),
      VehicleLoader._fetch(`${base}/${project.measurements}`),
      VehicleLoader._fetch(`${base}/${project.layout}`),
    ]);

    return { project, modules, wires, measurements, layout };
  },

  async _fetch(path) {
    const res = await fetch(path);
    if (!res.ok) throw new Error(`VehicleLoader: failed to fetch ${path} (HTTP ${res.status})`);
    return res.json();
  },

  // ── Module builder ────────────────────────────────────────────────
  // JSON:    { id, label, sublabel, category, exit, terminals:[{name,color}] }
  // Runtime: { id, label, sub, cat, exit, terminals:[{n,c}], bulb?, connector? }

  _buildModules(modulesArray) {
    return modulesArray.map(m => {
      const obj = {
        id:        m.id,
        label:     m.label,
        sub:       m.sublabel || '',
        cat:       m.category,
        exit:      m.exit || 'down',
        terminals: (m.terminals || []).map(t => ({ n: t.name, c: t.color })),
      };
      if (m.bulb)      obj.bulb      = true;
      if (m.connector) obj.connector = true;
      if (m.notes)     obj.notes     = m.notes;
      return obj;
    });
  },

  // ── Wire builder ──────────────────────────────────────────────────
  // JSON wire: { id, color, label, description, from:{module,terminal}, to:{module,terminal} }
  // Measurements: { wireId: { OFF_OFF:{}, ON_OFF:{}, CRANKING:{}, RUNNING:{} } }
  // Runtime: { id, c, lbl, desc, from:{m,t}, to:{m,t}, R:[4 readings] }

  _buildWires(wiresArray, measurements) {
    const KEY_ORDER = ['OFF_OFF', 'ON_OFF', 'CRANKING', 'RUNNING'];
    const blank = () => ({ VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:'' });

    return wiresArray.map(w => {
      const entry = measurements[w.id];
      const R = KEY_ORDER.map(k =>
        entry && entry[k] ? Object.assign(blank(), entry[k]) : blank()
      );
      return {
        id:   w.id,
        c:    w.color,
        lbl:  w.label,
        desc: w.description || '',
        from: { m: w.from.module, t: w.from.terminal },
        to:   { m: w.to.module,   t: w.to.terminal   },
        R,
      };
    });
  },
};
