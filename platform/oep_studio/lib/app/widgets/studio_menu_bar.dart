import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/commands/command_registry.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/output_panel.dart';
import '../../shared/widgets/property_inspector_panel.dart';
import 'about_dialog.dart';

/// The Menu Bar (OEP Design System Master Application Shell, region 1:
/// "Global application menus and commands") -- File / Edit / View /
/// Repository / Engineering / Simulation / AI / Marketplace / Window /
/// Help, each a real dropdown of real actions.
///
/// **Design-system gap** (see `docs/ui_refactor/PHASE_1_NOTES.md`): the
/// approved render (`02_Main_Application_Shell.png`) implies menu
/// entries this codebase has no real, safe way to wire yet -- opening a
/// diagram file needs a native picker plus an unsaved-changes
/// confirmation Diagram Studio's own page already owns privately; the
/// Simulation Center dialog needs a live `DiagramSimulationService`
/// that only exists inside that same page's private state; multi-window
/// support doesn't exist at all. Every entry below is either real or
/// present-but-disabled with a tooltip explaining exactly why, per this
/// work's "disclose, don't fabricate" rule -- never silently omitted
/// (that would look like an oversight) and never faked.
class StudioMenuBar extends ConsumerWidget {
  const StudioMenuBar({required this.selected, super.key});

  final StudioDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = CommandRegistry.defaultRegistry;
    final projectState = ref.watch(engineeringProjectServiceProvider);
    final onDiagramStudio = selected == StudioDestination.diagram;
    final hasActiveDiagram = onDiagramStudio && projectState.session != null;

    Future<void> run(String commandId) async {
      final result = await registry.execute(ref, commandId);
      if (!context.mounted || result.isSuccess) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errorMessage ?? 'Command failed.')));
    }

    const openDiagramStudioFirst = 'Open Diagram Studio first.';
    const needsActiveDiagram = 'Open Diagram Studio with an active diagram first.';

    return Container(
      height: 23,
      color: StudioColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          _MenuBarButton(
            label: 'File',
            items: [
              _MenuAction('New Diagram', hasActiveDiagram ? () => run('diagram.newDocument') : null,
                  disabledReason: needsActiveDiagram),
              _MenuAction('Open Diagram…', null,
                  disabledReason: 'Use Diagram Studio\'s own Open button -- opening a file needs an '
                      'unsaved-changes confirmation this shell-level menu cannot safely duplicate.'),
              _MenuAction('Save Diagram', hasActiveDiagram ? () => run('diagram.saveDocument') : null,
                  disabledReason: needsActiveDiagram),
              _MenuAction('Save Diagram As…', null,
                  disabledReason: 'Use Diagram Studio\'s own Save As button (same reason as Open).'),
              _MenuAction('Close Diagram', hasActiveDiagram ? () => run('diagram.closeDocument') : null,
                  disabledReason: needsActiveDiagram),
            ],
          ),
          _MenuBarButton(
            label: 'Edit',
            items: [
              _MenuAction('Undo', hasActiveDiagram ? () => run('diagram.undo') : null,
                  disabledReason: openDiagramStudioFirst),
              _MenuAction('Redo', hasActiveDiagram ? () => run('diagram.redo') : null,
                  disabledReason: openDiagramStudioFirst),
            ],
          ),
          _MenuBarButton(
            label: 'View',
            items: [
              _MenuAction(
                'Output Panel',
                () => ref.read(outputPanelVisibleProvider.notifier).state = !ref.read(outputPanelVisibleProvider),
                checked: ref.watch(outputPanelVisibleProvider),
              ),
              _MenuAction(
                'Property Inspector',
                () => ref.read(propertyInspectorVisibleProvider.notifier).state =
                    !ref.read(propertyInspectorVisibleProvider),
                checked: ref.watch(propertyInspectorVisibleProvider),
              ),
            ],
          ),
          _MenuBarButton(
            label: 'Repository',
            items: [
              _MenuAction('Open Repository', () => context.go(StudioDestination.repository.path)),
              _MenuAction('Open Packages', () => context.go(StudioDestination.packages.path)),
            ],
          ),
          _MenuBarButton(
            label: 'Engineering',
            items: [
              _MenuAction('Open Diagram Studio', () => context.go(StudioDestination.diagram.path)),
              _MenuAction('Open Engineering Acquisition', () => context.go(StudioDestination.acquisition.path)),
              _MenuAction('Open Engineering Intelligence', () => context.go(StudioDestination.engineeringIntelligence.path)),
            ],
          ),
          _MenuBarButton(
            label: 'Simulation',
            items: [
              _MenuAction(
                'Simulation Center…',
                null,
                disabledReason: 'Open Diagram Studio and use its own Simulate toolbar button -- the Simulation '
                    'Center needs the active diagram\'s live simulation session, which today only exists inside '
                    'that page\'s own private state, not anywhere shell-level code can reach.',
              ),
            ],
          ),
          _MenuBarButton(
            label: 'AI',
            items: [
              _MenuAction('Open Knowledge Studio', () => context.go(StudioDestination.knowledge.path)),
              // Phase 8: real destination now exists
              // (`CopilotPage`/`StudioDestination.copilot`) built on the
              // same `DiagramAiService`/`UnifiedAiContextService` pipeline
              // `ValidationPage`'s own "Ask AI" button already used in
              // production -- no Knowledge Session requirement, since the
              // Copilot page reads whatever real context currently exists
              // and discloses honestly when there is none.
              _MenuAction('Open AI Engineering Copilot', () => context.go(StudioDestination.copilot.path)),
            ],
          ),
          _MenuBarButton(
            label: 'Marketplace',
            items: [
              _MenuAction('Open Engineering Exchange', () => context.go(StudioDestination.exchange.path)),
            ],
          ),
          _MenuBarButton(
            label: 'Window',
            items: [
              _MenuAction('New Window', null,
                  disabledReason: 'OEP Studio is a single-window desktop application today -- multi-window '
                      'support is not implemented.'),
            ],
          ),
          _MenuBarButton(
            label: 'Help',
            items: [
              _MenuAction('About OEP Studio', () => showAboutOepStudioDialog(context)),
              _MenuAction('Documentation', null, disabledReason: 'No in-app documentation browser exists yet.'),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction(this.label, this.onTap, {this.disabledReason, this.checked});
  final String label;
  final VoidCallback? onTap;
  final String? disabledReason;

  /// Non-null for a toggle-style item (e.g. "Output Panel"), rendered
  /// with a checkbox leading icon reflecting current state.
  final bool? checked;
}

class _MenuBarButton extends StatelessWidget {
  const _MenuBarButton({required this.label, required this.items});

  final String label;
  final List<_MenuAction> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: label,
      onSelected: (callback) => callback(),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<VoidCallback>(
            value: item.onTap,
            enabled: item.onTap != null,
            child: Tooltip(
              message: item.onTap == null ? (item.disabledReason ?? '') : '',
              child: Row(
                children: [
                  if (item.checked != null) ...[
                    Icon(item.checked! ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Text(item.label, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
        ),
      ),
    );
  }
}
