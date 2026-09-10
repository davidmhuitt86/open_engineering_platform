'use strict';

// PRODUCT-READINESS-002 Phase 1 — automated regression coverage for the
// load-bearing solver invariants fixed over the last 3 days, none of
// which had ANY automated test before this file. Run with:
//   node --test tests/
//
// Each invariant gets its own small, synthetic, minimal circuit — not
// the full TRX300 fixture (see trx300-fixture.test.js for the
// integration-level proof against real vehicle topology). These are
// intentionally generic: none reference TRX300/Honda-specific ids,
// proving the solver itself (as opposed to swpack.js/the factory
// continuity tables/the sample diagrams) is genuinely general-purpose.

const test = require('node:test');
const assert = require('node:assert/strict');

const { loadSolverContext, buildAndSolve } = require('./harness');

test('A. Battery isolation', async (t) => {
  await t.test('ground on the − post does not leak through to the + post (GroundPropagator)', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'gnd', cat: 'ground', terminals: [{ n: 'GND' }] },
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'loadOnPlus', cat: 'accessory', terminals: [{ n: 'A' }] },
    ];
    const WIRES = [
      { id: 'w-gnd', from: { m: 'gnd', t: 'GND' }, to: { m: 'bat', t: '−' } },
      { id: 'w-load', from: { m: 'bat', t: '+' }, to: { m: 'loadOnPlus', t: 'A' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const gMap = ctx.GroundPropagator.propagate(graph, conditions);
    assert.equal(gMap.get('loadOnPlus'), false,
      'a node reachable ONLY via the battery + post must not be marked grounded just because the − post is');
  });

  await t.test('a real load on the + post is unaffected by the − post also having its own wire (regression safety)', () => {
    // KNOWN, DOCUMENTED LIMITATION (see AP-BATTERY-SEED-PIN-001's own
    // comment in voltage-propagator.js): this graph has one VOLTAGE
    // VALUE per NODE, not per terminal, so a battery's − post's OWN wire
    // still carries the same seeded value its + post does — pin-gating
    // can only stop that value from tunneling FURTHER, through some
    // OTHER component, onto a THIRD, unrelated circuit; it cannot give
    // the − post a genuinely different value than the + post. This is
    // harmless in every real diagram (the − post's wire runs straight to
    // a real Ground Point, itself a hard voltage dead-end — see the next
    // sub-test) — what THIS sub-test actually guards is that seeding the
    // battery per-pin didn't regress the ordinary, correct case: a real
    // load on + must still read the full battery voltage.
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'gnd', cat: 'ground', terminals: [{ n: 'GND' }] },
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'loadPlus', cat: 'accessory', terminals: [{ n: 'A' }] },
      { id: 'unrelatedGroundedLoad', cat: 'accessory', terminals: [{ n: 'B' }] },
    ];
    const WIRES = [
      { id: 'w-minus', from: { m: 'bat', t: '−' }, to: { m: 'gnd', t: 'GND' } },
      { id: 'w-plus', from: { m: 'bat', t: '+' }, to: { m: 'loadPlus', t: 'A' } },
      // An entirely separate circuit sharing only the same chassis
      // ground point -- must NOT see the battery's seeded voltage just
      // because it's also grounded (the real-world-relevant guarantee).
      { id: 'w-unrelated', from: { m: 'gnd', t: 'GND' }, to: { m: 'unrelatedGroundedLoad', t: 'B' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
    assert.equal(vMap.get('loadPlus'), 12.6, 'a real load on the + post must still read the full battery voltage');
    assert.equal(vMap.get('unrelatedGroundedLoad'), 0,
      'the − post seed value must not propagate PAST the ground point onto an unrelated circuit sharing only that ground');
  });

  await t.test('readWire()/moduleStatus() semantics agree: a load fed only through the − post shows unpowered', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'gnd', cat: 'ground', terminals: [{ n: 'GND' }] },
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'coil', cat: 'ignition', terminals: [{ n: 'PRI+' }, { n: 'GND' }] },
      { id: 'splice1', cat: 'splice', terminals: [{ n: 'SPLICE' }] },
      { id: 'lamp1', bulb: true, terminals: [{ n: 'SIG' }, { n: 'GND' }] },
    ];
    const WIRES = [
      { id: 'w1', from: { m: 'bat', t: '+' }, to: { m: 'coil', t: 'PRI+' } },
      { id: 'w2', from: { m: 'coil', t: 'GND' }, to: { m: 'splice1', t: 'SPLICE' } },
      { id: 'w3', from: { m: 'splice1', t: 'SPLICE' }, to: { m: 'lamp1', t: 'GND' } },
      { id: 'w4', from: { m: 'gnd', t: 'GND' }, to: { m: 'bat', t: '−' } },
    ];
    const { state } = buildAndSolve(ctx, MODULES, WIRES);
    const status = ctx.ElectricalSolver.moduleStatus('lamp1', state);
    assert.equal(status.powered, false,
      'a lamp reachable only through the coil\'s ground-return path (itself only reachable via the battery − post) must not read powered');
  });
});

test('B. Unmodeled multi-terminal component pin gating', async (t) => {
  await t.test('pin A -> pin A (same physical pin) passes freely', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'unmodeled', cat: 'accessory', terminals: [{ n: 'PIN_A' }, { n: 'PIN_B' }] },
      { id: 'sameA', cat: 'accessory', terminals: [{ n: 'X' }] },
    ];
    const WIRES = [
      { id: 'w1', from: { m: 'bat', t: '+' }, to: { m: 'unmodeled', t: 'PIN_A' } },
      { id: 'w2', from: { m: 'unmodeled', t: 'PIN_A' }, to: { m: 'sameA', t: 'X' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
    assert.equal(vMap.get('sameA'), 12.6,
      'two wires on the SAME pin of an unmodeled component must bridge (this is the legitimate "one physical lug, several wires" case, e.g. a solenoid\'s BAT post)');
  });

  await t.test('pin A -> pin B (different pins) is NOT automatically allowed', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'unmodeled', cat: 'accessory', terminals: [{ n: 'PIN_A' }, { n: 'PIN_B' }] },
      { id: 'onB', cat: 'accessory', terminals: [{ n: 'X' }] },
    ];
    const WIRES = [
      { id: 'w1', from: { m: 'bat', t: '+' }, to: { m: 'unmodeled', t: 'PIN_A' } },
      { id: 'w2', from: { m: 'unmodeled', t: 'PIN_B' }, to: { m: 'onB', t: 'X' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
    assert.equal(vMap.get('onB'), 0,
      'voltage entering an unmodeled component via one pin must NOT tunnel out a DIFFERENT pin with no defined cross-pin behavior');
  });
});

test('C. Multi-entry BFS / per-pin terminal identity is not collapsed', () => {
  const ctx = loadSolverContext();
  // A generic 2-group multi-position switch, entered via two DIFFERENT
  // external wires on two DIFFERENT pins (groupA's own terminal, and
  // groupB's own terminal) — proves the switch can be productively
  // entered via a SECOND pin even after being reached via a FIRST pin
  // whose own group doesn't unlock anything (the exact bug this session
  // found live: a switch reached via its "ST"-equivalent pin first
  // permanently blocked its "BAT2"-equivalent pin from ever being tried).
  const MODULES = [
    { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
    {
      id: 'sw', cat: 'control',
      terminals: [{ n: 'COMMON' }, { n: 'OUT_A' }, { n: 'DEAD_END_PIN' }],
    },
    { id: 'target', cat: 'accessory', terminals: [{ n: 'X' }] },
  ];
  const WIRES = [
    // Entry #1: a wire on the switch's DEAD_END_PIN — a pin with no
    // closedPairs entry at all under this state, so if the BFS
    // permanently "used up" the switch node on this entry, target would
    // never be reached even though a SECOND, genuinely valid entry
    // (COMMON, below) also exists.
    { id: 'w-deadend', from: { m: 'bat', t: '+' }, to: { m: 'sw', t: 'DEAD_END_PIN' } },
    // Entry #2: the switch's real COMMON pin, independently wired to the
    // SAME battery — must still be tried and must correctly unlock OUT_A.
    { id: 'w-common', from: { m: 'bat', t: '+' }, to: { m: 'sw', t: 'COMMON' } },
    { id: 'w-out', from: { m: 'sw', t: 'OUT_A' }, to: { m: 'target', t: 'X' } },
  ];
  // Register a throwaway generic def so `sw` is recognized as a
  // multi-switch purely by its terminal NAME SET (never a hardcoded id —
  // invariant D covers this more directly) — COMMON/OUT_A close when
  // 'group' is 'on'; DEAD_END_PIN is a real terminal with NO pair at all.
  ctx.MultiSwitchBehavior.DEFS.push({
    id: 'testMultiEntrySwitch',
    terms: ['COMMON', 'OUT_A', 'DEAD_END_PIN'],
    groups: { group: ['off', 'on'] },
    defaults: { group: 'on' },
    closedPairs(state) { return state.group === 'on' ? [['COMMON', 'OUT_A']] : []; },
  });
  const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES, {
    multiSwitchStates: { sw: { group: 'on' } },
  });
  const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
  assert.equal(vMap.get('target'), 12.6,
    'the switch must be independently re-enterable via its COMMON pin even after already being entered via DEAD_END_PIN first');
});

test('D. Multi-position switch pair-closed logic is generic (matched by terminal name, never a hardcoded id)', () => {
  const ctx = loadSolverContext();
  // A module with a deliberately arbitrary, non-TRX300, auto-generated-
  // looking id — MultiSwitchBehavior must recognize it purely by its
  // terminal NAME SET, exactly as it must for a user's own diagram.
  const MODULES = [
    { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
    {
      id: 'mod-xyz-9182734', cat: 'control',
      terminals: [{ n: 'HI' }, { n: 'HL' }, { n: 'LO' }],
    },
    { id: 'hiLoad', cat: 'accessory', terminals: [{ n: 'X' }] },
    { id: 'loLoad', cat: 'accessory', terminals: [{ n: 'X' }] },
  ];
  const WIRES = [
    { id: 'w-feed', from: { m: 'bat', t: '+' }, to: { m: 'mod-xyz-9182734', t: 'HL' } },
    { id: 'w-hi', from: { m: 'mod-xyz-9182734', t: 'HI' }, to: { m: 'hiLoad', t: 'X' } },
    { id: 'w-lo', from: { m: 'mod-xyz-9182734', t: 'LO' }, to: { m: 'loLoad', t: 'X' } },
  ];

  const def = ctx.MultiSwitchBehavior.match({ terminals: MODULES[1].terminals });
  assert.ok(def, 'a module must be recognized as a multi-switch by its terminal NAME SET alone, with no id involved');
  assert.equal(def.id, 'dimmerSwitch', 'the built-in dimmer definition should match HI/HL/LO regardless of module id');

  const loState = buildAndSolve(ctx, MODULES, WIRES, {
    multiSwitchStates: { 'mod-xyz-9182734': { dimmer: 'lo' } },
  });
  const loV = ctx.VoltagePropagator.propagate(loState.graph, loState.conditions);
  assert.equal(loV.get('hiLoad'), 0, 'dimmer=lo: HI must be open');
  assert.equal(loV.get('loLoad'), 12.6, 'dimmer=lo: LO must be conductive');

  const hiState = buildAndSolve(ctx, MODULES, WIRES, {
    multiSwitchStates: { 'mod-xyz-9182734': { dimmer: 'hi' } },
  });
  const hiV = ctx.VoltagePropagator.propagate(hiState.graph, hiState.conditions);
  assert.equal(hiV.get('hiLoad'), 12.6, 'dimmer=hi: HI must be conductive');
  assert.equal(hiV.get('loLoad'), 0, 'dimmer=hi: LO must be open — never both positions live at once');
});

test('E. Lamp dead-end behavior', () => {
  const ctx = loadSolverContext();
  // Two electrically UNRELATED circuits that happen to share a lamp's
  // two pins as their only common point — the lamp must not become an
  // accidental wire-to-wire bridge between them.
  const MODULES = [
    { id: 'batA', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
    { id: 'lamp', bulb: true, terminals: [{ n: 'SIG' }, { n: 'GND' }] },
    { id: 'unrelated', cat: 'accessory', terminals: [{ n: 'X' }] },
  ];
  const WIRES = [
    { id: 'w-feed', from: { m: 'batA', t: '+' }, to: { m: 'lamp', t: 'SIG' } },
    { id: 'w-tunnel', from: { m: 'lamp', t: 'GND' }, to: { m: 'unrelated', t: 'X' } },
  ];
  const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
  const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
  assert.equal(vMap.get('unrelated'), 0,
    'voltage reaching a lamp\'s SIG pin must not tunnel out its GND pin onto an unrelated circuit');
});

test('F. Starter motor dead-end behavior (body-grounded, no wire needed)', () => {
  const ctx = loadSolverContext();
  const MODULES = [
    { id: 'starter', starterMotor: true, terminals: [{ n: 'B+' }, { n: 'GND' }] },
    { id: 'feedsB+', cat: 'power', terminals: [{ n: '+' }] },
  ];
  // No Ground Point module at all -- the starter's body-ground is an
  // implicit solver connection (AP-BODY-GROUND-AUTO-001), not a wire.
  const WIRES = [
    { id: 'w1', from: { m: 'feedsB+', t: '+' }, to: { m: 'starter', t: 'B+' } },
  ];
  const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
  const gMap = ctx.GroundPropagator.propagate(graph, conditions);
  assert.equal(gMap.get('starter'), true,
    'a starterMotor-flagged module must be grounded with no drawn wire to a Ground Point');
  assert.equal(gMap.get('feedsB+'), false,
    'the starter\'s auto-ground must NOT leak back out its B+ lead onto whatever feeds it');
});

test('G. Connector same-pin behavior', async (t) => {
  await t.test('connector pin A -> pin A (IN/OUT of the same physical pin) passes', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'conn', connector: true, terminals: [{ n: 'A' }, { n: 'B' }] },
      { id: 'downstream', cat: 'accessory', terminals: [{ n: 'X' }] },
    ];
    const WIRES = [
      { id: 'w1', from: { m: 'bat', t: '+' }, to: { m: 'conn', t: 'A_IN' } },
      { id: 'w2', from: { m: 'conn', t: 'A_OUT' }, to: { m: 'downstream', t: 'X' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
    assert.equal(vMap.get('downstream'), 12.6, 'same connector pin (A_IN -> A_OUT) must pass through');
  });

  await t.test('connector pin A -> pin B is NOT automatically allowed', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'conn', connector: true, terminals: [{ n: 'A' }, { n: 'B' }] },
      { id: 'onB', cat: 'accessory', terminals: [{ n: 'X' }] },
    ];
    const WIRES = [
      { id: 'w1', from: { m: 'bat', t: '+' }, to: { m: 'conn', t: 'A_IN' } },
      { id: 'w2', from: { m: 'conn', t: 'B_OUT' }, to: { m: 'onB', t: 'X' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
    assert.equal(vMap.get('onB'), 0, 'a connector\'s different pins must be electrically isolated from each other');
  });
});

test('H. Splice bridging (deliberately conductive — the contrast case to G)', () => {
  const ctx = loadSolverContext();
  const MODULES = [
    { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
    { id: 'splice', cat: 'splice', terminals: [{ n: 'SPLICE' }] },
    { id: 'wireBTarget', cat: 'accessory', terminals: [{ n: 'X' }] },
  ];
  const WIRES = [
    { id: 'wireA', from: { m: 'bat', t: '+' }, to: { m: 'splice', t: 'SPLICE' } },
    { id: 'wireB', from: { m: 'splice', t: 'SPLICE' }, to: { m: 'wireBTarget', t: 'X' } },
  ];
  const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
  const vMap = ctx.VoltagePropagator.propagate(graph, conditions);
  assert.equal(vMap.get('wireBTarget'), 12.6,
    'a splice\'s whole job is bridging every wire on it -- unlike a connector, this MUST conduct');
});

test('I. Open/unreachable is distinguishable from a genuine 0.00V, never collapsed', async (t) => {
  await t.test('readWire(): an unreachable (no power path) wire reads CONT=OPN, VDC=0.00 -- not a fabricated voltage', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'floating', cat: 'accessory', terminals: [{ n: 'X' }] },
      { id: 'unconnected', cat: 'accessory', terminals: [{ n: 'Y' }] },
    ];
    // `floating` has NO wire to the battery at all -- genuinely
    // unreachable, not merely at 0V. Note: CONT here reflects GROUND
    // reachability (neither end has a ground path either), not the
    // wire's own resistance -- a plain conductor has near-zero
    // resistance independent of whether either end reaches power/ground,
    // exactly like a real ohmmeter can read a wire's own continuity with
    // the circuit fully unpowered. See the next sub-test for a genuinely
    // open (Infinity-resistance) component.
    const WIRES = [
      { id: 'w-open', from: { m: 'floating', t: 'X' }, to: { m: 'unconnected', t: 'Y' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const reading = ctx.ElectricalSolver.readWire('w-open', graph, conditions);
    assert.equal(reading.CONT, 'OPN', 'a wire with no ground path on either end must report OPN continuity');
    assert.equal(reading.VDC, '0.00', 'an unreachable wire must read 0.00V, never a fabricated voltage');
  });

  await t.test('readWire(): a genuinely open component (switch left open) reads RES=OL, never a fabricated ohm value', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'bat', cat: 'power', terminals: [{ n: '+' }, { n: '−' }] },
      { id: 'sw', cat: 'control', groundedSwitch: true, terminals: [{ n: 'SW' }, { n: 'GND' }] },
      { id: 'downstream', cat: 'accessory', terminals: [{ n: 'X' }] },
    ];
    // No switchStates entry for 'sw' -> defaults to OPEN.
    const WIRES = [
      { id: 'w-open-sw', from: { m: 'sw', t: 'SW' }, to: { m: 'downstream', t: 'X' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const reading = ctx.ElectricalSolver.readWire('w-open-sw', graph, conditions);
    assert.equal(reading.RES, 'OL', 'an open switch must report OL resistance, not a fabricated ohm value');
  });

  await t.test('readWire(): a genuinely grounded, reachable point at true 0V still reports continuity/reachability, not "unknown"', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'gnd', cat: 'ground', terminals: [{ n: 'GND' }] },
      { id: 'grounded', cat: 'accessory', terminals: [{ n: 'X' }] },
    ];
    const WIRES = [
      { id: 'w-gnd', from: { m: 'gnd', t: 'GND' }, to: { m: 'grounded', t: 'X' } },
    ];
    const { graph, conditions } = buildAndSolve(ctx, MODULES, WIRES);
    const reading = ctx.ElectricalSolver.readWire('w-gnd', graph, conditions);
    assert.equal(reading.VDC, '0.00');
    assert.equal(reading.CONT, '000',
      'a genuinely grounded/reachable 0V point must show CONTINUOUS (000), the opposite reading from an open circuit, even though both display "0.00" for VDC');
  });

  await t.test('LiveSim.readWireMeasurement(): open flag distinguishes OL from a true measured zero, structurally (not by string-matching a display value)', () => {
    const ctx = loadSolverContext();
    const MODULES = [
      { id: 'gnd', cat: 'ground', terminals: [{ n: 'GND' }] },
      { id: 'grounded', cat: 'accessory', terminals: [{ n: 'X' }] },
      { id: 'floating', cat: 'accessory', terminals: [{ n: 'X' }] },
      { id: 'unconnected', cat: 'accessory', terminals: [{ n: 'Y' }] },
    ];
    const WIRES = [
      { id: 'w-gnd', from: { m: 'gnd', t: 'GND' }, to: { m: 'grounded', t: 'X' } },
      { id: 'w-open', from: { m: 'floating', t: 'X' }, to: { m: 'unconnected', t: 'Y' } },
    ];
    buildAndSolve(ctx, MODULES, WIRES);
    const zeroReading = ctx.LiveSim.readWireMeasurement('w-gnd', 'VDC');
    const openReading = ctx.LiveSim.readWireMeasurement('w-open', 'VDC');
    assert.equal(zeroReading.open, false, 'a genuinely reachable 0V point must have open:false');
    assert.equal(openReading.open, true, 'an unreachable point must have open:true');
    assert.notEqual(zeroReading.open, openReading.open,
      'the structured DTO must never let a consumer confuse these two states by inspecting only `value`');
  });
});
