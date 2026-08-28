/**
 * models/vehicle.js
 *
 * Represents a complete electrical system for one vehicle platform.
 * This is the root of the electrical graph.
 *
 * The vehicle owns all modules, wires, and connectors.
 * The diagram is derived from this model — never the other way around.
 *
 * No DOM manipulation. No rendering. No UI.
 */

class Vehicle {
  /**
   * @param {object} opts
   * @param {string} opts.id        - e.g. "trx300"
   * @param {string} opts.label     - e.g. "Honda TRX300"
   * @param {string} [opts.year]
   * @param {string} [opts.platform]
   */
  constructor({ id, label, year = '', platform = '' }) {
    this.id       = id;
    this.label    = label;
    this.year     = year;
    this.platform = platform;

    /** @type {EKEModule[]} */
    this.modules = [];

    /** @type {EKEWire[]} */
    this.wires = [];
  }

  /** Find a module by id. */
  getModule(id) {
    return this.modules.find(m => m.id === id) || null;
  }

  /** Find a wire by id. */
  getWire(id) {
    return this.wires.find(w => w.id === id) || null;
  }

  /** All wires connected to a given module id. */
  wiresOf(moduleId) {
    return this.wires.filter(w => w.from.module === moduleId || w.to.module === moduleId);
  }

  toJSON() {
    return {
      id:       this.id,
      label:    this.label,
      year:     this.year,
      platform: this.platform,
      modules:  this.modules.map(m => m.toJSON()),
      wires:    this.wires.map(w => w.toJSON()),
    };
  }

  /**
   * Hydrate from the flat legacy format used in vehicle-loader.js (_buildModules/_buildWires):
   * { modules:[{id,label,cat,terminals:[{n,c}]}], connections:[{id,from:{m,t},to:{m,t},R:[]}] }
   */
  static fromLegacy(data, meta = {}) {
    const v = new Vehicle({ id: meta.id || 'vehicle', label: meta.label || 'Vehicle', ...meta });
    (data.modules || []).forEach(raw => v.modules.push(EKEModule.fromLegacy(raw)));
    (data.connections || []).forEach(raw => v.wires.push(EKEWire.fromLegacy(raw)));
    return v;
  }
}
