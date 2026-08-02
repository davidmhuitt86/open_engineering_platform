# OEP Digital Multimeter Diode Test Specification

**Document ID:** OIP-DMM-012
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Diode Test operating mode for the OEP Digital Multimeter.

Diode Test mode measures the forward voltage drop of semiconductor junctions and assists engineers in evaluating the condition and orientation of diodes and similar devices.

---

# 2. Objectives

The Diode Test mode shall:

- Measure forward voltage drop.
- Detect reverse-bias conditions.
- Identify open circuits.
- Identify short circuits.
- Operate identically on simulated and future physical hardware.
- Integrate with Engineering Sessions.

---

# 3. Operating Workflow

1. User selects Diode Test.
2. Probe configuration is validated.
3. Host enables diode test mode.
4. Test stimulus is applied by the measurement engine.
5. Forward voltage is measured.
6. Results are displayed and optionally recorded.

---

# 4. Probe Configuration

Required:

- Black Probe → COM
- Red Probe → V/Ω/Hz

Invalid probe assignments shall prevent testing.

---

# 5. Display

The display shall present:

- Forward Voltage
- Unit (V)
- Diode Mode Indicator
- Session Status
- Recording Status
- Host Connection Status

---

# 6. Forward Bias

When the device under test is forward biased:

- Measure forward voltage drop.
- Display the measured value.
- Record the measurement when recording is enabled.

---

# 7. Reverse Bias

When reverse biased:

- Indicate open or over-range according to instrument settings.
- Do not report a valid forward voltage.

---

# 8. Fault Conditions

Examples include:

- Shorted Diode
- Open Diode
- Invalid Probe Configuration
- Host Disconnected
- Measurement Unavailable

Fault conditions shall never leave the instrument in an undefined state.

---

# 9. Measurement States

Supported states:

- Initializing
- Measuring
- Forward Bias
- Reverse Bias
- Open Circuit
- Short Circuit
- Recording
- Playback
- Error

Only one primary state shall be active.

---

# 10. Integration

Diode Test integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

Every result is traceable to its originating Session.

---

# 11. Acceptance Criteria

- Correct probe validation.
- Deterministic forward voltage measurement.
- Reliable reverse-bias detection.
- Proper open/short indication.
- Recording and playback support.
- Platform-independent behavior.

---

End of Document
