/**
 * js/graph/validators/missing-terminal.js
 *
 * Detects wires that reference a terminal name that does not exist
 * on the referenced module.
 *
 * Cause: terminal was renamed or removed from a module definition
 * after wires were already created referencing the old terminal name.
 *
 * No DOM. No rendering. No UI.
 */

const MissingTerminalValidator = {

  name: 'missing-terminal',

  /**
   * @param {GraphData} graph
   * @param {object}    vehicle
   * @returns {ValidationResult[]}
   */
  validate(graph, vehicle) {
    const results = [];

    vehicle.wires.forEach(w => {
      // Check FROM terminal
      if (graph.nodes.has(w.from.m)) {
        const fromMod  = graph.modules.get(w.from.m);
        const termKey  = `${w.from.m}::${w.from.t}`;
        if (fromMod && !graph.terminals.has(termKey)) {
          results.push({
            type:      'missing-terminal',
            severity:  'error',
            wireId:    w.id,
            moduleId:  w.from.m,
            message:   `Wire "${w.lbl || w.id}" references unknown terminal "${w.from.t}" on module "${fromMod.label || w.from.m}".`,
          });
        }
      }

      // Check TO terminal
      if (graph.nodes.has(w.to.m)) {
        const toMod   = graph.modules.get(w.to.m);
        const termKey = `${w.to.m}::${w.to.t}`;
        if (toMod && !graph.terminals.has(termKey)) {
          results.push({
            type:      'missing-terminal',
            severity:  'error',
            wireId:    w.id,
            moduleId:  w.to.m,
            message:   `Wire "${w.lbl || w.id}" references unknown terminal "${w.to.t}" on module "${toMod.label || w.to.m}".`,
          });
        }
      }
    });

    return results;
  },
};
