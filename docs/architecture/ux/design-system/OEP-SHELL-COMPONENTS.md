# OEP Shell Components

**Status:** Proposed implementation baseline
**Purpose:** Define the reusable desktop shell that Studios must consume instead of independently inventing navigation chrome.

## 1. Shell anatomy

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Application Header                                                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ Global Studio Bar                                                            │
├──────────────────────────────────────────────────────────────────────────────┤
│ Workspace Bar                                                                │
├───────────────┬───────────────────────────────────────────────┬──────────────┤
│ Context Nav   │ Toolbar / Context Actions                    │ Inspector    │
│               ├───────────────────────────────────────────────┤              │
│               │                                               │              │
│               │ Primary Engineering Surface                  │              │
│               │                                               │              │
├───────────────┴───────────────────────────────────────────────┴──────────────┤
│ Status / Context Bar                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

The exact presence of each region is Studio-specific. The hierarchy is not.

## 2. Application Header

Purpose: identify OEP and provide application-level controls.

Rules:
- visually quiet;
- never consume the majority of vertical space;
- no Studio-specific navigation embedded here;
- no browser address-bar metaphor.

## 3. Global Studio Bar

Purpose: switch between meaningful OEP destinations.

Studios are first-class destinations. The bar may include Home, Diagram Studio, EAM, Knowledge Studio, Engineering Exchange, Engineering Intelligence, Instruments, Settings, and other ratified Studios.

Rules:
- native application tabs, not browser tabs;
- active Studio is obvious;
- inactive Studios remain available;
- no backend capability names such as Objects or Relationships as global tabs;
- no duplicate Studio-specific navigation in the global bar.

## 4. Workspace Bar

Purpose: identify open work inside the active Studio.

Examples include an open wiring artifact, acquisition workspace, project, or reference document.

Rules:
- workspace tabs represent OEP work contexts;
- closing a workspace must not imply closing the Studio;
- workspace labels should identify the engineering subject, not an internal class name;
- `+` creates/opens another workspace when the Studio supports it.

## 5. Context Navigation

Purpose: expose views and workflow stages that make sense for the current workspace.

Examples:
- Overview
- Document
- Objects
- Relationships
- Graph
- Validation
- Evidence
- History

A contextual item must derive its meaning from the current workspace. Do not promote it to global navigation merely because it has a route or backend service.

## 6. Toolbar

Purpose: expose actions applicable to the current selection/workspace.

Rules:
- action density is preferred over decorative spacing;
- destructive actions require clear separation/confirmation semantics;
- selection-dependent actions should disable rather than disappear when discoverability matters;
- toolbar must not become a second navigation bar.

## 7. Main Engineering Surface

The main surface belongs to the owning Studio. It may be a diagram canvas, document viewer, acquisition workflow, editor, table, or other engineering surface.

The shell must not dictate the internal rendering implementation.

## 8. Inspector

Purpose: inspect the selected engineering entity or current context.

Rules:
- contextual;
- compact;
- structured fields rather than card-heavy presentation;
- should not duplicate the entire object browser;
- selection changes should update the inspector without changing global navigation.

## 9. Status / Context Bar

Use for concise state such as save status, connection state, validation state, cursor coordinates, or active mode. Do not turn it into a dashboard.

## 10. Component ownership

The OEP Studio host owns shell composition. The owning Studio owns the contents of its workspace and contextual tools. Engine remains authoritative for engineering model, graph/layout/commands/validation/search/editing/navigation/rendering where established by the architecture.
