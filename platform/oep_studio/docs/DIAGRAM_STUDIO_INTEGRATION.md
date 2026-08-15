# Diagram Studio Integration

WORK_PACKAGE_024 — the first work package to span two repositories.
This document is the overview; four companion documents cover specific
seams in depth: `STUDIO_ENGINE_HOST.md`, `WORKSPACE_INTEGRATION.md`,
`PROPERTY_INSPECTOR_INTEGRATION.md`, `REPOSITORY_INTEGRATION.md`.

**Architecture freeze (AP-DS-001):** the full, independently-verified
architecture of Diagram Studio — Constitution, Architecture
Specification, Interaction Model, Document Model, Engineering Model,
Canvas Architecture, Editing Architecture, Performance Targets, and
Implementation Roadmap — is ratified under
[`docs/architecture/diagram_studio/`](architecture/diagram_studio/).
That document set supersedes this page as the authoritative source for
architectural claims (in particular: the current absence of a working
Foundation Bridge, the absence of Engineering Intelligence Platform
integration, and the absence of performance engineering in the canvas
rendering path — all confirmed by direct code inspection, not assumed).
This page remains a valid narrative overview of the two-repository
ownership split.

## What Diagram Studio is

Diagram Studio is the second major Primary Workspace, after Knowledge
Studio — the production, end-user diagram-editing experience for the
Open Engineering Platform. It is registered exactly like every other
Studio workspace: a `StudioDestination` enum value, a `GoRoute`, and a
page widget (`DiagramStudioPage`), rendered inside the same persistent
`StudioShell` (Toolbar/NavRail/Primary Workspace/Property Inspector/
Status Bar) every other workspace uses.

It is **not** a new application, does not open a floating window, and
does not duplicate any of Studio's existing infrastructure. Every
engineering capability it exposes — editing, selection, undo/redo,
routing, validation, search, layers, annotations, wire editing,
placement tools — is a direct call into `package:engineering_engine`'s
public API. Studio contributes only orchestration: workspace chrome,
toolbars, panels, document lifecycle, settings, workspace persistence,
and AI prompt assembly.

## Ownership boundary (unchanged, now proven in practice)

| Concern | Owner |
|---|---|
| Engineering Graph, Diagram Layout, ViewState, Selection, Commands, Routing, Validation, Search, Editing, Navigation, Rendering model | `oep_engine` |
| Workspace management, Window management, Docking, Menus, Toolbars, Property Inspector hosting, Workspace persistence, User experience | `oep_studio` |
| Repository ownership, Knowledge storage, Evidence, Provenance | `oep_foundation` |

No code in `lib/diagram_studio/` imports anything from
`package:engineering_engine` except the single public barrel
(`package:engineering_engine/engineering_engine.dart`) — there is no
`import 'package:engineering_engine/core/...'` anywhere in this
repository, matching the same discipline the Demonstration Host itself
follows.

## Module layout

```
lib/diagram_studio/
  workspaces/diagram_studio_page.dart   The workspace page + all interaction state
  host/engine_host.dart                 Thin EngineeringEngine lifecycle wrapper
  host/diagram_document.dart            Open/Save/Save As/Close/Dirty State
  inspector/                            7 new Property Inspector *Properties widgets
  toolbars/diagram_toolbars.dart        9 toolbar groups
  panels/                               6 panels (KnowledgePanel chrome)
  commands/studio_command_actions.dart  Undo/Redo/Copy/Cut/Paste/Delete/Duplicate
  settings/                             DiagramStudioSettingsProvider + its own storage
  persistence/                          DiagramWorkspaceState + WorkspaceStateStorage
  ai/                                   DiagramPromptContext + DiagramAiService
```

## Reuse, not duplication

Per this work package's explicit instruction ("Do not duplicate:
Property Inspector, Workspace framework, Docking framework, Settings,
AI infrastructure, Command routing. Integrate with them."):

* **Property Inspector** — one new field
  (`FoundationServiceState.selectedEngineeringInspectable`) and one new
  tuple case in the existing `PropertyInspectorPanel`, not a second
  inspector. See `PROPERTY_INSPECTOR_INTEGRATION.md`.
* **Workspace/docking framework** — there isn't a separate one to
  integrate with beyond the existing pattern (a `StudioDestination` +
  `GoRoute` + page, panels wrapped in `KnowledgePanel`). Diagram Studio
  follows the identical shape Knowledge Studio already established.
* **Settings** — one more `SettingsProvider`, appended to
  `SettingsRegistry.defaultRegistry`.
* **AI infrastructure** — calls the existing `AiProviderRegistry`
  directly; no new provider implementations.
* **Command routing** — there is no Studio-wide command bus to
  integrate with (`StudioToolbar`'s buttons are still `onPressed: null`
  placeholders, and grepping for `Shortcuts`/`Actions`/`Intent`
  elsewhere in Studio returns nothing). Diagram Studio's own
  `CallbackShortcuts` + toolbar callbacks are the first keyboard-
  shortcut plumbing in Studio, scoped entirely to its own workspace
  page — the global `StudioToolbar` is untouched.

## What changed in `oep_engine`

One deliberate, disclosed deviation from "no engine code changes are
anticipated": the Demonstration Host's canvas presentation widgets
(`GraphViewPanel` and ten supporting painters/widgets) and three
drafting dialogs had zero Demonstration-Host-specific dependencies, so
duplicating them into Diagram Studio would have created two
independently-drifting renderers of the same `DiagramScene`/`ViewState`
data. They were promoted into `oep_engine/lib/views/widgets/` and
`lib/views/dialogs/`, exported from the public barrel, and both hosts
now consume the exact same classes. No `lib/core/` file changed, no
engineering behavior changed, and the Demonstration Host's own full
test suite passes unmodified. See `oep_engine/docs/
ARCHITECTURE_DECISIONS.md` ADR-023 for the full reasoning.

## Known gaps (recommendations for future work)

* Align/Distribute commands have no toolbar button yet in Diagram
  Studio (reachable via `AlignNodesCommand`/`DistributeNodesCommand`
  directly, just not wired to UI).
* No on-screen rulers (a Demonstration-Host-only polish feature, not
  promoted).
* The Property Inspector's Relationship mode shows raw node ids for
  source/target rather than resolved display names.
* No dedicated AI chat/review panel yet — only the prompt-assembly/
  provider-call integration point exists.
