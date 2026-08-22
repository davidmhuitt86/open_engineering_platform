/// AP-STUDIO-WEB-SURFACE-002, Phase 9 — the narrow navigation trust
/// boundary for the Legacy V2 bridge. Deliberately a pure function (no
/// `WebviewController`, no bridge type) so it's testable without a real
/// WebView — the host widget (`legacy_v2_webview.dart`) calls this on
/// every URL change and writes the result into
/// `LegacyV2BridgeTransport.bridgeEnabled`.
///
/// **The trusted boundary is "the same local directory the V2 entry
/// point was loaded from, or a page within it"** — not merely "starts
/// with `file://`" (that would trust *any* local file, defeating the
/// point) and not "exactly equals the entry URL" (V2 is a single-page
/// app, but a same-origin/-directory sub-resource or anchor navigation
/// should not be treated as "left V2"). Anything on a different scheme
/// (a `https://` link V2 doesn't actually contain, but a user could
/// still type into... there is no address bar on the V2 tab, so this
/// realistically only fires if V2's own page ever executes a top-level
/// navigation) or a different directory is untrusted.
bool isTrustedLegacyV2Url(String currentUrl, String trustedEntryUrl) {
  final current = Uri.tryParse(currentUrl);
  final trusted = Uri.tryParse(trustedEntryUrl);
  if (current == null || trusted == null) return false;
  if (current.scheme != 'file' || trusted.scheme != 'file') return false;
  final trustedDir = _directoryOf(trusted.path);
  return current.path == trusted.path || current.path.startsWith(trustedDir);
}

String _directoryOf(String path) {
  final lastSlash = path.lastIndexOf('/');
  return lastSlash == -1 ? path : path.substring(0, lastSlash + 1);
}
