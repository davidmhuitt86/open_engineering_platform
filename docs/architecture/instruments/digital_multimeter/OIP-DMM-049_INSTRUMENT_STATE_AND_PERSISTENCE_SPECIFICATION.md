# OEP Digital Multimeter Instrument State & Persistence Specification

**Document ID:** OIP-DMM-049
**Status:** Draft
**Repository:** oep_instruments

---

# 1. Purpose

This specification defines the Instrument State and Persistence Architecture for the OEP Digital Multimeter.

The subsystem is responsible for capturing, restoring, and maintaining the operational state of the instrument across application restarts, Engineering Session transitions, device interruptions, and future dedicated hardware power cycles. State persistence shall preserve operator workflow while ensuring engineering integrity.

---

# 2. Scope

This specification applies to:

- Android
- Windows
- Linux
- Future iOS
- Future Dedicated Hardware
- Engineering Sessions
- Recording & Playback

---

# 3. Design Objectives

The subsystem shall:

- Preserve deterministic instrument behavior.
- Restore interrupted workflows safely.
- Separate transient runtime state from persistent configuration.
- Maintain Engineering Session integrity.
- Support future distributed synchronization.

---

# 4. Instrument State Model

The instrument state shall consist of:

- Active Measurement Mode
- Instrument Operating State
- Auto/Manual Range Status
- Probe Assignments
- Active Engineering Session
- Recording Status
- Playback Status
- Active Display Profile
- Accessibility State
- Communications State

Every state element shall have a defined owner.

---

# 5. Runtime State

Runtime state includes information that exists only while the instrument is active.

Examples:

- Current Measurement
- Live Probe Attachments
- Active Simulation Time
- Playback Position
- Temporary UI State

Runtime state shall not be permanently stored unless explicitly requested.

---

# 6. Persistent State

Persistent state may include:

- User Preferences
- Instrument Configuration
- Theme
- Display Profile
- Preferred Measurement Mode
- Calibration References
- Trusted Smart Probes

Persistent state shall survive application restarts.

---

# 7. Session Restoration

If an Engineering Session is recoverable, the instrument may restore:

- Active Session Identifier
- Probe Assignments
- Measurement Mode
- Recording State
- Playback Position
- Timeline Position

Restoration shall never fabricate missing engineering data.

---

# 8. Recovery

Following an unexpected interruption, the subsystem shall determine whether to:

- Resume Session
- Resume Recording
- Resume Playback
- Restore Configuration
- Enter Safe Startup

Recovery decisions shall be deterministic.

---

# 9. State Versioning

Persisted state shall include:

- Schema Version
- Creation Timestamp
- Last Modified Timestamp
- Compatibility Information

Unsupported versions shall trigger migration or safe recovery.

---

# 10. Integration

The State & Persistence subsystem integrates with:

- Measurement Engine
- Engineering Sessions
- Probe Manager
- Recording & Playback
- Settings
- Publishing
- Simulation Engine

State restoration shall not interrupt valid Engineering Sessions.

---

# 11. Acceptance Criteria

- Runtime and persistent state remain distinct.
- State restoration is deterministic.
- Interrupted sessions recover safely.
- Configuration persists correctly.
- Version migration is supported.
- Platform-independent behavior is maintained.

---

End of Document
