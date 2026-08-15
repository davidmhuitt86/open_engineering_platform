# OEP Desktop

# WORK PACKAGE 009

Status: Approved

Version: 1.0

---

# Objective

Introduce the first true Source Viewer.

The Source Viewer transforms attached engineering evidence into something engineers can actively work with.

No OCR.

No AI.

No repository commit.

No Foundation modifications.

This work package focuses entirely on engineering evidence visualization.

---

# Knowledge Architecture

This work package shall conform to the frozen Knowledge Architecture v1.

Implementation shall not introduce independent architectural decisions.

Architectural conflicts shall be documented and submitted for review.

---

# STUDIO-TASK-000019

## PDF Source Viewer

### Purpose

Support viewing attached PDF source material.

This is a viewer only.

No parsing.

No OCR.

No extraction.

---

# Requirements

Support:

- Open PDF
- Page navigation
- Zoom In
- Zoom Out
- Fit Width
- Fit Page
- Rotate
- Continuous scrolling

Display:

Current Page

Total Pages

Zoom Percentage

---

# Selection

The engineer may select pages.

Selection becomes part of the active Knowledge Session.

No text selection required.

Page selection only.

---

# STUDIO-TASK-000020

## Evidence Regions

### Purpose

Allow engineers to identify where engineering evidence exists.

This work package introduces manual Evidence Regions.

---

# Requirements

Support:

Rectangle Regions

Each region records:

- UUID
- Page
- Position
- Size
- Label
- Notes

Regions remain local to the Knowledge Session.

---

# Evidence Browser

Display:

Region Name

Page

Type

Linked Candidate Count

Support:

Rename

Delete

Navigate

---

# STUDIO-TASK-000021

## Evidence Linking

### Purpose

Knowledge Candidates may reference engineering evidence.

---

# Requirements

Support linking:

Knowledge Candidate

↓

Evidence Region

One candidate may reference multiple regions.

One region may support multiple candidates.

Display all evidence links inside the Property Inspector.

---

# Source Viewer Interaction

Selecting:

Knowledge Candidate

↓

Highlights linked Evidence Regions.

Selecting:

Evidence Region

↓

Highlights linked Knowledge Candidates.

Navigation shall work in both directions.

---

# Property Inspector

Extend support for:

Evidence Region

Evidence Links

Source Metadata

Knowledge Candidate Evidence

---

# Connection Manager

Extend with:

Current Source Document

Current Page

Current Evidence Region

Current Evidence Link

---

# Architecture Rules

Evidence remains separate from Engineering Objects.

Evidence belongs to the Knowledge Workspace.

Foundation remains unaware of Evidence Regions.

No engineering logic inside widgets.

---

# Error Handling

Handle:

Invalid PDFs

Missing files

Deleted source material

Corrupted session references

Display professional error messages.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

PDF rendering

Zoom

Page navigation

Evidence Region creation

Evidence linking

Property Inspector updates

Session persistence

Window resizing

---

# Documentation

Update:

README.md

docs/IMPLEMENTATION_STATUS.md

docs/KNOWLEDGE_STUDIO.md

Create:

docs/EVIDENCE_MODEL.md

Document:

Evidence Regions

Evidence Links

PDF Viewer

Selection model

Navigation model

Persistence

---

# Definition of Done

This work package is complete when:

- PDF Source Viewer functions.
- Evidence Regions function.
- Evidence linking functions.
- Property Inspector supports evidence.
- Session persistence includes evidence.
- Documentation is complete.
- flutter analyze passes.
- flutter tests pass.
- Windows build succeeds.
- Manual verification confirms correct operation.

Stop after completion and await formal review.