# OEP Digital Multimeter Display Layout Specification

**Document ID:** OIP-DMM-032
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the visual layout of the OEP Digital Multimeter across all supported platforms. It establishes the position, sizing, hierarchy, and scaling rules for every visible interface element.

---

# 2. Scope

Applies to:

- Android Phones
- Android Tablets
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware

---

# 3. Design Objectives

The layout shall:

- Prioritize measurement readability.
- Preserve a familiar handheld multimeter appearance.
- Scale responsively without changing workflow.
- Support touch, mouse, stylus, and keyboard interaction.
- Maintain visual consistency across platforms.

---

# 4. Layout Regions

Every layout shall contain the following regions:

1. Application Header
2. Instrument Display
3. Soft Key Bar
4. Rotary Selector
5. Probe Status Area
6. Session Status Bar
7. Optional Navigation Drawer

These regions shall remain in a consistent order regardless of screen size.

---

# 5. Portrait Layout

Portrait mode shall allocate the largest portion of the display to the Instrument Display.

The recommended vertical order is:

- Header
- Instrument Display
- Soft Keys
- Rotary Selector
- Probe Status
- Session Status

Scrolling shall never be required to access measurement controls.

---

# 6. Landscape Layout

Landscape mode shall prioritize simultaneous visibility of measurement data and controls.

The Instrument Display remains the dominant element.

Navigation components may relocate but shall not obscure measurements.

---

# 7. Responsive Scaling

The layout shall adapt using responsive rules rather than fixed pixel values.

Scaling shall preserve:

- Relative spacing
- Typography hierarchy
- Touch target sizes
- Measurement prominence

---

# 8. Typography

Text hierarchy:

- Primary Measurement
- Secondary Measurement
- Units
- Status Indicators
- Labels
- Auxiliary Information

The primary measurement shall always be the largest text element.

---

# 9. Safe Areas

Layouts shall respect:

- Display cutouts
- Rounded corners
- System navigation bars
- Gesture regions

No engineering information shall be placed inside unsafe display areas.

---

# 10. Visual Priority

Highest priority:

1. Primary Measurement
2. Measurement Units
3. Active Mode
4. Probe Status
5. Session Status
6. Navigation

Decorative elements shall never compete with engineering information.

---

# 11. Accessibility

Support:

- Large Display Mode
- High Contrast
- Adjustable Text Scaling
- Screen Readers
- Keyboard Navigation

Accessibility shall not alter engineering workflow.

---

# 12. Acceptance Criteria

- Layout remains consistent across platforms.
- Measurement is always the dominant visual element.
- Responsive behavior preserves usability.
- Safe areas are respected.
- Accessibility requirements are fully supported.
- Future hardware can adopt the layout without redesign.

---

End of Document
