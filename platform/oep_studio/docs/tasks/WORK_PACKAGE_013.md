# OEP Desktop

# WORK PACKAGE 013

Status: Approved

Version: 1.0

---

# Objective

Introduce the Engineering OCR Pipeline.

This work package converts engineering documents from images into structured, searchable text while preserving exact positional information.

No AI.

No automatic Knowledge Candidate generation.

No Repository Commit changes.

OCR augments Source Material only.

---

# Knowledge Architecture

This work package shall conform to the frozen Knowledge Architecture v1.

Implementation shall not introduce independent architectural decisions.

---

# STUDIO-TASK-000034

## OCR Pipeline

### Purpose

Extract text from Source Material.

Supported:

- PDF
- PNG
- JPG
- TIFF

OCR shall operate per page.

---

# OCR Output

Each page produces:

- Text
- Confidence
- Bounding Boxes
- Reading Order

OCR results remain attached to Source Material.

---

# STUDIO-TASK-000035

## OCR Layer Viewer

Display:

- Original page
- OCR overlay
- Confidence heat map
- Toggle overlay

Engineers may:

- Show OCR
- Hide OCR

No editing yet.

---

# STUDIO-TASK-000036

## Searchable Documents

OCR text becomes searchable.

Support:

- Find
- Find Next
- Highlight

Search remains local to Source Material.

---

# STUDIO-TASK-000037

## OCR Session Cache

OCR results shall persist.

Reopening a session shall not rerun OCR.

Support cache invalidation when Source Material changes.

---

# Property Inspector

Extend support for:

- OCR metadata
- Confidence
- OCR statistics

---

# Connection Manager

Extend support for:

- OCR state
- Current OCR page
- OCR overlay visibility

---

# Architecture Rules

OCR produces evidence only.

OCR shall never create Knowledge Candidates.

OCR shall never infer engineering meaning.

OCR is deterministic.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

- OCR extraction
- Overlay rendering
- Search
- Persistence
- Cache reuse

Manual verification against real engineering documents.

---

# Documentation

Update:

- README.md
- docs/IMPLEMENTATION_STATUS.md
- docs/KNOWLEDGE_STUDIO.md

Create:

docs/OCR_PIPELINE.md

Document:

- OCR architecture
- Cache
- Overlay
- Confidence model
- Search

---

# Definition of Done

Complete when:

- OCR functions.
- OCR overlay functions.
- Search functions.
- Cache functions.
- Documentation complete.
- Tests pass.
- Windows build succeeds.
- Manual verification succeeds.

Stop for review.