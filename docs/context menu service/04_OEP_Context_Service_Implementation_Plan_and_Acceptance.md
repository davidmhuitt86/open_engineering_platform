# OEP Context Service --- Implementation Plan & Acceptance Criteria

**Status:** Implementation guidance for Claude\
**Scope:** Initial implementation in `oep_studio`

------------------------------------------------------------------------

## 1. Objective

Implement the first production version of the OEP Context & Capability /
Contextual Command architecture without rewriting Foundation, Engine, or
existing Studio functionality.

The first implementation should establish the architecture and migrate
existing commands incrementally.

------------------------------------------------------------------------

## 2. Inspect Before Changing

Before implementation:

1.  Inspect the existing command registry.
2.  Inspect existing command descriptor types.
3.  Inspect current Ribbon implementation.
4.  Inspect existing command execution paths.
5.  Inspect current `PropertyInspectorPanel`.
6.  Inspect Foundation bridge/service APIs.
7.  Inspect Engine service APIs.
8.  Inspect simulation state ownership.
9.  Inspect existing Knowledge and AI service access.
10. Identify existing selection/state providers.

Do not create duplicate services where an existing authoritative
provider already exists.

------------------------------------------------------------------------

## 3. First Implementation Boundary

Initial implementation should be limited to:

``` text
oep_studio
    Context
    Capability Resolution
    Command Resolution
    Menu Descriptor
    Execution Bridge
```

Do not simultaneously redesign:

-   Foundation.
-   Engineering Engine.
-   Database schema.
-   Repository format.
-   Acquisition backend.
-   Exchange backend.
-   Simulation engine.

------------------------------------------------------------------------

## 4. Recommended Initial Components

Conceptual structure:

``` text
lib/core/commands/
    command.dart
    command_registry.dart
    command_context.dart
    command_capability.dart
    command_resolver.dart
    menu_descriptor.dart

lib/services/
    contextual_command_service.dart

lib/adapters/
    foundation_command_adapter.dart
    engine_command_adapter.dart
    simulation_command_adapter.dart
    knowledge_command_adapter.dart
    ai_command_adapter.dart
```

Names may be adjusted to existing repository conventions.

Do not create unnecessary abstractions merely to match this exact
directory tree.

------------------------------------------------------------------------

## 5. Existing Command Framework

The existing command framework must be extended rather than replaced
unless inspection proves it cannot support the required behavior.

Existing zero-argument commands should continue working.

Existing command IDs should remain stable.

Existing Ribbon behavior must not regress.

------------------------------------------------------------------------

## 6. Context Creation

Create an `EngineeringInteractionContext` from actual application state.

For Diagram Studio, initially support:

-   Current diagram/document.
-   Cursor target.
-   Current selection.
-   Simulation mode.
-   DMM/instrument state where available.
-   Knowledge availability.
-   AI availability.
-   Editing permissions where available.

Do not invent state that is currently page-private or unavailable.

If state is unavailable, represent it as unavailable.

------------------------------------------------------------------------

## 7. First Commands to Migrate

Start with a small representative set:

``` text
Inspect Object
View Properties
Show Connections

Place DMM Probe +
Place DMM Probe -

Measure Voltage
Measure Voltage Drop
Measure Resistance
Check Continuity

Inject Open Circuit
Inject Short to Ground
Inject Short to Power

View Engineering Knowledge
Ask AI About Selection
Add Annotation
```

Only migrate commands whose underlying execution capability already
exists.

Do not implement fake execution merely to populate the menu.

------------------------------------------------------------------------

## 8. First Presentation Surface

Implement the **Diagram Studio right-click contextual menu** first.

Do not immediately refactor Ribbon, Command Palette, and every Studio.

Once the contextual menu is proven, reuse the same command definitions
for other presentation surfaces.

------------------------------------------------------------------------

## 9. Right-Click Targeting

The Diagram Studio canvas must identify the engineering object under the
cursor.

The context service should receive:

``` text
cursorTarget
```

separately from:

``` text
selection
```

This is required because right-clicking an object should work without
requiring a prior left-click.

------------------------------------------------------------------------

## 10. DMM Workflow

The first real contextual interaction should support:

``` text
Right-click valid point
→ Place DMM Probe +

Right-click second valid point
→ Place DMM Probe -

→ DMM opens
```

Also support direct commands where the engine can determine endpoints:

``` text
Right-click wire
→ Measure Voltage Drop
```

No fabricated measurement values.

------------------------------------------------------------------------

## 11. Diagnostic Faults

Only expose fault commands when the current simulation and engineering
model support them.

For example:

``` text
Inject Open Circuit
```

must not appear as executable simply because the UI designer wants it
visible.

The command resolver must establish:

``` text
DiagnosticSimulationActive
+
TargetSupportsOpenCircuitFault
+
FaultInjectionServiceAvailable
```

------------------------------------------------------------------------

## 12. Knowledge and AI

Knowledge commands must use existing Knowledge services.

AI commands must use the existing AI provider/context pipeline.

The context service should not create a second AI system.

------------------------------------------------------------------------

## 13. UI Requirements

The contextual menu should:

-   Identify the target object.
-   Group commands.
-   Omit irrelevant groups.
-   Use concise labels.
-   Support submenus.
-   Display useful disabled reasons only where appropriate.
-   Never expose commands that cannot execute.
-   Revalidate before execution.

The menu should visually match the approved OEP Design System.

------------------------------------------------------------------------

## 14. Do Not Do

Do not:

-   Build one menu class per object type.
-   Hard-code all commands inside widgets.
-   Put Flutter UI code into Foundation.
-   Duplicate Foundation capabilities in Studio.
-   Invent unavailable backend operations.
-   Add a giant universal context menu.
-   Replace the existing command registry unnecessarily.
-   Move simulation algorithms into the UI.
-   Make network calls merely to build basic menus.
-   Treat unknown state as available.
-   Modify unrelated Studios during the first implementation.

------------------------------------------------------------------------

## 15. Acceptance Tests

### Test A --- Empty Canvas

Right-click empty diagram canvas.

Expected:

-   No object-specific commands.
-   Valid canvas/diagram commands appear.
-   No measurement/fault commands.

### Test B --- Wire

Right-click a real wire.

Expected:

-   Wire identity appears.
-   Wire inspection commands appear.
-   Measurement commands appear only when supported.
-   Fault commands appear only in appropriate simulation state.

### Test C --- Relay

Right-click a real relay.

Expected:

-   Relay-specific inspection appears.
-   Coil/contact operations appear only when supported.
-   DMM operations appear when measurement capability exists.
-   State/fault operations require appropriate simulation capability.

### Test D --- Simulation Mode

Right-click the same object before and during Diagnostic Simulation.

Expected:

-   Diagnostic commands appear only during the appropriate state.

### Test E --- Missing Capability

Disable/remove a required service.

Expected:

-   Associated executable command disappears or becomes appropriately
    unavailable.
-   No command can bypass the capability check.

### Test F --- Stale Menu

Open a context menu, change the underlying state, then select a
previously valid command.

Expected:

-   Command requirements are revalidated.
-   Invalid execution is rejected safely.

### Test G --- Command Reuse

A command resolved for the context menu must remain the same command
when exposed through another presentation surface.

------------------------------------------------------------------------

## 16. Regression Requirements

Before completion:

``` text
flutter analyze
flutter test
```

Existing functionality must continue to work.

No backend regressions.

No changes to Foundation/Engine unless inspection demonstrates that a
minimal bridge/API is genuinely required.

------------------------------------------------------------------------

## 17. Completion Criteria

The first implementation is complete when:

1.  A structured EngineeringInteractionContext exists.
2.  Capabilities can be resolved from actual application state.
3.  Commands declare requirements.
4.  A contextual command resolver filters commands correctly.
5.  A presentation-neutral MenuDescriptor exists.
6.  Diagram Studio can render a context menu from that descriptor.
7.  Right-click targeting works independently of left-click selection.
8.  At least the initial measurement/probe commands use the
    architecture.
9.  Diagnostic commands are state-aware.
10. Knowledge/AI commands use existing services.
11. Commands revalidate before execution.
12. Existing command/Ribbon behavior remains intact.
13. Tests cover context, capability, visibility, execution, and
    stale-state behavior.

------------------------------------------------------------------------

## 18. Architectural Success Condition

The implementation is successful if adding a new capability does **not**
require creating a new context-menu widget for every object type.

The desired future workflow is:

``` text
Add Capability
      ↓
Register Capability
      ↓
Define Command
      ↓
Declare Requirements
      ↓
Resolver discovers applicability
      ↓
Any compatible presentation surface can display it
```

That is the scalability requirement of the architecture.
