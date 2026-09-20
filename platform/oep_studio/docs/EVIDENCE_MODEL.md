# Evidence Model

Introduced in Work Package 009 (STUDIO-TASK-000019 PDF Source Viewer,
STUDIO-TASK-000020 Evidence Regions, STUDIO-TASK-000021 Evidence
Linking). Documents the PDF Source Viewer, the Evidence Region/
Evidence Link/Page Selection models, the selection and navigation
model, persistence, and the architectural findings this work package's
implementation surfaced. See `docs/KNOWLEDGE_STUDIO.md` for the
surrounding workspace/state-ownership documentation, and
`docs/KNOWLEDGE_SESSION_FORMAT.md` for the Knowledge Candidate/
Relationship Candidate/Commit Preview models this one builds on.

Everything here is **Studio-only** and follows the same rule Work
Package 008 established: "Evidence remains separate from Engineering
Objects. Evidence belongs to the Knowledge Workspace. Foundation
remains unaware of Evidence Regions." SDD-015 Layer 2.5 ("Evidence
Objects... are not Engineering Objects. They do not become repository
truth.") already anticipated exactly this model.

---

## PDF Source Viewer

`lib/knowledge/workspaces/pdf_source_viewer.dart` (`PdfSourceViewer`)
renders attached PDF Source Material with a real, interactive
viewer — "This is a viewer only. No parsing. No OCR. No extraction."
— nothing here reads a PDF's text or structure; only its rendered
pages and page geometry (dimensions, rotation) are ever used.

### Flutter Package Decision

Built on [`pdfrx`](https://pub.dev/packages/pdfrx) (MIT license,
PDFium-backed, actively maintained as of mid-2026), the only dependency
this work package adds. Alternatives considered:

* **`pdfx`** — also PDFium-backed and Windows-capable, but offers a
  thinner widget API; `pdfrx` was chosen specifically for
  `pageOverlaysBuilder`/`viewerOverlayBuilder`
  (`PdfViewerParams`), which let Evidence Region rectangles and the
  Page Selection marker be drawn directly inside the rendered page
  without reimplementing PDF page layout, and for
  `PdfViewerController.getPdfPageHitTestResult`, which converts a
  screen tap into a page number plus a PDF-point-space offset — exactly
  what Evidence Region creation needs.
* **`printing`'s `Printing.raster`** — designed around
  generate-and-preview workflows for PDFs Studio itself produces, not
  an interactive viewer for arbitrary attached PDFs; would have meant
  building page navigation, zoom, and hit-testing from scratch.
* **Syncfusion's PDF viewer** — capable, but a commercial-license
  dependency; rejected to keep this project's dependency set
  MIT/BSD-only, consistent with `oep_foundation`'s "before introducing
  any dependency ask: does the platform genuinely benefit?" philosophy.

`pdfrx` requires Windows Developer Mode enabled (its build uses
symbolic links) — already enabled on this development machine;
`pdfium.dll` is bundled alongside `oep_studio.exe` by the normal
`flutter build windows` process, confirmed present in the Release
output.

### Requirements Coverage

| Requirement | Implementation |
|---|---|
| Open PDF | `PdfViewer.file(source.localPath, ...)` |
| Page navigation | Prev/Next toolbar buttons (`PdfViewerController.goToPage`) |
| Zoom In / Zoom Out | `PdfViewerController.zoomUp`/`zoomDown` |
| Fit Width | `PdfViewerController.calcMatrixFitWidthForPage` + `goTo` |
| Fit Page | `PdfViewerController.calcMatrixForFit` + `goTo` |
| Rotate | `RotatedBox` wrapping the whole `PdfViewer` (see § Rotation below) |
| Continuous scrolling | `pdfrx`'s default layout behavior — no extra configuration needed |
| Current Page / Total Pages | `PdfViewerController.pageNumber`/`pageCount`, displayed via a `ListenableBuilder` (the controller is itself a `ValueListenable<Matrix4>`) |
| Zoom Percentage | `(controller.currentZoom * 100).round()`, same `ListenableBuilder` |

### Rotation

`pdfrx` exposes each page's own *embedded* PDF rotation
(`PdfPage.rotation`, a `PdfPageRotation`) but no controller method to
set an interactive *view* rotation independent of that. "Rotate" is
implemented instead as a `RotatedBox(quarterTurns: ...)` wrapping the
entire `PdfViewer` widget, cycling 0°→90°→180°→270°→0° per click. This
was a deliberate, low-risk choice: wrapping the *whole* widget (rather
than trying to rotate only the rendered page image) means Evidence
Region overlays — drawn as descendants of the same `PdfViewer`, inside
its own `pageOverlaysBuilder` — rotate together with the page
automatically, with no separate coordinate transform needed. Region
storage coordinates (see below) are always relative to the PDF page's
own un-rotated geometry, so nothing about persistence needs to know
the current view rotation at all.

### Page Selection (STUDIO-TASK-000019 § Selection)

"The engineer may select pages... No text selection required. Page
selection only." Each rendered page gets a small checkbox-style icon
overlay (top-left corner, via `pageOverlaysBuilder`) that toggles a
[`PageSelection`](#pageselection-model) for that page. Deliberately
lighter than an Evidence Region — SDD-015 lists "Page Selection" and
"Evidence Region" as distinct example Evidence Object kinds, and
STUDIO-TASK-000021's linking requirement names only "Evidence Region"
as something a Knowledge Candidate may reference — so Page Selection
carries no label, notes, or links, just identity.

---

## Evidence Region Model

STUDIO-TASK-000020: "Allow engineers to identify where engineering
evidence exists... Support: Rectangle Regions."

```dart
class EvidenceRegion {
  final String id;
  final String sourceId;   // the SourceMaterial this region belongs to
  final int page;          // 1-based, matches PdfPage.pageNumber
  final double x, y, width, height;  // fractions (0.0-1.0) of the page's own size
  final String label;
  final String notes;
  final DateTime createdTime;
  final DateTime? modifiedTime;
}
```

### Coordinate System

`x`/`y`/`width`/`height` are fractions of the PDF page's own width/
height, **top-left origin** — resolution- and zoom-independent, so a
region drawn at any zoom level renders correctly at any other, and
survives the page being viewed at a different size on a different
machine. This required one conversion: `pdfrx`'s own
`PdfPageHitTestResult.offset` (`PdfPoint`) uses the PDF's native
**bottom-left** origin ("the origin is at the bottom-left corner," per
`pdfrx`'s own documentation) — `PdfSourceViewer._finishDrag` inverts
the y-axis (`y = 1 - (offset.y / page.height)`) once, at creation time,
so every other part of the system (storage, rendering, the Evidence
Browser) only ever deals with the simpler top-left convention.

### Creation (Drag-to-Draw)

Armed via the Source Viewer's "Draw Evidence Region" toolbar toggle,
which renders a full-viewer, opaque `GestureDetector` inside
`PdfViewerParams.viewerOverlayBuilder` — present only while armed, so
normal pan/zoom/tap behavior is completely unaffected the rest of the
time. On drag end,
`PdfViewerController.getPdfPageHitTestResult` is called for both the
drag's start and end points; if both resolve to the *same* page, a new
region is created (`FoundationRuntimeNotifier.createEvidenceRegion`)
with fractional coordinates computed from the two hits, defaulting its
label to `"Region <n>"` (the drag gesture itself has no label input;
the engineer renames afterward via the Evidence Browser if they want
something more specific). Drags shorter than 8 logical pixels are
ignored, to avoid creating a zero-size region from an accidental click.

### Evidence Browser

`lib/knowledge/workspaces/evidence_browser_dialog.dart`, opened from
the Source Viewer's toolbar, scoped to one source's regions (opening
from a specific PDF, since "Navigate" only means something relative to
whichever document is open). Displays Region Name, Page, Type (always
"Rectangle" — STUDIO-TASK-000020 lists only one supported shape; the
column exists for a future shape, not because more than one exists
today), and Linked Candidate Count; supports Rename, Delete, and
Navigate (selects the region and jumps the Source Viewer to its page).

---

## Evidence Link Model

STUDIO-TASK-000021: "Knowledge Candidates may reference engineering
evidence... One candidate may reference multiple regions. One region
may support multiple candidates."

```dart
class EvidenceLink {
  final String id;
  final String candidateId;
  final String regionId;
  final DateTime createdTime;
}
```

A thin many-to-many join record — no fields beyond identity and the
two endpoints, since nothing in the Requirements asks a link itself to
carry a reason. Linking (`FoundationRuntimeNotifier.linkEvidence`) is
idempotent: creating a link for a pair that's already linked is a
no-op rather than a duplicate record, since "one candidate may
reference multiple regions" describes a *set* of distinct pairs, not
a multiset. Deleting either endpoint (a candidate or a region) cascades
to remove any link referencing it.

Links are created/removed from either direction's Property Inspector
view — `lib/knowledge/inspector/link_evidence_dialog.dart` provides one
shared checklist-dialog shell with two entry points
(`showLinkEvidenceRegionsDialog`/`showLinkKnowledgeCandidatesDialog`),
toggling a `CheckboxListTile` per candidate/region immediately
links/unlinks (autosaved, like every other mutation — no separate
"Save").

### Bidirectional Highlighting (Source Viewer Interaction)

* **Selecting a Knowledge Candidate** highlights its linked Evidence
  Regions — inside the Source Viewer (region rectangles rendered in a
  distinct color) and inside the Engineering Review panel's own
  candidate list is unaffected (a candidate can't highlight itself);
  the reverse direction below highlights *rows* there.
* **Selecting an Evidence Region** highlights its linked Knowledge
  Candidates — inside the Engineering Review panel's Candidates tab
  (`KnowledgeCandidateRow.linkedToSelectedEvidence`, a distinct row
  tint) and inside the Property Inspector's Evidence Region view (the
  linked-candidates list).

Both directions are derived views
(`FoundationServiceState.evidenceRegionsLinkedToCandidate`/
`candidatesLinkedToEvidenceRegion`), not separately stored state — a
link's existence is the only fact that needs to be persisted; which
regions/candidates currently *show* as highlighted is always computed
fresh from the current selection plus the current link list.

### Navigation ("shall work in both directions")

Selecting an Evidence Region — from the Evidence Browser's Navigate
action, from the Property Inspector, or from a future Knowledge
Candidate's evidence list — always brings the Source Viewer to that
region's page, if the region's source is the one currently open
(`PdfSourceViewer` watches `selectedEvidenceRegion` and calls
`PdfViewerController.goToPage` once per newly-selected region, via a
post-frame callback so the navigation never happens mid-`build()`).

---

## Page Selection Model

```dart
class PageSelection {
  final String id;
  final String sourceId;
  final int page;
  final DateTime createdTime;
}
```

See § Page Selection above for the feature description. Toggled per
page via `FoundationRuntimeNotifier.togglePageSelection` — if a
selection already exists for that source/page it's removed, otherwise
a new one is added.

---

## Local Storage Format

`EvidenceRegion`/`EvidenceLink`/`PageSelection` extend the same
`KnowledgeSessionRecord`/`session.json` format
`docs/KNOWLEDGE_SESSION_FORMAT.md` documents, as three new top-level
arrays:

```json
{
  "formatVersion": 1,
  "session": { "...": "..." },
  "candidates": [ "..." ],
  "relationshipCandidates": [ "..." ],
  "sources": [ "..." ],
  "reviewDecisions": [ "..." ],
  "evidenceRegions": [
    {
      "id": "region-1736550040000-a1b2",
      "sourceId": "source-1736550005000-i9j0",
      "page": 2,
      "x": 0.15, "y": 0.32, "width": 0.4, "height": 0.12,
      "label": "Torque Callout",
      "notes": "",
      "createdTime": "2026-01-10T14:34:00.000",
      "modifiedTime": null
    }
  ],
  "evidenceLinks": [
    {
      "id": "link-1736550050000-c3d4",
      "candidateId": "candidate-1736550012000-c3d4",
      "regionId": "region-1736550040000-a1b2",
      "createdTime": "2026-01-10T14:34:30.000"
    }
  ],
  "pageSelections": [
    {
      "id": "page-1736550060000-e5f6",
      "sourceId": "source-1736550005000-i9j0",
      "page": 5,
      "createdTime": "2026-01-10T14:35:00.000"
    }
  ]
}
```

`KnowledgeSessionRecord.fromJson` defaults all three arrays to `[]`
when absent (`json['evidenceRegions'] as List<dynamic>? ?? const []`,
etc.) — confirmed by a unit test (`knowledge_session_storage_test.dart`)
that loads a hand-written pre-Work-Package-009 `session.json` with none
of these keys present at all, so sessions created by the previous work
package's build continue to load without error. `buildDuplicate`
carries all three arrays over unchanged when duplicating a session (no
remapping needed — they only reference `sourceId`/`candidateId`/
`regionId`, which stay the same as the entities those IDs point to are
themselves copied unchanged).

---

## Architectural Observations

### The Connection Manager's "Current Source Document" must be separate from "Current Selection"

The most significant finding from this work package's implementation.
An early version of this state reused `selectedSourceMaterial` (Work
Package 008's Property-Inspector-mode field) as Work Package 009's
"Current Source Document" too, reasoning that "the source open in the
Source Viewer" and "the source selected in the Import Queue" were the
same thing. They are not: **every** `select*` method (including
`selectKnowledgeCandidate`) clears `selectedSourceMaterial` as part of
the existing mutual-exclusivity rule (switching the Property Inspector
to Candidate mode). If that same field also controlled *which document
the Source Viewer displays*, selecting a Knowledge Candidate would
silently close whatever PDF was open — directly breaking this work
package's own explicit requirement: "Selecting Knowledge Candidate →
Highlights linked Evidence Regions" presupposes the Source Viewer
*stays open* while a candidate is selected elsewhere.

This was caught during manual verification (the temporary integration
test's Page Selection step found the Source Viewer had reverted to its
empty placeholder immediately after a candidate-selection step earlier
in the same test), not by design review — worth noting because the
distinction ("what's open" vs. "what's Property-Inspector-selected")
is easy to conflate for exactly one entity kind (Source Material) that
happens to serve both roles, while every *other* selectable kind
(Object, Relationship, Knowledge Candidate, Relationship Candidate,
Evidence Region) only ever serves the Property Inspector role. Fixed by
introducing `openSourceDocument` as an independent field, set only by
`selectSourceMaterial` (opening a source from the Import Queue) and
left untouched by every other `select*` method — see
`docs/KNOWLEDGE_STUDIO.md` § State Ownership for the corrected table.

### A dialog-controller-lifecycle bug, reintroduced and caught by the integration test

The Evidence Browser's Rename dialog initially created its
`TextEditingController` in the calling `ConsumerWidget`'s method (not a
`State`) and disposed it immediately after `showDialog`'s `Future`
resolved — precisely the bug Work Package 007 already documented and
fixed for the New Session/New Candidate dialogs ("A `TextEditingController`
was used after being disposed," since `showDialog`'s `Future` completes
on `Navigator.pop()`, before the dialog's exit animation finishes
rebuilding the still-attached `TextField`). Reintroduced here because
this dialog was written fresh rather than copied from an existing
one, and the lesson wasn't re-checked against it. The temporary
integration test caught this immediately (a real crash, not a test
authoring mistake) — fixed by splitting the Rename dialog into its own
`ConsumerStatefulWidget` that owns and disposes its controller in
`State.dispose()`, the same pattern every other dialog in this
codebase already follows. Recorded here as a standing reminder: *any*
new dialog with a `TextEditingController` needs this pattern from the
start, regardless of how simple the dialog looks.

### `PdfOverlayInteractionRegion` vs. a plain `GestureDetector` for small overlay widgets

`pdfrx` recommends `PdfOverlayInteractionRegion` for tap-like overlay
widgets that shouldn't compete with the viewer's own pan/zoom gesture
recognition. In practice, for the small, fixed-size Evidence Region
rectangles and the Page Selection checkbox (each a tiny fraction of the
viewer's total area), a plain `GestureDetector` scoped to just that
widget's own bounds works identically and was simpler to reason about
(no dependency on `pdfrx`'s internal hit-test-registration mechanism).
The full-viewer drag-to-create-region gesture, by contrast, genuinely
needs to own the *entire* viewer's gesture arena while armed (and does,
via a plain `GestureDetector` with `HitTestBehavior.opaque` covering
the whole area) — this is also why the region-drawing tool must be
explicitly disarmed before other overlay interactions (clicking an
existing region, toggling Page Selection) will receive taps again: an
armed drag-detector spans the same area and is rendered above the page
content by design, so it intercepts every tap in the viewer until
disarmed. This is expected "tool mode" behavior, not a defect — noted
here since it wasn't obvious at first that "the tool is still armed"
was the reason an unrelated tap during verification appeared to do
nothing.

---

## Human Annotation, Classification, and Candidates (WP-INGEST-010/012)

The Extraction Inspector (`lib/knowledge/workspaces/extraction_inspector_dialog.dart`,
opened from the PDF Source Viewer toolbar and from the Acquire Knowledge
wizard's Candidate Preview) lets an engineer draw regions on a source and
classify them. This section is the canonical description of what each step
creates -- and, just as importantly, what it does not.

### Lifecycle

```
Human draws a region
        ↓
EvidenceRegion                      origin = human, status = unverified,
                                    label = "Unclassified"
        ↓
Engineer classifies the region      label = "<Type>" or "<Type>: <name>"
        ↓
KnowledgeCandidate created          (first classification) or updated
                                    (every later reclassification), and
                                    linked to the region by an EvidenceLink
        ↓
Engineering Review                  Accept / Reject / Edit -- human-controlled
        ↓
Accepted candidate
        ↓
CommitPlanService → explicit Commit → Committed Repository Object
```

### Four distinct things

| Term | What it is | Created by | Is Repository truth? |
|---|---|---|---|
| **Evidence** (`EvidenceRegion`) | *Where* on a source something is. A machine region (`origin = machine`, from `CandidateGenerationService`) or a human region (`origin = human`). | UIF, or the human drawing a rectangle | No -- never (SDD-015 Layer 2.5) |
| **Knowledge Candidate** (`KnowledgeCandidate`) | A pending, human-reviewable *interpretation* of evidence. | UIF (machine), or **classifying a human region** | No -- `status = pending` until reviewed |
| **Accepted Engineering Object** | A candidate an engineer has explicitly accepted in Engineering Review, ready for a Commit Plan. | Explicit human acceptance | Not yet -- only eligible to be committed |
| **Committed Repository Object** | A Foundation object created by an explicit, confirmed Commit. | `CommitTransactionService` via `CommitPlanService` | Yes |

### Classification creates/updates a candidate -- and nothing more

Classifying a human region renames it (its `label` is the single source of
truth for the chosen `KnowledgeCandidateType`; no separate field exists) and
creates -- or, on reclassification, **updates the same** -- one
`KnowledgeCandidate` linked to it (`addKnowledgeCandidate` / `linkEvidence` /
`editKnowledgeCandidate`, the same mechanism `CandidateGenerationService`
uses for machine detections). Reclassifying never creates a duplicate.

Classification does **not**: create an Engineering Object, write to the
Repository, bypass Engineering Review or `CommitPlanService`, invoke EKE,
modify UIF output, or modify machine-generated regions. `CommitPlanService`
takes candidates and relationship candidates, never `EvidenceRegion`s, so
evidence alone can never reach a Commit.

### Inspector counts and "New Relationship"

The Inspector's toolbar shows two independent counts: **Evidence** (every
`EvidenceRegion` of the source, any origin; also the overlay toggle) and
**Candidates** (every `KnowledgeCandidate` reachable from the source through
an Evidence Link; no overlay of its own). Both display `0` explicitly.

"New Relationship" opens the existing, unmodified
`RelationshipCandidateFormDialog`, and is enabled only when at least two
**human** annotations of the current source are classified (a human region
whose label is a selected type rather than "Unclassified"). Machine-generated
candidates, and candidates of unrelated evidence, never enable it
(`ExtractionInspectorSummary.canCreateRelationship`).

---

## Evidence vs. Annotation, and Extensible Properties (WP-INGEST-013)

> **`EvidenceRegion` answers WHERE. The annotation answers WHAT, and WHAT IS
> KNOWN ABOUT IT.**

### Region vs. annotation

`EvidenceRegion` stays spatial/evidence-only (source, page, normalized
coordinates, origin, annotator, status, observation reference). What an
engineer records about a region is carried by **one optional payload** on it,
`EvidenceRegion.annotation` (`EvidenceAnnotation`,
`lib/knowledge/models/evidence_annotation.dart`) -- deliberately not dozens of
engineering-specific fields on the region.

| Universal annotation field | Where it lives (unchanged from WP-INGEST-012) |
|---|---|
| Type | the region `label` (`"<Type>"` / `"<Type>: <name>"`) |
| Name | the region `label` |
| Description / Notes | `EvidenceRegion.notes` |
| Annotator, status | `annotatorId`, `status` |
| **Properties** (new) | `EvidenceAnnotation.properties` |

`EvidenceAnnotation` has a stable `id` (minted the first time a region gets
properties, never regenerated by an edit) and a list of properties.

### Extensible properties

An `AnnotationProperty` is `{key, value, valueType?, unit?}` and nothing more.
`valueType` is a hint from a small initial set (`text`, `number`, `boolean`;
absent reads as `text`); `unit` is optional free text. There is no validation
engine, no unit conversion, no enumerations, no ontology-defined types and no
confidence -- nothing checks a value against its type.

**Stable keys.** The persisted identity of a property is a machine-stable key
(`part_number`, not "Part Number"): keys are normalized on edit
(`AnnotationProperty.normalizeKey`: lower-case, non-alphanumeric runs collapsed
to `_`). Any key may be created; **no canonical vocabulary exists**.

### No wiring ontology yet

This mechanism is generic on purpose. The platform does **not** define wire /
connector / pin / splice forms or fields. The intended order is: generic
properties -> annotate real diagrams (the TRX300 exercise) -> observe which
keys engineers actually use -> only then derive a canonical annotation schema
-> only then any visual extraction that targets it.

### Lifecycle

```
Evidence Region
      ↓
Human Observation        (notes)
      ↓
Properties               (EvidenceAnnotation.properties)
      ↓
Classification           (label -> KnowledgeCandidateType)
      ↓
Knowledge Candidate      (created/updated, linked by an EvidenceLink)
      ↓
Engineering Review
      ↓
Explicit Commit          (CommitPlanService)
```

### Annotation vs. candidate

`EvidenceAnnotation` is *what the engineer observed at this location*;
`KnowledgeCandidate` is the *proposed engineering entity derived from that
observation*. Properties are **not** copied onto the candidate and are never
turned into Repository fields automatically. Classification keeps using the
existing `renameEvidenceRegion` / `addKnowledgeCandidate` / `linkEvidence` /
`editKnowledgeCandidate` paths; editing properties creates neither a region
nor a candidate, and reclassifying leaves the properties intact.

### Persistence ownership

```
Reference Vault artifact   (immutable evidence; never modified)
      ↓
Knowledge Session          (session.json -- the only persistence path)
      ↓
EvidenceRegion
      ↓
EvidenceAnnotation
      ↓
Properties
```

Properties are saved and reloaded with the session's `evidenceRegions` array
and deleted with their region. A session or region without the payload loads
as "no annotation / no properties" -- no migration.

### Boundary

Editing properties creates no Engineering Object, writes nothing to the
Repository and invokes no commit. `CommitPlanService` takes candidates and
relationship candidates, never `EvidenceRegion`s or their annotations.

---

## Observation model (INGEST-012)

The layers, from raw evidence to repository truth:

```
Evidence (EvidenceRegion)      = WHERE something is (spatial identity)
  -> Observation               = WHAT was observed / interpreted
  -> KnowledgeCandidate        = WHAT may enter engineering review
  -> Engineering Review
  -> Explicit Commit (CommitPlanService / CommitTransactionService)
  -> Engineering Repository    = accepted repository truth
```

**Observation** is the `EvidenceAnnotation` payload carried by an
`EvidenceRegion` (`typedef Observation = EvidenceAnnotation`, kept under
its WP-INGEST-013 storage name so persisted sessions stay valid). All
fields except `id` are optional:

| Field | Meaning |
|---|---|
| `type` | free-form type name; normally a `KnowledgeCandidateType.name`, but any string (e.g. `wire`) is valid |
| `name`, `description` | interpretation name / notes |
| `properties` | ordered `key`, `value`, optional `valueType` (`text`/`number`/`boolean`), `unit`, `source` |
| `origin` | `human`, `machine` or `llm` (`llm` is reserved; nothing produces it yet) |
| `authorId` | annotator identity, or later a model identity/version |
| `status` | `unverified` / `verified` -- never authoritative by itself |
| `regionId` | provenance back to the `EvidenceRegion` |

Persistence: the Observation lives inside its region in the existing
`session.json`; no second file or store. A session or region without one
loads unchanged. Deleting a region deletes its Observation, so no
dangling reference is possible.

Classification (`applyRegionClassification`) records `type`/`name` on the
Observation, renames the region, and creates/updates the ONE linked
`KnowledgeCandidate` exactly as before. It never creates an Engineering
Object, writes the Repository, or bypasses Engineering Review or the
commit services. `description` mirrors `EvidenceRegion.notes` when the
notes are edited in the Inspector.

The Observation is intentionally richer than `KnowledgeCandidate`: it
keeps the raw interpretation (arbitrary properties, provenance, author)
that a candidate does not carry, which may later support
training/evaluation and AI-assisted extraction. Properties are never
copied into candidates automatically. Type-specific property-key
suggestions (`observationPropertySuggestions`) are configuration only;
the persistence model does not depend on them and no wiring ontology is
defined.
