# WORK_PACKAGE-006

Title:
Engineering Downloader

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

- SDD-P001 Platform Workspace Architecture
- SDD-P002 Identity & Authentication
- SDD-P003 Capability Management
- SDD-P004 Platform Navigation
- SDD-P005 Engineering Administration Environment

---

# Objective

Implement the Engineering Downloader.

The Engineering Downloader is responsible for retrieving engineering artifacts through the Source Connector Framework.

The downloader shall manage acquisition requests, transfer lifecycle, progress reporting, and persistent storage of downloaded artifacts.

Integrity verification, metadata extraction, and repository publication are explicitly outside the scope of this work package.

---

# Scope

Implement:

- Downloader service
- Download request model
- Download session management
- Progress reporting
- Artifact storage
- Download history
- REST API
- Validation
- Unit tests
- Integration tests

Do NOT implement:

- Integrity verification
- Metadata extraction
- Reference Vault
- Engineering object creation
- OCR
- Document parsing
- Background scheduling
- Retry policies
- Parallel downloads

---

# Functional Requirements

The downloader shall support:

- Start Download
- Cancel Download
- Query Download Status
- Download Progress
- Download History

The downloader shall obtain engineering content exclusively through the Source Connector Framework.

No connector-specific logic shall exist inside the downloader.

---

# Download Model

Each download shall contain:

- UUID
- Job ID
- Connector ID
- Source URI
- Local Storage Path
- File Name
- MIME Type
- File Size
- Download Status
- Progress Percentage
- Started Date
- Completed Date
- Error Message

---

# Download States

Support:

- Pending
- Downloading
- Completed
- Failed
- Cancelled

Invalid transitions shall be rejected.

---

# Storage

Downloaded artifacts shall be stored in a temporary acquisition workspace.

The downloader shall not publish files into the Reference Vault.

Persistent storage location shall be configurable.

---

# REST API

Implement:

POST

    /downloads

GET

    /downloads

GET

    /downloads/{id}

GET

    /downloads/{id}/status

POST

    /downloads/{id}/cancel

Responses shall use JSON.

---

# Database

Create Flyway migrations for:

download_sessions

Store:

- identifiers
- status
- timestamps
- connector reference
- source reference
- storage location
- progress

Do not store metadata extracted from downloaded files.

---

# Validation Rules

Connector shall exist.

Connector shall be healthy.

Job shall exist.

Job shall be executable.

Download destination shall validate.

Progress shall remain between 0 and 100.

---

# Testing

Implement:

- Downloader service tests
- Repository tests
- REST API tests
- Progress tracking tests
- Validation tests
- Integration tests

Target:

100% pass.

---

# Success Criteria

This work package is considered successful when:

- Downloader implemented.
- Temporary artifact storage operational.
- Download lifecycle implemented.
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

Do not begin WORK_PACKAGE-007.