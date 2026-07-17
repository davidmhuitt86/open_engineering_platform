# SDD-R015

# Acquisition Record & Chain of Custody

**Document ID:** SDD-R015

**Title:** Acquisition Record & Chain of Custody

**Status:** Draft

**Version:** 1.0

**Author:** Divad Technology Group

**Applies To:** Open Engineering Platform (OEP)

**Parent Specifications:**
- SDD-R013 – Engineering Acquisition Manager
- SDD-R014 – Official Source Registry

---

# 1. Purpose

The Acquisition Record is the canonical representation of an engineering acquisition event.

It records **how**, **when**, **where**, and **from whom** an engineering artifact entered the Open Engineering Platform.

The Acquisition Record is immutable.

It represents history.

Not the artifact.

---

# 2. Mission

Provide complete, verifiable, and permanent documentation for every engineering artifact entering OEP.

Every engineering artifact shall possess one or more Acquisition Records.

---

# 3. Scope

The Acquisition Record is responsible for recording:

- acquisition event
- source
- metadata
- integrity
- licensing
- provenance
- chain of custody
- lifecycle

The Acquisition Record is not responsible for:

- storing the engineering artifact
- engineering analysis
- AI processing
- knowledge extraction
- engineering review
- publication

---

# 4. Guiding Principles

## 4.1 Immutable

Acquisition Records shall never be modified after creation.

Corrections shall be represented by additional records or events.

---

## 4.2 Event-Based

An Acquisition Record documents an acquisition event.

It is not the engineering artifact itself.

---

## 4.3 Multiple Acquisitions

The same engineering artifact may possess multiple Acquisition Records.

Each acquisition event remains independent.

---

## 4.4 Permanent Traceability

Every engineering artifact shall remain traceable to its original acquisition.

---

# 5. Acquisition Lifecycle

```text
Pending

↓

Acquired

↓

Verified

↓

Published to Vault

↓

Archived
```

Lifecycle events shall never be deleted.

---

# 6. Acquisition Identifier

Every Acquisition Record shall possess a globally unique Acquisition Identifier.

The identifier shall never be reused.

The identifier shall remain stable throughout the lifetime of the record.

---

# 7. Artifact Relationship

An Acquisition Record references an Engineering Artifact.

It does not contain the artifact.

```text
Acquisition Record

↓

Engineering Artifact

↓

Vault Object
```

Multiple Acquisition Records may reference a single Vault Object.

---

# 8. Acquisition Metadata

Each Acquisition Record should capture:

- Acquisition Identifier
- Timestamp
- Acquisition Method
- User
- Workstation
- Organization
- Source Registry Identifier
- Endpoint Identifier
- Source URL
- Referrer
- Redirect Chain
- MIME Type
- File Size
- Original Filename
- Content Encoding

---

# 9. Integrity Metadata

Integrity metadata should include:

- SHA-256
- SHA-512
- BLAKE3
- File Length
- Hash Timestamp

Integrity information shall never change.

---

# 10. Source Verification

Where available, record:

- DNS
- Resolved IP Address
- TLS Certificate
- Certificate Fingerprint
- HTTP Headers
- Server Information
- ETag
- Last Modified

---

# 11. Licensing

Licensing metadata shall remain independent from provenance.

Examples include:

- Vendor
- License Type
- Purchase Date
- Invoice
- Subscription
- Expiration
- Seat Count
- Redistribution Rights

Licensing may evolve over time.

Acquisition history shall not.

---

# 12. Chain of Custody

Every action performed after acquisition shall become a Custody Event.

Examples include:

- Downloaded
- Imported
- Verified
- OCR Complete
- Metadata Extracted
- AI Indexed
- Published to Vault
- Archived

Custody Events form an append-only history.

---

# 13. Custody Event

Each Custody Event should record:

- Event Identifier
- Timestamp
- Event Type
- Actor
- Workstation
- Software Version
- Description
- Related Objects

Events shall never be removed.

---

# 14. Provenance

The Acquisition Record establishes the beginning of engineering provenance.

Subsequent systems shall extend provenance.

They shall not replace it.

---

# 15. Duplicate Acquisitions

Duplicate artifacts shall not invalidate Acquisition Records.

Each acquisition event remains historically significant.

Duplicates may reference the same Vault Object.

---

# 16. Revision Detection

When a newer revision is acquired:

- create a new Acquisition Record
- preserve previous Acquisition Records
- preserve previous Vault Objects

No engineering evidence shall be overwritten.

---

# 17. Manual Acquisition

Manual acquisitions shall receive the same Acquisition Record structure as automated acquisitions.

Examples include:

- scanner
- USB
- drag-and-drop
- laboratory equipment
- email
- cloud storage

---

# 18. Relationship to the Reference Vault

Following successful verification, an Acquisition Record shall reference the resulting Vault Object.

The Vault Object shall preserve this relationship permanently.

---

# 19. Future Extensions

This architecture supports future capabilities including:

- Digital signatures
- Blockchain timestamping
- Enterprise audit systems
- Regulatory compliance
- Laboratory certification
- Secure evidence escrow
- Multi-party verification
- Distributed acquisition

---

# 20. Summary

The Acquisition Record is the immutable historical record of engineering acquisition.

It guarantees complete traceability from an engineering artifact's origin through every stage of the Engineering Knowledge Supply Chain.

The Chain of Custody preserves every significant event without modification, creating a permanent engineering evidence history for the lifetime of the platform.