# Engineering Acquisition Wizard

The primary way engineers bring knowledge into OEP. Opened from the
**Acquire Engineering Knowledge** button at the top of Engineering
Acquisition Studio.

## Why it exists

Before the Wizard, acquiring a document meant understanding OEP's own
internal architecture: register an Official Source, create an Acquisition
Job, advance that job's state machine by hand, start a Download, request
a Verification, request Metadata Extraction, then publish to the Vault --
seven distinct concepts and at least eight button presses, in an order
nothing on screen explained.

The Wizard replaces that with one guided flow that *teaches while it
works*: what is happening, why OEP asks for each piece of information,
how Engineering Chain of Custody works, and what happens next. The
backend concepts still exist and are unchanged -- they are now
implementation details rather than the user's workflow.

## Flow

| Step | Screen | What it does |
| --- | --- | --- |
| 1 | Knowledge Type | Classifies the material (Standard, Datasheet, Wiring Diagram, ...) so it can later be interpreted correctly. |
| 2 | Official Source | Pick an existing trusted publisher, search them, or register a new one inline -- immediately selectable on Save. |
| 3 | Chain of Custody | Collects Original URL, Publisher, Publication Date, Revision, License, Language, Acquisition Method, Engineer -- each with an explanation of *why* OEP needs it. |
| 4 | Acquisition Scope | Entire Document / Pages / Chapters / Sections. The complete artifact is **always** stored in the Vault regardless; scope describes what should later be *extracted*. |
| 5+6 | Acquire & Live Progress | One press. Runs the entire backend chain automatically and streams a live log of every stage. |
| 7 | Candidate Preview | Candidate Engineering Objects, grouped by category. |
| 8 | Engineering Review | Accept / Reject / Merge / Link Existing / Edit Metadata / Notes. |
| 9 | Publish | Destination package plus a summary of what was accomplished. |

## What the Wizard automates

One press of **Acquire Engineering Knowledge** (Step 5) drives this
entire real chain, stopping immediately with a real error message if any
stage fails:

```
POST /jobs                 create the Acquisition Job
POST /jobs/{id}/execute    created -> queued
POST /jobs/{id}/execute    queued  -> running
POST /downloads            real HTTP/HTTPS retrieval via the `http-source` connector
POST /verifications        real SHA-256 integrity verification
POST /metadata             file-type detection + document inspection
POST /vault                publish into the permanent, content-addressable Vault
POST /jobs/{id}/execute    running -> completed
```

Every one of those is an existing, already-tested `oep_acquisition`
endpoint. **No backend architecture was changed for the Wizard.** The
only Studio-side addition is a set of value-returning wrappers on
`AcquisitionRuntimeNotifier` (`createJobReturning`, `verifyReturning`,
...) that return the response body so each stage's id can be threaded
into the next, instead of round-tripping through a list refresh. The
original `void` methods are untouched and still back the classic panels.

## Honestly disclosed gaps

These are visible in the UI itself, not hidden in code comments:

- **Steps 7 and 8 do not work yet.** Generating Candidate Engineering
  Objects from an acquired artifact requires the Engineering Knowledge
  Engine, which is Milestone 2 of `oep_acquisition` and is not built. The
  screens show their real structure with every category honestly empty
  and a banner explaining why, rather than fabricating example objects.
- **Step 9's destination package selector is informational.** The
  Reference Vault is a single flat content-addressable store; it has no
  package/collection concept at the backend. The artifact is stored in
  the shared Vault regardless of the selection, and the UI says so.
- **Step 4's scope is recorded, not enforced.** The backend always
  acquires the complete artifact -- there is no partial-retrieval
  capability at the connector layer. The selection is preserved in the
  Chain of Custody record so intent survives until the Knowledge Engine
  can act on it.
- **Chain of Custody is stored locally.** `oep_acquisition` has no schema
  fields for publisher/license/revision/etc. Since this work explicitly
  must not modify the backend, records are persisted to
  `%APPDATA%/oep_studio/chain_of_custody.json`, keyed by Vault Entry id.
  Migrating this to real server-side columns is the natural next backend
  work package.
- **The connector is not selectable.** `oep_acquisition` ships
  `example-stub` (fabricates a placeholder file) and `http-source` (real
  HTTP/HTTPS). The Wizard always uses `http-source`, since asking the
  engineer to choose would contradict the whole point of the Wizard.

## Files

```
lib/acquisition/wizard/
  acquisition_wizard_page.dart          Shell: header, step rail, footer
  acquisition_wizard_controller.dart    Orchestration + live log + step gating
  chain_of_custody_record.dart          The provenance record model
  chain_of_custody_storage.dart         Local JSON persistence, keyed by Vault Entry id
  steps/
    wizard_step_knowledge_type.dart
    wizard_step_official_source.dart
    wizard_step_chain_of_custody.dart
    wizard_step_scope.dart
    wizard_step_acquire.dart            Steps 5 + 6 (same operation, before/during)
    wizard_step_candidate_preview.dart
    wizard_step_review.dart
    wizard_step_publish.dart
```

## Tests

`test/acquisition/acquisition_wizard_controller_test.dart` covers the
orchestration logic the Wizard itself owns, against a faked
`AcquisitionRuntimeNotifier` (no network, no running backend, no writes
to the real settings directory):

- the full chain runs in the correct order from a single press
- a failed download stops the chain -- verify/metadata/publish are never attempted
- a failed verification stops before metadata and publish
- every stage appears in the live log (no silent operations)
- step gating blocks advancing past a step with missing required input
- `run()` is not re-entrant -- a second press while running is ignored
- an API exception surfaces its curated message, not a raw error
