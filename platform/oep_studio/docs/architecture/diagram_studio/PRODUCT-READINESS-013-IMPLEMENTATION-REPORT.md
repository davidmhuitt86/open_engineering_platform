# PRODUCT-READINESS-013 — OEP Application Shell / Home Dashboard

## 1. Baseline commit

`fd7f77e353b85af946986fb81fcd1999b9b4b9f5` ("new oep ux/ui") is `main`'s current tip and this pass's baseline — the same commit noted at the start of this task. Every change described below is an uncommitted working-tree change on top of it; nothing has been committed or pushed.

## 2. Objective

Before this pass, `oep_studio` booted into a completely empty Workspace ("No tabs open — press '+' to open a Surface") until a user manually opened something. That is not acceptable finished-product behavior for an application meant to look and feel like a real, OEP-branded product. This pass adds a real Home/Dashboard landing surface that the Workspace boots to by default, built entirely from the existing `WorkspaceTabsController` / `SurfaceRegistry` / `StudioRegistry` architecture — no new tab authority, router, or registry was introduced.

## 3. Architecture changes

None of the three architectural boundaries (Engine owns engineering behavior, Studio owns presentation, the new Application Shell layer owns global OEP identity/Home/status presentation) were altered structurally. Home is implemented as one more `SurfaceDefinition`, opened and closed through the exact same `WorkspaceTabsController` API every other Surface already uses (`openSurface`, `close`, `activate`). No `HomeTabsController`, no alternate router, no alternate registry — the explicit constraints from the driving spec were followed literally.

## 4. Home surface implementation

`lib/workspace/home/home_dashboard_page.dart` (new file) — `HomeDashboardPage`, a `ConsumerWidget` with four cards:

- **Continue Work** — the single most-recent entry from `WorkspaceManager.instance.recentWorkspaces` (a real, already-persisted, capped-at-5 list of document paths — never fabricated). Tapping it calls `EngineeringProjectServiceNotifier.openDocument(path)` then `openDiagramTab(tabsController)` — the exact same real entry points a menu action would use. An "Open Existing Work" button (shown when `recentWorkspaces` is empty) uses `package:file_selector`'s `openFile()` to pick a real path, then the same open path.
- **Recent Work** — whatever else remains in `recentWorkspaces` (indices 1+), same real data source, same open path.
- **Available Studios** — every entry in `SurfaceRegistry.all` (the same list the Workspace's own "+" menu already renders from) plus one hardcoded Diagram Studio tile (Diagram is deliberately excluded from `SurfaceRegistry.all` itself, see that registry's own doc comment, so it is added here the same way the "+" menu adds it). Never a hand-maintained second list, never a target that isn't actually registered. Home's own tile is excluded from this list (see §12).
- **System Status** — five rows, each reading a real, already-existing provider/getter; see §8 for the full per-row accounting.

## 5. Application-shell changes

No new "application shell" widget/layer was introduced beyond the Home surface itself — `StudioShell`, `EngineeringWorkspacePage`, and the Diagram Studio's own header (`OepStudioHeader`) are unchanged in structure. Home is presented exactly like any other Workspace tab: same tab chip, same close affordance, same content area. No global chrome was added around it.

## 6. Startup lifecycle changes

`WorkspaceTabsController` gained one new private method, `_ensureHomeIfEmpty()`:

```dart
void _ensureHomeIfEmpty() {
  if (_tabs.isNotEmpty) return;
  final home = WorkspaceTab(id: 'workspace-tab-${SurfaceRegistry.homeSurfaceId}', surfaceId: SurfaceRegistry.homeSurfaceId);
  _tabs.add(home);
  _activeId = home.id;
}
```

It is called from two places, both pre-existing methods, unchanged otherwise:
- The end of `restore()` — after persisted tabs are loaded/validated, if the effective tab list is still empty (fresh install, or every persisted tab was invalid/stale), Home is opened as the default landing tab.
- The end of `close(id)` — if closing a tab leaves zero tabs open, Home reopens immediately, synchronously, in the same operation.

This is a strict addition: every existing open/activate/close/split/persistence code path is untouched.

## 7. Home tab closing policy — decision

The driving spec offered two options: make Home non-closeable, or have it automatically reopen when the Workspace would otherwise become empty. **This pass implements the second option.** Home's tab chip has the same close (×) affordance every other tab has — nothing special-cases it in the rendering layer — but closing it when it is the last tab immediately reopens it (via `_ensureHomeIfEmpty` inside `close()`), so the Workspace is never left with zero tabs. This was chosen over "non-closeable" because it required no new tab-chip special-casing (no `isCloseable` flag, no exception in `_TabChip`) — it falls entirely out of the one small addition in §6, consistent with the spec's own preference for minimal new mechanism.

## 8. System status — per-subsystem accounting (real vs. not available)

| Row | Source | Real? |
|---|---|---|
| Engineering Engine | `foundationRuntimeServiceProvider` → `FoundationServiceState.phase`/`isConnected` | Real — existing connection-phase state machine |
| Repository | `foundationRuntimeServiceProvider` → `isRepositoryOpen` | Real |
| Knowledge Package | `electricalCoreRuntimeProvider` (`FutureProvider<KnowledgeRuntime>`) via `AsyncValue.when` | Real — reflects actual load/error state |
| Engineering Exchange | `exchangeRuntimeServiceProvider` → `connectionStatus`/`isConnected` | Real |
| Instrument Bridge | `instrumentBridgeServiceProvider` → `isRunning`/`port` | Real, but coarse — this is "is the local OIP host server running," not "is a client connected"; no such signal exists today, so this row does not claim more than the server's own running state |
| Workspace | `tabsController.tabs.length` + `WorkspaceManager.instance.hasUnsavedChanges` | Real |

No fake health check was added anywhere. No polling infrastructure was added — every row is a `ref.watch` on a provider that already updates itself via its own existing mechanism (Riverpod rebuild on state change), the same as every other consumer of these providers.

## 9. Recent Work / Continue Work — persistence findings

`WorkspaceManager.instance.recentWorkspaces` was already real, persisted, and capped at 5 entries before this pass — it was not created for this feature, only read from. `WorkspaceTabsStorage`'s `workspace_tabs.json` persistence (also pre-existing) is separate from this and was not touched beyond the new Home tab record it now also persists when Home is the active/open tab, through the exact same save path every other tab record already goes through.

## 10. Files changed

**New:**
- `lib/workspace/home/home_dashboard_page.dart`

**Modified (PR-013):**
- `lib/core/surfaces/surface_registry.dart` — registers Home (`homeSurfaceId`), inserted first in `SurfaceRegistry.all`.
- `lib/workspace/workspace_tabs_controller.dart` — `_ensureHomeIfEmpty()`, called from `close()` and `restore()`.
- `lib/workspace/engineering_workspace_page.dart` — doc-comment correction (see §14).
- `test/core/surfaces/surface_registry_test.dart`, `test/widget_test.dart`, `test/shared/navigation/unified_navigation_workspace_test.dart`, `test/workbench/perspectives/engineering_instruments_surface_migration_test.dart`, `test/workspace/engineering_workspace_page_test.dart`, `test/workspace/workspace_tabs_controller_test.dart`, `test/workspace/workspace_tabs_persistence_test.dart` — updated for Home-boot behavior (§13).

**Carried over, uncommitted from the prior (PR-012) phase, not touched further in this pass:** `lib/diagram_studio/compare/diagram_with_compare_pane.dart`, `lib/diagram_studio/header/oep_studio_header.dart`, `lib/diagram_studio/webview/legacy_v2_webview.dart`, `lib/web_surface/web_surfaces_host_page.dart`, `docs/architecture/diagram_studio/PRODUCT-READINESS-011-IMPLEMENTATION-REPORT.md`, `docs/architecture/diagram_studio/PRODUCT-READINESS-012-IMPLEMENTATION-REPORT.md` (new), `docs/architecture/diagram_studio/OEP-STUDIO-BRANDING-V1.md` (new), `reference/legacy_wiring_sim_v2/eke-wiring-sim/{index.html,js/editor/module-editor.js,js/ui/toolbar.js}`.

## 11. Available Studios — Home self-reference fix

During verification, the Available Studios card was found to include a "Home" tile (derived from `SurfaceRegistry.all`, which includes Home itself) — a tile that, since this card only ever renders while Home is the open/active tab, would always link back to the page already on screen. Fixed by excluding `SurfaceRegistry.homeSurfaceId` from that card's tile list specifically (not from `SurfaceRegistry.all` itself, which the "+" menu still needs Home in, so a closed Home tab can be reopened from there).

## 12. Tests

- `oep_studio`: **1138/1138 passing** in the full suite (confirmed with two independent full runs after all fixes), aside from one already-disclosed, pre-existing flake (`diagram_studio/bridge/diagram_repository_commit_action_test.dart`, "11/persistence... full continuity") — confirmed to pass every time it was run in isolation; its full-suite-ordering-dependent failure predates this pass and is unrelated to it.
- `oep_engine`: 530/530, unchanged.
- `oep_instruments` runtime: 51/51, unchanged.
- Legacy V2 JS (`node --test`): 27/27, unchanged.

**Tests updated for the new Home-boot behavior**, each verified individually and in the full suite:
- `surface_registry_test.dart` — Home, like Browser, is exempted from the "every Surface has a matching `StudioDestination`" invariant (a real, intentional exception, same shape as the pre-existing Browser one).
- `widget_test.dart` — the boot test now asserts the app lands on Home (checking for its real, uppercased card titles — `_Card` renders `title.toUpperCase()`) instead of the old empty-state text.
- `unified_navigation_workspace_test.dart` — four assertions were changed from asserting exact tab counts/emptiness to asserting only on the presence/absence of the Diagram tab specifically. This was necessary, not cosmetic: `WorkspaceTabsController.restore()`'s real, unmocked `dart:io` file load resolves at a genuinely nondeterministic point relative to these widget tests' `pump()`/`pumpAndSettle()` calls, so whether Home has auto-opened by any given assertion point is a real race this suite does not control. Re-run three times consecutively in isolation with no failures after the fix.
- `engineering_instruments_surface_migration_test.dart` — one tab-count assertion updated from 2 to 3 to account for Home; stable across three consecutive isolated runs (this test's specific call ordering happens to make the restore()-timing race consistently resolve one way, unlike the file above).
- `engineering_workspace_page_test.dart` — the "closing the only open tab" test was rewritten to expect Home to reopen instead of the old empty state; one new test added for closing Home when it is the only tab. Investigated directly (not assumed) via a throwaway probe test that printed the actual widget tree, which found the real cause of two false-start failures: (a) this file's harness never lets `restore()`'s real file-I/O resolve within its plain `pump()`/`pumpAndSettle()` calls, so Home is never auto-opened by restoration here, only by `close()`'s own synchronous call; (b) card titles render uppercased (`_Card.title.toUpperCase()`), so an assertion for `'Continue Work'` (mixed case) legitimately finds nothing.
- `workspace_tabs_controller_test.dart` — "closing the last remaining tab leaves no active tab" (a test whose own name directly described the behavior this pass intentionally supersedes) rewritten to assert Home reopens; one new test added for closing Home itself.
- `workspace_tabs_persistence_test.dart` — two tests ("empty storage produces empty/default state," "all-invalid persisted state produces a valid empty/default Workspace") updated to expect Home instead of a genuinely empty controller — these are real `await controller.restore()` unit tests (not widget tests), so they deterministically observe the post-restore state and were not previously exposed to the timing race above; they simply asserted the literal old behavior.

## 13. Static analysis

- `oep_engine`: **No issues found.**
- `oep_instruments` runtime: **No issues found.**
- `oep_studio`: **9 pre-existing issues**, unchanged from before this pass (unnecessary import in `studio_app.dart`; 3 `curly_braces_in_flow_control_structures` info-level lints predating this work; 1 unused-import warning in an unrelated test file, confirmed via `git log`/`git diff` to predate this pass; 2 doc-comment HTML-escaping infos and 2 `avoid_print` infos in `tools/hot_reload_client.dart`, a dev tool). **No new issues introduced** — `home_dashboard_page.dart` itself analyzes with zero issues.

## 14. Doc-comment correction

`engineering_workspace_page.dart` had a stale doc comment claiming "no tab persistence (explicitly out of scope...)" — false; `WorkspaceTabsStorage` has provided real persistence (`workspace_tabs.json`) since AP-OEP-WORKSPACE-PERSISTENCE-001, predating this pass. Replaced with an accurate comment describing the real persistence mechanism and the new Home-boot behavior.

## 15. Windows build result

`flutter build windows --debug` — **succeeded.** `Built build\windows\x64\runner\Debug\oep_studio.exe` (42.4s).

## 16. Android build result

`flutter build apk --debug` — **succeeded.** `Built build\app\outputs\flutter-apk\app-debug.apk` (Gradle `assembleDebug`, 36.4s).

## 17. Windows E2E result

Actually re-run this pass (unlike PR-012, which did not re-run it) against the real `oep_studio.exe`, twice, using genuine `SendInput` Win32 injection per the existing `integration_test/trx300_windows_e2e_test.dart` harness. Both runs produced the identical result: the app launched, a real top-level HWND was found and brought to the foreground, `context.go(StudioDestination.diagram.path)` navigated to the standalone legacy Diagram route — then the test timed out after 10s waiting for a "Load Previous Diagram" button that never appeared.

This is **not a PR-013 regression**: `StudioDestination.diagram`'s route builds `WebSurfacesHostPage` directly (`studio_shell.dart`), a code path that does not read `workspaceTabsControllerProvider` at all (confirmed by direct source inspection — no reference to that provider exists in `app_router.dart` or the relevant `studio_shell.dart` branch), so nothing this pass touched can affect it. This matches direct confirmation during this pass that the "Load Previous Diagram" button is a pre-existing, already-broken affordance, unrelated to Home/Workspace work. PR-011's own honest conclusion stands: infrastructure and per-click OS-level `SendInput` delivery are proven (window discovery, foreground, navigation all succeeded both runs); the full chained acceptance workflow remains not fully provable past this specific button, for reasons outside this pass's scope.

## 18. Known limitations

- The Instrument Bridge status row reports "is the local host server running," not "is a client actually connected" — no such per-client signal exists in the current architecture, and none was fabricated to fill the row.
- "Recent Work" and "Continue Work" only ever show what `WorkspaceManager` has actually persisted; a fresh install or one with no prior saved documents correctly shows "No recent work" rather than a placeholder document.

## 19. Bounded gaps

- Windows E2E's "Load Previous Diagram" step remains non-functional, per §17 — pre-existing, outside this pass's scope, and structurally unrelated to any file this pass touched.
- `diagram_studio/bridge/diagram_repository_commit_action_test.dart`'s full-suite-ordering flake (§12) remains undiagnosed, per its prior disposition in an earlier phase of this engagement.

## 20. Final status

**Home/Dashboard boot behavior is implemented, verified, and working** per every requirement in the driving spec: real persisted data only, no fabricated health checks, no new tab/registry/router authority, Home coexists with Studio tabs, and the Workspace never falls back to the old empty state during normal operation. All four Dart/JS test suites are green apart from one already-disclosed, isolation-confirmed pre-existing flake. Static analysis is clean of new issues on all three packages. Both Windows and Android debug builds succeed. Windows E2E was actually re-run (not skipped) and honestly found to still fail at a pre-existing, structurally unrelated step — not claimed as passing, and not silently skipped.
