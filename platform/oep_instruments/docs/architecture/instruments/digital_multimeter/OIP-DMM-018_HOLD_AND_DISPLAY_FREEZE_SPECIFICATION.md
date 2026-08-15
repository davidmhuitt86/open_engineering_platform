# OEP Digital Multimeter Hold & Display Freeze Specification

**Document ID:** OIP-DMM-018
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the HOLD (Display Freeze) operating mode for the OEP Digital Multimeter.

HOLD mode freezes the displayed measurement for observation while allowing the Engineering Session and Host to continue acquiring live engineering data.

HOLD affects presentation only. It shall never interrupt or modify the underlying engineering measurement stream.

---

# 2. Objectives

The HOLD mode shall:

- Freeze only the displayed measurement.
- Preserve live measurement acquisition.
- Support all compatible measurement modes.
- Integrate with Engineering Sessions.
- Preserve engineering traceability.
- Support recording and playback.

---

# 3. Supported Measurement Modes

HOLD may be used with:

- DC Voltage
- AC Voltage
- Current
- Resistance
- Continuity
- Diode Test
- Capacitance
- Frequency
- Duty Cycle
- Temperature

Future measurement modes shall explicitly declare HOLD compatibility.

---

# 4. Operating Workflow

1. User acquires a stable measurement.
2. User presses the HOLD soft key.
3. Current displayed value is frozen.
4. Live measurements continue in the background.
5. User presses HOLD again.
6. Display resumes showing the current live measurement.

---

# 5. Display Behavior

When HOLD is active, the display shall indicate:

- Frozen measurement value
- HOLD annunciator
- Original engineering units
- Active measurement mode
- Session status
- Recording status
- Host connection status

The HOLD annunciator shall remain visible until HOLD is released.

---

# 6. Engineering Behavior

While HOLD is active:

- The Host continues acquiring measurements.
- Engineering Sessions continue receiving updates.
- Simulation continues executing.
- Measurement History continues recording if enabled.
- Publishing and Engineering Intelligence continue operating on live data.

Only the instrument presentation layer is frozen.

---

# 7. Recording

If recording is enabled:

- Live measurements continue to be recorded.
- HOLD activation and release events shall be recorded.
- The frozen display value shall be associated with the HOLD event.

Recording shall never pause solely because HOLD is active.

---

# 8. Playback

Playback shall reproduce:

- HOLD activation
- Frozen display value
- HOLD release
- Return to live measurements

Playback shall faithfully recreate the original operator experience.

---

# 9. Measurement States

Supported states:

- Live
- Hold Requested
- Display Frozen
- Hold Released
- Recording
- Playback
- Error

Only one primary HOLD state shall exist at any time.

---

# 10. Error Conditions

Examples include:

- Host disconnected during HOLD
- Measurement unavailable
- Session terminated
- Playback unavailable

Errors shall preserve the frozen display until the operator exits HOLD or the instrument enters a safe recovery state.

---

# 11. Integration

HOLD integrates with:

- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Measurement History
- Publishing

The feature shall remain presentation-only across all integrations.

---

# 12. Acceptance Criteria

- HOLD freezes only the display.
- Live engineering measurements continue uninterrupted.
- HOLD events are recorded.
- Playback reproduces HOLD behavior.
- Engineering traceability is preserved.
- Behavior is identical across all supported platforms.

---

End of Document
