# Engineering Acquisition Wizard

The primary way engineers bring knowledge into OEP. Replaces
"understand our object model, then create a Source, then a Job, then a
Download, then a Verification…" with one button — **Acquire Engineering
Knowledge** — on the Engineering Acquisition Studio page.

The Studio's existing panels (Official Sources, Acquisition Jobs,
Reference Vault, Pipeline) are unchanged and still work exactly as
before; they are now positioned as **operational dashboards** under the
wizard entry point rather than the primary workflow.

## Architecture

**No backend changes.** The wizard is purely a Studio-side UX and
orchestration layer over `oep_acquisition`'s existing, already-tested
REST API. Every call it makes is one the classic panels could already
make:

```
Wizard Step 5 "run()"  ──▶  AcquisitionRuntimeNotifier  ──▶  AcquisitionApiClient  ──▶  oep_acquisition REST
                              (*Returning methods)             (unchanged)                (unchanged)
```

`AcquisitionWizardController.run()` drives the real chain automatically,
threading each response's id into the next request:

```
POST /jobs                          → job id
POST /jobs/{id}/execute  (×2)       → created → queued → running
POST /downloads                     → real HTTP(S) fetch via the `http-source` connector
POST /verifications                 → real SHA-256
POST /metadata                      → file type / document inspection
POST /vault                         → permanent, content-addressable storage
POST /jobs/{id}/execute             → running → completed
```

One press. No step is ever left for the engineer to trigger manually.

### Why `*Returning` methods were added

`AcquisitionRuntimeNotifier`'s original methods return `void` and refresh
list state — right for the panel workflow (act, then re-read the list),
wrong for a chain where step N+1 needs the id step N just returned. The
new `createJobReturning`/`startDownloadReturning`/… wrap the *same*
`AcquisitionApiClient` calls and still refresh state afterward, so the
classic panels stay in sync no matter which caller triggered the action.
No new HTTP surface was introduced.

## Steps

| # | Step | Backed by |
|---|------|-----------|
| 1 | Knowledge Type | Local (recorded in Chain of Custody) |
| 2 | Official Source | **Real** — `GET /sources`, `POST /sources` |
| 3 | Chain of Custody | Local JSON (`chain_of_custody.json`) |
| 4 | Acquisition Scope | Local (recorded; see limitation below) |
| 5–6 | Acquire + Live Progress | **Real** — the full pipeline above |
| 7 | Candidate Preview | *Not yet available* |
| 8 | Engineering Review | *Not yet available* |
| 9 | Publish | **Real** summary; package routing not yet available |

Steps 5 and 6 share one screen (`WizardStepAcquire`) because they are the
before/during states of the same real operation.

## Honestly disclosed limitations

These are surfaced **in the UI itself**, not just here — the wizard never
pretends to have done something it hasn't.

- **Candidate Engineering Objects don't exist yet.** Turning an acquired
  document into equations/materials/symbols/behaviors requires the
  Engineering Knowledge Engine, which is explicitly Milestone 2 of
  `oep_acquisition` and is not built. Steps 7 and 8 show the real shape
  of that workflow with every category honestly empty rather than
  fabricating sample objects. This also means the "Candidate knowledge
  appears in Knowledge Studio after acquisition" integration has nothing
  to hand over yet.
- **Chain of Custody is stored locally**, in
  `%APPDATA%/oep_studio/chain_of_custody.json`, keyed by Vault Entry id.
  `oep_acquisition`'s schema has no publisher/license/revision/language
  fields on either `OfficialSource` or `AcquisitionJob`, and this work
  was explicitly not to modify the backend. Migrating this to real
  server-side provenance columns is the natural next backend work
  package.
- **Acquisition Scope is recorded, not enforced.** The backend always
  acquires the complete artifact; there is no partial-fetch capability at
  the connector layer. The selection is preserved as intent for the
  future Knowledge Engine's extraction step.
- **Publish destination packages are informational.** The Reference Vault
  is a single flat content-addressable store with no package/collection
  concept in its schema.
- **The connector is fixed to `http-source`.** `oep_acquisition` ships
  exactly two (`example-stub`, which fabricates a placeholder file, and
  `http-source`, which does real HTTP/HTTPS). The wizard always uses the
  real one and never asks — asking would be exactly the internal-
  architecture exposure this whole design exists to remove.

## Tests

`test/acquisition/acquisition_wizard_controller_test.dart` — the
orchestration logic the wizard genuinely owns: correct call ordering
from a single press, each failure stage halting the chain before
anything downstream runs, the live log covering every stage, step
gating on required input, re-entrancy protection, and curated (not raw)
error messages. The EAM backend is faked at the
`AcquisitionRuntimeNotifier` seam, so these run with no
`oep_acquisition` process and no network.
