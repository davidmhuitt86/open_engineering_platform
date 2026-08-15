# OEP Foundation

# WORK PACKAGE 012

**Status:** Approved

**Version:** 1.0

---

# Objective

This work package extends the Public C API to expose repository contents for external applications.

The goal is to satisfy the requirements identified by OEP Studio Work Package 003 without exposing Foundation internals.

No changes shall be required in Studio after these APIs are available.

---

# TASK-000023

## Engineering Object Enumeration API

### Purpose

Expose Engineering Objects through the Public C API.

This API shall support Studio, SDKs, automation tools, and future integrations.

The Public API remains the only supported interface.

---

# Requirements

Expose:

* Object count
* Object enumeration
* Object lookup by ID

Expose object metadata:

* Object ID
* Name
* Object Type
* Author
* Version
* Description
* Tags

The API shall use fixed-layout C structures.

No STL containers.

No C++ implementation types.

No exceptions.

Enumeration shall be deterministic.

---

# Memory Ownership

Returned collections shall have explicit ownership rules.

Foundation shall provide release functions for any allocated memory.

Ownership shall be fully documented.

---

# TASK-000024

## Repository Statistics API

### Purpose

Expose repository statistics through the Public C API.

This information supports Dashboard and Repository Explorer.

---

# Requirements

Expose:

* Total object count
* Object counts by type
* Relationship count
* Package count
* Repository version
* Repository ID
* Repository name

The API shall return deterministic C structures.

Studio shall not calculate these values itself.

---

# Public API Rules

All new functionality shall be implemented through:

platform/api/oep_api.h

No internal Foundation headers shall be exposed.

The ABI shall remain stable.

Version numbers shall be updated only if required by compatibility rules.

---

# Thread Safety

Document thread-safety guarantees for all new API functions.

---

# Error Handling

All functions shall return deterministic result structures.

No native exceptions shall cross the API boundary.

---

# Documentation

Update:

* platform/api/README.md
* platform/runtime/README.md
* CLI_USAGE.md (if applicable)

Document:

* Enumeration lifecycle
* Memory ownership
* Statistics structures
* Thread safety
* Performance considerations

---

# Verification

Perform:

* Full clean rebuild
* Complete regression test suite
* New Public API tests
* Enumeration tests
* Statistics tests

Verify:

* Deterministic enumeration
* Correct object metadata
* Correct repository statistics
* Memory ownership
* Error handling

---

# Definition of Done

This work package is complete when:

* Engineering Objects are enumerable through the Public C API.
* Repository statistics are available through the Public C API.
* Documentation is complete.
* Regression tests pass.
* New Public API tests pass.
* Studio can consume the API without requiring Foundation internals.

Stop after completion and await formal review.
