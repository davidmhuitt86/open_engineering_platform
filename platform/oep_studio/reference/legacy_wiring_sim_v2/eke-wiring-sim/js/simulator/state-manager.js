/**
 * simulator/state-manager.js
 *
 * Tracks the operating state of the vehicle electrical system.
 *
 * Key positions:
 *   0 = Key Off   (engine off, no switched power)
 *   1 = Key On    (switched power on, engine not running)
 *   2 = Cranking  (starter engaged)
 *   3 = Running   (engine running, charging system active)
 *
 * Phase 1: state lives as bare variables in app.js (keyPos, meterMode).
 *          setKey() and setMode() are global functions in app.js.
 *
 * Phase 2 goal: StateManager class below becomes the authority.
 *
 * The simulator reads keyPos to select the correct meter reading index.
 * The renderer reads keyPos to determine wire flow direction and bulb state.
 *
 * Future (Phase 3+):
 *   - Custom named states (e.g. "Idle", "High RPM", "Under Load")
 *   - Sensor value overrides per state
 *   - Fault injection per state
 *
 * No DOM. No rendering.
 */

class SimulatorStateManager {
  constructor() {
    /** 0=off, 1=on, 2=cranking, 3=running */
    this.keyPosition = 0;

    /** 'VDC' | 'VAC' | 'CONT' | 'RES' | 'DIODE' */
    this.meterMode = 'VDC';

    /** Active faults: Map<faultId, EKEFault> */
    this.faults = new Map();

    /** Registered change listeners */
    this._listeners = [];
  }

  setKeyPosition(pos) {
    this.keyPosition = Math.max(0, Math.min(3, pos));
    this._notify('keyPosition', this.keyPosition);
  }

  setMeterMode(mode) {
    this.meterMode = mode;
    this._notify('meterMode', mode);
  }

  injectFault(fault) {
    this.faults.set(fault.id, fault);
    this._notify('fault', fault);
  }

  clearFault(faultId) {
    this.faults.delete(faultId);
    this._notify('faultCleared', faultId);
  }

  clearAllFaults() {
    this.faults.clear();
    this._notify('allFaultsCleared', null);
  }

  onChange(fn) {
    this._listeners.push(fn);
    return () => { this._listeners = this._listeners.filter(f => f !== fn); };
  }

  _notify(type, value) {
    this._listeners.forEach(fn => fn({ type, value }));
  }

  /** Key position label for display. */
  get keyLabel() {
    return ['Key Off', 'Key On', 'Cranking', 'Running'][this.keyPosition];
  }
}
