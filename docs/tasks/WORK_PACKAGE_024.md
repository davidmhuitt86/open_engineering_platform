# WORK PACKAGE 024

# Diagram Studio Integration

Status: Approved

Version: 1.0

Repositories

projects/platform/oep_engine

projects/platform/oep_studio

---

# Objective

Integrate the Engineering Engine into OEP Studio as the second major Studio workspace.

This work package retires the Engineering Engine Demonstration Host as the primary user experience.

The Demonstration Host shall remain in the Engineering Engine repository as a permanent regression, testing, and architecture validation application.

Diagram Studio becomes the production application consuming the Engineering Engine.

No engineering behavior shall migrate into OEP Studio.

Studio orchestrates.

Engine executes.

---

# Architectural Goals

This work package establishes the long-term relationship between Studio and Engine.

The ownership boundary is permanent.

Engineering Engine owns:

- Engineering Graph
- Diagram Layout
- ViewState
- Selection
- Command History
- Search
- Routing
- Validation
- Editing
- Navigation
- Rendering Model
- Providers

Studio owns:

- Workspace lifecycle
- Window layout
- Menus
- Toolbars
- Docking
- Workspace persistence
- Property Inspector hosting
- Command routing
- Global application navigation

Studio shall never duplicate Engineering Engine functionality.

---

# ENGINE-TASK-000108

## Diagram Studio Workspace

Create the first Engineering workspace inside OEP Studio.

Implement:

- Diagram Studio Workspace
- Workspace registration
- Workspace lifecycle
- Workspace activation
- Workspace persistence

The workspace consumes only the Engineering Engine public API.

No internal Engine classes may be referenced.

---

# ENGINE-TASK-000109

## Engine Host Layer

Create a thin Engine Host layer inside OEP Studio.

Responsibilities:

- Engine initialization
- Workspace lifecycle
- Provider wiring
- Repository attachment
- Session creation
- Session disposal

The Host layer shall not implement engineering logic.

---

# ENGINE-TASK-000110

## Shared Property Inspector

Integrate Diagram Studio with the existing Studio Property Inspector.

Support inspection of:

- Engineering Nodes
- Relationships
- Groups
- Ports
- Layers
- Annotations
- Wire Overrides

The Property Inspector remains owned by Studio.

Property editing continues through Engineering Engine Commands.

---

# ENGINE-TASK-000111

## Repository Integration

Connect Diagram Studio to Foundation repositories.

Support:

- Open Engineering Repository
- Save Engineering Repository
- Save As
- Close Repository
- Dirty State
- Repository Metadata

Foundation remains repository owner.

Engineering Engine consumes repository services.

---

# ENGINE-TASK-000112

## Studio Command Integration

Integrate Engine Commands with Studio.

Support:

- Undo
- Redo
- Copy
- Cut
- Paste
- Delete
- Duplicate

Studio menu actions invoke Engineering Engine Commands.

Studio does not implement editing.

---

# ENGINE-TASK-000113

## Studio Toolbars

Replace Demonstration Host toolbars.

Implement native Studio toolbars for:

Selection

Navigation

Placement

Wire Editing

Layers

Annotations

View

Search

Constraints

These invoke Engineering Engine APIs.

---

# ENGINE-TASK-000114

## Dockable Panels

Create production Studio panels.

Implement:

Diagram Explorer

Layer Panel

Search Panel

Validation Panel

Annotation Panel

Recent Commands

Reuse existing Studio docking framework.

No custom docking implementation.

---

# ENGINE-TASK-000115

## Workspace Persistence

Persist:

Open documents

Active panels

Toolbar visibility

Window layout

Last repository

Current ViewState

Current Diagram Layout

Engineering Graph remains stored in Foundation.

Workspace persistence belongs to Studio.

---

# ENGINE-TASK-000116

## AI Integration

Expose Diagram Studio to the existing AI framework.

Support:

Diagram Selection

Property Context

Evidence Context

Engineering Graph Context

Prompt Context

Do not implement new AI providers.

Reuse WP016–018 infrastructure.

---

# ENGINE-TASK-000117

## Demonstration Host Transition

Reduce the Demonstration Host to:

Regression testing

Performance testing

Architecture validation

Feature verification

Future development shall occur primarily inside Diagram Studio.

The Demonstration Host remains permanently in the Engine repository.

---

# Documentation

Create:

docs/DIAGRAM_STUDIO_INTEGRATION.md

docs/STUDIO_ENGINE_HOST.md

docs/WORKSPACE_INTEGRATION.md

docs/PROPERTY_INSPECTOR_INTEGRATION.md

docs/REPOSITORY_INTEGRATION.md

Update:

README.md

ARCHITECTURE_DECISIONS.md

Document:

Workspace ownership

Host layer

Repository flow

Property flow

Studio ↔ Engine communication

---

# Verification

Run

oep_engine

flutter analyze

flutter test

flutter build windows

oep_studio

flutter analyze

flutter test

flutter build windows

Manual verification

Create repository

Open Diagram Studio

Create engineering diagram

Save

Close

Reopen

Undo

Redo

Property editing

Search

Layers

Annotations

Workspace persistence

Docking

Property Inspector

AI availability

Repository persistence

---

# Definition of Done

Complete when:

Diagram Studio operates entirely inside OEP Studio.

Engineering Engine owns all engineering behavior.

Studio owns all application behavior.

Foundation owns repositories.

The Demonstration Host is no longer the primary editing experience.

All tests pass.

Windows builds succeed.

Stop and await formal architectural review.