import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/context/contextual_command_definitions.dart';
import 'package:oep_studio/core/context/contextual_command_resolver.dart';
import 'package:oep_studio/core/context/engineering_interaction_context.dart';

/// User-requested: "when I click on a pin or port while in edit mode. it
/// should give me the option to Add a label to it", plus full parity
/// with the legacy sim's own node/wire context menu, which always
/// offers a real Delete this build's menu previously never had.
///
/// These commands are the first in `initialContextualCommands` that
/// perform a real *document* edit (as opposed to driving a runtime
/// controller like the DMM), which is why `EngineeringInteractionContext`
/// gained an `engine` reference -- these tests prove they mutate the
/// real, shared editing session rather than a copy.
void main() {
  final resolver = ContextualCommandResolver(commands: initialContextualCommands);

  const battery = EngineeringNode(
    id: 'battery',
    category: NodeCategory.component,
    displayName: 'Battery',
    ports: [
      Port(id: 'positive', name: 'BATT+'),
      Port(id: 'negative', name: 'GND'),
    ],
  );
  const lamp = EngineeringNode(id: 'lamp', category: NodeCategory.component, displayName: 'Lamp');
  const wire = EngineeringRelationship(
    id: 'rel-1',
    relationshipType: RelationshipType.connectedTo,
    sourceNode: 'battery',
    targetNode: 'lamp',
  );

  ({EngineeringEngine engine, EngineeringInteractionContext Function(CursorTarget) contextFor}) setUp$({
    DiagramStudioMode mode = DiagramStudioMode.edit,
  }) {
    final graph = EngineeringGraph(
      id: 'g',
      nodes: const {'battery': battery, 'lamp': lamp},
      relationships: const {'rel-1': wire},
    );
    final engine = EngineeringEngine.create();
    engine.beginEditingSession(graph);

    EngineeringInteractionContext contextFor(CursorTarget target) => EngineeringInteractionContext(
          diagram: const DiagramContext(diagramOpen: true, editable: true),
          mode: mode,
          cursorTarget: target,
          graph: engine.editing.session.graph,
          layout: engine.editing.session.layout,
          engine: engine,
          services: const ServiceAvailability(availableServiceIds: {ServiceAvailability.engineeringEngine}),
        );

    return (engine: engine, contextFor: contextFor);
  }

  const portTarget = CursorTarget(kind: CursorTargetKind.port, targetId: 'positive', ownerNodeId: 'battery');
  const nodeTarget = CursorTarget(kind: CursorTargetKind.node, targetId: 'lamp');
  const wireTarget = CursorTarget(kind: CursorTargetKind.relationship, targetId: 'rel-1');

  group('Add Label (port targets, Edit mode)', () {
    test('is applicable on a port in Edit mode', () {
      final env = setUp$();
      final resolved = resolver
          .resolveCommands(env.contextFor(portTarget))
          .where((r) => r.descriptor.id == 'diagram.port.addLabel')
          .single;
      expect(resolved.visibility, isNot(CommandVisibility.hidden));
    });

    test('disappears entirely for a node target -- a label belongs to a pin, not a whole component', () {
      final env = setUp$();
      final resolved = resolver
          .resolveCommands(env.contextFor(nodeTarget))
          .where((r) => r.descriptor.id == 'diagram.port.addLabel')
          .single;
      expect(resolved.visibility, CommandVisibility.hidden);
    });

    test('disappears entirely in View mode (Edit-only, per the user request)', () {
      final env = setUp$(mode: DiagramStudioMode.view);
      final resolved = resolver
          .resolveCommands(env.contextFor(portTarget))
          .where((r) => r.descriptor.id == 'diagram.port.addLabel')
          .single;
      expect(resolved.visibility, CommandVisibility.hidden);
    });

    test('creates a real portLabel annotation anchored to the real port, prefilled with the port\'s own real name', () async {
      final env = setUp$();
      expect(env.engine.editing.session.layout.annotations, isEmpty);

      final result = await resolver.execute('diagram.port.addLabel', env.contextFor(portTarget));
      expect(result.success, isTrue);

      final annotation = env.engine.editing.session.layout.annotations.values.single;
      expect(annotation.type, AnnotationType.portLabel);
      expect(annotation.anchorPortId, 'positive');
      expect(annotation.anchorNodeId, 'battery', reason: 'a port id alone is not unique across the graph');
      expect(annotation.text, 'BATT+', reason: "the port's own real name, not a fabricated placeholder");
    });

    test('is undoable through the same real editing session', () async {
      final env = setUp$();
      await resolver.execute('diagram.port.addLabel', env.contextFor(portTarget));
      expect(env.engine.editing.session.layout.annotations, hasLength(1));

      env.engine.editing.undo();
      expect(env.engine.editing.session.layout.annotations, isEmpty,
          reason: 'the command went through the real EditingService, not a direct layout mutation');
    });
  });

  group('Delete (node / wire / annotation targets, Edit mode)', () {
    test('deletes a real node from the real session', () async {
      final env = setUp$();
      expect(env.engine.editing.session.graph.nodes.containsKey('lamp'), isTrue);

      final result = await resolver.execute('diagram.object.delete', env.contextFor(nodeTarget));
      expect(result.success, isTrue);
      expect(env.engine.editing.session.graph.nodes.containsKey('lamp'), isFalse);
    });

    test('deletes a real wire from the real session', () async {
      final env = setUp$();
      expect(env.engine.editing.session.graph.relationships.containsKey('rel-1'), isTrue);

      final result = await resolver.execute('diagram.object.delete', env.contextFor(wireTarget));
      expect(result.success, isTrue);
      expect(env.engine.editing.session.graph.relationships.containsKey('rel-1'), isFalse);
    });

    test('is undoable', () async {
      final env = setUp$();
      await resolver.execute('diagram.object.delete', env.contextFor(nodeTarget));
      expect(env.engine.editing.session.graph.nodes.containsKey('lamp'), isFalse);

      env.engine.editing.undo();
      expect(env.engine.editing.session.graph.nodes.containsKey('lamp'), isTrue);
    });

    test('disappears entirely for a port target -- a pin is not independently deletable', () {
      final env = setUp$();
      final resolved = resolver
          .resolveCommands(env.contextFor(portTarget))
          .where((r) => r.descriptor.id == 'diagram.object.delete')
          .single;
      expect(resolved.visibility, CommandVisibility.hidden);
    });

    test('disappears entirely in View mode', () {
      final env = setUp$(mode: DiagramStudioMode.view);
      final resolved = resolver
          .resolveCommands(env.contextFor(nodeTarget))
          .where((r) => r.descriptor.id == 'diagram.object.delete')
          .single;
      expect(resolved.visibility, CommandVisibility.hidden);
    });
  });

  group('Add Annotation now has a real executor', () {
    test('creates a real annotation (closing the previously-documented "no executor yet" gap)', () async {
      final env = setUp$();
      final result = await resolver.execute('diagram.annotate.add', env.contextFor(const CursorTarget.none()));
      expect(result.success, isTrue);
      expect(env.engine.editing.session.layout.annotations, hasLength(1));
    });
  });
}
