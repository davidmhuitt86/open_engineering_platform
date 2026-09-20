# Inference Record — durable interpretation audit boundary (WP-INGEST-013)

Builds on `docs/architecture/knowledge/DIAGRAM_INTERPRETATION_REFERENCE_CONTEXT.md`
(WP-EKE-017). Code: `platform/oep_studio/lib/knowledge/inference/`
(`inference_record.dart`, `canonical_json.dart`).

```
Evidence (OCR, EvidenceRegions incl. human annotations, EvidenceLinks, candidates)
   -> DiagramInterpretationReferenceContext   (deterministic, in-memory; has a digest)
   -> InferenceRecord                         (durable audit of ONE interpretation attempt)
   -> Human Review -> Candidate -> explicit Engineering Repository commit
```

**An InferenceRecord is not engineering truth.** It is not an Engineering Object,
node or relationship, not Repository state, not a commit, not a
`KnowledgeCandidate`, not a Reference Library or runtime, and not a
`ReferenceUsage`. Nothing in this work creates or promotes any of those; the
future path Inference -> Knowledge Studio review -> Candidate -> Commit Preview ->
explicit commit is unchanged and downstream. `CommitPlanService`, the
Repository and the Reference Vault are not touched.

## What a record holds

| Group | Fields | Authority |
|---|---|---|
| Identity | `inferenceId` (unique per attempt), `schemaVersion` (1) | new; not a processing identity (a rerun over the same evidence and context is a new record) |
| Source | `sourceMaterialId`, `sourceFingerprint`, `pages` | existing `SourceMaterial.id` and `OcrPageResult.sourceFingerprint`; no new hash |
| Reference context | `contextDigest`, plus the Reference package/runtime identity consumed | digest of the context (below); identity copied from `KnowledgeRuntime.identity`; the context itself is not stored |
| Execution | adapter id, optional provider / model name / model version / prompt version / output schema version; `queuedAt`, `startedAt`, `completedAt`, `status` | vendor-neutral; no API, secret or configuration |
| Outputs | `evidenceUsed`, `hypotheses`, `statements`, `warnings`, `errors` | typed lists; no free-form payload |

`queuedAt` is included because the QUEUED state has a real time before any start.

**Evidence linkage** is by stable identity, not by copy: `evidenceRegion`,
`evidenceLink`, `knowledgeCandidate` (their own ids) and `ocrPage` (source id
+ page). No second spatial or evidence model exists. Observations (OCR facts,
regions, human annotations) stay where they are; the record points at them.

**Hypotheses** (`hypothesisId`, `category`, `proposedValue`, `label`, `status`,
`statusReason`, `evidence`, `referenceObjectIds`, `confidence`, `rationale`):
proposals. `HypothesisStatus` is `proposed | accepted | rejected`;
`accepted` means accepted *as an inference review outcome*, never as
engineering truth. A decision is final and is made only on a finished record
(a change of mind is a new hypothesis or record). **Rejected hypotheses are
retained** with their evidence, reference ids and reason, for later evaluation
and error analysis. Order is the provider's order and is not re-sorted.
`referenceObjectIds` are plain Reference object ids; richer usage records belong
to `ReferenceUsage` (WP-INGEST-014, `REFERENCE_USAGE.md`), a collection on the record
(`referenceUsage`), added without changing this schema version.

**Confidence** is only what a provider supplied (`value`, `basis`, and
`calibrated`, false unless the source establishes calibration). It is never
manufactured for OCR, regions, retrieval scores or human annotations;
`ReferenceDiscovery` scores remain retrieval scores.

## Lifecycle

`QUEUED -> RUNNING -> COMPLETED | PARTIAL | FAILED | CANCELLED` (QUEUED may
also go straight to FAILED or CANCELLED), identical to `IngestionRunStatus`.
Illegal transitions throw. PARTIAL, FAILED and CANCELLED keep whatever outputs
they were given (a provider that fails after 3 of 5 regions yields PARTIAL with
those 3). Cancellation is distinct from failure. The durable store accepts only
legal successors (`requireValidSuccessorOf`), so the RUNNING step must be
persisted before completion, and nothing is silently overwritten.

**Interrupted runs**: as for `IngestionRun`, when a session is loaded and a record
is still QUEUED/RUNNING (no live execution can exist), `KnowledgeSessionStorage.load`
reconciles it once to FAILED with an explicit `interrupted` error and writes it
back. There is no resume behavior.

## Reference Context identity

`DiagramInterpretationReferenceContext.digest` (additive to WP-EKE-017) is the
SHA-256 of the structured canonical JSON of the context (`canonicalJson`: sorted
map keys, list order preserved, `jsonEncode` scalars, the same convention as
`IngestionRun.processingIdentity`; no delimiters). The same evidence, queries,
package/runtime and binding registry give the same digest; any change changes it.
The record stores the digest and the Reference package/runtime identity, so it is
possible to say which Reference Knowledge was available without persisting the
context.

## Persistence

In the existing `KnowledgeSessionRecord` (`inferenceRecords`, one `session.json`);
no new database or store. Several records per session are supported, including
several runs over the same context. A session without the key loads with an empty
list; unknown extra keys are ignored; malformed data or an unsupported
`schemaVersion` fails explicitly (`FormatException`, surfaced by the existing
loader as a corrupted-session error). The `FoundationRuntimeNotifier` gained
`addInferenceRecord` / `updateInferenceRecord` (store and replace only; no delete)
and carries the list through create/close/open/load/archive/autosave, and session
duplication carries it over like other session history.

## Discovered issue (pre-existing; fixed by INGEST-FOLLOWUP-007)

The notifier's autosave rebuilds the `KnowledgeSessionRecord` from its state, and
that state has never held `ingestionRuns`, `derivedArtifacts` or
`normalizedProducts`. Those fields are therefore dropped from `session.json` the
first time an active session autosaves (the real TRX300 session shows
`ingestionRuns: []` although its description names a UIF run). This contradicts
the durability intent of AP-INGEST-006/007. Inference records were plumbed through
the state so they do not suffer the same loss. INGEST-FOLLOWUP-007 then carried
the ingestion fields through the same paths (see
`platform/oep_studio/docs/KNOWLEDGE_SESSION_FORMAT.md`, "Durable ingestion state
through autosave").

## Related existing model

`AiSuggestion` (text/entity-based candidate suggestions from the AI analysis flow,
status `pending/accepted/edited/rejected/deferred`, with a path to
`createdCandidateId`) is a separate, older concept and is untouched. The two
overlap conceptually (both hold model-proposed interpretations); unifying or
retiring one is a future decision. `InferenceRecord` has no candidate-creation
path.

## Not implemented

the constrained interpretation adapter
(AP-EKE-018), any LLM/vision provider, review UI, automatic candidate or object
creation, training/evaluation export, and validation of hypothesis evidence ids
against session contents.
