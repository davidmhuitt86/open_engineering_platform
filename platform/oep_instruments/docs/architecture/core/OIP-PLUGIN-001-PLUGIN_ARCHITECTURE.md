# OEP Instrument Plugin Architecture

Document ID:
OIP-PLUGIN-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the architecture for Instrument Plugins within the OEP Instruments platform.

Every engineering instrument shall be implemented as a Plugin.

The Runtime owns plugin lifecycle.

Plugins own instrument functionality.

The Runtime shall never require modification when new instruments are introduced.

---

# 2. Philosophy

Every engineering instrument is an independent application that executes inside the Instrument Runtime.

The Runtime provides infrastructure.

The Plugin provides instrument behavior.

Neither shall contain the other's responsibilities.

---

# 3. Architectural Position

Diagram Studio

↓

Instrument Host API

↓

OEP Instrument Protocol

↓

Instrument Runtime

↓

Plugin Manager

↓

Instrument Plugins

↓

Digital Multimeter

Oscilloscope

Logic Probe

CAN Analyzer

LIN Analyzer

Power Probe

Future Instruments

---

# 4. Runtime Responsibilities

The Runtime provides:

Plugin discovery

Plugin registration

Plugin loading

Plugin unloading

Session management

Configuration

Transport

Host communication

Theme

Localization

Logging

Diagnostics

Lifecycle management

The Runtime shall not implement any instrument behavior.

---

# 5. Plugin Responsibilities

Every Plugin owns:

Instrument UI

Measurement presentation

Instrument configuration

Interaction

Toolbars

Menus

Dialogs

Instrument-specific settings

Instrument-specific history

Instrument-specific bookmarks

No engineering computation.

---

# 6. Plugin Manifest

Every plugin shall provide metadata.

Required:

Plugin Identifier

Display Name

Version

Author

Description

Supported Protocol Version

Supported Runtime Version

Instrument Category

Capabilities

Dependencies

Entry Point

Icon

License

---

# 7. Plugin Categories

Initial categories:

Measurement

Analysis

Diagnostics

Communication

Monitoring

Future categories may be added.

---

# 8. Instrument Categories

Examples:

Digital Multimeter

Oscilloscope

Logic Probe

Power Probe

CAN Analyzer

LIN Analyzer

Signal Generator

Bench Power Supply

Breakout Box

Thermal Camera

Future instruments

---

# 9. Plugin Lifecycle

Installed

↓

Discovered

↓

Validated

↓

Loaded

↓

Initialized

↓

Activated

↓

Running

↓

Suspended

↓

Resumed

↓

Shutdown

↓

Unloaded

---

# 10. Initialization

During initialization the Runtime provides:

Host Connection

Current Session

Configuration

Theme

Localization

Capability Information

Available Services

The Plugin shall not establish Host connections directly.

---

# 11. User Interface

Each Plugin owns its own UI.

Examples:

Digital Multimeter

Seven-segment display

Rotary selector

Probe controls

History

Bookmarks

Oscilloscope

Waveform

Trigger

Channels

Measurements

Timebase

CAN Analyzer

Frame List

Filters

Decoder

Statistics

No Runtime modifications required.

---

# 12. Instrument Services

Plugins may request:

Measurements

Streaming

Playback

Simulation State

Selection

Visualization

History

Bookmarks

Through the Runtime only.

---

# 13. Plugin Isolation

Plugins shall not communicate directly.

All communication occurs through Runtime services.

Plugin failures shall not terminate other plugins.

---

# 14. Configuration

Each Plugin maintains:

Preferences

Layout

Display Units

Themes

Window State

Shortcuts

Bookmarks

History

Configuration shall remain isolated.

---

# 15. Instrument Modes

Plugins may support:

Standalone

Host Connected

Simulation

Playback

Live Hardware

Read Only

Inspection

Unavailable modes shall be disabled automatically.

---

# 16. Session Integration

Plugins participate in Runtime Sessions.

The Runtime provides:

Session Start

Session End

Session Pause

Session Resume

Session Transfer

Plugins shall not manage Sessions.

---

# 17. Event Model

Plugins subscribe to Runtime events.

Examples:

Measurement Updated

Selection Changed

Simulation Started

Playback Changed

Fault Injected

Session Closed

Events remain ordered.

---

# 18. Security

Plugins receive only authorized Host data.

Plugins shall never bypass Runtime authentication.

Plugins shall never communicate directly with Diagram Studio.

---

# 19. Version Compatibility

Each Plugin declares:

Minimum Runtime Version

Maximum Runtime Version

Supported Protocol Version

Supported Host API Version

Incompatible Plugins shall not load.

---

# 20. Error Handling

Plugins report:

Initialization Failure

Configuration Failure

Runtime Failure

Unsupported Capability

Host Disconnected

Transport Lost

Plugins shall fail independently.

---

# 21. Performance

Plugins shall:

Avoid blocking the UI

Use Runtime streaming

Avoid duplicate rendering

Release resources when inactive

Support incremental updates

---

# 22. Future Hardware

The same Plugin shall support:

Simulation

↓

Hardware

without redesign.

Example:

Digital Multimeter

Simulation Source

↓

Host

↓

Plugin

Bluetooth Meter

↓

Host

↓

Plugin

Vehicle

↓

Hardware Interface

↓

Host

↓

Plugin

The Plugin remains identical.

Only the Host data source changes.

---

# 23. Plugin API

Every Plugin shall expose:

Initialize()

Shutdown()

Activate()

Deactivate()

Suspend()

Resume()

Configuration()

Capabilities()

Metadata()

Render()

ReceiveEvent()

ReceiveMeasurement()

The Runtime owns invocation.

---

# 24. Extensibility

Future Plugins shall require:

Manifest

Registration

Implementation

No Runtime redesign.

---

# 25. Architectural Principles

1.

Runtime owns infrastructure.

2.

Plugins own instruments.

3.

Plugins never perform engineering computation.

4.

Plugins never communicate directly.

5.

Plugins receive engineering data.

6.

Plugins render engineering data.

7.

Plugins remain replaceable.

8.

Future instruments require no Runtime modification.

---

End of Document