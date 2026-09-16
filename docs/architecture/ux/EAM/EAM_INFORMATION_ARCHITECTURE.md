# EAM Information Architecture

**Status:** Proposed\
**Storage:** `docs/architecture/ux/EAM/EAM-INFORMATION-ARCHITECTURE.md`

## EAM role

Engineering Acquisition Manager is the controlled workflow environment
for acquiring, verifying, extracting, reviewing, and publishing
engineering knowledge. EAM is not primarily a dashboard.

## Top-level navigation

``` text
EAM
├── Home
├── Sources
├── Acquisitions
└── Reference Vault
```

## Active acquisitions

``` text
ACTIVE ACQUISITIONS
├── ● Honda TRX300 Manual
├── ● 1985 GL1200 Wiring
└── ⚠ Ford Ranger PCM
```

Selecting an acquisition opens or focuses its workspace.

## Acquisition workspace

``` text
[ Honda TRX300 Service Manual × ]

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

These are contextual views, not global applications.

## Overview

The Overview must answer: - What is this? - Where did it come from? -
What is its integrity state? - What has happened? - What is happening
now? - What is the next action?

## Sources

Sources are persistent acquisition inputs. Source records should expose
identity, type, reference/location, acquisition state, and applicable
acquisition history.

## Acquisitions

Acquisitions represent actual controlled workflows and chain of custody.
They support creation, monitoring, reopening, historical inspection, and
permitted retry.

## Reference Vault

Reference Vault presents successfully published engineering knowledge
while retaining traceability to acquisition and source.

## Design rule

Do not force users to leave EAM simply because an underlying capability
is implemented as a separate service.
