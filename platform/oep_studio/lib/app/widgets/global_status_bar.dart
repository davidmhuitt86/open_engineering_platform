import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/operations/operation_manager.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/oep_tokens.dart';
import '../../workspace/workspace_tabs_controller.dart';
import '../active_studio.dart';

/// The OEP Global Status Bar (target shell region 08,
/// `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md` §9;
/// canonical reference `docs/architecture/ux/renders/oep-shell/status-bar.svg`).
///
/// WP-UI-DS-008 — global, persistent shell chrome: hosted once by
/// `StudioShell`, the bottom-most region, visible across every Studio
/// (including Home, which has no Workspace Bar of its own). It displays
/// state; it does not execute engineering logic and does not duplicate any
/// state store — every value below reads an existing, already-authoritative
/// provider/service:
///
/// - Repository connection: [foundationRuntimeServiceProvider]
///   (`FoundationServiceState.isConnected`/`isRepositoryOpen`) — the same
///   source `OepApplicationHeader`'s "System Online" pill reads (Section
///   02), but this shows the *repository* half specifically, not a
///   duplicate of the header's own summary.
/// - Active Studio + active workspace: [activeStudioProvider] +
///   [resolveActiveTabForStudio] (`app/active_studio.dart`) — the exact
///   same resolution the Workspace Bar (Section 04, frozen) already uses,
///   reused read-only, not a second mechanism.
/// - Operations: [OperationManager.instance] — the same tracker
///   `OepApplicationHeader`'s notification bell already reads (Section 02);
///   here it is a compact "Idle"/"N running" summary, not the bell's own
///   dropdown list, so the two are complementary rather than duplicated.
/// - Diagram document state (only shown when Diagram Studio is active,
///   since this data is scoped to the one live Engine session, not to
///   Studios in general): [engineeringProjectServiceProvider]
///   (`EngineeringProjectState.isDirty`/`validationReport`) — the same
///   state `GlobalToolbar`'s `diagram.revalidate` command and
///   `diagram.saveDocument` command already act on (Section 07, frozen);
///   this only reads it.
/// - Clock: the real system time, refreshed every second — not fabricated
///   telemetry, just `DateTime.now()`.
///
/// No app-version field is shown: no runtime-accessible version source
/// exists in this codebase (no `package_info_plus` dependency, no bundled
/// version asset) — adding one would be a new capability, not a shell
/// migration, so it is left absent rather than hardcoded from `pubspec.yaml`
/// (which could silently drift out of sync with a hardcoded copy).
class GlobalStatusBar extends ConsumerStatefulWidget {
  const GlobalStatusBar({super.key});

  @override
  ConsumerState<GlobalStatusBar> createState() => _GlobalStatusBarState();
}

class _GlobalStatusBarState extends ConsumerState<GlobalStatusBar> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeStudio = ref.watch(activeStudioProvider);
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final tabsController = ref.watch(workspaceTabsControllerProvider);
    final activeTab = activeStudio == ActiveStudio.home
        ? null
        : resolveActiveTabForStudio(ref, tabsController.tabs, activeStudio, tabsController.activeId);

    return Container(
      width: double.infinity,
      height: OepGeometry.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: OepColors.surface1,
        border: Border(top: BorderSide(color: OepColors.border)),
      ),
      child: Row(
        children: [
          // --- Left zone: system/runtime ---
          Icon(Icons.circle, size: 8, color: foundation.isConnected ? OepColors.success : OepColors.warning),
          const SizedBox(width: 6),
          _StatusText(foundation.isConnected ? 'Ready' : 'Connecting…'),
          _Divider(),
          Icon(
            foundation.isRepositoryOpen ? Icons.folder : Icons.folder_off_outlined,
            size: 13,
            color: OepColors.textSecondary,
          ),
          const SizedBox(width: 6),
          _StatusText('Repository: ${foundation.isRepositoryOpen ? 'Open' : 'Closed'}'),

          _Divider(),

          // --- Middle zone: active Studio / active workspace context ---
          Icon(activeStudio.meta.icon, size: 13, color: OepColors.textSecondary),
          const SizedBox(width: 6),
          _StatusText(activeStudio.meta.label),
          if (activeTab != null) ...[
            const SizedBox(width: 6),
            Text('›', style: TextStyle(color: OepColors.textMuted, fontSize: OepTypography.metadata)),
            const SizedBox(width: 6),
            _StatusText(activeTab.title),
          ],

          if (activeStudio == ActiveStudio.diagram) ...[
            _Divider(),
            _DiagramStatus(),
          ],

          const Spacer(),

          // --- Right zone: operations + clock ---
          _OperationsSummary(),
          _Divider(),
          _StatusText(_formatClock(_now)),
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _formatClock(DateTime now) {
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final period = now.hour < 12 ? 'AM' : 'PM';
    return '$hour12:${_two(now.minute)}:${_two(now.second)} $period';
  }
}

class _DiagramStatus extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(engineeringProjectServiceProvider);
    final report = project.validationReport;
    final validationLabel = report == null
        ? 'Not validated'
        : report.isClean
            ? 'Valid'
            : '${report.errors.length} error(s), ${report.warnings.length} warning(s)';
    final validationColor = report == null
        ? OepColors.textMuted
        : report.hasErrors
            ? OepColors.error
            : report.isClean
                ? OepColors.success
                : OepColors.warning;
    return Row(
      children: [
        Icon(
          project.isDirty ? Icons.circle : Icons.check_circle_outline,
          size: project.isDirty ? 8 : 13,
          color: project.isDirty ? OepColors.warning : OepColors.success,
        ),
        const SizedBox(width: 6),
        _StatusText(project.isDirty ? 'Unsaved changes' : 'Saved'),
        const SizedBox(width: 12),
        Icon(Icons.fact_check_outlined, size: 13, color: validationColor),
        const SizedBox(width: 6),
        _StatusText(validationLabel, color: validationColor),
      ],
    );
  }
}

class _OperationsSummary extends StatefulWidget {
  @override
  State<_OperationsSummary> createState() => _OperationsSummaryState();
}

class _OperationsSummaryState extends State<_OperationsSummary> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = OperationManager.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = OperationManager.instance.activeOperations;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active.isEmpty ? Icons.check_circle_outline : Icons.sync,
          size: 13,
          color: active.isEmpty ? OepColors.textSecondary : OepColors.info,
        ),
        const SizedBox(width: 6),
        _StatusText(active.isEmpty ? 'Idle' : '${active.length} operation(s) running'),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color ?? OepColors.textSecondary,
        fontFamily: OepTypography.fontFamily,
        fontSize: OepTypography.metadata,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(width: 1, height: 14, color: OepColors.border),
    );
  }
}
