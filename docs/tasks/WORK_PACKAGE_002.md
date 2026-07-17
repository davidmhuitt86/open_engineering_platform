# Work Package 0002

Title:
Official Source Registry

Status:
Approved

Milestone:
M1 – Engineering Acquisition MVP

Estimated Size:
Medium

Dependencies:

- WP-0001 Repository Bootstrap
- SDD-P001 Platform Workspace Architecture
- SDD-P002 Identity & Authentication
- SDD-P003 Capability Management
- SDD-P004 Navigation
- SDD-P005 Engineering Administration Environment

---

# Objective

Implement the Official Source Registry service.

The registry is responsible for maintaining the catalog of engineering information sources that the Open Engineering Platform recognizes and trusts.

This work package establishes the first persistent engineering domain service.

No acquisition or downloading functionality shall be implemented.

---

# Scope

Implement:

- Official Source domain model
- PostgreSQL schema
- Repository layer
- Service layer
- REST API
- Validation
- Unit tests
- Integration tests
- Flyway migration

Do NOT implement:

- Browser automation
- Download engine
- Metadata extraction
- Integrity verification
- License management
- Reference Vault
- Scheduled validation
- Authentication providers

Those belong to future work packages.

---

# Functional Requirements

The system shall support:

- Create Source
- Read Source
- Update Source
- Soft Delete Source
- List Sources
- Filter Sources
- Enable Source
- Disable Source

---

# Source Model

Each source shall contain:

- UUID
- Name
- Organization
- Base URL
- Description
- Country
- Language
- Category
- Trust Level
- Status
- Authentication Type
- Created Date
- Modified Date

Future fields shall not require schema redesign.

---

# Trust Levels

Support:

- Level 5 – Authoritative
- Level 4 – Verified Commercial
- Level 3 – Verified Community
- Level 2 – Community
- Level 1 – Unknown
- Level 0 – Blocked

---

# Source Status

Support:

- Proposed
- Approved
- Active
- Suspended
- Deprecated
- Archived

---

# Authentication Types

Support enumeration only.

No implementation required.

Values:

- None
- UsernamePassword
- ApiKey
- OAuth2
- ClientCertificate

---

# REST API

Implement:

GET

    /sources

GET

    /sources/{id}

POST

    /sources

PUT

    /sources/{id}

DELETE

    /sources/{id}

GET

    /health

Responses shall use JSON.

---

# Database

Create Flyway migration.

Implement:

official_sources

Suggested columns:

- id
- uuid
- name
- organization
- base_url
- description
- category
- country
- language
- trust_level
- status
- authentication_type
- created_at
- updated_at
- deleted_at

Soft deletes only.

---

# Validation Rules

Name required.

Base URL required.

Trust Level required.

Status required.

UUID immutable.

Created timestamp immutable.

---

# Testing

Implement:

Repository tests

Service tests

REST API tests

Migration tests

Validation tests

CRUD tests

Health endpoint tests

Target:

100% pass.

---

# Architecture Validation

Implementation shall answer:

Did implementation require architectural changes?

If yes:

Create an ADR.

Otherwise record:

Architecture validated.

---

# Completion Criteria

This work package is complete when:

- Database schema exists.
- Migration succeeds.
- CRUD operations pass.
- API endpoints pass.
- Tests pass.
- Documentation updated.
- Architecture Validation completed.
- Commit created.
- Review requested.

No additional functionality shall be implemented beyond the approved scope.