# OEP Instrument Transport Layer Architecture

Document ID:
OIP-TRANSPORT-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the Transport Layer Architecture for OEP Instruments.

The Transport Layer provides reliable communication between an OEP Host and one or more Instrument Clients.

The Transport Layer is responsible only for moving OEP Instrument Protocol (OIP) messages.

It shall never interpret engineering data.

---

# 2. Philosophy

The protocol defines communication.

The transport moves communication.

The transport shall never understand engineering semantics.

A transport is interchangeable.

Replacing USB with Wi-Fi shall require no Host, Runtime, or Plugin modifications.

---

# 3. Architectural Position

Diagram Studio

↓

Host API

↓

OEP Instrument Protocol

↓

═══════════════════════

Transport Layer

═══════════════════════

↓

USB

Wi-Fi

Bluetooth

Ethernet

Future transports

---

# 4. Responsibilities

The Transport Layer owns:

Device discovery

Connection establishment

Connection monitoring

Message framing

Reliable delivery

Latency measurement

Bandwidth reporting

Reconnection

Connection health

Transport diagnostics

No engineering computation.

---

# 5. Responsibilities Not Owned

The Transport Layer shall never perform:

Authentication

Engineering calculations

Simulation

Verification

Session management

Instrument management

Plugin loading

History

Bookmarks

Rendering

These belong to higher layers.

---

# 6. Transport Interface

Every transport implements:

Initialize()

Shutdown()

Discover()

Connect()

Disconnect()

Reconnect()

Send()

Receive()

Flush()

Status()

Capabilities()

The Runtime communicates only with this interface.

---

# 7. Supported Transports

Initial targets:

USB-C

Wi-Fi (LAN)

Future:

Bluetooth

Ethernet

USB Serial

Named Pipes

Cloud Relay

Future transports shall implement the common interface.

---

# 8. Discovery

Transport discovery provides:

Device Identifier

Host Name

Transport Type

Signal Strength (if applicable)

Connection State

Latency Estimate

Supported Protocol Version

Capabilities

---

# 9. Connection Lifecycle

Disconnected

↓

Discovering

↓

Connecting

↓

Connected

↓

Authenticated

↓

Streaming

↓

Suspended

↓

Reconnecting

↓

Disconnected

The Transport Layer reports state only.

---

# 10. Message Delivery

Transport shall support:

Point-to-point

One-to-many

Many-to-one

Streaming

Burst delivery

Incremental delivery

Ordered delivery

---

# 11. Framing

The Transport Layer is responsible for:

Message boundaries

Fragmentation

Reassembly

Checksums (transport-specific)

Timeout detection

Retry policy (where appropriate)

OIP remains unaware of framing.

---

# 12. Reliability

Transport shall detect:

Dropped connection

Partial transmission

Timeout

Duplicate packets

Out-of-order packets

Recovery shall be transport-specific.

---

# 13. Latency

Transport reports:

Current latency

Average latency

Peak latency

Round-trip time

Bandwidth

Packet loss (where applicable)

This information is available to the Runtime for diagnostics.

---

# 14. Streaming

Support:

Continuous measurement updates

Simulation playback

Oscilloscope waveforms

CAN frame streams

Power monitoring

Streaming shall remain incremental.

---

# 15. Multiple Connections

One Host may communicate with:

Multiple phones

Multiple tablets

Embedded displays

Future dedicated instruments

Each transport instance remains independent.

---

# 16. Automatic Reconnection

If a connection is lost:

Attempt reconnection

Restore transport

Restore session association

Resume streaming

Notify Runtime

No engineering state is recreated by the Transport Layer.

---

# 17. Transport Diagnostics

Expose:

Connection quality

Bandwidth

Latency

Packet count

Reconnect count

Transport errors

Last activity

These diagnostics are transport-only.

---

# 18. Security

Transport shall support secure channels where applicable.

Authentication remains above the Transport Layer.

Transport shall never authorize engineering operations.

---

# 19. Transport Selection

The Runtime may select transports based on:

User preference

Availability

Priority

Performance

Policy

Example default priority:

USB-C

↓

Wi-Fi

↓

Bluetooth

Transport selection remains configurable.

---

# 20. Performance Goals

Target:

Sub-10 ms local transport latency (USB)

Sub-25 ms LAN latency

Continuous streaming

Multiple simultaneous instruments

No unnecessary buffering

Incremental updates

---

# 21. Extensibility

Adding a transport shall require:

Transport implementation

Registration

Testing

No Runtime redesign

No Protocol redesign

No Plugin redesign

---

# 22. Future Hardware

Future devices include:

Dedicated Divad handheld meter

Wireless oscilloscope

CAN interface

Bench supply

Logic analyzer

Industrial gateway

All communicate through the same Transport interface.

---

# 23. Failure Handling

Handle:

Cable unplugged

Wi-Fi loss

Bluetooth disconnect

Transport initialization failure

Unsupported transport

Host unavailable

Failures are reported upward.

Recovery decisions belong to the Runtime.

---

# 24. Core Principles

1.

Transport moves data.

2.

Transport never understands engineering.

3.

Transport is interchangeable.

4.

Protocol is transport independent.

5.

Runtime owns transport selection.

6.

Authentication belongs above transport.

7.

Sessions survive transport interruption when possible.

8.

Future transports require no architectural redesign.

---

End of Document