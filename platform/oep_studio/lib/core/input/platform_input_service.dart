import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/command_registry.dart';
import '../events/platform_event.dart';
import '../events/platform_event_bus.dart';

/// The Platform Input Framework's single entry point (WP-STUDIO-026)
/// for user-initiated command execution.
///
/// Before WP-STUDIO-026, the Command Palette (WP-STUDIO-024) called
/// [CommandRegistry.execute] directly — the only production call site
/// of command dispatch in the app. [PlatformInputService] doesn't
/// change *how* a command runs (that stays entirely owned by
/// [CommandRegistry] — this class re-implements none of its
/// resolution/validation/dispatch logic, only forwards to it); it gives
/// every present and future *source* of a command invocation — the
/// Command Palette today, a keyboard shortcut or context menu in some
/// future Work Package — one shared place to call through, so a second
/// input source never needs to duplicate the Command Palette's own
/// forwarding logic.
///
/// Still a plain, static, compile-time singleton — [defaultService] —
/// exactly like [CommandRegistry.defaultRegistry] and
/// `StudioRegistry.defaultRegistry` before it.
///
/// [runCommand] also publishes a [CommandExecutedEvent] on
/// [PlatformEventBus] (WP-STUDIO-028) after every call — this is the
/// bus's one, single source of that event; nothing else in the app
/// calls [CommandRegistry.execute] directly (verified in WP-STUDIO-026),
/// so there is no risk of a duplicate publish per command run.
class PlatformInputService {
  PlatformInputService({CommandRegistry? commandRegistry, PlatformEventBus? eventBus})
      : _commandRegistry = commandRegistry ?? CommandRegistry.defaultRegistry,
        _eventBus = eventBus ?? PlatformEventBus.instance;

  final CommandRegistry _commandRegistry;
  final PlatformEventBus _eventBus;

  /// Every command a UI surface can offer the user, in registration
  /// order — a direct passthrough of [CommandRegistry.commands], so a
  /// caller (the Command Palette, or a future input source) never needs
  /// its own reference to [CommandRegistry].
  List<CommandDescriptor> get commands => _commandRegistry.commands;

  /// Runs [commandId] on behalf of whatever UI surface the user just
  /// interacted with — the one method every input source should call
  /// instead of reaching into [CommandRegistry] itself. Forwards
  /// verbatim to [CommandRegistry.execute] for the actual
  /// resolution/argument-validation/dispatch behavior, then publishes
  /// the resulting [CommandExecutedEvent].
  Future<CommandResult> runCommand(
    WidgetRef ref,
    String commandId, {
    CommandArgs args = CommandArgs.none,
  }) async {
    final result = await _commandRegistry.execute(ref, commandId, args: args);
    _eventBus.publish(CommandExecutedEvent(commandId: commandId, result: result));
    return result;
  }

  static final PlatformInputService defaultService = PlatformInputService();
}
