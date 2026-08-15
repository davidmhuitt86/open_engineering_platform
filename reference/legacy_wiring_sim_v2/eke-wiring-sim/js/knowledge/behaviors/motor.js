/**
 * knowledge/behaviors/motor.js
 *
 * Electrical behavior of DC motors (primarily the starter motor).
 *
 * A DC motor is a low-resistance inductive load.
 * High current draw during cranking causes voltage sag on the supply.
 *
 * For diagnostic purposes:
 *   - Acts as a load (~0.12Ω cranking, ~0.3Ω running)
 *   - Requires B+ voltage AND grounded BODY terminal to operate
 *   - If resistance measures too high, suspect corroded connections
 *
 * No DOM. No rendering. No UI.
 */

const MotorBehavior = {

  id: 'motor',

  CRANKING_RESISTANCE: 0.12,  // Ω — starter motor under load
  RUNNING_RESISTANCE:  0.30,  // Ω — starter freewheeling
  MIN_CRANK_VOLTAGE:   9.5,   // V — minimum voltage to crank engine

  /**
   * Is this node a motor?
   * @param {GraphNode} node
   * @returns {boolean}
   */
  isMotor(node) {
    return node && node.module && node.module.cat === 'starter';
  },

  /**
   * Resistance of the motor winding.
   * @param {number} keyPosition
   * @returns {number}  Ω
   */
  resistance(keyPosition) {
    return keyPosition === 2
      ? MotorBehavior.CRANKING_RESISTANCE
      : MotorBehavior.RUNNING_RESISTANCE;
  },

  /**
   * Can the motor crank at the given voltage?
   * @param {number} voltage
   * @returns {boolean}
   */
  canCrank(voltage) {
    return voltage >= MotorBehavior.MIN_CRANK_VOLTAGE;
  },
};
