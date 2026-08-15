# FUTURE_ROADMAP_V2.md

Speculative, non-committal notes on what a hypothetical Engineering Knowledge Engine v2 might explore. Nothing in this document is a promise, a plan already in motion, or an approved scope. It exists so a future engineer starting v2 planning has a starting point drawn directly from `KNOWN_ISSUES.md` and from WP-EKE-007's own explicit framing of the Intelligence Platform's consumers.

---

# Possible Directions

**External Engineering AI integration.** WP-EKE-007's own spec text names "future Engineering AI systems" as a consumer of the Intelligence Platform, sitting above it. Every v1 work package (WP-EKE-001 through WP-EKE-008) deliberately excluded any external AI or network call from inside the Engine itself. A v2 might explore how an AI system would consume `EngineeringIntelligencePlatform`'s deterministic outputs (summaries, health reports, evidence-referenced conclusions and recommendations) as grounding input — without ever pulling AI calls into the Engine's own deterministic core. This would need its own architectural review; the "no AI calls inside the Engine" boundary in `ENGINEERING_KNOWLEDGE_ENGINE_CONSTITUTION.md` should not be casually revisited.

**Repository-event-driven live cache/graph invalidation.** `KNOWN_ISSUES.md` #4 describes the current caller-driven limitation: the Knowledge Graph and Query Cache never learn about a Foundation mutation automatically, because Repository Events (WP-REP-006) are publish-only with no subscriber mechanism. A v2 might explore adding a subscription mechanism to `EventBus` and wiring the Knowledge Graph Engine / Query Cache to subscribe and self-invalidate, making the current explicit `refresh_graph()`/`clear_query_cache()` calls automatic rather than caller-driven. This would be a meaningful architectural addition to WP-REP-006's own scope, not a small tweak.

**A richer, pluggable rule condition language.** `KNOWN_ISSUES.md` #5 notes the fixed ~10-primitive condition vocabulary. A v2 might explore a small, still-auditable expression language (comparisons, boolean composition, perhaps numeric-field predicates) while preserving the core "rules are data, never hardcoded engine logic" constitutional principle — the goal would be more expressiveness without reopening the door to hardcoded, rule-specific engine logic.

**Persistence for long-lived sessions, if a real use case emerges.** Every session type in v1 (Rules, Validation, Reasoning, Intelligence Platform) is in-memory and process-local by design. If a genuine product need for a session that survives a process restart or is shared across processes emerges, a v2 might explore an explicit, separately-designed persistence mechanism — deliberately not a silent addition to any existing engine, since "no persistence above Foundation" is a constitutional principle of the current architecture, not an accident.

**Studio UI completion.** Independent of any v2 architectural work, the eight Studio pages named in WP-EKE-008's own spec (Engineering Explorer, Knowledge Graph Explorer, Query Console, Validation Dashboard, Analysis Dashboard, Reasoning Dashboard, Recommendation Panel, Knowledge Session Manager UI) are not confirmed complete as of this v1.0 freeze — see `KNOWN_ISSUES.md` #10. Finishing that work is not itself a "v2" concern, but it is a prerequisite that should be resolved before treating Engine v1.0 as fully consumable by end users.

**Realistic-scale performance benchmarking.** `PERFORMANCE_REPORT.md` §5 notes that all v1 measurements are correctness-scale, not capacity benchmarks. If the Engine is expected to operate against significantly larger repositories, a v2 (or an earlier maintenance pass) might establish a proper large-scale performance baseline, and revisit whether `GraphStatistics`'s O(V·(V+E)) diameter computation needs a faster approximation at that scale.

---

# Explicitly Not Part of This Roadmap

This document does not propose new core engines beyond the seven already built (Knowledge Graph, Query, Rules, Validation, Analysis, Reasoning, Intelligence Platform). It does not propose graph editing in the Knowledge Graph Explorer. It does not propose relaxing any of the Constitution's non-negotiable principles (no hardcoded rules, determinism everywhere, evidence-referenced conclusions, no AI calls inside the Engine, no persistence above Foundation) — any of the above directions that would touch one of those principles would need its own explicit ratification, the same way the v1 series' own boundaries were ratified work package by work package.
