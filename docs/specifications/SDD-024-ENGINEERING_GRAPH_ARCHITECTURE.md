# SDD-024

# Engineering Graph Architecture

Status: Frozen

Version: 1.0

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07 | Initial Engineering Graph Architecture |

---

# Purpose

This document defines the architecture governing all engineering knowledge visualization.

Engineering Diagrams are visualizations of Engineering Knowledge.

Engineering Diagrams are not the Engineering Knowledge itself.

---

# Philosophy

The Engineering Repository stores engineering knowledge.

The Engineering Graph represents engineering knowledge.

Engineering Diagrams visualize the Engineering Graph.

Source Material remains immutable evidence.

---

# Architecture

```
Source Material

↓

OCR

↓

Engineering Evidence

↓

Engineering Entities

↓

Engineering Contexts

↓

Knowledge Candidates

↓

Repository Commit

↓

Foundation Repository

↓

Engineering Graph

↓

Diagram Renderer
```

The Engineering Graph is derived from Repository knowledge.

The Diagram Renderer visualizes the Engineering Graph.

---

# Source Material

Source Material is immutable.

Examples:

- PDF
- Image
- FSM
- Wiring Diagram
- Photograph

Source Material shall never be edited.

---

# Engineering Graph

The Engineering Graph represents engineering knowledge.

Nodes represent engineering objects.

Edges represent engineering relationships.

The graph contains no visual layout information.

---

# Engineering Nodes

Nodes may include:

- Component
- Connector
- Wire
- Circuit
- Harness
- Module
- Relay
- Fuse
- Switch
- Ground
- Sensor
- Actuator
- Measurement Point
- Procedure
- Specification

Future node types may be added.

---

# Engineering Relationships

Relationships describe engineering meaning.

Examples:

- Connected To
- Supplies Power
- Grounds
- Communicates With
- Contains
- Part Of
- Mounted To
- References
- Controls
- Measures

---

# Diagram Renderer

The Diagram Renderer visualizes the Engineering Graph.

Multiple renderers may exist.

Examples:

- Wiring Diagram
- Harness Layout
- Diagnostic View
- Installation View
- Simulation View
- Schematic View
- Physical Layout

Changing renderer shall never modify the Engineering Graph.

---

# Visual Layout

Visual layout is not engineering knowledge.

Layout information belongs to the renderer.

Layout may include:

- Position
- Rotation
- Color
- Layer
- Visibility
- Zoom
- Grouping

Layout is renderer-specific.

---

# Symbol Library

The Symbol Library defines visual representations.

Symbols are data.

Symbols are not hardcoded.

Each symbol defines:

- Identifier
- Name
- Category
- Geometry
- Connection Ports
- Aliases
- Supported Standards

Examples:

- SAE
- IEC
- ISO
- ANSI

---

# Connection Ports

Every symbol defines connection ports.

Ports include:

- Name
- Position
- Direction
- Type

Ports determine valid connections.

---

# Evidence

Every Engineering Node may reference evidence.

Evidence includes:

- OCR
- Text
- Diagram Regions
- Images
- Procedures

Evidence remains traceable.

---

# Simulation

Simulation operates on the Engineering Graph.

Simulation does not operate on diagrams.

Voltage, current, pressure, flow, and state propagate through graph relationships.

---

# Artificial Intelligence

AI consumes Engineering Knowledge.

AI does not consume rendered diagrams directly.

AI may suggest:

- Missing relationships
- Missing components
- Circuit names
- Procedures
- Specifications

Engineer approval remains mandatory.

---

# Multiple Views

A single Engineering Graph may be visualized as:

- Wiring Diagram
- Diagnostic Diagram
- Harness View
- Physical Layout
- Simulation
- Print Layout

All views represent the same Engineering Knowledge.

---

# Architecture Rules

1. Source Material is immutable.

2. Repository stores Engineering Knowledge.

3. Engineering Graph represents Engineering Knowledge.

4. Diagram Renderer visualizes the Engineering Graph.

5. Layout is not Engineering Knowledge.

6. Symbols are data.

7. Every node maintains evidence.

8. AI operates on Engineering Knowledge.

9. Simulation operates on Engineering Knowledge.

10. Multiple renderers may visualize the same graph.