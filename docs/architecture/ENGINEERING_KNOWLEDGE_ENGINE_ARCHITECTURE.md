# ENGINEERING_KNOWLEDGE_ENGINE_ARCHITECTURE.md

Technical architecture reference for `platform/oep_engine`, frozen as of WP-EKE-008 (Engineering Knowledge Engine v1.0).

Companion document: `ENGINEERING_KNOWLEDGE_ENGINE_CONSTITUTION.md` (mission and non-negotiable principles). This document covers structure, components, and preserved decisions.

---

# 1. Layer Diagram

```
+-----------------------------------------------------------------+
|  Studio / SDKs / future Engineering AI systems (consumers)      |
+-----------------------------------------------------------------+
                              |  (Public C API / Runtime API)
+-----------------------------------------------------------------+
|  Engineering Intelligence Platform          (WP-EKE-007)        |
|    EngineeringIntelligencePlatform, KnowledgeSessionManager      |
+-----------------------------------------------------------------+
                              |
+-----------------------------------------------------------------+
|  Analysis / Reasoning                       (WP-EKE-006)        |
|    AnalysisEngine, ReasoningEngine                                |
+-----------------------------------------------------------------+
                              |
+-----------------------------------------------------------------+
|  Validation                                 (WP-EKE-005)        |
|    ValidationEngine                                               |
+-----------------------------------------------------------------+
                              |
+-----------------------------------------------------------------+
|  Rules                                      (WP-EKE-004)        |
|    RulesEngine, RuleRegistry, RuleEvaluator                       |
+-----------------------------------------------------------------+
                              |
+-----------------------------------------------------------------+
|  Query                                      (WP-EKE-003)        |
|    EngineeringQueryEngine, QueryPlanner, QueryExecutor, QueryCache|
+-----------------------------------------------------------------+
                              |
+-----------------------------------------------------------------+
|  Knowledge Graph                            (WP-EKE-002)        |
|    KnowledgeGraphEngine, KnowledgeGraph, GraphValidator,          |
|    GraphAlgorithms, GraphStatistics, GraphSerialization           |
+-----------------------------------------------------------------+
                              |
+-----------------------------------------------------------------+
|  EngineeringContext                         (WP-EKE-001)        |
|    EngineeringContext, RuntimeGraph, ObjectLoader,                 |
|    RelationshipEngine, QueryEngine, TraversalEngine                |
+-----------------------------------------------------------------+
                              |  (RuntimeService only)
+-----------------------------------------------------------------+
|  Foundation Repository        (platform/runtime, platform/repo)  |
+-----------------------------------------------------------------+
```

Each layer consumes only the layer(s) immediately beneath it. No layer skips a layer. No layer above `EngineeringContext` accesses repository storage, `RuntimeService`, or `FoundationRuntime` directly.

---

# 2. Work Package Components

**WP-EKE-001 — Engineering Knowledge Runtime.** Introduced `platform/oep_engine` itself. `RuntimeGraph` (the Engine's own in-memory graph, distinct from Foundation's `GraphEngine`), `ObjectLoader` (lazy/batch loading via `RuntimeService`), `RelationshipEngine` (parent/child/neighbor/reference/dependency classification), `QueryEngine` (id/type/domain/relationship lookup, shortest path, connected component, subgraph), `TraversalEngine` (deterministic BFS/DFS, cycle-safe), and `EngineeringContext` — the six-method facade (`load_object`/`load_graph`/`query`/`traverse`/`related_objects`/`dependency_graph`) that every layer above depends on and no layer above bypasses.

**WP-EKE-002 — Knowledge Graph Engine.** The canonical Knowledge Graph. `KnowledgeGraph` (seven maintained indexes: Object ID/Type, Knowledge Domain, Relationship Type/Direction, Publisher, Package), `GraphValidator` (`MissingEndpoint`/`DuplicateRelationship`/`SelfReference`/`BrokenReference`/`Cycle`/`InvalidRelationshipType` detection over raw, not-yet-built input), `GraphAlgorithms` (`connected_components`/`shortest_path`/`reachable`/`neighborhood`/`subgraph`/`expand_relationships`), `GraphStatistics` (`compute_statistics`: counts, density, maximum depth, average degree, distributions), `GraphSerialization` (`to_json`, `to_graphml_placeholder`), and `KnowledgeGraphEngine`, the facade. Owns the one documented algorithmic exception to O(V+E)/O(V log V) elsewhere in the Engine: `maximum_depth`/diameter is computed via BFS-from-every-node, O(V·(V+E)).

**WP-EKE-003 — Engineering Query Engine.** A deterministic lookup/filter/traversal layer over the built graph: `QueryPlanner` (side-effect-free plan construction), `QueryExecutor` (all 10 `QueryCategory` values — Object/Relationship/Domain/Type/Dependency/Neighborhood/Path/Reference/Metadata/Composite), `QueryCache` (caller-driven invalidation — no event-subscription mechanism exists anywhere in this stack), and `EngineeringQueryEngine`, the facade.

**WP-EKE-004 — Rules Engine.** The data-driven rule evaluation framework. `RuleRegistry` (in-memory register/remove/enable/disable), `RuleEvaluator` (the sole interpreter of ~10 generic condition primitives — never a specific engineering policy), `RuleEvaluationContext`, and `RulesEngine`, the facade. Central constraint: rules are data, constructed at the call site, never hardcoded logic.

**WP-EKE-005 — Validation Engine.** Executes rules against Objects, Packages, or a complete Context to produce immutable `ValidationReport`s, covering all 5 named scopes (Single Object / Multiple Objects / Complete Context / Installed Package / Arbitrary Query Result) and 5 profiles (Structural/Connectivity/Documentation/Metadata/Complete). Never embeds a rule itself — only composes `RulesEngine::evaluate_rule`. Its most architecturally significant idea is **target-narrowing composition**: every profile-selected rule is evaluated in full against its own resolved scope, then each result is narrowed to the requested target's object set, so a rule that failed overall but didn't touch the narrower target is correctly reported Passed for that target.

**WP-EKE-006 — Analysis & Reasoning Engine.** Two classes with a deliberate split. `AnalysisEngine`: four pure, deterministic structural algorithms reusing WP-EKE-002's `GraphAlgorithms`/`KnowledgeGraph` directly — `analyze_dependencies`/`analyze_impact` (transitive `DependsOn` BFS closures, outgoing/incoming), `analyze_reachability` (via `GraphAlgorithms::shortest_path`), `analyze_root_cause` (ranking a symptom's transitive dependencies present in a supplied finding set by ascending BFS depth). `ReasoningEngine`: composes Analysis + Rules + Validation into a session-scoped, temporary `EvidenceGraph`, evidence-referenced `EngineeringConclusion`s (confidence `= min(1.0, 0.5 + 0.1*evidence_count)`), and `EngineeringRecommendation`s (5 kinds, always evidence-referenced). `ReasoningEngine::analyze_root_cause(symptom_id)` is a distinct, self-validating overload from `AnalysisEngine`'s two-argument version.

**WP-EKE-007 — Engineering Intelligence Platform (EIP).** The top-level orchestration facade. `EngineeringIntelligencePlatform`, constructed from `EngineeringContext&` plus references to all six lower engines — never `RuntimeService`/`FoundationRuntime`/repository storage directly. **The central architectural decision: of nine named responsibilities (Engineering Intelligence Platform, Knowledge Session Manager, Workflow Engine, Service Orchestrator, Unified Engineering API, Context Manager, Shared Cache Manager, Runtime Metrics, Engine Pipeline), only the Knowledge Session Manager (`KnowledgeSessionManager`) was built as its own separately-instantiated public class.** Every other responsibility is realized as `EngineeringIntelligencePlatform`'s own public methods and private composition — Workflow Engine as six session-scoped methods (`inspect`/`query`/`validate`/`analyze`/`reason`/`recommend`), Service Orchestrator as eight stateless methods (`inspect_object`/`inspect_package`/`inspect_context`/`engineering_summary`/`engineering_health`/`engineering_dependencies`/`engineering_trace`/`engineering_recommendations`), Context Manager as `switch_session`/`current_session_id`/`cleanup()`, Shared Cache Manager as `invalidate_caches()`, Runtime Metrics as a `RuntimeMetrics` struct via `runtime_metrics()`. This is a deliberate reading of the Unified Engineering API principle ("a single facade... consumers should not know which engine performs the work") taken to its logical conclusion: separately-instantiated classes for each responsibility would themselves be additional "which engine performs the work" surface area for a consumer to learn.

**WP-EKE-008 — v1.0 Release & Platform Integration.** Introduces no new engine. Integrates the assembled stack behind an end-to-end pipeline test, reviews and applies targeted runtime-performance fixes (e.g. `GraphStatistics::compute_statistics` no longer calling `all_nodes()` more than once per pass), and freezes the architecture and Public API documented in this file and its seven companion documents.

---

# 3. Key Architectural Decisions Worth Preserving

- **Data-driven rules (WP-EKE-004).** The Rules Engine's condition vocabulary is fixed and generic; no engineering policy is ever hardcoded as engine logic. This is the single most important invariant in the whole Engine and must survive any future refactor.
- **Target-narrowing composition (WP-EKE-005).** `ValidationEngine` reuses `RulesEngine::evaluate_rule`'s full-scope result and narrows it per target, rather than re-implementing scope resolution per validation target. Avoids duplicated evaluation logic and keeps rule semantics in exactly one place.
- **The Analysis/Reasoning split (WP-EKE-006).** `AnalysisEngine` is pure structural graph algorithms with no notion of evidence or confidence; `ReasoningEngine` is the only place evidence graphs, conclusions, and confidence scoring exist. Keeping these separate lets `AnalysisEngine` stay trivially deterministic and testable in isolation, while `ReasoningEngine` owns the more complex evidence-composition logic.
- **Only the Session Manager gets its own class (WP-EKE-007).** See the WP-EKE-007 component description above. The consequence for future work: before adding a new "manager"-shaped class to `EngineeringIntelligencePlatform`, ask whether it's genuinely an independent, independently-testable lifecycle concern (like sessions) or whether it's better expressed as more methods on the facade.
- **The shared no-persistence / no-transactions / no-repository-storage-access boundary.** Every layer from WP-EKE-001 through WP-EKE-007 independently arrived at, and never violated, the same three boundaries: no direct repository storage access above `EngineeringContext`, no disk persistence anywhere in the Engine, no transaction management (that remains exclusively Foundation's `RuntimeService`/Transaction Engine). This is not incidental — it is the layering principle enforced consistently, work package after work package, and it is the boundary future work packages must continue to respect.
- **Caller-driven cache/graph invalidation, disclosed honestly at every layer.** Neither the Knowledge Graph (WP-EKE-002) nor the Query Cache (WP-EKE-003) update automatically when Foundation data changes elsewhere; callers must explicitly call `build_graph`/`refresh_graph`/`object_added`/`object_removed` or `clear_query_cache()`. This is because Repository Events (WP-REP-006) are publish-only with no subscribers yet — documented as a known, deliberate gap in `KNOWN_ISSUES.md`, not an oversight.

---

# 4. Module File Layout

`platform/oep_engine/include/oep/engine/*.hpp` + `platform/oep_engine/src/*.cpp`, organized by introducing work package:

| Work Package | Header(s) | Source(s) |
|---|---|---|
| WP-EKE-001 | `engineering_context.hpp`, `runtime_graph.hpp`, `object_loader.hpp`, `relationship_engine.hpp`, `query_engine.hpp`, `traversal_engine.hpp` | `engineering_context.cpp`, `runtime_graph.cpp`, `object_loader.cpp`, `relationship_engine.cpp`, `query_engine.cpp`, `traversal_engine.cpp` |
| WP-EKE-002 | `knowledge_graph.hpp`, `graph_validator.hpp`, `graph_algorithms.hpp`, `graph_statistics.hpp`, `graph_serialization.hpp`, `knowledge_graph_engine.hpp` | `knowledge_graph.cpp`, `graph_validator.cpp`, `graph_algorithms.cpp`, `graph_statistics.cpp`, `graph_serialization.cpp`, `knowledge_graph_engine.cpp` |
| WP-EKE-003 | `query_types.hpp`, `query_planner.hpp`, `query_executor.hpp`, `query_cache.hpp`, `engineering_query_engine.hpp` | `query_types.cpp`, `query_planner.cpp`, `query_executor.cpp`, `query_cache.cpp`, `engineering_query_engine.cpp` |
| WP-EKE-004 | `rule_types.hpp`, `rule_registry.hpp`, `rule_context.hpp`, `rule_evaluator.hpp`, `rules_engine.hpp` | `rule_types.cpp`, `rule_registry.cpp`, `rule_evaluator.cpp`, `rules_engine.cpp` |
| WP-EKE-005 | `validation_types.hpp`, `validation_engine.hpp` | `validation_types.cpp`, `validation_engine.cpp` |
| WP-EKE-006 | `analysis_types.hpp`, `analysis_engine.hpp`, `reasoning_types.hpp`, `reasoning_engine.hpp` | `analysis_engine.cpp`, `reasoning_types.cpp`, `reasoning_engine.cpp` |
| WP-EKE-007 | `intelligence_types.hpp`, `knowledge_session_manager.hpp`, `engineering_intelligence_platform.hpp` | `intelligence_types.cpp`, `knowledge_session_manager.cpp`, `engineering_intelligence_platform.cpp` |
| WP-EKE-008 | (none — integration/optimization only; targeted edits inside existing files, e.g. `graph_statistics.cpp`) | (targeted edits only) |

Verified directly against `platform/oep_engine/include/oep/engine/` and `platform/oep_engine/src/` (29 headers, 28 sources at the time this document was written).
