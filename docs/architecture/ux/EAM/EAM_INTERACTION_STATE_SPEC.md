# EAM Interaction and State Specification

**Status:** Proposed\
**Storage:** `docs/architecture/ux/EAM/EAM-INTERACTION-STATE-SPEC.md`

## State model

An acquisition has workflow state and workspace state.

Workflow:
`SOURCE → DOWNLOAD → VERIFY → EXTRACT → REVIEW → PUBLISH → COMPLETE`,
with FAILED/attention states as applicable.

Workspace: `OPEN/CLOSED`, active tab, active view, selected entity,
unsaved changes, attention state.

Workspace state must never become the source of truth for workflow
state.

## Opening work

When selected: 1. focus or create its workspace tab 2. mark it active in
contextual navigation 3. show authoritative workflow state 4. open the
most useful view 5. show the dominant next action

## Switching views

Selecting a contextual view changes presentation context, not workflow
state.

Example:

``` text
Extract active
  ↓
User selects Objects
  ↓
Objects view opens
  ↓
Acquisition remains in Extract state
```

## Object selection

Selecting an object preserves acquisition identity and workflow state
while making related relationships, graph, validation, and evidence
capabilities available.

## Relationship selection

Expose source object, target object, relationship type, provenance,
evidence, and validation state.

## Validation

Expose severity, affected entity, rule/check, explanation, source
context, and Locate/Inspect/Resolve actions where applicable.

## Evidence

Evidence remains attached to the engineering information it supports and
remains directly reachable from that information.

## Closing work

Closing a workspace tab does not delete the acquisition. Persisted state
remains available. Unsaved changes require an appropriate confirmation.

## Returning Home

Home is navigation, not acquisition termination. Active work remains
available through Continue Working and Recent Work.

## Interaction priority

1.  Current work identity
2.  Workflow state
3.  Current contextual selection
4.  Blocking/attention conditions
5.  Next meaningful action
6.  Secondary navigation

## UX acceptance test

A user should be able to answer within seconds: - What am I working
on? - Where did it come from? - What stage am I in? - Is anything
wrong? - What do I do next?
