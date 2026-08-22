import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controller/diagram_studio_controller.dart';
import '../controller/diagram_studio_controller_provider.dart';
import '../simulation/diagram_simulation_service.dart';
import 'legacy_v2_bridge_transport.dart';
import 'legacy_v2_state_adapter.dart';
import 'legacy_v2_trust_boundary.dart';

/// AP-DIAGRAM-V2-WEBVIEW-001 — a minimal Windows WebView host that loads
/// the **existing, unmodified** legacy V2 reference application
/// (`reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html`) directly
/// from its repository location, and wires it to OEP through the
/// three-layer bridge established by this task:
///
/// ```
/// LegacyV2WebViewPage (this class)
///         |  owns WebviewController + Webview widget only
///         v
/// LegacyV2BridgeTransport  — WebView<->Dart messages, no OEP knowledge
///         v
/// LegacyV2StateAdapter     — V2 id <-> OEP node id, coordinates, loop guard
///         v
/// DiagramStudioController  — unchanged existing addNode/moveNodes/commands
///         v
/// OEP Engine                — unchanged existing MoveNodesCommand
/// ```
///
/// This widget itself owns none of the OEP ID mapping, coordinate
/// conversion, Engine command logic, persistence logic, or business
/// rules that produced the earlier POC's single-file implementation —
/// those now live in [LegacyV2BridgeTransport] and [LegacyV2StateAdapter]
/// respectively, per this task's explicit component boundaries. See
/// `docs/DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md` for the full account
/// of why this split exists and what each layer may/may not know.
///
/// **Package/API choice** (unchanged since POC-001/002/003 — restated
/// briefly): `webview_flutter_windows` 1.1.1's *actual* API
/// (`WebviewController`/`Webview`, not `webview_flutter`'s abstraction,
/// which this package version does not implement) is what works on
/// Windows — see `docs/DIAGRAM_STUDIO_V2_WEBVIEW_POC.md` for the full
/// record.
///
/// **Loading mechanism:** `WebviewController.loadUrl('file:///...')`
/// pointed directly at the reference directory's own `index.html` — no
/// copy into the Studio source tree, no bundling step, no local HTTP
/// server.
///
/// **Platform:** Windows only, dev-only entry point.
class LegacyV2WebViewPage extends ConsumerStatefulWidget {
  const LegacyV2WebViewPage({super.key});

  @override
  ConsumerState<LegacyV2WebViewPage> createState() => _LegacyV2WebViewPageState();
}

class _LegacyV2WebViewPageState extends ConsumerState<LegacyV2WebViewPage> {
  final WebviewController _controller = WebviewController();
  late final LegacyV2BridgeTransport _transport = LegacyV2BridgeTransport(_controller);
  LegacyV2StateAdapter? _adapter;

  String? _error;
  bool _ready = false;

  /// AP-OEP-DIAGRAM-UX-004 — the last size Fit View was run against.
  /// V2 runs its own one-shot "Fit View" (`zReset()`) during page load,
  /// computed against whatever size the control happened to be at that
  /// moment — which, now that this widget is preloaded hidden at app
  /// boot (`StudioShell._diagramStudioHost`, AP-OEP-DIAGRAM-UX-001), is
  /// its *hidden* size (constrained by the normal Studio chrome/sidebar
  /// layout), not its eventual full-screen size once the user actually
  /// switches to Diagram Studio. A single delayed one-shot re-fit (this
  /// widget's previous fix) only covered the original race and broke
  /// again under preloading. V2 has no resize-observer of its own (§1 of
  /// `EKE_INTERACTION_MODEL.md`: "on-demand, imperative... no per-frame
  /// render loop"), so re-running Fit View every time the *actual*
  /// rendered size changes (tracked via `LayoutBuilder` around the
  /// `Webview`, not a fixed delay) is the general, correct fix — it
  /// covers the preload-then-reveal transition, ordinary window resizes,
  /// and any future timing change alike, rather than guessing a delay.
  Size? _lastFitSize;

  // Display-only, populated via transport.onStatus — the same status bar
  // POC-002 established, unchanged in meaning.
  String? _v2SelectedModuleId;
  int? _v2ModuleCount;
  int? _v2WireCount;
  bool? _v2EditMode;
  String _lastMoveStatus = 'no V2-originated move yet';

  /// AP-STUDIO-WEB-SURFACE-002, Phase 9 — the trust boundary is live
  /// (bridge active) by default while V2 loads, and re-evaluated on
  /// every URL change (see `_controller.url.listen` in [_init]).
  bool _bridgeTrusted = true;

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 7 — set once the first
  /// `adapter.initializeFromDocument()` call has been kicked off, so
  /// [build] doesn't re-trigger it on every rebuild.
  bool _didInitialSeed = false;

  /// Resolves the legacy V2 entry point's `file://` URI by walking
  /// upward from this process's own directory looking for the monorepo
  /// marker path `reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html`.
  /// Robust to both `flutter run` (cwd = Flutter project root) and a
  /// directly-launched built `.exe` (cwd = build output dir) — see
  /// `docs/DIAGRAM_STUDIO_V2_WEBVIEW_POC.md` §5 for why a fixed
  /// `.parent.parent` guess was wrong. Dev-only, POC-only resolution —
  /// not meant to survive into any packaged build.
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

  /// AP-STUDIO-WEB-SURFACE-002, Phase 9 — re-evaluated on every
  /// navigation. Disables [LegacyV2BridgeTransport.bridgeEnabled] the
  /// moment the WebView shows anything outside V2's own trusted
  /// directory (`isTrustedLegacyV2Url`), and re-enables it if the user
  /// navigates back within that boundary (e.g. via the browser Back
  /// gesture, or reloading V2 itself) — restoration is automatic, not a
  /// separate manual action, since the boundary check itself is what's
  /// authoritative, not "was it ever trusted before."
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

  /// Constructed lazily once the controller is available, and wires
  /// itself to [_transport]'s `onModuleMoved` callback — the adapter is
  /// the only layer that ever calls into [DiagramStudioController].
  LegacyV2StateAdapter _ensureAdapter(DiagramStudioController controller) {
    return _adapter ??= LegacyV2StateAdapter(
      controller: controller,
      channel: _transport,
      // AP-DIAGRAM-V2-BRIDGE-006 — resolved fresh per request rather than
      // captured once (see the adapter's own doc comment on this field).
      simulationServiceResolver: () => ref.read(diagramSimulationServiceProvider),
    )
      ..onAuthoritativeResult = _onAuthoritativeResult
      ..onAuthoritativeLabel = _onAuthoritativeLabel
      ..onModuleRemoved = _onModuleRemoved
      ..onWireBridged = _onWireBridged
      ..onWireUnbridgeable = _onWireUnbridgeable
      ..onWireRemoved = _onWireRemoved;
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 7 — the very first seeding, once
  /// (WebView ready, adapter constructed). Deliberately not awaited by
  /// the caller (`build`) — `initializeFromDocument` itself is what
  /// keeps `LegacyV2StateAdapter.isReady` false for its own duration, so
  /// no message can slip through while it runs; this just needs to
  /// trigger it and refresh the status bar once it's done.
  void _triggerInitialSeed(LegacyV2StateAdapter adapter) {
    if (_didInitialSeed) return;
    _didInitialSeed = true;
    unawaited(adapter.initializeFromDocument().then((_) async {
      // AP-DIAGRAM-V2-BRIDGE-003, Phase 4 — applied after seeding
      // (i.e. after V2's own page has fully loaded and defined its own
      // `saveLayout`), not before — see `interceptV2Save`'s own doc
      // comment for why order matters here.
      await _transport.interceptV2Save();
      if (mounted) setState(() {});
    }));
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 8 — the active OEP document
  /// changed. Only meaningful after the first seed has already happened
  /// (a change observed *before* that point is just the initial value
  /// arriving, not a real switch).
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
    // AP-DIAGRAM-V2-BRIDGE-002, Phase 8 — the reactive "which document is
    // active" signal (unlike `DiagramStudioController`, this Riverpod
    // state genuinely changes identity on open/close/switch — see the
    // production architecture doc's "Document switching lifecycle").
    // AP-DIAGRAM-V2-BRIDGE-003, Phase 2 — `document.id` (not `.path`),
    // since two different never-saved documents both have `path == null`
    // but distinct `id`s (see `DiagramDocument.id`'s own doc comment).
    ref.listen(engineeringProjectServiceProvider.select((s) => s.document.id), (previous, next) {
      final adapter = _adapter;
      if (adapter != null) _onDocumentChanged(adapter);
    });
    // AP-OEP-DIAGRAM-UX-002 — the former "Save As…" toolbar button's
    // reseed-after-save logic, generalized so it fires no matter what
    // triggered the save (this button, or the Command Palette's
    // `diagram.saveDocumentAs`, which calls
    // `EngineeringProjectServiceNotifier.saveDocumentAs` directly and
    // has no idea a V2 bridge is even involved). Save As is a path
    // transition from `null` to non-null with the *same* document id
    // (`.document.id` alone, watched above, doesn't change on Save As —
    // confirmed by `DiagramDocument.id`'s own doc comment, which is
    // exactly why that listener alone was never enough here).
    ref.listen(engineeringProjectServiceProvider.select((s) => s.documentPath), (previous, next) {
      if (previous == null && next != null) {
        final adapter = _adapter;
        if (adapter == null) return;
        unawaited(adapter.reinitializeForDocument().then((_) async {
          await _transport.interceptV2Save();
        }));
      }
    });

    final controllerAsync = ref.watch(diagramStudioControllerProvider);
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

    // AP-DIAGRAM-V2-OEP-UI-001 — no own Scaffold/AppBar: this widget is
    // embedded directly inside `WebSurfacesHostPage`'s `IndexedStack`
    // (which itself has no Scaffold), so a nested AppBar previously
    // produced double chrome.
    //
    // AP-OEP-DIAGRAM-UX-002 — the toolbar row that used to live here
    // (Undo/Fit View/Reload/Save As icon buttons) was removed entirely:
    // Undo and Save As are already reachable platform-wide via the
    // Command Palette (`diagram.undo`/`diagram.saveDocumentAs`, both
    // registered in `command_registry.dart`) — Save As's V2-reseed side
    // effect is now wired to fire automatically from any trigger (see
    // the `documentPath` listener above), so nothing is lost there.
    // Fit View duplicates a button V2's own toolbar already has. Reload
    // had no equivalent elsewhere and is a real, if minor, capability
    // gap accepted here rather than kept as a dedicated button.
    //
    // Undo's reseed side effect (`adapter.resyncLastBridgedToV2()`,
    // re-synchronizing whichever V2 module a bridge-originated move last
    // touched) is a real, honest, narrower gap than Save As's: it can
    // only fire reliably from a caller that already holds the specific
    // node/relationship id that changed (this widget's own
    // `_undoLastV2Move`, since removed, got that context from the same
    // adapter that performed the original bridged move). The Engine's
    // `EditingService` does emit a real, typed 'undo'/'redo' event
    // (`EngineEventBus`, `editing_service.dart`) that a generic listener
    // could react to, but that bus is not exposed on `EngineeringEngine`'s
    // public surface today — adding that getter is a (small) Engine
    // change, out of scope for this Studio-layer cleanup. Net effect: a
    // Command-Palette-triggered Undo while Diagram Studio is open undoes
    // correctly in the Engine (and dirty-state correctly, unaffected by
    // this change) but may leave V2's on-screen module position stale
    // until the next V2-originated action re-syncs it — a real, minor,
    // documented gap, not a silently dropped one.
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
                              'Bridge: ${_bridgeTrusted ? "AUTHORIZED (trusted V2 content)" : "DISABLED (navigated away from trusted V2 content)"}\n'
                              'V2 -> Transport -> Flutter: ${_v2ModuleCount ?? '?'} module(s), '
                              '${_v2WireCount ?? '?'} wire(s), selected: ${_v2SelectedModuleId ?? 'none'}, '
                              'V2 mode: ${_v2EditMode == true ? 'Layout' : _v2EditMode == false ? 'Normal' : 'unknown'}\n'
                              'Flutter -> DiagramStudioController -> Engine (read-only): $oepStatus\n'
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
