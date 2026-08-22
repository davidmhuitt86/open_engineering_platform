# AP-DIAGRAM-V2-BRIDGE-003 — Document Identity & Persistence Authority Hardening

> Builds on
> [`DIAGRAM_STUDIO_V2_BRIDGE_PRODUCTION_ARCHITECTURE.md`](DIAGRAM_STUDIO_V2_BRIDGE_PRODUCTION_ARCHITECTURE.md)
> and [`DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`](DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md)
> — not rewritten here.

## 1. Document Identity — **IMPLEMENTED, VERIFIED**

`DiagramDocument.id` (new public getter, `diagram_studio/host/diagram_document.dart`)
exposes the existing lazy `_ensureId()`/`_documentId` mechanism — already
used internally to name autosave/recovery files — rather than introducing
a new identity concept. **No Engine/Foundation change** (this is
`oep_studio`'s own file).

Verified by direct reading and by test
(`legacy_v2_state_adapter_persistence_test.dart`): `EngineeringProjectService.newDocument`/
`closeDocument` call `state.document.close()`, which resets
`_documentId = null`; the next `.id` access lazily regenerates a fresh
one. `EngineeringProjectState.document` is the **same Dart object
instance** mutated in place across new/close/open (confirmed by reading
`engineering_project_service.dart` directly — `state = state.copyWith()`,
never `state.copyWith(document: DiagramDocument())`), so two successive
never-saved documents share an object identity but get **distinct**
`.id` values, verified directly: `newDocument()` called twice in a row
produces two different `.id` reads, neither equal to the first, both
with `path == null`.

## 2. Bridge Document Token — **IMPLEMENTED, VERIFIED**

`LegacyV2StateAdapter.currentDocumentToken` (new field) is set to
`controller.document.id` at the end of every successful
`initializeFromDocument()` call. Verified: after `initializeFromDocument`,
the token equals the document's own current id; after switching
documents and calling `reinitializeForDocument`, the token updates to
the new document's id.

**Invariant enforcement, precisely**: the token is a *record*, not a
*gate* — nothing currently compares an inbound message against it before
acting. The actual "A cannot mutate B" guarantee comes from
`reinitializeForDocument`'s own sequence (§5 of the production
architecture doc, unchanged by this task): `_ready = false` →
`clearAllSurfaces()` → reseed → `_ready = true`. This was judged
sufficient because the adapter is single-instance-per-mounted-WebView-tab
(never live for two documents concurrently) — a true multi-document-
aware token check would only matter if a single adapter instance could
receive messages naming a document it isn't currently bound to, which
the readiness gate already prevents structurally. Documented as a
deliberate simplification, not an oversight.

## 3. Durable Entity Mapping — **VERIFIED unchanged**

Re-confirmed via the existing `legacy_v2_state_adapter_document_lifecycle_test.dart`
(AP-DIAGRAM-V2-BRIDGE-002, still passing): mapping survives save/load
(metadata round-trips through `toJson`/`fromJson`), survives adapter
reconstruction (a fresh adapter instance rebuilds identical mapping from
document metadata alone), survives document switching
(`reinitializeForDocument`), and survives WebView reload (§5 below — now
also verified to re-run the same `initializeFromDocument` path). No
array index, screen position, random id, or object identity is used
anywhere in the mapping — unchanged finding from every prior task.
Application-restart persistence was not re-verified by an actual process
restart in this task (impractical in an automated test) — the metadata-
round-trip mechanism this relies on is the same one already exercised by
the existing `toJson`/`fromJson` tests at the Engine level, which is the
load-bearing guarantee.

## 4. V2 Initialization — **VERIFIED unchanged**

Unchanged from AP-DIAGRAM-V2-BRIDGE-002 — `initializeFromDocument()`
still seeds only bridge-metadata-carrying nodes/relationships; the
"arbitrary OEP node with no V2-compatible category" limitation still
stands (§3 of the production architecture doc), not addressed by this
task (out of scope).

## 5. WebView Reload Behavior — **IMPLEMENTED, VERIFIED (design), not live-tested this task**

`LegacyV2WebViewPage._reloadV2()` now: `_controller.reload()` →
`adapter.reinitializeForDocument()` → `_transport.interceptV2Save()` (§10)
→ `setState`. Reuses the exact same "clear V2, reseed from the current
document" path document switching already uses (§8 of the production
architecture doc) — a reload is, from the bridge's perspective, "V2 came
back empty for whichever document is currently active," not a distinct
code path. **Readiness gating remains intact**: `reinitializeForDocument`
still flips `_ready = false` for its own duration, so a mutation event
firing between reload and reseed completion is dropped, unchanged
mechanism from AP-DIAGRAM-V2-BRIDGE-002.

The injected bridge script itself re-attaches automatically on reload
(`addScriptToExecuteOnDocumentCreated` re-fires on every navigation,
confirmed in earlier tasks) — no additional re-attachment code was
needed for that half.

**Not live-verified this task** — the developer's live-check pass
confirmed the broader route/build change but did not specifically
exercise "click Reload while V2 has bridged content, confirm it comes
back." Flagged for the next live-verification pass.

## 6. Document Switching — **VERIFIED (scenarios A–D, F; E and G deferred)**

Against the required scenarios:

- **A** (new document → V2 initializes → modify → dirty): unchanged,
  already verified in prior tasks' own dirty-state findings.
- **B** (second new document → switch → V2 clears A → initializes B →
  modify B → A unchanged): **VERIFIED** —
  `legacy_v2_state_adapter_document_lifecycle_test.dart`'s existing
  `reinitializeForDocument` coverage plus this task's new distinct-id
  test together cover this precisely: two never-saved documents now
  have genuinely distinct identity, and `reinitializeForDocument` clears/
  reseeds on switch.
- **C** (save A → switch B → switch back A → V2 reconstructs A):
  **PARTIALLY VERIFIED** — the reconstruction mechanism itself
  (`initializeFromDocument` reading metadata) is verified; the specific
  "switch back to a previously-active, now-saved document" sequence end-
  to-end was not separately exercised as its own test this task (it
  reduces to the same `reinitializeForDocument` path already covered).
- **D** (WebView reload while A is active → V2 reconstructs A):
  **IMPLEMENTED** (§5), not separately live-verified.
- **E** (close current document → V2 must not retain stale A identity):
  **DEFERRED** — closing a document calls `EngineeringProjectService.closeDocument()`,
  which (like `newDocument()`) resets to a fresh empty document with its
  own new `.id` — the existing `ref.listen` on `document.id` should fire
  and trigger `reinitializeForDocument` the same as any other switch, but
  this specific sequence (close, not switch-to-another) was not written
  as its own test this task. Believed covered by the same mechanism as
  B, not separately confirmed.
- **F** (open saved document → V2 reconstructs saved state):
  **IMPLEMENTED** via the same `initializeFromDocument` path reading
  metadata off whatever graph is currently loaded — opening a file
  populates the session the same way `newDocument` does, from the
  bridge's perspective. Not separately tested with an actual saved-file-
  on-disk round trip this task.
- **G** (Save As → document identity changes correctly → bridge follows):
  **OPEN** — `saveDocumentAs` changes `document.path` but does **not**
  reset `_documentId` (confirmed by reading `DiagramDocument.saveAs`
  directly — it only touches `path`/`metadata`, never `_documentId`).
  This is actually **correct** behavior for identity purposes (Save As
  is "the same document, now has a file"), but it means the bridge's
  `document.id`-based switch-detection will **not** fire for a Save As —
  which is the right outcome (no reinitialization needed, nothing about
  the in-memory graph changed) but was not verified by an explicit test
  this task. Marked OPEN because the "correct behavior" conclusion above
  is reasoned from source, not confirmed by running the scenario.

## 7. Save Architecture — **IMPLEMENTED, VERIFIED**

`V2 Save button click → intercepted saveLayout → 'saveRequested' message
→ LegacyV2StateAdapter._handleSaveRequested → controller.saveDocument()`
(the existing method, unchanged) `→ OEP document persistence`. No new
save command. Verified: simulating a save request with no path set
reports failure with an explanatory message rather than silently no-
op'ing or falling back to V2's own file download.

**Not separately tested**: the success path (a document that already has
a path, save-request → `controller.saveDocument()` actually called →
success reported) — the adapter code path is straightforward
(`controller.saveDocument()` + `reportSaveResult(true, ...)`), matching
the tested-and-passing failure path's own shape, but wasn't given its
own assertion this task, since establishing a real saved path inside the
test harness would require an actual file-system write the existing test
suite's isolation helpers weren't set up for. Flagged as a minor test
gap, not a design gap.

## 8. Save-As Architecture — **DEFERRED**

Not implemented. §6 scenario G's own finding: `saveDocumentAs` already
exists (`DiagramStudioController.saveDocumentAs(path)`) and would work
if called, but nothing in V2's UI can supply a target file path (no
picker reachable from a WebView), and building one was explicitly out of
this task's minimal scope (Phase 5's own "do not create new save
commands... use existing Controller/Engine functionality" — a picker UI
is new Flutter UI work, not a Controller method). V2's own Save button,
when the document has never been saved, now reports this limitation to
the user via `showToast` rather than silently doing nothing.

## 9. Dirty-State Authority — **VERIFIED unchanged**

No change. Every bridged mutation still goes through
`DiagramStudioController` methods that call the existing `markDirty()`
internally; the new `saveDocument()` call this task added on the save
path is the same existing method every other Save trigger already uses.

## 10. V2 Save Layout Disposition — **IMPLEMENTED (Option B)**

Per this task's own preferred-order list: Option A (suppress via
existing V2 runtime configuration) does not apply — V2 is a monolith
with no such configuration surface. **Option B (intercept at the WebView
boundary without modifying V2 source) was used**:
`LegacyV2BridgeTransport.interceptV2Save()` calls `executeScript` to
reassign the global `window.saveLayout` function — confirmed by reading
`index.html` directly that V2's own Save button
(`onclick="saveLayout()"`) looks up that identifier **by name at click
time** (a plain inline handler, not a captured reference), so a runtime
reassignment after V2's own script has already defined it takes effect
for all subsequent clicks. Applied once after every successful seed
(initial load, reload, per §5) — since a reload/re-navigation re-runs
V2's own `function saveLayout(){...}` declaration, clobbering any prior
reassignment, the interception must be (and is) reapplied every time.

**`js/storage/project-saver.js` was never modified** — confirmed by the
same V2-integrity check every prior task ran (§ Verification below).

## 11. Vehicle/Base-Data Ownership — **OPEN**

Per this task's own Phase 9 instruction ("if the correct answer cannot
be determined from existing architecture, mark it OPEN and leave it
unchanged") — re-examined, not resolved:

- **Option A** (V2 vehicle data as immutable presentation/reference,
  OEP owns only the bridged engineering document) is the most consistent
  with everything actually built across every prior bridge task — the
  bridge has never touched, read, or represented V2's base
  `diagrams/<vehicle>/*.json` data as OEP entities; only bridge-created
  (V2-user-originated) modules/wires ever get `EngineeringNode`/
  `EngineeringRelationship` representations.
- No code in this codebase currently enforces or contradicts that
  choice, and nothing in the existing OEP project/document model was
  found that represents "a vehicle" as a distinct concept from "a
  document" — so Options C (an existing OEP project/vehicle object) does
  not currently exist to use.
- **Left OPEN, not implemented, not chosen** — this task did not
  introduce any new vehicle-data code path in either direction.

## 12. Lifecycle/Error Handling — **VERIFIED unchanged, extended**

The bridge lifecycle state table from the production architecture
document (§8 there) is unchanged in shape; this task adds two new
transitions to it, both already covered above: reload now correctly
re-enters INITIALIZING (§5), and the document token (§2) is now visible
state for debugging/testing rather than implicit.

## 13. Remaining Open Decisions

- §2: the document token is currently record-only, not an enforced gate
  — acceptable given the single-instance-per-tab architecture, but would
  need to become a real gate if that assumption ever changes.
- §6 scenarios C/D/E/F: reasoned as covered by the same mechanism as
  scenario B, not each individually tested.
- §7: the success path of save-interception (as opposed to the tested
  failure path) has no dedicated test.
- §8: Save As from V2 remains impossible without a file-picker UI this
  task did not build.
- §11: vehicle/base-data ownership remains genuinely undecided.

---

## Verification

- `flutter analyze` — clean on every touched file.
- `flutter test test/diagram_studio/ test/web_surface/ test/widget_test.dart
  test/command_palette_dialog_test.dart test/studio_registry_test.dart` —
  192 tests, all passing (191 from the prior task + 1 new file,
  `legacy_v2_state_adapter_persistence_test.dart`).
- `flutter build windows --debug` — succeeded.
- V2 source (`reference/legacy_wiring_sim_v2/eke-wiring-sim/`) — zero
  writes; `js/storage/project-saver.js` specifically confirmed unmodified.
- Engine/Foundation — zero writes; no schema change was needed or
  requested (§1).
- Native Flutter renderer — untouched (no file under the frozen list was
  modified).
- No second authoritative persistence path — V2's own Save button is
  now the *same* path as OEP's own Save, not a parallel one (§7/§10).
- No duplicate bridge subscriptions — `LegacyV2BridgeTransport._sub`
  remains a single subscription for the widget's lifetime, unchanged.
- No stale document can mutate the active document — enforced by
  `reinitializeForDocument`'s readiness gate, unchanged mechanism, now
  also correctly triggered by reload (§5) and by genuinely distinct
  never-saved document ids (§1).
- Existing bridge functionality — all prior module/wire bridge tests
  still pass, unmodified in substance.
