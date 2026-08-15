# Engineering Context Analysis

Introduced in Work Package 015 (STUDIO-TASK-000042 Context Detection
Engine, STUDIO-TASK-000043 Context Explorer, STUDIO-TASK-000044
Context Validation, STUDIO-TASK-000045 Context Navigation). Groups
extracted engineering entities into logical contexts — a Torque
Specifications section, a Parts List, a Warning callout — using only
deterministic document structure: headings, layout, page structure,
and entity proximity. One layer above Work Package 014's Engineering
Entities, itself one layer above Work Package 013's OCR text. No AI,
no LLMs, no machine learning, no Repository changes — "context
analysis augments engineering evidence only."

An `EngineeringContext` is a Workspace artifact, exactly like
`EngineeringEntity`/`OcrPageResult` before it. It is never a Knowledge
Candidate and never a Foundation Engineering Object — "Contexts
organize engineering evidence" (this work package's own Architecture
Rules), nothing more.

For entity extraction, see `docs/ENGINEERING_ENTITY_EXTRACTION.md`. For
OCR itself, see `docs/OCR_PIPELINE.md`. For the surrounding workspace
layout and Connection Manager ownership pattern, see
`docs/KNOWLEDGE_STUDIO.md`.

---

## Context Model

```dart
class EngineeringContext {
  final String id;
  final EngineeringContextType type;
  final String title;              // the detected heading/callout line's text, verbatim
  final String sourceId;
  final int pageStart, pageEnd;     // 1-based, inclusive — the context's true content extent
  final OcrBoundingBox boundingRegion;
  final List<String> childEntityIds;
  final double confidence;          // 0.0-1.0
  final String? parentContextId;    // enclosing context, null for top-level
  final String sourceFingerprint;   // whole-source, not per-page — see § Detection Rules
  final DateTime detectedTime;
  final EngineeringContextStatus status;  // pending | accepted | ignored
}
```

Matches STUDIO-TASK-000042's own "Context Output" field list (UUID,
Context Type, Title, Source Material, Page Range, Bounding Region,
Child Entities, Confidence) plus `parentContextId` — needed to
implement the Property Inspector's explicitly-requested "Parent
Context" and Context Validation's explicitly-requested "Invalid
hierarchy" check, neither of which is meaningful without some notion of
context-to-context nesting (see § Architectural Observations),
`sourceFingerprint`/`detectedTime`/`status` mirroring the same fields
`EngineeringEntity` already carries for the same reasons.

**`EngineeringContextType`** — 12 values from STUDIO-TASK-000042's
"Detect: Support contexts including..." list: Procedure, Component,
Connector, Circuit, Wiring Section, Torque Table, Specification Table,
Warning, Note, Figure, Diagram, Parts List.

**`EngineeringContextStatus` is `pending | accepted | ignored`** — the
same vocabulary `EngineeringEntityStatus` established in Work Package
014, for the same reason: a Context is never a Knowledge Candidate, so
accepting or ignoring one carries no candidate-review implication.
**Accepting a context creates nothing** — unlike accepting an entity
(which creates a Knowledge Candidate), accepting a context is purely a
review-status marker meaning "I reviewed this grouping and agree it is
correct." This is a deliberate, load-bearing distinction: "Contexts are
not Knowledge Candidates" (Architecture Rules) and "no automatic
repository changes" (STUDIO-TASK-000043) both rule out any
candidate-creating side effect here.

---

## Detection Rules

`ContextDetectionService` (`lib/knowledge/services/context_detection_service.dart`,
pure) derives contexts from OCR layout alone — no engineering meaning
beyond document organization, per this work package's own explicit
instruction ("Use document structure, layout, headings, tables, and
entity proximity only. Do not infer engineering meaning beyond
deterministic document organization").

### Heading and Callout Detection

Every OCR line (grouped by `OcrWord.lineIndex`, exactly like
`EngineeringEntityExtractionService`/`OcrSearchService` already do) is
checked against two independent rules:

1. **Callout keywords** (Warning, Note) — matched at the start of a
   line, *regardless of line height or word count*. Real service
   manuals typically print "WARNING"/"CAUTION"/"NOTE" inline at normal
   body text size, not as a larger heading — confirmed against real
   Tesseract output during manual verification (see § Architectural
   Observations).
2. **Section keywords** (the remaining ten types) — matched only on a
   line that is *both* short (≤ 8 words) *and* meaningfully taller than
   the document's median line height (`> 1.15×`). Line height is used
   as a proxy for font size, since Tesseract's own output carries no
   font-size or style metadata — real OCR output was confirmed to
   produce a genuine, exploitable height difference between headings
   and body text during manual verification (heading words ~70px vs.
   body words ~30-50px, in a real 300 DPI scan).

Keyword matching is checked in a deliberate priority order so a line
combining two keywords resolves to the more specific type — e.g.
"Torque Specification Table" matches Torque Table, not the generic
Specification Table, because the torque keyword is checked first.

### Major/Minor Tiering and Nesting

Every detected heading is one of two tiers:

* **Major** (section-level): Procedure, Component, Connector, Circuit,
  Wiring Section, Torque Table, Specification Table, Parts List. Each
  major heading opens a new top-level context that extends until the
  *next major heading* (or end of document) — a standard, deterministic
  "each heading starts a new section" segmentation.
* **Minor** (annotation-level): Warning, Note, Figure, Diagram. Each
  minor heading gets its own small context that extends until the
  *next heading of any tier* — and is assigned as a **child** of
  whichever major context's position currently encloses it (the last
  major heading positioned before it, if any), giving the Property
  Inspector's "Parent Context" and Context Validation's "Invalid
  hierarchy" real, structurally-grounded meaning without inventing a
  second segmentation scheme. A minor heading before any major one has
  no parent (top-level).

Containment is computed by **position** (page, then line index within
the page) — not by page number alone. An earlier implementation
compared only page numbers, which incorrectly treated a callout
appearing *before* a heading on the very same page as already inside
that heading's section; caught by this work package's own unit tests
before manual verification began (see § Architectural Observations).

**Page range** reflects the actual lines included in a context's range
— not merely "until the next heading's page," which can overstate the
range when the next heading is several content-free pages away, and
correctly includes a heading's own page even when other content on
that page precedes it.

**Child entities** are `EngineeringEntity` records whose own OCR line
falls within the context's line range — resolved precisely by
re-slicing the entity's recorded `[characterStart, characterEnd)`
against the reconstructed line text and confirming it matches the
entity's own `extractedText` verbatim (a stronger check than "this text
appears somewhere on the line," since it also validates the exact
offset). Entities whose line cannot be resolved this way fall back to
page-only containment on strictly-interior pages, to avoid
double-counting across a shared boundary page.

### Cache Reuse

Unlike entity extraction's per-page cache reuse, a context can span
**multiple pages**, so contexts are re-derived as a whole document
together: `sourceFingerprint` is a SHA-256 of every OCR page's own
fingerprint concatenated in page order. If a source's combined
fingerprint is unchanged, every existing context is returned completely
unchanged — preserving accept/ignore status and parent/child links. If
anything changed, the whole source is freshly re-detected. This is a
coarser granularity than `OcrCacheService`'s/`EngineeringEntityExtractionService`'s
own per-page reuse, a deliberate, documented judgment call: contexts
are inherently document-wide structures, so there is no meaningful
finer-grained unit to reuse independently.

---

## Context Navigation

STUDIO-TASK-000045: "Allow engineers to move through engineering
documents by context instead of pages... Selecting a context updates:
Source Viewer, OCR Viewer, Entity Viewer, Property Inspector."

* **Source Viewer** (`PdfSourceViewer`) and **OCR Viewer** (the OCR
  Layer Viewer) each independently watch
  `FoundationServiceState.selectedContext` and jump to its `pageStart`
  — the same `_lastNavigatedRegionId`/`_lastNavigatedEntityId`
  watch-and-jump pattern Work Packages 009/014 already established,
  applied a third time.
* **Entity Viewer** (the Entity Review Workspace) watches the same
  field and, when a context belonging to its own source becomes
  selected, applies a local filter restricting its list to that
  context's own `childEntityIds` — with a dismissible banner naming the
  active context and a "Clear" action. This is deliberately *local*
  filter state, not Connection-Manager-owned, mirroring how the Entity
  Review Workspace's own type/status/search filters already work.
* **Property Inspector** switches to Engineering Context mode via the
  same mutually-exclusive selection mechanism every other mode uses.

**Previous/Next Context** toolbar buttons on the OCR Layer Viewer cycle
`selectedContext` through the source's own context list (wrapping
around), respecting `FoundationServiceState.contextTypeFilter` when
set. STUDIO-TASK-000045's own "Navigate by: Procedure, Component,
Diagram, Table, Specification, Warning" is read as an illustrative
six-example subset of the full 12-type taxonomy (the same reading Work
Package 014 gave its own "Initial Pattern Categories" vs. "Detect"
list tension) — picking a type via the Context Filter, then cycling
next/previous through contexts of that type, is this feature's literal
implementation of "navigate by X."

---

## Validation Model

`ContextValidationService.computeValidation` (pure) implements
STUDIO-TASK-000044's "Detect: Empty contexts, Duplicate contexts,
Overlapping contexts, Orphaned entities, Invalid hierarchy... remains
informational only." Reuses `ValidationSeverity` from
`candidate_validation_result.dart`, the same tri-level model
`CandidateValidationResult`/`EntityValidationResult` already use.

* **Empty contexts** (warning) — `childEntityIds.isEmpty`.
* **Duplicate contexts** (warning) — two or more non-ignored contexts
  on the same source sharing type, title, and page range.
* **Overlapping contexts** (warning) — two non-ignored contexts on the
  same source whose page ranges intersect *without* a parent/child
  relationship between them. A nested minor context inside its own
  major parent's range is expected and never flagged.
* **Invalid hierarchy** (error) — a context whose `parentContextId`
  references a context that no longer exists, belongs to a different
  source, whose own page range falls outside the parent's, or whose
  parent chain contains a cycle.
* **Orphaned entities** — a separate derived set
  (`computeOrphanedEntityIds`, exposed as
  `FoundationServiceState.orphanedEntityIdsFor(sourceId)`), not a
  per-context finding: an `EngineeringEntity` claimed by no context at
  all, regardless of any claiming context's own accept/ignore status
  (ignoring a context's *grouping* is a judgment about the grouping,
  not a retroactive statement that its entities have no home).

---

## Persistence

`KnowledgeSessionRecord.engineeringContexts` round-trips through
`session.json` exactly like `engineeringEntities`/`ocrPageResults`
before it — backward-compatible default `[]`, no migration needed.
`KnowledgeSessionService.buildDuplicate` carries it over **unchanged**,
for the same reason: the duplicate's copied source files are
byte-identical, so the combined fingerprint still matches.

### Connection Manager

`FoundationServiceState.engineeringContexts` (persisted),
`selectedContext` (the tenth mutually-exclusive selection field — every
pre-existing `select*` method now also clears it), and
`contextTypeFilter` (ephemeral, Connection-Manager-owned per this work
package's own explicit "Extend support for: ... Context Filter" —
unlike the Entity Review Workspace's local filters, this one genuinely
lives in state, since the spec names it directly). Derived getters:
`engineeringContextsForSource(sourceId)`, `contextValidation`,
`orphanedEntityIdsFor(sourceId)`, `childEntitiesFor(contextId)`,
`parentContextOf(contextId)`, `contextStatisticsFor(contextId)` (child
entity count, average child confidence, count by entity type — the
Property Inspector's "Context Statistics").

`detectContextsForSource` requires an active session and at least one
successful OCR result, but — unlike entity extraction — does **not**
require prior entity extraction: a context derived purely from heading
structure with zero entities is valid, and would correctly surface the
"empty context" validation warning rather than being blocked outright.

`acceptContext`/`ignoreContext` only flip `status`.
`splitContext(contextId, atPage)` divides a context into two at a
chosen page boundary, reassigning child entities by page and starting
both halves `pending` (a fresh grouping judgment the engineer must
re-review). `mergeContexts(idA, idB)` combines two same-source contexts
into one (union of page ranges/child entities/bounding regions,
averaged confidence), also starting `pending`, keeping a shared parent
if both originals had the same one. Neither Split nor Merge triggers
any Repository or Knowledge Candidate side effect.

---

## Context Explorer

STUDIO-TASK-000043: "Provide a dedicated workspace for reviewing
engineering contexts." A dialog scoped to one Source Material
(`lib/knowledge/workspaces/context_explorer_dialog.dart`,
`showContextExplorerDialog`) — every context is itself source-relative,
so this mirrors the Entity Review Workspace's own identical scoping
choice, opened from a new "Context Explorer" button on the OCR Layer
Viewer.

Renders as an **expandable tree** by default — top-level contexts with
their nested minor children revealed by an expand/collapse chevron,
satisfying STUDIO-TASK-000043's "Support: Expand, Collapse" directly
from the major/minor nesting structure. Applying a type filter, status
filter, or search switches to a **flat, filtered list** instead — a
context and its parent can independently match or not match a filter,
so a tree view would otherwise have to invent rules for showing a
non-matching parent just to reach a matching child; a flat list avoids
that entirely. Supports Accept/Ignore/Split/Merge/Navigate to Source
per row, plus a two-tap Merge flow (pick one context, then pick a
second) since STUDIO-TASK-000043 names "Merge" as an action without
specifying its interaction mechanics.

---

## Architectural Observations

* **"Context Output"'s field list doesn't literally include a
  parent-context or child-context field, yet the Property Inspector
  and Validation sections explicitly ask for "Parent Context" and
  "Invalid hierarchy."** Resolved as a non-blocking, well-grounded
  extension: `parentContextId` implements exactly what those other two
  sections of the *same document* already ask for, rather than an
  invented feature — the major/minor tiering (§ Detection Rules) gives
  it real structural meaning derived purely from document layout, with
  no engineering-meaning inference involved.
* **"Navigate by: Procedure, Component, Diagram, Table, Specification,
  Warning" (six items) vs. the "Detect" list (twelve) — resolved as a
  non-exhaustive illustrative subset**, the same reading Work Package
  014 gave its own "Initial Pattern Categories" vs. "Detect" tension.
  Next/Previous Context navigation works across all twelve types, via
  the Context Filter.
* **A real position-vs-page-number bug, caught by unit tests before
  manual verification began**: the first implementation determined a
  minor context's parent by checking whether its *page number* fell
  within a major context's page range — which incorrectly parented a
  callout appearing *before* a heading on the very same page, since
  page-number containment alone can't distinguish "before" from
  "after" within one page. Fixed by comparing actual (page, line)
  position instead. The inverse of Work Package 014's own
  `\b`-after-`Ω` regex finding — another case of a real bug caught by
  the deterministic unit-test layer, not manual verification.
* **Real OCR confirmed the height-heuristic's core premise**: a
  genuine, exploitable line-height difference between headings (~70px)
  and body text (~30-50px) was observed in real Tesseract output
  against a 300 DPI-rendered fixture during manual verification, and
  "WARNING" itself was confirmed to render at ordinary body-text
  height — validating the design choice to detect callouts by keyword
  alone, independent of size, rather than requiring every heading-like
  signal to also be a size signal.
* **Manual verification exercised real cross-viewer synchronization**:
  selecting a context from the Context Explorer was confirmed, against
  the real compiled application, to simultaneously move both the
  background Source Viewer and the still-open OCR Layer Viewer to the
  same page — not merely asserted from code reading.
