import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/commands/command_registry.dart';
import '../../core/input/platform_input_service.dart';
import '../../core/notifications/platform_notification_service.dart';
import '../../core/routing/studio_registry.dart';
import '../../core/theme/oep_tokens.dart';
import '../active_studio.dart';

/// The OEP Global Toolbar (target shell region 07,
/// `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md` §6;
/// canonical reference `docs/architecture/ux/renders/oep-shell/toolbar.svg`).
///
/// WP-UI-DS-007 — this is GLOBAL SHELL CHROME, not a Diagram-Studio-only
/// control strip: its container is persistent shell chrome (hosted once by
/// `StudioShell`, exactly like `OepApplicationHeader`/`OepGlobalStudioBar`),
/// and its CONTENT changes with [activeStudioProvider]. It does not own,
/// duplicate, or reimplement any action — every button here is a thin,
/// direct call into the existing Platform Command Framework
/// (`CommandRegistry`/`PlatformInputService`, WP-STUDIO-023/026), the exact
/// same dispatch path the Command Palette (`command_palette_dialog.dart`)
/// already uses. No new command, no new Engine call, no new business logic
/// was introduced to build this widget.
///
/// **Action source, per Studio:** [CommandRegistry.commandsForStudio], keyed
/// by [ActiveStudioCommandSource.studioDestination]. Commands are grouped by
/// their real [CommandDescriptor.capabilityId] (via
/// [StudioRegistry.findCapability] for the group's display label) — not an
/// invented grouping scheme. Today this yields real actions for Diagram
/// Studio, EAM, Knowledge Studio, and Engineering Exchange; Home,
/// Instruments, and Settings have no commands registered against them yet
/// (`CommandRegistry.defaultRegistry`'s own current contents — verified by
/// direct inspection, not assumed), so the Toolbar is intentionally sparse
/// for those three Studios — see this Work Package's own completion report
/// for the full list, not fabricated to fill the space.
///
/// **Not implemented here (frozen elsewhere):** the Diagram/Simulation
/// view-swap control (`OepStudioHeader`'s `_ViewSwapControl`) — its
/// strongest architectural home is Context Navigation (Section 06, not yet
/// built), not this Toolbar. It is untouched by this widget.
class GlobalToolbar extends ConsumerWidget {
  const GlobalToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStudio = ref.watch(activeStudioProvider);
    final destination = activeStudio.studioDestination;
    final commands = destination == null
        ? const <CommandDescriptor>[]
        : CommandRegistry.defaultRegistry.commandsForStudio(destination);

    final groups = <String, List<CommandDescriptor>>{};
    for (final command in commands) {
      groups.putIfAbsent(command.capabilityId, () => []).add(command);
    }

    return Container(
      width: double.infinity,
      height: OepGeometry.toolbarHeight,
      decoration: const BoxDecoration(
        color: OepColors.surface1,
        border: Border(
          top: BorderSide(color: OepColors.border),
          bottom: BorderSide(color: OepColors.border),
        ),
      ),
      child: commands.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No toolbar actions are registered for ${activeStudio.meta.label} yet.',
                  style: TextStyle(
                    color: OepColors.textMuted,
                    fontFamily: OepTypography.fontFamily,
                    fontSize: OepTypography.body,
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final entry in groups.entries)
                    _ToolbarGroup(
                      label: StudioRegistry.defaultRegistry.findCapability(entry.key)?.label ?? entry.key,
                      commands: entry.value,
                    ),
                ],
              ),
            ),
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({required this.label, required this.commands});

  final String label;
  final List<CommandDescriptor> commands;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: OepColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final command in commands) _ToolbarButton(command: command),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends ConsumerWidget {
  const _ToolbarButton({required this.command});

  final CommandDescriptor command;

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    var args = CommandArgs.none;
    if (command.requiresArgument) {
      final value = await _promptForArgument(context, command);
      if (value == null || value.trim().isEmpty) return; // cancelled
      args = CommandArgs(value: value);
    }
    final result = await PlatformInputService.defaultService.runCommand(ref, command.id, args: args);
    if (!context.mounted) return;
    if (result.isSuccess) {
      PlatformNotificationService.success(context, '${command.label} completed.');
    } else {
      PlatformNotificationService.error(context, result.errorMessage ?? '${command.label} failed.');
    }
  }

  /// Mirrors `command_palette_dialog.dart`'s own `_promptForArgument` —
  /// deliberately generic (no per-command/per-Studio wording), same as
  /// that dialog's own doc comment explains for the identical need. Not
  /// extracted into a shared widget in this pass, to avoid modifying the
  /// unrelated, already-shipped Command Palette file for this section.
  Future<String?> _promptForArgument(BuildContext context, CommandDescriptor command) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OepColors.surface2,
        title: Text(command.label),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: OepColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Enter a value'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: command.description,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(OepGeometry.radiusSm),
            onTap: () => _run(context, ref),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: OepColors.border),
                borderRadius: BorderRadius.circular(OepGeometry.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(command.id), size: 14, color: OepColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    command.label,
                    style: const TextStyle(color: OepColors.textPrimary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small, best-effort icon lookup by command id — presentation only, not
/// a claim about the command's own semantics. Falls back to a generic icon
/// for any command not explicitly listed, so a future addition to
/// `CommandRegistry.defaultRegistry` renders (with a plain icon) rather
/// than crashing or being silently dropped.
IconData _iconFor(String commandId) => switch (commandId) {
      'diagram.newDocument' => Icons.add,
      'diagram.openDocument' => Icons.folder_open,
      'diagram.saveDocument' => Icons.save,
      'diagram.saveDocumentAs' => Icons.save_as,
      'diagram.closeDocument' => Icons.close,
      'diagram.undo' => Icons.undo,
      'diagram.redo' => Icons.redo,
      'diagram.revalidate' => Icons.fact_check_outlined,
      'diagram.analyze' => Icons.analytics_outlined,
      'acquisition.executeJob' => Icons.play_arrow,
      'acquisition.cancelJob' => Icons.cancel_outlined,
      'acquisition.verify' => Icons.check_circle_outline,
      'acquisition.extractMetadata' => Icons.description_outlined,
      'acquisition.publish' => Icons.publish_outlined,
      'knowledge.acceptCandidate' => Icons.check,
      'knowledge.rejectCandidate' => Icons.close,
      'knowledge.deleteCandidate' => Icons.delete_outline,
      'knowledge.acceptAiSuggestion' => Icons.auto_awesome_outlined,
      'knowledge.rejectAiSuggestion' => Icons.block_outlined,
      'exchange.search' => Icons.search,
      'exchange.refreshMarketplace' => Icons.storefront_outlined,
      'exchange.refreshRepository' => Icons.refresh,
      _ => Icons.bolt_outlined,
    };
