# TRX300 diagram ingestion reference dataset

AP-KIE-REFERENCE-001. This directory is the platform's **first formal
ground-truth reference dataset** for a future Diagram Ingestion pipeline —
a way to eventually answer, objectively, "given this source PDF, how
closely does automated ingestion reconstruct what a human engineer
produced?"

**This is dataset/ground-truth preparation only.** It is not AI training
data, not an ML/embeddings/vector-db artifact, and it introduces no
ML/training infrastructure of any kind. The real milestone this directory
represents is a trustworthy, provenance-tagged relationship between one
real source document and one real human-completed engineering diagram —
not the mere existence of generated files.

## Why this location, not "KIE" or "COIM"

Neither "KIE" nor "COIM" corresponds to any real, established
architectural concept in this repository (confirmed by direct repo-wide
search — zero meaningful hits). The closest existing precedents,
inspected before choosing this location:

- `platform/oep_engine/lib/importers/{pdf,svg,images,shared}/` — empty,
  `.gitkeep`-only stubs reserved for a **legacy, never-migrated** analysis
  effort that historically used the name "EKE" (Electrical Knowledge
  Engine) — a different historical system from the JS reference simulator
  at `reference/legacy_wiring_sim_v2/eke-wiring-sim/` despite the name
  collision. Nothing usable exists there today.
- `services/acquisition` — a real, working, generic document-custody/
  provenance pipeline (Source → Job → Record → Vault; see `SDD-R013`–
  `SDD-R019`, `docs/decisions/ADR-0001`/`ADR-0002-PROPOSED`). Structurally
  the closest analogue in spirit (source document provenance tracking),
  but generic/non-diagram-specific and stops before any content
  extraction — it would not natively hold component inventories, wire
  topology, or electrical validation cases.
- `knowledge/reference_library` — about reusable, compiled ENGINEERING
  KNOWLEDGE PACKAGES (components/equations/units → `.oerp`); its own
  README explicitly disclaims ingestion/importers as out of scope.
  Unrelated to this dataset.

No master ADR or numbering index exists anywhere in the monorepo — every
subsystem invents its own local scheme. Given no existing structure fits,
this dataset proposes and uses a new one: `reference/ingestion/<vehicle>/`,
parallel in spirit to `reference/legacy_wiring_sim_v2/` (an existing
top-level `reference/` convention for material that informs but is not
itself product code). This is a proposal, not a unilateral architectural
decision — flagged explicitly in the final report for the user's
confirmation before a second dataset ever gets added here.

## Directory structure

```
reference/ingestion/trx300/
  source/
    trx300_factory_wiring_diagram.pdf   -- exact copy of the user-provided source PDF
    source_manifest.json                -- source document identity, hashes, known quality issues
  ground_truth/
    build_inventory.js                  -- re-runnable: diagram7.json -> object/relationship inventories
    build_snapshot.js                   -- re-runnable: inventories -> comparison-ready snapshot
    ground_truth_manifest.json          -- how diagram7.json was identified as ground truth, counts
    object_inventory.json               -- 47 objects, generated
    relationship_inventory.json         -- 80 relationships, generated
    ground_truth_snapshot.json          -- merged, indexed, comparator-ready snapshot, generated
  mappings/
    pdf_to_oep_correspondence.json      -- PDF symbol <-> ground-truth object correspondence, per-entry confidence
  annotations/
    visual_annotations.json             -- page regions, legends, tables, rendering hazards
  validation/
    critical_ambiguities.md             -- named hard cases (splice dots, connector-vs-splice, etc.)
    validation_categories.md            -- 14 category definitions (no scoring engine built)
    electrical_validation_cases.md      -- named electrical behavior cases, run through the EXISTING live solver
  ingestion_benchmark_contract.md       -- future pipeline shape + what questions it must answer
  provenance_model.md                   -- SOURCE / HUMAN_VERIFIED / DERIVED / INFERRED / UNRESOLVED vocabulary
  README.md                             -- this file
```

## What is authoritative here vs. what is not

- **`diagram7.json`** (`platform/oep_studio/samples/diagram7.json`) is the
  ground truth. It was never modified by this dataset — every file under
  `ground_truth/` is derived by READING it, confirmed via `git diff`.
- **The live JS solver**
  (`reference/legacy_wiring_sim_v2/eke-wiring-sim/js/simulation/`,
  hardened under PRODUCT-READINESS-002) is the only electrical calculation
  authority this dataset ever references. Nothing here duplicates it.
- **The source PDF** was never modified. It is genuinely rotated 180° in
  the scan itself and is the best-quality copy the user could find — both
  documented as permanent characteristics, not gaps to be fixed later.
- Anything marked `unresolved` / `requires_human_annotation` in
  `mappings/pdf_to_oep_correspondence.json` is an honest gap, not a
  fabricated guess. See `provenance_model.md` for how to interpret it.

## Regenerating the derived files

If `diagram7.json` is ever updated, re-run, in order, from
`ground_truth/`:

```bash
node build_inventory.js
node build_snapshot.js
```

Then update `ground_truth_manifest.json`'s `sourceDiagramSha256` to match.
