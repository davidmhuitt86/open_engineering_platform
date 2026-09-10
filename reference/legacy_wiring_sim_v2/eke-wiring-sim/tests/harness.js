'use strict';

// PRODUCT-READINESS-002 Phase 2 — the smallest deterministic test harness
// that fits this codebase, not a framework. The solver files under
// js/graph/, js/knowledge/behaviors/, and js/simulation/ are plain
// browser-global scripts (no module.exports/require — they are loaded via
// <script> tags in index.html and rely on shared global scope + load
// order). Rather than retrofit a module system onto production code just
// to make it testable (an "architecture refactor" the task explicitly
// rules out), this loads the SAME files, in the SAME order index.html
// uses, into one Node `vm` sandbox context — functionally identical to
// what a browser's script tags do, without needing a browser or DOM at
// all (none of the files in LOAD_ORDER touch `document`/`window` outside
// a function body, so nothing executes at load time that would need one).
//
// Node's own built-in test runner (`node:test`, stable since Node 18,
// zero extra dependencies) is used for the actual test files — see
// solver-invariants.test.js / trx300-fixture.test.js. Run with:
//   node --test tests/

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.join(__dirname, '..');

// Mirrors index.html's own <script> order for exactly the
// simulation-relevant subset (graph model, component knowledge, the
// solver itself) — deliberately excludes anything UI/editor/renderer/
// storage-related, none of which the solver depends on.
const LOAD_ORDER = [
  'js/graph/graph-builder.js',
  'js/graph/graph-traversal.js',
  'js/knowledge/behaviors/battery.js',
  'js/knowledge/behaviors/switch.js',
  'js/knowledge/behaviors/relay.js',
  'js/knowledge/behaviors/diode.js',
  'js/knowledge/behaviors/lamp.js',
  'js/knowledge/behaviors/motor.js',
  'js/knowledge/behaviors/multi-switch.js',
  'js/knowledge/behaviors/index.js',
  'js/simulation/voltage-propagator.js',
  'js/simulation/ground-propagator.js',
  'js/simulation/continuity-solver.js',
  'js/simulation/electrical-solver.js',
  'js/simulation/live-runner.js',
];

/**
 * Loads a fresh copy of the live solver stack into an isolated vm
 * context and returns it. Fresh per call (not memoized/shared) so one
 * test file's mutations (e.g. LiveSim's own internal switchStates) can
 * never leak into another test.
 *
 * @returns {object} the sandbox — access e.g. `ctx.GraphBuilder`,
 *   `ctx.VoltagePropagator`, `ctx.ElectricalSolver`, `ctx.LiveSim`.
 */
// Every top-level `const X = ...`/`class X ...` this harness's callers
// need to reach from plain Node code (not from more script run inside
// the same vm context) — see the "why" note below.
const EXPORTED_NAMES = [
  'GraphBuilder', 'GraphTraversal',
  'BatteryBehavior', 'SwitchBehavior', 'RelayBehavior', 'DiodeBehavior',
  'LampBehavior', 'MotorBehavior', 'MultiSwitchBehavior', 'ComponentBehaviors',
  'VoltagePropagator', 'GroundPropagator', 'ContinuitySolver', 'ElectricalSolver',
  'LiveSim',
];

function loadSolverContext() {
  const sandbox = {
    console,
    // `getEdgeBehavior()` (knowledge/behaviors/index.js) checks
    // `window.SWPACK` to see whether the TRX300-specific switch-pack
    // override table is loaded — this harness deliberately does NOT load
    // swpack.js (it's UI/product data, out of scope for generic solver
    // tests), so `window` just needs to exist as a plain object; `window.
    // SWPACK` then correctly evaluates to `undefined` (no override table
    // registered) exactly like a real page that hasn't loaded swpack.js
    // yet, rather than throwing `ReferenceError: window is not defined`.
    window: {},
    // `LiveSim.setSwitch`/`setMultiSwitchGroup` call `refresh()`
    // internally (exactly like a real SWPACK/sim-panel click would),
    // which updates each lamp's glow via `_applyLampVisual` —
    // `document.querySelector`/`CSS.escape` calls that need to exist
    // (returning "no element" is fine; this harness never renders
    // anything) so a test that goes through LiveSim's OWN setters
    // — the same entry point production code uses, and the one
    // `LiveSim.readWireMeasurement`'s own switch-state reads depend on
    // (see AP-DMM-BRIDGE-001's `_conditions()`) — doesn't throw
    // `ReferenceError: document is not defined`.
    document: { querySelector: () => null },
    CSS: { escape: (s) => String(s) },
  };
  vm.createContext(sandbox);
  for (const rel of LOAD_ORDER) {
    const code = fs.readFileSync(path.join(ROOT, rel), 'utf8');
    vm.runInContext(code, sandbox, { filename: rel });
  }
  // `const`/`class` declarations create bindings in the context's global
  // LEXICAL environment, resolvable by more script run in that SAME
  // context, but — exactly like `const x = 1` at a real browser's top
  // level never becoming `window.x` — they are never attached to the
  // sandbox object itself, so plain Node code holding `sandbox` can't
  // reach `sandbox.GraphBuilder` directly. One more tiny script, run in
  // the same context, copies each name onto the context's own global
  // object (`globalThis` inside a vm context IS that context's sandbox
  // object) so ordinary Node code can use it afterwards.
  const exportScript = EXPORTED_NAMES
    .map(name => `if (typeof ${name} !== 'undefined') { globalThis.${name} = ${name}; }`)
    .join('\n');
  vm.runInContext(exportScript, sandbox, { filename: '(harness export)' });
  return sandbox;
}

/** Plain, minimal simulation conditions — override fields as needed. */
function baseConditions(overrides) {
  return Object.assign(
    {
      keyPosition: 1,
      switchStates: {},
      multiSwitchStates: {},
      faults: new Map(),
      engineState: {},
    },
    overrides || {},
  );
}

/**
 * `ComponentBehaviors.wireResistance` (knowledge/behaviors/index.js) is a
 * pre-existing exception to every OTHER solver function's own convention
 * of taking `graph` as an explicit parameter — it reaches for a global
 * `EKE.graph` instead (the real app keeps this in sync itself; nothing
 * this task's scope calls for changing). Any test exercising a RES/CONT
 * reading (which routes through `ContinuitySolver._wireResistance` →
 * `ComponentBehaviors.wireResistance`) must set this first, mirroring
 * what the real app's own bootstrap/live-runner already keep current.
 */
function setActiveGraph(ctx, graph, conditions) {
  ctx.EKE = { graph, conditions };
}

/**
 * One-call setup for a test circuit: builds the graph, wires up `EKE.
 * graph`/`EKE.conditions` (see [setActiveGraph]) and the `MODULES`/
 * `WIRES`/`keyPos` globals `LiveSim.readWireMeasurement` itself needs,
 * and returns everything a test typically wants.
 *
 * @param {object} ctx        from [loadSolverContext]
 * @param {object[]} modules
 * @param {object[]} wires
 * @param {object}   [conditionOverrides]
 * @returns {{graph: object, conditions: object, state: object}}
 *   `state` is `ElectricalSolver.solve(graph, conditions)`'s own result.
 */
function buildAndSolve(ctx, modules, wires, conditionOverrides) {
  const conditions = baseConditions(conditionOverrides);
  const graph = ctx.GraphBuilder.build(modules, wires);
  setActiveGraph(ctx, graph, conditions);
  ctx.MODULES = modules;
  ctx.WIRES = wires;
  ctx.keyPos = conditions.keyPosition;
  const state = ctx.ElectricalSolver.solve(graph, conditions);
  return { graph, conditions, state };
}

// PRODUCT-READINESS-002 Phase 12 — converts an OEP-format
// DiagramDocument (platform/oep_studio/samples/*.json) into V2's own
// flat MODULES/WIRES shape, so the TRX300 fixture test can run the
// SAME real diagram data through the SAME live solver this whole
// package is about, without needing a running Studio app or WebView.
//
// This is the SAME conversion verified interactively earlier this
// session (found and fixed twice: v2Category must map to `cat`, not a
// generically-stripped `category`; and a module's real `id` for solver
// purposes is `metadata.v2ModuleId` — the identity Diagram Studio's own
// bridge (legacy_v2_state_adapter.dart) actually uses — NOT the OEP
// graph's own outer node id, which is a separate, unrelated identifier
// only the OEP/Dart side cares about).
const FIELD_MAP = {
  v2Category: 'cat', v2Sublabel: 'sub', v2Sub: 'sub', v2Exit: 'exit',
  v2Terminals: 'terminals', v2Connector: 'connector', v2Vertical: 'vertical',
  v2Flipped: 'flipped', v2LabelPos: 'labelPos', v2PinLabelPos: 'pinLabelPos',
  v2BulbStyle: 'bulbStyle', v2BulbColor: 'bulbColor',
};

/**
 * @param {string} relativeSamplePath e.g. 'diagram7.json'
 * @returns {{modules: object[], wires: object[]}}
 */
function loadOepSampleAsV2(relativeSamplePath) {
  const samplePath = path.join(ROOT, '..', '..', '..', 'platform', 'oep_studio', 'samples', relativeSamplePath);
  const doc = JSON.parse(fs.readFileSync(samplePath, 'utf8'));
  const idMap = new Map();
  const modules = doc.graph.nodes.map(node => {
    const md = node.metadata || {};
    const realId = md.v2ModuleId || node.id;
    idMap.set(node.id, realId);
    const m = { id: realId, label: node.displayName };
    Object.keys(md).forEach(key => {
      if (key === 'v2Kind') { m[md[key]] = true; return; }
      if (key === 'v2ModuleId') return;
      m[FIELD_MAP[key] || key] = md[key];
    });
    return m;
  });
  const wires = doc.graph.relationships.map(rel => {
    const md = rel.metadata || {};
    return {
      id: md.v2WireId || rel.id,
      from: { m: idMap.get(rel.sourceNode) || rel.sourceNode, t: md.sourcePort },
      to: { m: idMap.get(rel.targetNode) || rel.targetNode, t: md.targetPort },
      c: md.wireColor,
      lbl: md.label,
    };
  });
  return { modules, wires };
}

module.exports = {
  loadSolverContext, baseConditions, setActiveGraph, buildAndSolve,
  loadOepSampleAsV2, ROOT,
};
