/**
 * knowledge/behaviors/diode.js
 *
 * Electrical behavior of diodes and rectifier circuits.
 *
 * A diode passes current in one direction only (anode → cathode).
 * Forward voltage drop: ~0.6-0.7V for silicon, ~0.3V for Schottky.
 *
 * Applies to:
 *   - rectifier-diode component (TRX300: between regulator output and battery)
 *   - diode bridge inside regulator-rectifier
 *
 * In DIODE TEST mode, meter applies small test voltage and reads:
 *   Forward biased: 0.400–0.750V (good silicon diode)
 *   Reverse biased: OL (no reading)
 *   Short:          0.000V
 *   Open:           OL in both directions
 *
 * No DOM. No rendering. No UI.
 */

const DiodeBehavior = {

  id: 'diode',

  FORWARD_DROP_SILICON:  0.650,  // V
  FORWARD_DROP_SCHOTTKY: 0.300,  // V

  /**
   * Is this component a diode?
   * @param {GraphNode} node
   * @returns {boolean}
   */
  isDiode(node) {
    return node && node.module &&
      (node.module.id === 'rectifier-diode' || node.module.id.includes('diode'));
  },

  /**
   * Determine if this edge represents forward-biased diode conduction.
   * Returns the forward voltage drop if conducting, null if blocked.
   *
   * @param {GraphEdge} edge
   * @param {GraphNode} fromNode
   * @param {GraphNode} toNode
   * @returns {number|null}  forward drop in V, or null if reverse/not-diode
   */
  forwardDrop(edge, fromNode, toNode) {
    // Check if either endpoint is a diode component
    const isDiodeFrom = DiodeBehavior.isDiode(fromNode);
    const isDiodeTo   = DiodeBehavior.isDiode(toNode);
    if (!isDiodeFrom && !isDiodeTo) return null;

    // TRX300 rectifier diode: anode=A, cathode=K
    // Current flows A→K (from→to when from=A terminal)
    const fromTerm = edge.fromTerm.toUpperCase();
    const toTerm   = edge.toTerm.toUpperCase();

    if (fromTerm === 'A' && toTerm === 'K') return DiodeBehavior.FORWARD_DROP_SILICON;
    if (fromTerm === 'K' && toTerm === 'A') return null; // reverse biased = blocked

    // Default: unknown diode orientation, assume conductive
    return DiodeBehavior.FORWARD_DROP_SILICON;
  },

  /**
   * Format DIODE test reading for the meter display.
   * @param {number|null} forwardDrop
   * @returns {string}
   */
  formatDiodeReading(forwardDrop) {
    if (forwardDrop === null)     return 'OL';   // reverse biased or open
    if (forwardDrop < 0.001)      return '0.000'; // short circuit
    return forwardDrop.toFixed(3);
  },
};
