# OEP Instrument Session Management Architecture

Document ID:
OIP-SESSION-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the Session Architecture for the OEP Instruments platform.

Every interaction between an OEP Host and one or more Instrument Clients occurs inside an Engineering Instrument Session.

A Session is the authoritative runtime context for communication, synchronization, measurement state, playback state, instrument configuration, and client coordination.

No communication shall exist outside an active Session.

---

# 2. Philosophy

A Session represents an engineering activity.

Examples:

Vehicle diagnosis

Simulation playback

Circuit verification

Signal tracing

Power analysis

Training exercise

Engineering review

The Session persists while instruments may connect and disconnect freely.

---

# 3. Architecture

Diagram Studio

↓

Instrument Host API

↓

Session Manager

↓

══════════════════════

Engineering Session

══════════════════════

↓

Runtime

↓

Connected Instruments

↓

Android Phone

Android Tablet

Windows Tablet

Future Devices

---

# 4. Session Responsibilities

The Session owns:

Connected Clients

Connected Instruments

Authentication

Measurement State

Playback State

Simulation State

History

Bookmarks

Current Selection

Shared Instrument State

Synchronization

Session Metadata

No engineering calculations.

---

# 5. Session Lifecycle

Created

↓

Authenticated

↓

Initialized

↓

Running

↓

Paused

↓

Resumed

↓

Completed

↓

Archived

↓

Destroyed

Every state transition shall be deterministic.

---

# 6. Session Creation

A Session may be created by:

Diagram Studio

Future Repair Studio

Future Training Studio

Future Service Studio

Future Engineering Applications

Clients shall never create Sessions independently.

---

# 7. Session Identity

Each Session contains:

Session Identifier

Host Identifier

Owner

Creation Time

Last Activity

Project Identifier

Diagram Identifier

Simulation Identifier (optional)

Playback Identifier (optional)

Version

Status

---

# 8. Session Ownership

One Host owns a Session.

A Session may contain multiple Clients.

Clients never own Sessions.

Ownership may be transferred only through Host authorization.

---

# 9. Client Participation

Clients may:

Join

Leave

Reconnect

Suspend

Resume

Clients may freely disconnect without terminating the Session.

---

# 10. Instrument Participation

A Session may contain:

One Instrument

Many Instruments

Many instances of one Instrument

Different instrument types

The Runtime coordinates synchronization.

---

# 11. Shared Engineering State

The Session synchronizes:

Current Project

Current Diagram

Current Selection

Current Simulation Tick

Playback Position

Fault State

Highlighted Paths

Probe Locations

Measurement Targets

Every client observes identical engineering state.

---

# 12. Instrument State

Each Instrument maintains:

Configuration

Visibility

Window State

Measurement Mode

Current Measurement

History

Bookmarks

The Session synchronizes shared state only.

---

# 13. Measurement State

The Session stores:

Active Measurements

Completed Measurements

Continuous Streams

Probe Locations

Expected Values

Measured Values

Comparison Values

Measurement History

---

# 14. Probe Synchronization

Probe movement shall synchronize across every connected Client.

Example:

Phone moves Probe A

↓

Diagram Studio updates

↓

Tablet updates

↓

Second Phone updates

Every participant observes identical probe placement.

---

# 15. Playback Synchronization

The Session synchronizes:

Play

Pause

Resume

Reset

Step

Replay

Timeline Position

Playback Speed

Bookmark Selection

---

# 16. Fault Synchronization

The Session synchronizes:

Injected Faults

Removed Faults

Fault Categories

Fault Locations

Fault History

Every client observes identical fault state.

---

# 17. Selection Synchronization

Selection changes synchronize immediately.

Examples:

Object Selection

Relationship Selection

Connector Selection

Pin Selection

Measurement Target

Highlighted Path

Current Instrument

---

# 18. History

Each Session stores:

Measurement History

Simulation History

Playback History

Selection History

Fault History

Connection History

History remains available for export.

---

# 19. Bookmarks

Bookmarks include:

Probe Locations

Simulation Positions

Engineering Objects

Measurement Targets

Playback Timeline

User Notes

Bookmarks belong to the Session.

---

# 20. Notifications

Session publishes:

Client Joined

Client Left

Instrument Activated

Measurement Started

Measurement Updated

Playback Changed

Simulation Changed

Fault Changed

Session Paused

Session Closed

---

# 21. Recovery

Recover from:

Client Disconnect

Transport Failure

Host Restart

Instrument Restart

Network Loss

Temporary Suspension

Recovery shall preserve Session state whenever possible.

---

# 22. Persistence

Sessions may be:

Transient

Persistent

Archived

Imported

Exported

Persistent Sessions may later become Engineering Records.

---

# 23. Multi-Client Example

Diagram Studio

↓

Engineering Session

↓

Android Phone

Digital Multimeter

↓

Android Tablet

Oscilloscope

↓

Windows Tablet

CAN Analyzer

↓

Embedded Display

Power Monitor

All synchronized.

---

# 24. Performance

Target:

Immediate synchronization

Low-latency updates

Incremental state transfer

Minimal bandwidth

No duplicated engineering messages

---

# 25. Security

Sessions require:

Authenticated Host

Authenticated Clients

Authorized Instruments

Session Tokens

Timeout Detection

Expired Sessions shall terminate automatically.

---

# 26. Future Expansion

Future Sessions may support:

Collaborative Engineering

Instructor / Student

Multiple Engineers

Cloud Synchronization

Remote Assistance

Shared Engineering Reviews

No Session redesign required.

---

# 27. Core Principles

1.

Sessions own interaction.

2.

Hosts own engineering.

3.

Clients own presentation.

4.

Measurements belong to Sessions.

5.

History belongs to Sessions.

6.

Bookmarks belong to Sessions.

7.

Synchronization remains deterministic.

8.

Clients may come and go without destroying the Session.

---

End of Document