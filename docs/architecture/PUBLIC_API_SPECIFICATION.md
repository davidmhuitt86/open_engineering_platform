# PUBLIC_API_SPECIFICATION.md

Structured reference for `platform/api/include/oep/api/oep_api.h`, the Open Engineering Platform Public C API, as frozen at WP-EKE-008 (Engineering Knowledge Engine v1.0).

This document is an index and compatibility statement. It does not reproduce per-function documentation — that lives in the header itself, which remains the single source of truth for exact signatures, struct layouts, and error codes.

Verified directly from `platform/api/include/oep/api/oep_api.h` (3,277 lines) during this work package.

---

# 1. Current Version

```
OEP_API_VERSION = 19
OEP_ABI_VERSION = 1
```

`OEP_ABI_VERSION` has been `1` since WP-REP-001, the first work package in this entire multi-series session, and has never changed. `OEP_API_VERSION` reached 19 at WP-EKE-007; WP-EKE-008 introduced no new Public C API surface (it is an integration/optimization/documentation work package per its own spec's "SHALL NOT introduce new core engines" constraint), so `OEP_API_VERSION` remains 19 as of this freeze.

---

# 2. Section Index (grouped exactly as the header's own section comments group them)

| # | Section | Introduced by |
|---|---|---|
| 1 | Versioning | OEP-SPEC-021 §8 |
| 2 | Opaque handles | OEP-SPEC-021 §4 |
| 3 | Runtime state | OEP-SPEC-022 §3 |
| 4 | Error reporting | OEP-SPEC-021 §6 / OEP-SPEC-022 §4 |
| 5 | Runtime lifecycle | OEP-SPEC-021 §5 |
| 6 | Repository status | OEP-SPEC-021 §5 / OEP-SPEC-022 §5 |
| 7 | Engineering Object Enumeration | Work Package 012 (TASK-000023) |
| 8 | Repository Statistics | Work Package 012 (TASK-000024) |
| 9 | Engineering Relationship Enumeration | Work Package 013 (TASK-000025) |
| 10 | Repository Search | Work Package 013 (TASK-000026) |
| 11 | Object Mutation | Work Package 014 (TASK-000027) |
| 12 | Relationship Mutation | Work Package 014 (TASK-000028) |
| 13 | Transactions | Work Package 014 (TASK-000029); upgraded by WP-REP-003 |
| 14 | Batch Mutation | Work Package 014 (TASK-000030) |
| 15 | Package Installation | WP-REP-001 |
| 16 | Package Lifecycle Queries | WP-REP-002 |
| 17 | Repository Transaction Engine | WP-REP-003 |
| 18 | Trust & Signing | WP-REP-004 |
| 19 | Dependency Resolution | WP-REP-005 |
| 20 | Repository Events | WP-REP-006 |
| 21 | Package Lifecycle: Uninstall & Update | WP-REP-007 |
| 22 | Merge Engine | WP-REP-008 |
| 23 | Engineering Knowledge Runtime | WP-EKE-001 |
| 24 | Engineering Knowledge Graph Engine | WP-EKE-002 |
| 25 | Engineering Query Engine | WP-EKE-003 |
| 26 | Engineering Rules Engine | WP-EKE-004 |
| 27 | Engineering Validation Engine | WP-EKE-005 |
| 28 | Engineering Analysis & Reasoning Engine | WP-EKE-006 |
| 29 | Engineering Intelligence Platform | WP-EKE-007 |

WP-EKE-008 added no new section — it is documented here as the freeze point, not a new content section.

---

# 3. Function Groups by Work Package (Engineering Knowledge Engine, WP-EKE-001 through 007)

- **WP-EKE-001:** `oep_engine_load_object`, `_load_graph`, `_query`, `_traverse`, `_related_objects`, `_dependency_graph`. Reuses the existing `oep_package_id_list_t` for every id-list output.
- **WP-EKE-002:** `oep_kge_build_graph`, `_refresh_graph`, `_validate_graph`, `_graph_statistics`, `_connected_components`, `_shortest_path`, `_subgraph`, `_export_json`, `_export_graphml_placeholder`. Introduces the caller-owned-heap-string export convention released via `oep_string_release()` (the export-size-is-unbounded exception to the fixed-buffer/`*_list_t` convention used everywhere else).
- **WP-EKE-003:** `oep_eqe_plan_query`, `_execute_query`, `_query_statistics`, `_clear_query_cache`, `_query_cache_info`.
- **WP-EKE-004:** `oep_rules_register`, `_remove`, `_enable`, `_disable`, `_list_all`, `_list_enabled`, `_list_disabled`, `_get`, `_evaluate`, `_evaluate_all`. First array-of-structs input (`oep_rules_register`'s `conditions`).
- **WP-EKE-005:** `oep_validation_create_session`, `_validate_object`, `_validate_objects`, `_validate_package`, `_validate_context`, `_report`, `_statistics`.
- **WP-EKE-006:** `oep_analysis_dependencies`, `_impact`, `_reachability`, `_root_cause`; `oep_reasoning_create_session`, `_execute`, `_report`, `_get_conclusion`, `_get_recommendation`, `_get_evidence_node`.
- **WP-EKE-007:** `oep_eip_create_session`, `_resume_session`, `_clone_session`, `_close_session`, `_switch_session`, `_list_sessions`, `_get_session`, `_export_session_summary`; `oep_eip_query`, `_inspect`, `_validate`, `_analyze`, `_reason`, `_recommend`; `oep_eip_engineering_summary`, `_engineering_health`, `_engineering_recommendations`; `oep_eip_runtime_metrics`, `_invalidate_caches`, `_cleanup`.

All Engineering Knowledge Engine functions are `RuntimeService`-exclusive, reachable only via `oep_runtime_impl`'s internal engine-member chain, and valid only from the `RepositoryOpen` runtime state (confirmed by the header's own state-precondition documentation, including for the three session-independent `oep_eip_runtime_metrics`/`_invalidate_caches`/`_cleanup` functions).

---

# 4. Compatibility Guarantees

These guarantees are declared, not aspirational — every one has held across all 19 `OEP_API_VERSION` increments to date.

1. **ABI has never changed and never will change within a 1.x release.** `OEP_ABI_VERSION` has been `1` since WP-REP-001 and has never advanced. A future ABI-breaking layout change to an existing struct would require a major version bump; none has occurred through WP-EKE-008.
2. **Every API version increment has been purely additive.** New structs, new functions, new enum values have been added; no existing struct layout has ever been altered.
3. **Existing function signatures are never altered.** A function's parameter list, return type, and calling convention are fixed once released. If a function's behavior needs to change incompatibly, a new function is added instead.
4. **Fixed-size buffer struct fields may grow in a future minor version, but existing fields never shrink or change type.** Several structs in this API (e.g. session-id output buffers) use fixed-size character buffers by established convention; a future work package may widen such a buffer, but never narrow one or change its element type.
5. **Callers should check `oep_api_version()` / `oep_abi_version()` at runtime, never assume a specific version.** Both are exposed as the first functions in the Versioning section and are safe to call at any point in the runtime lifecycle.

---

# 5. Consumers

Per this API's own layering, and per `CLAUDE.md`'s platform-wide rule ("Every SDK wraps the C API. Applications consume SDKs. No Studio shall communicate directly with Runtime internals."), this header is the only supported boundary between the C++ Runtime (including the entire Engineering Knowledge Engine) and every SDK, Studio, or CLI consumer. `platform/cli` and `platform/oep_studio`'s Foundation Bridge both consume this header exclusively; no consumer links against `platform/oep_engine` internals directly.
