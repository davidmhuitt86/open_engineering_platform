# OEP Studio

# WORK PACKAGE 004

**Status:** Approved

**Version:** 1.0

---

# Objective

This work package replaces the remaining Repository and Object placeholders with live data provided by the Foundation Public C API.

No Foundation modifications are permitted.

Studio shall consume only the existing Public C API.

---

# STUDIO-TASK-000007

## Live Repository Explorer

### Purpose

Populate the Repository Explorer using the Repository Statistics API.

The Repository Explorer shall display live repository information.

---

# Requirements

Populate category counts using Foundation statistics.

Display:

* Components
* Documents
* Diagrams
* Procedures
* Images
* Projects

Display the live object count beside each category.

Continue supporting:

* Expand / Collapse
* Incremental filtering
* Category selection

The Repository Explorer shall update automatically whenever a different repository is opened.

No placeholder values shall remain.

---

# STUDIO-TASK-000008

## Live Object Explorer

### Purpose

Populate the Object Explorer using the Engineering Object Enumeration API.

The Object Explorer shall display every Engineering Object returned by Foundation.

---

# Requirements

Display:

* Icon
* Name
* Object Type
* Author
* Version

Continue supporting:

* Sort by Name
* Sort by Type
* Sort by Author

Continue supporting filtering:

* Object Type
* Author
* Tags

Filtering and sorting remain Studio responsibilities.

Repository contents shall never be modified.

---

# Property Inspector

Replace placeholder data with live Foundation data.

Display:

* Name
* Object ID
* Object Type
* Author
* Version
* Description
* Tags

Display only.

No editing.

---

# Dashboard

Replace placeholder Repository Statistics with live Foundation values.

Display:

* Repository Name
* Repository Version
* Repository ID
* Total Objects
* Relationship Count
* Package Count

Foundation Version, API Version and ABI Version remain displayed.

---

# Connection Manager

Extend the existing Connection Manager.

Responsibilities now include:

* Current Runtime
* Current Repository
* Repository Statistics
* Current Object List
* Current Selection

Widgets shall continue consuming only the Connection Manager.

---

# Architecture Rules

Repository Explorer

↓

Connection Manager

↓

Foundation Bridge

↓

Public C API

↓

Foundation Runtime

Widgets shall never communicate directly with the Foundation Bridge.

No Foundation API calls shall originate from Widgets.

---

# Public API

Consume only the existing Public C API.

Do not modify Foundation.

If additional functionality is required:

Document it.

Do not implement it.

---

# Error Handling

If enumeration fails:

Display a professional empty-state message.

The application shall remain fully usable.

No native implementation details shall be exposed.

---

# Verification

Perform:

* flutter analyze
* flutter test
* flutter build windows

Verify:

* Repository Explorer displays live category counts.
* Object Explorer displays live objects.
* Sorting functions.
* Filtering functions.
* Property Inspector displays live object data.
* Dashboard displays live repository statistics.
* Runtime state remains correct.
* Status Bar remains correct.
* Window resizing remains correct.

Perform manual verification using a real Foundation-generated repository containing multiple Engineering Objects.

---

# Documentation

Update:

* README.md
* docs/IMPLEMENTATION_STATUS.md
* docs/CONNECTION_MANAGER.md

Update:

* docs/FOUNDATION_BRIDGE.md

Document:

* Enumeration workflow
* Statistics workflow
* Object selection lifecycle
* UI update lifecycle

---

# Definition of Done

This work package is complete when:

* Repository Explorer displays live Foundation statistics.
* Object Explorer displays live Engineering Objects.
* Property Inspector displays live metadata.
* Dashboard displays live repository statistics.
* No Foundation modifications were required.
* Documentation is complete.
* Flutter analyze passes.
* Flutter tests pass.
* Windows build succeeds.
* Manual verification confirms correct operation.

Stop after completion and await formal review.
