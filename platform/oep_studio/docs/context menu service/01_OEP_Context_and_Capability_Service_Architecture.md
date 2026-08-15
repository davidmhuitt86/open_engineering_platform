# OEP Context & Capability Service --- Architecture Specification

**Status:** Proposed architectural specification\
**Primary consumer:** OEP Studio / Flutter application\
**Purpose:** Define the application-layer service that resolves
engineering context and available capabilities into contextual commands
without coupling Foundation or Engine to UI.

------------------------------------------------------------------------

## 1. Architectural Intent

OEP requires a common mechanism for determining which operations are
available at a particular point in the application.

The same mechanism must eventually support:

-   Right-click contextual menus.
-   Ribbon commands.
-   Command Palette.
-   Keyboard shortcuts.
-   Toolbar/action surfaces.
-   Contextual panels.

The system must not implement a separate command system for each
presentation surface.

The governing architecture is:

``` text
                    OEP STUDIO
                        |
                        v
          +----------------------------+
          | Context & Capability Bridge |
          +-------------+--------------+
                        |
                        v
          +----------------------------+
          | Contextual Command Service |
          +-------------+--------------+
                        |
             +----------+----------+
             |          |          |
             v          v          v
        Foundation    Engine    Platform Services
```

The UI renders the resulting commands. It does not determine engineering
capability itself.

------------------------------------------------------------------------

## 2. Architectural Boundary

### Foundation / Engine / Services

These systems provide facts and capabilities.

Examples:

-   Object type.
-   Object state.
-   Relationships.
-   Measurement support.
-   Fault-model support.
-   Simulation support.
-   Knowledge relationships.
-   Validation capability.
-   Permission/capability state.

### Context & Capability Bridge

This application-layer boundary gathers those facts into a normalized
context.

### Contextual Command Service

This service determines which commands are applicable to the normalized
context.

### UI

The UI renders the resulting commands.

The dependency direction must remain:

``` text
UI
 |
Contextual Command Service
 |
Context & Capability Bridge
 |
Foundation / Engine / Services
```

Foundation and Engine must not depend on Flutter menu widgets.

------------------------------------------------------------------------

## 3. What the Service Owns

The Contextual Command Service owns:

-   Context normalization.
-   Capability evaluation.
-   Command applicability.
-   Command visibility.
-   Command grouping.
-   Command ordering.
-   Submenu hierarchy.
-   Command descriptors.
-   Presentation-neutral command metadata.
-   Execution routing.

It does not own:

-   Flutter widget rendering.
-   Engineering algorithms.
-   Electrical calculations.
-   Simulation algorithms.
-   Knowledge extraction.
-   Repository persistence.
-   AI reasoning.

------------------------------------------------------------------------

## 4. What the Service Must Not Become

Do not create:

-   A second repository.
-   A second engineering model.
-   A duplicate simulation engine.
-   A Flutter-specific Foundation layer.
-   Hard-coded menus for every object type.
-   One class per context menu.
-   A giant switch statement containing all possible UI combinations.

The system must remain capability-driven.

------------------------------------------------------------------------

## 5. Core Flow

``` text
User interaction
      |
      v
Context target identified
      |
      v
EngineeringInteractionContext
      |
      v
Context & Capability Bridge
      |
      v
Normalized capabilities
      |
      v
Contextual Command Service
      |
      v
Applicable CommandDescriptors
      |
      v
Command grouping / ordering
      |
      v
Presentation surface
      |
      +--> Context Menu
      +--> Ribbon
      +--> Command Palette
      +--> Shortcut
      +--> Toolbar
```

------------------------------------------------------------------------

## 6. Context Must Be First-Class

The service must not receive a long list of unrelated parameters.

It should receive one structured interaction context.

Conceptual shape:

``` text
EngineeringInteractionContext
    workspace
    view
    activeDocument
    selection
    cursorTarget
    diagramState
    simulationState
    measurementState
    knowledgeState
    aiState
    permissions
    availableServices
```

Fields may be null/empty when the real application state does not
provide them.

The service must not invent missing state.

------------------------------------------------------------------------

## 7. Capability Model

Capabilities are facts, not menu labels.

Examples:

``` text
VoltageMeasurement
VoltageDropMeasurement
ResistanceMeasurement
ContinuityMeasurement
CurrentMeasurement

OpenCircuitFault
ShortToGroundFault
ShortToPowerFault
HighResistanceFault
IntermittentFault

ComponentStateControl
SimulationControl
EngineeringSimulation
DiagnosticSimulation

KnowledgeLookup
KnowledgeSourceAccess
ChainOfCustodyAccess

AIAnalysis
```

A capability may be:

-   Available.
-   Unavailable.
-   Available only under a condition.
-   Restricted by permission.

------------------------------------------------------------------------

## 8. Command Model

A command is a presentation-neutral operation.

Example:

``` text
diagram.measure.voltage
```

Descriptor:

``` text
id
label
description
category
icon
requirements
visibility
priority
execution target
```

The command descriptor does not contain Flutter widgets.

------------------------------------------------------------------------

## 9. Command Requirements

Commands declare requirements rather than manually checking every
possible menu.

Example:

``` text
Measure Voltage

Requires:
    SelectedEngineeringTarget
    VoltageMeasurement
    MeasurementService
```

Another:

``` text
Inject Open Circuit

Requires:
    SelectedEngineeringTarget
    DiagnosticSimulation
    OpenCircuitFault
```

The resolver evaluates requirements against the current context.

------------------------------------------------------------------------

## 10. Contextual vs Global Commands

Commands may have scopes such as:

``` text
Global
Workspace
Document
Selection
Simulation
Knowledge
```

A selection-scoped command should not appear when nothing is selected.

A simulation-scoped command should not appear when simulation is
inactive.

------------------------------------------------------------------------

## 11. Presentation Independence

The same command can appear in multiple surfaces.

Example:

``` text
diagram.measure.voltage
```

may appear in:

-   Right-click menu.
-   Diagnostic ribbon.
-   Command Palette.
-   Keyboard shortcut.

The command definition remains one object.

------------------------------------------------------------------------

## 12. Extensibility

The architecture should allow future services to contribute capabilities
and commands without modifying the core resolver for every new feature.

Potential contributors:

-   Diagram Engine.
-   Simulation Engine.
-   Knowledge Engine.
-   Acquisition.
-   Exchange.
-   Validation.
-   AI.
-   Repository.
-   Package subsystem.

The first implementation may use statically registered adapters.
Plugin-contributed command registration should remain a future extension
unless an existing plugin architecture already supports it.

------------------------------------------------------------------------

## 13. Initial Implementation Boundary

Implement this service in `oep_studio` first.

Do not move the command system into `oep_foundation` merely to obtain
reuse.

Foundation should expose engineering facts through its existing
bridge/API.

The Studio application layer can normalize those facts into contextual
capabilities.

------------------------------------------------------------------------

## 14. Design Principle

> **Foundation and Engine determine what is possible. The Contextual
> Command Service determines what is applicable now. The UI determines
> how it is presented.**

This is the primary architectural rule for the system.
