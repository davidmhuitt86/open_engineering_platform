/**
 * js/simulation/voltage-propagator.js
 *
 * Propagates voltage from power sources through the circuit graph.
 *
 * Given a set of source conditions (battery voltage, key position),
 * determines the voltage present at every reachable node by walking
 * the graph and applying component behavior rules.
 *
 * This replaces the static measurements.json lookup for DC voltage.
 *
 * Algorithm:
 *   1. Seed all power-source nodes with their supply voltage
 *   2. BFS outward through the graph
 *   3. At each edge (wire), apply any component behavior that gates
 *      or transforms the voltage (switch open/closed, relay contacts, fuse)
 *   4. Record the voltage at each node
 *
 * No DOM. No rendering. No UI.
 */

// AP-CONNECTOR-BRIDGE-001 — strips a connector pin ref's `_IN`/`_OUT`
// suffix (buildConnCard's own convention, renderer.js) down to its bare
// pin number, so "pin 1 IN" and "pin 1 OUT" compare equal (same
// physical pin, passes through) while "pin 1" and "pin 2" don't (two
// different, electrically-unrelated pins on the same connector body).
// Shared byte-for-byte with ground-propagator.js's own copy — no module
// system in this codebase to import a single definition from.
function _pinNumberOf(termRef) {
  if (termRef == null) return null;
  return String(termRef).replace(/_(IN|OUT)$/, '');
}

// AP-DEADEND-GENERALIZE-001 — generalizes AP-CONNECTOR-BRIDGE-001's
// same-pin-only gating (below) to EVERY plain component this app has no
// real pass-through behavior for, instead of a hardcoded list of
// component types. This graph has one node per MODULE, not per
// terminal, so a component with no RECOGNIZED reason to conduct (a
// switch, a diode, a splice's own bus-bar job, a connector's own
// per-pin gating) let voltage or ground "tunnel" straight through its
// body between ANY two of its pins — this bit TWO separate real
// components in the same diagram before a per-type fix could even be
// written for the first one: an Ignition Coil's PRI+/GND, and (once the
// coil was fixed) a 5-pin Alarm Unit whose power feed leaked out its
// own unrelated chassis-ground pin — both poisoning a shared
// ground-splice bus with false nonzero voltage that then read back as
// "powered" on completely unrelated lamps sharing that same ground
// return. Naming every individual component type as it's discovered is
// a losing game (this app has no module system to enumerate them from
// one place, and the user's own diagrams can use ANY component shape).
//
// Deliberately NOT a full dead end (unlike a lamp or the starter
// motor): a component like a Starter Solenoid legitimately reuses ONE
// physical pin (its BAT lug) for several wires (battery in, AND a
// downstream feed onward to the ignition switch) — those must still
// bridge freely, since they're the same physical terminal, not two
// different ones. So this is treated exactly like a connector — same
// pin only, never a fully different pin — just applied by DEFAULT
// instead of only to modules explicitly flagged `connector: true`.
// Excludes anything that already has its own correct, explicit
// pass-through rule elsewhere in this file (switch, multi-switch,
// diode, splice).
//
// AP-BATTERY-TUNNEL-001 — the power source itself (`cat==='power'`,
// almost always the Battery) was ALSO excluded here at first, on the
// reasoning that it's "just the seed" — wrong: a battery's + and −
// posts are two electrically SEPARATE pins exactly like an Ignition
// Coil's PRI+/GND, and its − post is routinely wired straight to a
// real Ground Point (correctly — that's how a battery grounds a
// vehicle's chassis). Excluding it from this same-pin gating meant
// GroundPropagator, reaching that − pin exactly as intended, then
// tunneled straight through the battery's own body and out its +
// post — flooding the ENTIRE downstream power distribution network
// (every module fed from the battery, however many hops away) with a
// false "grounded" status. This one node explained nearly every
// "always lit regardless of switch state" symptom traced this
// session; the coil/alarm-unit fixes above were real but secondary —
// this was the dominant leak. Safe to include here even though the
// battery is also VoltagePropagator's own seed: a seed node is always
// first entered with `viaTerm: null` (see `queue`'s own construction
// below), and the gating check only ever activates for a non-null
// viaTerm — so this never restricts the battery's OWN initial seeded
// exploration, only a LATER re-entry via one specific pin.
// Shared byte-for-byte with ground-propagator.js's own copy.
function _isUnmodeledComponent(node) {
  if (!node || node.type !== 'module' || !node.module) return false;
  const m = node.module;
  if (m.cat === 'splice') return false;
  if (typeof SwitchBehavior !== 'undefined' && SwitchBehavior.isSwitch(node)) return false;
  if (typeof MultiSwitchBehavior !== 'undefined' && MultiSwitchBehavior.isMultiSwitch(node)) return false;
  if (typeof DiodeBehavior !== 'undefined' && DiodeBehavior.isDiode(node)) return false;
  return true;
}

const VoltagePropagator = {

  /**
   * Calculate the voltage present at every node in the graph
   * under the given simulation conditions.
   *
   * @param {GraphData}          graph
   * @param {SimulationConditions} conditions
   * @returns {Map<string, number>}  nodeId → voltage (V)
   */
  propagate(graph, conditions) {
    /** @type {Map<string, number>} nodeId → solved voltage */
    const nodeVoltage = new Map();

    // AP-VOLTAGE-GROUND-RACE-001 — ground nodes used to ALSO be seeded
    // here (at 0V) alongside power sources, both racing in the SAME BFS.
    // Since a normal 2-terminal load (a bulb: one terminal to power, the
    // OTHER straight to ground — the ordinary, expected topology, not an
    // edge case) has an edge reaching a ground node directly, whichever
    // seed's BFS got there first won — if the ground-side BFS happened
    // to reach the load's node before the power-side BFS did (pure Map/
    // queue insertion-order luck, nothing to do with the actual wiring),
    // the load was permanently marked 0V/unpowered even with a perfectly
    // valid power path, since `visited` blocked the power BFS from ever
    // overwriting it. Ground reachability is GroundPropagator's job
    // (a completely separate BFS) — this one now seeds ONLY power
    // sources, so "is this node powered" is answered purely by whether
    // voltage can reach it, never short-circuited by an unrelated race.
    const batteryVoltage = VoltagePropagator._batteryVoltage(conditions);
    const visited = new Set();
    const queue   = [];

    // AP-MULTI-ENTRY-001 — nodeId → Set of entry-pin keys already tried,
    // for a connector/multi-switch node specifically (declared before the
    // seeding loop below, which now also participates in it — see
    // AP-BATTERY-SEED-PIN-001).
    const enteredPins = new Map();

    // AP-BATTERY-SEED-PIN-001 — a power source is seeded with `viaTerm:
    // null`, and `null` is exactly the one value that SKIPS pin-gating
    // entirely (`viaPin` stays null below, so `isConnectorLike && viaPin
    // != null` is false) — that's correct and necessary for a node with
    // only ONE real external pin. For consistency, and so a power node
    // participates in the SAME `enteredPins` bookkeeping every other
    // pin-gated node does (relevant if it's ever re-entered later via a
    // separate route), this now seeds once PER DISTINCT PIN it actually
    // has a wire on instead of one `viaTerm: null` entry.
    //
    // Deliberate, KNOWN limitation this does NOT (and structurally
    // cannot) fix: this graph has one VOLTAGE VALUE per NODE, not per
    // terminal — `nodeVoltage.set(id, batteryVoltage)` above is set ONCE
    // for the whole node, so a load wired to the battery's OWN − post
    // still reads the full battery voltage on that post's own wire,
    // exactly as it did before this change (confirmed by a regression
    // test attempting the opposite expectation and failing — pin-gating
    // only ever blocks CROSS-pin propagation reached FROM a different
    // entry pin; it cannot give the − post a genuinely different value
    // than the + post has, since there is only one value to give either
    // of them). This is harmless in every real diagram this was checked
    // against: the − post's own wire runs straight to a real Ground
    // Point, which is ALREADY a hard voltage dead-end (line ~150 below)
    // — so this seed-visible value never propagates any further than
    // that one wire. The bug AP-BATTERY-TUNNEL-001 actually fixed is the
    // opposite direction (GROUND reaching the − post tunneling THROUGH
    // the battery's body and back OUT the + post) and remains fixed —
    // see GroundPropagator's own equivalent fix, which does not have
    // this limitation (GroundPropagator seeds real Ground nodes, never
    // the battery itself).
    GraphTraversal.powerNodes(graph).forEach(id => {
      nodeVoltage.set(id, batteryVoltage);
      visited.add(id);
      const node = graph.nodes.get(id);
      const isPinGated = node && (node.type === 'connector' || _isUnmodeledComponent(node));
      if (isPinGated && node.edges.length) {
        const seenPins = new Set();
        node.edges.forEach(edge => {
          const ownTerm = edge.fromNode === id ? edge.fromTerm : edge.toTerm;
          const pin = _pinNumberOf(ownTerm);
          if (pin == null || seenPins.has(pin)) return;
          seenPins.add(pin);
          if (!enteredPins.has(id)) enteredPins.set(id, new Set());
          enteredPins.get(id).add(pin);
          queue.push({ id, viaTerm: ownTerm });
        });
      } else {
        queue.push({ id, viaTerm: null });
      }
    });

    while (queue.length) {
      const { id: nodeId, viaTerm } = queue.shift();
      const node    = graph.nodes.get(nodeId);
      if (!node) continue;
      // AP-VOLTAGE-GROUND-RACE-001 — a ground node is a SINK for voltage
      // propagation, not a conductor: once reached (marked 0V below, via
      // the 'ground' edge behavior), it must NOT keep propagating that
      // 0V onward to every OTHER thing sharing the same chassis-ground
      // point — that would falsely cap every other load on that ground
      // bus at 0V regardless of whether ITS OWN power path is separately
      // valid, for the exact same reason removing the seed above fixes.
      //
      // AP-LAMP-TUNNEL-001 — a lamp (or any real 2-terminal load with an
      // internal drop across it, not a plain junction) is ALSO a dead
      // end here, for the same underlying reason: this graph has one
      // node per MODULE, not per terminal, so an edge touching a lamp's
      // OWN power pin and a SEPARATE edge touching its OWN ground pin
      // are — as far as this BFS can tell — just two edges on the same
      // node. Without this, voltage reaching a lamp's power pin would
      // keep "tunneling" through it and out its ground-return wire,
      // incorrectly marking whatever ELSE shares that return path
      // (another module, even the battery itself if reached indirectly)
      // as powered at the lamp's own voltage — confirmed live: a second,
      // unrelated bulb wired to the same battery lit up whenever a FIRST
      // bulb's own ground-return path was traced through, purely because
      // of this tunneling, with no real electrical connection between
      // the two circuits at all.
      if (node.type === 'ground') continue;
      if (typeof LampBehavior !== 'undefined' && LampBehavior.isLamp(node)) continue;
      const srcV = nodeVoltage.get(nodeId);
      // AP-CONNECTOR-BRIDGE-001 — a connector's pins are NOT electrically
      // joined to each other (it's a mechanical multi-pin plug bundling
      // otherwise-unrelated wires, unlike a splice, whose whole job IS
      // joining every wire on it) — but this graph has one node per
      // MODULE, not per terminal, so every pin's edges used to look
      // identical to the BFS, and voltage arriving on pin 1 "tunneled"
      // straight out pin 2 to whatever THAT wire happened to feed, with
      // zero real electrical connection between them. Confirmed live: a
      // bulb wired only to a connector's pin 2, with nothing else on
      // that circuit at all, still read as fully powered purely because
      // the SAME connector's pin 1 happened to be wired to the battery.
      // Fix: once inside a connector, only continue through an edge on
      // the SAME pin number (its `_IN`/`_OUT` counterpart) as the one we
      // arrived through — never a DIFFERENT pin. `viaTerm` is null only
      // for a seed node (a connector is never a power source), so this
      // never over-restricts anything else.
      //
      // AP-DEADEND-GENERALIZE-001 — an unmodeled component (see above)
      // gets this EXACT same same-pin-only treatment, not just a real
      // `connector: true` module: it may freely bridge several wires
      // that share one physical pin, but never tunnels between two of
      // its OWN different pins the way a lamp or the starter motor
      // (fully dead-ended, not pin-gated, above) would.
      const isConnectorLike = node.type === 'connector' || _isUnmodeledComponent(node);
      const viaPin = isConnectorLike && viaTerm != null ? _pinNumberOf(viaTerm) : null;
      // AP-MULTI-SWITCH-001 — same "which of my own edges may this signal
      // continue out of" mechanism as the connector fix just above, but
      // for a real multi-position switch (knowledge/behaviors/multi-
      // switch.js — Ignition/Lighting/Dimmer/Engine Stop/Starter,
      // matched by terminal name, not a hardcoded module id): instead of
      // "same pin number", the rule is "is (viaTerm, thisTerm) one of
      // THIS switch's own internally-bridged pairs under its CURRENT
      // selected position" — e.g. the ignition switch only bridges its
      // own BAT1 to its own BAT2 when its `power` group is 'on'.
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

        // AP-MULTI-ENTRY-001 — a connector or multi-switch node can have
        // SEVERAL independent external wires landing on DIFFERENT pins of
        // the SAME node (e.g. a handlebar switch's BAT2 pin fed by the
        // battery AND its ST pin fed by the starter button, from two
        // unrelated directions) — each entry pin can unlock a DIFFERENT
        // set of onward pairs (the isConnector/isMultiSwitch filter
        // above). A single global `visited` flag, set by whichever entry
        // edge the BFS happens to process FIRST, would permanently block
        // every OTHER entry attempt — even via a pin that would unlock
        // genuinely different, still-unexplored onward pairs. Confirmed
        // live: the handlebar switch got marked visited via its ST pin
        // (reached from the starter circuit) before its own BAT2 pin's
        // edge (from the battery) was ever tried, so the lights/dimmer/
        // taillight pairs — gated on a BAT2 entry — never got a chance to
        // evaluate, leaving the headlights permanently dark regardless of
        // switch position. Fix: track entry pins PER NODE for a gated
        // next-hop, and allow re-queueing the same node via a genuinely
        // NEW entry pin even after it's already been visited via another
        // one. Voltage itself is still only ever recorded once (first
        // arrival wins, below) — only "which of my edges get explored"
        // needs re-running per pin.
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

        // Ask the behavior registry whether this wire passes voltage
        const passV = VoltagePropagator._resolveEdgeVoltage(edge, srcV, conditions, graph);

        if (passV !== null) {
          if (!nodeVoltage.has(nextId)) nodeVoltage.set(nextId, passV);
          visited.add(nextId);
          queue.push({ id: nextId, viaTerm: nextTerm });
        }
      });
    }

    // Any unvisited node = 0V (no path to power, or blocked by open circuit)
    graph.nodes.forEach((_, id) => {
      if (!nodeVoltage.has(id)) nodeVoltage.set(id, 0);
    });

    return nodeVoltage;
  },

  /**
   * Get the voltage at a specific node under the given conditions.
   *
   * @param {string}               nodeId
   * @param {GraphData}            graph
   * @param {SimulationConditions} conditions
   * @returns {number}
   */
  voltageAt(nodeId, graph, conditions) {
    const map = VoltagePropagator.propagate(graph, conditions);
    return map.get(nodeId) || 0;
  },

  /**
   * Get the voltage present on a wire (the lower of its two endpoint voltages,
   * since the wire itself is a conductor — it carries whatever is supplied to it).
   *
   * @param {GraphEdge}            edge
   * @param {Map<string,number>}   nodeVoltage
   * @returns {number}
   */
  voltageOnWire(edge, nodeVoltage) {
    const fromV = nodeVoltage.get(edge.fromNode) || 0;
    const toV   = nodeVoltage.get(edge.toNode)   || 0;
    return Math.max(fromV, toV);
  },

  // ── Internal ──────────────────────────────────────────────────────

  _batteryVoltage(conditions) {
    switch (conditions.keyPosition) {
      case 0: return 12.6;  // key off — battery voltage present on always-hot lines
      case 1: return 12.6;  // key on
      case 2: return 11.8;  // cranking — slight voltage drop
      case 3: return 14.2;  // running — charging system raises voltage
      default: return 12.6;
    }
  },

  /**
   * Resolve what voltage passes through an edge given the source voltage
   * and current simulation conditions.
   *
   * Returns null if the edge blocks voltage (open switch, blown fuse, etc).
   * Returns a voltage if the edge passes current.
   *
   * @param {GraphEdge}            edge
   * @param {number}               srcVoltage
   * @param {SimulationConditions} conditions
   * @param {GraphData}            graph
   * @returns {number|null}
   */
  _resolveEdgeVoltage(edge, srcVoltage, conditions, graph) {
    // Check for injected faults that open this wire
    if (conditions.faults) {
      const fault = conditions.faults.get(edge.wire.id);
      if (fault) {
        if (fault.type === 'open' || fault.type === 'blown-fuse') return null;
        if (fault.type === 'short-to-gnd') return 0;
        if (fault.type === 'short-to-pwr') return VoltagePropagator._batteryVoltage(conditions);
      }
    }

    // Delegate to component behavior
    const toNode = graph.nodes.get(edge.toNode);
    const fromNode = graph.nodes.get(edge.fromNode);

    // Let the behavior registry determine if voltage passes
    const behavior = ComponentBehaviors.getEdgeBehavior(edge, fromNode, toNode, conditions);
    if (behavior === 'open')   return null;
    if (behavior === 'ground') return 0;
    if (typeof behavior === 'number') return behavior;

    // Default: pass through with negligible drop
    return srcVoltage;
  },
};

/**
 * @typedef {{
 *   keyPosition:  number,
 *   switchStates: Object.<string, string>,
 *   faults:       Map<string, object>
 * }} SimulationConditions
 */
