# SDD-016

# Knowledge Studio User Experience

Version: 1.0

Status: Draft

---

# Purpose

Knowledge Studio is the primary engineering authoring environment within OEP.

It exists to transform engineering information into engineering knowledge.

Unlike traditional document management systems, engineers do not organize files.

They construct Engineering Knowledge.

---

# Design Philosophy

The engineer should never feel like they are importing documents.

The engineer should feel like they are building an engineering model of reality.

Every interaction shall reinforce this philosophy.

---

# Workspace Layout

Knowledge Studio shall use a seven-panel workflow.

+--------------------------------------------------------------+
| Toolbar                                                      |
+--------------------------------------------------------------+
| Import Queue | Source Viewer | AI Suggestions | Inspector     |
|              |               |                |               |
|--------------+---------------+----------------+---------------|
| Repository Matches           | Engineering Review             |
|------------------------------+-------------------------------|
| Commit Summary                                               |
+--------------------------------------------------------------+

Every panel represents one stage of the Engineering Knowledge Acquisition Pipeline.

---

# Panel 1

Import Queue

Purpose:

Manage source material.

Supported:

* PDF
* Images
* Markdown
* HTML
* Documents

Each import becomes an Import Session.

Display:

* File
* Pages
* Status
* Progress

---

# Panel 2

Source Viewer

Purpose:

Display the original engineering source.

Capabilities:

* Zoom
* Pan
* Rotate
* Page Navigation
* OCR Overlay
* Image Overlay

The Source Viewer is always available.

Evidence Objects

The Source Viewer allows engineers to create Evidence Objects.

Evidence Objects may include:

- Evidence Regions
- Page Selections
- Image Annotations
- Future OCR Regions

Evidence Objects remain local to the active Knowledge Curation Session until Repository Commit.

Evidence Objects shall always preserve a reference to the original source material.

The engineer should never lose sight of the original evidence.

---

# Panel 3

AI Suggestions

Purpose:

Display proposed Engineering Objects.

Display:

Object Type

Object Name

Confidence

Supporting Evidence

Repository Matches

Status

Color Coding:

Green

High confidence

Yellow

Needs review

Red

Low confidence

Nothing is automatically accepted.

---

# Panel 4

Repository Matches

Purpose:

Prevent duplicate Engineering Objects.

Display:

Possible existing Components

Possible Procedures

Possible Specifications

Possible Images

Each proposal supports:

Merge

Replace

Create New

Open Existing

---

# Panel 5

Engineering Review

Purpose:

Engineer approval.

Every proposal supports:

Accept

Reject

Merge

Edit

Postpone

Bulk actions shall be available.

No repository changes occur until Commit.

---

# Panel 6

Property Inspector

Displays:

Object metadata

Evidence

Relationships

Confidence

Repository references

Import Session

Every proposal remains fully traceable.

---

# Panel 7

Commit Summary

Before repository modification display:

Objects

Relationships

Specifications

Images

Warnings

Procedures

Modified Objects

Merged Objects

Rejected Objects

The engineer shall approve one final Commit.

---

# Import Workflow

Step 1

Select Source Material.

↓

Step 2

Create Import Session.

↓

Step 3

Analyze.

↓

Step 4

Review AI Suggestions.

↓

Step 5

Resolve duplicates.

↓

Step 6

Approve Engineering Objects.

↓

Step 7

Review Commit Summary.

↓

Step 8

Commit Repository.

---

# Confidence Visualization

Every AI proposal displays confidence.

95–100%

Green

80–94%

Yellow

Below 80%

Red

Confidence never determines acceptance.

The engineer always decides.

---

# Evidence Viewer

Selecting any proposal highlights:

Original text

Images

Tables

Captions

Pages

OCR

Supporting evidence

The engineer shall always understand why AI proposed an Engineering Object.

---
# Repository Preview

Before Commit:

Display the repository exactly as it will appear.

Objects

Relationships

Specifications

Search Results

Graph

The engineer previews repository changes before committing.

---

# Undo

Repository commits shall support rollback.

Rollback restores repository integrity.

Import Sessions remain preserved.

---

# Design Goals

Knowledge Studio shall feel:

Methodical

Transparent

Trustworthy

Traceable

Professional

It shall never feel autonomous.

The engineer remains responsible for repository knowledge.

---

# Long-Term Vision

Knowledge Studio becomes the world's primary environment for transforming engineering documentation into reusable engineering knowledge while preserving provenance, engineering authority, and complete traceability.
