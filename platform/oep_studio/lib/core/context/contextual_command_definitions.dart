import 'package:engineering_engine/engineering_engine.dart';

import '../../diagram_studio/ai/diagram_ai_service.dart';
import '../../knowledge/models/ai_request.dart';
import '../../knowledge/services/ai_provider_registry.dart';
import 'command_requirement.dart';
import 'contextual_command_descriptor.dart';
import 'engineering_capability.dart';
import 'engineering_interaction_context.dart';

/// The first representative command set migrated onto the Contextual
/// Command architecture (Implementation Plan § 7). Each command
/// declares real requirements; `execute` is a real, callable function
/// wherever this build has a genuine non-UI execution path for it, and
/// deliberately `null` (never a fake stand-in) where the only real
/// execution path requires a service this build cannot reach from a
/// pure-Dart layer yet (Diagram Studio's page-private
/// `MultimeterController`/`DiagramSimulationService` — see each
/// command's own comment for exactly which).
///
/// This list is intentionally NOT wired into any Ribbon, Command
/// Palette, or Diagram Studio right-click menu in this phase — per
/// this phase's own explicit scope, it exists to be resolved and
/// executed by unit tests, proving the architecture without any UI
/// change.
final List<ContextualCommandDescriptor> initialContextualCommands = [
  ContextualCommandDescriptor(
    id: 'diagram.inspect.object',
    label: 'Inspect Object',
    description: 'Shows the targeted object in the Property Inspector.',
    group: CommandGroup.inspect,
    requirements: const [RequireSelectedTarget(), RequireCapability(EngineeringCapability.objectInspection)],
    // No executor: "inspecting" means driving the shared, Flutter-side
    // `PropertyInspectorPanel` -- there is no non-UI side effect for
    // this command to perform. Real execution wiring belongs to the
    // future phase that connects this resolver to a presentation
    // surface, not to this pure-Dart service.
  ),
  ContextualCommandDescriptor(
    id: 'diagram.inspect.viewProperties',
    label: 'View Properties',
    description: "Opens the targeted object's full property sheet.",
    group: CommandGroup.inspect,
    priority: 1,
    requirements: const [RequireSelectedTarget(), RequireCapability(EngineeringCapability.propertyInspection)],
  ),
  ContextualCommandDescriptor(
    id: 'diagram.inspect.showConnections',
    label: 'Show Connected Nodes',
    description: 'Lists every node directly connected to the targeted node.',
    group: CommandGroup.inspect,
    priority: 2,
    requirements: const [RequireSelectedTarget(), RequireCapability(EngineeringCapability.relationshipInspection)],
    execute: _showConnectedNodes,
  ),
  ContextualCommandDescriptor(
    id: 'diagram.probe.placePositive',
    label: 'Place DMM Probe +',
    description: 'Places the Digital Multimeter\'s positive probe on the targeted point.',
    group: CommandGroup.test,
    requirements: const [
      RequireSelectedTarget(),
      RequireCapability(EngineeringCapability.dmmProbePlacement),
      RequireService(ServiceAvailability.measurement),
    ],
    execute: (context) => _placeProbe(context, positive: true),
  ),
  ContextualCommandDescriptor(
    id: 'diagram.probe.placeNegative',
    label: 'Place DMM Probe -',
    description: 'Places the Digital Multimeter\'s negative probe on the targeted point.',
    group: CommandGroup.test,
    priority: 1,
    requirements: const [
      RequireSelectedTarget(),
      RequireCapability(EngineeringCapability.dmmProbePlacement),
      RequireService(ServiceAvailability.measurement),
    ],
    execute: (context) => _placeProbe(context, positive: false),
  ),
  ContextualCommandDescriptor(
    id: 'diagram.measure.voltage',
    label: 'Voltage',
    description: 'Measures voltage across the placed probes.',
    group: CommandGroup.test,
    priority: 2,
    submenuLabel: 'Measure',
    requirements: const [
      RequireBothProbesPlaced(),
      RequireCapability(EngineeringCapability.voltageMeasurement),
      RequireService(ServiceAvailability.measurement),
    ],
    execute: (context) => _measure(context, MeasurementType.voltageDc),
  ),
  ContextualCommandDescriptor(
    id: 'diagram.measure.voltageDrop',
    label: 'Voltage Drop',
    description: 'Measures the voltage difference across the placed probes.',
    group: CommandGroup.test,
    priority: 2,
    submenuLabel: 'Measure',
    requirements: const [
      RequireBothProbesPlaced(),
      RequireCapability(EngineeringCapability.voltageDropMeasurement),
      RequireService(ServiceAvailability.measurement),
    ],
    // Same `MeasurementType.voltageDc` call as "Voltage" above --
    // documented gap: the Simulation Engine's `MeasurementType` enum
    // has no separate voltage-drop concept. Measuring voltage between
    // two probes *is* the voltage drop between them; there is no
    // second, distinct engine operation to call.
    execute: (context) => _measure(context, MeasurementType.voltageDc),
  ),
  ContextualCommandDescriptor(
    id: 'diagram.measure.resistance',
    label: 'Resistance',
    description: 'Measures resistance across the placed probes.',
    group: CommandGroup.test,
    priority: 2,
    submenuLabel: 'Measure',
    requirements: const [
      RequireBothProbesPlaced(),
      RequireCapability(EngineeringCapability.resistanceMeasurement),
      RequireService(ServiceAvailability.measurement),
    ],
    execute: (context) => _measure(context, MeasurementType.resistance),
  ),
  ContextualCommandDescriptor(
    id: 'diagram.measure.continuity',
    label: 'Continuity',
    description: 'Checks continuity across the placed probes.',
    group: CommandGroup.test,
    priority: 2,
    submenuLabel: 'Measure',
    requirements: const [
      RequireBothProbesPlaced(),
      RequireCapability(EngineeringCapability.continuityMeasurement),
      RequireService(ServiceAvailability.measurement),
    ],
    execute: (context) => _measure(context, MeasurementType.continuity),
  ),
  ContextualCommandDescriptor(
    id: 'diagram.fault.openCircuit',
    label: 'Open Circuit',
    description: 'Injects an open-circuit fault at the targeted element.',
    group: CommandGroup.diagnose,
    submenuLabel: 'Inject Fault',
    // (OEP Diagram Studio -- Phase 7, Part 4/20 -- explicit correction
    // of Phase 6's own conservative choice.) Fault injection is a
    // runtime diagnostic operation: "actively run, manipulate, and
    // diagnose the engineering model" is Simulate mode's own
    // definition, not View's ("inspect and measure") or Edit's
    // ("construct, modify, organize, save"). Now hidden in both View
    // and Edit, applicable only in Simulate.
    requirements: const [
      RequireSelectedTarget(),
      RequireActiveSimulationSession(),
      RequireCapability(EngineeringCapability.openCircuitFault),
      RequireService(ServiceAvailability.simulation),
      RequireStudioMode({DiagramStudioMode.simulate}),
    ],
    execute: _injectOpenCircuitFault,
  ),
  ContextualCommandDescriptor(
    id: 'diagram.fault.clear',
    label: 'Clear Fault',
    description: 'Removes the active fault from the targeted element.',
    group: CommandGroup.diagnose,
    submenuLabel: 'Inject Fault',
    priority: -1,
    // (OEP Diagram Studio -- Phase 8, Part 16.) The real, existing
    // `SimulationSession.clearFault(faultId)` (via
    // `DiagramSimulationService.clearFault`) -- target-shaped on
    // `RequireTargetHasActiveFault`: a target with no active fault has
    // no relationship to "clear the fault" at all, it disappears
    // rather than showing disabled.
    requirements: const [
      RequireSelectedTarget(),
      RequireActiveSimulationSession(),
      RequireTargetHasActiveFault(),
      RequireService(ServiceAvailability.simulation),
      RequireStudioMode({DiagramStudioMode.simulate}),
    ],
    execute: _clearFault,
  ),
  ContextualCommandDescriptor(
    id: 'diagram.fault.shortToGround',
    label: 'Short to Ground',
    description: 'Injects a short-to-ground fault at the targeted element.',
    group: CommandGroup.diagnose,
    priority: 1,
    submenuLabel: 'Inject Fault',
    requirements: const [
      RequireSelectedTarget(),
      RequireActiveSimulationSession(),
      RequireCapability(EngineeringCapability.shortToGroundFault),
      RequireService(ServiceAvailability.simulation),
    ],
    // No executor: `shortToGroundFault` never resolves as available
    // (see `DiagnosticCapabilityAdapter`'s own doc comment) -- the
    // Simulation Engine's fault model has no ground-specific short
    // fault to call.
  ),
  ContextualCommandDescriptor(
    id: 'diagram.fault.shortToPower',
    label: 'Short to Power',
    description: 'Injects a short-to-power fault at the targeted element.',
    group: CommandGroup.diagnose,
    priority: 2,
    submenuLabel: 'Inject Fault',
    requirements: const [
      RequireSelectedTarget(),
      RequireActiveSimulationSession(),
      RequireCapability(EngineeringCapability.shortToPowerFault),
      RequireService(ServiceAvailability.simulation),
    ],
    // No executor: same reason as Short to Ground above.
  ),
  ContextualCommandDescriptor(
    id: 'diagram.knowledge.view',
    label: 'View Engineering Knowledge',
    description: 'Shows related Knowledge for the current context.',
    group: CommandGroup.knowledge,
    requirements: const [RequireCapability(EngineeringCapability.knowledgeLookup)],
    execute: _viewKnowledge,
  ),
  ContextualCommandDescriptor(
    id: 'diagram.ai.askAboutSelection',
    label: 'Ask AI About Selection',
    description: 'Sends the targeted object and current context to the configured AI provider.',
    group: CommandGroup.ai,
    requirements: const [
      RequireSelectedTarget(),
      RequireCapability(EngineeringCapability.contextualAiAnalysis),
      RequireService(ServiceAvailability.ai),
    ],
    execute: _askAiAboutSelection,
  ),
  ContextualCommandDescriptor(
    id: 'diagram.annotate.add',
    label: 'Add Annotation',
    description: 'Adds an annotation at the targeted location.',
    group: CommandGroup.annotate,
    // (OEP Diagram Studio -- Phase 5, Part 19.) The first, minimal
    // proof that `mode` actually flows through the resolver: creating
    // an annotation is a Build/Modify action (Part 6's own list), so it
    // has no relationship to View or Simulate mode's context at all --
    // matching the same "disappears entirely" rule already established
    // for RequireActiveSimulationSession. This is deliberately the
    // ONLY command gated on mode this phase (Part 26: no complete
    // per-mode command matrix yet).
    requirements: const [
      RequireDiagramOpen(),
      RequireCapability(EngineeringCapability.annotation),
      RequireStudioMode({DiagramStudioMode.edit}),
    ],
    // Real now (`context.engine` -- OEP Context & Capability Service,
    // this phase): the earlier "No executor yet" gap this comment used
    // to document is closed, now that a live `EngineeringEngine`
    // reference reaches this pure-Dart layer.
    execute: _addAnnotationAtTarget,
  ),
  // (User-requested: "when I click on a pin or port while in edit
  // mode. it should give me the option to Add a label to it.") Reuses
  // the exact same `CreateAnnotationCommand`/`AnnotationType.portLabel`
  // `AnnotationWidget` already renders without a bordered box --
  // no second labeling mechanism.
  ContextualCommandDescriptor(
    id: 'diagram.port.addLabel',
    label: 'Add Label',
    description: "Adds a small text label at the targeted pin/port, prefilled with its real name where known.",
    group: CommandGroup.annotate,
    requirements: const [
      RequireDiagramOpen(),
      RequireCursorTargetKind({CursorTargetKind.port}),
      RequireCapability(EngineeringCapability.annotation),
      RequireStudioMode({DiagramStudioMode.edit}),
    ],
    execute: _addPortLabel,
  ),
  // (User-requested full parity with the legacy sim's own node/wire
  // "Edit" flow -- its context menu always offers a real Delete, this
  // one never did.)
  ContextualCommandDescriptor(
    id: 'diagram.object.delete',
    label: 'Delete',
    description: 'Deletes the targeted node, wire, or annotation.',
    group: CommandGroup.edit,
    requirements: const [
      RequireDiagramOpen(),
      RequireCursorTargetKind({CursorTargetKind.node, CursorTargetKind.relationship, CursorTargetKind.annotation}),
      RequireStudioMode({DiagramStudioMode.edit}),
    ],
    execute: _deleteTarget,
  ),
];

/// Real execution for "Add Annotation" and "Add Label" -- both create a
/// real `DiagramAnnotation` via the shared `EngineeringEngine.editing`
/// session (`context.engine`), the same command
/// `diagram_studio_page.dart`'s own toolbar-driven `_addAnnotation()`
/// already uses. "Add Label" additionally anchors the annotation to the
/// targeted port (`anchorPortId`/`anchorNodeId`) and prefills its text
/// with the port's own real name when the owning node's graph-level
/// `Port` data has one -- falling back to the raw port id (never a
/// fabricated name) for symbol-backed nodes whose port geometry lives
/// only on the Symbol, not mirrored onto the graph node (a disclosed,
/// pre-existing gap; see `fallback_port_layout.dart`'s own doc comment).
Future<ContextualCommandResult> _addAnnotationAtTarget(EngineeringInteractionContext context) => _createAnnotation(
      context,
      type: AnnotationType.freeText,
      textFor: (_) => 'New annotation',
    );

Future<ContextualCommandResult> _addPortLabel(EngineeringInteractionContext context) => _createAnnotation(
      context,
      type: AnnotationType.portLabel,
      textFor: (target) {
        final ports = context.graph?.nodes[target.ownerNodeId]?.ports ?? const [];
        for (final port in ports) {
          if (port.id == target.id) return port.name;
        }
        return target.id;
      },
    );

Future<ContextualCommandResult> _createAnnotation(
  EngineeringInteractionContext context, {
  required AnnotationType type,
  required String Function(EngineeringTargetRef target) textFor,
}) async {
  final engine = context.engine;
  if (engine == null) {
    return ContextualCommandResult.unavailable('The Engineering Engine is not available in this workspace.');
  }
  final target = context.effectiveTarget;
  // A port label specifically needs a real owning node to anchor to
  // and to position itself near -- a bare `Add Annotation` doesn't.
  final anchorNodeId = type == AnnotationType.portLabel ? target?.ownerNodeId : null;
  if (type == AnnotationType.portLabel && (target == null || anchorNodeId == null)) {
    return ContextualCommandResult.unavailable('This port has no known owning node to anchor the label to.');
  }
  final basePosition = anchorNodeId != null
      ? context.layout?.positionOf(anchorNodeId)
      : null;
  final position = basePosition?.translate(0, -14) ?? const Point2D(40, 40);

  final id = 'annotation_${DateTime.now().microsecondsSinceEpoch}';
  final annotation = DiagramAnnotation(
    id: id,
    type: type,
    text: target == null ? 'New annotation' : textFor(target),
    position: position,
    anchorNodeId: anchorNodeId,
    anchorPortId: type == AnnotationType.portLabel ? target?.id : null,
  );
  engine.editing.execute(CreateAnnotationCommand(annotation));
  return ContextualCommandResult(
    success: true,
    message: type == AnnotationType.portLabel ? 'Label added.' : 'Annotation added.',
    affectedObjectIds: [id],
  );
}

/// Real execution for "Delete" (user-requested full parity with the
/// legacy sim's own node/wire context menu, which always offers a real
/// Delete this build's menu previously never did). Picks the real
/// delete command by the targeted kind -- the exact same commands
/// `diagram_studio_page.dart`'s own toolbar/keyboard-shortcut
/// `_deleteSelection()` path uses for a node/wire, plus the equivalent
/// for an annotation.
Future<ContextualCommandResult> _deleteTarget(EngineeringInteractionContext context) async {
  final engine = context.engine;
  final target = context.effectiveTarget;
  if (engine == null || target == null) {
    return ContextualCommandResult.unavailable('Nothing is targeted, or the Engineering Engine is not available.');
  }
  switch (target.kind) {
    case CursorTargetKind.node:
      engine.editing.execute(DeleteNodeCommand(target.id));
    case CursorTargetKind.relationship:
      engine.editing.execute(DeleteRelationshipCommand(target.id));
    case CursorTargetKind.annotation:
      engine.editing.execute(DeleteAnnotationCommand(target.id));
    case CursorTargetKind.port:
    case CursorTargetKind.testPoint:
    case CursorTargetKind.none:
      return ContextualCommandResult.unavailable('This target kind cannot be deleted directly.');
  }
  return ContextualCommandResult(success: true, message: 'Deleted.', affectedObjectIds: [target.id]);
}

Future<ContextualCommandResult> _showConnectedNodes(EngineeringInteractionContext context) async {
  final target = context.effectiveTarget;
  final graph = context.graph;
  if (target == null || graph == null || target.kind != CursorTargetKind.node) {
    return ContextualCommandResult.unavailable('No node is targeted.');
  }

  final connectedIds = <String>{};
  for (final relationship in graph.relationships.values) {
    if (relationship.sourceNode == target.id) connectedIds.add(relationship.targetNode);
    if (relationship.targetNode == target.id) connectedIds.add(relationship.sourceNode);
  }

  return ContextualCommandResult(
    success: true,
    message: connectedIds.isEmpty
        ? 'No connected nodes.'
        : '${connectedIds.length} connected node(s): ${connectedIds.join(', ')}',
    affectedObjectIds: connectedIds.toList(),
  );
}

/// Real execution for "Place DMM Probe +/-" (OEP Context & Capability
/// Service -- Phase 2, Part 7): builds a real `ProbePoint` from the
/// current [EngineeringInteractionContext.effectiveTarget] and sets it
/// on the shared, authoritative `MultimeterController`
/// (`context.multimeterController`, the same instance
/// `multimeterRuntimeServiceProvider` exposes -- not a second one).
///
/// Supported for node and port targets: `ProbePoint` needs
/// `(nodeId, portId?)`. Node targets supply `nodeId` directly.
/// (OEP Diagram Studio -- Phase 4, Part 11): port targets now carry a
/// real `ownerNodeId` (`CursorTarget.ownerNodeId`, sourced from
/// `PortReference.nodeId` -- see `_handlePortSecondaryTap`), so a port's
/// `ProbePoint` can be built with both `nodeId` (the real owning node)
/// and `portId` (the real port) -- resolving the limitation Phase 2
/// documented, with no change to `ProbePoint`, `MultimeterController`,
/// or the DMM runtime itself. Relationship/annotation targets still
/// have no owning-node concept and remain unsupported.
Future<ContextualCommandResult> _placeProbe(EngineeringInteractionContext context, {required bool positive}) async {
  final target = context.effectiveTarget;
  final multimeter = context.multimeterController;
  if (target == null || multimeter == null) {
    return ContextualCommandResult.unavailable('No Digital Multimeter is available in this workspace.');
  }

  final ProbePoint probePoint;
  if (target.kind == CursorTargetKind.node) {
    probePoint = ProbePoint(nodeId: target.id);
  } else if (target.kind == CursorTargetKind.port && target.ownerNodeId != null) {
    probePoint = ProbePoint(nodeId: target.ownerNodeId!, portId: target.id);
  } else {
    return ContextualCommandResult.unavailable(
      'Probe placement is only supported for nodes and ports with a known owning node today -- '
      '${target.kind.name} targets have no owning-node id recorded in this context yet.',
    );
  }

  if (positive) {
    multimeter.setProbeA(probePoint);
  } else {
    multimeter.setProbeB(probePoint);
  }
  return ContextualCommandResult(
    success: true,
    message: 'Probe ${positive ? '+' : '-'} placed on ${target.id}.',
    affectedObjectIds: [target.id],
    followUpAction: positive ? 'diagram.probe.placeNegative' : 'diagram.measure.voltage',
  );
}

/// Real execution for the Measure commands: calls the shared
/// `MultimeterController.measure()`, which itself calls
/// `DiagramSimulationService.measure()` -- the exact same real,
/// engine-backed call path `DigitalMultimeterPanel`'s own "Measure"
/// button already uses, just reached from this pure-Dart layer via the
/// same live controller instance.
Future<ContextualCommandResult> _measure(EngineeringInteractionContext context, MeasurementType type) async {
  final multimeter = context.multimeterController;
  if (multimeter == null) {
    return ContextualCommandResult.unavailable('No Digital Multimeter is available in this workspace.');
  }
  if (multimeter.probeA == null || multimeter.probeB == null) {
    return ContextualCommandResult.unavailable('Place both DMM probes before measuring.');
  }

  multimeter.setType(type);
  await multimeter.measure();

  final result = multimeter.latestResult;
  if (result == null) {
    return ContextualCommandResult(
      success: false,
      message: multimeter.lastError ?? 'The measurement did not produce a result.',
      errorCode: 'measurement_failed',
    );
  }
  return ContextualCommandResult(
    success: true,
    message: '${type.name}: ${result.measuredValue ?? 'unreachable'} ${result.unit}'.trim(),
  );
}

/// Real execution for "Inject Open Circuit" -- the only fault capability
/// that maps 1:1 onto a real `SimulationFaultType` (see
/// `DiagnosticCapabilityAdapter`'s own doc comment for why the other
/// four fault commands have no executor). Calls the shared
/// `DiagramSimulationService.injectFault`, the same real engine
/// operation `SimulationCenterDialog`'s own fault-injection UI uses.
Future<ContextualCommandResult> _injectOpenCircuitFault(EngineeringInteractionContext context) async {
  final target = context.effectiveTarget;
  final simulation = context.simulationService;
  if (target == null || simulation == null || !simulation.hasSession) {
    return ContextualCommandResult.unavailable('No simulation session is active.');
  }

  final fault = SimulationFault(
    id: EngineIds.generate('contextual_fault'),
    type: SimulationFaultType.openCircuit,
    targetId: target.id,
    isRelationship: target.kind == CursorTargetKind.relationship,
    injectedAt: DateTime.now(),
  );

  try {
    await simulation.injectFault(fault);
    return ContextualCommandResult(success: true, message: 'Open-circuit fault injected at ${target.id}.', affectedObjectIds: [target.id]);
  } catch (error) {
    return ContextualCommandResult(success: false, message: error.toString(), errorCode: 'fault_injection_failed');
  }
}

/// Real execution for "Clear Fault" (OEP Diagram Studio -- Phase 8,
/// Part 16) -- calls the shared `DiagramSimulationService.clearFault`,
/// the same real engine operation `FaultInjectionPanel`'s own "Clear"
/// action already uses.
Future<ContextualCommandResult> _clearFault(EngineeringInteractionContext context) async {
  final target = context.effectiveTarget;
  final simulation = context.simulationService;
  final faultId = context.simulation.targetFaultId;
  if (target == null || simulation == null || !simulation.hasSession || faultId == null) {
    return ContextualCommandResult.unavailable('No active fault on this target.');
  }

  try {
    await simulation.clearFault(faultId);
    return ContextualCommandResult(success: true, message: 'Fault cleared at ${target.id}.', affectedObjectIds: [target.id]);
  } catch (error) {
    return ContextualCommandResult(success: false, message: error.toString(), errorCode: 'fault_clear_failed');
  }
}

Future<ContextualCommandResult> _viewKnowledge(EngineeringInteractionContext context) async {
  if (!context.knowledge.knowledgeAvailable) {
    return ContextualCommandResult.unavailable('No Knowledge Curation Session is active.');
  }
  return ContextualCommandResult(
    success: true,
    message: '${context.knowledge.relatedKnowledgeCount} related Knowledge item(s) for the current context.',
  );
}

Future<ContextualCommandResult> _askAiAboutSelection(EngineeringInteractionContext context) async {
  final target = context.effectiveTarget;
  if (target == null) {
    return ContextualCommandResult.unavailable('No object is selected or targeted.');
  }

  final provider = AiProviderRegistry.defaultRegistry.providerFor(context.ai.currentProviderId);
  if (provider == null) {
    return ContextualCommandResult.unavailable('No AI provider registered with id "${context.ai.currentProviderId}".');
  }

  final request = AiRequest(
    id: EngineIds.generate('contextual_ai_request'),
    systemPrompt: 'You are an assistant helping an engineer understand one Engineering Object in their diagram. '
        'Answer using only the context provided; never invent data that is not listed.',
    userPrompt: 'Explain the ${target.kind.name} with id "${target.id}" in this diagram.',
    sourceId: target.id,
    referencedEntityIds: [target.id],
    referencedContextIds: const [],
    evidenceLabels: {target.id: target.id},
    createdTime: DateTime.now(),
  );

  final response = await DiagramAiService.ask(providerId: context.ai.currentProviderId, request: request);
  return ContextualCommandResult(
    success: response.success,
    message: response.success ? response.rawText : response.errorMessage,
    errorCode: response.success ? null : 'ai_provider_error',
  );
}
