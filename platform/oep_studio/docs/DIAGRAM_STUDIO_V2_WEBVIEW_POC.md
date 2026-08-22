# AP-DIAGRAM-V2-WEBVIEW-POC-001 — Legacy V2 Embedded WebView Proof of Concept

> See also [`DIAGRAM_STUDIO_V2_BRIDGE_POC.md`](DIAGRAM_STUDIO_V2_BRIDGE_POC.md) (POC-002, bidirectional
> messaging) and [`DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md`](DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md)
> (the full functional/architectural assessment building on this and the
> node-movement POC).

## 1. POC Objective

Determine whether the existing legacy V2 reference application
(`reference/legacy_wiring_sim_v2/eke-wiring-sim/`) can run **unmodified**
inside OEP Studio as an embedded HTML/JavaScript application, hosted in a
native Windows WebView, with zero changes to the V2 source tree and zero
changes to Engine/Foundation.

This is a proof-of-concept only. No OEP↔V2 communication bridge was
attempted or is in scope — that remains a separate, later architectural
decision.

## 2. Result

**A — V2 runs embedded successfully.** The unmodified legacy V2
application loads and is fully interactive inside a native Windows
WebView2 control hosted by an OEP Studio widget, reached via a dev-only
button on the Diagram Studio page.

## 3. WebView package selected, and why (full journey)

Three candidates were evaluated, in this order:

1. **`webview_windows` 0.4.0** (standalone package, direct
   `WebviewController`/`Webview` API). Tried first. Its native plugin
   **fails to compile** against this machine's MSVC toolchain
   (14.51.36231): a hard `error C2338` on `<experimental/coroutine>`
   (the Coroutines TS, deprecated and removed from that toolchain
   version). Confirmed via `flutter pub outdated` that 0.4.0 is the
   latest published version — no version bump fixes this.
2. **`webview_flutter` + `webview_flutter_windows` 1.1.1** (the
   federated, actively-maintained pairing). Compiles successfully.
   However, at **runtime**, every call through `webview_flutter`'s own
   `WebViewController`/`WebViewWidget` throws:
   ```
   'package:webview_flutter_platform_interface/src/platform_webview_controller.dart':
   Failed assertion: line 27 pos 7: 'WebViewPlatform.instance != null':
   A platform implementation for 'webview_flutter' has not been set.
   ```
   Root cause, confirmed by reading the package's own source: `webview_flutter_windows`
   1.1.1's `pubspec.yaml` declares only a native `pluginClass:
   WebviewWindowsPlugin` — **no `dartPluginClass`** at all. Its
   `lib/webview_flutter_windows.dart` and `lib/webview_windows.dart` are
   byte-identical, re-exporting a raw `WebviewController`/`Webview` API —
   the *same* API `webview_windows` exposes, under a different package
   name. It never implements `webview_flutter_platform_interface`'s
   `WebViewPlatform` contract, so `WebViewPlatform.instance` is never
   set and `webview_flutter`'s abstraction can never work against it.
3. **`webview_flutter_windows` 1.1.1, used directly** (its actual
   `WebviewController`/`Webview` API, bypassing `webview_flutter`
   entirely). Native plugin compiles successfully (same plugin as
   attempt 2, since it's the same package). This is the API this POC
   ultimately uses, and it works.

Final dependency: `webview_flutter_windows: ^1.1.1` only (`webview_flutter`
removed). See [`pubspec.yaml`](../pubspec.yaml) and
[`lib/diagram_studio/webview/legacy_v2_webview.dart`](../lib/diagram_studio/webview/legacy_v2_webview.dart)
for the in-code account.

## 4. Windows/WebView2 requirements

The Microsoft Edge WebView2 runtime was already installed on the dev
machine (confirmed via registry at build/run time — `webview_flutter_windows`
would otherwise fail to initialize). No separate installation step was
required for this POC. A packaged distribution would need to either
bundle the WebView2 Evergreen Bootstrapper or document it as a
prerequisite — out of scope for this POC.

## 5. V2 entry point and local content loading mechanism

- Entry point: `reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html`,
  loaded directly via `file://` — no copy into the Studio source tree,
  no bundling step, no local HTTP server.
- `file://` worked. A local HTTP server was **not** required.
- V2's own `js/storage/vehicle-loader.js` already branches on
  `location.protocol === 'file:'` to read a pre-bundled
  `window.EKE_BUNDLE` global instead of calling `fetch()` — V2 was
  already designed to run from `file://`; this is not a workaround
  introduced by this POC.

### Path-resolution bug found and fixed during this POC

The first implementation resolved the entry point as a fixed
`Directory.current.parent.parent`. This is correct when launched via
`flutter run` (cwd = `platform/oep_studio/`, the Flutter project root)
but **wrong** when the built `.exe` is launched directly (cwd =
`build/windows/x64/runner/Debug/`, a different depth below the repo
root). The mismatch pointed the WebView at a nonexistent path; WebView2
rendered its own "File not found" page rather than a Dart-level error,
which briefly looked like a successful-but-broken load. Fixed by
searching upward (up to 8 levels) from both `Directory.current` and
`Platform.resolvedExecutable`'s directory for the marker path
`reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html`, so it's
correct regardless of launch method. This is dev-only, POC-only
resolution logic, not meant to survive into any packaged build.

## 6. V2 browser/API dependencies discovered

- No ES modules — all scripts are classic `<script>` tags.
- No dependency on `fetch()` when running under `file:`, per §5.
- No other browser APIs beyond standard DOM/Canvas/File APIs were
  observed to cause problems inside WebView2 (which is Chromium-based,
  so this is expected).

## 7. Whether V2 ran unmodified

**Yes.** SHA-256 checksums of all 100 files under
`reference/legacy_wiring_sim_v2/eke-wiring-sim/` were captured before
and after this POC's work; the checksums are identical. Zero
modifications to the V2 source tree.

## 8. V2 functionality demonstrated

Confirmed working live, interactively, by the user inside the embedded
WebView (not just "process health"):

- V2 renders its full canvas, modules, and wires.
- Module selection.
- Edit/layout mode.
- Zoom (Ctrl+scroll and/or the +/−/Fit controls).
- Wire interaction.
- General interactivity — user's own words: "it all seems to function
  correctly."

No functional gaps or WebView-specific limitations were observed during
this pass.

## 9. Performance

No perceptible lag or rendering issues were reported during interactive
use.

## 10. Keyboard / mouse / focus / resize / scrolling / context-menu behavior

Not specifically itemized beyond the general "functions correctly"
confirmation above — no issues reported for any interaction attempted.

## 11. Persistence behavior

Not exercised in this pass (V2's own manual Save/Load Layout JSON
file flow was not specifically tested). No indication of a blocker;
V2's persistence is pure client-side JS/file-picker logic with no
special WebView requirements.

## 12. OEP↔V2 communication status

**Not implemented.** No bridge, no shared state, no message-passing
between OEP Studio (Dart/Flutter) and the embedded V2 page (JS) exists.
This was explicitly out of scope for this POC and remains a separate,
later architectural decision.

## 13. Files modified

- [`pubspec.yaml`](../pubspec.yaml) — added `webview_flutter_windows: ^1.1.1`.
- [`lib/diagram_studio/webview/legacy_v2_webview.dart`](../lib/diagram_studio/webview/legacy_v2_webview.dart) — new file, `LegacyV2WebViewPage`.
- [`lib/diagram_studio/workspaces/diagram_studio_page.dart`](../lib/diagram_studio/workspaces/diagram_studio_page.dart) — added a dev-only (`kDebugMode`-gated) "Open Legacy V2 (dev)" button that pushes `LegacyV2WebViewPage` as a separate route. No existing UI/behavior altered.
- `pubspec.lock` — updated for the new dependency.

No Engine, Foundation, or V2 source files were modified.

## 14. Engine/Foundation status

Untouched. This POC has no dependency on `oep_engine` or Foundation
beyond what `oep_studio` already required.

## 15. V2 source integrity status

Verified unchanged (§7).

## 16. Recommended next architectural step

The embedding approach is viable. The next decision point — not started
here — is whether and how to build an OEP↔V2 communication bridge (e.g.
exposing OEP's engineering data model to V2 via a JS injection channel,
or the reverse), which is a substantially larger design question than
this POC's scope.

---

## Stop condition

Per this task's own instructions, this POC concludes here. Not
proceeded to: OEP/V2 bridge implementation, Engine integration, V2 data
model replacement, deletion of the existing Flutter Diagram Studio UI,
a Studio architecture rewrite, renderer migration, cross-platform
WebView work, production packaging, or V2 modernization.
