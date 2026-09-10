# TRX300 reference dataset — electrical validation cases

AP-KIE-REFERENCE-001, Phase 13. Named electrical-behavior test cases tied
to the ground-truth topology (`ground_truth/ground_truth_snapshot.json`).
Every case here is validated by RUNNING the existing, authoritative live
solver stack
(`reference/legacy_wiring_sim_v2/eke-wiring-sim/js/simulation/`,
established and hardened in PRODUCT-READINESS-002) against `diagram7.json`
— **never** by a second, independent electrical calculation written for
this dataset. Several of these cases are already covered by real
automated tests in
`reference/legacy_wiring_sim_v2/eke-wiring-sim/tests/trx300-fixture.test.js`;
those are called out explicitly below. Cases not yet backed by an
automated test are documented as expected behavior only (per this task's
explicit instruction not to build a scoring engine yet) — they are a
target list for future test authorship, not new test code written here.

For future Diagram Ingestion validation, category 14 ("electrical
behavior") in `validation_categories.md` is scored by: build a candidate
graph from a real ingestion run, load it into the same solver the same way
`tests/harness.js`'s `loadOepSampleAsV2` already does for `diagram7.json`,
and compare per-case pass/fail against the expected outcomes below.

## EV-001 — Battery isolation with key off

**Expected:** with the ignition switch in OFF, no downstream circuit
(ignition coil, CDI unit, headlights, taillight) reads battery voltage
except the always-hot paths (if any exist upstream of the ignition switch
itself, e.g. the alarm unit or DC consent jack, which the diagram may wire
directly to battery+ ahead of the switch).
**Backed by:** `trx300-fixture.test.js` ("key-off actually kills
everything" — see `tests/README.md`).
**Ground truth objects:** `node_hm268oh4ab_a08ox4` (battery),
`ignition-switch`.

## EV-002 — Ignition switch continuity truth table

**Expected:** OFF = open (no continuity anywhere on the switch); ON =
BAT1-BAT2 continuity AND BAT3-IG1 continuity simultaneously.
**Provenance:** user-verbatim-confirmed this session (see
`mappings/pdf_to_oep_correspondence.json`).
**Ground truth objects:** `ignition-switch`.

## EV-003 — Dimmer switch is a true 2-position switch (no OFF state)

**Expected:** the dimmer connects EITHER the HI filament OR the LO
filament at all times when the lighting circuit is otherwise live — never
both, never neither. There is no third "headlights off" position on the
dimmer itself (that function belongs to the separate lighting switch).
**Provenance:** user-verbatim-confirmed this session.
**Backed by:** `trx300-fixture.test.js` ("the dimmer actually gates HI vs
LO").
**Ground truth objects:** `left-handlebar-switch`,
`node_hm293u86wk_1siprh5` (LH Headlight), `node_hm294pfd09_155849t` (RH
Headlight).

## EV-004 — Indicator lights are ground-switched, not power-switched

**Expected:** the neutral, reverse, and oil-temperature indicator lights
each have a constant 12V+ feed already present; activating the
corresponding switch (neutral switch closing, reverse switch closing, oil
temp sensor's resistance dropping enough to be read as "closed" in this
model) completes a GROUND path for that specific lamp, not a power path.
An ingestion/validation approach that assumes these switches deliver
12V+ downstream would be electrically wrong even if the topology "looks"
connected.
**Provenance:** user-stated directly this session: "the neutral, reverse
and oil temp switches do not deliver 12v+ the indicator lights have a
constant 12v+ already and when one of those switches is activated it
completes a ground circuit."
**Ground truth objects:** `node_hm268xadl2_14b9olo` (Neutral Switch),
`node_hm26bcdwud_z4g4up` (Reverse Switch), `node_hm2691c017_be7zb0` (Oil
Temp Sensor), `node_hm290w07v2_17b2iov` (Neutral Indicator),
`node_hm28yiides_14i8bbq` (Reverse Indicator),
`node_hm2920qdd8_aelkyk` (Oil Temp Indicator).

## EV-005 — Headlights and taillight respond to the lighting switch

**Expected:** with the lighting switch OFF, headlights and taillight are
both dark regardless of dimmer/key position (beyond key being ON at all);
with it ON, taillight is lit and headlights follow the dimmer per EV-003.
**Backed by:** `trx300-fixture.test.js` ("the lights switch actually
lights the headlights/taillight").
**Ground truth objects:** `left-handlebar-switch`,
`node_hm293u86wk_1siprh5`, `node_hm294pfd09_155849t`,
`node_hm29auwdot_vx4btw` (Taillight).

## EV-006 — Starter circuit interlock via neutral/clutch-adjacent switches

**Expected:** the starter motor/solenoid circuit's actual closure
conditions depend on the starter switch (handlebar) plus whatever
series-gating the neutral switch and/or engine-stop switch impose per the
diagram's real topology — this case exists to be checked against
`diagram7.json`'s actual wiring (not assumed from general ATV knowledge),
since interlock wiring is exactly the kind of detail easy to get subtly
wrong.
**Ground truth objects:** `node_hm268qdn3o_1xhlgpy` (Starter Solenoid),
`node_hm268u6ygb_1fa6wy` (Starter Motor), `left-handlebar-switch`,
`node_hm268xadl2_14b9olo` (Neutral Switch).
**Status:** expected-behavior documentation only; not yet backed by a
named automated test — candidate for future test authorship.

## EV-007 — Splice bridging is unconditional; connector passthrough is same-pin-only

**Expected:** any relationship touching a splice-category node
(`touchesSplice: true` in `relationship_inventory.json`) electrically
bridges all wires meeting there, unconditionally. Any relationship
touching a connector-category node (`touchesConnector: true`) passes
through same-pin-only (pin N in to pin N out), per the generalized
unmodeled-component pin-gating fix from PRODUCT-READINESS-002
(`AP-DEADEND-GENERALIZE-001`/`AP-CONNECTOR-BRIDGE-001`) — it must never
"tunnel through" to a different pin.
**Backed by:** `solver-invariants.test.js`'s synthetic connector/splice
group (generic, not TRX300-specific — proves the SOLVER behavior this case
depends on; this case additionally confirms diagram7.json's own splice/
connector nodes are correctly classified, via `object_inventory.json`'s
`isSplice`/`isConnector` flags).
**Ground truth objects:** all 14 splice nodes, all 8 connector nodes.

## EV-008 — Open circuit reads OL, not a spurious 0.00V

**Expected:** any wire with no closed path back to the battery reads as
genuinely open (OL / no continuity), never collapsed to a fraudulent
0.00V reading that would look identical to "measured a real short."
**Backed by:** `solver-invariants.test.js` ("open/OL vs. a genuine 0.00V
never being collapsed together" — see `tests/README.md`).
**Ground truth objects:** general solver invariant, exercised against
`diagram7.json`'s own topology via `trx300-fixture.test.js`.
