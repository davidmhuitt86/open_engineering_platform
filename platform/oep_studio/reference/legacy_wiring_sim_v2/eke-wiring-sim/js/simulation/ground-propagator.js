/**
 * js/simulation/ground-propagator.js
 *
 * Determines which nodes have a valid ground path.
 *
 * A node has a valid ground if there exists a continuous conductive
 * path from that node to a chassis-ground node, with no open circuits
 * or active faults blocking the path.
 *
 * Used by ElectricalSolver to complete the circuit check:
 * a component needs BOTH power and ground to function.
 *
 * No DOM. No rendering. No UI.
 */

const GroundPropagator = {

  /**
   * Calculate which nodes have a valid ground path under
   * the given simulation conditions.
   *
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {Map<string, boolean>}  nodeId → hasGround
   */
  propagate(graph, conditions) {
    /** @type {Map<string, boolean>} */
    const hasGround = new Map();

    // Seed: ground nodes always have ground
    GraphTraversal.groundNodes(graph).forEach(id => hasGround.set(id, true));

    // BFS outward from all ground nodes
    const queue   = [...hasGround.keys()];
    const visited = new Set(queue);

    while (queue.length) {
      const nodeId = queue.shift();
      const node   = graph.nodes.get(nodeId);
      if (!node) continue;

      node.edges.forEach(edge => {
        const nextId = edge.fromNode === nodeId ? edge.toNode : edge.fromNode;
        if (visited.has(nextId)) return;

        // Check for faults or open-circuit behaviors blocking this return path
        if (GroundPropagator._isBlocked(edge, conditions)) return;

        hasGround.set(nextId, true);
        visited.add(nextId);
        queue.push(nextId);
      });
    }

    // Nodes not reachable from ground = no ground path
    graph.nodes.forEach((_, id) => {
      if (!hasGround.has(id)) hasGround.set(id, false);
    });

    return hasGround;
  },

  /**
   * Check whether a specific node has a valid ground under given conditions.
   *
   * @param {string}               nodeId
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {boolean}
   */
  hasGround(nodeId, graph, conditions) {
    const map = GroundPropagator.propagate(graph, conditions);
    return map.get(nodeId) || false;
  },

  /**
   * Find all nodes that are missing a ground path.
   * Used by diagnostics to identify floating components.
   *
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {string[]}  array of moduleIds with no ground
   */
  floatingNodes(graph, conditions) {
    const map = GroundPropagator.propagate(graph, conditions);
    const result = [];
    map.forEach((grounded, id) => { if (!grounded) result.push(id); });
    return result;
  },

  // ── Internal ──────────────────────────────────────────────────────

  _isBlocked(edge, conditions) {
    // Fault blocks
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault && (fault.type === 'open' || fault.type === 'high-resistance')) return true;
    }
    // High-resistance bad-ground blocks the return path
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault && fault.type === 'bad-ground') return true;
    }
    return false;
  },
};
