# OEP Digital Multimeter Relative (REL/Δ) Measurement Mode Specification

**Document ID:** OIP-DMM-017
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Relative (REL/Δ) Measurement Mode for the OEP Digital Multimeter.

Relative mode allows an engineer to establish a reference measurement and display subsequent measurements as the mathematical difference between the current measurement and the stored reference value.

---

# 2. Objectives

Relative mode shall:

- Support every compatible measurement mode.
- Preserve the original engineering measurement.
- Display relative values without modifying recorded source measurements.
- Integrate with Engineering Sessions.
- Support recording, playback, and publishing.

---

# 3. Supported Modes

Relative mode may be used with:

- DC Voltage
- AC Voltage
- Resistance
- Current
- Capacitance
- Frequency
- Temperature

Modes that do not support REL shall disable the control.

---

# 4. Operating Workflow

1. User selects a compatible measurement mode.
2. Stable measurement is acquired.
3. User presses REL.
4. Current value becomes the reference.
5. Display changes to Δ mode.
6. Subsequent measurements display the difference from the stored reference.

---

# 5. Reference Value

The stored reference shall include:

- Measurement value
- Engineering units
- Measurement mode
- Timestamp
- Session identifier

Changing measurement modes clears the reference unless explicitly configured otherwise.

---

# 6. Display

The display shall show:

- Relative value
- Δ or REL annunciator
- Engineering units
- Original measurement mode
- Session status
- Recording status

The REL indicator remains visible while the mode is active.

---

# 7. Recording

When recording is enabled, each record shall contain:

- Original engineering value
- Reference value
- Relative value
- Timestamp
- Session reference

This preserves complete engineering traceability.

---

# 8. Playback

Playback shall reproduce:

- Reference capture
- Relative calculations
- Display behavior
- User actions

Playback shall not recalculate historical values.

---

# 9. Measurement States

Supported states:

- Inactive
- Reference Capture
- Relative Active
- Hold
- Recording
- Playback
- Error

Only one primary state may be active.

---

# 10. Integration

Relative mode integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

---

# 11. Error Conditions

Examples:

- Unsupported measurement mode
- Invalid reference
- Session unavailable
- Host disconnected
- Measurement unavailable

Errors shall automatically exit Relative mode or prevent activation while preserving instrument stability.

---

# 12. Acceptance Criteria

- Deterministic reference capture.
- Correct Δ calculations.
- Original engineering values remain preserved.
- Complete Engineering Session integration.
- Recording and playback support.
- Platform-independent behavior.

---

End of Document
