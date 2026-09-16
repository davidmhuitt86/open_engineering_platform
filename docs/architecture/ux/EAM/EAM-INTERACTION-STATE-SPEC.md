# EAM Interaction and State Specification

**Status:** **CANONICAL** — the authoritative EAM interaction/state specification (AP-UX-002 C4).
**Parent:** `docs/architecture/ux/OEP-UX-ARCHITECTURE.md`
**Reconciled by:** AP-UX-002 — `EAM_INTERACTION_STATE_SPEC.md` (same title, underscored filename) covers the same workflow (`SOURCE→DOWNLOAD→VERIFY→EXTRACT→REVIEW→PUBLISH`) and the same workspace-state/workflow-state separation rule, independently written. No substantive disagreement was found between the two; this document is retained as canonical because it is the longer, more detailed treatment and was already the README-listed authority. The other document is retained for historical/migration reference, subordinate to this one.

## 1. Purpose

Define how EAM behaves as a persistent workflow workspace rather than a collection of dashboard pages.

## 2. Primary State Model

An acquisition has both a workflow state and a workspace state.

Workflow state:

```text
SOURCE → DOWNLOAD → VERIFY → EXTRACT → REVIEW → PUBLISH → COMPLETE
```

`FAILED` and attention states may occur where applicable.

Workspace state includes open/closed state, active workspace tab, active contextual view, selected engineering entity, unsaved review changes where applicable, and attention/error state.

Workflow state must not be inferred solely from the selected UI tab.

## 3. Opening an Acquisition

When a user selects an acquisition:

1. Open or focus its workspace.
2. Show it in the workspace tab bar.
3. Mark it active in the contextual tree.
4. Show its authoritative workflow state.
5. Open the most useful view for that state.
6. Present one dominant next action.

## 4. Stage Transition

Successful stage completion marks the stage complete, activates the next applicable stage, persists the state, keeps the workspace open, and updates the next action. Required review stages must not be silently bypassed.

## 5. Workspace Tabs

Workspace tabs represent open work objects, not navigation destinations.

Example:

```text
[ TRX300 Manual × ] [ GL1200 Manual × ] [ Ranger PCM × ] [ + ]
```

Closing a tab closes presentation context only; it does not delete the acquisition. Persisted state remains available. Unsaved changes require an appropriate confirmation.

## 6. Contextual Views

An acquisition may expose:

```text
Overview
Document View
Metadata
Detected Content
Objects
Relationships
Validation
Evidence
History
```

Every view preserves acquisition identity in the surrounding shell.

## 7. Object and Relationship Context

Selecting an object or relationship changes contextual focus without leaving the acquisition. Related Objects, Relationships, Graph, Validation, and Evidence capabilities become available at the contextual level.

## 8. Validation

Validation is contextual and should expose severity, affected entity, rule/check, explanation, source context where applicable, and direct actions such as Locate, Inspect, or Resolve.

## 9. Evidence

Evidence remains attached to the engineering information it supports. Source document, page/region, acquisition identity, provenance, and integrity information should be reachable without losing context.

## 10. Error and Attention States

Errors belong to their owning workflow stage.

Example:

```text
VERIFY ⚠
SHA-256 mismatch

[Inspect Artifact] [Retry Verification]
```

Warnings should appear in the workflow rail, acquisition tree, relevant contextual view, and Overview when useful, without redundant modal interruption.

## 11. Completion

On successful publication:

```text
Source ✓ → Download ✓ → Verify ✓ → Extract ✓ → Review ✓ → Publish ✓
```

The acquisition remains historically accessible while resulting engineering knowledge becomes available through Reference Vault workflows.

## 12. Home Return

Returning Home does not close an acquisition. Continue Working should surface active/recent acquisitions.

## 13. Repository Access

Repository browsing may remain independently accessible because repositories are persistent resources. Opening repository content from EAM should preserve acquisition/source context where applicable.

## 14. Interaction Priority

At any moment the UI prioritizes:

1. current work identity
2. workflow state
3. contextual selection
4. blocking/attention conditions
5. next meaningful action
6. secondary navigation

## 15. State Integrity

Persisted acquisition state is authoritative. Presentation state is a projection and must never become the source of truth for engineering workflow state.

## 16. Design Test

Any EAM screen should let a user answer within seconds:

- What am I working on?
- Where did it come from?
- What stage am I in?
- Is anything wrong?
- What do I do next?
