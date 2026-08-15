# OEP Probe System Architecture

Document ID:
OIP-PROBE-001

Status:
Draft

Repository:
oep_instruments

Version:
1.0

---

# 1. Purpose

This document defines the Probe System Architecture for the OEP Instruments platform.

The Probe System provides a unified method for interacting with engineering objects through virtual probes.

Every instrument utilizing probes shall implement this architecture.

---

# 2. Philosophy

A probe is an engineering interface.

It represents the engineer's physical interaction with an electrical system.

Whether the measurement originates from:

• Simulation

• Diagram Studio

• Engineering Intelligence

• Physical Hardware

the interaction with the probe shall remain identical.

---

# 3. Objectives

The Probe System shall be:

Deterministic

Instrument Independent

Host Independent

Transport Independent

Extensible

Observable

Platform Independent

---

# 4. Probe Definition

A Probe represents a measurement endpoint.

A probe never performs measurements.

A probe establishes where a measurement is requested.

Engineering computation remains the responsibility of the Host.

---

# 5. Probe Types

The platform supports:

Measurement Probe

Reference Probe

Ground Probe

Current Probe

Differential Probe

Logic Probe

CAN Probe

LIN Probe

Future Probe Types

---

# 6. Standard Probe Pair

The default measurement pair consists of:

Black Probe

↓

Reference

↓

Red Probe

↓

Measurement

This convention shall remain consistent across all applicable instruments.

---

# 7. Probe Properties

Every probe shall define:

Identifier

Display Name

Type

Color

State

Current Target

Connection Status

Session Reference

Capabilities

---

# 8. Probe States

Each probe exists in one state.

Available

↓

Selected

↓

Dragging

↓

Hovering

↓

Attached

↓

Measuring

↓

Released

↓

Disabled

↓

Unavailable

Only one state shall be active at a time.

---

# 9. Probe Targets

A probe may attach to:

Wire

Connector

Terminal

Pin

Node

Harness

Engineering Object

Simulation Object

Future Target Types

Targets shall advertise their probe compatibility.

---

# 10. Target Resolution

When multiple targets overlap:

Priority shall be determined by the Host.

Selection shall remain deterministic.

The same target shall always be selected under identical conditions.

---

# 11. Probe Attachment

Attachment consists of:

Selection

Validation

Snap

Confirmation

Measurement Request

Display Update

Attachment shall complete atomically.

---

# 12. Probe Validation

The Host validates:

Target Exists

Measurement Allowed

Probe Compatible

Session Valid

Connection Active

Validation failures shall never corrupt probe state.

---

# 13. Probe Visualization

Every probe shall display:

Probe Color

Connection Line

Attachment Point

Hover Target

Measurement Status

Connection State

Visualization shall remain consistent across all instruments.

---

# 14. Probe Movement

Movement supports:

Touch

Stylus

Mouse

Keyboard (Accessibility)

Future Physical Hardware

Movement shall remain fluid and deterministic.

---

# 15. Multiple Probes

Future instruments may support:

Four-wire measurements

Oscilloscope channels

Logic analyzer pods

CAN/LIN differential probes

Additional probes shall extend this architecture without modification.

---

# 16. Probe Metadata

Every probe interaction records:

Timestamp

Session

Target

Instrument

Engineering Object

Measurement Mode

Operator Action

Metadata supports engineering traceability.

---

# 17. Probe History

The Runtime may maintain:

Recent Attachments

Recent Targets

Favorite Targets

Measurement Locations

Bookmarks

History shall remain read-only after recording.

---

# 18. Probe Synchronization

Probe state shall synchronize across:

Host

Runtime

Instrument

Engineering Session

Connected Clients

Synchronization shall preserve deterministic behavior.

---

# 19. Probe Events

Events include:

Probe Selected

Probe Released

Probe Attached

Probe Detached

Measurement Requested

Measurement Completed

Probe Invalid

Probe Disabled

Events shall be observable by the Runtime.

---

# 20. Probe Accessibility

Support:

Large Touch Targets

Keyboard Navigation

Stylus

External Mouse

Screen Readers

Accessible attachment shall preserve engineering precision.

---

# 21. Platform Consistency

Probe behavior shall remain identical across:

Android

Windows

Linux

Future iOS

Dedicated Hardware

Platform-specific implementation shall remain internal.

---

# 22. Extensibility

Future probe types shall integrate without modifying existing probe behavior.

Existing instruments shall remain compatible.

---

# 23. Core Principles

1.

A probe defines where a measurement is requested.

2.

The Host performs engineering computation.

3.

Probe attachment is deterministic.

4.

Every interaction is observable.

5.

Probe behavior remains consistent across instruments.

6.

Probe history supports engineering traceability.

7.

Future probe types extend the architecture without redesign.

8.

Every OEP Instrument shares one unified Probe System Architecture.

---

End of Document