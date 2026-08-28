/**
 * js/graph/validators/duplicate-wire.js
 *
 * Detects wires that connect the same two terminals more than once.
 *
 * Duplicates cause ambiguity in path-finding and meter readings.
 * Severity: error — only one wire should exist per terminal pair.
 *
 * No DOM. No rendering. No UI.
 */

const DuplicateWireValidator = {

  name: 'duplicate-wire',

  /**
   * @param {GraphData} graph
   * @param {object}    vehicle
   * @returns {ValidationResult[]}
   */
  validate(graph, vehicle) {
    const results = [];

    // Key: "fromModule::fromTerm→toModule::toTerm" (normalised so order doesn't matter)
    const seen = new Map();

    vehicle.wires.forEach(w => {
      const a = `${w.from.m}::${w.from.t}`;
      const b = `${w.to.m}::${w.to.t}`;
      // Normalise direction so A→B and B→A count as the same pair
      const key = a < b ? `${a}→${b}` : `${b}→${a}`;

      if (seen.has(key)) {
        results.push({
          type:     'duplicate-wire',
          severity: 'error',
          wireId:   w.id,
          message:  `Wire "${w.lbl || w.id}" duplicates an existing connection between "${w.from.m}::${w.from.t}" and "${w.to.m}::${w.to.t}" (first seen: "${seen.get(key)}").`,
        });
      } else {
        seen.set(key, w.id);
      }
    });

    return results;
  },
};
