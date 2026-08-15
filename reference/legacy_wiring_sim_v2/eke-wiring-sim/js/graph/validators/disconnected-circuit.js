/**
 * js/graph/validators/disconnected-circuit.js
 *
 * Detects isolated sub-graphs (islands) — groups of modules that have
 * no wired connection to the main circuit.
 *
 * Example: Battery → Fuse → Relay → [gap] → Starter
 * If the relay has no wire to the starter, the starter is on its own island.
 *
 * The main circuit is assumed to be the island containing the first
 * power source (cat === 'power'). All other islands are flagged.
 *
 * Severity: warning — isolated modules may be intentional stubs.
 *
 * No DOM. No rendering. No UI.
 */

const DisconnectedCircuitValidator = {

  name: 'disconnected-circuit',

  /**
   * @param {GraphData} graph
   * @param {object}    vehicle
   * @returns {ValidationResult[]}
   */
  validate(graph, vehicle) {
    const results = [];

    if (graph.nodes.size === 0) return results;

    // Find the islands
    const unvisited = new Set(graph.nodes.keys());
    const islands   = [];

    while (unvisited.size > 0) {
      const start   = unvisited.values().next().value;
      const visited = GraphTraversal.bfs(graph, start);
      islands.push(visited);
      visited.forEach(id => unvisited.delete(id));
    }

    // Single island = fully connected. Nothing to report.
    if (islands.length <= 1) return results;

    // Identify the main island: the largest one, or the one containing a power source
    const powerNodes = GraphTraversal.powerNodes(graph);
    let mainIsland   = islands[0];

    if (powerNodes.length > 0) {
      mainIsland = islands.find(island => island.has(powerNodes[0])) || islands[0];
    } else {
      // Fallback: largest island is main
      mainIsland = islands.reduce((a, b) => a.size >= b.size ? a : b);
    }

    // Flag all other islands
    islands.forEach((island, i) => {
      if (island === mainIsland) return;

      const labels = [...island].map(id => {
        const node = graph.nodes.get(id);
        return node ? (node.label || id) : id;
      });

      results.push({
        type:     'disconnected-circuit',
        severity: 'warning',
        message:  `Isolated circuit island (${island.size} module${island.size !== 1 ? 's' : ''}): ${labels.join(', ')}.`,
        moduleIds: [...island],
      });
    });

    return results;
  },
};
