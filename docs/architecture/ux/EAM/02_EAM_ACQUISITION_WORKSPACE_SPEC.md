# EAM Acquisition Workspace Design Specification

> **Status: RETAINED FOR HISTORICAL / MIGRATION REFERENCE (AP-UX-002 C4).**
> Canonical specification: [`EAM-ACQUISITION-WORKSPACE-SPEC.md`](EAM-ACQUISITION-WORKSPACE-SPEC.md). This document covers the same workflow/workspace model independently; no substantive disagreement was found, but it is not the authoritative version. Consult it for historical context or if the canonical document appears to be missing detail this one has.

## Purpose
Define the user-facing workflow for acquiring external engineering knowledge and converting it into trusted OEP engineering knowledge.

EAM is a workflow workspace, not primarily a dashboard.

## Canonical Workflow

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

The workflow indicator remains visible while the acquisition workspace is open.

## Acquisition as a First-Class Work Object
An acquisition is an open workspace:

    [ Honda TRX300 Service Manual x ]

The workspace remains available while moving between:
- Overview
- Document View
- Metadata
- Detected Content
- Objects
- Relationships
- Validation
- Evidence
- History

## Header
The acquisition header establishes identity immediately:

    Honda TRX300 Service Manual
    Engineering Acquisition | Source: Honda (Official) | Type: Service Manual

It should also show acquisition state, timestamps, and contextual Actions.

## Workflow Indicator
Use a horizontal state rail:

    ✓ Source -> ✓ Download -> ✓ Verify -> ● Extract -> ○ Review -> ○ Publish

States:
- completed
- active
- pending
- attention required
- failed

Completed stages may be selected to inspect results without silently changing the acquisition state.

## Overview
Overview answers:
- What was acquired?
- Where did it come from?
- Is it trustworthy?
- What has happened?
- What is happening now?
- What happens next?

Recommended areas:
- Current Step
- Quick Info
- Document Preview
- Detected Content
- Sample Extractions
- Next Action

## Document View
Document View is contextual, not a separate application.

Support:
- page navigation
- zoom
- source references
- page/section context
- extraction overlays where appropriate

## Metadata
Metadata extraction presents machine-detected candidates as reviewable engineering information.

Typical fields:
- Manufacturer
- Model
- Model Year
- Document Type
- Language
- Pages
- Source
- Acquisition timestamp
- SHA-256

Machine-derived information must remain distinguishable from engineer-approved information.

## Detected Content
Show extraction classes such as:
- Wiring Diagrams
- Component Information
- Specifications
- Procedures
- Torque Specifications
- Maintenance Information

Counts link into contextual review.

## Objects and Relationships
Objects and Relationships are contextual views of the current acquisition.

Example:

    Objects (47)
    Relationships (83)

Selecting an object opens contextual review.

## Validation
Validation belongs beside the artifact/content being validated.

Example:

    ✓ Component type is valid
    ✓ Required properties present
    ⚠ Confidence below auto-accept threshold
    ✓ Source page reference valid

Validation should provide a direct action to locate affected content.

## Evidence
Evidence maintains the chain between extracted/engineered content and source material.

Expose:
- source document
- page
- region/section where available
- extraction provenance
- acquisition identity
- integrity state

## Next Action
Every active acquisition should expose one dominant next action:

    Continue to Metadata Review →
    Continue to Engineering Review →
    Publish to Reference Vault →

The user should never need to determine the next step from unrelated dashboard panels.

## Completion
A completed acquisition transitions naturally into Reference Vault status while retaining acquisition history and chain-of-custody information.
