/**
 * js/diagnostics/path-finder.js
 *
 * Finds electrical paths through the circuit graph.
 *
 * Functions:
 *   findPowerPath(targetModuleId)     → wireId[]   source → target
 *   findGroundPath(sourceModuleId)    → wireId[]   source → nearest ground
 *   findAllPaths(fromId, toId)        → wireId[][] all simple paths
 *   findShortestPath(fromId, toId)    → wireId[]   fewest hops
 *
 * Consumes: EKE.graph via GraphTraversal — never walks WIRES directly.
 *
 * Future UI will call these to highlight Power Path and Ground Path
 * on the diagram, and to animate Fault Trace.
 *
 * No DOM. No rendering. No UI.
 */

const PathFinder = {

  /**
   * Find the shortest path from any power source to a target module.
   * Returns an ordered array of wire ids (source → target),
   * or null if no path exists.
   *
   * @param {string} targetModuleId
   * @returns {string[]|null}
   */
  findPowerPath(targetModuleId) {
    const graph = EKE.graph;
    if (!graph) return null;

    const powerSources = GraphTraversal.powerNodes(graph);
    if (!powerSources.length) return null;

    // Try each power source, return the shortest path found
    let shortest = null;
    powerSources.forEach(srcId => {
      const path = GraphTraversal.shortestPath(graph, srcId, targetModuleId);
      if (path && (!shortest || path.length < shortest.length)) {
        shortest = path;
      }
    });
    return shortest;
  },

  /**
   * Find the shortest path from a source module to any chassis ground.
   * Returns an ordered array of wire ids, or null if no path exists.
   *
   * @param {string} sourceModuleId
   * @returns {string[]|null}
   */
  findGroundPath(sourceModuleId) {
    const graph = EKE.graph;
    if (!graph) return null;

    const grounds = GraphTraversal.groundNodes(graph);
    if (!grounds.length) return null;

    let shortest = null;
    grounds.forEach(gndId => {
      const path = GraphTraversal.shortestPath(graph, sourceModuleId, gndId);
      if (path && (!shortest || path.length < shortest.length)) {
        shortest = path;
      }
    });
    return shortest;
  },

  /**
   * Find all simple paths between two modules.
   * Returns an array of wire-id arrays.
   *
   * @param {string} fromModuleId
   * @param {string} toModuleId
   * @param {number} [maxDepth=20]
   * @returns {string[][]}
   */
  findAllPaths(fromModuleId, toModuleId, maxDepth = 20) {
    const graph = EKE.graph;
    if (!graph) return [];
    return GraphTraversal.allPaths(graph, fromModuleId, toModuleId, maxDepth);
  },

  /**
   * Find the shortest path (fewest hops) between any two modules.
   * Returns an array of wire ids, or null if no path exists.
   *
   * @param {string} fromModuleId
   * @param {string} toModuleId
   * @returns {string[]|null}
   */
  findShortestPath(fromModuleId, toModuleId) {
    const graph = EKE.graph;
    if (!graph) return null;
    return GraphTraversal.shortestPath(graph, fromModuleId, toModuleId);
  },

  /**
   * Describe a path as a human-readable string.
   * Used for diagnostic output and future AI reasoning.
   *
   * @param {string[]} wireIds
   * @returns {string}
   */
  describePath(wireIds) {
    const graph = EKE.graph;
    if (!graph || !wireIds || !wireIds.length) return 'No path.';

    return wireIds.map((wid, i) => {
      const edge = graph.edges.get(wid);
      if (!edge) return `[unknown wire: ${wid}]`;
      const fromNode = graph.nodes.get(edge.fromNode);
      const toNode   = graph.nodes.get(edge.toNode);
      const fromLabel = fromNode ? fromNode.label : edge.fromNode;
      const toLabel   = toNode   ? toNode.label   : edge.toNode;
      return `${fromLabel}.${edge.fromTerm} —[${edge.label || edge.color || wid}]→ ${toLabel}.${edge.toTerm}`;
    }).join('\n');
  },
};
