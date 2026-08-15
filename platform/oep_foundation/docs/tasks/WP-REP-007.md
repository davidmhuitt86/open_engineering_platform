# WORK PACKAGE

**ID:** WP-REP-007

**Title:** Foundation Repository Runtime – Update & Remove Engine

**Component:** platform/oep_foundation

**Priority:** Critical

**Status:** Ready

---

# Objective

Implement the Update & Remove Engine (URE).

The URE manages the lifecycle of installed Engineering Packages while preserving repository integrity.

It provides deterministic package updates, safe removal, rollback on failure, dependency impact analysis, and repository consistency guarantees.

This work package completes the Repository Package Lifecycle.

---

# Architectural Principles

The Update & Remove Engine SHALL:

- Operate exclusively through RuntimeService.
- Never bypass Transactions.
- Never bypass Dependency Resolution.
- Never bypass Repository Registry.
- Never modify installed objects directly.

All lifecycle operations are transactional.

---

# Lifecycle Pipeline

Update

```
Locate Installed Package
        │
        ▼
Verify New Package Trust
        │
        ▼
Resolve Dependencies
        │
        ▼
Analyze Impact
        │
        ▼
Begin Transaction
        │
        ▼
Replace Repository Objects
        │
        ▼
Update Registry
        │
        ▼
Commit
        │
        ▼
Publish Events
```

---

Remove

```
Locate Installed Package
        │
        ▼
Reverse Dependency Analysis
        │
        ▼
Ownership Validation
        │
        ▼
Begin Transaction
        │
        ▼
Remove Objects
        │
        ▼
Update Registry
        │
        ▼
Commit
        │
        ▼
Publish Events
```

---

# Requirements

## 1. Package Update

Support:

- newer version
- reinstall same version
- downgrade (optional flag)
- repair install
- replace metadata

---

## 2. Package Removal

Support removal of:

- package
- registry entry
- installed objects
- relationships
- metadata

No orphaned objects.

---

## 3. Dependency Impact Analysis

Before removal determine:

```
Packages affected

Objects affected

Relationships affected

Broken dependencies

Remaining graph
```

---

## 4. Removal Policies

Support:

```
Strict

Cascade

Force
```

Strict

Reject removal if dependencies exist.

Cascade

Remove dependent packages in deterministic order.

Force

Allowed only through explicit Runtime Request.

---

## 5. Repository Impact Report

Return immutable report:

```
Objects removed

Relationships removed

Packages updated

Packages removed

Dependency changes

Warnings
```

---

## 6. Rollback

Every failure restores repository to original state.

No partial removals.

No partial updates.

---

## 7. Registry Integration

Update Repository Registry atomically.

Old version removed only after new version committed.

---

## 8. Runtime Events

Publish:

```
PackageUpdated

PackageRemoved

PackageRepair

UpdateFailed

RemovalFailed
```

---

## 9. Runtime API

New Requests

```
UpdatePackageRequest

RemovePackageRequest

RepairPackageRequest

ImpactAnalysisRequest
```

---

## 10. Runtime Responses

```
UpdateResponse

RemoveResponse

ImpactReport
```

---

## 11. C API

Expose:

```
oep_package_update()

oep_package_remove()

oep_package_repair()

oep_package_analyze()
```

Increment API version.

Maintain ABI compatibility.

---

## 12. CLI

Add:

```
oep package update

oep package remove

oep package repair

oep package impact
```

---

## 13. Studio

Repository Explorer

Add:

- Update Package
- Remove Package
- Repair Package
- Impact Preview

Confirmation dialog displays immutable Impact Report.

---

## 14. Tests

Update scenarios

Downgrade

Repair

Rollback

Strict removal

Cascade removal

Force removal

Dependency analysis

Registry consistency

CLI

Studio

Regression

---

## 15. Documentation

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

Update Engine

Remove Engine

Impact Analyzer

Repair Engine

Runtime Requests

Runtime Responses

CLI

Studio

Tests

Documentation

---

# Exit Criteria

✓ Transactional updates

✓ Transactional removals

✓ Impact analysis complete

✓ Removal policies implemented

✓ Rollback verified

✓ Registry consistency maintained

✓ Runtime integration complete

✓ API updated

✓ CLI updated

✓ Studio updated

✓ Tests passing

✓ Documentation complete