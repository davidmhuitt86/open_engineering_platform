# OEP Digital Multimeter Auto Ranging & Range Selection Architecture

**Document ID:** OIP-DMM-022
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This document defines the Auto Ranging and Manual Range Selection architecture used by the OEP Digital Multimeter.

The architecture provides a consistent framework for selecting the optimum measurement range while maintaining stable, deterministic measurement behavior across every supported measurement mode.

---

# 2. Scope

This architecture applies to all DMM measurement modes that support ranging, including:

- DC Voltage
- AC Voltage
- Current
- Resistance
- Capacitance
- Frequency (where applicable)
- Temperature (future sensor-dependent implementations)

---

# 3. Design Objectives

The ranging subsystem shall:

- Maximize displayed resolution.
- Minimize unnecessary range transitions.
- Prevent oscillation between adjacent ranges.
- Preserve measurement stability.
- Operate identically across all supported platforms.

---

# 4. Operating Modes

The subsystem supports:

- Auto Range
- Manual Range
- Range Lock
- Range Step Up
- Range Step Down

Only one ranging mode may be active at a time.

---

# 5. Auto Range Behavior

Auto Range shall:

1. Acquire the incoming engineering value.
2. Compare the value against available ranges.
3. Select the smallest valid range capable of representing the measurement.
4. Apply hysteresis before changing ranges.
5. Update the display.

The selected range shall maximize useful display resolution without causing instability.

---

# 6. Range Hysteresis

To prevent rapid switching between adjacent ranges, Auto Range shall implement hysteresis.

A range transition shall occur only after the measured value exceeds the configured transition threshold for the required stabilization period.

---

# 7. Manual Range

Manual Range shall:

- Lock the active range.
- Ignore automatic range requests.
- Persist until the operator exits Manual Range.
- Display the MAN annunciator.

---

# 8. Range Persistence

Each measurement mode shall remember its last selected manual range.

Returning to a previously used measurement mode restores the stored range configuration unless user preferences specify otherwise.

---

# 9. Over-Range Handling

If the measurement exceeds the active range:

- Display the configured over-range indication.
- Preserve instrument stability.
- Allow Auto Range to select a larger range when enabled.

Manual Range shall require operator intervention.

---

# 10. Under-Range Handling

Measurements significantly below the active range shall:

- Remain valid.
- Continue displaying engineering units.
- Permit Auto Range to transition to a more appropriate range.

---

# 11. User Interface

The interface shall provide:

- AUTO annunciator
- MAN annunciator
- Current range
- Range controls
- Range status messages

Range changes shall be immediately visible.

---

# 12. Integration

The ranging subsystem integrates with:

- Measurement Engine
- Engineering Sessions
- Recording
- Playback
- Publishing
- Simulation Engine

---

# 13. Acceptance Criteria

- Deterministic range selection.
- Stable display during transitions.
- Effective hysteresis.
- Manual range lock behaves predictably.
- Consistent behavior across every supported platform.

---

End of Document
