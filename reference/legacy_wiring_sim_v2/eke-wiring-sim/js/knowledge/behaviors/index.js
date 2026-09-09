/**
 * knowledge/behaviors/index.js
 *
 * Component Behavior Registry.
 *
 * The ElectricalSolver calls into this registry to determine how
 * each component/edge behaves electrically.
 *
 * The registry consults individual behavior modules (battery.js,
 * switch.js, relay.js, etc.) and returns a unified answer.
 *
 * Methods called by ElectricalSolver and propagators:
 *   getEdgeBehavior(edge, fromNode, toNode, conditions) → 'open' | 'ground' | number | 'pass'
 *   wireResistance(edge, conditions)                    → Ω
 *   diodeForward(edge, fromNode, toNode, conditions)    → V | null
 *   acVoltage(edge, conditions)                         → V
 *
 * No DOM. No rendering. No UI.
 */

const ComponentBehaviors = {

  /**
   * Determine how an edge behaves when voltage arrives from a node.
   *
   * Returns:
   *   'open'   — edge blocks voltage (switch open, blown fuse, relay open)
   *   'ground' — edge connects to ground (ground path)
   *   number   — edge passes this specific voltage (relay contact drop, etc.)
   *   'pass'   — edge passes source voltage unchanged
   *
   * @param {GraphEdge}            edge
   * @param {GraphNode}            fromNode
   * @param {GraphNode}            toNode
   * @param {SimulationConditions} conditions
   * @returns {'open'|'ground'|number|'pass'}
   */
  getEdgeBehavior(edge, fromNode, toNode, conditions) {
    const kp = conditions.keyPosition || 0;

    // ── Ground node → anything = ground path ─────────────────────
    if (fromNode && fromNode.type === 'ground') return 'ground';
    if (toNode   && toNode.type   === 'ground') return 'ground';

    // ── Ignition switch (legacy, name-based pairs) ────────────────
    // AP-MULTI-SWITCH-001 — `ignitionSwitchResistance` compares
    // `edge.fromTerm`/`edge.toTerm` against hardcoded NAME strings
    // ('BAT1-IG1', etc.) — but a real wire's terminal ref is almost
    // always a bare PIN NUMBER ("4"), not the terminal's name, so this
    // comparison silently never matched on any diagram built through
    // the normal module/wire editor (only if someone hand-authored a
    // wire with a literal name in that field, as the bundled demo's own
    // seed data happens to). Skipped entirely for a module
    // MultiSwitchBehavior recognizes (by terminal-name SET, robust
    // against any module id) — for those, gating is handled correctly,
    // per-pin-pair, by the propagators' own BFS filter instead
    // (js/simulation/voltage-propagator.js's `isMultiSwitch` check) —
    // this edge-level check would otherwise run first and wrongly
    // return 'open' for every edge touching the switch's EXTERNAL wires,
    // since `[fromTerm,toTerm].sort().join('-')` never equals any of the
    // hardcoded name pairs when both sides are just pin numbers.
    const fromIsMultiSwitch = typeof MultiSwitchBehavior !== 'undefined' && MultiSwitchBehavior.isMultiSwitch(fromNode);
    const toIsMultiSwitch = typeof MultiSwitchBehavior !== 'undefined' && MultiSwitchBehavior.isMultiSwitch(toNode);
    if (!fromIsMultiSwitch && !toIsMultiSwitch) {
      if (fromNode && SwitchBehavior.isIgnitionSwitch(fromNode)) {
        const r = SwitchBehavior.ignitionSwitchResistance(edge.fromTerm, edge.toTerm, kp);
        return r === Infinity ? 'open' : 'pass';
      }
      if (toNode && SwitchBehavior.isIgnitionSwitch(toNode)) {
        const r = SwitchBehavior.ignitionSwitchResistance(edge.fromTerm, edge.toTerm, kp);
        return r === Infinity ? 'open' : 'pass';
      }
    }

    // ── Generic switch (sensor switches: neutral, oil, reverse) ───
    if (fromNode && SwitchBehavior.isSwitch(fromNode)) {
      return SwitchBehavior.sensorSwitchClosed(fromNode, conditions) ? 'pass' : 'open';
    }
    if (toNode && SwitchBehavior.isSwitch(toNode)) {
      return SwitchBehavior.sensorSwitchClosed(toNode, conditions) ? 'pass' : 'open';
    }

    // ── Diode ─────────────────────────────────────────────────────
    const diodeDrop = DiodeBehavior.forwardDrop(edge, fromNode, toNode);
    if (diodeDrop !== null) return 'pass'; // conduction with drop — handled in solver

    // ── Relay contacts ────────────────────────────────────────────
    // (Simplified: full relay simulation requires coil state from prior solve pass)
    // Handled by SWPACK override for the TRX300 start circuit

    // ── SWPACK overrides (TRX300 handlebar switches) ──────────────
    if (window.SWPACK && SWPACK.getReading) {
      const ov = SWPACK.getReading(edge.wire.id, kp);
      if (ov !== null) {
        // AP-SWPACK-GROUND-001 — the kill switch's own override
        // (js/swpack.js: 'kill-cdi', kill==='stop') encodes "shorted to
        // ground" as CONT:'000' (continuity present — it's shorted, not
        // broken) with VDC:'0.00', which this check never recognized:
        // only the OPEN-circuit encoding (CONT:'OPN') blocked propagation,
        // so a kill-switch-gated wire always fell through to 'pass' here
        // regardless of kill state — harmless for the meter display
        // (updateMeter(), ui/meter-panel.js, reads SWPACK.getReading()
        // directly, a completely separate path this doesn't touch) but
        // wrong for the graph solver (VoltagePropagator/GroundPropagator),
        // meaning a bulb wired through a kill-style "short to ground"
        // switch would never actually go dark when that switch tripped.
        if (parseFloat(ov.VDC) === 0 && ov.CONT === '000') return 'ground';
        // SWPACK override exists — pass voltage if CONT !== 'OPN'
        if (ov.CONT === 'OPN' && parseFloat(ov.VDC) === 0) return 'open';
        return 'pass';
      }
    }

    // ── Default: conductors pass voltage ──────────────────────────
    return 'pass';
  },

  /**
   * Wire/component resistance for continuity calculations.
   *
   * @param {GraphEdge}            edge
   * @param {SimulationConditions} conditions
   * @returns {number}  Ω or Infinity
   */
  wireResistance(edge, conditions) {
    const fromNode = EKE.graph ? EKE.graph.nodes.get(edge.fromNode) : null;
    const toNode   = EKE.graph ? EKE.graph.nodes.get(edge.toNode)   : null;
    const kp       = conditions.keyPosition || 0;

    // Switch resistance
    if (fromNode && SwitchBehavior.isIgnitionSwitch(fromNode)) {
      return SwitchBehavior.ignitionSwitchResistance(edge.fromTerm, edge.toTerm, kp);
    }
    if (fromNode && SwitchBehavior.isSwitch(fromNode)) {
      return SwitchBehavior.sensorResistance(fromNode, conditions);
    }
    if (toNode && SwitchBehavior.isSwitch(toNode)) {
      return SwitchBehavior.sensorResistance(toNode, conditions);
    }

    // Lamp resistance
    if (fromNode && LampBehavior.isLamp(fromNode)) return LampBehavior.resistance(0);
    if (toNode   && LampBehavior.isLamp(toNode))   return LampBehavior.resistance(0);

    // Motor resistance
    if (fromNode && MotorBehavior.isMotor(fromNode)) return MotorBehavior.resistance(kp);
    if (toNode   && MotorBehavior.isMotor(toNode))   return MotorBehavior.resistance(kp);

    // Diode resistance
    const diodeDrop = fromNode && toNode ? DiodeBehavior.forwardDrop(edge, fromNode, toNode) : null;
    if (diodeDrop !== null)  return 10;   // conducting — ~10Ω approximation
    if (diodeDrop === null && (fromNode && DiodeBehavior.isDiode(fromNode))) return Infinity; // reverse

    // All other conductors: near-zero resistance
    return 0.1;
  },

  /**
   * Diode forward voltage drop for DIODE TEST mode.
   * Returns null if edge is not a diode.
   *
   * @param {GraphEdge} edge
   * @param {GraphNode} fromNode
   * @param {GraphNode} toNode
   * @param {SimulationConditions} conditions
   * @returns {number|null}
   */
  diodeForward(edge, fromNode, toNode, conditions) {
    return DiodeBehavior.forwardDrop(edge, fromNode, toNode);
  },

  /**
   * AC voltage generated on a wire (stator/alternator wires only).
   * Returns 0 for all non-AC wires.
   *
   * @param {GraphEdge}            edge
   * @param {SimulationConditions} conditions
   * @returns {number}  VAC
   */
  acVoltage(edge, conditions) {
    const kp = conditions.keyPosition || 0;
    const id = edge.wire.id || '';

    // Stator AC wires
    if (id.startsWith('stator-ac')) {
      if (kp === 2) return 8;   // cranking — low AC
      if (kp === 3) return 22;  // running — full AC
      return 0;
    }
    return 0;
  },
};
