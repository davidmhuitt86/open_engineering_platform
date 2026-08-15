# Knowledge Candidates: Model Reference

Work Package 010 (STUDIO-TASK-000022 Manual Knowledge Candidate
Authoring, STUDIO-TASK-000023 Procedure Builder, STUDIO-TASK-000024
Specification Editor, STUDIO-TASK-000025 Knowledge Candidate
Validation). Validates the frozen Knowledge Architecture v1 (SDD-013
through SDD-021), remaining **Studio-only: no AI, no OCR, no automatic
extraction, no repository commit, no Foundation modifications** —
identical scope discipline to Work Packages 007–009.

This document is the model reference for everything a Knowledge
Candidate can now carry: the candidate itself, Procedures and their
Steps, Specifications, and the Validation model that inspects all of
it. For session lifecycle, workspace layout, and general state
ownership, see `docs/KNOWLEDGE_STUDIO.md`. For the persisted file
format, see `docs/KNOWLEDGE_SESSION_FORMAT.md`. For Evidence
Region/Evidence Link/Page Selection and the PDF Source Viewer, see
`docs/EVIDENCE_MODEL.md`.

---

## Knowledge Candidate Model

`KnowledgeCandidate` (`lib/knowledge/models/knowledge_candidate.dart`)
gained three fields this work package — `notes`, `author`, `tags` —
alongside its existing identity/description/status fields. Still no
AI-era fields (confidence, supporting evidence, repository matches):
none of this work package's authoring is AI-driven either.

```dart
class KnowledgeCandidate {
  final String id;
  final KnowledgeCandidateType type;
  final String name;
  final String description;
  final String notes;         // New: free-form engineering notes
  final String author;        // New: who authored this candidate
  final List<String> tags;    // New: free-form labels
  final KnowledgeCandidateStatus status;   // Pending | Accepted | Rejected
  final DateTime createdTime;
  final DateTime? modifiedTime;
}
```

`author` is deliberately distinct from `KnowledgeSession.author` (the
session owner) — a session may accumulate candidates authored by more
than one engineer, even though only one author field exists at the
session level.

### Candidate Types

`KnowledgeCandidateType` (`lib/knowledge/models/knowledge_candidate_type.dart`)
expanded from five types to the ten this work package's Requirements
list names, mirroring more of SDD-015's Layer 3 Engineering Objects
and SDD-021's Evidence Object examples:

```
Component | Procedure | Specification | Tool | Material | Fluid |
Warning | Measurement | Image | Document
```

### Creating from Evidence

Work Package 010's Requirements: "Support creating Knowledge Candidates
from: Source Material / Page Selection / Evidence Region." Evidence
remains optional at creation time in every case (a candidate with none
displays a validation warning — see § Validation Model) — these are
three additional *entry points* into the same New Candidate dialog
(`lib/knowledge/review/knowledge_candidate_form_dialog.dart`,
extended with `initialName`/`initialDescription`/`initialType`/
`linkToRegionId` parameters), not three different creation flows:

* **From Evidence Region** — a "Create Knowledge Candidate from Region"
  action in the Evidence Browser (`lib/knowledge/workspaces/evidence_browser_dialog.dart`)
  pre-fills the candidate's name from the region's label and, on
  successful creation, immediately calls the existing
  `FoundationRuntimeNotifier.linkEvidence` (Work Package 009) to create
  a real `EvidenceLink` between the new candidate and that region.
* **From Source Material** — a matching action on each row in the
  Import Queue (`lib/knowledge/workspaces/import_queue_panel.dart`)
  pre-fills the candidate's name from the source's file name. No new
  link is created — see § Architectural Observations for why.
* **From Page Selection** — a matching action next to each selected
  page in the Property Inspector's Source Material mode
  (`lib/knowledge/inspector/source_material_properties.dart`)
  pre-fills the candidate's name from the source file name and page
  number. No new link is created, for the same reason.

`FoundationRuntimeNotifier.addKnowledgeCandidate` now returns the
created `KnowledgeCandidate` (previously `void`) so the dialog can
immediately act on its ID — the same pattern
`createEvidenceRegion` already established in Work Package 009.

### Duplicate

The Candidate List's "Duplicate" action
(`FoundationRuntimeNotifier.duplicateKnowledgeCandidate`) deliberately
does **not** call `KnowledgeSessionService.validateCandidateName` —
unlike New/Edit, which reject a duplicate name outright, Duplicate is
specified to allow same-named copies, surfaced afterward as a
non-blocking finding by the Validation model instead of being rejected
at creation time. The duplicate copies name/type/description/notes/
author/tags but starts with a fresh ID, `Pending` status, and **no**
Evidence Links, Procedure Steps, or Specification Details — those are
`candidateId`-keyed side tables the original candidate ID still owns.

---

## Procedure Model

Procedure Steps remain part of a Procedure Knowledge Candidate — per
this work package's explicit architectural guidance — but "part of"
means "owned by," not "embedded in": `ProcedureStep`
(`lib/knowledge/models/procedure_step.dart`) is a separate,
`candidateId`-keyed list, mirroring how `EvidenceLink` and
`RelationshipCandidate` already reference candidates by ID rather than
nesting.

```dart
class ProcedureStep {
  final String id;
  final String candidateId;          // Owning Procedure candidate
  final String title;
  final String description;
  final String notes;
  final List<String> referencedCandidateIds;   // Other Knowledge Candidates
  final List<String> referencedRegionIds;      // Evidence Regions
  final DateTime createdTime;
  final DateTime? modifiedTime;
}
```

**Ordering is array position**, not an explicit `order` field — a
step's position within `KnowledgeSessionRecord.procedureSteps`,
filtered to one `candidateId`, is its step number. "Display automatic
step numbering" (this work package's Requirements) only ever needs a
step's position among its own siblings, and array position already
carries that unambiguously — the same way `KnowledgeSessionRecord`'s
existing lists (candidates, relationship candidates, evidence regions,
…) carry no explicit ordering field either.

### Procedure Builder

`lib/knowledge/workspaces/procedure_builder_dialog.dart`: a dedicated
editor dialog (not a new panel — SDD-016's seven-panel layout stays
frozen), opened from the Property Inspector's Knowledge Candidate mode
when `type == procedure` ("Open Procedure Builder"). Supports:

* **Insert / Delete / Duplicate step** — plain list operations against
  `FoundationRuntimeNotifier.addProcedureStep`/`deleteProcedureStep`/
  `duplicateProcedureStep`. Duplicate inserts the copy immediately
  after the original within that candidate's own step order.
* **Drag-and-drop reordering** — `ReorderableListView`, wired to
  `reorderProcedureStep(stepId, newIndex)`. Throws
  `KnowledgeValidationException` for an out-of-range `newIndex` — this
  work package's Error Handling: "Invalid procedure ordering." Array
  position being the only ordering signal means an out-of-range target
  index is the one way an invalid ordering can even be *requested*
  through this API; nothing else about ordering can be "invalid."
* **References** — each step's own edit dialog
  (`showStepEditDialog`/`_StepEditDialog`) offers a checklist of the
  session's other Knowledge Candidates and Evidence Regions,
  committed via `setProcedureStepReferences`.

Tapping a step (not its Edit/Duplicate/Delete buttons) calls
`selectProcedureStep`, switching the docked Property Inspector to
Procedure Step mode (§ Property Inspector below) — visible even while
the (non-blocking, non-full-screen) Procedure Builder dialog remains
open, the same "selection updates the still-visible Property Inspector
from inside a dialog" pattern the Evidence Browser already established
in Work Package 009.

### Cascading Deletes

Deleting a Knowledge Candidate now also removes every `ProcedureStep`
and `SpecificationDetails` entry that referenced it as `candidateId` —
extending the cascade `deleteKnowledgeCandidate` already performed for
Evidence Links and Relationship Candidates. A `ProcedureStep` whose
*reference lists* (`referencedCandidateIds`/`referencedRegionIds`)
point at something since deleted is **not** cleaned up automatically —
see § Validation Model's "orphaned procedure steps" rule, which exists
specifically to surface that case rather than silently repair it.

---

## Specification Model

`SpecificationDetails` (`lib/knowledge/models/specification_details.dart`)
is a separate, `candidateId`-keyed (1:1) list, mirroring
`ProcedureStep`'s separation from its owning candidate — a Component or
Tool candidate has no use for `specType`/`value`/`unit`, so these are
not always-present nullable fields directly on `KnowledgeCandidate`.

```dart
class SpecificationDetails {
  final String candidateId;    // Owning Specification candidate, 1:1
  final SpecificationType specType;
  final String value;
  final String unit;
  final String notes;
  final DateTime createdTime;
  final DateTime? modifiedTime;
}
```

`SpecificationType` (`lib/knowledge/models/specification_type.dart`)
covers exactly the seven types this work package's Requirements list:
Torque, Voltage, Resistance, Pressure, Temperature, Clearance,
Measurement.

**"Linked Evidence" is not a field on `SpecificationDetails`.** It is
the same `EvidenceLink` list every other Knowledge Candidate type
already uses (Work Package 009), read and edited through the existing
`linkEvidence`/`unlinkEvidence`/`showLinkEvidenceRegionsDialog`
mechanism. A Specification needing "Linked Evidence" does not need a
new link type — it needs the general one it already has, by virtue of
being a `KnowledgeCandidate` like any other.

### Specification Editor

`lib/knowledge/workspaces/specification_editor_dialog.dart`: a
dedicated editor dialog, opened from the Property Inspector's
Knowledge Candidate mode when `type == specification` ("Open
Specification Editor"). Fields: Type (dropdown), Value, Unit, Notes,
plus a read-only Linked Evidence list with Unlink buttons and a "Link
Evidence Region" action.

`KnowledgeSessionService.validateSpecificationDetails` rejects an empty
Value or an empty Unit with a professional message — this work
package's Error Handling: "Invalid specifications, Invalid units" —
the same inline-error, dialog-stays-open pattern every other Knowledge
Studio form dialog uses.

Specifications "remain Knowledge Candidates until Repository Commit"
(this work package's own text) — nothing here changes that; a
Specification candidate goes through the identical Accept/Reject/Edit/
Delete/Duplicate lifecycle as every other candidate type.

---

## Validation Model

`CandidateValidationResult` (`lib/knowledge/models/candidate_validation_result.dart`):

```dart
enum ValidationSeverity { ok, warning, error }

class CandidateValidationResult {
  final String candidateId;
  final ValidationSeverity severity;
  final List<String> issues;   // Human-readable findings, worst-first
}
```

Computed by `KnowledgeSessionService.computeCandidateValidation` — a
pure, stateless function taking the session's current candidates,
relationship candidates, evidence links, evidence regions, procedure
steps, and specification details, returning one result per candidate.
Exposed as a derived Connection Manager getter,
`FoundationServiceState.candidateValidation` (this work package's
Connection Manager: "Current Validation State") — **never stored,
never persisted**, the same derived-not-stored discipline
`CommitPreview` already established in Work Package 008. "Validation
shall never modify candidate data" (this work package's own text) is
therefore true by construction: the function that computes validation
results has no path back to `candidates`, `procedureSteps`, or
`specificationDetails` that could mutate them — it only reads.

### Rules

| Rule | Severity | Applies to |
|---|---|---|
| Duplicate candidate names (case-insensitive) | `error` | Every candidate |
| Missing evidence (no `EvidenceLink` references it) | `warning` | Every candidate |
| Empty procedure (zero `ProcedureStep`s) | `warning` | Procedure candidates |
| Orphaned procedure step reference (a step's `referencedCandidateIds`/`referencedRegionIds` points at something deleted) | `warning` | Procedure candidates |
| Missing/incomplete Specification (no `SpecificationDetails`, or an empty Value/Unit) | `error` | Specification candidates |
| Invalid relationship (a `RelationshipCandidate` connecting it to a candidate that no longer exists) | `error` | Every candidate |

A candidate's overall `severity` is the worst of its individual
findings (`error` > `warning` > `ok`); `issues` lists every finding
that fired, not just the worst one.

**"Orphaned procedure steps" is read as "a step whose reference is now
orphaned,"** not "a step disconnected from its parent candidate" — the
latter cannot occur through this notifier's own API, since deleting a
candidate cascades to its steps (see § Procedure Model above) the same
way it already cascades to relationship candidates and evidence links.
This reading was a judgment call, not something the work package's
one-line Requirements text ("Orphaned procedure steps") states
explicitly — flagged here as the kind of ambiguity this work package's
own instructions asked to be documented, though it did not rise to a
blocking conflict: a reasonable, literal reading was available, and it
parallels "Invalid relationships" (a *reference* going stale) rather
than introducing a second, unrelated meaning for "orphaned."

### Display

* **Property Inspector** — the Knowledge Candidate mode
  (`lib/knowledge/inspector/knowledge_candidate_properties.dart`) gained
  a Validation Status section: severity icon/label plus every issue,
  bulleted.
* **Candidate List** — each row
  (`lib/knowledge/review/knowledge_candidate_row.dart`) gained a
  Validation Status icon (error/warning/ok, tooltip listing the
  issues) and a Linked Evidence Count, both from
  `KnowledgeCandidateListQuery`'s
  (`lib/knowledge/review/knowledge_candidate_list_query.dart`) new
  `validation`-aware sort field, alongside existing Name/Type/Status
  sort and Type/Status/name-substring filters — the "Support: …
  Filter, Sort" half of this work package's Candidate List
  requirements, mirroring `RelationshipCandidateListQuery`'s (Work
  Package 008) design.

---

## Property Inspector

This work package's Property Inspector section: "Extend support for:
Knowledge Candidate, Procedure Step, Specification, Validation
Status." Only **one** new top-level, mutually-exclusive mode was
added — Procedure Step
(`lib/knowledge/inspector/procedure_step_properties.dart`) — bringing
the Property Inspector's selection switch to eight arms. Specification
and Validation Status are **sections within the existing Knowledge
Candidate mode**, not separate selectable entities:

* Neither has a "Current Specification" or "Current Validation"
  Connection Manager selection field — this work package's own
  Connection Manager section lists exactly four items to extend
  ("Current Knowledge Candidate, Current Procedure, Current Procedure
  Step, Current Validation State"), and "Current Validation State" is
  the derived `candidateValidation` map (§ Validation Model), not a
  *selectable* thing.
  A Specification's Type/Value/Unit only make sense in the context of
  an already-selected Specification-type candidate — there is nothing
  to select independently of the candidate itself.
* A Specification **is** a Knowledge Candidate (SDD-015/this work
  package's own candidate-type list), so its fields belonging inside
  Knowledge Candidate mode, conditional on `type == specification`,
  follows directly rather than requiring an invented separate mode.

This reconciliation between the section's four-item list and the
Connection Manager section's four-item list (which don't name the same
four things) was a judgment call — documented under § Architectural
Observations below alongside the Evidence-linking one, since it's the
same category of "the task text names N things; how many really need
independent mutual-exclusivity machinery" question this project has
faced before (e.g. Work Package 008's Relationship Candidates as a
tab, not an eighth panel).

`FoundationServiceState` gained `openProcedure`
(`KnowledgeCandidate?`) and `selectedProcedureStep` (`ProcedureStep?`).
`openProcedure` mirrors `openSourceDocument`'s separation from the
mutually-exclusive selection fields (Work Package 009) — set by
`openProcedureBuilder`/cleared by `closeProcedureBuilder`, left
untouched by every `select*` method, so the Procedure Builder dialog
can stay conceptually "open" (its Connection Manager sense) while its
own step selection changes underneath it. `selectedProcedureStep` is
part of the eight-way mutual exclusivity like every other `selected*`
field.

---

## Session Persistence Changes

`KnowledgeSessionRecord` (`lib/knowledge/models/knowledge_session_record.dart`)
gained two new lists, `procedureSteps` and `specificationDetails`,
serialized/deserialized the same way every prior work package's
additions were: a top-level JSON array, each entry's own `toJson`/
`fromJson`, defaulting to `[]` on load if the key is absent entirely —
so a session file saved before Work Package 010 still loads with empty
Procedure/Specification data rather than throwing. `KnowledgeCandidate.fromJson`
similarly defaults `notes`/`author`/`tags` (`''`/`''`/`[]`) when those
keys are missing, for the same backward-compatibility reason.

`KnowledgeSessionService.buildDuplicate` (Session Browser: "Duplicate")
carries `procedureSteps`/`specificationDetails` over unchanged, the
same as every other list — a duplicated session's Procedures/
Specifications are independent copies of the *data*, but keep their
original IDs (matching how candidates/evidence themselves are
duplicated: `buildDuplicate` never needs to remap `candidateId`
references since candidate IDs themselves are preserved into the
duplicate).

`_persistActiveSession` (the autosave path every mutation triggers)
now includes both new lists in the `KnowledgeSessionRecord` it writes,
alongside every previously-persisted field.

---

## Architectural Observations

* **"Create Knowledge Candidates from Source Material / Page
  Selection / Evidence Region" does not fully reconcile with SDD-021's
  four-layer Evidence Object hierarchy (Source Material → Source Pages
  → Evidence Objects → Evidence Regions), and this work package's
  literal Requirements text does not resolve the gap.** SDD-021
  describes "Evidence Objects" as an intermediate abstraction (Page
  Selection, Figure, Table, Photograph, Annotation, Highlight,
  Measurement Region are its own listed examples) that "Evidence
  Links" connect Knowledge Candidates to *generally* — not
  specifically Evidence Regions. The implementation as it exists
  (`EvidenceLink.regionId`, Work Package 009) only supports linking to
  an Evidence Region; there is no Evidence Object abstraction unifying
  Source Material, Page Selection, and Evidence Region under one
  linkable type. This is the same discrepancy flagged at the end of
  Work Package 009's completion report as an untracked, then-Draft
  SDD-021 outside that work package's authorized scope; it is now
  in-scope architecture, and this work package's own Requirements text
  ("Support creating Knowledge Candidates from: Source Material / Page
  Selection / Evidence Region") reads most naturally as *three UI
  entry points into candidate creation*, not a mandate to rebuild the
  Evidence model around SDD-021's fuller hierarchy — nothing in this
  work package's Requirements, Connection Manager, or Property
  Inspector sections mentions a "Source Material Link" or "Page
  Selection Link," and `EvidenceLink`'s own Work Package 009 doc
  comment already scopes it to Region↔Candidate pairs specifically.
  **Resolution applied:** all three entry points pre-fill and open the
  New Candidate dialog; only the Evidence Region path also creates a
  real, persisted `EvidenceLink` (reusing the existing mechanism
  exactly as-is). The Source Material and Page Selection paths are
  UI-only convenience — they save the engineer from retyping a
  name/description, nothing more. Generalizing `EvidenceLink` into a
  true SDD-021 "Evidence Object" reference (a link that can point at a
  Source Material, a Page Selection, *or* an Evidence Region) would be
  a genuine schema change with cascading effects on the Evidence
  Browser, the bidirectional-highlighting UI, and the persisted file
  format — the kind of "independent architectural decision" this work
  package's instructions say to document and stop for rather than
  make unilaterally. **This is flagged for architectural review**:
  should a future work package unify Source Material/Page
  Selection/Evidence Region under a real "Evidence Object" type with a
  generalized link, per SDD-021's letter, or does the three-entry-point
  reading applied here satisfy the frozen architecture's intent well
  enough to leave as-is? This did not block implementation — a
  reasonable, literal, non-breaking reading of this work package's own
  text was available and was applied — so work continued rather than
  halting, but the discrepancy between SDD-021's model and the shipped
  behavior is real and worth a deliberate answer rather than
  accumulating further work packages on top of an unresolved question.
* **The Property Inspector's "extend support for" list (Knowledge
  Candidate, Procedure Step, Specification, Validation Status) names
  four things; only one — Procedure Step — became a new
  mutually-exclusive mode.** See § Property Inspector above for the
  reasoning (no corresponding Connection Manager selection field exists
  for the other two, and a Specification is itself a Knowledge
  Candidate). Documented here as the judgment call it is, not
  independently re-litigated as a blocking conflict, since the
  Connection Manager section's own four-item list ("Current Knowledge
  Candidate, Current Procedure, Current Procedure Step, Current
  Validation State") is consistent with — and effectively resolves —
  the Property Inspector section's more ambiguous four-item list.
* **`openProcedure` had to be introduced as real Connection Manager
  state, not just a constructor parameter passed to
  `showProcedureBuilderDialog`, to satisfy this work package's own
  "Current Procedure" Connection Manager requirement and to avoid
  re-introducing Work Package 009's `openSourceDocument` bug in a new
  form.** An initial design considered simply passing `candidateId`
  as a dialog parameter (the way `showEvidenceBrowserDialog` takes
  `sourceId` directly, since no "Current Source" Connection Manager
  field was needed there — `openSourceDocument` already served that
  role). Procedure Builder has no equivalent existing "what's open"
  field to borrow, and losing it silently on any unrelated selection
  change would repeat exactly the class of bug Work Package 009 spent
  significant effort diagnosing and fixing. `openProcedure` was added
  instead, deliberately mirroring `openSourceDocument`'s pattern: set
  only by `openProcedureBuilder`, cleared only by
  `closeProcedureBuilder` or a session change, untouched by every
  `select*` method.
