# TRX300 reference dataset — ingestion validation category definitions

AP-KIE-REFERENCE-001, Phase 12. These 14 categories define WHAT a future
Diagram Ingestion accuracy benchmark would need to measure against this
reference dataset. This file defines the categories only — it does **not**
build a scoring engine, comparator, or accuracy metric. That is explicitly
out of scope for this task (see `ingestion_benchmark_contract.md` for the
future pipeline shape these categories would plug into).

For each category: what it measures, which ground-truth file(s) hold the
answer key, and — where relevant — a pointer to a known gap in this
dataset's own current mapping (so a future scoring pass doesn't mistake a
documented, honest gap for an ingestion failure).

1. **Component recognition** — did the candidate correctly detect that a
   component exists at all, independent of what it's called? Answer key:
   `ground_truth/object_inventory.json` (47 objects). Known gap: 9 of 33
   non-splice objects and all 14 splices have no confirmed 1:1 source
   symbol in `mappings/pdf_to_oep_correspondence.json` — a candidate that
   also fails to detect exactly those same objects should not be penalized
   as if it missed something a correct reader would have caught.

2. **Component classification** — did the candidate assign the correct
   category/kind (e.g. `switch` vs `thermistor`)? Answer key:
   `object_inventory.json`'s `category`/`kind` fields. Known hard case: the
   Oil Temp Sensor is drawn using a switch symbol but is electrically a
   thermistor (`kind: thermistor`) — see
   `mappings/pdf_to_oep_correspondence.json`'s `node_hm2691c017_be7zb0`
   entry. A shape-only classifier would misclassify this by design; a
   correct classifier needs the printed label too.

3. **Terminal extraction** — did the candidate identify the right number
   and naming of a component's pins? Answer key: `object_inventory.json`'s
   `terminals` array per object.

4. **Connector recognition** — did the candidate correctly identify which
   objects are harness connectors (as opposed to permanent splices or
   plain components)? Answer key: `object_inventory.json`'s `isConnector`
   flag (8 objects). Known gap: see critical ambiguity #2 in
   `critical_ambiguities.md` — the source page mostly does not visually
   distinguish connectors from splices at all.

5. **Connector pin identification** — for a recognized connector, did the
   candidate get the individual pin count/order right? Answer key:
   `object_inventory.json`'s `terminals` on connector-flagged objects.

6. **Wire extraction** — did the candidate detect that a wire/connection
   exists between two points at all? Answer key:
   `relationship_inventory.json` (80 relationships).

7. **Wire color extraction** — did the candidate read the correct color
   code off the wire label? Answer key: `relationship_inventory.json`'s
   `wireColor` field. Known gap: the source page's own `Bl` legend entry is
   ambiguous between Black/Blue — see
   `annotations/visual_annotations.json`'s `wire-color-legend` region.

8. **Wire endpoint identification** — did the candidate connect the wire
   to the correct component AND the correct terminal on each end (not just
   "some wire touches this component somewhere")? Answer key:
   `relationship_inventory.json`'s `source.port`/`target.port` fields — all
   80 relationships have explicit terminal references on both ends
   (`relationshipsWithExplicitTerminalRefsOnBothEnds: 80` in
   `ground_truth_manifest.json`), making this category fully scoreable once
   a comparator exists.

9. **Splice detection** — did the candidate correctly identify a junction
   point as a real electrical splice (vs. an incidental crossing)? Answer
   key: `object_inventory.json`'s `isSplice` flag. Known gap: see critical
   ambiguity #1 — this is flagged as the single largest unresolved mapping
   gap in the whole dataset.

10. **Crossing vs. connection interpretation** — for any two wire lines
    that visually cross on the page, did the candidate correctly decide
    "connected" vs. "merely overlapping"? This is the general case splice
    detection (#9) is the specific "identify the resulting node" version
    of. Answer key: implied by `relationship_inventory.json`'s topology
    (which components end up electrically joined), not directly by any
    single field.

11. **Label extraction** — did the candidate correctly OCR/transcribe
    printed text (component names, wire labels, switch-table headers and
    cell values)? Answer key: `object_inventory.json`'s `displayName`,
    `relationship_inventory.json`'s `label`, and
    `mappings/pdf_to_oep_correspondence.json`'s `switchContinuityTables`
    section.

12. **Topology reconstruction** — taken as a whole, does the candidate's
    graph have the same connectivity structure as the ground truth (same
    components joined to the same components via the same splices/
    connectors), independent of visual layout? Answer key: the full
    `ground_truth_snapshot.json` (objects + relationships + adjacency
    index) — this is the category the snapshot file was specifically built
    to make comparator-ready.

13. **Layout reconstruction** — did the candidate preserve/infer a
    reasonable spatial arrangement (not required to be pixel-identical to
    the source, but structurally sensible)? No answer key currently exists
    in this dataset for this category — `diagram7.json`'s own node
    positions reflect the user's Diagram Studio canvas layout, not the
    source page's layout, so they are not usable as a "correct" spatial
    ground truth for THIS category. Documented as an open gap rather than
    silently scored against the wrong reference.

14. **Electrical behavior** — given the candidate's reconstructed graph,
    does simulating it produce the same real-world electrical outcomes
    (which lights turn on for which switch positions, etc.) as the real
    vehicle? Answer key: `electrical_validation_cases.md` — this is the
    only category that is validated by RUNNING the existing live solver
    (`reference/legacy_wiring_sim_v2/eke-wiring-sim/js/simulation/`)
    against the ground-truth topology, never by a second, duplicate
    calculation.
