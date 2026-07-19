# TASK-EXC-0002
# Exchange Database & Persistence Layer

**Task ID:** TASK-EXC-0002

**Work Package:** WP-EXC-001

**Repository:** oep_exchange

**Status:** Planned

**Priority:** Critical

---

# 1. Objective

Design and implement the initial Exchange database schema and persistence layer.

This task establishes the authoritative PostgreSQL schema, Flyway migrations, repositories, and persistence abstractions required by the Engineering Exchange.

The schema shall support the current MVP while remaining extensible for future specifications without requiring disruptive redesign.

---

# 2. Scope

Included:

- PostgreSQL schema
- Flyway migrations
- Persistence package
- Repository pattern
- Database configuration
- Connection management
- Initial seed data
- Migration verification
- Database integration tests

Excluded:

- Business logic
- Upload pipeline
- Publisher authentication
- Search indexing
- Commerce
- Reviews
- Federation

---

# 3. Architecture

Persistence shall remain isolated.

Applications

↓

Services

↓

Repositories

↓

Persistence Layer

↓

PostgreSQL

No service or controller may issue SQL directly.

---

# 4. Database Tables

Implement the initial schema.

### publishers

Stores publisher identity.

### publisher_profiles

Stores public profile information.

### packages

Package metadata.

### package_versions

Individual published versions.

### package_categories

Classification.

### package_files

Physical package artifacts.

### downloads

Download history.

### audit_log

Exchange audit events.

---

# 5. Flyway

Create versioned migrations.

Example:

V1__initial_exchange_schema.sql

V2__seed_categories.sql

V3__seed_reference_data.sql

Every schema change shall occur through Flyway.

---

# 6. Repository Interfaces

Define repository interfaces for:

PublisherRepository

PackageRepository

PackageVersionRepository

CategoryRepository

DownloadRepository

AuditRepository

Interfaces belong in packages/interfaces.

Implementations belong in persistence packages.

---

# 7. Persistence Package

Create:

packages/persistence

Responsibilities:

- Database access
- SQL
- Transactions
- Mapping
- Repository implementations

No business rules.

---

# 8. Database Standards

Use:

UUID primary keys

CreatedAt

UpdatedAt

Optimistic version fields

Foreign key constraints

Indexes

Unique constraints

Check constraints where appropriate

---

# 9. Seed Data

Provide initial categories.

Example:

Automotive

Industrial

Residential

Commercial

Marine

Powersports

Robotics

Education

Reference data must be versioned.

---

# 10. Testing

Provide:

Migration tests

Repository tests

Constraint tests

Transaction tests

Rollback tests

---

# 11. Documentation

Update:

DATABASE.md

ERD.md

Migration Guide

Repository Guide

---

# 12. Exit Criteria

✓ Fresh database builds successfully.

✓ Flyway completes successfully.

✓ Seed data loads.

✓ Repository tests pass.

✓ Integration tests pass.

✓ Documentation updated.

✓ No SQL exists outside persistence.