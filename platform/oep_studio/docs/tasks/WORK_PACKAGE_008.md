# OEP Desktop

# WORK PACKAGE 008

Status: Approved

Version: 1.0

---

# Objective

Expand the Knowledge Workspace into a complete manual engineering curation environment.

This work package introduces:

* Persistent Knowledge Curation Sessions
* Source Material management
* Manual Engineering Relationship authoring
* Repository Commit Preview

No AI.

No OCR.

No automatic repository modifications.

No Foundation changes.

---

# Knowledge Architecture

This work package shall conform to the frozen Knowledge Architecture v1:

* SDD-013 Knowledge Studio
* SDD-014 Engineering Knowledge Acquisition Pipeline
* SDD-015 Engineering Knowledge Model
* SDD-016 Knowledge Studio User Experience
* SDD-017 Knowledge Curation Workflow
* SDD-018 Engineering Knowledge Lifecycle and Provenance
* SDD-019 Engineering Object Philosophy
* SDD-020 Engineering Knowledge Review System

Implementation shall not introduce independent architectural decisions.

Architectural conflicts shall be documented and submitted for review.

---

# STUDIO-TASK-000015

## Persistent Knowledge Curation Sessions

### Purpose

Knowledge Curation Sessions shall become durable Studio artifacts.

Sessions may be:

* Created
* Saved
* Closed
* Reopened
* Archived

Repository commits remain out of scope.

---

# Requirements

Persist:

* Session ID
* Name
* Description
* Author
* Repository
* Status
* Created Date
* Last Modified
* Proposal List
* Review Decisions

Sessions shall survive application restart.

Storage format shall be human-readable.

JSON is recommended.

Persistence is local to Studio.

Foundation shall remain unaware of Knowledge Sessions.

---

# Session Browser

Implement a Session Browser.

Display:

* Session Name
* Repository
* Status
* Created
* Last Modified
* Proposal Count

Support:

* Open
* Duplicate
* Archive
* Delete

Deletion shall require confirmation.

---

# STUDIO-TASK-000016

## Source Material Workspace

### Purpose

Introduce Source Material management.

No OCR.

No parsing.

No AI.

This work package only manages engineering evidence.

---

# Requirements

The engineer may attach source material.

Supported initially:

* PDF
* Images
* Markdown
* Text

Display:

* File Name
* Type
* Size
* Date Added

Preview support:

Images:

Thumbnail.

Text:

Read-only preview.

PDF:

Placeholder preview panel.

Actual PDF rendering is deferred.

---

# Source Metadata

Each source records:

* UUID
* Original File Name
* Local Path
* Import Date
* Added By

Sources remain attached to the Knowledge Session.

---

# STUDIO-TASK-000017

## Manual Relationship Authoring

### Purpose

Allow engineers to manually define Engineering Relationships.

These remain Knowledge Candidates.

Nothing enters the repository.

---

# Requirements

Support:

Create Relationship

Edit Relationship

Delete Relationship

Relationship fields:

* Source Candidate
* Target Candidate
* Relationship Type
* Description

Validation:

Source and Target must exist.

Self-reference prohibited.

Duplicate relationships warned.

---

# Relationship View

Display:

Source

↓

Relationship Type

↓

Target

Support filtering and sorting.

---

# STUDIO-TASK-000018

## Repository Commit Preview

### Purpose

Display exactly what would be committed.

No repository modification occurs.

---

# Preview

Display:

New Engineering Objects

Modified Objects

Relationships

Merged Objects

Rejected Candidates

Validation Summary

Repository Statistics After Commit

Everything displayed is simulated.

Commit remains disabled.

---

# Property Inspector

Extend support for:

Knowledge Session

Knowledge Candidate

Relationship Candidate

Source Material

Selection switching shall remain automatic.

---

# Connection Manager

Extend with:

Current Knowledge Session

Current Source List

Current Relationship Candidate List

Current Commit Preview

Widgets continue consuming only Connection Manager state.

---

# Architecture Rules

Knowledge Workspace remains a Workspace.

No engineering logic in widgets.

Validation belongs in services.

Persistence belongs in services.

Connection Manager coordinates state.

---

# Error Handling

Handle:

Duplicate session names.

Invalid source files.

Missing source files.

Invalid relationship definitions.

Corrupted session files.

Display professional error messages.

No native implementation details.

---

# Verification

Perform:

* flutter analyze
* flutter test
* flutter build windows

Verify:

* Session persistence.
* Session reopening.
* Session browser.
* Source attachment.
* Manual relationship creation.
* Commit Preview.
* Property Inspector.
* Window resizing.
* Theme consistency.

Perform manual verification using a real engineering repository.

---

# Documentation

Update:

* README.md
* docs/IMPLEMENTATION_STATUS.md
* docs/KNOWLEDGE_STUDIO.md

Create:

docs/KNOWLEDGE_SESSION_FORMAT.md

Document:

* Session persistence
* Source management
* Relationship candidates
* Commit Preview
* Local storage format

---

# Definition of Done

This work package is complete when:

* Knowledge Sessions persist.
* Session Browser functions.
* Source Material management functions.
* Manual Relationship authoring functions.
* Commit Preview functions.
* Documentation is complete.
* flutter analyze passes.
* flutter test passes.
* Windows build succeeds.
* Manual verification confirms correct operation.

Stop after completion and await formal review.
