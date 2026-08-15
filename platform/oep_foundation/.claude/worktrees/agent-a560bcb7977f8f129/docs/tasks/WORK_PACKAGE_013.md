# OEP Foundation

# WORK PACKAGE 013

**Status:** Approved

**Version:** 1.0

---

# Objective

This work package extends the Public C API to expose Engineering Relationships and Repository Search capabilities required by OEP Studio.

The implementation shall preserve Foundation's architecture while enabling Studio to activate the Relationship Explorer and Search Workspace introduced in Studio Work Package 005.

No changes shall be required to Studio's architecture.

---

# TASK-000025

# Engineering Relationship Enumeration API

## Purpose

Expose Engineering Relationships through the Public C API.

This API shall support Studio, SDKs, automation tools, and future integrations.

The Public C API remains the only supported interface.

---

# Requirements

Expose:

* Relationship count
* Relationship enumeration
* Relationship lookup by ID

Expose relationship metadata:

* Relationship ID
* Source Object ID
* Target Object ID
* Relationship Type
* Author
* Description
* Created Timestamp

Enumeration shall be deterministic.

Relationships shall be returned in a stable ordering.

---

# Memory Ownership

Relationship enumeration shall follow the same ownership model already established for Object enumeration.

If Foundation allocates memory, Foundation shall also provide the release function.

Ownership rules shall be documented.

---

# TASK-000026

# Repository Search Public API

## Purpose

Expose Foundation's Search Engine through the Public C API.

Studio shall consume Foundation search results directly.

Studio shall never implement repository search independently.

---

# Requirements

Expose:

* Repository search
* Object-only search
* Relationship-only search

Return:

* Match score
* Match location
* Result type
* Referenced object or relationship ID

Result ordering shall exactly match Foundation's Search Engine.

The Public API shall never reorder search results.

---

# Search Parameters

Support:

* Search query

Filtering by author, tags, and object type remains a Studio responsibility after results are returned.

---

# Public API Rules

All new functionality shall be implemented only through:

platform/api/oep_api.h

No C++ implementation types.

No STL containers.

No exceptions across the API boundary.

The ABI shall remain stable.

Increment the API version if required by compatibility rules.

---

# Thread Safety

Document thread-safety guarantees for:

* Relationship enumeration
* Search operations

---

# Error Handling

All functions shall return deterministic result structures.

Errors shall use the existing Public API error model.

No exceptions shall cross the boundary.

---

# Documentation

Update:

* platform/api/README.md
* platform/runtime/README.md

Document:

* Relationship enumeration lifecycle
* Search lifecycle
* Memory ownership
* Performance considerations
* Thread safety

CLI documentation shall only be updated if user-visible CLI behavior changes.

---

# Verification

Perform:

* Full clean rebuild
* Complete regression suite
* New Public API tests
* Relationship enumeration tests
* Search API tests

Verify:

* Deterministic relationship enumeration
* Relationship lookup by ID
* Stable search ordering
* Match scores
* Match locations
* Memory ownership
* Error handling

Re-run:

* oep relationship
* oep search

to confirm no regressions.

---

# Definition of Done

This work package is complete when:

* Engineering Relationships are enumerable through the Public C API.
* Repository Search is available through the Public C API.
* Documentation is complete.
* Regression tests pass.
* Public API tests pass.
* Existing CLI behavior remains unchanged.
* Studio can consume the new API without requiring Foundation modifications.

Stop after completion and await formal review.
