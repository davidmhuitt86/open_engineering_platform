# OEP Digital Multimeter Frequency & Duty Cycle Measurement Specification

**Document ID:** OIP-DMM-015  
**Status:** Draft  
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Frequency and Duty Cycle measurement mode for the OEP Digital Multimeter.

Frequency mode measures the repetition rate of a periodic signal while Duty Cycle mode measures the percentage of one complete cycle that the signal remains in its active state.

---

# 2. Objectives

The measurement mode shall:

- Measure frequency across supported ranges.
- Calculate duty cycle from the active waveform.
- Operate consistently in simulation and future hardware.
- Integrate with Engineering Sessions.
- Support recording, playback, and publishing.

---

# 3. Operating Workflow

1. User selects Frequency/Duty Cycle mode.
2. Probe configuration is validated.
3. Host verifies waveform availability.
4. Frequency is calculated.
5. Duty cycle is calculated.
6. Results are displayed and optionally recorded.

---

# 4. Probe Configuration

Required:

Black Probe → COM

Red Probe → V/Ω/Hz

Measurement shall not begin until the probe configuration is valid.

---

# 5. Display

Primary Display:

- Frequency Value
- Unit (Hz, kHz, MHz)

Secondary Display:

- Duty Cycle (%)

Additional Indicators:

- AUTO/MAN
- Session Status
- Recording Status
- Host Connection
- Simulation Indicator

---

# 6. Frequency Measurement

The Host determines the waveform period.

Frequency shall be displayed using the most appropriate engineering prefix.

Display updates shall remain stable and deterministic.

---

# 7. Duty Cycle Measurement

Duty cycle shall be calculated as:

High Time ÷ Period × 100

The displayed value shall be expressed as a percentage.

---

# 8. Auto Range

Auto Range shall:

- Select the most appropriate frequency range.
- Reduce unnecessary range switching.
- Maintain stable display updates.

---

# 9. Manual Range

Manual Range shall:

- Lock the selected range.
- Ignore automatic adjustments.
- Display the MAN annunciator.

---

# 10. Measurement States

Supported states:

- Initializing
- Measuring
- Stable
- No Waveform
- Over Range
- Hold
- Relative
- Recording
- Playback
- Error

Only one primary state shall be active.

---

# 11. Integration

Frequency and Duty Cycle measurements integrate with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

Every measurement shall remain traceable to its originating Session.

---

# 12. Error Conditions

Examples:

- No waveform detected
- Probe missing
- Invalid input jack
- Host disconnected
- Measurement unavailable

Errors shall never leave the instrument in an undefined state.

---

# 13. Acceptance Criteria

- Correct probe validation.
- Deterministic frequency calculation.
- Deterministic duty cycle calculation.
- Stable display behavior.
- Complete Engineering Session integration.
- Compatible with future hardware.

---

End of Document
