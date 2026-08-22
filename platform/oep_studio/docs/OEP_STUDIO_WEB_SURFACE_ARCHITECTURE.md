# AP-STUDIO-WEB-SURFACE-001/002 — OEP Studio Web Surface Architecture

> Builds on
> [`DIAGRAM_STUDIO_V2_WEBVIEW_POC.md`](DIAGRAM_STUDIO_V2_WEBVIEW_POC.md),
> [`DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md`](DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md),
> [`DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md`](DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md),
> [`DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md`](DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md).
> Does not rewrite any of them — this document asks a different
> question: not "can V2 bridge to OEP" but "should Chromium web content
> be a first-class Studio primitive at all."
>
> **§§1–21 below are AP-STUDIO-WEB-SURFACE-001's original POC findings,
> unmodified.** §§24+ (below §23's original "Recommended Next Phase")
> record AP-STUDIO-WEB-SURFACE-002, which promoted that POC into a real
> Studio destination — read those sections for what actually changed.

## 1. Objective

Determine whether OEP Studio can treat Chromium-based web content
(Legacy V2, arbitrary URLs, other local HTML applications) as a
first-class Studio surface/tab — multiple independent WebView2 instances
coexisting with native Studio content, switchable without destroying
state — as the generalized foundation Legacy V2 becomes the first
example of, not the only one.

## 2. Current Studio Tab Architecture (Phase 1 — as found, unmodified)

Two distinct navigation concepts exist, neither of which is a general
multi-content-type tab system:

**A. App-level Studio routing** (`core/routing/studio_registry.dart`,
`app_router.dart`): each Studio (Dashboard, the Diagram/Engineering
Workbench, Knowledge, Acquisition, Repository, Objects, etc.) is one
`GoRoute` built from a `StudioDestination` descriptor. This is
route-based, single-page-at-a-time navigation — there is no persistent
multi-tab strip holding several Studios open simultaneously at this
level.

**B. Diagram Studio's own internal tab strip**
(`diagram_studio/tabs/diagram_tab.dart`,
`diagram_studio/tabs/diagram_tabs_controller.dart`) — this is the one
real tab-strip UI in the app, and it is **not** a general content-type
tab system. `DiagramTab`'s own doc comment states the load-bearing
constraint directly: `EngineeringProjectState` holds **exactly one**
live `DiagramDocument`/`EditingSession`; a `DiagramTab` is a
**reference** (path/title/pin/mode) to a document, and switching tabs
means the one shared engine session loads a different document — never
a second independent document model. Tabs are:

- **Created** via `DiagramTabsNotifier.openTab({path, title})` — reuses
  an existing tab for the same path rather than duplicating.
- **Activated** via `activate(id)` — pure state change, does not itself
  load anything (the page's own `_confirmDiscardChanges`/
  `EngineeringProjectNotifier.openDocument` orchestration does that).
- **Closed** via `closeTab(id)` — records the tab in a bounded
  "recently closed" list; activates a neighbor.
- **Persisted** via `DiagramTabsStorage` (list/active-id/recently-closed,
  not document content — the document itself is a file on disk).
- **Titles/icons**: plain strings on `DiagramTab` (`title`), no icon
  concept found.
- **Content survival across switching**: **no** — because there is only
  one shared `EditingSession`, "switching tabs" is really "swap which
  document the one shared session currently holds," not "keep N
  independent sessions alive and show a different one." Inactive tabs
  do **not** keep independent live state; they keep a *reference* that
  gets reloaded into the shared session on reactivation.

**Conclusion, decisive for Phase 2**: a Web Surface needs genuinely
independent, simultaneously-alive per-tab state (its own JS runtime,
navigation history, DOM) — the exact opposite of what `DiagramTab`
already assumes about its own tabs. Grafting a "web content" case onto
`DiagramTab`/`DiagramTabsController` would either break that system's
single-shared-session assumption or produce a web tab that's fake (not
actually independent). **A Web Surface tab is therefore its own,
separate, small concept — not a new `DiagramTab` variant.**

## 3. Web Surface Abstraction (Phase 2)

Neither of the task's two suggested shapes was adopted verbatim:

- `StudioSurface > NativeSurface/WebSurface` implies OEP's *entire*
  content model gets reorganized under one root type — far more than
  this POC needs and not something Phase 1's findings justify (native
  Studio content, per §2, already has its own working models; nothing
  here requires unifying them under a shared base class).
- `StudioTab > NativeTabContent/WebTabContent` — same issue, plus §2's
  finding that `DiagramTab` isn't a generic tab-content contract to
  begin with.

**What was actually built**: a standalone `WebSurface` model
(`lib/web_surface/web_surface.dart`) —

```dart
class WebSurface {
  final String id;
  final String title;
  final String initialUrl;
  final WebSurfaceKind kind;       // local | remote, derived from URL scheme
  final bool bridgeAuthorized;      // always false for generic surfaces
}
```

— paired with a small, plain-Dart `WebSurfaceTabsController`
(`lib/web_surface/web_surface_tabs_controller.dart`, add/activate/close
only, deliberately not Riverpod-based since nothing here needs
app-wide reactivity) and a rendering widget, `WebSurfaceView`
(`lib/web_surface/web_surface_view.dart`) that owns exactly one
`WebviewController`. This is the smallest shape that satisfies all six
of Phase 2's listed requirements — verified against each: Legacy V2 (§4
below, embedded as its own pre-existing widget, not reconstructed
through this model), arbitrary URL navigation (`WebSurfaceView`'s own
Back/Forward/Reload/URL-bar chrome), local `file://` content (§6),
multiple independent WebViews (§4), tab switching/closing
(`WebSurfaceTabsController`), and future OEP bridge integration (§9).

## 4. WebView Lifetime (Phase 3)

**Decision: B — keep the WebView alive while its tab remains open**,
implemented via `IndexedStack` in `WebSurfacesHostPage`
(`lib/web_surface/web_surfaces_host_page.dart`): every open tab's
content widget is built once and kept in the `IndexedStack`'s children
list; switching tabs changes which index is *painted*, not which
widgets exist. A widget's `State.dispose()` — and therefore its
`WebviewController.dispose()` — only runs when the tab is actually
**closed** (removed from the list), never on a mere switch. This is
what lets a form half-filled-in on a remote page, or V2's in-progress
diagram edits, survive switching away and back — verified live (§20).
Decision A (destroy on switch-away) was rejected as it would defeat the
entire point of the POC (Phase 11 explicitly requires state survival);
decision C (a shared surface/session provider keeping WebViews alive
independent of widget lifetime) was not needed for this POC's scope —
`IndexedStack` already delivers the required behavior without a
separate provider layer, and introducing one now would be premature
(the task's own Phase 3 instruction: "do not optimize prematurely").

## 5. Multiple WebViews (Phase 4)

Each `WebSurfaceView` constructs its own `WebviewController()` —
confirmed by reading `webview_flutter_windows` 1.1.1's own source
(`lib/src/webview.dart`, already reviewed in the POC-001/002 era): a
`WebviewController` wraps one native WebView2 `CoreWebView2` instance.
Multiple concurrent `WebviewController`s were exercised live in this
task's own verification (§20) — the plugin does not appear to impose a
process-wide singleton or a single shared profile at the level this POC
exercises. What was **not** separately investigated: whether every
`WebviewController` defaults to the same underlying WebView2 user-data
folder (meaning shared cookies/localStorage/session-state across
surfaces by default, Chromium's normal same-profile behavior) or
whether `WebviewController.initialize()`/`initializeEnvironment()`
accepts a distinct user-data-folder argument per instance for true
profile isolation — `initializeEnvironment` exists on the class (seen in
the package's own API) but configuring genuinely isolated
profiles/cookies per surface was not attempted (Phase 4's own "do not
create persistent profiles yet"). **Independent navigation, independent
in-page JS state, and independent scroll position were all confirmed
live** (§20) — these live at the page/renderer level, not the profile
level, so they're independent regardless of profile sharing.

## 6. Local vs. Remote Content (Phase 6)

Three content sources were loaded, live:

1. **Legacy V2** — via the existing, unmodified `LegacyV2WebViewPage`
   and its own `_v2EntryPointUri()` path resolution, embedded directly
   into `WebSurfacesHostPage` as one of its tabs, untouched.
2. **A second, new local HTML test app**
   (`dev_assets/web_surface_test_app/index.html` — a small,
   self-contained page with its own independent counter/JS state, used
   to prove two local `file://` surfaces don't share state) — loaded via
   a **generalized** version of V2's own upward-marker-search algorithm,
   extracted into `lib/web_surface/local_file_resolver.dart`'s
   `resolveRepoRelativeFileUri`. Per this task's Phase 7 instruction to
   evaluate, not blindly rewrite, the existing V2 implementation,
   `LegacyV2WebViewPage` itself was **left untouched** — it keeps its
   own copy of this algorithm rather than being refactored to call the
   new shared function, to avoid touching an already-verified, working
   widget as part of an architecture POC. Migrating it is straightforward
   follow-up work, not done here.
3. **A normal HTTPS URL** — via `WebSurfaceView`'s own URL bar
   (`_navigate`), which auto-prepends `https://` for a bare
   hostname/search term the same way an address bar normally does.

## 7. Chromium/WebView2 Implementation (unchanged from prior tasks)

`webview_flutter_windows` 1.1.1's actual `WebviewController`/`Webview`
API (not `webview_flutter`'s abstraction, which this package version
does not implement) — investigated in full during POC-001/002 and not
re-litigated here; confirmed still correct by this task's own successful
build/live-verification. Not replaced, per this task's own "do not
replace the package unless investigation proves it is necessary" —
investigation found no reason to.

## 8. Native/Web Boundary (Phase 7)

```
        WebSurfacesHostPage
                 │
     ┌───────────┼────────────────┐
     │           │                │
Legacy V2    Generic Web      Native OEP
(bridged)     Surfaces        panel
     │        (unbridged)         │
LegacyV2BridgeTransport           │
     │                            │
LegacyV2StateAdapter              │
     │                            │
     └──────────────┬─────────────┘
                     │
          DiagramStudioController
                     │
                 OEP Engine
```

`WebSurfaceView` (the generic surface widget) imports only
`flutter/material.dart` and `webview_flutter_windows` — no OEP type
appears anywhere in its file, verified by inspection (§ the file itself).
The existing `LegacyV2BridgeTransport`/`LegacyV2StateAdapter` pair
(built across AP-DIAGRAM-V2-WEBVIEW-001/002/003) is confirmed, not
newly designed, as **the** implementation of "a bridge-authorized Web
Surface" — it already respects exactly this boundary (transport knows
only V2's vocabulary; adapter is the only layer touching
`DiagramStudioController`). It was **not generalized** into a reusable
"any Web Surface can have a bridge" mechanism in this task, per Phase 7's
own explicit instruction — that remains a real, separate design question
(what would a bridge transport for a *generic* engineering web app even
look like, versus V2's specific poll-and-diff mechanism?) appropriately
deferred to whenever a second bridged surface is actually authorized.

## 9. Bridge Authorization Model (Phase 8 / security boundary)

**The concrete, currently-enforced boundary**: a `WebSurface` created
through the generic path (`WebSurfacesHostPage._addWebSurface`) never
has any injected script, never has a `webMessage` listener registered,
and never has any Dart-side code path that could call into
`DiagramStudioController`. There is no "check `bridgeAuthorized` before
acting" gate to bypass, because the capability simply isn't wired up for
generic surfaces at all — the strongest form of "arbitrary web content
must not automatically gain access to OEP" available without building
authorization *infrastructure* this task explicitly says not to build
yet (`bridgeAuthorized` exists on the model as a documented future hook,
not an enforced gate today — see the field's own doc comment for why).

The one bridged surface, Legacy V2, is not constructed through this
generic path — it's a dedicated, separately-reviewed widget embedded
directly as one specific tab. **Any future second bridged surface would
need the same treatment**: its own dedicated transport/adapter pair,
explicitly composed, not a flag flipped on a generic `WebSurfaceView`.

Investigated, not implemented (Phase 8's own "do not build a full
security framework"):

- **JavaScript injection / `executeScript` / `postMessage`**: only
  present on `LegacyV2BridgeTransport`; `WebSurfaceView` never calls
  `addScriptToExecuteOnDocumentCreated` or listens to `webMessage`.
- **Navigation events**: `WebviewController.url`/`loadingState` streams
  exist and are used today only for the URL bar's own display
  (`WebSurfaceView._init`'s `_controller.url.listen`) — not for any
  origin-based access-control decision. A real bridge-authorization
  system would need to consult the *current* URL/origin on every
  navigation (a page can navigate itself after initial load), not just
  the surface's `initialUrl` — noted as a real requirement for later,
  not solved here.
- **Popups/new windows/downloads/external navigation**: not
  investigated this task — see §12/§16.

## 10. Navigation

`WebviewController` exposes `loadUrl`, `reload`, `goBack`, `goForward`,
`stop`, and `url`/`loadingState`/`historyChanged` streams (confirmed by
reading the package source, same class already used by
`LegacyV2BridgeTransport`). `WebSurfaceView` uses `loadUrl`/`reload`/
`goBack`/`goForward` directly — no navigation *history* is persisted or
tracked by OEP itself; back/forward relies entirely on WebView2's own
in-page history.

## 11. Downloads (Phase 9, investigated only)

`WebviewController` exposes an `onDownloadEvent` stream (seen in the
package source, already noted in the transport's own file for a
different purpose in POC-002/003's investigation) — not wired up or
tested in this task. A production Web Surface would need an explicit
decision about whether downloads are allowed at all, and if so where
they land — not attempted here.

## 12. Clipboard (Phase 9, investigated only)

No dedicated clipboard API was found on `WebviewController` beyond
whatever the OS/Chromium's own default clipboard integration provides
implicitly (standard copy/paste inside the rendered page, which requires
no extra plugin surface). Not tested explicitly this task.

## 13. Drag/Drop (Phase 9, investigated only)

Not tested. `webview_flutter_windows`'s own API surface (reviewed via
its source, §7) exposes no explicit drag/drop hook; whatever a page does
with drag/drop internally (e.g. drag-select in a web app) is presumably
Chromium's own default behavior, unverified for interaction with
Flutter's own drag/drop system (e.g. dragging a file from a native OEP
panel onto a Web Surface, or vice versa) — not attempted.

## 14. Printing/PDF (Phase 9, investigated only)

Not tested this task. `WebviewController` was not found to expose a
dedicated print/PDF-export API in the reviewed source; Chromium's own
in-page print dialog (Ctrl+P inside the WebView) is presumably reachable
the same way it is in any Chromium-based browser, unverified here.

## 15. Import/Export Opportunities (Phase 9)

Conceptual pipelines named by the task, **not implemented**:

- **Web reference → Import → OEP object/document**: would need either
  (a) a bridge-authorized surface's own page script cooperating (like
  V2's poll-and-diff mechanism), or (b) a native-side content-extraction
  step (e.g. `executeScript` pulling structured data out of a *trusted*
  local page) — both are bridge-design questions, not something this
  generic `WebSurfaceView` should grow itself.
- **OEP diagram → Export/capture → Web reference**: no export/screenshot
  API was found on `WebviewController` in this task's review; would
  likely mean rendering OEP's own diagram to an image/PDF (existing
  Diagram Studio printing/publishing code, untouched by this task) and
  handing that to a Web Surface some other way, not a WebView2
  capability per se.

## 16. Tab Persistence Requirements (Phase 14, documented only)

Not implemented. What a real Web Surface tab would need to persist,
eventually:

- `surface type` (Legacy V2 / generic web / a future named engineering
  web app)
- `url` (current, not just initial — a surface can navigate away from
  where it started)
- `title`
- `local`/`remote` designation (derivable from URL, so maybe not stored
  separately)
- `bridgeAuthorized` (and, if ever granted, by what mechanism/at what
  point — an audit trail, not just a boolean)
- an optional session/profile identifier, if per-surface profile
  isolation (§5) is ever implemented

None of this is wired to `DiagramTabsStorage` or any other persistence
mechanism in this task — Web Surface tabs do not survive an app restart
today.

## 17. Cross-Platform Architecture (Phase 15, documented only)

| Platform | Implementation |
|---|---|
| Windows | WebView2 (`webview_flutter_windows`, current, unchanged) |
| Android | Chromium-based `android.webkit.WebView` (via `webview_flutter_android`, the federated `webview_flutter` package's real platform implementation — unlike Windows, this one *does* implement the shared interface, per general Flutter ecosystem knowledge; not verified against this repo since Android isn't a build target here) |
| Linux | No official Flutter-team WebView implementation is bundled with `webview_flutter`; a Linux target would need a WebKitGTK-backed community package or a custom platform channel — not investigated further |
| macOS/iOS | `WKWebView` (via `webview_flutter_wkwebview`, the real platform implementation for those targets) |

**The architectural requirement this task called out — "Studio's Web
Surface abstraction should not expose WebView2-specific concepts to the
rest of OEP" — is already satisfied by construction**: `WebSurface` (the
model) has zero WebView2 types in its own file (§3); only
`WebSurfaceView`'s own `State` imports `webview_flutter_windows`
directly. A cross-platform implementation would mean giving
`WebSurfaceView` (or a factory it calls) a per-platform controller
choice — the model and tab-controller layers would not need to change at
all.

## 18. Legacy V2's Role (unchanged from prior tasks, restated)

Legacy V2 remains the first, and so far only, bridge-authorized Web
Surface — proven to still fully function (create/select/edit/zoom/pan/
edit-mode/wires/sidebar) while embedded as one tab inside the new
generalized host, not just standalone (§20).

## 19. Future Engineering Applications

The task's own list — Service Manual, Datasheet, OEM Documentation,
Wiring Database, Parts Catalog, general engineering web applications —
are all, per this architecture, just additional **unbridged** (or, if a
real need arises, individually bridge-authorized the same deliberate way
V2 was) `WebSurface` tabs. Nothing about the abstraction built here is
V2-specific; V2 is simply the one surface with a bridge behind it.

## 20. POC Results (Live Verification)

Performed live by the developer against the built app:

- Opened a Legacy V2 Web Surface tab — V2 loaded and worked.
- Opened a second Web Surface tab, navigated it to an HTTPS URL.
- Switched V2 → HTTPS tab → back to V2 — **V2's state remained intact**
  (module positions, selection, zoom/pan all as left).
- Switched to the HTTPS tab — its state (scroll/navigation) remained
  intact.
- Opened the native OEP panel tab, switched among all three repeatedly.
- Closed the HTTPS tab — V2 remained intact.
- Closed V2 — the native tab remained functional.

**Every item in the task's own 15-step Live POC Acceptance Test passed.**
Step 16 (two Web Surfaces visible simultaneously via a split view) was
**not attempted** — the tab-strip-plus-`IndexedStack` design already
proves the state-preservation property the split view would have
additionally demonstrated, and building a split-view layout was judged
unnecessary UI work for what the acceptance test's own wording marks as
optional ("if practical").

## 21. Known Limitations

- No per-surface WebView2 profile/cookie isolation configured (§5) —
  unverified whether concurrent surfaces share cookies/localStorage by
  default.
- No downloads, clipboard, drag/drop, or print/PDF capability tested
  (§11–14).
- No tab persistence (§16) — Web Surface tabs are lost on restart.
- No navigation-time origin re-check for bridge authorization (§9) — a
  bridged surface that navigated itself elsewhere would need this before
  any real second bridged surface is added.
- Native/Web tab icon classification is cosmetic-only for the two
  special-cased tabs (Legacy V2, Native OEP) — their `WebSurface.kind` is
  derived from a placeholder pseudo-URL, not a real content check, since
  neither is actually routed through `WebSurfaceView`.
- `WebSurfacesHostPage` is not registered in `core/routing/
  studio_registry.dart` — reachable only via the same dev-only button
  pattern `LegacyV2WebViewPage` already used, not the main app
  navigation.
- The wire-creation bridge's own known undo-ordering issue
  (`DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md` §13a) is unrelated to
  this task and was left as-is — investigation was paused, not
  abandoned, when this task's own directive arrived.

## 22. Recommended Architecture

Adopt the `WebSurface`/`WebSurfaceTabsController`/`WebSurfaceView` shape
as the standing primitive for future Chromium-backed Studio content —
it is minimal, has no OEP knowledge by default, and has been proven to
coexist with both a bridge-authorized surface (V2) and native Studio
content without requiring changes to either. Do **not** fold it into
`DiagramTabsController` (§2's finding stands). Whether
`WebSurfacesHostPage` should eventually become a registered
`StudioDestination` (a true top-level Studio, sibling to Diagram Studio)
or remain embedded/reachable from within Diagram Studio is a product
decision this document does not make.

## 23. Recommended Next Phase

Not decided here, per this task's own stop conditions — options named,
not chosen: per-surface profile isolation design (§5/§21); tab
persistence design (§16); a second bridge-authorized surface (to prove
the bridge pattern generalizes beyond V2, without yet building a generic
bridge protocol Phase 7 explicitly deferred); origin-based bridge
re-authorization on navigation (§9/§21); registering `WebSurfacesHostPage`
as a real `StudioDestination`; resuming the paused wire-creation-undo
bug investigation (§21).

---

# AP-STUDIO-WEB-SURFACE-002 — Promotion to a First-Class Studio Tab Surface

This section records what AP-STUDIO-WEB-SURFACE-002 actually changed.
It does not restate §§1–23 above.

## 24. Studio Entry Point (Phases 1–2)

Phase 1's own investigation (§2 above, unchanged) already established
that Diagram Studio's own tab strip cannot host Web Surfaces. The
correct real entry point turned out to be one level up: `core/routing/
studio_registry.dart`'s `StudioDescriptor` list — the same mechanism
every other top-level Studio (Dashboard, Diagram, Knowledge, Acquisition,
etc.) already uses, reached through the persistent Navigation Rail
(`StudioShell`, wrapping every route via `app_router.dart`'s single
`ShellRoute`).

**What was added**: a new `StudioDestination.webSurfaces` entry
(`'Web Surfaces'`, `/web-surfaces`, `Icons.public`/`Icons.public_outlined`)
and a matching `StudioDescriptor` in `defaultRegistry` whose
`pageBuilder` returns `WebSurfacesHostPage` directly — no
`settingsProvider`/`searchProvider` (optional fields; several existing
Studios, e.g. Copilot, Settings, already omit them). `WebSurfacesHostPage`
itself was changed from a `Scaffold`+`AppBar` page (correct for a
`Navigator.push`-reached dev route) into plain body content (a `Column`
with no own `Scaffold`) — matching every other `StudioDescriptor` target
(`DashboardPage` etc.), which render inside the shell's own frame rather
than building a second one.

**What was removed**: both `kDebugMode`-gated dev buttons in
`diagram_studio_page.dart` ("Open Legacy V2 (dev)" and "Open Web Surfaces
(dev)") and their now-unused imports — per this task's explicit "do not
retain duplicate dev-only entry points once the real entry point exists."
Legacy V2 remains reachable, now exclusively via the Web Surfaces
destination's "Open Legacy V2" button (§25).

## 25. Tab Behavior (Phase 3/12)

The same `WebSurfaceTabsController`/`IndexedStack` mechanism from
AP-STUDIO-WEB-SURFACE-001 (§4 above), unchanged. Two creation paths, per
Phase 12:

- **"Open Legacy V2"** — reuses the existing tab if one is already open
  (checked by the fixed `WebSurfacesHostPage.legacyV2TabId`, matching
  `DiagramTabsNotifier.openTab`'s own "don't duplicate an already-open
  reference" convention) rather than activating a fresh instance every
  click.
- **"Open Web URL"** — a small dialog prompts for a URL, creates a
  `WebSurface(application: WebSurfaceApplication.generic)`, adds it, and
  activates it. No production website is hard-coded anywhere in the
  architecture (the dialog defaults to an empty field; the retained
  "Open Local Test App" button is the one example-URL shortcut, pointing
  at the dev-only local test HTML app from AP-STUDIO-WEB-SURFACE-001,
  not a real site).

The tab strip (`_TabStrip`/`_TabChip`) is unchanged in shape from §1's
POC — title, active-state highlight, close (×) — with one addition: a
bridge-authorized tab's icon renders in a distinct color
(`Colors.lightGreenAccent` vs. the default `Colors.white70`), a purely
visual cue that a tab has OEP access, backed by the same
`WebSurface.bridgeAuthorized` getter §27 makes structurally reliable.

## 26. Generic Web Surface (Phase 4/5)

Unchanged from AP-STUDIO-WEB-SURFACE-001 (§3/§6 above) — `WebSurfaceView`
itself was not modified by this task. Its Back/Forward/Reload/URL-bar
chrome remains the surface's own UI, not part of any Studio-wide command
surface (§28).

## 27. Legacy V2 Web Surface (Phase 7/8)

**Model change**: `WebSurface.bridgeAuthorized` is no longer a
constructor parameter (it was, defaulting to `false`, in
AP-STUDIO-WEB-SURFACE-001). It is now a **derived getter**:

```dart
enum WebSurfaceApplication { legacyV2, generic }

bool get bridgeAuthorized => application == WebSurfaceApplication.legacyV2;
```

This is the "minimum structural enforcement necessary" this task calls
for: there is no longer a code path that could construct a generic
surface with `bridgeAuthorized: true` by mistake — the only way to get a
`true` value is to construct the surface with
`application: WebSurfaceApplication.legacyV2`, which
`WebSurfacesHostPage._openLegacyV2` is the only call site that does.

**Rendering**: `WebSurfacesHostPage._buildSurfaceContent` special-cases
`application == WebSurfaceApplication.legacyV2` to render the existing,
unmodified `LegacyV2WebViewPage` directly — **not** a new
`LegacyV2WebSurfaceView` wrapper class. The task's own conceptual diagram
(`WebSurface > Generic WebSurfaceView | LegacyV2WebSurfaceView >
LegacyV2BridgeTransport/LegacyV2StateAdapter`) is satisfied by
`LegacyV2WebViewPage` itself filling the `LegacyV2WebSurfaceView` role —
it already *is* exactly that composition (owns its own
`WebviewController`, composes `LegacyV2BridgeTransport`/
`LegacyV2StateAdapter`, matches the diagram's own shape). Introducing an
additional pass-through wrapper class around an already-correct,
already-verified widget was judged unnecessary indirection, not a
architecture gap — renaming/relocating it remains straightforward future
work if a literal class named `LegacyV2WebSurfaceView` is ever required.

## 28. Command Palette (Phase 6, documented only — not removed)

No file or class literally named "command palette" exists in
`diagram_studio/`. What earlier tasks' documents referred to by that name
is `diagram_studio/toolbars/diagram_toolbars.dart` — the toolbar-button
bar (Add Node, Undo/Redo, mode toggles, etc.) rendered as part of
`DiagramStudioPage`. It is used **only** within Diagram Studio's own
page; nothing in `WebSurfacesHostPage` or the Web Surface model depends
on it, references it, or was found to require it during this task's
implementation. Promoting Web Surfaces to a real Studio destination did
**not** require touching it, confirming (not merely asserting) the
"promoting Web Surfaces requires it" condition this task's own
instructions used as the bar for removal was never met. It remains
exactly as it was; no replacement functionality was invented.

## 29. Navigation Boundary (Phase 9)

**New file**: `diagram_studio/webview/legacy_v2_trust_boundary.dart` —
a pure function, `isTrustedLegacyV2Url(currentUrl, trustedEntryUrl)`,
with no `WebviewController`/bridge dependency (testable standalone, see
§31). The trusted boundary is **the local directory V2's own entry point
was loaded from** (`file://.../eke-wiring-sim/`), not merely "any
`file://` URL" (too broad — would trust arbitrary local content) and not
"exactly the entry URL" (too narrow — V2 is a single page, but its own
sub-resources, e.g. `js/app.js`, load from `file://` URLs within the same
directory and must not be flagged as "navigation away").

**Wiring**: `LegacyV2WebViewPage._init` now subscribes to
`_controller.url` (a stream `WebviewController` already exposed,
previously unused by this widget) and calls `isTrustedLegacyV2Url` on
every emission, writing the result into a new
`LegacyV2BridgeTransport.bridgeEnabled` field.

**Enforcement — inbound**: `LegacyV2BridgeTransport._dispatch` (the one
place every inbound message from V2 passes through, batched or not) now
starts with `if (!bridgeEnabled) return;` — a message arriving while
untrusted is dropped before any handler (`onModuleMoved`,
`onModuleCreated`, etc.) ever sees it. `LegacyV2StateAdapter` was **not**
modified — it never needed to know about trust; the gate lives entirely
in the transport, one layer below it.

**Enforcement — outbound**: all six of the transport's own
`executeScript`-issuing methods (`sendAuthoritativeModulePosition`,
`sendAuthoritativeModuleLabel`, `restoreModule`, `removeModuleFromV2`,
`confirmWireCreated`, `removeWireFromV2`) now route through a private
`_executeIfEnabled` helper that no-ops (without touching the
`WebviewController` at all) while `bridgeEnabled` is `false` — defense in
depth against a queued action (e.g. the user's own Undo button) firing
after navigation has already left the trusted boundary. The one
remaining unguarded method, `executeRawScript` (used only for the
non-mutating "Fit view" button), was deliberately left as-is — it issues
no OEP-authoritative write and gating it would only prevent a harmless
view-reset command from working on whatever page is currently loaded.

**Restoration behavior**: automatic, not a separate manual action —
`bridgeEnabled` is recomputed from `isTrustedLegacyV2Url` on **every**
navigation event, so navigating back within the trusted directory (Back
button, reload, or V2 itself never having actually left) restores
`bridgeEnabled = true` the moment the URL stream reports it, with no
extra user action required. This was a deliberate design choice: the
boundary check itself is authoritative on every navigation, not "was
this tab ever trusted historically."

**Visibility**: the status bar's first line now reads `Bridge: AUTHORIZED
(trusted V2 content)` or `Bridge: DISABLED (navigated away from trusted
V2 content)`, colored green/orange respectively — this is what a live
verifier actually reads to confirm the boundary is working (§32).

**Not implemented, per this task's own "do not build a generalized
security subsystem"**: this mechanism is Legacy-V2-specific
(`isTrustedLegacyV2Url`'s signature is V2-only) — it does not generalize
to "any bridge-authorized surface" without a real design pass, since a
generic version would need to know what "trusted" means for whatever that
surface's application is (a question with no single right answer across
different engineering web applications).

## 30. Native/Web Coexistence (Phase 11)

Unchanged from AP-STUDIO-WEB-SURFACE-001 (§8 above) — the Native OEP
panel remains a plain Flutter widget reading the same
`diagramStudioControllerProvider`, now one tab inside the real Studio
destination instead of the dev-only host. `DiagramTab`'s own document
model was not touched or merged with `WebSurface` in any way.

## 31. Tests Added

- `test/web_surface/web_surface_test.dart` — extended with
  `WebSurfaceApplication`/structural `bridgeAuthorized` coverage (legacyV2
  is authorized; generic is never authorized even with a `file://` URL;
  `copyWith` cannot change `application`).
- `test/diagram_studio/webview/legacy_v2_trust_boundary_test.dart` — new,
  pure-function tests for `isTrustedLegacyV2Url` (entry URL, sibling
  file, nested subdirectory, a different local app, an `https://` URL, an
  unparseable URL, and restoration-on-return).
- `test/diagram_studio/webview/legacy_v2_bridge_transport_gating_test.dart`
  — new, verifies the outbound gate (`bridgeEnabled = false`) short-
  circuits before touching the underlying `WebviewController`, safe to
  run without a real initialized WebView2 instance.
- `test/web_surface/web_surface_tabs_controller_test.dart` — unchanged
  from AP-STUDIO-WEB-SURFACE-001, still exercises tab add/activate/close
  including a mix of local/remote/`legacyV2`-classified surfaces.

No test depends on WebView2 rendering internals, per this task's own
instruction.

## 32. Live Verification (Phase 14)

Performed live by the developer against the built app, all steps of the
task's 18-step acceptance test:

- Opened Legacy V2 as a real Studio Web Surface (via the Navigation
  Rail → "Web Surfaces" → "Open Legacy V2") — confirmed working
  normally.
- Opened a generic Web Surface, navigated it to an HTTPS test page.
- Switched V2 → generic surface → V2 repeatedly — state preserved both
  directions.
- Opened a second generic Web Surface; switched among all three (V2,
  generic, Native OEP).
- Closed one Web Surface — the remaining surfaces stayed alive.
- Confirmed the generic surface has no OEP bridge access (its tab icon
  never turns green; no bridge status line exists for it at all, since
  only `LegacyV2WebViewPage` renders one).
- Confirmed Legacy V2 retains its authorized bridge (status bar reads
  "Bridge: AUTHORIZED").

**Confirmed by the developer: "all good."**

## 33. Known Limitations (Phase 002-specific, in addition to §21 above)

- The Legacy-V2-specific trust boundary (§29) does not generalize to
  future bridge-authorized surfaces without new design work.
- `WebSurfacesHostPage`'s two special-cased tabs (Legacy V2, Native OEP)
  are still identified by fixed string ids
  (`WebSurfacesHostPage.legacyV2TabId`/`nativeTabId`) rather than a more
  general "surface renderer registry" — acceptable for two special cases,
  would need revisiting for a third.
- No `LegacyV2WebSurfaceView` class was introduced (§27) — the task's own
  conceptual diagram is satisfied by composition/naming-in-spirit, not a
  literal new type.
- Command palette (§28): confirmed not required for this task, not
  removed — the broader question of whether/when to remove it remains
  open, unchanged from prior tasks' framing.
- The pre-existing wire-creation-bridge undo-ordering issue
  (`DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md` §13a) remains unresolved;
  unrelated to and untouched by this task.

## 34. Architectural Conclusion (Phase 002)

Web Surfaces are now reached the same way every other Studio is —
through the persistent Navigation Rail, not a developer-only button —
without requiring any change to `DiagramTabsController`, the shared
`EngineeringProjectState`/`EditingSession`, or the Engine. The bridge-
authorization boundary that was a documented-but-unenforced field in the
POC is now a structurally-derived property with no accidental-`true`
code path, and the one bridge-authorized surface (Legacy V2) now
disables itself automatically the moment it's no longer showing trusted
content — closing the exact gap AP-STUDIO-WEB-SURFACE-001 §21 flagged as
open ("no navigation-time origin re-check for bridge authorization").

## 35. Recommended Next Phase

Not decided here, per this task's own stop conditions — options named,
not chosen: the V2 wire/simulation/persistence bridges; browser
profiles/history/downloads; a generalized Web/OEP protocol (now that two
surface applications exist, is a real second bridge worth designing
against?); cross-platform implementation; Flutter renderer deletion;
command-palette removal (§28's finding: not currently blocking anything,
still an open product decision); full V2 migration.
