# OEP Studio
Knowledge Studio is governed by the frozen Knowledge Architecture v1.

The implementation in this work package shall conform to:

- SDD-013 Knowledge Studio
- SDD-014 Engineering Knowledge Acquisition Pipeline
- SDD-015 Engineering Knowledge Model
- SDD-016 Knowledge Studio User Experience
- SDD-017 Knowledge Curation Workflow
- SDD-018 Engineering Knowledge Lifecycle and Provenance
- SDD-019 Engineering Object Philosophy
- SDD-020 Engineering Knowledge Review System

These documents are considered architectural specifications.

Implementation shall follow them.

If implementation reveals a conflict or omission, document the issue and stop for architectural review rather than introducing an independent design.

# WORK PACKAGE 007

Status: Approved

Version: 1.0

---

# Objective

Begin implementation of Knowledge Studio.

This work package establishes the first functional Engineering Knowledge Curation workflow.

The objective is not to build the complete Knowledge Studio.

The objective is to validate the architecture defined in:

* SDD-013
* SDD-014
* SDD-015
* SDD-016
* SDD-017
* SDD-018
* SDD-019

No AI implementation is required.

No OCR implementation is required.

No Foundation modifications are permitted.

Knowledge Studio shall initially operate with manually-created Engineering Objects.

---

# STUDIO-TASK-000013

## Knowledge Studio Shell

### Purpose

Implement the complete Knowledge Studio workspace.

The layout shall match SDD-016.

Panels:

* Import Queue
* Source Viewer
* AI Suggestions
* Repository Matches
* Engineering Review
* Property Inspector
* Commit Summary

Only Property Inspector shall contain live Foundation data.

All remaining panels shall initially use placeholder content.

The objective is to validate layout, navigation, resizing, docking behavior, and state management.

---

# STUDIO-TASK-000014

## Knowledge Curation Session

### Purpose

Implement the first Knowledge Curation Session.

This is a Studio-only implementation.

No repository commit occurs.

No Foundation modifications occur.

---

# Requirements

The user shall be able to:

Create a new Knowledge Curation Session.

Name the session.

Assign:

* Repository
* Author
* Description

Display:

Session ID

Creation Time

Status

Source Count

Proposal Count

Accepted Count

Rejected Count

Pending Count

The session shall remain entirely in memory.

Persistence is deferred.

---

# Session Workflow

Support the following states:

Created

↓

Preparing

↓

Reviewing

↓

Ready to Commit

↓

Cancelled

Repository Commit is intentionally not implemented in this work package.

---

# Engineering Review

The engineer shall be able to create manual proposals.

Proposal types:

* Component
* Procedure
* Specification
* Image
* Document

Each proposal supports:

Accept

Reject

Edit

Delete

These proposals exist only within the current session.

---

# Property Inspector

Display:

Proposal metadata

Session metadata

Selected repository object

Selection shall switch automatically.

---

# Navigation

Knowledge Studio shall register as a new Studio workspace.

It shall integrate with:

* Navigation Rail
* Connection Manager
* Theme
* Window layout

No separate application shall be created.

---

# Architecture Rules

Knowledge Studio remains a Studio workspace.

No engineering logic shall exist inside widgets.

The Connection Manager owns session state.

Widgets consume state only.

---

# Error Handling

Handle:

* Invalid session names
* Duplicate proposal names
* Missing repository

Display professional validation messages.

---

# Verification

Perform:

* flutter analyze
* flutter test
* flutter build windows

Verify:

* Knowledge Studio opens correctly.
* All panels resize correctly.
* Session lifecycle functions.
* Proposal editing functions.
* Property Inspector updates.
* Navigation functions.
* Window resizing remains correct.

---

# Documentation

Update:

README.md

docs/IMPLEMENTATION_STATUS.md

Create:

docs/KNOWLEDGE_STUDIO.md

Document:

* Workspace layout
* Session lifecycle
* Proposal model
* State ownership
* Future Foundation integration

---

# Definition of Done

This work package is complete when:

* Knowledge Studio workspace exists.
* Knowledge Curation Sessions function.
* Manual proposal workflow functions.
* Property Inspector supports proposal inspection.
* Documentation is complete.
* Flutter analyze passes.
* Flutter tests pass.
* Windows build succeeds.
* Manual verification confirms correct operation.

Stop after completion and await formal review.
