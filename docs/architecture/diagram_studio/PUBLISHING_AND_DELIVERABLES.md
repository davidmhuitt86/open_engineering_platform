# Diagram Studio — Engineering Publishing & Deliverables

**Architecture Phase:** AP-DS-004. Covers the spec's Publishing Guide / Print Guide / Template Guide / Exchange Preparation Guide documentation requirements in one coherent document, following AP-DS-003's `ENGINEERING_WORKSPACE.md` precedent of consolidating related integration docs rather than fragmenting them.

## What changed

Diagram Studio gained a complete publishing pipeline: professional PDF/SVG/PNG diagram export, print preview, six tabular engineering reports (BOM, Wire, Connector, Harness, Relationship, Engineering Object), Validation/Reasoning reports sourced exclusively from the Engineering Intelligence Platform, title blocks and revision management, an Engineering Exchange readiness checklist (preparation only — no networking or upload), and a minimal template-preset system.

## The one rule this phase enforces throughout

**Publishing never computes engineering data itself.** Every deliverable is either (a) a direct rendering of `EngineeringGraph`/`DiagramLayoutState` data that already exists (drawings, BOM, wire/connector/harness/relationship/object reports), or (b) a rendering of a result already computed by the Engineering Intelligence Platform, reached exclusively through `DiagramIntelligenceService` (Validation Reports, Reasoning Reports). No validation rule, analysis algorithm, or reasoning step is implemented in the publishing system.

## Architecture: where things live and why

```
oep_engine (no Foundation/FFI dependency — pure Dart, reusable by any future consumer)
├── core/publishing/models/title_block.dart        — TitleBlock, RevisionEntry (pure data)
├── core/publishing/reports/                        — 6 generators: EngineeringGraph(+layout) → TabularReport
│   ├── tabular_report.dart                          (generic rows/columns shape + sort/filter/group/custom-column)
│   ├── bill_of_materials.dart, wire_report.dart, connector_report.dart,
│   │   harness_report.dart, relationship_report.dart, engineering_object_report.dart
└── core/exporters/
    ├── shared/tabular_report_renderer.dart          — TabularReport → CSV / Markdown (hand-rolled, no dependency)
    ├── shared/tabular_report_pdf_renderer.dart       — TabularReport → PDF (uses `pdf` package)
    ├── shared/diagram_print_scene.dart               — print-visibility filtering (DiagramLayer.printVisible)
    ├── pdf/{diagram_pdf_renderer,pdf_export_provider,drawing_package_pdf_renderer}.dart
    ├── svg/{diagram_svg_renderer,svg_export_provider}.dart   — hand-rolled XML, no new dependency
    └── png/{diagram_png_renderer,png_export_provider}.dart   — dart:ui rasterization

oep_studio/lib/diagram_studio/publishing/  — everything that needs Foundation/EIP data or UI
├── publishing_center_dialog.dart          — the single entry point (reachable via the document bar's new "Publishing…" button)
├── title_block_editor_dialog.dart, title_block_storage.dart  — editor + JSON-on-disk persistence + named presets
├── tabular_report_kind.dart, tabular_report_dialog.dart       — UI over oep_engine's 6 report generators
├── intelligence_reports.dart              — Validation/Reasoning reports, via DiagramIntelligenceService ONLY
├── engineering_summary.dart               — structural rollup (counts), zero intelligence content
├── package_manifest.dart                  — export-bundle bookkeeping
└── exchange_checklist.dart                — local readiness checklist, NO networking, NO upload
```

This split mirrors AP-DS-003's own precedent exactly: anything derivable from the graph/layout alone stays in `oep_engine` (portable, no FFI, reusable by a future CLI/headless publishing tool); anything needing Foundation persistence or the Engineering Intelligence Platform lives in `oep_studio`, behind `DiagramIntelligenceService`/`FoundationBridge`, never bypassing them.

## Printing System

Single-sheet Print Preview (`PublishingCenterDialog`'s "Print" tab, using the `printing` package's `PdfPreview` widget fed by `oep_engine`'s `PdfExportProvider`), title blocks rendered as a bordered field grid below the drawing, layer `printVisible` honored (a layer marked not-print-visible is excluded from exported output even if visible on-screen).

**A real gap found during independent verification of this phase, and closed directly**: the diagram print-preview dialog was built and unit-tested in isolation but was never actually wired to a reachable button in `PublishingCenterDialog` — the "Print" tab did not exist until this was caught and fixed. This is recorded here as a concrete illustration of why every phase in this project's history has been independently re-verified against the actual disk state rather than trusted from an agent's report alone.

**Not built, disclosed**: a dedicated Page Setup dialog (margins/scale/orientation as user-configurable settings, distinct from the title block's own "Scale" text field); Multiple Sheets / Entire Project / Entire Package print modes — this platform has no multi-sheet document model to print across (the same disclosed limitation `DOCUMENT_MODEL.md` has recorded since AP-DS-001).

## Export Formats

PDF, SVG, PNG (diagram drawings, vector where the format supports it — PDF/SVG are true vector via `pw.Canvas`/hand-rolled XML, not a rasterized screenshot of the Flutter widget tree), CSV, Markdown, PDF (tabular reports). JSON export (the diagram's own graph+layout) already existed since Phase 1. **Not built**: a literal "Engineering Package" as a single exportable artifact beyond `DrawingPackagePdfRenderer`'s "one diagram + selected reports" PDF bundle (see Engineering Deliverables below); batch export across multiple diagrams (no multi-document concept exists to batch across).

## Engineering Deliverables — status against the spec's own list

| Deliverable | Status |
|---|---|
| Engineering Drawing (PDF/SVG/PNG) | Done — vector rendering, title block, layer print-visibility |
| Drawing Package | Partial, disclosed — one diagram + selected reports, not a multi-sheet bundle |
| Installation Package, Service Package | Not built — same multi-sheet-model gap; would need product-level scoping of what "installation" vs. "service" content differs by, which wasn't attempted |
| Engineering Report | Done — `engineering_summary.dart`, a genuine structural rollup, not padding |
| Validation Report | Done — via `DiagramIntelligenceService.validate()` only |
| Reasoning Report | Done — via `DiagramIntelligenceService.reason()` only |
| Engineering Summary | Done (same as Engineering Report above) |
| Package Manifest | Done — `package_manifest.dart`, simple bookkeeping |
| Bill of Materials | Done — grouping/sorting/filtering/custom columns/CSV/PDF all real, via `TabularReport`'s own methods |
| Wire List | Done — color/gauge/length/source/destination/harness/label/termination, with disclosed approximated-length note for auto-routed wires |
| Connector List / Connector Report | Done, with disclosed per-pin-connectivity limitation (the graph model connects nodes, not individual ports) |
| Harness Report | Done — groups by layer assignment (this platform's chosen harness-membership representation) |
| Relationship Report | Done |
| Engineering Object Report | Done |

## Validation Reports / Reasoning Reports — honest field coverage

`OepWorkflowResult` (the EIP call's actual return shape) provides `.success`, `.summary` (free text), `.executionTimeMs`, and a related-object-id list — coarser than the spec's own bullet lists (Severity/Evidence/Rules/Resolution Status for Validation; Confidence/Traceability/Knowledge References for Reasoning) might imply if read as requiring independently-structured fields. `intelligence_reports.dart` renders exactly what's real and explicitly states in the UI which named fields the API doesn't provide, rather than fabricating structure — the same honesty discipline `RecommendationPanel` (AP-DS-003) already established for this exact API shape.

## Title Blocks & Revision Management

Full field editor (`title_block_editor_dialog.dart`): company/project/drawing number/revision/engineer/approver/date/scale/sheet/classification/custom fields, plus revision history (add/edit/delete, approval status). **Persistence design decision**: stored in a dedicated `title_blocks.json` (JSON-on-disk, `RecentFilesStorage`'s established pattern), keyed by diagram file path — NOT folded into `DiagramDocument`'s envelope. Reasoning: a title block is "how to publish," not "what the diagram is" — the same category as Print/Export Profiles, kept additive and zero-risk to the actively-used document schema rather than risking AP-DS-002's document persistence path. Disclosed trade-off: a title block does not travel with the diagram file if copied to another machine/location (it lives in local settings storage, keyed by path).

## Engineering Exchange Integration — preparation only

`exchange_checklist.dart`: a local readiness check (title block complete / validation passing / BOM generated / diagram non-empty). **No networking, no upload — verified**: no HTTP/socket code exists anywhere in this phase's files (consistent with the platform's broader "no REST surface in oep_foundation/oep_studio" finding from the earlier platform-wide architectural review). Package-level Foundation validation (`FoundationBridge.verifyPackage`, from AP-DS-002) exists and was not re-wired into this specific checklist — a disclosed, small follow-up item, not a missing capability (the underlying validation itself already works, it's just not surfaced in this particular checklist yet).

## Templates & Document Management — lowest priority, minimal by design

Built: `TitleBlockPresetStorage` (named title-block presets, JSON-on-disk, `RecentFilesStorage`/`RecentProjectsStorage` pattern) — storage layer only, tested, **not yet wired to any UI entry point**. Not built: Report/Print-Layout/Cover-Page/Header/Footer templates, Print Profiles, Export Profiles, Saved Layouts, Favorites, Recent Exports. This was explicitly scoped as the lowest-priority item given the breadth of the rest of this phase — a real, disclosed gap for a future phase, not a corner cut silently.

## Performance

The spec requires publishing to support 100,000 Engineering Objects "without excessive memory usage." **Not benchmarked at that scale in this phase.** What was done: `pw.MultiPage`'s built-in pagination is used for tabular report PDFs (not one unbounded in-memory table widget), SVG rendering uses a single-pass `StringBuffer` (not repeated string concatenation), and no obviously memory-pathological pattern was introduced. This is a correctness-scale implementation with disclosed, unverified behavior at 100,000-object scale — the same category of gap `PERFORMANCE_REPORT.md` (AP-DS-001B) already established a precedent for disclosing rather than glossing over.

## Testing

`oep_engine`: `test/publishing/report_generators_test.dart` (9 tests, the 6 generators + `TabularReport`'s own methods + CSV/Markdown rendering), `test/exporters/diagram_export_test.dart` (12 tests — PDF/SVG/PNG byte-level validity, page counts, print-visibility filtering). `oep_studio`: `test/publishing/` (9 files, 32 tests — report dispatch, engineering summary correctness, intelligence-report rendering against synthetic `OepWorkflowResult` data, exchange checklist logic, title block storage round-trip, dialog structure/wiring including the Print tab fix above). Consistent, disclosed gap with every other FFI-dependent area of this codebase: `DiagramIntelligenceService`/`FoundationBridge`-backed live behavior isn't exercised under `flutter test` (no test loads the real native DLL) — what's tested is rendering/formatting/storage logic given synthetic or null data.

## Known limitations (disclosed, not hidden — consolidated from above)

1. Drawing/Installation/Service "Package" deliverables are bounded by the platform's single-diagram document model — not true multi-sheet bundles.
2. Page Setup and multi-sheet print modes are not built.
3. Connector Reports report node-level, not per-pin, connectivity (a real data-model limitation, not an oversight).
4. Wire lengths for auto-routed wires are straight-line approximations, disclosed in the report itself.
5. Title blocks are keyed by file path in local settings storage, not embedded in the document file.
6. Package-level Exchange validation exists (from AP-DS-002) but isn't yet surfaced in the Exchange checklist specifically.
7. Templates/Document Management beyond named title-block presets (storage layer only, unwired) were not built.
8. 100,000-object performance was not benchmarked, only reasoned about.
9. Symbol Library artwork is not embedded in exported drawings — nodes render as a bordered box + label, since the on-screen symbol renderer depends on Flutter asset-bundle loading that the headless export path doesn't use. A future phase should give `DiagramPdfRenderer`/`DiagramSvgRenderer` access to the same symbol geometry the canvas uses, without depending on `rootBundle`.
