# OEP Digital Multimeter Simulation Engine Integration Specification

**Document ID:** OIP-DMM-028
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines how the OEP Digital Multimeter integrates with the OEP Simulation Engine.

The Digital Multimeter shall behave as a first-class engineering instrument capable of measuring live simulated circuits exactly as it would interact with future physical hardware. Simulation shall expose engineering truth through the same measurement interface used by the Measurement Engine.

---

# 2. Scope

This specification applies to:

- Diagram Studio
- Simulation Engine
- Engineering Sessions
- Playback
- Recording
- Publishing
- Future Hardware-in-the-Loop (HIL)

---

# 3. Design Objectives

The integration shall:

- Present simulation measurements identically to live hardware measurements.
- Preserve deterministic behavior.
- Support paused, running, stepped, and replayed simulations.
- Maintain engineering traceability.
- Require no DMM architecture changes when new simulation capabilities are added.

---

# 4. Architectural Relationship

The DMM shall never solve circuit behavior.

Responsibilities:

Simulation Engine:
- Circuit state
- Signal propagation
- Voltage/current computation
- Fault modeling
- Time progression

Measurement Engine:
- Probe validation
- Measurement requests
- Formatting
- Display
- Recording
- Operator interaction

---

# 5. Measurement Workflow

1. Engineer places probes.
2. Probe locations resolve to Engineering Objects.
3. Measurement request is sent to the Simulation Engine.
4. Simulation Engine evaluates circuit state.
5. Engineering value is returned.
6. Measurement Engine validates the result.
7. Display updates.
8. Measurement is optionally recorded.

---

# 6. Probe Interaction

Virtual probes may attach to:

- Wires
- Connector pins
- Components
- Ground nodes
- Power rails
- Test points
- Harness branches

Probe attachment shall use immutable Engineering Object identifiers.

---

# 7. Simulation States

The DMM shall recognize:

- Stopped
- Initializing
- Running
- Paused
- Single Step
- Fast Forward
- Replay
- Fault Injection

Displayed measurements shall always correspond to the active simulation state.

---

# 8. Time Synchronization

Every displayed measurement shall be associated with:

- Simulation Time
- Session Time
- Recording Timestamp

During playback, historical timestamps shall be reproduced exactly.

---

# 9. Fault Injection

When simulation faults are introduced:

- Measurements shall immediately reflect the altered circuit.
- Existing recordings remain unchanged.
- Fault metadata shall be available for recording and publishing.

The DMM shall never fabricate measurements to hide simulated failures.

---

# 10. Recording

When recording is enabled:

- Measurements
- Probe locations
- Simulation time
- Simulation state
- Fault state
- Operator actions

shall all be recorded.

---

# 11. Publishing

Published measurement packages shall preserve:

- Engineering Session references
- Simulation references
- Engineering Object references
- Probe metadata
- Measurement metadata

Publishing shall never modify simulation history.

---

# 12. Acceptance Criteria

- Measurements accurately reflect simulation state.
- Probe attachment is deterministic.
- Simulation timing remains synchronized.
- Recording preserves simulation context.
- Publishing maintains engineering traceability.
- Future simulation capabilities integrate without redesign.

---

End of Document
