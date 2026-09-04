# License Schema

**Repository:** oep_acquisition

**Document:** LICENSE_SCHEMA.md

**Status:** Draft

**Version:** 1.0

**Applies To:** Engineering Acquisition Manager

---

# 1. Purpose

This specification defines the canonical representation of engineering licenses within the Open Engineering Platform.

Engineering licenses govern the acquisition, storage, processing, sharing, and use of engineering evidence.

This specification defines:

- License Objects
- Entitlements
- Restrictions
- Purchases
- Subscriptions
- Compliance
- Validation
- Relationships

---

# 2. Design Principles

Engineering licensing shall be:

- Explicit
- Auditable
- Relationship-aware
- Versioned
- Non-destructive
- Independent of engineering knowledge

A License Object represents legal permissions.

It never modifies engineering evidence.

---

# 3. License Architecture

```text
License

├── Identity
├── Provider
├── Terms
├── Entitlements
├── Restrictions
├── Subscription
├── Compliance
├── Relationships
├── Lifecycle
└── Audit
```

---

# 4. Identity

Required Fields

| Field | Type |
|---------|------|
| license_id | UUID |
| schema_version | String |
| created_at | Timestamp |
| created_by | User ID |

Rules

License IDs are permanent.

License IDs shall never be reused.

---

# 5. Provider

Defines the issuing authority.

Fields

| Field | Type |
|---------|------|
| provider_name | String |
| organization_id | UUID |
| contact_information | Object |
| website | URI |

---

# 6. License Types

Supported values

- Public Domain
- Open License
- Creative Commons
- Proprietary
- Subscription
- Academic
- Educational
- Government
- Internal
- Enterprise
- OEM Agreement
- Marketplace License
- Trial
- Evaluation

Additional license types may be registered.

---

# 7. Entitlements

License entitlements describe permitted actions.

Supported entitlements

- View
- Download
- Store
- Index
- OCR
- Parse
- AI Processing
- Embedding Generation
- Metadata Extraction
- Internal Distribution
- External Distribution
- Export
- Printing
- Archiving

Entitlements are independently configurable.

---

# 8. Restrictions

Restrictions describe prohibited actions.

Examples

- No Redistribution
- No Commercial Use
- Internal Use Only
- Named Users Only
- Seat Limited
- Time Limited
- Geographic Restriction
- Export Restriction
- Confidential
- NDA Required

Restrictions never override legal agreements.

---

# 9. Subscription Information

Fields

| Field | Type |
|---------|------|
| subscription_id | UUID |
| start_date | Date |
| expiration_date | Date |
| renewal_policy | Enum |
| billing_cycle | Enum |
| seats | Integer |
| active | Boolean |

---

# 10. Compliance

Compliance records determine current status.

Fields

| Field | Type |
|---------|------|
| compliance_status | Enum |
| last_review | Timestamp |
| reviewed_by | User ID |
| exceptions | Array |

Compliance States

- Compliant
- Pending Review
- Expired
- Suspended
- Revoked

---

# 11. Relationships

License Objects may reference

- Organizations
- Acquisition Records
- Vault Objects
- Engineering Knowledge Objects
- Projects
- Users
- Marketplace Assets
- Subscription Contracts

Relationships are immutable.

---

# 12. Lifecycle

```text
Draft

↓

Pending Approval

↓

Active

↓

Expired

↓

Suspended

↓

Archived
```

Historical states are preserved permanently.

---

# 13. Validation Rules

Validators shall verify

✓ Required fields

✓ Provider identity

✓ License type

✓ Entitlements

✓ Restrictions

✓ Lifecycle transitions

✓ Date consistency

✓ Relationship integrity

---

# 14. Future Extensions

Reserved for

- Digital license certificates
- Smart contracts
- Automated entitlement synchronization
- Enterprise compliance integrations
- Government export controls
- AI usage policies
- Marketplace royalty tracking

---

# 15. Example

```yaml
license:
  license_id:
  provider:
  type: Subscription

entitlements:
  - Download
  - OCR
  - AI Processing

restrictions:
  - No Redistribution

subscription:
  expiration_date:

compliance:
  status: Compliant
```

---

# 16. Summary

The License Schema defines the legal permissions associated with engineering evidence acquired by the Open Engineering Platform.

License Objects provide a structured, auditable representation of entitlements, restrictions, compliance, and lifecycle while remaining independent of the engineering evidence itself.