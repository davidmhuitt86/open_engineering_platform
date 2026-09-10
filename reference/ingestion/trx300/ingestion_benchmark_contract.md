# TRX300 reference dataset — future ingestion benchmark contract

AP-KIE-REFERENCE-001, Phase 14. This is a **specification for a pipeline
that does not exist yet** — Diagram Ingestion has not been built. Nothing
in `reference/ingestion/trx300/` builds any part of it. This file exists so
that whenever Diagram Ingestion IS built, there is already an agreed
contract for how it would be benchmarked against this dataset, instead of
that contract being invented ad hoc at that time.

## Pipeline shape

```
SOURCE PDF  -->  Ingestion  -->  Candidate Graph  -->  Comparator  -->  Accuracy Report
(source/                                                  ^
 trx300_factory_                                          |
 wiring_diagram.pdf)                              Ground Truth
                                                   (ground_truth/
                                                    ground_truth_snapshot.json)
```

- **SOURCE PDF** — `source/trx300_factory_wiring_diagram.pdf`, exactly as
  documented in `source/source_manifest.json`. Never modified.
- **Ingestion** — the future, not-yet-built system that reads the PDF and
  produces a candidate OEP-shaped graph. Out of scope for this dataset.
- **Candidate Graph** — whatever Ingestion produces, in whatever format it
  produces it in (presumably OEP `DiagramDocument` shape, to be comparable
  against ground truth without a translation step, but that is a decision
  for Ingestion's own design, not this dataset).
- **Ground Truth** — `ground_truth/ground_truth_snapshot.json` (objects +
  relationships + adjacency index, all `HUMAN_VERIFIED`), cross-referenced
  against `mappings/pdf_to_oep_correspondence.json` where per-symbol source
  correspondence is needed.
- **Comparator** — the future, not-yet-built component that diffs a
  Candidate Graph against the Ground Truth snapshot, scored per the 14
  categories in `validation/validation_categories.md`. Not built here.
- **Accuracy Report** — the future output: per-category pass/fail or
  precision/recall against the ground truth, plus the electrical-behavior
  cases in `validation/electrical_validation_cases.md` run through the
  existing live solver.

## Questions the benchmark must be able to answer

1. Per category (1–14 in `validation_categories.md`): what fraction of
   ground-truth objects/relationships/facts did the candidate correctly
   reconstruct?
2. Does the candidate's graph, when run through the EXISTING live solver
   (never a second one), reproduce the expected outcomes in
   `electrical_validation_cases.md`?
3. For entries this dataset itself marked `unresolved` /
   `requires_human_annotation` (the 9 connector/wire-function-label
   objects, the 14 splices' individual correspondence) — did the candidate
   do BETTER than this dataset's own human-grade visual read? If so, that
   is valuable signal that Ingestion found something a careful human
   reading missed, not a scoring anomaly to be discarded.
4. For known ambiguity cases in `critical_ambiguities.md` — did the
   candidate resolve them the same way, differently, or not at all (i.e.
   flagged for review, matching the behavior this dataset itself modeled)?
5. Does accuracy differ meaningfully between categories that depend on
   printed text (label extraction, wire color) vs. categories that depend
   on drawn-symbol interpretation (component recognition, splice
   detection) vs. categories that require inference beyond what's on the
   page (connector recognition, per the connector/splice ambiguity)? This
   would be diagnostic of WHERE a real ingestion pipeline needs the most
   work, not just an aggregate score.

## Explicitly not defined here

- A numeric accuracy formula, weighting scheme, or pass/fail threshold.
- Any comparator implementation.
- Any assumption about Ingestion's own internal architecture (OCR model,
  vision model, rule-based symbol library, or otherwise) — this contract
  is about the INTERFACE (PDF in, graph out, compared against this ground
  truth) not the implementation.
