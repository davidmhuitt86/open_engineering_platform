# KNOWN_ISSUES.md

Documented, deliberate scope limitations across the Engineering Knowledge Engine series (WP-EKE-001 through WP-EKE-008). This is not a bug tracker. Everything listed here is an intentional gap, disclosed at the work package that introduced it, not an oversight discovered later.

---

# 1. Sessions Are In-Memory / Process-Local Only

Every session-based engine — Rules (`RuleRegistry`), Validation (`ValidationSession`), Reasoning (`ReasoningSession`), and the Intelligence Platform (`KnowledgeSession`) — holds state purely in memory, scoped to the owning process/handle. There is no persistence, no cross-invocation continuity, and no cross-process sharing. A CLI invocation of `oep session create` / `oep rules register` / `oep evalidate` / `oep reasoning execute` starts from a fresh, empty engine every time. This is by design, disclosed explicitly at WP-EKE-004 and carried forward unchanged through WP-EKE-007.

# 2. The Shared Cache Manager Coordinates Only the Query Engine's Cache

`EngineeringIntelligencePlatform::invalidate_caches()` clears WP-EKE-003's `QueryCache` — the only lower engine that maintains an actual cache today. The Knowledge Graph Engine, Analysis Engine, and Reasoning Engine always compute fresh on every call; there is no cache to invalidate for them. This was documented honestly at WP-EKE-007 rather than presented as a fabricated multi-cache coordination mechanism.

# 3. GraphStatistics's Diameter Computation Is O(V·(V+E))

`GraphStatistics::compute_statistics()`'s `maximum_depth` field is computed via BFS-from-every-node (eccentricity per node, then max), which is O(V·(V+E)) rather than a faster approximate-diameter algorithm. This has been true since WP-EKE-002. It is acceptable for realistic engineering-repository graph sizes and is the one explicitly documented exception to the deterministic O(V+E)/O(V log V) algorithmic profile used everywhere else in the Engine (see `PERFORMANCE_REPORT.md` §3).

# 4. No Automatic Change Detection in the Knowledge Graph Engine

The Knowledge Graph Engine has no mechanism to detect Foundation-side mutations automatically. After any repository mutation, a caller must explicitly call `build_graph()`/`refresh_graph()` or the incremental `object_added`/`object_removed`/`relationship_added`/`relationship_removed` methods to keep the graph synchronized. The Query Engine's cache carries the identical limitation — `clear_query_cache()` must be called by the caller after any graph rebuild.

The underlying reason: Repository Events (WP-REP-006) are publish-only. `EventBus` exists and is fully functional for publishing, but no subscriber/callback mechanism has ever been built anywhere in this codebase. This is disclosed as an honest architectural limitation at WP-EKE-002 and remains true through WP-EKE-008 — automatic, event-driven graph/cache invalidation was never in scope for any WP-EKE work package.

# 5. RulesEngine's Condition Vocabulary Is a Fixed ~10 Primitives

`RuleConditionKind` has exactly ten values (`RequiresRelationship`, `ForbidsRelationship`, `MinRelationshipCount`, `MaxRelationshipCount`, `RequiresTag`, `ForbidsTag`, `HasDescription`, `HasAuthor`, `NoCycles`, `NoIsolatedObjects`). This is not a general-purpose expression language — there is no way to express arbitrary boolean logic, arithmetic comparisons on numeric fields, or cross-object correlation beyond what these ten primitives support. This is a deliberate scope boundary from WP-EKE-004, preserving the "rules are data, never hardcoded engine logic" principle by keeping the primitive set small and auditable, at the cost of expressiveness.

# 6. `oep_eip_engineering_recommendations` Returns Message Strings, Not Full Recommendation Objects

At the Public C API boundary, `oep_eip_engineering_recommendations` reuses `oep_package_id_list_t` to return recommendation message strings only, because the underlying `EngineeringIntelligencePlatform::engineering_recommendations` call creates an ephemeral internal `ReasoningSession` that is never exposed and never independently queryable afterward. A caller wanting full `EngineeringRecommendation` objects (with evidence ids, referenced rules, referenced objects) must drive `oep_reasoning_create_session`/`_execute`/`_recommendations`/`_get_recommendation` directly over their own session instead. Documented at WP-EKE-007.

# 7. Evidence Graph Exposure at the C Boundary Is Minimal

`oep_reasoning_get_evidence_node` fetches a single evidence node by id; there is no C-boundary function to enumerate an entire `EvidenceGraph`. Full evidence graph traversal requires the C++ `ReasoningEngine` API directly. Documented at WP-EKE-006.

# 8. Reasoning Session State Ambiguity at the C Boundary

`oep_reasoning_report`/`_get_conclusion`/`_get_recommendation`/`_get_evidence_node` cannot distinguish "session was never created" from "session was created but `execute()` was never called" — both map to `OEP_ERROR_NOT_FOUND`. This is specific to `ReasoningEngine`'s explicit two-step create-then-execute flow (unlike `ValidationEngine`, which finalizes its session within a single `validate_*` call). Documented at WP-EKE-006 as a known ambiguity, not a residual defect.

# 9. `oep_validation_validate_query_result` Has No C-Boundary Equivalent

Callers at the C API boundary wanting to validate an arbitrary query result must compose `oep_eqe_execute_query` + `oep_validation_validate_objects` themselves; there is no single combined function. The C++ `ValidationEngine::validate_query_result` exists and is fully supported, but was deliberately not mirrored at the C boundary. Documented at WP-EKE-005.

Item 10 (Studio Integration for WP-EKE-008's eight named pages) was removed from this list: all eight pages were subsequently verified present under `platform/oep_studio/lib/engineering_intelligence/`, routed, `flutter analyze`/`flutter test` clean — see `INTEGRATION_REPORT.md` §2 for the delivered-and-verified record.
