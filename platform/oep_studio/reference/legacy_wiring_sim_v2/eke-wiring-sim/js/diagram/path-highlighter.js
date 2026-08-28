/**
 * js/diagram/path-highlighter.js
 *
 * Controls which wires are highlighted on the diagram.
 *
 * Capabilities:
 *   Show Battery → [Target]   (power path)
 *   Show [Target] → Ground    (ground path)
 *   Show charging path        (alternator → regulator → battery)
 *   Show full circuit         (circuit tracer)
 *   Clear all highlights
 *
 * Uses PathFinder for traversal. Sets tracedWires global which
 * renderer.js reads to apply the highlight color.
 *
 * This is the only diagram file that knows about PathFinder and
 * CircuitTracer — all other diagram files only render.
 */

const PathHighlighter = {

  /**
   * Highlight the power path from any source to a target module.
   * @param {string} targetModuleId
   */
  showPowerPath(targetModuleId) {
    const result = PowerPath.find(targetModuleId);
    if (!result.found) { showToast(`No power path to this module`, 'warn'); return; }
    tracedWires = new Set(result.wireIds);
    drawWires();
    showToast(`Power path: ${result.wireIds.length} wire(s)`);
  },

  /**
   * Highlight the ground path from a module to chassis ground.
   * @param {string} sourceModuleId
   */
  showGroundPath(sourceModuleId) {
    const result = GroundPath.find(sourceModuleId);
    if (!result.found) { showToast(`No ground path from this module`, 'warn'); return; }
    tracedWires = new Set(result.wireIds);
    drawWires();
    showToast(`Ground path: ${result.wireIds.length} wire(s)`);
  },

  /**
   * Highlight the full circuit containing a wire.
   * @param {string} wireId
   */
  showCircuit(wireId) {
    tracedWires = CircuitTracer.traceFromWire(wireId);
    drawWires();
    showToast(`Circuit: ${tracedWires.size} wire(s)`);
  },

  /**
   * Highlight the charging path:
   * Alternator stator → Regulator/Rectifier → Battery.
   */
  showChargingPath() {
    const graph = EKE.graph;
    if (!graph) return;

    const statorId  = 'alternator-stator';
    const batteryId = 'battery-fuses';

    const paths = PathFinder.findAllPaths(statorId, batteryId);
    if (!paths.length) { showToast('Charging path not found', 'warn'); return; }

    tracedWires = new Set(paths.flat());
    drawWires();
    showToast(`Charging path: ${tracedWires.size} wire(s)`);
  },

  /**
   * Clear all path highlights.
   */
  clear() {
    tracedWires = new Set();
    drawWires();
  },
};
