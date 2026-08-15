# OEP Diagram Studio --- Definition, Scope & User Workflow

**Status:** Proposed architectural/UI baseline\
**Scope:** Diagram Studio

## 1. Purpose

Diagram Studio is the primary engineering workspace for working with an
engineering diagram after it has been opened, created, acquired, or
imported.

**The diagram is the center of the workflow.**

Before a diagram is open, Diagram Studio acts primarily as a task
launcher. After a diagram is open, it becomes the engineering workbench.

## 2. What Diagram Studio Is

Diagram Studio provides the workflow for:

-   Opening existing diagrams.
-   Creating diagrams.
-   Acquiring diagrams from engineering sources.
-   Obtaining engineering assets from Engineering Exchange.
-   Editing diagrams.
-   Inspecting engineering objects and relationships.
-   Validating diagrams.
-   Accessing engineering knowledge relevant to the active diagram.
-   Asking AI questions in the context of the active diagram.
-   Running diagnostic simulation.
-   Running engineering/system simulation when supported.
-   Performing measurements.
-   Injecting supported diagnostic faults.
-   Following guided diagnostic procedures.
-   Navigating from diagnostic results directly to diagram locations and
    test points.

## 3. What Diagram Studio Is Not

Diagram Studio is not:

-   The Engineering Knowledge database itself.
-   Engineering Exchange.
-   Engineering Acquisition.
-   A generic AI application.
-   A package-management application.
-   Repository administration.
-   A generic simulation laboratory unrelated to a diagram.
-   A replacement for the Engineering Engine.
-   A replacement for the Foundation Repository.

Those capabilities may be invoked contextually while retaining their own
architectural ownership.

## 4. Initial Diagram Studio Experience

When no diagram is open, the primary question should be:

> **What do you want to do?**

Primary actions:

1.  **Open Existing Diagram**
2.  **Create New Diagram**
3.  **Get From Engineering Exchange**
4.  **Acquire From Source**
5.  **Import** --- only when a real supported importer exists.

Diagram-dependent engineering controls should not dominate this screen.

## 5. After a Diagram Is Open

The workspace becomes centered on the active diagram.

Contextually available functions may include:

-   Edit
-   Inspect
-   Validate
-   Search
-   Knowledge
-   AI
-   Diagnose
-   Simulate
-   Measure
-   Test
-   Annotate
-   Export

Only capabilities actually supported by the underlying platform should
be presented as functional.

## 6. Knowledge as a Global Contextual Capability

Knowledge Studio should be treated as a global platform capability
rather than a permanent competing Studio in the main navigation.

Knowledge can be invoked when needed:

-   Select an object and inspect its knowledge.
-   Select a wire or connector and look up information.
-   Search the knowledge repository.
-   Open a knowledge object.
-   Ask AI about the active diagram.
-   Dock or tab the knowledge view.

The knowledge repository remains globally searchable regardless of the
current Studio.

## 7. AI as a Contextual Capability

AI should operate primarily against the active engineering context,
which may include:

-   Active diagram.
-   Selected object or relationship.
-   Selected nodes.
-   Validation results.
-   Diagnostic state.
-   Measurements.
-   Fault conditions.
-   Relevant engineering knowledge.
-   User-entered symptoms.

AI must not imply capabilities the runtime does not actually possess.

## 8. Simulation as a Contextual Capability

Simulation is primarily invoked from an open diagram.

Preferred workflow:

**Open Diagram → Simulate → Select Simulation Mode**

Two modes are defined in the companion specification:

1.  Diagnostic Simulation.
2.  Engineering/System Simulation.

## 9. Navigation Philosophy

The main application shell should not expose every OEP subsystem
simultaneously.

Inside Diagram Studio, the primary navigation should describe Diagram
Studio functions. Other platform capabilities should appear
contextually.

Example:

``` text
Diagram Studio
├── Diagram
├── Edit
├── Inspect
├── Validate
├── Knowledge
├── AI
├── Diagnose
└── Simulate
```

Repository administration, Exchange administration, acquisition
administration, package management, and unrelated Studio functions
should not permanently consume Diagram Studio navigation space.

## 10. Tabs and Panels

Contextual capabilities should be opened as panels or tabs.

Examples:

-   Diagram
-   Knowledge
-   Diagnostic
-   Simulation
-   Validation
-   AI

Panels/tabs may be:

-   Selected
-   Closed
-   Pinned
-   Reordered
-   Docked
-   Undocked where supported

## 11. Core UI Principle

> **Do not expose a capability merely because OEP possesses it. Expose
> it when the active engineering context makes it useful.**

This reduces cognitive load and prevents the application shell from
becoming a catalog of every OEP subsystem.

## 12. Architectural Boundary

Diagram Studio orchestrates the engineering workflow while the
Engineering Engine executes diagram/document behavior.

The Studio owns workspace chrome, panels, orchestration, and user
workflow. The Engineering Engine owns the underlying diagram/document
behavior.

The Studio composes platform capabilities rather than reimplementing
them.

## 13. Definition of Done

The UI direction is successful when:

1.  Users enter Diagram Studio without being confronted by unrelated OEP
    systems.
2.  The initial screen clearly asks what the user wants to accomplish.
3.  Diagram-dependent functions become available after a diagram is
    open.
4.  Knowledge remains globally accessible without permanently occupying
    primary navigation.
5.  AI can be invoked against the active diagram context.
6.  Diagnostic and engineering simulation are invoked from the diagram
    workflow.
7.  Contextual panels/tabs can be opened, closed, docked, and pinned.
8.  The current engineering context remains obvious.
9.  Unsupported capabilities are never presented as functional.
10. Diagram Studio remains centered on the engineering diagram.
