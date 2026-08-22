# AP-DIAGRAM-V2-BRIDGE-002 — Production Web Surface & Document/Identity Foundation

> Builds on
> [`DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`](DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md)
> (the audit this task's decision ratifies) and every prior bridge/Web
> Surface document — not rewritten here.

## 1. Production Web Surface Architecture

`Studio → Diagram Studio (/diagram) → Web Surface Host → Legacy V2`.
`core/routing/studio_registry.dart`'s `_diagramBuilder` now returns
`const WebSurfacesHostPage(autoOpenLegacyV2: true)` instead of
`EngineeringWorkbenchPage(...)` directly — the **same** `StudioDestination.diagram`
entry, not a second competing one (per this task's own explicit
constraint). Legacy V2 is listed first in `WebSurfacesHostPage`'s
initial tab list, so `WebSurfaceTabsController`'s "first surface added is
active" rule makes it the default view. A "Native OEP" tab is present
alongside it, unchanged from the POC.

**Temporary fallback**: the pre-existing native renderer
(`EngineeringWorkbenchPage`) is reachable at a new, deliberately
unlisted route, `StudioDestination.diagramClassic` (`/diagram-classic`)
— reachable only via a "Use Classic Renderer (fallback)" link inside the
Web Surface host itself, never from the primary Navigation Rail
(`workbench_sidebar.dart`'s `_otherStudioDestinations` explicitly
excludes it). `StudioShell`'s existing full-window carve-out (previously
keyed on `StudioDestination.diagram` alone) now also matches
`diagramClassic`, so the fallback renders with the same full-window
chrome the old `/diagram` route always had. **Removal condition**:
per `DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md` §15's exit criteria —
once bridge parity is reached, `diagramClassic`, its route, its link,
and the renderer it points at are all deleted together.

## 2. Document Authority

**No second document model was created.** The existing single shared
`EngineeringProjectService`/`EditingSession` (confirmed in the migration
plan's audit) remains the one authoritative document; V2 is purely a
presentation surface over it, reached through the same
`DiagramStudioController` every other bridge task already used
(`addNodeWithMetadata`/`moveNodes`/`deleteNode`/`renameNode`/
`createRelationship`/`updateRelationshipMetadata`, all unchanged).

## 3. V2 Initialization Protocol

`LegacyV2StateAdapter.initializeFromDocument()` (new):

```
Rebuild identity index from document metadata (§4)
    ↓
For each node with metadata['v2ModuleId']: channel.restoreModule(...)
    ↓
For each relationship with metadata['v2WireId'] whose BOTH endpoints
  have a known v2ModuleId: channel.restoreWire(...)
    ↓
_ready = true
```

Reuses `restoreModule`/adds `restoreWire` — the same injected-script
mechanism (`__oepBridgeRestoreModule`/new `__oepBridgeRestoreWire`) the
undo-of-delete path already established, not a new content-injection
protocol.

**What can already be initialized**: any node/relationship this bridge
itself created (i.e. anything carrying `v2ModuleId`/`v2WireId` metadata)
— position, label, category, wire endpoints, label, color.

**What remains unresolved (documented, not solved)**: an arbitrary OEP
node with no `v2ModuleId` (created via the native renderer, or from a
category with no deterministic V2 symbol) has **no deterministic V2
module shape to construct** — no category known to be V2-compatible in
the first place. Fabricating one would be exactly the kind of invented
mapping every prior bridge task refused. This is a real, permanent
limitation of "V2 can only show what V2-compatible data OEP actually
has," not a bug to fix later — unless/until OEP nodes generally carry a
V2-representable category, which is outside this task's scope.

## 4. Durable Identity Architecture

**No Engine/Foundation schema change — none was needed.** Verified
directly by reading `EngineeringNode.toJson`/`fromJson` and
`EngineeringRelationship.toJson`/`fromJson`: `metadata` already
round-trips fully, and already round-trips through
`DiagramDocument.save`/`open` (the existing document persistence
mechanism, untouched). The module bridge task already stashed
`v2ModuleId`/`v2Category` in node metadata; this task adds
`v2WireId`/`label`/`wireColor` to relationship metadata at wire-creation
time (`legacy_v2_state_adapter.dart`'s `_handleWireCreated`).

`_v2ToOepNodeId`/`_v2ToOepRelationshipId` (the in-memory `Map`s) are now
explicitly documented, and implemented, as a **rebuildable index over
that metadata**, not a second source of truth — `initializeFromDocument`
proves this by reconstructing them from scratch on every call, purely by
scanning the graph. A **new adapter instance with no prior in-memory
state at all** reconstructs the identical mapping from a document that
already has bridge metadata in it (verified in
`legacy_v2_state_adapter_document_lifecycle_test.dart`).

This satisfies all five of Phase 5's durability requirements: survives
restart (it's in the saved document), survives save/load (same
mechanism every other node/relationship field uses), not index/screen-
position/random-based (keyed by the same authored/session-stable V2 ids
every prior task already established), stable across V2↔OEP exchange
(re-derivable from either side's current state).

## 5. Document Switching Lifecycle

```
Document A active, V2 showing A's bridged content
    ↓
active document changes (engineeringProjectServiceProvider's
  document.path, watched reactively — the one genuinely reactive
  document-identity signal found in the existing code; DiagramStudioController
  itself never emits change notifications, by design, per its own doc
  comment)
    ↓
LegacyV2WebViewPage.build's ref.listen fires -> adapter.reinitializeForDocument()
    ↓
_ready = false (every inbound handler now drops messages)
    ↓
channel.clearAllSurfaces() -- V2's own MODULES/WIRES/positions/wireRoutes/
  cardEls emptied via the new __oepBridgeClearAll injected function
    ↓
initializeFromDocument() reseeds from whatever document is now active
    ↓
_ready = true
```

The readiness gate (§7) is what actually closes the race: a message V2
fires between "document changed" and "reseed finished" is dropped, not
queued and replayed against the wrong document.

**Known limitation, documented not solved**: the tracked identity signal
is `document.path`, which is `null` for a brand-new unsaved document —
switching between two different *never-saved* documents in the same
session is not distinguished by this signal and is not covered by the
current implementation. Flagged as **OPEN DECISION**.

## 6. Dirty-State Lifecycle

Unchanged, verified not touched: every bridged mutation already goes
through `DiagramStudioController` methods that call the existing
`markDirty()` internally. No bridge-specific dirty-state code exists
anywhere in this codebase, before or after this task. The Web Surface UI
does not currently render its own dirty/clean/saved/save-failure
indicator — that remains whatever the native document bar (still present
at `/diagram-classic`, and structurally still driving the same
`EngineeringProjectState`) already shows; adding an equivalent indicator
to the Web Surface host itself is **DEFERRED**, not attempted this task.

## 7. Save/Save-As Architecture

**Not implemented — classified, per Phase 10's own instruction, not
silently duplicated.** V2's own "Save Layout" button (`project-saver.js`)
remains fully present and functional (V2 is unmodified) and would write
a *separate*, partial file if used — a real, un-reconciled second save
path that this task does not disable (cannot, without touching V2
source) and does not hide. **OPEN DECISION**, carried forward from the
migration plan's §6: whether V2's own save UI should eventually be
suppressed/redirected via injected script (technically possible, not
attempted) once OEP's own Save/Save As become reachable from the Web
Surface host.

## 8. Bridge Lifecycle

No formal enum was introduced (Phase 11 explicitly allows this). States
are expressed through existing/new fields, checked in this order:

| Concept | Field | Meaning |
|---|---|---|
| UNINITIALIZED | `LegacyV2StateAdapter._ready == false` (initial) | adapter constructed, `initializeFromDocument` not yet run |
| INITIALIZING | `_ready == false` during `initializeFromDocument`/`reinitializeForDocument` | inbound messages dropped |
| READY | `_ready == true` | normal operation |
| REINITIALIZING | `_ready` flipped back to `false` inside `reinitializeForDocument` | same drop behavior as INITIALIZING |
| (trust) DISABLED | `LegacyV2BridgeTransport.bridgeEnabled == false` (AP-STUDIO-WEB-SURFACE-002) | orthogonal to readiness — V2 navigated outside its trusted directory |
| DISPOSED | `LegacyV2WebViewPage.dispose()` → `_transport.dispose()`/`_controller.dispose()` | unchanged from POC |
| ERROR | `LegacyV2WebViewPage._error != null` | WebView failed to initialize/load at all |

Races explicitly considered:

- **WebView loads before OEP document is ready**: not possible today —
  `DiagramStudioController.bootstrap` (unchanged) already runs once at
  app-session start, before any Web Surface tab can mount.
- **OEP document changes while V2 is loaded**: §5.
- **V2 sends a mutation during reinitialization**: dropped by `_ready`
  (§3/§5).
- **WebView reloads**: `_controller.url` listener and
  `LegacyV2BridgeTransport.attach()` are set up once in `initState`;
  a reload re-runs V2's own scripts (including the injected one, since
  `addScriptToExecuteOnDocumentCreated` re-fires on every navigation,
  confirmed in POC-002) but does **not** re-run `_init()` or
  re-subscribe the Dart-side listener — **no duplicate subscription is
  possible** because there is exactly one `StreamSubscription` for the
  lifetime of the widget (`LegacyV2BridgeTransport._sub`), confirmed by
  reading `attach()`. A reload does **not** currently re-trigger
  `initializeFromDocument` — V2 comes back empty until the user
  re-triggers a document switch or the tab is closed/reopened. Flagged
  as **DEFERRED**, not a correctness bug (nothing mutates against stale
  state — `_ready` stays whatever it was, and a fresh `MODULES`/`WIRES`
  with no bridge metadata simply produces "created" messages for
  already-mapped ids, which the existing dedup checks
  (`_v2ToOepNodeId.containsKey`) already no-op correctly).
- **WebView crashes/restarts**: not specifically handled; the existing
  `_error` state would surface a native failure, but a mid-session
  native crash recovery path was not investigated this task.
- **Document closes**: covered by §5 (path becomes null/changes).
- **Studio route changes**: `LegacyV2WebViewPage.dispose()` runs when the
  tab hosting it is closed (§ Phase 3's "closing a tab destroys its
  WebView," AP-STUDIO-WEB-SURFACE-001, unchanged) — navigating away from
  `/diagram` entirely while the tab strip is still mounted inside an
  `IndexedStack` does **not** dispose it (by design, state preservation).
- **Tab closes**: unchanged, disposes the WebView (AP-STUDIO-WEB-SURFACE-001 §4).

## 9. Web Surface Lifecycle

Unchanged from AP-STUDIO-WEB-SURFACE-001/002 (`IndexedStack`-based,
create/activate/close via `WebSurfaceTabsController`) — this task did not
modify `WebSurfaceView`, `WebSurfaceTabsController`, or the generic
Web Surface model beyond what §1 required in the host page itself.

## 10. Error/Reload Handling

Unchanged widget-level behavior (`_error`/loading spinner in
`LegacyV2WebViewPage`, `WebSurfaceView`'s own equivalents) — this task
added no new error UI. One real bug found and fixed during this task's
own verification: the Web Surface host's toolbar `Row` overflowed at
narrower window widths once the classic-renderer link was added (now
wrapped in a horizontally-scrollable `SingleChildScrollView`) — this was
also cascading into unrelated tests, since `/diagram` becoming the app's
default `initialLocation` (a pre-existing "temporary dev-only bypass,"
per that file's own comment) meant every test that merely launched the
app was hitting the overflow. Fixed by reverting `initialLocation` to
`StudioDestination.dashboard.path`, per that file's own standing
instruction to do so "before any real work."

## 11. Native Renderer — Temporary Status

**Confirmed untouched.** None of `GraphViewPanel`, `SymbolNodeWidget`,
`WirePainter`, `ConnectionPreviewPainter`, `V2CanvasHost`,
`V2ModuleCard`, `V2WirePainter`, `V2ConnectionPreviewPainter`, or any
native-renderer test file was modified. `EngineeringWorkbenchPage` itself
is byte-for-byte unchanged; only *which route* points at it changed
(§1). It remains reachable, fully functional, at `/diagram-classic`.

## 12. Remaining Bridge Dependencies

Everything the migration plan's §4 classified as ADAPTER REQUIRED or
ENGINE EXTENSION REQUIRED and not yet built: module/wire selection,
edit-mode gating, wire deletion/editing, wire routing strategy,
simulation/multimeter bridging, pan, continuous zoom sync, terminal/port
fidelity. This task added the document/identity foundation those depend
on; it did not implement any of them (explicitly out of scope, per this
task's own Phase 15 stop conditions on wire routing and simulation, and
the general "do not implement V2 wire routing" instruction).

## 13. Open Architectural Decisions

- §5: identity signal is `document.path`, which can't distinguish two
  different never-saved documents in the same session.
- §7: V2's own "Save Layout" remains a live, un-reconciled second save
  path — not disabled, not hidden.
- §8: WebView reload doesn't re-trigger `initializeFromDocument` — V2
  comes back empty until a document switch or tab close/reopen.
- §1: whether `diagramClassic`'s eventual removal also removes
  `StudioDestination.diagram`'s own capability/settings/search metadata
  wholesale, or whether those stay describing whatever "Diagram Studio"
  means once it's V2-only.
- Whether a dirty/save-state indicator belongs on the Web Surface host
  itself before `/diagram-classic` is removed (§6/§7).

---

## Verification

- `flutter analyze` — clean on every touched file.
- `flutter test test/diagram_studio/ test/web_surface/ test/widget_test.dart
  test/command_palette_dialog_test.dart test/studio_registry_test.dart` —
  191 tests, all passing (includes the new document/identity foundation
  test, `legacy_v2_state_adapter_document_lifecycle_test.dart`, and the
  fix for two real regressions this task's own route change caused,
  see §10).
- `flutter build windows --debug` — succeeded.
- V2 source: zero writes — `reference/legacy_wiring_sim_v2/eke-wiring-sim/`
  untouched.
- Engine/Foundation: zero writes — no schema change was needed (§4).
- Native renderer: zero writes (§11).
- No duplicate bridge subscriptions (§8).
- No second V2 persistence authority — V2's own save path exists but is
  explicitly classified, not silently duplicated against (§7).
- No second dirty-state authority (§6).
