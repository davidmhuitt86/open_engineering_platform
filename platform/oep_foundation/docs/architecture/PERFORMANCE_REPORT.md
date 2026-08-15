# PERFORMANCE_REPORT.md

WP-EKE-008 Performance Report — Engineering Knowledge Engine v1.0.

All figures in this report were measured directly in this session; none are estimated or carried over from prior work package narration.

---

# 1. End-to-End Pipeline Timing

Measured by running `./tests/engine/oep_end_to_end_workflow_tests` directly (WSL, `.scratch_build/wprep006` build):

```
(end-to-end pipeline completed in 31.8595 ms)
```

This covers the full nine-step pipeline: synthetic archive build, Repository Install, `EngineeringContext` graph load, Knowledge Graph build, a query, a rule registration plus context-wide validation, dependency analysis, a reasoning workflow, recommendation generation, and the four Studio-visualization-equivalent calls (`engineering_summary`, `engineering_health`, session inspection, `runtime_metrics`). This is a single-process, in-memory, small-fixture measurement (3 objects, 2 relationships) — it demonstrates the pipeline is not pathologically slow when integrated end to end, not a benchmark against a realistic-scale repository.

---

# 2. Full Regression Suite Timing

Measured by running `ctest` inside `.scratch_build/wprep006` for the full 62-suite registration:

```
95% tests passed, 3 tests failed out of 62
Total Test time (real) = 9.31 sec
```

The 3 apparent failures in that particular run were a transient WSL9P "text file busy" filesystem flake (different tests failed on different runs; each failing test passed independently when re-run standalone), not real test or performance regressions — see `INTEGRATION_REPORT.md` §3 and `VALIDATION_REPORT.md` for detail. A separate clean run reported all registered suites passing individually. Total suite wall time is consistently in the single-digit-seconds range for all 62 executables combined.

---

# 3. Algorithmic Complexity Characterization

The Engineering Knowledge Engine uses deterministic, well-understood graph algorithms throughout:

- Index lookups (`KnowledgeGraph`'s seven maintained indexes) are O(1)/O(log n) amortized.
- `GraphAlgorithms::connected_components`, `shortest_path`, `reachable`, `neighborhood`, `subgraph`, `expand_relationships` are standard O(V+E) or O(V log V + E) graph traversals (BFS/DFS/Dijkstra-shaped, depending on the specific algorithm).
- `EngineeringQueryEngine`'s ten query categories resolve to index lookups or bounded traversals; only `Metadata`/`Composite` categories are full scans, and those are documented as such.
- `RuleEvaluator`'s condition primitives resolve via `KnowledgeGraph`'s existing indexes; graph-level conditions (`NoCycles`/`NoIsolatedObjects`) are checked once per evaluation, not once per scoped object.
- `AnalysisEngine`'s four algorithms (`analyze_dependencies`/`analyze_impact`/`analyze_reachability`/`analyze_root_cause`) all reuse `GraphAlgorithms`/`KnowledgeGraph` directly rather than re-implementing traversal, inheriting the same O(V+E)-class bounds.

**The one documented exception:** `GraphStatistics::compute_statistics`'s `maximum_depth`/diameter computation runs BFS from every node to find eccentricity, an O(V·(V+E)) algorithm. This has been true since WP-EKE-002 and remains true after this work package's performance review — it is acceptable for realistic repository sizes (engineering repositories are not expected to reach graph sizes where this becomes the dominant cost) and is called out explicitly in `KNOWN_ISSUES.md` rather than left as an undocumented surprise for a future engineer profiling the Engine.

---

# 4. Runtime Performance Review

A performance review pass over `platform/oep_engine` was performed as part of this work package's Runtime Optimization responsibility. One concrete, verified change from that pass:

**`platform/oep_engine/src/graph_statistics.cpp`, `compute_statistics()`:** `KnowledgeGraph::all_nodes()` rebuilds and returns a new `std::vector` on every call — an O(V) allocation-and-copy. Prior to this fix, `compute_statistics()` called it multiple times per pass; the function now calls it exactly once and reuses the resulting vector for both the maximum-depth loop and (implicitly) any other per-node work in the same function, verified directly in the current source:

```cpp
// all_nodes() rebuilds and returns a new vector on every call (O(V)); the
// result is invariant for the remainder of this function, so it is
// computed once and reused below instead of being requested twice more.
const std::vector<const KnowledgeGraphNode*> nodes = graph.all_nodes();
```

This is the one specific, source-verified change confirmed in this session. No other specific performance change under `platform/oep_engine/` was independently verified by this session beyond what is documented above — if additional changes were made by a separate concurrent performance-review effort, they should be enumerated here by diffing against the pre-WP-EKE-008 state before this report is treated as exhaustive.

---

# 5. Honest Summary

- The measured end-to-end pipeline time (~32 ms) and full-suite wall time (~9-10 seconds for 62 executables) show no evidence of a performance problem at the Engine's current, small-fixture test scale.
- The algorithmic profile is deterministic O(V+E)/O(V log V) throughout, with one explicitly documented O(V·(V+E)) exception (`GraphStatistics` diameter computation).
- No large-scale (thousands-to-millions of objects) load or stress testing was performed or verified in this session; this report describes correctness-scale measurements, not a capacity benchmark. A future work package should establish a realistic-scale performance baseline if the Engine is expected to operate against repositories significantly larger than the current test fixtures.
