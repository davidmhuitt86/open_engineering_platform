# Acquisition Record Schema

**Repository:** oep_acquisition

**Document:** ACQUISITION_RECORD_SCHEMA.md

**Status:** Draft

**Version:** 1.0

**Applies To:** Engineering Acquisition Manager

---

# 1. Purpose

This specification defines the canonical schema for Acquisition Records.

An Acquisition Record represents an immutable historical event documenting how an engineering artifact entered the Open Engineering Platform.

This specification defines:

- object structure
- required fields
- optional fields
- relationships
- validation rules
- lifecycle
- constraints

---

# 2. Design Principles

Acquisition Records shall be:

- immutable
- globally unique
- deterministic
- append-only
- relationship aware
- fully traceable

Acquisition Records shall never be edited after creation.

Corrections shall be represented through additional events.

---

# 3. Object Definition

An Acquisition Record consists of the following sections.

```text
Acquisition Record

├── Identity
├── Acquisition
├── Source
├── Integrity
├── Licensing
├── Metadata
├── Relationships
├── Provenance
├── Chain of Custody
├── Lifecycle
└── Audit
```

---

# 4. Identity

Required fields

| Field | Type | Required |
|---------|---------|----------|
| acquisition_id | UUID | Yes |
| schema_version | String | Yes |
| created_at | Timestamp | Yes |
| created_by | User ID | Yes |
| repository_version | String | Yes |

Rules

- acquisition_id is immutable
- UUIDs shall never be reused

---

# 5. Acquisition

Defines the acquisition event.

Fields

| Field | Type |
|---------|---------|
| acquisition_method | Enum |
| acquisition_time | Timestamp |
| acquisition_status | Enum |
| acquisition_duration | Integer |
| acquisition_session | UUID |

Allowed acquisition methods

- Browser
- API
- Drag and Drop
- Local File
- USB
- Scanner
- Email
- Git
- Cloud Storage
- Laboratory Instrument
- Manual

---

# 6. Source

Describes where the artifact originated.

Fields

| Field | Type |
|---------|---------|
| organization_id | UUID |
| endpoint_id | UUID |
| service_id | UUID |
| source_url | URI |
| referrer | URI |
| redirect_chain | Array |
| original_filename | String |

---

# 7. Integrity

Fields

| Field | Type |
|---------|---------|
| sha256 | Hash |
| sha512 | Hash |
| blake3 | Hash |
| content_length | Integer |
| mime_type | String |
| integrity_verified | Boolean |

Validation

At least one cryptographic hash is required.

SHA-256 is mandatory.

---

# 8. Source Verification

Fields

| Field | Type |
|---------|---------|
| dns_name | String |
| resolved_ip | String |
| tls_certificate | Reference |
| certificate_fingerprint | String |
| http_headers | Object |
| server | String |
| etag | String |
| last_modified | Timestamp |

---

# 9. Licensing

Fields

| Field | Type |
|---------|---------|
| license_id | UUID |
| vendor | String |
| purchase_date | Date |
| invoice | Reference |
| expiration | Date |
| redistribution | Enum |
| seat_count | Integer |

Licensing information is mutable.

Licensing changes do not modify Acquisition history.

---

# 10. Metadata

Fields

| Field | Type |
|---------|---------|
| title | String |
| author | String |
| organization | String |
| revision | String |
| publication_date | Date |
| language | String |
| keywords | Array |
| engineering_domain | Enum |

Metadata may be refined over time.

Original captured metadata shall remain available.

---

# 11. Relationships

Relationships may reference

- Vault Objects
- Organizations
- Licenses
- Projects
- Engineering Knowledge Objects
- Previous Acquisition Records
- Later Acquisition Records

Relationship IDs are immutable.

---

# 12. Provenance

Fields

| Field | Type |
|---------|---------|
| acquisition_origin | Enum |
| verification_status | Enum |
| evidence_level | Enum |
| trust_level | Enum |

These values describe confidence.

They do not determine engineering truth.

---

# 13. Chain of Custody

Each custody event contains

| Field | Type |
|---------|---------|
| event_id | UUID |
| timestamp | Timestamp |
| actor | String |
| event_type | Enum |
| description | String |
| software_version | String |

Events are append-only.

---

# 14. Lifecycle

Allowed lifecycle states

```text
Pending

↓

Acquired

↓

Verified

↓

Published

↓

Archived
```

Lifecycle history is permanent.

---

# 15. Validation Rules

The validator shall enforce

✓ UUID uniqueness

✓ Required fields

✓ Required hashes

✓ Timestamp validity

✓ Relationship integrity

✓ Lifecycle transitions

✓ Schema version

✓ Enum validation

---

# 16. Future Extensions

Reserved sections

- Digital Signatures

- Blockchain Anchors

- Enterprise Compliance

- Regulatory Certifications

- Laboratory Accreditation

No schema redesign shall be required.

---

# 17. Example

```yaml
identity:
  acquisition_id:
  schema_version:
  created_at:

acquisition:
  acquisition_method:
  acquisition_time:

source:
  organization_id:
  endpoint_id:
  source_url:

integrity:
  sha256:
  blake3:

licensing:

metadata:

relationships:

provenance:

custody_events:

lifecycle:
```

---

# 18. Summary

The Acquisition Record Schema defines the immutable historical representation of engineering acquisition within the Open Engineering Platform.

Every engineering artifact entering OEP shall possess at least one Acquisition Record conforming to this specification.

The Acquisition Record establishes the foundation of engineering provenance, traceability, and chain of custody throughout the Engineering Knowledge Supply Chain.