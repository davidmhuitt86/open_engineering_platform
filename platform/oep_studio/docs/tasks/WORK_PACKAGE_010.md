# OEP Desktop

# WORK PACKAGE 010

Status: Approved

Version: 1.0

---

# Objective

Transform Knowledge Workspace into a complete manual engineering authoring environment.

The engineer shall be able to create Engineering Knowledge directly from engineering evidence.

This work package intentionally remains a manual workflow.

No OCR.

No AI.

No automatic extraction.

No Repository Commit.

No Foundation modifications.

The purpose is to validate the complete manual engineering authoring experience before introducing automation.

---

# Knowledge Architecture

This work package shall conform to the frozen Knowledge Architecture v1.

Implementation shall not introduce independent architectural decisions.

Architectural conflicts shall be documented and submitted for review.

---

# STUDIO-TASK-000022

## Manual Knowledge Candidate Authoring

### Purpose

Allow engineers to manually create Knowledge Candidates directly from engineering evidence.

Knowledge Candidates remain local to the active Knowledge Curation Session.

They are not Engineering Objects.

---

# Requirements

Support creating Knowledge Candidates from:

- Source Material
- Page Selection
- Evidence Region

Supported candidate types:

- Component
- Procedure
- Specification
- Tool
- Material
- Fluid
- Warning
- Measurement
- Image
- Document

Each Knowledge Candidate shall support:

- Name
- Description
- Notes
- Author
- Tags

Evidence shall be optional.

Candidates without evidence shall display a validation warning.

---

# Candidate List

Display:

- Name
- Type
- Validation Status
- Linked Evidence Count

Support:

- Create
- Edit
- Duplicate
- Delete
- Filter
- Sort

---

# STUDIO-TASK-000023

## Procedure Builder

### Purpose

Provide a dedicated editor for Procedure Knowledge Candidates.

Procedures remain entirely within the active Knowledge Curation Session.

---

# Requirements

Support:

- Ordered procedure steps
- Insert step
- Delete step
- Duplicate step
- Drag-and-drop reordering

Each step shall support:

- Title
- Description
- Notes

Each step may reference:

- Knowledge Candidates
- Evidence Regions

Display automatic step numbering.

---

# STUDIO-TASK-000024

## Specification Editor

### Purpose

Provide manual authoring for Specification Knowledge Candidates.

---

# Supported Specification Types

- Torque
- Voltage
- Resistance
- Pressure
- Temperature
- Clearance
- Measurement

Each Specification supports:

- Type
- Value
- Unit
- Notes
- Linked Evidence

Specifications remain Knowledge Candidates until Repository Commit.

---

# STUDIO-TASK-000025

## Knowledge Candidate Validation

### Purpose

Validate Knowledge Candidates before Repository Commit.

Validation remains entirely local to the active Knowledge Curation Session.

---

# Validation Rules

Detect:

- Duplicate candidate names
- Missing required fields
- Missing evidence
- Invalid relationships
- Empty procedures
- Orphaned procedure steps

Display validation status for every Knowledge Candidate.

Validation shall never modify candidate data.

---

# Property Inspector

Extend support for:

- Knowledge Candidate
- Procedure Step
- Specification
- Validation Status

Selection shall continue updating automatically.

---

# Connection Manager

Extend support for:

- Current Knowledge Candidate
- Current Procedure
- Current Procedure Step
- Current Validation State

Connection Manager continues coordinating application state only.

Business logic shall remain in services.

---

# Architecture Rules

Knowledge Candidates remain Workspace artifacts.

Foundation shall remain unaware of Knowledge Candidates.

No Repository Commit.

No Foundation modifications.

No engineering logic inside Widgets.

Validation belongs in services.

Persistence belongs in services.

Widgets consume state only.

---

# Error Handling

Handle:

- Duplicate candidate names
- Invalid specifications
- Invalid units
- Missing required fields
- Invalid procedure ordering
- Corrupted session data

Display professional validation messages.

Do not expose implementation details.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

- Manual candidate creation
- Procedure Builder
- Specification Editor
- Validation
- Property Inspector
- Session persistence
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

docs/KNOWLEDGE_CANDIDATES.md

Document:

- Knowledge Candidate model
- Procedure model
- Procedure Step model
- Specification model
- Validation model
- Session persistence changes

Document any architectural observations discovered during implementation.

---

# Definition of Done

This work package is complete when:

- Manual Knowledge Candidate authoring functions.
- Procedure Builder functions.
- Specification Editor functions.
- Validation functions.
- Documentation is complete.
- flutter analyze passes.
- flutter tests pass.
- Windows build succeeds.
- Manual verification confirms correct operation.

Stop after completion and await formal review.