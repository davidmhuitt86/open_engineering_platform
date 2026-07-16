# Package Format (`.oerp`)

How WORK_PACKAGE_001 implements SDD-R004's Engineering Reference
Package Format for its one vertical-slice package,
`core_reference_v0.oerp`.

## Archive contents

An `.oerp` file is a deterministic ZIP archive (SDD-R004 §7):

```
manifest.json       Package identity + counts (SDD-R004 §8)
reference.db        Compiled SQLite database (SDD-R004 §9) -- internal
                     schema, see docs/REFERENCE_COMPILER.md
search.idx           Precompiled term -> object id inverted index
                     (SDD-R004 §10)
graph.idx            Precompiled object id -> outgoing relationship
                     edges (SDD-R004 §11)
assets/<object_id>/  Every asset file each compiled object references
                     (SDD-R004 §12), copied verbatim from that
                     object's own packages/<pkg>/<object>/assets/
localization/        Present but empty for this package -- no
                     localized content is compiled yet (SDD-R004 §13)
signature/           Present but contains only an UNSIGNED marker --
                     digital signing (SDD-R004 §15) is deferred to a
                     future work package; see "Deferred" below
license/             LICENSE.txt, generated from the package's own
                     manifest.yaml license field
```

## Filename

`<package_id>_v<major>.oerp`, where `<major>` is the leading component
of the package's own semantic version (`packages/<package>/manifest.yaml`'s
`version` field). `core_reference`'s `manifest.yaml` pins
`version: "0.1.0"`, so the compiled artifact is
`core_reference_v0.oerp` -- exactly the name ENGINE-TASK-000007
requires.

## What is deferred

* **Digital signatures** (SDD-R004 §15). Every official package "shall
  be digitally signed," but no platform signing infrastructure exists
  yet to sign against. Rather than invent one as an incidental part of
  this work package, the `signature/` directory is present (so the
  archive's shape matches SDD-R004 §7 in full) but contains only an
  `UNSIGNED` marker file explaining the gap. This is a genuine,
  disclosed limitation, not a silent omission -- signing belongs to
  its own future work package.
* **Localization** (SDD-R004 §13). No translated content exists yet to
  compile; `localization/` is present but empty, with a short
  `README.txt` explaining why.
* **Dependencies between packages** (SDD-R004 §14). `core_reference`
  has none to declare. The manifest schema (`schemas/package_manifest.schema.json`)
  already supports a `dependencies` list; circular-dependency checking
  across multiple real packages is future work once a second package
  exists to depend on the first.
* **Installation and Removal** (SDD-R004 §18/§19) and the **Reference
  Runtime** generally (SDD-R004 §23) -- explicitly out of scope for
  WORK_PACKAGE_001; see `runtime/README.md`.

## Reproducibility

Running `oep-compile core_reference` twice (from the same source tree)
produces byte-identical `.oerp` files -- verified by
`test_build.py::test_compile_package_is_deterministic_across_two_independent_builds`
and empirically during this work package's own verification (see the
completion report's Verification section for the exact SHA-256).
`docs/REFERENCE_COMPILER.md` explains the three specific techniques
(pinned release date, deterministic SQLite construction, deterministic
ZIP timestamps) that make this possible.
