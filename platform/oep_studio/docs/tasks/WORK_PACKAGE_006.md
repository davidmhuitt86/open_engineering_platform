# OEP Studio

# WORK PACKAGE 006

**Status:** Approved

**Version:** 1.0

---

# Objective

This work package activates the Relationship Explorer and Search Workspace using the new Public C API introduced in Foundation Work Package 013.

No Foundation modifications are permitted.

Studio shall consume only the existing Public C API.

This work package should replace the remaining placeholder functionality with live engineering data.

---

# STUDIO-TASK-000011

# Live Relationship Explorer

## Purpose

Populate the Relationship Explorer using Foundation's Engineering Relationship Enumeration API.

Relationships shall be retrieved exclusively through the Foundation Bridge.

---

# Requirements

Display every Engineering Relationship returned by Foundation.

Each relationship shall display:

* Relationship Type
* Source Object
* Target Object
* Author
* Description

Support:

* Sort by Relationship Type
* Sort by Source
* Sort by Target
* Sort by Author

Support filtering:

* Relationship Type
* Source Object
* Target Object
* Author

Filtering and sorting remain Studio responsibilities.

---

# Property Inspector

Selecting a relationship shall display:

* Relationship ID
* Relationship Type
* Source Object
* Target Object
* Author
* Description
* Created Timestamp

Selecting an object shall continue displaying Object metadata.

The Property Inspector shall switch automatically between Object mode and Relationship mode.

---

# Relationship Navigation

Double-clicking a relationship shall:

* Navigate to the Source Object.
* Navigate to the Target Object.

Provide toolbar buttons:

* Go To Source
* Go To Target

---

# STUDIO-TASK-000012

# Live Search Workspace

## Purpose

Connect Studio's Search Workspace to Foundation's Repository Search API.

Studio shall never implement repository search independently.

---

# Requirements

Support:

* Repository Search
* Object Search
* Relationship Search

Display results exactly in the order returned by Foundation.

Studio shall never reorder search results.

---

# Search Results

Each result shall display:

* Icon
* Name
* Result Type
* Match Score
* Match Location

Selecting a result shall:

* Navigate to the appropriate Explorer.
* Select the corresponding Object or Relationship.
* Update the Property Inspector.

---

# Search History

Maintain in-memory search history.

History remains session-only.

Provide:

* Previous Searches
* Clear History

Search history shall not be stored in the repository.

---

# Connection Manager

Extend the existing Connection Manager.

Manage:

* Current Search Results
* Current Relationship List
* Selected Relationship
* Current Search Query

Widgets continue consuming only the Connection Manager.

---

# Dashboard

No structural changes.

Continue displaying live Foundation statistics.

---

# Status Bar

Continue displaying:

* Runtime
* Repository
* Selected Object
* Theme
* Studio Version

Do not introduce additional Status Bar fields.

---

# Architecture Rules

Relationship Explorer

↓

Connection Manager

↓

Foundation Bridge

↓

Public C API

↓

Foundation Runtime

Search Workspace

↓

Connection Manager

↓

Foundation Bridge

↓

Public C API

↓

Foundation Runtime

Widgets shall never call Foundation directly.

No business logic shall exist in Widgets.

---

# Error Handling

If relationship retrieval fails:

Display an informative empty-state message.

If search fails:

Display a professional error dialog.

Studio shall remain responsive.

No native implementation details shall be exposed.

---

# Verification

Perform:

* flutter analyze
* flutter test
* flutter build windows

Verify:

* Relationship Explorer displays live relationships.
* Relationship sorting functions correctly.
* Relationship filtering functions correctly.
* Property Inspector updates correctly.
* Repository Search returns live Foundation results.
* Object Search returns live Foundation results.
* Relationship Search returns live Foundation results.
* Search result navigation functions correctly.
* Connection Manager updates correctly.
* Window resizing remains correct.

Perform manual verification using a Foundation-generated repository containing:

* Multiple Engineering Objects
* Multiple Engineering Relationships
* Multiple searchable metadata fields

---

# Documentation

Update:

* README.md
* docs/IMPLEMENTATION_STATUS.md
* docs/CONNECTION_MANAGER.md
* docs/FOUNDATION_BRIDGE.md
* docs/SEARCH_WORKSPACE.md

Document:

* Relationship enumeration lifecycle
* Search execution lifecycle
* Search navigation
* Property Inspector state transitions

---

# Definition of Done

This work package is complete when:

* Relationship Explorer displays live Foundation relationships.
* Search Workspace performs live Foundation searches.
* Property Inspector displays live relationship metadata.
* Search navigation functions correctly.
* Documentation is complete.
* Flutter analyze passes.
* Flutter tests pass.
* Windows build succeeds.
* Manual verification confirms correct operation.

Stop after completion and await formal review.
