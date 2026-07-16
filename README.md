# OEP Reference Library

The Engineering Reference Library (ERL) for the Open Engineering
Platform: authored, verified, and compiled engineering knowledge that
is authoritative, deterministic, and offline-first, independent of any
one application, programming language, or AI provider. See
`docs/adr/OEP_REFERENCE_CONSTITUTION.md`.

## Status

**WORK_PACKAGE_001 (Engineering Reference Library Foundation)
implemented.** The first complete vertical slice of the
authoring -> validation -> compilation pipeline: five canonical
Engineering Knowledge Objects (Resistor, Ohm's Law, Volt, IEC Resistor
Symbol, Copper) author, validate, and compile into a deterministic
`.oerp` package. The objective was architectural validation, not
content quantity -- no attempt was made to populate the library beyond
these five objects.

Implemented:

* The canonical Engineering Knowledge Object (EKO) schema (SDD-R001),
  as eight JSON Schemas under `schemas/` -- see `docs/SCHEMA_REFERENCE.md`.
* The Reference Validator (`validator/`) -- schema validity, required
  fields, duplicate ids, broken references, relationship integrity,
  behavior references, and asset references, producing a deterministic
  JSON report. See `docs/AUTHORING_GUIDE.md`.
* The Reference Compiler (`compiler/`) -- validated YAML source ->
  SQLite `reference.db` + precompiled `search.idx`/`graph.idx` +
  `manifest.json` -> a byte-for-byte reproducible `.oerp` ZIP archive.
  Compiler only; no runtime loading. See `docs/REFERENCE_COMPILER.md`
  and `docs/PACKAGE_FORMAT.md`.
* Five gold-standard Engineering Knowledge Objects under
  `packages/core_reference/`, every SDD-R001 section populated with
  real content, cross-referenced by five relationships, compiling into
  `dist/core_reference_v0.oerp`. See `docs/GOLD_STANDARD_OBJECTS.md`.

Explicitly out of scope for this work package: the Reference Runtime
(package loading), Marketplace, AI integration, executable Engineering
Behaviors, Simulation, and Discovery/Search runtime. See
`docs/IMPLEMENTATION_STATUS.md` for the full picture, and
`runtime/README.md` for what the (not-yet-implemented) Reference
Runtime will need to do.

## Getting Started

Requires Python 3.10+.

```
pip install -e .[dev]
oep-validate                  # validates every package under packages/
oep-compile core_reference    # -> dist/core_reference_v0.oerp
pytest                        # unit tests (91 tests, 97% coverage)
```

The Reference Validator and Reference Compiler are implemented in
Python -- an authoring/build toolchain choice, not a Reference Runtime
one. The Reference Runtime itself (a future work package) remains
language-independent; it will consume compiled `.oerp` packages only,
never the Python source here (SDD-R010 §17).

## Repository Structure

Per the OEP Reference Constitution and SDD-R010 §4:

```
docs/            Constitution, SDDs, work packages, and this documentation set
schemas/         JSON Schemas for every authoring file (SDD-R010 §8)
packages/        Engineering Knowledge Object authoring source (SDD-R010 §5/§6)
compiler/        The Reference Compiler (ENGINE-TASK-000004)
validator/       The Reference Validator (ENGINE-TASK-000003)
runtime/         Reserved for the Reference Runtime (out of scope for WORK_PACKAGE_001)
tools/           Shared library code used by both compiler/ and validator/
examples/        Reserved for future authoring examples
test/            Unit tests (pytest)
```

## Documentation

* `docs/adr/OEP_REFERENCE_CONSTITUTION.md` -- the permanent governing
  principles of the Engineering Reference Library
* `docs/specifications/SDD-R001` through `SDD-R010` -- the architecture
  this repository implements
* `docs/AUTHORING_GUIDE.md` -- how to author a new Engineering
  Knowledge Object, and what the validator checks
* `docs/SCHEMA_REFERENCE.md` -- every JSON Schema, and the interpretive
  decisions made where the SDDs left the authoring-file split
  underspecified
* `docs/REFERENCE_COMPILER.md` -- the compilation pipeline and why its
  output is deterministic
* `docs/PACKAGE_FORMAT.md` -- what a compiled `.oerp` archive contains,
  and what is deliberately deferred (signing, localization, runtime)
* `docs/GOLD_STANDARD_OBJECTS.md` -- the five canonical reference
  objects and their relationships
* `docs/IMPLEMENTATION_STATUS.md` -- current implementation status
