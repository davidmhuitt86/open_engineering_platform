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
  void Function(V2ModulePropertiesChangedMessage message)? onModulePropertiesChanged;

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
  void Function(V2ModuleSelectionChangedMessage message)? onModuleSelectionChanged;

  /// AP-DIAGRAM-V2-BRIDGE-005 — fired when an already-known wire's
  /// `lbl`/`c` differs from the previous poll's snapshot (i.e. after V2's
  /// own `saveWireProps()` has already run and closed the modal). Mirrors
  /// [onModulePropertiesChanged]'s detection shape exactly — V2 mutates
  /// the wire object in place on Save, so this is a diff against a
  /// per-wire `{lbl, c}` snapshot, not an id-presence check.
  void Function(V2WirePropertiesChangedMessage message)? onWirePropertiesChanged;

  /// AP-DIAGRAM-V2-BRIDGE-006 — fired whenever V2's own selected-wire-id +
  /// meter-mode pair changes (poll-diffed, same rationale as every other
  /// detector in this transport — V2 raises no "measurement requested"
  /// event of its own; `updateMeter()` is a synchronous local lookup, see
  /// the simulation bridge architecture doc §1). Only fires while a wire
  /// is selected — V2's own `updateMeter()` is itself a no-op with no
  /// selection (`if (!selW) return;`), so there is nothing to request.
  void Function(V2MeasurementRequestedMessage message)? onMeasurementRequested;

  /// AP-DIAGRAM-V2-BRIDGE-003, Phase 4 — fired when V2's own "Save"
  /// button is clicked, once [interceptV2Save] has been applied. Never
  /// fires before that call, since V2's original `saveLayout` (a plain
  /// file download) is still in effect until then.
  void Function()? onSaveRequested;

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
        onModulePropertiesChanged?.call(V2ModulePropertiesChangedMessage.fromJson(payload));
      case 'wireCreated':
        onWireCreated?.call(V2WireCreatedMessage.fromJson(payload));
      case 'wireDeleted':
        onWireDeleted?.call(V2WireDeletedMessage.fromJson(payload));
      case 'wireSelectionChanged':
        onWireSelectionChanged?.call(V2WireSelectionChangedMessage.fromJson(payload));
      case 'moduleSelectionChanged':
        onModuleSelectionChanged?.call(V2ModuleSelectionChangedMessage.fromJson(payload));
      case 'wirePropertiesChanged':
        onWirePropertiesChanged?.call(V2WirePropertiesChangedMessage.fromJson(payload));
      case 'measurementRequested':
        onMeasurementRequested?.call(V2MeasurementRequestedMessage.fromJson(payload));
      case 'saveRequested':
        onSaveRequested?.call();
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
  Future<void> sendAuthoritativeModulePosition(String v2ModuleId, double x, double y) {
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
  /// it again. Terminals are intentionally omitted (documented
  /// limitation — see the architecture doc) since this bridge does not
  /// currently mirror V2's terminal list into OEP metadata.
  ///
  /// AP-DIAGRAM-V2-BRIDGE-011 — [notes] is passed through when
  /// `metadata['notes']` is stored, so notes survive document
  /// reload/undo-of-delete the same way label/category already did.
  @override
  Future<void> restoreModule(String v2ModuleId, String label, String category, double x, double y, {String notes = ''}) {
    return _executeIfEnabled(
      'window.__oepBridgeRestoreModule && window.__oepBridgeRestoreModule('
      '${jsonEncode(v2ModuleId)}, ${jsonEncode(label)}, ${jsonEncode(category)}, $x, $y, ${jsonEncode(notes)})',
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
  }) {
    return _executeIfEnabled(
      'window.__oepBridgeRestoreWire && window.__oepBridgeRestoreWire('
      '${jsonEncode(v2WireId)}, ${jsonEncode(fromModuleId)}, ${jsonEncode(toModuleId)}, '
      '${jsonEncode(label)}, ${jsonEncode(color)}, ${jsonEncode(fromTerminal)}, ${jsonEncode(toTerminal)})',
    );
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 8 — clears V2's entire runtime
  /// state (`MODULES`/`WIRES`/`positions`/`wireRoutes`) before
  /// re-seeding from a (newly active) document — the mechanism that
  /// prevents document A's modules/wires from lingering, and being
  /// mutable, once document B becomes active.
  @override
  Future<void> clearAllSurfaces() {
    return _executeIfEnabled('window.__oepBridgeClearAll && window.__oepBridgeClearAll()');
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
    return _executeIfEnabled('window.__oepBridgeInterceptSave && window.__oepBridgeInterceptSave()');
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
  Future<void> applyMeasurementResult(String v2WireId, String mode, String displayValue, String unit, String note) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyMeasurementResult && window.__oepBridgeApplyMeasurementResult('
      '${jsonEncode(v2WireId)}, ${jsonEncode(mode)}, ${jsonEncode(displayValue)}, '
      '${jsonEncode(unit)}, ${jsonEncode(note)})',
    );
  }

  /// Transport-level escape hatch for one-off, non-mutating V2 calls that
  /// don't warrant their own message type — used today only for
  /// "Fit view" (`zReset()`), proven in POC-002. Not a general-purpose
  /// command channel: nothing above the transport should reach for this
  /// to implement new bridged operations.
  Future<void> executeRawScript(String script) => _controller.executeScript(script);

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
  set onModulePropertiesChanged(void Function(V2ModulePropertiesChangedMessage message)? handler);
  set onWireCreated(void Function(V2WireCreatedMessage message)? handler);
  set onWireDeleted(void Function(V2WireDeletedMessage message)? handler);
  set onWireSelectionChanged(void Function(V2WireSelectionChangedMessage message)? handler);
  set onModuleSelectionChanged(void Function(V2ModuleSelectionChangedMessage message)? handler);
  set onWirePropertiesChanged(void Function(V2WirePropertiesChangedMessage message)? handler);
  set onMeasurementRequested(void Function(V2MeasurementRequestedMessage message)? handler);
  set onSaveRequested(void Function()? handler);

  Future<void> sendAuthoritativeModulePosition(String v2ModuleId, double x, double y);
  Future<void> sendAuthoritativeModuleLabel(String v2ModuleId, String label);
  Future<void> restoreModule(String v2ModuleId, String label, String category, double x, double y, {String notes});
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
  });
  Future<void> clearAllSurfaces();
  Future<void> interceptV2Save();
  Future<void> reportSaveResult(bool success, String message);
  Future<void> applyMeasurementResult(String v2WireId, String mode, String displayValue, String unit, String note);
}

class V2ModuleMovedMessage {
  const V2ModuleMovedMessage({required this.v2ModuleId, required this.x, required this.y});

  factory V2ModuleMovedMessage.fromJson(Map<String, dynamic> json) => V2ModuleMovedMessage(
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
  });

  factory V2ModuleCreatedMessage.fromJson(Map<String, dynamic> json) => V2ModuleCreatedMessage(
        v2ModuleId: json['id'] as String,
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
      );

  final String v2ModuleId;
  final String label;
  final String category;
  final double x;
  final double y;
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
  });

  factory V2ModulePropertiesChangedMessage.fromJson(Map<String, dynamic> json) =>
      V2ModulePropertiesChangedMessage(
        v2ModuleId: json['id'] as String,
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );

  final String v2ModuleId;
  final String label;
  /// AP-DIAGRAM-V2-BRIDGE-011 — V2's own free-text module notes field
  /// (`js/models/module.js`'s `notes`, edited via `saveModProps()`).
  final String notes;
  final String category;
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
  });

  factory V2WireCreatedMessage.fromJson(Map<String, dynamic> json) => V2WireCreatedMessage(
        v2WireId: json['id'] as String,
        fromModuleId: json['fromModuleId'] as String,
        fromTerminal: json['fromTerminal'] as String? ?? '',
        toModuleId: json['toModuleId'] as String,
        toTerminal: json['toTerminal'] as String? ?? '',
        label: json['label'] as String? ?? '',
        color: json['color'] as String? ?? '',
      );

  final String v2WireId;
  final String fromModuleId;
  final String fromTerminal;
  final String toModuleId;
  final String toTerminal;
  final String label;
  final String color;
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
  const V2WirePropertiesChangedMessage({required this.v2WireId, required this.label, required this.color});

  factory V2WirePropertiesChangedMessage.fromJson(Map<String, dynamic> json) => V2WirePropertiesChangedMessage(
        v2WireId: json['id'] as String,
        label: json['label'] as String? ?? '',
        color: json['color'] as String? ?? '',
      );

  final String v2WireId;
  final String label;
  final String color;
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
  const V2MeasurementRequestedMessage({required this.v2WireId, required this.mode});

  factory V2MeasurementRequestedMessage.fromJson(Map<String, dynamic> json) => V2MeasurementRequestedMessage(
        v2WireId: json['id'] as String,
        mode: json['mode'] as String,
      );

  final String v2WireId;
  final String mode;
}

class V2StatusMessage {
  const V2StatusMessage({
    required this.selectedModuleId,
    required this.moduleCount,
    required this.wireCount,
    this.editMode,
  });

  factory V2StatusMessage.fromJson(Map<String, dynamic> json) => V2StatusMessage(
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

