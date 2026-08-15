# OEP Instruments Runtime Architecture

Document ID:
OIP-ARCH-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the architecture of the OEP Instruments Runtime.

The runtime provides a platform-independent execution environment for engineering instruments while remaining completely independent from engineering computation.

The runtime is responsible for instrument lifecycle management, communication, session management, plugin loading, synchronization, and presentation orchestration.

---

# 2. Goals

The runtime shall:

• Discover Hosts

• Establish Connections

• Authenticate Sessions

• Load Instrument Plugins

• Route Messages

• Synchronize Instrument State

• Manage Instrument Lifecycles

• Coordinate Multiple Instruments

• Coordinate Multiple Clients

The runtime shall never calculate engineering values.

---

# 3. High-Level Architecture

                    OEP Platform

                          │

                  Diagram Studio

                          │

                 Instrument Host API

                          │

═══════════════════════════════════════════════

                OEP Instrument Protocol

═══════════════════════════════════════════════

                          │

              OEP Instruments Runtime

                          │

        ┌──────────┬──────────┬──────────┐

        │Session   │Plugin    │Transport │

        │Manager   │Manager   │Manager   │

        └──────────┴──────────┴──────────┘

                          │

              Instrument Plugins

                          │

      Digital Multimeter

      Oscilloscope

      Logic Probe

      CAN Analyzer

      LIN Analyzer

      Future Instruments

---

# 4. Runtime Responsibilities

The runtime is responsible for:

Host Discovery

Connection Management

Authentication

Session Lifecycle

Transport Selection

Plugin Discovery

Plugin Loading

Instrument Coordination

Message Routing

Configuration

Layout Persistence

History Persistence

Bookmark Persistence

Instrument Synchronization

Connection Recovery

Error Reporting

Logging

---

# 5. Responsibilities Not Owned

The runtime shall never perform:

Simulation

Verification

Engineering Analysis

Knowledge Graph Queries

Signal Propagation

Reasoning

Publishing

Repository Transactions

Engineering Persistence

These remain inside OEP.

---

# 6. Runtime Components

The runtime consists of:

Host Manager

Transport Manager

Session Manager

Plugin Manager

Instrument Manager

Message Router

Configuration Manager

Layout Manager

History Manager

Bookmark Manager

Logging Manager

Diagnostics Manager

Update Manager

---

# 7. Host Manager

Responsible for:

Host discovery

Pairing

Authentication

Host capabilities

Host version

Connection monitoring

Automatic reconnection

---

# 8. Session Manager

Responsible for:

Creating Sessions

Closing Sessions

Session persistence

Session synchronization

Session ownership

Session recovery

Only one Host controls a Session.

A Host may own multiple Sessions.

---

# 9. Plugin Manager

Responsible for:

Plugin discovery

Plugin registration

Version compatibility

Loading

Unloading

Dependency validation

Plugin lifecycle

Plugins remain isolated.

---

# 10. Instrument Manager

Responsible for:

Instrument creation

Instrument destruction

Instrument configuration

Visibility

Docking

Window state

Focus

Input routing

No engineering calculations.

---

# 11. Message Router

Responsible for:

Receiving messages

Routing messages

Dispatching updates

Streaming values

Ordering

Guaranteed delivery (when supported)

No engineering interpretation.

---

# 12. Transport Manager

Responsible for:

USB

Wi-Fi

Bluetooth

Ethernet

Future transports

Transport abstraction

Automatic reconnection

Bandwidth reporting

Latency reporting

---

# 13. Configuration Manager

Stores:

Preferences

Instrument settings

Host settings

Themes

Layouts

Transport preferences

Measurement preferences

No engineering data.

---

# 14. History Manager

Stores:

Measurement history

Session history

Timeline

Bookmarks

Recent Hosts

Recent Instruments

---

# 15. Diagnostics Manager

Reports runtime health.

Examples:

Disconnected Host

Plugin failure

Transport latency

Protocol mismatch

Authentication failure

Version mismatch

Runtime errors

No engineering diagnostics.

---

# 16. Plugin Architecture

Each plugin exposes:

Metadata

Capabilities

Supported Modes

Supported Measurements

Commands

UI

Configuration

Lifecycle Hooks

The runtime provides every shared service.

---

# 17. Instrument Lifecycle

Install

↓

Register

↓

Discover

↓

Initialize

↓

Connect

↓

Operate

↓

Suspend

↓

Resume

↓

Shutdown

↓

Unload

---

# 18. Multi-Instrument Operation

The runtime shall support:

One Host

↓

Many Instruments

One Instrument

↓

Many Views

Many Instruments

↓

Many Clients

Many Clients

↓

One Session

---

# 19. Multi-Client Architecture

Example:

Desktop

↓

Android Phone

↓

Android Tablet

↓

Windows Tablet

↓

Embedded Display

All synchronized through the Host.

---

# 20. Future Hardware

The runtime shall support hardware-backed instruments without architectural changes.

Examples:

Bluetooth Multimeter

USB Oscilloscope

CAN Interface

LIN Interface

Bench Supply

Signal Generator

Future hardware shall implement existing plugin interfaces.

---

# 21. Failure Recovery

Recover from:

Transport interruption

Host restart

Session interruption

Plugin crash

Instrument crash

Version mismatch

Authentication timeout

Recovery shall preserve user state whenever possible.

---

# 22. Performance

Target:

Sub-50 ms interaction latency

Continuous streaming

Multiple simultaneous instruments

Large engineering projects

No UI blocking

Incremental updates

---

# 23. Extensibility

New capabilities shall require:

New Plugin

or

New Transport

or

New Host

No runtime redesign.

---

# 24. Architectural Principles

1.

Runtime owns presentation.

2.

Host owns engineering.

3.

Plugins own instruments.

4.

Protocol owns communication.

5.

Transport remains abstract.

6.

Sessions own state.

7.

Engineering values remain immutable once received.

8.

Runtime never computes engineering information.

---

End of Document