/**
 * utils/events.js
 *
 * Minimal event emitter for inter-module communication.
 *
 * Used by Phase 2+ modules that need to publish state changes without
 * coupling directly to their consumers.
 *
 * Example:
 *   const bus = new EventBus();
 *   bus.on('selectionChange', ({ wire }) => inspector.showWire(wire));
 *   bus.emit('selectionChange', { wire: selW });
 *
 * No DOM. No electrical logic.
 */

class EventBus {
  constructor() {
    /** @type {Map<string, Function[]>} */
    this._listeners = new Map();
  }

  /**
   * Subscribe to an event.
   * @param {string}   event
   * @param {Function} fn
   * @returns {Function} unsubscribe function
   */
  on(event, fn) {
    if (!this._listeners.has(event)) this._listeners.set(event, []);
    this._listeners.get(event).push(fn);
    return () => this.off(event, fn);
  }

  /**
   * Unsubscribe from an event.
   * @param {string}   event
   * @param {Function} fn
   */
  off(event, fn) {
    const list = this._listeners.get(event);
    if (list) this._listeners.set(event, list.filter(f => f !== fn));
  }

  /**
   * Emit an event with optional data.
   * @param {string} event
   * @param {*}      [data]
   */
  emit(event, data) {
    (this._listeners.get(event) || []).forEach(fn => fn(data));
  }

  /** Remove all listeners for all events. */
  clear() {
    this._listeners.clear();
  }
}

/**
 * Global application event bus (Phase 2).
 * Systems communicate via this bus rather than direct function calls.
 *
 * Standard events:
 *   'wireSelected'      { wire }
 *   'moduleSelected'    { moduleId }
 *   'selectionCleared'  {}
 *   'keyPositionChanged'{ keyPos }
 *   'meterModeChanged'  { mode }
 *   'diagramChanged'    {}          - any edit that requires redraw
 *   'layoutChanged'     {}          - position/route edit (triggers autosave)
 *   'faultInjected'     { fault }
 *   'faultCleared'      { faultId }
 */
const AppBus = new EventBus();
