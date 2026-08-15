# WP-REP-002
# Foundation Repository Runtime
# Vertical Slice 2 – Repository Registry & Lifecycle

**Repository:**
oep_foundation

**Status:**
Implemented (Task 000032) — awaiting review; see TASK.md and CURRENT_SPRINT.md for the verification record

**Priority:**
Critical

---

# 1. Objective

Expand the Foundation Repository Runtime to maintain a complete registry of installed packages and provide the first package lifecycle services.

This work package also ratifies and implements the approved terminology changes throughout Foundation and related specifications before additional development depends upon the previous naming.

---

# 2. Scope

Included

- Repository Registry
- Package lifecycle management
- Package metadata persistence
- Installed package discovery
- Runtime queries
- Registry API
- Registry CLI
- Registry indexing
- Terminology migration
- Documentation updates

Excluded

- Dependency resolution
- Transactions
- Merge engine
- Trust & signing
- Update
- Uninstall
- HTTP services

---

# 3. Terminology Ratification

The following terminology changes are now official.

Rename:

platform/exchange

to

platform/archive

The Foundation subsystem is responsible for archive import/export/template operations and is not related to the Engineering Exchange.

Rename the package directory:

repository/

to

fragment/

within PKG-001.

The package contains a Repository Fragment rather than an entire Repository.

Going forward the following terminology shall be used consistently:

- Foundation Repository
- Repository Runtime
- Repository Fragment
- Engineering Exchange

Avoid using the word "Repository" without context.

---

# 4. Repository Registry

Implement a persistent Repository Registry.

Track:

- Package ID
- Version
- Publisher
- Installation Date
- Install Source
- Runtime State
- Object Count
- Relationship Count
- Manifest Metadata
- Package Hash
- Installation Path

The Registry becomes the authoritative inventory of installed engineering packages.

---

# 5. Lifecycle Services

Implement runtime services for:

- Enumerate installed packages
- Query package metadata
- Query package contents
- Query package ownership
- Locate installed package
- Verify installation status

No update or uninstall functionality is included.

---

# 6. Runtime APIs

Extend the Foundation Runtime and Public C API.

Provide functions for:

- Enumerating installed packages
- Retrieving package information
- Locating installed objects
- Looking up package ownership
- Querying installation state

Maintain backward compatibility.

---

# 7. CLI

Extend the OEP CLI.

Implement:

oep package info

oep package contents

oep package verify

oep package locate

Improve:

oep package list

using the new Repository Registry.

---

# 8. Repository Index

Expand indexing to include package-level metadata.

Support searching by:

- Package ID
- Title
- Publisher
- Version
- Category
- Engineering Domain
- Installed Objects

---

# 9. Studio Verification

Verify OEP Studio correctly displays:

- Installed Packages
- Package Metadata
- Package Contents
- Installation Status

Only implement the Foundation bindings required to expose this information.

Do not redesign Studio.

---

# 10. Testing

Implement:

- Registry tests
- Package lookup tests
- Registry persistence tests
- CLI tests
- Runtime API tests
- Installation verification tests

Validate using:

engineering-demo.oep

---

# 11. Documentation

Update:

Repository Runtime Guide

Foundation API Guide

CLI Guide

Package Specification

Architecture documentation

Repository terminology

Ratify all approved naming changes.

---

# 12. Deliverables

Repository Registry

Runtime Registry APIs

CLI enhancements

Studio verification

Updated specifications

Updated terminology

Validation report

---

# 13. Exit Criteria

✓ Repository Registry implemented

✓ Installed packages discoverable

✓ Package metadata queryable

✓ Registry persisted

✓ CLI commands operational

✓ Studio displays Registry information

✓ Documentation updated

✓ Terminology migration completed

✓ All tests pass