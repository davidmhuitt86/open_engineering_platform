/**
 * js/graph/validators/index.js
 *
 * Runs all graph validators and returns the combined results.
 * Called by bootstrap.js after the graph is built.
 *
 * Results are stored in EKE.validationResults and displayed
 * by ui/graph-inspector.js.
 *
 * No DOM. No rendering. No UI.
 */

const GraphValidators = {

  /** Registered validators in run order. */
  validators: [
    OrphanWireValidator,
    MissingTerminalValidator,
    DuplicateWireValidator,
    FloatingGroundValidator,
    DisconnectedCircuitValidator,
  ],

  /**
   * Run all validators against the built graph and vehicle data.
   *
   * @param {GraphData} graph
   * @param {object}    vehicle
   * @returns {ValidationResult[]}
   */
  runAll(graph, vehicle) {
    const results = [];
    this.validators.forEach(v => {
      try {
        const found = v.validate(graph, vehicle);
        results.push(...found);
      } catch (err) {
        console.error(`[GraphValidators] ${v.name} threw:`, err);
        results.push({
          type:     'validator-error',
          severity: 'error',
          message:  `Validator "${v.name}" failed: ${err.message}`,
        });
      }
    });
    return results;
  },

  /** Count results by severity. */
  summary(results) {
    const errors   = results.filter(r => r.severity === 'error').length;
    const warnings = results.filter(r => r.severity === 'warning').length;
    return { errors, warnings, total: results.length };
  },
};
