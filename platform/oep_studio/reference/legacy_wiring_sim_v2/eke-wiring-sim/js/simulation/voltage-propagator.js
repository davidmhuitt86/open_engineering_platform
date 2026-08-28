/**
 * js/simulation/voltage-propagator.js
 *
 * Propagates voltage from power sources through the circuit graph.
 *
 * Given a set of source conditions (battery voltage, key position),
 * determines the voltage present at every reachable node by walking
 * the graph and applying component behavior rules.
 *
 * This replaces the static measurements.json lookup for DC voltage.
 *
 * Algorithm:
 *   1. Seed all power-source nodes with their supply voltage
 *   2. BFS outward through the graph
 *   3. At each edge (wire), apply any component behavior that gates
 *      or transforms the voltage (switch open/closed, relay contacts, fuse)
 *   4. Record the voltage at each node
 *
 * No DOM. No rendering. No UI.
 */

const VoltagePropagator = {

  /**
   * Calculate the voltage present at every node in the graph
   * under the given simulation conditions.
   *
   * @param {GraphData}          graph
   * @param {SimulationConditions} conditions
   * @returns {Map<string, number>}  nodeId → voltage (V)
   */
  propagate(graph, conditions) {
    /** @type {Map<string, number>} nodeId → solved voltage */
    const nodeVoltage = new Map();

    // Seed: ground nodes are 0V
    GraphTraversal.groundNodes(graph).forEach(id => nodeVoltage.set(id, 0));

    // Seed: power source nodes use their supply voltage
    // Battery voltage depends on key position (running = charging voltage)
    const batteryVoltage = VoltagePropagator._batteryVoltage(conditions);
    GraphTraversal.powerNodes(graph).forEach(id => {
      nodeVoltage.set(id, batteryVoltage);
    });

    // BFS from all power sources simultaneously
    const queue   = [...nodeVoltage.keys()];
    const visited = new Set(queue);

    while (queue.length) {
      const nodeId  = queue.shift();
      const node    = graph.nodes.get(nodeId);
      if (!node) continue;
      const srcV = nodeVoltage.get(nodeId);

      node.edges.forEach(edge => {
        const nextId = edge.fromNode === nodeId ? edge.toNode : edge.fromNode;
        if (visited.has(nextId)) return;

        // Ask the behavior registry whether this wire passes voltage
        const passV = VoltagePropagator._resolveEdgeVoltage(edge, srcV, conditions, graph);

        if (passV !== null) {
          nodeVoltage.set(nextId, passV);
          visited.add(nextId);
          queue.push(nextId);
        }
      });
    }

    // Any unvisited node = 0V (no path to power, or blocked by open circuit)
    graph.nodes.forEach((_, id) => {
      if (!nodeVoltage.has(id)) nodeVoltage.set(id, 0);
    });

    return nodeVoltage;
  },

  /**
   * Get the voltage at a specific node under the given conditions.
   *
   * @param {string}               nodeId
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {number}
   */
  voltageAt(nodeId, graph, conditions) {
    const map = VoltagePropagator.propagate(graph, conditions);
    return map.get(nodeId) || 0;
  },

  /**
   * Get the voltage present on a wire (the lower of its two endpoint voltages,
   * since the wire itself is a conductor — it carries whatever is supplied to it).
   *
   * @param {GraphEdge}            edge
   * @param {Map<string,number>}   nodeVoltage
   * @returns {number}
   */
  voltageOnWire(edge, nodeVoltage) {
    const fromV = nodeVoltage.get(edge.fromNode) || 0;
    const toV   = nodeVoltage.get(edge.toNode)   || 0;
    return Math.max(fromV, toV);
  },

  // ── Internal ──────────────────────────────────────────────────────

  _batteryVoltage(conditions) {
    switch (conditions.keyPosition) {
      case 0: return 12.6;  // key off — battery voltage present on always-hot lines
      case 1: return 12.6;  // key on
      case 2: return 11.8;  // cranking — slight voltage drop
      case 3: return 14.2;  // running — charging system raises voltage
      default: return 12.6;
    }
  },

  /**
   * Resolve what voltage passes through an edge given the source voltage
   * and current simulation conditions.
   *
   * Returns null if the edge blocks voltage (open switch, blown fuse, etc).
   * Returns a voltage if the edge passes current.
   *
   * @param {GraphEdge}            edge
   * @param {number}               srcVoltage
   * @param {SimulationConditions} conditions
   * @param {GraphData}            graph
   * @returns {number|null}
   */
  _resolveEdgeVoltage(edge, srcVoltage, conditions, graph) {
    // Check for injected faults that open this wire
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault) {
        if (fault.type === 'open' || fault.type === 'blown-fuse') return null;
        if (fault.type === 'short-to-gnd') return 0;
        if (fault.type === 'short-to-pwr') return VoltagePropagator._batteryVoltage(conditions);
      }
    }

    // Delegate to component behavior
    const toNode = graph.nodes.get(edge.toNode);
    const fromNode = graph.nodes.get(edge.fromNode);

    // Let the behavior registry determine if voltage passes
    const behavior = ComponentBehaviors.getEdgeBehavior(edge, fromNode, toNode, conditions);
    if (behavior === 'open')   return null;
    if (behavior === 'ground') return 0;
    if (typeof behavior === 'number') return behavior;

    // Default: pass through with negligible drop
    return srcVoltage;
  },
};

/**
 * @typedef {{
 *   keyPosition:  number,
 *   switchStates: Object.<string, string>,
 *   faults:       Map<string, object>
 * }} SimulationConditions
 */
