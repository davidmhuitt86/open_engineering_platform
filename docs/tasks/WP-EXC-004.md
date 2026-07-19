# TASK-EXC-0004
# Package Catalog

**Task ID:** TASK-EXC-0004

**Work Package:** WP-EXC-001

**Repository:** oep_exchange

**Status:** Planned

**Priority:** Critical

---

# 1. Objective

Implement the Engineering Package Catalog.

The Package Catalog is the authoritative registry of all published Engineering Packages within the Engineering Exchange.

---

# 2. Scope

Included:

- Package registration
- Package metadata
- Package version registration
- Package lookup
- Package listing
- Package status
- Package REST API
- Service layer
- Validation
- Repository integration
- Unit tests
- Integration tests
- Documentation

Excluded:

- Package upload
- Manifest parsing
- Package validation
- Package signing
- Search indexing
- Downloads
- Commerce
- Reviews

---

# 3. Architecture

REST API

↓

Package Service

↓

Package Repository

↓

PostgreSQL

Business logic shall remain within the Package Service.

---

# 4. API Endpoints

Implement:

GET /api/v1/packages

GET /api/v1/packages/{id}

POST /api/v1/packages

PUT /api/v1/packages/{id}

DELETE /api/v1/packages/{id}

---

# 5. Package Model

Implement support for:

- Package ID
- Publisher ID
- Package Name
- Display Name
- Description
- Category
- Current Version
- Status
- Created At
- Updated At

---

# 6. Validation

Validate:

- Required fields
- Duplicate package names within a publisher
- Invalid publisher references
- Invalid category references
- Invalid status transitions

---

# 7. Service Layer

Implement:

- PackageService
- Validation
- Mapping
- Repository interaction

No SQL outside the persistence layer.

---

# 8. Testing

Provide:

- Unit tests
- Service tests
- Repository tests
- REST API tests
- Integration tests

---

# 9. Documentation

Update:

- API documentation
- Developer Guide
- Package Catalog Guide

---

# 10. Exit Criteria

✓ Package registration works.

✓ Package lookup works.

✓ Package updates work.

✓ Validation passes.

✓ Tests pass.

✓ Documentation updated.