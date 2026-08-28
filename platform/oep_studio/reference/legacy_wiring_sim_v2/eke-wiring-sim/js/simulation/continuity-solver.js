/**
 * js/simulation/continuity-solver.js
 *
 * Determines whether a continuous conductive path exists between
 * any two nodes in the circuit graph.
 *
 * This replaces stored CONT readings in measurements.json.
 *
 * Continuity exists between A and B when:
 *   - A path of wires exists in the graph connecting A to B
 *   - No wire on that path is open-circuited (by fault or component state)
 *   - The circuit is complete (not just a partial path)
 *
 * Note on meter leads:
 *   With the meter set to CONT/RESISTANCE, the circuit is unpowered.
 *   We test bare conductivity — switches must be in the right position
 *   to provide a conductive path, but voltage is irrelevant.
 *
 * No DOM. No rendering. No UI.
 */

const ContinuitySolver = {

  /**
   * Test continuity between two nodes.
   *
   * @param {string}               fromNodeId
   * @param {string}               toNodeId
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {boolean}
   */
  hasContinuity(fromNodeId, toNodeId, graph, conditions) {
    return ContinuitySolver.resistance(fromNodeId, toNodeId, graph, conditions) !== Infinity;
  },

  /**
   * Estimate total resistance between two nodes along the lowest-resistance path.
   *
   * Returns Infinity if no conductive path exists (open circuit).
   * Returns 0 for direct shorts (short-to-ground faults).
   *
   * @param {string}               fromNodeId
   * @param {string}               toNodeId
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {number}  ohms, or Infinity for open circuit
   */
  resistance(fromNodeId, toNodeId, graph, conditions) {
    // Find all paths
    const paths = GraphTraversal.allPaths(graph, fromNodeId, toNodeId);
    if (!paths.length) return Infinity;

    let lowestResistance = Infinity;

    paths.forEach(wireIds => {
      let pathResistance = 0;
      let blocked = false;

      wireIds.forEach(wid => {
        if (blocked) return;
        const edge = graph.edges.get(wid);
        if (!edge) { blocked = true; return; }

        const r = ContinuitySolver._wireResistance(edge, conditions);
        if (r === Infinity) { blocked = true; return; }
        pathResistance += r;
      });

      if (!blocked && pathResistance < lowestResistance) {
        lowestResistance = pathResistance;
      }
    });

    return lowestResistance;
  },

  /**
   * Format a resistance value for meter display.
   *
   * @param {number} ohms
   * @returns {string}  e.g. "OL", "<1Ω", "4.7kΩ", "0.8Ω"
   */
  formatResistance(ohms) {
    if (ohms === Infinity || ohms > 1e6) return 'OL';
    if (ohms === 0)                       return '000';
    if (ohms < 1)                         return '<1Ω';
    if (ohms < 1000)                      return `${ohms.toFixed(1)}Ω`;
    return `${(ohms / 1000).toFixed(1)}kΩ`;
  },

  /**
   * Format continuity for meter display.
   *
   * @param {boolean} hasPath
   * @returns {string}  '000' (beep) or 'OPN'
   */
  formatContinuity(hasPath) {
    return hasPath ? '000' : 'OPN';
  },

  // ── Internal ──────────────────────────────────────────────────────

  /**
   * Resistance of a single wire/edge under current conditions.
   * Returns Infinity for open circuits.
   *
   * @param {GraphEdge}            edge
   * @param {SimulationConditions} conditions
   * @returns {number}
   */
  _wireResistance(edge, conditions) {
    // Fault overrides
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault) {
        if (fault.type === 'open' || fault.type === 'blown-fuse') return Infinity;
        if (fault.type === 'short-to-gnd' || fault.type === 'short-to-pwr') return 0;
        if (fault.type === 'high-resistance') return fault.params?.ohms || 5000;
        if (fault.type === 'bad-ground') return fault.params?.ohms || 200;
        if (fault.type === 'corrosion')  return fault.params?.ohms || 50;
      }
    }

    // Wire resistance — all copper wire is essentially 0Ω for diagnostic purposes
    // Specific component resistances come from the behavior registry
    return ComponentBehaviors.wireResistance(edge, conditions);
  },
};
