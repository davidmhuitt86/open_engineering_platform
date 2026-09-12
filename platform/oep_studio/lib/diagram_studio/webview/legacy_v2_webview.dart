import 'dart:async';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../../core/notifications/platform_notification_service.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';
import '../compare/diagram_with_compare_pane.dart'
    show dmmPanelVisibleProvider, tracePanelVisibleProvider;
import '../controller/diagram_studio_controller.dart';
import '../controller/diagram_studio_controller_provider.dart';
import '../instruments/multimeter/multimeter_controller.dart';
import '../simulation/diagram_simulation_service.dart';
import '../tabs/diagram_tabs_storage.dart';
import '../trace/trace_controller.dart';
import 'legacy_v2_android_webview.dart';
import 'legacy_v2_bridge_transport.dart';
import 'legacy_v2_state_adapter.dart';
import 'legacy_v2_trust_boundary.dart';

/// AP-OEP-DIAGRAM-ANDROID-001 — the stable public entry point every call
/// site (`WebSurfacesHostPage`, `EngineeringWorkspacePage`,
/// `DiagramWithComparePane`) already embeds. Picks the platform-specific
/// implementation at build time: [_WindowsLegacyV2WebViewPage] (this
/// file's own original implementation, byte-for-byte unchanged — see its
/// doc comment) on Windows, [LegacyV2AndroidWebViewPage] everywhere else
/// this app currently runs. Existing tests that look up
/// `find.byType(LegacyV2WebViewPage)` are unaffected — this stays the
/// widget type in the tree either way, and every test in this repo runs
/// on Windows, so the branch always resolves to the original
/// implementation during `flutter test`.
/// OEP-STUDIO-BRANDING-V1 — the narrow, real hook `OepStudioHeader`'s own
/// view-swap control (lib/diagram_studio/header/oep_studio_header.dart)
/// uses to actually flip the PRIMARY Diagram Studio instance's live V2
/// page between its Diagram and Simulation view — calling V2's own,
/// already-working `toggleSimPanel()` (`js/ui/sim-panel.js`) rather than
/// only changing the header's own chrome. `null` whenever no primary
/// instance is currently mounted/ready (header falls back to a
/// chrome-only swap in that case — see its own doc comment). Only ever
/// set by the primary instance (`instanceId == primaryDiagramInstanceId`)
/// — a second/compare Diagram Studio tab never overwrites this, so the
/// one shared header always controls the one primary session, matching
/// [LegacyV2WebViewPage]'s own "instanceId == null is the primary
/// instance" convention.
final legacyV2ToggleSimulationViewProvider =
    StateProvider<Future<void> Function()?>((ref) => null);

class LegacyV2WebViewPage extends StatelessWidget {
  const LegacyV2WebViewPage({this.instanceId, super.key});

  /// AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — the
  /// `WorkspaceTab.id` this host's Diagram state belongs to. `null`
  /// (every existing call site — `WebSurfacesHostPage`,
  /// `DiagramWithComparePane`) means the primary instance
  /// (`primaryDiagramInstanceId`), preserving every existing caller's
  /// behavior byte-for-byte. Only a genuinely new, non-primary Diagram
  /// Workspace tab passes a real id here.
  final String? instanceId;

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows)
      return _WindowsLegacyV2WebViewPage(instanceId: instanceId);
    return LegacyV2AndroidWebViewPage(instanceId: instanceId);
  }
}

/// AP-DIAGRAM-V2-WEBVIEW-001 — a minimal Windows WebView host that loads
/// the **existing, unmodified** legacy V2 reference application
/// (`reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html`) directly
/// from its repository location, and wires it to OEP through the
/// three-layer bridge established by this task:
///
/// ```
/// _WindowsLegacyV2WebViewPage (this class)
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
/// **Platform:** Windows only — see [LegacyV2WebViewPage] (the public
/// entry point above) for how Android reaches a different implementation.
class _WindowsLegacyV2WebViewPage extends ConsumerStatefulWidget {
  const _WindowsLegacyV2WebViewPage({this.instanceId});

  final String? instanceId;

  @override
  ConsumerState<_WindowsLegacyV2WebViewPage> createState() =>
      _WindowsLegacyV2WebViewPageState();
}

class _WindowsLegacyV2WebViewPageState
    extends ConsumerState<_WindowsLegacyV2WebViewPage> {
  /// Resolves once per `State` lifetime — this `State` instance is
  /// itself already scoped to one `WorkspaceTab` (a fresh widget/State
  /// per Diagram tab, per `EngineeringWorkspacePage._buildTabContent`),
  /// so the instance id never changes mid-lifetime.
  String get _instanceId => widget.instanceId ?? primaryDiagramInstanceId;

  final WebviewController _controller = WebviewController();
  late final LegacyV2BridgeTransport _transport =
      LegacyV2BridgeTransport(_controller);
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

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 7 — set once the first
  /// `adapter.initializeFromDocument()` call has been kicked off, so
  /// [build] doesn't re-trigger it on every rebuild.
  bool _didInitialSeed = false;

  /// AP-OEP-DIAGRAM-OPEN-RACE-001 — serializes every seed operation
  /// (the very first one, and every later document switch) onto one
  /// chain, so they can never run concurrently. `_didInitialSeed` being
  /// set synchronously and immediately (right above, at the *start* of
  /// `_triggerInitialSeed`, before any of its own `await`s) means a
  /// document switch — "Open...", "Load Previous Diagram" — arriving
  /// while that first seed is still mid-flight (its own
  /// `_waitForV2Ready()` + `initializeFromDocument()` chain can easily
  /// still be running: V2 hasn't finished loading yet, which is
  /// precisely the scenario `_waitForV2Ready` exists to wait out) used
  /// to start a SECOND, fully independent seed operation right on top of
  /// the first, each with its own concurrent `executeScript` calls
  /// against V2's still-loading page. Confirmed as the actual mechanism
  /// behind "the diagram I opened right after launch never loads, no
  /// error, but works after restarting the app": whichever seed's calls
  /// happened to land last silently won, and if that was the *original*
  /// (blank/previous) document's seed rather than the one just
  /// requested, the diagram the user asked to open never visibly
  /// appeared — with nothing to show as an error, since both operations
  /// "succeeded" from Dart's point of view. Chaining every seed through
  /// this future makes them provably sequential instead.
  Future<void> _seedChain = Future<void>.value();

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
      // OEP-STUDIO-BRANDING-V1 — only the primary instance publishes the
      // swap hook (§ legacyV2ToggleSimulationViewProvider's own doc
      // comment).
      if (_instanceId == primaryDiagramInstanceId) {
        ref.read(legacyV2ToggleSimulationViewProvider.notifier).state =
            () => _transport.executeRawScript('toggleSimPanel()');
        // OEP-STUDIO-BRANDING-V1 — Trace/Measure are the only two
        // engineering-toolbar groups backed by real FLUTTER logic
        // (TraceController/MultimeterController) rather than a V2-native
        // JS function; only the primary instance wires this, matching
        // the swap hook just above (Compare/DMM/Trace are primary-only
        // stopgap infrastructure, § DiagramWithComparePane's own doc
        // comment).
        _transport.onEngineeringCommand = _handleEngineeringCommand;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// OEP-STUDIO-BRANDING-V1 — the engineering toolbar's Trace/Measure
  /// dropdown items (index.html's `dd-trace`/`dd-measure`, via
  /// `toolbarSendEngineeringCommand` in `js/ui/toolbar.js`) reach the
  /// SAME real, already-existing [TraceController]/[MultimeterController]
  /// the Trace Circuit/Multimeter workspace-action panels already use —
  /// this only opens/drives them, never a second/parallel
  /// implementation. `command` is always one of the fixed set this
  /// method switches on; anything else is silently ignored (V2's own
  /// toolbar never sends anything else — see the message's own doc
  /// comment on [LegacyV2BridgeTransport.onEngineeringCommand]).
  void _handleEngineeringCommand(String command) {
    if (!mounted) return;
    switch (command) {
      case 'trace.physical':
      case 'trace.conducting':
      case 'trace.currentFlow':
        final mode = switch (command) {
          'trace.conducting' => TraceMode.conducting,
          'trace.currentFlow' => TraceMode.currentFlow,
          _ => TraceMode.physical,
        };
        ref.read(traceRuntimeServiceProvider)?.setMode(mode);
        ref.read(tracePanelVisibleProvider.notifier).state = true;
      case 'trace.fromSource':
        // §29/§30 of trace_controller.dart — "trace from source" is the
        // Trace Inspector panel's own toggle (`_traceFromSource`,
        // private State inside `trace_inspector_panel.dart`, not a
        // provider); this opens that real panel rather than
        // reimplementing the toggle a second time here.
        ref.read(tracePanelVisibleProvider.notifier).state = true;
      case 'trace.clear':
        ref.read(traceRuntimeServiceProvider)?.clear();
      case 'measure.voltageDc':
      case 'measure.voltageAc':
      case 'measure.resistance':
      case 'measure.continuity':
      case 'measure.diode':
        final type = switch (command) {
          'measure.voltageAc' => MeasurementType.voltageAc,
          'measure.resistance' => MeasurementType.resistance,
          'measure.continuity' => MeasurementType.continuity,
          'measure.diode' => MeasurementType.diode,
          _ => MeasurementType.voltageDc,
        };
        ref.read(multimeterRuntimeServiceProvider)?.setType(type);
        ref.read(dmmPanelVisibleProvider.notifier).state = true;
      case 'measure.open':
        ref.read(dmmPanelVisibleProvider.notifier).state = true;
      // OEP-STUDIO-BRANDING-V1 — the engineering toolbar's own FILE
      // dropdown (index.html's `dd-file`): the exact same pre-existing
      // methods this file's old floating Load Previous/Open/Save/Save
      // As buttons called directly, now reached the same way Trace/
      // Measure are (§ this method's own class doc comment) instead of
      // 4 separate always-visible overlay buttons that visibly collided
      // with each other and this toolbar.
      case 'file.new':
        unawaited(_newDiagram(context));
      case 'file.open':
        unawaited(_openDocument(context));
      case 'file.loadPrevious':
        unawaited(_loadPreviousDocument(context));
      case 'file.save':
        final documentPath = ref.read(
            engineeringProjectServiceFamily(_instanceId).select((s) => s.documentPath));
        unawaited(_saveDocument(context, documentPath));
      case 'file.saveAs':
        unawaited(_saveDocumentAs(context));
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
  }

  /// Constructed lazily once the controller is available, and wires
  /// itself to [_transport]'s `onModuleMoved` callback — the adapter is
  /// the only layer that ever calls into [DiagramStudioController].
  LegacyV2StateAdapter _ensureAdapter(DiagramStudioController controller) {
    final adapter = _adapter ??= LegacyV2StateAdapter(
      controller: controller,
      channel: _transport,
      // AP-DIAGRAM-V2-BRIDGE-006 — resolved fresh per request rather than
      // captured once (see the adapter's own doc comment on this field).
      simulationServiceResolver: () =>
          ref.read(diagramSimulationServiceProvider),
    );
    // AP-DIAGRAM-V2-BRIDGE-SAVE-002 — registered on every `_ensureAdapter`
    // call (cheap/idempotent after the first), not just once, so a Save
    // triggered from OUTSIDE V2's own in-page button (Ctrl+S, the Command
    // Palette's `diagram.saveDocument`) also flushes V2's current state
    // first — see `EngineeringProjectNotifier.beforeSaveFlush`'s own doc
    // comment for the full rationale.
    ref
        .read(engineeringProjectServiceFamily(_instanceId).notifier)
        .beforeSaveFlush = adapter.flushBeforeSave;
    // PRODUCT-READINESS-008 — publish this adapter (and its live,
    // translated operating context) so a sibling DMM instrument panel can
    // reach the SAME live V2 state without this WebView page needing any
    // awareness of the DMM at all. `_ensureAdapter` is called from
    // `build()` (via `whenData`), so the actual provider write is
    // deferred past the current frame — Riverpod disallows modifying a
    // provider synchronously while another widget's build is in
    // progress.
    if (ref.read(legacyV2AdapterFamily(_instanceId)) != adapter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(legacyV2AdapterFamily(_instanceId)) != adapter) {
          ref.read(legacyV2AdapterFamily(_instanceId).notifier).state = adapter;
        }
      });
    }
    adapter.onOperatingStateChanged = (context) {
      if (!mounted) return;
      ref.read(legacyV2OperatingContextFamily(_instanceId).notifier).state = context;
    };
    return adapter;
  }

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-008 — `_ready` (this widget's own flag,
  /// flipped right after `loadUrl()` returns) is NOT "V2's page has
  /// loaded" — `loadUrl()` resolves as soon as WebView2's `Navigate()`
  /// call is dispatched (§ `legacy_v2_bridge_script.dart`'s own doc
  /// comment on this exact gap), well before V2's own `<script src>`
  /// tags have actually executed. Calling [initializeFromDocument]'s
  /// `clearAllSurfaces()` at that point is a silent no-op (`MODULES`
  /// doesn't exist yet in V2's page) — and since nothing clears again
  /// afterward, V2's `Bootstrap.run('trx300')` demo-vehicle bootstrap
  /// (`js/app.js`) loads moments later completely uncontested. This is
  /// what made a genuinely blank document still show the trx300 demo:
  /// the clear ran, but too early to have anything to clear.
  ///
  /// A single readiness signal isn't enough here, though: V2's own
  /// `app.js` declares `MODULES`/`WIRES` (and every other runtime global,
  /// including `selM`, which the 400ms status poller elsewhere in this
  /// injected script waits on before it starts posting) synchronously, at
  /// the very top of the file — **before** it `await`s
  /// `Bootstrap.run('trx300')`, the actual (asynchronous, e.g. fetching
  /// vehicle JSON) population of those arrays. So "V2's globals exist" is
  /// true well before "V2's bootstrap vehicle has actually loaded" — a
  /// single status ping would race Bootstrap the same way the original
  /// one-shot clear did. Instead this polls `MODULES.length` directly
  /// until it reads the same value twice in a row (two consecutive
  /// ~250ms samples) — the same "stability" idea `legacy_v2_bridge_script
  /// .dart`'s own live poller already uses for module-move detection
  /// (`stableCount === 2`), applied here to "has the bootstrap fetch
  /// settled" instead of "has a drag stopped." Bounded by an overall
  /// timeout so a V2 load failure can never hang initial seeding forever.
  Future<void> _waitForV2Ready() async {
    const pollInterval = Duration(milliseconds: 250);
    const overallTimeout = Duration(seconds: 8);
    final deadline = DateTime.now().add(overallTimeout);
    int? lastCount;
    while (DateTime.now().isBefore(deadline)) {
      final result = await _transport.executeRawScript(
          "typeof MODULES !== 'undefined' ? MODULES.length : -1");
      final count = result is num ? result.toInt() : -1;
      if (count >= 0 && lastCount == count) return;
      lastCount = count;
      await Future<void>.delayed(pollInterval);
    }
  }

  /// AP-OEP-DIAGRAM-OPEN-RACE-001 companion — every `restoreModule` call
  /// [LegacyV2StateAdapter.initializeFromDocument] makes is a
  /// fire-and-forget `window.__oepBridgeX && window.__oepBridgeX(...)`:
  /// if V2's page can't actually accept it yet for any reason (bridge
  /// script not injected, a mid-loop JS exception, `bridgeEnabled` false,
  /// anything else), that call silently no-ops — no thrown exception, so
  /// nothing here would otherwise notice. That is precisely the reported
  /// symptom: "opened a diagram, no error, but it looks like it never
  /// loaded." This closes the gap by reading V2's own live `MODULES.length`
  /// right after a seed and comparing it to how many modules the adapter
  /// just attempted to restore ([LegacyV2StateAdapter.bridgedModuleCount])
  /// — a mismatch throws, which the caller's own `.catchError` turns into
  /// the existing visible "Failed to load legacy V2" error screen instead
  /// of a diagram that quietly shows nothing.
  Future<void> _verifySeedLanded(LegacyV2StateAdapter adapter) async {
    final expectedModules = adapter.bridgedModuleCount;
    if (expectedModules > 0) {
      final result = await _transport.executeRawScript(
          "typeof MODULES !== 'undefined' ? MODULES.length : -1");
      final actual = result is num ? result.toInt() : -1;
      if (actual != expectedModules) {
        throw StateError(
            'Diagram did not load into the wiring editor: expected $expectedModules '
            'module(s) to appear but the editor shows $actual. The wiring '
            'editor page likely was not ready to receive the diagram — try '
            'reopening it.');
      }
    }
    // AP-DIAGRAM-V2-BRIDGE-WIRE-VERIFY-001 — the module check above has
    // existed since AP-OEP-DIAGRAM-OPEN-RACE-001, but nothing ever checked
    // WIRES the same way: `restoreWire` is the same fire-and-forget
    // `window.__oepBridgeRestoreWire && ...` shape as `restoreModule` (§
    // `LegacyV2StateAdapter.bridgedWireCount`'s own doc comment), so a
    // silent per-call failure on some wires (module count still matches,
    // so the check above passes) produced a diagram that looked fully
    // loaded but was missing most of its wires, with no error at all —
    // confirmed live: replaying the exact same restore calls against the
    // exact same document data in an isolated page landed every wire
    // correctly, which rules out the data/JS logic and points at a
    // runtime-only failure in the real seeding sequence — exactly the
    // kind of gap this check exists to surface instead of hide.
    final expectedWires = adapter.bridgedWireCount;
    if (expectedWires == 0) return;
    final wireResult = await _transport.executeRawScript(
        "typeof WIRES !== 'undefined' ? WIRES.length : -1");
    final actualWires = wireResult is num ? wireResult.toInt() : -1;
    if (actualWires != expectedWires) {
      throw StateError(
          'Diagram did not load into the wiring editor: expected $expectedWires '
          'wire(s) to appear but the editor shows $actualWires. The wiring '
          'editor page likely was not ready to receive the diagram — try '
          'reopening it.');
    }
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
    _seedChain = _seedChain.then((_) => _waitForV2Ready()).then((_) async {
      await adapter.initializeFromDocument();
      await _verifySeedLanded(adapter);
      // AP-DIAGRAM-V2-BRIDGE-003, Phase 4 — applied after seeding
      // (i.e. after V2's own page has fully loaded and defined its own
      // `saveLayout`), not before — see `interceptV2Save`'s own doc
      // comment for why order matters here.
      await _transport.interceptV2Save();
      // AP-DIAGRAM-V2-BRIDGE-SAVE-008 — V2's own bootstrap already ran
      // one Fit View (`zReset()`) against ITS content (e.g. the trx300
      // demo vehicle's own bounding box), before `initializeFromDocument`
      // just replaced that content with the real OEP document's — whose
      // bounding box is generally different (a different vehicle, a
      // different subset of modules, different saved positions). Nothing
      // else re-fits after a content swap like this one (only an actual
      // *widget resize* re-triggers `_fitV2ViewFromOep` — see
      // `_lastFitSize`'s own doc comment), so the pan/zoom stayed
      // calibrated to content that no longer exists — read by the user as
      // "the canvas is shifted down and to the right" after opening a
      // saved diagram. Re-fitting here, against the now-final content,
      // fixes it.
      await _fitV2ViewFromOep();
      // AP-OEP-DIAGRAM-BOOT-UNTITLED-001 companion fix — V2's own boot
      // (its unconditional demo-vehicle load) is hidden from first paint
      // by an injected style rule (legacy_v2_bridge_script.dart's own
      // doc comment on this), revealed only now that the real document
      // has actually been seeded and fitted — so a fresh Studio launch
      // shows the diagram the user actually has open, never V2's own
      // unrelated placeholder content, regardless of how long V2's own
      // bootstrap took.
      await _transport.executeRawScript(
          'if (typeof window.__oepBridgeRevealCanvas === "function") { window.__oepBridgeRevealCanvas(); }');
      if (mounted) setState(() {});
      // Caught, not left to propagate: an unguarded exception here would
      // leave `_seedChain` itself rejected, and every `.then()` any LATER
      // document switch chains onto an already-rejected future skips
      // straight to rejection too — silently breaking every subsequent
      // "Open" for the rest of the session over one failed seed, which
      // is worse than the race this chain exists to fix in the first
      // place.
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
    unawaited(_seedChain);
  }

  /// AP-DIAGRAM-V2-BRIDGE-002, Phase 8 — the active OEP document
  /// changed. Only meaningful after the first seed has already happened
  /// (a change observed *before* that point is just the initial value
  /// arriving, not a real switch).
  void _onDocumentChanged(LegacyV2StateAdapter adapter) {
    if (!_didInitialSeed) return;
    // `_triggerInitialSeed` waits for V2's own bootstrap to settle
    // (`_waitForV2Ready`) before its first `initializeFromDocument()` —
    // this one didn't, on the assumption that by the time a user
    // switches documents, V2 must already be fully loaded from that
    // first seed. That assumption breaks exactly when someone opens a
    // different diagram (the toolbar's "Open..."/"Load Previous
    // Diagram") quickly after Diagram Studio itself first appears,
    // before V2's own script bootstrap has actually finished: every
    // bridge call below is a fire-and-forget `window.__oepBridgeX &&
    // window.__oepBridgeX(...)` (legacy_v2_bridge_transport.dart) that
    // silently no-ops if that function isn't defined yet — no error, no
    // retry, and `reinitializeForDocument()` still marks itself
    // complete regardless, so the diagram you tried to open never
    // actually loads and nothing about the app's state indicates why.
    // The only way to recover was a full app restart, which gives V2's
    // bootstrap more real time to finish before the next attempt.
    // Waiting here the same way the first seed already does closes that
    // race for every subsequent document switch too, not just the
    // first one.
    // Chained onto _seedChain (AP-OEP-DIAGRAM-OPEN-RACE-001, this
    // field's own doc comment) rather than started independently, so a
    // document switch requested while the first seed — or a PREVIOUS
    // document switch — is still mid-flight waits its turn instead of
    // running concurrently against V2's page.
    _seedChain = _seedChain
        .then((_) => _waitForV2Ready())
        .then((_) => adapter.reinitializeForDocument())
        .then((_) => _verifySeedLanded(adapter))
        .then((_) async {
      // § the initial-seed completion's own comment above — the same
      // "content just changed, pan/zoom is now stale" reasoning applies
      // to every genuine document switch, not just the first load.
      await _fitV2ViewFromOep();
      if (mounted) setState(() {});
      // § _triggerInitialSeed's own catchError on this same chain for why
      // an exception here must not propagate to `_seedChain` itself.
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
    unawaited(_seedChain);
  }

  /// AP-OEP-DIAGRAM-VIEWPORT-PERSIST-001 — used to unconditionally call
  /// V2's own `zReset()` (a hard fit-to-content recompute) here, on every
  /// initial seed, every later document switch, AND every widget resize
  /// (`_lastFitSize`'s own doc comment). That flattened V2's own
  /// `initViewport()` mechanism (renderer.js) — which already restores
  /// whatever pan/zoom the user last had, from `localStorage`, and only
  /// computes a fresh fit when nothing was ever saved — every single time
  /// this ran, which is why the user's own chosen zoom never survived
  /// past the very first moment a document displayed: reported directly
  /// as "it does not default to the last state the app was closed in, i
  /// have to zoom in every time i open a diagram." `initViewport()` is
  /// the one already-correct mechanism for "what should the view be right
  /// now" — this just defers to it instead of duplicating/overriding its
  /// own logic. The original bug this function was written for (V2's own
  /// bootstrap fit-to-ITS-content, stale once the real document replaced
  /// it) is still covered: `initViewport()` computes a fresh fit under
  /// the exact same "nothing saved yet" condition. `zReset` is kept as a
  /// defensive fallback only for an unexpectedly old V2 build that
  /// predates `initViewport` — never the normal path anymore.
  Future<void> _fitV2ViewFromOep() => _transport.executeRawScript(
        'if (typeof initViewport === "function") { initViewport(); } '
        'else if (typeof zReset === "function") { zReset(); }',
      );

  @override
  void dispose() {
    // AP-DIAGRAM-V2-BRIDGE-SAVE-002 — never leave a disposed widget's
    // adapter reachable from a save trigger that outlives it. Best-effort
    // only: if the family entry has already been torn down by the time
    // this widget disposes (e.g. its own WorkspaceTab closing, or app
    // shutdown racing this widget's teardown), `ref.read` can throw —
    // harmless to skip here, since a notifier that no longer exists can't
    // call a stale hook either way.
    try {
      ref
          .read(engineeringProjectServiceFamily(_instanceId).notifier)
          .beforeSaveFlush = null;
    } catch (_) {}
    // OEP-STUDIO-BRANDING-V1 — clear the swap hook so the header never
    // calls into a disposed WebviewController; best-effort for the same
    // reason as the `beforeSaveFlush` clear just above.
    if (_instanceId == primaryDiagramInstanceId) {
      try {
        ref.read(legacyV2ToggleSimulationViewProvider.notifier).state = null;
      } catch (_) {}
    }
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
    ref.listen(
        engineeringProjectServiceFamily(_instanceId)
            .select((s) => s.document.id), (previous, next) {
      final adapter = _adapter;
      if (adapter != null) _onDocumentChanged(adapter);
    });
    // AP-DIAGRAM-V2-BRIDGE-SAVE-006 — Save As assigning a document its
    // first path is a path transition from `null` to non-null with the
    // *same* document id (`.document.id`, watched above, does NOT
    // change on Save As — confirmed by `DiagramDocument.id`'s own doc
    // comment). This USED to call `adapter.reinitializeForDocument()`
    // (AP-OEP-DIAGRAM-UX-002's inherited "reseed after Save As" logic,
    // carried over from the old toolbar button) — which is the wrong
    // operation here: `reinitializeForDocument()` clears V2's entire
    // MODULES/WIRES arrays and reseeds only from OEP graph nodes that
    // already carry a `v2ModuleId` — anything V2-bootstrap-original that
    // was never individually bridged has no such node and gets silently
    // dropped. On a diagram whose content mostly traces back to V2's own
    // bootstrap, this visibly deleted most of the diagram the moment
    // Save As ran (discovered via real end-to-end testing once Save As
    // became reachable at all — see the new Save button below). Save As
    // doesn't change what V2 is showing — `flushBeforeSave` already
    // reconciled it into the OEP graph moments earlier as part of the
    // same save — so there is nothing here to clear or reseed; only the
    // adapter's own bookkeeping token needs updating.
    ref.listen(
        engineeringProjectServiceFamily(_instanceId)
            .select((s) => s.documentPath), (previous, next) {
      if (previous == null && next != null) {
        _adapter?.acknowledgeSaveAs();
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
    // AP-OEP-DIAGRAM-UX-002's premise — "Save As is already reachable
    // platform-wide via the Command Palette" — turned out to be false in
    // practice: Ctrl+K is bound through Flutter's focus-tree-based
    // `CallbackShortcuts` (`studio_shell.dart`), and a native embedded
    // WebView holds OS-level keyboard focus outside that tree whenever
    // it's the visible content (i.e. essentially always, here). A user
    // whose document has never been saved gets told to press Ctrl+K and
    // has no way to do so. A single small always-visible Save button —
    // a mouse click, not a keyboard shortcut, so WebView focus is
    // irrelevant — closes that gap without resurrecting the rest of the
    // removed toolbar.
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
                            'Failed to load legacy V2:\n$_error\n\nExpected entry point:\n${_v2EntryPointUri()}',
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
                              return Webview(_controller);
                            },
                          ),
              ),
            ],
          ),
          // OEP-STUDIO-BRANDING-V1 — File used to live here as 4
          // separate, always-visible floating buttons (Load Previous
          // Diagram/Open/Save/Save As), which visibly collided with
          // each other and with the engineering toolbar underneath
          // (direct report: with no path yet, Save itself also read
          // "Save As…", so two "Save As…" buttons showed at once). Now
          // reachable from the engineering toolbar's own FILE dropdown
          // (index.html's `dd-file`) instead, via the same
          // engineeringCommand bridge Trace/Measure use (§
          // _handleEngineeringCommand's own doc comment) — nothing
          // floats over the canvas anymore.
        ],
      ),
    );
  }

  /// AP-OEP-DIAGRAM-BOOT-UNTITLED-001 — a fresh app launch/new tab no
  /// longer auto-reopens the previously active document (§
  /// `DiagramStudioController.bootstrap`'s own doc comment for why) — the
  /// user explicitly asked for that to become a one-click action instead
  /// of silent, automatic behavior. This reads the same on-disk records
  /// that auto-restore used to read from (`DiagramTabsStorage`, falling
  /// back to nothing found rather than a second, different source of
  /// truth) — a fresh, standalone read at click time, not anything
  /// `bootstrap` computed earlier in this session.
  /// OEP-STUDIO-BRANDING-V1 — the FILE dropdown's "New Diagram", same
  /// real action `WebSurfacesHostPage._newDiagram()` already uses
  /// (`engineeringProjectServiceProvider.notifier.newDocument()`) —
  /// replaces the single current document rather than opening a second,
  /// independent one, same rationale as that method's own doc comment.
  Future<void> _newDiagram(BuildContext context) async {
    await ref.read(engineeringProjectServiceProvider.notifier).newDocument();
  }

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
      // AP-OEP-DIAGRAM-BOOT-UNTITLED-001 — through the Controller, not
      // `EngineeringProjectNotifier` directly, so the active tab's own
      // path/title gets updated too (§ `_openDocument`'s own doc comment
      // for why this matters).
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

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-006 companion fix — `diagram.openDocument`
  /// (an OEP document, e.g. a saved diagram like `trx300.json`) has only
  /// ever been reachable through the Command Palette, which — like Ctrl+S
  /// before the native Save button above — is unreachable while the
  /// embedded WebView holds OS-level keyboard focus (Ctrl+K never
  /// reaches Flutter's `CallbackShortcuts`). The legacy V2 editor's own
  /// "⬆ Load" toolbar button is not a substitute: it reads a completely
  /// different, V2-internal JSON shape (`positions`/`wireRoutes`/
  /// `userConns`/`userMods`) via its own native `<input type=file>`, not
  /// an OEP `DiagramDocument` (`schemaVersion`/`documentId`/`graph`/
  /// `layout`) — pointing it at an OEP document file parses fine but
  /// matches none of those keys, so nothing loads and no error surfaces
  /// either, which reads as "doesn't load at all". This button gives
  /// `diagram.openDocument` its own click-reachable entry point, mirroring
  /// the Save button's fix.
  ///
  /// AP-OEP-DIAGRAM-TAB-SYNC-001 — goes through
  /// `DiagramStudioController.openDocument`/`.saveDocumentAs`, not
  /// `EngineeringProjectNotifier` directly (this method's own original
  /// version called the notifier directly, which was itself a bug: the
  /// active tab's `path`/`title` — and therefore `DiagramTabsStorage`'s
  /// persisted record of "what's actually open" — never got updated, so
  /// anything that reads the tab's path afterward (a fresh app boot, or
  /// the "Load Previous Diagram" button above) saw a stale/wrong path.
  /// This is what made a Save As look like it "didn't persist" unless the
  /// tab was separately closed first — closing happened to route through
  /// the correct, tab-updating code instead).
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

  /// Overwrites the document's current path if it has one; otherwise
  /// this is the first save, so it's really a Save As — delegates to
  /// [_saveDocumentAs] rather than duplicating that flow.
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

  /// AP-OEP-DIAGRAM-SAVE-AS-002 — always prompts for a location and
  /// writes there, regardless of whether the document already has a
  /// path — the explicit "save a modified copy without overwriting the
  /// original" action, reachable on its own (not only as the
  /// never-saved-yet fallback [_saveDocument] uses).
  ///
  /// AP-OEP-DIAGRAM-TAB-SYNC-001 — goes through
  /// `DiagramStudioController.saveDocumentAs` (not the notifier directly)
  /// for the same reason `_openDocument` does — see that method's own
  /// doc comment.
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

