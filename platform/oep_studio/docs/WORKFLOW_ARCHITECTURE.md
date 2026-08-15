# Workflow Architecture

Evidence Integration, Validation Integration, and AI Workspace
Integration — the three cross-workspace features not already covered
by `ENGINEERING_PROJECT.md`, `WORKSPACE_SYNCHRONIZATION.md`,
`UNIFIED_SEARCH.md`, or `PROJECT_EXPLORER.md` — plus how
`test/workflow/unified_workflow_test.dart` verifies all of them
together as one composed workflow rather than as isolated units
(WORK_PACKAGE_025, ENGINE-TASK-000122/123/124/125/127).

## Evidence Integration (ENGINE-TASK-000122/123)

### The gap this closes

Through WORK_PACKAGE_024, an `EvidenceLink` attached to a graph node or
relationship was only ever shown nested/summarized inside that node or
relationship's own Property Inspector mode — as a bare count, never as
its own selectable object, and with no way to jump from it to whatever
evidence it actually references.

### The Property Inspector gains an eighth mode

`EngineeringInspectableKind.evidenceLink` (`lib/core/models/
engineering_inspectable.dart`) is an additive enum case — the outer
Property Inspector's own 12-slot tuple switch is untouched, matching
the same "one new slot inside `selectedEngineeringInspectable`, not a
structural change" pattern WORK_PACKAGE_024 established for its seven
inspector modes. `EngineeringNodeProperties`/`EngineeringRelationshipProperties`
now render each evidence link as its own tappable row (was: a bare "N
linked" count); tapping one calls
`selectEngineeringInspectable(EngineeringInspectable.evidenceLink(ownerId, link))`,
switching the Property Inspector to the new
`EngineeringEvidenceLinkProperties` widget, which shows the link's
fields plus a "Go to Evidence" action.

### The `sourceReference`/`locator` convention

`EvidenceLink.sourceReference` and `EvidenceLink.locator` are both
declared Engine-owned but deliberately opaque — "interpreted by
whatever produced the evidence" and "producer-defined shape"
respectively (`oep_engine/lib/core/graph/models/evidence_link.dart`).
This work package establishes the concrete Studio-side interpretation,
documented here and enforced only by convention, not by a schema
change in either Foundation or the Engine:

* `sourceReference` holds a Knowledge Session `SourceMaterial.id`.
* `locator['regionId']`, when present, holds an `EvidenceRegion.id`
  within that source.

`goToEvidence` (`lib/shared/navigation/evidence_navigation.dart`)
resolves both against the active Knowledge Session
(`FoundationServiceState.sourceMaterials`/`evidenceRegions`), selects
them, and calls two Engine hooks that already existed but had zero
callers anywhere in Studio before this work package:
`SelectionService.focusEvidence(String)` and
`NavigationService.syncEvidence(String)` — so the diagram canvas can
reflect the same evidence reference the Property Inspector just
navigated to. A `sourceReference` that does not resolve shows an inline
"could not be found" message rather than navigating anywhere silently.

### What this does not add

No UI exists anywhere in Diagram Studio to *create* an `EvidenceLink`.
Attaching evidence to a graph node or relationship is a graph
mutation, and WORK_PACKAGE_025 explicitly excludes new engineering
editing features. This work package builds navigation and resolution
for links that already exist on graph data; `test/workflow/
unified_workflow_test.dart` verifies `goToEvidence` against a
test-constructed `EngineeringNode` with a real `evidenceLinks` entry,
not through any hand-built creation UI, since none exists.

## Validation Integration (ENGINE-TASK-000125)

`ValidationPage` (`lib/features/validation/validation_page.dart`),
previously a 16-line stub, now reads the same live
`ValidationReport` `docs/WORKSPACE_SYNCHRONIZATION.md` describes —
recomputed automatically on every graph edit, not just when Diagram
Studio happens to be open. Its row rendering is shared with Diagram
Studio's own `DiagramValidationPanel` through a new
`ValidationFindingsList` widget (`lib/shared/widgets/
validation_findings_list.dart`), so the two never drift into rendering
findings differently. Each row optionally shows a Suggested Fix —
`lib/features/validation/suggested_fixes.dart`, a plain `String ->
String` lookup over the exact seven codes `ValidationService` emits
(`missing_symbol`, `unknown_symbol`, `broken_relationship`,
`duplicate_node`, `duplicate_port`, `floating_node`,
`invalid_evidence_mapping`) — presentation only; no new checks were
added to the Engine's validator. Tapping a finding calls
`goToValidationResult` (`shared/navigation/unified_navigation.dart`),
which resolves `finding.subjectId` against the live graph's nodes/
relationships first, falling back to a Knowledge Object lookup, and
finally to the bare Validation page if neither resolves.

## AI Workspace Integration (ENGINE-TASK-000124)

`UnifiedAiContextService.buildProjectContext` (`lib/core/services/
unified_ai_context_service.dart`) does not replace either existing
prompt assembler — it calls whichever one already applies
(`DiagramPromptContext.buildSelectionRequest` when a diagram editing
session is active, a minimal Knowledge-only request otherwise) and
appends two sections neither one emits on its own: the current
`ValidationReport`'s findings, and evidence resolved the same way
`goToEvidence` resolves it (source material file names, not raw
`sourceReference` ids). The resulting `AiRequest` is handed to the
existing `AiProviderRegistry.defaultRegistry.providerFor(id)!.complete(request)`
call unchanged — no new provider, no changes to `PromptService`/
`DiagramPromptContext`/`DiagramAiService`. `ValidationPage`'s "Ask AI"
action is the one new entry point that calls this service; it uses the
Studio-wide AI provider setting (`FoundationServiceState.
currentAiProviderId`), the same setting every other AI entry point
already reads — Validation does not get its own provider selector.

## The composition test

`test/workflow/unified_workflow_test.dart` (ENGINE-TASK-000127) is
deliberately the *last* thing this work package built, and
deliberately does not re-test gesture-level canvas editing —
WORK_PACKAGE_021 through 024's own test suites already cover node/
port/wire dragging exhaustively. Its job is to prove the pieces above
actually compose: seed one diagram node (with a real evidence link,
directly through `EngineeringGraph`/`EngineeringNode`/`EvidenceLink` —
not through any UI, since no creation UI exists) so `ValidationService`
emits exactly one deterministic `floating_node` finding, then drive,
through real widget taps, the full loop the work package's own
Definition of Done describes: Project Explorer reflects the live
finding count → selecting the node updates the shared Property
Inspector → the evidence row navigates to Knowledge Studio and records
shared history → switching workspaces via the Navigation Rail
preserves both selection and history → the global Validation page
shows the same live finding with a Suggested Fix → "Ask AI" produces a
response from the deterministic Mock provider → click-to-navigate
returns to Diagram Studio with the node still selected. A `FoundationRuntimeNotifier`
override seeds one `SourceMaterial` for evidence resolution to succeed
against — the standard Riverpod `overrideWith` test seam, since no
existing test previously needed to seed Foundation-side state at all.

Three incidental, pre-existing bugs surfaced only once this composition
test exercised code paths no earlier test had reached, and were fixed
as part of this work package rather than left in place: a `ListTile`/
`ColoredBox` Material-ancestor layering warning (present in `diagram_explorer_panel.dart`,
`diagram_annotation_panel.dart`, and this work package's own
`validation_findings_list.dart` — none had ever been exercised with
actual list rows before), a Riverpod "modify a provider while the
widget tree is building" crash in `DiagramStudioPage.dispose()` (fixed
by deferring the Property Inspector clear via `scheduleMicrotask`), and
a `RenderFlex` overflow in `ValidationPage`'s header once "Ask AI" had
something to click (fixed by shortening its label, the same fix
`docs/UNIFIED_SEARCH.md` describes for the Search page's own
previously-latent overflow).
