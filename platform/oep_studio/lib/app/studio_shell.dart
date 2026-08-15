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
import '../shared/widgets/output_panel.dart';
import '../shared/widgets/property_inspector_panel.dart';
import '../workbench/perspective/perspective_manager.dart';
import '../workbench/widgets/workbench_sidebar.dart';
import 'widgets/command_palette_dialog.dart';
import 'widgets/studio_breadcrumb_bar.dart';
import 'widgets/studio_menu_bar.dart';
import 'widgets/studio_ribbon.dart';
import 'widgets/studio_status_bar.dart';
import 'widgets/studio_toolbar.dart';

/// The application shell (STUDIO-TASK-000001, Property Inspector added
/// in Work Package 003).
///
/// Composes the five persistent regions defined by SDD-004 Workspace
/// Layout: Top Toolbar, left Navigation Rail, central Primary
/// Workspace, right Property Inspector, and bottom Status Bar. Only
/// one Primary Workspace is visible at a time (SDD-003/SDD-004);
/// navigation never opens a floating window.
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
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPaletteDialog(context),
        },
        child: Builder(
          builder: (context) {
            // Phase 14 (UI Layout Ratification) -- "the diagram is the
            // workspace, everything else is subordinate" (§ 2), modeled
            // closely on the `legacy_wiring_sim_v2` reference tool per
            // explicit user direction: Diagram Studio does not sit
            // beneath the OEP global Menu Bar/Toolbar/Ribbon/Breadcrumb
            // Bar/Sidebar/Property Inspector/Output Panel at all -- it
            // owns the full window. Every other Studio keeps the full
            // shell chrome unchanged (Section 21's "studio-by-studio"
            // rule -- this is a Diagram-Studio-only carve-out, not a
            // shell redesign). `DiagramStudioPage` itself is
            // responsible for its own top strip/status surfaces now
            // that it has the whole screen.
            if (widget.selected == StudioDestination.diagram) {
              return Scaffold(backgroundColor: StudioColors.background, body: widget.child);
            }
            final showInspector = ref.watch(propertyInspectorVisibleProvider);
            return Scaffold(
              backgroundColor: StudioColors.background,
              body: Column(
                children: [
                  // Master Application Shell, Phase 1 (OEP Design System
                  // `02_Main_Application_Shell.png`): Menu Bar above the
                  // existing document/command Toolbar, above the Ribbon,
                  // above the unchanged Sidebar/Workspace/Inspector row.
                  // `StudioToolbar` moves out of `Scaffold.appBar` into
                  // this Column as a plain child -- same widget, same
                  // behavior, new position -- since the appBar slot can
                  // only hold one bar and the Menu Bar now owns it.
                  StudioMenuBar(selected: widget.selected),
                  StudioToolbar(selected: widget.selected),
                  StudioRibbon(selected: widget.selected),
                  // Phase 2 (ODS-S004 Navigation Standard § 5): Breadcrumb
                  // Bar + Back/Forward History, directly above the
                  // workspace like an IDE's own breadcrumb bar.
                  StudioBreadcrumbBar(selected: widget.selected),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // WP-DS-006 follow-up: the Engineering Workbench
                        // sidebar is now the app's single left nav, replacing
                        // the classic `StudioNavRail` (still present in
                        // `widgets/studio_nav_rail.dart`, just no longer
                        // mounted here). `PerspectiveManager.instance` is the
                        // same shared instance `_diagramBuilder`
                        // (`core/routing/studio_registry.dart`) hands to
                        // `EngineeringWorkbenchPage`, so a Perspective selected
                        // here is the same Perspective that page renders.
                        WorkbenchSidebar(
                          perspectiveManager: PerspectiveManager.instance,
                          current: widget.selected,
                          // Phase 14 § 10: the same real
                          // `EngineeringProjectState.session` signal
                          // `.select`ed here (not `.watch`ed whole, to avoid
                          // rebuilding the sidebar on unrelated selection/
                          // validation churn) -- never a fabricated
                          // "diagram open" flag.
                          diagramSessionActive: ref.watch(engineeringProjectServiceProvider.select((s) => s.session != null)),
                        ),
                        Expanded(child: widget.child),
                        if (showInspector) const PropertyInspectorPanel(),
                      ],
                    ),
                  ),
                  // The dockable Output Panel sits between the workspace and
                  // the Status Bar, Visual-Studio style -- collapsed by
                  // default so it never steals space from a Studio that
                  // isn't using it. See `OutputPanel`'s own doc comment for
                  // why it observes already-published Platform events rather
                  // than introducing a new logging API.
                  const OutputPanel(),
                  const StudioStatusBar(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
