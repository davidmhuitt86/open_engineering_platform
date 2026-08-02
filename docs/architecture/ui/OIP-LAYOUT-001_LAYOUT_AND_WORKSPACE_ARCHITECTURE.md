
# OEP Layout & Workspace Architecture

Document ID:
OIP-LAYOUT-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the layout architecture for every instrument within the OEP Instruments platform.

It establishes how information, controls, displays, workspaces, and engineering data are organized.

The objective is to create layouts that resemble dedicated professional engineering equipment while remaining adaptable to multiple screen sizes.

---

# 2. Philosophy

The layout shall serve the engineer.

The engineer shall never search for frequently used controls.

Primary engineering information shall always occupy the most prominent location.

Layout decisions shall reduce cognitive load.

---

# 3. Objectives

The layout architecture shall be:

Consistent

Predictable

Responsive

Professional

Accessible

Platform Independent

Expandable

---

# 4. Workspace Model

Every instrument consists of one or more Workspaces.

Examples:

Measurement Workspace

Configuration Workspace

History Workspace

Diagnostics Workspace

Playback Workspace

Calibration Workspace

Help Workspace

Each workspace shall have a clearly defined purpose.

---

# 5. Workspace Hierarchy

Workspace

↓

Primary Display

↓

Primary Controls

↓

Secondary Controls

↓

Status Area

↓

Supporting Information

The hierarchy shall remain visually consistent.

---

# 6. Primary Display Region

The Primary Display Region contains the instrument's most important engineering information.

Examples:

Measured Value

Waveform

CAN Frames

Logic State

Power Distribution

This region always receives visual priority.

---

# 7. Primary Control Region

The Primary Control Region contains controls required during normal operation.

Examples:

Rotary Selector

Probe Controls

Measurement Controls

Trigger Controls

Playback Controls

These controls shall remain immediately accessible.

---

# 8. Secondary Control Region

Secondary controls include:

Settings

Configuration

History

Export

Bookmarks

Calibration

These controls shall never compete with primary controls.

---

# 9. Status Region

Status information includes:

Connection

Session

Battery

Streaming

Recording

Simulation

Warnings

Errors

Status shall remain visible without distracting from engineering work.

---

# 10. Navigation

Navigation shall remain shallow.

Maximum structure:

Home

↓

Workspace

↓

Dialog

Deep menu hierarchies are prohibited.

---

# 11. Dialogs

Dialogs shall be used only for:

Confirmation

Configuration

Selection

Warnings

Help

Dialogs shall never interrupt measurement unless required for safety.

---

# 12. Instrument Home

Every instrument shall provide a Home workspace.

The Home workspace contains:

Instrument Overview

Recent Sessions

Connection Status

Recent Measurements

Quick Actions

Instrument Information

---

# 13. Landscape Layout

Landscape is the preferred orientation.

Priority:

Primary Display

↓

Primary Controls

↓

Status

↓

Secondary Information

Landscape shall maximize engineering visibility.

---

# 14. Portrait Layout

Portrait shall preserve:

Measurement visibility

Primary controls

Status

Navigation

The user shall not lose engineering capability.

---

# 15. Tablet Layout

Tablets may display:

Multiple workspaces

Persistent side panels

Expanded history

Expanded diagnostics

Additional engineering context

Tablets shall not merely enlarge phone layouts.

---

# 16. Foldable Devices

Foldable layouts shall support:

Single-screen operation

Dual-pane operation

Expanded engineering workspace

Dynamic reflow

State preservation during folding.

---

# 17. Large Displays

Future dedicated hardware may expose:

Persistent diagnostics

Multiple instruments

Large engineering dashboards

Additional engineering panels

The layout architecture shall scale naturally.

---

# 18. Spacing

Spacing communicates hierarchy.

Primary controls receive generous spacing.

Secondary controls remain visually grouped.

Whitespace improves readability.

---

# 19. Alignment

Measurements:

Centered

Controls:

Grid aligned

Status:

Consistent location

Lists:

Column aligned

Alignment shall remain deterministic.

---

# 20. Responsiveness

Layouts shall adapt without changing engineering workflow.

No engineering capability shall become unavailable because of screen size.

---

# 21. Accessibility

Layouts shall support:

Large text

Screen readers

High contrast

External keyboards

Stylus

One-handed operation

Accessibility shall preserve workflow.

---

# 22. Future Hardware

The layout system shall support:

Android

Windows

Linux

Dedicated handheld instruments

Industrial touch displays

Vehicle-mounted displays

No redesign shall be required.

---

# 23. Extensibility

Future instruments may define additional workspaces.

Existing workspace hierarchy shall remain unchanged.

---

# 24. Core Principles

1.

Engineering information always has highest priority.

2.

Primary controls remain immediately accessible.

3.

Navigation remains shallow.

4.

Layouts scale without changing workflow.

5.

Whitespace improves engineering clarity.

6.

Status remains continuously visible.

7.

Professional instruments are the design reference.

8.

Every instrument shares one workspace architecture.

---

End of Document