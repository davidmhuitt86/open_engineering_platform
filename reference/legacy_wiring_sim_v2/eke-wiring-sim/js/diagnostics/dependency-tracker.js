/**
 * js/diagnostics/dependency-tracker.js
 *
 * Answers: "What affects this component?"
 *
 * For any module, returns the set of other modules that must be
 * functioning for it to receive power and have a return path to ground.
 *
 * Example — CDI Unit returns:
 *   Battery, Fuse Block, Ignition Switch, Kill Switch,
 *   Pulse Generator, Chassis Ground
 *
 * This becomes the foundation for future AI-assisted diagnostics.
 * The reasoning engine will use dependency data to narrow fault candidates.
 *
 * Consumes: EKE.graph via GraphTraversal — never walks WIRES directly.
 *
 * No DOM. No rendering. No UI.
 */

const DependencyTracker = {

  /**
   * All modules that this module depends on for power.
   * Traces from every power source to the target; collects all nodes on any path.
   *
   * @param {string} moduleId
   * @returns {{ moduleId: string, label: string, type: string }[]}
   */
  dependenciesOf(moduleId) {
    const graph = EKE.graph;
    if (!graph) return [];

    const powerSources = GraphTraversal.powerNodes(graph);
    const onPath       = new Set();

    powerSources.forEach(srcId => {
      const paths = GraphTraversal.allPaths(graph, srcId, moduleId);
      paths.forEach(wireIds => {
        wireIds.forEach(wid => {
          const edge = graph.edges.get(wid);
          if (edge) { onPath.add(edge.fromNode); onPath.add(edge.toNode); }
        });
      });
    });

    // Also include ground modules reachable from the target
    const groundPaths = DependencyTracker._groundPaths(moduleId, graph);
    groundPaths.forEach(id => onPath.add(id));

    // Remove the target itself
    onPath.delete(moduleId);

    return [...onPath].map(id => {
      const node = graph.nodes.get(id);
      return { moduleId: id, label: node ? node.label : id, type: node ? node.type : 'unknown' };
    });
  },

  /**
   * All modules that depend on this module (downstream consumers).
   * These will be affected if this module fails.
   *
   * @param {string} moduleId
   * @returns {{ moduleId: string, label: string, type: string }[]}
   */
  dependentsOf(moduleId) {
    const graph = EKE.graph;
    if (!graph) return [];

    // Everything reachable from this module, excluding itself
    const reachable = GraphTraversal.bfs(graph, moduleId);
    reachable.delete(moduleId);

    return [...reachable].map(id => {
      const node = graph.nodes.get(id);
      return { moduleId: id, label: node ? node.label : id, type: node ? node.type : 'unknown' };
    });
  },

  /**
   * All modules that share the same ground connection as this module.
   *
   * @param {string} moduleId
   * @returns {{ moduleId: string, label: string }[]}
   */
  sharedGrounds(moduleId) {
    const graph = EKE.graph;
    if (!graph) return [];

    // Find all grounds reachable from this module
    const grounds = GraphTraversal.groundNodes(graph);
    const myGrounds = grounds.filter(gndId => {
      const path = GraphTraversal.shortestPath(graph, moduleId, gndId);
      return path !== null;
    });

    if (!myGrounds.length) return [];

    // Find all other modules that share at least one of those grounds
    const shared = new Set();
    myGrounds.forEach(gndId => {
      const reachable = GraphTraversal.bfs(graph, gndId);
      reachable.forEach(id => { if (id !== moduleId && id !== gndId) shared.add(id); });
    });

    return [...shared].map(id => {
      const node = graph.nodes.get(id);
      return { moduleId: id, label: node ? node.label : id };
    });
  },

  /**
   * All modules that share the same power supply (fuse or direct battery connection).
   *
   * @param {string} moduleId
   * @returns {{ moduleId: string, label: string }[]}
   */
  sharedPower(moduleId) {
    const graph = EKE.graph;
    if (!graph) return [];

    // Find the power sources on the path to this module
    const powerSources = GraphTraversal.powerNodes(graph);
    const myPowerSources = powerSources.filter(srcId => {
      const path = GraphTraversal.shortestPath(graph, srcId, moduleId);
      return path !== null;
    });

    if (!myPowerSources.length) return [];

    // Find all other modules reachable from those power sources
    const shared = new Set();
    myPowerSources.forEach(srcId => {
      const reachable = GraphTraversal.bfs(graph, srcId);
      reachable.forEach(id => { if (id !== moduleId) shared.add(id); });
    });

    return [...shared].map(id => {
      const node = graph.nodes.get(id);
      return { moduleId: id, label: node ? node.label : id };
    });
  },


  // ── Phase 5 additions ─────────────────────────────────────────────

  /**
   * What powers this component?
   * Returns the power source nodes and the path wires from source to target.
   *
   * @param {string} moduleId
   * @returns {{ sources: string[], pathWireIds: string[] }}
   */
  whatPowers(moduleId) {
    const graph   = EKE.graph;
    if (!graph) return { sources: [], pathWireIds: [] };
    const sources = GraphTraversal.powerNodes(graph);
    const paths   = [];
    sources.forEach(srcId => {
      const p = GraphTraversal.shortestPath(graph, srcId, moduleId);
      if (p) paths.push(...p);
    });
    return { sources, pathWireIds: [...new Set(paths)] };
  },

  /**
   * What grounds this component?
   * Returns the ground nodes reachable from the target.
   *
   * @param {string} moduleId
   * @returns {{ grounds: string[], pathWireIds: string[] }}
   */
  whatGrounds(moduleId) {
    const graph   = EKE.graph;
    if (!graph) return { grounds: [], pathWireIds: [] };
    const grounds = GraphTraversal.groundNodes(graph);
    const paths   = [];
    grounds.forEach(gndId => {
      const p = GraphTraversal.shortestPath(graph, moduleId, gndId);
      if (p) paths.push(...p);
    });
    const reachableGrounds = grounds.filter(gndId => {
      return GraphTraversal.bfs(graph, moduleId).has(gndId);
    });
    return { grounds: reachableGrounds, pathWireIds: [...new Set(paths)] };
  },

  /**
   * What depends on this component?
   * Returns all modules that require this module to have power.
   *
   * @param {string} moduleId
   * @returns {string[]}
   */
  whatDependsOn(moduleId) {
    return DependencyTracker.dependentsOf(moduleId).map(d => d.moduleId);
  },

  /**
   * What fails if this component fails?
   * Returns modules that will lose power or ground if this module has an open fault.
   * Excludes modules that have alternative paths.
   *
   * @param {string} moduleId
   * @returns {{ moduleId: string, label: string, reason: string }[]}
   */
  whatFailsIf(moduleId) {
    const graph = EKE.graph;
    if (!graph) return [];

    // Find all downstream modules
    const downstream = DependencyTracker.dependentsOf(moduleId);

    // For each, check if there is an alternative path bypassing moduleId
    return downstream.filter(dep => {
      const allPaths = PathFinder.findAllPaths(
        GraphTraversal.powerNodes(graph)[0] || moduleId,
        dep.moduleId
      );
      // If all paths go through moduleId, removing it cuts power
      return allPaths.every(wireIds => {
        return wireIds.some(wid => {
          const edge = graph.edges.get(wid);
          return edge && (edge.fromNode === moduleId || edge.toNode === moduleId);
        });
      });
    }).map(dep => ({
      moduleId: dep.moduleId,
      label:    dep.label,
      reason:   `Depends on ${moduleId} for power`,
    }));
  },

  // ── Internal ──────────────────────────────────────────────────────

  _groundPaths(moduleId, graph) {
    const grounds = GraphTraversal.groundNodes(graph);
    const nodes   = new Set();
    grounds.forEach(gndId => {
      const paths = GraphTraversal.allPaths(graph, moduleId, gndId);
      paths.forEach(wireIds => {
        wireIds.forEach(wid => {
          const edge = graph.edges.get(wid);
          if (edge) { nodes.add(edge.fromNode); nodes.add(edge.toNode); }
        });
      });
    });
    return nodes;
  },
};
