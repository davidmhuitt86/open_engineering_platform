# @oep-exchange/core

Domain primitives and shared engineering types used across every Exchange package and app.

**Status:** Scaffolded (TASK-EXC-0001). Provides the foundational building blocks every later task needs — no upload/catalog/search domain logic lives here.

## Exports

- `Result<T, E>`, `ok()`, `err()` — explicit success/failure for expected, handled outcomes.
- `DomainError` and its subclasses (`NotFoundError`, `ValidationError`, `ForbiddenError`, `ConflictError`) — a small, stable set of error codes shared by the REST API and every service package.
- `newId()` — UUID v4 generation for new entities.
- `Clock` / `SystemClock` — an injectable time source, so later tests (publication timestamps, license expiry) don't depend on real wall-clock time.

## Dependency direction

This package depends on nothing else in the workspace. Every other package/app may depend on it.

## Naming note

Renamed from `packages/common` during TASK-EXC-0001's architectural review — "common" tends to become an unscoped dumping ground over time; "core" names what this package actually is: the domain primitives and shared engineering types every other package builds on.
