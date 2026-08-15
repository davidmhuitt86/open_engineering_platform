# OEP Digital Multimeter DC Voltage Measurement Specification

**Document ID:** OIP-DMM-008
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the functional behavior of the DC Voltage measurement mode for the OEP Digital Multimeter.

The document establishes the engineering rules governing voltage acquisition, presentation, recording, playback, and interaction with the Open Engineering Platform.

---

# 2. Scope

This specification applies to:

- Android Client
- Windows Client
- Linux Client
- Future iOS Client
- Dedicated OEP Handheld Hardware

All implementations shall provide identical engineering behavior.

---

# 3. Design Objectives

The DC Voltage mode shall:

- Emulate premium professional multimeters.
- Produce deterministic results.
- Support simulation and future physical hardware.
- Integrate with Engineering Sessions.
- Support recording and playback.

---

# 4. Operating Workflow

1. User selects DC Voltage.
2. Runtime validates probe configuration.
3. Host activates DC voltage measurement.
4. Measurement stream begins.
5. Display updates.
6. Measurement history records samples if enabled.

---

# 5. Probe Configuration

Required inputs:

Black Probe → COM

Red Probe → V/Ω/Hz Input

Incorrect probe placement shall prevent measurement and notify the user.

---

# 6. Display Behavior

Display includes:

- Measured Voltage
- Sign (+/-)
- Engineering Prefix
- Unit (VDC)
- Range
- Session Status
- Host Status

The primary measurement remains visible at all times.

---

# 7. Auto Range

Auto Range shall:

- Select the smallest valid range.
- Prevent unnecessary range switching.
- Minimize display instability.
- Indicate AUTO on the display.

---

# 8. Manual Range

Manual Range shall:

- Lock the selected range.
- Ignore automatic range changes.
- Display MAN indicator.

---

# 9. Measurement States

Supported states:

- Initializing
- Measuring
- Stable
- Over Range
- Under Range
- Hold
- Relative
- Recording
- Playback
- Error

Only one primary state may be active.

---

# 10. Integration

DC Voltage measurements integrate with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

Every measurement is traceable to its source.

---

# 11. Error Conditions

Examples:

- Probe Missing
- Invalid Jack
- Host Disconnected
- Simulation Stopped
- Measurement Unavailable

Errors shall never leave the instrument in an undefined state.

---

# 12. Acceptance Criteria

- Deterministic measurements.
- Correct probe validation.
- Stable display updates.
- Full Engineering Session integration.
- Recording and playback supported.
- Compatible with future hardware.

---

End of Document
