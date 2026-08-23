# OEP Workspace Routing Architecture

**AP-OEP-WORKSPACE-ROUTING-001** — resolves the one remaining lifecycle
limitation documented by `AP-OEP-WORKSPACE-LIFECYCLE-001`: leaving
`/workspace` for another route and returning used to rebuild
`EngineeringWorkspacePage` from scratch. This document records the
audit, the compared options, the selected fix, and its verification.

## 1. Current routing topology

```
GoRouter (app_router.dart)
  initialLocation: /dashboard
  ShellRoute
    builder: (context, state, child) => StudioShell(
      selected: StudioDestination.fromPath(state.uri.path),
      onSelect: (d) => context.go(d.path),
      child: child,
    )
    routes: StudioRegistry.defaultRegistry.buildRoutes()
      — one GoRoute per StudioDestination (dashboard, knowledge,
        acquisition, repository, objects, relationships, search, graph,
        validation, packages, engineeringIntelligence, exchange,
        copilot, settings, workspace, diagram, diagram-classic, ...)
```

There is exactly one `ShellRoute`, one `StudioShell`, and one flat list
of sibling `GoRoute`s beneath it — no nested `Navigator`s, no branches.

## 2. Actual Workspace lifecycle (audited, not assumed)

Traced empirically via `studio_shell_workspace_persistence_test.dart`
(new, this package) and `workspace_lifecycle_test.dart` (from
`AP-OEP-WORKSPACE-LIFECYCLE-001`):

- **`StudioShell`'s own `State` survives every route change** within the
  `ShellRoute` (confirmed: `identical(shellStateBefore, shellStateAfterNav)`
  is `true`). This is `ShellRoute`'s documented purpose — it keeps its
  builder's returned widget mounted while only `child` changes.
- **Before this package**: `StudioShell.build()` rendered `widget.child`
  directly for every non-Diagram destination. Since GoRouter constructs a
  *new* `EngineeringWorkspacePage()` widget instance each time `/workspace`
  is (re)matched, and Flutter's own diffing removes/rebuilds a child slot
  when its position in the tree stops being occupied by anything (i.e.
  when `/workspace` isn't the matched route, nothing renders it at all),
  `EngineeringWorkspacePage`'s `Element`/`State` was destroyed the moment
  the route changed away, and a brand-new one was built on return.
- **The four traced scenarios** (`/workspace → another Studio →
  /workspace`, `→ /diagram →`, `→ settings →`, `→ an arbitrary route →`)
  all reduce to the same mechanism: any route change away from
  `/workspace` stops GoRouter from supplying an `EngineeringWorkspacePage`
  as `child` at all, so whatever previously held that page (before this
  fix: `widget.child` directly) loses it.
- **Diagram Studio already solved this same problem for itself** in
  `AP-OEP-DIAGRAM-UX-001`: `StudioShell` holds `_diagramStudioHost` (a
  `WebSurfacesHostPage`) in a `late final` field, and renders it inside
  an `Offstage` **unconditionally**, regardless of `widget.selected` —
  never through `widget.child`. That field, once built, never changes,
  so its `Element` survives every route change for the same reason
  `StudioShell` itself does.

## 3. Compared routing options

**A. Current plain `ShellRoute`, using `widget.child` for Workspace
(pre-fix state).** Recreates the Workspace subtree on every route
change away and back, because `widget.child` is GoRouter-supplied and
only exists while `/workspace` is the matched route. This is the
documented defect.

**B. `StatefulShellRoute` (go_router ^14.6.2, available in this
project's dependency).** Provides `IndexedStack`-style branch
preservation, but *only between sibling branches of the same
`StatefulShellRoute`* — every destination that should coexist under
this preservation must become a distinct branch with its own nested
`Navigator`. Since this app has 15+ flat sibling routes derived
dynamically from `StudioRegistry.buildRoutes()`, adopting
`StatefulShellRoute` would mean restructuring the entire route table,
introducing per-branch `Navigator`s, and changing how
`StudioDestination.fromPath`/`context.go`/cross-Surface navigation
resolve the "current" destination — a broad routing redesign, not a
localized fix. **Rejected** — exactly the kind of change Phase 4 says to
avoid ("If implementation would require a broader routing redesign,
STOP after the architecture report").

**C. Persistent Workspace host beneath the existing shell.** Since
`StudioShell` itself already survives route changes (§2), and already
proves the pattern for Diagram Studio (§2, `_diagramStudioHost`), the
same technique generalizes directly: hold `EngineeringWorkspacePage` in
a `late final` field on `_StudioShellState`, render it unconditionally
inside the existing content `Stack`, and toggle only its `Offstage`
visibility based on `widget.selected`. Zero changes to `app_router.dart`,
`ShellRoute`, `StudioRegistry`, `WorkspaceTabsController`, or
`SurfaceRegistry`. **Selected** — the smallest change that achieves the
goal, and reuses an already-proven, already-shipped mechanism rather
than inventing one.

**D. Any other existing OEP routing mechanism.** None found.
`WebSurfaceTabsController` is a separate, intentionally-scoped
controller for Diagram Studio's *own* internal Web Surface tabs
(`web_surface_tabs_controller.dart`) — unrelated to top-level routing,
not a candidate.

## 4. Persistence boundary

| State | Classification |
|---|---|
| Open Workspace tabs, active tab (`WorkspaceTabsController`) | **Already survives** — Riverpod-scoped, independent of any widget tree change; unaffected by this package |
| Scroll positions, filter text, expanded/collapsed sections, per-tab local widget state (per `AP-OEP-WORKSPACE-LIFECYCLE-001`'s own Surface audit) | **Must survive** across a route-away-and-back — was previously lost, now retained (fixed by this package) |
| Copilot conversation state (`_exchanges`, `_asking`, `_questionController`) | **Must survive** — same mechanism, now retained |
| Diagram WebView instance, zoom/pan/navigation state, V2 selection/edit mode | **Must survive** — same mechanism; the WebView plugin instance is never disposed by a route-away-and-back now, since `EngineeringWorkspacePage`'s own `IndexedStack` (holding the Diagram tab's `LegacyV2WebViewPage`) is itself never disposed |
| Provider-backed selections (Foundation/Acquisition/Exchange/Engine) | **Already survives** — always was, via app-wide Riverpod providers, independent of any widget lifecycle |
| Engine graph/document state | **Already survives** — same reasoning, `engineeringProjectServiceProvider`/`diagramStudioControllerProvider` are app-wide singletons |
| Anything not yet opened as a Workspace tab | **Should intentionally reset** — out of scope; no persistence to disk, no restoration of a *previous session's* tabs, only continuity of the *current* session's already-open tabs across route changes |

No disk persistence or serialization was introduced. The mechanism is
purely "don't destroy the live widget," not "save and restore state."

## 5. Selected architecture — exact implementation changes

**File modified**: `lib/app/studio_shell.dart` only.

1. New field on `_StudioShellState`, next to the existing
   `_diagramStudioHost`:
   ```dart
   late final Widget _workspaceHost = const EngineeringWorkspacePage();
   ```
   No `GlobalKey` is needed (unlike `_diagramStudioHost`): the Workspace
   host always renders at the *same* position in the *same* `Stack`,
   for every non-Diagram destination — it never relocates between
   structurally different `Scaffold` trees the way the Diagram
   carve-out does, so plain widget/field identity is enough for Flutter
   to keep its `Element`/`State` alive across rebuilds.

2. In the content `Stack` (previously `[diagramHostOffstage,
   widget.child]`), changed to:
   ```dart
   Offstage(offstage: widget.selected != StudioDestination.workspace, child: _workspaceHost),
   if (widget.selected != StudioDestination.workspace) widget.child,
   ```
   For every destination that isn't the Workspace, behavior is
   unchanged — `widget.child` (whatever GoRoute matched) still renders
   exactly as before. For the Workspace destination, GoRouter's own
   constructed `child` (a throwaway `EngineeringWorkspacePage()`
   instance from the route's own `pageBuilder`) is simply never
   inserted into the tree — mirroring exactly how the Diagram carve-out
   already discards `widget.child` in favor of its own persistent host.

No other file needed to change. `WorkspaceTabsController`,
`SurfaceRegistry`, `StudioRegistry`, `app_router.dart`, and the Diagram/
V2 bridge are untouched.

## 6. Test evidence

- `test/app/studio_shell_workspace_persistence_test.dart` (new) — a
  real two-route `GoRouter` + `ShellRoute` structurally identical to
  `app_router.dart`, proving:
  - Workspace mounts once at startup.
  - Leaving `/workspace` for Knowledge and returning keeps the *same*
    `EngineeringWorkspacePage` `Element` mounted (`identical(...)` true
    both while away — `Offstage`-hidden, found only with
    `skipOffstage: false` — and after returning).
  - The same `IndexedStack` instance (holding all open tab content) is
    never rebuilt.
  - Tabs, tab count, and active tab are unchanged across the round trip.
  - Closing a tab still correctly removes and disposes that tab's
    content, independent of the Workspace host itself staying mounted.
  - Sidebar-driven Workspace navigation still converges on the same
    `WorkspaceTabsController`.
  - Non-Workspace routes still render their real page directly and
    visibly, unaffected.
- `test/workspace/workspace_lifecycle_test.dart` (updated) — its
  pre-existing "Phase 8 finding" test is retained and repurposed: it
  now documents the underlying bare-Flutter mechanism this package's
  fix exploits (a route swap with no persistent host above it *does*
  still rebuild a widget), explaining *why* the fix had to live in
  `StudioShell` specifically rather than in `EngineeringWorkspacePage`
  itself.
- Full suite: 843 passed, 0 failed. `flutter analyze`: clean (7
  pre-existing, unrelated infos, unchanged). `flutter build windows
  --debug`: succeeded. Runtime: launched and ran stably.

One pre-existing test file, `studio_shell_workspace_sidebar_test.dart`
(from `AP-OEP-WORKSPACE-UX-001`), needed two adjustments as a direct
consequence of the fix now being real: it previously relied on the
Workspace's `child` being a throwaway `SizedBox.shrink()` that was never
actually the persistent host, so opening a real Surface (or the Diagram
tab) inside it now genuinely renders that Surface's content for the
first time in that file. It was updated to (a) use a realistic test
viewport (matching the pattern already used elsewhere in this suite)
and (b) use `pump()` rather than `pumpAndSettle()` after a tap, since
the Diagram tab's real `LegacyV2WebViewPage` now genuinely mounts and
its WebView2 initialization never resolves under `flutter test`'s
headless binding — the same pre-existing constraint `_isUnderTest`
already documents for `_diagramStudioHost`. No assertion in that file
was weakened; every one of them reads `WorkspaceTabsController` state
directly, not rendered pixels.

## 7. Remaining limitations

- Restoring a *previous application session's* open tabs (persistence
  to disk) remains explicitly out of scope, per this package's own
  instruction and every prior Workspace package's standing constraint.
- The Workspace host, being permanently mounted once created, means a
  Diagram tab opened during a test run that never gets closed will keep
  a `LegacyV2WebViewPage` alive for the rest of that test's lifetime —
  already true before this package (the Diagram tab was never disposed
  by *closing other tabs* either), just newly reachable from more test
  harnesses now that the host is unconditionally real. No test in this
  suite opens the Diagram tab and then asserts on its content, so this
  has no practical impact today.

## 8. Recommended next package

None proposed — stopping here per this package's explicit instruction.
