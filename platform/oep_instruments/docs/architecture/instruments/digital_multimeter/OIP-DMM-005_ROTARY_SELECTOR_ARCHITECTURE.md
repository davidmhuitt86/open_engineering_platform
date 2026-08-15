# OEP Digital Multimeter Rotary Selector Architecture

**Document ID:** OIP-DMM-005
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the architecture, behavior, and operational rules of the rotary selector used by the OEP Digital Multimeter.

The rotary selector is the primary measurement-mode selection interface and shall provide a deterministic, professional user experience across Android, desktop, and future dedicated hardware.

---

# 2. Design Philosophy

The rotary selector shall emulate the tactile workflow of premium handheld multimeters while allowing software implementations to preserve the same engineering workflow.

Every detent represents one engineering function.

Changing the selector shall never directly perform a measurement. It requests a change of operating mode from the Host.

---

# 3. Objectives

The selector shall:

- Provide deterministic mode selection
- Preserve muscle memory
- Require no nested menus for primary measurements
- Scale to future hardware
- Support accessibility input methods

---

# 4. Standard Positions

Recommended default positions:

OFF

↓

V DC

↓

V AC

↓

Resistance / Continuity / Diode

↓

Capacitance

↓

Frequency / Duty Cycle

↓

Current (mA)

↓

Current (10A)

↓

Temperature

↓

Custom Position (future)

The exact order may evolve, but software shall preserve a consistent mapping.

---

# 5. Detent Behavior

Each selector position represents exactly one operational state.

Changing positions shall:

1. Update the UI immediately
2. Notify the Host
3. Negotiate capabilities if required
4. Activate the selected measurement mode
5. Restore mode-specific settings

---

# 6. Soft-Key Integration

Each rotary position defines a default soft-key profile.

Example:

Voltage:
- HOLD
- REL
- MIN/MAX
- MENU

Resistance:
- HOLD
- REL
- CONTINUITY
- MENU

---

# 7. State Preservation

Each mode shall remember:

- Manual range
- Relative reference
- Display precision
- Recording state
- Preferred graph options

Returning to a mode restores its previous configuration.

---

# 8. Error Conditions

Invalid mode requests shall:

- Leave the selector visually unchanged
- Notify the user
- Preserve the previous operational state

The selector shall never enter an undefined state.

---

# 9. Accessibility

Support:

- Keyboard selection
- Touch rotation
- Stylus
- External controllers
- Screen readers

Every selector position shall expose an accessible name and description.

---

# 10. Acceptance Criteria

- One detent equals one mode.
- Mode changes are deterministic.
- Previous mode configuration is restored.
- Accessibility behavior matches platform standards.
- Future hardware requires no architectural changes.

---

End of Document
