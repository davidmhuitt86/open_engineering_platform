/**
 * js/diagnostics/fault-injector.js
 *
 * Injects electrical faults into the simulation conditions.
 *
 * Workflow:
 *   FaultInjector.inject(wireId, 'open')
 *       ↓
 *   Fault added to EKE.conditions.faults map
 *       ↓
 *   ElectricalSolver.solve() called with updated conditions
 *       ↓
 *   Voltages recalculated — affected nodes lose power
 *       ↓
 *   Renderer updates wire highlighting
 *       ↓
 *   Meter display shows fault effect
 *
 * This is the foundation for training scenarios where students must
 * identify faults by taking measurements.
 *
 * No DOM. No rendering. No UI.
 */

const FaultInjector = {

  /**
   * Inject a fault on a wire.
   *
   * @param {string} wireId
   * @param {string} faultType   - key from FailureModes (e.g. 'open', 'short-to-gnd')
   * @param {object} [params]    - fault-specific parameters
   * @returns {object}  the created fault object
   */
  inject(wireId, faultType, params = {}) {
    const mode = FailureModes.getById(faultType);
    if (!mode) throw new Error(`FaultInjector: unknown fault type "${faultType}"`);

    const fault = {
      id:       `fault-${faultType}-${wireId}-${Date.now()}`,
      type:     faultType,
      wireId,
      label:    mode.label,
      params:   Object.assign({}, mode.defaultParams || {}, params),
      injectedAt: Date.now(),
    };

    // Store in EKE conditions
    FaultInjector._ensureConditions();
    EKE.conditions.faults.set(wireId, fault);

    console.log(`[FaultInjector] Injected: ${mode.label} on wire "${wireId}"`);
    return fault;
  },

  /**
   * Clear a fault on a specific wire.
   * @param {string} wireId
   */
  clear(wireId) {
    FaultInjector._ensureConditions();
    EKE.conditions.faults.delete(wireId);
  },

  /**
   * Clear all active faults.
   */
  clearAll() {
    FaultInjector._ensureConditions();
    EKE.conditions.faults.clear();
    console.log('[FaultInjector] All faults cleared');
  },

  /**
   * List all active faults.
   * @returns {object[]}
   */
  activeFaults() {
    FaultInjector._ensureConditions();
    return [...EKE.conditions.faults.values()];
  },

  /**
   * Check whether a wire has an active fault.
   * @param {string} wireId
   * @returns {object|null}
   */
  getFault(wireId) {
    FaultInjector._ensureConditions();
    return EKE.conditions.faults.get(wireId) || null;
  },

  // ── Internal ──────────────────────────────────────────────────────

  _ensureConditions() {
    if (!EKE.conditions) {
      EKE.conditions = {
        keyPosition:  typeof keyPos !== 'undefined' ? keyPos : 0,
        switchStates: {},
        faults:       new Map(),
        engineState:  {},
      };
    }
    if (!EKE.conditions.faults) {
      EKE.conditions.faults = new Map();
    }
  },
};
