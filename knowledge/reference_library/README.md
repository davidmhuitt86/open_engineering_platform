# OEP Reference Library

The Engineering Reference Library (ERL) for the Open Engineering
Platform: authored, verified, and compiled engineering knowledge that
is authoritative, deterministic, and offline-first, independent of any
one application, programming language, or AI provider. See
`docs/adr/OEP_REFERENCE_CONSTITUTION.md`.

## Status

**WORK_PACKAGE_001 (Engineering Reference Library Foundation) and
WORK_PACKAGE_002 (Engineering Knowledge Object Schema Normalization)
implemented.** WORK_PACKAGE_001 proved the complete authoring ->
validation -> compilation pipeline with five canonical Engineering
Knowledge Objects. WORK_PACKAGE_002 froze **Schema Version 1.0** by
implementing SDD-R011's Engineering Knowledge Facet model and SDD-R012's
Authority/Evidence model, then migrating those same five objects to
conform -- an architectural refinement, not a content expansion; still
no attempt to populate the library beyond these five objects.

Implemented:

* The canonical Engineering Knowledge Object (EKO) schema, Schema
  Version 1.0 (SDD-R011, SDD-R012), as seventeen JSON Schemas under
  `schemas/` organized around SDD-R011's fourteen Engineering Knowledge
  Facets -- see `docs/SCHEMA_REFERENCE.md`, and `docs/SCHEMA_MIGRATION.md`
  for exactly what changed from WORK_PACKAGE_001's schema and why.
* The Reference Validator (`validator/`) -- schema validity, required
  fields, duplicate ids (including per-object Property ID uniqueness),
  broken references (including `unit_ref`/`authority_source_object`/
  `evidence_source_object`), documented pending-unit exceptions,
  relationship integrity, behavior references, and asset references,
  producing a deterministic JSON report. See `docs/AUTHORING_GUIDE.md`.
* The Reference Compiler (`compiler/`) -- validated YAML source ->
  SQLite `reference.db` + precompiled `search.idx`/`graph.idx` +
  `manifest.json` -> a byte-for-byte reproducible `.oerp` ZIP archive.
  Compiler only; no runtime loading. See `docs/REFERENCE_COMPILER.md`
  and `docs/PACKAGE_FORMAT.md`.
* Five gold-standard Engineering Knowledge Objects under
  `packages/core_reference/`, every facet populated with real content,
  cross-referenced by five relationships, compiling into
  `dist/core_reference_v1.oerp`. See `docs/GOLD_STANDARD_OBJECTS.md`.

Explicitly out of scope for both work packages: the Reference Runtime
(package loading), Reference Studio, Reference Vault, Universal
Ingestion Framework/Importers, Marketplace, AI integration, executable
Engineering Behaviors, Simulation, and Discovery/Search runtime. See
`docs/IMPLEMENTATION_STATUS.md` for the full picture, and
`runtime/README.md` for what the (not-yet-implemented) Reference
Runtime will need to do.

## Getting Started

Requires Python 3.10+.

```
pip install -e .[dev]
oep-validate                  # validates every package under packages/
oep-compile core_reference    # -> dist/core_reference_v1.oerp
pytest                        # unit tests (98 tests, 97% coverage)
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
* `docs/SCHEMA_MIGRATION.md` -- exactly what changed between
  WORK_PACKAGE_001's schema and Schema Version 1.0, field by field, and
  why
* `docs/REFERENCE_COMPILER.md` -- the compilation pipeline and why its
  output is deterministic
* `docs/PACKAGE_FORMAT.md` -- what a compiled `.oerp` archive contains,
  and what is deliberately deferred (signing, localization, runtime)
* `docs/GOLD_STANDARD_OBJECTS.md` -- the five canonical reference
  objects and their relationships
* `docs/IMPLEMENTATION_STATUS.md` -- current implementation status
