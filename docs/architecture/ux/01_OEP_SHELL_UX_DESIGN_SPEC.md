# OEP Shell UX Design Specification

## Purpose
Define the global navigation and workspace shell for Open Engineering Platform (OEP), using the approved dark engineering-tool visual baseline.

## Core UX Model
OEP separates navigation into four levels:

1. Global application navigation — Studios and major platform destinations.
2. Studio navigation — capabilities and workspaces belonging to the active Studio.
3. Open workspaces — engineering artifacts, acquisitions, projects, or other active work.
4. Contextual views/tools — Objects, Relationships, Graph, Validation, Evidence, History, Packages, and similar capabilities.

The user should not be required to navigate to an implementation concept merely because that concept exists as a distinct subsystem.

## Global Application Bar
Reference arrangement:

    OEP | Home | Diagram Studio | EAM | Knowledge Studio | Exchange | Engineering | Instruments | +

The active Studio receives a strong blue treatment. Inactive Studios remain visible and should look like native OEP Studio selectors rather than browser tabs.

## Home
Home is the OEP landing surface. It replaces a global Dashboard as a permanent destination.

Home should contain:
- Continue Working
- Recent Work
- Available Studios
- concise system/connectivity status when useful

Home should not expose internal implementation pages such as Objects, Relationships, Graph, Validation, or Packages.

## Studio Workspace Bar
When a Studio is active, a second-level workspace bar may show open work objects:

    [ Honda TRX300 Service Manual x ] [ 1985 GL1200 Wiring x ] [ + ]

These are work-object tabs, intentionally distinct from the global Studio navigation.

## Contextual Navigation
The left navigation is controlled by the active Studio and current work context.

EAM example:

    EAM
      Home
      Sources
      Acquisitions
      Reference Vault

      ACTIVE ACQUISITIONS
        ● Honda TRX300 Manual
        ● 1985 GL1200 Wiring
        ⚠ Ford Ranger PCM

      COMPLETED
        Jaguar XF Service Info
        Dodge Ram 4.7L Manual

## Contextual Capability Rule
Capabilities should be exposed at the lowest navigation level where their meaning becomes clear.

Examples:
- Objects -> inside an engineering workspace
- Relationships -> inside an engineering workspace
- Graph -> inside an engineering workspace
- Validation -> inside the current engineering artifact
- Evidence -> alongside extracted/engineered content
- Packages -> in the workflow that creates or consumes the package

Direct repository browsing remains a legitimate destination because repositories are persistent resources that users may intentionally browse and search independently.

## Visual Language
- dark slate/near-black background
- restrained blue primary accent
- thin low-contrast borders
- compact, readable typography
- high information density without clutter
- rounded panels used sparingly
- green/yellow/red status indicators
- strong active-state highlighting
- contextual document/engineering imagery

## Interaction Principles
- Always show where the user is.
- Always show the current work object.
- Always show workflow state where a workflow exists.
- Always expose the next meaningful action.
- Preserve open work while navigating.
- Prefer contextual actions over global tool destinations.
