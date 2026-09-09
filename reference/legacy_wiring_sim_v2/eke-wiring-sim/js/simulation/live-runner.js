/**
 * js/simulation/live-runner.js
 *
 * AP-LIVE-SIM-001 — wires the electrical solver (GraphBuilder +
 * VoltagePropagator + GroundPropagator + ElectricalSolver — all real,
 * already-built, but until now only ever registered into
 * `EKE.diagnostics` and never actually called by anything the user sees)
 * into the live diagram: rebuilds the circuit graph from the CURRENT
 * MODULES/WIRES on every key-position or switch-state change, solves
 * it, and updates each lamp module's own glow visual from its real
 * per-module powered+grounded result.
 *
 * This REPLACES `updateBulbs()`'s old behavior (ui/meter-panel.js:
 * every `.bgl` element glows the same generic yellow whenever
 * `keyPos >= 1`, with zero regard for switches, wiring, or bulb color)
 * — that function still exists (still called from setKey()) but now
 * only handles the meter-mode-unrelated legacy fallback; LiveSim.refresh()
 * is the real per-bulb authority, called right after it.
 *
 * No DOM assumptions beyond `.bgl[data-mid]` (the glow element every
 * lamp card already tags itself with — buildBulbCard, renderer.js).
 */
const LiveSim = (function () {

  // moduleId -> 'open' | 'closed'. Mirrors EKE.conditions.switchStates,
  // which is what SwitchBehavior.sensorSwitchClosed's generic fallback
  // (knowledge/behaviors/switch.js) actually reads for any switch that
  // isn't one of the three specifically-named engine-state switches —
  // i.e. every switch a user places on their own diagram, since a
  // user-assigned module id is never literally 'neutral-switch' etc.
  const switchStates = {};

  // AP-MULTI-SWITCH-001 — moduleId -> { groupName: 'position' }, for a
  // real multi-position switch (knowledge/behaviors/multi-switch.js —
  // Ignition/Lighting/Dimmer/Engine Stop/Starter). Mirrors
  // EKE.conditions.multiSwitchStates, which is what
  // MultiSwitchBehavior.currentState actually reads.
  const multiSwitchStates = {};

  const BULB_COLORS = {
    red: '#ef4444', green: '#22c55e', amber: '#f59e0b',
    blue: '#3b82f6', white: '#f8fafc', yellow: '#eab308',
  };

  function isClosed(moduleId) {
    return switchStates[moduleId] === 'closed';
  }

  function setSwitch(moduleId, closed) {
    switchStates[moduleId] = closed ? 'closed' : 'open';
    refresh();
  }

  function toggleSwitch(moduleId) {
    setSwitch(moduleId, !isClosed(moduleId));
  }

  // AP-MULTI-SWITCH-001 — set one GROUP's position on a real
  // multi-position switch module (e.g. moduleId's own `dimmer` group to
  // 'lo') — a single module can have several independent groups (the
  // user's own bundled Left Handlebar Switch has 4: lights/dimmer/
  // engineStop/starter), so this is keyed by group, not the whole module.
  function setMultiSwitchGroup(moduleId, group, value) {
    if (!multiSwitchStates[moduleId]) multiSwitchStates[moduleId] = {};
    multiSwitchStates[moduleId][group] = value;
    refresh();
  }

  function multiSwitchGroupValue(moduleId, def, group) {
    const saved = multiSwitchStates[moduleId];
    if (saved && saved[group] != null) return saved[group];
    return def.groups[group][0];
  }

  // A module counts as a switch for the CONTROL PANEL the same way
  // SwitchBehavior.isSwitch (knowledge/behaviors/switch.js) does for the
  // solver itself — kept in sync deliberately, so "what shows up as a
  // toggle" and "what the solver actually gates on" never disagree.
  function isSwitchModule(m) {
    return !!(m && (m.cat === 'switch' || m.groundedSwitch === true || m.thermistor === true));
  }

  function _conditions() {
    if (typeof EKE !== 'undefined' && EKE.conditions) {
      EKE.conditions.keyPosition = (typeof keyPos !== 'undefined') ? keyPos : 0;
      EKE.conditions.switchStates = switchStates;
      EKE.conditions.multiSwitchStates = multiSwitchStates;
      return EKE.conditions;
    }
    return { keyPosition: (typeof keyPos !== 'undefined') ? keyPos : 0, switchStates, multiSwitchStates, faults: new Map(), engineState: {} };
  }

  function _applyLampVisual(m, lit) {
    const glow = document.querySelector(`.bgl[data-mid="${CSS.escape(m.id)}"]`);
    if (!glow) return;
    // AP-BULB-VISUAL-002 — same incandescent-vs-color determination as
    // buildBulbCard's own initial render (renderer.js: `!m.bulbColor`
    // also counts as incandescent, not just an explicit `bulbStyle`) —
    // these two used to disagree (this branch only checked `bulbStyle`),
    // so a bulb with neither field set (every pre-existing Headlight,
    // predating `bulbStyle`/`bulbColor` entirely) rendered white-glass
    // on first load but flipped to a colored-lens gray the instant the
    // simulation's own OFF state was applied on top of it.
    const isIncandescent = m.bulbStyle === 'incandescent' || !m.bulbColor;
    if (!lit) {
      glow.setAttribute('fill', isIncandescent ? '#fffde7' : '#52525b');
      glow.style.filter = '';
      return;
    }
    if (isIncandescent) {
      // AP-BULB-VISUAL-001 — incandescent white-to-amber glow, per direct
      // request ("visual representation of an incandescent bulb that
      // goes from white to yellow for the headlights").
      glow.setAttribute('fill', '#fef9c3');
      glow.style.filter = 'drop-shadow(0 0 4px #fbbf24)';
    } else {
      const hex = BULB_COLORS[m.bulbColor] || BULB_COLORS.red;
      glow.setAttribute('fill', hex);
      glow.style.filter = `drop-shadow(0 0 4px ${hex})`;
    }
  }

  // AP-LIVE-SIM-001 — `drawWires()` (renderer.js) already runs after
  // EVERY diagram mutation that could change circuit topology (module/
  // wire add, delete, edit) as an existing, universal checkpoint — but it
  // ALSO runs on every drag mousemove frame and every pan/zoom, where
  // topology hasn't changed at all. Debouncing the actual rebuild+solve
  // (cheap for this app's diagram sizes, but no reason to redo it dozens
  // of times a second while dragging) means every call site that already
  // remembers to call drawWires() gets a correct refresh for free,
  // without hunting down and separately instrumenting every individual
  // module/wire create/delete/edit function.
  let _pending = null;
  function scheduleRefresh() {
    if (_pending) clearTimeout(_pending);
    _pending = setTimeout(() => { _pending = null; refresh(); }, 120);
  }

  function refresh() {
    if (typeof MODULES === 'undefined' || typeof GraphBuilder === 'undefined') return;
    const conditions = _conditions();
    const graph = GraphBuilder.rebuild(MODULES, WIRES);
    const state = ElectricalSolver.solve(graph, conditions);
    MODULES.forEach(m => {
      if (!(typeof LampBehavior !== 'undefined' && LampBehavior.isLamp({ module: m }))) return;
      const status = ElectricalSolver.moduleStatus(m.id, state);
      _applyLampVisual(m, status.functional);
    });
    if (typeof renderSimPanel === 'function') renderSimPanel();
  }

  return {
    setSwitch, toggleSwitch, isClosed, isSwitchModule, refresh, scheduleRefresh, BULB_COLORS,
    setMultiSwitchGroup, multiSwitchGroupValue,
  };
})();
