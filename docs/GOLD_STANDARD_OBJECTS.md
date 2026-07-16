# Gold Standard Objects

The five Engineering Knowledge Objects ENGINE-TASK-000005 requires,
under `packages/core_reference/`, and how they satisfy
ENGINE-TASK-000006's relationship requirements.

> "No attempt shall be made to populate the library beyond these
> objects... The objective is architectural validation, not content
> quantity." -- WORK_PACKAGE_001

Every object below has all six authoring files
(`object.yaml`/`properties.yaml`/`relationships.yaml`/`behaviors.yaml`/
`validation.yaml`/`education.yaml`) with real, engineering-accurate
content -- no placeholder sections, no empty required fields. Every
object's `identity.status` is `Published` with a real
`provenance.reviewer`, and the whole package validates with **zero**
findings of any severity (`test_gold_standard_objects.py`).

## 1. `component.passive.resistor` -- Resistor

The Component. Eight Engineering Properties (resistance, tolerance,
power rating, temperature coefficient, maximum voltage, preferred
series, package style, noise), six Behaviors (Calculate Current/
Voltage/Power, Voltage Divider, Series/Parallel Resistance -- the exact
list SDD-R001 §11 gives as its own Resistor example), four Validation
Rules, and a worked LED current-limiting-resistor example.

## 2. `equation.ohms_law` -- Ohm's Law

The Equation. Its three variables (voltage, current, resistance)
modeled as Engineering Properties of the equation itself; four
Behaviors (Forward Solver, Inverse Solver, Unit Conversion, Variable
Validation -- SDD-R001 §11's own Equation example, verbatim).

## 3. `unit.volt` -- Volt

The Unit. Symbol, quantity measured, SI base expression, and
conversion factor to SI (1.0, since the volt is itself an SI derived
unit) as properties; an SI-prefix conversion Behavior.

## 4. `symbol.iec.resistor` -- IEC Resistor Symbol

The Symbol. An original, independently-authored SVG rendering of the
IEC 60617 rectangular resistor symbol (`assets/symbol.svg` --
two leads plus a rectangle body, not copied from any copyrighted
artwork), referenced from `object.yaml`'s `visualization.assets`. A
`Render` Behavior (scale/rotation -> rendered geometry reference) --
declarative metadata only, no actual rendering engine (out of scope).

## 5. `material.copper` -- Copper

The Material. Resistivity, temperature coefficient, IACS conductivity,
melting point, density, and thermal conductivity as properties; a
"Calculate Wire Resistance" Behavior using the resistivity relationship
(R = resistivity x length / area) -- deliberately *not* marked as
depending on Ohm's Law, since that is a materially different physical
relationship (Pouillet's Law, not V = IR) and asserting a false
dependency would misrepresent the engineering fact.

## Relationships (ENGINE-TASK-000006)

| Source | Type | Target |
|---|---|---|
| `component.passive.resistor` | `USES_EQUATION` | `equation.ohms_law` |
| `component.passive.resistor` | `HAS_UNIT` | `unit.volt` |
| `component.passive.resistor` | `REPRESENTED_BY` | `symbol.iec.resistor` |
| `equation.ohms_law` | `HAS_UNIT` | `unit.volt` |
| `material.copper` | `USED_BY` | `component.passive.resistor` |

All five resolve cleanly against the five gold objects above --
`validator.checks.check_broken_references` and
`check_duplicate_ids` both report zero findings against this package
(`test_gold_standard_objects.py::test_the_full_package_validates_with_zero_errors_and_zero_warnings`).

### Reconciling ENGINE-TASK-000006's example wording

The work package's own relationship examples list
`Resistor -> HAS_UNIT -> Ohm`, but ENGINE-TASK-000005's object list
does not include a `unit.ohm` object -- it names `unit.volt` as the
one Unit gold object. Inventing a sixth object (`unit.ohm`) purely to
satisfy the example's literal wording would violate ENGINE-TASK-000005's
explicit "no attempt shall be made to populate the library beyond these
[five] objects"; leaving the relationship pointed at a non-existent
`unit.ohm` would violate "relationship validation shall succeed" and
the validator's own broken-reference check. Both constraints are
unambiguous and explicit, so the relationship's *target* was resolved
to the Unit object that actually exists (`unit.volt`, representing the
resistor's `maximum_voltage` rating) while keeping the exact
relationship *type* the example specifies (`HAS_UNIT`). This is
disclosed here rather than resolved silently, and is a genuine
candidate for a future clarifying revision to WORK_PACKAGE_001 or a
future `unit.ohm` gold object once the library expands beyond this
vertical slice.

## Building and verifying

```
oep-validate                 # zero findings against these five objects
oep-compile core_reference   # -> dist/core_reference_v0.oerp
```

See `docs/REFERENCE_COMPILER.md` for what the compiled package
contains and why it is byte-for-byte reproducible.
