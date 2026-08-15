# SDD-017

# Knowledge Curation Workflow

Version: 1.0

Status: Draft

---

# Purpose

The Knowledge Curation Workflow defines how engineers transform source material into trusted engineering knowledge.

The workflow emphasizes transparency, traceability, repeatability, and engineering judgment.

Knowledge is curated.

Knowledge is never automatically accepted.

---

# Core Philosophy

The repository is not a file cabinet.

It is an engineering knowledge base.

Every action taken by the engineer should improve the quality of that knowledge.

---

# Curation Lifecycle

Every curation session follows the same lifecycle.

Source Material

↓

Preparation

↓

Analysis

↓

Review

↓

Validation

↓

Repository Preview

↓

Commit

↓

Audit

---

# Stage 1

## Preparation

The engineer selects one or more source documents.

Examples:

* Factory Service Manual
* Technical Service Bulletin
* Wiring Diagram
* Personal Notes
* Engineering Drawing
* Manufacturer Specification
* Photograph

The system creates a new Knowledge Curation Session.

During Preparation, the engineer may create Evidence Objects that identify relevant portions of the source material.

Examples include:

- Page selections
- Evidence regions
- Image annotations
- Table selections

Evidence Objects remain part of the active Knowledge Curation Session and provide traceable support for future Knowledge Candidates.

Nothing enters the repository.

---

# Stage 2

## Analysis

The platform analyzes the source.

Outputs may include:

* Components
* Procedures
* Images
* Specifications
* Measurements
* Fluids
* Warnings
* Tools
* Relationships

Each proposal contains:

* Confidence
* Supporting evidence
* Source references
* Existing repository matches

The analysis stage is read-only.

---

# Stage 3

## Review

The engineer evaluates every proposed object.

Possible actions:

Accept

Reject

Merge

Edit

Postpone

Every decision is recorded.

Rejected proposals remain part of the session history.

---

# Stage 4

## Validation

The repository is validated before any commit.

Checks include:

Duplicate Objects

Broken Relationships

Invalid References

Incomplete Procedures

Missing Evidence

Conflicting Specifications

Validation failures must be resolved before commit.

---

# Stage 5

## Repository Preview

The engineer sees exactly what will change.

The preview shall include:

New Objects

Modified Objects

Merged Objects

New Relationships

Modified Relationships

Removed Proposals

Validation Summary

Repository Statistics After Commit

The repository itself is unchanged.

---

# Stage 6

## Commit

Commit is atomic.

Either every approved object is committed or none are.

Every commit generates:

* Repository Audit Event
* Knowledge Curation Session record
* Change Summary

---

# Stage 7

## Audit

The completed session remains permanently attached to the repository.

The audit records:

* Reviewer
* Date
* Source Material
* Objects Created
* Objects Modified
* Relationships Created
* Validation Results
* Confidence Summary

---

# Engineering Review Principles

The engineer remains the authority.

Artificial Intelligence proposes.

The engineer approves.

Repository truth is established through engineering judgment.

---

# Session Recovery

Knowledge Curation Sessions shall support:

Resume

Pause

Archive

Duplicate

Export

Sessions may remain unfinished indefinitely.

---

# Batch Operations

The engineer may:

Accept All High Confidence

Reject All Low Confidence

Merge All Exact Matches

These actions remain reversible until Commit.

---

# Quality Metrics

Each session shall produce metrics.

Examples:

Objects Created

Relationships Created

Merge Rate

Duplicate Rate

Average Confidence

Manual Edits

Review Time

Validation Errors

These metrics support continuous repository improvement.

---

# Long-Term Vision

Knowledge Curation becomes an engineering discipline.

Every repository records not only what is known, but how that knowledge was established, reviewed, and validated.
