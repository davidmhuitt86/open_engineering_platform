# Save Location

```text
oep_acquisition/
└── docs/
    └── DATABASE_SCHEMA.md
```

---

# Document

# Engineering Acquisition Management (EAM)

## Database Schema Reference

**Document Status:** Ratified

**Version:** 1.0.0-M1

**Applies To:** `oep_acquisition`

---

# Purpose

This document defines the persistent data model used by the Engineering Acquisition Management (EAM) subsystem.

The database mirrors the Engineering Acquisition pipeline. Every table represents a distinct architectural stage and preserves the immutable history of engineering artifact acquisition.

The schema is designed to support deterministic processing, historical traceability, and future scalability while maintaining strict separation of architectural responsibilities.

---

# Design Principles

The Engineering Acquisition database follows the principles established in the Architecture Freeze.

## Pipeline-Oriented

The database reflects the acquisition pipeline.

```text
Official Sources
        │
        ▼
Acquisition Jobs
        │
        ▼
Download Sessions
        │
        ▼
Integrity Verifications
        │
        ▼
Artifact Metadata
        │
        ▼
Reference Vault
```

Each table consumes information produced by the previous stage.

---

## Immutable Records

The following records are append-only:

- Integrity Verifications
- Artifact Metadata
- Reference Vault Entries

Historical records are never modified.

Corrections create new records rather than updating existing ones.

---

## Referential Integrity

Each stage references the immediately preceding stage using foreign keys.

No stage may reference downstream data.

---

## Deterministic Relationships

Every persistent relationship is explicit.

No implicit or inferred relationships exist within the schema.

---

# Schema Overview

```text
official_sources
        │
        ▼
acquisition_jobs
        │
        ▼
download_sessions
        │
        ▼
integrity_verifications
        │
        ▼
artifact_metadata
        │
        ▼
reference_vault
```

---

# official_sources

## Purpose

Represents trusted engineering content providers.

Each record defines a single source from which engineering artifacts may be acquired.

---

## Primary Key

```text
id
```

---

## Responsibilities

Stores:

- Source identity
- Connector type
- Connection configuration
- Authentication configuration
- Operational metadata

Does not store:

- Download history
- Artifacts
- Verification data

---

## Relationships

```text
official_sources

1

↓

Many

acquisition_jobs
```

---

# acquisition_jobs

## Purpose

Represents an engineering acquisition request.

A job defines *what* should be acquired.

Execution is handled separately.

---

## Primary Key

```text
id
```

---

## Foreign Keys

```text
official_source_id
```

References:

```text
official_sources
```

---

## Responsibilities

Stores:

- Source reference
- Acquisition parameters
- Scheduling information
- Job state

Does not store:

- Downloaded files
- Verification results

---

## Relationships

```text
official_sources

↓

acquisition_jobs

↓

download_sessions
```

---

# download_sessions

## Purpose

Represents execution of an Acquisition Job.

A Download Session records retrieval of an engineering artifact into the temporary acquisition workspace.

---

## Primary Key

```text
id
```

---

## Foreign Keys

```text
acquisition_job_id
```

References:

```text
acquisition_jobs
```

---

## Responsibilities

Stores:

- Download location
- Workspace path
- Download timestamps
- Download status

Does not store:

- SHA-256
- Metadata
- Permanent storage

---

## Relationships

```text
acquisition_jobs

↓

download_sessions

↓

integrity_verifications
```

---

# integrity_verifications

## Purpose

Represents immutable verification events.

Each verification independently validates an artifact's integrity.

---

## Primary Key

```text
id
```

---

## Foreign Keys

```text
download_session_id
```

References:

```text
download_sessions
```

---

## Responsibilities

Stores:

- SHA-256
- Verification timestamp
- Verification status
- Verification result

Does not store:

- Metadata
- Publication state

---

## Characteristics

Append-only.

Multiple verifications may exist for a single Download Session.

---

## Relationships

```text
download_sessions

↓

integrity_verifications

↓

artifact_metadata
```

---

# artifact_metadata

## Purpose

Stores descriptive information extracted from verified artifacts.

Metadata describes the artifact.

It never interprets engineering meaning.

---

## Primary Key

```text
id
```

---

## Foreign Keys

```text
verification_id
```

References:

```text
integrity_verifications
```

---

## Responsibilities

Stores:

- Filename
- Extension
- MIME type
- File size
- SHA-256 reference
- Creation timestamp
- Modification timestamp
- Extraction timestamp
- Basic document properties

Does not store:

- Engineering classification
- Engineering objects
- Knowledge relationships

---

## Characteristics

Append-only.

Multiple metadata records may exist for a single verification if future architecture permits re-extraction.

Milestone 1 currently publishes one metadata record per successful extraction.

---

## Relationships

```text
integrity_verifications

↓

artifact_metadata

↓

reference_vault
```

---

# reference_vault

## Purpose

Represents permanent publication of engineering artifacts.

The Reference Vault is the authoritative engineering archive.

---

## Primary Key

```text
id
```

---

## Foreign Keys

```text
metadata_id

verification_id

download_session_id

acquisition_job_id
```

---

## Responsibilities

Stores:

- Publication timestamp
- SHA-256
- Vault storage path
- MIME type
- File size

Does not store:

- Engineering interpretation
- Search indexes
- Knowledge relationships

---

## Characteristics

Immutable.

Content-addressable.

Permanent.

Canonical.

---

# Entity Relationship Diagram

```text
official_sources
        │
        │ 1
        ▼
acquisition_jobs
        │
        │ 1
        ▼
download_sessions
        │
        │ 1
        ▼
integrity_verifications
        │
        │ 1
        ▼
artifact_metadata
        │
        │ 1
        ▼
reference_vault
```

This linear relationship intentionally mirrors the Engineering Acquisition pipeline.

---

# Referential Integrity Rules

Every foreign key shall reference an existing parent record.

Deletion of parent records shall not silently orphan acquisition history.

Historical integrity takes precedence over convenience.

---

# Migration History

| Migration | Purpose |
|------------|---------|
|V1|Repository Bootstrap|
|V2|Official Source Registry|
|V3|Acquisition Job Engine|
|V4|Execution Engine Support|
|V5|Source Connector Framework Support|
|V6|Integrity Verifications|
|V7|Artifact Metadata|
|V8|Reference Vault|

Schema evolution is managed exclusively through Flyway migrations.

Direct modification of deployed schemas is prohibited.

---

# Indexing Strategy

Indexes exist to support:

- Primary key lookups
- Foreign key relationships
- Acquisition pipeline traversal
- Status queries
- SHA-256 lookups
- Content-addressable publication

Additional indexes shall be introduced only when supported by measured performance requirements.

---

# Transaction Boundaries

Each pipeline stage owns its own transaction.

Successful completion of one stage does not imply success of subsequent stages.

Example:

```text
Download

COMMIT

↓

Verification

COMMIT

↓

Metadata

COMMIT

↓

Publication

COMMIT
```

This preserves historical evidence even when downstream processing fails.

---

# Historical Traceability

Every Vault Entry can be traced completely back to its origin.

```text
Reference Vault
        │
        ▼
Artifact Metadata
        │
        ▼
Integrity Verification
        │
        ▼
Download Session
        │
        ▼
Acquisition Job
        │
        ▼
Official Source
```

Likewise, every Official Source can be used to enumerate every acquired artifact.

This bidirectional traceability is a core architectural objective.

---

# Data Ownership

| Table | Owns |
|--------|------|
|official_sources|Source definitions|
|acquisition_jobs|Acquisition requests|
|download_sessions|Temporary acquisition execution|
|integrity_verifications|Trust evidence|
|artifact_metadata|Descriptive artifact information|
|reference_vault|Permanent engineering artifacts|

Each table owns exactly one category of information.

No ownership overlaps another table.

---

# Out of Scope

The Engineering Acquisition database intentionally does not contain:

- Engineering Objects
- Engineering Relationships
- Knowledge Graphs
- Search indexes
- AI embeddings
- OCR output
- Parsed engineering content
- User annotations
- Marketplace assets

These belong to future OEP subsystems.

---

# Database Stability Statement

The Engineering Acquisition database schema defined by this document represents the stable persistence model for Version 1.0.0-M1.

Future schema evolution shall preserve the architectural layering established by Milestone 1.

Breaking structural changes require formal architectural review and shall be implemented through approved Flyway migrations and, where applicable, Architecture Decision Records (ADRs).