# OEP Contextual Tools and Navigation Specification

## Design Principle
OEP distinguishes between destinations and capabilities.

A destination is somewhere the user intentionally goes.
A capability is something the user uses while already working on something.

## Global Destinations
Appropriate global destinations include:

    Home
    Diagram Studio
    EAM
    Knowledge Studio
    Engineering Exchange
    Engineering
    Instruments
    Settings

The exact Studio list can evolve.

## Contextual Capabilities
The following should generally be contextual:

    Objects
    Relationships
    Graph
    Validation
    Evidence
    Provenance
    History
    Packages

Their visibility and placement depend on the active workspace.

## Repository Exception
Repository browsing is different because a repository is itself a persistent engineering resource.

A Repository Browser may therefore remain directly accessible from the appropriate Studio/application context.

It should support:
- tree navigation
- search
- filters
- artifact/object inspection
- repository metadata

## Diagram Studio Example

    Diagram Studio
      Home
      Projects

      OPEN WORK
        TRX300 Wiring Diagram
        GL1200 Wiring Diagram

      CURRENT
        Diagram
        Objects
        Relationships
        Graph
        Validation
        Properties
        Evidence

## Knowledge Studio Example

    Knowledge Studio
      Home
      Knowledge Projects

      OPEN WORK
        TRX300 Knowledge Model

      CURRENT MODEL
        Objects
        Relationships
        Evidence
        Validation
        Provenance
        Package

## EAM Example

    EAM
      Home
      Sources
      Acquisitions
      Reference Vault

      ACTIVE ACQUISITIONS
        TRX300 Manual
        GL1200 Wiring
        Ranger PCM

Within an acquisition:

    Overview
    Document View
    Metadata
    Detected Content
    Objects
    Relationships
    Validation
    Evidence
    History

## Studio Tab Behavior
Studio tabs should:
- look native to OEP
- not imitate browser tabs
- clearly indicate the active Studio
- support fast switching
- remain visually subordinate to the workspace itself

Workspace tabs should:
- identify the open artifact
- support closing
- support multiple simultaneous work objects
- preserve state when possible

## Information Architecture Test
Before adding a new top-level navigation item, ask:

1. Is this a persistent destination?
2. Can the user intentionally browse it without another work object?
3. Does it have an independent lifecycle?
4. Would removing it from global navigation make a common task harder?

If mostly no, it should probably be contextual.

## Result
The OEP interface should expose the platform's architecture without forcing the user to understand the platform's architecture.

The UI should communicate engineering work, not implementation topology.
