# Engineering Entity Extraction

Introduced in Work Package 014 (STUDIO-TASK-000038 Entity Extraction
Engine, STUDIO-TASK-000039 Entity Review Workspace, STUDIO-TASK-000040
Pattern Library, STUDIO-TASK-000041 Entity Validation). Recognizes
engineering values — torque specs, part numbers, voltages, wire
colors, and ten other categories — inside already-recognized OCR text
via deterministic pattern matching, one layer above Work Package 013's
OCR Pipeline. "Entity extraction operates only on OCR evidence."
"Pattern matching shall be deterministic." "Every extraction must be
reproducible from the same OCR input." No AI, no LLMs, no machine
learning — regular expressions and normalization functions, nothing
that infers or guesses.

An `EngineeringEntity` is a Workspace artifact — SDD-015 Layer 2
("Extracted Artifacts... machine-readable... not Engineering
Objects"), the same tier `OcrPageResult`/`EvidenceRegion` already
occupy. It becomes a Knowledge Candidate only after explicit engineer
acceptance (§ Review Workflow); "no automatic engineering
interpretation beyond deterministic pattern matching."

For OCR itself, see `docs/OCR_PIPELINE.md`. For the surrounding
workspace layout and Connection Manager ownership pattern, see
`docs/KNOWLEDGE_STUDIO.md`.

---

## Pattern Engine

```dart
class EngineeringPattern {
  final String id;
  final EngineeringEntityType type;
  final String label;
  final RegExp regex;
  final String Function(String matchedText) normalize;
}
```

A pure data class — no `Widget`, no `BuildContext`, nothing UI-shaped
("no hardcoded UI logic" reads literally: the pattern itself must be
inert data, not just "not currently rendering anything").
`EngineeringPatternLibrary` (`lib/knowledge/services/engineering_pattern_library.dart`)
is a static `List<EngineeringPattern>` — the *only* place regex
patterns live; `EngineeringEntityExtractionService` is the only reader,
and the Property Inspector only ever looks a pattern up by the id an
already-extracted entity recorded (`patternFor`), never by re-matching.

**Line-scoped, exactly like `OcrSearchService`** (Work Package 013):
`EngineeringEntityExtractionService._extractFromPage` groups a page's
`OcrWord`s by `lineIndex`, reconstructs each line's text (words joined
by a single space, tracking each word's start offset in that
reconstructed string), and runs every pattern's `regex.allMatches`
against that one line at a time — never across a line break. Printed
engineering values (a torque-spec table row, a wire-gauge callout) are
overwhelmingly single-line; this reuses an already-established,
already-documented convention rather than inventing a second
cross-line joining rule.

**Mapping a regex match back to `OcrWord`s.** A match's `[start, end)`
character range (within the reconstructed line) is compared against
each word's own tracked start offset and text length; any word whose
span overlaps the match's span is included. From the overlapping
words:

* **Bounding Box** — the union rectangle (min `x`/`y`, max `x+width`/
  `y+height`) of every overlapping word's `OcrBoundingBox`.
* **Confidence** — the mean of every overlapping word's
  `OcrWord.confidence`, `0.0`–`1.0`. Deliberately only the words the
  match actually spans, not every word on the line — e.g. matching
  `"24 Nm"` inside the line `"Torque: 24 Nm"` averages only the `"24"`
  and `"Nm"` words' confidence, not `"Torque"`'s, since that word isn't
  part of what was recognized.

Both are fully deterministic functions of the OCR input — the same
`OcrPageResult`s always produce the same entities, satisfying "every
extraction must be reproducible from the same OCR input" without any
extra bookkeeping.

### Cache Reuse

`extractForSource` takes the source's current `OcrPageResult`s plus
whatever `EngineeringEntity`s already exist for *any* source (it reads
and returns only the ones matching `source.id`, ignoring the rest).
Per page: if an already-extracted entity's own
`EngineeringEntity.sourceFingerprint` still matches that page's current
`OcrPageResult.sourceFingerprint`, every entity already extracted from
that page is kept **completely unchanged** — preserving whatever
`EngineeringEntityStatus` (pending/accepted/ignored) and
`createdCandidateId` the engineer already assigned. Only a page whose
fingerprint has changed (re-OCR'd against updated source content) has
its old entities dropped and freshly re-extracted as new, pending
suggestions. This is exactly `OcrCacheService`'s own page-level
fingerprint-reuse contract (`docs/OCR_PIPELINE.md` § OCR Cache), applied
one layer up — re-opening the Entity Review Workspace never silently
discards an engineer's prior accept/ignore decisions just because the
whole source got re-extracted.

---

## Entity Model

```dart
class EngineeringEntity {
  final String id;
  final EngineeringEntityType type;
  final String matchedPatternId;   // EngineeringPattern.id
  final String extractedText;      // raw OCR text, verbatim
  final String normalizedValue;    // canonical form, e.g. "24 Nm"
  final String sourceId;
  final int page;                  // 1-based, matches OcrPageResult.page
  final OcrBoundingBox boundingBox;
  final double confidence;         // 0.0-1.0
  final int characterStart, characterEnd;  // within the OCR line text
  final String sourceFingerprint;  // for cache-reuse (see above)
  final DateTime extractedTime;
  final EngineeringEntityStatus status;    // pending | accepted | ignored
  final String? createdCandidateId;        // set once, on acceptance
}
```

Matches STUDIO-TASK-000038's own "Entity Output" field list (UUID,
Entity Type, Extracted Text, Normalized Value, Source Material, Page,
Bounding Box, Confidence, Character Range) plus what the implementation
needs beyond that literal list: `matchedPatternId` (the Property
Inspector's "Pattern Match"), `sourceFingerprint` (cache invalidation,
mirroring `OcrPageResult`), `extractedTime`, `status`, and
`createdCandidateId`.

**`EngineeringEntityStatus` is `pending | accepted | ignored`** —
deliberately *not* reusing `KnowledgeCandidateStatus`'s
`pending`/`accepted`/`rejected` vocabulary. "Ignore" and "Reject" are
not the same action: rejecting a Knowledge Candidate is a considered
engineering judgment about that candidate's validity, recorded as part
of the session's review trail. Ignoring an extracted entity just means
"this deterministic pattern match isn't something I want to act on" —
it carries no engineering judgment, and per this work package's own
text, "ignoring shall never delete OCR evidence": the underlying
`OcrPageResult` that produced the match is completely untouched either
way.

**`createdCandidateId` is set once, on acceptance, and never cleared**
— the same one-way-set precedent `KnowledgeCandidate.committedObjectId`
established in Work Package 012. An accepted entity always points at
the Knowledge Candidate it produced, for the lifetime of the session.

---

## Pattern Library

`EngineeringPatternLibrary.patterns` implements all **14** entity types
STUDIO-TASK-000038's "Detect: Support recognition of..." list names:
Torque Specifications, Voltage Values, Resistance Values, Pressure
Values, Temperature Values, Dimensions, Fastener Sizes, Part Numbers,
Tool References, Fluid Specifications, Fuse Ratings, Connector
Identifiers, Wire Colors, Wire Gauges. Several types have more than one
pattern (e.g. metric vs. imperial torque, SAE vs. metric fasteners),
for **17** patterns total. See § Architectural Observations for the
"Initial Pattern Categories" vs. "Detect" list discrepancy this
resolves.

Each pattern's `normalize` function converts whatever exact text
matched into one canonical display form — e.g. `"24nm"`, `"24 N.m"`,
and `"24 N·m"` all normalize to `"24 Nm"`; `"BLK"` and `"Black"` both
normalize to `"Black"` (`_normalizeWireColor`'s abbreviation table).
Regexes are case-insensitive where the source text's casing is
inherently unpredictable (units, wire-color abbreviations) and
case-sensitive where casing itself is meaningful (fastener/part-number
formatting conventions).

**A real regex bug this work package's own unit tests caught before
manual verification began**: the Resistance pattern originally ended
in `\b` (word boundary) immediately after the ohm symbol `Ω`. Dart's
`\b` is defined over ASCII word characters (`[A-Za-z0-9_]`); `Ω`
(Greek capital omega, U+03A9) is not one, so `\b` never matches between
`Ω` and end-of-string or whitespace — the pattern silently failed to
match `"4.7kΩ"` at all. Fixed by replacing the trailing `\b` with a
negative lookahead, `(?!\w)`, which succeeds at end-of-string the same
way it succeeds before whitespace. Caught by
`test/engineering_pattern_library_test.dart`'s own resistance-pattern
test, not by manual verification — the inverse of Work Package 013's
CRLF finding (see `docs/OCR_PIPELINE.md` § Architectural Observations),
and a reminder that both verification paths catch real, different
classes of bug.

---

## Validation Model

`EntityValidationService.computeValidation` (pure,
`lib/knowledge/services/entity_validation_service.dart`) implements
STUDIO-TASK-000041's "Detect: Duplicate entities, Invalid units,
Impossible values, Malformed specifications, OCR uncertainty. Display
validation warnings. No automatic correction." Reuses `ValidationSeverity`
(`ok`/`warning`/`error`) from `candidate_validation_result.dart` rather
than inventing a parallel severity enum — the same tri-level model
`CandidateValidationResult` already established.

* **Duplicate entities** (warning) — two or more non-ignored entities
  on the same source sharing the same type and normalized value. An
  ignored duplicate never counts toward this check, so ignoring one of
  two duplicates clears the warning on the one that remains.
* **Malformed / invalid unit** (error) — an empty normalized value, or
  a numeric-typed entity (torque/voltage/resistance/pressure/
  temperature/dimension/wire gauge/fuse rating) whose normalized value
  carries no parseable leading number. In practice this mostly cannot
  fire through the normal extraction path, since every pattern is
  already unit-anchored and only normalizes text it successfully
  matched — kept as an explicit, defensive check because this work
  package's own Requirements name both findings by name.
* **Impossible values** (error) — per-type plausible-range checks:
  torque `0`–`1000`, voltage `|v| ≤ 100000`, resistance `≥ 0`, pressure
  `≥ 0`, temperature `≥` absolute zero (`-273.15 °C` / `-459.67 °F`,
  selected by the normalized unit), wire gauge `0`–`40` AWG, fuse
  rating `0`–`600` A, dimension `≥ 0`. Fastener sizes, part numbers,
  tool references, fluid specifications, connector identifiers, and
  wire colors have no numeric range and are never flagged here.
* **OCR uncertainty** (warning) — `confidence < 0.6`
  (`EntityValidationService.lowConfidenceThreshold`). A judgment call
  with no spec-given number, chosen the same way `OcrPageResult`'s own
  confidence-related thresholds were: low enough that a clean scan's
  real matches don't trigger it, high enough that a plausible
  garbled-OCR misread does.

---

## Review Workflow

STUDIO-TASK-000039: "Allow engineers to inspect extracted entities."
The Entity Review Workspace
(`lib/knowledge/workspaces/entity_review_workspace_dialog.dart`,
`showEntityReviewWorkspaceDialog`) is a dialog scoped to one Source
Material — extraction "operates only on OCR evidence," so there is no
session-wide entity view, only a per-source one, the same scoping the
OCR Layer Viewer itself uses. Opened via a new "Extract Entities"
toolbar button on the OCR Layer Viewer
(`lib/knowledge/workspaces/ocr_layer_viewer_dialog.dart`) — another
dedicated dialog for a substantial interactive surface, keeping
SDD-016's seven-panel Knowledge Studio layout frozen, the same
precedent Work Packages 010/011/013 already set for the Procedure
Builder, Specification Editor, Knowledge Session Graph, and OCR Layer
Viewer itself.

Opening the dialog calls `extractEntitiesForSource` in its own
`initState` (extraction is cheap and cache-aware, so it's always safe
to call — the same "always safe to re-run, cache makes it fast"
property `runOcrForSource` already has). Provides:

* **Type filter, status filter** (All/Pending/Accepted/Ignored),
  **sort** (page/type/confidence), and free-text **search** (matches
  either extracted or normalized text).
* **Accept** — calls `FoundationRuntimeNotifier.acceptEntity`, which
  creates a Knowledge Candidate via the existing `addKnowledgeCandidate`
  (type: `entity.type.defaultCandidateType`, name: the normalized
  value, description naming the source/page/type, notes naming the
  matched pattern's label and the raw extracted text), then marks the
  entity accepted with the new candidate's id. Disabled once already
  accepted.
* **Ignore** — calls `ignoreEntity`, which only flips `status`; OCR
  evidence is never touched.
* **Navigate to Source** — mirrors the Evidence Browser's own
  established "Navigate" precedent exactly: select the entity, then
  close this dialog. The still-open OCR Layer Viewer watches
  `FoundationServiceState.selectedEntity` and jumps its own page view
  to the entity's page (`_lastNavigatedEntityId`-guarded, the same
  pattern `PdfSourceViewer` already uses for Evidence Regions). Required
  extending `showOcrLayerViewerDialog` with an `initialPage` parameter,
  using `pdfrx`'s own `PdfViewer.file(..., initialPageNumber: ...)`.

### Connection Manager

`FoundationServiceState.engineeringEntities` (persisted,
`List<EngineeringEntity>`) and `selectedEntity` (the ninth mutually-
exclusive selection field — every pre-existing `select*` method now
also clears it). Derived getters, recomputed fresh on every read, never
independently stored:

* `engineeringEntitiesForSource(sourceId)` — sorted by page, then
  character start.
* `entityValidation` — `Map<String, EntityValidationResult>` for every
  entity in the session, via `EntityValidationService.computeValidation`.
* `patternFor(entityId)` — looks up `EngineeringPatternLibrary.byId`
  using the entity's own recorded `matchedPatternId`; never re-derived
  by re-matching the OCR text.

`extractEntitiesForSource` throws `KnowledgeValidationException` if
there is no active session, the source doesn't exist, or the source
has no *successful* OCR results yet — "entity extraction operates only
on OCR evidence" is enforced at the point of the call, not just
documented as an expectation.

### Property Inspector

`EngineeringEntityProperties`
(`lib/knowledge/inspector/engineering_entity_properties.dart`) is the
Property Inspector's new Engineering Entity mode (added as the first
element of the panel's mutually-exclusive selection tuple): Entity ID,
Entity Type, Extracted Text, Normalized Value, Confidence, Status,
Knowledge Candidate id (if accepted); a **Pattern Match** section
(matched pattern label, character range); a **Source Context** section
(source name, page, extracted time); and a **Validation** section
(colored issue list, red for error / yellow for warning), shown only
when at least one issue exists.

### Persistence

`KnowledgeSessionRecord.engineeringEntities` round-trips through
`session.json` exactly like `ocrPageResults`/`EvidenceRegion`/
`ProcedureStep` before it — backward-compatible default `[]`, no
migration needed for sessions saved before this work package.
`KnowledgeSessionService.buildDuplicate` carries it over **unchanged**,
for the same reason `ocrPageResults` does: the duplicate's copied
source files are byte-identical, so every entity's own
`sourceFingerprint` still matches.

---

## Architectural Observations

* **"Initial Pattern Categories" (11) vs. "Detect" (14) — resolved as a
  non-exhaustive-subset reading, not a hard cap.** STUDIO-TASK-000040's
  own "Initial Pattern Categories" list names eleven categories;
  STUDIO-TASK-000038's "Detect: Support recognition of..." list names
  fourteen, including three ("Initial" omits Dimensions, Tool
  References, Fluid Specifications, Connector Identifiers) not present
  in the shorter list. This library implements all fourteen — reading
  "Initial" as an illustrative starting subset of a still-growing list
  (STUDIO-TASK-000040 itself is titled "Pattern Library... Patterns
  shall be configurable," implying growth is expected), and "Support
  recognition of" as the more literal, complete requirement. Not
  treated as a blocking conflict: both lists point the same direction
  (recognize more engineering values, deterministically), and
  implementing the union rather than the intersection cannot violate
  either requirement's text.
* **`defaultCandidateType` mapping is grounded in SDD-015's own
  vocabulary, not invented.** SDD-015's Specification Model names
  "Torque, Voltage, Resistance, Pressure, Temperature, Clearance" as
  Specification examples; its Component Model says Components "may
  possess: Part Numbers." This work package's mapping reuses that
  text directly: Torque/Voltage/Resistance/Pressure/Temperature/
  Dimension/Fastener Size/Fuse Rating/Wire Color/Wire Gauge →
  `specification`; Part Number/Connector Identifier → `component`
  (both identify a physical part); Tool Reference → `tool`; Fluid
  Specification → `fluid` (both map onto candidate types that already
  exist for exactly this purpose). The engineer may still change the
  candidate's type before saving — this is only the sensible starting
  default STUDIO-TASK-000039 asks for ("Acceptance shall create a
  Knowledge Candidate"), not a restriction.
* **A real, non-synthetic OCR-noise finding from manual
  verification**: a fixture line reading "Coolant temperature sender
  resistance is 4.7kOhms at 20C" was OCR'd by a real Tesseract
  5.4.0.20240606 installation as `"4.7kKOhms"` — an extra `K` inserted
  by the recognizer, not present in the source text. The Resistance
  pattern correctly does *not* match this garbled text (there is no
  pattern for `"kK"` as a unit prefix, nor should there be one invented
  to paper over a recognition error). This is the expected, correct
  behavior of "entity extraction operates only on OCR evidence" — a
  pattern is only as good as the text Tesseract actually produced, and
  a genuine OCR misread silently costing one entity match is a
  real-world limitation of pattern-matching-on-OCR-output, not a
  Studio defect to fix. Recorded here rather than "fixed" by, say,
  fuzzy-matching the unit prefix, which would trade determinism for a
  narrow accuracy gain — exactly the tradeoff "pattern matching shall
  be deterministic" rules out.
* **Manual verification exercised a genuine cross-page duplicate**: the
  synthetic manual fixture repeats the exact same "Drain plug torque is
  35 ft-lb" specification verbatim on page 1 (as a fact) and page 3
  (inside a numbered procedure step) — a realistic authoring pattern in
  real service manuals, not a contrived test case. Both were correctly
  extracted as separate entities and both were correctly flagged as
  duplicates of each other by `EntityValidationService`, confirming the
  duplicate check works across page boundaries within one source, not
  only within a single page.
