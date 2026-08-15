# OEP Studio

# WORK PACKAGE 002

**Status:** Approved

**Version:** 1.0

---

# Objective

This work package establishes the first live connection between OEP Studio and OEP Foundation.

The objective is to validate the complete architecture:

Flutter

↓

Foundation Bridge

↓

Public C API

↓

Foundation Runtime

↓

Repository

No engineering business logic shall be implemented within Studio.

---

# STUDIO-TASK-000003

## Foundation Bridge

### Purpose

Implement the first version of the Foundation Bridge.

The Bridge provides a language-neutral abstraction over the Foundation Public C API.

The Bridge is responsible for:

* Runtime initialization
* Runtime shutdown
* Runtime state
* Foundation version
* API version
* ABI version
* Error translation
* Data marshaling

The Bridge shall not contain engineering business logic.

The Bridge shall communicate only through the Public C API.

No C++ implementation details shall cross into Studio.

---

# Requirements

Implement:

* Runtime initialization
* Runtime shutdown
* Runtime lifecycle
* Runtime status
* Foundation Version
* API Version
* ABI Version

Translate all Foundation errors into user-friendly Studio errors.

The Bridge shall remain reusable by future Studio features.

---

# STUDIO-TASK-000004

## Open Repository Workflow

### Purpose

Implement the first live interaction between Studio and Foundation.

Workflow:

Dashboard

↓

Open Repository

↓

Foundation Bridge

↓

Public C API

↓

Foundation Runtime

↓

Repository

Successful operation shall update:

* Dashboard
* Repository Status
* Runtime Status
* Foundation Version
* API Version
* ABI Version

Failed operations shall:

* Display professional error dialogs.
* Preserve Studio stability.
* Never expose implementation details.

---

# Status Bar

Replace:

Foundation: Not Connected

With:

Runtime: Disconnected

When connected display:

Runtime: Connected

The Status Bar shall display:

* Runtime
* Repository
* Theme
* Studio Version

Foundation Version shall be displayed on the Dashboard.

---

# Architecture Rules

Studio remains a presentation layer.

Foundation Bridge owns:

* FFI
* Public C API
* Marshaling
* Error Translation

Studio Services own:

* Runtime State
* Repository State
* Navigation State
* Application Workflow

Widgets contain presentation logic only.

No engineering logic shall exist in Widgets.

---

# Public API Rules

Studio shall consume only:

platform/api/oep_api.h

No additional Foundation headers may be referenced.

No Runtime implementation classes may be referenced.

No Foundation internals may be referenced.

---

# Error Handling

Translate Foundation errors into user-friendly messages.

Studio shall never expose:

* C++ exceptions
* Stack traces
* Internal Foundation paths
* Native implementation details

---

# Verification

Perform:

* flutter analyze
* flutter test
* flutter build windows

Verify:

* Runtime initializes.
* Runtime shuts down.
* Runtime state transitions correctly.
* Repository opens.
* Dashboard updates.
* Status Bar updates.
* Error handling functions correctly.
* Window resizing remains correct.

---

# Documentation

Update:

* README.md
* docs/IMPLEMENTATION_STATUS.md
* docs/FOUNDATION_BRIDGE.md

Document:

* Public API usage
* Runtime lifecycle
* Bridge architecture
* Error translation
* Ownership rules
* Data conversion

---

# Definition of Done

This work package is complete when:

* Foundation Bridge is implemented.
* Runtime lifecycle is operational.
* Repository open workflow functions.
* Dashboard displays live Foundation information.
* Status Bar reflects Runtime state.
* Documentation is updated.
* Flutter analyze passes.
* Flutter tests pass.
* Windows build succeeds.
* Manual verification confirms correct behavior.

Stop after completion and await formal review.
