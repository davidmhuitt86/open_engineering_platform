/**
 * js/graph/validators/orphan-wire.js
 *
 * Detects wires that reference a module id that does not exist in the graph.
 *
 * Cause: wire was created pointing to a module that was later deleted,
 * or a vehicle data file contains a typo in a module id reference.
 *
 * No DOM. No rendering. No UI.
 */

const OrphanWireValidator = {

  name: 'orphan-wire',

  /**
   * @param {GraphData} graph
   * @param {object}    vehicle
   * @returns {ValidationResult[]}
   */
  validate(graph, vehicle) {
    const results = [];

    vehicle.wires.forEach(w => {
      const fromExists = graph.nodes.has(w.from.m);
      const toExists   = graph.nodes.has(w.to.m);

      if (!fromExists) {
        results.push({
          type:     'orphan-wire',
          severity: 'error',
          wireId:   w.id,
          message:  `Wire "${w.lbl || w.id}" references unknown FROM module "${w.from.m}".`,
        });
      }
      if (!toExists) {
        results.push({
          type:     'orphan-wire',
          severity: 'error',
          wireId:   w.id,
          message:  `Wire "${w.lbl || w.id}" references unknown TO module "${w.to.m}".`,
        });
      }
    });

    return results;
  },
};
