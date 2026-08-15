# OEP-SPEC-021

# Public C API

Version: 1.0

Status: Draft

---

# 1. Purpose

This specification defines the official Public C API exposed by OEP Foundation.

The Public C API provides a stable ABI for external applications including Studio, SDKs, testing tools, and future integrations.

The Public C API shall be the only supported native interface into Foundation.

---

# 2. Scope

This specification defines:

* Public ABI
* Runtime handles
* Repository handles
* Error handling
* Memory ownership

This specification does not define:

* Flutter bindings
* Language-specific SDKs
* Network APIs
* Remote Foundation

---

# 3. Design Principles

The Public API shall:

* Use a pure C ABI.
* Never expose C++ classes.
* Never expose STL types.
* Never expose exceptions.
* Remain ABI-stable across Foundation updates whenever practical.

---

# 4. Opaque Handles

Foundation objects shall be represented by opaque handles.

Example:

```c
typedef struct oep_runtime* OEP_Runtime;
```

Applications shall never inspect handle contents.

---

# 5. Runtime API

Version 1 shall expose:

* Initialize Runtime
* Shutdown Runtime
* Open Repository
* Close Repository
* Repository Status

Future specifications shall extend this API.

---

# 6. Result Objects

Every API function shall return a deterministic result.

Result objects shall include:

* Success
* Error Code
* Error Message

Native exceptions shall never cross the API boundary.

---

# 7. Memory Ownership

Every allocation crossing the API boundary shall have a corresponding Foundation release function.

Ownership rules shall be explicitly documented.

---

# 8. Versioning

The Public API shall expose:

* Foundation Version
* API Version
* ABI Version

Applications shall validate compatibility before use.

---

# 9. Documentation

Implementation shall create:

```text
platform/api/README.md
```

Documenting:

* API lifecycle
* Handle ownership
* Thread safety
* Error handling
* Versioning

---

# 10. Acceptance Criteria

Sprint 021 is complete when:

* Public C API exists.
* Runtime lifecycle functions operate.
* Repository lifecycle functions operate.
* ABI is pure C.
* No C++ implementation types cross the boundary.
* Documentation is complete.
* Unit tests validate lifecycle, errors, ownership, and version reporting.

---

# 11. Engineering Principle

Foundation shall expose one stable native interface.

All external products shall depend upon this interface rather than internal implementation details.
