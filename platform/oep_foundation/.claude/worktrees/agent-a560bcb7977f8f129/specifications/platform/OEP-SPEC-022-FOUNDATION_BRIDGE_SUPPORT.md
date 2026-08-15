# OEP-SPEC-022

# Foundation Bridge Support

Version: 1.0

Status: Draft

---

# 1. Purpose

This specification extends Foundation to support external Bridge implementations.

The Foundation Bridge provides language-neutral access to the Public C API.

Foundation shall provide the primitives required by all future Bridges.

---

# 2. Scope

This specification defines:

* Error translation support
* Runtime state reporting
* Object conversion support
* Bridge compatibility

This specification does not define:

* Flutter implementation
* C# implementation
* Python implementation
* Java implementation

---

# 3. Runtime State

Foundation shall expose:

* Uninitialized
* Initialized
* Repository Open
* Repository Closed
* Shutdown

State values shall be deterministic.

---

# 4. Error Reporting

Foundation shall expose:

* Error Code
* Error Category
* Error Message

Messages shall be suitable for translation by Bridge implementations.

---

# 5. Data Conversion

Foundation shall expose deterministic C structures suitable for conversion into language-native models.

No STL containers shall cross the Public API.

---

# 6. Thread Safety

Thread safety guarantees shall be documented.

Bridge implementations shall understand which operations are safe concurrently.

---

# 7. Documentation

Implementation shall update:

```text
platform/api/README.md
```

to include Bridge integration guidance.

---

# 8. Acceptance Criteria

Sprint 022 is complete when:

* Runtime state is exposed.
* Error translation information is available.
* Data structures are Bridge-compatible.
* Documentation is complete.
* Unit tests validate state transitions, error propagation, and structure compatibility.

---

# 9. Engineering Principle

Foundation provides the contract.

Bridge implementations provide language integration.

Neither layer shall duplicate the responsibilities of the other.
