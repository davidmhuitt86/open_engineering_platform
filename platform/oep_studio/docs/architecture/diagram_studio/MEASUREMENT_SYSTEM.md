# Measurement System

**Work Package:** WP-DS-005A. Covers the Probe System, Measurement
Modes, Measurement History, and Measurement Bookmarks — the plumbing
shared by every current and future Engineering Instrument that takes a
reading between two points. See `DIGITAL_MULTIMETER.md` for how the
first instrument consumes all of this.

## Probe System

`lib/diagram_studio/instruments/probe/probe_overlay.dart`.

Two independent probes: Probe A (black), Probe B (red). Each is a
`ProbePoint` (`oep_engine`) — a node id, optional port id, optional
relationship id (for a wire-segment anchor).

* **Click-to-place**: arm a probe from the toolbar (Probe A/Probe B
  buttons), then tap a node on the canvas. This reuses
  `DiagramStudioPage._handleNodeTap` — the exact same handler every
  other node-tap interaction (selection) already goes through — rather
  than a second hit-tester. When a probe is armed, a node tap places
  the probe and disarms instead of changing selection.
* **Drag**: an already-placed probe marker can be dragged; `ProbeOverlay`
  re-snaps it, on every drag update, to the nearest node in
  `DiagramLayoutState.positions` — the same position map
  `SimulationStateOverlay`/`DiagramIntelligenceOverlay` already read for
  their own node-id → screen-position transform (`pan.dx + zoom *
  position.dx`), so there is exactly one node-position source of truth
  across every canvas overlay in this Studio.
* **Snap targets**: resolves to the nearest Engineering Object (node)
  only. The spec's fuller target list (Pins, Connectors, Wire segments,
  Terminals, Measurement points individually) is **not** built — a
  real, working node-level snap rather than a half-built resolver for
  five target kinds. `ProbePoint.portId`/`relationshipId` already exist
  on the model for when finer-grained snapping is built.

## Measurement Modes

`MeasurementMode` (`oep_engine`): `manual`, `liveSimulation`,
`expected`, `comparison`, `historical`.

* **Manual / Expected / Comparison** all funnel through
  `MultimeterController.measure()`, differing only in which
  `MeasurementMode` is passed to `SimulationEngine.measure` and how the
  result is displayed. Comparison mode's "difference" is not a separate
  computation — it is `MeasurementResult.difference`, the same getter
  every mode's result already exposes.
* **Live Simulation**: `MultimeterController.startLive()` starts a
  `Timer.periodic` (default 500ms) that calls `measure()` on every
  tick — fully async, matching the spec's "Instrument updates shall
  remain asynchronous." `stopLive()` cancels it; switching away from
  `liveSimulation` mode stops it automatically. Deferred: Pause/Step/
  Replay/Timeline synchronization for live mode specifically (the
  Simulation Center dialog's own playback controls already cover
  Pause/Step/Replay for the *session*; wiring the Multimeter to follow
  that timeline directly was not built).
* **Historical**: `setHistoricalCompareEntry(entryId)` picks a stored
  `MeasurementHistoryEntry`; `historicalDifference` is a local,
  read-only subtraction of two already-computed values (current vs.
  stored) — no new engine call, matching the spec's "comparing against
  a stored history entry" scoping.

## Continuity Mode + path highlighting

A continuity/diode result's `path` (from probe A to probe B) is
exposed as `MultimeterController.highlightedPathNodeIds` and fed
directly into `SimulationStateOverlay.propagationPathNodeIds` by
`DiagramStudioPage` — the exact same rendering
`SimulationStateOverlay` already uses for a `PropagationReport`'s path,
per that widget's own established "additive overlay, no engineering
logic" pattern. No new path-drawing code was written.

## Measurement History

`lib/diagram_studio/instruments/history/`.

* `MeasurementHistoryEntry` — an id plus a `MeasurementResult`
  (timestamp, probe locations, mode, result, path are all already on
  `MeasurementResult` itself; the entry adds only a stable id for
  addressing).
* `MeasurementHistoryStore` — JSON persistence,
  `measurement_history.json` under `SettingsStorage.root()`, same
  storage shape as `WorkspaceStateStorage` (WORK_PACKAGE_024).
* Every successful `measure()` call prepends a new entry automatically.
* **Replay**: `MultimeterController.replay(entry)` restores the entry's
  result/probes/type as the active state — no new engine call.
* **Clear**: `clearHistory()` empties the list and persists.
* **Export**: `exportHistoryJson()` returns a pretty-printed JSON
  string of the current history; the host page is responsible for
  writing it wherever the user chooses (reusing this Studio's existing
  `file_selector`-based save-file precedent) — this store only produces
  the string.

**Disclosed scope**: history is Studio-wide (one file), not scoped per
diagram document — matching the spec's "maintain a measurement
history" (no per-document scoping stated) and every other settings-file
precedent in this codebase.

## Measurement Bookmarks

`lib/diagram_studio/instruments/bookmarks/`.

* `MeasurementBookmark` — name, group, probe A/B, measurement type.
* `MeasurementBookmarkStore` — JSON persistence,
  `measurement_bookmarks.json`, same shape as the history store.
* `MultimeterController.addBookmark(name, group: ...)` saves the
  current probe placement + type.
* `recallBookmark(bookmark)` — quick recall: restores probe placement +
  type (does not re-measure automatically; press Measure after
  recalling).
* `removeBookmark(id)`.

Grouping is a free-text `group` string (default `"Ungrouped"`) rather
than a separate group-management model — real grouping (filter/display
by group) without building a second taxonomy system.

## Testing

`test/instruments/multimeter_controller_test.dart`,
`measurement_history_store_test.dart`,
`measurement_bookmark_store_test.dart`, and `probe_overlay_test.dart`
exercise all of the above against a real `SimulationEngine` (no mocks)
and real on-disk storage (with cleanup), matching
`diagram_simulation_service_test.dart`'s own established convention.
