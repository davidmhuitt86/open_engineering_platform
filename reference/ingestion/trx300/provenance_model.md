# TRX300 reference dataset — provenance model

AP-KIE-REFERENCE-001, Phase 15. Every fact recorded anywhere in
`reference/ingestion/trx300/` carries a `provenance` value from this fixed
vocabulary. This file is the single authoritative definition; individual
files reference it rather than re-explaining it.

| Value | Meaning | Used for |
|---|---|---|
| `SOURCE` | A raw, unprocessed fact about the source document itself (file hash, page count, dimensions) — not an interpretation of its content. | `source/source_manifest.json`'s structural fields (hash, page count, dimensions, producer metadata). |
| `HUMAN_VERIFIED` | Directly taken from `diagram7.json` (the user's own completed engineering work — itself the ground truth, not a claim ABOUT the ground truth), or directly and verbatim stated by the user in conversation. Not inferred, not visually read from the PDF. | `ground_truth/object_inventory.json`, `ground_truth/relationship_inventory.json`, `ground_truth/ground_truth_snapshot.json` (all fields); `mappings/pdf_to_oep_correspondence.json` entries whose `provenance` is `user_verbatim`. |
| `DERIVED` | Computed mechanically FROM other HUMAN_VERIFIED or SOURCE data, with no new judgment call introduced (e.g. the adjacency index in `ground_truth_snapshot.json`, or `byCategory`/`byKind` counts in `ground_truth_manifest.json`). | `ground_truth/build_inventory.js` / `build_snapshot.js` outputs' summary/index fields. |
| `INFERRED` (used in this dataset as `multimodal_visual_read`) | A judgment call made by directly reading the source PDF's visual content (component symbols, printed labels, table contents) with no independent confirmation. Carries an explicit `confidence` (high/medium/low) alongside it in every file that uses it. | `mappings/pdf_to_oep_correspondence.json` entries whose `provenance` is `multimodal_visual_read`; `annotations/visual_annotations.json`. |
| `UNRESOLVED` (used in this dataset as `confidence: "unresolved"` combined with a `relationship: "structural_inference_only"` or similar) | No reliable source-page correspondence could be established; explicitly NOT guessed. Always paired with a `requires_human_annotation` note explaining what a human would need to check. | The 9 connector/wire-function-label entries and the 14-splice categorical entry in `mappings/pdf_to_oep_correspondence.json`; category 13 (layout reconstruction) in `validation/validation_categories.md`. |

## Why this vocabulary, not a generic "confidence score"

A single numeric confidence score would conflate two genuinely different
questions this dataset needs to answer separately:

1. **Where did this fact come from?** (provenance — a fixed, small
   vocabulary, chosen from the table above)
2. **How sure are we it's correct, given where it came from?** (confidence
   — high/medium/low/unresolved, only meaningful WITHIN a provenance
   category; a `HUMAN_VERIFIED` fact needs no confidence field at all
   because provenance itself establishes it as authoritative, while an
   `multimodal_visual_read`/`INFERRED` fact always needs one)

Keeping these separate is what lets a future ingestion benchmark trust
`HUMAN_VERIFIED` facts unconditionally as the answer key, while still being
honest that some of THIS DATASET's own PDF-side annotations are
themselves uncertain and should not be over-trusted as if they were part
of the answer key.

## Where each value appears

- `source/source_manifest.json` — `SOURCE` for structural facts;
  `multimodal_visual_read` for `knownQualityIssues` (an interpretation, not
  a raw fact).
- `ground_truth/*.json` — `HUMAN_VERIFIED` throughout, plus `DERIVED` for
  computed summary/index fields.
- `mappings/pdf_to_oep_correspondence.json` — mixed, per-entry
  `multimodal_visual_read` / `user_verbatim`, each with its own
  `confidence`.
- `annotations/visual_annotations.json` — `multimodal_visual_read`
  throughout.
- `validation/*.md` — references facts from the files above by pointer;
  does not introduce new provenance-tagged facts of its own.
