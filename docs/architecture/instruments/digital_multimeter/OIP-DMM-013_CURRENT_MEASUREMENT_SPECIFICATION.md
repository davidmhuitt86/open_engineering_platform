# OEP Digital Multimeter Current Measurement Specification

**Document ID:** OIP-DMM-013
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Current Measurement operating mode for the OEP Digital Multimeter.

Current mode measures electrical current flowing through a circuit while maintaining deterministic behavior across simulation, Engineering Sessions, and future physical hardware.

---

# 2. Objectives

The Current Measurement mode shall:

- Support DC and AC current.
- Validate probe jack assignments.
- Support Auto and Manual Range.
- Detect overload conditions.
- Integrate with Engineering Sessions.
- Support recording and playback.

---

# 3. Operating Workflow

1. User selects Current mode.
2. Runtime validates probe placement.
3. Runtime validates input jack.
4. Host enables current measurement.
5. Measurements stream to the display.
6. History records measurements when enabled.

---

# 4. Probe Configuration

Required:

Black Probe → COM

Red Probe →

• mA/µA Input

or

• 10A Input

The selected input determines the available measurement range.

---

# 5. Jack Validation

Before measurement begins the Runtime shall verify:

- Correct input jack
- Selected measurement range
- Host capability
- Session availability

Invalid configurations shall generate a warning before any measurement request.

---

# 6. Display

The display shall present:

- Measured Current
- Engineering Prefix
- Unit (A, mA, µA)
- AUTO/MAN Indicator
- Session Status
- Recording Status
- Host Connection

---

# 7. Auto Range

Auto Range shall:

- Select the smallest valid current range.
- Minimize unnecessary range switching.
- Preserve display stability.

---

# 8. Manual Range

Manual Range shall:

- Lock the active range.
- Ignore automatic range changes.
- Display the MAN annunciator.

---

# 9. Overload Protection

If the requested current exceeds the selected input range:

- Stop the measurement.
- Display an overload indication.
- Preserve instrument stability.
- Record the event when appropriate.

Future physical hardware may additionally trigger fuse or hardware protection.

---

# 10. Measurement States

Supported states:

- Initializing
- Measuring
- Stable
- Overload
- Under Range
- Hold
- Relative
- Recording
- Playback
- Error

Only one primary state may be active.

---

# 11. Integration

Current Measurement integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

---

# 12. Acceptance Criteria

- Correct jack validation.
- Deterministic measurements.
- Stable ranging.
- Reliable overload detection.
- Complete Engineering Session integration.
- Compatible with future hardware.

---

End of Document
