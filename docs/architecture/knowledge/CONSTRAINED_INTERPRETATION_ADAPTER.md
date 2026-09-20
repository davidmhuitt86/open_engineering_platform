# Constrained Interpretation Adapter (WP-EKE-018)

Builds on `DIAGRAM_INTERPRETATION_REFERENCE_CONTEXT.md` (WP-EKE-017),
`docs/architecture/ingestion/INFERENCE_RECORD.md` (WP-INGEST-013) and
`docs/architecture/ingestion/REFERENCE_USAGE.md` (WP-INGEST-014). Code:
`platform/oep_studio/lib/knowledge/interpretation/adapter/`.

```
InterpretationProvider
   -> constrained ProviderResult      (UNTRUSTED input)
   -> ConstrainedInterpretationAdapter (validation; builds every authoritative field)
   -> InferenceRecord (+ ReferenceUsage)
   -> Human Review -> Candidate -> explicit Repository commit
```

The adapter lets a future LLM, vision or local model interpret evidence while the
OEP authority model stays intact. **No provider is implemented** (no LLM, vision,
network call, API key, vendor or prompt format); only a deterministic test double
exists, under `test/`.

## Authority

- **Provider output is untrusted input.** Nothing in it is authoritative until the
  adapter validates it.
- **The Reference Context is authoritative reference input**, not background text.
  It reaches the provider only inside the request; the provider is given no
  Reference Library, OERP package, index, `reference.db`, `KnowledgeRuntime` or
  `ReferenceDiscovery`.
- **The adapter validates provider claims and builds the record itself**: source
  identity, context digest, Reference package/runtime identity, usage ids, and each
  usage's reference identity, retrieval provenance and symbol binding come from
  the request, never from the provider. A provider's claims about them are only
  checked.
- **A provider cannot create engineering truth.** The schema has no field for
  Engineering Objects, relationships, repository operations, candidates, commits
  or acceptance, and the adapter has no handle to the Repository, `CommitPlanService`,
  Foundation or the Engineering Graph. Hypotheses stay hypotheses (`proposed`),
  statements stay interpretation, and relationship proposals are only hypotheses.
- **Retrieval is not usage.** A `ReferenceUsage` exists only when the provider
  declares that a supplied context item was used; the adapter constructs it.
- Repository mutation is outside the adapter boundary; deterministic Engine
  reasoning remains authoritative downstream (the adapter calculates, solves,
  converts and validates nothing, and does not compute, normalize or rank
  confidence).

## Contract

`InterpretationRequest`: `objective` (the existing WP-EKE-017 purpose vocabulary,
reused as `InterpretationObjective`; no new objective), the
`DiagramInterpretationReferenceContext` (which holds the scoped evidence: source,
OCR, regions, links, candidates, plus Reference items, relationships and binding
views), optional `selectedEvidenceRegionIds` (narrows what is interpretable),
`instructionVersion` (provenance only) and `outputSchemaVersion`. Evidence is
required; a request with no source is rejected. Nothing outside the context is
exposed.

`InterpretationProvider`: `identity` (its own `InferenceAdapterProvenance`),
`supportedObjectives`, and `interpret(request, {isCancelled})`. It knows nothing of
the Foundation bridge, Repository, `CommitPlanService`, graph mutation or
persistence. Relation to the older `AiProvider` (WP-016/SDD-022): that is an untyped
text `complete(AiRequest) -> rawText` interface feeding `AiSuggestion` (which has
a candidate-creation path), so it was not reused. A future model provider can
implement `InterpretationProvider` by wrapping an `AiProvider`, parsing its text
with `ProviderResult.fromJson`, and letting the adapter validate the result.

`ProviderResult` (schemaVersion 1): typed hypotheses, statements, reference-usage
declarations, warnings, errors, an outcome (`completed` | `partial` |
`cancelled`), optional claimed context digest and package identity, and
`referenceContextInsufficient` (what it wanted but was not given; the adapter
records it and never retrieves anything). Vocabulary fields (status, evidence
type, purpose, role) are strings at this untrusted boundary so invalid values are
representable and rejected explicitly. `ProviderResult.fromJson` is strict: any
undefined key (`engineeringObjects`, `repository`, `commit`, `candidates`,
`autoAccept...`, anything unknown) is rejected, not ignored.

## Validation

| Check | Failure code |
|---|---|
| empty request / no source evidence / unsupported objective | `invalid_request` / `unsupported_objective` (raised before any record exists) |
| result schema not the requested version | `unsupported_provider_schema` |
| unknown JSON field (Engineering Object, repository, commit, candidate, unknown claim) | `unsupported_provider_field` |
| claimed context digest or package/runtime identity differs from the request | `invalid_context_identity` |
| evidence not in scope: unknown region/link/candidate, page or source mismatch, out-of-selection, or a hypothesis with no evidence | `invalid_evidence_reference` |
| a hypothesis or usage naming a Reference object that is not in the supplied context | `unknown_reference_object` |
| unknown purpose or role, missing rationale, an Engine-symbol claim that disagrees with the context's binding (or a binding-less object), duplicate usage, link to an invalid hypothesis | `invalid_reference_usage` |
| duplicate hypothesis id (all declarations rejected), missing fields, status other than `proposed`/`rejected` (a provider cannot self-accept), non-finite or "calibrated" confidence | `malformed_hypothesis` |
| duplicate statement id, statement about an invalid hypothesis | `malformed_statement` |
| the provider threw | `provider_failure` |
| the provider reported itself incomplete | `incomplete_provider_result` |
| the provider needed Reference Knowledge it was not given | `reference_context_insufficient` |

The adapter never searches again, fabricates a context item or accepts an unknown
id. The Reference id (`symbol.iec.resistor`) is never replaced by the Engine id
(`resistor`); the binding view is preserved from the context and no mapping is
invented. Confidence is the provider's value unchanged (`basis` defaults to
`provider-supplied`, never calibrated, never ranked).

## Outcomes and lifecycle

Invalid output is never dropped silently: each rejected item becomes an error
diagnostic on the record. If nothing is invalid: `COMPLETED`. If some output is
valid and some problem exists (invalid items, provider errors, incomplete or
insufficient result): `PARTIAL` keeping the valid output. If nothing valid remains,
or the result as a whole is untrustworthy (schema/identity): `FAILED`. A provider
exception is `FAILED`. Lifecycle steps (queued, running, finished) are reported
through `onRecord` so each can be persisted through the ordinary session path.

**Cancellation** reuses the record lifecycle (no new framework): checked before
the provider runs (provider never called), after it returns (output produced after
cancellation is discarded with a warning), and a provider-declared `cancelled`
outcome keeps only what validates. Cancellation stays distinct from failure.

## Persistence and determinism

The adapter returns an `InferenceRecord`; it is persisted by the existing session
machinery (`addInferenceRecord` / `updateInferenceRecord`, INGEST-FOLLOWUP-007
autosave), with no adapter or provider store. The adapter is deterministic in its
validation, provenance, ordering and identity handling: usage ids are derived from
the inference id and position, timestamps come from an injectable clock and enter
no identity, and lists keep the provider's order.

## TRX300 deterministic flow

```
real Reference Library -> compiler -> OERP -> KnowledgeRuntime -> ReferenceDiscovery
  -> DiagramInterpretationReferenceContext (symbol.iec.resistor, component.passive.resistor, unit.ohm)
  -> deterministic test provider  -> hypothesis "resistor" on region-12
       usage: symbol.iec.resistor     symbol_identification   (Engine "resistor", via binding)
       usage: component.passive.resistor  component_classification
       unit.ohm: retrieved, NOT used
  -> adapter validation -> COMPLETED InferenceRecord -> save / reload
```

Source identity, context digest, package/runtime identity, the hypothesis, evidence
linkage, usages, retrieval provenance and the symbol binding survive save/reload;
no candidate, Engineering Object, Repository object or commit exists.

## Not implemented

Any production provider (LLM, vision, local model), autonomous reference retrieval,
candidate promotion, Engineering Object creation, review UI, training/evaluation,
embeddings or a vector store.
