# OEP Desktop

# WORK PACKAGE 019

Status: Approved

Version: 1.0

---

# Objective

Implement the first generation of Engineering Diagram Intelligence.

This work package enables Studio to analyze engineering diagrams and convert them into structured, reviewable engineering knowledge.

Supported input includes:

- Wiring Diagrams
- Electrical Schematics
- Block Diagrams
- Mechanical Assembly Diagrams
- Hydraulic Schematics
- Pneumatic Schematics

No Foundation changes.

No Public C API changes.

All extracted engineering knowledge remains subject to engineer review before repository commit.

---

# Knowledge Architecture

This work package shall conform to:

- SDD-013 through SDD-023

Implementation shall not introduce independent architectural decisions.

---

# STUDIO-TASK-000060

## Diagram Analysis Pipeline

Implement DiagramAnalysisService.

Responsibilities:

- Image preprocessing
- Symbol detection orchestration
- Text region discovery
- Line extraction
- Junction detection
- Connection graph construction

DiagramAnalysisService shall coordinate analysis only.

Individual detection logic belongs in dedicated services.

---

# STUDIO-TASK-000061

## Symbol Detection

Implement deterministic symbol detection.

Initial supported symbols:

Electrical

- Battery
- Ground
- Fuse
- Relay
- Switch
- Lamp
- Motor
- Connector
- Splice

Mechanical

- Bearing
- Gear
- Shaft

Hydraulic

- Pump
- Valve
- Cylinder

Pneumatic

- Regulator
- Compressor

Unknown symbols shall be preserved as UnknownSymbol objects.

No AI classification in this work package.

---

# STUDIO-TASK-000062

## Wire and Connection Extraction

Implement deterministic extraction of:

- Wires
- Junctions
- Branches
- Crossovers
- Arrow continuations
- Connector pins

Construct a complete connection graph.

Support disconnected subgraphs.

---

# STUDIO-TASK-000063

## Diagram Review Workspace

Create a Diagram Review Workspace.

Support:

- Original Diagram
- Overlay Display
- Symbol List
- Connection List
- Unknown Symbols
- Validation Messages

Selecting any object shall synchronize:

- Diagram Viewer
- Property Inspector
- Evidence Browser

---

# STUDIO-TASK-000064

## Engineering Object Suggestions

Generate reviewable Knowledge Candidates for:

- Components
- Connectors
- Wires
- Circuits
- Relationships

Nothing shall automatically enter the repository.

Engineer approval remains mandatory.

---

# Property Inspector

Extend support for:

- Diagram Symbol
- Wire
- Junction
- Circuit
- Connection

---

# Connection Manager

Extend support for:

- Current Diagram
- Current Symbol
- Current Wire
- Current Junction
- Current Circuit

Connection Manager coordinates application state only.

---

# Validation

Detect and report:

- Floating wires
- Unconnected symbols
- Broken line segments
- Duplicate symbols
- Ambiguous junctions
- Unknown symbols

Validation shall never silently discard data.

---

# Architecture Rules

Diagram analysis is deterministic.

AI is not responsible for geometry extraction.

AI may consume extracted diagram knowledge in future work packages.

Unknown objects shall be preserved.

Every extracted object shall maintain evidence links back to the source diagram.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

- Symbol detection
- Wire extraction
- Overlay rendering
- Review workflow
- Knowledge Candidate generation
- Session persistence

Manual verification shall use real engineering diagrams from multiple disciplines.

---

# Documentation

Update:

- README.md
- docs/IMPLEMENTATION_STATUS.md
- docs/KNOWLEDGE_STUDIO.md

Create:

docs/ENGINEERING_DIAGRAM_INTELLIGENCE.md

Document:

- Diagram pipeline
- Symbol detection
- Wire extraction
- Connection graph
- Validation
- Review workflow
- Architectural observations

---

# Definition of Done

Complete when:

- Diagram pipeline functions.
- Symbol detection functions.
- Wire extraction functions.
- Diagram Review Workspace functions.
- Knowledge Candidate generation functions.
- Documentation complete.
- flutter analyze passes.
- flutter tests pass.
- Windows build succeeds.
- Manual verification succeeds.

Stop after completion and await formal review.