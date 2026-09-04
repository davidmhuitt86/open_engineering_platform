import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import 'legacy_v2_bridge_script.dart';
import 'legacy_v2_bridge_transport.dart';

/// AP-OEP-DIAGRAM-ANDROID-001 — the Android counterpart of
/// [LegacyV2BridgeTransport] (Windows). Same [LegacyV2Channel] contract,
/// same shared [legacyV2BridgeScript] JS payload, different WebView
/// plumbing:
///
///  - **Injection timing**: WebView2's `addScriptToExecuteOnDocumentCreated`
///    has no first-class `webview_flutter` equivalent on Android (the
///    androidx.webkit analogue, `WebViewCompat.addDocumentStartJavaScript`,
///    is gated behind a runtime feature check not guaranteed on older
///    device WebView builds). Instead this transport injects the bridge
///    script from [attach], called once the host widget's
///    `NavigationDelegate.onPageFinished` fires. Safe here because the
///    bridge script only starts a 400ms poll loop and wraps the Save
///    button's handler — both no-ops until V2's own scripts have already
///    run, unlike, say, a monkey-patch that needs to beat V2's own
///    `<script>` tags to a race.
///  - **Message channel**: `window.chrome.webview.postMessage` doesn't
///    exist on Android — `addJavaScriptChannel` registers `window.OepBridge`
///    instead, and [legacyV2BridgeScript] is asked to route through that.
///  - **Outbound calls**: [WebViewController.runJavaScript] in place of
///    `executeScript` — same fire-and-forget shape.
class LegacyV2AndroidBridgeTransport implements LegacyV2Channel {
  LegacyV2AndroidBridgeTransport(this._controller);

  final WebViewController _controller;

  /// Same trust-boundary flag as [LegacyV2BridgeTransport.bridgeEnabled]
  /// — see that field's own doc comment.
  bool bridgeEnabled = true;

  void Function(V2ModuleMovedMessage message)? onModuleMoved;
  void Function(V2StatusMessage message)? onStatus;
  void Function(V2ModuleCreatedMessage message)? onModuleCreated;
  void Function(V2ModuleDeletedMessage message)? onModuleDeleted;
  void Function(V2ModulePropertiesChangedMessage message)?
      onModulePropertiesChanged;
  void Function(V2WireCreatedMessage message)? onWireCreated;
  void Function(V2WireDeletedMessage message)? onWireDeleted;
  void Function(V2WireSelectionChangedMessage message)? onWireSelectionChanged;
  void Function(V2ModuleSelectionChangedMessage message)?
      onModuleSelectionChanged;
  void Function(V2WirePropertiesChangedMessage message)?
      onWirePropertiesChanged;
  void Function(V2MeasurementRequestedMessage message)? onMeasurementRequested;
  void Function()? onSaveRequested;

  /// Registers the `OepBridge` JS channel and injects the shared bridge
  /// script. Must be called once the page has actually finished loading
  /// (see class doc comment) — the host widget calls this from
  /// `NavigationDelegate.onPageFinished`, not from `initState`.
  Future<void> attach() async {
    await _controller.addJavaScriptChannel(
      'OepBridge',
      onMessageReceived: (JavaScriptMessage message) =>
          _onRawMessage(message.message),
    );
    await _controller.runJavaScript(
      legacyV2BridgeScript('window.OepBridge.postMessage(s)'),
    );
  }

  void _onRawMessage(String raw) {
    final Map<String, dynamic> envelope =
        jsonDecode(raw) as Map<String, dynamic>;
    // Same batching rationale as `LegacyV2BridgeTransport._onRawMessage`
    // — a `JavaScriptChannel` message is a single string, so ordering
    // within one poll tick is guaranteed by construction here too.
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
      case 'saveRequested':
        onSaveRequested?.call();
    }
  }

  Future<void> _executeIfEnabled(String script) {
    if (!bridgeEnabled) return Future<void>.value();
    return _controller.runJavaScript(script);
  }

  @override
  Future<void> sendAuthoritativeModulePosition(
      String v2ModuleId, double x, double y) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyAuthoritative && window.__oepBridgeApplyAuthoritative('
      '${jsonEncode(v2ModuleId)}, $x, $y)',
    );
  }

  @override
  Future<void> sendAuthoritativeModuleLabel(String v2ModuleId, String label) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyModuleLabel && window.__oepBridgeApplyModuleLabel('
      '${jsonEncode(v2ModuleId)}, ${jsonEncode(label)})',
    );
  }

  @override
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes = '', List<Map<String, String>> terminals = const []}) {
    return _executeIfEnabled(
      'window.__oepBridgeRestoreModule && window.__oepBridgeRestoreModule('
      '${jsonEncode(v2ModuleId)}, ${jsonEncode(label)}, ${jsonEncode(category)}, $x, $y, ${jsonEncode(notes)}, ${jsonEncode(terminals)})',
    );
  }

  @override
  Future<void> removeModuleFromV2(String v2ModuleId) {
    return _executeIfEnabled(
      'window.__oepBridgeRemoveModule && window.__oepBridgeRemoveModule(${jsonEncode(v2ModuleId)})',
    );
  }

  @override
  Future<void> confirmWireCreated(String v2WireId, String label, String color) {
    return _executeIfEnabled(
      'window.__oepBridgeConfirmWireCreated && window.__oepBridgeConfirmWireCreated('
      '${jsonEncode(v2WireId)}, ${jsonEncode(label)}, ${jsonEncode(color)})',
    );
  }

  @override
  Future<void> removeWireFromV2(String v2WireId) {
    return _executeIfEnabled(
      'window.__oepBridgeRemoveWire && window.__oepBridgeRemoveWire(${jsonEncode(v2WireId)})',
    );
  }

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

  @override
  Future<void> clearAllSurfaces() {
    return _executeIfEnabled(
        'window.__oepBridgeClearAll && window.__oepBridgeClearAll()');
  }

  @override
  Future<void> interceptV2Save() {
    return _executeIfEnabled(
        'window.__oepBridgeInterceptSave && window.__oepBridgeInterceptSave()');
  }

  @override
  Future<void> reportSaveResult(bool success, String message) {
    return _executeIfEnabled(
      'window.__oepBridgeReportSaveResult && window.__oepBridgeReportSaveResult('
      '${jsonEncode(success)}, ${jsonEncode(message)})',
    );
  }

  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyMeasurementResult && window.__oepBridgeApplyMeasurementResult('
      '${jsonEncode(v2WireId)}, ${jsonEncode(mode)}, ${jsonEncode(displayValue)}, '
      '${jsonEncode(unit)}, ${jsonEncode(note)})',
    );
  }

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — Android counterpart of
  /// [LegacyV2BridgeTransport.captureSaveSnapshot]. `runJavaScriptReturningResult`
  /// (unlike `executeScript` on Windows) does **not** pre-decode a JSON
  /// object result — for a non-primitive JS return value it hands back
  /// the raw JSON text as a plain Dart `String` (confirmed by reading
  /// `webview_flutter_android`'s own `runJavaScriptReturningResult`:
  /// it only special-cases `'true'`/`'false'`/numeric strings, falling
  /// through to the raw string otherwise) — so exactly one `jsonDecode`
  /// is needed here where Windows needs zero, matching the same "each
  /// transport does its own minimal platform glue" split every other
  /// method in this file already has. The underlying JS this calls is
  /// the identical, shared `window.__oepBridgeCaptureSaveSnapshot`.
  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async {
    if (!bridgeEnabled) return null;
    final result = await _controller.runJavaScriptReturningResult(
      'window.__oepBridgeCaptureSaveSnapshot && window.__oepBridgeCaptureSaveSnapshot()',
    );
    if (result is! String || result.isEmpty || result == 'null') return null;
    return V2SaveSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(result) as Map));
  }

  @override
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets) {
    return _executeIfEnabled(
      'window.__oepBridgeApplyWireRouteOffsets && window.__oepBridgeApplyWireRouteOffsets('
      '${jsonEncode(v2WireId)}, ${jsonEncode(offsets)})',
    );
  }

  /// Same escape hatch as [LegacyV2BridgeTransport.executeRawScript].
  Future<void> executeRawScript(String script) =>
      _controller.runJavaScript(script);

  Future<void> dispose() async {
    // No subscription to cancel here — `addJavaScriptChannel`'s callback
    // is owned by the `WebViewController`/`WebViewWidget` lifecycle,
    // torn down by the host widget disposing the controller itself
    // (same division of responsibility as the Windows transport, whose
    // `_sub` similarly doesn't own the underlying `WebviewController`).
  }
}
