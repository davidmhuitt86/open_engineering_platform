# TRX300 reference dataset — critical ambiguity cases

AP-KIE-REFERENCE-001, Phase 10. These are the specific, named cases where the
source PDF's own drawn content is genuinely ambiguous — not places where this
dataset failed to look hard enough, but places where a correct, careful
human reader is still left with a judgment call. A future ingestion pipeline
should be expected to either resolve these the same way a human would, or
flag them for review — not silently guess. Each case below references the
concrete ground-truth objects/relationships it touches so a future
comparator can locate it programmatically.

## 1. Splice dots vs. incidental wire crossings

**The case:** the main schematic body has many places where two or more
wire lines cross on the page. Standard convention is that a solid filled
dot at a crossing means "these wires are electrically joined here" and the
absence of a dot means "these lines merely cross on paper, not connected."
At this scan's resolution, some crossings' dots are not reliably
distinguishable from line-weight overlap or scan noise.

**Ground truth objects involved:** all 14 splice nodes
(see `mappings/pdf_to_oep_correspondence.json`'s `spliceCorrespondence`
section — individually unresolved, categorically medium-confidence).

**Why it matters for ingestion validation:** this is possibly THE
canonical hard case for schematic ingestion generally, not just this
vehicle. A pipeline that gets this wrong either invents electrical
connections that don't exist (false splice) or drops real ones (missed
splice) — both are silent, high-impact errors that would only surface as
wrong solver behavior far downstream, not as an obviously-wrong drawing.

**Resolution used in this dataset:** none attempted at the individual
symbol level (would require fabricated coordinates). The ground-truth
splice topology is instead taken entirely from `diagram7.json` itself
(`HUMAN_VERIFIED` — the user placed each splice deliberately, including two
splices added specifically to fix real wiring bugs found during
PRODUCT-READINESS-002's live-debugging phase). The PDF-side individual
correspondence remains `unresolved` / `requires_human_annotation`.

## 2. Connector vs. splice modeling choice

**The case:** the OEP graph models 8 explicit "connector" nodes (multi-pin,
representing real disconnectable wire-harness connectors) and 14 "splice"
nodes (single-point, representing permanent solder/crimp joints or simple
branch points). The source page's drawing convention does not visually
distinguish these two categories in most cases — both often render as
nothing more than a wire junction, with no connector-body symbol drawn.

**Ground truth objects involved:** the 8 connector nodes
(`node_hlzz7d8xvu_wn2xzq`, `node_hm11a90flg_4abwqs`, `node_hm13fzhpd7_1yhimgb`,
`node_hm2vz4eunm_mfxq72`, `node_hm2w4xzhz8_1xpw939`, `node_hm2wkv7mtt_9hiy30`,
`node_hm2x5jwn0x_atvrws`, `node_hm2xerewgw_1ecxfdq`) — all flagged
`unresolved` in `mappings/pdf_to_oep_correspondence.json` for the same
reason.

**Why it matters:** connector vs. splice is not a cosmetic distinction —
it changes real electrical behavior in the solver (a connector gates by
same-pin-only passthrough; a splice bridges unconditionally). An ingestion
pipeline that cannot tell them apart from the source page alone cannot
reconstruct correct electrical behavior, only correct-looking topology.

**Resolution used in this dataset:** the connector/splice distinction is
taken entirely from `diagram7.json`'s own metadata (`HUMAN_VERIFIED` — this
is real information the user encoded when building the diagram, based on
their own knowledge of the actual wire harness, not information visible on
the factory diagram page itself). This is documented as a case where the
ground truth necessarily carries MORE information than the source page
alone provides — an expected and important finding, not a dataset defect.

## 3. Symmetric/unlabeled LH vs. RH headlight

**The case:** the page draws two visually identical dual-filament headlight
symbols side by side, both part of one "HEADLIGHTS (12V 25W/25W X2)"
annotation, with no per-symbol LEFT/RIGHT text label.

**Ground truth objects involved:** `node_hm293u86wk_1siprh5` (LH Headlight),
`node_hm294pfd09_155849t` (RH Headlight).

**Resolution used in this dataset:** mapped by vehicle-layout convention
(rider's-left vs. rider's-right, matching the left-to-right symbol order as
drawn) at `medium` confidence — see
`mappings/pdf_to_oep_correspondence.json`. Flagged explicitly as
convention-based rather than label-based.

## 4. Two separate diode-family ground-truth objects, possibly one drawn symbol

**The case:** `diagram7.json` contains two distinct single-diode graph
objects — `rectifier-diode` (category `charging`) and a separate node
`node_hm241o81f0_1foy2j2` (category `diode`, displayName "Diode"). The page
shows one clearly-labeled "RECTIFIER" box containing a diode arrow symbol;
it is not certain from the visual read whether a second, independent diode
symbol exists elsewhere on the page or whether both graph nodes are meant
to correspond to the same drawn symbol (split into two nodes for internal
topology-modeling reasons on the OEP side).

**Ground truth objects involved:** `rectifier-diode`, `node_hm241o81f0_1foy2j2`.

**Resolution used in this dataset:** `rectifier-diode` mapped at `medium`
confidence to the labeled RECTIFIER box; `node_hm241o81f0_1foy2j2` left at
`low` confidence / `requires_human_annotation`. Not guessed further.

## 5. Chassis-ground symbol multiplicity

**The case:** ground-truth models exactly 2 ground objects
(`chassis-ground`, `node_hm235oce1b_4wm62u`), but the source page's ground
symbol (a small earth/frame glyph) appears to repeat at multiple distinct
points across the schematic — standard practice in factory diagrams is to
draw a local ground symbol at each physical grounding point rather than
route every ground wire back to one drawn symbol.

**Ground truth objects involved:** `chassis-ground`, `node_hm235oce1b_4wm62u`.

**Why it matters:** this means a naive "count the ground symbols, count the
ground nodes, expect them to match" validation approach would be wrong by
construction — the real relationship is likely many-symbols-to-few-nodes
(all physically the same chassis ground net), not 1:1. A future ingestion
benchmark's electrical/topology comparator needs to know this going in.

**Resolution used in this dataset:** documented as an open, structural
ambiguity rather than resolved — see
`mappings/pdf_to_oep_correspondence.json`'s `chassis-ground` entry.

## 6. Physical-part name vs. graph category naming mismatch

**The case:** the source page labels the starter relay as "STARTER RELAY
SWITCH"; ground truth's `kind` metadata flag for the same object is
`solenoid`. Both terms refer to the same real automotive part (a
solenoid-actuated relay); this is a nomenclature difference, not a
component-identity ambiguity.

**Ground truth objects involved:** `node_hm268qdn3o_1xhlgpy`.

**Why it matters:** a naive string-match-based ingestion validator would
flag this as a "misclassification" when it is actually a correct match
under a different, equally valid name. Any future ingestion-accuracy
scoring must account for known part-name synonymy rather than penalizing
it as an error.

**Resolution used in this dataset:** documented, not treated as an error —
see `mappings/pdf_to_oep_correspondence.json`'s `node_hm268qdn3o_1xhlgpy`
entry.
