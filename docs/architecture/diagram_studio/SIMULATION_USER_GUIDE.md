# Simulation User Guide

**Architecture Phase:** AP-DS-005. A user-facing walkthrough of Diagram Studio's Engineering Verification & Simulation subsystem. For the underlying architecture, see `SIMULATION_ARCHITECTURE.md`, `SIGNAL_PROPAGATION.md`, `VERIFICATION_ENGINE.md`, `FAULT_INJECTION.md`.

## Opening the Simulation Center

From the diagram toolbar, click the Simulation icon to open the Simulation Center dialog (following the same pattern as the Publishing Center from AP-DS-004). This is the single entry point for everything below — sessions, playback, fault injection, and diagnostics all live inside it, so the rest of the canvas and toolbar are unaffected.

## Sessions

A simulation session captures one scenario: a starting graph, a history of actions taken (faults injected/cleared, steps advanced), and the resulting computed state at any point in that history.

- **Create** a new session from the current diagram to start exploring "what if" scenarios without affecting the design itself.
- **Save/Export** a session to preserve its fault history and bookmarks.
- **Resume** (import) a previously exported session against the current diagram.
- **Duplicate** a session to branch a scenario — e.g. compare "what if the relay fails" against a clean baseline without losing either.
- **Compare** two sessions to see exactly which nodes differ in powered/grounded/functional status between them.
- **Delete** a session when you're done with it.

## Understanding the overlay

With a session active, the canvas shows a simulation overlay on top of the normal diagram:

- **Powered / unpowered** nodes are colored distinctly.
- **Grounded** state is shown separately from powered state — a node can be one without the other, which is itself informative (see Continuity below).
- **Active faults** are marked with a warning treatment at their target node or wire.
- **Propagation paths** — select a node and request its Propagation Report to see exactly which path power or ground took to reach it, highlighted on the canvas.

None of this is computed by Diagram Studio — every color and highlight reflects a fact the Simulation Engine already computed. The overlay never lies ahead of what the engine has told it.

## Injecting a fault

1. Select a target on the canvas — a component (node) or a wire (relationship).
2. Choose a fault type: Open Circuit, Short Circuit, Disconnected Connector, Broken Wire, Incorrect Wire, Missing Ground, Missing Power, Relay Failure, Fuse Failure, or Connector Failure.
3. Inject it. The overlay updates immediately to show what the fault now blocks.
4. Clear an individual fault, or use Restore Normal to clear every active fault in the session at once.

Faults never modify your actual diagram — they are session-scoped conditions. Deleting the session or clearing faults always returns you to the diagram's true, unmodified state.

## Playback

Every fault injection or clear is recorded as an event in the session's timeline, so you can:

- **Step** forward one event at a time to watch a scenario unfold.
- **Play** to auto-advance through the timeline at a chosen speed; **Pause**/**Resume** to control it.
- **Reset** to jump back to the very start (no faults, no events applied) without losing the recorded timeline.
- **Bookmark** a position with a name, and **jump to** or **replay from** it later.
- Scrub the **Timeline** directly to any recorded position.

Because propagation is fully deterministic, replaying the same session from the same starting point always reproduces the exact same result — useful for demonstrating a fault scenario reliably.

## Diagnostics

With a session active, request any of the following reports:

- **Verification Report** — design-correctness findings (connectivity, continuity, ground, power, relationship, dependency, package, harness, connector), each marked info/warning/error.
- **Fault Report** — every active fault and what it's currently blocking downstream.
- **Propagation Report** — for a chosen node, the actual path power or ground took to reach it (or confirmation it's unreachable).
- **Power Report / Ground Report** — every node's powered/grounded status, and which nodes were expected to be reachable but aren't.
- **Simulation Report** — a one-page summary: fault count, verification pass/fail, functional node count.

Reports state facts, not recommendations. If you want a ranked explanation of *why* something is failing or a suggested fix, use the diagram's Intelligence panel (Engineering Intelligence Platform) — that reasoning is deliberately kept separate from the Simulation Engine's factual reports.

## Engineering Instruments (WP-DS-005A)

The Instrument Dock is a permanent panel — open it from the toolbar's
instrument icon or `Ctrl+M`, or float/dock/auto-hide it from its own tab
bar controls. It stays available in every mode (editing, verification,
simulation, inspection), independent of the Simulation Center dialog
above.

The first instrument is the **Digital Multimeter**. See
`DIGITAL_MULTIMETER.md` for a full walkthrough and
`MEASUREMENT_SYSTEM.md` for how Modes/History/Bookmarks work; in short:

1. Arm Probe A (black) or Probe B (red) from the toolbar, then click a
   node on the canvas to place it (or drag a placed probe marker to
   re-snap it to the nearest node).
2. Pick a measurement type and mode in the Multimeter panel, then
   Measure.
3. For Continuity, the measured path is automatically highlighted on
   the canvas — reusing the exact same path-highlight rendering the
   Propagation Report overlay above already uses.

Every reading comes from the same Simulation Engine this guide already
describes — the Multimeter never computes a value itself, and every
"disclosed scope" limitation above (logical, not SPICE-style, values)
applies identically to its readings.

## What simulation does not do

This is a logical, deterministic simulator — it answers "is this node reachable from power/ground given current faults," not "what voltage is present" or "how much current flows" in an analog/SPICE sense. The Digital Multimeter's non-continuity readings (voltage/current/power/frequency/etc.) reflect the diagram's own *authored* expected value, gated by this logical reachability — not a computed analog reading; each such result is marked with a disclosure note saying so. If your question requires real circuit-level analog computation, this tool is not the right one.
