# EAM Post-Acquisition UX Flow

**Status:** Proposed
**Storage:** `docs/architecture/ux/EAM/EAM-POST-ACQUISITION-UX-FLOW.md`

## 1. Purpose

Define the user experience immediately after a source has been downloaded and explain how EAM should transition from acquisition status to active engineering work.

## 2. Current Problem

The legacy dashboard can return the user to broad panels such as Sources, Acquisition Jobs, and Reference Vault after acquisition activity.

That presentation does not clearly communicate:
- what was just acquired
- whether the download succeeded
- what stage is active
- whether verification succeeded
- what the user should do next

## 3. Required Transition

After a successful download:

```text
Download complete
      ↓
Automatically focus acquisition workspace
      ↓
Show artifact identity
      ↓
Show verification state
      ↓
Activate next required stage
      ↓
Present dominant next action
```

## 4. Example

```text
Honda TRX300 Service Manual

✓ Source
✓ Download
● Verify
○ Extract
○ Review
○ Publish

SHA-256
9A72...F83C

Artifact
TRX300_Service_Manual.pdf

[ Continue to Verification → ]
```

## 5. Successful Verification

```text
✓ Source
✓ Download
✓ Verify
● Extract
○ Review
○ Publish
```

The primary action becomes:

```text
Continue to Extraction →
```

The verification result remains inspectable.

## 6. Failed Verification

```text
✓ Source
✓ Download
⚠ Verify
○ Extract
○ Review
○ Publish

SHA-256 mismatch

[Inspect Artifact]
[Retry Verification]
```

The user remains in the acquisition workspace.

## 7. Extraction

The extraction workspace should progressively reveal engineering content:

```text
Detected Content

Wiring Diagrams          4
Components              47
Relationships           83
Specifications          21
Procedures              16
```

These counts are contextual entry points into review, not global destinations.

## 8. Review

The review workspace changes from machine-processing presentation to engineering-control presentation.

Example:

```text
KNOWLEDGE REVIEW

Ignition Coil

Candidate Type
Electrical Component

Source
TRX300 Service Manual — Page 43

Confidence
94%

[ Accept ] [ Modify ] [ Reject ]
```

## 9. Publication

Before publishing:

```text
READY FOR REFERENCE VAULT

Objects              47
Relationships         83
Evidence             126
Validation            ✓
Provenance             ✓
Integrity              ✓

[ Publish to Reference Vault ]
```

## 10. Completion

After publication:

```text
✓ Source
✓ Download
✓ Verify
✓ Extract
✓ Review
✓ Publish

COMPLETE

Published to Reference Vault
```

The acquisition remains available for historical inspection.

## 11. UX Principle

The user should experience the acquisition as one continuous piece of work.

The UI should not make the user repeatedly rediscover the acquisition through unrelated dashboard pages.
