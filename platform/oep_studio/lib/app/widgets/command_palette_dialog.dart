import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/commands/command_registry.dart';
import '../../core/input/platform_input_service.dart';
import '../../core/notifications/platform_notification_service.dart';
import '../../core/routing/studio_registry.dart';
import '../../core/theme/studio_colors.dart';

/// Opens the Platform Command Palette (WP-STUDIO-024) — the first
/// user-facing consumer of the Platform Command Framework
/// (WP-STUDIO-023) and its Studio Registry/Capability Metadata
/// (WP-STUDIO-021/022).
///
/// This dialog is a pure Platform UI component: it reads
/// [PlatformInputService.commands] and [StudioRegistry.defaultRegistry]
/// to discover what to show, and dispatches exclusively through
/// [PlatformInputService.runCommand] (WP-STUDIO-026 — previously
/// [CommandRegistry.execute] directly) to run anything — it never
/// registers a command, never holds its own copy of command/capability
/// metadata, and never calls a Studio method directly. Routing through
/// [PlatformInputService] rather than [CommandRegistry] itself means a
/// future keyboard shortcut or context menu (out of scope for this Work
/// Package) can share the exact same entry point instead of duplicating
/// this dialog's own forwarding logic.
///
/// [inputService]/[studioRegistry] default to the real platform
/// singletons and only exist as parameters so tests can exercise the
/// "no commands registered" empty state (Phase 5) with a deliberately
/// empty registry — production code should never pass either.
Future<void> showCommandPaletteDialog(
  BuildContext context, {
  PlatformInputService? inputService,
  StudioRegistry? studioRegistry,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CommandPaletteDialog(
      inputService: inputService ?? PlatformInputService.defaultService,
      studioRegistry: studioRegistry ?? StudioRegistry.defaultRegistry,
    ),
  );
}

class _CommandPaletteDialog extends ConsumerStatefulWidget {
  const _CommandPaletteDialog({required this.inputService, required this.studioRegistry});

  final PlatformInputService inputService;
  final StudioRegistry studioRegistry;

  @override
  ConsumerState<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<_CommandPaletteDialog> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isExecuting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CommandDescriptor> _filter(List<CommandDescriptor> commands, StudioRegistry studioRegistry) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return commands;
    return [
      for (final command in commands)
        if (_matches(command, studioRegistry, needle)) command,
    ];
  }

  /// Phase 3 search: simple case-insensitive substring matching against
  /// command name, Studio name, capability name, and description — no
  /// fuzzy matching, ranking, or synonyms. Studio/capability names are
  /// looked up from [StudioRegistry] on demand, never cached locally,
  /// so the palette can never drift out of sync with it.
  bool _matches(CommandDescriptor command, StudioRegistry studioRegistry, String needle) {
    if (command.label.toLowerCase().contains(needle)) return true;
    if (command.description.toLowerCase().contains(needle)) return true;
    final studioName = studioRegistry.ownerOf(command.capabilityId)?.label ?? '';
    if (studioName.toLowerCase().contains(needle)) return true;
    final capabilityName = studioRegistry.findCapability(command.capabilityId)?.label ?? '';
    if (capabilityName.toLowerCase().contains(needle)) return true;
    return false;
  }

  Future<void> _runCommand(CommandDescriptor command) async {
    var args = CommandArgs.none;
    if (command.requiresArgument) {
      final value = await _promptForArgument(command);
      if (value == null) return; // user cancelled the prompt
      args = CommandArgs(value: value);
    }
    if (!mounted) return;

    setState(() => _isExecuting = true);
    final result = await widget.inputService.runCommand(ref, command.id, args: args);
    if (!mounted) return;
    setState(() => _isExecuting = false);

    if (result.isSuccess) {
      Navigator.of(context).pop();
      PlatformNotificationService.success(context, '${command.label} completed.');
      return;
    }
    await _showOutcomeDialog(command, result);
  }

  /// Commands that already existed as a `String`-argument method
  /// ([CommandDescriptor.requiresArgument]) need a value before
  /// [PlatformInputService.runCommand] can run them — this prompt is
  /// deliberately generic (no per-command/per-Studio wording) since the
  /// palette must not encode any Studio-specific knowledge.
  Future<String?> _promptForArgument(CommandDescriptor command) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: Text(command.label),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Enter a value'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Run')),
        ],
      ),
    );
  }

  /// Phase 4: handles `notFound`/`invalidArguments`/`failure` gracefully,
  /// using the same `AlertDialog`/`StudioColors.surfaceRaised` pattern
  /// `showFoundationErrorDialog` and the Session Browser dialog already
  /// use elsewhere in the app.
  Future<void> _showOutcomeDialog(CommandDescriptor command, CommandResult result) {
    final title = switch (result.outcome) {
      CommandOutcome.notFound => 'Command Not Found',
      CommandOutcome.invalidArguments => 'Invalid Argument',
      CommandOutcome.failure => "Couldn't Run \"${command.label}\"",
      CommandOutcome.success => '',
    };
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: Text(title),
        content: Text(result.errorMessage ?? 'Something went wrong.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studioRegistry = widget.studioRegistry;
    final allCommands = widget.inputService.commands;
    final filtered = _filter(allCommands, studioRegistry);

    return Dialog(
      backgroundColor: StudioColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_outlined, size: 18, color: StudioColors.selection),
                  SizedBox(width: 10),
                  Text(
                    'Commands',
                    style: TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 16),
                  hintText: 'Search commands…',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: allCommands.isEmpty
                    ? const _CommandPaletteEmptyState(message: 'No commands are registered yet.')
                    : filtered.isEmpty
                        ? _CommandPaletteEmptyState(message: 'No commands match "${_query.trim()}".')
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final command = filtered[index];
                              return _CommandRow(
                                command: command,
                                studioRegistry: studioRegistry,
                                enabled: !_isExecuting,
                                onTap: () => _runCommand(command),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.command,
    required this.studioRegistry,
    required this.enabled,
    required this.onTap,
  });

  final CommandDescriptor command;
  final StudioRegistry studioRegistry;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final studioName = studioRegistry.ownerOf(command.capabilityId)?.label ?? 'Platform';
    final capabilityName = studioRegistry.findCapability(command.capabilityId)?.label ?? command.capabilityId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right, size: 16, color: StudioColors.textDisabled),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          command.label,
                          style: const TextStyle(
                            color: StudioColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _Tag(text: studioName),
                        _Tag(text: capabilityName),
                      ],
                    ),
                    if (command.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        command.description,
                        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: StudioColors.surfaceSunken, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5)),
    );
  }
}

class _CommandPaletteEmptyState extends StatelessWidget {
  const _CommandPaletteEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined, size: 32, color: StudioColors.textDisabled),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
