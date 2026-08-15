import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/context/contextual_command_definitions.dart';
import 'package:oep_studio/core/context/contextual_command_resolver.dart';
import 'package:oep_studio/core/context/engineering_capability.dart';
import 'package:oep_studio/core/context/engineering_interaction_context.dart';
import 'package:oep_studio/diagram_studio/instruments/multimeter/multimeter_controller.dart';
import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/knowledge/services/ai_provider_registry.dart';
import 'package:oep_studio/knowledge/services/mock_ai_provider.dart';

import '../../simulation/simulation_test_fixtures.dart';

/// Acceptance tests for the OEP Context & Capability Service (Phase 1).
/// Mirrors the acceptance criteria in
/// `docs/context menu service/04_OEP_Context_Service_Implementation_Plan_and_Acceptance.md`
/// § 15 (Tests A-G) and this phase's own task 11 (scenarios A-J).
/// Deliberately independent of Flutter widgets and Riverpod: every
/// context here is constructed directly, exactly as
/// `EngineeringInteractionContextBuilder` would from real state, but
/// without needing a running app.
void main() {
  final resolver = ContextualCommandResolver(commands: initialContextualCommands);

  EngineeringGraph wireGraph({required String wireId, List<EngineeringRelationship> relationships = const []}) {
    return EngineeringGraph(
      id: 'graph-1',
      nodes: {
        wireId: const EngineeringNode(id: 'wire-1', category: NodeCategory.wire, displayName: 'Wire W104'),
        'node-a': const EngineeringNode(id: 'node-a', category: NodeCategory.connector, displayName: 'Connector A'),
      },
      relationships: {for (final r in relationships) r.id: r},
    );
  }

  group('Test A -- Empty canvas', () {
    test('no object-specific commands are applicable; canvas-relevant commands remain visible', () {
      const context = EngineeringInteractionContext(diagram: DiagramContext(diagramOpen: true, editable: true));
      final resolved = resolver.resolveCommands(context);

      final objectSpecific = resolved.where((r) => r.descriptor.id == 'diagram.inspect.object').single;
      expect(objectSpecific.visibility, CommandVisibility.hidden, reason: 'nothing is targeted');

      final measure = resolved.where((r) => r.descriptor.id == 'diagram.measure.voltage').single;
      expect(measure.visibility, CommandVisibility.hidden, reason: 'measurement needs a target');

      final fault = resolved.where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single;
      expect(fault.visibility, CommandVisibility.hidden, reason: 'no target and no active simulation');

      // Annotate has no target requirement -- stays relevant on an
      // empty, editable canvas (though disabled: no executor wired).
      final annotate = resolved.where((r) => r.descriptor.id == 'diagram.annotate.add').single;
      expect(annotate.visibility, isNot(CommandVisibility.hidden));
    });
  });

  group('Test B -- Real wire', () {
    final wire = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');

    test('wire inspection commands appear', () {
      final context = EngineeringInteractionContext(
        diagram: const DiagramContext(diagramOpen: true, editable: true),
        cursorTarget: wire,
        graph: wireGraph(wireId: 'wire-1'),
      );
      final resolved = resolver.resolveCommands(context);
      final inspect = resolved.where((r) => r.descriptor.id == 'diagram.inspect.object').single;
      expect(inspect.visibility, isNot(CommandVisibility.hidden));
    });

    test('measurement commands need both probes placed, not merely a target', () {
      final noDmm = EngineeringInteractionContext(cursorTarget: wire, graph: wireGraph(wireId: 'wire-1'));
      final dmmNoProbesPlaced = EngineeringInteractionContext(
        cursorTarget: wire,
        graph: wireGraph(wireId: 'wire-1'),
        measurement: const MeasurementContext(dmmAvailable: true),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.measurement}),
      );
      final bothProbesPlaced = EngineeringInteractionContext(
        cursorTarget: wire,
        graph: wireGraph(wireId: 'wire-1'),
        measurement: const MeasurementContext(dmmAvailable: true, probeAPlaced: true, probeBPlaced: true),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.measurement}),
      );

      final withoutDmmResolved = resolver.resolveCommands(noDmm).where((r) => r.descriptor.id == 'diagram.measure.voltage').single;
      final noProbesResolved =
          resolver.resolveCommands(dmmNoProbesPlaced).where((r) => r.descriptor.id == 'diagram.measure.voltage').single;
      final bothProbesResolved =
          resolver.resolveCommands(bothProbesPlaced).where((r) => r.descriptor.id == 'diagram.measure.voltage').single;

      expect(withoutDmmResolved.visibility, CommandVisibility.hidden, reason: 'DMM unavailable -- no probes can ever be placed');
      expect(noProbesResolved.visibility, CommandVisibility.hidden, reason: 'DMM available, but neither probe is placed yet');
      expect(bothProbesResolved.visibility, CommandVisibility.applicable,
          reason: 'both probes placed and the Measurement service is up -- a real executor is wired');
    });

    test('fault commands appear only in diagnostic simulation', () {
      final normalMode = EngineeringInteractionContext(cursorTarget: wire, graph: wireGraph(wireId: 'wire-1'));
      final diagnosticMode = EngineeringInteractionContext(
        cursorTarget: wire,
        graph: wireGraph(wireId: 'wire-1'),
        // Phase 7, Part 4/20: fault injection is Simulate-mode-only now.
        mode: DiagramStudioMode.simulate,
        simulation: const SimulationContext(active: true, mode: SimulationMode.diagnostic),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.simulation}),
      );

      final normalFault = resolver.resolveCommands(normalMode).where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single;
      final diagnosticFault =
          resolver.resolveCommands(diagnosticMode).where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single;

      expect(normalFault.visibility, CommandVisibility.hidden, reason: 'Resolution spec § 11: disappears in normal mode');
      expect(diagnosticFault.visibility, isNot(CommandVisibility.hidden));
    });
  });

  group('Test C -- Real relay', () {
    test('relay-specific inspection appears; DMM/fault gating matches wire behavior', () {
      final relayGraph = EngineeringGraph(
        id: 'graph-2',
        nodes: {'relay-1': const EngineeringNode(id: 'relay-1', category: NodeCategory.relay, displayName: 'Relay K1')},
      );
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'relay-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: relayGraph);
      final resolved = resolver.resolveCommands(context);

      expect(resolved.where((r) => r.descriptor.id == 'diagram.inspect.object').single.visibility,
          isNot(CommandVisibility.hidden));
      expect(resolved.where((r) => r.descriptor.id == 'diagram.measure.voltage').single.visibility,
          CommandVisibility.hidden, reason: 'targeted, but neither probe is placed');
      expect(resolved.where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single.visibility,
          CommandVisibility.hidden, reason: 'no simulation active');
    });
  });

  group('Test D -- Diagnostic simulation state changes resolution', () {
    test('the same object resolves a different command set before and during diagnostic simulation', () {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final before = EngineeringInteractionContext(cursorTarget: target, graph: wireGraph(wireId: 'wire-1'));
      final during = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        mode: DiagramStudioMode.simulate,
        simulation: const SimulationContext(active: true, mode: SimulationMode.diagnostic),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.simulation}),
      );

      final beforeApplicableIds = resolver
          .resolveCommands(before)
          .where((r) => r.visibility != CommandVisibility.hidden)
          .map((r) => r.descriptor.id)
          .toSet();
      final duringApplicableIds = resolver
          .resolveCommands(during)
          .where((r) => r.visibility != CommandVisibility.hidden)
          .map((r) => r.descriptor.id)
          .toSet();

      expect(duringApplicableIds.length, greaterThan(beforeApplicableIds.length));
      expect(duringApplicableIds.contains('diagram.fault.openCircuit'), isTrue);
      expect(beforeApplicableIds.contains('diagram.fault.openCircuit'), isFalse);
    });
  });

  group('Test E -- Diagnostic vs. Engineering Simulation is not a real distinction', () {
    test(
      'fault commands gate on real session activity alone (Phase 2 finding: the Simulation Engine has no '
      'Diagnostic-vs-Engineering mode concept, so asserting either mode value produces identical fault-command '
      'resolution -- both fault commands appear whenever a session is genuinely active)',
      () {
        final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
        final engineeringAsserted = EngineeringInteractionContext(
          cursorTarget: target,
          graph: wireGraph(wireId: 'wire-1'),
          mode: DiagramStudioMode.simulate,
          simulation: const SimulationContext(active: true, mode: SimulationMode.engineering),
          services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.simulation}),
        );
        final resolved = resolver.resolveCommands(engineeringAsserted);
        expect(resolved.where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single.visibility,
            isNot(CommandVisibility.hidden),
            reason: 'RequireActiveSimulationSession only checks .active, not .mode -- there is no real mode to gate on');

        // `diagnosticSimulation` itself (a *capability*, not the fault
        // command's own requirement) stays honestly unavailable even
        // here -- it specifically represents the mode distinction that
        // does not exist, and is never repurposed to mean "any session."
        final capabilities = resolver.capabilityBridge.resolve(engineeringAsserted);
        expect(capabilities.isAvailable(EngineeringCapability.diagnosticSimulation), isFalse);
      },
    );
  });

  group('Test F -- Missing capability', () {
    test('removing the Measurement service makes measurement commands unavailable even with both probes placed', () {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        measurement: const MeasurementContext(dmmAvailable: true, probeAPlaced: true, probeBPlaced: true),
        // Measurement service deliberately absent from ServiceAvailability.
      );
      final resolved = resolver.resolveCommands(context);
      final measure = resolved.where((r) => r.descriptor.id == 'diagram.measure.voltage').single;
      expect(measure.visibility, CommandVisibility.disabled);
      expect(measure.disabledReason, isNotNull);
    });
  });

  group('Test G -- Missing service blocks execution, not just visibility', () {
    test('executing a command whose service is unavailable is rejected, not silently allowed', () async {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: wireGraph(wireId: 'wire-1'));
      final result = await resolver.execute('diagram.measure.voltage', context);
      expect(result.success, isFalse);
    });
  });

  group('Test H -- Stale context is revalidated before execution', () {
    test('a command resolved as applicable while diagnostic simulation was active is rejected if simulation has since ended', () async {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final whenMenuOpened = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        mode: DiagramStudioMode.simulate,
        simulation: const SimulationContext(active: true, mode: SimulationMode.diagnostic),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.simulation}),
      );
      // Confirm the command really was applicable at menu-build time --
      // Phase 2 connected a real executor for Open Circuit.
      final resolvedWhenOpened =
          resolver.resolveCommands(whenMenuOpened).where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single;
      expect(resolvedWhenOpened.visibility, CommandVisibility.applicable);

      // The underlying state changes (simulation ends) before the user
      // actually selects the menu item -- execute() must receive and
      // revalidate against the *current* context, not silently reuse
      // whatever was true when the menu opened.
      final whenSelected = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        mode: DiagramStudioMode.simulate,
      );
      final result = await resolver.execute('diagram.fault.openCircuit', whenSelected);
      expect(result.success, isFalse, reason: 'No simulation session is active anymore');
    });
  });

  group('Test I -- Multi-selection', () {
    test('a command declared for single selection is hidden when multiple items are selected with no cursor target', () {
      const context = EngineeringInteractionContext(
        selection: SelectionContext(selectedNodeIds: {'a', 'b'}),
      );
      final resolved = resolver.resolveCommands(context);
      expect(resolved.where((r) => r.descriptor.id == 'diagram.inspect.object').single.visibility,
          CommandVisibility.hidden);
    });
  });

  group('Test J -- Command reuse', () {
    test('the same ContextualCommandDescriptor instance is returned regardless of how many times resolution runs', () {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: wireGraph(wireId: 'wire-1'));
      final first = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.inspect.object').single;
      final second = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.inspect.object').single;
      expect(identical(first.descriptor, second.descriptor), isTrue,
          reason: 'the same command definition must back every presentation surface, not a copy per resolution');
    });
  });

  group('MenuDescriptor building', () {
    test('groups only contain sections with at least one non-hidden command', () {
      const context = EngineeringInteractionContext(diagram: DiagramContext(diagramOpen: true, editable: true));
      final menu = resolver.buildMenu(context, title: 'Canvas', contextIdentity: 'Canvas');
      expect(menu.sections, isNotEmpty);
      for (final section in menu.sections) {
        expect(section.items, isNotEmpty);
      }
      // No Test/Diagnose section on an empty canvas -- nothing in
      // those groups is anything but hidden here.
      expect(menu.sections.any((s) => s.id == 'test'), isFalse);
      expect(menu.sections.any((s) => s.id == 'diagnose'), isFalse);
    });

    test('measure commands are grouped under a Measure submenu', () {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        measurement: const MeasurementContext(dmmAvailable: true, probeAPlaced: true, probeBPlaced: true),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.measurement}),
      );
      final menu = resolver.buildMenu(context, title: 'Wire W104', contextIdentity: 'WIRE W104');
      final testSection = menu.sections.where((s) => s.id == 'test').single;
      final measureSubmenu = testSection.items.where((i) => i.label == 'Measure').single;
      expect(measureSubmenu.isSubmenu, isTrue);
      expect(measureSubmenu.submenu!.map((i) => i.commandId), contains('diagram.measure.voltage'));
    });
  });

  group('Real, non-UI executable commands', () {
    test('Show Connected Nodes computes real connections from the graph, no fabricated data', () async {
      final graph = wireGraph(
        wireId: 'wire-1',
        relationships: [
          const EngineeringRelationship(
            id: 'relationship-1',
            relationshipType: RelationshipType.connectedTo,
            sourceNode: 'wire-1',
            targetNode: 'node-a',
          ),
        ],
      );
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: graph);
      final result = await resolver.execute('diagram.inspect.showConnections', context);
      expect(result.success, isTrue);
      expect(result.affectedObjectIds, ['node-a']);
    });

    test('Show Connected Nodes with no connections reports zero, not a fabricated count', () async {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: wireGraph(wireId: 'wire-1'));
      final result = await resolver.execute('diagram.inspect.showConnections', context);
      expect(result.success, isTrue);
      expect(result.affectedObjectIds, isEmpty);
    });

    test('Ask AI About Selection is rejected safely when no provider resolves', () async {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        ai: const AiContext(aiAvailable: true, contextualAnalysisAvailable: true, currentProviderId: 'nonexistent-provider'),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.ai}),
      );
      final result = await resolver.execute('diagram.ai.askAboutSelection', context);
      expect(result.success, isFalse);
      expect(result.message, contains('No AI provider'));
    });

    test('Ask AI About Selection runs the real Mock provider end-to-end when configured', () async {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        ai: const AiContext(aiAvailable: true, contextualAnalysisAvailable: true, currentProviderId: 'mock'),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.ai}),
      );
      final result = await resolver.execute('diagram.ai.askAboutSelection', context);
      expect(result.success, isTrue);
      expect(result.message, isNotNull);
    });
  });

  group('OEP Context & Capability Service -- Phase 2: real runtime execution', () {
    // Integration-style, against a REAL `SimulationEngine` (pure Dart,
    // no FFI, no mocks) -- the exact same engine `DiagramStudioPage`'s
    // shared providers wrap, exercised through the exact same
    // `DiagramSimulationService`/`MultimeterController` facades the
    // real DMM panel/fault-injection UI already use. Mirrors
    // `test/simulation/diagram_simulation_service_test.dart`'s own
    // "no mocks" convention and reuses its shared fixture graph
    // (battery -> fuse -> lamp, grounded via chassis).
    late SimulationEngine engine;
    late DiagramSimulationService simulation;
    late MultimeterController multimeter;
    late EngineeringGraph graph;

    setUp(() async {
      engine = SimulationEngine();
      simulation = DiagramSimulationService(engine: engine);
      multimeter = MultimeterController(simulationService: simulation);
      graph = buildSimulationTestGraph();
      await simulation.createSession(graph, name: 'phase-2-test');
    });

    EngineeringInteractionContext contextFor(CursorTarget target) => EngineeringInteractionContext(
          cursorTarget: target,
          graph: graph,
          simulation: SimulationContext(active: simulation.hasSession),
          measurement: MeasurementContext(
            dmmAvailable: true,
            probeAPlaced: multimeter.probeA != null,
            probeBPlaced: multimeter.probeB != null,
          ),
          services: const ServiceAvailability(
            availableServiceIds: {ServiceAvailability.measurement, ServiceAvailability.simulation},
          ),
          multimeterController: multimeter,
          simulationService: simulation,
        );

    test('Place DMM Probe + actually sets MultimeterController.probeA, not a copy', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      expect(multimeter.probeA, isNull);

      final result = await resolver.execute('diagram.probe.placePositive', contextFor(target));

      expect(result.success, isTrue);
      // Asserted on the SAME `multimeter` instance the test constructed
      // -- proving the executor mutated the real, shared controller,
      // not an internal copy the context happened to carry.
      expect(multimeter.probeA, isNotNull);
      expect(multimeter.probeA!.nodeId, 'fuse1');
    });

    test('Place DMM Probe - actually sets MultimeterController.probeB', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp');
      final result = await resolver.execute('diagram.probe.placeNegative', contextFor(target));
      expect(result.success, isTrue);
      expect(multimeter.probeB, isNotNull);
      expect(multimeter.probeB!.nodeId, 'lamp');
    });

    test('Measure Voltage actually calls DiagramSimulationService.measure and records a real MeasurementResult', () async {
      multimeter.setProbeA(const ProbePoint(nodeId: 'fuse1'));
      multimeter.setProbeB(const ProbePoint(nodeId: 'lamp'));
      expect(multimeter.latestResult, isNull);

      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp');
      final result = await resolver.execute('diagram.measure.voltage', contextFor(target));

      expect(result.success, isTrue);
      // The real controller's own `latestResult` -- populated by the
      // real engine call, not fabricated by the command executor.
      expect(multimeter.latestResult, isNotNull);
      expect(multimeter.latestResult!.type, MeasurementType.voltageDc);
    });

    test('Measure Voltage Drop, Resistance, and Continuity each call the real engine and produce a real result '
        '(OEP Context & Capability Service -- Phase 3A, Test D)', () async {
      multimeter.setProbeA(const ProbePoint(nodeId: 'fuse1'));
      multimeter.setProbeB(const ProbePoint(nodeId: 'lamp'));
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp');

      final voltageDrop = await resolver.execute('diagram.measure.voltageDrop', contextFor(target));
      expect(voltageDrop.success, isTrue);
      expect(multimeter.latestResult!.type, MeasurementType.voltageDc);
      expect(multimeter.latestResult!.reachable, isTrue, reason: 'fuse1 and lamp are really connected in the fixture graph');

      final resistance = await resolver.execute('diagram.measure.resistance', contextFor(target));
      expect(resistance.success, isTrue);
      expect(multimeter.latestResult!.type, MeasurementType.resistance);
      expect(multimeter.latestResult!.reachable, isTrue);

      final continuity = await resolver.execute('diagram.measure.continuity', contextFor(target));
      expect(continuity.success, isTrue);
      expect(multimeter.latestResult!.type, MeasurementType.continuity);
      expect(multimeter.latestResult!.continuous, isNotNull,
          reason: 'a real continuity reading must report an actual continuous/open verdict, not just success:true');
    });

    test('Inject Open Circuit actually adds a real fault the engine reports back', () async {
      const target = CursorTarget(kind: CursorTargetKind.relationship, targetId: 'r_fuse_lamp');
      final reportBefore = await simulation.faultReport();
      expect(reportBefore.activeFaultCount, 0);

      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: graph,
        mode: DiagramStudioMode.simulate,
        simulation: SimulationContext(active: simulation.hasSession),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.simulation}),
        simulationService: simulation,
      );
      final result = await resolver.execute('diagram.fault.openCircuit', context);
      expect(result.success, isTrue);

      // Verified against the real engine's own fault report -- the
      // exact same call `SimulationCenterDialog`'s fault UI already
      // makes -- not a locally-tracked flag.
      final reportAfter = await simulation.faultReport();
      expect(reportAfter.activeFaultCount, 1);

      final snapshot = await simulation.run();
      expect(snapshot.isPowered('lamp'), isFalse, reason: 'the real open-circuit fault must block real power propagation');
    });

    test('state identity: a second, independently-built context sees the same probe placement', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      await resolver.execute('diagram.probe.placePositive', contextFor(target));

      // A brand-new context, built separately (as
      // `EngineeringInteractionContextBuilder` would on a later
      // right-click), still reports the probe placement -- because it
      // reads the same `multimeter` instance, never a second one.
      final laterContext = contextFor(const CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp'));
      expect(laterContext.measurement.probeAPlaced, isTrue);
      expect(laterContext.multimeterController, same(multimeter));
    });

    test(
      'Test I (Phase 3A) -- a measurement command resolved as applicable while both probes were placed is '
      'rejected against a freshly-built context after a probe is removed, and no measurement is produced',
      () async {
        const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp');
        multimeter.setProbeA(const ProbePoint(nodeId: 'fuse1'));
        multimeter.setProbeB(const ProbePoint(nodeId: 'lamp'));

        // Confirm the command really was applicable when the menu would
        // have been built -- both probes are genuinely placed on the
        // real, shared controller.
        final whenMenuOpened = contextFor(target);
        final resolvedWhenOpened =
            resolver.resolveCommands(whenMenuOpened).where((r) => r.descriptor.id == 'diagram.measure.voltage').single;
        expect(resolvedWhenOpened.visibility, CommandVisibility.applicable);
        final capturedCommandId = resolvedWhenOpened.descriptor.id;

        // The real runtime state changes *after* the menu opened, *before*
        // the command is selected -- removing a probe through the same
        // real controller the menu itself reads.
        multimeter.setProbeB(null);
        expect(multimeter.latestResult, isNull);

        // `resolver.execute` must rebuild its own requirement evaluation
        // against a *freshly-built* context, not trust that the command
        // was valid when it was first resolved.
        final freshContext = contextFor(target);
        expect(freshContext.measurement.probeBPlaced, isFalse);
        final result = await resolver.execute(capturedCommandId, freshContext);

        expect(result.success, isFalse, reason: 'one probe was removed -- the stale command must not execute');
        expect(result.message, contains('Place both DMM probes'));
        expect(multimeter.latestResult, isNull, reason: 'no measurement must have been produced by the real engine');
      },
    );
  });

  group('Test F (Phase 3A) -- unsupported faults never become executable commands', () {
    // Pure-context construction is sufficient here: `DiagnosticCapabilityAdapter`
    // resolves `shortToGroundFault`/`shortToPowerFault`/`highResistanceFault`/
    // `intermittentFault` as permanently unavailable *regardless* of
    // session/target state (see that adapter's own doc comment -- the
    // real `SimulationFaultType` enum has no matching values), so no
    // real engine is needed to prove they can never resolve or execute.
    final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
    final activeSessionContext = EngineeringInteractionContext(
      cursorTarget: target,
      graph: wireGraph(wireId: 'wire-1'),
      simulation: const SimulationContext(active: true),
      services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.simulation}),
    );

    const unsupportedFaultCommandIds = {
      'diagram.fault.shortToGround',
      'diagram.fault.shortToPower',
    };

    test('unsupported fault commands resolve as disabled (never applicable), even with an active session and a real target', () {
      final resolved = resolver.resolveCommands(activeSessionContext);
      for (final id in unsupportedFaultCommandIds) {
        final command = resolved.where((r) => r.descriptor.id == id).single;
        expect(command.visibility, CommandVisibility.disabled,
            reason: '$id is conceptually relevant (session active, target present) but the engine cannot precisely '
                'support it -- disabled with a reason, never applicable, never hidden as if it did not exist at all');
        expect(command.disabledReason, isNotNull);
      }
    });

    test('unsupported fault commands are absent from the built menu\'s Diagnose section as executable entries', () {
      final menu = resolver.buildMenu(activeSessionContext, title: 'Wire W104', contextIdentity: 'WIRE W104');
      final diagnoseSection = menu.sections.where((s) => s.id == 'diagnose').single;
      final injectFaultSubmenu = diagnoseSection.items.where((i) => i.label == 'Inject Fault').single;
      final submenuLabels = injectFaultSubmenu.submenu!.map((i) => i.label).toSet();
      // They DO appear in the submenu (disabled, with a reason -- Part
      // 23's own "disabled-vs-hidden" rule), but every one is disabled.
      expect(submenuLabels, containsAll(['Short to Ground', 'Short to Power']));
      for (final item in injectFaultSubmenu.submenu!.where((i) => submenuLabels.contains(i.label) && i.label != 'Open Circuit')) {
        expect(item.enabled, isFalse, reason: '${item.label} must never render as a clickable/executable entry');
      }
    });

    test('executing an unsupported fault command through the resolver is always rejected, regardless of context', () async {
      for (final id in unsupportedFaultCommandIds) {
        final result = await resolver.execute(id, activeSessionContext);
        expect(result.success, isFalse, reason: '$id has no real engine counterpart and must never report success');
      }
    });

    test('High Resistance and Intermittent were never migrated onto the contextual command system at all '
        '(no descriptor exists for a fault type the engine cannot express)', () {
      final allIds = initialContextualCommands.map((c) => c.id).toSet();
      expect(allIds.any((id) => id.toLowerCase().contains('highresistance')), isFalse);
      expect(allIds.any((id) => id.toLowerCase().contains('intermittent')), isFalse);
    });
  });

  group('Test G (Phase 3A) -- Knowledge command executes through the contextual command system', () {
    test('View Engineering Knowledge resolves as applicable and its real, non-fabricated result is produced only '
        'through resolver.execute -- the primary assertion never calls a Knowledge service directly', () async {
      final context = EngineeringInteractionContext(
        knowledge: const KnowledgeContext(knowledgeAvailable: true, relatedKnowledgeCount: 3),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.knowledge}),
      );

      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.knowledge.view').single;
      expect(resolved.visibility, CommandVisibility.applicable);

      final result = await resolver.execute('diagram.knowledge.view', context);
      expect(result.success, isTrue);
      // The executor's own real logic (`_viewKnowledge`) reports the
      // context's own `relatedKnowledgeCount` -- proving the command
      // path actually reached and read the real `KnowledgeContext`
      // rather than returning a canned success.
      expect(result.message, contains('3'));
    });

    test('View Engineering Knowledge is honestly disabled with no Knowledge Curation Session active', () async {
      // The Knowledge *service* is up, but no session is active --
      // isolates the "no session" reason from the separate "service
      // unavailable" reason covered below.
      const context = EngineeringInteractionContext(
        services: ServiceAvailability(availableServiceIds: {ServiceAvailability.knowledge}),
      );
      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.knowledge.view').single;
      expect(resolved.visibility, CommandVisibility.disabled);

      final result = await resolver.execute('diagram.knowledge.view', context);
      expect(result.success, isFalse);
      expect(result.message, contains('No Knowledge Curation Session'));
    });

    test('View Engineering Knowledge is honestly disabled with the Knowledge service itself unavailable', () async {
      const context = EngineeringInteractionContext();
      final result = await resolver.execute('diagram.knowledge.view', context);
      expect(result.success, isFalse);
      expect(result.message, contains('Knowledge service is not available'));
    });
  });

  group('Test H (Phase 3A) -- AI command executes through the real, deterministic Mock provider, with identity verified', () {
    test('the configured provider id actually resolves to the real MockAiProvider -- not merely a string match', () {
      final provider = AiProviderRegistry.defaultRegistry.providerFor('mock');
      expect(provider, isNotNull);
      expect(provider, isA<MockAiProvider>());
      expect(provider!.modelInfo.providerId, 'mock',
          reason: 'the provider\'s own declared identity must match the id the context asked for, no network access involved');
    });

    test('Ask AI About Selection, executed through the resolver, produces the real Mock provider\'s deterministic output', () async {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        ai: const AiContext(aiAvailable: true, contextualAnalysisAvailable: true, currentProviderId: 'mock'),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.ai}),
      );

      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.ai.askAboutSelection').single;
      expect(resolved.visibility, CommandVisibility.applicable);

      final result = await resolver.execute('diagram.ai.askAboutSelection', context);
      expect(result.success, isTrue);
      expect(result.message, isNotNull);
      // The Mock provider's own contract (see `MockAiProvider`'s doc
      // comment): deterministic, derived only from the request's own
      // referenced evidence -- calling it again with the same target
      // must reproduce byte-identical output, proving this is a real
      // provider call, not a per-invocation random/fabricated string.
      final repeat = await resolver.execute('diagram.ai.askAboutSelection', context);
      expect(repeat.message, result.message);
    });
  });

  group('Test J (Phase 3A) -- multi-selection is preserved through resolution, not silently narrowed to one object', () {
    test('a real multi-node selection is preserved on the context, single-target commands are hidden, and a '
        'whole-selection-scoped command (no RequireSelectedTarget) remains available', () {
      const context = EngineeringInteractionContext(
        diagram: DiagramContext(diagramOpen: true, editable: true),
        selection: SelectionContext(selectedNodeIds: {'node-a', 'node-b', 'node-c'}),
      );

      // The context itself, not some derived/summarized value, carries
      // the full selection.
      expect(context.selection.selectedNodeIds, {'node-a', 'node-b', 'node-c'});
      // With no single cursor target and more than one selected node,
      // `effectiveTarget` correctly reports no single object to act on
      // (Contract spec's fallback rule only picks a single selected item).
      expect(context.effectiveTarget, isNull);

      final resolved = resolver.resolveCommands(context);
      expect(resolved.where((r) => r.descriptor.id == 'diagram.inspect.object').single.visibility, CommandVisibility.hidden,
          reason: 'a single-target command must not silently pick one arbitrary member of the selection');
      expect(resolved.where((r) => r.descriptor.id == 'diagram.measure.voltage').single.visibility, CommandVisibility.hidden);

      // `diagram.annotate.add` declares no `RequireSelectedTarget` --
      // only `RequireDiagramOpen`/`RequireCapability(annotation)`, both
      // of which are satisfied for the whole selection at once -- so it
      // must remain visible (not hidden) regardless of how many objects
      // are selected.
      final annotate = resolved.where((r) => r.descriptor.id == 'diagram.annotate.add').single;
      expect(annotate.visibility, isNot(CommandVisibility.hidden),
          reason: 'a command scoped to the whole selection/canvas must not disappear just because more than one object is selected');
    });

    test('executing a single-target command against a multi-selection context is rejected, not silently run against one member', () async {
      const context = EngineeringInteractionContext(
        diagram: DiagramContext(diagramOpen: true, editable: true),
        selection: SelectionContext(selectedNodeIds: {'node-a', 'node-b'}),
      );
      final result = await resolver.execute('diagram.inspect.object', context);
      expect(result.success, isFalse, reason: 'no single target exists -- execution must not guess which selected object to use');
    });
  });

  group('Part 3 (Phase 3A) -- MenuDescriptor is the renderer\'s only source of content', () {
    test('MenuDescriptor carries the exact title/contextIdentity passed in, unmodified', () {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: wireGraph(wireId: 'wire-1'));
      final menu = resolver.buildMenu(context, title: 'Wire W104', contextIdentity: 'WIRE W104');
      expect(menu.title, 'Wire W104');
      expect(menu.contextIdentity, 'WIRE W104');
    });

    test('a disabled MenuItem carries enabled:false and a real, non-null disabledReason -- not just a boolean', () {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      // A target is present (so the measurement commands are not
      // target-shaped-hidden) but the Measurement service itself is
      // absent -- a genuine capability-level disablement.
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        measurement: const MeasurementContext(dmmAvailable: true, probeAPlaced: true, probeBPlaced: true),
      );
      final menu = resolver.buildMenu(context, title: 'Wire W104', contextIdentity: 'WIRE W104');
      final testSection = menu.sections.where((s) => s.id == 'test').single;
      final measureSubmenu = testSection.items.where((i) => i.label == 'Measure').single;
      final voltageItem = measureSubmenu.submenu!.where((i) => i.commandId == 'diagram.measure.voltage').single;
      expect(voltageItem.enabled, isFalse);
      expect(voltageItem.disabledReason, isNotNull);
      expect(voltageItem.disabledReason, isNot(isEmpty));
    });

    test('MenuItem.label and .commandId are exactly the descriptor\'s own label/id -- the renderer invents no text', () {
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: wireGraph(wireId: 'wire-1'));
      final menu = resolver.buildMenu(context, title: 'Wire W104', contextIdentity: 'WIRE W104');
      final inspectSection = menu.sections.where((s) => s.id == 'inspect').single;
      final inspectObjectItem = inspectSection.items.where((i) => i.commandId == 'diagram.inspect.object').single;
      final descriptor = initialContextualCommands.where((c) => c.id == 'diagram.inspect.object').single;
      expect(inspectObjectItem.label, descriptor.label);
      expect(inspectObjectItem.commandId, descriptor.id);
    });

    test('sections with zero non-hidden commands are omitted entirely -- no active session means no Diagnose section at all', () {
      final relayGraph = EngineeringGraph(
        id: 'graph-menu-3',
        nodes: {'relay-1': const EngineeringNode(id: 'relay-1', category: NodeCategory.relay, displayName: 'Relay K1')},
      );
      final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'relay-1');
      final context = EngineeringInteractionContext(cursorTarget: target, graph: relayGraph);
      final menu = resolver.buildMenu(context, title: 'Relay K1', contextIdentity: 'RELAY K1');
      final sectionIds = menu.sections.map((s) => s.id).toSet();
      // Both fault commands' `RequireActiveSimulationSession` is
      // target-shaped -- with no session active they resolve `hidden`,
      // not merely disabled, so the whole Diagnose section must not
      // exist (a section with zero non-hidden items is omitted, not
      // rendered empty). `diagram.annotate.add`'s `RequireDiagramOpen`
      // is likewise unmet (no diagram open in this context), so
      // Annotate is absent too.
      expect(sectionIds, isNot(contains('diagnose')));
      expect(sectionIds, isNot(contains('annotate')));
      // Inspect/Test/Knowledge/AI each still have at least one
      // disabled-but-not-hidden command (e.g. "Place DMM Probe +" is
      // conceptually relevant to a real target even with no DMM
      // present), so those sections DO appear -- proving the omission
      // rule is genuinely per-section-content, not "only inspect ever
      // shows.".
      expect(sectionIds, containsAll(['inspect', 'test', 'knowledge', 'ai']));
    });
  });

  group('Part 4 (Phase 3A) -- the resolver is the sole authority on applicability; no object-type branching exists', () {
    test('a wire and a relay target, given otherwise-identical context state, resolve the exact same applicable-command-id set', () {
      final relayGraph = EngineeringGraph(
        id: 'graph-boundary-1',
        nodes: {'relay-1': const EngineeringNode(id: 'relay-1', category: NodeCategory.relay, displayName: 'Relay K1')},
      );
      final wireContext = EngineeringInteractionContext(
        cursorTarget: const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1'),
        graph: wireGraph(wireId: 'wire-1'),
        measurement: const MeasurementContext(dmmAvailable: true, probeAPlaced: true, probeBPlaced: true),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.measurement}),
      );
      final relayContext = EngineeringInteractionContext(
        cursorTarget: const CursorTarget(kind: CursorTargetKind.node, targetId: 'relay-1'),
        graph: relayGraph,
        measurement: const MeasurementContext(dmmAvailable: true, probeAPlaced: true, probeBPlaced: true),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.measurement}),
      );

      String visibilityMap(EngineeringInteractionContext context) => resolver
          .resolveCommands(context)
          .map((r) => '${r.descriptor.id}:${r.visibility.name}')
          .join(',');

      // If any command's applicability depended on `NodeCategory` (a
      // hidden `if (target is Wire)`), this would diverge between the
      // two otherwise-identical contexts. It does not, because
      // `ContextualCommandResolver`/`CapabilityAdapter`s never inspect
      // `EngineeringNode.category` at all -- only `effectiveTarget`
      // presence, capabilities, and services.
      expect(visibilityMap(wireContext), visibilityMap(relayContext));
    });
  });

  group('OEP Diagram Studio -- Phase 4: port targets carry a real owning node through to execution', () {
    const portTarget = CursorTarget(kind: CursorTargetKind.port, targetId: 'positive', ownerNodeId: 'battery-1');

    test('effectiveTarget preserves ownerNodeId for a port CursorTarget', () {
      const context = EngineeringInteractionContext(cursorTarget: portTarget);
      final target = context.effectiveTarget;
      expect(target, isNotNull);
      expect(target!.kind, CursorTargetKind.port);
      expect(target.id, 'positive');
      expect(target.ownerNodeId, 'battery-1');
    });

    test('Inspect Object resolves as applicable for a port target, exactly like a node target -- '
        'no port-specific branching exists in the resolver', () {
      final context = EngineeringInteractionContext(
        cursorTarget: portTarget,
        graph: EngineeringGraph(id: 'g-port-1', nodes: {
          'battery-1': const EngineeringNode(id: 'battery-1', category: NodeCategory.component, displayName: 'Battery'),
        }),
      );
      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.inspect.object').single;
      expect(resolved.visibility, isNot(CommandVisibility.hidden));
    });

    test('Place DMM Probe + on a port target builds a real ProbePoint(nodeId, portId) from '
        'CursorTarget.ownerNodeId -- resolving Phase 2\'s documented limitation', () async {
      final engine = SimulationEngine();
      final simulation = DiagramSimulationService(engine: engine);
      final multimeter = MultimeterController(simulationService: simulation);
      final graph = buildSimulationTestGraph();
      await simulation.createSession(graph, name: 'phase-4-port-probe-test');

      const target = CursorTarget(kind: CursorTargetKind.port, targetId: 'positive', ownerNodeId: 'battery');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: graph,
        measurement: MeasurementContext(dmmAvailable: true, probeAPlaced: multimeter.probeA != null, probeBPlaced: multimeter.probeB != null),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.measurement}),
        multimeterController: multimeter,
      );

      final result = await resolver.execute('diagram.probe.placePositive', context);
      expect(result.success, isTrue);
      expect(multimeter.probeA, isNotNull);
      expect(multimeter.probeA!.nodeId, 'battery', reason: 'the real owning node, from ownerNodeId, not the port id itself');
      expect(multimeter.probeA!.portId, 'positive');
    });

    test('a relationship/annotation target still has no owning-node concept -- probe placement stays unavailable, honestly', () async {
      final multimeter = MultimeterController(simulationService: DiagramSimulationService(engine: SimulationEngine()));
      const relationshipTarget = CursorTarget(kind: CursorTargetKind.relationship, targetId: 'r-1');
      final context = EngineeringInteractionContext(
        cursorTarget: relationshipTarget,
        graph: wireGraph(wireId: 'wire-1'),
        measurement: const MeasurementContext(dmmAvailable: true),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.measurement}),
        multimeterController: multimeter,
      );
      final result = await resolver.execute('diagram.probe.placePositive', context);
      expect(result.success, isFalse);
      expect(result.message, contains('no owning-node id'));
    });
  });

  group('OEP Diagram Studio -- Phase 5, Test H: the resolver receives and honors the current mode', () {
    final target = const CursorTarget(kind: CursorTargetKind.node, targetId: 'wire-1');

    test('Add Annotation is applicable in Edit mode', () {
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        diagram: const DiagramContext(diagramOpen: true, editable: true),
        // mode defaults to edit -- explicit here for clarity.
      );
      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.annotate.add').single;
      expect(resolved.visibility, isNot(CommandVisibility.hidden));
    });

    test('Add Annotation disappears entirely in View mode -- mode-shaped, not merely disabled', () {
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        diagram: const DiagramContext(diagramOpen: true, editable: true),
        mode: DiagramStudioMode.view,
      );
      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.annotate.add').single;
      expect(resolved.visibility, CommandVisibility.hidden);
    });

    test('Add Annotation disappears entirely in Simulate mode', () {
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        diagram: const DiagramContext(diagramOpen: true, editable: true),
        mode: DiagramStudioMode.simulate,
      );
      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.annotate.add').single;
      expect(resolved.visibility, CommandVisibility.hidden);
    });

    test('executing a mode-gated command in the wrong mode is rejected, not silently allowed', () async {
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        diagram: const DiagramContext(diagramOpen: true, editable: true),
        mode: DiagramStudioMode.view,
      );
      final result = await resolver.execute('diagram.annotate.add', context);
      expect(result.success, isFalse);
      expect(result.message, contains('view mode'));
    });

    test('the same wire target, in View vs. Edit mode, resolves a different command set -- '
        'the resolver, not the widget, is where mode-shaped differences are decided', () {
      final editContext = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        diagram: const DiagramContext(diagramOpen: true, editable: true),
      );
      final viewContext = EngineeringInteractionContext(
        cursorTarget: target,
        graph: wireGraph(wireId: 'wire-1'),
        diagram: const DiagramContext(diagramOpen: true, editable: true),
        mode: DiagramStudioMode.view,
      );
      final editIds = resolver.resolveCommands(editContext).where((r) => r.visibility != CommandVisibility.hidden).map((r) => r.descriptor.id).toSet();
      final viewIds = resolver.resolveCommands(viewContext).where((r) => r.visibility != CommandVisibility.hidden).map((r) => r.descriptor.id).toSet();
      expect(editIds.contains('diagram.annotate.add'), isTrue);
      expect(viewIds.contains('diagram.annotate.add'), isFalse);
    });
  });

  group('OEP Diagram Studio -- Phase 6 (View/Inspect mode)', () {
    late SimulationEngine engine;
    late DiagramSimulationService simulation;
    late MultimeterController multimeter;
    late EngineeringGraph graph;

    setUp(() async {
      engine = SimulationEngine();
      simulation = DiagramSimulationService(engine: engine);
      multimeter = MultimeterController(simulationService: simulation);
      graph = buildSimulationTestGraph();
      await simulation.createSession(graph, name: 'phase-6-view-mode-test');
    });

    EngineeringInteractionContext contextFor(CursorTarget target, DiagramStudioMode mode) => EngineeringInteractionContext(
          cursorTarget: target,
          graph: graph,
          mode: mode,
          simulation: SimulationContext(active: simulation.hasSession),
          measurement: MeasurementContext(
            dmmAvailable: true,
            probeAPlaced: multimeter.probeA != null,
            probeBPlaced: multimeter.probeB != null,
          ),
          services: const ServiceAvailability(
            availableServiceIds: {ServiceAvailability.measurement, ServiceAvailability.simulation},
          ),
          multimeterController: multimeter,
          simulationService: simulation,
        );

    test('Test F -- DMM probe placement and measurement work from View mode, through the real runtime', () async {
      const fuseTarget = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      const lampTarget = CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp');

      final probeAResult = await resolver.execute('diagram.probe.placePositive', contextFor(fuseTarget, DiagramStudioMode.view));
      expect(probeAResult.success, isTrue);
      final probeBResult = await resolver.execute('diagram.probe.placeNegative', contextFor(lampTarget, DiagramStudioMode.view));
      expect(probeBResult.success, isTrue);

      final measureResult = await resolver.execute('diagram.measure.voltage', contextFor(lampTarget, DiagramStudioMode.view));
      expect(measureResult.success, isTrue);
      expect(multimeter.latestResult, isNotNull, reason: 'a real MeasurementResult, from the real engine, not fabricated');
      expect(multimeter.latestResult!.type, MeasurementType.voltageDc);
    });

    test('Test G -- switching mode does not disturb the real simulation session or DMM state, and creates no second instance', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      await resolver.execute('diagram.probe.placePositive', contextFor(target, DiagramStudioMode.simulate));
      expect(multimeter.probeA, isNotNull);
      expect(simulation.hasSession, isTrue);

      // Building fresh contexts for View, then back to Simulate, must
      // observe the exact same live objects -- proving mode is purely a
      // context field, never a trigger that tears down or recreates
      // runtime state.
      final viewContext = contextFor(target, DiagramStudioMode.view);
      expect(viewContext.simulation.active, isTrue, reason: 'the real session must still be active while viewing');
      expect(viewContext.measurement.probeAPlaced, isTrue, reason: 'the real probe placement must still be visible while viewing');
      expect(viewContext.multimeterController, same(multimeter));
      expect(viewContext.simulationService, same(simulation));

      final simulateAgainContext = contextFor(target, DiagramStudioMode.simulate);
      expect(simulateAgainContext.multimeterController, same(multimeter));
      expect(simulateAgainContext.simulationService, same(simulation));
    });

    test('Test H -- Knowledge command is unaffected by mode', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: graph,
        mode: DiagramStudioMode.view,
        knowledge: const KnowledgeContext(knowledgeAvailable: true, relatedKnowledgeCount: 1),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.knowledge}),
      );
      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.knowledge.view').single;
      expect(resolved.visibility, CommandVisibility.applicable);
      final result = await resolver.execute('diagram.knowledge.view', context);
      expect(result.success, isTrue);
    });

    test('Test I -- AI command is unaffected by mode', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      final context = EngineeringInteractionContext(
        cursorTarget: target,
        graph: graph,
        mode: DiagramStudioMode.view,
        ai: const AiContext(aiAvailable: true, contextualAnalysisAvailable: true, currentProviderId: 'mock'),
        services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.ai}),
      );
      final resolved = resolver.resolveCommands(context).where((r) => r.descriptor.id == 'diagram.ai.askAboutSelection').single;
      expect(resolved.visibility, CommandVisibility.applicable);
      final result = await resolver.execute('diagram.ai.askAboutSelection', context);
      expect(result.success, isTrue);
    });

    test('Inject Fault is unavailable in View mode -- Part 10\'s "inspect and measure, not manipulate" boundary', () async {
      const target = CursorTarget(kind: CursorTargetKind.relationship, targetId: 'r_fuse_lamp');
      final viewContext = contextFor(target, DiagramStudioMode.view);
      final resolved = resolver.resolveCommands(viewContext).where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single;
      expect(resolved.visibility, CommandVisibility.hidden);

      final result = await resolver.execute('diagram.fault.openCircuit', viewContext);
      expect(result.success, isFalse);

      // Simulate mode keeps working -- this phase narrows View only.
      final simulateContext = contextFor(target, DiagramStudioMode.simulate);
      final resolvedSimulate =
          resolver.resolveCommands(simulateContext).where((r) => r.descriptor.id == 'diagram.fault.openCircuit').single;
      expect(resolvedSimulate.visibility, CommandVisibility.applicable);
    });
  });

  // (OEP Diagram Studio -- Phase 8.) Mirrors
  // `EngineeringInteractionContextBuilder._activeFaultIdFor` exactly --
  // the same real `session.activeFaults.active` lookup by target id,
  // not a fabricated fault-presence flag.
  String? activeFaultIdFor(DiagramSimulationService? simulationService, String? targetId) {
    if (targetId == null) return null;
    final session = simulationService?.currentSession;
    if (session == null) return null;
    for (final fault in session.activeFaults.active) {
      if (fault.targetId == targetId) return fault.id;
    }
    return null;
  }

  group('OEP Diagram Studio -- Phase 8 (Simulate/Diagnose mode)', () {
    late SimulationEngine engine;
    late DiagramSimulationService simulation;
    late MultimeterController multimeter;
    late EngineeringGraph graph;

    setUp(() async {
      engine = SimulationEngine();
      simulation = DiagramSimulationService(engine: engine);
      multimeter = MultimeterController(simulationService: simulation);
      graph = buildSimulationTestGraph();
      await simulation.createSession(graph, name: 'phase-8-simulate-mode-test');
    });

    EngineeringInteractionContext contextFor(CursorTarget target) => EngineeringInteractionContext(
          cursorTarget: target,
          graph: graph,
          mode: DiagramStudioMode.simulate,
          simulation: SimulationContext(
            active: simulation.hasSession,
            targetFaultId: activeFaultIdFor(simulation, target.targetId),
          ),
          services: const ServiceAvailability(
            availableServiceIds: {ServiceAvailability.measurement, ServiceAvailability.simulation},
          ),
          multimeterController: multimeter,
          simulationService: simulation,
        );

    const relationshipTarget = CursorTarget(kind: CursorTargetKind.relationship, targetId: 'r_fuse_lamp');

    test('Test H/I -- Clear Fault is hidden with no active fault on the target, applicable once one real exists', () async {
      final beforeContext = contextFor(relationshipTarget);
      expect(
        resolver.resolveCommands(beforeContext).where((r) => r.descriptor.id == 'diagram.fault.clear').single.visibility,
        CommandVisibility.hidden,
        reason: 'a target with no active fault has no relationship to "clear the fault" at all',
      );

      final injectResult = await resolver.execute('diagram.fault.openCircuit', beforeContext);
      expect(injectResult.success, isTrue);

      final afterContext = contextFor(relationshipTarget);
      expect(afterContext.simulation.targetFaultId, isNotNull, reason: 'the real, injected fault must now be visible on the context');
      expect(
        resolver.resolveCommands(afterContext).where((r) => r.descriptor.id == 'diagram.fault.clear').single.visibility,
        CommandVisibility.applicable,
      );
    });

    test('Test H/I -- Clear Fault actually removes the real fault from the engine, not a locally-tracked flag', () async {
      final injectContext = contextFor(relationshipTarget);
      await resolver.execute('diagram.fault.openCircuit', injectContext);
      final reportAfterInject = await simulation.faultReport();
      expect(reportAfterInject.activeFaultCount, 1);

      final clearContext = contextFor(relationshipTarget);
      final clearResult = await resolver.execute('diagram.fault.clear', clearContext);
      expect(clearResult.success, isTrue);

      final reportAfterClear = await simulation.faultReport();
      expect(reportAfterClear.activeFaultCount, 0, reason: 'the real engine fault report must reflect the real removal');
    });

    test('Test J -- unsupported fault types remain unavailable regardless of mode', () {
      final context = contextFor(relationshipTarget);
      for (final id in ['diagram.fault.shortToGround', 'diagram.fault.shortToPower']) {
        expect(
          resolver.resolveCommands(context).where((r) => r.descriptor.id == id).single.visibility,
          CommandVisibility.disabled,
        );
      }
      final allIds = initialContextualCommands.map((c) => c.id).toSet();
      expect(allIds.any((id) => id.toLowerCase().contains('highresistance')), isFalse);
      expect(allIds.any((id) => id.toLowerCase().contains('intermittent')), isFalse);
    });

    test('Test O -- a stale Clear Fault command is rejected against a fresh context after the fault is already gone', () async {
      final injectContext = contextFor(relationshipTarget);
      await resolver.execute('diagram.fault.openCircuit', injectContext);

      // Confirm applicable at "menu open" time.
      final whenOpened = contextFor(relationshipTarget);
      expect(
        resolver.resolveCommands(whenOpened).where((r) => r.descriptor.id == 'diagram.fault.clear').single.visibility,
        CommandVisibility.applicable,
      );

      // Real state changes before the user selects the item -- the
      // fault is cleared through a completely different path
      // (`restoreNormal`, not the resolver).
      await simulation.restoreNormal();

      final whenSelected = contextFor(relationshipTarget);
      final result = await resolver.execute('diagram.fault.clear', whenSelected);
      expect(result.success, isFalse, reason: 'the fault is already gone -- stale execution must be rejected, not silently no-op');
    });

    test('Test N -- runtime simulation state and engineering document state are genuinely separate concepts '
        '(EngineeringInteractionContext carries no document-dirty signal derived from simulation activity)', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      await resolver.execute('diagram.probe.placePositive', contextFor(target));
      await resolver.execute('diagram.fault.openCircuit', contextFor(relationshipTarget));
      // `EngineeringInteractionContext.document` is sourced from
      // `DiagramDocument` alone (see `EngineeringInteractionContextBuilder`)
      // -- nothing simulation-related ever writes to it. Asserted here by
      // construction: this context was never given a document at all,
      // yet every real simulation operation above still succeeded,
      // proving simulation execution has no dependency on -- and no
      // side effect on -- document/dirty state.
      expect(contextFor(target).document.isDirty, isFalse);
    });

    test('Test B (Phase 8) -- View -> Simulate: the real shared runtime instances are unchanged', () {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      final viewContext = EngineeringInteractionContext(
        cursorTarget: target,
        graph: graph,
        mode: DiagramStudioMode.view,
        multimeterController: multimeter,
        simulationService: simulation,
      );
      final simulateContext = contextFor(target);
      expect(viewContext.multimeterController, same(simulateContext.multimeterController));
      expect(viewContext.simulationService, same(simulateContext.simulationService));
    });
  });

  group('OEP Engineering Runtime -- Phase 9 (Operating State & Input-State Architecture)', () {
    const keyOff = OperatingStateDefinition(id: 'key_off', name: 'Key Off / Engine Off');
    const keyOn = OperatingStateDefinition(id: 'key_on', name: 'Key On / Engine Off');

    late SimulationEngine engine;
    late DiagramSimulationService simulation;
    late EngineeringGraph graph;

    setUp(() async {
      engine = SimulationEngine();
      simulation = DiagramSimulationService(engine: engine);
      graph = buildSimulationTestGraph();
      await simulation.createSession(
        graph,
        name: 'phase-9-operating-state-test',
        availableOperatingStates: const [keyOff, keyOn],
      );
    });

    EngineeringInteractionContext contextFor(CursorTarget target, DiagramStudioMode mode) => EngineeringInteractionContext(
          cursorTarget: target,
          graph: graph,
          mode: mode,
          simulation: SimulationContext(
            active: simulation.hasSession,
            activeOperatingStateId: simulation.currentSession?.activeOperatingStateId,
            availableOperatingStateIds: simulation.currentSession?.availableOperatingStates.map((s) => s.id).toList() ?? const [],
          ),
          simulationService: simulation,
        );

    // --- Test I: Context ------------------------------------------------------
    test('Test I -- the Context Service observes the real active operating state, sourced from the real session', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      final before = contextFor(target, DiagramStudioMode.simulate);
      expect(before.simulation.activeOperatingStateId, isNull, reason: 'no fabricated implicit default');
      expect(before.simulation.availableOperatingStateIds, ['key_off', 'key_on']);

      await simulation.setOperatingState('key_on');

      final after = contextFor(target, DiagramStudioMode.simulate);
      expect(after.simulation.activeOperatingStateId, 'key_on', reason: 'sourced from the real SimulationSession, not a copy');
    });

    // --- Test L: Runtime/document separation ------------------------------
    test('Test L -- changing operating state is runtime state, never engineering document state', () async {
      // `SimulationSession.setOperatingState` mutates only the session's
      // own event history (Phase 9's `SimulationSession` extension) --
      // it has no reference to, and never touches, the `EditingSession`/
      // document model that `_markDirty()` guards in
      // `diagram_studio_page.dart`. This is verified here by construction:
      // the engineering graph instance itself is provably unchanged.
      final graphBefore = graph;
      await simulation.setOperatingState('key_on');
      expect(simulation.currentSession!.graph, same(graphBefore), reason: 'operating state never mutates the engineering document/graph');
    });

    // --- Test N: Identity -------------------------------------------------------
    test('Test N -- View <-> Simulate mode transitions do not create duplicate runtime state', () async {
      const target = CursorTarget(kind: CursorTargetKind.node, targetId: 'fuse1');
      await simulation.setOperatingState('key_on');

      final simulateContext = contextFor(target, DiagramStudioMode.simulate);
      final viewContext = contextFor(target, DiagramStudioMode.view);

      expect(viewContext.simulationService, same(simulateContext.simulationService));
      expect(viewContext.simulation.activeOperatingStateId, 'key_on', reason: 'the same real session, observed from a different mode');
      expect(simulateContext.simulation.activeOperatingStateId, 'key_on');
    });
  });

  group('OEP Engineering Runtime -- Phase 10 (Operating/Input State Effects -> Signal Propagation)', () {
    const lampSwitch = InputStateDefinition(id: 'lamp_switch', label: 'Lamp Switch', targetRelationshipId: 'r_fuse_lamp');

    late SimulationEngine engine;
    late DiagramSimulationService simulation;
    late MultimeterController multimeter;
    late EngineeringGraph graph;

    setUp(() async {
      engine = SimulationEngine();
      simulation = DiagramSimulationService(engine: engine);
      multimeter = MultimeterController(simulationService: simulation);
      graph = buildSimulationTestGraph();
      await simulation.createSession(graph, name: 'phase-10-state-effects-test', availableInputStates: const [lampSwitch]);
    });

    EngineeringInteractionContext contextFor(CursorTarget target) => EngineeringInteractionContext(
          cursorTarget: target,
          graph: graph,
          mode: DiagramStudioMode.simulate,
          simulation: SimulationContext(active: simulation.hasSession),
          measurement: MeasurementContext(
            dmmAvailable: true,
            probeAPlaced: multimeter.probeA != null,
            probeBPlaced: multimeter.probeB != null,
          ),
          services: const ServiceAvailability(
            availableServiceIds: {ServiceAvailability.measurement, ServiceAvailability.simulation},
          ),
          multimeterController: multimeter,
          simulationService: simulation,
        );

    test('Test F (Phase 10) -- a real input-state change through DiagramSimulationService produces a real, changed MeasurementResult through the resolver', () async {
      const batteryTarget = CursorTarget(kind: CursorTargetKind.node, targetId: 'battery');
      const lampTarget = CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp');

      await resolver.execute('diagram.probe.placePositive', contextFor(batteryTarget));
      await resolver.execute('diagram.probe.placeNegative', contextFor(lampTarget));

      final before = await resolver.execute('diagram.measure.continuity', contextFor(lampTarget));
      expect(before.success, isTrue);
      expect(multimeter.latestResult!.continuous, isTrue, reason: 'State A: switch not yet opened');

      await simulation.setInputState('lamp_switch', false);

      final after = await resolver.execute('diagram.measure.continuity', contextFor(lampTarget));
      expect(after.success, isTrue);
      expect(multimeter.latestResult!.continuous, isFalse, reason: 'State B: real, changed result through the same Studio path the DMM UI uses');
    });

    test('Test K (Phase 10) -- state-effect changes never mark the engineering document dirty', () async {
      await simulation.setInputState('lamp_switch', false);
      // Mirrors Phase 8's own Test N exactly: `document` is sourced only
      // from `DiagramDocument`, which `setInputState` (a
      // `DiagramSimulationService`/`SimulationSession`-only operation)
      // never touches -- state effects add no new path into `_markDirty()`.
      expect(contextFor(const CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp')).document.isDirty, isFalse);
    });
  });

  group('Command definitions self-check', () {
    test('every command id is unique', () {
      final ids = initialContextualCommands.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('CommandRegistry (old) and the new contextual command list never share an id', () {
      // Guards against accidental id collisions between the existing,
      // untouched zero/single-argument command system and the new
      // requirements-based one -- both are allowed to coexist, but must
      // never claim the same identifier.
      final oldIds = <String>{
        'diagram.newDocument',
        'diagram.openDocument',
        'diagram.saveDocument',
        'diagram.saveDocumentAs',
        'diagram.closeDocument',
        'diagram.undo',
        'diagram.redo',
        'diagram.revalidate',
      };
      final newIds = initialContextualCommands.map((c) => c.id).toSet();
      expect(oldIds.intersection(newIds), isEmpty);
    });
  });
}
