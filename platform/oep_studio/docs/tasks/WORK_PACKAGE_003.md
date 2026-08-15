# OEP Studio

# WORK PACKAGE 003

**Status:** Approved

**Version:** 1.0

---

# Objective

This work package introduces the first engineering workspace within OEP Studio.

Users shall be able to browse an open repository and inspect Engineering Objects.

This work package builds entirely upon the existing Foundation Bridge.

No new Foundation functionality shall be implemented.

---

# STUDIO-TASK-000005

## Repository Explorer

### Purpose

Implement the Repository Explorer.

The Repository Explorer provides structural navigation of the currently open repository.

It serves a role similar to Solution Explorer in an IDE.

The Repository Explorer shall consume data only through the Foundation Bridge.

---

# Requirements

Display the currently opened repository.

Display categories:

* Components
* Documents
* Diagrams
* Procedures
* Images
* Projects

Display object counts beside each category.

Expand and collapse categories.

Selecting a category updates the Primary Workspace.

Provide an incremental filter.

The filter affects only visible items.

Repository contents shall never be modified.

---

# Behavior

If no repository is open:

Display:

"No Repository Open"

with a button:

"Open Repository"

that returns the user to the Dashboard workflow.

---

# STUDIO-TASK-000006

## Object Explorer

### Purpose

Display Engineering Objects contained within the selected Repository category.

---

# Requirements

Each object shall display:

* Icon
* Name
* Object Type
* Author
* Version

Support:

* Sort by Name
* Sort by Type
* Sort by Author

Support filtering by:

* Type
* Author
* Tags

Selecting an object shall populate the Property Inspector placeholder.

No editing is implemented in this work package.

No object creation.

No deletion.

Read-only browsing only.

---

# Property Inspector

Introduce the Property Inspector placeholder.

Display:

* Name
* Object Type
* Author
* Version
* Description
* Tags

Display only.

No editing.

If no object is selected display:

"No Object Selected"

---

# Status Bar

Continue displaying:

* Runtime
* Repository
* Theme
* Studio Version

Add:

Selected Object

When nothing is selected:

Selected Object: None

---

# Connection Manager

Introduce a Studio Connection Manager.

Responsibilities:

* Runtime State
* Repository State
* Current Repository
* Current Selection

The Connection Manager shall consume only the Foundation Bridge.

Widgets shall not communicate directly with the Bridge.

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

Widgets shall remain presentation only.

No engineering logic shall exist in Widgets.

No Foundation API calls shall originate from Widgets.

---

# Public API

Consume only existing Foundation functionality.

Do not modify Foundation.

If additional Public API functionality is required:

Document it.

Do not implement it.

---

# Verification

Perform:

* flutter analyze
* flutter test
* flutter build windows

Verify:

* Repository Explorer populates correctly.
* Categories expand and collapse.
* Object list updates correctly.
* Sorting functions correctly.
* Filtering functions correctly.
* Property Inspector updates.
* Status Bar updates.
* Window resizing remains correct.

---

# Documentation

Update:

* README.md
* docs/IMPLEMENTATION_STATUS.md

Create:

docs/CONNECTION_MANAGER.md

Document:

* Responsibilities
* State ownership
* Foundation interaction
* Lifecycle

---

# Definition of Done

This work package is complete when:

* Repository Explorer functions.
* Object Explorer functions.
* Property Inspector placeholder functions.
* Connection Manager is implemented.
* No Foundation modifications are required.
* Documentation is complete.
* Flutter analyze passes.
* Flutter tests pass.
* Windows build succeeds.
* Manual verification confirms correct operation.

Stop after completion and await formal review.
