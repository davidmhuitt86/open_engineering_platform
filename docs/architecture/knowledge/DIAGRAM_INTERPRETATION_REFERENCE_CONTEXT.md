# Diagram Interpretation Reference Context (WP-EKE-017)

Builds on `KNOWLEDGE_RUNTIME_BOUNDARY.md`, `REFERENCE_DISCOVERY.md`,
`SYMBOL_BINDING.md`. Code: `platform/oep_studio/lib/knowledge/interpretation/`
(`reference_context.dart`, `reference_context_builder.dart`).

**WP-EKE-017 does not interpret diagrams.** It assembles what a future
interpretation step is allowed to use, deterministically and with provenance.

```
Diagram / source evidence  (OCR, EvidenceRegions incl. human annotations,
                            EvidenceLinks, KnowledgeCandidates, SourceMaterial)
        |                              ReferenceDiscovery.search (term match, deterministic)
        v                                    |
DiagramInterpretationReferenceContextBuilder +--> KnowledgeRuntime (authoritative objects / relationships)
        |                                    +--> SymbolBindingAdapter (optional integration view)
        v
DiagramInterpretationReferenceContext   (immutable, in-memory)
        v
future InferenceRecord -> LLM / Vision      (not implemented)
```

## Four different things

| | Meaning | In the context? |
|---|---|---|
| Observation | evidence directly present in the source: OCR words, regions, explicitly sourced human annotations and existing candidates | yes, as-is |
| Reference Knowledge | authoritative knowledge retrieved via ReferenceDiscovery and resolved by KnowledgeRuntime | yes, as the runtime's own objects |
| Interpretation | a conclusion from a future inference process | **no** |
| Accepted engineering truth | reviewed and committed knowledge | **no** |

A human annotation is evidence, not Reference Knowledge and not an Engineering
Object; a `KnowledgeCandidate` stays a candidate (status/provenance untouched,
never committed). Nothing here calls `CommitPlanService` or mutates the
Repository, the Engineering Graph, the KnowledgeSession or the Reference
Knowledge.

## Why it lives in Studio

The canonical evidence models (`OcrPageResult`, `EvidenceRegion`,
`EvidenceLink`, `KnowledgeCandidate`, `SourceMaterial`) are Studio models, and
the engine cannot depend on Studio. The builder therefore sits beside them and
consumes the engine's Reference stack. No evidence model was re-modelled; the
context holds the existing objects and the runtime's own
`KnowledgeObject`/`KnowledgeRelationship`.

## Request and retrieval

`ReferenceContextRequest { evidence?, queries[] }`
- `DiagramEvidenceInput`: `SourceMaterial`, optional page, and the OCR pages,
  regions, links and candidates to select from. Anything for another source (or
  page) is excluded. Candidates are those linked (via `EvidenceLink`) to an
  included region, the same join the session state uses.
- `ReferenceContextQuery`: a `ReferenceRetrievalPurpose` (`symbol_identification`,
  `component_classification`, `terminal_interpretation`,
  `relationship_interpretation`, `property_interpretation`, `terminology`,
  `standard_reference`), the search text, optional exact `objectTypes` filter
  (`Symbol`, `Component`, ...), optional `relationshipTypes` filter,
  `requireAllTerms`, `maxResults`, and optional `evidenceRegionIds` (provenance
  only).
- Limits: `maxResults` defaults to **10** and may not exceed **50**; truncation is
  applied after ranking and object-type filtering, and each query's outcome
  records `totalMatches`, `returned` and `truncated`. There is no "load the
  library" operation.

Flow per query: `ReferenceDiscovery.search(query)` -> ids -> `KnowledgeRuntime.getObject`
-> filter by type -> keep the first `maxResults`. For each retained object,
`KnowledgeRuntime.relationshipsForObject` supplies the Reference relationships
(both directions; `graph.idx` is outgoing-only, so the runtime is the better
source), de-duplicated by id. No relationship is inferred and none is converted
to an `EngineeringRelationship`. The builder does no matching of its own: no
fuzzy, semantic or embedding search, and it parses no Reference files, indexes or
`reference.db`.

## Provenance: why each item is there

`ReferenceContextItem` = the runtime's `KnowledgeObject`, the `purpose`, a
`ReferenceRetrieval` (query index and text, normalized terms, matched terms,
`score`, `rank`, the region ids the query was about, and a rationale string),
the Reference `identity`, and, for a Symbol, the binding view.
`score` and `rank` are match counts and list positions, **not** confidence or
probability. An object retrieved by two queries appears once per query with
its own rationale. Relationships record the purposes and retrieved object ids
that caused their inclusion.

## Identity

- Source: `SourceMaterial.id`, page filter, and `sourceFingerprint` = the
  existing `OcrPageResult.sourceFingerprint` (`SourceMaterial` itself carries no
  hash). If a source's OCR results disagree, the build fails
  (`inconsistentSourceIdentity`). No new hashing scheme is introduced. A source with no OCR
  result has no fingerprint (`null`); that is a documented gap.
- Reference package/runtime: `ReferenceContextIdentity`, copied from
  `KnowledgeRuntime.identity` (`packageId`, `packageVersion`, `schemaVersion`,
  `compilerVersion`, `contentHash`, `runtimeVersion`, `runtimeBuild`).
  Not an Engine version and not an inference-model identity (the future
  InferenceRecord owns that).
- Reference object id and Engine symbol id are separate; see below.

## Symbol Binding

A retrieved Reference `Symbol` gets a `ReferenceSymbolBindingView`:
`bound` (both `referenceSymbolId` and `engineSymbolId`, plus the binding's
`notes` verbatim), `absent` (no binding: valid, explicit, nothing inferred),
`invalid` (a binding that does not resolve, with its error code) or
`notEvaluated` (no adapter supplied). The Reference object stays authoritative;
the Engine `SymbolDefinition` is not copied into the context. A missing binding
never fails retrieval.

**Rendering mismatch (unchanged from WP-EKE-016):** `symbol.iec.resistor` is bound
to Engine `resistor`, but the Reference symbol is an IEC rectangle and the Engine
glyph is a zigzag. The context asserts no visual equivalence; the binding's
caveat travels with the item.

## Determinism

Same evidence + request (queries in the caller's order) + Reference package +
binding registry gives an identical context. Ordering: OCR pages by page (words
keep OCR reading order, with boxes and confidence); regions by (page, y, x, id);
links by (candidate, region, id); candidates by id; items by query order then
rank; relationships by id. No unordered map iteration, timestamps, random ids or
model output is introduced. (Timestamps inside existing models such as
`processedTime` are source provenance and are carried as-is.)

## Missing pieces

- No Reference stack and no queries: an evidence-only context (`reference: null`).
- Queries but no Reference stack: explicit `referenceKnowledgeUnavailable`.
- A query with no hits: valid; the outcome records `totalMatches: 0`.
- A Reference-only context (no evidence) is allowed.

## Persistence

An immutable in-memory value object. It is not stored in the KnowledgeSession
and adds no database. `toJson()` gives a deterministic serialized *snapshot* for
tests/export (marked as not authoritative and not an interpretation); nothing
reads it back.

## Limits and not-done

- Structured annotation properties (`EvidenceRegion.annotation`, WP-INGEST-013)
  are passed through by region serialization, but that model was not present in
  the tree this was built on, so it is not exercised by tests here.
- The Engineering Graph / `DiagramView` are not consumed; "existing diagram
  context" is a later input.
- Not implemented: `InferenceRecord`, `ReferenceUsage`, constrained
  interpretation, LLM/vision, symbol recognition, ranking beyond
  ReferenceDiscovery's, caching, or an index-backed property/behavior search.
