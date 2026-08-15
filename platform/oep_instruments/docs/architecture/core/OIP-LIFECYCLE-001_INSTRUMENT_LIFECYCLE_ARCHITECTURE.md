# OEP Instrument Lifecycle Architecture

Document ID:
OIP-LIFECYCLE-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the lifecycle of every instrument within the OEP Instruments platform.

Every instrument shall follow an identical lifecycle regardless of:

• Instrument type

• Host platform

• Communication transport

• Engineering data source

The lifecycle governs the operational state of the instrument, not the engineering session.

---

# 2. Philosophy

An instrument is a living runtime component.

It is:

Discovered

Loaded

Initialized

Connected

Operated

Suspended

Resumed

Disconnected

Unloaded

Destroyed

Every instrument shall follow the same lifecycle.

---

# 3. Objectives

The lifecycle architecture shall be:

Deterministic

Observable

Recoverable

Transport Independent

Plugin Independent

Host Independent

Extensible

---

# 4. Lifecycle States

Every instrument shall exist in one and only one state.

States:

Not Installed

↓

Installed

↓

Discovered

↓

Loaded

↓

Initializing

↓

Ready

↓

Connected

↓

Active

↓

Paused

↓

Disconnected

↓

Unloaded

↓

Destroyed

---

# 5. Not Installed

The runtime has no knowledge of the instrument.

No resources exist.

No registration exists.

---

# 6. Installed

The plugin exists on the client.

Metadata is available.

No runtime resources have been allocated.

---

# 7. Discovered

The Instrument Runtime has identified the plugin.

The following information becomes available:

Identifier

Version

Capabilities

Requirements

Supported Hosts

Supported Platforms

No execution occurs.

---

# 8. Loaded

The runtime loads the instrument.

Operations include:

Allocate resources

Load assets

Register commands

Register capabilities

Register views

No engineering communication begins.

---

# 9. Initializing

Initialization prepares the instrument.

Examples:

Load preferences

Restore layout

Restore history

Verify compatibility

Acquire runtime services

Initialization shall be repeatable.

---

# 10. Ready

The instrument is prepared for operation.

Waiting for:

Host Connection

Engineering Session

User Interaction

No measurements occur.

---

# 11. Connected

The instrument establishes communication with a Host.

Initialization includes:

Protocol negotiation

Capability negotiation

Session synchronization

Transport verification

Connection health monitoring

The instrument remains idle until activated.

---

# 12. Active

The instrument is operational.

Examples:

Displaying measurements

Receiving updates

Streaming

Playback

Recording

Responding to user input

Only Active instruments receive engineering updates.

---

# 13. Paused

The instrument remains connected.

Engineering state is preserved.

Streaming stops.

Measurements freeze.

Playback pauses.

Resume shall restore the previous operational state.

---

# 14. Disconnected

Communication with the Host has ended.

Possible causes:

User Request

Host Shutdown

Transport Failure

Authentication Failure

Network Loss

Disconnected instruments preserve recoverable state.

---

# 15. Unloaded

Runtime resources are released.

Operations include:

Stop timers

Release memory

Unregister commands

Dispose views

Terminate background tasks

Persistent data remains intact.

---

# 16. Destroyed

All runtime state has been removed.

The runtime returns to the Installed state if the plugin remains available.

---

# 17. Lifecycle Events

The runtime publishes lifecycle events.

Examples:

Instrument Loaded

Instrument Ready

Connection Established

Connection Lost

Instrument Paused

Instrument Resumed

Instrument Closed

Events shall be observable.

---

# 18. Error Recovery

Lifecycle failures shall recover whenever possible.

Examples:

Reconnect

Reinitialize

Reload

Restore Session

Retry Negotiation

Recovery shall never corrupt engineering state.

---

# 19. State Validation

Illegal transitions shall be rejected.

Examples:

Ready

↓

Destroyed

without unloading

or

Not Installed

↓

Connected

shall not be permitted.

The runtime validates every transition.

---

# 20. Session Relationship

The Instrument Lifecycle is independent of the Engineering Session.

An instrument may:

Join a Session

Leave a Session

Reconnect to a Session

without restarting its lifecycle.

---

# 21. Platform Consistency

The lifecycle shall remain identical across:

Android

Windows

Linux

Future iOS

Dedicated Hardware

Platform implementation details shall remain internal.

---

# 22. Extensibility

Future lifecycle states may be introduced.

Existing transitions shall remain backward compatible.

Plugins written against previous lifecycle versions shall continue to operate.

---

# 23. Core Principles

1.

Every instrument follows one deterministic lifecycle.

2.

Only one lifecycle state exists at any time.

3.

Lifecycle state is independent of engineering state.

4.

Recovery preserves user context whenever possible.

5.

Illegal transitions are prohibited.

6.

Lifecycle events are observable.

7.

Platform differences remain implementation details.

8.

Every future instrument inherits the same lifecycle architecture.

---

End of Document