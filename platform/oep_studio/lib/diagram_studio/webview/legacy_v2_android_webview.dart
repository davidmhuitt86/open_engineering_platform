import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/notifications/platform_notification_service.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controller/diagram_studio_controller.dart';
import '../controller/diagram_studio_controller_provider.dart';
import '../simulation/diagram_simulation_service.dart';
import '../tabs/diagram_tabs_storage.dart';
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
  ConsumerState<LegacyV2AndroidWebViewPage> createState() =>
      _LegacyV2AndroidWebViewPageState();
}

class _LegacyV2AndroidWebViewPageState
    extends ConsumerState<LegacyV2AndroidWebViewPage> {
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

  /// AP-OEP-DIAGRAM-ANDROID-READY-RACE-001 — `_ready` used to be set
  /// `true` right after [WebViewController.loadRequest] itself returned,
  /// not after the page actually finished loading. `loadRequest`'s
  /// Future resolves once navigation is merely KICKED OFF (confirmed:
  /// `onPageFinished` — the real "page + V2's own scripts have loaded"
  /// signal — fires measurably later, asynchronously). Since `build()`'s
  /// `if (_ready) _triggerInitialSeed(adapter)` gates on this same flag,
  /// the entire seed-the-real-diagram-into-V2-then-reveal-the-canvas
  /// sequence was racing to start BEFORE [LegacyV2AndroidBridgeTransport
  /// .attach] had injected the bridge script — meaning every
  /// `window.__oepBridgeX && window.__oepBridgeX(...)` call in that
  /// sequence (including the canvas-reveal call) found `__oepBridgeX`
  /// undefined and silently no-opped via its own `&&` guard (never an
  /// exception — nothing for the try/catch in [_triggerInitialSeed] to
  /// catch). Net effect: the user's real diagram was never actually
  /// pushed into V2 at all, the `#canvas`/`#wire-layer` boot-hide CSS
  /// rule was never removed (permanently black canvas), and
  /// `_didInitialSeed` was already permanently `true` so the sequence
  /// never got a second chance to run once the page truly was ready —
  /// while V2's OWN bundled demo vehicle (loaded independently at page
  /// start, before any of this) kept rendering into elements the boot-hide
  /// rule doesn't cover (e.g. the minimap), which is what made it look
  /// like "something opened" even though it was never the real document.
  /// Fix: `_ready` now only becomes `true` once [_onPageFinished] has
  /// actually run AND [LegacyV2AndroidBridgeTransport.attach] has
  /// resolved — the same "safe to call bridge functions" point the
  /// original doc comment on [_onPageFinished] already correctly
  /// identified, just not yet wired to gate anything.
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
      await _controller
          .loadRequest(Uri.parse(LegacyV2AndroidWebViewPage._entryAssetUrl));
      // Deliberately NOT `setState(() => _ready = true)` here — see this
      // method's own doc comment. `_ready` now becomes true from
      // [_onPageFinished], the point the bridge script is actually
      // injected and safe to call into.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Fires once per navigation, once the page (including V2's own
  /// scripts) has finished loading — the point at which
  /// [LegacyV2AndroidBridgeTransport.attach] is safe to call (see that
  /// class's own doc comment). Also the point [_ready] becomes true —
  /// see [_init]'s own doc comment for why that moved here.
  Future<void> _onPageFinished(String url) async {
    _onNavigate(url);
    await _transport.attach();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  /// Same trust boundary as the Windows host — `file:///android_asset/...`
  /// is a genuine `file://` URL, so [isTrustedLegacyV2Url]'s directory-
  /// prefix check applies unchanged.
  void _onNavigate(String url) {
    final trusted =
        isTrustedLegacyV2Url(url, LegacyV2AndroidWebViewPage._entryAssetUrl);
    _transport.bridgeEnabled = trusted;
  }

  LegacyV2StateAdapter _ensureAdapter(DiagramStudioController controller) {
    final adapter = _adapter ??= LegacyV2StateAdapter(
      controller: controller,
      channel: _transport,
      simulationServiceResolver: () =>
          ref.read(diagramSimulationServiceProvider),
    );
    // AP-DIAGRAM-V2-BRIDGE-SAVE-002 — see the Windows host's own doc
    // comment on this same line for the full rationale.
    ref
        .read(engineeringProjectServiceFamily(_instanceId).notifier)
        .beforeSaveFlush = adapter.flushBeforeSave;
    return adapter;
  }

  /// AP-OEP-DIAGRAM-ANDROID-CANVAS-REVEAL-001 — the canvas-reveal chain
  /// (`initializeFromDocument()` → `interceptV2Save()` →
  /// `__oepBridgeRevealCanvas()`) used to be a bare `unawaited(...)` with
  /// no error handling: if ANY step threw, the `#canvas`/`#wire-layer`
  /// `visibility: hidden` rule injected at boot (legacy_v2_bridge_script.dart)
  /// was never removed, and the failure was silently swallowed by the
  /// unawaited Future — the user saw permanently blank/black WebView
  /// content with no spinner (`_ready` is already true by this point)
  /// and no error (`_error` is a completely separate field this method
  /// never touched). Wrapping this in try/catch and routing a failure
  /// into `_error` turns that silent black screen into the same visible
  /// "Failed to load legacy V2: ..." message the Windows host already
  /// shows for its own `_init()` failures, instead of an undiagnosable
  /// blank canvas.
  void _triggerInitialSeed(LegacyV2StateAdapter adapter) {
    if (_didInitialSeed) return;
    _didInitialSeed = true;
    unawaited(() async {
      try {
        await adapter.initializeFromDocument();
        await _transport.interceptV2Save();
        // AP-OEP-DIAGRAM-BOOT-UNTITLED-001 companion fix — see the
        // Windows host's own doc comment on this same call for why: V2's
        // own demo-vehicle boot is hidden from first paint by an injected
        // style rule (legacy_v2_bridge_script.dart, shared byte-for-byte
        // with this platform), revealed only once the real document has
        // actually been seeded.
        await _transport.executeRawScript(
            'if (typeof window.__oepBridgeRevealCanvas === "function") { window.__oepBridgeRevealCanvas(); }');
        // AP-OEP-DIAGRAM-ANDROID-CANVAS-REVEAL-002 — the view-fit
        // (`zReset()`, `_fitV2ViewFromOep`) that centers/scales the main
        // canvas on the diagram is triggered separately, from `build()`'s
        // `LayoutBuilder` noticing the widget's own SIZE change — which
        // only fires once for a given screen size and, on a phone where
        // the screen dimensions never change across this whole sequence,
        // could run (and compute its pan/zoom) BEFORE this reveal call
        // above ever removes the `visibility: hidden` rule blocking
        // `#canvas`/`#wire-layer`. A fit computed against still-hidden,
        // effectively zero-size elements produces a bogus pan/zoom (the
        // real diagram data is present — confirmed live: the minimap,
        // which isn't affected by this same pan/zoom state, shows the
        // correct diagram — but the MAIN canvas view ends up positioned/
        // scaled somewhere with nothing visible in it). Re-running the
        // fit here, now that the canvas is guaranteed actually visible,
        // is the fix — cheap and idempotent (V2's own `zReset()` is a
        // pure recompute, not a toggle).
        await _fitV2ViewFromOep();
        if (mounted) setState(() {});
      } catch (e) {
        // Allow a retry: if the underlying cause was transient (e.g. the
        // WebView briefly not ready), a later rebuild can attempt the
        // seed again instead of being permanently stuck on this one
        // failure.
        _didInitialSeed = false;
        if (mounted) setState(() => _error = 'canvas reveal failed: $e');
      }
    }());
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
      ref
          .read(engineeringProjectServiceFamily(_instanceId).notifier)
          .beforeSaveFlush = null;
    } catch (_) {}
    unawaited(_transport.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
        engineeringProjectServiceFamily(_instanceId)
            .select((s) => s.document.id), (previous, next) {
      final adapter = _adapter;
      if (adapter != null) _onDocumentChanged(adapter);
    });
    ref.listen(
        engineeringProjectServiceFamily(_instanceId)
            .select((s) => s.documentPath), (previous, next) {
      if (previous == null && next != null) {
        final adapter = _adapter;
        if (adapter == null) return;
        unawaited(adapter.reinitializeForDocument().then((_) async {
          await _transport.interceptV2Save();
        }));
      }
    });

    final controllerAsync =
        ref.watch(diagramStudioControllerFamily(_instanceId));
    // The debug status bar this used to feed a display string for is
    // gone; the adapter must still be ensured/seeded on every build,
    // which is the actual load-bearing part of this watch.
    controllerAsync.whenData((controller) {
      final adapter = _ensureAdapter(controller);
      if (_ready) _triggerInitialSeed(adapter);
    });

    // AP-OEP-DIAGRAM-ANDROID-TOOLBAR-001 — the Load-Previous/Open/Save/
    // Save As overlay the Windows host (`legacy_v2_webview.dart`) already
    // has was never ported here when this file was split off as its own
    // structural copy (see class doc comment): this page had no way to
    // open or save a diagram at all. Duplicated (not shared/imported)
    // deliberately, matching this codebase's own established convention
    // for these platform-split WebView host files — see the class doc
    // comment's "structural copy, not a parameterization" rationale.
    final documentPath = ref.watch(engineeringProjectServiceFamily(_instanceId)
        .select((s) => s.documentPath));

    return Container(
      color: StudioColors.background,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Failed to load legacy V2:\n$_error',
                            style: const TextStyle(
                                color: StudioColors.error,
                                fontFamily: 'Consolas'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : !_ready
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: StudioColors.selection))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final size = constraints.biggest;
                              if (size.isFinite && size != _lastFitSize) {
                                _lastFitSize = size;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted) _fitV2ViewFromOep();
                                });
                              }
                              return WebViewWidget(controller: _controller);
                            },
                          ),
              ),
            ],
          ),
          if (_ready && _error == null)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AndroidLoadPreviousButton(
                      onPressed: () => _loadPreviousDocument(context)),
                  const SizedBox(width: 8),
                  _AndroidOpenButton(onPressed: () => _openDocument(context)),
                  const SizedBox(width: 8),
                  _AndroidSaveButton(
                    hasPath: documentPath != null,
                    onPressed: () => _saveDocument(context, documentPath),
                  ),
                  const SizedBox(width: 8),
                  _AndroidSaveAsButton(onPressed: () => _saveDocumentAs(context)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Mirrors the Windows host's own `_loadPreviousDocument` — see that
  /// method's doc comment (`legacy_v2_webview.dart`) for the full
  /// rationale; duplicated rather than shared per this file's own
  /// "structural copy" convention.
  Future<void> _loadPreviousDocument(BuildContext context) async {
    final fileSuffix =
        _instanceId == primaryDiagramInstanceId ? '' : '_$_instanceId';
    final stored = await DiagramTabsStorage.load(fileSuffix: fileSuffix);
    String? path;
    if (stored.activeTabId != null) {
      for (final tab in stored.tabs) {
        if (tab.id == stored.activeTabId) {
          path = tab.path;
          break;
        }
      }
    }
    path ??= stored.tabs.isNotEmpty ? stored.tabs.last.path : null;
    if (path == null) {
      if (context.mounted) {
        PlatformNotificationService.error(
            context, 'No previous diagram found.');
      }
      return;
    }
    try {
      await ref
          .read(diagramStudioControllerFamily(_instanceId))
          .requireValue
          .openDocument(path);
      if (context.mounted) {
        PlatformNotificationService.success(
            context, 'Loaded previous diagram "$path".');
      }
    } catch (error) {
      if (context.mounted) {
        PlatformNotificationService.error(
            context, 'Couldn\'t load previous diagram "$path": $error');
      }
    }
  }

  /// Mirrors the Windows host's own `_openDocument` — see that method's
  /// doc comment for the full rationale.
  Future<void> _openDocument(BuildContext context) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json'])
      ],
    );
    if (file == null) return;
    try {
      await ref
          .read(diagramStudioControllerFamily(_instanceId))
          .requireValue
          .openDocument(file.path);
      if (context.mounted) {
        PlatformNotificationService.success(
            context, 'Diagram opened from ${file.path}.');
      }
    } catch (error) {
      if (context.mounted) {
        PlatformNotificationService.error(
            context, 'Couldn\'t open "${file.path}": $error');
      }
    }
  }

  /// Mirrors the Windows host's own `_saveDocument`.
  Future<void> _saveDocument(BuildContext context, String? documentPath) async {
    if (documentPath == null) {
      await _saveDocumentAs(context);
      return;
    }
    await ref
        .read(engineeringProjectServiceFamily(_instanceId).notifier)
        .saveDocument();
    if (context.mounted) {
      PlatformNotificationService.success(context, 'Diagram saved.');
    }
  }

  /// Mirrors the Windows host's own `_saveDocumentAs`.
  Future<void> _saveDocumentAs(BuildContext context) async {
    final location = await getSaveLocation(
      suggestedName: 'diagram.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json'])
      ],
    );
    if (location == null) return;
    await ref
        .read(diagramStudioControllerFamily(_instanceId))
        .requireValue
        .saveDocumentAs(location.path);
    if (context.mounted) {
      PlatformNotificationService.success(
          context, 'Diagram saved to ${location.path}.');
    }
  }
}

/// Mirrors the Windows host's own `_LoadPreviousButton`. Named with an
/// `_Android` prefix (rather than reusing the Windows file's identical
/// private class name) purely so both files can be open/greppable side by
/// side without name confusion — these are two separate, intentionally
/// duplicated widgets, not a shared one split across files.
class _AndroidLoadPreviousButton extends StatelessWidget {
  const _AndroidLoadPreviousButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudioColors.surfaceRaised,
      borderRadius: BorderRadius.circular(4),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 14, color: StudioColors.textPrimary),
              SizedBox(width: 6),
              Text(
                'Load Previous',
                style: TextStyle(
                    fontSize: 12,
                    color: StudioColors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AndroidOpenButton extends StatelessWidget {
  const _AndroidOpenButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudioColors.surfaceRaised,
      borderRadius: BorderRadius.circular(4),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 14, color: StudioColors.textPrimary),
              SizedBox(width: 6),
              Text(
                'Open',
                style: TextStyle(
                    fontSize: 12,
                    color: StudioColors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AndroidSaveButton extends StatelessWidget {
  const _AndroidSaveButton({required this.hasPath, required this.onPressed});

  final bool hasPath;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudioColors.surfaceRaised,
      borderRadius: BorderRadius.circular(4),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.save_outlined,
                  size: 14, color: StudioColors.textPrimary),
              const SizedBox(width: 6),
              Text(
                hasPath ? 'Save' : 'Save As…',
                style: const TextStyle(
                    fontSize: 12,
                    color: StudioColors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AndroidSaveAsButton extends StatelessWidget {
  const _AndroidSaveAsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudioColors.surfaceRaised,
      borderRadius: BorderRadius.circular(4),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.save_as_outlined,
                  size: 14, color: StudioColors.textPrimary),
              SizedBox(width: 6),
              Text(
                'Save As…',
                style: TextStyle(
                    fontSize: 12,
                    color: StudioColors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
