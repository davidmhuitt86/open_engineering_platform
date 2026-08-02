# OEP Display & LCD System Architecture

Document ID:
OIP-LCD-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the display system architecture used throughout the OEP Instruments platform.

The display system is responsible for presenting engineering information clearly, consistently, and authentically across every instrument.

The display system shall establish a common visual language while allowing each instrument to retain its own identity.

---

# 2. Philosophy

The display is the engineer's primary interface.

Every element displayed shall communicate engineering information.

The display shall never become decorative.

Readability takes precedence over aesthetics.

---

# 3. Objectives

The display system shall:

Present engineering values

Present engineering status

Present engineering warnings

Present engineering history

Present engineering modes

Present connection state

Present session state

Remain immediately readable under all supported operating conditions.

---

# 4. Display Types

The platform shall support multiple display technologies.

Examples:

Segment LCD

Dot Matrix LCD

Monochrome LCD

Color LCD

OLED

Future display technologies

Every display shall implement the common display architecture.

---

# 5. Information Hierarchy

Priority 1

Primary Measurement

Priority 2

Measurement Units

Priority 3

Measurement Mode

Priority 4

Instrument Status

Priority 5

Connection Status

Priority 6

Session Information

Priority 7

Secondary Information

Nothing shall visually compete with the primary measurement.

---

# 6. Primary Measurement

The primary measurement shall always remain visible.

Characteristics:

Largest text

Highest contrast

Centered

Stable position

Minimal animation

Never truncated

Never obscured

---

# 7. Measurement Units

Units shall remain permanently visible.

Examples:

V

A

Ω

Hz

%

W

°C

Units shall never rely on color alone.

---

# 8. Status Annunciators

Support annunciators including:

AUTO

MAN

HOLD

MIN

MAX

REL

PEAK

RMS

SIM

LIVE

CONNECTED

BATTERY

STREAM

Each annunciator shall have a consistent location.

---

# 9. Numeric Display

Numeric values shall:

Use fixed-width digits

Prevent layout shifting

Support engineering notation

Support negative values

Support overload indication

Support out-of-range indication

Support invalid measurements

---

# 10. Engineering Symbols

Support standard engineering symbols.

Examples:

Ω

µ

m

k

M

Hz

VAC

VDC

A

mA

µA

Engineering notation shall conform to accepted industry standards.

---

# 11. Display States

Support:

Startup

Ready

Measuring

Streaming

Hold

Relative

Warning

Error

Disconnected

Shutdown

Every state shall have a unique visual presentation.

---

# 12. Startup Display

Startup shall perform:

Segment test

Model identification

Firmware version

Calibration status

Battery status

Connection status

Ready

Startup shall reinforce confidence in the instrument.

---

# 13. Update Behavior

Measurements shall update:

Smoothly

Predictably

Without flicker

Without unnecessary animation

Changes shall never distract from engineering work.

---

# 14. Measurement Stability

Support visual indication of:

Stable measurement

Changing measurement

Streaming

Sampling

Overload

Noise

Disconnected source

The engineer shall immediately recognize measurement quality.

---

# 15. Warning Presentation

Warnings shall appear without obscuring measurements.

Examples:

Overload

Probe error

Disconnected

Low battery

Host unavailable

Simulation paused

Warnings shall remain readable.

---

# 16. Error Presentation

Errors shall:

Be descriptive

Remain deterministic

Never replace the primary measurement unnecessarily

Provide corrective guidance when appropriate

---

# 17. Brightness

Support:

Automatic brightness (future)

Manual brightness

Night mode

Day mode

High contrast mode

Brightness shall never reduce measurement readability.

---

# 18. Orientation

Displays shall support:

Portrait

Landscape

Tablet

Phone

Foldable devices

Future embedded hardware

Measurements shall maintain hierarchy regardless of orientation.

---

# 19. Refresh Rate

Target:

Responsive updates

Consistent rendering

No visible tearing

Smooth streaming

Stable numerical transitions

Refresh behavior shall prioritize engineering accuracy.

---

# 20. Color Usage

Color communicates engineering state.

Never engineering value.

Values shall remain understandable in monochrome.

---

# 21. Accessibility

Support:

Large numerals

Screen readers

High contrast

Color-blind safe indicators

Accessible annunciators

Accessibility shall not alter engineering meaning.

---

# 22. Future Displays

The display architecture shall support future:

Dedicated hardware LCDs

E-Ink

Industrial TFT displays

Heads-up displays

External monitors

No redesign shall be required.

---

# 23. Core Principles

1.

The display exists to communicate engineering information.

2.

Measurements always have highest priority.

3.

Engineering clarity overrides decoration.

4.

Status indicators remain predictable.

5.

Display behavior builds user confidence.

6.

Values never shift unnecessarily.

7.

Every display belongs to one OEP family.

8.

Future display technologies require no architectural redesign.

---

End of Document