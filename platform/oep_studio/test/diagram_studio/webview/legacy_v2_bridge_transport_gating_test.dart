import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';

/// AP-STUDIO-WEB-SURFACE-002, Phase 9 — verifies the outbound trust gate
/// (`bridgeEnabled`) short-circuits before ever touching the underlying
/// `WebviewController`, so this is safe to test without a real,
/// initialized WebView2 instance (constructing `WebviewController()`
/// itself performs no native calls; only `initialize()`/`executeScript()`
/// would).
void main() {
  test('bridgeEnabled starts true by default', () {
    final transport = LegacyV2BridgeTransport(WebviewController());
    expect(transport.bridgeEnabled, isTrue);
  });

  test(
      'when bridgeEnabled is false, sendAuthoritativeModulePosition completes without touching the controller',
      () async {
    final transport = LegacyV2BridgeTransport(WebviewController())
      ..bridgeEnabled = false;
    // Would throw/hang against an uninitialized native controller if the
    // gate didn't short-circuit before reaching `_controller.executeScript`.
    await expectLater(
        transport.sendAuthoritativeModulePosition('m', 1, 2), completes);
  });

  test(
      'when bridgeEnabled is false, restoreModule completes without touching the controller',
      () async {
    final transport = LegacyV2BridgeTransport(WebviewController())
      ..bridgeEnabled = false;
    await expectLater(
        transport.restoreModule('m', 'label', 'ground', 1, 2), completes);
  });

  test(
      'when bridgeEnabled is false, removeWireFromV2 completes without touching the controller',
      () async {
    final transport = LegacyV2BridgeTransport(WebviewController())
      ..bridgeEnabled = false;
    await expectLater(transport.removeWireFromV2('w'), completes);
  });
}
