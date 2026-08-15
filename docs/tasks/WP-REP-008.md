# WORK PACKAGE

**ID:** WP-REP-008

**Title:** Foundation Repository Runtime – Merge & Ownership Engine

**Component:** platform/oep_foundation

**Priority:** Critical

**Status:** Ready

---

# Objective

Implement the Merge & Ownership Engine (MOE).

The MOE enables multiple Engineering Packages and multiple engineering organizations to safely contribute to a shared Repository while preserving provenance, ownership, and engineering integrity.

Unlike source control systems, the Merge Engine operates on Engineering Objects and Relationships rather than text files.

This completes the Repository Runtime architecture.

---

# Architectural Principles

The Merge Engine SHALL:

- Operate exclusively through RuntimeService.
- Never modify Repository state outside a Transaction.
- Never bypass Trust or Dependency Resolution.
- Preserve complete provenance.
- Preserve engineering history.
- Produce deterministic merge results.

---

# Architecture

```
Repository A
        │
        ▼
Repository Change Set
        │
        ▼
Ownership Analysis
        │
        ▼
Conflict Detection
        │
        ▼
Merge Planner
        │
        ▼
Transaction
        │
        ▼
Repository Update
        │
        ▼
Events
```

---

# Ownership Model

Every Engineering Object SHALL contain immutable ownership metadata.

Minimum:

```
Owner ID

Package ID

Publisher

Repository

Created

Modified

Version
```

Ownership metadata is immutable once recorded.

Updates create new ownership records.

---

# Provenance Model

Every Repository mutation records provenance.

Track:

```
Source Repository

Publishing Package

Transaction

Timestamp

Trust Fingerprint

Merge Operation
```

---

# Repository Change Set

Introduce immutable RepositoryChangeSet.

Contains:

```
Object Changes

Relationship Changes

Package Changes

Registry Changes
```

Change Sets become the canonical description of Repository mutations.

---

# Conflict Detection

Detect:

```
Object conflict

Relationship conflict

Package conflict

Registry conflict

Ownership conflict

Version conflict
```

Return immutable Conflict Report.

---

# Conflict Policies

Support:

```
Reject

Prefer Local

Prefer Incoming

Manual Resolution
```

Policy selected through RuntimeRequest.

---

# Merge Planner

Generate deterministic Merge Plan.

Contains:

```
Safe operations

Conflicts

Skipped operations

Required actions
```

No Repository mutation occurs during planning.

---

# Merge Execution

Pipeline:

```
Analyze

↓

Plan

↓

Validate

↓

Transaction

↓

Apply Change Set

↓

Update Registry

↓

Commit

↓

Publish Events
```

---

# Runtime Requests

Add:

```
MergeRepositoryRequest

MergePackageRequest

MergeChangeSetRequest

OwnershipQueryRequest

ConflictAnalysisRequest
```

---

# Runtime Responses

Add:

```
MergeResponse

ConflictReport

OwnershipReport

MergePlan
```

---

# Runtime Events

Publish:

```
MergeStarted

MergeCompleted

MergeRejected

ConflictDetected

OwnershipChanged
```

---

# Repository Queries

Support:

```
Who owns this object?

Which package introduced it?

What transaction created it?

Where did it originate?

What repositories modified it?
```

---

# Public Runtime API

Expose merge and ownership through RuntimeService.

Legacy APIs remain unchanged.

---

# C API

Add:

```
oep_repository_merge()

oep_repository_plan_merge()

oep_repository_conflicts()

oep_repository_ownership()

oep_repository_changeset()
```

Increment API version.

Maintain ABI compatibility.

---

# CLI

Add:

```
oep repository merge

oep repository plan

oep repository conflicts

oep repository ownership

oep repository changeset
```

---

# Studio

Repository Explorer

Add:

Merge Preview

Ownership Inspector

Conflict Viewer

Merge Plan

Repository History

---

# Tests

Ownership

Conflict detection

Merge planning

Transactions

Rollback

Policy handling

API

CLI

Studio

Regression

---

# Documentation

Update:

Repository Runtime README

API README

CLI README

Architecture diagrams

TASK.md

CURRENT_SPRINT.md

PROJECT_STATUS.md

---

# Deliverables

Ownership Engine

Provenance Engine

Repository Change Set

Conflict Detection

Merge Planner

Merge Execution

Runtime Requests

Runtime Responses

CLI

Studio

Tests

Documentation

---

# Exit Criteria

✓ Ownership model implemented

✓ Provenance tracking complete

✓ Repository Change Set implemented

✓ Conflict detection complete

✓ Merge planner operational

✓ Transactional merge execution

✓ Runtime integration complete

✓ API updated

✓ CLI updated

✓ Studio updated

✓ Tests passing

✓ Documentation complete