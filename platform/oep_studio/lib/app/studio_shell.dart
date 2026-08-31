import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../acquisition/models/download_session.dart';
import '../acquisition/services/acquisition_runtime_service.dart';
import '../acquisition/services/acquisition_runtime_state.dart';
import '../core/events/platform_event.dart';
import '../core/events/platform_event_bus.dart';
import '../core/notifications/platform_notification_service.dart';
import '../core/routing/studio_destination.dart';
import '../core/services/engineering_project_service.dart';
import '../core/objects/engineering_object_runtime.dart';
import '../core/services/foundation_runtime_service.dart';
import '../core/services/foundation_runtime_state.dart';
import '../core/theme/studio_colors.dart';
import '../core/workspace/workspace_manager.dart';
import '../knowledge/models/ocr_processing_status.dart';
import '../web_surface/web_surfaces_host_page.dart';
import '../workspace/engineering_workspace_page.dart';
import 'widgets/command_palette_dialog.dart';

/// The application shell (STUDIO-TASK-000001).
///
/// AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — this shell no longer renders any
/// persistent chrome (the Menu Bar/Toolbar/Ribbon/Breadcrumb Bar/left
/// Sidebar/Property Inspector/Output Panel/Status Bar that SDD-004
/// originally specified were removed once the tabbed
/// [EngineeringWorkspacePage] became the app's entire UI, in the same
/// spirit `StudioDestination.diagram` already got a chrome-free
/// full-window carve-out for — see `build()`). What remains is
/// background wiring that has nothing to do with chrome: the app-wide
/// Ctrl+K binding, lifecycle/progress event publishing, and the
/// `WorkspaceManager`/`EngineeringObjectRuntime` bridges documented
/// below, all of which must keep running regardless of what's on
/// screen.
///
/// Also the Platform's one centralized keyboard shortcut binding point
/// (WP-STUDIO-027): wrapping the whole shell in [CallbackShortcuts]
/// reuses the exact same widget Diagram Studio's own local shortcuts
/// (`DiagramStudioPage`) already rely on, just one layer higher, so
/// Ctrl+K opens the Command Palette from anywhere in the app. A
/// Studio's own [CallbackShortcuts] (if it binds a different key) still
/// gets first refusal — Flutter's focus/key-event propagation walks
/// from the currently focused node up to its ancestors, so this
/// shell-level binding only fires for a key combo nothing more specific
/// has already claimed.
///
/// WP-STUDIO-028 adds two more Platform-layer-only responsibilities,
/// both requiring no change to any Studio:
///
/// * Publishes exactly one [StudioLifecycleEvent] per real
///   Studio-destination transition (`didUpdateWidget`, comparing the
///   previous [selected] to the new one) — not once per rebuild, which
///   this shell (hosting every route) undergoes far more often than the
///   user actually switches Studios.
/// * Bridges Acquisition's already-existing `DownloadSession
///   .progressPercentage` into [ProgressEvent]s via
///   `ref.listenManual(acquisitionRuntimeServiceProvider, ...)`,
///   started once in [State.initState] and cancelled in
///   [State.dispose] — the one trade-off this introduces is that the
///   Acquisition Studio's own Connection Manager now initializes (a
///   local `http.Client`, no network I/O) as soon as the app starts
///   rather than only once the user first opens Engineering
///   Acquisition; see this Work Package's documentation for why that
///   was judged an acceptable, low-risk cost of keeping progress
///   reporting entirely in the Platform layer instead of editing the
///   Studio's own file.
///
/// WP-STUDIO-029 adds the third: [WorkspaceManager] initializes here
/// (loading the recent-workspace list and checking for a crash-recovery
/// sentinel), and a `ref.listenManual(engineeringProjectServiceProvider,
/// ...)` feeds every Diagram document state change to it, the same
/// pattern already used for Acquisition's progress bridge above. This
/// `State` also mixes in [WidgetsBindingObserver] for
/// [didRequestAppExit] — a best-effort "Exit anyway?" prompt when
/// closing with unsaved changes; the crash-recovery sentinel
/// (rewritten on every dirty-state change, not just at exit) is the
/// actual reliable safety net, since a desktop close-intercept isn't
/// guaranteed to fire for every possible way the app can end (a crash,
/// a forced kill).
///
/// WP-STUDIO-030 adds a fourth `ref.listenManual`: Knowledge Studio's
/// already-existing `FoundationServiceState.ocrProcessingStatus` (Work
/// Package 013 — a per-source background-OCR signal, not something this
/// Work Package invents) is diffed into [OperationEvent]s the same way
/// [_publishDownloadProgress] already turns Acquisition's download list
/// into them; both feed `OperationManager`. No new background-task
/// abstraction was introduced — these two already-existing signals were
/// the only genuine "background work" found during this Work Package's
/// architecture review.
///
/// WP-STUDIO-031 feeds `EngineeringObjectRuntime` from that same fourth
/// `ref.listenManual` (`_handleFoundationStateChange`, renamed from the
/// WP-STUDIO-030 OCR-only callback) rather than adding a second, redundant
/// listener on the same provider — `FoundationServiceState.objectList`/
/// `relationshipList` and `ocrProcessingStatus` are both diffed from the
/// one `next` value already delivered.
class StudioShell extends ConsumerStatefulWidget {
  const StudioShell({
    required this.selected,
    required this.onSelect,
    required this.child,
    PlatformEventBus? eventBus,
    WorkspaceManager? workspaceManager,
    EngineeringObjectRuntime? engineeringObjectRuntime,
    super.key,
  })  : _eventBus = eventBus,
        _workspaceManager = workspaceManager,
        _engineeringObjectRuntime = engineeringObjectRuntime;

  final StudioDestination selected;
  final ValueChanged<StudioDestination> onSelect;
  final Widget child;

  /// Defaults to [PlatformEventBus.instance]; only ever overridden in
  /// tests, so lifecycle/progress event assertions don't have to share
  /// the app-wide singleton with whatever else is running.
  final PlatformEventBus? _eventBus;

  /// Defaults to [WorkspaceManager.instance]; only ever overridden in
  /// tests, so workspace-lifecycle assertions never touch the real
  /// user settings directory.
  final WorkspaceManager? _workspaceManager;

  /// Defaults to [EngineeringObjectRuntime.instance]; only ever
  /// overridden in tests.
  final EngineeringObjectRuntime? _engineeringObjectRuntime;

  @override
  ConsumerState<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends ConsumerState<StudioShell> with WidgetsBindingObserver {
  ProviderSubscription<AcquisitionServiceState>? _progressBridge;
  ProviderSubscription<EngineeringProjectState>? _workspaceBridge;
  ProviderSubscription<FoundationServiceState>? _foundationBridge;

  /// AP-OEP-DIAGRAM-UX-001 — constructed exactly once, alive for this
  /// `State`'s entire lifetime (which spans every navigation, since
  /// `StudioShell` is the one persistent widget the `ShellRoute` never
  /// tears down between destinations). Rendered directly as `build()`'s
  /// `Scaffold.body` whenever `widget.selected == StudioDestination.diagram`
  /// (AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — no longer additionally kept
  /// alive `Offstage` while some other destination is selected, now that
  /// the tabbed Workspace's own Diagram tab, `DiagramWithComparePane`, is
  /// the real, normal way users reach Diagram content today). `/diagram`
  /// itself is no longer reachable from ordinary production navigation
  /// (AP-OEP-WORKSPACE-NAVIGATION-CONVERGENCE-001 removed the last raw
  /// `context.go(StudioDestination.diagram.path)` call sites, in
  /// `ProjectExplorerPage`, in favor of the Workspace-aware
  /// `openOrActivateDestination`) — the route and this host still exist,
  /// deliberately not removed, but nothing in the UI navigates here
  /// anymore. A `GlobalKey` is kept regardless, since `build()`'s three
  /// branches are still structurally different `Scaffold` trees.
  final GlobalKey _diagramStudioHostKey = GlobalKey();
  late final Widget _diagramStudioHost = WebSurfacesHostPage(key: _diagramStudioHostKey, autoOpenLegacyV2: true);

  /// AP-OEP-WORKSPACE-ROUTING-001 — built once as a stable field so
  /// `EngineeringWorkspacePage`'s own `Element`/`State` (and everything
  /// mounted inside its `IndexedStack` of open tabs, including a live
  /// Diagram tab's WebView) survives across rebuilds. Rendered directly
  /// as `build()`'s `Scaffold.body` whenever `widget.selected ==
  /// StudioDestination.workspace` — which, since
  /// AP-OEP-WORKSPACE-AS-PRIMARY-UI-001, is effectively always (the app
  /// boots straight into `/workspace` and nothing in the UI navigates
  /// away from it anymore). Tab state itself lives in
  /// `workspaceTabsControllerProvider`, independent of this field, so
  /// even the rare case of this `Element` being torn down and rebuilt
  /// loses no open-tab bookkeeping.
  late final Widget _workspaceHost = const EngineeringWorkspacePage();

  PlatformEventBus get _eventBus => widget._eventBus ?? PlatformEventBus.instance;
  WorkspaceManager get _workspaceManager => widget._workspaceManager ?? WorkspaceManager.instance;
  EngineeringObjectRuntime get _engineeringObjectRuntime =>
      widget._engineeringObjectRuntime ?? EngineeringObjectRuntime.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventBus.publish(
      StudioLifecycleEvent(destination: widget.selected, phase: StudioLifecyclePhase.entered),
    );
    _progressBridge = ref.listenManual<AcquisitionServiceState>(
      acquisitionRuntimeServiceProvider,
      _publishDownloadProgress,
    );
    _workspaceBridge = ref.listenManual<EngineeringProjectState>(
      engineeringProjectServiceProvider,
      (previous, next) => _workspaceManager.handleProjectStateChange(next),
    );
    _foundationBridge = ref.listenManual<FoundationServiceState>(
      foundationRuntimeServiceProvider,
      _handleFoundationStateChange,
    );
    unawaited(_initializeWorkspaceManager());
  }

  Future<void> _initializeWorkspaceManager() async {
    await _workspaceManager.initialize();
    if (!mounted) return;
    final recoverable = _workspaceManager.recoverableWorkspacePath;
    if (recoverable == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showRecoveryPrompt(recoverable));
    });
  }

  /// A best-effort warning when closing with unsaved Diagram Studio
  /// changes — see this class's own doc comment for why the
  /// crash-recovery sentinel, not this prompt, is the reliable
  /// mechanism.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (!_workspaceManager.hasUnsavedChanges || !mounted) return AppExitResponse.exit;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Unsaved Changes'),
        content: const Text('The active diagram has unsaved changes. Exit anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: StudioColors.error),
            child: const Text('Exit Without Saving'),
          ),
        ],
      ),
    );
    return (shouldExit ?? false) ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  /// Shown once at startup when [WorkspaceManager.initialize] finds a
  /// workspace flagged dirty when the app last closed (or crashed).
  Future<void> _showRecoveryPrompt(String path) async {
    final shouldRecover = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Recover Diagram?'),
        content: Text('"$path" had unsaved changes when Studio last closed. Reopen it?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Recover')),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldRecover ?? false) {
      // The recovered path is only as reliable as whatever the sentinel
      // recorded — by the next launch, the file may have been moved,
      // deleted, or corrupted outside Studio entirely. That must not
      // propagate as an uncaught exception; report it the same way any
      // other failed Open already would.
      try {
        await ref.read(engineeringProjectServiceProvider.notifier).openDocument(path);
        _eventBus.publish(WorkspaceEvent(kind: WorkspaceEventKind.recovered, path: path));
        if (mounted) PlatformNotificationService.success(context, 'Recovered diagram from last session.');
      } catch (error) {
        if (mounted) PlatformNotificationService.error(context, 'Couldn\'t recover "$path": ${error.toString()}');
      }
    }
    await _workspaceManager.clearRecoverable();
  }

  @override
  void didUpdateWidget(StudioShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _eventBus.publish(
        StudioLifecycleEvent(destination: widget.selected, phase: StudioLifecyclePhase.entered),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressBridge?.close();
    _workspaceBridge?.close();
    _foundationBridge?.close();
    super.dispose();
  }

  /// Translates Acquisition's own already-computed
  /// `DownloadSession.progressPercentage` into [ProgressEvent]s (unchanged
  /// since WP-STUDIO-028) and, since WP-STUDIO-030, also diffs
  /// [previous]/[next] to publish [OperationEvent]s so `OperationManager`
  /// can track each download's start/finish — `progressPercentage < 100`
  /// is used rather than matching a `status` string for the [ProgressEvent]
  /// half, since only `'completed'`/`'failed'` are confirmed status values
  /// anywhere else in the app (`acquisition_pipeline_panel.dart`); the
  /// numeric percentage is reliable regardless of exactly which other
  /// status strings the backend may use.
  void _publishDownloadProgress(AcquisitionServiceState? previous, AcquisitionServiceState next) {
    final previousById = {for (final download in previous?.downloads ?? const <DownloadSession>[]) download.id: download};
    for (final download in next.downloads) {
      final label = download.fileName.isEmpty ? download.id : download.fileName;
      if (download.progressPercentage < 100) {
        _eventBus.publish(ProgressEvent(id: download.id, label: label, fraction: download.progressPercentage / 100));
      }

      final previousDownload = previousById[download.id];
      if (previousDownload == null) {
        _eventBus.publish(
          OperationEvent(
            id: download.id,
            kind: OperationEventKind.started,
            label: label,
            fraction: download.progressPercentage / 100,
          ),
        );
      } else if (previousDownload.status == download.status &&
          previousDownload.progressPercentage == download.progressPercentage) {
        continue;
      }
      if (download.status == 'completed') {
        _eventBus.publish(OperationEvent(id: download.id, kind: OperationEventKind.completed, label: label));
      } else if (download.status == 'failed') {
        _eventBus.publish(OperationEvent(id: download.id, kind: OperationEventKind.failed, label: label));
      } else if (previousDownload != null && download.progressPercentage < 100) {
        _eventBus.publish(
          OperationEvent(
            id: download.id,
            kind: OperationEventKind.progressed,
            label: label,
            fraction: download.progressPercentage / 100,
          ),
        );
      }
    }
  }

  /// The single Foundation Bridge listener callback (renamed from
  /// WP-STUDIO-030's OCR-only `_publishOcrOperations`): diffs
  /// [FoundationServiceState.ocrProcessingStatus] into [OperationEvent]s
  /// (§ [_publishOcrOperations]'s own former doc comment, unchanged
  /// below) and, since WP-STUDIO-031, feeds
  /// [EngineeringObjectRuntime.updateFromFoundationState] with the same
  /// already-delivered `next` — one listener, two independent diffs, no
  /// second subscription on the same provider.
  void _handleFoundationStateChange(FoundationServiceState? previous, FoundationServiceState next) {
    _publishOcrOperations(previous, next);
    _engineeringObjectRuntime.updateFromFoundationState(next);
  }

  /// Surfaces Knowledge Studio's already-existing background OCR signal
  /// (`FoundationServiceState.ocrProcessingStatus`, Work Package 013) as
  /// [OperationEvent]s (WP-STUDIO-030) — this bridge does not run OCR or
  /// duplicate any of `FoundationRuntimeNotifier.runOcrForSource`'s own
  /// state transitions; it only observes the one already-existing
  /// per-source status map and republishes each transition as a fact on
  /// the Platform Event Bus, the same pattern [_publishDownloadProgress]
  /// already established for Acquisition.
  void _publishOcrOperations(FoundationServiceState? previous, FoundationServiceState next) {
    final previousStatus = previous?.ocrProcessingStatus ?? const <String, OcrProcessingStatus>{};
    for (final entry in next.ocrProcessingStatus.entries) {
      if (previousStatus[entry.key] == entry.value) continue;
      final sourceId = entry.key;
      final matches = next.sourceMaterials.where((source) => source.id == sourceId);
      final label = matches.isEmpty ? 'Recognizing text' : 'Recognizing text — ${matches.first.originalFileName}';
      switch (entry.value) {
        case OcrProcessingStatus.processing:
          _eventBus.publish(OperationEvent(id: 'ocr:$sourceId', kind: OperationEventKind.started, label: label));
        case OcrProcessingStatus.completed:
          _eventBus.publish(OperationEvent(id: 'ocr:$sourceId', kind: OperationEventKind.completed, label: label));
        case OcrProcessingStatus.failed:
          _eventBus.publish(OperationEvent(id: 'ocr:$sourceId', kind: OperationEventKind.failed, label: label));
        case OcrProcessingStatus.notProcessed:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPaletteDialog(context),
      },
      child: Focus(
        autofocus: true,
        child: Builder(
          builder: (context) {
            // AP-OEP-WORKSPACE-AS-PRIMARY-UI-001 — the tabbed Workspace is
            // now the app's entire UI, the same way Diagram Studio already
            // owned the full window (Phase 14, unchanged below): no Menu
            // Bar/Toolbar/Ribbon/Breadcrumb Bar/Sidebar/Property Inspector/
            // Output Panel/Status Bar chrome around either of them. Every
            // other `StudioDestination` is no longer reachable via any UI
            // element — the Workspace's own "+" menu
            // (`_WorkspaceTabStrip` in `engineering_workspace_page.dart`)
            // already lists every `SurfaceRegistry` entry plus Diagram
            // Studio, so it is the app's sole navigation surface now (the
            // tabbed-browser model: the "+" button *is* the navigation).
            // The fallback branch below stays bare and chrome-free (never
            // actually reached via the UI) purely so those other routes'
            // `GoRoute`s keep resolving for `StudioRegistry`'s other,
            // unrelated consumers (`settingsProviders`/`searchProviders`/
            // `capabilitiesFor` still iterate every descriptor).
            if (widget.selected == StudioDestination.diagram) {
              return Scaffold(backgroundColor: StudioColors.background, body: _diagramStudioHost);
            }
            if (widget.selected == StudioDestination.workspace) {
              return Scaffold(backgroundColor: StudioColors.background, body: _workspaceHost);
            }
            return Scaffold(backgroundColor: StudioColors.background, body: widget.child);
          },
        ),
      ),
    );
  }
}
