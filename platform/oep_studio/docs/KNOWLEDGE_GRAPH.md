# Knowledge Graph: Model Reference

Work Package 011 (STUDIO-TASK-000026 Knowledge Session Graph,
STUDIO-TASK-000027 Provenance Explorer, STUDIO-TASK-000028 Candidate
Dependency Viewer, STUDIO-TASK-000029 Session Health Dashboard).
Validates the frozen Knowledge Architecture v1 (SDD-013 through
SDD-021), remaining **Studio-only: no OCR, no AI, no Repository
Commit, no Foundation modifications** — identical scope discipline to
Work Packages 007–010.

This document is the model reference for the Knowledge Session Graph
and the three views built on it. For the Knowledge Candidate/
Procedure/Specification/Validation models it visualizes, see
`docs/KNOWLEDGE_CANDIDATES.md`. For Evidence Region/Evidence Link/Page
Selection, see `docs/EVIDENCE_MODEL.md`. For session lifecycle and
general state ownership, see `docs/KNOWLEDGE_STUDIO.md`.

---

## Knowledge Session Graph Model

`KnowledgeSessionGraph` (`lib/knowledge/models/knowledge_session_graph.dart`)
is "completely independent of Foundation Graph" (this work package's
own text) — it visualizes only Knowledge Workspace artifacts already
held by the active session, never anything from the Foundation Bridge.
Computed on demand by `KnowledgeGraphService.buildGraph`
(`lib/knowledge/services/knowledge_graph_service.dart`) from the
Connection Manager's existing candidate/relationship-candidate/
evidence-region/evidence-link/source-material/procedure-step state —
never stored, the same derived-not-stored discipline every prior work
package's computed models (`CommitPreview`, `CandidateValidationResult`)
already established.

```dart
class KnowledgeSessionGraph {
  final List<KnowledgeGraphNode> nodes;
  final List<KnowledgeGraphEdge> edges;
}
```

### Nodes

`KnowledgeGraphNode` (`lib/knowledge/models/knowledge_graph_node.dart`)
— one per artifact, `id` always equal to the underlying artifact's own
id:

```dart
enum KnowledgeGraphNodeKind { candidate, evidenceRegion, sourceMaterial }

class KnowledgeGraphNode {
  final String id;
  final KnowledgeGraphNodeKind kind;
  final String label;
  final IconData icon;
}
```

"Each node type shall use a distinct icon" (this work package's own
text) is satisfied by reusing icons every prior work package already
attached to these artifacts, rather than inventing new ones:
`KnowledgeCandidateType.icon` (ten distinct icons, Work Package 010)
for candidate nodes, `SourceMaterialType.icon` (five distinct icons,
Work Package 008) for Source Material nodes, and one fixed icon
(matching the region-drawing tool's own icon) for every Evidence
Region node. A Procedure or Specification Candidate is still a
`candidate`-kind node — see § Architectural Observations for why this
work package's Display list naming them separately doesn't mean a
separate node *kind*.

### Edges

`KnowledgeGraphEdge` (`lib/knowledge/models/knowledge_graph_edge.dart`)
— every edge kind corresponds to data that already exists elsewhere;
the graph draws it, it does not define it:

| Edge kind | Direction | Source data |
|---|---|---|
| `relationshipCandidate` | candidate → candidate | `RelationshipCandidate` (Work Package 008). "Relationship Candidates are represented as graph edges." |
| `evidenceLink` | region → candidate | `EvidenceLink` (Work Package 009). "Evidence Regions connect to Knowledge Candidates only." |
| `sourceContainsRegion` | source → region | `EvidenceRegion.sourceId` (Work Package 009) |
| `procedureReference` | procedure candidate → referenced candidate/region | `ProcedureStep.referencedCandidateIds`/`referencedRegionIds` (Work Package 010) |

`sourceContainsRegion` and the exact reading of `procedureReference`
were judgment calls this work package's own edge list didn't spell
out explicitly — see § Architectural Observations.

### Broken References

Per this work package's Error Handling ("Broken references, Invalid
graph nodes"): `buildGraph` silently omits any edge whose endpoint no
longer exists (a relationship candidate, evidence link, or procedure
step reference pointing at something deleted) rather than throwing.
This is defensive — the Connection Manager's own cascading deletes
already prevent it in the normal case — the same posture
`KnowledgeGraphService`'s sibling services take toward the same class
of problem (see § Provenance Model, § Dependency Model).

### Rendering

`lib/knowledge/workspaces/knowledge_graph_dialog.dart`
(`showKnowledgeGraphDialog`) — a dialog, not a new panel (SDD-016's
seven-panel layout stays frozen), opened from the Session Header's new
"Knowledge Graph" button. Supports Pan/Zoom (Flutter's
`InteractiveViewer`, native), Fit All, Center Selection, and Select
Node. Node layout is a deterministic three-column arrangement (Source
Material, Evidence Regions, Knowledge Candidates, left to right,
mirroring the Provenance Explorer's own reading direction) computed in
the widget itself — visual pixel layout is a UI-layer concern, the
same split `pdf_source_viewer.dart` already draws between Evidence
Region *creation* (service) and its on-screen geometry (widget); graph
*construction* (which nodes/edges exist) is what "belongs in
services."

## Provenance Model

`CandidateProvenance`/`ProvenanceEntry`
(`lib/knowledge/models/candidate_provenance.dart`), computed by
`ProvenanceService.computeProvenance`
(`lib/knowledge/services/provenance_service.dart`) — "Provenance is
derived from existing session state and shall not duplicate persisted
data." No new fields are introduced anywhere; the chain is assembled
purely by following existing foreign keys:

```
Knowledge Candidate
  ↓ (EvidenceLink.candidateId / .regionId)
Evidence Region(s)
  ↓ (EvidenceRegion.sourceId + .page, matched against PageSelection.sourceId + .page)
Page Selection            — optional; present only if that page was toggled
  ↓ (EvidenceRegion.sourceId)
Source Material
```

**A region's "Page Selection" link is optional, not fabricated.**
`EvidenceRegion` and `PageSelection` (Work Package 009) are
independent, parallel evidence-marker types on the same
`sourceId`+`page` space — nothing requires a region's page to have
also been explicitly toggled as a Page Selection. `computeProvenance`
looks for a `PageSelection` matching the region's own `sourceId`/`page`
and includes it when found; otherwise that step of the chain reads
"Not selected as a page" rather than inventing one. This was the one
genuine ambiguity in this work package's own three-line Display
description ("Evidence Region(s) ↓ Page Selection ↓ Source Material")
— it does not say what to do when no Page Selection exists for a
region's page, and one very often won't, since drawing a region and
toggling its page as "selected" are two independent engineer actions.

**Navigation "in both directions"** is satisfied by two halves working
together, not one bidirectional widget: the Provenance Explorer
(`lib/knowledge/inspector/candidate_provenance_section.dart`, the
Property Inspector's Provenance tab) navigates *down* — tapping a
region or source selects it via the existing `selectEvidenceRegion`/
`selectSourceMaterial` Connection Manager methods; the Evidence
Region's own Property Inspector view
(`evidence_region_properties.dart`, Work Package 009) already lists
and navigates *up* to every Knowledge Candidate linked to it. Nothing
new was needed for the "up" direction — it already existed.

## Dependency Model

`CandidateDependencyInfo`/`DependencyRelationshipEntry`
(`lib/knowledge/models/candidate_dependency_info.dart`), computed by
`DependencyService.computeDependencyInfo`
(`lib/knowledge/services/dependency_service.dart`). This work
package's Display list ("Referenced By, References, Relationships,
Procedure Usage, Specification Usage, Evidence Count, Validation
Status") maps directly onto existing data with no new persisted
fields:

| Field | Derivation |
|---|---|
| References | Other candidates/regions this candidate's own `ProcedureStep`s reference (`referencedCandidateIds`/`referencedRegionIds`) — empty unless `type == procedure`, since only Procedure candidates own steps |
| Referenced By | Other candidates whose `ProcedureStep`s reference this one |
| Relationships | `RelationshipCandidate`s connecting to this candidate as source or target (Work Package 008), with resolved display names |
| Procedure Usage | This candidate's own step count — `null` unless `type == procedure`, distinguishing "not a Procedure" from "a Procedure with 0 steps" |
| Specification Usage | This candidate's own `SpecificationDetails` — `null` unless `type == specification` |
| Evidence Count | How many `EvidenceLink`s reference this candidate (Work Package 009/010) |
| Validation Status | This candidate's `CandidateValidationResult` (Work Package 010) — reused directly, not a second parallel status concept |

Every entry in the Dependency Viewer
(`lib/knowledge/inspector/candidate_dependency_section.dart`, the
Property Inspector's Dependencies tab) is tappable, selecting the
referenced candidate/region/relationship through the existing
Connection Manager selection methods — the same clickable-cross-
reference convention the Evidence Browser and Provenance Explorer
already use.

## Session Health Model

`SessionHealthMetrics`
(`lib/knowledge/models/session_health_metrics.dart`), computed by
`SessionHealthService.computeSessionHealth`
(`lib/knowledge/services/session_health_service.dart`) — "these
metrics are informational only" (this work package's own text):
`computeSessionHealth` takes a snapshot and returns a value; nothing
in its call path can write back to `candidates`, `procedureSteps`, or
any other session list.

Most of the eleven metrics this work package lists are direct counts
or reuse the Work Package 010 validation map
(`Knowledge Candidates`/`Relationship Candidates`/`Evidence Regions`/
`Procedures`/`Specifications`/`Validation Errors`/`Candidates Missing
Evidence`/`Duplicate Candidates`). Three needed an explicit formula
this work package's one-line labels didn't specify — documented here,
and in § Architectural Observations, as judgment calls:

* **Orphaned Candidates** — read as a graph-theoretic "isolated node":
  a candidate with zero Evidence Links, zero Relationship Candidates
  (as source or target), and zero Procedure Step references in either
  direction. A candidate can have *some* connection (e.g. a
  relationship but no evidence) and still not be "orphaned" — that
  candidate is instead flagged by the separate "Candidates Missing
  Evidence" metric. Orphaned means *nothing* connects it to the rest
  of the session at all.
* **Relationship Density** — `relationshipCandidateCount /
  candidateCount` (`0` with no candidates): Relationship Candidates
  per Knowledge Candidate, not the combinatorial `edges / (n·(n-1)/2)`
  graph-theory density formula. The combinatorial formula answers "how
  close is this session to a complete graph," which isn't a
  meaningful engineering-quality question for a Knowledge Curation
  Session; "relationships per candidate" answers the more useful
  "how thoroughly are candidates being connected to each other,"
  which is what a health dashboard should be telling an engineer.
* **Average Evidence Coverage** — the *percentage of candidates with
  at least one linked Evidence Region*, not the average link-count per
  candidate. "Coverage" reads most naturally as "how much of the
  session is covered by evidence" — a fraction of the whole — rather
  than an average magnitude; the average-link-count reading would also
  let one heavily-evidenced candidate mask several candidates with
  none, which is exactly the failure mode a health metric should
  surface, not hide.

### Display

Session Health is a section within the Property Inspector's existing
Session mode (`lib/knowledge/inspector/session_properties.dart`,
shown as the fallback when a session exists but nothing more specific
is selected) rather than a separate dialog or mode — see § Property
Inspector below.

## Property Inspector

This work package's Property Inspector section: "Extend support for:
Provenance, Dependency information, Session Health." None of the
three became an independent, mutually-exclusive top-level mode:

* **Provenance and Dependencies** are **tabs** within the existing
  Knowledge Candidate mode (`lib/knowledge/inspector/knowledge_candidate_properties.dart`,
  now a `Properties | Provenance | Dependencies` tab switch, mirroring
  the Engineering Review panel's own Candidates/Relationships tab
  pattern from Work Package 007). This work package's own Connection
  Manager section calls these "Current Provenance View"/"Current
  Dependency View" — read as **derived getters**
  (`FoundationServiceState.provenanceFor`/`dependencyFor`), not new
  selection state, the same reading Work Package 010 applied to
  "Current Validation State" (`candidateValidation`). Since neither has
  its own selection field, neither can be an independently-selectable,
  mutually-exclusive mode the way Object/Relationship/Knowledge
  Candidate/etc. are — but unlike Work Package 010's Specification/
  Validation Status (folded directly into the Properties display),
  Provenance and Dependencies can each be substantial enough content
  that permanently mixing them into the same scroll as core fields
  would bury the core fields, so they're tabs *within* Knowledge
  Candidate mode instead of sections *inside* the Properties tab.
* **Session Health** is a section within Session mode
  (`session_properties.dart`) — it has no "selection" to switch on at
  all (it describes the whole session, not one selected thing), so it
  couldn't be a tab or a mode driven by a selected item the way
  Provenance/Dependencies are; it belongs wherever the *session itself*
  is already displayed, which is Session mode's existing fallback
  role.

## Selection Synchronization

"Selecting a node updates the Property Inspector. Selecting an item
elsewhere updates the graph. Selection remains synchronized." (this
work package's own text) — satisfied **without any new selection
field**. Every node the Knowledge Session Graph renders is one of
three kinds (`candidate`/`evidenceRegion`/`sourceMaterial`), and the
Connection Manager already has a `selected*` field for each of the
three (`selectedCandidate`/`selectedEvidenceRegion`/
`selectedSourceMaterial`, established Work Packages 005/008/009):

* The graph widget reads `foundation.selectedCandidate`/
  `selectedEvidenceRegion`/`selectedSourceMaterial` directly to
  determine which node (if any) to highlight — the same state every
  other panel already watches, so "selecting an item elsewhere updates
  the graph" requires no extra wiring at all; it falls out of `ref.watch`.
* Tapping a node calls the new
  `FoundationRuntimeNotifier.selectGraphNode(KnowledgeGraphNode node)`,
  which dispatches to whichever of the three existing `select*` methods
  matches the node's `kind` — "Current Graph Selection" (this work
  package's own Connection Manager text) is this dispatch method, not a
  fourth selection field competing with the three that already exist.

This was a deliberate choice over introducing a new, independent
"Current Graph Selection" field — see § Architectural Observations for
why that alternative was rejected.

## Architectural Observations

* **This work package's Connection Manager section names four items
  ("Current Graph Selection, Current Provenance View, Current
  Dependency View, Current Session Health") but none required new
  stored state.** "Current Graph Selection" is fully satisfiable by
  reusing the three selection fields the graph's own node kinds already
  map onto one-to-one (see § Selection Synchronization) — introducing
  a separate, fourth field would have meant either duplicating
  selection state (a synchronization bug waiting to happen, the exact
  class of bug Work Package 009's `openSourceDocument` mistake
  demonstrated) or maintaining two competing "what's selected" sources
  of truth. "Current Provenance View"/"Current Dependency View"/
  "Current Session Health" are all read as derived getters, following
  the precedent Work Package 010 set for "Current Validation State." No
  part of this reading required an independent architectural decision
  beyond patterns this project has already applied twice.
* **"Procedures connect to their Procedure Steps" (this work package's
  Node Types section) does not literally describe an edge between two
  *nodes* this graph renders — Procedure Steps are not in the Display
  list of things to visualize.** Read as "a Procedure connects, via its
  steps, to whatever those steps reference" — i.e. the edge is drawn
  from the Procedure Candidate node directly to each
  `referencedCandidateId`/`referencedRegionId` its steps carry, treating
  the step itself as a relationship-carrier rather than a rendered
  node. An alternative reading — Procedure Steps as their own small
  node kind, with Procedure → Step → Referenced-Thing as two edges
  instead of one — was considered and rejected: it would add a fourth
  node kind nowhere named in the Display list ("Knowledge Candidates,
  Relationship Candidates, Procedure Candidates, Specification
  Candidates, Evidence Regions, Source Material"), and Procedure Steps
  already have a dedicated, fully-featured display surface (the
  Property Inspector's Procedure Step mode, Work Package 010) that a
  small graph node couldn't usefully replace. This is a judgment call,
  not a blocking conflict — a literal reading of the surrounding text
  was available and applied.
* **A Source Material → Evidence Region edge (`sourceContainsRegion`)
  is not named anywhere in this work package's edge list, but was
  added anyway.** Without it, every Source Material node would be
  completely disconnected from the rest of the graph whenever no
  Page Selection or other explicit source-level link exists — an
  isolated node with no way to reach it from anything else the graph
  shows, even though "Source Material" is explicitly listed among the
  things to visualize. This edge draws a structural fact that already
  exists (`EvidenceRegion.sourceId`) rather than introducing new data
  or new architecture; it was treated as filling an omission in the
  edge list, not as an independent decision to model something new.
* **Session Health's "Orphaned Candidates," "Relationship Density," and
  "Average Evidence Coverage" have no formulas anywhere in this work
  package's text.** See § Session Health Model above for the exact
  formula chosen for each and the reasoning — all three are read
  literally from their labels' most natural engineering-dashboard
  meaning, computed purely from existing session data, and documented
  explicitly rather than left implicit, so a future work package (or
  this one's review) can agree, disagree, or redefine them with a
  clear record of what "Work Package 011" originally meant.
