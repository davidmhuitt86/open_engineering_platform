# Official Source Schema

**Repository:** oep_acquisition

**Document:** OFFICIAL_SOURCE_SCHEMA.md

**Status:** Draft

**Version:** 1.0

**Applies To:** Official Source Registry (OSR)

---

# 1. Purpose

This specification defines the canonical schema for Organizations, Endpoints, and Services maintained by the Official Source Registry.

The Official Source Registry provides a curated catalog of trusted engineering information providers used by the Engineering Acquisition Manager.

This specification defines:

- Organization objects
- Endpoint objects
- Service objects
- Relationships
- Validation rules
- Trust classifications
- Lifecycle rules

---

# 2. Design Principles

The Official Source Registry shall be:

- organization-centric
- globally unique
- relationship aware
- extensible
- deterministic
- auditable

Organizations are first-class engineering entities.

Endpoints belong to Organizations.

Services belong to Endpoints.

---

# 3. Object Hierarchy

```text
Organization

├── Endpoints

│     ├── Services

│     ├── Authentication

│     ├── Content Types

│     └── Capabilities

└── Relationships
```

---

# 4. Organization Object

Required fields

| Field | Type |
|--------|------|
| organization_id | UUID |
| organization_name | String |
| legal_name | String |
| organization_type | Enum |
| trust_level | Enum |
| status | Enum |

Optional fields

| Field | Type |
|--------|------|
| website | URI |
| country | ISO Country Code |
| headquarters | String |
| description | String |
| logo | Asset Reference |
| public_keys | Array |
| notes | String |

---

# 5. Organization Types

Supported types

- Standards Organization
- Manufacturer
- Government Agency
- Educational Institution
- Research Organization
- Commercial Publisher
- Industry Association
- Open Source Organization
- Internal Organization
- Exchange Partner
- Laboratory
- Certification Authority

Additional types may be registered.

---

# 6. Trust Classification

Organizations shall be assigned a Trust Level.

Supported values

- Core Authority
- Official Authority
- Verified Organization
- Trusted Partner
- Community Source
- Experimental
- Unverified

Trust classifications assist acquisition.

They do not replace engineering review.

---

# 7. Endpoint Object

An Organization may expose multiple Endpoints.

Required fields

| Field | Type |
|--------|------|
| endpoint_id | UUID |
| organization_id | UUID |
| endpoint_name | String |
| endpoint_type | Enum |
| endpoint_url | URI |
| endpoint_status | Enum |

---

# 8. Endpoint Types

Supported endpoint types

- Website
- Download Portal
- Documentation Portal
- REST API
- GraphQL API
- FTP
- Git Repository
- Package Registry
- RSS Feed
- Customer Portal
- Cloud Storage
- Local Repository

---

# 9. Endpoint Metadata

Optional metadata

- supported MIME types
- authentication requirements
- rate limits
- robots policy
- download restrictions
- API version
- availability
- last verification

---

# 10. Service Object

Endpoints expose one or more Services.

Required fields

| Field | Type |
|--------|------|
| service_id | UUID |
| endpoint_id | UUID |
| service_name | String |
| service_type | Enum |
| enabled | Boolean |

---

# 11. Service Types

Supported services include

- Product Search
- Datasheet Download
- Standards Catalog
- Firmware Download
- CAD Library
- Symbol Library
- Documentation
- Software Download
- Knowledge Base
- Technical Bulletin
- Product Catalog
- API Query
- Authentication Service

---

# 12. Authentication

Supported methods

- Anonymous
- Username / Password
- OAuth
- OAuth2
- OpenID Connect
- API Key
- Client Certificate
- Enterprise SSO
- Token Based

Credentials shall never be stored inside Organization records.

---

# 13. Relationships

Organizations may reference

- Parent Organization
- Subsidiary
- Standards Committee
- Manufacturer
- Distributor
- Government Agency
- Industry Association
- Certification Authority

Relationships are directional.

---

# 14. Lifecycle

Organizations

```text
Draft

↓

Verified

↓

Active

↓

Deprecated

↓

Archived
```

Endpoints

```text
Pending

↓

Verified

↓

Available

↓

Unavailable

↓

Retired
```

Services

```text
Registered

↓

Available

↓

Deprecated

↓

Retired
```

---

# 15. Validation Rules

The validator shall verify

✓ Unique Organization IDs

✓ Unique Endpoint IDs

✓ Unique Service IDs

✓ Valid relationships

✓ Valid endpoint URLs

✓ Trust classification

✓ Lifecycle transitions

✓ Authentication definitions

---

# 16. Future Extensions

Reserved for

- Organization certificates
- Digital signatures
- Reputation metrics
- Availability monitoring
- Automatic discovery
- API capability negotiation
- Federated registries
- Distributed synchronization

---

# 17. Example

```yaml
organization:
  organization_id:
  organization_name:
  organization_type:
  trust_level:

endpoints:

  - endpoint_id:
    endpoint_type:
    endpoint_url:

    services:

      - service_name:
      - service_type:
```

---

# 18. Summary

The Official Source Schema defines the authoritative representation of trusted engineering organizations within the Open Engineering Platform.

Organizations, Endpoints, and Services provide the structured foundation from which engineering evidence is acquired while preserving identity, trust, relationships, and long-term maintainability.
