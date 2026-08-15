# OEP Digital Multimeter MIN/MAX & Peak Capture Specification

**Document ID:** OIP-DMM-019
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the MIN/MAX and Peak Capture operating modes for the OEP Digital Multimeter.

These modes allow engineers to monitor changing measurements, identify extreme values, and capture transient events while preserving complete engineering traceability.

---

# 2. Objectives

The MIN/MAX subsystem shall:

- Continuously monitor live measurements.
- Capture minimum and maximum values.
- Support future peak capture capability.
- Operate across all compatible measurement modes.
- Integrate with Engineering Sessions, recording, and playback.

---

# 3. Supported Measurement Modes

MIN/MAX supports:

- DC Voltage
- AC Voltage
- Current
- Resistance
- Capacitance
- Frequency
- Temperature

Future measurement modes shall explicitly declare compatibility.

---

# 4. Operating Workflow

1. User selects a supported measurement mode.
2. User enables MIN/MAX.
3. Current measurement initializes both minimum and maximum values.
4. Incoming measurements are continuously evaluated.
5. Display updates according to the selected view.
6. User exits MIN/MAX or resets captured values.

---

# 5. Minimum Capture

The system shall retain the smallest valid engineering measurement received during the active session.

Minimum values remain unchanged until:

- A lower value is observed.
- The user performs a reset.
- The Engineering Session ends.

---

# 6. Maximum Capture

The system shall retain the largest valid engineering measurement received during the active session.

Maximum values remain unchanged until:

- A higher value is observed.
- The user performs a reset.
- The Engineering Session ends.

---

# 7. Peak Capture (Future)

The architecture reserves support for Peak Capture.

Peak Capture shall:

- Detect fast transient events.
- Capture positive and negative peaks independently.
- Record timestamps for every captured event.
- Integrate with waveform-capable instruments where appropriate.

---

# 8. Display Behavior

Display shall provide:

- Live Measurement
- Minimum Value
- Maximum Value
- Peak Value (Future)
- Active Indicator
- Engineering Units
- Session Status
- Recording Status

Users may cycle between views without resetting stored values.

---

# 9. Recording

When recording is enabled:

- Every minimum update is recorded.
- Every maximum update is recorded.
- Peak events (future) are recorded.
- Reset operations are recorded.
- Measurements remain associated with their Engineering Session.

---

# 10. Playback

Playback shall reproduce:

- MIN updates
- MAX updates
- Reset operations
- Display transitions
- Peak events (future)

Playback shall preserve original event order.

---

# 11. Measurement States

Supported states:

- Inactive
- Initializing
- Tracking
- Minimum Updated
- Maximum Updated
- Peak Detected (Future)
- Reset
- Playback
- Error

Only one primary state shall exist at a time.

---

# 12. Integration

MIN/MAX integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

All captured values remain fully traceable.

---

# 13. Error Conditions

Examples:

- Measurement unavailable
- Host disconnected
- Session terminated
- Unsupported measurement mode

Errors shall preserve previously captured values whenever possible.

---

# 14. Acceptance Criteria

- Deterministic minimum tracking.
- Deterministic maximum tracking.
- Reset behavior is predictable.
- Recording preserves all captured events.
- Playback reproduces captured values accurately.
- Platform-independent behavior.

---

End of Document
