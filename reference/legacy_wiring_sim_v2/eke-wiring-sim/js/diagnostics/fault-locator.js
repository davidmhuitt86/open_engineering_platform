/**
 * js/diagnostics/fault-locator.js
 *
 * Answers: "What could cause [symptom]?"
 *
 * Combines circuit-tracer, power-path, ground-path, and dependency-tracker
 * to generate a ranked list of possible fault causes for a given symptom.
 *
 * Phase 4: integrate with AI reasoning engine for natural-language diagnosis.
 *
 * Consumes: EKE.graph — never walks MODULES or WIRES directly.
 *
 * No DOM. No rendering. No UI.
 */

const FaultLocator = {

  /**
   * Diagnose why a module might not be functioning.
   * Returns an ordered list of findings, most likely first.
   *
   * @param {string} moduleId
   * @returns {Finding[]}
   */
  diagnose(moduleId) {
    const graph = EKE.graph;
    if (!graph) return [{ cause: 'Graph not built', confidence: 0, testSteps: [] }];

    const node = graph.nodes.get(moduleId);
    if (!node) return [{ cause: `Module "${moduleId}" not found in graph`, confidence: 0, testSteps: [] }];

    const findings = [];

    // 1. Check power path
    const powerPath = PathFinder.findPowerPath(moduleId);
    if (!powerPath) {
      findings.push({
        cause:      `No power path to ${node.label}`,
        confidence: 0.9,
        moduleId,
        testSteps: [
          { description: 'Check for blown fuse on supply circuit', expectedReading: 'Continuity' },
          { description: `Verify battery voltage at power source`, expectedReading: '12.6V DC' },
        ],
      });
    }

    // 2. Check ground path
    const groundPath = PathFinder.findGroundPath(moduleId);
    if (!groundPath) {
      findings.push({
        cause:      `No ground path from ${node.label}`,
        confidence: 0.8,
        moduleId,
        testSteps: [
          { description: `Check ground wire continuity from ${node.label} to chassis`, expectedReading: '<1Ω' },
          { description: 'Check ground bolt for corrosion or looseness', expectedReading: 'Visual OK' },
        ],
      });
    }

    // 3. Check for open wires on power path
    if (powerPath) {
      const openWires = FaultLocator._findOpenWiresOnPath(powerPath, graph);
      openWires.forEach(wireId => {
        const edge = graph.edges.get(wireId);
        findings.push({
          cause:      `Open circuit on wire "${edge ? edge.label : wireId}"`,
          confidence: 0.85,
          wireId,
          testSteps: [
            { description: `Test continuity of ${edge ? edge.label : wireId}`, expectedReading: 'Continuity (< 0.5Ω)' },
            { description: 'Inspect wire for visible damage or disconnected connector', expectedReading: 'Visual OK' },
          ],
        });
      });
    }

    // 4. Dependencies — upstream components that could cause failure
    const deps = DependencyTracker.dependenciesOf(moduleId);
    deps.slice(0, 3).forEach(dep => {
      if (dep.type === 'ground') return; // Already covered above
      findings.push({
        cause:      `Failed upstream component: ${dep.label}`,
        confidence: 0.5,
        moduleId:   dep.moduleId,
        testSteps: [
          { description: `Test voltage output of ${dep.label}`, expectedReading: 'Per spec' },
        ],
      });
    });

    // Sort by confidence descending
    findings.sort((a, b) => b.confidence - a.confidence);

    return findings.length ? findings : [{
      cause:      `No faults detected for ${node.label} — verify test conditions`,
      confidence: 0,
      testSteps:  [],
    }];
  },

  /**
   * Find open circuits at a specific module.
   * Returns wire ids that show CONT: OPN at the current key position.
   *
   * @param {string} moduleId
   * @param {number} keyPos  0-3
   * @returns {string[]}
   */
  openCircuitsAt(moduleId, keyPos = 1) {
    const graph = EKE.graph;
    if (!graph) return [];
    const node = graph.nodes.get(moduleId);
    if (!node) return [];

    return node.edges
      .filter(edge => {
        const w  = edge.wire;
        const rd = w.R && w.R[keyPos];
        return rd && rd.CONT === 'OPN';
      })
      .map(edge => edge.wire.id);
  },

  // ── Internal ──────────────────────────────────────────────────────

  _findOpenWiresOnPath(wireIds, graph) {
    return wireIds.filter(wid => {
      const edge = graph.edges.get(wid);
      if (!edge) return false;
      const w  = edge.wire;
      const rd = w.R && w.R[1]; // key-on
      return rd && rd.CONT === 'OPN';
    });
  },
};

/**
 * @typedef {{
 *   cause:       string,
 *   confidence:  number,
 *   wireId?:     string,
 *   moduleId?:   string,
 *   testSteps:   { description: string, expectedReading: string, actualReading?: string }[]
 * }} Finding
 */
