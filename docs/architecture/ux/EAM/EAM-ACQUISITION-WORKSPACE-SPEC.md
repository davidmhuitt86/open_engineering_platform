# EAM Acquisition Workspace UX Specification

**Status:** **CANONICAL** — the authoritative EAM acquisition-workspace specification (AP-UX-002 C4).
**Parent architecture:** `docs/architecture/ux/OEP-UX-ARCHITECTURE.md`
**Baseline:** 2026-09 EAM/OEP design render series.
**Reconciled by:** AP-UX-002 — `02_EAM_ACQUISITION_WORKSPACE_SPEC.md` covers materially the same ground (Canonical Workflow, Overview, Document View, Metadata, Detected Content, Objects/Relationships/Validation, Evidence, Completion) and is retained for historical/migration reference, subordinate to this document. Supplementary EAM detail documents (`EAM_ACQUISITION_WORKFLOW_SPEC.md`, `EAM_INFORMATION_ARCHITECTURE.md`, `EAM_POST_ACQUISITION_UX_FLOW.md`, `EAM_WORKSPACE_SCREEN_SPEC.md`) are additive, not duplicative, and remain in effect alongside this document.

## 1. EAM Is a Workflow Workspace

EAM is not primarily a dashboard. Its primary user task is moving an engineering source through a controlled chain of custody until trusted engineering knowledge is available in the Reference Vault.

## 2. Canonical Workflow

```text
Source
  ↓
Download
  ↓
Verify
  ↓
Extract
  ↓
Review
  ↓
Publish
  ↓
Reference Vault
```

The active workflow stage must remain visible throughout the acquisition workspace.

## 3. Acquisition as a Workspace

An acquisition is a first-class open work object.

Example workspace tab:

```text
[ Honda TRX300 Service Manual × ]
```

The user should be able to switch between multiple acquisitions without losing the current work context.

## 4. EAM Studio Navigation

The EAM Studio should expose only EAM-level destinations:

```text
EAM
├── Home
├── Sources
├── Acquisitions
└── Reference Vault
```

Active acquisitions may appear in a contextual tree:

```text
ACTIVE ACQUISITIONS
├── ● Honda TRX300 Manual
├── ● 1985 GL1200 Wiring
└── ⚠ Ford Ranger PCM
```

## 5. Acquisition Workspace Views

Within an acquisition, contextual views may include:

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

These are not global OEP destinations. They describe or operate on the acquisition currently open.

## 6. Workflow Rail

The workspace header should show:

```text
✓ Source → ✓ Download → ✓ Verify → ● Extract → ○ Review → ○ Publish
```

The active stage is visually dominant. Completed stages remain inspectable. Pending stages remain visually available but subordinate.

## 7. Overview

Overview must answer six questions immediately:

1. What was acquired?
2. Where did it come from?
3. Is it trustworthy?
4. What has happened?
5. What is happening now?
6. What should I do next?

Recommended information regions:
- acquisition identity
- source identity
- artifact/integrity summary
- current workflow stage
- document preview
- detected content summary
- dominant next action

## 8. Next Action

Every active acquisition must expose a dominant next action.

Examples:

```text
Continue to Metadata Review →
Continue to Engineering Review →
Publish to Reference Vault →
```

The user should not have to infer the next step from unrelated dashboard panels.

## 9. Document View

Document View is a contextual acquisition view.

It should support page navigation, zoom, source references, page/section context, and extraction overlays where appropriate.

## 10. Metadata

Machine-detected metadata must be clearly distinguishable from engineer-approved metadata.

Typical fields include:
- Manufacturer
- Model
- Model Year
- Document Type
- Language
- Pages
- Source
- Acquisition timestamp
- SHA-256

## 11. Detected Content

Detected content should be grouped by engineering meaning, for example:

- Wiring Diagrams
- Component Information
- Specifications
- Procedures
- Torque Specifications
- Maintenance Information

Counts should open contextual review rather than navigate to a global subsystem.

## 12. Objects / Relationships / Validation

Objects, Relationships, and Validation are contextual capabilities.

For example:

```text
TRX300 Service Manual

Objects (47)
Relationships (83)
Validation (2 warnings)
```

Selecting one opens the appropriate contextual inspector or work surface.

## 13. Evidence and Chain of Custody

Evidence must preserve the relationship between engineering knowledge and its source material.

The UI should make source document, page/region, acquisition identity, extraction provenance, and integrity state readily inspectable.

## 14. Failure / Attention States

Errors and warnings belong to the stage that owns them.

Example:

```text
Verify ⚠
SHA-256 mismatch
```

rather than an unrelated global error panel.

## 15. Completion

After successful publication, the acquisition remains historically inspectable while its resulting engineering knowledge becomes available through Reference Vault workflows.
