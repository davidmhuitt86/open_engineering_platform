/**
 * knowledge/behaviors/relay.js
 *
 * Electrical behavior of an automotive relay.
 *
 * A relay has two circuits:
 *   Coil (85/86): Low-current control circuit. When energized, coil creates
 *                 magnetic field that pulls contact arm closed.
 *   Contacts (30/87/87A): High-current switched circuit.
 *                 30 = common
 *                 87 = normally-open (closes when coil energized)
 *                 87A = normally-closed (opens when coil energized)
 *
 * Coil energizes when: voltage at 86 ≥ pickupVoltage AND 85 connected to ground.
 *
 * No DOM. No rendering. No UI.
 */

const RelayBehavior = {

  id: 'relay',

  PICKUP_VOLTAGE:   9.0,   // V — minimum coil voltage to close contacts
  DROPOUT_VOLTAGE:  1.5,   // V — coil voltage below which contacts open
  COIL_RESISTANCE:  70,    // Ω — typical 12V relay coil
  CONTACT_RESISTANCE: 0.1, // Ω — closed contact resistance

  /**
   * Is this node a relay?
   * @param {GraphNode} node
   * @returns {boolean}
   */
  isRelay(node) {
    return node && node.module && node.module.cat === 'control' &&
           (node.module.label || '').toLowerCase().includes('relay');
  },

  /**
   * Determine whether a relay's coil is energized given the node voltage map.
   *
   * The TRX300 starter relay coil connects:
   *   C+ (terminal 86) — receives voltage from start button circuit
   *   C- (terminal 85) — connects to chassis ground
   *
   * @param {GraphNode}          relayNode
   * @param {Map<string,number>} nodeVoltage
   * @param {Map<string,boolean>}nodeGround
   * @returns {boolean}
   */
  coilEnergized(relayNode, nodeVoltage, nodeGround) {
    const nodeId = relayNode.id;

    // Find the coil+ edge (C+ terminal on TRX300 starter relay)
    // Coil energized if coil+ has voltage AND the node itself is grounded
    const nodeV = nodeVoltage.get(nodeId) || 0;
    const grounded = nodeGround.get(nodeId) || false;

    // Simplified: relay is energized if coil+ receives ≥ pickupVoltage
    // A real solver would track per-terminal voltages
    return nodeV >= RelayBehavior.PICKUP_VOLTAGE && grounded;
  },

  /**
   * Return the contact resistance between two relay terminals
   * given current coil state.
   *
   * @param {string}  fromTerm
   * @param {string}  toTerm
   * @param {boolean} coilOn
   * @returns {number}  Ω or Infinity
   */
  contactResistance(fromTerm, toTerm, coilOn) {
    const pair = [fromTerm, toTerm].sort().join('-');
    switch (pair) {
      case 'MB+-MO':      // 30→87 on TRX300 starter relay: closes when coil energized
      case 'C+-MO':
        return coilOn ? RelayBehavior.CONTACT_RESISTANCE : Infinity;
      default:
        return Infinity;
    }
  },
};
