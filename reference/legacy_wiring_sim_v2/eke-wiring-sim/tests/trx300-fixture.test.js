'use strict';

// PRODUCT-READINESS-002 Phase 12 — integration-level regression against
// the user's real, independently-authored TRX300 diagram (platform/
// oep_studio/samples/diagram7.json — 47 modules / 80 relationships,
// confirmed this session to be structurally distinct from the JS app's
// own bundled demo, not a duplicate of it). This is deliberately NOT a
// snapshot test (no coordinates, no rendered SVG, no exact module-id
// assertions — ids in this file are timestamp-suffixed and NOT stable
// across re-edits, confirmed live: the "Taillight" module's own id is
// literally `mod-headlight-...`, a labeling quirk, not a bug — so every
// lookup below goes by the module's own `label`, which IS what a human
// editing this diagram actually keeps meaningful). It proves real
// electrical BEHAVIOR: with the lights switch on, the headlights and
// taillight actually light; with it off, they don't; the dimmer
// correctly gates HI vs LO; key off means nothing lights at all.
//
// Run with: node --test tests/

const test = require('node:test');
const assert = require('node:assert/strict');

const { loadSolverContext, buildAndSolve, loadOepSampleAsV2 } = require('./harness');

function findByLabel(modules, labelPattern) {
  const m = modules.find(mod => labelPattern.test(mod.label || ''));
  assert.ok(m, `expected a module matching ${labelPattern} in diagram7.json — has the fixture changed shape?`);
  return m;
}

function functionalStatus(ctx, state, moduleId) {
  return ctx.ElectricalSolver.moduleStatus(moduleId, state).functional;
}

test('TRX300 fixture (diagram7.json): loads as a real, non-trivial vehicle topology', () => {
  const { modules, wires } = loadOepSampleAsV2('diagram7.json');
  assert.ok(modules.length > 40, `expected a substantial module count, got ${modules.length}`);
  assert.ok(wires.length > 70, `expected a substantial wire count, got ${wires.length}`);
  // Sanity: the conversion must not produce any wire referencing a
  // module id that doesn't exist among the converted modules (would
  // indicate the v2ModuleId identity mapping broke).
  const ids = new Set(modules.map(m => m.id));
  const dangling = wires.filter(w => !ids.has(w.from.m) || !ids.has(w.to.m));
  assert.deepEqual(dangling, [], 'every wire endpoint must resolve to a real converted module');
});

test('TRX300 fixture: lights switch genuinely controls the headlights and taillight', async (t) => {
  const { modules, wires } = loadOepSampleAsV2('diagram7.json');
  const lh = findByLabel(modules, /^LH Headlight$/);
  const rh = findByLabel(modules, /^RH Headlight$/);
  const tl = findByLabel(modules, /Taillight/);
  const ignitionSwitch = findByLabel(modules, /^Ignition Switch$/);
  const handlebarSwitch = findByLabel(modules, /Handlebar Sw/);

  function solveWithLights(ctx, lightsOn, dimmer) {
    const { state } = buildAndSolve(ctx, modules, wires, {
      keyPosition: 1,
      multiSwitchStates: {
        [ignitionSwitch.id]: { power: 'on' },
        [handlebarSwitch.id]: {
          lights: lightsOn ? 'on' : 'off',
          dimmer: dimmer || 'lo',
          engineStop: 'run',
          starter: 'free',
        },
      },
    });
    return state;
  }

  await t.test('lights ON, dimmer LO: both headlights and the taillight are functional', () => {
    const ctx = loadSolverContext();
    const state = solveWithLights(ctx, true, 'lo');
    assert.equal(functionalStatus(ctx, state, lh.id), true, 'LH Headlight must light with lights on');
    assert.equal(functionalStatus(ctx, state, rh.id), true, 'RH Headlight must light with lights on');
    assert.equal(functionalStatus(ctx, state, tl.id), true, 'Taillight must light with lights on');
  });

  await t.test('lights ON, dimmer HI: still functional (dimmer selects beam, not on/off)', () => {
    const ctx = loadSolverContext();
    const state = solveWithLights(ctx, true, 'hi');
    assert.equal(functionalStatus(ctx, state, lh.id), true);
    assert.equal(functionalStatus(ctx, state, rh.id), true);
  });

  await t.test('lights OFF: headlights and taillight are NOT functional', () => {
    const ctx = loadSolverContext();
    const state = solveWithLights(ctx, false, 'lo');
    assert.equal(functionalStatus(ctx, state, lh.id), false, 'LH Headlight must be dark with lights off');
    assert.equal(functionalStatus(ctx, state, rh.id), false, 'RH Headlight must be dark with lights off');
    assert.equal(functionalStatus(ctx, state, tl.id), false, 'Taillight must be dark with lights off');
  });

  await t.test('key OFF: nothing lights, regardless of switch position', () => {
    const ctx = loadSolverContext();
    const { state } = buildAndSolve(ctx, modules, wires, {
      keyPosition: 0,
      multiSwitchStates: {
        [ignitionSwitch.id]: { power: 'off' },
        [handlebarSwitch.id]: { lights: 'on', dimmer: 'lo', engineStop: 'run', starter: 'free' },
      },
    });
    assert.equal(functionalStatus(ctx, state, lh.id), false, 'key off must override lights=on');
    assert.equal(functionalStatus(ctx, state, rh.id), false);
    assert.equal(functionalStatus(ctx, state, tl.id), false);
  });
});

test('TRX300 fixture: LiveSim.readWireMeasurement() produces real, structured readings against this fixture (the DMM bridge\'s own query path)', () => {
  const ctx = loadSolverContext();
  const { modules, wires } = loadOepSampleAsV2('diagram7.json');
  const ignitionSwitch = findByLabel(modules, /^Ignition Switch$/);
  const handlebarSwitch = findByLabel(modules, /Handlebar Sw/);
  const rh = findByLabel(modules, /^RH Headlight$/);

  // `LiveSim.readWireMeasurement` reads switch state from LiveSim's OWN
  // internal state (set via `setMultiSwitchGroup` -- exactly what
  // SWPACK/sim-panel clicks do in production, and what V2's own
  // meter-panel wire selection, the Dart bridge's real trigger, always
  // happens AFTER in normal use), not from a `conditions` object handed
  // to `buildAndSolve` -- `_conditions()` (live-runner.js) overwrites
  // `multiSwitchStates` from its own closure state on every internal
  // solve. `buildAndSolve` is still called first, for its side effect of
  // populating the `MODULES`/`WIRES`/`EKE.graph` globals
  // `readWireMeasurement`'s own `GraphBuilder.rebuild` needs.
  buildAndSolve(ctx, modules, wires, { keyPosition: 1 });
  ctx.keyPos = 1;
  ctx.LiveSim.setMultiSwitchGroup(ignitionSwitch.id, 'power', 'on');
  ctx.LiveSim.setMultiSwitchGroup(handlebarSwitch.id, 'lights', 'on');
  ctx.LiveSim.setMultiSwitchGroup(handlebarSwitch.id, 'dimmer', 'lo');
  ctx.LiveSim.setMultiSwitchGroup(handlebarSwitch.id, 'engineStop', 'run');
  ctx.LiveSim.setMultiSwitchGroup(handlebarSwitch.id, 'starter', 'free');

  // A real POWER-FEED wire into the RH Headlight (not its ground wire —
  // the fixture wires each headlight's HI/LO beam pins AND its own
  // ground return, and `value > 0` is only meaningful for the power
  // side) -- prove the exact function the Dart bridge calls
  // (`LiveSim.readWireMeasurement`, via __oepBridgeQueryLiveMeasurement)
  // produces a real, non-fabricated structured reading against ACTUAL
  // vehicle wiring, not just the synthetic circuits in
  // solver-invariants.test.js. Specifically the LO-beam feed, matching
  // the dimmer:'lo' condition set above -- the HI-beam feed would
  // correctly read open here.
  const feedWire = wires.find(w =>
    (w.to.m === rh.id || w.from.m === rh.id) && /lo\s*beam/i.test(w.lbl || ''));
  assert.ok(feedWire, 'RH Headlight must have a labeled Lo Beam feed wire in this fixture');
  const reading = ctx.LiveSim.readWireMeasurement(feedWire.id, 'VDC');
  assert.equal(reading.status, 'ok');
  assert.equal(reading.open, false, 'with lights on, a wire feeding a lit RH Headlight must not read open');
  assert.equal(typeof reading.value, 'number');
  assert.ok(reading.value > 0, 'must be a real positive voltage, not a fabricated placeholder');
  assert.ok(reading.source && reading.source.moduleId, 'terminal-level source identity must be populated from real fixture data');
});
