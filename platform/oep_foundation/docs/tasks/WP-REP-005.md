# WORK PACKAGE

**ID:** WP-REP-005

**Title:** Foundation Repository Runtime – Dependency Resolution Engine

**Component:** platform/oep_foundation

**Priority:** Critical

**Status:** Ready

---

# Objective

Implement the Dependency Resolution Engine (DRE).

The DRE determines whether an Engineering Package can be installed while maintaining Repository consistency.

It answers:

• What does this package require?
• Is every dependency already satisfied?
• Which versions satisfy the requested constraints?
• What installation order is valid?
• Are cycles present?
• Will installation violate repository integrity?

The DRE MUST NOT download packages.

It MUST remain provider-agnostic.

Finding packages is the responsibility of future Providers
(Local Repository, Engineering Exchange, Enterprise Repository,
Offline Archive, etc.)

The Dependency Engine only evaluates dependency graphs.

---

# Architecture

```
Install Package
        │
        ▼
Trust Verification
        │
        ▼
Dependency Resolution
        │
        ▼
Transaction Begin
        │
        ▼
Install Objects
        │
        ▼
Commit
```

Dependency Resolution MUST occur AFTER Trust and BEFORE Transactions.

---

# Requirements

## 1. Dependency Manifest

Support package manifest section:

```json
{
  "dependencies":
  [
      {
          "package":"org.divad.foundation",
          "version":">=1.2.0"
      },
      {
          "package":"org.iso.16750",
          "version":"^3.1"
      }
  ]
}
```

---

## 2. Semantic Version Constraints

Implement:

```
=
!=
>
>=
<
<=

^

~

*
```

Examples:

```
>=1.0.0

^2.1

~3.4

*

```

---

## 3. Version Parser

Create immutable Version object.

Supports:

```
major
minor
patch

pre-release

build metadata
```

RFC 9110 style semantic versioning.

---

## 4. Version Comparator

Implement total ordering.

Examples:

```
1.0.0

1.0.1

1.1.0

2.0.0

2.0.0-alpha

2.0.0-beta

2.0.0
```

---

## 5. Dependency Graph

Represent repository dependency graph.

Nodes

Edges

Parents

Children

Reverse lookup

Traversal

---

## 6. Resolver

Determine:

Satisfied

Missing

Conflict

Ambiguous

Unsatisfied

---

## 7. Installation Order

Produce deterministic topological ordering.

Example

```
Library

↓

Connector

↓

Standard

↓

Application
```

---

## 8. Cycle Detection

Reject:

```
A → B

B → C

C → A
```

Return full cycle diagnostics.

---

## 9. Missing Dependency Report

Return diagnostics:

```
Missing package

Requested version

Constraint

Candidate versions

Resolution recommendation
```

---

## 10. Repository Runtime Integration

FoundationRuntime::install_package()

Flow becomes:

```
Verify Trust

↓

Resolve Dependencies

↓

Open Transaction

↓

Install

↓

Commit
```

---

## 11. Public Runtime API

Add:

```
resolve_dependencies()

check_dependencies()

dependency_graph()

dependency_tree()

reverse_dependencies()

install_order()
```

---

## 12. C API

Expose equivalent functions.

Increment API version.

Maintain ABI compatibility.

---

## 13. CLI

New commands

```
oep repository dependencies PACKAGE

oep repository tree PACKAGE

oep repository reverse PACKAGE

oep repository graph PACKAGE

oep repository check PACKAGE
```

---

## 14. Studio

Engineering Workspace

Package Inspector

Dependency Viewer

Dependency Tree

Missing Dependency Diagnostics

---

## 15. Tests

Version parsing

Version comparison

Constraint evaluation

Dependency graph

Cycles

Topological sort

Reverse lookup

Repository integration

CLI

Studio

---

## 16. Documentation

Update

Repository Runtime README

CLI README

API README

TASK.md

CURRENT_SPRINT.md

PROJECT_STATUS.md

Architecture diagrams

---

# Deliverables

Dependency Engine

Version parser

Version comparator

Constraint engine

Dependency graph

Runtime APIs

CLI

Studio integration

Tests

Documentation

---

# Exit Criteria

✓ Semantic versions implemented

✓ Constraint engine complete

✓ Deterministic resolver

✓ Topological installation order

✓ Cycle detection

✓ Repository integration

✓ API complete

✓ CLI complete

✓ Studio complete

✓ Tests passing

✓ Documentation updated