# OEP Desktop

# WORK PACKAGE 014

Status: Approved

Version: 1.0

---

# Objective

Introduce deterministic Engineering Entity Extraction.

This work package analyzes OCR text and identifies engineering entities using rule-based pattern matching.

No AI.

No LLMs.

No machine learning.

Entity extraction augments engineering evidence only.

Knowledge Candidates continue to be created only through explicit engineer approval.

---

# Knowledge Architecture

This work package shall conform to the frozen Knowledge Architecture v1.

Implementation shall not introduce independent architectural decisions.

Any architectural conflict shall be documented and submitted for review.

---

# STUDIO-TASK-000038

## Engineering Entity Extraction Engine

### Purpose

Analyze OCR text using deterministic pattern matching.

Entities are suggestions only.

No Engineering Objects or Knowledge Candidates shall be created automatically.

---

# Detect

Support recognition of:

- Torque Specifications
- Voltage Values
- Resistance Values
- Pressure Values
- Temperature Values
- Dimensions
- Fastener Sizes
- Part Numbers
- Tool References
- Fluid Specifications
- Fuse Ratings
- Connector Identifiers
- Wire Colors
- Wire Gauges

Detection shall be entirely rule based.

---

# Entity Output

Each entity records:

- UUID
- Entity Type
- Extracted Text
- Normalized Value
- Source Material
- Page
- Bounding Box
- Confidence
- Character Range

---

# STUDIO-TASK-000039

## Entity Review Workspace

### Purpose

Allow engineers to inspect extracted entities.

---

# Display

Show:

- Entity Type
- Extracted Value
- Source Page
- Confidence
- OCR Text
- Bounding Box

Support:

- Filter
- Sort
- Search
- Navigate to source

Engineers may:

- Accept
- Ignore

Acceptance shall create a Knowledge Candidate.

Ignoring shall never delete OCR evidence.

---

# STUDIO-TASK-000040

## Engineering Pattern Library

### Purpose

Centralize deterministic engineering recognition rules.

---

# Initial Pattern Categories

- Torque
- Voltage
- Resistance
- Pressure
- Temperature
- Wire Colors
- AWG
- Metric Thread Sizes
- SAE Fasteners
- Fuse Ratings
- Part Numbers

Patterns shall be configurable.

No hardcoded UI logic.

---

# STUDIO-TASK-000041

## Entity Validation

### Purpose

Validate extracted entities.

---

# Detect

- Duplicate entities
- Invalid units
- Impossible values
- Malformed specifications
- OCR uncertainty

Display validation warnings.

No automatic correction.

---

# Property Inspector

Extend support for:

- Engineering Entity
- Pattern Match
- Validation
- Source Context

---

# Connection Manager

Extend support for:

- Current Entity
- Current Pattern
- Current Validation

Connection Manager coordinates application state only.

---

# Architecture Rules

Entity extraction operates only on OCR evidence.

Engineering entities are not Knowledge Candidates.

Knowledge Candidates are created only after engineer approval.

Pattern matching belongs in services.

Widgets remain presentation only.

---

# Error Handling

Handle:

- Invalid OCR
- Unsupported units
- Pattern failures
- Corrupted OCR cache

Display professional messages.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

- Pattern matching
- Entity extraction
- Entity review
- Validation
- Candidate creation
- Session persistence

Manual verification shall be performed against real engineering documents.

If environmental limitations prevent GUI interaction, use the approved temporary integration-test strategy and remove all temporary verification code before committing.

---

# Documentation

Update:

- README.md
- docs/IMPLEMENTATION_STATUS.md
- docs/KNOWLEDGE_STUDIO.md
- docs/OCR_PIPELINE.md

Create:

docs/ENGINEERING_ENTITY_EXTRACTION.md

Document:

- Pattern engine
- Entity model
- Validation model
- Review workflow
- Pattern library
- Architectural observations

---

# Definition of Done

This work package is complete when:

- Engineering Entity Extraction functions.
- Pattern Library functions.
- Entity Review Workspace functions.
- Validation functions.
- Candidate creation from accepted entities functions.
- Documentation is complete.
- flutter analyze passes.
- flutter tests pass.
- Windows build succeeds.
- Manual verification succeeds.

Stop after completion and await formal review.