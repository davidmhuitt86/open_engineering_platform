import 'command_requirement.dart';
import 'engineering_interaction_context.dart';

/// Semantic command groups (Resolution spec § 6). The menu builder
/// creates a section only when at least one applicable command belongs
/// to it (§ 6's own rule) — this enum exists purely for grouping,
/// never for hard-coded per-object-type menu construction.
enum CommandGroup { inspect, edit, test, diagnose, simulate, knowledge, ai, annotate, navigate }

/// The structured outcome of executing a contextual command (this
/// phase's own task 10 — "Implement Structured Command Results"; mirrors
/// the shape of the existing `CommandResult` in `command_registry.dart`,
/// extended with the additional fields that spec calls for, rather than
/// creating an unrelated parallel type for the *old* command system —
/// the old `CommandRegistry`/`CommandDescriptor` are untouched by this
/// phase; this result type belongs only to the new contextual command
/// path).
class ContextualCommandResult {
  const ContextualCommandResult({
    required this.success,
    this.message,
    this.errorCode,
    this.affectedObjectIds = const [],
    this.followUpAction,
  });

  final bool success;
  final String? message;
  final String? errorCode;
  final List<String> affectedObjectIds;

  /// An optional command id the UI may offer to run next (e.g. after
  /// "Place DMM Probe +" completes, a natural follow-up is "Place DMM
  /// Probe -"). Presentation-neutral — a string id, not a widget.
  final String? followUpAction;

  static const ContextualCommandResult notExecutable = ContextualCommandResult(
    success: false,
    message: 'This command is not currently executable.',
    errorCode: 'not_executable',
  );

  factory ContextualCommandResult.unavailable(String reason) =>
      ContextualCommandResult(success: false, message: reason, errorCode: 'requirement_not_satisfied');
}

/// A command's real execution — receives the *revalidated* context at
/// the moment of execution (Resolution spec § 14/§ 15), not the
/// possibly-stale context the menu was originally built from.
///
/// `null` for a command whose requirements this phase can express and
/// test, but whose actual execution needs a service this build has no
/// shared access point for yet (Diagram Studio's page-private
/// `MultimeterController`/`DiagramSimulationService` — see
/// `engineering_interaction_context.dart`'s own doc comments). The
/// resolver treats a resolvable-but-unexecutable command as disabled
/// with an honest reason, never as silently absent and never as fake
/// success.
typedef ContextualCommandExecutor = Future<ContextualCommandResult> Function(EngineeringInteractionContext context);

/// A presentation-neutral, requirements-declaring command (Architecture
/// spec § 8/§ 9). Distinct from the existing `CommandDescriptor`
/// (`command_registry.dart`) — that type is zero/single-string-argument
/// and has no requirement-based visibility model; extending it to carry
/// a `List<CommandRequirement>` and capability-aware visibility would
/// change its meaning for every existing Ribbon/Command-Palette
/// consumer, so this phase adds a new, additional type instead of
/// modifying the existing one (Implementation Plan § 5 — "extended
/// rather than replaced unless inspection proves it cannot support the
/// required behavior"; here inspection showed the *existing* type
/// itself needs no change, since a second, parallel type is enough to
/// add the new resolution model without disturbing it).
class ContextualCommandDescriptor {
  const ContextualCommandDescriptor({
    required this.id,
    required this.label,
    required this.description,
    required this.group,
    this.requirements = const [],
    this.priority = 0,
    this.submenuLabel,
    this.execute,
  });

  /// Stable, globally-unique — the same id this command keeps across
  /// every presentation surface (Architecture spec § 11 — "Presentation
  /// Independence").
  final String id;
  final String label;
  final String description;
  final CommandGroup group;
  final List<CommandRequirement> requirements;

  /// Lower runs first within a group (Resolution spec § 7 — ordering).
  final int priority;

  /// When non-null, this command is nested under a submenu with this
  /// label within its group (Resolution spec § 8 — e.g. "Measure >").
  final String? submenuLabel;

  final ContextualCommandExecutor? execute;

  bool get hasExecutor => execute != null;
}
