# OEP Digital Multimeter Capacitance Measurement Specification

**Document ID:** OIP-DMM-014
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Capacitance Measurement operating mode for the OEP Digital Multimeter.

Capacitance mode measures the electrical capacitance of components while providing deterministic behavior across simulation, Engineering Sessions, and future dedicated hardware.

---

# 2. Objectives

The Capacitance mode shall:

- Measure capacitance from pF through mF ranges.
- Detect charged capacitors before measurement.
- Support Auto and Manual Range.
- Integrate with Engineering Sessions.
- Support recording, playback, and publishing.

---

# 3. Operating Workflow

1. User selects Capacitance mode.
2. Runtime validates probe configuration.
3. Host verifies measurement capability.
4. Capacitor charge state is evaluated.
5. Measurement begins.
6. Results are displayed and optionally recorded.

---

# 4. Probe Configuration

Required:

Black Probe → COM

Red Probe → V/Ω/Hz

Invalid probe assignments shall prevent measurement.

---

# 5. Display

The display shall present:

- Capacitance Value
- Engineering Prefix (pF, nF, µF, mF)
- AUTO/MAN Indicator
- Session Status
- Recording Status
- Host Connection Status

---

# 6. Charged Capacitor Detection

Before measuring, the Host shall determine whether excessive residual voltage exists.

If a capacitor exceeds the allowable measurement threshold:

- Abort measurement.
- Display a warning.
- Preserve instrument stability.

Future physical hardware may require manual discharge before continuing.

---

# 7. Auto Range

Auto Range shall:

- Select the most appropriate capacitance range.
- Minimize unnecessary range switching.
- Maintain display stability.

---

# 8. Manual Range

Manual Range shall:

- Lock the active range.
- Ignore automatic adjustments.
- Display the MAN annunciator.

---

# 9. Measurement States

Supported states:

- Initializing
- Measuring
- Stable
- Charging
- Discharging
- Over Range
- Hold
- Relative
- Recording
- Playback
- Error

Only one primary state may be active.

---

# 10. Integration

Capacitance Measurement integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

Every measurement remains traceable to its originating Engineering Session.

---

# 11. Error Conditions

Examples:

- Charged Capacitor
- Probe Missing
- Invalid Input Jack
- Host Disconnected
- Measurement Unavailable

Errors shall never leave the instrument in an undefined state.

---

# 12. Acceptance Criteria

- Correct probe validation.
- Charged-capacitor detection prior to measurement.
- Deterministic measurements.
- Stable ranging behavior.
- Complete Engineering Session integration.
- Compatible with future hardware.

---

End of Document
