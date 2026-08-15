/**
 * js/diagnostics/circuit-tracer.js
 *
 * Traces the connected sub-graph reachable from a wire or module.
 * Used to highlight all wires in the same circuit.
 *
 * Consumes: EKE.graph via GraphTraversal — never walks WIRES directly.
 *
 * No DOM. No rendering. No UI.
 */

const CircuitTracer = {

  /**
   * Find all wire ids in the same connected circuit as a given wire.
   *
   * @param {string} wireId
   * @returns {Set<string>}
   */
  traceFromWire(wireId) {
    const graph = EKE.graph;
    if (!graph) return new Set();

    const edge = graph.edges.get(wireId);
    if (!edge) return new Set();

    // Start BFS from both endpoints of the wire
    const reachable = new Set();
    GraphTraversal.bfs(graph, edge.fromNode, node => reachable.add(node.id));
    GraphTraversal.bfs(graph, edge.toNode,   node => reachable.add(node.id));

    return CircuitTracer._wireIdsForNodes(graph, reachable);
  },

  /**
   * Find all wire ids in the same connected circuit as a given module.
   *
   * @param {string} moduleId
   * @returns {Set<string>}
   */
  traceFromModule(moduleId) {
    const graph = EKE.graph;
    if (!graph) return new Set();

    const reachable = GraphTraversal.bfs(graph, moduleId);
    return CircuitTracer._wireIdsForNodes(graph, reachable);
  },

  /**
   * Get the wire objects for a set of traced wire ids.
   * Used by the tracer panel to build its list.
   *
   * @param {Set<string>} wireIds
   * @returns {object[]}
   */
  getWires(wireIds) {
    const graph = EKE.graph;
    if (!graph) return [];
    const result = [];
    wireIds.forEach(id => {
      const edge = graph.edges.get(id);
      if (edge) result.push(edge.wire);
    });
    return result;
  },

  // ── Internal ──────────────────────────────────────────────────────

  _wireIdsForNodes(graph, nodeIds) {
    const wireIds = new Set();
    graph.edges.forEach((edge, wireId) => {
      if (nodeIds.has(edge.fromNode) || nodeIds.has(edge.toNode)) {
        wireIds.add(wireId);
      }
    });
    return wireIds;
  },
};
