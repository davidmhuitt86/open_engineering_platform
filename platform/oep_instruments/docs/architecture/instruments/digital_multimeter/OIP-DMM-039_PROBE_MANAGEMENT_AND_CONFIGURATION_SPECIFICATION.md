# OEP Digital Multimeter Probe Management & Configuration Specification

**Document ID:** OIP-DMM-039
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines how probes are managed, configured, assigned, and persisted within the OEP Digital Multimeter.

The Probe Management subsystem is responsible for maintaining probe identity, configuration, assignment, and lifecycle without modifying engineering measurements.

---

# 2. Scope

This specification applies to:

- Virtual Probes
- Future Physical Probes
- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Recording & Playback
- Publishing

---

# 3. Design Objectives

The subsystem shall:

- Maintain deterministic probe assignments.
- Support multiple probe types.
- Preserve probe identity across a session.
- Persist user preferences where appropriate.
- Remain extensible.

---

# 4. Probe Registry

The Probe Manager shall maintain a registry of available probes.

Each registry entry includes:

- Probe Identifier
- Probe Type
- Display Name
- Capability Profile
- Current State
- Current Assignment

Only registered probes may participate in measurements.

---

# 5. Probe Assignment

The subsystem shall support:

- Automatic assignment
- Manual assignment
- Reassignment
- Probe release
- Probe replacement

Assignments shall be validated before becoming active.

---

# 6. Active Probe Selection

Only one probe of a given logical role may be active at a time unless a measurement mode explicitly supports multiple probes.

Supported logical roles include:

- Common
- Positive
- Current
- Temperature
- Auxiliary (Future)

---

# 7. Configuration

Each probe may define:

- Display name
- Default color
- Preferred measurement modes
- Calibration reference
- User notes
- Capability flags

Configuration changes shall never alter historical recordings.

---

# 8. Persistence

The following may persist between sessions:

- Preferred probe names
- Display colors
- Default assignments
- User preferences

Engineering Session attachments shall not persist unless explicitly restored.

---

# 9. Conflict Resolution

The Probe Manager shall detect:

- Duplicate assignments
- Incompatible probe types
- Unsupported measurement modes
- Missing probes

Conflicts shall be reported before measurements begin.

---

# 10. Synchronization

Probe configuration shall synchronize with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Recording
- Playback

Synchronization shall preserve probe identity.

---

# 11. Future Hardware

Future smart probes may expose:

- Serial Number
- Firmware Version
- Calibration Date
- Battery Status
- Diagnostic Information

The logical management model shall remain unchanged.

---

# 12. Acceptance Criteria

- Probe assignments are deterministic.
- Configuration is persisted correctly.
- Conflicts are detected before measurement.
- Probe identity remains stable.
- Platform-independent behavior.
- Future probe types require no redesign.

---

End of Document
