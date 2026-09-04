# Save Location

```text
oep_acquisition/
└── docs/
    └── DEVELOPER_GUIDE.md
```

---

# Document

# Engineering Acquisition Management (EAM)

## Developer Guide

**Document Status:** Ratified

**Version:** 1.0.0-M1

**Applies To:** `oep_acquisition`

---

# Purpose

This document serves as the primary onboarding guide for engineers contributing to the Engineering Acquisition Management (EAM) subsystem.

It explains the architectural philosophy, repository organization, development workflow, engineering standards, and extension points that govern development.

Every contributor should understand this document before implementing new functionality.

---

# Guiding Principle

Engineering Acquisition is **not** a downloader.

Engineering Acquisition is a deterministic pipeline that transforms external engineering artifacts into trusted engineering assets.

Every design decision within this repository exists to support that objective.

---

# Engineering Philosophy

The repository is built around several core principles.

## One Responsibility Per Component

Every subsystem owns exactly one engineering responsibility.

Components should become smaller over time—not larger.

If a component begins performing multiple unrelated tasks, it should be refactored into separate services.

---

## Pipeline Architecture

The system is intentionally linear.

```text
Official Sources
        │
        ▼
Acquisition Jobs
        │
        ▼
Execution Engine
        │
        ▼
Source Connector Framework
        │
        ▼
Engineering Downloader
        │
        ▼
Integrity Verification
        │
        ▼
Metadata Extraction
        │
        ▼
Reference Vault
```

New functionality should integrate into the appropriate stage rather than bypassing the pipeline.

---

## Deterministic Behavior

Given identical inputs, the system should produce identical outputs.

Avoid:

- hidden state
- implicit behavior
- non-deterministic processing
- side effects outside the defined pipeline

Determinism simplifies testing, debugging, and long-term maintenance.

---

## Architecture Before Features

The architecture defines where functionality belongs.

Do not place functionality into an existing component simply because it is convenient.

If the architecture does not define an appropriate location, raise the issue through the Architecture Decision Record (ADR) process.

---

# Repository Organization

A typical repository layout is shown below.

```text
oep_acquisition/

docs/
src/
include/
tests/
migrations/
cmake/
```

Each top-level directory has a single purpose.

---

# Source Layout

The source tree mirrors the architecture.

```text
src/

sources/
jobs/
execution/
connectors/
downloads/
integrity/
metadata/
vault/
api/
database/
common/
```

Each directory represents one architectural subsystem.

Cross-directory dependencies should be minimized.

---

# Layer Responsibilities

The repository is organized into distinct layers.

## Domain Layer

Defines business entities and validation rules.

Contains no database or REST dependencies.

---

## Service Layer

Implements engineering workflow.

Coordinates domain objects.

Does not contain transport logic.

---

## Repository Layer

Persists domain objects.

Responsible only for storage and retrieval.

Contains no workflow logic.

---

## API Layer

Translates HTTP requests into service calls.

Contains no engineering logic.

---

## Infrastructure Layer

Provides:

- PostgreSQL integration
- Filesystem access
- Connector implementations
- Configuration
- Logging

Infrastructure should remain replaceable.

---

# Dependency Direction

Dependencies always point inward.

```text
REST API

↓

Services

↓

Domain

↓

Repositories

↓

Infrastructure
```

Lower layers never depend on higher layers.

---

# Coding Standards

Contributors shall follow the established project conventions.

General expectations include:

- Small classes
- Single-purpose methods
- Explicit ownership
- RAII for resource management
- Const correctness where practical
- Modern C++ practices
- Clear error reporting

Code should optimize for readability and maintainability over cleverness.

---

# Error Handling

Errors should be explicit.

Prefer structured error types over ambiguous return values.

Validation failures should occur as early as practical.

Do not silently ignore errors.

---

# Testing Philosophy

Every architectural stage is independently testable.

Testing should include:

- Domain validation
- Service behavior
- Repository behavior
- REST API behavior
- Integration scenarios

Unit tests should isolate a single responsibility.

Integration tests should verify interaction between components.

---

# Database Development

Database schema evolution occurs exclusively through Flyway migrations.

Never modify an existing migration after it has been committed.

Instead:

1. Create a new migration.
2. Apply the change.
3. Update documentation.
4. Add tests.

The migration history is part of the permanent engineering record.

---

# Connector Development

New connectors should integrate through the Source Connector Framework.

Each connector should:

- implement the connector interface
- remain stateless where possible
- isolate external API behavior
- avoid embedding business logic

Connectors retrieve artifacts.

They do not validate, classify, or interpret them.

---

# Metadata Development

Metadata extraction should remain descriptive.

Appropriate additions include:

- additional file signatures
- additional document properties
- improved container inspection

Metadata extraction shall not perform:

- engineering interpretation
- semantic analysis
- document classification

Those responsibilities belong to future Engineering Knowledge Engine components.

---

# Reference Vault Development

The Reference Vault is immutable.

New functionality must preserve:

- content-addressable storage
- deterministic publication
- immutable artifacts
- traceable provenance

No feature may modify an existing published artifact.

---

# Performance Guidelines

Optimize only after correctness.

When optimization is required:

- measure first
- document the bottleneck
- preserve architectural boundaries
- avoid introducing hidden complexity

Performance improvements should not compromise determinism or maintainability.

---

# Architectural Changes

Contributors shall distinguish between implementation changes and architectural changes.

Implementation changes include:

- bug fixes
- optimizations
- new connector implementations
- additional metadata readers
- improved validation
- test improvements

Architectural changes include:

- altering stage responsibilities
- changing pipeline order
- introducing new architectural layers
- modifying trust boundaries
- changing persistence responsibilities

Architectural changes require an approved Architecture Decision Record (ADR) before implementation.

---

# Documentation Requirements

Any significant implementation change should update the appropriate documentation.

Potential updates include:

- API Reference
- Database Schema
- Pipeline Reference
- Operational Guide
- Developer Guide
- Architecture Freeze

Documentation is considered part of the implementation.

---

# Code Review Expectations

Every contribution should be evaluated against the following questions:

- Does it preserve architectural boundaries?
- Does it introduce hidden coupling?
- Does it maintain deterministic behavior?
- Does it preserve immutability where required?
- Is the new responsibility placed in the correct subsystem?
- Are tests comprehensive?
- Is documentation updated?

Architectural correctness takes precedence over implementation convenience.

---

# Common Extension Points

The architecture intentionally supports future expansion.

Examples include:

- Additional Source Connectors
- Additional file signature detection
- Expanded document inspection
- Additional validation strategies
- Performance improvements
- Additional REST endpoints that preserve existing resource boundaries

New functionality should extend existing interfaces rather than altering established responsibilities.

---

# Anti-Patterns

The following practices are prohibited within Engineering Acquisition:

- Skipping pipeline stages
- Combining multiple responsibilities into one service
- Writing directly to the Reference Vault outside the publication pipeline
- Modifying immutable records
- Embedding engineering interpretation into metadata extraction
- Circumventing repository abstractions
- Introducing hidden global state

These practices undermine the architectural guarantees established by Milestone 1.

---

# Relationship to the Open Engineering Platform

Engineering Acquisition is one subsystem within the broader Open Engineering Platform.

Its responsibility ends when trusted engineering artifacts are published into the Engineering Reference Vault.

Subsequent systems—including the Engineering Knowledge Engine, Engineering Review, Engineering Publishing, and Engineering Exchange—consume those trusted artifacts but do not participate in acquisition.

Maintaining this boundary is essential to the overall OEP architecture.

---

# Milestone 1 Development Statement

Engineering Acquisition Version 1.0.0-M1 establishes the reference implementation for pipeline-oriented engineering acquisition within the Open Engineering Platform.

Future contributors should view this repository as an architectural baseline rather than simply an implementation.

Enhancements are encouraged, provided they preserve the principles of deterministic processing, single responsibility, immutability, explicit validation, and clear separation of concerns that define the Engineering Acquisition architecture.