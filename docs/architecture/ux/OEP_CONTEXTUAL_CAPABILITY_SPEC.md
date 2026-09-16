# OEP Contextual Capability Specification

**Status:** Proposed
**Storage:** `docs/architecture/ux/OEP_CONTEXTUAL_CAPABILITY_SPEC.md` (corrected AP-UX-002 C6 — this line previously named a hyphenated path that does not exist on disk)

## 1. Purpose

Define how platform capabilities become available through the current engineering context.

## 2. Core Rule

A capability should appear where its meaning is obvious.

```text
Global destination
    ↓
Studio
    ↓
Workspace
    ↓
Selected engineering context
    ↓
Relevant capabilities
```

## 3. Objects

Objects should normally be viewed in the context of:
- a diagram
- an acquisition
- a knowledge model
- a repository
- another engineering artifact

Object inspection should preserve the originating context.

## 4. Relationships

Relationships should normally be exposed from:
- selected objects
- engineering graphs
- diagrams
- contextual relationship views

The user should not have to navigate to a global Relationships application merely to inspect a connection.

## 5. Graph

Graph is a contextual visualization.

It should open:
- centered on the selected entity
- with relevant neighboring entities
- with filters appropriate to the current context

The graph should provide a clear route back to the originating work.

## 6. Validation

Validation belongs to the artifact or engineering context being validated.

Example:

```text
TRX300 Wiring Diagram
    ↓
Validation
    ↓
2 warnings
1 error
    ↓
Locate
    ↓
Wire W-047 selected
```

## 7. Evidence

Evidence connects engineering information to supporting source material.

It should be accessible directly from:
- objects
- relationships
- metadata
- extracted content
- validation findings

## 8. Provenance

Provenance should be contextual and traceable.

Example:

```text
Engineering Object
    ↓
Derived From
    ↓
Extracted Content
    ↓
Source Document
    ↓
Acquisition
```

## 9. History

History should describe the selected context rather than becoming an unrelated global page.

Possible levels:
- acquisition history
- object revision history
- relationship history
- publication history

## 10. Packages

Packages should appear where package creation, validation, installation, or publication is meaningful.

The user should think:

```text
Package this knowledge model
```

rather than:

```text
Go to Packages
```

## 11. Contextual Capability Surface

A contextual toolbar or tab set may expose:

```text
Objects | Relationships | Graph | Validation | Evidence | History
```

Only capabilities relevant to the current context should be shown.

## 12. Progressive Disclosure

Do not display every possible capability simultaneously.

Primary capabilities should be visible.
Secondary capabilities may be placed in menus.
Rare operations may be available through contextual Actions.

## 13. Consistency

The same capability should behave consistently across Studios while adapting to the current engineering context.

## 14. Acceptance Test

A user should never need to know which backend service owns a capability in order to use it.
