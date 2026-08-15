# OEP Digital Multimeter Display Symbols & Indicators Specification

**Document ID:** OIP-DMM-006
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines every display symbol, annunciator, status icon, engineering indicator, and visual notification used by the OEP Digital Multimeter.

The objective is to create a professional, standardized display language that remains consistent across Android, Windows, Linux, and future dedicated hardware.

---

# 2. Design Objectives

The indicator system shall:

- Convey engineering state at a glance
- Never obscure measurements
- Remain recognizable on every platform
- Match professional test equipment conventions
- Support accessibility

---

# 3. Indicator Categories

The display supports the following categories:

• Measurement Mode

• Measurement State

• Range

• Recording

• Playback

• Session

• Host Connection

• Probe Status

• Simulation

• Diagnostics

• Warnings

• Accessibility

---

# 4. Measurement Mode Indicators

The following indicators identify the active measurement mode:

VDC

VAC

Ω

A

mA

µA

Hz

Duty

Cap

Temp

Diode

Continuity

Only one primary measurement mode indicator may be active.

---

# 5. Measurement State Indicators

Support:

AUTO

MAN

HOLD

REL

MIN

MAX

PEAK (Future)

AVG (Future)

Recording

Playback

Streaming

Measurement state indicators may be combined when appropriate.

---

# 6. Range Indicators

Display:

Auto Range

Manual Range

Current Range

Engineering Prefix

Over Range

Under Range

Range indicators remain visible whenever applicable.

---

# 7. Session Indicators

Display:

Connected

Disconnected

Offline

Simulation

Recording Session

Shared Session

Read-Only Session

Synchronization

These indicators communicate Engineering Session status only.

---

# 8. Connection Indicators

Support:

Bluetooth

USB

Wi-Fi

Future Hardware

Signal Strength

Latency Warning

Connection Lost

---

# 9. Probe Indicators

Display:

Red Probe Connected

Black Probe Connected

Probe Missing

Probe Invalid

Probe Measuring

Probe Hold

Future multi-channel probes shall extend this system.

---

# 10. Warning Indicators

Examples:

Overload

Open Circuit

Low Battery (Future Hardware)

Calibration Required

Measurement Invalid

Host Error

Transport Error

Warnings shall never replace the primary measurement.

---

# 11. Accessibility

Every symbol shall include:

Accessible Name

Accessible Description

High Contrast Variant

Large Display Variant

---

# 12. Acceptance Criteria

- Symbols remain readable on every supported display size.
- Engineering meaning is never ambiguous.
- Icons remain consistent across all OEP instruments.
- Future indicators can be added without redesign.

---

End of Document
