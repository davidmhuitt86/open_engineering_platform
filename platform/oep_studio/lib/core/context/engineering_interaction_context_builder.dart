import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diagram_studio/instruments/multimeter/multimeter_controller.dart';
import '../../diagram_studio/simulation/diagram_simulation_service.dart';
import '../../knowledge/services/ai_provider_registry.dart';
import '../services/engineering_project_service.dart';
import '../services/foundation_runtime_service.dart';
import 'engineering_interaction_context.dart';

/// The Riverpod-facing half of the Context & Capability Bridge
/// (Architecture spec § 2) — the one place in this phase's new
/// architecture that is allowed to depend on `flutter_riverpod`,
/// because its entire job is reading already-real, already-shared
/// providers and normalizing them into a pure
/// [EngineeringInteractionContext]. No other file under
/// `lib/core/context/` imports Riverpod or Flutter.
///
/// This builder is deliberately **not called from anywhere in this
/// phase** — no Ribbon, Command Palette, or Diagram Studio widget
/// constructs a context through it yet (explicitly out of scope this
/// phase). It exists so the architecture's context-construction half
/// is real and testable now, ready for the future phase that actually
/// wires a presentation surface to call it.
///
/// **OEP Context & Capability Service — Phase 2 update**: [simulation]/
/// [measurement] are no longer parameters the caller must supply —
/// `DiagramSimulationService`/`MultimeterController` are now real,
/// shared providers (`diagramSimulationServiceProvider`/
/// `multimeterRuntimeServiceProvider`), so this builder reads the same
/// authoritative runtime instances Diagram Studio itself uses. Only
/// [cursorTarget] remains caller-supplied — no shared cursor-hit-testing
/// provider exists yet (still page-private/nonexistent in Diagram
/// Studio, unchanged by this phase).
class EngineeringInteractionContextBuilder {
  const EngineeringInteractionContextBuilder();

  EngineeringInteractionContext build(
    WidgetRef ref, {
    String? studioId,
    String? route,
    CursorTarget cursorTarget = const CursorTarget.none(),
    DiagramStudioMode mode = DiagramStudioMode.edit,
  }) {
    final project = ref.read(engineeringProjectServiceProvider);
    final foundation = ref.read(foundationRuntimeServiceProvider);
    final session = project.session;
    final simulationService = ref.read(diagramSimulationServiceProvider);
    final multimeter = ref.read(multimeterRuntimeServiceProvider);

    final relatedKnowledgeCount = session != null && cursorTarget.targetId != null
        ? session.graph.nodes[cursorTarget.targetId]?.evidenceLinks.length ?? 0
        : 0;

    return EngineeringInteractionContext(
      workspace: WorkspaceContext(studioId: studioId, route: route),
      document: DocumentContext(documentPath: project.document.path, isOpen: session != null),
      selection: SelectionContext.fromGraphSelection(project.selection),
      cursorTarget: cursorTarget,
      diagram: DiagramContext(
        diagramOpen: session != null,
        editable: session != null,
        validated: project.validationReport != null,
        hasValidationErrors: project.validationReport?.hasErrors ?? false,
      ),
      mode: mode,
      // Real today: `.active` reflects whether `DiagramSimulationService`
      // actually has a live session (`hasSession`) -- the one real,
      // engine-backed signal that exists. `.mode` stays `.none`: the
      // underlying `SimulationEngine`/`DiagramSimulationService` has no
      // Diagnostic-vs-Engineering distinction anywhere (confirmed by
      // Phase 2's own inspection) -- inventing one here would be
      // exactly the fabrication this phase's brief forbids. See
      // `command_requirement.dart`'s `RequireActiveSimulationSession`
      // for how fault-injection commands were adjusted to gate on this
      // real signal instead of a mode this codebase does not have.
      simulation: SimulationContext(
        active: simulationService?.hasSession ?? false,
        // Real today: matches the target against the same
        // `session.activeFaults.active` list `FaultInjectionPanel`
        // already reads, by real target id -- never a fabricated
        // fault-presence flag.
        targetFaultId: _activeFaultIdFor(simulationService, cursorTarget.targetId),
        // Real today (Phase 9): sourced directly from the same
        // `SimulationSession.activeOperatingStateId`/
        // `.availableOperatingStates` a Simulate-mode control reads --
        // never fabricated, empty/null whenever no session or no
        // domain-supplied operating states exist.
        activeOperatingStateId: simulationService?.currentSession?.activeOperatingStateId,
        availableOperatingStateIds:
            simulationService?.currentSession?.availableOperatingStates.map((s) => s.id).toList() ?? const [],
      ),
      // Real today: `dmmAvailable` reflects whether the shared
      // `MultimeterController` actually exists (i.e. the engine has
      // bootstrapped) -- probe placement reflects its real `probeA`/`probeB`
      // fields.
      measurement: MeasurementContext(
        dmmAvailable: multimeter != null,
        probeAPlaced: multimeter?.probeA != null,
        probeBPlaced: multimeter?.probeB != null,
      ),
      knowledge: KnowledgeContext(
        knowledgeAvailable: foundation.knowledgeSession != null,
        relatedKnowledgeCount: relatedKnowledgeCount,
      ),
      ai: AiContext(
        // Real today: an AI provider is "available" only if the
        // currently-configured id actually resolves in the shared
        // registry -- not merely because a registry object exists.
        aiAvailable: _providerResolves(foundation.currentAiProviderId),
        contextualAnalysisAvailable: _providerResolves(foundation.currentAiProviderId),
        currentProviderId: foundation.currentAiProviderId,
      ),
      services: ServiceAvailability(
        availableServiceIds: {
          ServiceAvailability.foundation,
          if (project.engine != null) ServiceAvailability.engineeringEngine,
          if (foundation.knowledgeSession != null) ServiceAvailability.knowledge,
          if (_providerResolves(foundation.currentAiProviderId)) ServiceAvailability.ai,
          // Real today (Phase 2): both services now have a genuine
          // shared provider to confirm reachability against, replacing
          // Phase 1's documented "never added, no shared provider
          // exists" gap.
          if (simulationService != null) ServiceAvailability.simulation,
          if (multimeter != null) ServiceAvailability.measurement,
        },
      ),
      graph: session?.graph,
      layout: session?.layout,
      engine: project.engine,
      multimeterController: multimeter,
      simulationService: simulationService,
    );
  }

  /// The real check -- does this id actually resolve in the same
  /// shared registry `contextual_command_definitions.dart`'s AI
  /// commands call through -- not a guess at which ids are "probably"
  /// valid.
  bool _providerResolves(String providerId) => AiProviderRegistry.defaultRegistry.providerFor(providerId) != null;

  String? _activeFaultIdFor(DiagramSimulationService? simulationService, String? targetId) {
    if (targetId == null) return null;
    final session = simulationService?.currentSession;
    if (session == null) return null;
    for (final fault in session.activeFaults.active) {
      if (fault.targetId == targetId) return fault.id;
    }
    return null;
  }
}
