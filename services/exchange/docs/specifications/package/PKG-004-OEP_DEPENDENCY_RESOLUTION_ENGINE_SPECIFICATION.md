# PKG-004
# OEP Dependency Resolution Engine (DRE) Specification

**Specification ID:** PKG-004

**Title:** OEP Dependency Resolution Engine Specification

**Status:** Draft 1.0

**Authority:** Open Engineering Platform Specification

**Depends On:**
- PKG-001 Package Format
- PKG-002 Package Manifest
- PKG-003 Package Transaction Engine

---

# 1. Purpose

The Dependency Resolution Engine (DRE) is responsible for determining whether an OEP package can be safely installed into a Repository.

The DRE analyzes package dependencies, version constraints, capability requirements, repository state, and platform compatibility before any repository modifications occur.

The DRE never modifies the repository.

It produces a Dependency Resolution Report consumed by the Package Transaction Engine.

---

# 2. Design Principles

The DRE shall be:

- Deterministic
- Stateless
- Side-effect free
- Repeatable
- Explainable
- Extensible

Given the same repository state and package set, the DRE shall always produce the same result.

---

# 3. Responsibilities

The DRE is responsible for:

- Dependency analysis
- Version compatibility
- Capability verification
- Platform compatibility
- Studio compatibility
- Circular dependency detection
- Conflict identification
- Resolution planning

The DRE shall never perform installation.

---

# 4. Inputs

The DRE consumes:

- Package Manifest
- Installed Package Registry
- Repository Metadata
- Platform Version
- Installed Capability Registry
- Installed Studio Registry

---

# 5. Outputs

The DRE produces a Dependency Resolution Report.

The report contains:

- Resolution Status
- Required Packages
- Optional Packages
- Missing Packages
- Version Conflicts
- Capability Requirements
- Compatibility Results
- Warnings
- Errors
- Recommended Actions

---

# 6. Resolution States

Every dependency shall resolve to one of:

Satisfied

Missing

Optional

Conflicting

Deprecated

Superseded

Unsupported

Unknown

---

# 7. Dependency Types

The DRE recognizes several dependency categories.

## Required Package

Installation cannot proceed without it.

---

## Optional Package

Enhances functionality but is not required.

---

## Recommended Package

Provides additional engineering capabilities.

Installation may continue without it.

---

## Incompatible Package

Cannot coexist with another package.

---

## Replacement Package

Supersedes an existing package.

---

## Virtual Capability

A dependency may target a capability rather than a specific package.

Example:

Electrical Simulation

rather than

simulation.engine.v2

This allows multiple implementations to satisfy the same engineering capability.

---

# 8. Version Constraints

Supported operators include:

=

!=

>

>=

<

<=

Compatible (~)

Caret (^)

Version ranges

Examples:

>=2.0

<5.0

^4.1

~3.8

---

# 9. Capability Resolution

Capabilities are resolved independently from packages.

Examples:

Diagram Editing

Electrical Validation

Simulation

Knowledge Navigation

AI Analysis

A capability may be provided by multiple installed packages.

The DRE resolves capabilities before resolving package identity.

---

# 10. Circular Dependency Detection

The DRE shall detect cycles.

Example:

Package A requires B

Package B requires C

Package C requires A

Circular dependencies terminate resolution.

---

# 11. Repository Compatibility

The DRE verifies:

Repository schema

Repository specification version

Repository feature set

Repository capabilities

Repository state

---

# 12. Platform Compatibility

The DRE verifies:

Platform Version

Foundation Version

Studio Version

Specification Versions

Operating System Requirements

Architecture Requirements

---

# 13. Studio Compatibility

Packages may declare required Studios.

Examples:

Diagram Studio

Knowledge Studio

Simulation Studio

Repair Studio

Missing required Studios generate installation errors.

---

# 14. Capability Registry

Capabilities are identified by globally unique IDs.

Examples:

oep.capability.diagram

oep.capability.validation

oep.capability.simulation

Capabilities are versioned independently from packages.

---

# 15. Conflict Detection

The DRE detects:

Duplicate Package IDs

Duplicate Capability Providers

Version Conflicts

License Conflicts

Specification Conflicts

Deprecated Components

Publisher Restrictions

Repository Ownership Conflicts

---

# 16. Resolution Report

The report includes:

Overall Result

Dependency Graph

Package Tree

Capability Tree

Warnings

Errors

Recommended Actions

Estimated Downloads

Estimated Storage

The report is immutable.

---

# 17. Automatic Resolution

Implementations may optionally support automatic dependency acquisition.

The DRE may recommend additional packages.

The DRE shall never download packages directly.

Package acquisition is the responsibility of the Engineering Exchange or another package source.

---

# 18. Offline Operation

The DRE shall operate without network connectivity.

When dependencies cannot be verified offline, the report shall indicate unresolved external dependencies.

---

# 19. Events

The DRE publishes informational events.

Examples:

DependencyAnalysisStarted

DependencyResolved

DependencyMissing

ConflictDetected

ResolutionCompleted

The DRE shall not publish repository modification events.

---

# 20. Extensibility

Future specifications may introduce:

Conditional dependencies

Enterprise policy constraints

Regional package restrictions

Security classifications

Hardware requirements

Certification requirements

AI model dependencies

without altering the core resolution process.

---

# 21. Conformance

An implementation claiming compliance with PKG-004 shall:

- Resolve all declared dependencies.
- Detect circular dependency graphs.
- Validate version constraints.
- Verify capability requirements.
- Produce a deterministic Dependency Resolution Report.
- Never modify repository state.