/**
 * utils/colors.js
 *
 * Wire color codes, display names, and hex values.
 * Category accent colors.
 *
 * Phase 1: these constants live at the top of renderer.js (diagram.js)
 * as CAT_CLR, HEX, CNAMES, and helper functions h(), trH(), cn().
 *
 * Phase 2 goal: extract here so any module can import colors without
 * depending on the renderer.
 *
 * Pure data and pure functions. No DOM. No state.
 */

/** Hex colors for each component category. */
const CAT_COLORS = {
  indicator: '#7c3aed',
  ignition:  '#dc2626',
  control:   '#2563eb',
  accessory: '#ea580c',
  charging:  '#d97706',
  ground:    '#374151',
  lighting:  '#0891b2',
  switch:    '#059669',
  starter:   '#9333ea',
  power:     '#b45309',
  connector: '#0e7490',
};

/** Hex colors for wire color codes. */
const WIRE_HEX = {
  Bl:  '#1e293b',
  Br:  '#7c2d12',
  R:   '#dc2626',
  G:   '#15803d',
  Gr:  '#9ca3af',
  Lg:  '#4ade80',
  Y:   '#ca8a04',
  W:   '#94a3b8',
  Bu:  '#2563eb',
  Blu: '#2563eb',
  O:   '#ea580c',
  P:   '#ec4899',
  '—': '#999',
};

/** Human-readable names for wire color codes. */
const WIRE_NAMES = {
  Bl:    'Black',
  Br:    'Brown',
  R:     'Red',
  G:     'Green',
  Gr:    'Gray',
  Lg:    'Lt Green',
  Y:     'Yellow',
  W:     'White',
  Bu:    'Blue',
  Blu:   'Blue',
  O:     'Orange',
  P:     'Pink',
  'P/W':   'Pink/White',
  'Y/R':   'Yellow/Red',
  'Bl/Y':  'Black/Yellow',
  'Blu/Y': 'Blue/Yellow',
  'Bl/W':  'Black/White',
  'Y/W':   'Yellow/White',
  'Lg/R':  'Lt Grn/Red',
  'G/R':   'Green/Red',
  'Br/R':  'Brown/Red',
  'Blu/R': 'Blue/Red',
};

const Colors = {
  /**
   * Primary hex color for a wire color code.
   * @param {string} code  e.g. "R", "Bl/Y"
   * @returns {string}  hex color
   */
  wireHex(code) {
    if (!code) return '#888';
    const k = code.trim();
    if (WIRE_HEX[k]) return WIRE_HEX[k];
    return WIRE_HEX[k.split('/')[0].trim()] || '#666';
  },

  /**
   * Stripe (secondary) hex for a bi-color wire, or null for solid colors.
   * @param {string} code
   * @returns {string|null}
   */
  stripeHex(code) {
    if (!code) return null;
    const i = code.indexOf('/');
    if (i < 0) return null;
    return WIRE_HEX[code.slice(i + 1).trim()] || null;
  },

  /**
   * Human-readable name for a wire color code.
   * @param {string} code
   * @returns {string}
   */
  wireName(code) {
    return WIRE_NAMES[code] || code || '—';
  },

  /**
   * Hex accent color for a component category.
   * @param {string} cat
   * @returns {string}
   */
  categoryHex(cat) {
    return CAT_COLORS[cat] || '#888';
  },
};
