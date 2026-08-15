# Engineering Project

What an "Engineering Project" is, why it lives in Studio rather than
Foundation or the Engineering Engine, and how it relates to the shared
Engine instance every other WORK_PACKAGE_025 doc assumes exists
(WORK_PACKAGE_025, ENGINE-TASK-000118).

## What it is

`EngineeringProject` (`lib/core/models/engineering_project.dart`) is
reference data only:

```dart
class EngineeringProject {
  final String id;
  final String name;
  final String? repositoryPath;
  final String? knowledgeSessionId;
  final String? diagramDocumentPath;
  final DateTime createdTime;
  final DateTime lastModified;
}
```

A Project coordinates existing systems — it never copies Knowledge
Session, Engineering Graph, or Evidence content. `repositoryPath`,
`knowledgeSessionId`, and `diagramDocumentPath` are pointers into
systems that already own that data (Foundation, `KnowledgeSessionStorage`,
`DiagramDocument` respectively) and are all independently nullable: a
Project can exist with none, some, or all of them set, matching
"Projects coordinate existing systems. Projects do not duplicate
repository functionality" from the work package text.

`EngineeringProjectStorage` (`lib/core/services/engineering_project_storage.dart`)
persists one JSON file per project under
`%APPDATA%/oep_studio/projects/<id>.json` — the same file-per-record
convention `KnowledgeSessionStorage` already established, not a new
persistence pattern.

## Why Studio, not Engine or Foundation

* **Not Foundation.** Foundation is read-only from Studio's perspective
  and has no concept of a Knowledge Session — an `EngineeringProject`
  referencing one would be meaningless to it.
* **Not the Engineering Engine.** The Engine owns Graph/Layout/
  ViewState/Commands/Search/Validation — none of those are
  Foundation- or Knowledge-Session-aware, and the Constitution's
  ownership boundary keeps it that way. Putting `EngineeringProject`
  there would force the Engine to learn about `KnowledgeSession`/
  `SourceMaterial`, both Studio-only concepts.
* **Studio.** Studio already orchestrates both Knowledge Studio and
  Diagram Studio; a Project is exactly the kind of cross-cutting
  coordination object Studio's own ownership area ("Workflow,
  Persistence") already covers.

## Relationship to the shared Engine instance

`EngineeringProject` itself carries no Engine reference — the live
Engine, editing session, selection, and validation report are held
separately, by `engineeringProjectServiceProvider`
(`lib/core/services/engineering_project_service.dart`), described in
full in `docs/WORKSPACE_SYNCHRONIZATION.md`. A Project's
`diagramDocumentPath`, once set, identifies *which* document that
shared Engine should have open — the Project does not hold the
document itself, and setting a Project's `diagramDocumentPath` does
not, by itself, open the document (Project Explorer's "New Project"
flow only creates and activates the Project record; opening or
switching the active diagram document remains an explicit Diagram
Studio action, unchanged from WORK_PACKAGE_024).

## What this work package does not add

No repository creation/deletion, no Knowledge Session creation beyond
what Knowledge Studio already provides, and no schema shared between
Foundation/Engine/Studio — `EngineeringProject` is purely a Studio-side
grouping of ids that already mean something to their owning system.
