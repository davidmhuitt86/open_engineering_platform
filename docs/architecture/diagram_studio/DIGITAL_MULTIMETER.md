# Digital Multimeter

**Work Package:** WP-DS-005A. The first Engineering Instrument — see
`ENGINEERING_INSTRUMENTS.md` for the framework it plugs into and
`MEASUREMENT_SYSTEM.md` for Probes/Modes/History/Bookmarks.

## Location

`lib/diagram_studio/instruments/multimeter/`:
`multimeter_controller.dart` (state + orchestration, no engineering
math), `digital_multimeter_panel.dart` (UI + the `EngineeringInstrument`
wrapper `DigitalMultimeterInstrument`).

## Supported measurement types

Every `MeasurementType` (`oep_engine`,
`lib/core/simulation/measurement/measurement_types.dart`) is wired to
`SimulationEngine.measure`:

* Voltage DC, Voltage AC
* Resistance
* Continuity
* Current
* Diode
* Frequency
* Duty Cycle
* Power
* Ground Potential

`capacitance` and `temperature` are the engine's own named future
placeholders — present in the type dropdown, rendered disabled with a
"(not yet supported)" suffix, and rejected by
`MultimeterController.measure()` (sets `lastError`, never calls the
engine) if somehow reached without going through the dropdown's
`enabled: false` state.

## Reading a value

1. Place both probes (see `MEASUREMENT_SYSTEM.md` § Probe System).
2. Choose a measurement type and mode.
3. Press **Measure** (or, in Live Simulation mode, **Start live**).

`MultimeterController.measure()` is fully async — it calls
`DiagramSimulationService.measure(...)`, awaits the `Future`, and only
then updates `latestResult`. `busy` is `true` for the duration, so the
UI can (and does) disable the Measure button and show "Measuring…"
rather than double-firing a request.

## Result readout

Every field the governing spec lists is displayed, sourced directly
from `MeasurementResult` (`oep_engine`) with no Studio-side
recomputation:

* Measured value / unit
* Expected value
* Difference (`MeasurementResult.difference` — a getter on the result
  itself: `measuredValue - expectedValue`, `null` if either is missing)
* Engineering path (probe A → probe B, shortest path found)
* Power source / Ground source
* Contributing relationships
* Timestamp
* Mode
* Reachability (`reachable: false` for an open circuit — not an error,
  a real answer)
* Continuity (`continuous: true/false`, only for continuity/diode)
* Notes — a disclosure string the engine attaches to non-continuity
  types explaining the "authored expected value, gated by logical
  reachability, not a computed analog reading" scope boundary (see
  `MeasurementEngine`'s own doc comment in `oep_engine` for the full
  rationale)

## Engineering Integration (light touch)

`DigitalMultimeterInstrument` accepts an optional
`verificationReport: () => VerificationReport?` callback — wired by
`DiagramStudioPage` to its own last `DiagramSimulationService.verify()`
result. `MultimeterController.relatedFindings(report)` filters that
report to findings whose `nodeId` lies on the current result's
engineering path (or is either probe's node), and the panel lists them
under "Related verification findings." This is read-only: no new
verification pass is triggered by the Multimeter, and no finding is
ever fabricated locally.

## Deferred

* Diagnostics/Reasoning/Recommendations/Publishing/Reports integration
  beyond the Verification-findings slice above were not built.
* No settings panel (e.g. default unit preferences, decimal precision)
  exists yet.
* Capacitance/Temperature will need `MeasurementEngine` support before
  this panel's dropdown can enable them — no client-side workaround was
  attempted (that would violate "Diagram Studio shall never compute
  engineering measurements").
