# Reference Compiler

How `compiler/` turns validated YAML authoring source into a
deterministic `.oerp` package (SDD-R004, SDD-R010 §12,
ENGINE-TASK-000004/000007).

## Pipeline

```
packages/<package_id>/  (YAML authoring source)
        |
        v
  discover_packages()        oep_reference_core.package_source
        |
        v
  run_all_checks()           validator.checks -- see docs/AUTHORING_GUIDE.md
        |                    (aborts with CompilationError if any error finding exists)
        v
  build_manifest()           compiler.manifest      -> manifest.json
  build_database()           compiler.database       -> reference.db (SQLite)
  build_search_index()       compiler.indexes        -> search.idx
  build_graph_index()        compiler.indexes        -> graph.idx
  (copy each object's assets/)                       -> assets/<object>/...
        |
        v
  write_deterministic_zip()  compiler.archive        -> dist/<package_id>_v<major>.oerp
```

`compiler.build.compile_package(package_id)` runs the whole pipeline.
Validation runs across *every* package under `packages/`, not just the
one being compiled -- a relationship into a sibling package would
otherwise compile successfully today and break the moment that sibling
package's own reference changed, so the compiler catches it up front
instead.

Compiler only: nothing in this package loads a `.oerp` file back. That
is the Reference Runtime's job (`runtime/README.md`), deliberately out
of scope for WORK_PACKAGE_001.

## Why the output is deterministic

SDD-R004 §7 requires the archive to be "byte-for-byte reproducible";
ENGINE-TASK-000007 requires "running the compiler twice shall produce
identical package hashes." Three ordinary, well-known non-determinism
sources are eliminated deliberately:

1. **No wall-clock time anywhere in the build path.** `manifest.json`'s
   `build_date` is the package's own pinned, source-controlled
   `release_date` (`packages/<package>/manifest.yaml`) -- never
   `datetime.now()`. See `compiler/manifest.py`.
2. **`reference.db` (SQLite) is built the same way every time.**
   `compiler/database.py` always creates a fresh file, fixes
   `page_size` before any table exists, never uses `AUTOINCREMENT`
   (which would depend on insert history via `sqlite_sequence`), and
   inserts every row in a stable sort order (by id). SQLite's own
   on-disk format is fully deterministic given an identical sequence
   of operations against a fresh file.
3. **The ZIP archive fixes every non-content byte.** `compiler/archive.py`
   assigns a constant DOS timestamp (`1980-01-01`) and constant
   permission bits to every entry, uses a fixed compression level, and
   adds files in sorted path order -- the standard "reproducible
   builds" technique, since `zipfile`'s defaults otherwise embed the
   real filesystem mtime.

`test_build.py::test_compile_package_is_deterministic_across_two_independent_builds`
and `test_database.py`/`test_archive.py`'s own determinism tests
enforce all three empirically, not just by inspection.

## Usage

```
pip install -e .[dev]
oep-validate
oep-compile core_reference
```

`oep-compile <package_id>` writes `dist/<package_id>_v<major>.oerp` and
prints its SHA-256. `dist/` is git-ignored (SDD-R010 §16: "Compiler
output shall never be submitted").

## Internal package structure (`reference.db`)

SDD-R004 §9 explicitly declares the compiled database's schema
internal to the compiler/runtime, not a public contract. For this
vertical slice it is a small, straightforward relational schema:
`objects`, `properties`, `relationships`, `behaviors`,
`validation_rules`, `evidence` (added in WORK_PACKAGE_002 for the new
Evidence Facet, SDD-R011 §16) -- each row also carries a
`document_json` column with the complete, canonically-serialized
authoring content for that row, so no information is lost even where a
column wasn't normalized out. `objects` itself carries Identity/
Classification/Authority/Provenance columns (Schema Version 1.0); see
`compiler/database.py` for the exact DDL and
`docs/SCHEMA_MIGRATION.md` for what changed from WORK_PACKAGE_001's
column set.
