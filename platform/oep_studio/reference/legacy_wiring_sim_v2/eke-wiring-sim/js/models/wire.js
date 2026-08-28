/**
 * models/wire.js
 *
 * Represents a wire (electrical connection) between two terminals.
 *
 * A wire contains:
 *   - from / to endpoints (module + terminal name)
 *   - color code
 *   - label and description
 *   - multimeter readings for each key position (0–3)
 *   - bend points for visual routing (layout concern, stored separately in layout.json)
 *
 * No coordinates except bend offsets.
 * No DOM. No rendering. No UI.
 */

class EKEWire {
  /**
   * @param {object} opts
   * @param {string} opts.id
   * @param {{ module: string, terminal: string }} opts.from
   * @param {{ module: string, terminal: string }} opts.to
   * @param {string} [opts.color]
   * @param {string} [opts.label]
   * @param {string} [opts.description]
   * @param {EKEReading[]} [opts.readings]  - 4 entries: key-off / key-on / cranking / running
   */
  constructor({ id, from, to, color = 'W', label = '', description = '', readings = [] }) {
    this.id          = id;
    this.from        = from;        // { module, terminal }
    this.to          = to;          // { module, terminal }
    this.color       = color;
    this.label       = label;
    this.description = description;
    this.readings    = this._normalizeReadings(readings);
  }

  _normalizeReadings(arr) {
    const blank = () => ({ VDC: '0.00', VAC: '0.00', CONT: 'OPN', RES: 'OL', DIODE: 'OL', note: '' });
    const result = [];
    for (let i = 0; i < 4; i++) {
      result.push(arr[i] ? Object.assign(blank(), arr[i]) : blank());
    }
    return result;
  }

  /** Get reading for a key position (0=off, 1=on, 2=cranking, 3=running). */
  getReading(keyPos) {
    return this.readings[keyPos] || this.readings[0];
  }

  toJSON() {
    return {
      id:          this.id,
      from:        this.from,
      to:          this.to,
      color:       this.color,
      label:       this.label,
      description: this.description,
      readings:    this.readings,
    };
  }

  /**
   * Hydrate from legacy format:
   * { id, c, lbl, from:{m,t}, to:{m,t}, desc, R:[{VDC,VAC,CONT,RES,DIODE,note}] }
   */
  static fromLegacy(raw) {
    return new EKEWire({
      id:          raw.id,
      from:        { module: raw.from.m, terminal: raw.from.t },
      to:          { module: raw.to.m,   terminal: raw.to.t   },
      color:       raw.c    || 'W',
      label:       raw.lbl  || '',
      description: raw.desc || '',
      readings:    (raw.R || []).map(r => ({
        VDC:   r.VDC   || '0.00',
        VAC:   r.VAC   || '0.00',
        CONT:  r.CONT  || 'OPN',
        RES:   r.RES   || 'OL',
        DIODE: r.DIODE || 'OL',
        note:  r.note  || '',
      })),
    });
  }
}
