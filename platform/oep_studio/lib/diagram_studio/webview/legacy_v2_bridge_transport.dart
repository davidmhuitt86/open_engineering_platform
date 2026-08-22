import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter_windows/webview_flutter_windows.dart';

/// AP-DIAGRAM-V2-WEBVIEW-001 — the transport layer of the OEP↔Legacy V2
/// bridge. Pure communication: WebView lifecycle, message envelope
/// parsing, and script execution. **Deliberately knows nothing about OEP**
/// — no `EngineeringNode`, no `EngineeringRelationship`, no
/// `DiagramStudioController`, no `MoveNodesCommand`. Everything here is
/// expressed in V2's own vocabulary (a module id, an x/y pair) or is a
/// raw script string. [LegacyV2StateAdapter] is the layer that gives
/// these messages OEP meaning.
///
/// Owns the one injected script that runs alongside V2's own (unmodified)
/// scripts, registered via `addScriptToExecuteOnDocumentCreated` — this
/// is the same external-injection mechanism POC-002/003 established;
/// nothing here is written to, or loaded from, any file under
/// `reference/legacy_wiring_sim_v2/eke-wiring-sim/`.
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
    await _controller.addScriptToExecuteOnDocumentCreated(_kBridgeScript);
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

/// Polls (V2 exposes no move-start/move-end event, so this is the
/// smallest viable observation mechanism per POC-003's own finding) V2's
/// existing globals every 400ms:
///
///  - `selM`/`MODULES`/`WIRES` (unchanged from POC-002) for the status
///    snapshot.
///  - `positions` (module id -> {x,y}, V2's own runtime layout map,
///    `js/core/bootstrap.js`/`js/editor/module-editor.js`) for module
///    movement. A position is reported as a discrete `moduleMoved` event
///    only once it has been stable for two consecutive polls AND differs
///    from the last value `sendAuthoritativeModulePosition` itself wrote
///    — the second condition is what prevents the authoritative echo
///    from being reinterpreted as a new user move (Phase 10 loop
///    prevention, POC-003).
const String _kBridgeScript = r'''
(function () {
  // ══════════════════════════════════════════════════════════════
  // AP-DIAGRAM-V2-UI-001 — OEP visual theme adaptation.
  //
  // V2's own `css/main.css` already routes essentially every UI chrome
  // color through `:root`/`[data-theme="dark"]` custom properties
  // (confirmed by direct read — `--surf-0..3`, `--border-0..2`,
  // `--text-hi/md/lo/faint`, `--btn-text*`, `--ink`, `--bg`, `--amber`).
  // That is exactly the "reusable V2 CSS variable" mechanism this task
  // asked to prefer over scattering literal colors — this block redefines
  // those SAME variables to OEP's own `StudioColors` hex values (see
  // `lib/core/theme/studio_colors.dart`, the single source of truth this
  // mapping was taken from), rather than inventing a second theme system
  // or duplicating V2's CSS. `!important` on every declaration makes the
  // override independent of DOM/stylesheet load order (this script runs
  // at `addScriptToExecuteOnDocumentCreated` time, before V2's own
  // `<link rel="stylesheet">` tags are even parsed, so relying on source
  // order alone would let V2's own rule win instead).
  //
  // **What is deliberately NOT remapped** (engineering-semantic, per this
  // task's own explicit protection list): `--purple`/`--green`/`--cyan`/
  // `--cyan-dim`/`--red`/`--red-dim` (category/status colors used by the
  // meter continuity display and mode badges), `--lcd-bg`/`--lcd-fg`
  // (the multimeter LCD readout), `--canvas-*`/`--card-*` (the actual
  // wiring-diagram module-card rendering on the canvas — these are the
  // engineering graphic itself, not UI chrome, and changing them risks
  // exactly the "flatten meaningful engineering colors" outcome this task
  // prohibits). None of `js/utils/colors.js`'s wire-color table is
  // touched either.
  //
  // `--amber` IS remapped, deliberately: reading its actual usage
  // (`.key-btn.active`, `.tb-btn.edit-on`-adjacent badges, `#fp-kb.active`,
  // `.mod-card.wire-selected`'s selection outline) shows it functions as
  // V2's own general **UI accent/selection color**, not an engineering
  // status color — exactly the "selection/interaction colors may be
  // adapted to OEP's accent language" case this task explicitly permits.
  // `#0891b2` (wire-mode badge) and other one-off hex values hardcoded
  // directly in CSS rules (not routed through a variable) are left as-is
  // — overriding those would mean patching individual selectors instead
  // of the token mechanism this task asked to prefer, for a handful of
  // secondary badges with no corresponding OEP token anyway.
  try {
    var oepThemeStyle = document.createElement('style');
    oepThemeStyle.id = 'oep-v2-theme-overlay';
    oepThemeStyle.textContent =
      ':root, [data-theme="dark"], [data-theme="light"] {' +
      '  --ink: #E6E9EE !important;' +          /* StudioColors.textPrimary */
      '  --bg: #0D1117 !important;' +            /* StudioColors.background */
      '  --surf-0: #0D1117 !important;' +        /* StudioColors.background */
      '  --surf-1: #11161D !important;' +        /* StudioColors.surface */
      '  --surf-2: #161C25 !important;' +        /* StudioColors.surfaceRaised */
      '  --surf-3: #232B36 !important;' +        /* StudioColors.border, doubling as an interactive-surface tone */
      '  --surf-3-hover: #2C3542 !important;' +  /* derived (no OEP hover token exists) -- documented, not a token */
      '  --border-0: #1B222C !important;' +      /* StudioColors.borderSubtle */
      '  --border-1: #232B36 !important;' +      /* StudioColors.border */
      '  --border-2: #2C3542 !important;' +      /* derived, same rationale as surf-3-hover */
      '  --text-hi: #E6E9EE !important;' +       /* StudioColors.textPrimary */
      '  --text-md: #9AA5B1 !important;' +       /* StudioColors.textSecondary */
      '  --text-lo: #9AA5B1 !important;' +       /* StudioColors.textSecondary (V2's 4-tier hierarchy collapses to OEP's 3-tier one here) */
      '  --text-faint: #5B6572 !important;' +    /* StudioColors.textDisabled */
      '  --btn-text: #9AA5B1 !important;' +      /* StudioColors.textSecondary */
      '  --btn-text-hover: #E6E9EE !important;' +/* StudioColors.textPrimary */
      '  --amber: #3B82F6 !important;' +         /* StudioColors.selection -- V2's own accent/selection role, not an engineering color (see comment above) */
      '  --shadow-soft: 0 1px 3px rgba(0,0,0,.4) !important;' +
      '  --shadow-panel: 0 8px 32px rgba(0,0,0,.65) !important;' +
      '  --shadow-modal: 0 4px 16px rgba(0,0,0,.6) !important;' +
      '}' +
      /* Typography -- OEP's own dual-font convention (Segoe UI for
         general UI text, Consolas for technical/monospace readouts,
         `studio_theme.dart`'s `_fontFamily`/`_monoFontFamily`) replaces
         V2's blanket Courier New, EXCEPT the multimeter LCD digits
         (`#lcd-*`), which keep a monospace face -- matching OEP's own
         convention of using Consolas for technical data, not abandoning
         the "instrument readout" character the LCD is meant to have. */
      'html, body {' +
      '  font-family: "Segoe UI", "Courier New", monospace !important;' +
      '}' +
      '#lcd-mode, #lcd-val, #lcd-unit, #lcd-range, #lcd-note {' +
      '  font-family: "Consolas", "Courier New", monospace !important;' +
      '}';
    (document.head || document.documentElement).appendChild(oepThemeStyle);
  } catch (e) {
    // Visual-only, non-fatal -- never block the functional bridge over
    // a theme-injection failure.
  }

  var lastStatusSnapshot = null;
  var lastSeen = {};   // id -> { x, y, stableCount }
  var synced = {};     // id -> { x, y } most recent OEP-authoritative value
  var lastModules = {};       // id -> { label, cat }, previous poll's MODULES snapshot
  var syncedModuleProps = {}; // id -> { label } most recent OEP-authoritative label
  var lastWires = {};         // id -> true, previous poll's WIRES id set
  var lastSelW = null;        // previous poll's selected wire id (or null)
  var lastSelM = null;        // previous poll's selected module id (or null)
  var lastWireProps = {};     // id -> { lbl, c }, previous poll's WIRES lbl/c snapshot
  var syncedWireProps = {};   // id -> { lbl, c } most recent OEP-authoritative wire label/color
  var lastMeterKey = null;    // previous poll's "<selW.id>|<meterMode>" combined key

  window.__oepBridgeApplyAuthoritative = function (id, x, y) {
    if (typeof positions !== 'undefined') {
      positions[id] = { x: x, y: y };
    }
    var card = (typeof cardEls !== 'undefined') ? cardEls[id] : null;
    if (card) { card.style.left = x + 'px'; card.style.top = y + 'px'; }
    if (typeof drawWires === 'function') { drawWires(); }
    synced[id] = { x: x, y: y };
    lastSeen[id] = { x: x, y: y, stableCount: 99 };
  };

  window.__oepBridgeApplyModuleLabel = function (id, label) {
    if (typeof MODULES === 'undefined') return;
    var m = MODULES.find(function (x) { return x.id === id; });
    if (!m) return;
    m.label = label;
    if (typeof rebuildCard === 'function') { rebuildCard(m); }
    syncedModuleProps[id] = { label: label };
    if (lastModules[id]) { lastModules[id].label = label; }
  };

  window.__oepBridgeRemoveModule = function (id) {
    if (typeof MODULES === 'undefined') return;
    MODULES = MODULES.filter(function (m) { return m.id !== id; });
    if (typeof WIRES !== 'undefined') {
      WIRES = WIRES.filter(function (w) { return w.from.m !== id && w.to.m !== id; });
    }
    if (typeof removeCard === 'function') { removeCard(id); }
    if (typeof positions !== 'undefined') { delete positions[id]; }
    if (typeof drawWires === 'function') { drawWires(); }
    delete lastModules[id];
    delete syncedModuleProps[id];
    delete synced[id];
    delete lastSeen[id];
  };

  window.__oepBridgeConfirmWireCreated = function (id, label, color) {
    if (typeof WIRES === 'undefined') return;
    var w = WIRES.find(function (x) { return x.id === id; });
    if (!w) return;
    w.lbl = label;
    w.c = color;
    if (typeof drawWires === 'function') { drawWires(); }
    lastWires[id] = true;
    lastWireProps[id] = { lbl: label, c: color };
    syncedWireProps[id] = { lbl: label, c: color };
  };

  window.__oepBridgeRemoveWire = function (id) {
    if (typeof WIRES === 'undefined') return;
    WIRES = WIRES.filter(function (w) { return w.id !== id; });
    if (typeof wireRoutes !== 'undefined') { delete wireRoutes[id]; }
    if (typeof drawWires === 'function') { drawWires(); }
    delete lastWires[id];
    delete lastWireProps[id];
    delete syncedWireProps[id];
  };

  window.__oepBridgeRestoreModule = function (id, label, category, x, y, notes) {
    if (typeof MODULES === 'undefined') return;
    if (MODULES.some(function (m) { return m.id === id; })) return;
    var m = { id: id, label: label, sub: '', cat: category, notes: notes || '', exit: 'down', terminals: [], _user: true };
    MODULES.push(m);
    if (typeof positions !== 'undefined') { positions[id] = { x: x, y: y }; }
    if (typeof placeCards === 'function') { placeCards(); }
    if (typeof drawWires === 'function') { drawWires(); }
    lastModules[id] = { label: label, cat: category, notes: notes || '' };
    synced[id] = { x: x, y: y };
    lastSeen[id] = { x: x, y: y, stableCount: 99 };
  };

  window.__oepBridgeRestoreWire = function (id, fromModuleId, toModuleId, label, color, fromTerminal, toTerminal) {
    if (typeof WIRES === 'undefined') return;
    if (WIRES.some(function (w) { return w.id === id; })) return;
    var w = {
      id: id,
      c: color,
      lbl: label,
      from: { m: fromModuleId, t: fromTerminal || '' },
      to: { m: toModuleId, t: toTerminal || '' },
      desc: '',
      R: Array.from({ length: 4 }, function () {
        return { VDC: '0.00', VAC: '0.00', CONT: 'OPN', RES: 'OL', DIODE: 'OL', note: '' };
      }),
    };
    WIRES.push(w);
    if (typeof drawWires === 'function') { drawWires(); }
    lastWires[id] = true;
    lastWireProps[id] = { lbl: label, c: color };
    syncedWireProps[id] = { lbl: label, c: color };
  };

  window.__oepBridgeClearAll = function () {
    if (typeof MODULES !== 'undefined') { MODULES = []; }
    if (typeof WIRES !== 'undefined') { WIRES = []; }
    if (typeof positions !== 'undefined') { for (var pid in positions) { delete positions[pid]; } }
    if (typeof wireRoutes !== 'undefined') { for (var wid in wireRoutes) { delete wireRoutes[wid]; } }
    if (typeof cardEls !== 'undefined') {
      for (var cid in cardEls) {
        if (cardEls[cid] && cardEls[cid].remove) { cardEls[cid].remove(); }
      }
      for (var cid2 in cardEls) { delete cardEls[cid2]; }
    }
    if (typeof drawWires === 'function') { drawWires(); }
    lastModules = {};
    lastWires = {};
    synced = {};
    lastSeen = {};
    syncedModuleProps = {};
    lastWireProps = {};
    syncedWireProps = {};
  };

  window.__oepBridgeApplyMeasurementResult = function (id, mode, displayValue, unit, note) {
    // Discard a stale reply: V2 has already moved on to a different wire
    // or mode by the time this landed, so applying it would overwrite
    // what the user is currently looking at with an answer to a question
    // V2 no longer cares about (see the Dart-side doc comment).
    if (typeof selW === 'undefined' || !selW || selW.id !== id) return;
    if (typeof meterMode === 'undefined' || meterMode !== mode) return;
    var valEl = $('lcd-val'), noteEl = $('lcd-note'), unitEl = $('lcd-unit');
    if (valEl) {
      valEl.textContent = displayValue;
      valEl.style.color = (mode === 'CONT' && displayValue === 'OPN') ? '#ff6b6b'
        : (mode === 'CONT' && displayValue === '000') ? '#22d3ee'
        : 'var(--lcd-fg)';
    }
    if (unitEl) { unitEl.textContent = mode === 'CONT' ? '' : unit; }
    if (noteEl) { noteEl.textContent = note || ''; }
  };

  window.__oepBridgeInterceptSave = function () {
    // See the Dart-side `interceptV2Save`'s own doc comment for why this
    // must run after V2's own script has already defined `saveLayout` —
    // this simply overwrites that binding at runtime; V2's own
    // `js/storage/project-saver.js` file is never touched.
    window.saveLayout = function () {
      window.chrome.webview.postMessage(JSON.stringify({ type: 'saveRequested', payload: {} }));
    };
  };

  window.__oepBridgeReportSaveResult = function (success, message) {
    if (typeof showToast === 'function') {
      showToast(message, success ? undefined : 'warn');
    }
  };

  setInterval(function () {
    // AP-DIAGRAM-V2-WEBVIEW-003 bugfix — every event this tick detects is
    // pushed here instead of posted immediately, then sent as ONE
    // `type: 'batch'` message at the very end of the tick. This is what
    // guarantees delivery order matches detection order (see
    // `_onRawMessage`'s own comment on the Dart side for why separate
    // `postMessage` calls could not be trusted to preserve it).
    var pending = [];

    try {
      if (typeof selM !== 'undefined') {
        var statusSnapshot = JSON.stringify({
          selM: selM,
          moduleCount: (typeof MODULES !== 'undefined') ? MODULES.length : null,
          wireCount: (typeof WIRES !== 'undefined') ? WIRES.length : null,
          editMode: (typeof editMode !== 'undefined') ? editMode : null,
        });
        if (statusSnapshot !== lastStatusSnapshot) {
          lastStatusSnapshot = statusSnapshot;
          pending.push({ type: 'v2Status', payload: JSON.parse(statusSnapshot) });
        }
      }

      if (typeof positions !== 'undefined') {
        for (var id in positions) {
          var p = positions[id];
          var prev = lastSeen[id];
          if (prev && prev.x === p.x && prev.y === p.y) {
            prev.stableCount = (prev.stableCount || 0) + 1;
          } else {
            lastSeen[id] = { x: p.x, y: p.y, stableCount: 0 };
            prev = lastSeen[id];
          }
          if (prev.stableCount === 2) {
            var s = synced[id];
            if (!s || s.x !== p.x || s.y !== p.y) {
              pending.push({ type: 'moduleMoved', payload: { id: id, x: p.x, y: p.y } });
            }
          }
        }
      }
    } catch (e) {
      // V2 globals not initialized yet (bootstrap still running) — ignore
      // and try again on the next tick.
    }

    try {
      if (typeof MODULES !== 'undefined') {
        var current = {};
        MODULES.forEach(function (m) {
          current[m.id] = { label: m.label, cat: m.cat, notes: m.notes || '' };
        });

        // Created: an id present now that wasn't present last poll.
        for (var newId in current) {
          if (!(newId in lastModules)) {
            var pos = (typeof positions !== 'undefined' && positions[newId]) ? positions[newId] : { x: 0, y: 0 };
            pending.push({
              type: 'moduleCreated',
              payload: { id: newId, label: current[newId].label, category: current[newId].cat, x: pos.x, y: pos.y },
            });
          }
        }

        // Deleted: an id present last poll that's gone now.
        for (var goneId in lastModules) {
          if (!(goneId in current)) {
            pending.push({ type: 'moduleDeleted', payload: { id: goneId } });
            delete syncedModuleProps[goneId];
          }
        }

        // Properties changed: label/category/notes differ from last poll
        // AND from whatever this bridge itself most recently applied as
        // authoritative (loop prevention, same pattern as position sync,
        // extended to `notes` -- AP-DIAGRAM-V2-BRIDGE-011).
        for (var existingId in current) {
          if (!(existingId in lastModules)) continue;
          var prevProps = lastModules[existingId];
          var curProps = current[existingId];
          if (prevProps.label !== curProps.label || prevProps.cat !== curProps.cat || prevProps.notes !== curProps.notes) {
            var syncedProps = syncedModuleProps[existingId];
            if (!syncedProps || syncedProps.label !== curProps.label || syncedProps.notes !== curProps.notes) {
              pending.push({
                type: 'modulePropertiesChanged',
                payload: { id: existingId, label: curProps.label, category: curProps.cat, notes: curProps.notes },
              });
            }
          }
        }

        lastModules = current;
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-WEBVIEW-003/AP-DIAGRAM-V2-BRIDGE-004 — wire
    // create/delete detection (no property/route-edit detection —
    // out of this task's scope).
    try {
      if (typeof WIRES !== 'undefined') {
        var currentWireIds = {};
        WIRES.forEach(function (w) { currentWireIds[w.id] = true; });
        for (var wireId in currentWireIds) {
          if (!(wireId in lastWires)) {
            var w = WIRES.find(function (x) { return x.id === wireId; });
            pending.push({
              type: 'wireCreated',
              payload: {
                id: wireId,
                fromModuleId: w.from.m,
                fromTerminal: w.from.t,
                toModuleId: w.to.m,
                toTerminal: w.to.t,
                label: w.lbl || '',
                color: w.c || '',
              },
            });
            lastWireProps[wireId] = { lbl: w.lbl || '', c: w.c || '' };
          }
        }
        for (var goneWireId in lastWires) {
          if (!(goneWireId in currentWireIds)) {
            pending.push({ type: 'wireDeleted', payload: { id: goneWireId } });
            delete lastWireProps[goneWireId];
            delete syncedWireProps[goneWireId];
          }
        }
        lastWires = currentWireIds;

        // AP-DIAGRAM-V2-BRIDGE-005 — wire property edits: V2's own
        // `saveWireProps()` mutates the wire object in place (no id
        // change), so this diffs a per-wire `{lbl, c}` snapshot, exactly
        // mirroring the module-properties-changed block above, including
        // the same loop-prevention pattern against `syncedWireProps`.
        WIRES.forEach(function (w) {
          var prevProps = lastWireProps[w.id];
          if (!prevProps) return;
          var curLbl = w.lbl || '';
          var curColor = w.c || '';
          if (prevProps.lbl !== curLbl || prevProps.c !== curColor) {
            var syncedProps = syncedWireProps[w.id];
            if (!syncedProps || syncedProps.lbl !== curLbl || syncedProps.c !== curColor) {
              pending.push({
                type: 'wirePropertiesChanged',
                payload: { id: w.id, label: curLbl, color: curColor },
              });
            }
            lastWireProps[w.id] = { lbl: curLbl, c: curColor };
          }
        });
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-BRIDGE-004 — wire selection: V2 keeps the selected
    // wire object itself (`selW`, not just an id) at `app.js` scope; a
    // module and a wire are never selected at the same time in V2
    // (confirmed in earlier research — mutually exclusive with `selM`).
    try {
      var currentSelW = (typeof selW !== 'undefined' && selW) ? selW.id : null;
      if (currentSelW !== lastSelW) {
        lastSelW = currentSelW;
        pending.push({ type: 'wireSelectionChanged', payload: { id: currentSelW } });
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-BRIDGE-009 — module selection, symmetric with wire
    // selection above. V2 keeps the selected module id as a bare `selM`
    // global (`app.js`), toggled by `js/ui/inspector.js` — no
    // multi-select, and never set at the same time as `selW`.
    try {
      var currentSelM = (typeof selM !== 'undefined') ? selM : null;
      if (currentSelM !== lastSelM) {
        lastSelM = currentSelM;
        pending.push({ type: 'moduleSelectionChanged', payload: { id: currentSelM } });
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    // AP-DIAGRAM-V2-BRIDGE-006 — a measurement request whenever the
    // selected-wire/meter-mode pair changes. V2's own `updateMeter()` is
    // a synchronous local lookup with no outward event of its own (§1 of
    // the simulation bridge doc), so this is poll-diffed like every other
    // V2-observation in this bridge. Only fires with a wire selected —
    // `updateMeter()` itself is a no-op with none (`if (!selW) return;`).
    try {
      if (typeof selW !== 'undefined' && selW && typeof meterMode !== 'undefined') {
        var meterKey = selW.id + '|' + meterMode;
        if (meterKey !== lastMeterKey) {
          lastMeterKey = meterKey;
          pending.push({ type: 'measurementRequested', payload: { id: selW.id, mode: meterMode } });
        }
      } else {
        lastMeterKey = null;
      }
    } catch (e) {
      // Same rationale as the position-polling try/catch above.
    }

    if (pending.length > 0) {
      window.chrome.webview.postMessage(JSON.stringify({ type: 'batch', payload: pending }));
    }
  }, 400);
})();
''';
