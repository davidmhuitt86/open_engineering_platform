/**
 * models/module.js
 *
 * Represents a single electrical component in the system:
 * battery, relay, CDI, switch, sensor, lamp, motor, connector, etc.
 *
 * A module owns its terminals.
 * Wires connect terminals.
 *
 * No DOM. No rendering. No UI.
 */

class EKEModule {
  /**
   * @param {object} opts
   * @param {string}   opts.id
   * @param {string}   opts.label
   * @param {string}   [opts.sub]        - subtitle / part description
   * @param {string}   opts.cat          - category: 'power'|'ground'|'ignition'|'control'|etc.
   * @param {string}   [opts.exit]       - wire exit direction hint: 'up'|'down'|'left'|'right'
   * @param {string}   [opts.notes]
   * @param {boolean}  [opts.bulb]       - render as bulb symbol
   * @param {boolean}  [opts.connector]  - render as pass-through connector
   * @param {boolean}  [opts._user]      - added by user at runtime (not in base vehicle data)
   */
  constructor({ id, label, sub = '', cat, exit = 'down', notes = '', bulb = false, connector = false, _user = false }) {
    this.id        = id;
    this.label     = label;
    this.sub       = sub;
    this.cat       = cat;
    this.exit      = exit;
    this.notes     = notes;
    this.bulb      = bulb;
    this.connector = connector;
    this._user     = _user;

    /** @type {EKETerminal[]} */
    this.terminals = [];
  }

  /** Find a terminal by name. */
  getTerminal(name) {
    return this.terminals.find(t => t.name === name) || null;
  }

  toJSON() {
    return {
      id:        this.id,
      label:     this.label,
      sub:       this.sub       || undefined,
      cat:       this.cat,
      exit:      this.exit,
      notes:     this.notes     || undefined,
      bulb:      this.bulb      || undefined,
      connector: this.connector || undefined,
      _user:     this._user     || undefined,
      terminals: this.terminals.map(t => t.toJSON()),
    };
  }

  /**
   * Hydrate from legacy flat format: { id, label, sub, cat, exit, bulb, connector, terminals:[{n,c}] }
   */
  static fromLegacy(raw) {
    const m = new EKEModule({
      id:        raw.id,
      label:     raw.label,
      sub:       raw.sub,
      cat:       raw.cat,
      exit:      raw.exit,
      notes:     raw.notes,
      bulb:      raw.bulb,
      connector: raw.connector,
      _user:     raw._user,
    });
    (raw.terminals || []).forEach(t => m.terminals.push(EKETerminal.fromLegacy(t, raw.id)));
    return m;
  }
}
