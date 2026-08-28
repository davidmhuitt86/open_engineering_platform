/**
 * knowledge/behaviors/lamp.js
 *
 * Electrical behavior of incandescent lamps and indicator bulbs.
 *
 * A lamp is a resistive load. It illuminates when current flows through it.
 * Cold resistance is much lower than hot resistance (tungsten filament).
 *
 * For diagnostic purposes:
 *   - Acts as a load (~120Ω hot, ~10Ω cold)
 *   - Allows current to flow when powered and grounded
 *   - Used in the renderer to determine bulb glow state
 *
 * No DOM. No rendering. No UI.
 */

const LampBehavior = {

  id: 'lamp',

  COLD_RESISTANCE: 10,   // Ω — at room temperature (inrush)
  HOT_RESISTANCE:  120,  // Ω — at operating temperature
  MIN_GLOW_VOLTAGE: 9.0, // V — minimum voltage for visible illumination

  /**
   * Is this node a lamp/lighting component?
   * @param {GraphNode} node
   * @returns {boolean}
   */
  isLamp(node) {
    return node && node.module &&
      (node.module.bulb === true || node.module.cat === 'lighting' || node.module.cat === 'indicator');
  },

  /**
   * Resistance of a lamp at the given voltage.
   * @param {number} voltage
   * @returns {number}  Ω
   */
  resistance(voltage) {
    if (voltage < 0.5) return LampBehavior.COLD_RESISTANCE;
    return LampBehavior.HOT_RESISTANCE;
  },

  /**
   * Is the lamp visibly illuminated?
   * @param {number} voltage
   * @returns {boolean}
   */
  isLit(voltage) {
    return voltage >= LampBehavior.MIN_GLOW_VOLTAGE;
  },
};
