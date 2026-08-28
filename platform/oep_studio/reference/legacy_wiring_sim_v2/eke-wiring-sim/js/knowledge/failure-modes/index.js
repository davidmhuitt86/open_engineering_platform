/**
 * knowledge/failure-modes/index.js
 *
 * Failure mode registry.
 *
 * Defines all supported fault types with their electrical effects,
 * display names, and default parameters.
 *
 * Used by:
 *   diagnostics/fault-injector.js   — to create fault objects
 *   simulation/electrical-solver.js — to apply fault effects
 *   ui/graph-inspector.js           — to display active faults
 *
 * No DOM. No rendering. No UI.
 */

const FailureModes = {

  OPEN_CIRCUIT: {
    id:          'open',
    label:       'Open Circuit',
    description: 'Wire or connection is broken. No current flows.',
    effects: {
      VDC:  '0.00',
      CONT: 'OPN',
      RES:  'OL',
    },
    severity: 'critical',
  },

  SHORT_TO_GROUND: {
    id:          'short-to-gnd',
    label:       'Short to Ground',
    description: 'Wire is shorted to chassis. Voltage collapses. May blow fuse.',
    effects: {
      VDC:  '0.00',
      CONT: '000',
      RES:  '<1Ω',
    },
    severity: 'critical',
  },

  SHORT_TO_POWER: {
    id:          'short-to-pwr',
    label:       'Short to Power',
    description: 'Wire is shorted to battery positive. Fixed voltage regardless of switch state.',
    effects: {
      VDC:  'BATTERY',  // resolved at inject time
      CONT: 'OPN',
      RES:  'OL',
    },
    severity: 'critical',
  },

  HIGH_RESISTANCE: {
    id:          'high-resistance',
    label:       'High Resistance',
    description: 'Poor connection, corroded terminal, or damaged wire. Voltage drop under load.',
    defaultParams: { ohms: 5000, display: '>5kΩ' },
    effects: {
      VDC:  'REDUCED',  // partial voltage
      CONT: 'OPN',      // meter reads open (above threshold)
      RES:  '>5kΩ',
    },
    severity: 'moderate',
  },

  CORROSION: {
    id:          'corrosion',
    label:       'Corrosion',
    description: 'Terminal or connector corrosion. Intermittent contact, elevated resistance.',
    defaultParams: { ohms: 75, display: '50-200Ω' },
    effects: {
      VDC:  'REDUCED',
      CONT: 'OPN',
      RES:  '50-200Ω',
    },
    severity: 'moderate',
  },

  BAD_GROUND: {
    id:          'bad-ground',
    label:       'Bad Ground',
    description: 'Ground connection has high resistance. Component may work intermittently.',
    defaultParams: { ohms: 200, display: '>100Ω' },
    effects: {
      VDC:  '0.00',
      CONT: 'OPN',
      RES:  '>100Ω',
    },
    severity: 'moderate',
  },

  OPEN_RELAY_COIL: {
    id:          'open-relay-coil',
    label:       'Open Relay Coil',
    description: 'Relay coil winding is broken. Relay never activates.',
    effects: {
      COIL_CONT: 'OPN',
      COIL_RES:  'OL',
      CONTACTS:  'never-close',
    },
    severity: 'critical',
  },

  STUCK_RELAY_CONTACTS: {
    id:          'stuck-relay-contacts',
    label:       'Stuck Relay Contacts',
    description: 'Relay contacts are welded closed. Circuit is always connected.',
    effects: {
      CONTACTS: 'always-closed',
    },
    severity: 'moderate',
  },

  BLOWN_FUSE: {
    id:          'blown-fuse',
    label:       'Blown Fuse',
    description: 'Fuse element has opened. Circuit is broken until fuse is replaced.',
    effects: {
      VDC:  '0.00',
      CONT: 'OPN',
      RES:  'OL',
    },
    severity: 'critical',
  },

  // ── Registry methods ──────────────────────────────────────────────

  all() {
    return [
      FailureModes.OPEN_CIRCUIT,
      FailureModes.SHORT_TO_GROUND,
      FailureModes.SHORT_TO_POWER,
      FailureModes.HIGH_RESISTANCE,
      FailureModes.CORROSION,
      FailureModes.BAD_GROUND,
      FailureModes.OPEN_RELAY_COIL,
      FailureModes.STUCK_RELAY_CONTACTS,
      FailureModes.BLOWN_FUSE,
    ];
  },

  getById(id) {
    return FailureModes.all().find(f => f.id === id) || null;
  },
};
