# OEP Digital Multimeter Soft Key System Specification

**Document ID:** OIP-DMM-035
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Soft Key System used by the OEP Digital Multimeter.

The soft key system provides context-sensitive access to frequently used instrument functions while preserving the familiar workflow of professional handheld digital multimeters.

---

# 2. Scope

Applies to:

- Android
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware

The architecture is independent of platform and display size.

---

# 3. Design Objectives

The Soft Key System shall:

- Reduce menu navigation.
- Keep common functions immediately accessible.
- Adapt automatically to the active measurement mode.
- Preserve consistent key locations.
- Support accessibility and external input devices.

---

# 4. Architecture

The instrument shall provide four primary soft keys positioned directly beneath the main display.

Default positions:

- Soft Key 1
- Soft Key 2
- Soft Key 3
- Soft Key 4

Their physical position never changes.

Only their assigned function changes.

---

# 5. Dynamic Assignment

Each measurement mode defines its own default soft-key profile.

Example:

Voltage Mode
- HOLD
- REL
- MIN/MAX
- MENU

Resistance Mode
- HOLD
- REL
- Continuity
- MENU

Playback Mode
- Play
- Pause
- Step
- Timeline

Assignments shall be provided by the Measurement Engine.

---

# 6. Labels

Every soft key shall display:

- Text label
- Optional icon
- Enabled/Disabled state

Labels shall update immediately when context changes.

---

# 7. Interaction

Supported activation methods:

- Touch
- Mouse click
- Keyboard shortcut
- Accessibility action
- Future hardware buttons

Only one action shall execute per activation.

---

# 8. States

Each soft key supports:

- Enabled
- Disabled
- Active
- Busy
- Hidden (reserved for future use)

State changes shall be deterministic.

---

# 9. Accessibility

The Soft Key System shall support:

- Screen readers
- Large text
- High contrast
- Keyboard navigation
- Switch access

Each key shall expose an accessible name and description.

---

# 10. Integration

The Soft Key System integrates with:

- Measurement Engine
- Engineering Sessions
- Simulation Engine
- Recording & Playback
- Instrument Settings
- Engineering Intelligence

---

# 11. Acceptance Criteria

- Soft key locations remain fixed.
- Context changes update assignments correctly.
- Labels remain synchronized with active functions.
- Accessibility is fully supported.
- Platform-independent behavior.
- Future hardware can implement identical functionality.

---

End of Document
