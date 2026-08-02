# OEP Digital Multimeter AC Voltage & True RMS Measurement Specification

**Document ID:** OIP-DMM-009
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the functional behavior of the AC Voltage measurement mode and True RMS processing for the OEP Digital Multimeter.

The specification establishes a common engineering behavior across all OEP platforms.

---

# 2. Scope

Applies to:

- Android
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware

All platforms shall provide identical engineering behavior.

---

# 3. Design Objectives

The AC Voltage mode shall:

- Measure alternating voltage accurately.
- Support True RMS calculations.
- Operate with simulated and future physical hardware.
- Integrate with Engineering Sessions.
- Support recording and playback.

---

# 4. Operating Workflow

1. User selects AC Voltage.
2. Probe configuration is validated.
3. Host enables AC measurement mode.
4. True RMS processing begins.
5. Measurement stream updates the display.
6. Measurements may be recorded.

---

# 5. Probe Configuration

Required:

Black Probe → COM

Red Probe → V/Ω/Hz

Incorrect configuration prevents measurement.

---

# 6. Display

Display includes:

- RMS Voltage
- Engineering Unit (VAC)
- Engineering Prefix
- Range
- AUTO/MAN Indicator
- Session Status
- Recording Indicator

---

# 7. True RMS

True RMS processing shall:

- Correctly represent non-sinusoidal waveforms.
- Remain deterministic.
- Be identified by a TRMS annunciator.
- Preserve engineering traceability.

---

# 8. Auto Range

Auto Range shall:

- Select the appropriate range.
- Reduce unnecessary range switching.
- Maintain stable display updates.

---

# 9. Manual Range

Manual range shall:

- Lock the current range.
- Ignore automatic adjustments.
- Display MAN indicator.

---

# 10. Measurement States

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

---

# 11. Integration

Integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

---

# 12. Error Conditions

Examples:

- Probe Missing
- Invalid Input
- Host Offline
- Simulation Stopped
- Measurement Unavailable

Errors shall preserve instrument stability.

---

# 13. Acceptance Criteria

- Accurate RMS presentation.
- Deterministic operation.
- Correct probe validation.
- Stable display updates.
- Recording and playback supported.
- Compatible with future hardware.

---

End of Document
