# SDD-021

# Engineering Evidence Model

Version: 1.0

Status: Approved

---

# Purpose

The Engineering Evidence Model defines how engineering evidence is represented during a Knowledge Curation Session.

Evidence supports engineering knowledge.

Evidence is not engineering knowledge.

Evidence remains external to Foundation and is managed entirely by Knowledge Workspace.

---

# Design Philosophy

Engineering knowledge must always be supported by engineering evidence.

Evidence explains why a Knowledge Candidate exists.

Knowledge Candidates become Engineering Objects only after Repository Commit.

Evidence itself never becomes an Engineering Object.

---

# Scope

The Engineering Evidence Model is owned by Knowledge Workspace.

Foundation remains unaware of evidence management.

Only provenance references are transferred during Repository Commit.

---

# Core Model

The Engineering Evidence Model consists of four primary entities.

Source Material

↓

Page Selection

↓

Evidence Region

↓

Evidence Link

These entities exist only within an active Knowledge Curation Session.

---

# Source Material

Source Material represents an original engineering reference.

Examples include:

- Factory Service Manual
- Technical Service Bulletin
- Engineering Drawing
- Photograph
- Parts Catalog
- Specification Sheet
- Markdown
- HTML

Source Material remains immutable.

Each Source Material record stores:

- UUID
- Original filename
- Local path
- File type
- Date added
- Added by

---

# Page Selection

A Page Selection identifies one or more pages within Source Material that are relevant to the current Knowledge Curation Session.

Page Selection is intended only to narrow the engineer's working context.

It does not identify specific engineering evidence.

Each Page Selection records:

- UUID
- Source Material
- Selected pages
- Notes

---

# Evidence Region

Evidence Regions identify specific engineering evidence on a page.

Evidence Regions are manually created by the engineer.

Supported region type:

- Rectangle

Future versions may introduce:

- Polygon
- Freehand
- OCR Region
- AI Region

Each Evidence Region stores:

- UUID
- Source Material
- Page
- Position
- Size
- Label
- Notes

---

# Evidence Links

Evidence Links connect Knowledge Candidates to supporting Evidence Regions.

Relationships are many-to-many.

One Knowledge Candidate may reference many Evidence Regions.

One Evidence Region may support many Knowledge Candidates.

Evidence Links preserve engineering provenance.

---

# Ownership

Knowledge Workspace owns:

- Source Material
- Page Selections
- Evidence Regions
- Evidence Links

Foundation owns:

- Engineering Objects
- Engineering Relationships
- Repository Truth

This separation shall remain strict.

---

# Session Persistence

Evidence data is persisted with the Knowledge Curation Session.

Session persistence includes:

- Source Material
- Page Selections
- Evidence Regions
- Evidence Links

Evidence shall survive application restart.

---

# Repository Commit

Repository Commit remains outside the scope of this document.

When Repository Commit is implemented:

Engineering Objects shall retain provenance references back to their supporting evidence.

Foundation shall not own Evidence Regions or Source Material.

---

# Future Expansion

Future versions may extend this model with additional evidence types including:

- OCR Text Blocks
- Figures
- Tables
- AI Detections
- CAD Geometry
- Video Timestamps
- Audio Segments
- Sensor Captures
- Oscilloscope Traces

Future extensions shall build upon this model without requiring changes to existing session files.

---

# Design Goal

An engineer shall be able to inspect any Knowledge Candidate or Engineering Object and immediately identify the Source Material, Page Selection, and Evidence Regions that support it.

Engineering evidence shall remain transparent, traceable, and permanently associated with the engineering knowledge it supports.