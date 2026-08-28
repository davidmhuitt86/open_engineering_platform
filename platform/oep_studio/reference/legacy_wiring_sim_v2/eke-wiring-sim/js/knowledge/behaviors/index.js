/**
 * knowledge/behaviors/index.js
 *
 * Component Behavior Registry.
 *
 * The ElectricalSolver calls into this registry to determine how
 * each component/edge behaves electrically.
 *
 * The registry consults individual behavior modules (battery.js,
 * switch.js, relay.js, etc.) and returns a unified answer.
 *
 * Methods called by ElectricalSolver and propagators:
 *   getEdgeBehavior(edge, fromNode, toNode, conditions) → 'open' | 'ground' | number | 'pass'
 *   wireResistance(edge, conditions)                    → Ω
 *   diodeForward(edge, fromNode, toNode, conditions)    → V | null
 *   acVoltage(edge, conditions)                         → V
 *
 * No DOM. No rendering. No UI.
 */

const ComponentBehaviors = {

  /**
   * Determine how an edge behaves when voltage arrives from a node.
   *
   * Returns:
   *   'open'   — edge blocks voltage (switch open, blown fuse, relay open)
   *   'ground' — edge connects to ground (ground path)
   *   number   — edge passes this specific voltage (relay contact drop, etc.)
   *   'pass'   — edge passes source voltage unchanged
   *
   * @param {GraphEdge}            edge
   * @param {GraphNode}            fromNode
   * @param {GraphNode}            toNode
   * @param {SimulationConditions} conditions
   * @returns {'open'|'ground'|number|'pass'}
   */
  getEdgeBehavior(edge, fromNode, toNode, conditions) {
    const kp = conditions.keyPosition || 0;

    // ── Ground node → anything = ground path ─────────────────────
    if (fromNode && fromNode.type === 'ground') return 'ground';
    if (toNode   && toNode.type   === 'ground') return 'ground';

    // ── Ignition switch ───────────────────────────────────────────
    if (fromNode && SwitchBehavior.isIgnitionSwitch(fromNode)) {
      const r = SwitchBehavior.ignitionSwitchResistance(edge.fromTerm, edge.toTerm, kp);
      return r === Infinity ? 'open' : 'pass';
    }
    if (toNode && SwitchBehavior.isIgnitionSwitch(toNode)) {
      const r = SwitchBehavior.ignitionSwitchResistance(edge.fromTerm, edge.toTerm, kp);
      return r === Infinity ? 'open' : 'pass';
    }

    // ── Generic switch (sensor switches: neutral, oil, reverse) ───
    if (fromNode && SwitchBehavior.isSwitch(fromNode)) {
      return SwitchBehavior.sensorSwitchClosed(fromNode, conditions) ? 'pass' : 'open';
    }
    if (toNode && SwitchBehavior.isSwitch(toNode)) {
      return SwitchBehavior.sensorSwitchClosed(toNode, conditions) ? 'pass' : 'open';
    }

    // ── Diode ─────────────────────────────────────────────────────
    const diodeDrop = DiodeBehavior.forwardDrop(edge, fromNode, toNode);
    if (diodeDrop !== null) return 'pass'; // conduction with drop — handled in solver

    // ── Relay contacts ────────────────────────────────────────────
    // (Simplified: full relay simulation requires coil state from prior solve pass)
    // Handled by SWPACK override for the TRX300 start circuit

    // ── SWPACK overrides (TRX300 handlebar switches) ──────────────
    if (window.SWPACK && SWPACK.getReading) {
      const ov = SWPACK.getReading(edge.wire.id, kp);
      if (ov !== null) {
        // SWPACK override exists — pass voltage if CONT !== 'OPN'
        if (ov.CONT === 'OPN' && parseFloat(ov.VDC) === 0) return 'open';
        return 'pass';
      }
    }

    // ── Default: conductors pass voltage ──────────────────────────
    return 'pass';
  },

  /**
   * Wire/component resistance for continuity calculations.
   *
   * @param {GraphEdge}            edge
   * @param {SimulationConditions} conditions
   * @returns {number}  Ω or Infinity
   */
  wireResistance(edge, conditions) {
    const fromNode = EKE.graph ? EKE.graph.nodes.get(edge.fromNode) : null;
    const toNode   = EKE.graph ? EKE.graph.nodes.get(edge.toNode)   : null;
    const kp       = conditions.keyPosition || 0;

    // Switch resistance
    if (fromNode && SwitchBehavior.isIgnitionSwitch(fromNode)) {
      return SwitchBehavior.ignitionSwitchResistance(edge.fromTerm, edge.toTerm, kp);
    }
    if (fromNode && SwitchBehavior.isSwitch(fromNode)) {
      return SwitchBehavior.sensorResistance(fromNode, conditions);
    }
    if (toNode && SwitchBehavior.isSwitch(toNode)) {
      return SwitchBehavior.sensorResistance(toNode, conditions);
    }

    // Lamp resistance
    if (fromNode && LampBehavior.isLamp(fromNode)) return LampBehavior.resistance(0);
    if (toNode   && LampBehavior.isLamp(toNode))   return LampBehavior.resistance(0);

    // Motor resistance
    if (fromNode && MotorBehavior.isMotor(fromNode)) return MotorBehavior.resistance(kp);
    if (toNode   && MotorBehavior.isMotor(toNode))   return MotorBehavior.resistance(kp);

    // Diode resistance
    const diodeDrop = fromNode && toNode ? DiodeBehavior.forwardDrop(edge, fromNode, toNode) : null;
    if (diodeDrop !== null)  return 10;   // conducting — ~10Ω approximation
    if (diodeDrop === null && (fromNode && DiodeBehavior.isDiode(fromNode))) return Infinity; // reverse

    // All other conductors: near-zero resistance
    return 0.1;
  },

  /**
   * Diode forward voltage drop for DIODE TEST mode.
   * Returns null if edge is not a diode.
   *
   * @param {GraphEdge} edge
   * @param {GraphNode} fromNode
   * @param {GraphNode} toNode
   * @param {SimulationConditions} conditions
   * @returns {number|null}
   */
  diodeForward(edge, fromNode, toNode, conditions) {
    return DiodeBehavior.forwardDrop(edge, fromNode, toNode);
  },

  /**
   * AC voltage generated on a wire (stator/alternator wires only).
   * Returns 0 for all non-AC wires.
   *
   * @param {GraphEdge}            edge
   * @param {SimulationConditions} conditions
   * @returns {number}  VAC
   */
  acVoltage(edge, conditions) {
    const kp = conditions.keyPosition || 0;
    const id = edge.wire.id || '';

    // Stator AC wires
    if (id.startsWith('stator-ac')) {
      if (kp === 2) return 8;   // cranking — low AC
      if (kp === 3) return 22;  // running — full AC
      return 0;
    }
    return 0;
  },
};
