/**
 * js/simulation/electrical-solver.js
 *
 * Master simulation coordinator.
 *
 * Orchestrates voltage propagation, ground propagation, and continuity
 * solving to produce a complete electrical state for the current
 * simulation conditions.
 *
 * This is the core of the Electrical Behavior Engine.
 *
 * Flow:
 *   SimulationConditions
 *         ↓
 *   VoltagePropagator   → nodeVoltage map
 *   GroundPropagator    → nodeGround map
 *   ContinuitySolver    → per-wire continuity
 *         ↓
 *   ElectricalState     (nodeVoltage, nodeGround, wireReadings)
 *         ↓
 *   MeterEngine         (reads from ElectricalState, not measurements.json)
 *
 * Priority order for readings:
 *   1. Active fault override
 *   2. SWPACK switch-pack override (TRX300 handlebar switches)
 *   3. Electrical solver (calculated)
 *   4. Static measurements.json (fallback / training data)
 *
 * No DOM. No rendering. No UI.
 */

const ElectricalSolver = {

  /**
   * Solve the complete electrical state of the vehicle graph
   * under the given conditions.
   *
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {ElectricalState}
   */
  solve(graph, conditions) {
    const nodeVoltage = VoltagePropagator.propagate(graph, conditions);
    const nodeGround  = GroundPropagator.propagate(graph, conditions);

    /** @type {Map<string, WireReading>} wireId → computed reading */
    const wireReadings = new Map();

    graph.edges.forEach((edge, wireId) => {
      wireReadings.set(wireId, ElectricalSolver._solveWire(edge, nodeVoltage, nodeGround, graph, conditions));
    });

    return {
      nodeVoltage,
      nodeGround,
      wireReadings,
      conditions,
      solvedAt: Date.now(),
    };
  },

  /**
   * Get the calculated meter reading for a single wire.
   * Does NOT fall back to static measurements — use MeterEngine for that.
   *
   * @param {string}               wireId
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {WireReading}
   */
  readWire(wireId, graph, conditions) {
    const state = ElectricalSolver.solve(graph, conditions);
    return state.wireReadings.get(wireId) || ElectricalSolver._blankReading();
  },

  /**
   * Check whether a module is fully functional under current conditions.
   * Requires: voltage at node AND valid ground path.
   *
   * @param {string}               nodeId
   * @param {ElectricalState}      state
   * @returns {{ powered: boolean, grounded: boolean, functional: boolean }}
   */
  moduleStatus(nodeId, state) {
    const powered   = (state.nodeVoltage.get(nodeId) || 0) > 0.5;
    const grounded  = state.nodeGround.get(nodeId) || false;
    return { powered, grounded, functional: powered && grounded };
  },

  // ── Internal ──────────────────────────────────────────────────────

  _solveWire(edge, nodeVoltage, nodeGround, graph, conditions) {
    const fromV = nodeVoltage.get(edge.fromNode) || 0;
    const toV   = nodeVoltage.get(edge.toNode)   || 0;
    const wireV = Math.max(fromV, toV);

    // Fault check — overrides everything
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault) return ElectricalSolver._faultReading(fault, wireV, conditions);
    }

    // Diode behavior
    const fromNode = graph.nodes.get(edge.fromNode);
    const toNode   = graph.nodes.get(edge.toNode);
    const diodeV   = ComponentBehaviors.diodeForward(edge, fromNode, toNode, conditions);
    if (diodeV !== null) {
      return ElectricalSolver._diodeReading(diodeV);
    }

    // Continuity: wire has continuity when it lies on a conductive path to ground
    const fromGrounded = nodeGround.get(edge.fromNode) || false;
    const toGrounded   = nodeGround.get(edge.toNode)   || false;
    const cont = fromGrounded || toGrounded;

    // Resistance from continuity solver
    const resistance = ContinuitySolver._wireResistance(edge, conditions);

    // AC voltage for stator/charging wires
    const acV = ComponentBehaviors.acVoltage(edge, conditions);

    return {
      VDC:   wireV > 0.1 ? wireV.toFixed(2) : '0.00',
      VAC:   acV  > 0    ? ElectricalSolver._formatAC(acV, conditions.keyPosition) : '0.00',
      CONT:  resistance < Infinity ? ContinuitySolver.formatContinuity(cont) : 'OPN',
      RES:   ContinuitySolver.formatResistance(resistance),
      DIODE: 'OL',
      note:  ElectricalSolver._note(wireV, cont, conditions.keyPosition),
    };
  },

  _faultReading(fault, wireV, conditions) {
    switch (fault.type) {
      case 'open':
      case 'blown-fuse':
        return { VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:`OPEN: ${fault.type}` };
      case 'short-to-gnd':
        return { VDC:'0.00', VAC:'0.00', CONT:'000', RES:'<1Ω', DIODE:'OL', note:'SHORT TO GROUND' };
      case 'short-to-pwr':
        return { VDC: VoltagePropagator._batteryVoltage(conditions).toFixed(2), VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:'SHORT TO POWER' };
      case 'high-resistance':
        return { VDC: (wireV * 0.4).toFixed(2), VAC:'0.00', CONT:'OPN', RES:fault.params?.display || '>5kΩ', DIODE:'OL', note:'HIGH RESISTANCE' };
      case 'bad-ground':
        return { VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'>100Ω', DIODE:'OL', note:'BAD GROUND' };
      case 'corrosion':
        return { VDC: (wireV * 0.7).toFixed(2), VAC:'0.00', CONT:'OPN', RES:'50-200Ω', DIODE:'OL', note:'CORROSION' };
      default:
        return ElectricalSolver._blankReading();
    }
  },

  _diodeReading(forwardV) {
    return { VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE: forwardV.toFixed(3), note:'Diode forward drop' };
  },

  _formatAC(v, keyPos) {
    if (keyPos === 2) return `${Math.round(v * 0.5)}-${Math.round(v)}`;
    return `${Math.round(v * 0.9)}-${Math.round(v * 1.1)}`;
  },

  _note(voltage, grounded, keyPos) {
    if (keyPos === 0) return 'Key off';
    if (voltage > 0.5 && grounded) return 'Circuit complete';
    if (voltage > 0.5 && !grounded) return 'Voltage present — check ground';
    if (voltage < 0.1 && grounded)  return 'Ground path OK — no supply voltage';
    return 'No power';
  },

  _blankReading() {
    return { VDC:'0.00', VAC:'0.00', CONT:'OPN', RES:'OL', DIODE:'OL', note:'' };
  },
};

/**
 * @typedef {{
 *   nodeVoltage:  Map<string, number>,
 *   nodeGround:   Map<string, boolean>,
 *   wireReadings: Map<string, WireReading>,
 *   conditions:   SimulationConditions,
 *   solvedAt:     number
 * }} ElectricalState
 *
 * @typedef {{
 *   VDC: string, VAC: string, CONT: string, RES: string, DIODE: string, note: string
 * }} WireReading
 */
