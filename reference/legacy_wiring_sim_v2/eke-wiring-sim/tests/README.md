# tests/

PRODUCT-READINESS-002 Phase 1/2 — automated regression coverage for the
live electrical solver (`js/graph/`, `js/knowledge/behaviors/`,
`js/simulation/`). Before this, the solver had zero automated tests
despite three days of real bug fixes (battery pin isolation, connector/
splice pin gating, multi-switch continuity, lamp/starter dead-ends, the
multi-entry BFS fix) — those fixes were verified by hand, interactively,
each time.

## Running

```bash
node --test
# or
npm test
```

No dependencies, no framework — this uses Node's own built-in test
runner (`node:test`, stable since Node 18) plus a small `vm`-based
harness (`harness.js`) that loads the SAME solver files, in the SAME
order `index.html`'s own `<script>` tags use, into one sandboxed
context — functionally identical to a browser loading them, without
needing a browser.

## Files

- `harness.js` — `loadSolverContext()` (fresh sandbox with GraphBuilder/
  VoltagePropagator/GroundPropagator/ElectricalSolver/LiveSim/etc.
  loaded), `buildAndSolve()` (one-call circuit setup), and
  `loadOepSampleAsV2()` (converts a real `platform/oep_studio/samples/
  *.json` OEP document into V2's own MODULES/WIRES shape, using the
  same v2ModuleId-based identity mapping Diagram Studio's own bridge
  uses — verified against the "wrong id" bug this exact conversion hit
  earlier this session).
- `solver-invariants.test.js` — unit-level regression tests, one group
  per load-bearing invariant fixed over the last 3 days: battery
  isolation, unmodeled-component pin gating, multi-entry BFS, generic
  multi-position switch continuity, lamp/starter-motor dead-ends,
  connector same-pin isolation, splice bridging, and open/OL vs. a
  genuine 0.00V never being collapsed together. Each uses a small,
  synthetic, deliberately non-TRX300 circuit, to prove the SOLVER itself
  is generic — not dependent on the sample vehicle data.
- `trx300-fixture.test.js` — integration-level regression against the
  user's real, independently-authored TRX300 diagram (`diagram7.json`).
  Not a snapshot test (module ids in that file are timestamp-suffixed
  and not stable across edits — every lookup goes by the module's own
  `label`); proves real electrical behavior (the lights switch actually
  lights the headlights/taillight, the dimmer actually gates HI vs LO,
  key-off actually kills everything) and exercises
  `LiveSim.readWireMeasurement()` — the exact function the Dart-side DMM
  bridge calls — against real vehicle wiring.

## Historical note

An earlier version of this file listed *planned* Phase 2/3 unit tests
for `models/vehicle.js`, `utils/geometry.js`, `simulator/meter-engine.js`,
etc. — none of those were ever written, and `js/simulator/*` (including
`meter-engine.js`) turned out to be dead code, superseded by `js/
simulation/*` and never loaded by `index.html` at all (confirmed during
PRODUCT-READINESS-002). This file now documents what actually exists.
