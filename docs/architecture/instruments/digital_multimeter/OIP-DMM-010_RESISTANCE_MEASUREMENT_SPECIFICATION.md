# OEP Digital Multimeter Resistance Measurement Specification

**Document ID:** OIP-DMM-010
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Resistance (Ω) measurement mode for the OEP Digital Multimeter.

It establishes the engineering behavior for measuring resistance across simulated circuits, engineering models, and future physical hardware.

---

# 2. Scope

Applies to all OEP Instrument clients:

- Android
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware

---

# 3. Design Objectives

The resistance mode shall:

- Measure resistance deterministically.
- Detect open circuits.
- Detect short circuits.
- Support auto and manual ranging.
- Integrate with Engineering Sessions.

---

# 4. Operating Workflow

1. User selects Resistance mode.
2. Probe configuration is validated.
3. Host enters resistance measurement mode.
4. Measurement stream begins.
5. Display updates.
6. History records measurements if enabled.

---

# 5. Probe Configuration

Required:

Black Probe → COM

Red Probe → V/Ω/Hz

Measurements shall not begin if probes are incorrectly assigned.

---

# 6. Display

The display shall show:

- Resistance Value
- Engineering Prefix (Ω, kΩ, MΩ)
- AUTO/MAN Indicator
- Hold Status
- Relative Status
- Session Status
- Recording Status

---

# 7. Auto Range

Auto range shall:

- Select the most appropriate resistance range.
- Prevent unnecessary range changes.
- Maintain display stability.

---

# 8. Manual Range

Manual range shall:

- Lock the active range.
- Ignore automatic range changes.
- Display the MAN annunciator.

---

# 9. Measurement States

Supported states:

- Initializing
- Measuring
- Stable
- Open Circuit
- Short Circuit
- Over Range
- Hold
- Relative
- Recording
- Playback
- Error

---

# 10. Open Circuit

When resistance exceeds the measurable range, the instrument shall display the configured over-range indication.

Open-circuit conditions shall never be interpreted as valid resistance values.

---

# 11. Short Circuit

Near-zero resistance shall be reported accurately.

This state shall remain distinct from Continuity Mode.

---

# 12. Integration

Resistance measurements integrate with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

---

# 13. Acceptance Criteria

- Correct probe validation.
- Deterministic measurements.
- Proper open/short detection.
- Stable ranging behavior.
- Complete Engineering Session integration.

---

End of Document
