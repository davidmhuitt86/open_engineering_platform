import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/commands/command_registry.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/routing/studio_registry.dart';
import '../../core/theme/studio_colors.dart';

/// The Ribbon (OEP Design System Master Application Shell, region 2:
/// icon-button groups under the Menu Bar, grouped by capability).
///
/// **Design-system gap, and a real architectural limitation** (see
/// `docs/ui_refactor/PHASE_1_NOTES.md`): the approved render
/// (`02_Main_Application_Shell.png`) shows every Studio with a populated
/// Ribbon. In this codebase, [CommandRegistry] commands mostly declare
/// `requiresArgument: true` (a job id, a candidate id, a file path) --
/// there is no "current selection" mechanism a shell-level widget can
/// use to supply that argument generically. Only Diagram Studio
/// currently exposes zero-argument commands. Rather than fabricate a
/// selection-argument plumbing layer or invent Ribbon buttons that call
/// nothing real, this widget shows exactly the zero-argument commands
/// that genuinely exist for the active Studio, grouped under their real
/// [CapabilityDescriptor.label], and an honest empty state everywhere
/// else. This is a real open question for the design/architecture
/// decision this Work Package's own Phase 1 report calls out -- not a
/// gap this widget silently works around.
class StudioRibbon extends ConsumerWidget {
  const StudioRibbon({required this.selected, super.key});

  final StudioDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = CommandRegistry.defaultRegistry;
    final studioRegistry = StudioRegistry.defaultRegistry;
    final zeroArgCommands = registry.commandsForStudio(selected).where((c) => !c.requiresArgument).toList();

    Future<void> run(String commandId) async {
      final result = await registry.execute(ref, commandId);
      if (!context.mounted || result.isSuccess) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errorMessage ?? 'Command failed.')));
    }

    if (zeroArgCommands.isEmpty) {
      return Container(
        height: 24,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: StudioColors.surface,
          border: Border(bottom: BorderSide(color: StudioColors.borderSubtle)),
        ),
        child: const Text(
          'No ribbon actions for this workspace yet -- use its own panels below.',
          style: TextStyle(color: StudioColors.textDisabled, fontSize: 11.5),
        ),
      );
    }

    final byCapability = <String, List<CommandDescriptor>>{};
    for (final command in zeroArgCommands) {
      byCapability.putIfAbsent(command.capabilityId, () => []).add(command);
    }

    return Container(
      height: 24,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(bottom: BorderSide(color: StudioColors.borderSubtle)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in byCapability.entries)
              _RibbonGroup(
                title: studioRegistry.findCapability(entry.key)?.label ?? entry.key,
                commands: entry.value,
                onRun: run,
              ),
          ],
        ),
      ),
    );
  }
}

class _RibbonGroup extends StatelessWidget {
  const _RibbonGroup({required this.title, required this.commands, required this.onRun});

  final String title;
  final List<CommandDescriptor> commands;
  final void Function(String commandId) onRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: StudioColors.borderSubtle)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final command in commands)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${command.label} ($title) -- ${command.description}',
                child: InkWell(
                  onTap: () => onRun(command.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(_iconFor(command.id), size: 16, color: StudioColors.textPrimary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String commandId) {
    switch (commandId) {
      case 'diagram.newDocument':
        return Icons.note_add_outlined;
      case 'diagram.saveDocument':
        return Icons.save_outlined;
      case 'diagram.closeDocument':
        return Icons.close;
      case 'diagram.undo':
        return Icons.undo;
      case 'diagram.redo':
        return Icons.redo;
      case 'diagram.revalidate':
        return Icons.fact_check_outlined;
      default:
        return Icons.play_arrow_outlined;
    }
  }
}
