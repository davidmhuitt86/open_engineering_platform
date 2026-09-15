# Diagram Studio Golden Workspace Specification

**Status:** Proposed implementation baseline
**Screen ID:** `DS-WORKSPACE-A`
**Target:** Windows desktop, 1920×1080, 16:9, full application window
**Purpose:** First OEP screen used to validate shell reuse, Studio integration, engineering-surface preservation, and visual QA.

## 1. Intent

Diagram Studio is the golden screen because it exercises the OEP shell while retaining a real engineering surface. The objective is to make the existing Diagram Studio feel native to OEP without replacing its engineering behavior.

## 2. Screen hierarchy

```text
OEP Application
└── Diagram Studio
    └── Open Diagram Workspace
        ├── Context Navigation / diagram tree
        ├── Diagram Toolbar
        ├── Wiring Diagram Surface
        └── Property / Selection Inspector
```

## 3. Required visible regions

### Application Header
OEP identity and application-level controls. Compact.

### Global Studio Bar
Diagram Studio is visibly active. Other meaningful Studios may remain available according to the current OEP shell implementation.

### Workspace Bar
Shows the active diagram/work item. Workspace identity is distinct from Studio identity.

### Left Context Region
Provides diagram/document context and navigation. It should expose the engineering structure without becoming a generic application menu.

### Center Diagram Surface
The existing real Diagram Studio/wiring surface remains the primary visual focus. Existing diagram data, interaction model, renderer, command behavior, and Engine bridge remain authoritative.

### Right Inspector
Shows properties/details for the current selection or context. It is contextual, compact, and visually subordinate to the engineering surface.

### Bottom Status Region
Optional concise status/context information. It must not become a dashboard.

## 4. Diagram surface requirements

The redesign must preserve the characteristics that make Diagram Studio an engineering tool:

- visible wiring/diagram content;
- engineering symbols/components;
- readable wire paths and labels;
- selection/focus state;
- inspection of engineering entities;
- existing interaction affordances;
- existing Engine/Legacy-V2 bridge behavior where currently authorized.

The UI WP is not authorized to replace the engineering renderer with a static mockup.

## 5. Visual target

The screen should follow the OEP visual baseline:

- dark near-black/slate application foundation;
- slightly lighter panel surfaces;
- restrained blue active state;
- subtle structural borders;
- compact professional typography;
- selective corner radii;
- high information density;
- clear separation between shell chrome and engineering content.

## 6. Layout behavior

At the 1920×1080 baseline, the diagram surface receives the majority of available area. Left context navigation and right inspector are persistent side regions in the golden reference. Their widths should be stable and user-adjustable if the existing implementation supports resizing.

The center surface must resize rather than force clipping when side regions change width.

## 7. Interaction rules

- selecting a diagram entity updates contextual inspection;
- contextual tools remain near the work they affect;
- opening another work item uses the Workspace Bar rather than creating a new top-level Studio destination;
- Objects, Relationships, Graph, and Validation are contextual capabilities, not global Studio destinations;
- existing commands/undo/redo and Engine-facing behavior remain unchanged unless separately authorized.

## 8. Non-goals

This WP does not authorize:

- redesigning the Engine;
- changing the diagram data model;
- replacing the Legacy V2 renderer solely for visual reasons;
- changing bridge protocols;
- changing persistence;
- inventing new engineering semantics;
- adding unrelated global navigation;
- converting Diagram Studio into a generic dashboard.

## 9. Implementation evidence

The implementation agent must provide a design-to-code map and a final 1920×1080 screenshot. The final report must identify any reference mismatch that could not be resolved without changing an architectural boundary.
