# OEP Instrument State Machine

Document ID:
OIP-STATE-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the runtime state machine governing every instrument within the OEP Instruments platform.

The state machine describes the operational behavior of an instrument while it is executing.

This document is distinct from the Instrument Lifecycle Architecture.

Lifecycle defines the existence of an instrument.

State defines what the instrument is currently doing.

---

# 2. Philosophy

Every instrument behaves as a deterministic finite state machine.

At any moment an instrument occupies one and only one operational state.

State transitions occur only in response to defined events.

Undefined transitions are prohibited.

---

# 3. Objectives

The state machine shall be:

Deterministic

Observable

Recoverable

Testable

Platform Independent

Extensible

---

# 4. State Hierarchy

The operational state machine consists of:

Idle

↓

Waiting

↓

Measuring

↓

Holding

↓

Recording

↓

Playback

↓

Paused

↓

Fault

↓

Recovering

↓

Shutdown

Only one state may be active at any time.

---

# 5. Idle

The instrument is operational but inactive.

Characteristics:

No active measurement

No playback

No recording

No engineering computation

Waiting for user or Host activity.

---

# 6. Waiting

The instrument awaits an external condition.

Examples:

Probe placement

Host response

Simulation step

Transport availability

Session synchronization

The instrument remains responsive to user interaction.

---

# 7. Measuring

The instrument is actively presenting engineering measurements.

Examples:

Voltage

Current

Resistance

Waveforms

Bus Traffic

Logic Levels

Power Distribution

Measurements update continuously according to the active Session.

---

# 8. Holding

Measurement updates are suspended.

The displayed measurement remains fixed.

Engineering data continues to exist at the Host.

Only presentation is frozen.

---

# 9. Recording

The instrument records engineering information.

Examples:

Measurements

Waveforms

Bus Frames

Events

Timeline Data

Recording shall not alter measurement behavior.

---

# 10. Playback

Previously recorded engineering information is replayed.

Playback may include:

Pause

Resume

Step Forward

Step Backward

Jump

Playback Speed

Playback never modifies recorded data.

---

# 11. Paused

Active activity temporarily stops.

Examples:

Simulation paused

Playback paused

Streaming paused

Recording paused

Instrument configuration remains intact.

---

# 12. Fault

The instrument has encountered an abnormal operating condition.

Examples:

Transport failure

Host unavailable

Protocol mismatch

Plugin error

Runtime exception

Fault state preserves recoverable context.

---

# 13. Recovering

The instrument attempts automatic recovery.

Possible operations:

Reconnect

Resynchronize

Reload Session

Restore Measurement

Restore Playback

Recovery shall preserve engineering context whenever possible.

---

# 14. Shutdown

The instrument is terminating operation.

Operations include:

Stop measurement

Stop playback

Stop recording

Release runtime resources

Persist configuration

Shutdown completes before lifecycle unloading.

---

# 15. State Transitions

Examples:

Idle

↓

Measuring

Waiting

↓

Measuring

Measuring

↓

Holding

Holding

↓

Measuring

Measuring

↓

Recording

Recording

↓

Playback

Playback

↓

Paused

Paused

↓

Playback

Fault

↓

Recovering

Recovering

↓

Idle

Only documented transitions are permitted.

---

# 16. Transition Events

Transitions occur in response to events.

Examples:

User Input

Host Command

Transport Event

Session Event

Runtime Event

Measurement Event

Playback Event

Fault Event

Events shall be observable.

---

# 17. State Persistence

Operational state may be persisted where appropriate.

Examples:

Measurement Mode

Recording Status

Playback Position

Display Configuration

Hold State

Persistent state shall restore correctly after recovery.

---

# 18. State Observation

The Runtime shall expose:

Current State

Previous State

Transition Time

Transition Cause

State Duration

Observers shall receive deterministic notifications.

---

# 19. Illegal Transitions

Examples of prohibited transitions:

Idle

↓

Playback

without available playback data.

Recording

↓

Holding

without measurement capability.

Shutdown

↓

Measuring

without initialization.

Illegal transitions shall be rejected.

---

# 20. Error Handling

Fault conditions shall not corrupt state.

Recovery attempts shall preserve:

Measurements

Bookmarks

Session Association

Configuration

Playback Position

User interaction shall remain predictable.

---

# 21. Session Relationship

Operational state belongs to the instrument.

Engineering Session belongs to the Host.

Changing Session shall not require rebuilding the state machine.

---

# 22. Platform Consistency

The state machine shall remain identical across:

Android

Windows

Linux

Future iOS

Dedicated Hardware

Implementation details may differ while preserving identical behavior.

---

# 23. Extensibility

Future operational states may be introduced.

Existing states and transitions shall remain backward compatible.

Plugins written for earlier state-machine versions shall continue to function.

---

# 24. Core Principles

1.

Every instrument behaves as a deterministic state machine.

2.

Only one operational state exists at a time.

3.

State transitions occur only through defined events.

4.

Illegal transitions are prohibited.

5.

Recovery preserves engineering context.

6.

Operational state is independent of lifecycle state.

7.

State observation is always available.

8.

Every OEP Instrument shares the same operational state model.

---

End of Document