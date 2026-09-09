/**
 * js/simulation/ground-propagator.js
 *
 * Determines which nodes have a valid ground path.
 *
 * A node has a valid ground if there exists a continuous conductive
 * path from that node to a chassis-ground node, with no open circuits
 * or active faults blocking the path.
 *
 * Used by ElectricalSolver to complete the circuit check:
 * a component needs BOTH power and ground to function.
 *
 * No DOM. No rendering. No UI.
 */

// AP-CONNECTOR-BRIDGE-001 — shared byte-for-byte with
// voltage-propagator.js's own copy (no module system in this codebase
// to import a single definition from). Strips a connector pin ref's
// `_IN`/`_OUT` suffix down to its bare pin number.
function _pinNumberOf(termRef) {
  if (termRef == null) return null;
  return String(termRef).replace(/_(IN|OUT)$/, '');
}

// AP-DEADEND-GENERALIZE-001 — shared byte-for-byte with
// voltage-propagator.js's own copy of this comment: any plain module
// node with no RECOGNIZED reason to conduct (a switch, a diode, a
// splice, a connector/multi-switch's own explicit per-pin gating) gets
// the SAME same-pin-only treatment as a connector (below), instead of
// freely tunneling "has ground" between any two of its pins. Not a
// FULL dead end (unlike a lamp or the starter motor) — a component like
// a Starter Solenoid legitimately reuses one physical pin (its BAT lug)
// for several wires, which must still bridge freely. This replaced an
// earlier, narrower attempt that only caught a 2-terminal load with a
// literally GND-named pin — too narrow once a 5-pin Alarm Unit (ground
// pin arbitrarily named "A3", not GND) turned out to leak the same way.
//
// AP-BATTERY-TUNNEL-001 — the power source itself (`cat==='power'`,
// almost always the Battery) was ALSO excluded here at first, on the
// reasoning that it's "just the seed" — wrong: a battery's + and −
// posts are two electrically SEPARATE pins, and its − post is
// routinely wired straight to a real Ground Point (correctly — that's
// how a battery grounds a vehicle's chassis). Excluding it meant this
// BFS, reaching that − pin exactly as intended, tunneled straight
// through the battery's own body and out its + post — flooding the
// ENTIRE downstream power distribution network with a false "grounded"
// status. This one node explained nearly every "always lit regardless
// of switch state" symptom traced this session; the coil/alarm-unit
// fixes were real but secondary — this was the dominant leak.
function _isUnmodeledComponent(node) {
  if (!node || node.type !== 'module' || !node.module) return false;
  const m = node.module;
  if (m.cat === 'splice') return false;
  if (typeof SwitchBehavior !== 'undefined' && SwitchBehavior.isSwitch(node)) return false;
  if (typeof MultiSwitchBehavior !== 'undefined' && MultiSwitchBehavior.isMultiSwitch(node)) return false;
  if (typeof DiodeBehavior !== 'undefined' && DiodeBehavior.isDiode(node)) return false;
  return true;
}

const GroundPropagator = {

  /**
   * Calculate which nodes have a valid ground path under
   * the given simulation conditions.
   *
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {Map<string, boolean>}  nodeId → hasGround
   */
  propagate(graph, conditions) {
    /** @type {Map<string, boolean>} */
    const hasGround = new Map();

    // Seed: ground nodes always have ground
    GraphTraversal.groundNodes(graph).forEach(id => hasGround.set(id, true));

    // AP-BODY-GROUND-AUTO-001 — per direct correction: "the starter motor
    // is grounded by its body to the chassis" — its case bolts straight
    // to the engine/frame, the same real-world convention that made
    // Alternator/Pulse Generator's own body-ground purely decorative
    // (§ AP-BODY-GROUND-SYMBOL-001, renderer.js) rather than a second
    // wireable terminal. A starter motor never NEEDS a drawn wire to a
    // Ground Point module for this to be true — so it's seeded as
    // grounded here unconditionally, exactly like a real ground node.
    //
    // Deliberately NOT extended to `groundedSwitch`/`thermistor`: those
    // modules' whole electrical job is GATING a ground path (open vs
    // closed decides whether whatever's wired to their OTHER terminal is
    // grounded) — auto-grounding them regardless of switch state would
    // make the gate meaningless. Their GND post still needs a real wire
    // to an actual Ground Point module for the switch to do anything.
    graph.nodes.forEach((node, id) => {
      if (node.module && node.module.starterMotor === true) hasGround.set(id, true);
    });

    // BFS outward from all ground (+ auto-grounded) nodes. Queue items
    // carry `viaTerm` — the terminal ref THIS node was entered through —
    // so a connector node (§ AP-CONNECTOR-BRIDGE-001 below) knows which
    // of its own edges may continue propagation.
    const queue   = [...hasGround.keys()].map(id => ({ id, viaTerm: null }));
    const visited = new Set(hasGround.keys());

    // AP-MULTI-ENTRY-001 — same fix as VoltagePropagator's own copy of
    // this comment (js/simulation/voltage-propagator.js): nodeId → Set of
    // entry-pin keys already tried, for a connector/multi-switch node
    // specifically (see below).
    const enteredPins = new Map();

    while (queue.length) {
      const { id: nodeId, viaTerm } = queue.shift();
      const node   = graph.nodes.get(nodeId);
      if (!node) continue;
      // AP-BODY-GROUND-AUTO-001 — a starter motor is ALSO a dead end for
      // continuing propagation, same reason as the lamp-tunnel fix right
      // below: its body-ground ("hasGround" seeded above) must not leak
      // onward through the motor and out its B+ power lead, which would
      // wrongly mark whatever feeds that lead (a starter solenoid, say)
      // as grounded too.
      if (node.module && node.module.starterMotor === true) continue;
      // AP-LAMP-TUNNEL-001 — same fix as VoltagePropagator's own copy of
      // this comment (js/simulation/voltage-propagator.js): a lamp is a
      // dead end for CONTINUING propagation once reached, since this
      // graph has one node per module (not per terminal) and a lamp's
      // power pin and ground pin are otherwise indistinguishable edges
      // on the same node — without this, ground reaching a lamp's own
      // ground pin "tunnels" through it and out its power wire into the
      // battery, then floods "has ground" onto everything ELSE the
      // battery feeds, with no real electrical connection between them.
      // (Ground nodes themselves are NOT dead-ended here, unlike in
      // VoltagePropagator — they're this BFS's actual seeds; skipping
      // their own edges would mean nothing ever gets marked grounded.)
      if (typeof LampBehavior !== 'undefined' && LampBehavior.isLamp(node)) continue;
      // AP-CONNECTOR-BRIDGE-001 — same fix as VoltagePropagator's own
      // copy of this comment (js/simulation/voltage-propagator.js): a
      // connector's pins are mechanically bundled but NOT electrically
      // joined to each other, unlike a splice — without this, "has
      // ground" reaching one pin tunneled straight out every OTHER pin
      // on the same connector to whatever unrelated circuit happened to
      // be wired there.
      //
      // AP-DEADEND-GENERALIZE-001 — an unmodeled component (see above)
      // gets this EXACT same same-pin-only treatment, not just a real
      // `connector: true` module.
      const isConnectorLike = node.type === 'connector' || _isUnmodeledComponent(node);
      const viaPin = isConnectorLike && viaTerm != null ? _pinNumberOf(viaTerm) : null;
      // AP-MULTI-SWITCH-001 — same mechanism as VoltagePropagator's own
      // copy of this comment (js/simulation/voltage-propagator.js): a
      // real multi-position switch (knowledge/behaviors/multi-switch.js)
      // only lets ground continue through its OWN internally-bridged
      // terminal pairs for its CURRENT selected position.
      const isMultiSwitch = typeof MultiSwitchBehavior !== 'undefined' && MultiSwitchBehavior.isMultiSwitch(node);

      node.edges.forEach(edge => {
        if (isConnectorLike && viaPin != null) {
          const thisTerm = edge.fromNode === nodeId ? edge.fromTerm : edge.toTerm;
          if (_pinNumberOf(thisTerm) !== viaPin) return;
        }
        if (isMultiSwitch && viaTerm != null) {
          const thisTerm = edge.fromNode === nodeId ? edge.fromTerm : edge.toTerm;
          if (!MultiSwitchBehavior.pairClosed(node, viaTerm, thisTerm, conditions)) return;
        }
        const nextId   = edge.fromNode === nodeId ? edge.toNode : edge.fromNode;
        const nextTerm = edge.fromNode === nodeId ? edge.toTerm : edge.fromTerm;
        const nextNode = graph.nodes.get(nextId);

        // AP-MULTI-ENTRY-001 — same fix as VoltagePropagator's own copy of
        // this comment (js/simulation/voltage-propagator.js): a connector
        // or multi-switch node can have several independent wires landing
        // on DIFFERENT pins of the SAME node, each unlocking a different
        // set of onward pairs — a single global `visited` flag set by
        // whichever entry edge is processed FIRST would permanently block
        // every other entry attempt, even via a pin that would unlock
        // genuinely different, still-unexplored onward pairs. Track entry
        // pins per node for a gated next-hop instead, and allow
        // re-queueing via a genuinely NEW entry pin.
        const nextIsConnectorLike = nextNode && (nextNode.type === 'connector' || _isUnmodeledComponent(nextNode));
        const nextIsMultiSwitch = nextNode && typeof MultiSwitchBehavior !== 'undefined' && MultiSwitchBehavior.isMultiSwitch(nextNode);
        const nextIsGated = nextIsConnectorLike || nextIsMultiSwitch;
        const nextEntryKey = nextIsConnectorLike
          ? _pinNumberOf(nextTerm)
          : (nextIsMultiSwitch ? MultiSwitchBehavior._resolveTermName(nextNode.module, nextTerm) : null);

        if (nextIsGated && nextEntryKey != null) {
          if (!enteredPins.has(nextId)) enteredPins.set(nextId, new Set());
          const pins = enteredPins.get(nextId);
          if (pins.has(nextEntryKey)) return;
          pins.add(nextEntryKey);
        } else if (visited.has(nextId)) {
          return;
        }

        // Check for faults or open-circuit behaviors blocking this return path
        if (GroundPropagator._isBlocked(edge, conditions, graph)) return;

        hasGround.set(nextId, true);
        visited.add(nextId);
        queue.push({ id: nextId, viaTerm: nextTerm });
      });
    }

    // Nodes not reachable from ground = no ground path
    graph.nodes.forEach((_, id) => {
      if (!hasGround.has(id)) hasGround.set(id, false);
    });

    return hasGround;
  },

  /**
   * Check whether a specific node has a valid ground under given conditions.
   *
   * @param {string}               nodeId
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {boolean}
   */
  hasGround(nodeId, graph, conditions) {
    const map = GroundPropagator.propagate(graph, conditions);
    return map.get(nodeId) || false;
  },

  /**
   * Find all nodes that are missing a ground path.
   * Used by diagnostics to identify floating components.
   *
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {string[]}  array of moduleIds with no ground
   */
  floatingNodes(graph, conditions) {
    const map = GroundPropagator.propagate(graph, conditions);
    const result = [];
    map.forEach((grounded, id) => { if (!grounded) result.push(id); });
    return result;
  },

  // ── Internal ──────────────────────────────────────────────────────

  _isBlocked(edge, conditions, graph) {
    // Fault blocks
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault && (fault.type === 'open' || fault.type === 'high-resistance')) return true;
    }
    // High-resistance bad-ground blocks the return path
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault && fault.type === 'bad-ground') return true;
    }
    // AP-SWITCHED-GROUND-001 — an open switch blocks the GROUND path
    // through it exactly the same way it already blocks the POWER path
    // in VoltagePropagator (via the same ComponentBehaviors.getEdgeBehavior
    // check) — this was missing entirely before, so a switch wired on
    // its load's ground-return side (a real, common pattern: a neutral/
    // reverse/oil-temp indicator switch that completes ITS OWN ground
    // path when closed, rather than gating the power side) always
    // reported "grounded" regardless of the switch's actual state,
    // silently lighting its bulb any time it was merely powered.
    if (graph && typeof ComponentBehaviors !== 'undefined') {
      const fromNode = graph.nodes.get(edge.fromNode);
      const toNode   = graph.nodes.get(edge.toNode);
      if (ComponentBehaviors.getEdgeBehavior(edge, fromNode, toNode, conditions) === 'open') return true;
    }
    return false;
  },
};
