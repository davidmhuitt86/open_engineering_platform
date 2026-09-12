import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'legacy_v2_bridge_script.dart';

/// AP-DIAGRAM-V2-WEBVIEW-001 — the transport layer of the OEP↔Legacy V2
/// bridge. Pure communication: WebView lifecycle, message envelope
/// parsing, and script execution. **Deliberately knows nothing about OEP**
/// — no `EngineeringNode`, no `EngineeringRelationship`, no
/// `DiagramStudioController`, no `MoveNodesCommand`. Everything here is
/// expressed in V2's own vocabulary (a module id, an x/y pair) or is a
/// raw script string. [LegacyV2StateAdapter] is the layer that gives
/// these messages OEP meaning.
///
/// Injects [legacyV2BridgeScript] (shared verbatim with the Android
/// transport — see that file's own doc comment) alongside V2's own
/// (unmodified) scripts, registered via `addScriptToExecuteOnDocumentCreated`
/// — this is the same external-injection mechanism POC-002/003
/// established; nothing here is written to, or loaded from, any file
/// under `reference/legacy_wiring_sim_v2/eke-wiring-sim/`.
///
/// Implements [LegacyV2Channel] so [LegacyV2StateAdapter] can depend on
/// the narrow "receive module-moved events / send an authoritative
/// position" capability rather than this whole class — this is what lets
/// the adapter's dispatch/loop-prevention logic be unit-tested with a
/// lightweight fake channel, without a real `WebviewController`
/// (see `test/diagram_studio/webview/legacy_v2_state_adapter_test.dart`).
class LegacyV2BridgeTransport implements LegacyV2Channel {
  LegacyV2BridgeTransport(this._controller);

  final WebviewController _controller;
  StreamSubscription<dynamic>? _sub;

  /// AP-STUDIO-WEB-SURFACE-002, Phase 9 — the navigation trust boundary.
  /// `true` only while V2's own WebView is actually showing trusted V2
  /// content (checked by the host widget via [LegacyV2TrustBoundary] on
  /// every navigation event and written here). While `false`, every
  /// inbound message is dropped **before** it reaches any handler —
  /// enforced in one place ([_dispatch]) rather than relying on each of
  /// the five handlers to remember to check it. This does not disable
  /// the WebView itself (the user can still browse away and back); it
  /// only disables this transport's willingness to forward what the page
  /// says into the rest of the bridge.
  bool bridgeEnabled = true;

  /// Fired for a V2-originated module move, once V2's own `positions[id]`
  /// has been stable for two consecutive polls (~800ms) and differs from
  /// the last value this transport itself pushed back into V2 — the
  /// discrete "drag ended" boundary and first half of loop prevention
  /// (see [_kBridgeScript]'s own comment for the rest).
  void Function(V2ModuleMovedMessage message)? onModuleMoved;

  /// Fired on any change to V2's own selection/module-count/wire-count
  /// snapshot — display-only, unchanged from the POC-002 status bar.
  void Function(V2StatusMessage message)? onStatus;

  /// AP-DIAGRAM-V2-WEBVIEW-002 — fired once, the poll tick after a new
  /// entry appears in V2's own `MODULES` array (i.e. after
  /// `commitAddModule` has already run — V2 has no "about to create"
  /// event to hook, same rationale as `moduleMoved`'s stabilization
  /// detection).
  void Function(V2ModuleCreatedMessage message)? onModuleCreated;

  /// AP-DIAGRAM-V2-WEBVIEW-002 — fired once, the poll tick after an id
  /// that was previously present in `MODULES` is no longer found there
  /// (i.e. after `delModule` has already run).
  void Function(V2ModuleDeletedMessage message)? onModuleDeleted;

  /// AP-DIAGRAM-V2-WEBVIEW-002 — fired when an already-known module's
  /// `label`/`cat`/`sub` differs from the previous poll's snapshot (i.e.
  /// after `saveModProps` has already run).
  void Function(V2ModulePropertiesChangedMessage message)?
      onModulePropertiesChanged;

  /// AP-DIAGRAM-V2-WEBVIEW-003 — fired once, the poll tick after a new
  /// entry appears in V2's own `WIRES` array (i.e. after `handleWireTerm`
  /// has already created it — V2 has no "about to create a wire" event).
  /// Wire *editing* is deliberately not detected — only creation, per
  /// this task's scope.
  void Function(V2WireCreatedMessage message)? onWireCreated;

  /// AP-DIAGRAM-V2-BRIDGE-004 — fired once, the poll tick after a
  /// previously-present id is no longer found in V2's own `WIRES` array
  /// (i.e. after `deleteSelectedWire` has already run).
  void Function(V2WireDeletedMessage message)? onWireDeleted;

  /// AP-DIAGRAM-V2-BRIDGE-004 — fired whenever V2's own `selW` (the
  /// currently selected wire OBJECT, not just an id — `app.js` scope)
  /// changes identity, including to/from no selection.
  void Function(V2WireSelectionChangedMessage message)? onWireSelectionChanged;

  /// AP-DIAGRAM-V2-BRIDGE-009 — fired whenever V2's own `selM` (the
  /// currently selected module id, `js/ui/inspector.js`) changes,
  /// including to/from no selection. Symmetric with
  /// [onWireSelectionChanged] — V2 never has a module and a wire selected
  /// at once (`selectModule`/`selWire` each clear the other's global),
  /// and V2 has no multi-select for modules either (`selM` is a single
  /// id, toggled by clicking the same module again — confirmed by
  /// reading `inspector.js` directly), so this mirrors the exact same
  /// single-id shape [onWireSelectionChanged] already uses.
  void Function(V2ModuleSelectionChangedMessage message)?
      onModuleSelectionChanged;

  /// AP-DIAGRAM-V2-BRIDGE-005 — fired when an already-known wire's
  /// `lbl`/`c` differs from the previous poll's snapshot (i.e. after V2's
  /// own `saveWireProps()` has already run and closed the modal). Mirrors
  /// [onModulePropertiesChanged]'s detection shape exactly — V2 mutates
  /// the wire object in place on Save, so this is a diff against a
  /// per-wire `{lbl, c}` snapshot, not an id-presence check.
  void Function(V2WirePropertiesChangedMessage message)?
      onWirePropertiesChanged;

  /// AP-DIAGRAM-V2-BRIDGE-006 — fired whenever V2's own selected-wire-id +
  /// meter-mode pair changes (poll-diffed, same rationale as every other
  /// detector in this transport — V2 raises no "measurement requested"
  /// event of its own; `updateMeter()` is a synchronous local lookup, see
  /// the simulation bridge architecture doc §1). Only fires while a wire
  /// is selected — V2's own `updateMeter()` is itself a no-op with no
  /// selection (`if (!selW) return;`), so there is nothing to request.
  void Function(V2MeasurementRequestedMessage message)? onMeasurementRequested;

  /// PRODUCT-READINESS-008 — fired whenever V2's own live switch/key
  /// state changes (poll-diffed, same rationale as [onMeasurementRequested]
  /// above).
  void Function(V2OperatingStateChangedMessage message)?
      onOperatingStateChanged;

  /// AP-DIAGRAM-V2-BRIDGE-003, Phase 4 — fired when V2's own "Save"
  /// button is clicked, once [interceptV2Save] has been applied. Never
  /// fires before that call, since V2's original `saveLayout` (a plain
  /// file download) is still in effect until then.
  void Function()? onSaveRequested;

  /// OEP-STUDIO-BRANDING-V1 — fired when the engineering toolbar's own
  /// Trace/Measure dropdown items are clicked (`js/ui/toolbar.js`'s
  /// `toolbarSendEngineeringCommand`). These two groups are the only
  /// ones in that toolbar backed by real FLUTTER logic (the actual
  /// `TraceController`/`MultimeterController`, not anything V2's own JS
  /// can reach) rather than a V2-native function — [command] is one of
  /// a small, fixed, real set (`trace.physical`/`trace.conducting`/
  /// `trace.currentFlow`/`trace.fromSource`/`trace.clear`/
  /// `measure.voltageDc`/`measure.voltageAc`/`measure.resistance`/
  /// `measure.continuity`/`measure.diode`/`measure.open`), never a
  /// free-form command string interpreted as code.
  void Function(String command)? onEngineeringCommand;

  Future<void> attach() async {
    await _controller.addScriptToExecuteOnDocumentCreated(
      legacyV2BridgeScript('window.chrome.webview.postMessage(s)'),
    );
    _sub = _controller.webMessage.listen(_onRawMessage);
  }

  void _onRawMessage(dynamic raw) {
    final Map<String, dynamic> envelope = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : Map<String, dynamic>.from(raw as Map);
    // AP-DIAGRAM-V2-WEBVIEW-003 bugfix — a single poll tick that detects
    // more than one event (e.g. a module created and then immediately
    // wired up within the same ~400ms window) used to send one
    // `postMessage` per event. WebView2 does not guarantee that separate
    // `postMessage` calls arrive at this listener in the order they were
    // sent — observed live: a wire's relationship commands landed on the
    // Engine undo stack *before* the new module's own creation command,
    // so a single undo hit the module instead of the wire. The injected
    // script now batches every event from one tick into a single
    // `type: 'batch'` message (`payload` is an ordered array of
    // envelopes), so ordering is guaranteed by construction — there is
    // only one native round trip per tick to begin with.
    if (envelope['type'] == 'batch') {
      for (final entry in envelope['payload'] as List<dynamic>) {
        _dispatch(Map<String, dynamic>.from(entry as Map));
      }
      return;
    }
    _dispatch(envelope);
  }

  void _dispatch(Map<String, dynamic> envelope) {
    if (!bridgeEnabled) return;
    final type = envelope['type'] as String?;
    final payload = envelope['payload'] as Map<String, dynamic>?;
    if (payload == null) return;
    switch (type) {
      case 'moduleMoved':
        onModuleMoved?.call(V2ModuleMovedMessage.fromJson(payload));
      case 'v2Status':
        onStatus?.call(V2StatusMessage.fromJson(payload));
      case 'moduleCreated':
        onModuleCreated?.call(V2ModuleCreatedMessage.fromJson(payload));
      case 'moduleDeleted':
        onModuleDeleted?.call(V2ModuleDeletedMessage.fromJson(payload));
      case 'modulePropertiesChanged':
        onModulePropertiesChanged
            ?.call(V2ModulePropertiesChangedMessage.fromJson(payload));
      case 'wireCreated':
        onWireCreated?.call(V2WireCreatedMessage.fromJson(payload));
      case 'wireDeleted':
        onWireDeleted?.call(V2WireDeletedMessage.fromJson(payload));
      case 'wireSelectionChanged':
        onWireSelectionChanged
            ?.call(V2WireSelectionChangedMessage.fromJson(payload));
      case 'moduleSelectionChanged':
        onModuleSelectionChanged
            ?.call(V2ModuleSelectionChangedMessage.fromJson(payload));
      case 'wirePropertiesChanged':
        onWirePropertiesChanged
            ?.call(V2WirePropertiesChangedMessage.fromJson(payload));
      case 'measurementRequested':
        onMeasurementRequested
            ?.call(V2MeasurementRequestedMessage.fromJson(payload));
      case 'operatingStateChanged':
        onOperatingStateChanged
            ?.call(V2OperatingStateChangedMessage.fromJson(payload));
      case 'saveRequested':
        onSaveRequested?.call();
      case 'engineeringCommand':
        final command = payload['command'] as String?;
        if (command != null) onEngineeringCommand?.call(command);
    }
  }

  /// AP-STUDIO-WEB-SURFACE-002, Phase 9 — the outbound half of the trust
  /// boundary: every method below that writes an OEP-authoritative
  /// result into V2 routes through here, so a stray `executeScript` call
  /// while [bridgeEnabled] is `false` (e.g. a queued undo firing after
  /// the user has already navigated away) is a no-op rather than
  /// executing script against whatever page is currently loaded.
  Future<void> _executeIfEnabled(String script) {
    if (!bridgeEnabled) return Future<void>.value();
    return _controller.executeScript(script);
  }

  /// Sends an OEP-authoritative result back into V2's own runtime state
  /// (`positions[id]`, the card's `style.left/top`, and a redraw) via the
  /// `__oepBridgeApplyAuthoritative` function the injected script defines
  /// — never by writing to a V2 file. This is also the second half of
  /// loop prevention: the injected script records this value as
  /// already-synced so its own poller won't re-emit `moduleMoved` for it.
  @override
  Future<void> sendAuthoritativeModulePosition(
      String v2ModuleId, double x, double y) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyAuthoritative && window.__oepBridgeApplyAuthoritative('
      '${jsonEncode(v2ModuleId)}, $x, $y)',
    );
  }

  /// AP-DIAGRAM-V2-WEBVIEW-002, Phase 8 (property edit) — pushes OEP's
  /// authoritative `displayName` back into V2's `MODULES[id].label` (the
  /// only module property this task bridges — see
  /// `docs/DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md` §7 for why `cat`/`sub`/
  /// `exit`/`terminals` are not included) and rebuilds its card, via the
  /// same "authoritative apply also updates the loop-prevention sync
  /// record" pattern as [sendAuthoritativeModulePosition].
  @override
  Future<void> sendAuthoritativeModuleLabel(String v2ModuleId, String label) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyModuleLabel && window.__oepBridgeApplyModuleLabel('
      '${jsonEncode(v2ModuleId)}, ${jsonEncode(label)})',
    );
  }

  /// AP-DIAGRAM-V2-WEBVIEW-002, Phase 12 (undo-of-delete) — re-injects a
  /// module V2 already removed, using the adapter-supplied
  /// `(label, category)` it stashed at creation time
  /// (`EngineeringNode.metadata`) — reconstructs enough of V2's own
  /// module shape for `MODULES.push`/`placeCards`/`drawWires` to render
  /// it again.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-011 — [notes] is passed through when
  /// `metadata['notes']` is stored, so notes survive document
  /// reload/undo-of-delete the same way label/category already did.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-007 — [terminals] (also stashed in
  /// `EngineeringNode.metadata`, § [V2ModuleCreatedMessage.terminals])
  /// closes the gap this doc comment used to describe as an intentional
  /// omission: without it, every module reconstructed by this call
  /// rendered with zero terminal dots, which is what made a reopened
  /// document look like its modules had lost their pins entirely.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-009 — [exit] (§
  /// [V2ModuleCreatedMessage.exit]) closes a second, related gap: this
  /// call used to always reconstruct a module with a hardcoded `'down'`
  /// exit side regardless of its real one, silently rerouting every wire
  /// on any module that wasn't already 'down' the moment it was
  /// reconstructed — which, combined with clearing V2's display before
  /// every reseed, made a reopened document's wiring look wrong even
  /// though every module's *position* was correct.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-SAVE-010 — [connector]/[vertical] (§
  /// [V2ModuleCreatedMessage.connector]) close a third gap: a
  /// reconstructed connector module lost its whole stacked-pin layout
  /// (falling back to a plain module card), or — if it happened to keep
  /// rendering as a connector some other way — silently reverted from a
  /// vertical connector back to horizontal on every reopen, since neither
  /// flag was ever part of this call before.
  @override
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes = '',
      List<Map<String, String>> terminals = const [],
      String exit = '',
      bool? connector,
      bool? vertical,
      String? labelPos,
      String? pinLabelPos,
      String? subLabelPos,
      String? sub,
      String? labelJustify,
      String? kind,
      String? bulbStyle,
      String? bulbColor,
      bool? flipped}) {
    return _executeIfEnabled(
      'window.__oepBridgeRestoreModule && window.__oepBridgeRestoreModule('
      '${jsonEncode(v2ModuleId)}, ${jsonEncode(label)}, ${jsonEncode(category)}, $x, $y, ${jsonEncode(notes)}, ${jsonEncode(terminals)}, ${jsonEncode(exit)}, ${jsonEncode(connector)}, ${jsonEncode(vertical)}, ${jsonEncode(labelPos)}, ${jsonEncode(pinLabelPos)}, ${jsonEncode(subLabelPos)}, ${jsonEncode(sub)}, ${jsonEncode(labelJustify)}, ${jsonEncode(kind)}, ${jsonEncode(bulbStyle)}, ${jsonEncode(bulbColor)}, ${jsonEncode(flipped)})',
    );
  }

  /// AP-DIAGRAM-V2-WEBVIEW-002, Phase 12 (undo-of-create) — removes a
  /// module from V2's own runtime state via the injected
  /// `__oepBridgeRemoveModule`, for the "create → undo → V2 disappears"
  /// case, where the OEP node the create produced no longer exists for
  /// [LegacyV2StateAdapter.resyncLastBridgedModuleToV2] to read back from.
  @override
  Future<void> removeModuleFromV2(String v2ModuleId) {
    return _executeIfEnabled(
      'window.__oepBridgeRemoveModule && window.__oepBridgeRemoveModule(${jsonEncode(v2ModuleId)})',
    );
  }

  /// AP-DIAGRAM-V2-WEBVIEW-003, Phase 7 — writes OEP's authoritative
  /// label/color back onto the V2 wire object right after creation (a
  /// one-shot confirmation, not ongoing editing — this task does not
  /// poll for wire property changes at all, unlike modules).
  @override
  Future<void> confirmWireCreated(String v2WireId, String label, String color) {
    return _executeIfEnabled(
      'window.__oepBridgeConfirmWireCreated && window.__oepBridgeConfirmWireCreated('
      '${jsonEncode(v2WireId)}, ${jsonEncode(label)}, ${jsonEncode(color)})',
    );
  }

  /// AP-DIAGRAM-V2-WEBVIEW-003, Phase 10 (undo-of-create) — removes a
  /// wire from V2's own runtime state, for the "create → undo → V2's
  /// wire disappears" case, mirroring [removeModuleFromV2].
  @override
  Future<void> removeWireFromV2(String v2WireId) {
    return _executeIfEnabled(
      'window.__oepBridgeRemoveWire && window.__oepBridgeRemoveWire(${jsonEncode(v2WireId)})',
    );
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 4/7 — seeds a wire into V2's own
  /// `WIRES` array from OEP-authoritative data (used only during
  /// `LegacyV2StateAdapter.initializeFromDocument`/undo-of-delete resync).
  ///
  /// AP-DIAGRAM-V2-BRIDGE-011 — [fromTerminal]/[toTerminal] are now
  /// passed through when the bridged relationship has stored
  /// `metadata['sourcePort']`/`['targetPort']` (§ `_handleWireCreated`'s
  /// own doc comment for why that's a real, non-fabricated Engine
  /// convention, not a placeholder). Defaulted to `''` (unchanged
  /// behavior) for a relationship that predates this task or genuinely
  /// has no stored terminal — the injected function never fabricates a
  /// value it wasn't given.
  @override
  Future<void> restoreWire(
    String v2WireId,
    String fromModuleId,
    String toModuleId,
    String label,
    String color, {
    String fromTerminal = '',
    String toTerminal = '',
    String fromExit = '',
    String toExit = '',
    bool cable = false,
  }) {
    return _executeIfEnabled(
      'window.__oepBridgeRestoreWire && window.__oepBridgeRestoreWire('
      '${jsonEncode(v2WireId)}, ${jsonEncode(fromModuleId)}, ${jsonEncode(toModuleId)}, '
      '${jsonEncode(label)}, ${jsonEncode(color)}, ${jsonEncode(fromTerminal)}, ${jsonEncode(toTerminal)}, '
      '${jsonEncode(fromExit)}, ${jsonEncode(toExit)}, ${jsonEncode(cable)})',
    );
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 8 — clears V2's entire runtime
  /// state (`MODULES`/`WIRES`/`positions`/`wireRoutes`) before
  /// re-seeding from a (newly active) document — the mechanism that
  /// prevents document A's modules/wires from lingering, and being
  /// mutable, once document B becomes active.
  @override
  Future<void> clearAllSurfaces() {
    return _executeIfEnabled(
        'window.__oepBridgeClearAll && window.__oepBridgeClearAll()');
  }

  /// AP-DIAGRAM-V2-BRIDGE-003, Phase 4 — intercepts V2's own "Save"
  /// button (Option B of that task's own preferred-solutions list:
  /// "intercept at the WebView boundary without modifying V2 source").
  /// Reassigns the global `saveLayout` function — the same identifier
  /// V2's own `<button onclick="saveLayout()">` looks up **by name at
  /// click time** (confirmed by reading `index.html` directly: a plain
  /// inline `onclick`, not a captured function reference) — to post a
  /// `saveRequested` message instead of V2's original file-download
  /// behavior. Must be called *after* V2's own script has already
  /// defined `saveLayout` (i.e. after the page has loaded, not via
  /// `addScriptToExecuteOnDocumentCreated`, which runs *before* V2's own
  /// scripts and would just be overwritten when V2's own top-level
  /// `function saveLayout(){...}` declaration runs). V2's own
  /// `js/storage/project-saver.js` file is never modified — this is a
  /// runtime reassignment in the already-loaded page, gone the moment
  /// the page reloads or navigates (re-applied by the caller each time,
  /// same as every other post-ready `executeScript` call in this class).
  @override
  Future<void> interceptV2Save() {
    return _executeIfEnabled(
        'window.__oepBridgeInterceptSave && window.__oepBridgeInterceptSave()');
  }

  /// AP-DIAGRAM-V2-BRIDGE-003, Phase 5 — feedback for the intercepted
  /// Save, reusing V2's own existing `showToast(message, kind)` function
  /// (already used throughout V2 for "Module added"/"Wire deleted"/etc.)
  /// rather than inventing new V2-side UI.
  @override
  Future<void> reportSaveResult(bool success, String message) {
    return _executeIfEnabled(
      'window.__oepBridgeReportSaveResult && window.__oepBridgeReportSaveResult('
      '${jsonEncode(success)}, ${jsonEncode(message)})',
    );
  }

  /// AP-DIAGRAM-V2-BRIDGE-006 — writes an OEP-authoritative measurement
  /// result directly into V2's own LCD DOM elements (the same ids
  /// `updateMeter()` itself writes — see `__oepBridgeApplyMeasurementResult`
  /// in the injected script), for the wire/mode this was requested for.
  /// [displayValue]/[unit]/[note] are pre-formatted V2-vocabulary strings
  /// (a plain number, `'OPN'`, `'OL'`, or `'—'`) — the adapter owns all
  /// translation from `MeasurementResult` semantics (§8 of the simulation
  /// bridge doc); this transport stays exactly as OEP-unaware as every
  /// other method here. The injected function itself discards a stale
  /// result (V2 already moved on to a different wire/mode by the time it
  /// arrives) rather than overwriting what the user is currently looking
  /// at with an answer to a question V2 no longer cares about.
  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyMeasurementResult && window.__oepBridgeApplyMeasurementResult('
      '${jsonEncode(v2WireId)}, ${jsonEncode(mode)}, ${jsonEncode(displayValue)}, '
      '${jsonEncode(unit)}, ${jsonEncode(note)})',
    );
  }

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — `executeScript` already JSON-decodes
  /// WebView2's own JSON-encoded transport of the script's result (see
  /// `webview_flutter_windows`'s own implementation — `jsonDecode(data as
  /// String)`), so a JS object return value arrives here already as a
  /// `Map`. Deliberately bypasses [_executeIfEnabled]/[bridgeEnabled]'s
  /// silent-no-op convention (every other method here fires-and-forgets
  /// an OEP-authoritative *write* into V2, where "do nothing while
  /// untrusted" is correct; this is a *read* whose caller — the Save flush
  /// barrier — must be able to tell "disabled/unreachable" apart from
  /// "nothing changed," so it returns `null` explicitly instead).
  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async {
    if (!bridgeEnabled) return null;
    final result = await _controller.executeScript(
        'window.__oepBridgeCaptureSaveSnapshot && window.__oepBridgeCaptureSaveSnapshot()');
    if (result == null) return null;
    return V2SaveSnapshot.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// AP-DMM-BRIDGE-001 — queries the LIVE V2 electrical solver
  /// (`LiveSim.readWireMeasurement`, via `window.__oepBridgeQueryLive
  /// Measurement`) for a real, currently-solved reading on wire
  /// [v2WireId] in mode [v2Mode] (V2's own 'VDC'/'VAC'/'CONT'/'RES'/
  /// 'DIODE' codes). This is a READ, same rationale as
  /// [captureSaveSnapshot]: bypasses [_executeIfEnabled]'s fire-and-forget
  /// convention and returns `null` explicitly for "disabled/unreachable"
  /// so the caller can tell that apart from "the solver answered but the
  /// reading is open/OL" (which is a normal, non-null [V2LiveMeasurementResult]
  /// with `open: true`).
  @override
  Future<V2LiveMeasurementResult?> queryLiveMeasurement(
      String v2WireId, String v2Mode) async {
    if (!bridgeEnabled) return null;
    final result = await _controller.executeScript(
      'window.__oepBridgeQueryLiveMeasurement && window.__oepBridgeQueryLiveMeasurement('
      '${jsonEncode(v2WireId)}, ${jsonEncode(v2Mode)})',
    );
    if (result == null) return null;
    return V2LiveMeasurementResult.fromJson(
        Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyWireRouteOffsets && window.__oepBridgeApplyWireRouteOffsets('
      '${jsonEncode(v2WireId)}, ${jsonEncode(offsets)})',
    );
  }

  /// PRODUCT-READINESS-009 §11/§21 — see [LegacyV2Channel.applyTraceHighlight].
  /// `window.__oepBridgeApplyTraceHighlight` is the injected bridge-script
  /// function (`legacy_v2_bridge_script.dart`) that actually sets V2's own
  /// `tracedWires`/marker CSS classes/`nativeFlowWires` and redraws.
  @override
  Future<void> applyTraceHighlight(
    List<String> wireIds,
    List<String> sourceModuleIds,
    List<String> returnModuleIds,
    List<String> blockedModuleIds,
    Map<String, int> currentFlowByWireId,
  ) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyTraceHighlight && window.__oepBridgeApplyTraceHighlight('
      '${jsonEncode(wireIds)}, ${jsonEncode(sourceModuleIds)}, ${jsonEncode(returnModuleIds)}, '
      '${jsonEncode(blockedModuleIds)}, ${jsonEncode(currentFlowByWireId)})',
    );
  }

  @override
  Future<void> clearTraceHighlight() {
    return _executeIfEnabled(
      'window.__oepBridgeClearTraceHighlight && window.__oepBridgeClearTraceHighlight()',
    );
  }

  /// PRODUCT-READINESS-010 §17 — see [LegacyV2Channel.fitToTraceHighlight].
  @override
  Future<void> fitToTraceHighlight(List<String> nodeIds) {
    return _executeIfEnabled(
      'window.__oepBridgeFitToNodes && window.__oepBridgeFitToNodes(${jsonEncode(nodeIds)})',
    );
  }

  /// Transport-level escape hatch for one-off, non-mutating V2 calls that
  /// don't warrant their own message type — used for "Fit view"
  /// (`zReset()`, proven in POC-002, return value ignored) and for
  /// polling a plain expression's value (AP-DIAGRAM-V2-BRIDGE-SAVE-008's
  /// `_waitForV2Ready`, which reads it as a number). Not a general-purpose
  /// command channel: nothing above the transport should reach for this
  /// to implement new bridged operations.
  Future<dynamic> executeRawScript(String script) =>
      _controller.executeScript(script);

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}

/// The narrow "receive V2 module-moved events, push an authoritative
/// position back into V2" capability [LegacyV2StateAdapter] depends on —
/// implemented by [LegacyV2BridgeTransport] in production, and by a
/// lightweight fake in tests, so the adapter's dispatch/loop-prevention/
/// coordinate logic can be verified without a real `WebviewController`.
abstract class LegacyV2Channel {
  set onModuleMoved(void Function(V2ModuleMovedMessage message)? handler);
  set onModuleCreated(void Function(V2ModuleCreatedMessage message)? handler);
  set onModuleDeleted(void Function(V2ModuleDeletedMessage message)? handler);
  set onModulePropertiesChanged(
      void Function(V2ModulePropertiesChangedMessage message)? handler);
  set onWireCreated(void Function(V2WireCreatedMessage message)? handler);
  set onWireDeleted(void Function(V2WireDeletedMessage message)? handler);
  set onWireSelectionChanged(
      void Function(V2WireSelectionChangedMessage message)? handler);
  set onModuleSelectionChanged(
      void Function(V2ModuleSelectionChangedMessage message)? handler);
  set onWirePropertiesChanged(
      void Function(V2WirePropertiesChangedMessage message)? handler);
  set onMeasurementRequested(
      void Function(V2MeasurementRequestedMessage message)? handler);

  /// PRODUCT-READINESS-008 — fires whenever V2's own live switch/key
  /// state changes (poll-diffed the same way `onMeasurementRequested`
  /// is), so a host can translate it into an `ElectricalOperatingContext`
  /// for the native Engine.
  set onOperatingStateChanged(
      void Function(V2OperatingStateChangedMessage message)? handler);
  set onSaveRequested(void Function()? handler);

  /// § the concrete field's own doc comment on [LegacyV2BridgeTransport].
  set onEngineeringCommand(void Function(String command)? handler);

  Future<void> sendAuthoritativeModulePosition(
      String v2ModuleId, double x, double y);
  Future<void> sendAuthoritativeModuleLabel(String v2ModuleId, String label);
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes,
      List<Map<String, String>> terminals,
      String exit,
      bool? connector,
      bool? vertical,
      String? labelPos,
      String? pinLabelPos,
      String? subLabelPos,
      String? sub,
      String? labelJustify,
      String? kind,
      String? bulbStyle,
      String? bulbColor,
      bool? flipped});
  Future<void> removeModuleFromV2(String v2ModuleId);
  Future<void> confirmWireCreated(String v2WireId, String label, String color);
  Future<void> removeWireFromV2(String v2WireId);
  Future<void> restoreWire(
    String v2WireId,
    String fromModuleId,
    String toModuleId,
    String label,
    String color, {
    String fromTerminal,
    String toTerminal,
    String fromExit,
    String toExit,
    bool cable,
  });
  Future<void> clearAllSurfaces();
  Future<void> interceptV2Save();
  Future<void> reportSaveResult(bool success, String message);
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note);

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — the Save flush barrier's inbound
  /// half: a synchronous (awaitable), deterministic read of V2's CURRENT
  /// module/wire/route state, independent of the 400ms poller. `null`
  /// only if the WebView could not be reached at all (disposed, or
  /// [LegacyV2BridgeTransport.bridgeEnabled]/equivalent is `false`) — the
  /// caller must not treat that as "nothing changed."
  Future<V2SaveSnapshot?> captureSaveSnapshot();

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — reseeds V2's own `wireRoutes[id]`
  /// with OEP-authoritative segment offsets (document load, or resync
  /// after an Undo touching a route). An empty [offsets] clears the
  /// entry (V2's own Reset Route behavior).
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets);

  /// AP-DMM-BRIDGE-001 — queries the live V2 electrical solver for wire
  /// [v2WireId] in mode [v2Mode] (V2's own 'VDC'/'VAC'/'CONT'/'RES'/
  /// 'DIODE' codes). `null` only if the WebView/bridge could not be
  /// reached at all — a normal "reading is open/unreachable" answer is a
  /// non-null result with `open: true`, never `null`.
  Future<V2LiveMeasurementResult?> queryLiveMeasurement(
      String v2WireId, String v2Mode);

  /// PRODUCT-READINESS-009 §11 — pushes a native [TraceHighlightPlan]
  /// (already translated to V2 ids by the caller) into the real,
  /// unmodified V2 diagram rendering: [wireIds] become traced/glowing
  /// wires (V2's own `tracedWires` + `drawWires()` primitive, the same
  /// mechanism its own `PathHighlighter` already uses -- this call never
  /// invokes V2's own `CircuitTracer`/`PathFinder`), [sourceModuleIds]/
  /// [returnModuleIds]/[blockedModuleIds] get a distinct CSS marker class
  /// each, and [currentFlowByWireId] (wire id -> `+1`/`-1`, only ever
  /// populated for [TraceMode.currentFlow]) drives the real directional
  /// flow-overlay animation gated on genuinely solved current -- never
  /// V2's own legacy `VDC != 0` heuristic (§27/§41).
  Future<void> applyTraceHighlight(
    List<String> wireIds,
    List<String> sourceModuleIds,
    List<String> returnModuleIds,
    List<String> blockedModuleIds,
    Map<String, int> currentFlowByWireId,
  );

  /// §29 — returns the real diagram to its normal, unhighlighted state.
  Future<void> clearTraceHighlight();

  /// PRODUCT-READINESS-010 §17 — "Fit Circuit": pans/zooms the real,
  /// already-rendered V2 viewport to the bounding region of the real
  /// module cards named by [nodeIds] (already-translated V2 module ids).
  /// Never moves engineering objects, never touches persisted layout --
  /// pure transient viewport state (`scale`/`tx`/`ty`), reusing the same
  /// `applyT()`/`drawWires()` primitives V2's own existing "Fit view"
  /// (`zReset()`) already uses, just scoped to a bounding box over
  /// [nodeIds] instead of the whole canvas.
  Future<void> fitToTraceHighlight(List<String> nodeIds);
}

/// AP-DMM-BRIDGE-001 — one endpoint of a [V2LiveMeasurementResult]: the
/// module a wire's terminal belongs to, plus the terminal/pin ref itself
/// when the wire carried one (`w.from.t`/`w.to.t` — the SAME pin-ref
/// convention used everywhere else in V2, including
/// `sourcePort`/`targetPort` on the OEP relationship metadata this wire
/// bridges to). `terminalId` is `null` only for a wire whose endpoint
/// genuinely has no terminal ref recorded (rare — most V2 wires always
/// carry one).
class V2MeasurementEndpoint {
  const V2MeasurementEndpoint({required this.moduleId, this.terminalId});

  factory V2MeasurementEndpoint.fromJson(Map<String, dynamic> json) =>
      V2MeasurementEndpoint(
        moduleId: json['moduleId'] as String,
        terminalId: json['terminalId'] as String?,
      );

  final String moduleId;
  final String? terminalId;
}

/// AP-DMM-BRIDGE-001 — the decoded result of
/// `window.__oepBridgeQueryLiveMeasurement()`: a structured reading from
/// the LIVE V2 electrical solver (`LiveSim.readWireMeasurement`), not a
/// display-formatted string. This is the DMM bridge's own authoritative
/// answer — deliberately never collapses "open/unreachable" into a
/// fabricated `0.0` (see [open]); a consumer must check [open]/[status]
/// before trusting [value].
class V2LiveMeasurementResult {
  const V2LiveMeasurementResult({
    required this.status,
    required this.readingType,
    required this.value,
    required this.unit,
    required this.open,
    required this.overload,
    required this.fault,
    required this.note,
    required this.source,
    required this.reference,
    required this.solvedAt,
  });

  factory V2LiveMeasurementResult.fromJson(Map<String, dynamic> json) {
    final rawSource = json['source'] as Map?;
    final rawReference = json['reference'] as Map?;
    return V2LiveMeasurementResult(
      status: json['status'] as String? ?? 'error',
      readingType: json['readingType'] as String? ?? 'voltage',
      value: (json['value'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? '',
      open: json['open'] as bool? ?? true,
      overload: json['overload'] as bool? ?? false,
      fault: json['fault'] as bool? ?? false,
      note: json['note'] as String? ?? '',
      source: rawSource == null
          ? null
          : V2MeasurementEndpoint.fromJson(Map<String, dynamic>.from(rawSource)),
      reference: rawReference == null
          ? null
          : V2MeasurementEndpoint.fromJson(
              Map<String, dynamic>.from(rawReference)),
      solvedAt: (json['solvedAt'] as num?)?.toInt(),
    );
  }

  /// 'ok' or 'error' — 'error' means the solver could not answer at all
  /// (unknown wire, unsupported mode) and every other field is a safe
  /// placeholder, NOT a real reading.
  final String status;

  /// 'voltage' | 'voltageAc' | 'continuity' | 'resistance' | 'diode'.
  final String readingType;

  /// The measured value, or `null` when [open] is `true` (or [status] is
  /// 'error') — never a fabricated `0.0` standing in for "no reading".
  final double? value;

  final String unit;

  /// `true` = open circuit / no continuity / OL — the authoritative
  /// distinction from a genuine `value == 0.0`.
  final bool open;

  final bool overload;
  final bool fault;
  final String note;

  final V2MeasurementEndpoint? source;
  final V2MeasurementEndpoint? reference;

  /// `ElectricalSolver`'s own `Date.now()` at solve time — lets a caller
  /// detect a stale answer if it wants to (not currently enforced by any
  /// caller; see the bridge's own "measurement always triggers a fresh
  /// solve" contract instead, which makes staleness structurally
  /// impossible for this call).
  final int? solvedAt;
}

/// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — the decoded result of
/// `window.__oepBridgeCaptureSaveSnapshot()`, in V2's own vocabulary
/// (verbatim ids/fields) — [LegacyV2StateAdapter.flushBeforeSave] is what
/// gives this OEP meaning, exactly like every other message in this file.
class V2SaveSnapshot {
  const V2SaveSnapshot(
      {required this.modules, required this.wires, required this.wireRoutes});

  factory V2SaveSnapshot.fromJson(Map<String, dynamic> json) {
    final rawModules =
        Map<String, dynamic>.from(json['modules'] as Map? ?? const {});
    final rawWires =
        Map<String, dynamic>.from(json['wires'] as Map? ?? const {});
    final rawRoutes =
        Map<String, dynamic>.from(json['wireRoutes'] as Map? ?? const {});
    return V2SaveSnapshot(
      modules: rawModules.map((id, v) => MapEntry(
          id, V2SnapshotModule.fromJson(Map<String, dynamic>.from(v as Map)))),
      wires: rawWires.map((id, v) => MapEntry(
          id, V2SnapshotWire.fromJson(Map<String, dynamic>.from(v as Map)))),
      wireRoutes: rawRoutes.map((id, v) => MapEntry(
            id,
            Map<String, dynamic>.from(v as Map).map((segIdx, offset) =>
                MapEntry(int.parse(segIdx), (offset as num).toDouble())),
          )),
    );
  }

  /// v2ModuleId -> current module snapshot.
  final Map<String, V2SnapshotModule> modules;

  /// v2WireId -> current wire snapshot.
  final Map<String, V2SnapshotWire> wires;

  /// v2WireId -> (segmentIndex -> scalar offset). A wire with no manual
  /// route adjustment (or one that was Reset) is simply absent here.
  final Map<String, Map<int, double>> wireRoutes;
}

class V2SnapshotModule {
  const V2SnapshotModule(
      {required this.label,
      required this.category,
      required this.notes,
      required this.x,
      required this.y,
      this.terminals = const [],
      this.exit = '',
      this.connector,
      this.vertical,
      this.labelPos = '',
      this.pinLabelPos = '',
      this.subLabelPos = '',
      this.sub = '',
      this.labelJustify = '',
      this.kind = '',
      this.bulbStyle = '',
      this.bulbColor = '',
      this.flipped = false});

  factory V2SnapshotModule.fromJson(Map<String, dynamic> json) =>
      V2SnapshotModule(
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        terminals: _parseTerminals(json['terminals']),
        exit: json['exit'] as String? ?? '',
        connector: json['connector'] as bool?,
        vertical: json['vertical'] as bool?,
        labelPos: json['labelPos'] as String? ?? '',
        pinLabelPos: json['pinLabelPos'] as String? ?? '',
        subLabelPos: json['subLabelPos'] as String? ?? '',
        sub: json['sub'] as String? ?? '',
        labelJustify: json['labelJustify'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        bulbStyle: json['bulbStyle'] as String? ?? '',
        bulbColor: json['bulbColor'] as String? ?? '',
        flipped: json['flipped'] as bool? ?? false,
      );

  final String label;
  final String category;
  final String notes;
  final double x;
  final double y;

  /// AP-MODULE-LAYOUT-001 — V2's own `m.labelPos`/`m.pinLabelPos`
  /// ('top'/'bottom'/'left'/'right', or '' for "use the auto default" —
  /// buildCard/buildStdCard, renderer.js) verbatim, same shape/rationale
  /// as [exit].
  final String labelPos;
  final String pinLabelPos;
  final String subLabelPos;

  /// AP-MODULE-LABEL-WRAP-001 — V2's own `m.sub` (a subtitle shown under
  /// the module's main label, e.g. "12V 30A") verbatim. Pre-existing
  /// field, never actually threaded through this bridge before — see
  /// `__oepBridgeRestoreModule`'s own doc comment on `hasSub` for why
  /// this was a genuine, silent-data-loss gap independent of this task's
  /// own label-wrap/justify work.
  final String sub;

  /// AP-MODULE-LABEL-WRAP-001 — V2's own `m.labelJustify` ('left'/
  /// 'right', or '' for the default 'center' — buildCard, renderer.js),
  /// same shape/rationale as [labelPos].
  final String labelJustify;

  /// AP-MODULE-KIND-001 — V2's own special-render flag (`m.bulb`/
  /// `m.diode`/`m.battery`/`m.starterMotor`/`m.solenoid`/
  /// `m.groundedSwitch`/`m.thermistor` — whichever one `buildCard`,
  /// renderer.js, dispatches on), collapsed to a single string (empty
  /// means "no special kind, plain card"). Same shape/rationale as
  /// [labelPos].
  final String kind;

  /// AP-BULB-GENERIC-001 — a bulb's own lit-color choice (`m.bulbColor`)
  /// and incandescent-vs-color style (`m.bulbStyle`), same shape/
  /// rationale as [labelPos]; empty means "not set" (incandescent
  /// default, no color chosen).
  final String bulbStyle;
  final String bulbColor;

  /// AP-BULB-GENERIC-001 — which side a bulb's terminals sit on
  /// (`m.flipped`), same shape/rationale as [connector]/[vertical].
  final bool flipped;

  /// § [V2ModuleCreatedMessage.exit] — same shape, captured via the Save
  /// flush barrier's snapshot instead of the live poller.
  final String exit;

  /// § [V2ModuleCreatedMessage.terminals] — same shape, captured via the
  /// Save flush barrier's snapshot instead of the live poller.
  final List<Map<String, String>> terminals;

  /// § [V2ModuleCreatedMessage.connector]/[V2ModuleCreatedMessage.vertical].
  final bool? connector;
  final bool? vertical;
}

class V2SnapshotWire {
  const V2SnapshotWire({
    required this.fromModuleId,
    required this.fromTerminal,
    required this.toModuleId,
    required this.toTerminal,
    required this.label,
    required this.color,
    this.fromExit = '',
    this.toExit = '',
    this.cable = false,
  });

  factory V2SnapshotWire.fromJson(Map<String, dynamic> json) => V2SnapshotWire(
        fromModuleId: json['fromModuleId'] as String,
        fromTerminal: json['fromTerminal'] as String? ?? '',
        toModuleId: json['toModuleId'] as String,
        toTerminal: json['toTerminal'] as String? ?? '',
        label: json['label'] as String? ?? '',
        color: json['color'] as String? ?? '',
        fromExit: json['fromExit'] as String? ?? '',
        toExit: json['toExit'] as String? ?? '',
        cable: json['cable'] as bool? ?? false,
      );

  final String fromModuleId;
  final String fromTerminal;
  final String toModuleId;
  final String toTerminal;
  final String label;
  final String color;

  /// AP-WIRE-EXIT-OVERRIDE-001 — V2's own `w.fromExit` (which side this
  /// specific wire's first bend leaves its source terminal from,
  /// overriding the module/splice's own default `exit` side) verbatim,
  /// same shape/rationale as [V2ModuleCreatedMessage.exit] — captured via
  /// the Save flush barrier's snapshot instead of the live poller.
  final String fromExit;

  /// AP-SPLICE-INSPECTOR-001 — same idea for the DESTINATION end (§
  /// route()'s own doc comment, renderer.js, for why both ends need this).
  final String toExit;

  /// AP-BATTERY-CABLE-001 — V2's own `w.cable` (thick Red/Black
  /// battery-cable rendering, renderer.js) verbatim.
  final bool cable;
}

class V2ModuleMovedMessage {
  const V2ModuleMovedMessage(
      {required this.v2ModuleId, required this.x, required this.y});

  factory V2ModuleMovedMessage.fromJson(Map<String, dynamic> json) =>
      V2ModuleMovedMessage(
        v2ModuleId: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  final String v2ModuleId;
  final double x;
  final double y;
}

class V2ModuleCreatedMessage {
  const V2ModuleCreatedMessage({
    required this.v2ModuleId,
    required this.label,
    required this.category,
    required this.x,
    required this.y,
    this.terminals = const [],
    this.exit = '',
    this.connector,
    this.vertical,
    this.labelPos = '',
    this.pinLabelPos = '',
    this.subLabelPos = '',
    this.sub = '',
    this.labelJustify = '',
    this.kind = '',
    this.bulbStyle = '',
    this.bulbColor = '',
    this.flipped,
  });

  factory V2ModuleCreatedMessage.fromJson(Map<String, dynamic> json) =>
      V2ModuleCreatedMessage(
        v2ModuleId: json['id'] as String,
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        terminals: _parseTerminals(json['terminals']),
        exit: json['exit'] as String? ?? '',
        connector: json['connector'] as bool?,
        vertical: json['vertical'] as bool?,
        labelPos: json['labelPos'] as String? ?? '',
        pinLabelPos: json['pinLabelPos'] as String? ?? '',
        subLabelPos: json['subLabelPos'] as String? ?? '',
        sub: json['sub'] as String? ?? '',
        labelJustify: json['labelJustify'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        bulbStyle: json['bulbStyle'] as String? ?? '',
        bulbColor: json['bulbColor'] as String? ?? '',
        flipped: json['flipped'] as bool?,
      );

  final String v2ModuleId;
  final String label;
  final String category;
  final double x;
  final double y;

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-009 — V2's own `m.exit` (`'up'`/`'down'`/
  /// `'left'`/`'right'` — which side of the card its wires leave from),
  /// verbatim, at the moment this module was observed as created.
  /// Stashed the same way [terminals] is, and for the same reason: it was
  /// never captured anywhere before, so `restoreModule` always hardcoded
  /// `'down'` regardless of a module's real exit side — silently
  /// rerouting every wire on every module that wasn't already 'down' the
  /// moment a document was reopened (or, after AP-DIAGRAM-V2-BRIDGE-
  /// SAVE-008 started clearing V2's display before every reseed, on
  /// *every* document open, not just a genuine undo-of-delete).
  final String exit;

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-007 — V2's own terminal list (`m.terminals`,
  /// each a raw `{n, c}` pair — terminal name and color code, verbatim
  /// V2 vocabulary, unchanged/uninterpreted by OEP) at the moment this
  /// module was observed as created. Stashed into the OEP node's own
  /// metadata (`_handleModuleCreated`) so a later `restoreModule` call —
  /// on document reopen, or after an Engine undo-of-delete — can
  /// reconstruct a module V2 actually renders with terminal dots, instead
  /// of the empty list `restoreModule` used to always default to.
  final List<Map<String, String>> terminals;

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-010 — V2's own `m.connector`/`m.vertical`
  /// flags (whether this card renders as a connector's stacked-pin
  /// layout at all, and if so, standing vertically). `null` means "V2
  /// reported no value" — shouldn't happen for a live create event (the
  /// poller always sends a real `true`/`false`), but kept nullable for
  /// symmetry with how a *restored* module (§ `EngineeringNode.metadata`)
  /// legitimately has no recorded value for an older document. Without
  /// this, a reconstructed connector either lost its whole IN/OUT
  /// pin-stack layout entirely, or (if `connector` alone happened to
  /// survive) silently reverted from vertical to horizontal on every
  /// reopen.
  final bool? connector;
  final bool? vertical;

  /// § [V2SnapshotModule.labelPos]/[V2SnapshotModule.pinLabelPos]/
  /// [V2SnapshotModule.subLabelPos]/[V2SnapshotModule.sub]/
  /// [V2SnapshotModule.labelJustify] — same shape, captured via the live
  /// change poller instead of the Save flush barrier's snapshot.
  final String labelPos;
  final String pinLabelPos;
  final String subLabelPos;
  final String sub;
  final String labelJustify;

  /// § [V2SnapshotModule.kind] — same shape, captured via the live change
  /// poller instead of the Save flush barrier's snapshot.
  final String kind;

  /// § [V2SnapshotModule.bulbStyle]/[V2SnapshotModule.bulbColor]/
  /// [V2SnapshotModule.flipped] — same shape, captured via the live
  /// change poller instead of the Save flush barrier's snapshot.
  final String bulbStyle;
  final String bulbColor;
  final bool? flipped;
}

List<Map<String, String>> _parseTerminals(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((t) => t.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
      .toList();
}

class V2ModuleDeletedMessage {
  const V2ModuleDeletedMessage({required this.v2ModuleId});

  factory V2ModuleDeletedMessage.fromJson(Map<String, dynamic> json) =>
      V2ModuleDeletedMessage(v2ModuleId: json['id'] as String);

  final String v2ModuleId;
}

class V2ModulePropertiesChangedMessage {
  const V2ModulePropertiesChangedMessage({
    required this.v2ModuleId,
    required this.label,
    required this.category,
    this.notes = '',
    this.terminals = const [],
    this.exit = '',
    this.connector,
    this.vertical,
    this.labelPos = '',
    this.pinLabelPos = '',
    this.subLabelPos = '',
    this.sub = '',
    this.labelJustify = '',
    this.kind = '',
    this.bulbStyle = '',
    this.bulbColor = '',
    this.flipped,
  });

  factory V2ModulePropertiesChangedMessage.fromJson(
          Map<String, dynamic> json) =>
      V2ModulePropertiesChangedMessage(
        v2ModuleId: json['id'] as String,
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        terminals: _parseTerminals(json['terminals']),
        exit: json['exit'] as String? ?? '',
        connector: json['connector'] as bool?,
        vertical: json['vertical'] as bool?,
        labelPos: json['labelPos'] as String? ?? '',
        pinLabelPos: json['pinLabelPos'] as String? ?? '',
        subLabelPos: json['subLabelPos'] as String? ?? '',
        sub: json['sub'] as String? ?? '',
        labelJustify: json['labelJustify'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        bulbStyle: json['bulbStyle'] as String? ?? '',
        bulbColor: json['bulbColor'] as String? ?? '',
        flipped: json['flipped'] as bool?,
      );

  final String v2ModuleId;
  final String label;

  /// AP-DIAGRAM-V2-BRIDGE-011 — V2's own free-text module notes field
  /// (`js/models/module.js`'s `notes`, edited via `saveModProps()`).
  final String notes;
  final String category;

  /// V2's own terminal list at the moment this change was observed —
  /// same shape/rationale as [V2ModuleCreatedMessage.terminals]. Editing
  /// terminals on an already-bridged module (as opposed to a brand-new
  /// one, which only ever gets this data once via 'moduleCreated') used
  /// to have nowhere to go: OEP's authoritative metadata kept whatever
  /// terminal list the module was created with, so an edited module
  /// rendered correctly live in V2 but silently reverted on the next
  /// document save-and-reopen. This is what closes that gap.
  final List<Map<String, String>> terminals;

  /// Same rationale as [terminals], for V2's own `m.exit`.
  final String exit;

  /// Same rationale as [terminals], for V2's own `m.connector`/`m.vertical`.
  final bool? connector;
  final bool? vertical;

  /// Same rationale as [terminals], for V2's own `m.labelPos`/
  /// `m.pinLabelPos`/`m.subLabelPos`/`m.sub`/`m.labelJustify`.
  final String labelPos;
  final String pinLabelPos;
  final String subLabelPos;
  final String sub;
  final String labelJustify;

  /// Same rationale as [terminals], for V2's own special-render flag —
  /// § [V2SnapshotModule.kind].
  final String kind;

  /// Same rationale as [terminals], for V2's own bulb color/style/flip —
  /// § [V2SnapshotModule.bulbStyle]/[V2SnapshotModule.bulbColor]/
  /// [V2SnapshotModule.flipped].
  final String bulbStyle;
  final String bulbColor;
  final bool? flipped;
}

class V2WireCreatedMessage {
  const V2WireCreatedMessage({
    required this.v2WireId,
    required this.fromModuleId,
    required this.fromTerminal,
    required this.toModuleId,
    required this.toTerminal,
    required this.label,
    required this.color,
    this.fromExit = '',
    this.toExit = '',
    this.cable = false,
  });

  factory V2WireCreatedMessage.fromJson(Map<String, dynamic> json) =>
      V2WireCreatedMessage(
        v2WireId: json['id'] as String,
        fromModuleId: json['fromModuleId'] as String,
        fromTerminal: json['fromTerminal'] as String? ?? '',
        toModuleId: json['toModuleId'] as String,
        toTerminal: json['toTerminal'] as String? ?? '',
        label: json['label'] as String? ?? '',
        color: json['color'] as String? ?? '',
        fromExit: json['fromExit'] as String? ?? '',
        toExit: json['toExit'] as String? ?? '',
        cable: json['cable'] as bool? ?? false,
      );

  final String v2WireId;
  final String fromModuleId;
  final String fromTerminal;
  final String toModuleId;
  final String toTerminal;
  final String label;
  final String color;

  /// § [V2SnapshotWire.fromExit] — same shape, captured via the live
  /// change poller instead of the Save flush barrier's snapshot.
  final String fromExit;

  /// § [V2SnapshotWire.toExit] — same shape, captured via the live
  /// change poller instead of the Save flush barrier's snapshot.
  final String toExit;

  /// § [V2SnapshotWire.cable] — same shape, captured via the live change
  /// poller instead of the Save flush barrier's snapshot.
  final bool cable;
}

class V2WireDeletedMessage {
  const V2WireDeletedMessage({required this.v2WireId});

  factory V2WireDeletedMessage.fromJson(Map<String, dynamic> json) =>
      V2WireDeletedMessage(v2WireId: json['id'] as String);

  final String v2WireId;
}

class V2WireSelectionChangedMessage {
  const V2WireSelectionChangedMessage({required this.v2WireId});

  factory V2WireSelectionChangedMessage.fromJson(Map<String, dynamic> json) =>
      V2WireSelectionChangedMessage(v2WireId: json['id'] as String?);

  /// `null` means V2 deselected its wire (no wire currently selected).
  final String? v2WireId;
}

/// AP-DIAGRAM-V2-BRIDGE-009 — symmetric with [V2WireSelectionChangedMessage].
class V2ModuleSelectionChangedMessage {
  const V2ModuleSelectionChangedMessage({required this.v2ModuleId});

  factory V2ModuleSelectionChangedMessage.fromJson(Map<String, dynamic> json) =>
      V2ModuleSelectionChangedMessage(v2ModuleId: json['id'] as String?);

  /// `null` means V2 deselected its module (no module currently selected).
  final String? v2ModuleId;
}

/// AP-DIAGRAM-V2-BRIDGE-005 — `label`/`color` are V2's post-Save `lbl`/`c`
/// values verbatim. V2's own `saveWireProps()` can never produce a blank
/// value here (blank input falls back to the previous value — see
/// `js/editor/wire-editor.js`'s `w.lbl = ... || w.lbl` pattern, confirmed
/// by direct source read), so unlike the native Flutter property editor
/// there is no "blank means remove this metadata key" case to handle for
/// bridge-originated edits.
class V2WirePropertiesChangedMessage {
  const V2WirePropertiesChangedMessage({
    required this.v2WireId,
    required this.label,
    required this.color,
    this.fromExit = '',
    this.toExit = '',
    this.cable = false,
  });

  factory V2WirePropertiesChangedMessage.fromJson(Map<String, dynamic> json) =>
      V2WirePropertiesChangedMessage(
        v2WireId: json['id'] as String,
        label: json['label'] as String? ?? '',
        color: json['color'] as String? ?? '',
        fromExit: json['fromExit'] as String? ?? '',
        toExit: json['toExit'] as String? ?? '',
        cable: json['cable'] as bool? ?? false,
      );

  final String v2WireId;
  final String label;
  final String color;

  /// § [V2SnapshotWire.fromExit] — set when the wire properties panel's
  /// "Exit Side" dropdown (or an arrow-key override during creation, once
  /// it lands via the poller) changed this wire's `fromExit`.
  final String fromExit;

  /// § [V2SnapshotWire.toExit] — set when a splice's own inspector
  /// (sidebar.js's `_renderModInfoInSidebar`, via setSpliceWireExit())
  /// changed this wire's `toExit`.
  final String toExit;

  /// § [V2SnapshotWire.cable] — set when the wire properties panel's
  /// "Battery Cable" checkbox changed this wire's `cable`.
  final bool cable;
}

/// AP-DIAGRAM-V2-BRIDGE-006 — `mode` is one of V2's own 5 meter-mode
/// codes verbatim (`VDC`/`VAC`/`CONT`/`RES`/`DIODE`, from `meter-panel.js`'s
/// `ML`/`MU` maps — V2 has no current/amps mode at all, confirmed by
/// direct source read). `v2WireId` is `selW.id` — V2's multimeter reading
/// depends on the *selected wire* and mode only; V2's `leadR`/`leadB`
/// fields are cosmetic location labels only (`updateLeadLocDisplay`) and
/// do not feed into `updateMeter()`'s lookup at all, so they carry no
/// measurement meaning and are not part of this message.
class V2MeasurementRequestedMessage {
  const V2MeasurementRequestedMessage(
      {required this.v2WireId, required this.mode});

  factory V2MeasurementRequestedMessage.fromJson(Map<String, dynamic> json) =>
      V2MeasurementRequestedMessage(
        v2WireId: json['id'] as String,
        mode: json['mode'] as String,
      );

  final String v2WireId;
  final String mode;
}

/// PRODUCT-READINESS-008 — V2's own live switch/key state, exactly as
/// `LiveSim.getLiveOperatingState()` returns it (real, already-generic
/// data: `switchStates` covers any plain 2-position switch, keyed by V2's
/// own module id, value `'open'`/`'closed'`; `multiSwitchStates` covers
/// any real multi-position switch, keyed by module id then by that
/// switch's own group name, e.g. `{power: 'on'}` for the ignition switch
/// or `{lights: 'on', dimmer: 'lo', engineStop: 'run', starter: 'free'}`
/// for the handlebar switch — see `MultiSwitchBehavior.DEFS`, the real
/// source of these group/position names, not invented here). Deliberately
/// carries V2's own raw vocabulary rather than a pre-translated
/// `ElectricalOperatingContext` — translation (V2 module id -> OEP node
/// id, and whatever semantic shape a real component behavior expects) is
/// [LegacyV2StateAdapter]'s own job, not this transport's.
class V2OperatingStateChangedMessage {
  const V2OperatingStateChangedMessage({
    required this.switchStates,
    required this.multiSwitchStates,
  });

  factory V2OperatingStateChangedMessage.fromJson(Map<String, dynamic> json) =>
      V2OperatingStateChangedMessage(
        switchStates: Map<String, String>.from(
            json['switchStates'] as Map? ?? const {}),
        multiSwitchStates: {
          for (final entry
              in (json['multiSwitchStates'] as Map? ?? const {}).entries)
            entry.key as String:
                Map<String, String>.from(entry.value as Map),
        },
      );

  /// V2 module id -> `'open'`/`'closed'`.
  final Map<String, String> switchStates;

  /// V2 module id -> `{ groupName: 'position' }`.
  final Map<String, Map<String, String>> multiSwitchStates;
}

class V2StatusMessage {
  const V2StatusMessage({
    required this.selectedModuleId,
    required this.moduleCount,
    required this.wireCount,
    this.editMode,
  });

  factory V2StatusMessage.fromJson(Map<String, dynamic> json) =>
      V2StatusMessage(
        selectedModuleId: json['selM'] as String?,
        moduleCount: json['moduleCount'] as int?,
        wireCount: json['wireCount'] as int?,
        editMode: json['editMode'] as bool?,
      );

  final String? selectedModuleId;
  final int? moduleCount;
  final int? wireCount;

  /// AP-DIAGRAM-V2-BRIDGE-007 — V2's own `editMode` global
  /// (`js/editor/module-editor.js`'s `toggleEdit()`), display-only.
  /// **This is not a gating mechanism** — see the interaction-parity
  /// architecture doc §3 for why no Dart-side enforcement was added:
  /// every currently-bridged mutation (module move, wire create/delete/
  /// select) is detected by polling V2's own underlying data
  /// (`positions`/`MODULES`/`WIRES`/`selW`), which V2 itself only
  /// mutates when its own interaction rules already permit it — a
  /// blocked interaction in V2 never produces a data change for this
  /// bridge to observe, so there is nothing for this flag to gate on the
  /// Dart side. Exposed purely so the status bar can show which mode V2
  /// is in — never consulted by any handler, never persisted.
  final bool? editMode;
}
