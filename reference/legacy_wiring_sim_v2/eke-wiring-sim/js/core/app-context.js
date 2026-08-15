/**
 * js/core/app-context.js
 *
 * Single runtime source of truth for the Electrical Knowledge Engine.
 *
 * All subsystems register themselves here after initialization.
 * No subsystem should hold its own reference to the vehicle, graph,
 * or other subsystem — they read from EKE instead.
 *
 * This eliminates scattered globals and makes the application state
 * inspectable from one place.
 *
 * No DOM. No rendering. No electrical logic.
 */

const EKE = {

  // ── Core data ─────────────────────────────────────────────────────

  /** @type {object|null} Vehicle object returned by VehicleLoader.load() */
  vehicle: null,

  /** @type {object|null} CircuitGraph built by GraphBuilder from vehicle data */
  graph: null,

  // ── Subsystem references ──────────────────────────────────────────

  /** @type {object|null} Editor subsystem handle */
  editor: null,

  /** @type {object|null} Simulator subsystem handle */
  simulator: null,

  /** @type {object|null} Diagnostics subsystem handle */
  diagnostics: null,

  /** @type {object|null} UI subsystem handle */
  ui: null,

  // ── Validation results ────────────────────────────────────────────

  /** @type {ValidationResult[]} Results from graph validators, populated after build */
  validationResults: [],

  // ── State ─────────────────────────────────────────────────────────

  /** @type {'idle'|'loading'|'ready'|'error'} */
  status: 'idle',

  /** @type {string|null} Error message if status === 'error' */
  error: null,

  // ── Registration ──────────────────────────────────────────────────

  /**
   * Register a subsystem by name.
   * @param {string} name   - 'editor' | 'simulator' | 'diagnostics' | 'ui'
   * @param {object} handle - subsystem object or controller
   */
  register(name, handle) {
    this[name] = handle;
  },

  /**
   * Set vehicle and graph together — always updated as a pair.
   * @param {object} vehicle
   * @param {object} graph
   */
  setVehicle(vehicle, graph) {
    this.vehicle = vehicle;
    this.graph   = graph;
    this.status  = 'ready';
  },

  /**
   * Record a load or build failure.
   * @param {string|Error} err
   */
  setError(err) {
    this.error  = err instanceof Error ? err.message : String(err);
    this.status = 'error';
  },
};

/**
 * @typedef {{ type: string, message: string, wireId?: string, moduleId?: string }} ValidationResult
 */
