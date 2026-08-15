# WORK PACKAGE 021

# Engineering Graph Editing

Status: Approved

Version: 1.0

Repository

projects/platform/oep_engine

---

# Objective

Implement the first complete Engineering Graph editing capability.

This work package establishes the Engineering Engine as a fully interactive editor.

Editing operations shall modify the Engineering Graph.

Diagram View shall observe the Engineering Graph and update automatically.

The Diagram View shall never own engineering state.

No Studio integration.

No Marketplace integration.

No Simulation.

---

# ENGINE-TASK-000079

Engineering Graph Editing

Implement editing operations for:

Create Node

Delete Node

Move Node

Duplicate Node

Create Relationship

Delete Relationship

Reconnect Relationship

Update Properties

Rename

Change Category

Undoable operations only.

---

# ENGINE-TASK-000080

Selection System

Implement:

Single Selection

Multi Selection

Box Selection

Toggle Selection

Select All

Deselect All

Selection Priority

Selection Events

Selection Persistence

Selection shall remain independent from rendering.

---

# ENGINE-TASK-000081

Move System

Implement:

Drag Node

Move Multiple Nodes

Snap Preview

Alignment Preview

Undo

Redo

Movement updates Engineering Graph coordinates only.

Diagram View redraws automatically.

---

# ENGINE-TASK-000082

Grouping

Implement:

Create Group

Ungroup

Nested Groups

Collapse

Expand

Rename

Visibility

Lock

Groups are Engineering Graph objects.

---

# ENGINE-TASK-000083

Clipboard

Implement:

Copy

Cut

Paste

Duplicate

Clone

Maintain graph integrity.

Generate new identifiers.

Preserve relationships where possible.

---

# ENGINE-TASK-000084

Undo / Redo

Implement deterministic command history.

Operations include:

Create

Delete

Move

Property Change

Relationship

Grouping

Clipboard

Undo/Redo shall operate on Engineering Graph mutations.

---

# ENGINE-TASK-000085

Property Editing

Support editing of:

Engineering Node

Relationship

Port

Group

Evidence Link

Net (if approved through SDD amendments)

Confidence (if approved through SDD amendments)

Property changes shall be undoable.

---

# ENGINE-TASK-000086

Orthogonal Wire Routing

Implement the first routing engine.

Support:

Horizontal

Vertical

90° corners

Automatic reroute

Port snapping

Connection preservation

The routing engine shall remain replaceable.

Future routing engines may register through EngineRegistry.

---

# ENGINE-TASK-000087

View Synchronization

Diagram View shall automatically observe:

Selection

Movement

Grouping

Routing

Property Changes

Clipboard

Undo

Redo

No manual refreshes.

Views remain passive.

---

# Demonstration Host

Extend the Engineering Engine Demonstration Host.

Add:

Toolbar

Editing Commands

Selection Tools

Clipboard

Undo

Redo

Status Bar

Routing Visualization

Properties

Validation Refresh

This remains a Demonstration Host.

Not Diagram Studio.

---

# Documentation

Update:

README.md

ARCHITECTURE_DECISIONS.md

Create:

docs/GRAPH_EDITING.md

docs/UNDO_REDO.md

docs/ROUTING_ENGINE.md

docs/SELECTION_MODEL.md

Document:

Editing philosophy

Command model

Routing architecture

Selection architecture

Future extension points

---

# Verification

Perform:

flutter analyze

flutter test

flutter build windows

Manual verification:

Create graph

Edit graph

Move nodes

Create relationships

Delete relationships

Clipboard

Undo

Redo

Routing

Selection

Grouping

Property editing

Validation updates

---

# Definition of Done

Complete when:

Engineering Graph supports interactive editing.

Selection system complete.

Clipboard complete.

Undo/Redo complete.

Orthogonal routing operational.

Demonstration Host fully interactive.

Documentation complete.

All tests pass.

Windows build succeeds.

Stop and await architectural review.