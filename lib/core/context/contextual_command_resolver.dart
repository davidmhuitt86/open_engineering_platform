import 'capability_adapters.dart';
import 'command_requirement.dart';
import 'contextual_command_descriptor.dart';
import 'engineering_interaction_context.dart';
import 'menu_descriptor.dart';

/// How a command relates to the current context (Resolution spec § 5 —
/// "Hidden vs Disabled").
enum CommandVisibility {
  /// Every requirement is satisfied; the command may execute.
  applicable,

  /// The command has no meaningful relationship to the current context
  /// (e.g. a measurement command with nothing selected/targeted at
  /// all) — omitted from the menu entirely, never shown disabled.
  hidden,

  /// The command is conceptually relevant to the current target, but a
  /// specific capability/service it needs is not currently available —
  /// shown disabled with [ResolvedCommand.disabledReason] (§ 5: "the
  /// reason for temporary unavailability is useful to the user").
  disabled,
}

class ResolvedCommand {
  const ResolvedCommand({required this.descriptor, required this.visibility, this.disabledReason});
  final ContextualCommandDescriptor descriptor;
  final CommandVisibility visibility;
  final String? disabledReason;

  bool get isApplicable => visibility == CommandVisibility.applicable;
}

/// Requirements whose failure means "this command has no relationship
/// to the current context at all" (→ hidden) rather than "the command
/// is relevant but something it needs is unavailable" (→ disabled).
/// This is the deterministic rule Resolution spec § 5 leaves to
/// implementation judgment: a target-shaped requirement failing means
/// there is nothing here to act on; a capability/service requirement
/// failing means there is something here, but a specific ability is
/// missing.
bool _isTargetShapedRequirement(CommandRequirement requirement) =>
    requirement is RequireSelectedTarget ||
    requirement is RequireSingleSelection ||
    requirement is RequireDiagramOpen ||
    requirement is RequireSimulationMode ||
    requirement is RequireActiveSimulationSession ||
    requirement is RequireBothProbesPlaced ||
    requirement is RequireStudioMode ||
    // The most literally target-shaped requirement of all: the target
    // is simply the wrong kind of thing for this command ("Add Label"
    // on a whole component, "Delete" on a pin), so the command has no
    // relationship to this context at all.
    requirement is RequireCursorTargetKind ||
    requirement is RequireTargetHasActiveFault;

/// The Contextual Command Service (Architecture spec § 2's "Contextual
/// Command Service"): converts one [EngineeringInteractionContext] plus
/// a registered command list into applicable commands and, from those,
/// a [MenuDescriptor] — the full pipeline in Resolution spec § 2
/// (Normalize → Collect Capabilities → Load Commands → Evaluate
/// Requirements → Filter → Group → Sort → Build MenuDescriptor).
///
/// Presentation-independent: produces no Flutter widgets (Architecture
/// spec § 3's "What the Service Owns" vs. "What it does not own").
class ContextualCommandResolver {
  const ContextualCommandResolver({required this.commands, this.capabilityBridge = CapabilityBridge.defaultBridge});

  final List<ContextualCommandDescriptor> commands;
  final CapabilityBridge capabilityBridge;

  /// Steps 1-5 of the pipeline: normalize (the context is already
  /// normalized by construction), collect capabilities, load commands
  /// (this resolver's own [commands] list), evaluate requirements,
  /// classify visibility. Does not group/sort/build a menu — see
  /// [buildMenu] for that.
  List<ResolvedCommand> resolveCommands(EngineeringInteractionContext context) {
    final capabilities = capabilityBridge.resolve(context);
    final resolved = <ResolvedCommand>[];

    for (final command in commands) {
      String? firstTargetFailure;
      String? firstCapabilityFailure;

      for (final requirement in command.requirements) {
        final reason = requirement.unsatisfiedReason(context, capabilities);
        if (reason == null) continue;
        if (_isTargetShapedRequirement(requirement)) {
          firstTargetFailure ??= reason;
        } else {
          firstCapabilityFailure ??= reason;
        }
      }

      if (firstTargetFailure != null) {
        resolved.add(ResolvedCommand(descriptor: command, visibility: CommandVisibility.hidden));
      } else if (firstCapabilityFailure != null) {
        resolved.add(ResolvedCommand(
          descriptor: command,
          visibility: CommandVisibility.disabled,
          disabledReason: firstCapabilityFailure,
        ));
      } else if (!command.hasExecutor) {
        // Every declared requirement passed, but this build has no real
        // executor wired for it yet (see `ContextualCommandExecutor`'s
        // own doc comment) — conceptually relevant, disabled, honest
        // reason, never silently hidden and never fake-executable.
        resolved.add(ResolvedCommand(
          descriptor: command,
          visibility: CommandVisibility.disabled,
          disabledReason: 'This command is not yet connected to a real execution path.',
        ));
      } else {
        resolved.add(ResolvedCommand(descriptor: command, visibility: CommandVisibility.applicable));
      }
    }

    return resolved;
  }

  /// Steps 6-9: group, sort, build the [MenuDescriptor]. Sections
  /// (Resolution spec § 6) are created only when they contain at least
  /// one applicable-or-disabled command; hidden commands never appear.
  MenuDescriptor buildMenu(EngineeringInteractionContext context, {required String title, required String contextIdentity}) {
    final resolvedCommands = resolveCommands(context).where((r) => r.visibility != CommandVisibility.hidden).toList();

    final byGroup = <CommandGroup, List<ResolvedCommand>>{};
    for (final resolved in resolvedCommands) {
      byGroup.putIfAbsent(resolved.descriptor.group, () => []).add(resolved);
    }

    final sections = <MenuSection>[];
    for (final group in CommandGroup.values) {
      final groupCommands = byGroup[group];
      if (groupCommands == null || groupCommands.isEmpty) continue;
      groupCommands.sort((a, b) => a.descriptor.priority.compareTo(b.descriptor.priority));

      final bySubmenu = <String?, List<ResolvedCommand>>{};
      for (final resolved in groupCommands) {
        bySubmenu.putIfAbsent(resolved.descriptor.submenuLabel, () => []).add(resolved);
      }

      final items = <MenuItem>[];
      for (final entry in bySubmenu.entries) {
        if (entry.key == null) {
          items.addAll(entry.value.map(_toMenuItem));
        } else {
          items.add(MenuItem(
            commandId: '${group.name}.submenu.${entry.key}',
            label: entry.key!,
            description: '',
            enabled: entry.value.any((r) => r.isApplicable),
            submenu: entry.value.map(_toMenuItem).toList(),
          ));
        }
      }

      sections.add(MenuSection(id: group.name, label: labelForGroup(group), items: items));
    }

    return MenuDescriptor(title: title, contextIdentity: contextIdentity, sections: sections);
  }

  MenuItem _toMenuItem(ResolvedCommand resolved) => MenuItem(
        commandId: resolved.descriptor.id,
        label: resolved.descriptor.label,
        description: resolved.descriptor.description,
        enabled: resolved.isApplicable,
        disabledReason: resolved.disabledReason,
      );

  /// Executes [commandId] against a **freshly-provided** [context] —
  /// callers must pass the current, revalidated context, not whatever
  /// context a previously-built menu used (Resolution spec § 14/§ 15 —
  /// "Stale Context": "Do not execute solely because the command was
  /// valid when the menu opened"). This method re-runs the full
  /// requirement evaluation itself rather than trusting the caller's
  /// own judgment of validity.
  Future<ContextualCommandResult> execute(String commandId, EngineeringInteractionContext context) async {
    ContextualCommandDescriptor? command;
    for (final candidate in commands) {
      if (candidate.id == commandId) {
        command = candidate;
        break;
      }
    }
    if (command == null) {
      return ContextualCommandResult.unavailable('No command registered with id "$commandId".');
    }

    final capabilities = capabilityBridge.resolve(context);
    for (final requirement in command.requirements) {
      final reason = requirement.unsatisfiedReason(context, capabilities);
      if (reason != null) {
        return ContextualCommandResult.unavailable(reason);
      }
    }

    final executor = command.execute;
    if (executor == null) {
      return ContextualCommandResult.notExecutable;
    }

    try {
      return await executor(context);
    } catch (error) {
      return ContextualCommandResult(success: false, message: error.toString(), errorCode: 'execution_error');
    }
  }
}
