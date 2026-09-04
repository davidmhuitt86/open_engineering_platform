# Architecture

Architecture decisions made during implementation of `oep_exchange`'s work packages, as distinct from the governing specifications in `docs/specifications/` (which this repository implements rather than redesigns).

- [`REPOSITORY_STRUCTURE.md`](./REPOSITORY_STRUCTURE.md) — TASK-EXC-0001: monorepo tooling, package layout, dependency direction, and the rationale for every implementation detail not dictated by a specification.
- [`DEPENDENCY_GRAPH.md`](./DEPENDENCY_GRAPH.md) — the intended dependency graph, allowed/forbidden dependency directions, circular dependency policy, and future integration points with `oep_foundation`, `oep_repository`, and `oep_engine`.
- [`adr/`](./adr/) — Architecture Decision Records, starting with [`ADR-0001-Repository-Structure.md`](./adr/ADR-0001-Repository-Structure.md).

See also, at the repository root: [`OWNERSHIP.md`](../../OWNERSHIP.md) (who/what owns each package and app) and [`CONTRIBUTING_ARCHITECTURE.md`](../../CONTRIBUTING_ARCHITECTURE.md) (mandatory architectural rules for all contributors).
