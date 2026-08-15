import '../../core/commands/command_registry.dart';
import '../perspective/perspective_manager.dart';

/// WP-DS-006 Engineering Workbench — Command Manager.
///
/// The governing spec lists a Command Manager among the 8 Workbench-owned
/// managers. This codebase already has a Platform-wide command dispatcher,
/// `CommandRegistry` (WP-STUDIO-023, `lib/core/commands/command_registry.dart`)
/// — `CommandDescriptor`/`CommandArgs`/`CommandResult`/`execute` are exactly
/// the shape a Command Manager needs, so [WorkbenchCommandManager] reuses
/// that shape rather than inventing a second, parallel dispatch mechanism.
///
/// It does **not** add its own commands to `CommandRegistry.defaultRegistry`
/// itself: that field is a `static final` list built once, at class-load
/// time, from a fixed `List<CommandDescriptor>` literal
/// (`command_registry.dart` lines ~219 on) — there is no `register`/`add`
/// method on `CommandRegistry`, only a constructor taking the full list.
/// Extending it in place would mean editing `command_registry.dart`, which
/// belongs to WP-STUDIO-023, an already-shipped, unrelated Work Package —
/// out of scope here ("Do NOT modify" per this Work Package's own
/// constraints on read-only core files).
///
/// Instead, [WorkbenchCommandManager] builds a **second**, Workbench-scoped
/// `CommandRegistry` instance, seeded with Workbench-only commands (Phase 1:
/// "activate perspective by id") plus every command already in
/// `CommandRegistry.defaultRegistry`, so a caller that only knows about
/// `WorkbenchCommandManager.registry` still sees the Platform's existing
/// commands too — dispatch stays centralized in one object per call site,
/// without editing the shipped file. [CommandDescriptor.capabilityId]
/// validation (`CommandRegistry.validate`) is intentionally not run against
/// the Workbench's synthetic commands here: "activate perspective by id" is
/// shell/UI navigation, not a Studio capability, so it deliberately has no
/// matching `CapabilityDescriptor` — see [workbenchActivatePerspectiveCommandId].
class WorkbenchCommandManager {
  WorkbenchCommandManager({required PerspectiveManager perspectiveManager, CommandRegistry? baseRegistry})
      : registry = CommandRegistry(
          [
            ...(baseRegistry ?? CommandRegistry.defaultRegistry).commands,
            CommandDescriptor(
              id: workbenchActivatePerspectiveCommandId,
              label: 'Activate Perspective',
              description: 'Activates a registered Workbench Perspective by id.',
              // Shell/UI navigation, not a Studio capability — see class
              // doc comment for why this is deliberately unvalidated
              // against StudioRegistry's capability metadata.
              capabilityId: workbenchCapabilityId,
              requiresArgument: true,
              execute: (ref, args) async => perspectiveManager.activate(args.value!),
            ),
          ],
        );

  /// The Workbench-scoped [CommandRegistry] — every Platform command plus
  /// every Workbench-only command (Phase 1: [workbenchActivatePerspectiveCommandId]).
  final CommandRegistry registry;

  static const String workbenchActivatePerspectiveCommandId = 'workbench.activatePerspective';

  /// Not a real, registered `CapabilityDescriptor` id — see class doc
  /// comment. Kept as a named constant (rather than an inline literal) so
  /// a future Work Package that does want to register a real "Workbench
  /// Shell" capability has exactly one place to point it at.
  static const String workbenchCapabilityId = 'workbench.shell';
}
