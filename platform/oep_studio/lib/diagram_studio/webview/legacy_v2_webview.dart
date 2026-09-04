import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../../core/notifications/platform_notification_service.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controller/diagram_studio_controller.dart';
import '../controller/diagram_studio_controller_provider.dart';
import '../simulation/diagram_simulation_service.dart';
import '../tabs/diagram_tabs_storage.dart';
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
    return adapter;
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

  Future<void> _fitV2ViewFromOep() => _transport.executeRawScript(
        'if (typeof zReset === "function") { zReset(); }',
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
          if (_ready && _error == null)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LoadPreviousButton(
                      onPressed: () => _loadPreviousDocument(context)),
                  const SizedBox(width: 8),
                  _OpenButton(onPressed: () => _openDocument(context)),
                  const SizedBox(width: 8),
                  _SaveButton(
                    hasPath: documentPath != null,
                    onPressed: () => _saveDocument(context, documentPath),
                  ),
                ],
              ),
            ),
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

  /// AP-OEP-DIAGRAM-TAB-SYNC-001 — the Save-As branch goes through
  /// `DiagramStudioController.saveDocumentAs` (not the notifier directly)
  /// for the same reason `_openDocument` does — see that method's own
  /// doc comment. The already-has-a-path branch doesn't need this: the
  /// tab's path was already set correctly whenever it was first assigned.
  Future<void> _saveDocument(BuildContext context, String? documentPath) async {
    if (documentPath != null) {
      await ref
          .read(engineeringProjectServiceFamily(_instanceId).notifier)
          .saveDocument();
      if (context.mounted) {
        PlatformNotificationService.success(context, 'Diagram saved.');
      }
      return;
    }
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

class _LoadPreviousButton extends StatelessWidget {
  const _LoadPreviousButton({required this.onPressed});

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
                'Load Previous Diagram',
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

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.onPressed});

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
                'Open…',
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

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.hasPath, required this.onPressed});

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
