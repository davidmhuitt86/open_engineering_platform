# Reference Runtime

Out of scope for WORK_PACKAGE_001.

Per SDD-R004 §23 and SDD-R010 §17, the Reference Runtime loads compiled
`.oerp` packages, resolves dependencies, merges indexes and graphs, and
exposes APIs to consumers (Engineering Engine, Diagram Studio,
Knowledge Studio, Simulation Engine, AI Services). The runtime never
reads authoring YAML and never depends upon the source repository
layout.

WORK_PACKAGE_001 stops immediately after a `.oerp` package compiles
successfully and deterministically — no runtime loading is implemented
here yet. This directory exists so the repository layout matches
SDD-R010 §4 in full; it is populated in a subsequent work package,
after architectural review.
