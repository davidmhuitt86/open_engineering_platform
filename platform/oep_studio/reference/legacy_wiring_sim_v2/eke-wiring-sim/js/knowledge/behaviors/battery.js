/**
 * knowledge/behaviors/battery.js
 *
 * Electrical behavior of a 12V lead-acid battery.
 *
 * The battery is a power source that provides voltage at its B+ terminal
 * relative to its B- terminal (ground).
 *
 * Voltage output varies by key position (engine state):
 *   Key Off:  12.6V  (resting open-circuit voltage)
 *   Key On:   12.6V  (slight load, assume fully charged)
 *   Cranking: 11.8V  (voltage sag under starter load)
 *   Running:  14.2V  (charging system raises terminal voltage)
 *
 * No DOM. No rendering. No UI.
 */

const BatteryBehavior = {

  id: 'battery',

  /** Voltage at B+ for each key position (0=off, 1=on, 2=cranking, 3=running) */
  VOLTAGE: [12.6, 12.6, 11.8, 14.2],

  /**
   * Return the supply voltage for the given key position.
   * @param {number} keyPosition
   * @returns {number}  volts
   */
  supplyVoltage(keyPosition) {
    return BatteryBehavior.VOLTAGE[keyPosition] || 12.6;
  },

  /**
   * Return the internal resistance at each key position (Ω).
   * Used for voltage-drop calculations under load.
   * @param {number} keyPosition
   * @returns {number}
   */
  internalResistance(keyPosition) {
    if (keyPosition === 2) return 0.05; // slight rise under crank load
    return 0.02;
  },

  /**
   * Is the battery node (cat=power) the source for this edge?
   * @param {GraphNode} node
   * @returns {boolean}
   */
  isSource(node) {
    return node && node.module && node.module.cat === 'power';
  },
};
