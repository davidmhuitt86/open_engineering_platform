
# OEP Digital Multimeter Front Panel & Control Layout Specification

**Document ID:** OIP-DMM-003  
**Status:** Draft  
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the physical and virtual front panel layout of the OEP Digital Multimeter (DMM). It establishes a consistent operator interface for Android, desktop, and future dedicated hardware implementations.

---

# 2. Design Objectives

- Emulate premium professional handheld multimeters.
- Preserve identical workflows across every platform.
- Prioritize measurement visibility.
- Minimize operator interaction time.
- Support one-handed operation where practical.
- Remain scalable to future hardware.

---

# 3. Functional Zones

The front panel is divided into six primary zones:

1. Header
2. Main LCD
3. Soft Keys
4. Rotary Selector
5. Quick Action Controls
6. Probe Jack Area

Each zone has a single engineering purpose.

---

# 4. Header

Displays:

- Session name
- Host connection status
- Recording indicator
- Simulation indicator
- Future battery indicator
- Notifications

The header remains permanently visible.

---

# 5. Main LCD

The LCD is the visual focal point.

It displays:

- Primary measurement
- Secondary measurement
- Units
- Prefixes
- Measurement mode
- Annunciators
- Status icons

No dialog shall obscure the primary measurement.

---

# 6. Soft Keys

Four programmable soft keys:

- HOLD
- REL
- MIN/MAX
- MENU

Their function may change, but their physical location never changes.

---

# 7. Rotary Selector

The rotary selector is the primary mode selection device.

Each detent corresponds to exactly one measurement mode.

Changing position immediately requests the new operating mode from the Host.

---

# 8. Probe Jack Area

Standard layout:

- COM
- V Ω Hz
- mA / µA
- 10A

Future hardware shall preserve this arrangement.

---

# 9. Accessibility

Support:

- Touch
- Stylus
- Mouse
- Keyboard
- Screen Readers
- Large Touch Targets

---

# 10. Acceptance Criteria

- Controls have one clearly defined purpose.
- Measurement is always the primary visual element.
- Rotary selector behavior is deterministic.
- Layout scales from phone to tablet.
- Future hardware requires no architectural redesign.

---
End of Document
