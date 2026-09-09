/**
 * knowledge/behaviors/switch.js
 *
 * Electrical behavior of switch-type components.
 *
 * A switch controls continuity between terminals.
 * Open switch = OL (open circuit) between switched terminals.
 * Closed switch = ~0.1Ω between switched terminals.
 *
 * Switch state is determined by:
 *   1. The SimulationConditions.switchStates map  (user-controlled)
 *   2. Key position  (ignition switch behavior)
 *   3. Sensor state  (neutral, oil, reverse switches — determined by engine state)
 *
 * No DOM. No rendering. No UI.
 */

const SwitchBehavior = {

  id: 'switch',

  CLOSED_RESISTANCE: 0.1,  // Ω

  /**
   * Is this node a switch-type component?
   *
   * AP-GENERIC-SWITCH-SIM-001 — also recognizes `groundedSwitch`/
   * `thermistor` (renderer.js's card-dispatch flags) regardless of
   * category, so a user-placed Switch or Temp Sensor module participates
   * in simulation without needing its category changed to the literal
   * string 'switch' first. A thermistor-flagged module is electrically
   * just a switch here too — per direct correction, an oil-temp sender
   * "isn't really a sensor, it's a switch that only fully closes at a
   * set temperature," so it gates continuity exactly like any other
   * on/off switch; the actual temperature is not simulated, only
   * whether the switch is open or closed (§ `sensorSwitchClosed` below).
   * @param {GraphNode} node
   * @returns {boolean}
   */
  isSwitch(node) {
    return !!(node && node.module &&
      (node.module.cat === 'switch' || node.module.groundedSwitch === true || node.module.thermistor === true));
  },

  /**
   * Is this node an ignition switch?
   * @param {GraphNode} node
   * @returns {boolean}
   */
  isIgnitionSwitch(node) {
    return node && node.module && node.module.id === 'ignition-switch';
  },

  /**
   * Determine the resistance through the ignition switch for a given terminal pair.
   * The ignition switch routes battery voltage to different circuits:
   *   BAT1 → IG1  (ignition circuit)    closes on key-on
   *   BAT2 → IG1  (switched power)      closes on key-on
   *   BAT3 → always hot (tail circuit)  always closed
   *
   * @param {string} fromTerm
   * @param {string} toTerm
   * @param {number} keyPosition
   * @returns {number}  Ω or Infinity
   */
  ignitionSwitchResistance(fromTerm, toTerm, keyPosition) {
    const pair = [fromTerm, toTerm].sort().join('-');
    switch (pair) {
      // Always-hot lines (connect regardless of key)
      case 'B+(PW)-tail':
      case 'B-Ω':
        return SwitchBehavior.CLOSED_RESISTANCE;

      // Switched lines (close when key ≥ 1)
      case 'BAT1-IG1':
      case 'BAT2-IG1':
      case 'BAT2-IG2':
      case 'BAT1-BAT2':
      case 'BAT2-BAT3':
        return keyPosition >= 1 ? SwitchBehavior.CLOSED_RESISTANCE : Infinity;

      default:
        // Unknown pair — model as open
        return Infinity;
    }
  },

  /**
   * Determine whether a sensor switch (neutral, oil, reverse) is closed.
   * These are normally-open switches that close under specific conditions.
   *
   * @param {GraphNode}            node
   * @param {SimulationConditions} conditions
   * @returns {boolean}  true = closed (contacts touching)
   */
  sensorSwitchClosed(node, conditions) {
    const id = node.module.id;
    const engine = conditions.engineState || {};

    switch (id) {
      case 'neutral-switch':  return engine.inNeutral  || false;
      case 'reverse-switch':  return engine.inReverse  || false;
      case 'oil-temp-switch': return engine.oilOverTemp || false;
      default:
        // Generic switch: check switchStates map
        return (conditions.switchStates || {})[id] === 'closed';
    }
  },

  /**
   * Resistance for a sensor switch.
   * @param {GraphNode}            node
   * @param {SimulationConditions} conditions
   * @returns {number}
   */
  sensorResistance(node, conditions) {
    return SwitchBehavior.sensorSwitchClosed(node, conditions)
      ? SwitchBehavior.CLOSED_RESISTANCE
      : Infinity;
  },
};
