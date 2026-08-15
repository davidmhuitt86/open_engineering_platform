# Project Explorer

The new `/project` workspace: a single tree rooted at the active
Engineering Project, replacing nothing — it sits alongside the
existing per-domain explorers rather than absorbing them (WORK_PACKAGE_025,
ENGINE-TASK-000126).

## Placement

`StudioDestination.projectExplorer` (`lib/core/routing/studio_destination.dart`)
is inserted as the **second** enum value, immediately after
`dashboard`. `StudioNavRail` iterates `StudioDestination.values` in a
flat `ListView`, so enum position alone promotes Project Explorer to
the top of the rail — no Navigation Rail or `StudioShell` changes were
needed. Its `GoRoute` (`lib/core/routing/app_router.dart`) follows the
same one-route-per-destination shape every other workspace uses.

## Why a new page, not a rewrite of an existing one

Studio already has domain-specific explorers — the Repository
Explorer, the Object Explorer, Diagram Studio's own Diagram Explorer
panel. Project Explorer is not a replacement for any of them; it is a
cross-cutting summary view, one branch per domain, that exists because
none of those domain-specific explorers can see across Knowledge,
Diagrams, Evidence, Validation, and AI Sessions at once. Each branch's
leaves navigate through the exact same `unified_navigation.dart`
helpers a user would reach some other way (search results, evidence
chips, validation findings) — Project Explorer adds no navigation
logic of its own.

## Structure

`ProjectExplorerPage` (`lib/features/project_explorer/project_explorer_page.dart`)
is a `ConsumerWidget`: a header (active project name, or "Project
Explorer" if none is active, plus a "New Project" action) above a
plain `ExpansionTile`-based tree — consistent with WORK_PACKAGE_022/
023/024's repeated "basic implementation only, do not introduce a
docking framework" precedent for panels. Seven branches:

* **Knowledge** — `FoundationServiceState.candidates`, each leaf
  calling `goToKnowledgeObject`.
* **Diagrams** — one leaf (Diagram Studio has exactly one document
  concept today; there is no multi-document list to enumerate),
  showing the current document's filename/dirty state, navigating to
  `/diagram`.
* **Evidence** — `FoundationServiceState.sourceMaterials`, each leaf
  selecting the source and navigating to Knowledge Studio.
* **Components** — `FoundationServiceState.objectList` (Foundation
  Engineering Objects), each leaf calling `goToKnowledgeObject`.
* **Validation** — a trailing badge mirroring the live
  `ValidationReport.findings.length` (no branch expansion needed to see
  the count) and a leaf navigating to `/validation`.
* **AI Sessions** — the current AI conversation, if any, read from
  `FoundationServiceState.currentAiConversation`.
* **Simulation** — a disabled "Coming Soon" placeholder. WORK_PACKAGE_025
  explicitly excludes Simulation implementation; this branch exists so
  the tree's shape doesn't need to change again once Simulation is
  eventually built.

Every branch reads live state through the existing
`foundationRuntimeServiceProvider`/`engineeringProjectServiceProvider`
— no new state, no caching, no snapshotting.

## "New Project"

Creating a project (`_createProject`) prompts for a name, constructs an
`EngineeringProject` with only that name and a generated id set (every
other field — `repositoryPath`, `knowledgeSessionId`,
`diagramDocumentPath` — stays `null`), persists it via
`EngineeringProjectStorage.save`, and activates it via
`EngineeringProjectNotifier.setActiveProject`. It does not create a
Knowledge Session, open a repository, or create a diagram document —
see `docs/ENGINEERING_PROJECT.md` for why a Project is reference data
only, never a container that itself performs those actions.
