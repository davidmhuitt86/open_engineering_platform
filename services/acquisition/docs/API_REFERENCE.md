# Save Location

```text
oep_acquisition/
└── docs/
    └── API_REFERENCE.md
```

---

# Document

# Engineering Acquisition Management (EAM)

## API Reference

**Document Status:** Ratified

**Version:** 1.0.0-M1

**Applies To:** `oep_acquisition`

---

# Purpose

This document defines the public REST API exposed by the Engineering Acquisition Management (EAM) subsystem.

The API provides the complete interface for acquiring, validating, describing, and publishing engineering artifacts.

The API mirrors the internal acquisition pipeline. Each endpoint represents a single architectural responsibility.

All responses use JSON.

---

# API Design Principles

The API follows the architectural principles of Engineering Acquisition Management.

- Every endpoint represents one architectural stage.
- Endpoints are stateless.
- Operations are deterministic.
- Responses are JSON.
- Errors are explicit.
- Resources are immutable once published.

---

# Pipeline Overview

```text
Official Sources
        │
        ▼
Acquisition Jobs
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

Each stage consumes the output produced by the previous stage.

---

# Official Sources

## Register Source

```http
POST /sources
```

Creates a new Official Source.

### Request

```json
{
  "name": "...",
  "connector": "...",
  "configuration": { }
}
```

### Success

```http
201 Created
```

Returns the created Source.

---

## List Sources

```http
GET /sources
```

Returns all registered Official Sources.

---

## Get Source

```http
GET /sources/{id}
```

Returns the specified Official Source.

---

## Source Errors

| HTTP | Error |
|-------|-------|
|404|Source not found|
|422|Validation failed|

---

# Acquisition Jobs

## Create Job

```http
POST /jobs
```

Creates an Acquisition Job.

### Request

```json
{
  "source_id": "...",
  "schedule": "...",
  "configuration": { }
}
```

### Success

```http
201 Created
```

---

## List Jobs

```http
GET /jobs
```

---

## Get Job

```http
GET /jobs/{id}
```

---

## Job Errors

| HTTP | Error |
|-------|-------|
|404|Unknown job|
|422|Validation failed|

---

# Engineering Downloader

## Download Artifact

```http
POST /downloads
```

Creates a Download Session.

The downloader retrieves the artifact using the configured Source Connector and stores it within the temporary acquisition workspace.

---

## List Downloads

```http
GET /downloads
```

---

## Get Download

```http
GET /downloads/{id}
```

---

## Download Status

```http
GET /downloads/{id}/status
```

Returns download progress and completion state.

---

## Cancel Download

```http
POST /downloads/{id}/cancel
```

Requests cancellation of an active download.

---

## Download Errors

| HTTP | Error |
|-------|-------|
|404|Unknown download|
|409|Already completed|
|422|Validation failed|

---

# Integrity Verification

## Verify Artifact

```http
POST /verifications
```

Generates a streamed SHA-256 hash and records an immutable Verification.

---

## List Verifications

```http
GET /verifications
```

---

## Get Verification

```http
GET /verifications/{id}
```

---

## Verification Status

```http
GET /verifications/{id}/status
```

---

## Verification Errors

| HTTP | Error |
|-------|-------|
|404|Unknown verification|
|409|Verification conflict|
|422|Unknown download session|

---

# Metadata Extraction

## Extract Metadata

```http
POST /metadata
```

Extracts descriptive metadata from a successfully verified artifact.

Metadata includes file characteristics only.

No engineering interpretation occurs.

---

## List Metadata

```http
GET /metadata
```

---

## Get Metadata

```http
GET /metadata/{id}
```

---

## Metadata Status

```http
GET /metadata/{id}/status
```

---

## Metadata Errors

| HTTP | Error |
|-------|-------|
|404|Unknown metadata|
|409|Verification not successful|
|422|Validation failed|

---

# Reference Vault

## Publish Artifact

```http
POST /vault
```

Publishes an artifact into the Engineering Reference Vault.

Publication is immutable.

Artifacts are stored using content-addressable storage.

---

## List Vault Entries

```http
GET /vault
```

---

## Get Vault Entry

```http
GET /vault/{id}
```

---

## Publication Status

```http
GET /vault/{id}/status
```

---

## Vault Errors

| HTTP | Error |
|-------|-------|
|404|Unknown Vault Entry|
|409|Already published|
|422|Validation failed|

---

# Resource Relationships

The API follows the acquisition pipeline.

```text
Source

↓

Job

↓

Download

↓

Verification

↓

Metadata

↓

Vault Entry
```

Each resource references the resource immediately preceding it.

---

# Resource Lifecycle

## Official Source

```text
Create

↓

Configured

↓

Available
```

---

## Acquisition Job

```text
Create

↓

Scheduled

↓

Executed
```

---

## Download

```text
Create

↓

Running

↓

Completed

or

Cancelled
```

---

## Verification

```text
Pending

↓

Verified

or

Failed
```

Verification records are immutable.

---

## Metadata

```text
Pending

↓

Extracted

or

Failed
```

Metadata records are immutable.

---

## Vault Entry

```text
Published
```

Vault Entries are immutable.

---

# HTTP Status Codes

| Code | Meaning |
|------|---------|
|200|Success|
|201|Created|
|204|No Content|
|400|Malformed Request|
|404|Resource Not Found|
|409|Resource Conflict|
|422|Validation Failed|
|500|Internal Error|

---

# Error Response Format

Errors shall be returned using a consistent JSON structure.

Example:

```json
{
  "error": {
    "code": "unknown_metadata",
    "message": "Metadata record does not exist."
  }
}
```

Applications should rely on the error code rather than the human-readable message.

---

# API Versioning

Milestone 1 exposes Version 1 of the Engineering Acquisition API.

Breaking API changes require a new API version.

Backward-compatible enhancements may be introduced without changing the API version.

---

# Authentication

Authentication and authorization are provided by the Open Engineering Platform.

Engineering Acquisition assumes authenticated requests and does not implement its own identity provider.

Future versions may enforce capability-based authorization through the Platform Identity and Capability Management services.

---

# Transaction Model

Each POST operation represents a single atomic transaction.

Either:

- the operation completes successfully, or
- no persistent changes are made.

Partial publication is not permitted.

---

# Idempotency

GET operations are idempotent.

POST operations create new resources unless explicitly defined otherwise.

The Reference Vault prevents duplicate publication of the same Metadata record through immutable publication rules.

---

# Architectural Constraints

The API shall never expose implementation details that violate the architectural boundaries defined by the Engineering Acquisition Management Architecture Freeze.

Clients interact only with resources and operations.

Internal services, repositories, storage layouts, and execution mechanisms remain implementation details.

---

# Milestone 1 Endpoint Summary

| Resource | Endpoints |
|-----------|-----------|
|Official Sources|POST /sources<br>GET /sources<br>GET /sources/{id}|
|Acquisition Jobs|POST /jobs<br>GET /jobs<br>GET /jobs/{id}|
|Downloads|POST /downloads<br>GET /downloads<br>GET /downloads/{id}<br>GET /downloads/{id}/status<br>POST /downloads/{id}/cancel|
|Verifications|POST /verifications<br>GET /verifications<br>GET /verifications/{id}<br>GET /verifications/{id}/status|
|Metadata|POST /metadata<br>GET /metadata<br>GET /metadata/{id}<br>GET /metadata/{id}/status|
|Reference Vault|POST /vault<br>GET /vault<br>GET /vault/{id}<br>GET /vault/{id}/status|

---

# API Stability Statement

The Engineering Acquisition API defined by this document constitutes the stable public interface for Engineering Acquisition Management Version 1.0.0-M1.

Future enhancements may introduce additional endpoints and capabilities while preserving the architectural principles and resource model established by this specification. Breaking changes require a new major API version.