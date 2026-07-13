# SDD-026

Engineering Engine Public Architecture

Status: Frozen

Version: 1.0

---

# Purpose

This document defines the public interface exposed by the Engineering Engine.

Studio shall communicate with Engineering only through these interfaces.

Studio shall never depend upon Engineering implementation details.

---

# Philosophy

Engineering Engine is a reusable subsystem.

Diagram Studio is one consumer.

Future consumers may include:

- Marketplace
- AI
- Simulation Studio
- Mobile applications
- Web applications
- Enterprise servers

---

# Public Services

EngineeringEngine

GraphService

DiagramService

SymbolLibrary

ValidationService

SimulationService

ImportService

ExportService

SelectionService

NavigationService

SearchService

---

# EngineeringEngine

Primary entry point.

Responsibilities:

- Initialize Engine
- Shutdown
- Version
- Registered Services
- Diagnostics

---

# GraphService

Owns Engineering Graph.

Supports:

Create

Open

Close

Save

Load

Query

Update

Validate

---

# DiagramService

Owns Diagram rendering.

Supports:

Open Diagram

Renderer Selection

Layout

Zoom

Pan

Selection

Overlays

---

# SymbolLibrary

Provides:

Lookup

Registration

Validation

Aliases

Standards

Categories

---

# ValidationService

Provides deterministic validation.

No mutation.

---

# SimulationService

Future.

Supports:

Electrical

Hydraulic

Mechanical

Pneumatic

Thermal

---

# ImportService

Import:

PDF

PNG

JPG

TIFF

SVG

Future:

DXF

DWG

KiCad

Altium

---

# ExportService

Export:

SVG

PNG

PDF

JSON

OEP Package

---

# SearchService

Provides Engineering Graph search.

Independent from Foundation search.

---

# NavigationService

Provides:

Selection

Navigation

Highlight

Evidence synchronization

---

# SelectionService

Maintains:

Current Node

Current Relationship

Current Circuit

Current Symbol

Current Diagram

---

# Threading

Engineering Engine shall remain UI-independent.

No Flutter Widgets.

No BuildContext.

No Widget references.

---

# Dependencies

Engineering Engine may depend upon:

Foundation Bridge

Shared Models

Standard Dart packages

It shall never depend upon Studio.

---

# Extension

Future modules register through Engine interfaces.

No Studio modification required.

---

# Architecture Rules

Studio depends on Engineering.

Engineering depends on Foundation.

Foundation depends on nothing.

Dependency direction shall never reverse.