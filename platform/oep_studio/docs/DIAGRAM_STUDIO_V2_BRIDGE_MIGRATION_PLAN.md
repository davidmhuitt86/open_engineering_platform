# AP-DIAGRAM-V2-BRIDGE-MIGRATION-001 — Functional Parity Audit & Migration Plan

> Audit/architecture only. No V2, Engine, or Foundation source was
> modified to produce this document; no production behavior changed.
> Cross-references (not rewritten):
> [`DIAGRAM_STUDIO_V2_WEBVIEW_POC.md`](DIAGRAM_STUDIO_V2_WEBVIEW_POC.md),
> [`DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md`](DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md),
> [`DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md`](DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md),
> [`DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md`](DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md),
> [`DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md`](DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md),
> [`OEP_STUDIO_WEB_SURFACE_ARCHITECTURE.md`](OEP_STUDIO_WEB_SURFACE_ARCHITECTURE.md).

## 1. Executive Decision

**The native Flutter Diagram Studio renderer is no longer the target UI
architecture. Legacy V2 embedded through the Web Surface is the target
Diagram Studio presentation layer. OEP Engine/Foundation remain
authoritative for engineering state.**

Three prior bridge tasks (module lifecycle, wire creation, Web Surface
promotion) already proved the mechanics: module move/create/delete/
rename, node-to-node relationship creation, and a real Studio navigation
entry point all work against the existing, unmodified Engine/Controller
surface. This document is the first pass at *scope*: everything V2 does,
matched against everything OEP already has, with an honest classification
of what's left.

## 2. Current Architecture

```
OEP Studio (StudioShell, WorkbenchSidebar navigation)
  ├── Native Diagram Studio (StudioDestination.diagram)
  │     EngineeringWorkbenchPage → DiagramStudioPage
  │     GraphViewPanel / SymbolNodeWidget / WirePainter / ConnectionPreviewPainter
  │     V2CanvasHost / V2ModuleCard / V2WirePainter / V2ConnectionPreviewPainter
  │     (AP-DIAGRAM-V2-002..014's Studio-owned V2-look-alike renderer)
  └── Web Surfaces (StudioDestination.webSurfaces)
        WebSurfacesHostPage → LegacyV2WebViewPage (bridge-authorized)
                              → LegacyV2BridgeTransport → LegacyV2StateAdapter
                              → DiagramStudioController → OEP Engine
```

Two competing "look like V2" efforts currently coexist: the native
renderer (`V2CanvasHost` et al. — Flutter widgets painted to *resemble*
V2) and the actual embedded V2 (a real Chromium surface running V2's own
unmodified code). This task's decision collapses that duplication in
favor of the second.

## 3. Target Architecture

```
OEP Studio
  └── Web Surface Host (production route, not dev-only)
        └── Legacy V2 WebView
              ├── V2 UI / interaction  (unmodified)
              ├── V2 sidebar / dialogs (unmodified)
              └── Bridge
                    LegacyV2BridgeTransport (WebView<->Dart messages only)
                    LegacyV2StateAdapter (identity, coordinates, loop guard)
                    DiagramStudioController (existing Engine command wrappers)
                    OEP Engine (unmodified — every command already exists
                                 except where §4 marks ENGINE EXTENSION REQUIRED)
```

The native renderer's *painting* code is not part of this target at all.
Its *backend* code (Controller methods, Engine commands) mostly already
is the bridge's own dependency — see §12.

## 4. V2 Functional Inventory → OEP Mapping Matrix

Sourced from direct reading across this and prior tasks
(`js/app.js`, `js/editor/module-editor.js`, `js/editor/wire-editor.js`,
`js/editor/routing-editor.js`, `js/ui/sidebar.js`, `js/ui/inspector.js`,
`js/core/bootstrap.js`, `js/storage/vehicle-loader.js`,
`js/storage/project-saver.js`, `js/storage/project-loader.js`,
`js/editor/undo-redo.js`, `js/editor/clipboard.js`,
`js/storage/autosave.js`) plus OEP source across `platform/oep_engine/`
and `platform/oep_studio/`.

| # | V2 Operation | V2 Source | Existing OEP API | Classification |
|---|---|---|---|---|
| 1 | Module creation | `module-editor.js` `commitAddModule` | `CreateNodeCommand` / `controller.addNodeWithMetadata` | **DIRECT** for `ground`/`connector` categories (real symbol match); **ADAPTER REQUIRED** for the other 9 categories pending symbol authoring (`DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md` §6) |
| 2 | Module deletion | `module-editor.js` `delModule` | `DeleteNodeCommand` / `controller.deleteNode` | **DIRECT** (already bridged) |
| 3 | Module movement | `module-editor.js` `setupDrag` | `MoveNodesCommand` / `controller.moveNodes` | **DIRECT** (already bridged) |
| 4 | Module selection | `inspector.js` `showModInfo`/`selMod` | `engine.registry.selection.selectNode` | **ADAPTER REQUIRED** — not yet bridged; V2's `selM` is polled today only for display (status bar), never turned into an OEP selection call |
| 5 | Module property editing | `module-editor.js` `saveModProps` | `RenameNodeCommand` (label only); `UpdateNodePropertiesCommand` (generic) | **DIRECT** for label (bridged); **ADAPTER REQUIRED** for `sub`/`notes` via `properties`/`metadata`; **BLOCKED** for `cat` (taxonomy mismatch, same reasoning as row 1) |
| 6 | Module search | `app.js` `doSearch` | No direct OEP equivalent found; Diagram Studio has its own search UI (`features/search/search_page.dart`) operating on a different data shape | **V2-ONLY / NOT REQUIRED** — V2's search already works client-side over its own `MODULES` array; nothing to bridge unless OEP's graph needs to be searchable *from* V2, which isn't asked for |
| 7 | Sidebar interaction (Inspector/Meter tabs, popout/dock) | `sidebar.js` | N/A — this is presentation, not engineering state | **V2-ONLY / NOT REQUIRED** |
| 8 | Edit/layout mode | `app.js`/`module-editor.js` `editMode` flag | No OEP "mode" concept — Diagram Studio editing is always live | **ADAPTER REQUIRED** — purely a V2-side interaction gate on the injected poller (module bridge doc §14 already flags this as unimplemented) |
| 9 | Wire creation | `wire-editor.js` `handleWireTerm` | `CreateRelationshipCommand` / `controller.createRelationship` | **DIRECT** at node level (already bridged); terminal-level precision is **ENGINE EXTENSION REQUIRED** (`EngineeringRelationship` has no port field at all — confirmed by reading the model directly, `DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md` §6) |
| 10 | Wire deletion | `wire-editor.js` `deleteSelectedWire` | `DeleteRelationshipCommand` (exists, confirmed via `platform/oep_engine/lib/core/editing/commands/delete_relationship_command.dart`) | **ADAPTER REQUIRED** — command exists, not yet wired to a `wireDeleted` poll message (explicitly out of scope for the wire-creation task, next in sequence) |
| 11 | Wire selection | `wire-editor.js`/`inspector.js` `selW` | Presumed `engine.registry.selection.selectRelationship` (symmetric with `selectNode`; not directly re-confirmed this pass) | **ADAPTER REQUIRED** |
| 12 | Wire property editing (label/color) | `wire-editor.js` `saveWireProps` | `UpdateRelationshipPropertiesCommand` / `controller.updateRelationshipMetadata` (`metadata['label']`/`['wireColor']`, confirmed established keys) | **DIRECT** for label/color (creation-time bridging already exists; *editing* an existing wire's label/color after creation is not yet bridged — same command, just no poll-diff wired to detect the edit) |
| 13 | Wire routing/editing | `routing-editor.js` (`wireRoutes[wireId][segIdx] = offset`, relative-offset model) | `SetWireRouteCommand` (absolute `List<Point2D>`) | **ADAPTER REQUIRED, lossy** — V2→OEP conversion needs V2's own auto-router evaluated first (not yet implemented); OEP→V2 is not directly computable without re-deriving offsets against that same router (confirmed dead end in the wire-creation task, §10 of that doc) |
| 14 | Connection/terminal behavior | `module-editor.js` terminals (`{n, c}` per module) | `Port` model (`id`/`name`/`direction`/`type`/`metadata`) | **ENGINE EXTENSION REQUIRED if port-level fidelity is ever wanted** — today, bridge-created nodes have `ports: const []` (never populated from a symbol definition); the relationship model itself has no port reference (row 9) |
| 15 | Zoom | `app.js` `zBy`/`zReset`, Ctrl+scroll, `+`/`-`/`Fit` buttons | `ViewState`/`ViewStateService` (`controller.viewState`) | **DIRECT one-way (OEP→V2)** — proven in POC-002 (`zReset()` invoked via `executeScript`); V2→OEP zoom sync (V2's own zoom driving OEP's `ViewState`) not attempted |
| 16 | Pan | `app.js` viewport drag | Same `ViewState` | **ADAPTER REQUIRED** — not attempted in either direction |
| 17 | View reset/fit | `app.js` `zReset` | `ViewStateService` | **DIRECT** (same as row 15) |
| 18 | Undo/redo | **V2 has none** (`undo-redo.js`'s `UndoRedoStack` confirmed dead code, never instantiated) | `engine.editing.undo()`/`redo()`, real LIFO command stack (`CommandHistory`) | **DIRECT** for every operation this bridge already performs (move/create/delete/rename/relationship-create) — proven working, including the real multi-step-undo semantics documented in `DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md` §13a/13 |
| 19 | Diagram loading | `vehicle-loader.js` `VehicleLoader.load` (bundle or fetch) | `DiagramDocument.open`/`EngineeringProjectNotifier.openDocument` | **PERSISTENCE BRIDGE REQUIRED** — see §6 |
| 20 | Diagram saving | `project-saver.js` `saveLayout` (partial: positions/wireRoutes/user wires/user modules only, NOT base vehicle data) | `DiagramDocument.save`/`saveAs` (full graph/layout/metadata envelope) | **PERSISTENCE BRIDGE REQUIRED** — see §6 |
| 21 | Vehicle/project selection | Implicit `vehicleId` param to `VehicleLoader.load`; no in-app switcher UI found | `EngineeringProjectService`/document open flow | **V2-ONLY today / PERSISTENCE BRIDGE REQUIRED long-term** — no V2 UI exists to change vehicle at runtime, so nothing to bridge yet; becomes relevant only once §6 is designed |
| 22 | Simulation mode | **V2 has none** — `js/simulator/` confirmed Phase-2/3/4 placeholder stubs, never real | `SimulationSession`/`diagram_simulation_service.dart` (real, existing) | **N/A — OEP is strictly ahead**; see §8 |
| 23 | Multimeter | `sidebar.js` Meter tab — static per-key-state lookup (`w.R[keyIndex]`, authored in `measurements.json`) | `MeasurementEngine`/`multimeter_controller.dart` (real fault-gated reachability + authored-value reporting, confirmed by reading `measurement_engine.dart` directly) | **ADAPTER REQUIRED, high value** — see §8 |
| 24 | Electrical state visualization | `app.js` `traceCircuit` — visual highlight over the static wire graph, not a computation | `SignalPropagator`/diagnostics engine (real) | **ADAPTER REQUIRED** — same shape as row 23; V2's highlight could be driven by OEP's real propagation result instead of a client-side graph walk |
| 25 | Clipboard (copy/paste/duplicate) | **V2 has none** (`clipboard.js` confirmed empty Phase-3 placeholder) | `StudioCommandActions` (real, existing, used by the native renderer today) | **N/A — OEP is strictly ahead**; nothing on the V2 side to bridge from, and no V2 UI to bridge *to* |
| — | Annotations | **V2 has none** (confirmed, no construct found anywhere in `js/`) | `CreateAnnotationCommand` et al. (real) | **N/A — OEP is strictly ahead** |
| — | Groups | **V2 has none** | `CreateGroupCommand`/`UngroupCommand` (real) | **N/A — OEP is strictly ahead** |

## 5. Bridge Data Model

Identity and representation mappings, consolidated from all prior bridge
tasks plus this pass's confirmation:

| V2 entity | OEP entity | Mapping | Lossy? |
|---|---|---|---|
| V2 module (`m.id`, authored or `'mod-'+slug+timestamp`) | `EngineeringNode.id` | Established (not discovered) on first bridged create; session-scoped map in `LegacyV2StateAdapter` | No (id itself), but see next row |
| V2 terminal (`(moduleId, terminalName)`, no separate id field) | `Port` | **No mapping exists at all** — bridge-created nodes have empty `ports`; `EngineeringRelationship` has no port reference | **Yes — total loss of terminal precision today** |
| V2 wire (`w.id`, authored or `'wire-'+timestamp`) | `EngineeringRelationship.id` | Established, same pattern as modules | No (id itself) |
| V2 diagram (in-memory `MODULES`/`WIRES`/`positions`/`wireRoutes`) | `DiagramDocument`/`EngineeringGraph`/`DiagramLayoutState` | No mapping exists — V2's diagram and OEP's active document are two unrelated data sets until §6 is designed | Yes, by construction today |
| V2 view state (`scale`/`tx`/`ty`) | `ViewState` | One-way trigger only (`zReset()`); no continuous sync | Not yet attempted either direction |
| V2 simulation state (`selK` key-state, `R[]` readings) | `SimulationSession`/`MeasurementResult` | No mapping exists | See §8 |
| V2 vehicle/project (`vehicleId`) | OEP project/document/session | No mapping exists | See §6 |

**Stable IDs**: confirmed real for authored V2 entities (module/wire ids
from `modules.json`/`wires.json`); confirmed session-only (not
cross-restart stable) for user-created ones (`Date.now()`-based).
**Node categories**: V2's 11 free-text categories vs. OEP's
`NodeCategory` enum are different taxonomies with no deterministic
correspondence beyond the two exact-string matches already used
(`ground`, `connector`) — re-confirmed, not re-litigated, from the module
bridge task.

**No shadow Engine model was created or is recommended** — every
mapping above either uses an existing OEP type directly or is marked as
a genuine gap (terminal/port, diagram-document identity) requiring either
new bridge-side bookkeeping (acceptable) or, for the port case, a real
Engine-level decision (not a bridge workaround).

## 6. Persistence Architecture (design only, not implemented)

**Recommendation: Option A — V2 becomes a presentation layer over an OEP
document, not a second source of truth.** Reasoning, from the actual
existing code:

- `DiagramDocument`'s envelope (`schemaVersion`/`documentId`/`graph`/
  `layout`/`metadata`) is already the complete, authoritative on-disk
  representation OEP uses everywhere else in Diagram Studio (native
  renderer included) — introducing a second, V2-native persisted format
  (Option B) would mean either two files staying in sync (a real
  synchronization problem with no existing infrastructure to lean on) or
  V2's own `project-saver.js`/`project-loader.js` becoming dead code
  once OEP is authoritative — the latter is what Option A implies
  cleanly.
- V2's own save format is **already partial** (`saveLayout` never
  re-saves base vehicle data) — it was never a complete document format
  to begin with, which weakens any case for treating it as co-equal with
  OEP's.

**What Option A requires, not yet built**:
1. A deterministic way to reconstruct V2's `MODULES`/`WIRES`/`positions`
   from an OEP `EngineeringGraph`/`DiagramLayoutState` on load — the
   reverse of every bridge direction built so far (today the bridge only
   ever reacts to V2 creating things; nothing yet *seeds* V2 from OEP at
   startup).
2. Durable (not session-scoped) V2-id ↔ OEP-id persistence — today's
   `_v2ToOepNodeId`/`_v2ToOepRelationshipId` maps live only in
   `LegacyV2StateAdapter`'s memory; they would need to become part of the
   saved document (e.g. as node/relationship `metadata`, which already
   exists as a mechanism — `EngineeringNode.metadata` already stores
   `v2ModuleId`/`v2Category` per the module bridge task).
3. A decision about what happens to a V2 vehicle's *base* data (the part
   V2 never re-saves) — does the OEP document become the sole record, or
   does V2's own `diagrams/<vehicle>/*.json` remain the seed data every
   OEP document for that vehicle is initialized from once? This is
   marked **OPEN**.

## 7. Undo/Redo Architecture

**No second undo system.** Every bridged mutation already goes through
`engine.editing.execute(...)`, so `engine.editing.undo()`/`redo()` is
already authoritative for everything bridged today — confirmed working,
including real multi-command semantics (a wire creation is *two* real
commands; undo reverts them one at a time, not atomically — documented,
not treated as a bug, in the wire-creation task).

**What's needed for full parity, not yet built**: `LegacyV2StateAdapter`
currently tracks only `lastBridgedV2ModuleId`/`lastBridgedV2WireId` — a
single-entry "what was most recently touched" pointer, sufficient for
one undo step but not a general history. A real "OEP undo happened,
resync whatever it affected" mechanism would need either (a) diffing the
whole graph before/after an undo (expensive, not attempted) or (b) the
Engine's own `CommandHistory` exposing *which* entities a given
undo/redo actually touched (not currently exposed — `EditingCommand`
has no "affected ids" contract) — marked **OPEN**, and the honest
answer to "should Engine expose this" is a real Engine-level design
question, not a bridge workaround.

## 8. Simulation/Multimeter Architecture

**This is the single highest-value, most over-qualified gap in the
whole system.** V2's own multimeter is a static lookup (`w.R[keyIndex]`,
pre-authored per wire per key-state, zero computation). OEP's
`MeasurementEngine` (confirmed by direct reading, `measurement_engine.dart`)
is a real fault-gated reachability engine already wired into Diagram
Studio's own Instruments Framework (`instruments/multimeter/
multimeter_controller.dart`, `simulation/diagram_simulation_service.dart`)
— both of which are **backend services, not renderer widgets**, meaning
they are already reusable by a bridge without touching (or depending on)
any of the frozen native-renderer files.

**Recommended architecture** (design only):

```
V2 meter UI (leads, key-state selector, reading display — unmodified)
    → bridge detects a meter-read request (V2 has no explicit "read"
      event today; would need either polling `selK`/lead state, or a
      new lightweight injected hook — smaller than a full protocol)
    → LegacyV2StateAdapter resolves the two probed (moduleId, terminal)
      pairs to OEP node/port references (BLOCKED today — same terminal/
      port gap as §4 row 14, until that's resolved this can only work
      at node granularity, which may be good enough for a first pass)
    → DiagramStudioController-level call into the existing
      MeasurementEngine/SimulationSession (no new Engine capability
      needed — confirmed real and already used by the native UI)
    → authoritative MeasurementResult
    → bridge writes the reading into V2's own meter display DOM
      (same "apply authoritative value" pattern already used for
      position/label sync)
```

**V2's own multimeter UI does not need to change at all** — only its
*data source* would be redirected, exactly as this document's Phase 8
instruction anticipated. The blocking dependency is §4 row 14/§5's
terminal/port gap; a node-granularity-only first version is possible
without waiting on that.

## 9. Native Flutter DS Dependency Audit

| File/class | Classification | Reasoning |
|---|---|---|
| `GraphViewPanel`, `SymbolNodeWidget`, `WirePainter`, `ConnectionPreviewPainter` | **KEEP TEMPORARILY** | The original (pre-V2-lookalike) native renderer; still the fallback while Web Surface isn't production. Frozen per this task's own Phase 1. |
| `V2CanvasHost`, `V2ModuleCard`, `V2WirePainter`, `V2ConnectionPreviewPainter` | **DELETE AFTER BRIDGE PARITY** | Built specifically to visually imitate V2 in Flutter (AP-DIAGRAM-V2-002..014) — now redundant by this task's own decision that real V2 is the target, not a Flutter lookalike of it. Frozen, not touched, per Phase 1. |
| `DiagramStudioController` | **REUSABLE BACKEND LOGIC** | Already the bridge's own dependency for every operation bridged so far (`addNode(WithMetadata)`, `moveNodes`, `deleteNode`, `renameNode`, `createRelationship`, `updateRelationshipMetadata`, `commands.undo/redo`) — this is not renderer code, it never was, and nothing about this migration touches it structurally. |
| `StudioCommandActions` | **REUSABLE BACKEND LOGIC** | Same reasoning — undo/redo/clipboard, engine-facing, no Flutter rendering dependency. |
| `DiagramDocument`, `EngineeringProjectService`, tab/document lifecycle (`diagram_studio/tabs/`) | **REUSABLE BACKEND LOGIC / REQUIRES DESIGN** | Document lifecycle stays; §6 requires new logic on top, not a replacement. |
| `MeasurementEngine`, `SimulationSession`, `multimeter_controller.dart`, `diagram_simulation_service.dart` | **REUSABLE BACKEND LOGIC** | Confirmed real, confirmed not renderer-coupled — directly reusable per §8. |
| `diagram_studio_page.dart`'s own widget tree (panels, toolbars, canvas host wiring, interaction-state fields) | **DELETE AFTER BRIDGE PARITY**, with **REQUIRES EXTRACTION BEFORE DELETION** for anything found to hold non-UI logic | Not fully re-audited line-by-line this pass (2900+ lines) — flagged as the single largest remaining unknown; a dedicated extraction pass is needed before deletion to confirm nothing beyond UI/interaction state lives there. **OPEN.** |
| Existing Diagram Studio tests (`test/diagram_studio/renderer/*`, `test/diagram_studio/controller/*`, `test/workflow/*`) | **REQUIRES EXTRACTION BEFORE DELETION** for controller-level tests (keep — they test reusable backend logic); **DELETE AFTER BRIDGE PARITY** for renderer-specific tests (`v2_wire_painter_test.dart` etc.) | Not exhaustively enumerated this pass — **OPEN**, a full test inventory is part of the eventual deletion PR, not this audit. |

## 10. Command-Palette Disposition

Re-examined per this task's explicit instruction to not assume it's
still needed. No file literally named "command palette" exists;
`diagram_studio/toolbars/diagram_toolbars.dart` is what prior tasks'
documents meant by that name — a `Ctrl+K`-openable dialog
(`command_palette_dialog_test.dart` confirms this exists as a real,
tested feature at the `StudioShell` level, not Diagram-Studio-specific)
plus the toolbar's own "Commands" field.

**Every meaningful Diagram Studio operation this palette exposes
already has a Legacy V2 sidebar/menu/modal equivalent** (module add/
edit/delete via the Add-Module panel and property modal; wire create/
edit via wire-mode + the wire-properties modal; search via V2's own `/`
search; zoom/fit via V2's own toolbar buttons) — confirmed by the
functional inventory in §4 and the earlier functional bridge assessment.

**Classification: OBSOLETE — DELETE**, once Legacy V2 is the production
surface. **Not removed in this task** (explicitly out of scope, and it
is a `StudioShell`-level feature reachable from every Studio, not just
Diagram Studio — removing it needs its own scoped task that confirms no
other Studio depends on it, since this audit only inspected its Diagram-
Studio-relevant commands).

## 11. Native DS Deletion Plan (dependency-ordered, not executed)

1. **Now → bridge parity**: nothing deleted. Native renderer remains the
   fallback.
2. **Immediately deletable once Web Surface is production** (§13's step
   1): the two dev-only entry-point buttons already were removed in
   AP-STUDIO-WEB-SURFACE-002; no further immediate deletions identified.
3. **Must remain until bridge parity** (§4's DIRECT+ADAPTER-REQUIRED rows
   are all actually bridged, not just classified): `V2CanvasHost` and
   siblings, `diagram_studio_page.dart`'s widget tree, renderer-specific
   tests.
4. **Backend logic requiring extraction first**: none identified beyond
   what §9 already flags as reusable and staying — `DiagramStudioController`/
   `StudioCommandActions`/document lifecycle/simulation services are
   already separate from the renderer, nothing to extract *out of* the
   renderer that isn't already outside it. The one **OPEN** item is
   `diagram_studio_page.dart` itself, per §9.
5. **Tests to replace**: renderer-specific tests (`test/diagram_studio/
   renderer/*`) get deleted alongside the renderer; controller/bridge
   tests stay and grow (this is the established pattern from every prior
   bridge task).
6. **Route/navigation changes required**: `StudioDestination.diagram`
   would need to either point at the Web Surface host instead of
   `EngineeringWorkbenchPage`, or be retired in favor of always routing
   through `StudioDestination.webSurfaces` — **OPEN**, a product decision
   about whether "Diagram Studio" as a distinct nav entry survives the
   transition or collapses into "Web Surfaces."
7. **Final files/directories removed** (once all of the above is
   actually done, not before): `diagram_studio/renderer/` (the whole
   V2-lookalike stack), `diagram_studio/workspaces/diagram_studio_page.dart`
   and its own toolbars/panels/context-menu support files, and their
   tests — **not enumerated file-by-file in this pass**; that level of
   detail belongs to the actual deletion PR, not this audit.

## 12. Ordered Implementation Roadmap

1. **Production Web Surface integration** — largely done
   (AP-STUDIO-WEB-SURFACE-002: real `StudioDestination`, real nav entry).
   Remaining: decide §11 item 6 (does `/diagram` redirect here?).
2. **Document/session authority** — §6's Option A design needs to become
   real: OEP document ↔ V2 seeding on load, durable id-map persistence.
3. **Durable V2 ↔ OEP identity mapping** — today session-scoped only
   (every prior bridge task's own stated limitation); needs to become
   part of the persisted document per §6 item 2.
4. **Module operations** — mostly done (create/delete/move/rename);
   remaining: selection (row 4), edit-mode gating (row 8), the 9
   unmapped categories (row 1, blocked on symbol authoring, not bridge
   code).
5. **Wire creation/deletion** — creation done; deletion is the next,
   already-scoped, not-yet-authorized task (row 10).
6. **Wire selection/metadata** — selection and post-creation metadata
   *editing* (as opposed to creation-time setting) not yet bridged (rows
   11/12).
7. **Wire routing strategy** — needs an explicit decision (attempt the
   lossy V2-router-evaluation conversion, or accept auto-routed-only
   wires permanently for V2-originated wires) before any code is written
   (row 13).
8. **Save/load persistence** — blocked on step 2's design being finished
   first; this is the item with the most remaining design work of
   everything in this roadmap.
9. **Undo/redo synchronization** — already real for what's bridged;
   needs the §7 "what did this undo actually touch" mechanism to
   generalize past single-entry tracking.
10. **Simulation/multimeter bridge** — §8's design, contingent on a
    node-granularity-only first version (not blocked on the terminal/
    port gap) or a real port-model decision (if full fidelity is wanted).
11. **Remaining V2 functionality** — pan (row 16), continuous zoom sync
    (row 15), electrical-state-visualization redirection (row 24).
12. **Native Flutter DS retirement** — stop routing any *new* Diagram
    Studio work through it once step 1–11 give Legacy V2 real functional
    coverage; keep it mounted as fallback.
13. **Native Flutter DS deletion** — per §11, only once parity is
    confirmed, not before.

This mostly matches the task's own suggested priority order; the one
adjustment made from direct source inspection is putting **wire routing
strategy** as its own explicit decision point (step 7) rather than
folding it into "wire creation/deletion" — the lossy-conversion problem
is large enough (confirmed dead-end for a lossless bidirectional
mapping, prior task) that it needs a yes/no decision before any code,
not just an implementation step.

## 13. Risks / Open Decisions

Every item marked **OPEN** above, consolidated:

- Whether OEP's document becomes the sole record for a V2 vehicle's base
  data, or V2's own `diagrams/<vehicle>/*.json` remains the seed data
  (§6 item 3).
- Whether `CommandHistory`/`EditingCommand` should expose "which
  entities did this command touch" for a general undo-resync mechanism,
  or whether per-bridge-task manual tracking (today's pattern) is
  accepted permanently (§7).
- Full line-by-line audit of `diagram_studio_page.dart` to confirm
  nothing beyond UI/interaction state lives there before it can be
  deleted (§9).
- Full test inventory for the eventual deletion PR (§9/§11 item 5).
- Whether `StudioDestination.diagram` survives as a distinct nav entry
  or collapses into Web Surfaces (§11 item 6).
- Command-palette removal — classified OBSOLETE but not removed; needs
  its own scoped task confirming no other Studio depends on it (§10).
- The wire-routing lossy-conversion yes/no decision (§12 step 7).
- Whether a real `Port`-level Engine model extension is ever pursued for
  terminal fidelity, or whether node-granularity bridging is accepted
  permanently (§4 rows 9/14, §5).

## 14. Definition of Bridge Parity

Bridge parity means, precisely: **every V2 operation classified DIRECT or
ADAPTER REQUIRED in §4 is actually implemented and live-verified**
(not merely classified) **, and every operation classified ENGINE
EXTENSION REQUIRED has an explicit, accepted decision** (build the
extension, or permanently accept the limitation) **rather than being
silently unaddressed.** V2-ONLY/NOT-REQUIRED and N/A rows do not block
parity by definition — they were never candidates for bridging.

By this definition, parity is **not yet reached**: rows 4, 6 (already
excluded), 8, 10–14, 16, 21–24 all still need either implementation or
an explicit accepted-limitation decision.

## 15. Exit Criteria for Deleting the Old Flutter DS

All of the following, not some:

1. Bridge parity (§14) reached.
2. §6's persistence architecture implemented and load/save round-trips
   verified live (a saved-then-reloaded V2-fronted document matches).
3. §11's full file/test inventory completed and executed.
4. §11 item 6's routing decision made and implemented.
5. §10's command-palette removal executed as its own task (parity makes
   it safe to remove, but removal itself is separate scoped work).
6. A final live regression pass confirming every §4 row still works
   through the bridge with the native renderer's route no longer
   reachable.

## 16. AP-DIAGRAM-V2-BRIDGE-007 — Edit-Mode / Interaction Parity

### 16.1 Exact V2 edit-mode behavior discovered

V2 has exactly **one** global boolean gate, `editMode`
(`js/editor/module-editor.js:66`, `toggleEdit()`, bound to the `✦
Layout` button and key `E`), plus two independent, mutually-coordinating
mode globals that are **not** "the" edit mode: `wireMode` (wire-creation
tool) and `routeEditMode` (route-segment tool, out of this bridge's
scope entirely). All three live as bare globals in `app.js`, are never
persisted (`project-saver.js`'s `saveLayout()` does not serialize any of
them), and carry **no data/simulation semantics** — `WIRES`/`MODULES`/
`positions` mutate identically regardless of mode, and the electrical
solver never reads any of the three.

Toggling `editMode` on also force-clears wire selection
(`editMode=true` branch of `toggleEdit()`: `selW = null;`) and
self-cancels `wireMode`/`routeEditMode` if either was active — V2's own
existing exclusivity logic, not something this bridge needed to
reproduce.

### 16.2 Exact operations gated, per source (module-editor.js, app.js, selection-manager.js)

| Operation | V2 gating rule (exact) |
|---|---|
| Module drag/move | Only starts `if (editMode)` — the **only** operation `editMode` disables outside itself |
| Module click-select | No-ops `if (editMode \|\| wireMode \|\| routeEditMode)` — i.e. only selectable in the "normal" mode |
| Wire select (`selWire`) | No-ops `if (editMode \|\| wireMode)` |
| Wire creation (`handleWireTerm`) | Gated by `wireMode` only, independent of `editMode` |
| Wire deletion via `Delete` key | `if (e.key === 'Delete' && selW && !editMode)` — blocked while `editMode` is on |
| Wire deletion via context menu (`ctxDelete`) | **Not** gated by any mode |
| Module deletion (`delModule`, always via context menu) | **Not** gated by any mode |
| Module creation (`commitAddModule`) | **Not** gated by any mode |
| Module/wire property modals | **Not** gated by any mode at the function level — only the context-menu *entry point* to module edit is conditionally hidden while `editMode` is on (`!editMode` in the menu-item list); the underlying function performs no check |
| Keyboard shortcuts | `Delete` (wire) gated as above; arrow-nudge/`R` reset gated by `routeEditMode` (out of scope); `E`/`W`/`F`/`/`/`L` toggle keys always fire |

### 16.3 Central finding — the existing bridge already respects every one of these rules, with zero gaps

Every currently-bridged mutation (module move, module create/delete/
rename, wire create/delete/select/property-edit, measurement request)
is detected by **polling V2's own underlying data**
(`positions`/`MODULES`/`WIRES`/`selW`/`selM`) — never by listening to a
synthesized UI event. V2 itself is the only thing that ever writes to
that data, and V2's own interaction code (§16.2) is what decides
whether a given user action is allowed to write to it at all. A blocked
interaction in V2 (e.g. attempting to drag a module while `editMode` is
off) therefore **never produces a data change** — there is nothing for
the poll loop to detect, and consequently nothing for the bridge to
mistakenly forward to OEP. This holds for every row in §16.2 without
exception; no gap requiring a Dart-side guard was found.

This is the direct, source-confirmed answer to this task's own
"THIRD: IMPLEMENT ONLY WHAT IS REQUIRED" — the required change turned
out to be none, for gating specifically. **Do not read this as "nothing
was verified"**: the finding was reached by reading every gating
condition in current V2 source (§16.2) and tracing, for each one, that
the corresponding bridge detector only fires on an actual observed data
transition — not by assumption.

One additional, related finding, not a gating gap: module selection
(`selM`) was **already** display-only in this bridge (surfaced only in
the status bar via `V2StatusMessage.selectedModuleId`) — it has never
been mirrored into OEP's `GraphSelection`, unlike wire selection. So
"module selection behavior where required for edit-mode semantics"
(this task's scope item 4) requires no change: there is no OEP
authoritative-selection mutation for module clicks to gate in the first
place.

### 16.4 Change implemented

Exactly one, deliberately minimal, **display-only** addition: V2's
`editMode` global is now included in the existing `v2Status` poll
message (`{selM, moduleCount, wireCount, editMode}`) — extending, not
duplicating, the same status snapshot POC-002 already established — and
surfaced in `LegacyV2WebViewPage`'s existing status bar text ("V2 mode:
Layout/Normal/unknown"). It is:

- **Not** consulted by any handler in `LegacyV2StateAdapter` — no
  gating logic reads it, per §16.3's finding that none is needed.
- **Not** part of the `LegacyV2Channel` interface (`onStatus` is a
  transport-only field, unchanged architecture from POC-002) — no test
  double needed updating.
- **Not** persisted anywhere, and not represented in the adapter at all
  — satisfying Phase FOURTH's own "if V2's edit mode is purely
  transient UI state, keep it transient. Do not add an Engine field for
  it" directly, by not adding any adapter/Engine representation at all.
- Reset for free on every WebView reload/reinitialization: it is not
  stored anywhere outside the poll loop's own `lastStatusSnapshot`
  (cleared by the injected script's own fresh initialization on
  navigation), so there is no stale-value carryover to guard against.

No other file changed operational behavior. Module movement, wire
creation/selection/deletion/property-edit, measurement requests, and
undo/resync are byte-for-byte unchanged from AP-DIAGRAM-V2-BRIDGE-
004/005/006 — confirmed by the full existing test suite passing
unmodified (189/189, including every wire/module/measurement test from
prior tasks).

### 16.5 Tests added

`test/diagram_studio/webview/legacy_v2_bridge_transport_message_test.dart`
— `V2StatusMessage.fromJson` extended with `editMode: true`/`false`/
absent decoding cases. This is the one part of this task genuinely
testable at the Dart level (message decoding); the gating claims in
§16.2/§16.3 are **source-level findings**, verified by direct reading of
current V2 `js/` files (quoted inline above), not by launching WebView2
— consistent with this task's own allowance ("If the behavior is best
verified by inspecting the injected JavaScript rather than launching
WebView2, document that explicitly"). A Dart test built on the existing
fake-channel architecture cannot exercise V2's actual gating logic at
all (the fake channel's `simulate*` calls represent "V2 already decided
to permit this," by construction) — writing one would not test the real
rule, only restate it, which is why none was added for "module move
while prohibited" / "wire creation while prohibited" per se.

Existing tests unmodified: the full `test/diagram_studio/`,
`test/instruments/`, `test/simulation/` suites (189 tests) all pass
unchanged, confirming no regression to any previously-bridged operation.

### 16.6 Remaining functional gaps (unchanged from prior tasks, not addressed by this task — out of scope)

- Terminal/port-level relationship fidelity — still **ENGINE EXTENSION
  REQUIRED**, unattempted (§3/§13 of prior bridge docs).
- Key-state (`keyPos`) → OEP operating-state mapping — still **OPEN**
  (§5/§21 of the simulation bridge doc).
- Wire route/segment editing, reconnect — still explicitly out of
  scope, unattempted.
- Wire-color format gap (V2 code strings vs. native editor's hex-only
  validation) — still **OPEN** (§21 of the wire bridge doc).

### 16.7 Recommended next AP-DIAGRAM-V2-BRIDGE package

Given §16.6, the two lowest-risk, highest-value remaining items are:
(a) a **live save/reload verification pass** exercising a document that
has gone through create → move → wire → measure → save → reopen, since
several prior tasks flagged this as tested only at the mechanism level,
not end-to-end live; or (b) revisiting the key-state gap (§16.6) if a
concrete document/DomainProfile author-side convention for pairing V2
key positions with OEP operating states is defined. Neither requires an
Engine change.

## 17. AP-DIAGRAM-V2-BRIDGE-008 — End-to-End Persistence Verification

### 17.1 Persistence path audited (current source, not prior reports)

`DiagramDocument` (`lib/diagram_studio/host/diagram_document.dart`) is
the authoritative persistence unit: one JSON envelope
(`{schemaVersion, documentId, graph, layout, metadata}`) per file,
written by `saveAs`/`save`, read by `open`. `documentId` is
`DiagramDocument._ensureId()` — generated lazily, reset to `null` by
`close()` (so two never-saved documents get distinct ids without
relying on `path`, confirmed unchanged from BRIDGE-003's own finding).
`EngineeringProjectNotifier` (`lib/core/services/engineering_project_service.dart`)
owns the actual lifecycle calls: `newDocument()`/`openDocument(path)`
both call `host.engine.editing.resetSession(...)` — a genuine, full
graph/session replacement, not a shortcut — and `saveDocument()`/
`saveDocumentAs(path)` write through `DiagramDocument.save`/`saveAs`.
`DiagramStudioController` (the bridge's own dependency) exposes thin
wrappers (`openDocument`, `saveDocument`, `saveDocumentAs`, `documentPath`,
`isDirty`) over the same notifier — confirmed these are the only
document-lifecycle entry points the bridge or its tests need.

### 17.2 Real disk round-trip — PASS

`test/diagram_studio/webview/legacy_v2_persistence_disk_roundtrip_test.dart`
(new): builds two modules + one wire through the real bridge path,
`saveDocumentAs` to a real temp file, asserts the written JSON contains
`v2ModuleId`/`v2WireId`/`wireColor`/`documentId`, discards the in-memory
adapter by switching to a different document (proving the old adapter's
maps are now stale, not merely "probably fine"), then `openDocument`s
the same file for real and constructs a **brand-new**
`LegacyV2StateAdapter` that reconstructs the full V2↔OEP identity
mapping — module ids, wire id, label, color, and **position** (`x`/`y`)
— purely from the reloaded document's own metadata. `DiagramDocument.id`
is confirmed to round-trip unchanged across the save/reload.

### 17.3 Cross-document isolation — PASS

`test/diagram_studio/webview/legacy_v2_persistence_cross_document_test.dart`
(new): Document A (module `a1`) and Document B (module `b1`) are each
built and saved to **real, separate files**. Switching A → B → A, each
time via a real `openDocument` + a **fresh** adapter instance, confirms:
Document B's adapter can never resolve `a1`; Document A's adapter (both
before and after visiting B) can never resolve `b1`; the live graph
contains exactly one node at every step, never a residual from the
other document. No leakage in either direction, across a real reload —
not just an in-memory `newDocument()` switch (which BRIDGE-002/003's
own tests already covered).

### 17.4 Never-saved document identity / dirty-state — PASS (after one fix — see §17.6)

`test/diagram_studio/webview/legacy_v2_persistence_dirty_state_test.dart`
(new): confirms mutation → dirty, save → clean, undo-after-save →
dirty-again, reopen → clean, and that two never-saved documents
(`path == null` for both) get distinct `DiagramDocument.id`s.

### 17.5 V2 reseed / WebView reload — verified at the transport/adapter contract level (source-level, per this task's own allowance)

`initializeFromDocument`/`reinitializeForDocument` (unchanged this
task) already clear V2 (`clearAllSurfaces`) before reseeding, and their
existing test coverage (BRIDGE-002/004) already proves no duplication
and no cross-document retention for the `newDocument()`-switch case;
§17.3 above extends that same guarantee through a **real** file reload.
A live WebView2 reload was not exercised (no WebView2 host runs inside
`flutter test`) — per this task's own instruction ("if the behavior is
best verified by inspecting the injected JavaScript rather than
launching WebView2, document that explicitly"), the reload contract is
verified at the two boundaries that matter: (1) `LegacyV2WebViewPage
._reloadV2()` calls `adapter.reinitializeForDocument()` then
`_transport.interceptV2Save()` again, in that order (confirmed by
reading current source) — save-interception re-application after
reload is therefore structural, not incidental; (2) V2's own
`window.saveLayout` reassignment happens via the injected script's
`__oepBridgeInterceptSave`, called fresh on every reload — V2's own
`js/storage/project-saver.js` file is never touched, so there is no
persisted V2-side override that could survive a reload and defeat
interception permanently.

### 17.6 Save — PASS, with one real defect found and fixed (dirty-state, not persistence)

Verified: V2's `saveLayout()` override (via `__oepBridgeInterceptSave`)
routes exclusively through `saveRequested` → `LegacyV2StateAdapter
._handleSaveRequested` → `DiagramStudioController.saveDocument()` — V2's
own `js/storage/project-saver.js` (a plain file download) is never
invoked once interception is active; confirmed unchanged from
BRIDGE-003. For an already-saved document, save succeeds and clears
dirty (§17.4). For a never-saved document, the existing, previously-
documented behavior (report failure via `reportSaveResult`, no fallback
to V2's own download) is unchanged.

**Real defect found and fixed**: `LegacyV2WebViewPage._undoLastV2Move()`
(the bridge's own "Undo" affordance) called
`controllerState.commands.undo()` directly, bypassing
`DiagramStudioController.undo()`'s own `markDirty()` call — every native
Diagram Studio undo action goes through the wrapper and dirties
correctly; the bridge's Undo button did not. This was caught by §17.4's
own dirty-state test failing on first run (`controller.commands.undo()`
called directly, matching the same bug), not invented after the fact.
**Fixed**: changed the one call site to `controllerState.undo()` — the
existing wrapper, not a new dirty-state mechanism (`legacy_v2_webview.dart`).
This is a one-line, source-confirmed fix squarely inside this task's own
"do not redesign unless verification exposes a concrete defect" allowance.

### 17.7 Save As — DEFERRED — FILE PICKER / WEBVIEW BRIDGE REQUIRED (confirmed, not changed)

`DiagramStudioController.saveDocumentAs(path)` /
`EngineeringProjectNotifier.saveDocumentAs` already exist and work
(exercised directly, repeatedly, by every new test this task added) —
the OEP controller has full Save As support. What is missing is a
**target path**: V2 has no file-picker mechanism of its own (it is a
browser page inside a WebView, not a native app with OS dialog access),
and no Flutter file-picker UI is wired to the bridge to supply one.
Building that picker/bridge wiring was explicitly out of this task's
scope ("do not fabricate a Save As UI"). Classified exactly as the task
itself frames it: **DEFERRED — FILE PICKER / WEBVIEW BRIDGE REQUIRED**,
not a persistence failure — ordinary Save works correctly (§17.6).

### 17.8 Undo/resync boundary — unchanged, re-confirmed

The full existing bridge test suite (192 tests across
`test/diagram_studio/`, `test/instruments/`, `test/simulation/`) passed
unchanged after §17.6's fix, including every move/rename/create/delete/
wire-property-edit/wire-delete undo scenario from BRIDGE-002/004/005.
The existing single-entry resync architecture
(`lastBridgedV2ModuleId`/`lastBridgedV2WireId`/`_lastBridgedKind`) is
unchanged and was not expanded — no concrete failure required it.

### 17.9 Tests added

- `test/diagram_studio/webview/legacy_v2_persistence_disk_roundtrip_test.dart`
- `test/diagram_studio/webview/legacy_v2_persistence_cross_document_test.dart`
- `test/diagram_studio/webview/legacy_v2_persistence_dirty_state_test.dart`
- `test/diagram_studio/webview/legacy_v2_persistence_e2e_support.dart`
  (shared harness/fake channel — not a test file itself)

**One file per `testWidgets` body, deliberately** — an earlier draft put
all three in one file and reproduced, on first run, the exact
intermittent-bootstrap-failure pattern `legacy_v2_state_adapter_test.dart`'s
own doc comment already warned about (splitting into multiple
`testWidgets` blocks in one file is not independent). Splitting into
separate files, one `testWidgets` each, resolved it — documented in
`legacy_v2_persistence_e2e_support.dart`'s own doc comment so the next
task doesn't rediscover this the hard way.

**Real disk I/O required `tester.runAsync`**: the first draft's real
`saveDocumentAs`/`openDocument` calls, awaited directly inside a plain
`testWidgets` body (not wrapped in `tester.runAsync`), hung for the full
10-minute test timeout rather than erroring — `AutomatedTestWidgetsFlutterBinding`'s
test zone does not reliably resolve genuine `dart:io` async gaps without
`runAsync` bridging them, the same reason this codebase's own
`bootstrap()` helper already wraps its `Future.delayed` polling loop in
`runAsync`. Every real-file-I/O call in the final three test files is
wrapped in `tester.runAsync(() => ...)`.

Isolation: `useIsolatedSettingsStorage()` (existing helper) redirects
`SettingsStorage.root()` (autosave/recovery); document files
save/load through a separate `Directory.systemTemp.createTempSync(...)`
per test, deleted in `tearDown`. Neither ever touches
`%APPDATA%\oep_studio` — confirmed by inspecting the helper's own
production-path guard.

### 17.10 Remaining persistence gaps

- Save As from V2 itself: DEFERRED per §17.7 (not a failure).
- A live WebView2 reload was not exercised inside an automated test —
  verified at the transport/adapter contract level instead (§17.5); a
  manual reload check remains a reasonable, non-blocking, optional
  developer spot-check.
- Autosave/recovery specifically for a V2-bridged (as opposed to
  native-renderer-created) document was not separately re-verified this
  task — the underlying mechanism (`DiagramDocument.autosave`/
  `findRecovery`) is identical regardless of which UI produced the
  document, and is already covered by `diagram_document_test.dart`.

## Verification

- `flutter analyze` — clean, this task (7 pre-existing, unrelated lints
  only).
- `flutter test test/diagram_studio/webview/legacy_v2_persistence_*` —
  3/3 new tests passed.
- `flutter test test/diagram_studio/ test/instruments/ test/simulation/`
  — 192/192 passed (zero regressions from the §17.6 fix).
- `flutter build windows --debug` — succeeded.
- Built `oep_studio.exe` launched, process confirmed running/responsive,
  then stopped cleanly (no lingering process).
- V2 source: zero writes — this task only read `js/`.
- Engine/Foundation: zero writes — no Engine change was needed or made.
- Production behavior: unchanged except the one dirty-state fix (§17.6).

## 18. AP-DIAGRAM-V2-BRIDGE-009 — V2 Functional Parity Completion Audit

### 18.1 Complete functional matrix (current state, this task's own re-verification)

**MODULES**

| Operation | Classification | Status |
|---|---|---|
| Select | ADAPTER REQUIRED | **NEW this task** — mirrored into `GraphSelection` |
| Move | ADAPTER REQUIRED | DIRECT, unchanged (BRIDGE-002) |
| Create | ADAPTER REQUIRED | DIRECT for `ground`/`connector` only (BRIDGE-002) |
| Delete | ADAPTER REQUIRED | DIRECT (BRIDGE-002) |
| Rename (label) | ADAPTER REQUIRED | DIRECT (BRIDGE-002) |
| Category/type (post-creation edit) | — | **GAP, classified honestly (§18.3)** — not bridged |
| Notes | PERSISTENCE REQUIRED | **GAP, classified honestly (§18.3)** — not bridged |
| Terminal information (post-creation edit) | ENGINE EXTENSION REQUIRED | OPEN, unchanged — structural, same boundary as port fidelity |
| Module search | V2-ONLY | N/A — pure local presentation over `MODULES`, no bridge needed |
| Module sidebar inspection | V2-ONLY | N/A — reads local `MODULES`, already seeded correctly at init |

**WIRES**

| Operation | Classification | Status |
|---|---|---|
| Create | ADAPTER REQUIRED | DIRECT, node-level (BRIDGE-003) |
| Select | ADAPTER REQUIRED | DIRECT (BRIDGE-004) |
| Delete | ADAPTER REQUIRED | DIRECT (BRIDGE-004) |
| Label | ADAPTER REQUIRED | DIRECT (BRIDGE-005) |
| Color | ADAPTER REQUIRED | DIRECT, V2 code-string representation; OPEN cross-producer gap vs. native hex editor (BRIDGE-005 §21) |
| Route/layout | ENGINE EXTENSION REQUIRED | OPEN, unchanged — explicit non-goal every task since BRIDGE-004 |
| Wire search/listing | V2-ONLY | N/A |
| Wire sidebar inspection | V2-ONLY | N/A |

**MODES**

| Item | Classification | Status |
|---|---|---|
| Edit mode | ADAPTER REQUIRED (display-only) | DIRECT (BRIDGE-007) — exposed via `v2Status.editMode`, never gates anything Dart-side because V2's own gating already prevents disallowed data changes (BRIDGE-007 §16.3) |
| Wire mode | V2-ONLY | N/A — a V2 tool-selection flag; the bridge only ever observes its *effect* (a wire actually appearing in `WIRES`), never the flag itself |
| Route edit mode | V2-ONLY | N/A — same reasoning; also gates a capability (route editing) this bridge deliberately never touches |

**SELECTION**

| Item | Classification | Status |
|---|---|---|
| Module selection | ADAPTER REQUIRED | **NEW this task** |
| Wire selection | ADAPTER REQUIRED | DIRECT (BRIDGE-004) |
| Deselection | ADAPTER REQUIRED | DIRECT, both kinds |
| Multi-selection | N/A | V2 has none (confirmed: `selM`/`selW` are each a single id, not a set — source-verified this task) |
| Selection reflected in sidebar | V2-ONLY | N/A — V2's own sidebar renders off `selM`/`selW` locally, unaffected by (and not dependent on) the OEP mirror |

**DOCUMENT**

| Item | Classification | Status |
|---|---|---|
| Save | ADAPTER REQUIRED | DIRECT (BRIDGE-003), verified end-to-end on real disk (BRIDGE-008) |
| Save As | DEFERRED | FILE PICKER / WEBVIEW BRIDGE REQUIRED (BRIDGE-008 §17.7) — OEP controller already supports it; V2 has no path-picker mechanism |
| Reload | ADAPTER REQUIRED | DIRECT, verified real-disk cross-document isolation (BRIDGE-008) |
| Close/reopen | ADAPTER REQUIRED | DIRECT, same mechanism as reload |

**SIMULATION**

| Item | Classification | Status |
|---|---|---|
| VDC / VAC / resistance / continuity / diode | ADAPTER REQUIRED | DIRECT (BRIDGE-006) |
| Current | NOT APPLICABLE | V2 has no current mode |
| Key state | OPEN | Unchanged — no deterministic V2-keyPos↔OEP-operating-state mapping exists (BRIDGE-006 §5/§21); re-confirmed this task, nothing new found |

**OTHER**

| Item | Classification | Status |
|---|---|---|
| Zoom / pan / fit | V2-ONLY | N/A — pure local canvas transform, confirmed no OEP sync attempted anywhere in V2 source |
| Annotations | N/A | V2 has no annotation concept |
| Clipboard | N/A | V2's own `js/editor/clipboard.js` is an explicit unimplemented placeholder — confirmed by direct read, not a bridge gap |
| Grouping | N/A | V2 has no grouping/layer concept at all — confirmed |
| Sidebar workflows | V2-ONLY / mostly N/A | See §18.4 |
| Keyboard shortcuts | V2-ONLY | N/A — every shortcut (`E`/`W`/`F`/`/`/`L`/`Delete`/`0`-`3`/arrows/`Ctrl+Shift+G`) drives local V2 tools or already-bridged operations; none needs new bridge support |
| Context menus | V2-ONLY | N/A — a single shared `#ctx` menu (`Edit`/`Trace Circuit`/`Delete`) routing to already-bridged or V2-local functions; no separate duplicate/notes/terminal menu items exist |
| Search | V2-ONLY | N/A — filters local `MODULES`/`WIRES` arrays only |
| Legend | V2-ONLY | N/A — iterates V2's own static category-color table |

### 18.2 Functionality implemented this package

**Module selection → `GraphSelection` mirroring** — the one genuine gap this audit found that was cheap, low-risk, and squarely in scope (Phase SEVENTH's own explicit ask). V2's `selM` (a single module id or `null`, confirmed via direct source read of `js/ui/inspector.js` — no multi-select) is now poll-diffed exactly like wire selection already was, and mirrored one-way into `engine.registry.selection.selectNode`/`deselectAll` via a new `LegacyV2StateAdapter._handleModuleSelectionChanged`. Symmetric with the existing wire-selection handler in every respect: unmapped module id → OEP selection left untouched (not cleared); confirmed by direct inspection that `SelectionService.selectNode`/`deselectAll` never touch the command stack or `EditingService` — selection cannot dirty the document (also asserted directly in the new test).

New transport message `moduleSelectionChanged { id }`, new `V2ModuleSelectionChangedMessage`, new `LegacyV2Channel.onModuleSelectionChanged` member (all four existing `_FakeChannel` test doubles updated). New adapter field `onModuleSelectionMirrored` (display-only callback, symmetric with `onWireSelectionMirrored` — neither is currently wired into `LegacyV2WebViewPage`'s own status text, matching that the wire-selection one wasn't either; both remain available for a future status-bar enhancement, not required for correctness).

### 18.3 Functionality intentionally NOT implemented, classified honestly

- **Module category/subtype editing after creation** — V2's module-properties modal (`saveModProps()`) can change `cat`/`sub` on an existing module; the bridge's `_handleModulePropertiesChanged` only ever compares/renames `label` (confirmed by direct re-read this task — `message.category` is decoded but never compared or acted on). This is not an oversight to fix casually: OEP has no "change a node's underlying symbol/category after creation" command — `_symbolIdForCategory`'s 2-of-11 deterministic mapping (§ module bridge doc) only applies at creation time, and there is no Controller/Engine operation that swaps a node's `symbolId` post-creation. Bridging this would mean either fabricating a category change that has no real effect on the node's actual symbol (dishonest), or inventing a new "change node symbol" Engine capability (out of this task's authorization — no concrete normal-workflow requirement forces it, since module category is overwhelmingly set once at creation). **Classified: no exact/defensible mapping exists — left unbridged, documented, not silently discarded.**

- **Module notes** — confirmed to be a real, separate string field on V2's module model (`js/models/module.js`'s `notes`, editable via the same properties modal, `module-editor.js`'s `saveModProps()`). Investigated whether OEP has a corresponding representation: `EngineeringNode` has two distinct maps — `metadata` (where this bridge already stores `v2ModuleId`/`v2Category`) and `properties` (a semantically different, engineering-value bag read by `MeasurementEngine`/verification for things like `expectedValue`). **A genuine architecture asymmetry was found**: relationships have `UpdateRelationshipPropertiesCommand` operating on `metadata` (which is what wire label/color bridging already uses), but nodes have no equivalent metadata-patch command — `UpdateNodePropertiesCommand` exists but patches `properties`, not `metadata`, and `DiagramStudioController` has no wrapper for either a node-metadata patch or a `properties` patch today. Bridging `notes` would require either (a) misusing the `properties` bag for a UI-only free-text field it wasn't designed to hold, alongside real engineering values like `expectedValue` — rejected as a category error, not a defensible mapping — or (b) adding a new node-metadata-patch Engine command, which is a small, real, but out-of-authorization capability this task did not add ("do not invent Engine metadata simply to make the matrix appear complete" — this task takes that literally: the metadata *mechanism* already exists for nodes, what's missing is only a *patch command* for it, a small, well-scoped, and defensible future addition, but still a genuine gap today, not something to paper over). **Classified: PERSISTENCE REQUIRED (a small, well-scoped Controller/Engine addition), left unbridged this task.**

- **Module terminal editing after creation** — confirmed V2 genuinely supports this (`editModProps()`/`saveModProps()` rebuild `m.terminals` wholesale from an editable row list, not just at creation — a materially bigger capability than previously documented). This is structurally the same terminal/port-fidelity gap already established as **ENGINE EXTENSION REQUIRED** across every prior bridge task (`EngineeringNode.ports` is `const []` on every bridge-created node; nothing writes to it). No new decision was made or needed — this task's investigation simply confirmed the existing classification also covers post-creation terminal *editing*, not only terminal-aware wire creation.

None of the above triggered a full package STOP — each is a bounded, already-classified item, not a blocker to the normal module/wire/selection/document/simulation workflows this task otherwise found fully bridged.

### 18.4 Sidebar-as-primary-UI assessment

V2's sidebar/inspector (`js/ui/inspector.js`, `js/ui/sidebar.js`) is confirmed **already fully functional as the primary interaction surface**, with no bridge dependency for its own rendering: module/wire property display, search (`doSearch`, local `MODULES`/`WIRES` filter), legend (`buildLegend`, V2's own static category table), and the single shared context menu all operate entirely on V2's own already-correctly-seeded local state (`initializeFromDocument` already restores `MODULES`/`WIRES` with real label/category/color before V2 ever renders). **No new bridge support was needed for any sidebar workflow** — this is the intended architecture already working as designed, not a gap. Property *editing* from the sidebar routes through the modals already covered in §18.1/§18.3 (label/color: bridged; category/notes/terminals: the classified gaps above).

### 18.5 Native renderer deletion-readiness assessment (read-only audit; nothing deleted)

Full file-by-file inventory performed. Summary:

- **Confirmed production routing** (re-verified directly, current source): `/diagram` → `WebSurfacesHostPage(autoOpenLegacyV2: true)` (V2 bridge, production default). `/diagram-classic` → `EngineeringWorkbenchPage` → `DiagramStudioPage` (native renderer), reachable only via an explicit in-app link, excluded from the primary nav rail. `initialLocation` is `/dashboard`, not `/diagram` — deliberate (BRIDGE-002, keeps `flutter test`'s headless environment from auto-opening a WebView2 surface), unrelated to which page `/diagram` itself resolves to.
- **DELETE AFTER PARITY** (renderer-exclusive, no other consumer): the full `lib/diagram_studio/renderer/` canvas/painter/scene stack (`v2_canvas_host.dart`, `v2_module_card.dart`, `v2_wire_painter.dart`, `v2_connection_preview_painter.dart`, `v2_wire_edit_overlay.dart`, `v2_category_colors.dart`, `scene_coordinate_transform.dart`, `studio_diagram_scene.dart`, `diagram_scene_adapter.dart`); native inspector widgets (`inspector/*.dart`, 8 files); native canvas-coupled panels (`panels/diagram_mini_map.dart`, `diagram_intelligence_overlay.dart`, `diagram_annotation_panel.dart`, `diagram_layer_panel.dart`, `diagram_search_panel.dart`, `diagram_recent_commands_panel.dart`, `diagram_explorer_panel.dart`); `toolbars/diagram_toolbars.dart`; `context_menu/diagram_context_menu.dart`; tab UI widgets (`tabs/diagram_mode_switcher.dart`, `diagram_tab_bar.dart` — NOT `diagram_tab.dart`/`diagram_tabs_controller.dart`/`diagram_tabs_storage.dart`, which are REUSABLE BACKEND); the multimeter/probe UI widgets (`instruments/dock/instrument_dock.dart`, `instruments/multimeter/digital_multimeter_panel.dart`, `instruments/probe/probe_overlay.dart` — NOT their controllers/stores, which are REUSABLE BACKEND); simulation UI widgets (`simulation/fault_injection_panel.dart`, `power_distribution_panel.dart`, `simulation_diagnostics_panel.dart`, `simulation_playback_controls.dart`, `simulation_sessions_panel.dart`, `simulation_state_overlay.dart`, `simulation_center_dialog.dart` — NOT `diagram_simulation_service.dart`, confirmed directly imported by the V2 bridge itself, REUSABLE BACKEND); publishing dialogs (`publishing/publishing_center_dialog.dart`, `tabular_report_dialog.dart`, `title_block_editor_dialog.dart`).
- **REUSABLE BACKEND** (no canvas coupling, used by or usable by the V2 bridge): `controller/diagram_studio_controller*.dart`, `commands/studio_command_actions.dart`, `host/*.dart`, `repository/diagram_repository_service.dart`, `persistence/*.dart`, `intelligence/diagram_intelligence_service.dart`, `ai/*.dart`, `simulation/diagram_simulation_service.dart`, `instruments/*_controller.dart`/`*_store.dart`, `instruments_host/*.dart`, `tabs/diagram_tab.dart`/`diagram_tabs_controller.dart`/`diagram_tabs_storage.dart`.
- **STILL REQUIRED / not renderer-specific**: `migration/legacy_migration_dialog.dart`/`legacy_migration_models.dart` (document-format migration, unrelated to the V2-bridge question despite the naming collision); `settings/diagram_studio_settings*.dart`; the Knowledge Studio-flavored panels (`panels/knowledge_graph_panel.dart`, `knowledge_sessions_panel.dart`, `query_console_panel.dart`, `recommendation_panel.dart`) — these depend on `DiagramStudioController`/engine data, not the native canvas, so they likely need re-parenting to a V2-hosted dock rather than deletion.
- **UNKNOWN, needs a closer pass before AP-DIAGRAM-V2-BRIDGE-010**: `workspaces/diagram_studio_page.dart` itself (~3750 lines) — never line-audited to confirm no non-UI business logic is trapped in its `State` fields; this is the single largest open blocker to a clean deletion, independent of anything else in this audit. `panels/diagram_validation_panel.dart`, `panels/engineering_explorer_panel.dart` — plausibly reusable/re-parentable, not confirmed either way this pass. `test/widget_test.dart`, `test/diagram_intelligence_overlay_test.dart`, `test/intelligence_panels_test.dart`, `test/workflow/unified_workflow_test.dart` — need individual review before bulk-deleting alongside the renderer.
- **Tests to delete alongside the renderer**: all of `test/diagram_studio/renderer/` (12 files), `test/diagram_studio/toolbars/simulation_controls_toolbar_operating_state_test.dart`, all of `test/workflow/` except any confirmed to test controller-only logic.
- **Tests that must survive**: all of `test/diagram_studio/controller/` (9 files), `test/diagram_studio/tabs/diagram_tabs_controller_test.dart`, all of `test/diagram_studio/webview/` (the V2 bridge's own tests).
- **Assets**: `oep_studio` bundles no local asset directory of its own (`pubspec.yaml`'s `assets:` block is fully commented out). The renderer's only asset touchpoint (`v2_module_card.dart`'s `SvgPicture.asset('assets/symbols/...', package: 'engineering_engine')`) pulls from the Engine-owned package, not a renderer-exclusive asset — nothing renderer-exclusive to clean up.
- **Genuinely still-required native-only capabilities** (corrected against this session's actual completed work, since a first-pass audit read stale planning sections of this same document rather than the record of what BRIDGE-004 through 009 actually shipped): wire route/segment editing (still genuinely unbridged, explicit non-goal); terminal/port-level precision (ENGINE EXTENSION REQUIRED, unchanged); Save As (DEFERRED, file picker); module category/notes/terminal post-creation editing (§18.3, this task's own new findings). Module move/create/delete/rename/select, wire create/delete/select/label/color, document save/reload, and VDC/VAC/RES/CONT/DIODE measurement are **already fully bridged** — the first-pass file-level audit is accurate; do not trust that same audit's characterization of *functional* parity status without cross-checking against §§1-18 of this document, which is the current source of truth.

**Bottom line**: parity is close but not complete — wire routing (no decision made) and the three new §18.3 gaps (category/notes/terminals) remain. `diagram_studio_page.dart`'s own extraction audit is the largest concrete blocker to a clean AP-DIAGRAM-V2-BRIDGE-010 deletion pass, independent of bridge functionality.

### 18.6 Command-palette dependency assessment

`toolbars/diagram_toolbars.dart` (Diagram Studio's own in-page toolbar/command surface, confirmed to live only in `DiagramStudioPage`'s content area, never the global `StudioShell` toolbar) and its companion `panels/diagram_recent_commands_panel.dart` are the closest things to a "command palette" specific to Diagram Studio. Per §18.4, V2's own sidebar (search, legend, mode buttons, context menu, property modals) already covers the equivalent day-to-day workflows for a V2-fronted document. **This task documents `diagram_toolbars.dart`/`diagram_recent_commands_panel.dart` as functionally obsolete for Diagram Studio once V2 is the production surface** (which it already is, at `/diagram`) — consistent with their §18.5 DELETE AFTER PARITY classification. No global `StudioShell` behavior was inspected or altered — this assessment is scoped exactly to Diagram Studio's own in-page toolbar, per this task's own instruction not to touch `StudioShell` yet.

### 18.7 Save/reload regression

Re-ran the full BRIDGE-008 persistence suite (`legacy_v2_persistence_disk_roundtrip_test.dart`, `legacy_v2_persistence_cross_document_test.dart`, `legacy_v2_persistence_dirty_state_test.dart`) as part of this task's full regression pass — all pass unchanged, confirming module selection's addition introduced no persistence regression (selection is intentionally never persisted, per §18.1's SELECTION row and the existing "V2 UI-only mode changes do not dirty" guarantee).

### 18.8 Tests added

- No separate message-decoding test file changes were needed: `V2ModuleSelectionChangedMessage` reuses the exact same single-nullable-id shape `V2WireSelectionChangedMessage` already exercises in `legacy_v2_bridge_transport_message_test.dart`.
- `test/diagram_studio/webview/legacy_v2_state_adapter_test.dart` — extended with module-selection assertions: mirrors into `GraphSelection.nodeIds`, does not dirty the document, deselects correctly, and leaves existing selection untouched for an unmapped module id. All 4 `_FakeChannel` test doubles across the webview test directory updated with the new `onModuleSelectionChanged` interface member.

### 18.9 Verification (this task)

- `flutter analyze` (`lib/diagram_studio/webview`, `test/diagram_studio/webview`) — clean.
- `flutter test test/diagram_studio/ test/instruments/ test/simulation/` — 192/192 passed (same total as BRIDGE-008's own final count — module selection extended an existing test rather than adding a new one).
- `flutter build windows --debug` — succeeded.
- Built `oep_studio.exe` launched, confirmed running/responsive, stopped cleanly.
- V2 source: zero writes (read-only investigation, including the new deletion-readiness/sidebar audits).
- Engine/Foundation: zero writes — the one genuine Engine gap found this task (node-metadata-patch command, §18.3) was left unimplemented, not silently added.

## 19. AP-DIAGRAM-V2-BRIDGE-010 — Native Diagram Studio Retirement & Parity Completion

### 19.1 What was audited

- **`diagram_studio_page.dart` line-by-line extraction audit** (Phase 1):
  the full ~3872-line file was classified section by section. Finding:
  the controller extraction from prior Wave 1/2 tasks was genuinely
  thorough — almost every document/tab/command delegation was already a
  clean one-line forward to `DiagramStudioController`, not duplicated
  logic. Two real gaps were found and closed (§19.2). The remaining
  ~2500 non-`build()` lines were overwhelmingly native-canvas gesture/
  hit-testing/drag machinery with no meaning once the canvas is gone.
- **Native-renderer dependency audit** (Phase 5): every file under
  `renderer/`, `inspector/`, `panels/`, `toolbars/`, `context_menu/`,
  the native halves of `tabs/`/`instruments/`/`simulation/`, and
  `publishing/` was traced by real import graph (not filename guessing)
  against the rest of `lib/`. One file (`property_inspector_panel.dart`,
  `lib/shared/widgets/`) was discovered to depend on the entire
  `inspector/` directory — a genuine cross-Studio dependency the initial
  pass missed by only checking `diagram_studio_page.dart`'s own
  consumption, not the reverse direction; caught by the compiler
  (`flutter analyze`) immediately after deletion, and `inspector/` was
  restored intact (`git restore`, confirmed zero net diff on that
  directory). `engineering_instrument.dart` was confirmed genuinely
  shared (imported by `workbench/perspectives/instruments_perspective.dart`)
  and kept. `MultimeterController` and `instrument_bridge_provider.dart`/
  `oip_host_bridge_service.dart` were confirmed shared with
  `core/context/` (the Contextual Command System) and
  `diagram_simulation_service.dart` respectively, and kept.
- **Production routing**: `/diagram-classic` was found to not be
  purely a "native renderer fallback" as originally assumed — it is the
  only route mounting the multi-Perspective `EngineeringWorkbenchPage`
  shell, which also hosts the real Engineering and Instruments
  Perspectives. Deleting the route entirely would have deregistered
  those. The route was **kept**; only `diagramPerspective` (the
  native-renderer-hosting Perspective) was removed from
  `workbenchPerspectives`.

### 19.2 What was implemented

- **Save As from the V2 bridge** (Phase 4): `LegacyV2WebViewPage`
  gained a "Save As…" toolbar button using `package:file_selector`
  (already an existing dependency — no new package), calling
  `DiagramStudioController.saveDocumentAs` (the exact same method the
  native renderer's own `_saveAsDocument()` already called — same OEP
  document authority, no second save format), then reseeding V2 via the
  existing `reinitializeForDocument()` path. Closes the DEFERRED item
  from AP-DIAGRAM-V2-BRIDGE-008 §17.7.
- **Selection→Property-Inspector sync, extracted to the Controller**
  (Phase 1 finding, closed): the retired native page's own
  `_selectionInspectorSub`/`_syncPropertyInspectorSelection` was real,
  UI-independent business logic the shared `PropertyInspectorPanel`
  still needs regardless of which surface changes the selection — it
  was not yet extracted, and deleting the page without moving it would
  have silently broken the Property Inspector for every selection
  change, native or V2-bridged. Moved into
  `DiagramStudioController.bootstrap` (a `engine.registry.selection.changes`
  subscription, app-session-lived, same lifetime as `engine` itself —
  see that method's own doc comment). The other half of the original
  subscription (wire-edit-mode point reseeding) was genuinely native-
  canvas-specific and was retired, not moved — there is nothing left
  for it to do without draggable wire vertices.
- **Test harness replacement**: every bridge/controller/persistence
  test that used to mount the native `DiagramStudioPage` purely to reach
  `state.controllerForTest`/`state.engine` now uses a new
  `test/support/diagram_studio_controller_harness.dart`
  (`bootstrapDiagramStudioController`), which awaits
  `diagramStudioControllerProvider` directly — the exact same real
  bootstrap sequence, with no native-canvas widget tree involved. This
  is faster (no more polling for an "Add node" tooltip that no longer
  exists) as well as necessary.

### 19.3 What was deleted

**Library** (41 files) — the full native canvas/painter stack
(`renderer/canvas/*`, `renderer/scene/*`); native property-editor
widgets NOT shared elsewhere (`inspector/` was audited and kept, see
§19.1); native-only panels (`panels/*` — all 14, confirmed
renderer-exclusive by import trace); `toolbars/diagram_toolbars.dart`;
`context_menu/diagram_context_menu.dart`; native tab UI widgets
(`tabs/diagram_mode_switcher.dart`, `diagram_tab_bar.dart` — NOT
`diagram_tab.dart`/`diagram_tabs_controller.dart`/
`diagram_tabs_storage.dart`, confirmed shared with
`web_surface_tabs_controller.dart` and kept); native instrument UI
widgets (`instruments/dock/*`, `instruments/multimeter/digital_multimeter_panel.dart`,
`instruments/probe/probe_overlay.dart` — NOT their controllers/stores,
confirmed shared and kept); native simulation UI panels
(`simulation/*_panel.dart`, `simulation_center_dialog.dart`,
`simulation_playback_controls.dart`, `simulation_state_overlay.dart` —
NOT `diagram_simulation_service.dart`, confirmed used directly by the
V2 bridge and kept); all of `publishing/` (9 files — dialogs plus their
supporting logic; confirmed renderer-exclusive by import trace, though
the logic files are individually portable if a future task wants to
re-parent them); `workspaces/diagram_studio_page.dart` itself;
`workbench/perspectives/diagram_perspective.dart`.

**Tests** (32 files) — every test that pumped the now-deleted native
widgets directly: all of `test/diagram_studio/renderer/` (12 files),
all of `test/workflow/` (14 files), all of `test/publishing/` (9
files), `test/instruments/{instrument_dock_state,instrument_dock_widget,
probe_overlay,digital_multimeter_panel}_test.dart`,
`test/intelligence_panels_test.dart`, `test/diagram_intelligence_overlay_test.dart`,
`test/diagram_studio/toolbars/simulation_controls_toolbar_operating_state_test.dart`,
`test/simulation/simulation_center_dialog_test.dart`. One additional
test, `test/diagram_studio/controller/diagram_studio_wire_metadata_inspector_test.dart`,
was discovered — via a real test failure, not assumption — to already
be stale before this task (it asserted `TextField`s
(`relationship_wire_label_field`/`relationship_wire_color_field`) that
do not exist anywhere in `EngineeringRelationshipProperties`'s actual
source, confirmed via `git diff HEAD` showing zero difference on that
widget — it has never had editable wire label/color fields in this
repository's history); deleted as testing functionality that does not
exist, not as a casualty of this task's own changes.

### 19.4 What was deliberately retained

Every file `git status` doesn't list as deleted under
`lib/diagram_studio/`/`lib/workbench/perspectives/` — most notably:
`controller/`, `commands/`, `host/`, `repository/`, `persistence/`,
`intelligence/`, `ai/`, `webview/` (the bridge itself), `migration/`
(document-format migration, unrelated to the renderer question despite
the naming collision), `settings/`, `tabs/diagram_tab*.dart`/
`diagram_tabs_controller.dart`/`diagram_tabs_storage.dart`,
`instruments/core/`, `instruments/bookmarks/`, `instruments/history/`,
`instruments/multimeter/multimeter_controller.dart`,
`instruments_host/`, `simulation/diagram_simulation_service.dart`; the
`/diagram-classic` route and `EngineeringWorkbenchPage` itself (kept
for the Engineering/Instruments Perspectives, §19.1); the global
`StudioShell` command system (§19.6); `inspector/` (all 8 files,
confirmed shared with `property_inspector_panel.dart`).

### 19.5 Final V2 parity matrix

Unchanged from §18.1 — this task added Save As (§19.2) and re-confirmed
every other row; no new gaps were found in the functional bridge
itself. Remaining open items: wire routing (ENGINE EXTENSION REQUIRED/
model-incompatibility, unchanged), terminal/port fidelity (ENGINE
EXTENSION REQUIRED, unchanged), module category/notes/terminal
post-creation editing (§18.3, unchanged), key-state mapping (OPEN,
unchanged).

### 19.6 Command-palette disposition

Confirmed by dependency audit: `diagram_toolbars.dart` and
`diagram_recent_commands_panel.dart` (Diagram Studio's own in-page
toolbar/recent-commands surface — the closest thing to a "command
palette" scoped to this Studio) had no consumer outside the native
renderer and were deleted alongside it (§19.3). The global `StudioShell`
command system was not inspected for deletion and was not touched —
this task's own scope was Diagram-Studio-specific, per
AP-DIAGRAM-V2-BRIDGE-009 §18.6's own finding, now acted on.

### 19.7 Route architecture (confirmed, re-verified after all changes)

```
/diagram  →  WebSurfacesHostPage(autoOpenLegacyV2: true)  →  Legacy V2 (auto-opened)
             → LegacyV2BridgeTransport → LegacyV2StateAdapter
             → DiagramStudioController → OEP Engine
```

No hidden dependency on the native renderer remains on this path — the
native renderer's own route (`/diagram-classic`) now serves only the
Engineering/Instruments Perspectives (§19.1), with no Diagram
Perspective registered on it anymore.

### 19.8 Tests and verification

- `flutter analyze` — clean throughout (returned to the same 7
  pre-existing, unrelated lints after every fix pass).
- `flutter test` (the **entire** suite, not a scoped subset) — 768/768
  passed (2 pre-existing skips), after fixing every fallout compile
  error and 5 genuine runtime failures this deletion surfaced (detailed
  in the completion report).
- `flutter build windows --debug` — succeeded.
- Built `oep_studio.exe` launched, confirmed running/responsive twice
  (once mid-task, once at the end), stopped cleanly both times.
- Static verification: `/diagram` route confirmed to not reference the
  native renderer; zero V2 source writes; zero Engine/Foundation writes
  (the one Engine gap found, §18.3, remains unimplemented); zero
  remaining imports of any deleted file (confirmed by `flutter analyze`
  returning to a clean baseline); one document-save authority
  throughout (`DiagramStudioController.saveDocument`/`saveDocumentAs`,
  used identically by V2's new Save As button and the (removed) native
  renderer alike — never duplicated); one undo system throughout
  (`StudioCommandActions`/the Engine command stack — unchanged); no
  shadow routing engine introduced; no fabricated V2→OEP category/
  terminal mappings introduced.

## 20. AP-DIAGRAM-V2-BRIDGE-011 — remaining functional parity & engineering-gap resolution

### 20.1 Terminal/port fidelity (Phase 2) — RESOLVED, case A

Discovered a real, pre-existing informal convention already consumed by
`VerificationEngine._portReferenced` and
`StateConditionResolver._relationshipsForComponent`:
`relationship.metadata['sourcePort']`/`['targetPort']`, a plain
string-equality convention (no `Port` object, no schema change). No
writer existed anywhere before this task. Classification: **existing
capability (A)** — no STOP CONDITION, no Engine schema change.

### 20.2 Wire creation terminal mapping (Phase 3) — IMPLEMENTED

`LegacyV2StateAdapter._handleWireCreated` now writes
`metadata['sourcePort']`/`['targetPort']` from V2's `fromTerminal`/
`toTerminal` (received on every `V2WireCreatedMessage` since
AP-DIAGRAM-V2-WEBVIEW-003 but never persisted until now). Round-tripped
through `restoreWire` on document init, undo-resync, and disk
save/reload. Verified in `legacy_v2_state_adapter_test.dart` and
`legacy_v2_persistence_disk_roundtrip_test.dart`.

### 20.3 Module metadata / notes (Phase 4) — IMPLEMENTED, generic mechanism

New `UpdateNodeMetadataCommand` (`platform/oep_engine/lib/core/editing/
commands/update_node_metadata_command.dart`) — a generic metadata-patch
command mirroring the pre-existing `UpdateRelationshipPropertiesCommand`
exactly (`null` patch values remove keys; full undo/redo). Deliberately
targets `metadata`, not `properties` (still confirmed semantically
distinct — `properties` is the engineering-value bag, `metadata` is
free-form annotation). Wired end-to-end: V2's module `notes` field
bridges via `DiagramStudioController.updateNodeMetadata`, with a real
null-vs-empty-string bug found and fixed
(`legacy_v2_state_adapter.dart`, `_handleModulePropertiesChanged`) — a
missing `?? ''` default caused every plain label-only rename to also
push a spurious, no-op notes-clear command onto the undo stack.

Category/subtype: **CONTENT/AUTHORING REQUIRED** — only 2 of 11 V2
module categories have a deterministic OEP symbol; the pre-existing
`ChangeNodeCategoryCommand` exists but partial/fabricated category
mapping for the other 9 was rejected as out of scope for this task
(no fabricated mappings, per the operating-mode instruction).

### 20.4 Wire routing (Phase 5) — classified B, not implemented

V2 stores bend points as module-position-relative offsets
(`js/models/wire.js`: "bend offsets... layout concern"). OEP already
has a comparably-shaped subsystem — `DiagramLayoutState.wireOverrides`
(absolute `Point2D` list per relationship, layout-sibling state per
SDD-024/ADR-011, never on the graph itself), `SetWireRouteCommand`
(command/undo-redo), and `OrthogonalRoutingProvider` auto-routing when
no override exists. The only real gap: OEP's overrides are absolute
canvas coordinates, V2's are position-relative offsets, so an OEP
override does not itself track a subsequently-moved module.
Classification: **(B) small Engine extension** (translate stored
override points by node-position delta) — not a second routing engine,
so STOP CONDITION #2 does not apply. Not implemented this task (listed
in §20.9 List A as recommended future work — scope/time bounded, and
not required to answer the parity question honestly).

### 20.5 Reconnect (Phase 6) — NOT APPLICABLE

`ReconnectRelationshipCommand` already exists and is already wrapped by
`DiagramStudioController.reconnectRelationship`. Confirmed via
`grep -rln "reconnect|dragEndpoint|moveEndpoint"` against the V2 JS
source that V2 has **zero** reconnect/endpoint-drag UI. Engine
capability exists with nothing in V2 to bridge it to — no code change
made or needed.

### 20.6 Key state / operating state (Phase 7) — classified A, not implemented

V2 (`js/knowledge/behaviors/switch.js`) models ignition key position
(OFF/ACC/RUN/START) as a discrete value that changes which terminal
pairs conduct. OEP Engine already has the exact generic mechanism for
this: `InputStateDefinition.topologyEffects`, resolved by
`StateConditionResolver.resolveBlockedRelationshipIds` — explicitly
designed to be domain-agnostic, mapping any discrete `toString()` value
to a set of blocked relationship ids. Classification revised from
BRIDGE-006's prior **OPEN** to **(A) existing capability — bridge it**:
one `InputStateDefinition` per ignition switch with `topologyEffects`
keyed `'OFF'`/`'ACC'`/`'RUN'`/`'START'`. Not implemented this task
(§20.9 List A) — requires locating/bridging V2's actual key-position UI
event and constructing real `InputStateDefinition`s per project, which
is a data-authoring/bridging exercise better scoped as its own task
than folded in here.

### 20.7 Simulation/multimeter terminal-aware probes (Phase 8) — classified B, not implemented

`ProbePoint` (`measurement_types.dart`) already has an optional `portId`
field. No `Port` object exists on `EngineeringNode`. Terminal-precise
measurement can reuse the same plain-string convention §20.1
established (`relationship.metadata['sourcePort']`/`['targetPort']`)
rather than fabricating a Port model — matching `ProbePoint.portId`
against those metadata strings, the same pattern
`_relationshipsForComponent` already uses. Classification: **(B) small,
non-fabricated extension**. Not implemented this task (§20.9 List A) —
requires wiring measurement resolution to filter by this match, plus a
V2-side terminal-selection UI audit, which BRIDGE-006 did not confirm
V2 exposes today.

### 20.8 Sidebar/workflow parity (Phase 9) — re-confirmed, no new gaps

Re-audited against BRIDGE-009's findings; no new gaps found beyond
those already tracked in §20.9.

### 20.9 Final lists

**List A — remaining Engine extensions (classified, not implemented):**
wire-route position-relative override translation (§20.4);
`InputStateDefinition` topology-effects authoring for ignition key
state (§20.6); `ProbePoint.portId`-to-`metadata['sourcePort']` matching
in measurement resolution (§20.7).

**List B — remaining bridge adapters:** none identified beyond List A's
Engine-side prerequisites — no purely bridge-side gap remains once
those three land.

**List C — remaining content-authoring requirements:** OEP symbols for
the 9 of 11 V2 module categories without a deterministic mapping today
(§20.3).

**List D — remaining product decisions:** whether V2-parity wire
routing (§20.4) and key-state (§20.6) are worth the Engine extension
investment given they are not blocking any test or basic
create/edit/save/undo workflow today.

**List E — permanently incompatible V2 behaviors:** none newly
identified this task; no STOP CONDITION was triggered (all Phase 2/5/7/8
investigations resolved to A/B classifications, not C).

**List F — recommended future work:** implement List A in priority
order (terminal-aware probes first, since §20.1/§20.2's convention is
already live and this is the smallest remaining increment); then
key-state; then wire-route translation.

### 20.10 Tests and verification

- `flutter test` (full `oep_studio` suite) — 768/768 passed (2
  pre-existing skips), after fixing the null-vs-empty-string notes bug
  (§20.3).
- `flutter test` (full `oep_engine` suite) — 356/356 passed (unchanged
  from baseline; `UpdateNodeMetadataCommand` covered indirectly via the
  `oep_studio`-side bridge tests, following this repo's existing
  pattern of testing new Engine commands through their real caller
  rather than in isolation).
- `flutter analyze` (`oep_studio`) — 7 issues, all pre-existing and
  unrelated (unnecessary import in `studio_app.dart`, 2 curly-brace
  style notes in `foundation_runtime_service.dart`, 4 doc-comment/print
  notes in `tools/hot_reload_client.dart`) — zero issues in any file
  touched this task.
- `flutter build windows --debug` — succeeded
  (`build\windows\x64\runner\Debug\oep_studio.exe`).
- No V2 source files modified. No native Flutter renderer resurrected.
  No shadow routing engine created. No fabricated category/terminal
  mappings. Single document/save/undo authority preserved throughout
  (`DiagramStudioController` + the Engine command stack).
- No STOP CONDITION was triggered — every phase resolved to a
  concrete A/B/NOT APPLICABLE classification, never a vague "needs
  investigation."

## 21. AP-DIAGRAM-V2-OEP-UI-001 — OEP visual integration

Purely a presentation-layer task: restyled the OEP shell/chrome
surrounding the (unmodified) Legacy V2 webview to use the app's real
`StudioColors`/`StudioTheme` tokens instead of ad-hoc hardcoded colors,
and removed leftover migration-only UI. No functional/bridge/Engine
code touched.

### 21.1 Visual system audited

`platform/oep_studio/lib/core/theme/studio_colors.dart`
(`StudioColors`) and `studio_theme.dart` (`StudioTheme.dark`) — the
existing, real design-token source of truth (background, surface,
surfaceRaised, surfaceSunken, border, textPrimary/Secondary/Disabled,
selection, success/warning/error). Typography: `'Segoe UI'` body,
`'Consolas'` monospace for diagnostic/status text. Confirmed these are
already used consistently in the rest of `oep_studio` (dock panels,
tab strips elsewhere) but were **not** applied to the Web Surface host
chrome or the Legacy V2 embed's toolbar/status bar, which used raw
hex/`Colors.*` values instead.

### 21.2 Web Surface host changes

`web_surfaces_host_page.dart`: toolbar, `_TabStrip`, `_TabChip`, and
`_NativeOepPanel` now use `StudioColors` throughout (surfaceRaised/
surface/border/selection/textPrimary/textSecondary/textDisabled/
success). Active tab now gets a `selection`-colored bottom indicator
(matching the convention already used elsewhere, e.g.
`dock_region.dart`) plus bold text, not just a background fill.

`legacy_v2_webview.dart`: removed the nested `Scaffold`/`AppBar` (it
was double chrome — this widget is embedded inside
`WebSurfacesHostPage`'s `IndexedStack`, which itself has no
`Scaffold`). Replaced with a themed toolbar `Container` carrying the
same four actions (Undo, Fit View, Reload, Save As…), and restyled the
bottom bridge-diagnostic status bar with `StudioColors` instead of raw
hex.

### 21.3 Color changes

See 21.2 — every hardcoded `Color(0xFF...)`/`Colors.*` value in the
Web Surface host and Legacy V2 embed's own chrome (not the V2 canvas
itself, which is untouched HTML/JS) replaced with `StudioColors`
tokens.

### 21.4 Typography changes

Tab labels and the host toolbar title now use the theme's implicit
`'Segoe UI'` (via ambient `Theme`/default `TextStyle` inheritance) with
explicit weight distinction (active tab bold, inactive regular).
Diagnostic/status text (bridge state, error text) kept `'Consolas'`
monospace, matching the existing convention for this class of content
elsewhere in the app (`StudioTheme.monoTextStyle`). V2's own internal
HTML typography was not touched.

### 21.5 Panel/sidebar changes

None — V2's own sidebar/canvas layout is untouched, per the task's
explicit instruction not to recreate it in Flutter or duplicate it.

### 21.6 Tab-system changes

Restyled only (colors/indicator/typography, per 21.2). No change to
`IndexedStack` lifetime behavior, `WebSurfaceTabsController`, or the
deliberate non-merge with `DiagramTabsController` — all confirmed
unchanged.

### 21.7 Migration UI removed

- `web_surfaces_host_page.dart`: "Open Local Test App" button and its
  handler (`_openLocalTestApp`) — a POC-only entry point from
  AP-STUDIO-WEB-SURFACE-001 with no production purpose.
- `local_file_resolver.dart` — deleted; it existed solely to support
  the removed dev button and had zero other callers (confirmed via
  grep across `lib/` and `test/`).
- `legacy_v2_webview.dart`: "(dev only)" removed from the (now-toolbar,
  formerly AppBar) title text.
- `legacy_v2_state_adapter.dart:816`: fixed a stale user-facing error
  message referring to "the classic renderer's Save As" (the classic/
  native renderer was retired in BRIDGE-010) — now points at the real
  "Save As…" toolbar button.

### 21.8 Files created

None.

### 21.9 Files modified

`web_surfaces_host_page.dart`, `legacy_v2_webview.dart`,
`legacy_v2_state_adapter.dart` (one stale string), this migration plan
doc.

### 21.10 Files deleted

`platform/oep_studio/lib/web_surface/local_file_resolver.dart`.

### 21.11 Tests added

None net-new (this was a styling/cleanup pass with no new host-level
behavior) — existing `web_surface/` and `diagram_studio/webview/`
suites re-run to confirm no regression, per Phase 11.

### 21.12 Full test result

`flutter test` (entire `oep_studio` suite) — **768/768 passed** (2
pre-existing skips), both scoped (`test/web_surface`,
`test/diagram_studio/webview`, `test/app/oep_boot_app_test.dart` — 49
tests) and full-suite runs.

### 21.13 flutter analyze result

7 issues, all pre-existing and unrelated to this task's files
(`studio_app.dart` unnecessary import, 2 curly-brace style notes in
`foundation_runtime_service.dart`, 4 doc/print notes in
`tools/hot_reload_client.dart`). Zero issues in any file touched this
task.

### 21.14 Windows build result

`flutter build windows --debug` succeeded —
`build\windows\x64\runner\Debug\oep_studio.exe`.

### 21.15 Runtime startup result

Built `oep_studio.exe` launched via `Start-Process`, confirmed still
running (no immediate crash/exception) 6 seconds later, then stopped
cleanly.

### 21.16 Legacy V2 / Engine / Foundation integrity

Zero V2 source files modified. Zero Engine (`platform/oep_engine`)
files modified. Zero Foundation files modified. All changes confined to
`platform/oep_studio` presentation-layer files.

### 21.17 Functional behavior preserved

All V2 workflows (module/wire CRUD, notes, terminal metadata, save/
save as, persistence, undo, simulation/multimeter, edit/wire/route
modes, sidebar) untouched — confirmed by the full, unmodified test
suite passing at the same 768/768 count as the BRIDGE-011 baseline.

### 21.18 Remaining visual inconsistencies

The "Open Web URL" dialog (`AlertDialog` in `web_surfaces_host_page.dart`)
still relies on ambient Material dark-theme defaults rather than
explicit `StudioColors` styling — no shared dialog theme/wrapper exists
anywhere in the app yet (confirmed during the Phase 1 audit), so this
is consistent with the rest of the app's current (unstyled) dialogs,
not a new gap introduced here.

### 21.19 Recommended next phase

Establish a shared dialog theme/wrapper (`StudioTheme` currently has no
`dialogTheme`) so `AlertDialog`s across the app — including the "Open
Web URL" prompt — pick up `StudioColors` automatically instead of each
call site hand-rolling it.
