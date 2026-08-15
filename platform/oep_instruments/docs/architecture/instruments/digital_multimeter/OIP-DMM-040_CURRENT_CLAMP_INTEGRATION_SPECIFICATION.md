# OEP Digital Multimeter Current Clamp Integration Specification

**Document ID:** OIP-DMM-040
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the architecture for integrating current clamp accessories with the OEP Digital Multimeter.

Current clamps extend the measurement capabilities of the Digital Multimeter by allowing non-invasive current measurements while preserving the standard OEP Measurement Engine architecture.

---

# 2. Scope

This specification applies to:

- Virtual Current Clamps
- Future Bluetooth Current Clamps
- Future USB Current Clamps
- Dedicated OEP Clamp Hardware
- Engineering Sessions
- Simulation Engine
- Recording & Playback

---

# 3. Design Objectives

The Current Clamp subsystem shall:

- Support AC current measurements.
- Support DC current measurements.
- Support Auto-Ranging and Manual Ranging.
- Integrate with the Measurement Engine.
- Preserve engineering traceability.
- Remain extensible for future clamp technologies.

---

# 4. Supported Clamp Types

The architecture shall support:

- AC Clamp
- DC Clamp
- AC/DC Combination Clamp
- Flexible Rogowski Coil (Future)
- High Current Industrial Clamp (Future)
- Simulation Clamp

Each clamp shall advertise its capabilities to the Measurement Engine.

---

# 5. Clamp Identity

Every clamp shall expose:

- Clamp Identifier
- Model Name
- Manufacturer
- Firmware Version
- Capability Profile
- Serial Number (if available)

The Clamp Identifier shall remain immutable for the lifetime of the device.

---

# 6. Pairing & Discovery

Wireless clamps shall support:

- Automatic discovery
- Manual pairing
- Trusted device list
- Secure reconnection
- Connection status reporting

Only authenticated clamps shall provide measurements.

---

# 7. Measurement Workflow

1. Clamp connects to the DMM.
2. Measurement Engine validates compatibility.
3. Clamp reports scaling information.
4. Measurement requests begin.
5. Measurements are displayed.
6. Measurements may be recorded or published.

The clamp shall never perform Engineering Session management.

---

# 8. Scaling & Calibration

Each clamp shall provide:

- Current scaling factor
- Measurement range
- Calibration metadata
- Accuracy metadata
- Temperature compensation (future)

The Measurement Engine shall apply scaling before presentation.

---

# 9. Simulation Integration

Simulation shall support virtual clamp devices.

Virtual clamps shall:

- Behave identically to physical clamps.
- Produce deterministic results.
- Participate in Engineering Sessions.
- Support recording and playback.

---

# 10. Error Handling

Examples:

- Clamp disconnected
- Low battery
- Calibration expired
- Unsupported firmware
- Communication timeout

Errors shall not invalidate previously recorded engineering measurements.

---

# 11. Integration

The Current Clamp subsystem integrates with:

- Measurement Engine
- Probe Manager
- Engineering Sessions
- Simulation Engine
- Recording & Playback
- Publishing

---

# 12. Acceptance Criteria

- Clamp identity remains stable.
- Pairing is deterministic.
- Scaling is applied correctly.
- Virtual and physical clamps behave consistently.
- Engineering traceability is preserved.
- Future clamp technologies require no architectural redesign.

---

End of Document
