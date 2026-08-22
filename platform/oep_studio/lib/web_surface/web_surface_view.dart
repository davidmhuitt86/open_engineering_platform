import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../core/theme/studio_colors.dart';
import 'web_surface.dart';

/// AP-STUDIO-WEB-SURFACE-001 — a generic Web Surface: one
/// `WebviewController`/`Webview` plus the minimal browser chrome Phase 5
/// calls for (Back/Forward/Reload/URL bar) and nothing else (no
/// bookmarks, history database, profiles UI, downloads manager —
/// explicitly out of scope, Phase 13).
///
/// **Knows nothing about OEP** — no `EngineeringNode`,
/// `DiagramStudioController`, or any bridge type, matching Phase 7's
/// boundary: `import`s here are Flutter/`webview_flutter_windows` only.
/// A future bridge-authorized surface would wrap this widget (or an
/// equivalent controller) the same way `LegacyV2WebViewPage` already
/// wraps its own `WebviewController` with `LegacyV2BridgeTransport`/
/// `LegacyV2StateAdapter` — composition, not a capability this widget
/// grows itself.
///
/// **Lifetime (Phase 3, decision B — "keep WebView alive while tab
/// remains open")**: this widget's own `State` owns the
/// `WebviewController` for the lifetime of the widget. The host
/// ([WebSurfacesHostPage]) keeps every open tab's `WebSurfaceView` in an
/// `IndexedStack` rather than swapping widgets in and out of the tree on
/// tab switch — an `IndexedStack`'s non-visible children stay mounted
/// (just not painted), so `WebSurfaceView`'s own `State.dispose()` only
/// runs when the tab is actually **closed**, not when it's merely
/// switched away from. This is what makes V2's state (and every other
/// surface's own JS/navigation state) survive tab switching, verified
/// live (see the architecture doc §11).
class WebSurfaceView extends StatefulWidget {
  const WebSurfaceView({super.key, required this.surface, this.showChrome = true});

  final WebSurface surface;

  /// V2's own dedicated widget already draws its own toolbar; a generic
  /// surface embedded standalone wants the Back/Forward/Reload/URL bar
  /// row. Kept togglable rather than duplicated as a second widget.
  final bool showChrome;

  @override
  State<WebSurfaceView> createState() => _WebSurfaceViewState();
}

class _WebSurfaceViewState extends State<WebSurfaceView> with AutomaticKeepAliveClientMixin {
  final WebviewController _controller = WebviewController();
  final TextEditingController _urlField = TextEditingController();
  bool _ready = false;
  String? _error;
  String _currentUrl = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.surface.initialUrl;
    _urlField.text = _currentUrl;
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      _controller.url.listen((url) {
        if (!mounted) return;
        setState(() {
          _currentUrl = url;
          _urlField.text = url;
        });
      });
      await _controller.loadUrl(widget.surface.initialUrl);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _navigate(String url) {
    var target = url.trim();
    if (target.isEmpty) return;
    if (!target.contains('://')) target = 'https://$target';
    unawaited(_controller.loadUrl(target));
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        if (widget.showChrome)
          Container(
            decoration: const BoxDecoration(
              color: StudioColors.surfaceRaised,
              border: Border(bottom: BorderSide(color: StudioColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, size: 18),
                  color: StudioColors.textSecondary,
                  onPressed: _ready ? () => _controller.goBack() : null,
                ),
                IconButton(
                  tooltip: 'Forward',
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  color: StudioColors.textSecondary,
                  onPressed: _ready ? () => _controller.goForward() : null,
                ),
                IconButton(
                  tooltip: 'Reload',
                  icon: const Icon(Icons.refresh, size: 18),
                  color: StudioColors.textSecondary,
                  onPressed: _ready ? () => _controller.reload() : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _urlField,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search or enter a web address',
                      hintStyle: TextStyle(fontSize: 12, color: StudioColors.textDisabled),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      filled: true,
                      fillColor: StudioColors.surfaceSunken,
                      border: OutlineInputBorder(borderSide: BorderSide(color: StudioColors.border)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: StudioColors.border)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: StudioColors.selection)),
                    ),
                    onSubmitted: _navigate,
                  ),
                ),
                IconButton(
                  tooltip: 'Go',
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  color: StudioColors.textSecondary,
                  onPressed: () => _navigate(_urlField.text),
                ),
              ],
            ),
          ),
        Expanded(
          child: _error != null
              ? Center(
                  child: Text(
                    'Failed to load:\n$_error',
                    style: const TextStyle(color: StudioColors.error),
                    textAlign: TextAlign.center,
                  ),
                )
              : !_ready
                  ? const Center(child: CircularProgressIndicator(color: StudioColors.selection))
                  : Webview(_controller),
        ),
      ],
    );
  }
}
