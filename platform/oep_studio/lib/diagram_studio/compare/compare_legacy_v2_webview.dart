import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../../core/theme/studio_colors.dart';
import '../simulation/diagram_simulation_service.dart';
import '../webview/legacy_v2_bridge_transport.dart';
import '../webview/legacy_v2_state_adapter.dart';
import '../webview/legacy_v2_trust_boundary.dart';
import 'compare_diagram_controller.dart';
import 'compare_legacy_v2_android_webview.dart';
import 'compare_project_provider.dart';

/// AP-OEP-DIAGRAM-COMPARE-001/AP-OEP-DIAGRAM-ANDROID-001 — the Compare
/// pane's own Legacy V2 WebView host, and the stable public entry point
/// every call site embeds. Picks [_WindowsCompareLegacyV2WebViewPage]
/// (this file's own original implementation, unchanged) on Windows,
/// [CompareLegacyV2AndroidWebViewPage] everywhere else — same platform
/// branch [LegacyV2WebViewPage] (`diagram_studio/webview/legacy_v2_webview.dart`)
/// uses, for the same reasons.
class CompareLegacyV2WebViewPage extends StatelessWidget {
  const CompareLegacyV2WebViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) return const _WindowsCompareLegacyV2WebViewPage();
    return const CompareLegacyV2AndroidWebViewPage();
  }
}

/// A structural copy of `diagram_studio/webview/legacy_v2_webview.dart`'s
/// Windows implementation, not a parameterization of it — kept as a
/// separate file so the Primary pane's widget (and its own test suite)
/// carry zero risk from this addition.
///
/// Owns its own `WebviewController`/`LegacyV2BridgeTransport`/
/// `LegacyV2StateAdapter` triple, exactly like the Primary widget does —
/// each is a genuinely independent native WebView2 process/JS context,
/// so two of these can run side by side with no shared state between
/// them (confirmed during the audit for this package: neither
/// `LegacyV2BridgeTransport` nor `LegacyV2StateAdapter` has any
/// static/global state). Watches [compareDiagramControllerProvider]/
/// [compareEngineeringProjectServiceProvider] instead of the Primary
/// document's providers — this is the only substantive difference from
/// the Primary widget.
class _WindowsCompareLegacyV2WebViewPage extends ConsumerStatefulWidget {
  const _WindowsCompareLegacyV2WebViewPage();

  @override
  ConsumerState<_WindowsCompareLegacyV2WebViewPage> createState() => _WindowsCompareLegacyV2WebViewPageState();
}

class _WindowsCompareLegacyV2WebViewPageState extends ConsumerState<_WindowsCompareLegacyV2WebViewPage> {
  final WebviewController _controller = WebviewController();
  late final LegacyV2BridgeTransport _transport = LegacyV2BridgeTransport(_controller);
  LegacyV2StateAdapter? _adapter;

  String? _error;
  bool _ready = false;

  Size? _lastFitSize;

  String? _v2SelectedModuleId;
  int? _v2ModuleCount;
  int? _v2WireCount;
  bool? _v2EditMode;
  String _lastMoveStatus = 'no V2-originated move yet';

  bool _bridgeTrusted = true;
  bool _didInitialSeed = false;

  /// Same resolution strategy as `LegacyV2WebViewPage._v2EntryPointUri` —
  /// both panes load the same static, unmodified V2 entry file; loading
  /// one local file from two independent WebView2 processes is safe,
  /// the same as two browser tabs pointed at the same URL.
  static Uri _v2EntryPointUri() {
    const marker = 'reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html';
    final startDirs = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in startDirs) {
      var dir = start;
      for (var i = 0; i < 8; i++) {
        final candidate = File(
          '${dir.path}${Platform.pathSeparator}${marker.replaceAll('/', Platform.pathSeparator)}',
        );
        if (candidate.existsSync()) {
          return Uri.file(candidate.path);
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    final repoRoot = Directory(Directory.current.path).parent.parent;
    final indexHtml = File(
      '${repoRoot.path}${Platform.pathSeparator}reference${Platform.pathSeparator}legacy_wiring_sim_v2'
      '${Platform.pathSeparator}eke-wiring-sim${Platform.pathSeparator}index.html',
    );
    return Uri.file(indexHtml.path);
  }

  @override
  void initState() {
    super.initState();
    _transport.onStatus = _onStatus;
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _transport.attach();
      final entryUrl = _v2EntryPointUri().toString();
      _controller.url.listen((url) => _onNavigate(url, entryUrl));
      await _controller.loadUrl(entryUrl);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onNavigate(String url, String trustedEntryUrl) {
    final trusted = isTrustedLegacyV2Url(url, trustedEntryUrl);
    _transport.bridgeEnabled = trusted;
    if (!mounted) return;
    setState(() => _bridgeTrusted = trusted);
  }

  void _onStatus(V2StatusMessage status) {
    if (!mounted) return;
    setState(() {
      _v2SelectedModuleId = status.selectedModuleId;
      _v2ModuleCount = status.moduleCount;
      _v2WireCount = status.wireCount;
      _v2EditMode = status.editMode;
    });
  }

  LegacyV2StateAdapter _ensureAdapter(CompareDiagramController controller) {
    return _adapter ??= LegacyV2StateAdapter(
      controller: controller,
      channel: _transport,
      simulationServiceResolver: () => ref.read(diagramSimulationServiceProvider),
    )
      ..onAuthoritativeResult = _onAuthoritativeResult
      ..onAuthoritativeLabel = _onAuthoritativeLabel
      ..onModuleRemoved = _onModuleRemoved
      ..onWireBridged = _onWireBridged
      ..onWireUnbridgeable = _onWireUnbridgeable
      ..onWireRemoved = _onWireRemoved;
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

  void _onAuthoritativeResult(String v2ModuleId, String oepNodeId, double x, double y) {
    if (!mounted) return;
    setState(() {
      _lastMoveStatus = 'V2 "$v2ModuleId" -> OEP node $oepNodeId @ '
          '(${x.toStringAsFixed(0)}, ${y.toStringAsFixed(0)})';
    });
  }

  void _onAuthoritativeLabel(String v2ModuleId, String oepNodeId, String label) {
    if (!mounted) return;
    setState(() {
      _lastMoveStatus = 'V2 "$v2ModuleId" -> OEP node $oepNodeId label="$label"';
    });
  }

  void _onModuleRemoved(String v2ModuleId) {
    if (!mounted) return;
    setState(() {
      _lastMoveStatus = 'V2 "$v2ModuleId" removed from OEP graph';
    });
  }

  void _onWireBridged(String v2WireId, String oepRelationshipId) {
    if (!mounted) return;
    setState(() {
      _lastMoveStatus = 'V2 wire "$v2WireId" -> OEP relationship $oepRelationshipId';
    });
  }

  void _onWireUnbridgeable(String v2WireId) {
    if (!mounted) return;
    setState(() {
      _lastMoveStatus = 'V2 wire "$v2WireId" not bridged (an endpoint module has no OEP mapping)';
    });
  }

  void _onWireRemoved(String v2WireId) {
    if (!mounted) return;
    setState(() {
      _lastMoveStatus = 'V2 wire "$v2WireId" removed from OEP graph (create undone)';
    });
  }

  Future<void> _fitV2ViewFromOep() => _transport.executeRawScript(
        'if (typeof zReset === "function") { zReset(); }',
      );

  @override
  void dispose() {
    unawaited(_transport.dispose());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(compareEngineeringProjectServiceProvider.select((s) => s.document.id), (previous, next) {
      final adapter = _adapter;
      if (adapter != null) _onDocumentChanged(adapter);
    });
    ref.listen(compareEngineeringProjectServiceProvider.select((s) => s.documentPath), (previous, next) {
      if (previous == null && next != null) {
        final adapter = _adapter;
        if (adapter == null) return;
        unawaited(adapter.reinitializeForDocument().then((_) async {
          await _transport.interceptV2Save();
        }));
      }
    });

    final controllerAsync = ref.watch(compareDiagramControllerProvider);
    final oepStatus = controllerAsync.when(
      data: (controller) {
        final adapter = _ensureAdapter(controller);
        if (_ready) _triggerInitialSeed(adapter);
        final graph = controller.session?.graph;
        final base = graph == null
            ? 'no active document'
            : '${graph.nodes.length} node(s), ${graph.relationships.length} relationship(s) — '
                '"${controller.document.metadata.title}"'
                '${adapter.isReady ? '' : ' — initializing V2 from document…'}';
        return adapter.unbridgedV2ModuleIds.isEmpty
            ? base
            : '$base | ${adapter.unbridgedV2ModuleIds.length} V2 module(s) unbridged (no symbol mapping for their category)';
      },
      loading: () => 'loading…',
      error: (_, __) => 'unavailable',
    );

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
                        'Failed to load legacy V2:\n$_error\n\nExpected entry point:\n${_v2EntryPointUri()}',
                        style: const TextStyle(color: StudioColors.error, fontFamily: 'Consolas'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : !_ready
                    ? const Center(child: CircularProgressIndicator(color: StudioColors.selection))
                    : Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = constraints.biggest;
                                if (size.isFinite && size != _lastFitSize) {
                                  _lastFitSize = size;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) _fitV2ViewFromOep();
                                  });
                                }
                                return Webview(_controller);
                              },
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: StudioColors.surfaceSunken,
                              border: Border(top: BorderSide(color: StudioColors.border)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text(
                              'Compare pane — Bridge: ${_bridgeTrusted ? "AUTHORIZED" : "DISABLED"}\n'
                              'V2: ${_v2ModuleCount ?? '?'} module(s), ${_v2WireCount ?? '?'} wire(s), '
                              'selected: ${_v2SelectedModuleId ?? 'none'}, '
                              'mode: ${_v2EditMode == true ? 'Layout' : _v2EditMode == false ? 'Normal' : 'unknown'}\n'
                              '$oepStatus\n'
                              'Last move: $_lastMoveStatus',
                              style: TextStyle(
                                color: _bridgeTrusted ? StudioColors.success : StudioColors.warning,
                                fontFamily: 'Consolas',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
