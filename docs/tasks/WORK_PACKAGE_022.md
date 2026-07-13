# WORK PACKAGE 022

# Diagram Editing Environment

Status: Approved

Version: 1.0

Repository

projects/platform/oep_engine

---

# Objective

Transform the Engineering Engine Demonstration Host into a professional engineering diagram editor while preserving the architectural separation established in WP019–WP021.

The Engineering Graph remains the canonical engineering model.

The Diagram View remains a passive visualization.

This work package enhances the editing environment, drafting workflow, layout management, routing, navigation, and user interaction.

No Studio integration.

No Marketplace integration.

No Simulation.

---

# Architectural Separation (Mandatory)

The following separation is now considered permanent architecture.

Engineering Graph
- Engineering knowledge only.
- No layout.
- No viewport.
- No rendering state.

Diagram Layout
- Node positions.
- Diagram geometry.
- Layout persistence.

ViewState
- Zoom
- Pan
- Viewport
- Grid
- Guides
- Theme
- Render options
- Hover state
- Visible layers

Selection
- GraphSelection
- FocusState

Undo / Redo
- CommandHistory
- EditingSession { Graph + Layout }

ViewState and Selection remain runtime concerns.

They are NOT Engineering Knowledge.

They are NOT stored in the Engineering Graph.

Only mutations affecting Engineering Graph or Diagram Layout shall execute through the Command architecture.

Guides, hover state, viewport, zoom, pan, and runtime visualization shall never become commands.

---

# ENGINE-TASK-000088

## ViewState

Create:

lib/core/viewstate/

Implement:

ViewState

ViewStateProvider

ViewStateService

ViewState contains:

- Zoom
- Pan
- Viewport Size
- Visible Layers
- GridSettings
- Guide Visibility
- Theme
- Render Options
- Hovered Port

Provide change notification identical in architecture to SelectionService.

ViewState is NOT part of Engineering Graph.

ViewState is NOT part of Diagram Layout.

ViewState shall be serializable independently of the Engineering Graph and Diagram Layout.

Future Studio workspaces shall be able to persist and restore ViewState without modifying engineering data or layout state.

The serialization mechanism shall remain provider-based.

---

# ENGINE-TASK-000089

## Layout Persistence

Extend LayoutProvider.

Implement:

- Save Named Layout
- Load Named Layout
- List Named Layouts
- Delete Named Layout
- Reset Layout

Implement:

JsonFileLayoutSerializer

following the existing SerializationProvider architecture.

Persistence shall support:

Graph ID

↓

Named Layout

↓

DiagramLayoutState

No Engineering Graph modifications.

---

# ENGINE-TASK-000090

## Professional Grid System

Implement:

GridSettings

GridComputer

GridLine

GridComputer shall expose:

computeLines()

snap()

The Engine computes grid geometry.

The Demonstration Host renders it.

Support:

- Major Grid
- Minor Grid
- Configurable Spacing
- Toggle Grid
- Toggle Snap

No renderer-specific code in Engine.

---

# ENGINE-TASK-000091

## Alignment & Guides

Implement:

AlignmentGuideComputer

Support:

- Smart Guides
- Alignment Guides
- Snap Lines

Implement Commands:

AlignNodesCommand

DistributeNodesCommand

Support:

- Left
- Right
- Top
- Bottom
- Center
- Middle
- Horizontal Distribution
- Vertical Distribution

Guides are runtime only.

Alignment operations mutate Diagram Layout through Commands.

---

# ENGINE-TASK-000092

## Port Interaction

Implement:

PortReference

containing:

- nodeId
- portId

PortReference exists only in the View layer.

Do NOT modify EngineeringRelationship.

Support:

- Hover
- Highlight
- Selection
- Drag Preview
- Port Preview

Hovered Port belongs to ViewState.

Selected Port continues using FocusState.

---

# ENGINE-TASK-000093

## Connection Editing

Extend interaction.

Implement:

- Drag to Connect
- Drag to Reconnect
- Connection Preview
- Invalid Connection Preview
- Connection Cancellation

Reuse existing:

CreateRelationshipCommand

ReconnectRelationshipCommand

Do not introduce new command types.

Implement:

ConnectionValidator

Rules:

- No self loops
- No duplicate relationships

Validator remains pure.

---

# ENGINE-TASK-000094

## Routing Improvements

Extend OrthogonalRoutingProvider.

Implement:

- Shared Trunks
- Improved Corner Cleanup
- Vertical Cleanup
- Horizontal Cleanup
- Crossing Reduction
- Endpoint Refinement

Routing algorithms shall remain deterministic.

Given identical Engineering Graph, Diagram Layout, and routing configuration, the routing provider shall always produce identical routing results.

Future routing providers supplied through EngineRegistry shall satisfy the same determinism requirement.

Routing remains replaceable through EngineRegistry.

---

# ENGINE-TASK-000095

## Viewport Navigation

Create:

viewport_math.dart

Implement:

- Fit All
- Fit Selection
- Center Selection
- Zoom To Cursor

Implement:

NavigationHistory

ViewState owns:

- Zoom
- Pan
- Viewport

Animation remains Demonstration Host responsibility.

No Flutter animation code inside Engine.

---

# ENGINE-TASK-000096

## Drafting Environment

Implement:

- Rulers
- Origin Indicator
- Coordinate Readout
- Crosshair Cursor
- Selection Rectangle
- Marquee Selection
- Status Indicators

Use ViewState.

No Engineering Graph modifications.

---

# ENGINE-TASK-000097

## Demonstration Host

Extend the Demonstration Host.

Add:

Toolbar

View Menu

Grid Settings

Snap Settings

Named Layout Menu

Toolbar Commands:

- Fit All
- Fit Selection
- Center Selection

Support:

Resizable side panels.

Basic implementation only.

Do NOT implement a docking framework.

The Demonstration Host remains an Engineering Engine verification application.

It is NOT Diagram Studio.

---

# Verification

Run:

flutter analyze

flutter test

flutter test integration_test/ -d windows

flutter build windows

Manual verification shall include:

- Grid toggle
- Snap toggle
- Smart guides
- Alignment
- Distribution
- Named layouts
- Layout persistence
- Port hover
- Port selection
- Drag-to-connect
- Drag-to-reconnect
- Routing improvements
- Fit All
- Fit Selection
- Zoom To Cursor
- Navigation History
- Demonstration Host workflow

---

# Documentation

Create:

docs/VIEW_STATE.md

docs/LAYOUT_SYSTEM.md

docs/GRID_SYSTEM.md

docs/ROUTING_ARCHITECTURE.md

docs/PORT_INTERACTION.md

Update:

README.md

docs/ARCHITECTURE_DECISIONS.md

Document:

- ViewState architecture
- Layout persistence
- Grid architecture
- Routing architecture
- Port interaction
- Demonstration Host architecture

---

# Definition of Done

Complete when:

- ViewState subsystem is operational.
- Layout persistence is operational.
- Professional grid system is complete.
- Alignment and distribution commands are operational.
- Port interaction is complete.
- Connection editing is complete.
- Routing improvements are operational.
- Viewport navigation is complete.
- Demonstration Host provides a professional engineering editing environment.
- All tests pass.
- Windows build succeeds.

Stop and await formal architectural review before beginning the next work package.