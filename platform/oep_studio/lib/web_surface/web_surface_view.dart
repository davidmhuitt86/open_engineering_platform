import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../core/services/foundation_runtime_service.dart';
import '../core/theme/studio_colors.dart';
import '../knowledge/models/knowledge_validation_exception.dart';
import 'web_browser_settings_provider.dart';
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
class WebSurfaceView extends ConsumerStatefulWidget {
  const WebSurfaceView({super.key, required this.surface, this.showChrome = true});

  final WebSurface surface;

  /// V2's own dedicated widget already draws its own toolbar; a generic
  /// surface embedded standalone wants the Back/Forward/Reload/URL bar
  /// row. Kept togglable rather than duplicated as a second widget.
  final bool showChrome;

  @override
  ConsumerState<WebSurfaceView> createState() => _WebSurfaceViewState();
}

class _WebSurfaceViewState extends ConsumerState<WebSurfaceView> with AutomaticKeepAliveClientMixin {
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

  /// Matches an explicit URI scheme prefix ("https:", "about:", "file:",
  /// "data:", ...) — anything already shaped like this is used exactly
  /// as typed, never search-encoded or re-prefixed. Needed so the
  /// homepage default (`about:blank`) and the Home button both still
  /// work regardless of the search-on-typed-text setting.
  static final RegExp _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

  /// A bare domain/host ("example.com", "localhost:8080") is still a
  /// navigable address even without a scheme; anything else typed into
  /// the address bar (a space anywhere, or no dot at all) reads as a
  /// search query, not a URL.
  bool _looksLikeAddress(String input) => !input.contains(' ') && (input.contains('.') || input.startsWith('localhost'));

  void _navigate(String input) {
    var target = input.trim();
    if (target.isEmpty) return;
    if (_schemePattern.hasMatch(target)) {
      // already a fully-qualified address (https:, about:, file:, ...), use as-is
    } else if (_looksLikeAddress(target)) {
      target = 'https://$target';
    } else if (ref.read(webBrowserSettingsProvider).searchOnTypedText) {
      target = 'https://www.google.com/search?q=${Uri.encodeQueryComponent(target)}';
    } else {
      target = 'https://$target';
    }
    unawaited(_controller.loadUrl(target));
  }

  /// "Import to Diagram Studio" — the native WebView2 control this
  /// widget embeds exposes no hook to add/intercept its own right-click
  /// context menu, and no download-completed callback (confirmed by
  /// reading `webview_flutter_windows`'s own API surface: no
  /// `onContextMenuRequested`, no download event of any kind). The
  /// browser's own native "Save picture as…"/"Save as…" already saves a
  /// file to disk unchanged; this button picks up from there — the user
  /// saves normally, then imports that saved file as Source Material via
  /// the same, already-existing `attachSourceMaterial` path Knowledge
  /// Studio's own Import Queue panel uses (`import_queue_panel.dart`) —
  /// not a new import pipeline.
  Future<void> _importToKnowledge() async {
    final picked = await openFile();
    if (picked == null) return;
    if (!mounted) return;
    try {
      await ref.read(foundationRuntimeServiceProvider.notifier).attachSourceMaterial(picked.path);
    } on KnowledgeValidationException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Couldn't Import"),
          content: Text(error.message),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    final settings = ref.read(webBrowserSettingsProvider);
    final homepageController = TextEditingController(text: settings.homepageUrl);
    var searchOnTypedText = settings.searchOnTypedText;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Browser Settings'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Homepage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: homepageController,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'about:blank or https://example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Loaded when a new blank web tab is opened.',
                  style: TextStyle(fontSize: 11, color: StudioColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Search with Google', style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    "When what you type in the address bar isn't a web address",
                    style: TextStyle(fontSize: 11),
                  ),
                  value: searchOnTypedText,
                  onChanged: (value) => setDialogState(() => searchOnTypedText = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                ref.read(webBrowserSettingsProvider.notifier).update(
                      homepageUrl: homepageController.text.trim().isEmpty ? 'about:blank' : homepageController.text.trim(),
                      searchOnTypedText: searchOnTypedText,
                    );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    homepageController.dispose();
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
                IconButton(
                  tooltip: 'Home',
                  icon: const Icon(Icons.home_outlined, size: 18),
                  color: StudioColors.textSecondary,
                  onPressed: _ready ? () => _navigate(ref.read(webBrowserSettingsProvider).homepageUrl) : null,
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
                IconButton(
                  tooltip: 'Import a saved image/PDF into Diagram Studio (as Source Material)',
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  color: StudioColors.textSecondary,
                  onPressed: _importToKnowledge,
                ),
                IconButton(
                  tooltip: 'Browser Settings',
                  icon: const Icon(Icons.menu, size: 18),
                  color: StudioColors.textSecondary,
                  onPressed: _openSettings,
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
