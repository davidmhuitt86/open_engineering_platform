# OEP Instrument Host API

Document ID:
OIP-API-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

The Instrument Host API defines the interface exposed by an OEP Host to one or more Instrument Clients.

The Host API is the sole engineering interface between Diagram Studio and OEP Instruments.

No Instrument Client shall communicate directly with Foundation Runtime, Engineering Engine, Engineering Intelligence Platform, or Simulation Engine.

The Host API preserves complete separation between engineering computation and instrument presentation.

---

# 2. Architectural Position

                    Foundation Runtime

                           │

                    Engineering Engine

                           │

             Engineering Intelligence Platform

                           │

                    Diagram Studio

                           │

                 Instrument Host API

                           │

═══════════════════════════════════════════════

                OEP Instrument Protocol

═══════════════════════════════════════════════

                           │

                 OEP Instrument Runtime

                           │

                  Instrument Clients

---

# 3. Responsibilities

The Host API is responsible for:

Session creation

Authentication

Instrument discovery

Measurement requests

Measurement streaming

Simulation synchronization

Playback synchronization

Fault synchronization

Publishing engineering events

Configuration

Diagnostics

Notifications

---

# 4. Responsibilities Not Owned

The Host API shall never perform:

Engineering calculations

Simulation

Verification

Knowledge graph traversal

Reasoning

Diagnostics generation

Publishing

Repository management

Package management

Persistence

Those remain inside Diagram Studio and OEP.

---

# 5. Engineering Authority

Diagram Studio remains the engineering authority.

The Host API exposes engineering services.

The Host API never exposes engineering implementation.

Clients receive results only.

---

# 6. Host Lifecycle

Host Startup

↓

Host Ready

↓

Accept Clients

↓

Authenticate

↓

Create Session

↓

Publish Capabilities

↓

Operate

↓

Shutdown

---

# 7. Session Services

Expose:

Create Session

Resume Session

Close Session

Enumerate Sessions

Transfer Session

Synchronize Session

Session History

---

# 8. Instrument Services

Expose:

Enumerate Instruments

Instrument Status

Instrument Capabilities

Instrument Configuration

Instrument Activation

Instrument Shutdown

Instrument Reset

---

# 9. Measurement Services

Support:

Begin Measurement

Cancel Measurement

Continuous Measurement

Expected Measurement

Historical Measurement

Measurement Comparison

Measurement History

Measurement Bookmarks

The Host computes.

The Client displays.

---

# 10. Simulation Services

Expose:

Simulation State

Simulation Timeline

Playback Control

Simulation Speed

Current Tick

Replay

Fault Injection Events

---

# 11. Diagnostics Services

Expose:

Verification Results

Fault Reports

Propagation Reports

Ground Reports

Power Reports

Recommendation Reports

Engineering Alerts

---

# 12. Engineering Object Services

Expose read-only access to:

Engineering Objects

Relationships

Measurement Targets

Pins

Connectors

Terminals

Wire Segments

Signal Names

Power Domains

Ground Domains

No modification permitted.

---

# 13. Selection Services

Expose:

Current Selection

Selection Changed

Probe Targets

Highlighted Objects

Highlighted Paths

Highlighted Relationships

---

# 14. Visualization Services

Expose:

Current View

Viewport

Zoom

Pan

Camera Position

Highlighted Regions

Overlay State

Visualization remains synchronized.

---

# 15. Notification Services

Host publishes:

Simulation Started

Simulation Finished

Playback Changed

Selection Changed

Measurement Updated

Recommendation Available

Fault Injected

Fault Cleared

Repository Changed

Project Loaded

Project Closed

---

# 16. Instrument Synchronization

Host maintains:

Current Instrument

Current Mode

Measurement State

Streaming State

Playback State

Fault State

Connected Clients

Every client receives the same synchronized engineering state.

---

# 17. Multi-Client Support

One Host

↓

Multiple Clients

Examples:

Desktop

↓

Android Phone

↓

Android Tablet

↓

Windows Tablet

↓

Future Embedded Device

All remain synchronized.

---

# 18. Read-Only Philosophy

Instrument Clients shall never modify engineering models.

They may request:

Measurements

Simulation Control

Playback Control

Fault Injection

Everything else remains read-only.

---

# 19. Event Model

Host publishes events.

Clients subscribe.

No polling shall be required for normal operation.

Events shall be ordered.

Events shall be deterministic.

---

# 20. Error Handling

Host reports:

Unavailable Service

Invalid Session

Authentication Failure

Transport Failure

Version Mismatch

Instrument Busy

Measurement Failure

Simulation Unavailable

Errors remain deterministic.

---

# 21. Version Compatibility

The Host API shall remain versioned independently from:

Transport

Android Client

Instrument Runtime

Protocol

Diagram Studio

Backward compatibility shall be maintained whenever practical.

---

# 22. Performance

Target:

Sub-50 ms measurement latency

Continuous streaming

Multiple simultaneous instruments

Multiple simultaneous clients

Incremental updates

No unnecessary message traffic

---

# 23. Security

Only authenticated clients receive engineering data.

Sessions expire.

Unauthorized requests are rejected.

Engineering data is never broadcast to anonymous devices.

---

# 24. Extensibility

Future Hosts may include:

Repair Studio

Service Studio

Training Studio

Field Inspector

Manufacturing Studio

No Instrument Client redesign shall be required.

---

# 25. Core Principles

1.

Diagram Studio owns engineering.

2.

Host API exposes engineering.

3.

Clients never calculate engineering values.

4.

Clients remain presentation-only.

5.

Engineering data is immutable once published.

6.

Events are deterministic.

7.

Sessions own interaction.

8.

The Host API remains independent of client platform.

---

End of Document