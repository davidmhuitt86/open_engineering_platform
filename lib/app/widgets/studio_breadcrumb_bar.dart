import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/navigation_history_service.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';

/// The Breadcrumb Bar + Back/Forward History (ODS-S004 Navigation
/// Standard § 5 "Navigation Components": Breadcrumb Bar, Back/Forward
/// History; § 4 "Navigation Hierarchy": Application, Workspace,
/// Perspective, Project, Document, Engineering Object).
///
/// Segments are built only from state that actually exists — Section
/// "Do not fabricate breadcrumb states" of this Work Package's own
/// brief: "OEP Studio" (the Application, always real) and the current
/// [StudioDestination]'s label (the Perspective, always real via
/// routing) are unconditional; a third, Document-level segment appears
/// only where this build genuinely tracks one today (Diagram Studio's
/// open document, Knowledge Studio's active Curation Session) — every
/// other Studio simply stops at two segments rather than inventing a
/// Project/Object level this codebase has no real data for yet.
class StudioBreadcrumbBar extends ConsumerWidget {
  const StudioBreadcrumbBar({required this.selected, super.key});

  final StudioDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(navigationHistoryProvider);
    final historyNotifier = ref.read(navigationHistoryProvider.notifier);

    return Container(
      height: 22,
      color: StudioColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            style: IconButton.styleFrom(minimumSize: const Size(20, 20), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            icon: const Icon(Icons.arrow_back),
            color: StudioColors.textSecondary,
            disabledColor: StudioColors.textDisabled,
            onPressed: history.canGoBack ? () => historyNotifier.goBack(context) : null,
          ),
          IconButton(
            tooltip: 'Forward',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            style: IconButton.styleFrom(minimumSize: const Size(20, 20), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            icon: const Icon(Icons.arrow_forward),
            color: StudioColors.textSecondary,
            disabledColor: StudioColors.textDisabled,
            onPressed: history.canGoForward ? () => historyNotifier.goForward(context) : null,
          ),
          const SizedBox(width: 8),
          const _CrumbDivider(first: true),
          _Crumb(
            label: 'OEP Studio',
            isCurrent: false,
            onTap: selected == StudioDestination.dashboard ? null : () => context.go(StudioDestination.dashboard.path),
          ),
          const _CrumbDivider(),
          if (_documentCrumb(ref) case final String document) ...[
            _Crumb(label: selected.label, isCurrent: false, onTap: null),
            const _CrumbDivider(),
            _Crumb(label: document, isCurrent: true, onTap: null),
          ] else
            _Crumb(label: selected.label, isCurrent: true, onTap: null),
        ],
      ),
    );
  }

  /// The real Document-level breadcrumb segment for [selected], or
  /// `null` where no such context currently exists — never a
  /// placeholder string.
  String? _documentCrumb(WidgetRef ref) {
    switch (selected) {
      case StudioDestination.diagram:
        final projectState = ref.watch(engineeringProjectServiceProvider);
        if (projectState.session == null) return null;
        return projectState.document.path ?? 'Untitled Diagram';
      case StudioDestination.knowledge:
        final session = ref.watch(foundationRuntimeServiceProvider).knowledgeSession;
        return session?.name;
      default:
        return null;
    }
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.isCurrent, required this.onTap});

  final String label;

  /// Styles this as the trail's terminal segment (bold, primary text)
  /// regardless of whether it happens to be interactive.
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isCurrent ? StudioColors.textPrimary : StudioColors.textSecondary,
        fontSize: 11.5,
        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    if (onTap == null) return Flexible(child: child);
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), child: child),
      ),
    );
  }
}

class _CrumbDivider extends StatelessWidget {
  const _CrumbDivider({this.first = false});

  final bool first;

  @override
  Widget build(BuildContext context) {
    if (first) return const SizedBox(width: 2);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right, size: 13, color: StudioColors.textDisabled),
    );
  }
}
