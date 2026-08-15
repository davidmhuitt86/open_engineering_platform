# WP-REP-001
# Foundation Repository Runtime
# Vertical Slice 1 – Package Installation

**Repository:**
oep_foundation

**Status:**
Planned

**Priority:**
Critical

---

# 1. Objective

Implement the first functional Repository Runtime capable of installing a valid .oep package into the Foundation Repository.

The objective of this work package is to complete the first end-to-end package installation workflow.

This work package establishes the Repository Runtime as the system responsible for package installation, object registration, indexing, and package lifecycle initialization.

---

# 2. Scope

Included

- Package installation
- Repository Fragment extraction
- Repository registration
- Engineering Object registration
- Relationship registration
- Metadata registration
- Repository indexing
- Package validation
- Package installation records
- FFI API additions
- Studio verification

Excluded

- Updates
- Uninstall
- Dependency resolution
- Merge engine
- Transaction engine
- Trust & signing
- HTTP services
- Exchange modifications

---

# 3. Package Installation

Implement a Repository Runtime capable of:

- Opening a .oep package
- Validating package structure
- Validating manifest
- Extracting the Repository Fragment
- Registering package metadata
- Registering Engineering Objects
- Registering Relationships
- Registering Metadata
- Updating Repository indexes

The Repository becomes the owner of all installed engineering assets.

---

# 4. Repository Fragment

Support installation of the approved PKG-001 Repository Fragment structure.

The runtime shall process:

fragment/

objects/

relationships/

metadata/

assets/

licenses/

indexes/

The runtime shall ignore unsupported future directories without failing installation.

---

# 5. Repository Registry

Maintain an installed package registry.

Track:

- Package ID
- Version
- Publisher
- Installation Date
- Installation Path
- Installation Status
- Manifest Metadata

---

# 6. Object Registration

Register all Engineering Objects contained within the Repository Fragment.

Objects shall become first-class Foundation Repository objects.

---

# 7. Relationship Registration

Register all Engineering Relationships.

Relationships shall be integrated into the existing Graph Engine.

---

# 8. Repository Index

Update Foundation indexes following successful installation.

Installed objects shall become discoverable through existing search facilities.

---

# 9. Validation

Reject packages containing:

- Invalid manifest
- Invalid structure
- Duplicate object identifiers
- Unsupported schema versions

Provide descriptive installation errors.

---

# 10. FFI API

Extend the existing Foundation C API.

Expose Repository Runtime functions required by OEP Studio.

Do not remove or break existing APIs.

---

# 11. Studio Verification

Verify that existing Studio Repository pages correctly display installed packages and Engineering Objects using the new Runtime APIs.

No new Studio functionality is required beyond verification and any necessary bindings.

---

# 12. Testing

Implement:

- Unit tests
- Installation tests
- Invalid package tests
- Duplicate package tests
- Repository registration tests
- Object registration tests
- Search verification tests

Validate installation using:

engineering-demo.oep

---

# 13. Documentation

Update:

Developer Guide

Repository Runtime Guide

Installation Guide

Create:

Repository Runtime Overview

Installation Validation Report

---

# 14. Deliverables

Repository Runtime

Package Installer

Repository Registry

Repository Index updates

FFI extensions

Validation Report

Updated documentation

---

# 15. Exit Criteria

✓ engineering-demo.oep installs successfully

✓ Repository Fragment extracted

✓ Engineering Objects registered

✓ Relationships registered

✓ Repository indexed

✓ Objects visible within OEP Studio Repository

✓ Existing search locates installed objects

✓ Documentation completed

✓ All tests pass