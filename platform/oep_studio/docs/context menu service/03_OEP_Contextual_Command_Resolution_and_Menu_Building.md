# OEP Contextual Command Resolution & Menu Building

**Status:** Proposed implementation specification

------------------------------------------------------------------------

## 1. Purpose

This document defines how OEP converts an EngineeringInteractionContext
into an executable set of contextual commands.

The goal is to avoid implementing separate logic for every possible
context menu.

------------------------------------------------------------------------

## 2. Resolution Pipeline

``` text
Interaction Context
        |
        v
Normalize Context
        |
        v
Collect Capabilities
        |
        v
Load Applicable Commands
        |
        v
Evaluate Requirements
        |
        v
Filter Commands
        |
        v
Group Commands
        |
        v
Sort Commands
        |
        v
Build MenuDescriptor
```

------------------------------------------------------------------------

## 3. Command Registration

Commands should be registered centrally or through controlled feature
adapters.

Example:

``` text
diagram.inspect.object
diagram.measure.voltage
diagram.measure.voltage_drop
diagram.measure.resistance
diagram.measure.continuity

diagram.probe.place_positive
diagram.probe.place_negative

diagram.fault.open_circuit
diagram.fault.short_ground
diagram.fault.short_power
diagram.fault.high_resistance

diagram.knowledge.open
diagram.ai.ask_selection
```

IDs should be stable.

------------------------------------------------------------------------

## 4. Requirement Evaluation

A command defines requirements.

Example:

``` text
diagram.measure.voltage

requires:
    selectedTarget
    electricalTarget
    voltageMeasurement
    measurementService
```

The resolver evaluates each requirement.

Result:

``` text
Applicable
Unavailable
Hidden
```

------------------------------------------------------------------------

## 5. Hidden vs Disabled

Use **hidden** when the command has no meaningful relationship to the
current context.

Use **disabled** when:

-   The command is conceptually relevant.
-   The reason for temporary unavailability is useful to the user.
-   The user may need to understand what is required.

Example:

``` text
Measure Resistance
Unavailable while circuit is energized.
```

Do not flood the menu with disabled commands.

------------------------------------------------------------------------

## 6. Grouping

Commands should declare a semantic group.

Suggested initial groups:

``` text
Inspect
Edit
Test
Diagnose
Simulate
Knowledge
AI
Annotate
Navigate
```

The menu builder creates groups only when at least one applicable
command exists.

------------------------------------------------------------------------

## 7. Ordering

Commands should have a priority or ordering value.

Recommended principle:

``` text
Inspect
Edit
Test
Diagnose / Simulate
Knowledge
AI
Annotate
```

However, actual ordering should be tuned through the design system and
renders.

The resolver must not hard-code a separate order for every object type.

------------------------------------------------------------------------

## 8. Submenus

Submenus are used when a category contains multiple related commands.

Example:

``` text
Measure >
    Voltage
    Voltage Drop
    Resistance
    Continuity
    Current
```

Another:

``` text
Inject Fault >
    Open Circuit
    Short to Ground
    Short to Power
    High Resistance
    Intermittent
```

Submenus should be generated from command grouping rather than
hand-built per menu.

------------------------------------------------------------------------

## 9. Menu Descriptor

The result of resolution should be presentation-neutral.

Conceptual:

``` text
MenuDescriptor
{
    title
    contextIdentity
    sections[]
}

MenuSection
{
    id
    label
    items[]
}

MenuItem
{
    commandId
    label
    description
    icon
    enabled
    disabledReason
    submenu
}
```

Flutter-specific widgets do not belong in these types.

------------------------------------------------------------------------

## 10. Example: Wire in Diagnostic Simulation

Context:

``` text
workspace = diagram
cursorTarget = wire W104
simulationMode = diagnostic
dmmAvailable = true
measurementService = available
```

Resolved menu:

``` text
WIRE W104

INSPECT
    Inspect Wire
    View Properties
    Show Connected Nodes

TEST
    Place DMM Probe +
    Place DMM Probe -
    Measure Voltage
    Measure Voltage Drop
    Measure Resistance
    Check Continuity

DIAGNOSE
    Inject Fault >
        Open Circuit
        High Resistance
        Short to Ground
        Short to Power

KNOWLEDGE
    View Engineering Knowledge
    View Source

AI
    Ask AI About Wire

ANNOTATE
    Add Annotation
```

------------------------------------------------------------------------

## 11. Example: Same Wire in Normal Diagram Mode

Context:

``` text
workspace = diagram
cursorTarget = wire W104
simulationMode = none
```

Resolved menu may become:

``` text
WIRE W104

INSPECT
    Inspect Wire
    View Properties
    Show Connected Nodes

TEST
    Place DMM Probe +
    Place DMM Probe -
    Measure Voltage

KNOWLEDGE
    View Engineering Knowledge

AI
    Ask AI About Wire

ANNOTATE
    Add Annotation
```

Diagnostic fault commands disappear because their requirements are not
satisfied.

------------------------------------------------------------------------

## 12. Example: Empty Canvas

Context:

``` text
cursorTarget = none
canvas = diagram
```

Possible result:

``` text
CREATE
    Create Node
    Create Connection

VIEW
    Zoom to Fit
    Show Object Explorer

DIAGRAM
    Validate Diagram
    Search Diagram

KNOWLEDGE
    Search Knowledge

ANNOTATE
    Add Annotation
    Add Test Point
```

------------------------------------------------------------------------

## 13. Execution

Selecting a menu command should execute through the command framework.

The menu should not directly call random service methods.

Conceptually:

``` text
Menu Item
    |
commandId
    |
CommandRegistry
    |
CommandExecutor
    |
Required Service
```

Example:

``` text
diagram.measure.voltage
        |
        v
MeasurementCommand
        |
        v
MeasurementService
```

------------------------------------------------------------------------

## 14. Execution Context

The command executor should receive the same interaction context used
during resolution, or a validated execution context reconstructed from
current authoritative state.

This prevents stale menu state from executing an operation that is no
longer valid.

The system should revalidate requirements immediately before execution
for operations where state can change.

------------------------------------------------------------------------

## 15. Stale Context

A menu may remain open while the underlying engineering state changes.

Therefore:

``` text
Menu resolution
      |
      v
User selects command
      |
      v
Revalidate capability
      |
      +--> valid → execute
      |
      +--> invalid → explain / refuse
```

Do not execute solely because the command was valid when the menu
opened.

------------------------------------------------------------------------

## 16. Error Handling

Execution failures should return structured results.

Example:

``` text
CommandResult
    success
    message
    errorCode
    affectedObjects
    followUpAction
```

The UI can then present the result through the standard
Output/Notification infrastructure.

------------------------------------------------------------------------

## 17. Logging

The contextual command system should produce useful diagnostic
information.

At minimum:

``` text
context created
capabilities resolved
commands evaluated
commands filtered
command executed
execution result
```

Verbose logging may be disabled in normal operation.

------------------------------------------------------------------------

## 18. Testing Strategy

The resolver should be heavily unit tested independently of Flutter
widgets.

Tests should verify:

### Context

-   Empty canvas.
-   Single object.
-   Multiple selection.
-   No document.
-   Diagram open.
-   Diagnostic simulation.
-   Engineering simulation.

### Capabilities

-   Measurement available/unavailable.
-   Fault capability available/unavailable.
-   Knowledge available/unavailable.
-   AI available/unavailable.

### Commands

-   Correct visibility.
-   Correct enabled state.
-   Correct grouping.
-   Correct ordering.
-   Correct execution routing.

### Safety

-   Unsupported operations never execute.
-   Missing capabilities do not expose executable commands.
-   Stale contexts are revalidated.

------------------------------------------------------------------------

## 19. Performance

Context menu resolution should be fast enough to occur on every
right-click.

Do not perform expensive network operations simply to decide whether a
basic command exists.

Use:

-   Cached local capability state.
-   Lightweight service queries.
-   Existing in-memory state where authoritative.
-   Asynchronous enrichment only where genuinely required.

The initial menu should not block on remote services unless the command
itself fundamentally depends on that service.

------------------------------------------------------------------------

## 20. Core Rule

> **Menus are the rendered consequence of context and capability; they
> are not the source of truth for capability.**
