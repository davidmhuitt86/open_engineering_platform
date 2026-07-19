# PKG-002
# Open Engineering Platform Package Manifest Specification

**Specification ID:** PKG-002

**Title:** OEP Package Manifest Specification

**Status:** Draft 1.0

**Authority:** Open Engineering Platform Specification

**Depends On:** PKG-001

---

# 1. Purpose

The Package Manifest is the authoritative metadata document describing an OEP package.

It allows the platform to understand a package without reading the Repository Fragment.

The manifest is always read before installation.

No package may be installed without a valid manifest.

---

# 2. Design Goals

The manifest shall be:

- Human readable
- Machine readable
- Deterministic
- Extensible
- Versioned
- Forward compatible
- Cryptographically verifiable

---

# 3. File Location

Every package shall contain exactly one manifest.

```
manifest/package.json
```

Future serialization formats may be added.

JSON remains the canonical format.

---

# 4. Manifest Lifecycle

The manifest is read during:

- Package discovery
- Exchange search indexing
- Installation
- Update
- Verification
- Dependency resolution
- License validation

The Repository Fragment is not required for these operations.

---

# 5. Required Fields

Every manifest shall contain:

```json
{
  "schemaVersion": "1.0",
  "packageId": "",
  "version": "",
  "publisher": {},
  "title": "",
  "summary": "",
  "description": "",
  "category": "",
  "engineeringDomains": [],
  "license": {},
  "dependencies": [],
  "capabilities": [],
  "repository": {},
  "statistics": {},
  "signatures": {},
  "build": {}
}
```

---

# 6. Schema Version

```json
"schemaVersion": "1.0"
```

Defines the manifest schema.

Not the package version.

---

# 7. Package Identity

```json
"packageId": "com.divad.honda.gl1200.electrical"
```

Rules:

- Globally unique
- Immutable
- Reverse-domain notation
- Lowercase
- No spaces

---

# 8. Package Version

```json
"version": "2.3.1"
```

Semantic Versioning.

Major.Minor.Patch

---

# 9. Publisher

```json
"publisher":
{
    "id": "",
    "name": "",
    "verified": true,
    "website": "",
    "support": ""
}
```

The Publisher ID is immutable.

Display names may change.

---

# 10. Package Information

```json
"title": ""

"summary": ""

"description": ""

"keywords": []

"categories": []
```

Used by the Engineering Exchange.

---

# 11. Engineering Classification

```json
"engineeringDomains":
[
    "Automotive",
    "Electrical"
]
```

Examples:

- Automotive
- Aerospace
- Marine
- Industrial
- Robotics

Future specifications define valid classifications.

---

# 12. Repository Metadata

```json
"repository":
{
    "objects": 2451,
    "relationships": 18231,
    "knowledge": 311,
    "assets": 987,
    "validationRules": 83
}
```

Provides installation preview.

---

# 13. Statistics

```json
"statistics":
{
    "compressedSize": "",
    "uncompressedSize": "",
    "objectCount": "",
    "relationshipCount": ""
}
```

Purely informational.

---

# 14. Capabilities

```json
"capabilities":
[
    "diagram",
    "knowledge",
    "validation",
    "simulation"
]
```

Capabilities describe what the package enables.

Not which Studios are installed.

---

# 15. Dependencies

```json
"dependencies":
[
]
```

Each dependency includes:

- Package ID
- Version constraint
- Required/Optional
- Reason

Dependency resolution is defined by PKG-005.

---

# 16. Licensing

```json
"license":
{
}
```

Includes:

- License ID
- Commercial/Open
- Subscription requirements
- Expiration
- Offline rights

Licensing behavior is defined separately.

---

# 17. Digital Signatures

```json
"signatures":
{
}
```

Contains:

- Algorithm
- Certificate ID
- Signature Hash
- Timestamp

PKG-006 defines signing.

---

# 18. Build Metadata

```json
"build":
{
    "tool": "",
    "buildNumber": "",
    "buildDate": "",
    "specVersion": ""
}
```

Not part of package identity.

---

# 19. Optional Metadata

Future versions may include:

- Screenshots
- Icons
- Videos
- Changelog
- Documentation links
- Supported languages
- AI metadata

Unknown fields shall be ignored.

---

# 20. Validation Rules

A valid manifest shall:

- Contain every required field.
- Pass schema validation.
- Match Repository statistics.
- Match package hashes.
- Match package signature.
- Match package contents.

Failure invalidates the package.

---

# 21. Exchange Usage

The Engineering Exchange shall use the manifest for:

- Search indexing
- Package previews
- Publisher pages
- Ratings
- Reviews
- Compatibility
- Dependency resolution
- Version comparisons

Repository data shall not be parsed for these operations.

---

# 22. Installer Usage

The installer shall display information from the manifest before installation.

Typical installation preview includes:

- Publisher
- Version
- Object count
- Relationship count
- Dependencies
- License
- Required platform version
- Estimated install size

The user shall have an opportunity to cancel before any repository transaction begins.

---

# 23. Future Extensions

The manifest is intentionally extensible.

Future specifications may introduce additional metadata without breaking existing packages.

Consumers shall ignore unknown fields unless explicitly marked as mandatory.

---

# 24. Conformance

Any implementation claiming compliance with PKG-002 shall:

- Parse valid manifests.
- Reject malformed manifests.
- Validate required fields.
- Preserve unknown fields during processing.
- Use the manifest as the authoritative package metadata source.
- Never infer metadata by inspecting the Repository Fragment when equivalent manifest data is present.