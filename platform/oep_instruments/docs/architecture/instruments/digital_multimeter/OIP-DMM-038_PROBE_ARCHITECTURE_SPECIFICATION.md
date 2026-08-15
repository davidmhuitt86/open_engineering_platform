# OEP Digital Multimeter Probe Architecture Specification

**Document ID:** OIP-DMM-038
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the probe architecture for the OEP Digital Multimeter.

The probe subsystem provides a unified abstraction for both virtual probes used within the Open Engineering Platform and future physical measurement probes. It establishes how probes are created, identified, attached, managed, and synchronized throughout an Engineering Session.

---

# 2. Scope

This specification applies to:

- Virtual probes
- Future physical probes
- Diagram Studio
- Simulation Engine
- Engineering Sessions
- Recording & Playback
- Publishing

---

# 3. Design Objectives

The probe architecture shall:

- Represent every probe as an engineering object.
- Maintain deterministic attachment behavior.
- Support multiple probe types.
- Preserve engineering traceability.
- Remain extensible for future instruments.

---

# 4. Probe Types

The architecture shall support:

- Common (Black)
- Positive (Red)
- Current Clamp (Future)
- Temperature Probe
- Differential Probe (Future)
- Logic Probe (Future)
- Custom Probe Extensions

Every probe type shall declare its capabilities.

---

# 5. Probe Identity

Each probe shall have:

- Probe Identifier
- Probe Type
- Display Name
- Session Identifier
- Instrument Identifier
- Capability Profile

Probe identifiers shall remain immutable during a session.

---

# 6. Probe Lifecycle

Each probe transitions through the following states:

Detached

↓

Available

↓

Selected

↓

Attached

↓

Measuring

↓

Released

↓

Detached

Transitions shall be deterministic and recorded when appropriate.

---

# 7. Probe Attachment

Probes may attach to:

- Wire
- Connector
- Connector Pin
- Component Terminal
- Ground Node
- Power Rail
- Test Point
- Harness Branch

Attachments shall reference immutable Engineering Object identifiers.

---

# 8. Probe Validation

Before attachment the runtime shall verify:

- Probe compatibility
- Measurement mode compatibility
- Engineering Object validity
- Session availability
- Host capability

Invalid attachments shall be rejected without modifying engineering data.

---

# 9. Probe Synchronization

Probe state shall synchronize with:

- Engineering Sessions
- Simulation Engine
- Recording
- Playback
- Diagram Studio

Synchronization shall preserve probe identity and attachment state.

---

# 10. Recording & Traceability

Probe events shall record:

- Probe Identifier
- Attached Engineering Object
- Timestamp
- Measurement Mode
- Session Identifier
- Operator Action

Probe history shall remain immutable after recording.

---

# 11. Future Hardware

Future dedicated hardware shall implement the same logical probe architecture.

Physical connection technology may differ without affecting software behavior.

---

# 12. Acceptance Criteria

- Every probe has a unique identity.
- Attachments are deterministic.
- Probe history is traceable.
- Virtual and physical probes share the same architecture.
- Platform-independent behavior.
- Future probe types require no architectural redesign.

---

End of Document
