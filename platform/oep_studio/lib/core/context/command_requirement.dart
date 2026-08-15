import 'engineering_capability.dart';
import 'engineering_interaction_context.dart';

/// One condition a [ContextualCommandDescriptor] declares instead of a
/// command manually re-checking every possible menu context
/// (Architecture spec § 9 — "Command Requirements"). The resolver
/// (`contextual_command_resolver.dart`) evaluates every requirement a
/// command declares; a command is applicable only when every
/// requirement it declares is satisfied.
sealed class CommandRequirement {
  const CommandRequirement();

  /// `null` when satisfied; a short, user-facing reason when not —
  /// used by the resolver to decide hidden vs. disabled (Resolution
  /// spec § 5) and, when disabled, what to tell the user.
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities);

  bool isSatisfied(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      unsatisfiedReason(context, capabilities) == null;
}

/// Requires an effective target (cursor target or a single selected
/// item) to exist — Architecture spec § 9's `SelectedEngineeringTarget`.
class RequireSelectedTarget extends CommandRequirement {
  const RequireSelectedTarget();

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      context.effectiveTarget == null ? 'No object is selected or targeted.' : null;
}

/// Requires a specific [SimulationMode] to be currently active. Distinct
/// from [RequireCapability]: this asks "is this whole mode even
/// happening" (a target-shaped gate — see
/// `contextual_command_resolver.dart`'s hidden-vs-disabled rule),
/// whereas a specific fault/measurement capability requirement asks
/// "given the mode is active, is this specific operation available"
/// (a disabled-with-reason gate). Matches Resolution spec § 11's own
/// worked example: fault commands simply disappear in normal diagram
/// mode, they are not shown disabled.
class RequireSimulationMode extends CommandRequirement {
  const RequireSimulationMode(this.mode);
  final SimulationMode mode;

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      (context.simulation.active && context.simulation.mode == mode)
          ? null
          : '${mode == SimulationMode.diagnostic ? 'Diagnostic' : 'Engineering'} Simulation is not active.';
}

/// Requires a real, active simulation session (`DiagramSimulationService.hasSession`
/// -- Phase 2's real, engine-backed replacement for [RequireSimulationMode]
/// on commands that do not actually depend on a Diagnostic/Engineering
/// distinction the Simulation Engine does not have). Target-shaped: no
/// active session means fault/component commands have no relationship
/// to the current context at all, matching Resolution spec § 11's
/// "disappears entirely," not merely disabled.
class RequireActiveSimulationSession extends CommandRequirement {
  const RequireActiveSimulationSession();

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      context.simulation.active ? null : 'No simulation session is active.';
}

/// Requires both DMM probes to already be placed (Contract spec § 10's
/// real DMM workflow: place + and − before a measurement is meaningful).
/// Target-shaped: with no probes placed, a Measure command has no
/// relationship to the current context yet.
class RequireBothProbesPlaced extends CommandRequirement {
  const RequireBothProbesPlaced();

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) {
    if (!context.measurement.probeAPlaced || !context.measurement.probeBPlaced) {
      return 'Place both DMM probes before measuring.';
    }
    return null;
  }
}

/// (OEP Diagram Studio -- Phase 8, Part 16/32.) Requires the current
/// target to actually have a real active `SimulationFault` (see
/// `SimulationContext.targetFaultId`'s own doc comment for the exact,
/// non-fabricated source). Target-shaped: "Clear Fault" has no
/// relationship to a target that isn't actually faulted -- it
/// disappears rather than showing disabled.
class RequireTargetHasActiveFault extends CommandRequirement {
  const RequireTargetHasActiveFault();

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      context.simulation.targetFaultId == null ? 'This target has no active fault.' : null;
}

/// (OEP Diagram Studio -- Phase 5, Part 19.) Requires the active
/// document tab to be in one of [modes]. Target-shaped: a command that
/// belongs to a specific mode has no relationship to the current
/// context at all in a different mode -- it disappears, it is not
/// shown disabled (matching the same "disappears entirely" rule
/// [RequireActiveSimulationSession]/[RequireSimulationMode] already
/// establish for mode-shaped gates).
class RequireStudioMode extends CommandRequirement {
  const RequireStudioMode(this.modes);
  final Set<DiagramStudioMode> modes;

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      modes.contains(context.mode) ? null : 'Not available in ${context.mode.name} mode.';
}

/// Requires a diagram document to actually be open.
class RequireDiagramOpen extends CommandRequirement {
  const RequireDiagramOpen();

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      context.diagram.diagramOpen ? null : 'No diagram is open.';
}

/// Requires one specific [EngineeringCapability] to be available.
class RequireCapability extends CommandRequirement {
  const RequireCapability(this.capability);
  final EngineeringCapability capability;

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) {
    final resolution = capabilities.resolutionFor(capability);
    if (resolution != null && resolution.isAvailable) return null;
    return resolution?.reason ?? 'This capability is not currently available.';
  }
}

/// Requires a specific backing service to be reachable (Contract spec
/// § 14 — "A command requiring an unavailable service must not be
/// executable").
class RequireService extends CommandRequirement {
  const RequireService(this.serviceId);
  final String serviceId;

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) =>
      context.services.isAvailable(serviceId) ? null : 'The required service ("$serviceId") is not available.';
}

/// Requires the effective target to be one of [kinds] -- a command
/// meaningful only for a specific kind of target (e.g. "Add Label" only
/// makes sense on a port) has no relationship to a different kind at
/// all, so it disappears entirely rather than showing disabled, same
/// "target-shaped gate" rule [RequireStudioMode] documents.
class RequireCursorTargetKind extends CommandRequirement {
  const RequireCursorTargetKind(this.kinds);
  final Set<CursorTargetKind> kinds;

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) {
    final kind = context.effectiveTarget?.kind;
    if (kind != null && kinds.contains(kind)) return null;
    return 'Not available for this kind of target.';
  }
}

/// Requires the selection to be a single item (not empty, not multiple)
/// — most object-scoped commands; distinct from [RequireSelectedTarget],
/// which also accepts a bare cursor target.
class RequireSingleSelection extends CommandRequirement {
  const RequireSingleSelection();

  @override
  String? unsatisfiedReason(EngineeringInteractionContext context, CapabilitySet capabilities) {
    if (context.effectiveTarget != null) return null;
    if (context.selection.isMultiple) return 'This command does not support multiple selection.';
    return 'No object is selected or targeted.';
  }
}
