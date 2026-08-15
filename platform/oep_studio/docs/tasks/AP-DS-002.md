# ARCHITECTURE PHASE

ID: AP-DS-002

Title:
Engineering Repository Integration

Component:
oep_studio

Priority:
Critical

Status:
Ready

---

# Objective

Replace Diagram Studio's local JSON document model with the Foundation Runtime Engineering Repository.

The editor experience established during AP-DS-001 through AP-DS-001B shall remain unchanged.

Diagram Studio shall become an engineering authoring environment whose documents are Engineering Objects managed by the Foundation Runtime.

---

# Architectural Principles

Diagram Studio remains an application.

The Engineering Engine remains responsible for editing behavior.

The Foundation Runtime remains responsible for persistence.

Diagram Studio shall never access:

- SQL
- Repository internals
- Package internals
- Transactions
- Trust
- Dependency Resolution

Diagram Studio shall communicate only through the RuntimeService and Engineering Engine.

---

# Scope

Replace local persistence only.

Do not redesign:

- Canvas
- Rendering
- Commands
- Selection
- Editing
- Toolbars
- Panels
- Workflows

The editing experience must remain functionally identical.

---

# Engineering Document Model

Replace local JSON documents with Engineering Objects.

Map every diagram element to Engineering Objects and Relationships.

Examples:

Diagram

Sheet

Drawing Set

Wire

Connector

Module

Harness

Splice

Terminal

Annotation

Layer

Viewport

Selection Set

User Preferences

Document Metadata

Relationship Metadata

The mapping shall be documented.

---

# Repository Integration

Implement:

Open Engineering Project

Create Engineering Project

Save Engineering Project

Save As

Project Browser

Repository Browser

Recent Projects

Project Metadata

Project Version

Project Identity

Package Identity

Repository Identity

---

# Runtime Integration

Consume RuntimeService exclusively.

No direct repository access.

No FoundationRuntime access.

No storage bypasses.

---

# Transaction Integration

Every editing command that modifies engineering data shall execute through Repository Transactions.

Undo/Redo shall remain unchanged from the user's perspective.

---

# Package Integration

Support:

Create Package

Open Package

Save Package

Install Package

Package Metadata

Publisher Metadata

Package Validation

No networking.

No Exchange integration.

---

# Migration

Provide migration from legacy local JSON diagrams.

Requirements:

Automatic conversion

Verification

Error reporting

Rollback on failure

No data loss

---

# Project Browser

Implement:

Repository tree

Packages

Projects

Recent projects

Search

Sorting

Filtering

Metadata

---

# Repository Events

Respond to:

Project opened

Project saved

Package installed

Package updated

Package removed

Repository changed

Refresh editor state appropriately.

---

# Testing

Implement:

Migration tests

Repository integration tests

Transaction tests

Undo/Redo regression

Save/Open regression

Project lifecycle

Package lifecycle

Large project tests

Regression tests

---

# Documentation

Update:

Architecture

Document Model

Engineering Mapping

Repository Integration

Migration Guide

Developer Guide

README

Implementation Status

Roadmap

---

# Deliverables

Engineering Repository Integration

Repository Browser

Project Browser

Migration System

Repository-backed documents

Package integration

Transaction integration

Documentation

Tests

---

# Exit Criteria

✓ Local JSON persistence removed from production workflows

✓ Engineering Objects become the canonical document model

✓ Repository-backed projects operational

✓ Migration completed

✓ Existing editor workflows unchanged

✓ RuntimeService exclusively used

✓ Tests passing

✓ Documentation complete