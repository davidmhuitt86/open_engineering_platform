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

  // AP-DMM-BRIDGE-001 — a pure QUERY wrapper around the existing solver,
  // added specifically for the Dart-side DMM bridge
  // (legacy_v2_bridge_script.dart's __oepBridgeQueryLiveMeasurement, via
  // LegacyV2Channel.queryLiveMeasurement). This is NOT a second solver —
  // it rebuilds the graph via the same GraphBuilder.rebuild every other
  // entry point uses and reads the answer via the EXISTING
  // ElectricalSolver.readWire()/_wireResistance(), translating the
  // already-computed WireReading (VDC/VAC/CONT/RES/DIODE/note) into a
  // structured, explicit-semantics object instead of a display string.
  //
  // Terminal identity is NOT invented here: `wire.from.m`/`wire.from.t`
  // and `wire.to.m`/`wire.to.t` are the SAME module-id + pin-ref pair
  // every other part of this app (GraphBuilder, the renderer, the OEP
  // bridge's own sourcePort/targetPort convention) already uses as a
  // wire's endpoint identity.
  //
  // Raw resistance is read directly via
  // ContinuitySolver._wireResistance(edge, conditions) rather than
  // re-parsing WireReading.RES's DISPLAY string ('12.3Ω'/'1.2kΩ'/'<1Ω'/
  // 'OL') — that string is formatted for a human LCD, not safe to
  // parseFloat back into a number (a 'kΩ' value would silently come back
  // 1000x too small, '<1Ω' wouldn't parse at all).
  function readWireMeasurement(wireId, mode) {
    const blank = (readingType, note) => ({
      status: 'error', readingType: readingType || 'voltage', value: null, unit: '',
      open: true, overload: false, fault: false, note: note || '',
      source: null, reference: null, solvedAt: null,
    });
    if (typeof MODULES === 'undefined' || typeof WIRES === 'undefined' ||
        typeof GraphBuilder === 'undefined' || typeof ElectricalSolver === 'undefined') {
      return blank(mode, 'Live solver not available');
    }
    const wire = WIRES.find(w => w.id === wireId);
    if (!wire) return blank(mode, 'Wire not found: ' + wireId);

    const MODE_MAP = { VDC: 'voltage', VAC: 'voltageAc', CONT: 'continuity', RES: 'resistance', DIODE: 'diode' };
    const readingType = MODE_MAP[mode] || null;
    if (!readingType) return blank(mode, 'Unsupported reading type: ' + mode);

    const conditions = _conditions();
    const graph = GraphBuilder.rebuild(MODULES, WIRES);
    const edge = graph.edges.get(wireId);
    const reading = ElectricalSolver.readWire(wireId, graph, conditions);
    const source = { moduleId: wire.from.m, terminalId: wire.from.t != null ? String(wire.from.t) : null };
    const reference = { moduleId: wire.to.m, terminalId: wire.to.t != null ? String(wire.to.t) : null };
    const base = { status: 'ok', readingType, overload: false, fault: false, note: reading.note || '', source, reference, solvedAt: Date.now() };

    if (readingType === 'voltage' || readingType === 'voltageAc') {
      const raw = readingType === 'voltage' ? reading.VDC : reading.VAC;
      const open = reading.CONT === 'OPN';
      const value = parseFloat(raw);
      return { ...base, unit: 'V', open, value: (open || isNaN(value)) ? null : value };
    }
    if (readingType === 'continuity') {
      const conductive = reading.CONT === '000';
      const open = reading.CONT === 'OPN';
      return { ...base, unit: '', open, value: conductive ? 0 : null };
    }
    if (readingType === 'resistance') {
      if (!edge || typeof ContinuitySolver === 'undefined') return blank(mode, 'Resistance model unavailable for this wire');
      const ohms = ContinuitySolver._wireResistance(edge, conditions);
      const open = ohms === Infinity || ohms > 1e6;
      return { ...base, unit: 'Ω', open, value: open ? null : ohms };
    }
    if (readingType === 'diode') {
      const open = reading.DIODE === 'OL';
      const value = parseFloat(reading.DIODE);
      return { ...base, unit: 'V', open, value: (open || isNaN(value)) ? null : value };
    }
    return blank(mode, 'Unsupported reading type: ' + mode);
  }

  return {
    setSwitch, toggleSwitch, isClosed, isSwitchModule, refresh, scheduleRefresh, BULB_COLORS,
    setMultiSwitchGroup, multiSwitchGroupValue, readWireMeasurement,
  };
})();
