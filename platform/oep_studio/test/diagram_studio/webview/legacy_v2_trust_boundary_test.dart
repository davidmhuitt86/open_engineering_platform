import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/webview/legacy_v2_trust_boundary.dart';

/// AP-STUDIO-WEB-SURFACE-002, Phase 9 — tests for the pure navigation
/// trust-check function, independent of any WebView.
void main() {
  const trustedEntry =
      'file:///C:/dev/open_engineering_platform/reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html';

  test('the exact entry URL is trusted', () {
    expect(isTrustedLegacyV2Url(trustedEntry, trustedEntry), isTrue);
  });

  test('another file within the same V2 directory is trusted', () {
    const sibling =
        'file:///C:/dev/open_engineering_platform/reference/legacy_wiring_sim_v2/eke-wiring-sim/js/app.js';
    expect(isTrustedLegacyV2Url(sibling, trustedEntry), isTrue);
  });

  test('a file in a subdirectory of V2 is trusted', () {
    const nested =
        'file:///C:/dev/open_engineering_platform/reference/legacy_wiring_sim_v2/eke-wiring-sim/diagrams/trx300/modules.json';
    expect(isTrustedLegacyV2Url(nested, trustedEntry), isTrue);
  });

  test('a different local file outside the V2 directory is NOT trusted', () {
    const outside =
        'file:///C:/dev/open_engineering_platform/reference/some_other_app/index.html';
    expect(isTrustedLegacyV2Url(outside, trustedEntry), isFalse);
  });

  test('navigating to an https URL is NOT trusted', () {
    expect(isTrustedLegacyV2Url('https://example.com', trustedEntry), isFalse);
  });

  test('an unparseable URL is NOT trusted (fails safe)', () {
    expect(isTrustedLegacyV2Url('not a url', trustedEntry), isFalse);
  });

  test('navigating back to the trusted directory restores trust', () {
    expect(isTrustedLegacyV2Url('https://example.com', trustedEntry), isFalse);
    expect(isTrustedLegacyV2Url(trustedEntry, trustedEntry), isTrue);
  });
}
