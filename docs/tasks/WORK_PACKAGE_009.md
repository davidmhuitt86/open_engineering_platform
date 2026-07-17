# WORK_PACKAGE-009

Title:
Engineering Reference Vault

Status:
Approved

Milestone:
M1 – Engineering Acquisition MVP

Estimated Size:
Large

Dependencies:

- WORK_PACKAGE-001
- WORK_PACKAGE-002
- WORK_PACKAGE-003
- WORK_PACKAGE-004
- WORK_PACKAGE-005
- WORK_PACKAGE-006
- WORK_PACKAGE-007
- WORK_PACKAGE-008

- ADR-0008 Connector Content Retrieval Interface

- SDD-P001 Platform Workspace Architecture
- SDD-P002 Identity & Authentication
- SDD-P003 Capability Management
- SDD-P004 Platform Navigation
- SDD-P005 Engineering Administration Environment

---

# Objective

Implement the Engineering Reference Vault.

The Reference Vault is the authoritative, immutable repository for verified engineering artifacts acquired by the Engineering Acquisition Management (EAM) system.

The Reference Vault shall receive only successfully verified artifacts with successfully extracted metadata.

No engineering interpretation or Engineering Object creation shall occur.

---

# Scope

Implement:

- Reference Vault Service
- Vault Repository
- Vault Object Model
- Artifact Publication
- Immutable Storage
- Vault History
- REST API
- Validation
- Unit Tests
- Integration Tests

Do NOT implement:

- Engineering Object creation
- Knowledge graph generation
- OCR
- AI analysis
- Search indexing
- Version comparison
- Duplicate detection
- Lifecycle management

---

# Functional Requirements

The Reference Vault shall support:

- Publish Verified Artifact
- Retrieve Vault Entry
- List Vault Entries
- View Publication Status
- View Publication History

Only artifacts with successful Integrity Verification and successful Metadata Extraction may be published.

Publication shall be immutable.

---

# Vault Model

Each Vault Entry shall contain:

- UUID
- Metadata ID
- Verification ID
- Download Session ID
- Original Source ID
- Vault Storage Path
- SHA-256 Hash
- MIME Type
- File Size
- Publication Timestamp
- Publication Status

Vault entries shall be immutable after publication.

---

# Storage

Published artifacts shall be copied from the temporary acquisition workspace into the permanent Reference Vault.

The Reference Vault location shall be configurable independently of the acquisition workspace.

Temporary acquisition files shall remain unchanged.

The Reference Vault shall become the canonical source for all downstream engineering systems.

---

# REST API

Implement:

POST

    /vault

GET

    /vault

GET

    /vault/{id}

GET

    /vault/{id}/status

Responses shall use JSON.

---

# Database

Create Flyway migration for:

reference_vault

Store:

- UUID
- Metadata ID
- Verification ID
- Download Session ID
- Source ID
- Vault Path
- SHA-256
- MIME Type
- File Size
- Publication Timestamp
- Status

No engineering interpretation shall be stored.

---

# Validation Rules

Metadata record shall exist.

Metadata extraction shall be successful.

Verification shall be successful.

Published artifact shall exist.

SHA-256 shall match the Verification record.

Vault path shall validate.

Publication shall be immutable.

---

# Testing

Implement:

- Vault service tests
- Repository tests
- REST API tests
- Publication tests
- Validation tests
- Integration tests

Target:

100% pass.

---

# Success Criteria

This work package is considered successful when:

- Reference Vault implemented.
- Permanent storage operational.
- Artifact publication implemented.
- Immutable storage enforced.
- REST API implemented.
- Database migration succeeds.
- Tests pass.
- Documentation updated.
- Repository builds successfully.
- Architecture Validation completed.
- Code committed.
- Review requested.

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

This work package is complete only when:

- Scope fully implemented.
- All tests pass.
- Documentation updated.
- Architecture Validation completed.
- Code committed.
- Review requested.

Milestone 1 shall then be considered complete.

Do not begin Milestone 2.