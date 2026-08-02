# OEP Digital Multimeter Companion Device & Remote Control Architecture

**Document ID:** OIP-DMM-051
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Companion Device and Remote Control Architecture for the OEP Digital Multimeter.

The architecture enables the Digital Multimeter to operate as either a standalone instrument or a remotely controlled companion instrument connected to OEP Studio. The companion device provides a realistic handheld instrument experience while remaining synchronized with the active Engineering Session.

---

# 2. Scope

This specification applies to:

- Android Companion Application
- OEP Studio
- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Recording & Playback
- Future Dedicated Hardware

---

# 3. Design Objectives

The architecture shall:

- Present a true handheld instrument experience.
- Separate instrument presentation from engineering computation.
- Maintain deterministic synchronization.
- Support online and offline operation.
- Scale to future OEP instruments.
- Preserve engineering traceability.

---

# 4. Architectural Overview

The Companion Device consists of:

- Instrument User Interface
- Local Runtime
- Communication Layer
- Session Synchronization Engine
- Instrument State Manager
- Local Cache
- Security Layer

Engineering computation remains the responsibility of OEP Studio or future hardware hosts.

---

# 5. Operating Modes

The companion application shall support:

- Standalone Mode
- Connected Mode
- Simulation Mode
- Playback Mode
- Read-Only Mode
- Demonstration Mode

Mode transitions shall preserve instrument integrity.

---

# 6. Remote Control

While connected, OEP Studio may control:

- Measurement Mode
- Probe State
- Recording
- Playback
- Session Binding
- Instrument Configuration

The companion application shall remain responsible for local presentation and operator interaction.

---

# 7. Session Synchronization

The synchronization engine shall maintain:

- Active Session Identifier
- Instrument State
- Probe Assignments
- Measurement Values
- Recording Status
- Playback Position
- Display Profile

Synchronization shall be deterministic and conflict-aware.

---

# 8. Communication Layer

Supported communication transports may include:

- Bluetooth Low Energy
- Wi-Fi
- USB
- Ethernet
- Future OEP Instrument Bus

Transport selection shall not alter application behavior.

---

# 9. Offline Operation

When disconnected from OEP Studio, the companion application may:

- Continue displaying locally available data.
- Replay recorded sessions.
- Allow configuration changes.
- Queue synchronization requests.

Offline operation shall never fabricate engineering measurements.

---

# 10. Security

The architecture shall support:

- Device Authentication
- Session Authorization
- Encrypted Communication
- Trusted Device Registry
- Secure Reconnection

Unauthorized devices shall not participate in Engineering Sessions.

---

# 11. Integration

The Companion Device Architecture integrates with:

- Measurement Engine
- Engineering Sessions
- Diagram Studio
- Simulation Engine
- Recording & Playback
- Publishing
- Future OEP Instruments

---

# 12. Acceptance Criteria

- Remote synchronization is deterministic.
- Companion presentation matches OEP Studio.
- Offline operation preserves engineering integrity.
- Communication is transport-independent.
- Security requirements are satisfied.
- Future instruments require no architectural redesign.

---

End of Document
