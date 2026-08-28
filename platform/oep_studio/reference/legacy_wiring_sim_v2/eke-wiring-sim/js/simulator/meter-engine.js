/**
 * simulator/meter-engine.js
 *
 * Returns multimeter readings for a wire at the current key position.
 *
 * Phase 1: reading lookup and display logic lives in app.js (updateMeter,
 *          autoPlaceLeads, setLeadMode, updateLeadLocDisplay).
 *          swpack.js registers switch-pack override functions.
 *
 * Phase 2 goal: MeterEngine class below becomes the authority.
 *
 * Reading resolution order:
 *   1. Active fault override (if a fault targets this wire)
 *   2. Switch-pack override (SWPACK.getReading if registered)
 *   3. Static reading from wire.readings[keyPosition]
 *
 * Consumes: measurements.json (via wire.readings array)
 * Future:   real electrical solver (voltage-engine, continuity-engine)
 *
 * No DOM. No rendering.
 */

const METER_MODES = {
  VDC:   { label: 'DC VOLTAGE',   unit: 'V'  },
  VAC:   { label: 'AC VOLTAGE',   unit: 'V~' },
  CONT:  { label: 'CONTINUITY',   unit: ''   },
  RES:   { label: 'RESISTANCE',   unit: 'Ω'  },
  DIODE: { label: 'DIODE TEST',   unit: 'V'  },
};

class MeterEngine {
  /**
   * @param {SimulatorStateManager} stateManager
   */
  constructor(stateManager) {
    this.state = stateManager;
  }

  /**
   * Get the full reading object for a wire at the current key position,
   * applying any active overrides.
   *
   * @param {EKEWire|object} wire  - EKEWire or legacy wire object
   * @returns {{ VDC, VAC, CONT, RES, DIODE, note }}
   */
  getReading(wire) {
    const keyPos = this.state.keyPosition;

    // 1. Active fault override
    // (Phase 3: check this.state.faults for wire.id)

    // 2. Switch-pack override (legacy SWPACK compatibility)
    if (typeof SWPACK !== 'undefined' && SWPACK.getReading) {
      const override = SWPACK.getReading(wire.id, keyPos);
      if (override) return override;
    }

    // 3. Static reading from wire data
    const readings = wire.readings || wire.R;
    if (readings && readings[keyPos]) return readings[keyPos];

    return { VDC: '0.00', VAC: '0.00', CONT: 'OPN', RES: 'OL', DIODE: 'OL', note: '' };
  }

  /**
   * Get the display value for a specific meter mode.
   * Applies continuity visual formatting.
   *
   * @param {EKEWire|object} wire
   * @param {string} mode  - 'VDC' | 'VAC' | 'CONT' | 'RES' | 'DIODE'
   * @returns {{ value: string, color: string, unit: string, label: string, note: string }}
   */
  getDisplay(wire, mode) {
    const rd    = this.getReading(wire);
    const raw   = rd[mode] || '0.00';
    const info  = METER_MODES[mode] || METER_MODES.VDC;
    let   value = raw;
    let   color = 'var(--lcd-fg)';

    if (mode === 'CONT') {
      if (raw === '000' || raw === '0.00') { value = '· · ·'; color = '#22d3ee'; }
      else if (raw === 'OPN')             { value = 'OPN';   color = '#ff6b6b'; }
    }

    return {
      value,
      color,
      unit:  mode === 'CONT' ? '' : info.unit,
      label: info.label,
      note:  rd.note || '',
    };
  }

  /**
   * Does current appear to be flowing through this wire at the current state?
   * Used to drive flow animation direction.
   *
   * @param {EKEWire|object} wire
   * @returns {boolean}
   */
  hasFlow(wire) {
    if (this.state.keyPosition === 0) return false;
    const rd = this.getReading(wire);
    const v  = parseFloat(rd.VDC || '0');
    if (isNaN(v) || v === 0) return false;
    if (rd.CONT === 'OPN') return false;
    return true;
  }
}
