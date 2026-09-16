# OEP UX Architecture

**Status:** Proposed — design authority for new OEP UX work pending formal ratification.
**Scope:** OEP application shell, Studio navigation, workspace navigation, contextual capabilities, and UX information architecture.
**Baseline:** 2026-09 OEP/EAM render series and subsequent navigation review.
**Reconciled by:** AP-UX-002 — §3's accent language and the "Instruments" naming below were confirmed/clarified against `OEP-DESIGN-TOKENS.md` §2A. No change to this document's navigation hierarchy, interaction grammar, or destination/capability rule (AP-UX-002 left all three intact, per its own instruction not to redesign them).

## 1. Purpose

OEP shall present engineering work rather than exposing the internal topology of the platform as a list of destinations.

The UX architecture therefore separates four concepts:

1. **Application / Studio** — a destination the user intentionally enters.
2. **Workspace** — an open piece of engineering work or reference content.
3. **Contextual view** — a view of the current workspace or selected engineering entity.
4. **Capability / operation** — something the user can do to the current context.

## 2. Navigation Hierarchy

```text
OEP
│
├── Global Studio Bar
│     ├── Home
│     ├── Diagram Studio
│     ├── EAM
│     ├── Knowledge Studio
│     ├── Engineering Exchange
│     ├── Engineering Intelligence
│     ├── Instruments
│     └── Settings
│
├── Workspace Bar
│     ├── open artifact / acquisition / project
│     ├── open artifact / acquisition / project
│     └── +
│
└── Contextual Navigation
      ├── views
      ├── inspections
      ├── tools
      └── workflow stages
```

The exact Studio inventory remains subject to the broader OEP application architecture. The hierarchy itself is the UX rule.

## 3. Global Studio Bar

The Studio bar is a native OEP application-navigation surface. It must not visually imitate browser tabs.

Reference visual behavior:

```text
OEP   Home   Diagram Studio   EAM   Knowledge   Exchange   Engineering   Instruments   +
                         ^ active Studio
```

The active Studio has a strong but restrained active state, in that Studio's own identity color (AP-UX-002 C1 — Home/Diagram Studio/EAM/Knowledge Studio/Engineering Exchange/Instruments/Settings each carry a distinct accent used only in the Studio Bar and Workspace Bar; see `design-system/OEP-DESIGN-TOKENS.md` §2A). Inactive Studios remain visible so users can switch contexts without returning to Home.

## 4. Home

Home is the OEP landing surface. A global Dashboard is not a first-class Studio destination.

Home should answer:

- What was I working on?
- What can I open?
- Which Studio should I enter?
- Is anything important requiring attention?

Recommended Home regions:

- Continue Working
- Recent Work
- Available Studios
- concise system status

Home should not expose implementation-level destinations such as Objects, Relationships, Graph, Validation, or Packages.

## 5. Workspace Bar

The Workspace Bar identifies open work inside the active Studio.

Example:

```text
[ Honda TRX300 Manual × ] [ GL1200 Wiring × ] [ + ]
```

Workspace tabs are not browser tabs. They represent active OEP work contexts and should preserve the state appropriate to their Studio.

## 6. Contextual Navigation

The navigation available beneath the Studio/workspace level changes according to the current context.

For an engineering artifact it may expose:

```text
Overview
Document
Objects
Relationships
Graph
Validation
Evidence
History
```

For an EAM acquisition it may expose workflow stages and acquisition-specific views.

## 7. Destination vs Capability Rule

Before adding a global destination, ask:

1. Is this independently meaningful without another work object?
2. Can a user intentionally browse it as a persistent resource?
3. Does it have an independent lifecycle?
4. Would making it contextual make a common task harder?

If the answers are mostly no, the feature should be contextual rather than global.

This rule specifically prevents implementation concepts from becoming navigation destinations merely because they are separate backend subsystems.

## 8. Known Contextual Capabilities

These should normally be contextual:

- Objects
- Relationships
- Graph
- Validation
- Evidence
- Provenance
- History
- Packages

Repository browsing is an exception because a repository is itself a persistent resource users may intentionally browse and search.

## 9. Interaction Model

The common interaction grammar is:

```text
OPEN WORK
   ↓
SELECT / FOCUS
   ↓
INSPECT
   ↓
VIEW RELATED ENGINEERING CONTEXT
   ↓
PERFORM CONTEXTUAL OPERATION
   ↓
VALIDATE / VERIFY
```

The exact interaction surface is Studio-specific. The grammar is the common UX principle.

## 10. Visual Language

The approved visual direction is:

- dark near-black/slate foundation
- one restrained blue interaction accent for controls/actions/focus, plus a closed set of per-Studio identity colors used only in the Studio Bar and Workspace Bar (AP-UX-002 C1; `design-system/OEP-DESIGN-TOKENS.md` §2A)
- subtle borders
- compact professional typography
- high information density without dashboard clutter
- restrained status indicators
- strong active states
- rounded surfaces used selectively
- native-looking OEP Studio tabs rather than browser chrome

## 11. Relationship to Existing Studio Architecture

This document establishes UX information architecture. It does not replace Engine ownership, Foundation semantics, existing command/undo architecture, or Studio implementation boundaries.

Existing Studio interaction documents may remain authoritative for behavioral details that do not conflict with this navigation model. Conflicting navigation assumptions must be reconciled against this architecture before new UI work.

## 12. Source-of-Truth Rule

For new OEP UX work:

**Architecture/specification defines behavior and hierarchy.**

**Design renders define visual reference and spatial intent.**

A render must not silently introduce behavior that is absent from the specification.
