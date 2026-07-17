# Engineering Acquisition API Specification

**Repository:** oep_acquisition

**Document:** API_SPECIFICATION.md

**Status:** Draft

**Version:** 1.0

**Applies To:** Engineering Acquisition Manager

---

# 1. Purpose

This specification defines the external interfaces exposed by the Engineering Acquisition Manager.

The API provides deterministic access to acquisition services while maintaining integrity, provenance, and traceability.

This specification defines:

- REST APIs
- Future gRPC interfaces
- Event contracts
- Commands
- Queries
- Authentication
- Versioning
- Error handling

---

# 2. Design Principles

The API shall be:

- Resource-oriented
- Versioned
- Deterministic
- Idempotent where applicable
- Secure
- Observable
- Event-driven
- Backward compatible

---

# 3. API Architecture

```
Applications

↓

REST API

↓

Command Layer

↓

Domain Services

↓

Repository Layer

↓

PostgreSQL

↓

Event Bus
```

---

# 4. Base URL

```
/api/v1
```

Future versions

```
/api/v2
```

Breaking changes require a new major version.

---

# 5. Authentication

Supported authentication methods

- OAuth2
- OpenID Connect
- API Keys
- Enterprise SSO
- Service Accounts
- JWT Bearer Tokens

Every request shall be authenticated unless explicitly designated as public.

---

# 6. Authorization

Permissions are role-based.

Example roles

- Administrator
- Engineer
- Reviewer
- Acquisition Operator
- Read Only
- Service Account

Authorization policies are evaluated before command execution.

---

# 7. Core Resources

Resources include

```
Organizations

Endpoints

Services

Acquisitions

Acquisition Records

Vault Objects

Licenses

Integrity Records

Metadata

Jobs

Events
```

---

# 8. Commands

Examples

```
POST /organizations

POST /acquisitions

POST /licenses

POST /jobs

POST /metadata

POST /integrity/verify

POST /vault/publish
```

Commands modify state.

---

# 9. Queries

Examples

```
GET /organizations

GET /organizations/{id}

GET /acquisitions

GET /acquisitions/{id}

GET /licenses

GET /metadata

GET /events

GET /vault
```

Queries never modify state.

---

# 10. Search

Search endpoints

```
GET /search

GET /organizations/search

GET /vault/search

GET /metadata/search
```

Search supports

- full text
- semantic search
- structured filters
- metadata filters
- date ranges
- organization filters

---

# 11. Jobs

Long-running operations execute as Jobs.

Examples

- OCR
- Metadata extraction
- Integrity verification
- Batch acquisition
- Duplicate analysis
- Revision analysis

Job states

Pending

↓

Running

↓

Completed

↓

Failed

↓

Cancelled

---

# 12. Events

Every significant operation publishes an event.

Examples

OrganizationRegistered

EndpointVerified

AcquisitionStarted

AcquisitionCompleted

AcquisitionFailed

IntegrityVerified

DuplicateDetected

RevisionDetected

VaultPublished

MetadataExtracted

LicenseUpdated

JobCompleted

Events are immutable.

---

# 13. Event Structure

Every event contains

| Field | Type |
|---------|------|
| event_id | UUID |
| event_type | String |
| timestamp | Timestamp |
| actor | User/System |
| aggregate_id | UUID |
| schema_version | String |
| payload | Object |

---

# 14. Pagination

Collections support

```
limit

offset

cursor
```

Cursor pagination is preferred.

---

# 15. Filtering

Supported filters

Organization

Trust Level

Acquisition Date

Lifecycle

Status

License Type

Engineering Domain

Hash

Metadata

---

# 16. Sorting

Supported sorting

Ascending

Descending

Multiple fields

Stable ordering

---

# 17. Error Model

Standard HTTP status codes

200 OK

201 Created

204 No Content

400 Bad Request

401 Unauthorized

403 Forbidden

404 Not Found

409 Conflict

422 Validation Error

500 Internal Error

Errors return

- code
- message
- details
- correlation_id

---

# 18. Idempotency

Commands that create resources may support Idempotency Keys.

Repeated requests with identical keys shall not create duplicate resources.

---

# 19. API Versioning

Breaking changes

Major Version

Compatible additions

Minor Version

Bug fixes

Patch Version

---

# 20. Observability

Every request shall produce

- Request ID
- Correlation ID
- Timing
- User
- Service
- Result

Logs must support distributed tracing.

---

# 21. Future Interfaces

Reserved for

- gRPC
- GraphQL
- WebSockets
- Event Streaming
- MCP Integration
- Repository Federation
- Enterprise Message Bus

---

# 22. Summary

The Engineering Acquisition API provides a deterministic, secure, and event-driven interface for acquiring, verifying, cataloging, and publishing engineering evidence within the Open Engineering Platform.

The API serves as the primary integration contract between the Engineering Acquisition Manager and the remainder of the OEP ecosystem.