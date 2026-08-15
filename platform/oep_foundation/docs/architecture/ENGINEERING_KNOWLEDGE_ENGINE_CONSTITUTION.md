# ENGINEERING_KNOWLEDGE_ENGINE_CONSTITUTION.md
## Open Engineering Platform (OEP)
### Engineering Knowledge Engine Constitution

**Version:** 1.0
**Status:** Ratified
**Authority:** Divad Technology Group (subordinate to, and never in conflict with, `CLAUDE.md`)

---

# Welcome

Welcome to the Engineering Knowledge Engine (`platform/oep_engine`).

Before writing a single line of code inside this module, understand that you are not building a data layer.

You are building the part of the Open Engineering Platform that turns stored engineering data into engineering *knowledge*: queryable, validatable, analyzable, explainable, and trustworthy.

If a proposed change conflicts with this document, this document takes precedence unless explicitly amended following the same authority that governs `CLAUDE.md` itself.

This document is scoped to `platform/oep_engine` alone. `CLAUDE.md` remains the constitution of the whole platform and is never superseded by anything written here.

---

# Mission

The Engineering Knowledge Engine exists to provide deterministic, evidence-based, explainable engineering knowledge services on top of the Foundation Repository.

Foundation stores engineering data. The Engineering Knowledge Engine reasons about it.

Every conclusion the Engine produces must be traceable to evidence. Every answer must be reproducible. Nothing the Engine says should ever be a guess.

This mission was stated, in nearly these words, at every layer built beneath it: WP-EKE-004's rules are "data, not code"; WP-EKE-005's validation reports are composed, never invented; WP-EKE-006's conclusions and recommendations are always evidence-referenced, with confidence computed by fixed deterministic arithmetic, never estimated. WP-EKE-008 changes none of this — it integrates, optimizes, and freezes it.

---

# The Layering Principle

The Engineering Knowledge Engine is built as eight strict layers, each consuming only the layer(s) immediately beneath it:

```
Foundation Repository
        |
EngineeringContext            (WP-EKE-001)
        |
Knowledge Graph                (WP-EKE-002)
        |
Query                          (WP-EKE-003)
        |
Rules                          (WP-EKE-004)
        |
Validation                     (WP-EKE-005)
        |
Analysis / Reasoning           (WP-EKE-006)
        |
Intelligence Platform          (WP-EKE-007)
        |
Studio / SDKs / future AI      (consumers, not part of the Engine)
```

No layer skips a layer. No layer above `EngineeringContext` touches repository storage directly. No layer reaches sideways into a layer's private internals — every dependency is expressed through a layer's own public class(es) and public methods.

This mirrors, at a smaller scale, `CLAUDE.md`'s own platform-wide layering principle ("Operating System -> Filesystem -> Repository -> Runtime -> Public API -> SDK -> Flutter -> Studios. Each layer communicates only with adjacent layers. No shortcuts."). The Engineering Knowledge Engine is not exempt from that discipline; it is a worked example of it.

---

# Non-Negotiable Principles

## No Hardcoded Engineering Rules

No engineering policy, standard, or check shall ever be written as `if`/`else` logic naming a specific rule inside the Engine's own source code.

`RuleEvaluator` (WP-EKE-004) contains only a fixed, small vocabulary of generic condition primitives (`RequiresRelationship`, `ForbidsRelationship`, `MinRelationshipCount`, `MaxRelationshipCount`, `RequiresTag`, `ForbidsTag`, `HasDescription`, `HasAuthor`, `NoCycles`, `NoIsolatedObjects`). Every actual engineering policy is constructed as *data* — an `EngineeringRule` value — at the call site: CLI flags, Public C API struct input, or a future rule-loading mechanism.

This is the Engineering Knowledge Engine's version of PKG-004's data-driven discipline, carried consistently from WP-EKE-004 through every layer above it. `ValidationEngine` never embeds a rule. `AnalysisEngine`/`ReasoningEngine` never embed a rule. `EngineeringIntelligencePlatform` never embeds a rule. If a future engineer is tempted to special-case a named engineering standard inside any `.cpp` file in this module, that is a constitutional violation and must be rejected.

## Deterministic and Reproducible, Everywhere

Every computation the Engine performs — graph traversal, query execution, rule evaluation, validation, dependency/impact/reachability/root-cause analysis, reasoning, confidence scoring, health scoring — is pure, deterministic arithmetic or deterministic graph algorithm over already-known input.

Two independent Engine instances constructed against the same underlying data must produce byte-identical results. This is not an aspiration; it is a tested invariant at every layer (WP-EKE-003 through WP-EKE-007 each carry at least one dedicated determinism test, and WP-EKE-008's end-to-end test proves it holds across the full assembled pipeline).

Confidence and health are never probabilistic estimates. `EngineeringConclusion` confidence is `min(1.0, 0.5 + 0.1 * evidence_count)`. `EngineeringHealthReport` score is `100 * passed / (passed + failed)`, defaulting to 100 when nothing was evaluated. Both are fixed formulas, not model outputs.

## Every Conclusion and Recommendation Is Evidence-Referenced

`EngineeringConclusion` and `EngineeringRecommendation` (WP-EKE-006) must never carry an empty `supporting_evidence_ids` list. This is an enforced, tested invariant, not a convention. A conclusion or recommendation with no evidence is not a lesser conclusion — it is a bug.

Findings, conclusions, and recommendations must be traceable back to the rule, query, or graph fact that produced them. A future engineer extending the Reasoning Engine must preserve this traceability, not summarize it away.

## No AI or External Service Calls

The Engineering Knowledge Engine never calls an external AI model, external service, or network endpoint of any kind. Every result is computed locally, deterministically, from data already loaded through `EngineeringContext`.

This does not foreclose future AI integration at a *higher* layer (WP-EKE-007's own spec names "future Engineering AI systems" as a consumer of the Intelligence Platform, sitting above it, not inside it). The Engine itself, at every layer through WP-EKE-008, remains AI-free by design.

## No Persistence Above Foundation

Nothing in `platform/oep_engine` writes to disk. `KnowledgeSession`s, `RuntimeMetrics`, validation/reasoning sessions, and every cache are in-memory and process-local, discarded when the owning handle goes away. Persistence, if it is ever needed for long-lived sessions, belongs to a future work package and a future, explicitly-designed mechanism — never a silent addition inside an existing layer.

## Never Touch Repository Storage Directly Above EngineeringContext

Every layer from the Knowledge Graph upward reads engineering data exclusively through `EngineeringContext`'s public API. No layer above `EngineeringContext` holds a `RuntimeService`, `FoundationRuntime`, or repository-storage reference of its own. This boundary has held, unbroken, across all eight WP-EKE work packages and must continue to hold.

---

# Things Never To Do (Engineering Knowledge Engine-specific)

In addition to everything `CLAUDE.md` already forbids platform-wide:

- Never hardcode an engineering rule, standard, or policy inside Engine source code.
- Never let a layer skip a layer (e.g., `ReasoningEngine` reaching into `KnowledgeGraph` directly instead of through `AnalysisEngine`/`QueryEngine`).
- Never produce a conclusion, recommendation, or finding without evidence.
- Never introduce non-determinism (wall-clock-seeded randomness, unordered-container iteration order leaking into output, floating-point accumulation order dependent on thread scheduling).
- Never call an external AI model or network service from within the Engine.
- Never persist Engine state to disk without an explicit, separately-ratified architectural decision.
- Never bypass the Engineering Intelligence Platform from Studio, SDKs, or any other consumer once a suitable EIP entry point exists — the Unified Engineering API principle ("consumers should not know which engine performs the work") is binding on callers, not just on the Engine's own internals.

---

# Definition of Done (Engineering Knowledge Engine-specific)

A change to `platform/oep_engine` is complete only when, in addition to `CLAUDE.md`'s platform-wide Definition of Done:

- No new engineering rule or policy was hardcoded anywhere in the change.
- Every new computation is deterministic and covered by a determinism test where two independent instances/invocations can meaningfully diverge.
- Every new conclusion/recommendation/finding type carries non-empty evidence by construction.
- The layering diagram above still holds — no new shortcut was introduced.
- The full CTest regression suite still passes.
- `OEP_API_VERSION` was incremented if and only if the Public C API surface grew, and `OEP_ABI_VERSION` was left unchanged unless an existing struct's memory layout was genuinely altered (which, as of WP-EKE-008, has never happened).

---

# The Standard

Every line of code inside `platform/oep_engine` should move the Engineering Knowledge Engine closer to being a trustworthy, explainable reasoning layer that any future engineer, Studio, SDK, or engineering AI system can rely on without re-deriving its own answer.

If a decision improves determinism, evidence traceability, or layering discipline, it is likely the correct decision.

When in doubt, choose the solution that keeps every answer explainable and every layer boundary intact.

Remember:

**We are not building a query engine.**

**We are building the part of the platform that makes engineering knowledge trustworthy enough to act on.**
