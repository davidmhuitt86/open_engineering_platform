# OEP Instrument Protocol (OIP)

Document ID:
OIP-SPEC-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

The OEP Instrument Protocol (OIP) defines the communication protocol between an OEP Host and one or more OEP Instrument Clients.

The protocol provides transport-independent, deterministic communication for engineering instruments.

OIP shall not contain engineering logic.

OIP transports engineering information.

---

# 2. Goals

OIP shall support:

• Host discovery

• Authentication

• Session establishment

• Instrument discovery

• Instrument control

• Measurement requests

• Live streaming

• Playback synchronization

• Simulation synchronization

• Fault injection

• Diagnostics

• Configuration

• Notifications

---

# 3. Design Principles

The protocol shall be:

Deterministic

Stateless between messages

Session-oriented

Transport independent

Versioned

Extensible

Platform independent

Human readable where practical

---

# 4. Architecture

             Diagram Studio

                    │

             Instrument Host

                    │

══════════════════════════════

        OEP Instrument Protocol

══════════════════════════════

                    │

        Instrument Runtime

                    │

       Instrument Plugins

---

# 5. Engineering Authority

The Host owns engineering truth.

Instrument Clients display engineering truth.

Clients shall never modify engineering values.

Clients request.

Hosts respond.

---

# 6. Message Model

Every message contains:

Protocol Version

Message Type

Session ID

Message ID

Timestamp

Payload

Optional Metadata

---

# 7. Message Categories

Connection

Authentication

Session

Discovery

Measurement

Simulation

Playback

Diagnostics

Instrument

Configuration

History

Notification

Error

Heartbeat

---

# 8. Connection Flow

Discover Host

↓

Connect

↓

Authenticate

↓

Exchange Versions

↓

Create Session

↓

Discover Instruments

↓

Ready

---

# 9. Discovery Messages

Host Advertisement

Host Request

Host Response

Capability List

Supported Instruments

Supported Protocol Version

---

# 10. Authentication

Support:

Pairing

Trusted Device

Session Token

Reconnection

Future certificate authentication.

---

# 11. Session Messages

Create Session

Resume Session

Close Session

Pause Session

Transfer Session

Synchronize Session

---

# 12. Instrument Discovery

Host provides:

Instrument Identifier

Name

Version

Capabilities

Supported Modes

Configuration Schema

Status

---

# 13. Instrument Commands

Initialize

Shutdown

Enable

Disable

Activate

Deactivate

Reset

Update Configuration

---

# 14. Measurement Messages

Request Measurement

Measurement Result

Measurement Update

Measurement Complete

Measurement Failed

Cancel Measurement

---

# 15. Streaming

Support:

Continuous updates

Live simulation

Live hardware

Playback synchronization

Periodic updates

Event-driven updates

---

# 16. Playback

Commands:

Play

Pause

Resume

Reset

Step

Jump

Bookmark

Replay

Speed

---

# 17. Simulation

Host sends:

Simulation Started

Simulation Paused

Simulation Resumed

Simulation Reset

Simulation Finished

Fault Injected

Fault Cleared

---

# 18. Fault Messages

Inject Fault

Clear Fault

Fault Active

Fault Cleared

Fault Report

---

# 19. Diagnostics

Host may publish:

Warnings

Errors

Recommendations

Verification Results

Simulation Reports

Propagation Reports

Power Reports

Ground Reports

---

# 20. Instrument State

States:

Disconnected

Connecting

Authenticating

Ready

Busy

Streaming

Paused

Error

Offline

---

# 21. Configuration

Messages:

Load Configuration

Save Configuration

Reset Configuration

Configuration Changed

---

# 22. Notifications

Examples:

Host Connected

Host Lost

Session Created

Instrument Ready

Measurement Complete

Battery Low (future hardware)

Transport Warning

---

# 23. Error Messages

Every error contains:

Code

Severity

Description

Recoverable

Suggested Action

---

# 24. Heartbeat

Support:

Heartbeat Request

Heartbeat Response

Latency Measurement

Connection Health

Automatic timeout detection

---

# 25. Version Negotiation

During connection:

Host Version

↓

Client Version

↓

Highest Compatible Version

↓

Session Starts

No compatible version:

↓

Connection Refused

---

# 26. Extensibility

New message types shall not invalidate older protocol versions.

Unknown messages shall be safely ignored when possible.

Protocol evolution shall remain backward compatible whenever practical.

---

# 27. Transport Independence

OIP shall not depend on:

USB

Bluetooth

Wi-Fi

Ethernet

Serial

Named Pipes

Future transports

Transport adapters perform framing.

OIP defines messages only.

---

# 28. Performance

Target:

Sub-20 ms message latency

Streaming support

Large engineering sessions

Multiple simultaneous instruments

Multiple simultaneous clients

---

# 29. Security

Only authenticated Hosts may establish Sessions.

Clients verify Host identity.

Replay attacks shall be prevented.

Sessions expire automatically.

Future cryptographic extensions shall not require protocol redesign.

---

# 30. Long-Term Vision

The same protocol shall support:

Diagram Studio

Repair Studio

Service Studio

Training Studio

Simulation

Real hardware

Wireless Divad accessories

Third-party engineering devices

without protocol redesign.

---

# 31. Core Principles

1.

Hosts own engineering truth.

2.

Clients display engineering truth.

3.

Protocol transports information.

4.

Transport is abstract.

5.

Messages are deterministic.

6.

Sessions own communication.

7.

Engineering values are immutable.

8.

Protocol evolution preserves compatibility.

---

End of Document