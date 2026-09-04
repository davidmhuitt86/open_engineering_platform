# Open Engineering Platform — Monorepo Architecture

This repository hosts multiple independently-owned OEP subsystems under one Git history. Physical co-location does **not** imply a dependency — each subsystem keeps its own language, toolchain, build system, and ownership boundary.

## Layout

```
open_engineering_platform/
├── platform/
│   ├── oep_foundation/       C/C++ engineering foundation + public API
│   ├── oep_engine/           Dart "engineering_engine" package (FFI onto oep_foundation)
│   ├── oep_instruments/      Instruments package (Dart, sibling path dep of oep_studio)
│   └── oep_studio/           Flutter desktop app — Diagram Studio, Compare, Legacy V2 bridge
├── services/
│   ├── acquisition/          C++23 / CMake — acquisition, provenance, integrity, licensing ("Trust Layer")
│   └── exchange/             npm / TypeScript workspace — OEP Exchange (OEX) distribution platform
├── knowledge/
│   └── reference_library/    Python — Engineering Reference Library (validator + compiler)
├── reference/
│   └── legacy_wiring_sim_v2/ Legacy reference wiring simulator (no build coupling to anything above)
└── docs/
    ├── MONOREPO_MIGRATION_PLAN.md            AP-REPO-001: platform/{oep_foundation,oep_engine,oep_studio}
    └── migrations/MONOREPO-INTEGRATION-001.md This migration: services/*, knowledge/reference_library
```

## Ownership and dependency rules

1. **`platform/oep_foundation`, `platform/oep_engine`, `platform/oep_studio`, `platform/oep_instruments`** form the core engineering-diagram loop. `oep_studio` depends on the other three via sibling-relative paths (Dart `path:` deps, a CMake `../../../oep_foundation` default). Nothing outside `platform/` may be pulled into this loop's source tree.
2. **`services/acquisition`, `services/exchange`, `knowledge/reference_library`** are independently-owned subsystems, each self-contained in its own language/toolchain (C++/CMake, TypeScript/npm, Python/pip respectively). They must never gain a direct source dependency on `oep_engine`, `oep_foundation`, or `oep_studio`, and those three must never depend on them.
3. **Integration is API-only.** Where `oep_studio` consumes Acquisition or Exchange, it does so through HTTP API client code under `platform/oep_studio/lib/{acquisition,exchange}/services/*_api_client.dart` — never a source import, `path:` dependency, or shared build target. `knowledge/reference_library` currently has no consumer inside this repository.
4. **`reference/legacy_wiring_sim_v2`** is reference/legacy material embedded (with explicit user authorization) directly into `platform/oep_studio`'s WebView bridge; it has no relationship to `services/` or `knowledge/`.

## Build/test entry points

| Subsystem | How to build | How to test |
|---|---|---|
| `platform/oep_studio` | `flutter build windows` (from `platform/oep_studio/`) | `flutter test` |
| `platform/oep_engine` | `dart pub get` | `dart test` |
| `platform/oep_foundation` | CMake (own `CMakeLists.txt`) | project's own CTest targets |
| `services/acquisition` | `cmake -B build && cmake --build build` (from `services/acquisition/`) | `ctest` (from the CMake build dir) |
| `services/exchange` | `npm install && npm run build` (from `services/exchange/`) | `npm run test` (vitest) |
| `knowledge/reference_library` | `pip install -e ".[dev]"` (from `knowledge/reference_library/`) | `pytest` |

Each subsystem is buildable and testable in isolation, using only its own toolchain — none require another subsystem's build to succeed first. Known current gaps (not introduced by migration, see `docs/migrations/MONOREPO-INTEGRATION-001.md`): `services/exchange` is missing its own `packages/*` workspace members and cannot fully build until the owner restores or repoints them; `services/acquisition`'s CMake build has not been verified in this environment (no `cmake` installed here).

## History

Every subsystem under `platform/`, `services/`, and `knowledge/` was imported via `git subtree add` (no `--squash`), preserving each source repository's full original commit history under its target path prefix. See `docs/MONOREPO_MIGRATION_PLAN.md` (platform/) and `docs/migrations/MONOREPO-INTEGRATION-001.md` (services/, knowledge/) for the exact mechanics and per-repo verification.
