# OEP Digital Multimeter Self-Test & Diagnostics Specification

**Document ID:** OIP-DMM-055
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Self-Test and Diagnostics Architecture for the OEP Digital Multimeter.

The diagnostics subsystem continuously verifies the operational health of the Digital Multimeter, connected accessories, communication interfaces, and software services. It detects faults, reports diagnostic information, and assists engineers in maintaining reliable instrument operation while preserving engineering integrity.

Diagnostic operations shall never modify engineering measurements or recorded Engineering Session data.

---

# 2. Scope

This specification applies to:

- Android Companion Application
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware
- Smart Probes
- Current Clamps
- Temperature Probes
- Engineering Sessions

---

# 3. Design Objectives

The diagnostics subsystem shall:

- Verify instrument health.
- Detect failures early.
- Provide deterministic diagnostic results.
- Preserve engineering traceability.
- Support automated and manual diagnostics.
- Scale to future OEP instruments.

---

# 4. Diagnostic Categories

The subsystem shall support:

- Startup Self-Test
- Runtime Diagnostics
- Measurement Diagnostics
- Probe Diagnostics
- Smart Probe Diagnostics
- Communication Diagnostics
- User Interface Diagnostics
- Storage Diagnostics
- Engineering Session Diagnostics
- System Diagnostics

Each diagnostic category shall execute independently.

---

# 5. Startup Self-Test

During application startup the system shall verify:

- Measurement Engine initialization
- Instrument configuration
- Settings integrity
- Required services
- User interface initialization
- Local storage accessibility
- Communication subsystem availability

Startup shall complete only after required diagnostics succeed or appropriate recovery actions are taken.

---

# 6. Runtime Diagnostics

While operating, the subsystem shall monitor:

- Measurement Engine health
- Memory utilization
- Communication status
- Synchronization status
- Recording subsystem
- Playback subsystem
- Probe state
- Background services

Runtime diagnostics shall not interrupt active measurements unless required for safety or data integrity.

---

# 7. Probe Diagnostics

The subsystem shall verify:

- Probe connection status
- Probe identity
- Capability information
- Calibration status
- Communication health
- Measurement compatibility

Invalid probe states shall generate diagnostic events.

---

# 8. Diagnostic Reporting

Each diagnostic event shall record:

- Diagnostic Identifier
- Timestamp
- Severity
- Category
- Affected Component
- Description
- Recommended Action
- Resolution Status

Diagnostic history shall be append-only.

---

# 9. Manual Diagnostics

Engineers may manually initiate:

- Complete Instrument Test
- Communication Test
- Probe Test
- Calibration Verification
- Storage Verification
- Synchronization Test

Manual diagnostics shall not modify Engineering Session data.

---

# 10. Integration

The diagnostics subsystem integrates with:

- Measurement Engine
- Probe Manager
- Calibration
- Engineering Sessions
- Recording & Playback
- Synchronization
- Publishing

---

# 11. Acceptance Criteria

- Startup diagnostics are deterministic.
- Runtime diagnostics execute continuously without affecting measurement accuracy.
- Diagnostic reports are traceable.
- Probe diagnostics detect invalid states.
- Diagnostic history remains immutable.
- Future instruments adopt this architecture without redesign.

---

End of Document
