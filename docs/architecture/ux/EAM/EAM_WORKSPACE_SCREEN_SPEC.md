# EAM Workspace Screen Specification

**Status:** Proposed design authority  
**Storage:** `docs/architecture/ux/EAM/EAM-WORKSPACE-SCREEN-SPEC.md`  
**Parent:** `docs/architecture/ux/OEP-UX-ARCHITECTURE.md`

## 1. Purpose

Define the major EAM screens and the information hierarchy each screen must provide.

This specification bridges the EAM information architecture and visual render set. It describes intended user-facing surfaces, not implementation classes or backend APIs.

## 2. Common EAM Shell

Every EAM screen uses the OEP shell:

```text
┌───────────────────────────────────────────────────────────────┐
│ OEP   Home   Diagram Studio   EAM   Knowledge   Exchange ... │
├───────────────────────────────────────────────────────────────┤
│ [ Current Acquisition × ] [ Other Work × ] [ + ]              │
├────────────────┬──────────────────────────────────────────────┤
│ EAM CONTEXT    │                                              │
│                │                 WORK SURFACE                 │
│ Home           │                                              │
│ Sources        │                                              │
│ Acquisitions   │                                              │
│ Vault          │                                              │
│                │                                              │
│ ACTIVE WORK    │                                              │
│ ● TRX300       │                                              │
│ ● GL1200       │                                              │
│ ⚠ Ranger PCM   │                                              │
└────────────────┴──────────────────────────────────────────────┘
```

The shell remains visually consistent while the center surface changes.

---

# 3. EAM Home

## Purpose

Provide an operational overview of EAM without forcing the user to manage work from a dashboard.

## Primary regions

### Continue Work

Highest-priority region.

Shows active acquisition(s) with:
- title
- source
- current workflow stage
- attention state
- dominant next action

Example:

```text
CONTINUE WORK

Honda TRX300 Service Manual
Engineering Acquisition
● Extract

47 candidate objects
83 candidate relationships

[ Continue → ]
```

### Active Acquisitions

Compact list of work requiring attention.

### Recent Acquisitions

Recently completed or accessed acquisitions.

### Source Status

Concise source information, not an administrative control panel.

### Reference Vault Summary

Useful publication counts/status without becoming a separate dashboard application.

---

# 4. Sources

## Purpose

Browse and manage registered acquisition sources.

## Layout

```text
SOURCES

[ Search sources... ]                         [ + New Source ]

Official Sources
─────────────────────────────────────────────────────────────

Honda Motor Co.                         Official
Ford Motor Company                      Official
Service Information Archive             Verified

Source details
─────────────────────────────────────────────────────────────

Identity
Authority
Reference
Acquisition history
Verification status
```

## Rules

Sources are persistent EAM resources and therefore deserve a direct destination.

Selecting a source should allow the user to inspect its acquisition history and start a new acquisition.

---

# 5. Acquisition List

## Purpose

Provide a persistent view of acquisition work.

## Layout

```text
ACQUISITIONS

[ Search... ] [ Status ▾ ] [ Source ▾ ]

ACTIVE
─────────────────────────────────────────────────────────────

● Honda TRX300 Service Manual       Extract
● 1985 GL1200 Wiring                Review
⚠ Ford Ranger PCM                   Verify

COMPLETED
─────────────────────────────────────────────────────────────

✓ Jaguar XF Service Information
✓ Dodge Ram 4.7L Manual
```

## Row information

Each acquisition should expose:
- identity
- source
- current stage
- state
- last activity
- attention indicator

Selecting a row opens/focuses its workspace.

---

# 6. Acquisition Overview

## Purpose

Primary landing surface for an individual acquisition.

## Header

```text
Honda TRX300 Service Manual
Engineering Acquisition
Source: Honda Official Documentation
```

## Workflow rail

```text
✓ Source → ✓ Download → ✓ Verify → ● Extract → ○ Review → ○ Publish
```

## Main content

Recommended arrangement:

```text
┌───────────────────────┬─────────────────────────────────────┐
│ CURRENT STEP          │ DOCUMENT                            │
│                       │                                     │
│ Extract               │ TRX300 Service Manual               │
│                       │                                     │
│ [ Continue → ]        │ [ document preview ]                │
├───────────────────────┼─────────────────────────────────────┤
│ ACQUISITION INFO      │ DETECTED CONTENT                    │
│                       │                                     │
│ Source                │ Wiring Diagrams       4             │
│ Artifact              │ Components           47             │
│ Integrity             │ Relationships        83             │
│ Acquired              │ Specifications       21             │
└───────────────────────┴─────────────────────────────────────┘
```

---

# 7. Document View

## Purpose

Inspect the acquired source artifact while preserving acquisition context.

## Required elements

- document preview
- page navigation
- zoom
- page number
- source identity
- acquisition identity
- evidence/reference indicators

## Context

The document viewer should not feel like a separate application.

The acquisition remains visible in the shell and workflow rail.

---

# 8. Verification View

## Purpose

Present artifact integrity and acquisition verification.

## Layout

```text
VERIFY

Artifact
TRX300_Service_Manual.pdf

Integrity
──────────────────────────────

SHA-256
9A72...F83C

✓ Download complete
✓ Hash calculated
✓ Integrity verified

Chain of Custody
──────────────────────────────

Source
Honda Official Documentation

Acquired
Sep 14, 2026 18:42

[ Continue to Extraction → ]
```

Failure state:

```text
⚠ VERIFICATION FAILED

SHA-256 mismatch

[ Inspect Artifact ] [ Retry Verification ]
```

---

# 9. Extraction View

## Purpose

Show the transition from source material to candidate engineering knowledge.

## Layout

```text
EXTRACT ENGINEERING KNOWLEDGE

Processing
────────────────────────────────────────

██████████████████░░░░  82%

Detected Content
────────────────────────────────────────

Wiring Diagrams             4
Components                 47
Relationships              83
Specifications             21
Procedures                 16
```

The interface should clearly communicate that these are detected/candidate results, not yet engineer-approved knowledge.

---

# 10. Review Workspace

## Purpose

Provide engineering control over machine-derived knowledge.

## Layout

```text
KNOWLEDGE REVIEW

┌─────────────────────┬──────────────────────────────────────┐
│ CANDIDATES          │ SELECTED CANDIDATE                   │
│                     │                                      │
│ Ignition Coil       │ Ignition Coil                        │
│ Spark Plug          │                                      │
│ Starter Relay       │ Type                                 │
│ Main Fuse            │ Electrical Component                │
│                     │                                      │
│ ⚠ 2 warnings        │ Source                               │
│                     │ TRX300 Manual — Page 43              │
│                     │                                      │
│                     │ Confidence                            │
│                     │ 94%                                  │
│                     │                                      │
│                     │ [ Reject ] [ Modify ] [ Accept ]     │
└─────────────────────┴──────────────────────────────────────┘
```

## Principle

The UI must distinguish:
- machine-detected
- engineer-reviewed
- engineer-approved
- rejected

---

# 11. Objects View

## Purpose

Inspect candidate or approved Engineering Objects associated with the acquisition.

## Layout

```text
OBJECTS (47)

[ Search objects... ] [ Type ▾ ] [ Status ▾ ]

Ignition Coil          Electrical Component     Reviewed
Spark Plug             Electrical Component     Reviewed
Starter Relay          Electrical Component     Candidate
Main Fuse              Electrical Component     Candidate
```

Selecting an object opens contextual detail without leaving the acquisition.

---

# 12. Object Detail

## Purpose

Inspect one Engineering Object while retaining acquisition context.

## Layout

```text
IGNITION COIL

Electrical Component

Properties
────────────────────────────
Manufacturer
Honda

Source
TRX300 Manual — Page 43

Relationships
────────────────────────────
→ Spark Plug
→ Ignition System

Validation
────────────────────────────
✓ Type valid
✓ Source evidence present

Evidence
────────────────────────────
TRX300 Manual — Page 43

[ Open in Document ] [ Open in Diagram ]
```

The object is contextual. It is not a separate global Studio.

---

# 13. Relationships View

## Purpose

Inspect relationships extracted or created within the current acquisition.

## Layout

```text
RELATIONSHIPS (83)

Ignition Coil  →  Spark Plug
Starter Relay  →  Starter Motor
Main Fuse      →  Fuse Box
```

Selecting a relationship opens contextual detail.

---

# 14. Relationship Detail

## Required information

```text
RELATIONSHIP

Source
Ignition Coil

Relationship
CONNECTS_TO

Target
Spark Plug

Evidence
TRX300 Manual — Page 43

Validation
✓ Endpoint objects valid
✓ Source evidence present

[ Open Source Object ]
[ Open Target Object ]
[ Open Evidence ]
```

---

# 15. Graph View

## Purpose

Provide contextual graph visualization.

The graph should open centered on the selected engineering object when launched from an object or relationship.

Example:

```text
             Spark Plug
                 ↑
                 │
           Ignition Coil
                 │
                 ↓
          Ignition System
```

The user should be able to select graph entities and return to their contextual detail.

Graph is not a global destination.

---

# 16. Validation View

## Purpose

Present validation results for the current acquisition or selected engineering context.

## Layout

```text
VALIDATION

✓ 126 checks passed
⚠   2 warnings
✕   1 error

ERROR
────────────────────────────────────────

Wire W-047 references nonexistent terminal.

[ Locate in Context ]

WARNING
────────────────────────────────────────

Ignition Coil confidence below review threshold.

[ Inspect Candidate ]
```

Validation results must identify affected entities and provide direct contextual actions.

---

# 17. Evidence View

## Purpose

Make source support and chain of custody inspectable.

## Layout

```text
EVIDENCE

Ignition Coil
────────────────────────────────────────

Source Document
TRX300 Service Manual

Page
43

Region
Electrical System

Acquisition
Honda TRX300 Service Manual

Integrity
✓ Verified

[ Open Document ]
```

Evidence should remain directly connected to the engineering information it supports.

---

# 18. History View

## Purpose

Expose acquisition history without replacing authoritative records.

Useful information:
- workflow transitions
- verification events
- extraction events
- review decisions
- publication event
- timestamps
- relevant actors/system stages

History is contextual to the acquisition.

---

# 19. Reference Vault View

## Purpose

Show successfully published engineering knowledge.

## Layout

```text
REFERENCE VAULT

[ Search... ] [ Type ▾ ]

Published Knowledge

Honda TRX300
1988
47 Objects
83 Relationships
126 Evidence Records

Status
✓ Verified
✓ Reviewed
✓ Published

[ Open Knowledge ]
```

Publication should preserve traceability to acquisition and source evidence.

---

# 20. Cross-Context Actions

Common contextual actions may include:

```text
Open in Document
Open in Diagram Studio
Inspect Object
Inspect Relationship
Show Graph
Validate
Show Evidence
Show History
```

Actions should carry the current identity/context forward.

---

# 21. Screen Consistency Rules

Every EAM work screen should preserve:

1. OEP Studio identity
2. current workspace identity
3. acquisition workflow state
4. contextual selection
5. attention/error state
6. appropriate next action

A screen that removes several of these elements should have a specific UX justification.

# 22. Render Priority

The next visual render set should prioritize these screens in order:

1. OEP Shell
2. EAM Home
3. Acquisition Overview
4. Verification
5. Extraction
6. Review
7. Object Detail
8. Relationship Detail
9. Validation
10. Reference Vault

These screens establish the complete primary workflow before lower-frequency screens are rendered.
