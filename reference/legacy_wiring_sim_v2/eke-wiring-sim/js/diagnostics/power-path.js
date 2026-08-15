/**
 * js/diagnostics/power-path.js
 *
 * Answers: "Show battery voltage path to [target]."
 *
 * Delegates all traversal to PathFinder.
 * Provides additional context: which modules are on the path,
 * whether the path is complete, and a human-readable description.
 *
 * Consumes: EKE.graph via PathFinder — never walks WIRES directly.
 *
 * No DOM. No rendering. No UI.
 */

const PowerPath = {

  /**
   * Find the power path to a target module.
   * Returns a result object with the wire ids, node labels, and description.
   *
   * @param {string} targetModuleId
   * @returns {PowerPathResult}
   */
  find(targetModuleId) {
    const graph   = EKE.graph;
    const wireIds = PathFinder.findPowerPath(targetModuleId);

    if (!wireIds || !wireIds.length) {
      return {
        found:       false,
        wireIds:     [],
        nodeIds:     [],
        description: `No power path found to "${PowerPath._label(targetModuleId, graph)}".`,
      };
    }

    // Collect node ids along the path
    const nodeIds = PowerPath._nodesOnPath(wireIds, graph);

    return {
      found:       true,
      wireIds,
      nodeIds,
      description: PathFinder.describePath(wireIds),
    };
  },

  /**
   * Returns all wire ids on the power path — for diagram highlighting.
   * @param {string} targetModuleId
   * @returns {Set<string>}
   */
  highlightSet(targetModuleId) {
    const result = PowerPath.find(targetModuleId);
    return new Set(result.wireIds);
  },

  // ── Internal ──────────────────────────────────────────────────────

  _label(moduleId, graph) {
    if (!graph) return moduleId;
    const node = graph.nodes.get(moduleId);
    return node ? node.label : moduleId;
  },

  _nodesOnPath(wireIds, graph) {
    const nodes = new Set();
    wireIds.forEach(wid => {
      const edge = graph && graph.edges.get(wid);
      if (edge) { nodes.add(edge.fromNode); nodes.add(edge.toNode); }
    });
    return [...nodes];
  },
};

/**
 * @typedef {{
 *   found: boolean,
 *   wireIds: string[],
 *   nodeIds: string[],
 *   description: string
 * }} PowerPathResult
 */
