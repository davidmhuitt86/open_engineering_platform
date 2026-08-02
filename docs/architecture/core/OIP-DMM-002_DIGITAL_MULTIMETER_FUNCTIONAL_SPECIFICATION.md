# OEP Digital Multimeter Functional Specification

Document ID:
OIP-DMM-002

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the functional behavior of the OEP Digital Multimeter (DMM).

It specifies every measurement mode, operating behavior, user interaction, and engineering capability independent of implementation.

This document supplements the Digital Multimeter Architecture.

---

# 2. Philosophy

The OEP Digital Multimeter shall behave exactly like a premium professional handheld instrument while extending beyond physical limitations through integration with the Open Engineering Platform.

An engineer already familiar with instruments from Fluke, Keysight, Brymen, Hioki, or Tektronix should require virtually no learning period.

---

# 3. Primary Functions

The Digital Multimeter shall support:

• DC Voltage

• AC Voltage

• True RMS

• Current

• Resistance

• Continuity

• Diode Test

• Capacitance

• Frequency

• Duty Cycle

• Temperature

• Relative Measurements

• Min / Max

• Hold

• Recording

• Playback

• Simulation Measurements

---

# 4. Measurement Modes

Each measurement mode shall operate independently.

Changing measurement modes shall never invalidate recorded measurements.

Every mode shall preserve its own configuration.

---

# 5. Display

The display shall include:

Primary Measurement

Engineering Units

Measurement Prefix

Connection Status

Measurement Mode

Range

Battery (future hardware)

Host Connection

Session Indicator

Recording Indicator

Simulation Indicator

Measurement Quality Indicator

---

# 6. Auto Range

Support:

Automatic Range

Manual Range

Range Lock

Range Step Up

Range Step Down

Auto range behavior shall emulate professional handheld instruments.

---

# 7. Relative Mode

Relative mode establishes a reference measurement.

Subsequent measurements display:

Measured Value

minus

Reference Value

Reference measurements remain visible until cleared.

---

# 8. Hold Mode

Hold freezes the displayed value.

The Engineering Session continues receiving measurements.

Only presentation is frozen.

---

# 9. Min / Max

Support:

Minimum

Maximum

Average (future)

Peak (future)

Values remain associated with the current Session.

---

# 10. Continuity

Continuity shall include:

Audible tone

Visual indication

Haptic confirmation

Threshold configuration

Near-instant response

Continuity behavior shall emulate professional instruments.

---

# 11. Diode Test

Support:

Forward Voltage

Reverse Blocking

Open Circuit

Short Circuit

Results shall include engineering units.

---

# 12. Frequency

Support:

Frequency

Period (future)

Duty Cycle

Pulse Width (future)

Measurements shall remain synchronized with Engineering Sessions.

---

# 13. Temperature

Future support includes:

Thermocouple

RTD

Infrared (future)

Temperature units:

°C

°F

K (future)

---

# 14. Recording

Recording captures:

Measurements

Timestamp

Probe Locations

Measurement Mode

Engineering Object

Session

Recording never modifies measurement behavior.

---

# 15. Playback

Playback supports:

Play

Pause

Resume

Step

Timeline Navigation

Bookmarks

Playback Speed

Playback uses Measurement History.

---

# 16. Probe Operation

Standard probes:

Black

Red

Future support:

Clamp Meter

Current Probe

Differential Probe

Probe behavior follows the Probe Architecture.

---

# 17. Integration

The Digital Multimeter integrates with:

Engineering Sessions

Diagram Studio

Simulation Engine

Engineering Intelligence Platform

Engineering Repository

Publishing System

Every measurement becomes traceable.

---

# 18. Export

Support exporting:

Measurements

History

Bookmarks

Reports

CSV

PDF

Markdown

OEP Package

---

# 19. Accessibility

The DMM supports:

Large Display Mode

High Contrast

Screen Readers

External Keyboard

Stylus

Reduced Motion

Accessibility shall never reduce engineering functionality.

---

# 20. Future Expansion

Future capabilities include:

Wireless Physical Meter

Automatic Probe Recognition

Thermal Camera Overlay

AI Measurement Assistant

Multi-channel Measurements

Hybrid Physical / Virtual Operation

---

# 21. Core Principles

1.

Behave like a premium professional multimeter.

2.

Engineering accuracy always overrides visual presentation.

3.

Measurements remain fully traceable.

4.

Sessions own engineering history.

5.

The Host performs engineering computation.

6.

The instrument presents engineering information.

7.

Every operation is deterministic.

8.

The Digital Multimeter serves as the reference implementation for all future OEP instruments.

---

End of Document