# Knowledge Studio

First implemented in Work Package 007 (STUDIO-TASK-000013 Knowledge
Studio Shell, STUDIO-TASK-000014 Knowledge Curation Session); extended
in Work Package 008 (STUDIO-TASK-000015 Persistent Sessions + Session
Browser, STUDIO-TASK-000016 Source Material Workspace,
STUDIO-TASK-000017 Manual Relationship Authoring + Relationship View,
STUDIO-TASK-000018 Repository Commit Preview); extended again in Work
Package 009 (STUDIO-TASK-000019 PDF Source Viewer, STUDIO-TASK-000020
Evidence Regions, STUDIO-TASK-000021 Evidence Linking); extended again
in Work Package 010 (STUDIO-TASK-000022 Manual Knowledge Candidate
Authoring, STUDIO-TASK-000023 Procedure Builder, STUDIO-TASK-000024
Specification Editor, STUDIO-TASK-000025 Knowledge Candidate
Validation); extended again in Work Package 011 (STUDIO-TASK-000026
Knowledge Session Graph, STUDIO-TASK-000027 Provenance Explorer,
STUDIO-TASK-000028 Candidate Dependency Viewer, STUDIO-TASK-000029
Session Health Dashboard); extended again in Work Package 012
(STUDIO-TASK-000030 Commit Plan, STUDIO-TASK-000031 Candidate
Conversion, STUDIO-TASK-000032 Transactional Repository Commit,
STUDIO-TASK-000033 Commit Report, including Property Inspector Commit
Plan/Commit Report support); extended again in Work Package 013
(STUDIO-TASK-000034 OCR Pipeline, STUDIO-TASK-000035 OCR Layer Viewer,
STUDIO-TASK-000036 Searchable Documents, STUDIO-TASK-000037 OCR
Session Cache); extended again in Work Package 014 (STUDIO-TASK-000038
Entity Extraction Engine, STUDIO-TASK-000039 Entity Review Workspace,
STUDIO-TASK-000040 Pattern Library, STUDIO-TASK-000041 Entity
Validation); extended again in Work Package 015 (STUDIO-TASK-000042
Context Detection Engine, STUDIO-TASK-000043 Context Explorer,
STUDIO-TASK-000044 Context Validation, STUDIO-TASK-000045 Context
Navigation); extended again in Work Package 016 (STUDIO-TASK-000046 AI
Provider Architecture, STUDIO-TASK-000047 Prompt Construction Service,
STUDIO-TASK-000048 AI Review Infrastructure, STUDIO-TASK-000049 Mock AI
Provider). Validates the architecture defined in SDD-013
(Knowledge Studio), SDD-014 (Engineering Knowledge Acquisition
Pipeline), SDD-015 (Engineering Knowledge Model), SDD-016 (Knowledge
Studio User Experience), SDD-017 (Knowledge Curation Workflow), SDD-018
(Engineering Knowledge Lifecycle and Provenance), SDD-019 (Engineering
Object Philosophy), SDD-020 (Engineering Knowledge Review System),
SDD-021 (Engineering Evidence Model, as of Work Package 010), and
SDD-022 (Artificial Intelligence Architecture, as of Work Package 016),
remaining **Studio-only, with no AI through Work Package 015** —
except Repository Commit itself (Work Package 012, a real,
transactional write into the open Foundation repository — see
`docs/REPOSITORY_COMMIT.md`) and OCR (Work Package 013 — a real, local
Tesseract OCR pipeline that augments Source Material with searchable
text and positional data, never Knowledge Candidates, never Foundation
— see `docs/OCR_PIPELINE.md`).
Work Package 014's Engineering Entity Extraction stays within this same
no-AI boundary: deterministic regex pattern matching over OCR text,
never a Knowledge Candidate until explicit engineer acceptance — see
`docs/ENGINEERING_ENTITY_EXTRACTION.md`. Work Package 015's Engineering
Context Analysis stays within it too: deterministic document-structure
grouping of entities, never a Knowledge Candidate and never a
Foundation Object — see `docs/ENGINEERING_CONTEXT.md`. Work Package 016
is the first work package to introduce genuine AI infrastructure — a
provider-independent `AiProvider` interface, a Prompt Construction
Service, and a full review workflow — but **integrates no production AI
provider**: the only concrete provider is a deterministic, in-process
`MockAiProvider` making zero network calls and requiring no API
credentials, and accepting an AI Suggestion still requires explicit
engineer action, never happening automatically — see
`docs/AI_PROVIDER_ARCHITECTURE.md`.

For the persisted-file format and the Relationship Candidate model
reference (including the `KnowledgeCandidateType`/`ObjectCategory`
mismatch), see `docs/KNOWLEDGE_SESSION_FORMAT.md`. For the Evidence
Region/Evidence Link/Page Selection models, the PDF Source Viewer, and
the Work Package 009 architectural findings, see
`docs/EVIDENCE_MODEL.md`. For the Knowledge Candidate/Procedure/
Procedure Step/Specification/Validation model reference and the Work
Package 010 architectural findings, see `docs/KNOWLEDGE_CANDIDATES.md`.
For the Knowledge Session Graph/Provenance/Dependency/Session Health
model reference and the Work Package 011 architectural findings, see
`docs/KNOWLEDGE_GRAPH.md`. For the Commit Plan/Candidate Conversion/
Transaction Model/Commit Report reference and the Work Package 012
architectural findings, see `docs/REPOSITORY_COMMIT.md`. For the OCR
architecture/cache/overlay/search/confidence model reference and the
Work Package 013 architectural findings, see `docs/OCR_PIPELINE.md`. For
the Engineering Entity/Pattern/Validation model reference and the Work
Package 014 architectural findings, see
`docs/ENGINEERING_ENTITY_EXTRACTION.md`. For the Engineering
Context/Detection/Navigation/Validation model reference and the Work
Package 015 architectural findings, see `docs/ENGINEERING_CONTEXT.md`.
For the AI provider abstraction/registry/Prompt Service/review
workflow reference and the Work Package 016 architectural findings,
see `docs/AI_PROVIDER_ARCHITECTURE.md`.
This document covers the workspace layout, session lifecycle, and
state ownership.

> **Note on SDD-014.** SDD-014 was an empty file (0 bytes) as of Work
> Package 007 and remains unpopulated as of Work Package 011. None of
> these work packages' decisions depend on its contents — SDD-013's own
> Import Pipeline section has been sufficient — but this is flagged
> again for whoever populates SDD-014 next, since a future work package
> implementing the acquisition pipeline itself (OCR, AI Analysis) will
> need real content there.

> **Terminology.** Work Package 008 renamed "Proposal" to "Knowledge
> Candidate" throughout `lib/knowledge/` (`EngineeringProposal` →
> `KnowledgeCandidate`, `ProposalType` → `KnowledgeCandidateType`,
> `ProposalStatus` → `KnowledgeCandidateStatus`, and every related
> file/method/field), per that work package's explicit terminology
> direction. This document uses "Knowledge Candidate" throughout,
> including in places describing Work Package 007 behavior that
> predates the rename.

---

## Workspace Layout

`lib/knowledge/workspaces/knowledge_studio_page.dart` implements
SDD-016's seven-panel layout as a normal Studio Primary Workspace page
— reached via the Navigation Rail's "Knowledge Studio" item
(`StudioDestination.knowledge`, positioned right after Dashboard),
rendered inside the same `StudioShell` every other page uses. No
separate window, no separate application.

```
+----------------------------------------------------------------+
| Session Header (name, status, counts, session/session-browser   |
| actions, storage-error banner)                                  |
+------------------+------------------+---------------------------+
| Import Queue      | Source Viewer    | AI Suggestions            |
|------------------+------------------+---------------------------|
| Repository Matches                   | Engineering Review        |
|                                       | (Candidates / Relationships tabs) |
|------------------+------------------+---------------------------|
| Commit Summary                                                   |
+-------------------------------------------------------------+---+
```

SDD-016's own "Property Inspector" panel is **not** duplicated inside
this layout — Studio already has exactly one Property Inspector,
docked on the right of every page via `StudioShell`
(`lib/shared/widgets/property_inspector_panel.dart`). Knowledge
Studio extends that shared panel with its own modes (see § State
Ownership) rather than embedding a second copy of it.

The Knowledge Session Graph (Work Package 011) is likewise **not** an
eighth panel — SDD-016's seven-panel layout stays frozen. It is a
dialog (`lib/knowledge/workspaces/knowledge_graph_dialog.dart`), opened
via a "Knowledge Graph" button in the Session Header, the same
dedicated-dialog precedent Work Package 010 established for the
Procedure Builder and Specification Editor. See
`docs/KNOWLEDGE_GRAPH.md`.

As of Work Package 010, four of the six panels carry real
functionality:

* **Import Queue** (`lib/knowledge/workspaces/import_queue_panel.dart`)
  — attach Source Material via the native file picker; browse/select/
  remove attached sources; each source row also offers "Create
  Knowledge Candidate from Source Material" (Work Package 010).
* **Source Viewer** (`lib/knowledge/workspaces/source_viewer_panel.dart`)
  — PDF sources get a real, interactive viewer
  (`lib/knowledge/workspaces/pdf_source_viewer.dart`: page navigation,
  zoom, fit, rotate, continuous scrolling, Evidence Region drawing,
  Page Selection — see `docs/EVIDENCE_MODEL.md`). Everything else
  renders what it reasonably can (image thumbnail; Markdown/Text raw
  content; a location-only message for Other). PDF and image (PNG/JPG/
  TIFF) sources both get an "OCR Layer Viewer" toolbar entry point
  (Work Package 013) opening `lib/knowledge/workspaces/ocr_layer_viewer_dialog.dart`
  — see `docs/OCR_PIPELINE.md`.
* **Engineering Review** (`lib/knowledge/review/engineering_review_panel.dart`)
  — two tabs: Candidates (manual Knowledge Candidate creation across
  ten types, Accept/Reject/Edit/Duplicate/Delete, filter/sort, and
  Validation Status/Linked Evidence Count display — see
  `docs/KNOWLEDGE_CANDIDATES.md`) and Relationships (manual
  Relationship Candidate authoring — see § Relationship Candidates
  below).
* **Commit Summary** (`lib/knowledge/workspaces/commit_preview_panel.dart`)
  — shows the real Commit Plan (New Objects/New Relationships/Existing
  Objects/Validation Errors/Warnings) and a "Commit" button, enabled
  once the plan is valid and non-empty, that performs a real,
  transactional write into the open Foundation repository — see
  § Repository Commit (Work Package 012).
* **Property Inspector** — eight modes (see § State Ownership).

**AI Suggestions** and **Repository Matches** remain placeholder
content (`lib/knowledge/widgets/knowledge_placeholder.dart`) — both
presuppose workflows still explicitly out of scope (AI functionality;
repository matching, which has no Public C API surface yet).

`lib/knowledge/widgets/knowledge_panel.dart` (`KnowledgePanel`) is the
titled/bordered container shared by all six panels, so they read as
one workspace rather than six unrelated widgets.

## Session Lifecycle

`SessionStatus` (`lib/knowledge/models/session_status.dart`) implements
the Session Workflow, unchanged since Work Package 007:

```
Created → Preparing → Reviewing → Ready to Commit
   ↓          ↓            ↓             ↓
                    Cancelled
```

This is deliberately **narrower** than SDD-017's full seven-stage
Curation Lifecycle (Preparation → Analysis → Review → Validation →
Repository Preview → Commit → Audit): AI analysis, validation, and
repository commit remain out of scope through Work Package 008, so
only the Studio-only portion of SDD-017's lifecycle — everything up to
and including engineer review, before validation/commit would occur —
is modeled. A rough correspondence, for whoever implements the rest:

| `SessionStatus` | SDD-017 stage |
|---|---|
| `created` | Preparation begins |
| `preparing` | Preparation |
| `reviewing` | Analysis + Review (no Analysis stage exists — candidates are manually authored, not AI-proposed) |
| `readyToCommit` | Validation passed, awaiting Repository Commit (a real, transactional Repository Commit exists as of Work Package 012 — see § Repository Commit) |
| `cancelled` | Session abandoned before Commit |

Transitions are validated by `KnowledgeSessionService.validateStatusTransition`:
only the next state in the forward sequence is a legal transition (no
skipping stages), except `cancelled`, which is reachable from any
non-cancelled state and is terminal. The Session Header only ever
offers the one valid forward action plus Cancel, so an engineer can't
reach an invalid transition through the UI at all.

`KnowledgeSession` also carries an independent `archived: bool` field
(Work Package 008), orthogonal to `SessionStatus` — see
`docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural Observations for
why this is a separate field rather than a new status value.

### Persistence and the Session Browser (Work Package 008)

Sessions now **survive application restart** — every mutation to the
active session's candidates, relationship candidates, sources, or
status triggers an autosave (`FoundationRuntimeNotifier`'s private
`_persistActiveSession()`) to
`%APPDATA%/oep_studio/knowledge_sessions/<sessionId>/session.json` via
`KnowledgeSessionStorage`. There is no separate explicit "Save" action.
See `docs/KNOWLEDGE_SESSION_FORMAT.md` for the full file format.

`FoundationRuntimeNotifier.createKnowledgeSession` still **replaces**
any currently active session as the one *active* session — but unlike
Work Package 007, the replaced session isn't lost; it remains on disk
and can be reopened. The Session Browser
(`lib/knowledge/sessions/session_browser_dialog.dart`, opened via the
Session Header's "Sessions" button) lists every persisted session and
supports:

* **Open** — loads a session as the active one, replacing whatever was
  active (same replacement semantics as creating a new session).
* **Duplicate** — a fresh ID/name/timestamps, independent copies of
  its Source Material files, candidates/relationship candidates/review
  decisions carried over as-is; does not change which session is
  active.
* **Archive / Unarchive** — toggles the `archived` field.
* **Delete** — permanent, requires an inline confirmation dialog,
  removes the session's directory (including its Source Material
  files) entirely.

Corrupted session files (a JSON parse or structural failure) are
listed separately in the browser with an explanation, rather than
silently dropped or blocking the browser from opening at all.

## Knowledge Candidate Model

`KnowledgeCandidate` (`lib/knowledge/models/knowledge_candidate.dart`,
renamed from `EngineeringProposal` in Work Package 008) is
intentionally minimal — SDD-018's "Draft" lifecycle state ("Created
during an active Knowledge Curation Session. Not yet committed.")
until persisted, after which it survives restart but is still
pre-commit — SDD-018's "Draft" state covers both. No AI-era fields
(confidence, supporting evidence, repository matches) since none of
these work packages have AI or repository-matching to populate them.

As of Work Package 010, `KnowledgeCandidateType` covers ten types
(Component, Procedure, Specification, Tool, Material, Fluid, Warning,
Measurement, Image, Document), and the candidate itself carries
`notes`/`author`/`tags` alongside description — see
`docs/KNOWLEDGE_CANDIDATES.md` § Knowledge Candidate Model for the
full field reference, the "create from Source Material/Page
Selection/Evidence Region" entry points, and the Duplicate action.
That document also covers the Procedure/Procedure Step model
(STUDIO-TASK-000023), the Specification model (STUDIO-TASK-000024),
and the Validation model (STUDIO-TASK-000025) in full.

`KnowledgeCandidateStatus` is narrower than SDD-020's full Decision
Options (Accept/Reject/Merge/Edit/Postpone/Duplicate):
Merge/Postpone presuppose repository matching, which doesn't exist
yet, so only Accept/Reject/Pending are modeled as a *status*; Edit and
Duplicate (Work Package 010) are actions, not statuses.

Candidate name uniqueness is enforced per-session, case-insensitively,
at creation/edit time by `KnowledgeSessionService.validateCandidateName`
— but **not** by the Duplicate action, which deliberately allows
same-named copies, surfaced instead as a non-blocking validation
finding (`docs/KNOWLEDGE_CANDIDATES.md` § Validation Model).

Every Create/Edit/Accept/Reject/Delete against a candidate appends a
`ReviewDecision` (Work Package 008) to the session's append-only
decision history — see `docs/KNOWLEDGE_SESSION_FORMAT.md` § Review
Decision Model. Duplicate also appends a `created` decision, for the
newly-created copy.

## Relationship Candidates (Work Package 008)

`RelationshipCandidate` (`lib/knowledge/models/relationship_candidate.dart`)
connects two `KnowledgeCandidate`s within the same session by ID, using
the existing `RelationshipType` enum (`lib/core/models/relationship_type.dart`,
already mirroring Foundation's `oep_relationship_type_t` since Work
Package 006) rather than a Knowledge-specific taxonomy — a manually
authored relationship candidate is still describing one of Foundation's
six relationship kinds, just not yet committed.

Unlike `KnowledgeCandidate`, a relationship candidate carries **no
accept/reject status** — only Create/Edit/Delete, per this work
package's Requirements list; every relationship candidate that exists
is a Commit Plan candidate (Work Package 012), included once both its
endpoints resolve to a Foundation object — see
`docs/REPOSITORY_COMMIT.md`.

Validation (`KnowledgeSessionService.validateRelationshipCandidate`,
blocking): a relationship cannot connect a candidate to itself, and
both the source and target must exist among the session's candidates.
**Duplicate relationships are warned, not blocked**
(`isDuplicateRelationshipCandidate`) — the New/Edit Relationship
Candidate dialog shows an inline, non-blocking warning when a
relationship with the same source/target/type already exists, but
still allows submission. Deleting a candidate cascades: any
relationship candidate referencing it as source or target is deleted
too.

Authored through the Engineering Review panel's "Relationships" tab
(`lib/knowledge/review/relationship_candidate_form_dialog.dart`),
listed via `RelationshipCandidateListQuery`
(`lib/knowledge/review/relationship_candidate_list_query.dart`), a
sort/filter pipeline mirroring `RelationshipListQuery`'s Work Package
006 shape.

## Source Material (Work Package 008)

`SourceMaterial` (`lib/knowledge/models/source_material.dart`) records
engineering evidence attached to a session. Supported types, classified
by file extension only — **no OCR, no parsing** —: PDF, Image
(PNG/JPG/JPEG/GIF/BMP/WEBP), Markdown, Text, Other.

`SourceMaterialService.attach` **copies** the picked file into the
session's own managed `sources/` directory at attach time, rather than
referencing the originally-picked path — a session stays self-contained
and portable even if the original file is later moved or deleted. See
`docs/KNOWLEDGE_SESSION_FORMAT.md` § Local Storage Format for the exact
directory layout.

The Source Viewer renders what it reasonably can from the managed copy
(a real PDF viewer as of Work Package 009 — see `docs/EVIDENCE_MODEL.md`;
image thumbnail; Markdown/Text raw content) and otherwise shows the
file's location — this is still "display," not "parse": nothing
extracts structured meaning from a source's content.

## Repository Commit (Work Package 012)

`CommitPreview` (Work Package 008) is superseded, not extended, by
`CommitPlan`/`CommitReport` — see `docs/REPOSITORY_COMMIT.md` for the
full Commit Plan/Candidate Conversion/Transaction Model/Commit Report
reference and the work package's architectural observations (most
notably the `KnowledgeCandidateType` → `ObjectCategory` mapping gap's
load-bearing consequences now that real conversion exists). In brief:

* `CommitPlan` (`lib/knowledge/models/commit_plan.dart`), computed on
  demand by `CommitPlanService.computeCommitPlan`, replaces
  `CommitPreview` entirely — same "derived, never stored" discipline,
  now describing exactly what a real commit will do rather than a
  simulation.
* The Commit Summary panel's "Commit" button is enabled once
  `CommitPlan.canCommit` is true, and — after a confirmation dialog —
  calls `FoundationRuntimeNotifier.commitToFoundation()`, which
  performs a real, one-shot transactional write into the open
  Foundation repository via the Public C API's Object/Relationship
  Mutation and Transaction functions, with automatic rollback on any
  failure.
* Every commit attempt (success or failure) produces a `CommitReport`
  (`lib/knowledge/models/commit_report.dart`), shown in
  `lib/knowledge/workspaces/commit_report_dialog.dart` and exportable
  as JSON — unlike `CommitPlan`, this is a real, persisted, append-only
  record (`FoundationServiceState.commitReports`), mirroring
  `ReviewDecision`'s audit-log pattern.
* Knowledge Candidates and Relationship Candidates remain in the
  Knowledge Session after Commit ("Knowledge Candidates remain
  Knowledge Workspace artifacts after Commit") — `committedObjectId`/
  `committedRelationshipId` track which Foundation object/relationship
  each became, so a later commit of the same session only touches
  newly-eligible candidates, never re-creating a duplicate Foundation
  object.

## State Ownership

Per this project's Architecture Rules ("The Connection Manager owns
session state. Widgets consume state only. Connection Manager
coordinates state only."), Knowledge Curation Session state lives in
the *same* Connection Manager every other Studio feature uses
(`lib/core/services/foundation_runtime_service.dart`/
`foundation_runtime_state.dart`, `FoundationRuntimeNotifier`/
`FoundationServiceState`) — **not** a separate Knowledge-specific
provider — even though this state is Studio-only and never touches
Foundation. See `docs/CONNECTION_MANAGER.md` for the full state
ownership table; as of Work Package 011:

| Field | Meaning |
|---|---|
| `knowledgeSession` | The active session, `null` until one is created or opened |
| `candidates` | Knowledge Candidates within the active session |
| `selectedCandidate` | The Knowledge Candidate currently selected |
| `relationshipCandidates` | Relationship Candidates within the active session |
| `selectedRelationshipCandidate` | The Relationship Candidate currently selected |
| `sourceMaterials` | Source Material attached to the active session |
| `selectedSourceMaterial` | The Source Material currently selected for the Property Inspector |
| `openSourceDocument` | The Source Material currently open in the Source Viewer (Work Package 009's "Current Source Document") — see § Evidence below for why this is *not* the same field as `selectedSourceMaterial` |
| `evidenceRegions` / `selectedEvidenceRegion` | Evidence Regions within the active session, and the one currently selected (Work Package 009) |
| `evidenceLinks` / `selectedEvidenceLink` | Knowledge Candidate ↔ Evidence Region links, and the one currently highlighted in the Property Inspector (Work Package 009) |
| `pageSelections` | Whole-page evidence markers (Work Package 009) |
| `currentPage` | The Source Viewer's current page for `openSourceDocument`, ephemeral (Work Package 009) |
| `procedureSteps` | Procedure Steps within the active session's Procedure Knowledge Candidates (Work Package 010) |
| `specificationDetails` | Type/Value/Unit/Notes for the active session's Specification Knowledge Candidates (Work Package 010) |
| `openProcedure` / `selectedProcedureStep` | The Procedure Knowledge Candidate currently open in the Procedure Builder (Work Package 010's "Current Procedure" — mirrors `openSourceDocument`'s separation), and the step currently selected |
| `candidateValidation` | Derived getter — see `docs/KNOWLEDGE_CANDIDATES.md` § Validation Model |
| `knowledgeSessionGraph` | Derived getter (Work Package 011) — see `docs/KNOWLEDGE_GRAPH.md` § Knowledge Session Graph Model |
| `provenanceFor(candidateId)` / `dependencyFor(candidateId)` | Derived getters (Work Package 011's "Current Provenance View"/"Current Dependency View") — see `docs/KNOWLEDGE_GRAPH.md` |
| `sessionHealth` | Derived getter (Work Package 011's "Current Session Health") — see `docs/KNOWLEDGE_GRAPH.md` § Session Health Model |
| `reviewDecisions` | The append-only Create/Edit/Accept/Reject/Delete audit log |
| `knowledgeStorageError` | The most recent autosave/Session-Browser persistence failure, if any |
| `commitPlan` | Derived getter (Work Package 012) — see § Repository Commit |
| `commitReports` / `latestCommitReport` | The append-only history of Repository Commit attempts against this session, and the most recent one (Work Package 012) — see § Repository Commit |
| `ocrPageResults` | OCR results for this session's Source Material, persisted (Work Package 013) — see `docs/OCR_PIPELINE.md` § OCR Cache |
| `ocrProcessingStatus` | Per-source OCR processing state, ephemeral (Work Package 013's "OCR state") — see `docs/OCR_PIPELINE.md` |
| `ocrOverlayVisible` | Whether the OCR Layer Viewer's overlay is shown, ephemeral (Work Package 013's "OCR overlay visibility") |
| `ocrErrorMessage` | The most recent pipeline-level OCR failure, if any (Work Package 013), mirroring `knowledgeStorageError` |
| `engineeringEntities` | Engineering Entities extracted from this session's OCR results, persisted (Work Package 014) — see `docs/ENGINEERING_ENTITY_EXTRACTION.md` |
| `selectedEntity` | The Engineering Entity currently selected (Work Package 014) |
| `engineeringEntitiesForSource(sourceId)` | Derived getter, sorted by page then character start (Work Package 014) |
| `entityValidation` | Derived getter (Work Package 014) — see `docs/ENGINEERING_ENTITY_EXTRACTION.md` § Validation Model |
| `patternFor(entityId)` | Derived getter — the `EngineeringPattern` that produced an entity, looked up by its recorded id (Work Package 014) |
| `engineeringContexts` | Engineering Contexts detected from this session's OCR results and entities, persisted (Work Package 015) — see `docs/ENGINEERING_CONTEXT.md` |
| `selectedContext` | The Engineering Context currently selected (Work Package 015) |
| `contextTypeFilter` | The Context Explorer's type filter, ephemeral (Work Package 015's "Context Filter") |
| `engineeringContextsForSource(sourceId)` | Derived getter, sorted by page start then title (Work Package 015) |
| `contextValidation` | Derived getter (Work Package 015) — see `docs/ENGINEERING_CONTEXT.md` § Validation Model |
| `orphanedEntityIdsFor(sourceId)` | Derived getter — entities claimed by no context (Work Package 015) |
| `childEntitiesFor(contextId)` / `parentContextOf(contextId)` / `contextStatisticsFor(contextId)` | Derived getters for the Property Inspector's Child Entities/Parent Context/Context Statistics (Work Package 015) |
| `aiSuggestions` | AI Suggestions generated from this session's evidence, persisted (Work Package 016) — see `docs/AI_PROVIDER_ARCHITECTURE.md` |
| `selectedAiSuggestion` | The AI Suggestion currently selected (Work Package 016) |
| `currentAiProviderId` | Which `AiProvider` (by `AiProviderRegistry` id) new analysis runs use, ephemeral, defaults to `'mock'` (Work Package 016's "Current AI Provider") |
| `currentAiConversation` | The most recent `AiConversation` (exact prompt/response), ephemeral (Work Package 016's "AI Review State") — never persisted, see `docs/AI_PROVIDER_ARCHITECTURE.md` § Persistence |
| `aiProcessingStatus` | Per-source AI analysis state, ephemeral, mirrors `ocrProcessingStatus` (Work Package 016's "AI Processing State") |
| `aiSuggestionsForSource(sourceId)` | Derived getter, sorted newest first (Work Package 016) |
| `supportingEntitiesFor(suggestionId)` / `supportingContextsFor(suggestionId)` | Derived getters for the Property Inspector's Supporting Evidence (Work Package 016) |

`knowledgeSourceCount`/`knowledgeCandidateCount`/`knowledgeAcceptedCount`/
`knowledgeRejectedCount`/`knowledgePendingCount`/
`knowledgeRelationshipCandidateCount`/`knowledgeEvidenceRegionCount` are
getters derived from the lists above, not separately stored.

Selection is **eleven-way mutually exclusive**: AI Suggestion (Work
Package 016), Engineering Context (Work Package 015), Engineering
Entity (Work Package 014), Knowledge Candidate, Relationship
Candidate, Source Material, Object, Relationship, Evidence Region,
Procedure Step (Work Package 010), and — the eleventh — nothing
selected at all. Every `select*` method clears the other ten. The
Property Inspector's mode order (`property_inspector_panel.dart`):

```
selectedAiSuggestion? → AI Suggestion mode (Work Package 016)
selectedContext? → Engineering Context mode (Work Package 015)
selectedEntity? → Engineering Entity mode (Work Package 014)
selectedEvidenceRegion? → Evidence Region mode
selectedCandidate? → Knowledge Candidate mode (Specification fields + Validation Status shown as sections when applicable — Work Package 010)
selectedProcedureStep? → Procedure Step mode (Work Package 010)
selectedRelationshipCandidate? → Relationship Candidate mode
selectedSourceMaterial? → Source Material mode
selectedObject? → Object mode
selectedRelationship? → Relationship mode
knowledgeSession? → Session mode (fallback — no more specific selection)
else → No Selection
```

`openSourceDocument` and `openProcedure` are deliberately **separate**
from the mutually-exclusive selection fields — see
`docs/EVIDENCE_MODEL.md` § Connection Manager Mapping for the full
account of why an earlier version of `openSourceDocument` conflated it
with `selectedSourceMaterial`, and why that broke Work Package 009's
own "selecting a Knowledge Candidate highlights its linked Evidence
Regions" requirement; `openProcedure` (Work Package 010) was
introduced following that same pattern from the start, specifically to
avoid reintroducing the bug in a new form (see
`docs/KNOWLEDGE_CANDIDATES.md` § Architectural Observations).

The Knowledge Session Graph's "Current Graph Selection" (Work Package
011) introduces **no new selection field at all** — every node it
renders is a Knowledge Candidate, Evidence Region, or Source Material,
each of which already has its own `selected*` field above.
`FoundationRuntimeNotifier.selectGraphNode` just dispatches a tapped
node to whichever of the three existing `select*` methods matches its
kind. See `docs/KNOWLEDGE_GRAPH.md` § Selection Synchronization.

`lib/knowledge/services/knowledge_session_service.dart` holds the
Knowledge domain's validation and ID-generation as pure, stateless
functions — kept separate from the notifier so "no engineering logic
shall exist inside widgets" doesn't push that logic into the widget
layer just because it also isn't Foundation-calling code that belongs
in the Bridge. `lib/knowledge/services/knowledge_session_storage.dart`
and `lib/knowledge/services/source_material_service.dart` hold
persistence logic the same way. Commit Plan computation, Candidate
Conversion, and Transaction orchestration (Work Package 012) live in
their own three services (`commit_plan_service.dart`,
`commit_conversion_service.dart`, `commit_transaction_service.dart`)
rather than `knowledge_session_service.dart` — see
`docs/REPOSITORY_COMMIT.md` for why the split.

## Error Handling

Per this project's Knowledge Studio error-handling rules (invalid
session names, duplicate candidate names, missing repository, invalid/
missing source files, invalid relationship definitions, corrupted
session files, invalid PDFs, deleted source material, invalid
specifications, invalid units, invalid procedure ordering, empty
sessions, missing evidence, broken graph/provenance/dependency
references, invalid graph nodes, and — as of Work Package 013 — a
missing/unavailable OCR engine and a page that fails to render or
recognize):

* **New Session / New Candidate / New Relationship Candidate / Insert
  or Edit Step / Specification Editor dialogs** validate inline — an
  invalid submission keeps the dialog open and shows the message
  beneath the fields, since the fix is local and the form data
  shouldn't be lost. Duplicate candidate names are the one case
  *deliberately not* rejected here (Work Package 010's Candidate List
  "Duplicate" action) — see § Knowledge Candidate Model.
* **Session status transitions** and **Session Browser actions**
  (Open/Duplicate/Archive/Delete) validate via a separate `AlertDialog`
  (mirroring `showFoundationErrorDialog`'s pattern from
  `dashboard_page.dart`), since these are single-click actions with no
  form to keep open.
* **Autosave failures** (any mutation's background persistence)
  surface via a dismissible banner in the Session Header
  (`knowledgeStorageError`) rather than a dialog, since most triggers
  (e.g. accepting a candidate) have no dialog already open to show one
  in.
* **Pipeline-level OCR failures** (the engine is missing; Work Package
  013) surface via a dismissible banner inside the OCR Layer Viewer
  dialog itself (`ocrErrorMessage`), the same pattern as
  `knowledgeStorageError` — `runOcrForSource` is triggered by opening
  that dialog, not from inside a form. **Per-page OCR failures** (one
  page failed to render/recognize) do not block the rest of the
  document — they produce a failed `OcrPageResult` for that page only,
  shown inline where that page would otherwise appear.

All validation and persistence failures throw
`KnowledgeValidationException`
(`lib/knowledge/models/knowledge_validation_exception.dart`) — a
Studio-only exception type, distinct from `FoundationBridgeException`,
since nothing here ever reaches Foundation. Every I/O failure in
`KnowledgeSessionStorage`/`SourceMaterialService` is translated to this
type — never a raw `IOException` or stack trace.

## Future Foundation Integration

Repository Commit (Work Package 012) is the first Knowledge Studio
feature to call the Foundation Bridge — everything else below remains
Studio-only by design, pending further Public C API surface:

* **Repository Matches** (SDD-013/016/020 duplicate detection) would
  need Foundation to expose something equivalent to a fuzzy/exact
  object-name search scoped for matching rather than free-text search
  — `oep_search_objects` (Work Package 006) is close but is designed
  for the Search Workspace's use case, not necessarily this one. The
  Commit Plan's existing-name-collision warning (Work Package 012,
  using the already-fetched Current Object List) is a narrower,
  exact-match-only version of this same idea, not a substitute for it.
* **AI Suggestions** (SDD-013/016 AI Analysis) requires an entire
  analysis pipeline (OCR, image extraction, object detection,
  relationship detection) that doesn't exist in Foundation or Studio
  yet.
* **`KnowledgeCandidateType`/`ObjectCategory` reconciliation** — see
  `docs/REPOSITORY_COMMIT.md` § Architectural Observations. Work
  Package 012 resolved this for Commit purposes with a nullable
  `foundationCategory` getter (excluding the six unmapped types from
  Commit eligibility with a warning) rather than extending Foundation's
  fixed `oep_object_type_t` or inventing a lossy substitute mapping —
  the underlying taxonomy mismatch itself is unchanged and still open
  for whoever extends Foundation's object types next.
* `oep_object_update`/`oep_object_delete`/`oep_relationship_update`/
  `oep_relationship_delete` (added alongside `oep_object_create`/
  `oep_relationship_create` in Foundation's Work Package 014) are not
  wired into Studio — out of Work Package 012's scope, which only
  needed create.

None of these are implemented here, per the "document it, do not
implement it" rule this project has followed since Work Package 004.
