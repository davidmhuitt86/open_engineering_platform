# OEP Desktop

# WORK PACKAGE 011

Status: Approved

Version: 1.0

---

# Objective

Introduce visual knowledge exploration for the active Knowledge Curation Session.

This work package allows engineers to inspect the structure and completeness of a Knowledge Curation Session before Repository Commit.

No OCR.

No AI.

No Repository Commit.

No Foundation modifications.

---

# Knowledge Architecture

This work package shall conform to the frozen Knowledge Architecture v1:

- SDD-013 Knowledge Studio
- SDD-014 Engineering Knowledge Acquisition Pipeline
- SDD-015 Engineering Knowledge Model
- SDD-016 Knowledge Studio User Experience
- SDD-017 Knowledge Curation Workflow
- SDD-018 Engineering Knowledge Lifecycle and Provenance
- SDD-019 Engineering Object Philosophy
- SDD-020 Engineering Knowledge Review System
- SDD-021 Engineering Evidence Model

Implementation shall not introduce independent architectural decisions.

Architectural conflicts shall be documented and submitted for review.

---

# STUDIO-TASK-000026

## Knowledge Session Graph

### Purpose

Provide a visual graph of the active Knowledge Curation Session.

This graph is local to the active session.

It is independent of Foundation Graph.

---

# Display

Visualize:

- Knowledge Candidates
- Relationship Candidates
- Procedure Candidates
- Specification Candidates
- Evidence Regions
- Source Material

---

# Node Types

Each node type shall use a distinct icon.

Relationship Candidates remain edges.

Evidence Regions connect to Knowledge Candidates.

Procedures connect to their Procedure Steps.

---

# Interaction

Support:

- Pan
- Zoom
- Fit All
- Center Selection
- Select Node

Selecting a node updates the Property Inspector.

Selecting an item elsewhere updates the graph.

Selection remains synchronized.

---

# STUDIO-TASK-000027

## Provenance Explorer

### Purpose

Display the provenance chain for any selected Knowledge Candidate.

---

# Display

Show:

Knowledge Candidate

↓

Evidence Region(s)

↓

Page Selection

↓

Source Material

Display all supporting evidence.

Support navigation in both directions.

---

# STUDIO-TASK-000028

## Candidate Dependency Viewer

### Purpose

Display engineering dependencies within the active Knowledge Session.

---

# Display

For each Knowledge Candidate show:

Referenced By

References

Relationships

Procedure Usage

Specification Usage

Evidence Count

Validation Status

---

# STUDIO-TASK-000029

## Session Health Dashboard

### Purpose

Provide engineering quality metrics for the active Knowledge Session.

---

# Display

Knowledge Candidates

Relationship Candidates

Evidence Regions

Procedures

Specifications

Validation Errors

Candidates Missing Evidence

Duplicate Candidates

Orphaned Candidates

Relationship Density

Average Evidence Coverage

These metrics are informational only.

---

# Property Inspector

Extend support for:

- Provenance
- Dependency information
- Session Health

---

# Connection Manager

Extend with:

- Current Graph Selection
- Current Provenance View
- Current Dependency View
- Current Session Health

Connection Manager continues coordinating application state only.

---

# Architecture Rules

The Knowledge Graph represents the active Knowledge Session.

It is not Foundation Graph.

No Repository Commit.

No Foundation modifications.

No engineering logic inside Widgets.

Graph construction belongs in services.

---

# Error Handling

Handle:

- Empty sessions
- Missing evidence
- Broken references
- Invalid graph nodes

Display professional messages.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

- Graph rendering
- Selection synchronization
- Provenance Explorer
- Dependency Viewer
- Session Health Dashboard
- Property Inspector
- Window resizing
- Theme consistency

Manual verification shall be performed against the compiled Windows application.

If environmental limitations prevent direct GUI interaction, use the previously approved temporary integration-test strategy and remove all temporary verification code before committing.

---

# Documentation

Update:

- README.md
- docs/IMPLEMENTATION_STATUS.md
- docs/KNOWLEDGE_STUDIO.md

Create:

docs/KNOWLEDGE_GRAPH.md

Document:

- Graph model
- Provenance model
- Dependency model
- Session Health model
- Synchronization model

Document any architectural observations discovered during implementation.

---

# Definition of Done

This work package is complete when:

- Knowledge Session Graph functions.
- Provenance Explorer functions.
- Dependency Viewer functions.
- Session Health Dashboard functions.
- Documentation is complete.
- flutter analyze passes.
- flutter tests pass.
- Windows build succeeds.
- Manual verification confirms correct operation.

Stop after completion and await formal review.