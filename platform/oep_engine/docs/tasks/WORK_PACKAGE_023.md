# WORK PACKAGE 023

# Professional Engineering Editing

Status: Approved

Version: 1.0

Repository

projects/platform/oep_engine

---

# Objective

Transform the Engineering Engine from a capable diagram editor into a professional engineering drafting environment suitable for production electrical documentation.

The Engineering Graph, Diagram Layout, ViewState, Selection, Command History, Providers, and Views established in WP019–WP022 are now considered architecturally stable.

No new architectural subsystems shall be introduced.

This work package focuses exclusively on expanding professional editing capability.

No Studio integration.

No Marketplace integration.

No Simulation.

---

# ENGINE-TASK-000098

## Advanced Selection

Extend the existing Selection system.

Implement:

- Lasso Selection
- Crossing Selection
- Window Selection
- Connected Component Selection
- Select Similar
- Select by Category
- Select by Layer
- Invert Selection

Selection remains runtime-only.

Selection shall never modify the Engineering Graph.

---

# ENGINE-TASK-000099

## Professional Wire Editing

Extend the RoutingProvider.

Implement:

- Insert Vertex
- Remove Vertex
- Drag Segment
- Drag Corner
- Preserve Orthogonality
- Automatic Corner Cleanup
- Manual Route Override
- Restore Automatic Routing

Routing remains deterministic.

Manual routing edits shall remain undoable.

---

# ENGINE-TASK-000100

## Labels & Annotations

Implement Diagram Layout support for:

- Text Labels
- Leader Notes
- Callouts
- Wire Labels
- Component Labels
- Free Text
- Revision Notes

Annotations belong to Diagram Layout.

They are not Engineering Graph objects.

Support:

- Move
- Rotate
- Edit
- Copy
- Paste
- Undo
- Redo

---

# ENGINE-TASK-000101

## Layer Management

Implement Layout Layers.

Support:

- Create Layer
- Delete Layer
- Rename Layer
- Visibility
- Lock
- Print Visibility
- Layer Assignment

Layers belong to Diagram Layout.

Engineering Graph remains layer-independent.

---

# ENGINE-TASK-000102

## Component Placement Tools

Implement placement helpers.

Support:

- Duplicate While Dragging
- Array Placement
- Mirror Horizontal
- Mirror Vertical
- Rotate 90°
- Rotate 180°
- Rotate Arbitrary Angle
- Replace Symbol

Placement modifies Diagram Layout.

Engineering Graph identity remains unchanged.

---

# ENGINE-TASK-000103

## Editing Constraints

Implement configurable constraints.

Support:

- Orthogonal Movement
- Axis Lock
- Angle Constraint
- Snap Priority
- Connection Protection
- Minimum Wire Length
- Minimum Bend Radius (future-ready)

Constraints operate through existing Commands.

---

# ENGINE-TASK-000104

## Search & Navigation

Implement Engineering search.

Support:

- Search Nodes
- Search Relationships
- Search Symbols
- Search Labels
- Search Layers

Navigation:

- Next Result
- Previous Result
- Zoom To Result
- Select Result
- Center Result

Search indexes Engineering Graph and Diagram Layout independently.

---

# ENGINE-TASK-000105

## Editing Productivity

Implement professional workflow tools.

Support:

- Repeat Last Command
- Recent Commands
- Favorites
- Custom Tool Palette
- Keyboard Shortcut Manager
- Context Menus
- Multi-step Command Preview

Reuse existing Command architecture.

---

# ENGINE-TASK-000106

## Demonstration Host Professionalization

Extend the Demonstration Host.

Add:

- Layer Panel
- Search Panel
- Annotation Tools
- Wire Editing Toolbar
- Placement Toolbar
- Constraint Toolbar
- Status Indicators
- Recent Commands

Remain intentionally separate from Diagram Studio.

Do not introduce docking frameworks or Studio workspace behavior.

---

# Documentation

Create:

docs/LAYER_SYSTEM.md

docs/ANNOTATION_SYSTEM.md

docs/WIRE_EDITING.md

docs/SEARCH_AND_NAVIGATION.md

docs/EDITING_CONSTRAINTS.md

Update:

README.md

docs/ARCHITECTURE_DECISIONS.md

Document:

- Layer architecture
- Annotation ownership
- Wire editing philosophy
- Constraint system
- Search architecture
- Professional editing workflow

---

# Verification

Run:

- flutter analyze
- flutter test
- flutter test integration_test/ -d windows
- flutter build windows

Manual verification shall include:

- Advanced selection modes
- Manual wire editing
- Annotation editing
- Layer creation and visibility
- Symbol replacement
- Rotation and mirroring
- Constraint behavior
- Search and navigation
- Repeat command
- Keyboard shortcuts
- Demonstration Host workflow

---

# Definition of Done

Complete when:

- Professional selection tools are operational.
- Manual wire editing is complete.
- Annotation system is operational.
- Layer management is complete.
- Placement tools are operational.
- Editing constraints are operational.
- Search and navigation are complete.
- Productivity tools are operational.
- Demonstration Host provides a professional engineering editing workflow.
- All tests pass.
- Windows build succeeds.

Stop and await formal architectural review before beginning Diagram Studio integration.