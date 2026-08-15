# OCR Pipeline

Introduced in Work Package 013 (STUDIO-TASK-000034 OCR Pipeline,
STUDIO-TASK-000035 OCR Layer Viewer, STUDIO-TASK-000036 Searchable
Documents, STUDIO-TASK-000037 OCR Session Cache). Converts engineering
documents from images into structured, searchable text while
preserving exact positional information — "OCR augments Source
Material only," per this work package's own text: OCR results are
Evidence, exactly like Evidence Regions and Page Selections
(`docs/EVIDENCE_MODEL.md`), never Knowledge Candidates and never
committed to Foundation. No AI. No automatic Knowledge Candidate
generation. No Repository Commit changes.

For the surrounding workspace layout and state ownership, see
`docs/KNOWLEDGE_STUDIO.md`. SDD-021 (Evidence Model) explicitly
anticipated this extension — its own "Future Expansion" section names
"OCR Text Blocks" as a future evidence type "without requiring changes
to existing session files," which this work package's persistence
design honors (see § OCR Cache).

Work Package 014 (Engineering Entity Extraction) builds one layer on
top of this OCR text: deterministic regex pattern matching recognizes
engineering values (torque specs, part numbers, voltages, and eleven
more) inside already-OCR'd text, using the exact same line-grouping and
cache-fingerprint conventions this document describes. See
`docs/ENGINEERING_ENTITY_EXTRACTION.md`.

Work Package 015 (Engineering Context Analysis) builds one layer above
that again: deterministic heading/layout detection groups OCR lines and
extracted entities into logical contexts (a Torque Specifications
section, a Parts List), using the same per-line grouping this document
describes plus a whole-source variant of the cache-fingerprint
convention (a context can span multiple pages). See
`docs/ENGINEERING_CONTEXT.md`.

---

## OCR Architecture

Supported input: PDF, PNG, JPG, TIFF — OCR operates **per page**,
uniformly across all four. For a PDF, each page is first rendered to
an image at 300 DPI (`PdfPage.render`, `pdfrx`, already used for the
PDF Source Viewer) and converted from raw BGRA8888 pixels to a
temporary PNG file via `dart:ui`'s `decodeImageFromPixels`/
`Image.toByteData(format: ImageByteFormat.png)` — a Flutter framework
capability, no new package. For PNG/JPG/TIFF, the Source Material file
is used directly; no rendering step exists to skip.

**Why a render-then-OCR step for PDFs, not `pdfrx`'s own embedded-text
extraction.** `pdfrx_engine`'s `PdfPage` also exposes `loadText()`/
`loadStructuredText()` — reading a *born-digital* PDF's own embedded
text objects, with character bounding boxes and reading order already
computed by PDFium. This is a different capability from OCR: it has no
confidence score (there is nothing to be uncertain about — the text is
literally embedded, not recognized from pixels), and it produces
nothing at all for a scanned/image-only PDF, which is exactly the case
this work package's OCR exists to handle. Using embedded-text
extraction for born-digital PDFs and true OCR for everything else would
mean two different data paths feeding the same `OcrPageResult` model
with fundamentally different confidence semantics (a fabricated "100%"
for embedded text vs. a real per-word score from the OCR engine) — a
correctness problem, not a convenience trade-off. Every PDF page is
rendered to an image and OCR'd exactly like every other supported
format, keeping "OCR results shall include text, confidence, reading
order, and positional information" true uniformly rather than only for
scanned pages.

### Pipeline

```
OcrPipelineService.processSource(source, existingResults)
  -> OcrCacheService.computeFingerprint(file)         [SHA-256 of the file's bytes]
  -> OcrCacheService.pagesNeedingProcessing(...)       [which pages are new/stale]
  -> for each page needing processing:
       PDF:   PdfPage.render(...) -> BGRA -> PNG file -> TesseractOcrEngine.recognizePage(path)
       Image: TesseractOcrEngine.recognizePage(source.localPath)
  -> merge freshly-computed pages with still-valid cached ones
  -> return the source's complete, up-to-date List<OcrPageResult>
```

`TesseractOcrEngine` (`lib/knowledge/services/tesseract_ocr_engine.dart`)
is the only place Studio invokes an external process for OCR —
`Process.run('tesseract', [imagePath, 'stdout', 'tsv'])`, streaming
Tesseract's `tsv` output format directly to stdout (no intermediate
output file). `TesseractTsvParser` (pure, unit-tested) parses that
output into `OcrWord`s. See § Package Selection Rationale for why an
external process rather than an in-process binding, and why Tesseract
rather than any Flutter-plugin alternative.

### Data Model

```dart
class OcrBoundingBox {
  final double x, y, width, height;  // fractions (0.0-1.0) of the page image, top-left origin
}

class OcrWord {
  final String text;
  final double confidence;   // 0.0-1.0
  final OcrBoundingBox boundingBox;
  final int readingOrder;    // 0-based, matches list position
  final int lineIndex;       // groups words into printed lines
}

class OcrPageResult {
  final String sourceId;
  final int page;            // 1-based
  final List<OcrWord> words; // already in reading order
  final int imageWidth, imageHeight;   // pixel dimensions OCR ran against
  final String sourceFingerprint;      // SHA-256 of the source file at OCR time
  final String engineVersion;          // e.g. "Tesseract 5.4.0.20240606"
  final DateTime processedTime;
  final bool success;
  final String? errorMessage;
}
```

`OcrBoundingBox`'s fraction/top-left-origin convention is deliberately
identical to `EvidenceRegion`'s (`docs/EVIDENCE_MODEL.md` § Coordinate
System) — the same resolution-/zoom-independence reasoning applies, and
reusing the convention meant the OCR Layer Viewer's overlay math is
line-for-line the same `left: box.x * canvasWidth` pattern
`PdfSourceViewer` already uses for Evidence Region rectangles.

### Reading Order and Line Grouping

Tesseract's `tsv` output already carries a `(block_num, par_num,
line_num, word_num)` hierarchy — top-to-bottom, then left-to-right,
exactly the reading order a human would follow. `readingOrder` is
simply each word's 0-based position in the already-ordered output;
`lineIndex` groups words sharing the same `(block_num, par_num,
line_num)` tuple, assigned 0-based in first-encounter order. Studio
never re-sorts or re-groups Tesseract's own segmentation — "OCR is
deterministic" is Tesseract's property to guarantee, not Studio's to
reconstruct.

---

## OCR Cache

STUDIO-TASK-000037: "OCR results shall persist. Reopening a session
shall not rerun OCR. Support cache invalidation when Source Material
changes."

`OcrCacheService.computeFingerprint` hashes the Source Material file's
**current bytes** with SHA-256 — content-based, not file-system-
metadata-based (size/mtime). This was a deliberate choice over the
cheaper size+mtime check most incremental-build caches use: this
project's own `SourceMaterialService.attach`/session-duplication paths
use `File.copy`, which produces byte-identical files with a *new*
modification time — a metadata-based fingerprint would spuriously
invalidate a duplicated session's still-perfectly-valid OCR cache on
its very first open. `OcrCacheService.isCacheValid` compares a page's
stored `sourceFingerprint` against a freshly-computed one; a mismatch
(or no stored result at all) means that page needs (re)processing. A
previously-*failed* page is never treated as permanently cached —
`isCacheValid` requires `success == true` — so a transient failure
(e.g. the engine was briefly unavailable) doesn't permanently block
that page from ever being retried.

**Persistence.** `OcrPageResult` round-trips through
`KnowledgeSessionRecord.ocrPageResults` (`session.json`, backward-
compatible default `[]`) exactly like `EvidenceRegion`/`EvidenceLink`/
`ProcedureStep` before it — "Future extensions shall build upon this
model without requiring changes to existing session files" (SDD-021),
confirmed true here: a session file saved before Work Package 013
loads with an empty OCR result list, no migration needed.
`KnowledgeSessionService.buildDuplicate` (Session Browser "Duplicate")
carries `ocrPageResults` over **unchanged**, for the same reason it
will still validate: the duplicate's copied files are byte-identical,
so the content fingerprint still matches.

**When OCR actually runs.** On-demand, the first time the OCR Layer
Viewer opens for a source — not automatically on attach (import), and
not eagerly for every source in a session. Opening the dialog always
calls `FoundationRuntimeNotifier.runOcrForSource`, which performs its
own cache-validity check first; a fully-cached, unchanged source
returns almost immediately with zero engine invocations. This is what
makes "reopening a session shall not rerun OCR" and "support cache
invalidation when Source Material changes" simultaneously true: the
check itself is cheap (one file hash), so it is always safe to run,
and real reprocessing only happens when something has actually
changed.

---

## OCR Overlay

STUDIO-TASK-000035: "Display: Original page, OCR overlay, Confidence
heat map, Toggle overlay. Engineers may: Show OCR, Hide OCR. No editing
yet." Implemented as a dialog (`lib/knowledge/workspaces/ocr_layer_viewer_dialog.dart`,
`showOcrLayerViewerDialog`) — not a new panel, the same "dedicated
dialog for a substantial new interactive surface" precedent Work
Packages 010/011 already set for the Procedure Builder, Specification
Editor, and Knowledge Session Graph, keeping SDD-016's seven-panel
Knowledge Studio layout frozen.

* **PDF sources** reuse `pdfrx`'s `PdfViewer` a second time
  (independent of the main Source Viewer's own instance), overlaying
  word boxes via `pageOverlaysBuilder` — the identical mechanism
  `PdfSourceViewer` already uses for Evidence Region rectangles, so
  pan/zoom/fit and the overlay's fraction-to-pixel math need no new
  code.
* **PNG/JPG sources** render inside a fixed-size canvas (`InteractiveViewer`
  + `Image.file` + `Stack`/`Positioned`), sized to `OcrPageResult`'s own
  aspect ratio.
* **TIFF sources** use the same fixed-size canvas, but the "original
  page" itself shows a placeholder rather than true pixels — see §
  Architectural Observations.

**Toggle overlay** (`FoundationServiceState.ocrOverlayVisible`,
Connection-Manager-owned per this work package's own "Extend support
for: ... OCR overlay visibility") shows or hides every word box at
once. **Confidence heat map** is a second, independent toggle (local
dialog state) that changes *how* a visible overlay renders: plain
outlines, or each box tinted along a continuous red→yellow→green
gradient (`Color.lerp`, two stops at 50% confidence) — a literal heat
map, not a small number of hard buckets. No editing exists anywhere in
this view, per the work package's own explicit "No editing yet."

---

## Search Model

STUDIO-TASK-000036: "OCR text becomes searchable. Support: Find, Find
Next, Highlight. Search remains local to Source Material."

`OcrSearchService.find` (pure, `lib/knowledge/services/ocr_search_service.dart`)
takes one source's cached `OcrPageResult`s and a query, and returns
every match as an `OcrSearchMatch` (page + the word indices the match
overlaps). Matching is case-insensitive **substring search over each
line's reconstructed text** (words sharing an `OcrWord.lineIndex`,
joined by a single space) rather than per-word-only — so a multi-word
query like "torque spec" matches even though "Torque" and "Spec" are
two separate `OcrWord`s, as long as they're on the same printed line.
Deliberately does not match across a line break: for printed
engineering text (a torque-spec table row, a parts-list line), a line
boundary delimits one visually-coherent phrase far more often than it
splits one, and "OCR is deterministic" reads most naturally as
"match what a human reading the page would recognize as one phrase."

**Local to Source Material, local widget state.** Unlike `commitPlan`/
`ocrPageResults`/every other genuinely shared piece of session state,
"which match is currently selected" and the query text itself live in
the OCR Layer Viewer dialog's own `State`, not the Connection Manager —
the same category of decision `PdfSourceViewer`'s own drag-gesture
state already makes (`docs/EVIDENCE_MODEL.md`'s `_addRegionArmed`/
`_dragStart`). This work package's Connection Manager extension list
names "OCR state, Current OCR page, OCR overlay visibility" but not
search state — a reasonable literal reading, since nothing outside this
one dialog ever needs to know what's currently searched or which match
is selected. **Find Next** cycles through matches in page-then-reading
order, wrapping around; navigating to a match on a different page moves
the PDF viewer to that page automatically. **Highlight** renders the
current match's word box(es) in the selection color, distinct from
every other (non-heat-map) box.

---

## Confidence Model

Tesseract's own `conf` column is `0`–`100` per word (`-1` for
structural, non-word rows, which `TesseractTsvParser` skips entirely).
`OcrWord.confidence` normalizes this to `0.0`–`1.0` — consistent with
every other fraction in this codebase (`OcrBoundingBox`, `EvidenceRegion`
coordinates) using the same `0.0`–`1.0` convention rather than a mixed
scale. `OcrPageResult.averageConfidence` is the mean of a page's word
confidences (`0` for an empty/failed page — the same honest-zero
convention `CommitPlan.mergeOperationCount` and others already use for
"nothing to average"). The Property Inspector's "Confidence" field
(`FoundationServiceState.ocrAverageConfidenceFor`) is the mean across
every *successfully* OCR'd page of a source, weighting each page
equally regardless of its word count — a reasonable, undocumented-by-
the-spec choice (word-count-weighting was considered and rejected: a
sparse page with 3 low-confidence words would otherwise be invisible
next to a dense page with 200 high-confidence ones, when both are
equally worth an engineer's attention).

The confidence heat map (§ OCR Overlay) interpolates this same `0.0`–
`1.0` value continuously between `StudioColors.error` (red, `<50%`)
through `StudioColors.warning` (yellow, `50%`) to `StudioColors.success`
(green, `100%`).

---

## Package Selection Rationale

**Chosen: Tesseract OCR, invoked as an external process, parsed via
its `tsv` output format.**

At least three alternatives were compared, per this work package's own
instruction:

1. **`flutter_ocr_native`** (pub.dev, MIT, actively published) — the
   only Flutter *plugin* found with genuine Windows desktop support
   (via `Windows.Media.Ocr`, the OS's own built-in engine) and a
   structured `blocks → lines → elements` result shape with confidence
   and bounding boxes. Rejected on closer inspection: its actual
   feature surface is an ID-document/KYC scanning SDK (Aadhaar/
   passport/driving-license/cheque field extraction, automatic
   document-type classification, face extraction) with content-based
   rejection behavior — `HandwrittenTextException` ("Document rejected
   as non-printed") and English-only text filtering ("non-Latin
   scripts auto-filtered"). Engineering documents legitimately contain
   handwritten annotations, stamps, and non-English text (parts
   catalogs, multilingual warning labels); a package whose core design
   intent is to *classify and selectively reject* document content is
   the wrong shape for "OCR shall never infer engineering meaning" and
   "OCR is deterministic," independent of which specific methods this
   work package would have called — the risk is in what the underlying
   `readFromBytes`/`readFromPdf` calls might silently filter or reject
   before Studio ever sees a result.
2. **`flusseract`** (pub.dev, MIT, Tesseract FFI bindings) — genuinely
   wraps the same underlying engine ultimately chosen, with real
   Windows support. Rejected: last published roughly two years before
   this work package, requiring a ~10-minute from-source native build
   step for consumers (compiling Tesseract and its dependencies), and
   its documented API surface does not clearly expose per-word
   confidence/bounding-box data — only a single concatenated text
   string in the shown examples. Both the staleness and the
   unconfirmed structured-output capability made it a worse fit than
   driving Tesseract directly.
3. **`tesseract_ocr`** (pub.dev, BSD-3-Clause) — Android/iOS only, no
   Windows desktop support at all. Ruled out immediately for this
   platform.
4. **Cloud OCR APIs** (Google Vision, Azure Computer Vision, AWS
   Textract) — briefly considered and rejected outright: violate
   "local/offline processing," and introduce a network dependency and
   a data-privacy concern for engineering documents that may be
   proprietary.

**Why Tesseract itself, via an external process rather than an
in-process FFI binding.** Tesseract (Apache 2.0) is the most mature,
widely-deployed open-source OCR engine — actively maintained by Google
(`github.com/tesseract-ocr/tesseract`), with first-class support for
exactly the structured output this work package requires (`tsv`
format: text, confidence, pixel bounding box, and block/paragraph/
line/word reading-order hierarchy, confirmed against a real
`tesseract 5.4.0.20240606` installation before any parsing code was
written — see the real captured TSV sample in
`test/tesseract_tsv_parser_test.dart`), runs entirely locally and
offline once installed, and its trained-data model system directly
supports "future engineering document workflows" (100+ languages,
custom-trainable for domain-specific fonts/symbols, without any Studio
code change). No Dart package exists that both bundles Tesseract
automatically (the way `pdfrx` bundles PDFium) and exposes its full
structured output reliably and currently — so Studio depends on a
system-installed `tesseract` executable directly, invoked via
`Process.run` and parsed via its documented, stable `tsv` CLI contract,
the same way this project's own build toolchain already depends on a
system-installed `flutter`/`cmake` without vendoring either. See §
Architectural Observations for the consequence of this being an
external, not-bundled dependency.

**No new Flutter package for the OCR Layer Viewer or search UI** —
built entirely on `pdfrx` (already a dependency), `InteractiveViewer`/
`Stack`/`Positioned` (Flutter framework), and plain `TextField`/
`IconButton` widgets. `package:crypto` (Dart-team-maintained, BSD-3, no
native code, already a transitive dependency via `pdfrx`) was added as
a direct dependency specifically for `OcrCacheService`'s SHA-256
fingerprinting — the only new package this work package adds.

---

## Architectural Observations

* **Tesseract is an external, system-installed dependency — the first
  of its kind in this project.** Every native dependency before this
  one (`oep_foundation_bridge.dll`, `pdfium.dll` via `pdfrx`) is built
  or bundled automatically as part of `flutter build windows`, with
  nothing for an engineer to install separately. Tesseract cannot be
  bundled the same way without either vendoring a multi-hundred-
  megabyte language-data-inclusive binary distribution into this
  repository or introducing a build-time download step, neither of
  which any existing Flutter/Dart package does reliably for Windows
  desktop today (see § Package Selection Rationale). `TesseractOcrEngine.isAvailable()`
  checks for it before any OCR run and surfaces a clear, professional
  error (`FoundationServiceState.ocrErrorMessage`) rather than a raw
  process failure when it's missing — but genuinely offering OCR
  out-of-the-box, with zero setup, the way this project's Requirements
  read for every other capability, would require either a future work
  package that vendors Tesseract's binaries into this repository (with
  the corresponding license/size/version-pinning tradeoffs that
  implies) or accepting this one external prerequisite permanently.
  Flagged here explicitly rather than silently treated as solved.
* **TIFF preview is a genuine, narrow gap: OCR supports it, on-screen
  preview does not.** Flutter's built-in image codecs (used by
  `Image.file`, both in `SourceViewerPanel`'s `_ImagePreview` and the
  OCR Layer Viewer) cannot decode TIFF — only PNG/JPG/GIF/BMP/WEBP.
  Tesseract itself reads TIFF natively (via `libtiff`, confirmed
  present in the installed engine's own `--version` output) since it
  never goes through Flutter's image pipeline — Studio just passes the
  file path directly to the `tesseract` process. Resolved with graceful
  degradation, not a stop-for-review escalation: the OCR Layer Viewer's
  "original page" area shows a plain placeholder for TIFF (sized to the
  correct aspect ratio from the OCR result's own `imageWidth`/
  `imageHeight`) while the word-box overlay, confidence heat map, and
  search all work identically to PNG/JPG — a narrow rendering-capability
  gap with a clear, non-architectural answer (this project's existing
  `_UnsupportedPreview`/error-builder precedent already handles "can't
  render this format" gracefully elsewhere), not the kind of genuine
  irreconcilable conflict this work package's instructions say to stop
  for. Pulling in a general-purpose image-decoding package (e.g.
  `package:image`) purely to add TIFF *preview* would be scope creep
  beyond this work package's actual OCR tasks.
* **Search is line-scoped, not page- or session-scoped.** A query
  never matches across a line break (§ Search Model) — a deliberate,
  documented judgment call reflecting how printed engineering text is
  actually laid out, not a limitation discovered by accident.
* **A real bug this work package's own manual verification caught, that
  synthetic unit tests did not**: `TesseractTsvParser` originally split
  Tesseract's `tsv` output on `'\n'` alone. On this Windows
  installation, `tesseract` emits `\r\n` line endings, leaving a
  trailing `'\r'` silently attached to every recognized word's text —
  invisible in casual inspection, but enough to break exact-substring
  search entirely (`"oil\r filter"` is not a substring of `"oil
  filter"`). The hand-written TSV fixtures in this work package's own
  unit tests used bare `'\n'` and never exercised this path. Caught
  only once a real, `tesseract`-generated PNG was searched through the
  actual running application — fixed by splitting on `RegExp(r'\r\n|\r|\n')`
  instead, with a regression test added
  (`test/tesseract_tsv_parser_test.dart`) reproducing the exact CRLF
  scenario. Recorded here as the concrete argument for why this work
  package's "Manual verification against real engineering documents"
  requirement is not redundant with unit testing that only exercises
  hand-authored fixtures — the two catch different classes of bug.
