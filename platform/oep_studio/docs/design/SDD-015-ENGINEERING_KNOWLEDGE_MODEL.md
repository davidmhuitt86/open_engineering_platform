# SDD-015

# Engineering Knowledge Model

Version: 1.0

Status: Draft

---

# Purpose

The Engineering Knowledge Model (EKM) defines how engineering knowledge is represented within an OEP Repository.

Documents are not the primary engineering artifact.

Engineering Objects are.

Relationships connect Engineering Objects to form an Engineering Knowledge Graph.

---

# Core Principle

Every piece of engineering information shall exist as a reusable Engineering Object.

Objects may be referenced by unlimited Procedures, Components, Images, Documents, and Specifications.

Knowledge shall never require duplication.

---

# Knowledge Layers

Engineering knowledge exists in five logical layers.

Layer 1

Source Material

Examples:

* Factory Service Manuals
* TSBs
* Drawings
* Notes
* Images

---

Layer 2

Extracted Artifacts

Examples:

* OCR Text
* Tables
* Captions
* Images

These are machine-readable artifacts.

They are not Engineering Objects.
---
Layer 2.5

Evidence Objects

Evidence Objects represent engineering evidence collected during a Knowledge Curation Session.

Evidence Objects are Workspace artifacts.

They are not Engineering Objects.

Examples:

- Source Document
- PDF
- Image
- Evidence Region
- Page Selection
- Annotation
- Measurement Region

Evidence Objects support Engineering Knowledge.

They do not become repository truth.

Engineering Objects may reference Evidence Objects as supporting provenance.
---

Layer 3

Engineering Objects

Examples:

Components

Procedures

Specifications

Tools

Fluids

Materials

Warnings

Measurements

Images

Documents

Import Sessions

---

Layer 4

Relationships

Relationships transform Engineering Objects into engineering knowledge.

Examples:

Requires

Contains

Uses

Documents

References

Connected To

Implements

Measured By

Specified By

Illustrated By

Replaces

Supersedes

---

Layer 5

Engineering Views

Views are temporary visualizations.

Examples:

Repository Explorer

Graph View

Procedure View

Repair View

Simulation View

Timeline View

Tree View

Views never own data.

They render repository knowledge.

---

# Engineering Object Identity

Every Engineering Object shall possess:

* UUID
* Name
* Type
* Author
* Version
* Created Date
* Modified Date

Objects are immutable by identity.

Names and metadata may evolve.

Identity never changes.

---

# Procedure Model

Procedures are ordered workflows.

Each Procedure contains Steps.

Each Step is an Engineering Object.

Steps may reference:

Components

Images

Specifications

Warnings

Measurements

Tools

Fluids

Other Procedures

---

# Specification Model

Specifications are independent Engineering Objects.

Examples:

Torque

Voltage

Resistance

Pressure

Temperature

Clearance

Every Specification may be referenced by unlimited Components and Procedures.

---

# Component Model

Components may possess:

Part Numbers

Manufacturers

Superseded Parts

Dimensions

Specifications

Images

Relationships

Documents

Failure Modes

Compatible Systems

---

# Image Model

Images are Engineering Objects.

Images may reference:

Components

Procedures

Specifications

Warnings

Bounding Regions

Annotations

Future AI detections

---

# Document Model

Documents preserve source context.

Documents remain immutable.

Engineering knowledge references Documents.

Documents do not own engineering knowledge.

---

# Traceability

Every Engineering Object shall preserve:

Original Source

Import Session

Reviewer

Approval Date

Evidence

Confidence

Repository history shall remain auditable.

---

# Graph

Every Engineering Object may possess unlimited Relationships.

The Engineering Graph is not a separate database.

It is an interpretation of Repository Relationships.

---

# Engineering Truth

The Repository becomes the engineering authority.

Documents become supporting evidence.

Engineering Objects become engineering truth.

---

# Future Expansion

Future versions may introduce:

* Electrical Signals
* Software Modules
* ECU Functions
* Calibration Data
* Test Results
* Oscilloscope Captures
* CAN Messages
* Diagnostic Trouble Codes
* Wiring Harnesses
* Connectors
* Pins
* Fasteners
* Assemblies

Each new domain extends the Engineering Object model without changing its underlying architecture.

---

# Design Goal

An engineer should be able to begin with any Engineering Object and navigate every related piece of engineering knowledge without opening a document unless they require supporting evidence.
