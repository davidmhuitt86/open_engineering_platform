# EAM Acquisition Workflow Specification

**Status:** Proposed\
**Storage:** `docs/architecture/ux/EAM/EAM-ACQUISITION-WORKFLOW-SPEC.md`

## Canonical workflow

``` text
SOURCE → DOWNLOAD → VERIFY → EXTRACT → REVIEW → PUBLISH → REFERENCE VAULT
```

## Workflow rail

``` text
✓ Source → ✓ Download → ✓ Verify → ● Extract → ○ Review → ○ Publish
```

The rail communicates authoritative workflow state and provides
contextual navigation. It is not itself the source of truth.

## Source

Establish what is being acquired and from where. Clearly identify
source, document/artifact, authority, and acquisition intent.

## Download

Show transfer state, progress, elapsed time, retry state, and resulting
artifact identity.

## Verify

Prominently expose verification state, checksum/integrity result,
failure reason, and inspection/retry actions.

## Extract

Show extraction progress, detected content classes, candidate
object/relationship counts, and extraction warnings.

## Review

Review is the engineering-control stage. Machine-derived information
must be distinguishable from engineer-approved information. Review
supports object, relationship, evidence, and validation inspection plus
approval/rejection/correction where supported.

## Publish

Show readiness, unresolved issues, publication result, resulting
knowledge identity, and provenance linkage.

## Failure behavior

Failures remain attached to the owning stage.

``` text
VERIFY ⚠
SHA-256 mismatch

[Inspect Artifact] [Retry Verification]
```

## Next action

Every non-terminal workflow state should provide one dominant next
action: `Continue to Verification →` `Continue to Extraction →`
`Continue to Engineering Review →` `Publish to Reference Vault →`

## Completion

Completed acquisitions remain historically inspectable. Resulting
engineering knowledge becomes available through Reference Vault
workflows without losing acquisition provenance.
