# AP-DIAGRAM-V2-WEBVIEW-POC-002 — OEP ↔ Legacy V2 Bridge Proof of Concept

## 1. Objective

Prove the basic communication path between the embedded, unmodified
legacy V2 UI and OEP's own Flutter/Engine stack:

```
Legacy V2 JavaScript ↕ WebView bridge ↕ Flutter/OEP ↕ DiagramStudioController ↕ OEP Engine
```

This is a small proof of concept, not a migration and not a production
bridge. It deliberately does not mutate engineering state in either
direction.

## 2. Result

**PASS.** Both directions of the bridge were demonstrated live and
confirmed working by the user ("yes both working correctly").

## 3. V2 → Flutter direction

An injected script, registered via
`WebviewController.addScriptToExecuteOnDocumentCreated` at WebView
initialization (before `loadUrl`), runs alongside V2's own scripts in
the same JS realm. It is **not** written to, or loaded from, any file
in `reference/legacy_wiring_sim_v2/eke-wiring-sim/` — V2's on-disk
source is untouched.

The script polls (V2 has no selection-changed event to hook) V2's own
existing top-level state — `selM`, `MODULES`, `WIRES`, declared as
`let` bindings in `js/app.js` — every 400ms, and calls
`window.chrome.webview.postMessage(...)` only when the observed
snapshot changes. Flutter listens on `WebviewController.webMessage`
and displays the result in a status bar under the WebView.

Verified live: module/wire counts and the currently selected module id
update in the Flutter status bar as the user clicks modules inside V2.

## 4. Flutter → V2 direction

A new toolbar button in `LegacyV2WebViewPage` calls
`WebviewController.executeScript('if (typeof zReset === "function") { zReset(); }')`
— invoking V2's own existing "Fit" toolbar function directly, without
modifying V2's source. Verified live: clicking the button snaps V2's
own view, driven entirely from the Flutter side.

## 5. Flutter → DiagramStudioController → Engine (read-only)

The same status bar also reads `DiagramStudioController.session?.graph`
(via the existing `diagramStudioControllerProvider`, read-only —
`.watch`, no writes) and displays OEP's own current node/relationship
counts and document title alongside V2's state. This closes the last
hop in the task's diagram (`DiagramStudioController ↕ OEP Engine`) by
showing both sides observable together in one screen, without
performing any real state synchronization or mutation.

## 6. What this POC does NOT do

- No mutation of OEP engineering state from V2 events, or vice versa.
- No mapping between V2's module/wire model and OEP's
  node/relationship model.
- No persistence bridging (V2's own Save/Load Layout is untouched and
  unconnected to OEP's document save/load).
- No production message protocol, versioning, or error-recovery
  design — the injected script and `executeScript` calls here are
  POC-grade only.

These are all explicitly out of scope per this task's own framing
("NOT a migration... NOT a complete V2/OEP integration") and are not
started here.

## 7. Files modified

- [`lib/diagram_studio/webview/legacy_v2_webview.dart`](../lib/diagram_studio/webview/legacy_v2_webview.dart) — added the injected bridge script, `webMessage` listener, `executeScript`-based OEP→V2 control button, and the read-only status bar reading `DiagramStudioController`.

No other files changed for this task. V2 source, Engine, and Foundation
remain untouched (same integrity guarantee as
[`DIAGRAM_STUDIO_V2_WEBVIEW_POC.md`](DIAGRAM_STUDIO_V2_WEBVIEW_POC.md) §7).

## 8. Recommended next architectural step

Both halves of the communication path are proven viable. The next
decision point — not started here — is designing an actual bridge
*protocol*: what OEP engineering-model events V2 interactions should
produce, what OEP-side mutations should be allowed to originate from
V2, and how the two data models (V2's module/wire graph vs. OEP's
node/relationship graph) would be kept consistent. That is a
substantially larger design task, out of scope for this POC.

## Stop condition

Per this task's own instructions, this POC concludes here. Not
proceeded to: a real bridge protocol, bidirectional state
synchronization, V2/OEP data-model mapping, persistence bridging,
Engine integration beyond the read-only status display, deletion of
the existing Flutter Diagram Studio UI, or any production-facing
bridge work.
