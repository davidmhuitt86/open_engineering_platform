# PKG-008
# OEP Package Registry Specification

**Specification ID:** PKG-008

**Title:** OEP Package Registry Specification

**Status:** Draft 1.0

**Authority:** Open Engineering Platform Specification

**Depends On:**
- PKG-001 Package Format
- PKG-002 Package Manifest
- PKG-003 Package Transaction Engine
- PKG-004 Dependency Resolution Engine
- PKG-005 Trust & Digital Signature
- PKG-006 Repository Merge
- PKG-007 Package Content Model

---

# 1. Purpose

The Package Registry (PRG) is the authoritative inventory of every package installed within an Open Engineering Platform Repository.

The Registry records package identity, ownership, installation history, lifecycle state, and repository contributions.

The Registry is not the Repository.

The Registry describes packages.

The Repository stores Engineering Knowledge.

---

# 2. Design Goals

The Package Registry shall be:

- Authoritative
- Deterministic
- Transactional
- Auditable
- Queryable
- Immutable where appropriate
- Extensible

---

# 3. Responsibilities

The Package Registry records:

- Installed packages
- Package versions
- Publishers
- Installation history
- Update history
- Removal history
- Package ownership
- Repository contributions
- Activation state
- Trust state
- License state

---

# 4. Registry Identity

Each registry has:

Registry ID

Repository ID

Creation Date

Schema Version

Platform Version

Repository Version

The registry belongs to exactly one Repository.

---

# 5. Package Record

Each installed package shall have exactly one Package Record.

A Package Record contains:

Package ID

Version

Publisher ID

Installation Transaction

Current State

Trust Status

License Status

Activation State

Repository Version Installed

Repository Version Modified

---

# 6. Lifecycle States

A package may exist in one of the following states:

Downloaded

Verified

Installed

Active

Inactive

Deprecated

Superseded

Pending Removal

Removed

Corrupted

Repair Required

---

# 7. Package Contributions

The registry records every repository contribution made by the package.

Examples:

Engineering Objects

Relationships

Knowledge Articles

Validation Rules

Capabilities

Reference Data

Assets

Templates

Localization Resources

The registry shall maintain contribution counts and references.

---

# 8. Ownership

Every contribution retains ownership metadata.

Ownership includes:

Publisher

Package ID

Version

Installation Transaction

Installation Timestamp

Ownership remains after package updates.

---

# 9. Activation

Packages may be:

Active

Disabled

Pending Activation

Pending Deactivation

Activation does not remove repository content.

Activation controls capability availability.

---

# 10. Updates

The registry records:

Current Version

Previous Version

Update History

Update Transactions

Rollback Availability

Update Timestamp

Package history is never discarded.

---

# 11. Removal

When a package is removed:

The Package Record remains.

State changes to Removed.

Historical installation data is preserved.

Repository contributions are removed only after successful dependency verification.

---

# 12. Trust Information

Each Package Record stores:

Signature Status

Certificate Fingerprint

Verification Timestamp

Publisher Trust Level

Certificate Expiration

Trust history is retained.

---

# 13. License Information

The registry stores:

License ID

License Type

Subscription Status

Offline Rights

Expiration

Validation Timestamp

The registry does not contain license secrets.

---

# 14. Transaction History

Every package maintains a complete transaction history.

Examples:

Installed

Updated

Repaired

Activated

Disabled

Removed

Rolled Back

Every transaction references the Package Transaction Engine journal.

---

# 15. Query Operations

The Package Registry supports queries including:

List Installed Packages

Find Package

Find Publisher

Find Contributions

Find Installed Version

Find Transaction History

Find Active Packages

Find Deprecated Packages

Find Repair Candidates

The registry is optimized for lookup rather than engineering analysis.

---

# 16. Events

The Package Registry publishes events.

Examples:

PackageInstalled

PackageActivated

PackageUpdated

PackageRemoved

PackageRepaired

PackageDeprecated

PackageDisabled

PackageVerificationChanged

These events are informational.

Repository modification remains the responsibility of the Package Transaction Engine.

---

# 17. Synchronization

The Package Registry shall remain synchronized with:

Repository

Capability Registry

Trust Service

License Service

Package Transaction Engine

Inconsistencies shall trigger repository diagnostics.

---

# 18. Recovery

If the registry becomes inconsistent:

Repository scan

↓

Contribution verification

↓

Ownership reconstruction

↓

Registry rebuild

↓

Integrity verification

Registry reconstruction shall never modify Engineering Objects.

---

# 19. Future Extensions

Future specifications may introduce:

Enterprise deployment policies

Cloud synchronization

Repository federation

Package analytics

Usage telemetry

Organization ownership

Repository replication

without changing the Package Registry model.

---

# 20. Conformance

An implementation claiming compliance with PKG-008 shall:

- Maintain exactly one Package Record per installed package.
- Preserve package history.
- Preserve ownership metadata.
- Maintain synchronization with Repository state.
- Support deterministic reconstruction.
- Provide query access to installed package metadata.