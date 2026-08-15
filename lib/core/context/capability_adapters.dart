import 'engineering_capability.dart';
import 'engineering_interaction_context.dart';

/// One source of capability facts (Architecture spec § 2's "Context &
/// Capability Bridge"). Each adapter inspects one already-normalized
/// [EngineeringInteractionContext] and reports the capabilities *it*
/// is authoritative for — never another adapter's. Pure Dart, no
/// Flutter/Riverpod, no network calls (Contract spec § 19 —
/// "Performance": resolution must stay cheap enough to run on every
/// right-click).
abstract class CapabilityAdapter {
  const CapabilityAdapter();

  String get sourceName;

  /// Adds this adapter's own resolved capabilities into [results].
  /// Adapters must not overwrite another adapter's entries — the
  /// bridge runs every registered adapter and merges disjoint capability
  /// sets, per Architecture spec § 12 ("Extensibility": "future
  /// services [may] contribute capabilities... without modifying the
  /// core resolver").
  void resolve(EngineeringInteractionContext context, Map<EngineeringCapability, ResolvedCapability> results);

  ResolvedCapability available(EngineeringCapability capability) =>
      ResolvedCapability(capability: capability, availability: CapabilityAvailability.available, source: sourceName);

  ResolvedCapability unavailable(EngineeringCapability capability, {String? reason}) => ResolvedCapability(
        capability: capability,
        availability: CapabilityAvailability.unavailable,
        source: sourceName,
        reason: reason,
      );
}

/// General object/property/relationship inspection and annotation
/// (spec categories: General). Available whenever there is an
/// [EngineeringInteractionContext.effectiveTarget] — inspecting an
/// already-selected/cursor-targeted object is real, existing
/// functionality (the shared `PropertyInspectorPanel`), not something
/// this phase invents.
class InspectionCapabilityAdapter extends CapabilityAdapter {
  const InspectionCapabilityAdapter();

  @override
  String get sourceName => 'InspectionCapabilityAdapter';

  @override
  void resolve(EngineeringInteractionContext context, Map<EngineeringCapability, ResolvedCapability> results) {
    final hasTarget = context.effectiveTarget != null;
    for (final capability in const [
      EngineeringCapability.objectInspection,
      EngineeringCapability.propertyInspection,
      EngineeringCapability.relationshipInspection,
    ]) {
      results[capability] =
          hasTarget ? available(capability) : unavailable(capability, reason: 'No object is selected or targeted.');
    }
    results[EngineeringCapability.annotation] =
        context.diagram.diagramOpen && context.diagram.editable
            ? available(EngineeringCapability.annotation)
            : unavailable(EngineeringCapability.annotation, reason: 'No editable diagram is open.');
  }
}

/// Measurement/DMM capabilities (spec category: Measurement).
/// **Documented gap** (see `MeasurementContext`'s own doc comment):
/// `context.measurement.dmmAvailable` is `false` in every adapter this
/// phase ships, since no shared provider exposes the page-private
/// `MultimeterController`/`DiagramSimulationService` yet — this adapter
/// is the correct, real logic for the day that state becomes reachable;
/// it does not fabricate availability today.
class MeasurementCapabilityAdapter extends CapabilityAdapter {
  const MeasurementCapabilityAdapter();

  @override
  String get sourceName => 'MeasurementCapabilityAdapter';

  @override
  void resolve(EngineeringInteractionContext context, Map<EngineeringCapability, ResolvedCapability> results) {
    final hasTarget = context.effectiveTarget != null;
    final serviceUp = context.services.isAvailable(ServiceAvailability.measurement);
    final dmmReady = context.measurement.dmmAvailable && serviceUp;

    void set(EngineeringCapability capability, {String? unavailableReason}) {
      if (dmmReady && hasTarget) {
        results[capability] = available(capability);
      } else {
        results[capability] = unavailable(
          capability,
          reason: unavailableReason ??
              (!serviceUp
                  ? 'The Measurement service is not available.'
                  : !context.measurement.dmmAvailable
                      ? 'No Digital Multimeter is available in this workspace.'
                      : 'No object is selected or targeted.'),
        );
      }
    }

    set(EngineeringCapability.voltageMeasurement);
    set(EngineeringCapability.voltageDropMeasurement);
    set(EngineeringCapability.resistanceMeasurement);
    set(EngineeringCapability.continuityMeasurement);
    set(EngineeringCapability.currentMeasurement);

    results[EngineeringCapability.dmmProbePlacement] = dmmReady
        ? available(EngineeringCapability.dmmProbePlacement)
        : unavailable(EngineeringCapability.dmmProbePlacement, reason: 'No Digital Multimeter is available in this workspace.');
  }
}

/// Diagnostic fault-injection capabilities (spec category: Diagnostic).
/// **Documented gap**: identical reasoning to [MeasurementCapabilityAdapter]
/// — `context.simulation.mode` can currently only be `.none` from any
/// real adapter this phase ships (no shared simulation-state provider
/// exists yet). Also documented in Contract spec § 11/Implementation
/// Plan § 11: this codebase has no per-object "does this target support
/// an open-circuit fault" metadata anywhere, so once diagnostic
/// simulation genuinely is reachable, this adapter treats every
/// targeted object uniformly rather than inventing a fault-support
/// table the Engine does not provide.
class DiagnosticCapabilityAdapter extends CapabilityAdapter {
  const DiagnosticCapabilityAdapter();

  @override
  String get sourceName => 'DiagnosticCapabilityAdapter';

  @override
  void resolve(EngineeringInteractionContext context, Map<EngineeringCapability, ResolvedCapability> results) {
    final hasTarget = context.effectiveTarget != null;
    // OEP Context & Capability Service -- Phase 2: `DiagramSimulationService`
    // (now a real, shared provider -- `diagram_simulation_service.dart`)
    // has no Diagnostic-vs-Engineering mode concept at all; `hasSession`
    // is the only real, engine-backed simulation-active signal. Gating
    // fault capabilities on `context.simulation.mode == .diagnostic`
    // (Phase 1's design) would make every fault command permanently
    // unavailable in real usage, since no real adapter can ever
    // populate that mode -- so this adapter now gates on `.active`
    // alone, the actual capability the engine provides. `diagnosticSimulation`
    // itself is left genuinely mode-gated below, since it specifically
    // represents the mode distinction that does not exist -- it stays
    // honestly unavailable from real context, not repurposed to mean
    // something it doesn't.
    final sessionActive = context.simulation.active;
    final diagnosticModeActive = context.simulation.active && context.simulation.mode == SimulationMode.diagnostic;
    final serviceUp = context.services.isAvailable(ServiceAvailability.simulation);

    results[EngineeringCapability.diagnosticSimulation] = diagnosticModeActive
        ? available(EngineeringCapability.diagnosticSimulation)
        : unavailable(
            EngineeringCapability.diagnosticSimulation,
            reason: 'The underlying Simulation Engine has no Diagnostic Simulation mode to distinguish yet.',
          );

    results[EngineeringCapability.componentStateControl] = sessionActive && serviceUp && hasTarget
        ? available(EngineeringCapability.componentStateControl)
        : unavailable(EngineeringCapability.componentStateControl, reason: 'No simulation session is active.');

    final faultReady = sessionActive && serviceUp && hasTarget;

    // Part 8 -- Fault Capability Model: `SimulationFaultType`
    // (`oep_engine/lib/core/simulation/models/simulation_fault.dart`)
    // has NO per-object-type support metadata (confirmed, matches
    // Phase 1's own finding) and its real fault vocabulary
    // (`openCircuit`, `shortCircuit`, `disconnectedConnector`,
    // `brokenWire`, `incorrectWire`, `missingGround`, `missingPower`,
    // `relayFailure`, `fuseFailure`, `connectorFailure`) does not map
    // 1:1 onto the five fault capabilities Phase 1 introduced from the
    // governing spec's own vocabulary. Only `openCircuitFault` has an
    // exact, unambiguous real counterpart (`SimulationFaultType.openCircuit`).
    // `shortCircuit` exists but does not distinguish "to ground" vs.
    // "to power" -- claiming `shortToGroundFault`/`shortToPowerFault`
    // are each precisely supported would overstate what the engine
    // actually models. `highResistanceFault`/`intermittentFault` have
    // no real counterpart at all. Rather than invent a mapping, only
    // `openCircuitFault` is ever resolved as available; the other four
    // stay permanently unavailable with the specific reason why,
    // regardless of session/target state.
    results[EngineeringCapability.openCircuitFault] = faultReady
        ? available(EngineeringCapability.openCircuitFault)
        : unavailable(
            EngineeringCapability.openCircuitFault,
            reason: !sessionActive
                ? 'No simulation session is active.'
                : !hasTarget
                    ? 'No object is selected or targeted.'
                    : 'The Simulation service is not available.',
          );

    results[EngineeringCapability.shortToGroundFault] = unavailable(
      EngineeringCapability.shortToGroundFault,
      reason: "The Simulation Engine's fault model has a generic Short Circuit fault, but does not "
          'distinguish "to ground" from "to power" -- not precisely supported.',
    );
    results[EngineeringCapability.shortToPowerFault] = unavailable(
      EngineeringCapability.shortToPowerFault,
      reason: "The Simulation Engine's fault model has a generic Short Circuit fault, but does not "
          'distinguish "to ground" from "to power" -- not precisely supported.',
    );
    results[EngineeringCapability.highResistanceFault] = unavailable(
      EngineeringCapability.highResistanceFault,
      reason: 'The Simulation Engine has no High Resistance fault type.',
    );
    results[EngineeringCapability.intermittentFault] = unavailable(
      EngineeringCapability.intermittentFault,
      reason: 'The Simulation Engine has no Intermittent fault type.',
    );
  }
}

/// Engineering-simulation capabilities (spec category: Engineering
/// simulation) — same documented-gap pattern as Diagnostic; `.engineering`
/// mode is likewise never produced by a real adapter today.
class EngineeringSimulationCapabilityAdapter extends CapabilityAdapter {
  const EngineeringSimulationCapabilityAdapter();

  @override
  String get sourceName => 'EngineeringSimulationCapabilityAdapter';

  @override
  void resolve(EngineeringInteractionContext context, Map<EngineeringCapability, ResolvedCapability> results) {
    final engineeringActive = context.simulation.active && context.simulation.mode == SimulationMode.engineering;
    final serviceUp = context.services.isAvailable(ServiceAvailability.simulation);
    final ready = engineeringActive && serviceUp;

    for (final capability in const [
      EngineeringCapability.engineeringSimulation,
      EngineeringCapability.simulationControl,
      EngineeringCapability.signalMeasurement,
      EngineeringCapability.eventInspection,
    ]) {
      results[capability] =
          ready ? available(capability) : unavailable(capability, reason: 'Engineering Simulation is not active.');
    }
  }
}

/// Knowledge capabilities — real today, sourced from
/// [KnowledgeContext] (`FoundationServiceState.knowledgeSession`/`.selectedObject`).
class KnowledgeCapabilityAdapter extends CapabilityAdapter {
  const KnowledgeCapabilityAdapter();

  @override
  String get sourceName => 'KnowledgeCapabilityAdapter';

  @override
  void resolve(EngineeringInteractionContext context, Map<EngineeringCapability, ResolvedCapability> results) {
    final serviceUp = context.services.isAvailable(ServiceAvailability.knowledge);
    final ready = context.knowledge.knowledgeAvailable && serviceUp;

    results[EngineeringCapability.knowledgeLookup] =
        ready ? available(EngineeringCapability.knowledgeLookup) : unavailable(
            EngineeringCapability.knowledgeLookup,
            reason: serviceUp ? 'No Knowledge Curation Session is active.' : 'The Knowledge service is not available.');

    final hasEvidence = context.knowledge.relatedKnowledgeCount > 0;
    results[EngineeringCapability.knowledgeSourceAccess] = ready && hasEvidence
        ? available(EngineeringCapability.knowledgeSourceAccess)
        : unavailable(EngineeringCapability.knowledgeSourceAccess, reason: 'No related Knowledge evidence exists.');

    // Chain of Custody is a Reference Vault/Acquisition concept, not
    // something `KnowledgeContext` carries — always unavailable from
    // this adapter until a real Acquisition-side context field exists
    // (documented gap, not a fabricated value).
    results[EngineeringCapability.chainOfCustodyAccess] = unavailable(
      EngineeringCapability.chainOfCustodyAccess,
      reason: 'Chain of Custody is only available for Reference Vault artifacts, not tracked in this context yet.',
    );
  }
}

/// AI capabilities — real today, sourced from [AiContext]
/// (`AiProviderRegistry.defaultRegistry`, per this phase's own
/// investigation of the existing, already-shipped AI provider
/// pipeline).
class AiCapabilityAdapter extends CapabilityAdapter {
  const AiCapabilityAdapter();

  @override
  String get sourceName => 'AiCapabilityAdapter';

  @override
  void resolve(EngineeringInteractionContext context, Map<EngineeringCapability, ResolvedCapability> results) {
    final serviceUp = context.services.isAvailable(ServiceAvailability.ai);
    final ready = context.ai.aiAvailable && serviceUp;

    results[EngineeringCapability.aiAnalysis] =
        ready ? available(EngineeringCapability.aiAnalysis) : unavailable(EngineeringCapability.aiAnalysis, reason: 'No AI provider is configured.');

    final contextualReady = ready && context.ai.contextualAnalysisAvailable && context.effectiveTarget != null;
    results[EngineeringCapability.contextualAiAnalysis] = contextualReady
        ? available(EngineeringCapability.contextualAiAnalysis)
        : unavailable(
            EngineeringCapability.contextualAiAnalysis,
            reason: !ready ? 'No AI provider is configured.' : 'No object is selected or targeted.',
          );
  }
}

/// The Context & Capability Bridge (Architecture spec § 2): runs every
/// registered [CapabilityAdapter] against one context and merges their
/// disjoint results into a [CapabilitySet]. This is the only place new
/// capability sources are wired in — adding a capability source means
/// adding an adapter here, never touching the resolver
/// (`contextual_command_resolver.dart`) itself (Implementation Plan §
/// 18 — "Architectural Success Condition").
class CapabilityBridge {
  const CapabilityBridge(this.adapters);

  final List<CapabilityAdapter> adapters;

  static const CapabilityBridge defaultBridge = CapabilityBridge([
    InspectionCapabilityAdapter(),
    MeasurementCapabilityAdapter(),
    DiagnosticCapabilityAdapter(),
    EngineeringSimulationCapabilityAdapter(),
    KnowledgeCapabilityAdapter(),
    AiCapabilityAdapter(),
  ]);

  CapabilitySet resolve(EngineeringInteractionContext context) {
    final results = <EngineeringCapability, ResolvedCapability>{};
    for (final adapter in adapters) {
      adapter.resolve(context, results);
    }
    return CapabilitySet(results);
  }
}
