# OEP Digital Multimeter Touch Interaction Specification

**Document ID:** OIP-DMM-033
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the touch interaction model for the OEP Digital Multimeter. It establishes consistent behavior for touch, stylus, and other direct-manipulation input methods across all supported platforms.

---

# 2. Scope

Applies to:

- Android Phones
- Android Tablets
- Future Dedicated Hardware
- Touch-enabled Windows Devices
- Touch-enabled Linux Devices

---

# 3. Design Objectives

The touch interface shall:

- Emulate the feel of a professional handheld instrument.
- Minimize accidental activation.
- Prioritize engineering workflows.
- Support left- and right-handed operation.
- Remain deterministic.

---

# 4. Supported Interactions

The application shall support:

- Single Tap
- Double Tap
- Long Press
- Drag
- Multi-touch
- Pinch Zoom
- Two-finger Pan
- Stylus Input

Each gesture shall have a single defined purpose.

---

# 5. Probe Placement

Touching an engineering object while a probe is active shall:

1. Resolve the selected Engineering Object.
2. Validate probe compatibility.
3. Attach the probe.
4. Request a new measurement.
5. Refresh the display.

Probe attachment shall always reference Engineering Object identifiers.

---

# 6. Rotary Selector

The virtual rotary selector shall support:

- Drag rotation
- Tap on detent
- Mouse wheel (desktop)
- Keyboard navigation
- Accessibility actions

Every detent change shall generate exactly one mode transition.

---

# 7. Soft Keys

Soft keys shall respond to:

- Tap
- Keyboard shortcut
- Accessibility activation

Long-press behavior is reserved for future extensions unless explicitly defined.

---

# 8. Gesture Priority

Priority order:

1. Safety dialogs
2. Probe placement
3. Rotary selector
4. Soft keys
5. Navigation
6. View manipulation

Higher-priority interactions shall consume the gesture.

---

# 9. Haptic Feedback

Where supported, haptic feedback may be generated for:

- Rotary detents
- Soft key activation
- Probe attachment
- Measurement HOLD
- Errors

Haptic feedback shall be configurable.

---

# 10. Accessibility

Support:

- Large touch targets
- Screen readers
- Stylus
- External keyboard
- Switch access

No engineering functionality shall require gestures unavailable to accessibility users.

---

# 11. Error Handling

Examples:

- Invalid probe target
- Gesture cancelled
- Unsupported interaction
- Lost touch focus

The UI shall recover without losing instrument state.

---

# 12. Acceptance Criteria

- Touch behavior is deterministic.
- Probe placement is reliable.
- Rotary interaction matches physical expectations.
- Accessibility provides full functionality.
- Platform behavior remains consistent.

---

End of Document
