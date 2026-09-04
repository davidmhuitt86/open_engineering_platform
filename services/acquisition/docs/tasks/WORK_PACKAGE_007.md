# WORK_PACKAGE-007

Title:
Engineering Integrity Verification Engine

Status:
Approved

Milestone:
M1 – Engineering Acquisition MVP

Estimated Size:
Medium

Dependencies:

- WORK_PACKAGE-001
- WORK_PACKAGE-002
- WORK_PACKAGE-003
- WORK_PACKAGE-004
- WORK_PACKAGE-005
- WORK_PACKAGE-006

- ADR-0008 Connector Content Retrieval Interface

- SDD-P001 Platform Workspace Architecture
- SDD-P002 Identity & Authentication
- SDD-P003 Capability Management
- SDD-P004 Platform Navigation
- SDD-P005 Engineering Administration Environment

---

# Objective

Implement the Engineering Integrity Verification Engine.

The Integrity Verification Engine is responsible for validating the integrity of engineering artifacts immediately after acquisition and before any metadata extraction or repository publication.

No metadata extraction or engineering object creation shall be performed.

---

# Scope

Implement:

- Integrity Verification Service
- Verification Result model
- Hash generation
- Hash validation
- File validation
- Verification history
- REST API
- Validation
- Unit tests
- Integration tests

Do NOT implement:

- Metadata extraction
- OCR
- Document parsing
- Engineering object creation
- Reference Vault publication
- Digital signatures
- Malware scanning
- License validation

---

# Functional Requirements

The engine shall support:

- Verify Downloaded Artifact
- Generate Cryptographic Hashes
- Verify Existing Hashes
- Detect Missing Files
- Detect Corrupt Files
- Record Verification History

Verification shall execute only against artifacts produced by the Engineering Downloader.

---

# Verification Model

Each verification shall contain:

- UUID
- Download Session ID
- Verification Status
- SHA-256 Hash
- File Size
- Verification Timestamp
- Error Message

Future verification algorithms shall be extensible.

---

# Verification States

Support:

- Pending
- Verified
- Failed

Invalid transitions shall be rejected.

---

# Hash Algorithms

Implement:

- SHA-256

Architecture shall support additional algorithms in future revisions without redesign.

---

# REST API

Implement:

POST

    /verifications

GET

    /verifications

GET

    /verifications/{id}

GET

    /verifications/{id}/status

Responses shall use JSON.

---

# Database

Create Flyway migration for:

integrity_verifications

Store:

- UUID
- Download Session ID
- Status
- SHA-256
- File Size
- Timestamp
- Error Message

No metadata shall be stored.

---

# Validation Rules

Download session shall exist.

Downloaded artifact shall exist.

Artifact shall not be empty.

SHA-256 shall always be generated.

Missing files shall fail verification.

Corrupt files shall fail verification.

---

# Testing

Implement:

- Verification service tests
- Repository tests
- REST API tests
- Hash validation tests
- Missing file tests
- Corrupt file tests
- Integration tests

Target:

100% pass.

---

# Success Criteria

This work package is considered successful when:

- Verification Engine implemented.
- SHA-256 generation implemented.
- Verification history implemented.
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

Do not begin WORK_PACKAGE-008.