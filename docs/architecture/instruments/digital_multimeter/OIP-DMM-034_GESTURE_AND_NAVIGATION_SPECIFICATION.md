# OEP Digital Multimeter Gesture & Navigation Specification

**Document ID:** OIP-DMM-034
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the global navigation architecture and gesture model for the OEP Digital Multimeter application.

It establishes consistent navigation behavior across Android, desktop operating systems, and future dedicated OEP hardware while preserving the workflow expected from a professional handheld instrument.

---

# 2. Scope

This specification applies to:

- Android Phones
- Android Tablets
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware

---

# 3. Design Objectives

The navigation system shall:

- Minimize interaction steps.
- Keep measurements continuously visible whenever practical.
- Prevent accidental navigation during measurement.
- Support multiple input methods.
- Maintain deterministic behavior.

---

# 4. Navigation Principles

Navigation shall be:

- Predictable
- Hierarchical
- Reversible
- Non-destructive
- Consistent across platforms

Engineering operations shall never depend on hidden navigation paths.

---

# 5. Primary Navigation Areas

The application provides access to:

- Measurement Modes
- Recording
- Playback
- Sessions
- Diagnostics
- Instrument Settings
- Help
- About

Primary measurement controls shall remain immediately accessible.

---

# 6. Navigation Stack

The application maintains a navigation stack.

Supported operations:

- Push
- Pop
- Replace
- Return to Root

Navigation history shall never alter Engineering Session state.

---

# 7. Back Navigation

Back navigation shall:

- Return to the previous screen.
- Preserve measurement state.
- Preserve active recordings.
- Preserve Engineering Session binding.

If unsaved configuration changes exist, confirmation shall be requested before discarding them.

---

# 8. Drawer Navigation

Where supported, a navigation drawer may provide access to secondary features.

The drawer shall never obscure the primary measurement longer than necessary.

The drawer is unavailable during dedicated full-screen measurement mode.

---

# 9. Full-Screen Measurement Mode

Full-screen mode shall:

- Maximize measurement visibility.
- Hide non-essential controls.
- Preserve access to HOLD and emergency actions.
- Support rapid exit.

Measurements continue uninterrupted while entering or leaving full-screen mode.

---

# 10. External Input

Navigation shall support:

- Keyboard
- Mouse
- Touch
- Stylus
- Rotary encoder (future hardware)
- Accessibility devices

All navigation paths shall remain functionally equivalent.

---

# 11. Gesture Priority

When multiple gestures are possible, priority shall be:

1. Safety dialogs
2. Probe operations
3. Measurement controls
4. Navigation
5. View manipulation

Lower-priority gestures shall not interrupt higher-priority engineering actions.

---

# 12. Accessibility

Navigation shall support:

- Screen readers
- Keyboard-only operation
- Switch access
- High-contrast mode
- Large touch targets

No engineering function shall require inaccessible gestures.

---

# 13. Acceptance Criteria

- Navigation is deterministic.
- Measurement state is preserved during navigation.
- Recording continues uninterrupted.
- Engineering Sessions remain bound.
- Platform-independent behavior.
- Future hardware requires no navigation redesign.

---

End of Document
