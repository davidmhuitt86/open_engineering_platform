/**
 * js/graph/validators/floating-ground.js
 *
 * Detects ground nodes (cat === 'ground') that have no wires connected.
 *
 * A ground module with no edges is a floating ground — it exists in the
 * module list but provides no return path for any circuit.
 *
 * Severity: warning (not necessarily a data error — could be intentional
 * during diagram construction).
 *
 * No DOM. No rendering. No UI.
 */

const FloatingGroundValidator = {

  name: 'floating-ground',

  /**
   * @param {GraphData} graph
   * @param {object}    vehicle
   * @returns {ValidationResult[]}
   */
  validate(graph, vehicle) {
    const results = [];

    graph.nodes.forEach((node, moduleId) => {
      if (node.type !== 'ground') return;
      if (node.edges.length === 0) {
        results.push({
          type:      'floating-ground',
          severity:  'warning',
          moduleId,
          message:   `Ground module "${node.label}" (${moduleId}) has no wires connected.`,
        });
      }
    });

    return results;
  },
};
