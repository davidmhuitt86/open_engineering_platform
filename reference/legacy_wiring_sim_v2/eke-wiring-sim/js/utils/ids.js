/**
 * utils/ids.js
 *
 * ID generation and sanitization helpers.
 *
 * No DOM. No state.
 */

const Ids = {
  /**
   * Sanitize a string for use as a DOM element id.
   * Replaces all non-alphanumeric characters with underscores.
   * @param {string} s
   * @returns {string}
   */
  sanitize(s) {
    return s.replace(/[^a-z0-9]/gi, '_');
  },

  /**
   * Generate a terminal dot element id from module id and terminal name.
   * Used by renderer.js to build and look up dot elements.
   * @param {string} moduleId
   * @param {string} terminalName
   * @returns {string}  e.g. "d_battery_fuses__B_"
   */
  terminalDotId(moduleId, terminalName) {
    return 'd_' + Ids.sanitize(`${moduleId}::${terminalName}`);
  },

  /**
   * Generate a unique module id from a label.
   * @param {string} label
   * @returns {string}  e.g. "mod-starter-relay-1718234567890"
   */
  newModuleId(label) {
    return 'mod-' + label.toLowerCase().replace(/[^a-z0-9]/g, '-') + '-' + Date.now();
  },

  /**
   * Generate a unique wire id.
   * @returns {string}  e.g. "wire-1718234567890"
   */
  newWireId() {
    return 'wire-' + Date.now();
  },

  /**
   * Check if an id was user-created (vs. base vehicle data).
   * @param {string} id
   * @returns {boolean}
   */
  isUserWireId(id) {
    return id.startsWith('wire-');
  },

  isUserModuleId(id) {
    return id.startsWith('mod-');
  },
};
