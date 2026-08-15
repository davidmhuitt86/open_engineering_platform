/**
 * js/diagnostics/ground-path.js
 *
 * Answers: "Show all grounds affecting [module]."
 *
 * Delegates all traversal to PathFinder.
 * Returns the ground path and identifies which ground nodes are reachable.
 *
 * Consumes: EKE.graph via PathFinder — never walks WIRES directly.
 *
 * No DOM. No rendering. No UI.
 */

const GroundPath = {

  /**
   * Find the ground path from a source module to the nearest chassis ground.
   *
   * @param {string} sourceModuleId
   * @returns {GroundPathResult}
   */
  find(sourceModuleId) {
    const graph   = EKE.graph;
    const wireIds = PathFinder.findGroundPath(sourceModuleId);

    if (!wireIds || !wireIds.length) {
      return {
        found:       false,
        wireIds:     [],
        nodeIds:     [],
        groundIds:   [],
        description: `No ground path found from "${GroundPath._label(sourceModuleId, graph)}".`,
      };
    }

    const nodeIds   = GroundPath._nodesOnPath(wireIds, graph);
    const groundIds = GroundPath.allGroundsAffecting(sourceModuleId);

    return {
      found:       true,
      wireIds,
      nodeIds,
      groundIds,
      description: PathFinder.describePath(wireIds),
    };
  },

  /**
   * Returns all ground module ids reachable from a source module.
   *
   * @param {string} sourceModuleId
   * @returns {string[]}
   */
  allGroundsAffecting(sourceModuleId) {
    const graph = EKE.graph;
    if (!graph) return [];
    const reachable = GraphTraversal.bfs(graph, sourceModuleId);
    return GraphTraversal.groundNodes(graph).filter(id => reachable.has(id));
  },

  /**
   * Returns all wire ids on the ground path — for diagram highlighting.
   * @param {string} sourceModuleId
   * @returns {Set<string>}
   */
  highlightSet(sourceModuleId) {
    const result = GroundPath.find(sourceModuleId);
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
 *   groundIds: string[],
 *   description: string
 * }} GroundPathResult
 */
