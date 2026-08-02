# OEP Digital Multimeter Diagram Studio Integration Specification

**Document ID:** OIP-DMM-029
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines how the OEP Digital Multimeter integrates with Diagram Studio.

The Digital Multimeter shall function as an interactive engineering instrument capable of attaching probes directly to engineering objects within a diagram. Measurements shall be obtained from the active Engineering Session through the Simulation Engine or connected hardware, never from the diagram itself.

---

# 2. Scope

This specification applies to:

- Diagram Studio
- Engineering Sessions
- Simulation Engine
- Publishing
- Measurement History
- Future Hardware-in-the-Loop

---

# 3. Objectives

The integration shall:

- Allow direct probe placement on engineering objects.
- Preserve engineering traceability.
- Maintain deterministic measurements.
- Support edit and read-only workflows.
- Synchronize with the active Engineering Session.

---

# 4. Architectural Responsibilities

Diagram Studio is responsible for:

- Rendering engineering objects
- User interaction
- Selection
- Highlighting
- Visual overlays

The DMM is responsible for:

- Probe management
- Measurement requests
- Display
- Recording
- Operator interaction

The Simulation Engine or physical hardware is responsible for producing engineering values.

---

# 5. Probe Placement

Virtual probes may attach to:

- Wires
- Connector bodies
- Connector pins
- Components
- Ground symbols
- Power rails
- Junctions
- Test points
- Harness branches

Probe attachment shall reference immutable Engineering Object identifiers.

---

# 6. Visual Feedback

Diagram Studio shall provide visual feedback for:

- Probe locations
- Active measurement path
- Selected engineering object
- Voltage source
- Ground reference
- Active simulation path

Visual overlays shall never modify engineering data.

---

# 7. Read-Only Sessions

In read-only mode:

- Probe placement is permitted.
- Measurements are permitted.
- Recording is permitted.
- Engineering objects shall not be modified.

The DMM remains fully functional.

---

# 8. Edit Sessions

In edit mode:

- Measurements continue uninterrupted.
- Probe locations update when engineering objects move.
- Deleted engineering objects invalidate attached probes.

The user shall be notified before invalid probe references are removed.

---

# 9. Cross Highlighting

Selecting an engineering object may optionally highlight:

- Connected wires
- Connected pins
- Related connectors
- Active current path
- Voltage path

Cross-highlighting shall remain synchronized with the Simulation Engine.

---

# 10. Recording & Publishing

Measurements originating within Diagram Studio shall preserve:

- Engineering Session identifier
- Engineering Object references
- Probe locations
- Simulation state
- Measurement metadata

Publishing shall retain all engineering relationships.

---

# 11. Acceptance Criteria

- Probe placement is deterministic.
- Engineering objects remain immutable references.
- Read-only sessions preserve measurement capability.
- Edit sessions preserve probe integrity where possible.
- Diagram overlays never alter engineering truth.
- Platform-independent behavior.

---

End of Document
