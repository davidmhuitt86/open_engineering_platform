# OEP Engineering Interaction Context & Capability Contract

**Status:** Proposed contract specification\
**Purpose:** Define the normalized context consumed by the Contextual
Command Service.

------------------------------------------------------------------------

## 1. Purpose

The Contextual Command Service needs a consistent representation of the
user's current engineering situation.

The context must be broad enough to support the large number of possible
menu combinations without requiring individual menu implementations.

------------------------------------------------------------------------

## 2. EngineeringInteractionContext

Conceptual structure:

``` text
EngineeringInteractionContext
{
    workspaceContext
    viewContext
    documentContext
    selectionContext
    cursorContext
    diagramContext
    simulationContext
    measurementContext
    knowledgeContext
    aiContext
    permissionContext
    serviceContext
}
```

The actual implementation language and type names may follow the
existing OEP Studio conventions.

------------------------------------------------------------------------

## 3. Workspace Context

Contains real information about where the user is working.

Possible fields:

``` text
studioId
workspaceId
perspectiveId
route
```

Examples:

``` text
diagram
knowledge
acquisition
repository
exchange
```

Do not fabricate workspace identifiers.

------------------------------------------------------------------------

## 4. View Context

Describes the current view/panel.

Possible fields:

``` text
viewId
viewType
activeTab
```

Examples:

``` text
diagramCanvas
knowledgePanel
diagnosticPanel
simulationPanel
```

------------------------------------------------------------------------

## 5. Document Context

Describes the active engineering document.

Possible fields:

``` text
documentId
documentType
documentName
isOpen
```

The context service must distinguish:

``` text
no document
document open
document active
```

It must not invent document state.

------------------------------------------------------------------------

## 6. Selection Context

Selection is one of the primary inputs to contextual commands.

Possible selection data:

``` text
selectedObjects
selectedRelationships
selectedPorts
selectedLayers
selectedAnnotations
selectedTestPoints
```

The context must support:

-   No selection.
-   Single selection.
-   Multiple selection.

Each selected item should expose normalized identity and capability
information where available.

------------------------------------------------------------------------

## 7. Cursor Context

The cursor target is distinct from the current selection.

For example, the user may right-click a wire without first selecting it.

Possible fields:

``` text
hasTarget
targetType
targetId
diagramPosition
```

The target may be:

-   Empty canvas.
-   Engineering object.
-   Relationship/wire.
-   Port.
-   Pin.
-   Annotation.
-   Test point.

------------------------------------------------------------------------

## 8. Diagram Context

Possible real state:

``` text
diagramId
diagramType
editable
validated
dirty
```

Only values backed by existing application state may be populated.

------------------------------------------------------------------------

## 9. Simulation Context

Possible fields:

``` text
active
mode
scenarioId
scenarioName
operatingState
faults
simulationCapabilities
```

Simulation mode values should distinguish:

``` text
none
diagnostic
engineering
```

If simulation is not active:

``` text
active = false
```

The service must not infer simulation state from UI appearance alone.

------------------------------------------------------------------------

## 10. Measurement Context

Possible fields:

``` text
dmmAvailable
activeInstrument
probePositive
probeNegative
measurementMode
measurementValue
measurementValidity
```

This context supports workflows such as:

``` text
Place Probe +
Place Probe -
Open DMM
Measure Voltage
Measure Voltage Drop
Measure Resistance
Continuity
```

The service must not fabricate measurement values.

------------------------------------------------------------------------

## 11. Knowledge Context

Possible fields:

``` text
knowledgeAvailable
relatedKnowledgeCount
sourceAvailable
chainOfCustodyAvailable
```

The actual knowledge system determines these values.

------------------------------------------------------------------------

## 12. AI Context

Possible fields:

``` text
aiAvailable
providerAvailable
contextualAnalysisAvailable
```

The service must not claim that AI reasoning exists when no usable
provider is configured.

------------------------------------------------------------------------

## 13. Permission Context

Potential values:

``` text
canRead
canEdit
canDelete
canSimulate
canPublish
canInstall
```

Permission evaluation should ultimately come from the authoritative
authorization system.

------------------------------------------------------------------------

## 14. Service Context

This identifies which actual services are available to execute
operations.

Examples:

``` text
foundation
engineeringEngine
simulation
measurement
knowledge
acquisition
exchange
ai
repository
```

A command requiring an unavailable service must not be executable.

------------------------------------------------------------------------

## 15. Capability Resolution

Capabilities should be computed from real context and service state.

Example:

``` text
Selected Wire
+
Diagnostic Simulation Active
+
DMM Available
+
Measurement Service Available
```

produces:

``` text
VoltageMeasurement
VoltageDropMeasurement
ResistanceMeasurement
ContinuityMeasurement
DmmProbePlacement
```

The resolver should not infer capabilities from object names alone.

------------------------------------------------------------------------

## 16. Capability Provenance

Where practical, capabilities should be traceable to their source.

Example:

``` text
VoltageMeasurement
Source:
Engineering Engine / Measurement Service

Available:
true
```

This is especially valuable for debugging and future diagnostics of the
command system.

------------------------------------------------------------------------

## 17. Missing Context

Missing information should result in conservative behavior.

Example:

``` text
simulationState = unknown
```

must not be treated as:

``` text
simulationState = active
```

The safe default is:

> If the system cannot establish that a command is valid, do not expose
> it as executable.

------------------------------------------------------------------------

## 18. Contract Principle

> **The interaction context describes what is actually true. It must
> never be a container for UI assumptions or fabricated state.**
