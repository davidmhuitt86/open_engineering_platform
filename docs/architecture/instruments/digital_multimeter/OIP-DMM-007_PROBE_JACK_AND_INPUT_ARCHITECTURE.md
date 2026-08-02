# OEP Digital Multimeter Probe Jack & Input Architecture

**Document ID:** OIP-DMM-007  
**Status:** Draft  
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the electrical input architecture, probe jack arrangement, virtual probe mapping, and operator interaction model for the OEP Digital Multimeter.

It establishes a single input architecture that applies to Android, desktop, and future dedicated OEP hardware.

---

# 2. Objectives

The probe input system shall:

- Mirror professional handheld multimeters.
- Maintain identical jack locations across all platforms.
- Support simulation and future physical hardware.
- Prevent ambiguous probe assignments.
- Remain extensible.

---

# 3. Standard Jack Layout

The default input arrangement is:

1. COM
2. V / Ω / Hz / Diode / Continuity
3. mA / µA
4. 10A

This ordering shall remain fixed.

---

# 4. Probe Definitions

Black Probe
- Default reference
- Normally connected to COM

Red Probe
- Active measurement probe
- Connected according to measurement mode

Future instruments may introduce additional probe colors without changing the standard pair.

---

# 5. Supported Measurement Paths

The architecture supports:

- Voltage
- Current
- Resistance
- Continuity
- Diode
- Capacitance
- Frequency
- Duty Cycle
- Temperature

Each measurement mode validates the required probe configuration before requesting measurements.

---

# 6. Virtual Probe Mapping

Virtual probes represent logical probe locations within:

- Diagram Studio
- Simulation Engine
- Engineering Intelligence
- Physical hardware

Probe placement always references Engineering Objects rather than screen coordinates.

---

# 7. Validation

Before measurement begins the Host shall verify:

- Correct jack assignment
- Valid probe configuration
- Supported measurement mode
- Active Engineering Session
- Compatible target

Invalid configurations shall generate user-visible warnings.

---

# 8. Status Indicators

The UI shall indicate:

- Probe Connected
- Probe Missing
- Probe Measuring
- Probe Invalid
- Current Jack Assignment

---

# 9. Future Hardware

Future dedicated hardware shall preserve the same logical input architecture even if the physical connector technology evolves.

---

# 10. Acceptance Criteria

- Standard jack ordering is maintained.
- Probe assignments are deterministic.
- Invalid configurations are detected before measurement.
- Virtual and physical probes share identical behavior.
- Architecture supports future hardware without redesign.

---

End of Document
