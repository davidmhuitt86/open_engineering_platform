/**
 * models/terminal.js
 *
 * Represents a single connection point on a module.
 * Wires attach to terminals, not to pixel coordinates.
 *
 * For pass-through connectors, a terminal has both an IN and OUT color.
 *
 * No DOM. No rendering. No UI.
 */

class EKETerminal {
  /**
   * @param {object} opts
   * @param {string} opts.name        - e.g. "B+", "GND", "P1"
   * @param {string} opts.moduleId    - owning module id
   * @param {string} opts.color       - wire color code, e.g. "R", "Bl/Y"
   * @param {string} [opts.colorOut]  - for connectors: color on the OUT side (null = same as color)
   * @param {object} [opts.state]     - runtime electrical state (Phase 3)
   */
  constructor({ name, moduleId, color = 'W', colorOut = null, state = null }) {
    this.name     = name;
    this.moduleId = moduleId;
    this.color    = color;
    this.colorOut = colorOut;
    this.state    = state; // Phase 3: { voltage, current, connected }
  }

  /** Unique key across the whole graph: "moduleId::terminalName" */
  get key() {
    return `${this.moduleId}::${this.name}`;
  }

  toJSON() {
    return {
      name:     this.name,
      moduleId: this.moduleId,
      color:    this.color,
      colorOut: this.colorOut || undefined,
    };
  }

  /**
   * Hydrate from legacy { n, c } format.
   * Connectors encode both sides as "IN|OUT" in the c field.
   */
  static fromLegacy({ n, c }, moduleId) {
    const parts    = (c || '').split('|');
    const color    = parts[0] || 'W';
    const colorOut = parts.length > 1 ? (parts[1] || color) : null;
    return new EKETerminal({ name: n, moduleId, color, colorOut });
  }
}
