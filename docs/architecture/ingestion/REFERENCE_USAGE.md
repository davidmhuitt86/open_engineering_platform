# Reference Usage — durable reference provenance for inference (WP-INGEST-014)

Builds on `INFERENCE_RECORD.md` (WP-INGEST-013) and
`docs/architecture/knowledge/DIAGRAM_INTERPRETATION_REFERENCE_CONTEXT.md`
(WP-EKE-017). Code: `platform/oep_studio/lib/knowledge/inference/reference_usage.dart`.

```
ReferenceDiscovery -> DiagramInterpretationReferenceContext -> InferenceRecord
                                                                 '-> ReferenceUsage
   -> Human Review -> Candidate -> explicit Repository commit
```

A `ReferenceUsage` answers: *which authoritative reference knowledge did this
inference use, for what purpose, and in support of what?* It is provenance
attached to the one `InferenceRecord` that used it (`InferenceRecord.referenceUsage`).

## Four different statements

| | Meaning | Recorded as |
|---|---|---|
| Retrieved | ReferenceDiscovery returned it | a `ReferenceContextItem` (with its retrieval facts) |
| Available | it was in the context the inference consumed | the context (identified by digest) |
| **Used** | the inference explicitly relied on it | a `ReferenceUsage` (only these) |
| Proved truth | (never) | nothing: no model here claims this |

**Retrieval is not usage.** Putting an item in the context creates no usage;
usage exists only when the adapter/reviewer states one. **Usage is not truth.**
It records why reference knowledge was relied upon, not that it proves the
interpretation. **Retrieval scores are not inference confidence**: the usage
carries the retrieval facts (query, terms, score, rank) as such and has no
confidence field.

A usage is **not** a Reference Library object, a `KnowledgeRuntime` object, a
discovery result, an Engineering Object or Relationship, a `KnowledgeCandidate`,
an inference, a commit, or a knowledge store. It mutates no Reference Knowledge
(Library, compiled package, discovery indexes, runtime, symbol bindings) and
creates no engineering truth or candidate.

## Fields (schemaVersion 1)

- Identity: `usageId` (unique per usage, caller-generated), `schemaVersion`,
  `inferenceId` (the owner), `contextDigest` (the exact context consumed).
- Reference identity: `referenceObjectId`, `referenceObjectType`,
  `referenceObjectVersion` as the runtime reports them, and `package`, the same
  `ReferenceContextIdentity` as the context (`packageId`, `packageVersion`,
  `schemaVersion`, `compilerVersion`, `contentHash`, `runtimeVersion`,
  `runtimeBuild`). Nothing is fabricated and there is no second version model.
- Usage: `purpose` (the frozen WP-EKE-017 vocabulary: `symbol_identification`,
  `component_classification`, `terminal_interpretation`,
  `relationship_interpretation`, `property_interpretation`, `terminology`,
  `standard_reference`), `role` (`primary` | `supporting`), `rationale` (required:
  why it was **used**).
- Links: `evidenceRegionIds`, `hypothesisIds`, `statementIds` (sorted, unique;
  existing ids, no new evidence model).
- Retrieval provenance: `retrieval` copied from the context item (query index and
  text, normalized and matched terms, score, rank, evidence regions) and, for a
  Symbol, the WP-EKE-016 `symbolBinding` view. **Why it was retrieved is kept
  separate from why it was used**: a symbol retrieved for identification may be
  used for terminal interpretation.

## Identity and duplication

`usageId` is independent of the inference and unique within it. The semantic
identity is the structured canonical JSON (sorted keys, no delimiters, no
timestamps) of `{referenceObjectId, purpose, evidenceRegionIds, hypothesisIds,
statementIds}`. Same reference for a different purpose, or the same reference and
purpose for different evidence/hypotheses, are **distinct** usages, which keeps
attribution auditable (one usage linking two hypotheses cannot say which
evidence supported which). Two usages with the same semantic key are one usage
and are rejected as a duplicate; deduplicating by reference id alone is never
done.

## Consistency, and dangling references

A usage is created **from a context item** (`ReferenceUsage.fromContextItem`),
so the object identity, package identity and retrieval provenance come from the
context, and it cannot point outside its context; evidence regions must exist in
that context. The record additionally enforces, without needing the context:
usages belong to this inference, share the record's context digest and Reference
package identity, link only to this record's hypotheses/statements, and are not
duplicates. `InferenceRecord.requireReferenceUsageMatches(context)` checks a
record against the actual context (digest, item membership, regions). Externally
supplied reference usage (not in the consumed context) is not supported and is
rejected.

## Persistence and lifecycle

Inside `KnowledgeSessionRecord.inferenceRecords[].referenceUsage`, in the one
`session.json`; no new store. Records saved earlier load with `[]`. An unsupported
usage `schemaVersion`, unknown purpose/role or malformed data fails explicitly
(`FormatException`). Usage is supplied when the inference is finished
(COMPLETED, PARTIAL, FAILED or CANCELLED all preserve whatever was produced; a
QUEUED record needs none) and is then immutable: a finished record may change
only by deciding proposed hypotheses, through the existing successor rules, which
now cover usage. The INGEST-FOLLOWUP-007 autosave path carries inference records
(and so their usage) intact.

## Example

```
Inference: hypothesis "resistor" (region-12)

ReferenceUsage #1: symbol.iec.resistor           purpose symbol_identification
                   evidence [region-12], hypothesis [hyp-resistor], role primary
                   retrieval: query "resistor", score 1, rank 1
                   binding view: symbol.iec.resistor -> Engine "resistor" (mismatch caveat kept)
ReferenceUsage #2: component.passive.resistor    purpose component_classification
                   evidence [region-12], hypothesis [hyp-resistor]
Retrieved but unused: unit.ohm  -> no ReferenceUsage
```

Both usages record the package `core_reference@1.0.0` and its `contentHash`, so a
reviewer can see that the inference proposed "resistor" because it used those two
Reference objects, from that exact package, for that evidence, and that neither
usage accepts the hypothesis or creates a candidate.

## Not implemented

The constrained interpretation adapter (AP-EKE-018), any model, automatic
reference retrieval or selection, automatic acceptance or candidate promotion, a
review UI, external (out-of-context) usage, and per-usage amendment after
completion.
