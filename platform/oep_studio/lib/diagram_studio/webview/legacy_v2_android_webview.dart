import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controller/diagram_studio_controller.dart';
import '../controller/diagram_studio_controller_provider.dart';
import '../simulation/diagram_simulation_service.dart';
import 'legacy_v2_android_bridge_transport.dart';
import 'legacy_v2_state_adapter.dart';
import 'legacy_v2_trust_boundary.dart';

/// AP-OEP-DIAGRAM-ANDROID-001 — the Android counterpart of
/// [LegacyV2WebViewPage] (`legacy_v2_webview.dart`), which stays
/// Windows-only and byte-for-byte unchanged. Same three-layer bridge
/// (`LegacyV2AndroidBridgeTransport` → [LegacyV2StateAdapter] →
/// [DiagramStudioController]), same unmodified V2 app — different
/// WebView plumbing, since `webview_flutter_windows`'s raw
/// `WebviewController` API doesn't exist on Android:
///
///  - Loads the V2 app from a native Android asset
///    (`file:///android_asset/index.html`, bundled via an extra Gradle
///    source set — see `android/app/build.gradle.kts`'s own comment for
///    why this is a native Android asset and not a Flutter one) instead
///    of a filesystem `file://` walk — Android has no accessible
///    monorepo checkout at runtime, and Flutter's own asset bundler
///    cannot reach a directory outside this package.
///  - Injects the bridge script from `NavigationDelegate.onPageFinished`
///    instead of WebView2's document-start hook — see
///    [LegacyV2AndroidBridgeTransport]'s own doc comment for why that's
///    safe here.
///
/// A structural copy of `legacy_v2_webview.dart`, not a parameterization
/// of it — same reasoning `compare_legacy_v2_webview.dart` already gives
/// for being its own file rather than a generic wrapper: keeps every
/// existing Windows test/behavior at zero risk from this addition.
class LegacyV2AndroidWebViewPage extends ConsumerStatefulWidget {
  const LegacyV2AndroidWebViewPage({this.instanceId, super.key});

  /// See [LegacyV2WebViewPage.instanceId]'s own doc comment — identical
  /// meaning/default here.
  final String? instanceId;

  /// The native Android asset URL — `eke-wiring-sim/index.html`'s own
  /// directory contents were declared as the *root* of an extra Gradle
  /// asset source set (`android/app/build.gradle.kts`), so its files
  /// land directly under `assets/`, not nested under a subdirectory.
  static const String _entryAssetUrl = 'file:///android_asset/index.html';

  @override
  ConsumerState<LegacyV2AndroidWebViewPage> createState() => _LegacyV2AndroidWebViewPageState();
}

class _LegacyV2AndroidWebViewPageState extends ConsumerState<LegacyV2AndroidWebViewPage> {
  String get _instanceId => widget.instanceId ?? primaryDiagramInstanceId;

  late final WebViewController _controller;
  late final LegacyV2AndroidBridgeTransport _transport;
  LegacyV2StateAdapter? _adapter;

  String? _error;
  bool _ready = false;

  /// Same "re-fit on actual rendered size change" mechanism as
  /// [LegacyV2WebViewPage]'s own `_lastFitSize` field — see that
  /// class's doc comment for why a `LayoutBuilder`-driven re-fit is used
  /// instead of a fixed delay.
  Size? _lastFitSize;

  bool _didInitialSeed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _transport = LegacyV2AndroidBridgeTransport(_controller);
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (kDebugMode) {
        await AndroidWebViewController.enableDebugging(true);
      }
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onPageFinished,
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _onNavigate(url);
          },
        ),
      );
      await _controller.loadRequest(Uri.parse(LegacyV2AndroidWebViewPage._entryAssetUrl));
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Fires once per navigation, once the page (including V2's own
  /// scripts) has finished loading — the point at which
  /// [LegacyV2AndroidBridgeTransport.attach] is safe to call (see that
  /// class's own doc comment).
  Future<void> _onPageFinished(String url) async {
    _onNavigate(url);
    await _transport.attach();
    if (mounted) setState(() {});
  }

  /// Same trust boundary as the Windows host — `file:///android_asset/...`
  /// is a genuine `file://` URL, so [isTrustedLegacyV2Url]'s directory-
  /// prefix check applies unchanged.
  void _onNavigate(String url) {
    final trusted = isTrustedLegacyV2Url(url, LegacyV2AndroidWebViewPage._entryAssetUrl);
    _transport.bridgeEnabled = trusted;
  }

  LegacyV2StateAdapter _ensureAdapter(DiagramStudioController controller) {
    final adapter = _adapter ??= LegacyV2StateAdapter(
      controller: controller,
      channel: _transport,
      simulationServiceResolver: () => ref.read(diagramSimulationServiceProvider),
    );
    // AP-DIAGRAM-V2-BRIDGE-SAVE-002 — see the Windows host's own doc
    // comment on this same line for the full rationale.
    ref.read(engineeringProjectServiceFamily(_instanceId).notifier).beforeSaveFlush = adapter.flushBeforeSave;
    return adapter;
  }

  void _triggerInitialSeed(LegacyV2StateAdapter adapter) {
    if (_didInitialSeed) return;
    _didInitialSeed = true;
    unawaited(adapter.initializeFromDocument().then((_) async {
      await _transport.interceptV2Save();
      if (mounted) setState(() {});
    }));
  }

  void _onDocumentChanged(LegacyV2StateAdapter adapter) {
    if (!_didInitialSeed) return;
    unawaited(adapter.reinitializeForDocument().then((_) {
      if (mounted) setState(() {});
    }));
  }

  Future<void> _fitV2ViewFromOep() => _transport.executeRawScript(
        'if (typeof zReset === "function") { zReset(); }',
      );

  @override
  void dispose() {
    // AP-DIAGRAM-V2-BRIDGE-SAVE-002 — best-effort; see the Windows host's
    // own doc comment on this same line for why this must never throw.
    try {
      ref.read(engineeringProjectServiceFamily(_instanceId).notifier).beforeSaveFlush = null;
    } catch (_) {}
    unawaited(_transport.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(engineeringProjectServiceFamily(_instanceId).select((s) => s.document.id), (previous, next) {
      final adapter = _adapter;
      if (adapter != null) _onDocumentChanged(adapter);
    });
    ref.listen(engineeringProjectServiceFamily(_instanceId).select((s) => s.documentPath), (previous, next) {
      if (previous == null && next != null) {
        final adapter = _adapter;
        if (adapter == null) return;
        unawaited(adapter.reinitializeForDocument().then((_) async {
          await _transport.interceptV2Save();
        }));
      }
    });

    final controllerAsync = ref.watch(diagramStudioControllerFamily(_instanceId));
    // The debug status bar this used to feed a display string for is
    // gone; the adapter must still be ensured/seeded on every build,
    // which is the actual load-bearing part of this watch.
    controllerAsync.whenData((controller) {
      final adapter = _ensureAdapter(controller);
      if (_ready) _triggerInitialSeed(adapter);
    });

    return Container(
      color: StudioColors.background,
      child: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load legacy V2:\n$_error',
                        style: const TextStyle(color: StudioColors.error, fontFamily: 'Consolas'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : !_ready
                    ? const Center(child: CircularProgressIndicator(color: StudioColors.selection))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.biggest;
                          if (size.isFinite && size != _lastFitSize) {
                            _lastFitSize = size;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _fitV2ViewFromOep();
                            });
                          }
                          return WebViewWidget(controller: _controller);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
