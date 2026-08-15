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
