# OEP Digital Multimeter LCD Display Architecture

**Document ID:** OIP-DMM-004  
**Status:** Draft  
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the architecture of the Digital Multimeter LCD display.

The display is the primary communication interface between the Engineering Session and the engineer.

---

# 2. Design Objectives

- Prioritize measurement visibility.
- Emulate premium professional multimeters.
- Scale from phones to dedicated hardware.
- Never obscure the primary measurement.
- Maintain consistent layout across all platforms.

---

# 3. Display Regions

The display consists of:

1. Header
2. Primary Measurement
3. Secondary Measurement
4. Units & Prefixes
5. Status Annunciators
6. Session Indicators
7. Measurement Quality
8. Soft Key Labels

Each region has a fixed purpose.

---

# 4. Primary Measurement

The primary measurement is the dominant visual element.

It shall display:

- Numeric Value
- Sign
- Engineering Prefix
- Engineering Unit

The primary value shall remain visible at all times.

---

# 5. Secondary Measurement

Used for:

- Frequency
- Duty Cycle
- Delta Values
- Min/Max
- Reference Values
- Future multi-measurement modes

---

# 6. Status Indicators

The LCD shall support indicators for:

- HOLD
- REL
- MIN
- MAX
- AUTO
- MANUAL RANGE
- RECORD
- PLAYBACK
- SIMULATION
- HOST CONNECTED

---

# 7. Engineering Units

Support:

- V
- VAC
- VDC
- A
- mA
- µA
- Ω
- kΩ
- MΩ
- Hz
- kHz
- MHz
- nF
- µF
- mF
- °C
- °F

---

# 8. Update Behavior

Measurement updates shall be smooth and deterministic.

The display shall never flicker during normal operation.

---

# 9. Accessibility

Support:

- High Contrast
- Large Text
- Screen Readers
- Color Blind Safe Indicators

---

# 10. Acceptance Criteria

- Primary measurement always visible.
- Consistent layout on every platform.
- Professional instrument appearance.
- Deterministic update behavior.

---

End of Document
