# API_AUDIT.md

Classification: **Stable** (safe to build on as-is) / **Needs Cleanup** (works, but has a known inconsistency worth fixing) / **Deprecated** (should not be used for new work) / **Future Candidate** (named/expected but not yet built).

## Runtime API (C++)

| Facade | Classification | Notes |
|---|---|---|
| `RuntimeService` | **Stable** | Consistent `{success, error}` Response-struct convention throughout, except `begin_transaction`/`commit_transaction`/`rollback_transaction` (no request struct — inconsistent with its own pattern) and `events()` (documented as an intentional exception to the "one call, one sequence" rule). |
| `EngineeringContext` | **Needs Cleanup** | Functionally solid; uses a different result-struct convention than `RuntimeService` (mutable-default `{success=false, error}` vs. immutable Response types) — a caller moving between the two layers has to context-switch conventions. |
| `KnowledgeGraphEngine` | **Needs Cleanup** | Mixes four different result conventions within one class (`bool`, `void`, raw `std::string`, `{success,error}` struct). Functionally complete; the inconsistency is purely ergonomic/cognitive. |
| `EngineeringQueryEngine` | **Stable** | Clean, consistent, well-scoped surface. |
| `RulesEngine` | **Needs Cleanup** | Mixes plain `bool` (register/remove/enable/disable) with `std::optional<T>` (evaluate). |
| `ValidationEngine` | **Stable** (internally consistent) | Uniform `std::optional<T>` convention throughout. |
| `AnalysisEngine` | **Stable**, but **under-tested** | API surface is clean; flagged separately in Test Coverage for having no dedicated unit test file. |
| `ReasoningEngine` | **Needs Cleanup** | `analyze_root_cause` name reused with a different arity/contract than `AnalysisEngine`'s method of the same name — a real trap for callers. |
| `EngineeringIntelligencePlatform` | **Needs Cleanup** | Largest constructor in the stack (7 references); "Workflow" methods and "Service Orchestrator" methods overlap in function under different names/signatures — genuinely usable today, but the dual-surface design should be reviewed before it's extended further. |

**Overall Runtime API verdict**: every facade is functionally stable and shipped — nothing here is broken — but there is no single, class-independent error-handling or ownership convention across the 9 classes. This is worth a deliberate cleanup pass specifically because the API is now frozen for v1.0; fixing it later means a breaking change, fixing it now (before wider external adoption) is comparatively cheap.

## Public C API

**Classification: Stable, with one Needs-Cleanup item and one Deprecated-in-spirit item.**

- `OEP_API_VERSION` 19, `OEP_ABI_VERSION` 1 — genuinely, verifiably unchanged/additive-only across the entire session (directly confirmed by header inspection). This part of the audit's job — verifying the freeze claim — checks out.
- 166 functions across a consistent `oep_<subsystem>_<verb>` shape, but subsystem tokens themselves are inconsistent (full words vs. acronyms vs. singular/plural split) — **Needs Cleanup**, cosmetic/documentation-level, not a functional risk given the freeze.
- Four coexisting ownership/return conventions (list+release, generic string-release, fixed output buffer, static no-release strings) — **Needs Cleanup**. Each is internally consistent; the API as a whole is not self-describing about which applies where without consulting documentation per-function.
- `oep_kge_export_graphml_placeholder` — **Deprecated-in-spirit / should not be built upon**. It is live, versioned, and callable, but its own name and documentation say it is a placeholder. Treat any current consumer of this function as consuming an interface that WILL change shape once real GraphML support is built — flag it now rather than let it quietly become load-bearing.
- No function in the 166 was found to be genuinely deprecated (marked for removal) — the API has only ever grown.

## Studio FFI (Dart)

**Classification: Needs Cleanup (functional gap), otherwise Stable.**

- 158 of 166 C functions have Dart bindings; the mapping from C name to Dart method name is mechanically consistent (no exceptions found in the sample reviewed) — the binding *pattern* itself is stable and trustworthy.
- **Missing bindings** (Needs Cleanup, functionally a real gap not just a style issue): `oep_object_update`, `oep_object_delete`, `oep_relationship_update`, `oep_relationship_delete`, `oep_batch_create_objects` (+ its release fn), `oep_batch_create_relationships` (+ its release fn), `oep_trust_state_to_string`. The first six represent a genuine capability gap (no update/delete/batch-create path from Studio); the seventh is a minor, low-impact omission (a to-string convenience helper).

## CLI

**Classification: Stable, with two Needs-Cleanup naming items.**

- 28 top-level command groups, each backed by dedicated tests (21 CLI test files), dispatch logic is simple and centralized (`CommandRegistry` in an 85-line `main.cpp`).
- `package` vs `packages` and `validate` vs `evalidate` — **Needs Cleanup**: real user-facing ambiguity, not a functional defect (both pairs work correctly and are separately tested), but worth resolving via rename/alias before the CLI's surface grows further and the collision risk compounds.
- No dedicated top-level command exists for `KnowledgeGraphEngine` or `EngineeringQueryEngine` specifically (reachable only through `graph`/`search`/`inspect`/`workflow`) — **Future Candidate**, not a defect: acceptable as-is, worth reconsidering if either engine's CLI usage grows.

## REST APIs

**Classification: Not applicable to `oep_foundation`/`oep_studio` — Stable-by-absence (deliberate architectural decision, confirmed, not accidental).** Zero REST/HTTP server code exists in either audited repository; the C API is explicit that "Network APIs. Remote Foundation." are out of scope by specification. The one REST API found anywhere in the broader monorepo belongs to the separate, unaudited `oep_exchange` repository, and that repo's own documentation self-reports at least one client call with no matching server route — **Needs Cleanup / possibly Deprecated-on-arrival**, but this is `oep_exchange`'s issue, outside this review's core scope, and should be independently audited before Exchange work resumes.

## Summary table

| Surface | Overall |
|---|---|
| Runtime API (C++) | Stable, functionally — Needs Cleanup on cross-class convention consistency |
| Public C API | Stable and genuinely frozen — Needs Cleanup on naming/ownership consistency — one function (GraphML export) should not be treated as stable |
| Studio FFI | Needs Cleanup — real functional gap (mutation/batch-create unbound) |
| CLI | Stable — Needs Cleanup on two naming collisions |
| REST | Not present in Foundation/Studio by design (Stable-by-absence); the one REST surface in the wider monorepo (`oep_exchange`) is out of this review's scope and self-reports its own gap |
