# PKG-001
# Open Engineering Platform Package Format Specification

**Specification ID:** PKG-001

**Title:** Open Engineering Platform Package Format

**Status:** Draft 1.0

**Authority:** Open Engineering Platform Specification

**Amendment (WP-REP-002):** §5/§7's in-archive directory is named `fragment/`, not `repository/`. The package contains a Repository Fragment — never an entire Foundation Repository — and the physical directory name now says so, resolving a terminology collision identified in `oep_foundation`'s OEP-ARCH-002-REPOSITORY_RUNTIME_ASSESSMENT.md §0. `@oep-exchange/package-cli` (`oep-package create`/`validate`) and `oep_foundation`'s `platform/installer` were updated to match; already-built archives using the legacy `repository/` name remain installable (see `platform/installer`'s own documented backward-compatibility fallback).

---

# 1. Purpose

This specification defines the physical package format used by the Open Engineering Platform (OEP).

A `.oep` package is the standard distribution unit for engineering knowledge.

It is the only supported format for exchanging engineering content through the Engineering Exchange.

This specification defines:

- physical package layout
- required metadata
- package integrity
- package signing
- installation behavior
- version compatibility

It does not define licensing, publishing, dependency resolution, or marketplace behavior. Those are covered by separate specifications.

---

# 2. Design Goals

The package format shall be:

- deterministic
- portable
- cross-platform
- cryptographically verifiable
- forward compatible
- backward compatible when practical
- streamable
- inspectable
- reproducible

A package shall produce identical hashes regardless of operating system.

---

# 3. Philosophy

A `.oep` package is **not** an archive of files.

A `.oep` package is a serialized engineering repository fragment.

When installed, its contents become Engineering Objects within a Repository.

The package itself is never the engineering database.

It is a transport container.

---

# 4. File Extension

```
.oep
```

MIME type

```
application/vnd.oep.package
```

---

# 5. Package Structure

```
package.oep

├── manifest/
│     package.json
│
├── fragment/
│     objects/
│     relationships/
│     metadata/
│
├── assets/
│     images/
│     documents/
│     media/
│
├── licenses/
│
├── signatures/
│
├── indexes/
│
└── package.info
```

Every directory has a defined purpose.

Unknown directories shall be ignored unless declared mandatory by a future specification.

---

# 6. Required Components

Every package shall contain:

- Package Manifest
- Repository Fragment
- Signature Block
- Package Metadata

Optional components include:

- Images
- Documents
- Video
- Audio
- CAD
- Simulations
- AI Models

---

# 7. Repository Fragment

The Repository Fragment contains:

Engineering Objects

Relationships

Metadata

Reference Data

Validation Rules

Capabilities

The Repository Fragment never contains application code.

Executable code is prohibited unless explicitly allowed by a future signed capability specification.

---

# 8. Assets

Assets are immutable.

Examples:

- JPEG
- PNG
- SVG
- PDF
- STEP
- DXF
- MP4

Assets are referenced by Engineering Objects.

They are never treated as Engineering Objects themselves.

---

# 9. Manifest

The Manifest is mandatory.

It contains:

- Package ID
- Version
- Publisher
- Description
- Categories
- Engineering Domains
- Required Platform Version
- Dependencies
- Licensing
- Digital Signature Metadata
- Build Metadata

The Manifest specification is defined separately.

---

# 10. Package Identity

Every package has a globally unique identifier.

Example

```
com.divad.automotive.honda.gl1200.electrical
```

Package IDs are immutable.

Names may change.

Identifiers shall not.

---

# 11. Package Versioning

Versioning follows Semantic Versioning.

```
Major.Minor.Patch
```

Breaking engineering changes require a major version increment.

---

# 12. Integrity

Every package shall include cryptographic hashes for all payload content.

Required:

SHA-256

Recommended:

BLAKE3

Integrity verification occurs before installation begins.

---

# 13. Signing

Every package shall be digitally signed.

Supported algorithm:

Ed25519

Unsigned packages shall be treated as untrusted.

Signature verification occurs before dependency resolution.

---

# 14. Compression

The package container shall use deterministic ZIP encoding.

Compression settings shall be standardized to ensure reproducible package hashes.

---

# 15. Installation

Installation is transactional.

High-level process:

1. Open package
2. Verify structure
3. Verify manifest
4. Verify hashes
5. Verify signature
6. Check compatibility
7. Resolve dependencies
8. Preview changes
9. Merge Repository Fragment
10. Build indexes
11. Activate package
12. Commit transaction

Any failure rolls back the transaction.

Partial installation is prohibited.

---

# 16. Uninstallation

Removal follows the reverse transaction.

Objects referenced by other installed packages shall not be removed until dependency checks succeed.

---

# 17. Updates

Updates are Repository-aware.

The installer shall determine:

- added objects
- modified objects
- removed objects
- deprecated objects

Users shall be presented with a change summary before installation.

---

# 18. Security

Packages shall never execute arbitrary code during installation.

Installation only imports engineering data.

Any executable extensions shall require future capability specifications and explicit user authorization.

---

# 19. Future Extensions

Future specifications may add:

- encrypted packages
- enterprise signatures
- delta updates
- streaming packages
- cloud synchronization
- offline bundles
- package families

without changing the core package structure.

---

# 20. Conformance

Any implementation claiming compliance with PKG-001 shall:

- read compliant packages
- validate package integrity
- verify signatures
- reject malformed packages
- perform transactional installation
- preserve Engineering Object integrity
- maintain Repository consistency

No implementation may silently ignore validation failures.

Validation failures shall terminate installation.