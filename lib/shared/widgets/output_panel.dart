import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../acquisition/services/acquisition_runtime_service.dart';
import '../../core/operations/activity_log.dart';
import '../../core/operations/operation.dart';
import '../../core/operations/operation_manager.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';

/// A dockable, Visual-Studio-style bottom Output Panel — "Every
/// long-running operation throughout OEP should eventually report here."
///
/// Deliberately built as a **view over facts the Platform already
/// publishes**, not a new logging system: `ActivityLog` and
/// `OperationManager` (WP-STUDIO-030's Engineering Operations Framework)
/// already observe every `CommandExecutedEvent`/`OperationEvent`/
/// `WorkspaceEvent`/`EngineeringObjectEvent` on the `PlatformEventBus`.
/// This panel surfaces them. No Studio has to call a "log this" API to
/// appear here, and nothing about their existing behavior changed.
///
/// Resizable (drag the top edge) and, like a real Visual Studio tool
/// window, **occupies zero height when hidden** -- toggled from the
/// Status Bar (`StudioStatusBar`'s "Output" button) rather than by a
/// permanently-visible header of its own. That matters: a permanently
/// docked 32px header would silently steal vertical space from every
/// Studio in the app, and several existing panels sit within a few
/// pixels of their available height already.
class OutputPanel extends ConsumerStatefulWidget {
  const OutputPanel({super.key});

  @override
  ConsumerState<OutputPanel> createState() => _OutputPanelState();
}

class _OutputPanelState extends ConsumerState<OutputPanel> with SingleTickerProviderStateMixin {
  static const _tabs = ['Output', 'Acquisition Log', 'Validation', 'Notifications', 'Review Queue'];

  // Created eagerly, NOT `late final`: the panel starts hidden and may
  // never be shown, in which case `dispose()` would be the first access
  // to a lazy field -- constructing a `TabController` (and its ticker,
  // via `vsync: this`) against an already-deactivated element, which
  // throws "Looking up a deactivated widget's ancestor is unsafe".
  late final TabController _tabController;
  late final StreamSubscription<void> _activitySub;
  late final StreamSubscription<void> _operationsSub;

  double _height = 200;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Both streams fire *after* their own state is already updated, so a
    // plain setState here always reads consistent data (see
    // `ActivityLog.changes`'s own doc comment).
    _activitySub = ActivityLog.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _operationsSub = OperationManager.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _activitySub.cancel();
    _operationsSub.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Zero height when hidden -- no permanently-docked chrome. See this
    // class's own doc comment for why that's deliberate.
    if (!ref.watch(outputPanelVisibleProvider)) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) =>
              setState(() => _height = (_height - details.delta.dy).clamp(120.0, 500.0)),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: Container(height: 4, color: StudioColors.border),
          ),
        ),
        _Header(
          tabs: _tabs,
          controller: _tabController,
          onHide: () => ref.read(outputPanelVisibleProvider.notifier).state = false,
        ),
        SizedBox(
          height: _height,
          child: TabBarView(
            controller: _tabController,
            children: [
              const _OutputTab(),
              const _AcquisitionLogTab(),
              _ValidationTab(ref: ref),
              const _NotificationsTab(),
              const _ReviewQueueTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Whether the Output Panel is currently shown. Toggled from the Status
/// Bar; hidden by default so no Studio loses vertical space until the
/// engineer actually asks for the panel.
final outputPanelVisibleProvider = StateProvider<bool>((ref) => false);

class _Header extends StatelessWidget {
  const _Header({required this.tabs, required this.controller, required this.onHide});

  final List<String> tabs;
  final TabController controller;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: StudioColors.surfaceRaised,
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 11.5),
              labelColor: StudioColors.textPrimary,
              unselectedLabelColor: StudioColors.textSecondary,
              indicatorColor: StudioColors.selection,
              dividerColor: Colors.transparent,
              tabs: [for (final tab in tabs) Tab(height: 32, text: tab)],
            ),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: 'Hide Output Panel',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: onHide,
          ),
        ],
      ),
    );
  }
}

/// Every cross-Studio activity fact, newest first — real
/// `ActivityLog.instance` entries.
class _OutputTab extends StatelessWidget {
  const _OutputTab();

  @override
  Widget build(BuildContext context) {
    final entries = ActivityLog.instance.entries;
    if (entries.isEmpty) return const _EmptyTab('Nothing has been recorded yet.');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _LogLine(
          timestamp: entry.timestamp,
          message: entry.studioLabel == null ? entry.message : '[${entry.studioLabel}] ${entry.message}',
        );
      },
    );
  }
}

/// Engineering Acquisition specifically: the live operations the EAM
/// runtime is currently running, plus its last reported error. Reads the
/// same `acquisitionRuntimeServiceProvider` the Acquisition Studio's own
/// panels do — no separate acquisition-only log store.
class _AcquisitionLogTab extends ConsumerWidget {
  const _AcquisitionLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(acquisitionRuntimeServiceProvider);
    // `ActivityLog._handleOperation` doesn't attribute operations to a
    // Studio (it records them with a null `studioLabel`), so this
    // matches on the stable prefix every EAM operation label carries --
    // see `AcquisitionRuntimeNotifier.operationLabelPrefix`, which is
    // referenced rather than duplicated so the two can't drift apart.
    final acquisitionEntries = ActivityLog.instance.entries
        .where((e) => e.message.contains(AcquisitionRuntimeNotifier.operationLabelPrefix))
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      children: [
        if (state.loading) const _StatusLine('Engineering Acquisition is working…'),
        if (state.lastError != null) _StatusLine(state.lastError!, isError: true),
        if (acquisitionEntries.isEmpty && !state.loading && state.lastError == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No acquisition activity yet. Run the Engineering Acquisition Wizard to see live progress here.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
            ),
          ),
        for (final entry in acquisitionEntries) _LogLine(timestamp: entry.timestamp, message: entry.message),
      ],
    );
  }
}

/// The live Engineering Engine validation report — the same report
/// Diagram Studio's own Validation panel and the global Validation page
/// already read from `engineeringProjectServiceProvider`.
class _ValidationTab extends StatelessWidget {
  const _ValidationTab({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(engineeringProjectServiceProvider).validationReport;
    final findings = report?.findings ?? const [];
    if (findings.isEmpty) {
      return const _EmptyTab('No validation findings — the open diagram is clean.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      itemCount: findings.length,
      itemBuilder: (context, index) {
        final finding = findings[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_outlined, size: 14, color: StudioColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${finding.code} — ${finding.message}',
                    style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Running and recently-finished operations from the Platform's own
/// `OperationManager` — downloads, background OCR, and anything else
/// that publishes an `OperationEvent`.
class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    final active = OperationManager.instance.activeOperations;
    final recent = OperationManager.instance.recentOperations;
    if (active.isEmpty && recent.isEmpty) {
      return const _EmptyTab('No active or recent operations.');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      children: [
        for (final op in active) _OperationRow(op),
        for (final op in recent) _OperationRow(op),
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow(this.operation);
  final Operation operation;

  @override
  Widget build(BuildContext context) {
    final color = switch (operation.status) {
      OperationStatus.running => StudioColors.selection,
      OperationStatus.completed => StudioColors.success,
      OperationStatus.failed => StudioColors.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(operation.label, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12))),
          if (operation.fraction != null)
            Text('${(operation.fraction! * 100).round()}%',
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// **Honestly empty.** A Review Queue would list Candidate Engineering
/// Objects awaiting engineering review — which requires the Engineering
/// Knowledge Engine (Milestone 2 of `oep_acquisition`), not built yet.
/// See `lib/acquisition/wizard/README.md`'s disclosed limitations.
class _ReviewQueueTab extends StatelessWidget {
  const _ReviewQueueTab();

  @override
  Widget build(BuildContext context) {
    return const _EmptyTab(
      'Nothing awaiting review. Candidate Engineering Objects require the Engineering Knowledge Engine, '
      'which has not been built yet.',
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.timestamp, required this.message});
  final DateTime timestamp;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = timestamp;
    final stamp = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$stamp  $message',
          style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontFamily: 'monospace')),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.message, {this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.autorenew,
              size: 14, color: isError ? StudioColors.error : StudioColors.selection),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: isError ? StudioColors.error : StudioColors.textPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
