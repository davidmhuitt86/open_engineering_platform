import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/theme/studio_colors.dart';
import '../simulation/diagram_simulation_service.dart';
import '../webview/legacy_v2_android_bridge_transport.dart';
import '../webview/legacy_v2_bridge_transport.dart' show V2StatusMessage;
import '../webview/legacy_v2_state_adapter.dart';
import '../webview/legacy_v2_trust_boundary.dart';
import 'compare_diagram_controller.dart';
import 'compare_project_provider.dart';

/// AP-OEP-DIAGRAM-ANDROID-001 — the Android counterpart of
/// [CompareLegacyV2WebViewPage] (`compare_legacy_v2_webview.dart`, which
/// stays Windows-only and unchanged). A structural copy of
/// `legacy_v2_android_webview.dart`'s `LegacyV2AndroidWebViewPage`, not a
/// parameterization of it — same reasoning the Windows Primary/Compare
/// pair already gives for being separate files (§ their own doc
/// comments): keeps every existing widget's test/behavior at zero risk.
/// Watches [compareDiagramControllerProvider]/
/// [compareEngineeringProjectServiceProvider] instead of the Primary
/// document's providers — the only substantive difference from
/// [LegacyV2AndroidWebViewPage].
class CompareLegacyV2AndroidWebViewPage extends ConsumerStatefulWidget {
  const CompareLegacyV2AndroidWebViewPage({super.key});

  static const String _entryAssetUrl = 'file:///android_asset/index.html';

  @override
  ConsumerState<CompareLegacyV2AndroidWebViewPage> createState() => _CompareLegacyV2AndroidWebViewPageState();
}

class _CompareLegacyV2AndroidWebViewPageState extends ConsumerState<CompareLegacyV2AndroidWebViewPage> {
  late final WebViewController _controller;
  late final LegacyV2AndroidBridgeTransport _transport;
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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _transport = LegacyV2AndroidBridgeTransport(_controller);
    _transport.onStatus = _onStatus;
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
      await _controller.loadRequest(Uri.parse(CompareLegacyV2AndroidWebViewPage._entryAssetUrl));
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _onPageFinished(String url) async {
    _onNavigate(url);
    await _transport.attach();
    if (mounted) setState(() {});
  }

  void _onNavigate(String url) {
    final trusted = isTrustedLegacyV2Url(url, CompareLegacyV2AndroidWebViewPage._entryAssetUrl);
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
                        'Failed to load legacy V2:\n$_error',
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
                                return WebViewWidget(controller: _controller);
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
