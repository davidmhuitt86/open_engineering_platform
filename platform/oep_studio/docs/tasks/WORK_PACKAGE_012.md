# OEP Desktop

# WORK PACKAGE 012

Status: Approved

Version: 1.0

---

# Objective

Implement the Repository Commit Pipeline using Foundation's newly completed Public Mutation API.

This work package completes the end-to-end engineering authoring workflow by converting validated Knowledge Candidates into Foundation Engineering Objects.

No OCR.

No AI.

No automatic extraction.

All commits remain engineer initiated and engineer reviewed.

---

# Knowledge Architecture

This work package shall conform to the frozen Knowledge Architecture v1:

- SDD-013
- SDD-014
- SDD-015
- SDD-016
- SDD-017
- SDD-018
- SDD-019
- SDD-020
- SDD-021

Implementation shall not introduce independent architectural decisions.

Any architectural conflict shall be documented and submitted for review.

---

# STUDIO-TASK-000030

## Commit Planner

### Purpose

Create a deterministic Commit Plan before any repository modification occurs.

---

# Requirements

Display:

- New Engineering Objects
- New Relationships
- Existing Objects
- Merge Operations
- Validation Errors
- Warnings

The Commit Plan shall represent exactly what will be sent to Foundation.

Commit remains disabled until validation succeeds.

---

# STUDIO-TASK-000031

## Foundation Commit Bridge

### Purpose

Translate Knowledge Workspace artifacts into Foundation objects using only the Public C API.

---

# Requirements

Convert:

Knowledge Candidate

↓

Foundation Engineering Object

Convert:

Relationship Candidate

↓

Foundation Engineering Relationship

Transfer:

- Name
- Description
- Tags
- Author
- Notes

Transfer provenance references only.

Evidence remains entirely within Knowledge Workspace.

No direct Runtime access.

No hidden APIs.

---

# STUDIO-TASK-000032

## Commit Execution

### Purpose

Execute the Commit Plan through Foundation.

---

# Requirements

Use only Foundation's Public Mutation API.

Support:

- Transaction Begin
- Object Creation
- Relationship Creation
- Transaction Commit
- Transaction Rollback

Failures shall automatically roll back the complete transaction.

Knowledge Sessions remain open after successful commit.

Knowledge Candidates remain unchanged after commit.

---

# STUDIO-TASK-000033

## Commit Report

### Purpose

Present a complete summary of the Repository Commit.

---

# Display

Show:

- Objects Created
- Relationships Created
- Objects Merged
- Warnings
- Errors
- Commit Duration
- Repository Statistics Before
- Repository Statistics After

Allow exporting the report as JSON.

---

# Property Inspector

Extend support for:

- Commit Plan
- Commit Report

---

# Connection Manager

Extend with:

- Current Commit Plan
- Current Commit Report
- Commit State

Connection Manager coordinates application state only.

---

# Architecture Rules

Knowledge Workspace owns:

- Knowledge Candidates
- Evidence
- Commit Planning

Foundation owns:

- Engineering Objects
- Engineering Relationships
- Repository persistence

Repository Commit is one-way.

Knowledge Sessions become historical engineering records after commit.

Evidence remains outside Foundation.

---

# Error Handling

Handle:

- Repository unavailable
- Duplicate objects
- Duplicate relationships
- Transaction failures
- Foundation API failures
- Validation failures

Display professional messages.

Do not expose native implementation details.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

- Commit planning
- Foundation conversion
- Repository commit
- Transaction rollback
- Commit report
- Session persistence after commit

Manual verification shall be performed against a real Foundation repository.

If environmental limitations prevent direct GUI interaction, use the previously approved temporary integration-test strategy and remove all temporary verification code before committing.

---

# Documentation

Update:

- README.md
- docs/IMPLEMENTATION_STATUS.md
- docs/KNOWLEDGE_STUDIO.md
- docs/FOUNDATION_BRIDGE.md

Create:

docs/REPOSITORY_COMMIT.md

Document:

- Commit pipeline
- Candidate conversion
- Foundation integration
- Transaction model
- Provenance transfer
- Commit report

Document any architectural observations discovered during implementation.

---

# Definition of Done

This work package is complete when:

- Commit Planner functions.
- Foundation Commit Bridge functions.
- Repository Commit functions.
- Commit Report functions.
- Documentation is complete.
- flutter analyze passes.
- flutter tests pass.
- Windows build succeeds.
- Manual verification confirms successful commits into a real Foundation repository.

Stop after completion and await formal review.