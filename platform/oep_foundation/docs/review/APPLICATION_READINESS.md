# APPLICATION_READINESS.md

Assessment basis: what the Foundation Runtime and Engineering Knowledge Engine backends genuinely expose today (verified via the C API and Runtime API audit), and what Studio's current FFI/UI coverage genuinely supports (verified via the Studio inspection). Not all seven named applications were independently code-audited in depth in this pass — where that is true, it is stated explicitly rather than assumed.

## Engineering Acquisition
**Backend readiness: Ready.** Package install, archive extraction, manifest parsing, trust/signing verification, and object/relationship creation are all implemented, tested, and stable behind the frozen C API — exactly what an acquisition pipeline (bringing external engineering standards/data into a repository) needs.
**Studio readiness: Partially ready.** `oep_studio/lib/knowledge/` (123 files) is the largest single Studio feature area and appears to already implement much of an acquisition workflow (OCR pipeline service, source viewer, import queue panel, entity review), but a significant fraction of its dialog surface (8+ dialogs) explicitly renders a shared placeholder widget rather than final content, per this review's technical debt scan. **Verdict: buildable now for backend-driven acquisition; the existing Studio acquisition UI needs a completion pass, not a restart.**

## Engineering Exchange
**Backend readiness: Partially ready, with a documented gap.** Package registry, dependency resolution, trust verification, and merge/update/uninstall are all implemented in Foundation. However, "Exchange" as a distribution/marketplace concept lives in a **separate, unaudited repository** (`oep_exchange`, Node/TS) with its own REST API — and this review's API audit found that repository's own architecture-assessment document self-reports at least one REST client call (`HttpRepositoryClient`'s install endpoint) with **no corresponding server implementation anywhere in the monorepo**. This is a real, documented gap in Exchange's own codebase, not a Foundation Runtime problem.
**Studio readiness**: `oep_studio/lib/exchange/` exists (22 files) but was not independently deep-audited this pass. **Verdict: Foundation's package/trust/dependency primitives are ready to support Exchange; the Exchange service itself has a known, self-disclosed incomplete client/server pairing that should be resolved before treating Exchange as launch-ready.**

## OEP Studio
**Readiness: Structurally ready, unevenly complete.** Studio's core architecture (routing/`StudioDestination`/`StudioRegistry` conventions, theming, FFI bridge pattern, Riverpod state management) is consistent and was successfully extended by the new Engineering Intelligence pages with no new patterns introduced — a good sign for maintainability. But roughly half of Studio's currently-visible feature surface (Graph page, Packages page, most Knowledge Studio dialogs, several Settings sub-pages, and now the new read-only Engineering Intelligence pages) is placeholder, partial, or explicitly non-interactive. **Verdict: Studio-the-shell is production-grade; Studio-the-application is a partially-furnished house.**

## Engineering Explorer
Not found as a distinct, separately-named module or Studio page anywhere in this inspection — closest existing analogue is the new `engineering_intelligence/pages/engineering_explorer_page.dart` (one of the 8 WP-EKE-008 pages), which is real but read-only and only smoke-tested. **Verdict: if "Engineering Explorer" is meant to be its own standalone application distinct from the Engineering Intelligence Studio's Explorer page, it does not yet exist and would be new work, not a rename. If it refers to the existing page, it is functionally present but shallow (no automated interaction coverage, no editing).**

## Diagram Studio
`oep_studio/lib/diagram_studio/` exists (27 files: ai, commands, host, inspector, panels, persistence, settings, toolbars, workspaces) — a real, non-trivial subtree, but it was **not independently code-audited in this pass** beyond confirming its existence and rough size. **Verdict: cannot be certified ready or not-ready without a dedicated follow-up review of this specific subtree — flagged honestly as unverified rather than assumed complete.**

## Diagnostic Studio
**No directory, module, or reference to "Diagnostic Studio" was found anywhere in either `oep_foundation` or `oep_studio` during this inspection.** **Verdict: Not started. This would be new application-layer work built on top of the Analysis/Reasoning engines (which are ready to support diagnostic-style root-cause/impact queries), but no Studio-side scaffold exists yet.**

## Engineering AI
**No external AI integration exists anywhere in the audited codebase**, and this is by explicit, repeated architectural design: every engine from WP-EKE-004 through WP-EKE-008 documents itself as "never calls external AI services," with `docs/architecture/FUTURE_ROADMAP_V2.md` naming external AI integration as speculative v2 territory, not committed work. `ReasoningEngine`'s "conclusions" and "recommendations" are deterministic evidence-weighted arithmetic (`confidence = min(1.0, 0.5 + 0.1*evidence_count)`), not AI-derived. **Verdict: Not started, and deliberately so.** The reasoning/evidence infrastructure (`EvidenceGraph`, `EngineeringConclusion`, referenced rules/findings/objects) is a genuinely strong foundation for a future AI layer to consume as grounding — but building "Engineering AI" today would mean starting the AI-integration architecture from zero; nothing in the current stack calls or is designed around any model.

## Summary table

| Application | Backend | Studio/UI | Overall verdict |
|---|---|---|---|
| Engineering Acquisition | Ready | Partial (placeholder dialogs) | Buildable now, needs Studio completion pass |
| Engineering Exchange | Partial (self-disclosed client/server gap in `oep_exchange`) | Not deep-audited | Needs the Exchange repo's own gap closed first |
| OEP Studio (the shell) | N/A | Structurally ready, content uneven | Ready as a shell; not as a finished product |
| Engineering Explorer | Ready (via EIP) | Exists, read-only, shallow tests | Present but shallow — clarify scope before committing |
| Diagram Studio | Not assessed this pass | Exists (27 files), not deep-audited | Unverified — needs its own review |
| Diagnostic Studio | Ready (Analysis/Reasoning engines) | **Does not exist** | Not started |
| Engineering AI | Not started (by design) | Not started | Not started — genuinely greenfield |
