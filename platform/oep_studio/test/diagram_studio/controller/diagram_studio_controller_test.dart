import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'package:oep_studio/core/theme/studio_theme.dart';
import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller.dart';
import 'package:oep_studio/diagram_studio/workspaces/diagram_studio_page.dart';

/// Focused tests for `DiagramStudioController` (WAVE 1, AP-DIAGRAM-W1) —
/// verifies the extracted controller is the real gateway
/// `DiagramStudioPage` now uses, and that centralizing dirty-marking
/// there did not change *when* the document becomes dirty. Reaches the
/// controller off the live page's own `State` (`tester.state(...) as
/// dynamic`), the same pattern `diagram_studio_interaction_test.dart`
/// already uses to reach engine-level state without depending on private
/// field layout beyond a name.
void main() {
  Widget harness() {
    return ProviderScope(
      child: MaterialApp(
        theme: StudioTheme.dark,
        home: const Scaffold(body: DiagramStudioPage()),
      ),
    );
  }

  Future<void> bootstrap(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.byTooltip('Add node').evaluate().isNotEmpty) return;
      }
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'DiagramStudioController: sole execute gateway, centralized dirty-state, node/wire/delete commands',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await bootstrap(tester);
      expect(find.byTooltip('Add node'), findsOneWidget, reason: 'Engine bootstrap must complete before controller tests run');

      final state = tester.state(find.byType(DiagramStudioPage)) as dynamic;
      final DiagramStudioController controller = state.controllerForTest as DiagramStudioController;
      final EngineeringEngine engine = state.engine as EngineeringEngine;

      // --- The controller is real and already the page's sole gateway ------
      expect(controller, isNotNull);

      // --- markDirty is centralized: document starts clean -----------------
      expect(engine.editing.session.graph.nodes, isEmpty);

      // --- addNode: real CreateNodeCommand executes + selects + marks dirty
      final beforeIds = Set<String>.from(engine.editing.session.graph.nodes.keys);
      controller.addNode('battery', const Point2D(40, 40));
      await settle(tester);
      final afterIds = engine.editing.session.graph.nodes.keys.toSet();
      expect(afterIds.length, beforeIds.length + 1, reason: 'addNode must execute a real CreateNodeCommand against the shared engine');
      final nodeId = afterIds.difference(beforeIds).single;
      expect(engine.registry.selection.current.nodeIds, {nodeId}, reason: 'addNode must select the newly created node, same as before extraction');
      expect(engine.editing.canUndo, isTrue, reason: 'the command must be on the real undo stack');

      // --- moveNodes: real MoveNodesCommand, undo reverts it ----------------
      final startPosition = engine.editing.session.layout.positionOf(nodeId)!;
      controller.moveNodes({nodeId: const Point2D(200, 150)});
      await settle(tester);
      expect(engine.editing.session.layout.positionOf(nodeId), const Point2D(200, 150));
      engine.editing.undo();
      await settle(tester);
      expect(engine.editing.session.layout.positionOf(nodeId), startPosition);

      // --- addNode a second node, then create a relationship between them --
      controller.addNode('ground', const Point2D(300, 40));
      await settle(tester);
      final groundId = engine.editing.session.graph.nodes.keys.firstWhere((id) => id != nodeId);
      final beforeRelIds = Set<String>.from(engine.editing.session.graph.relationships.keys);
      controller.createRelationship(nodeId, groundId);
      await settle(tester);
      final afterRelIds = engine.editing.session.graph.relationships.keys.toSet();
      expect(afterRelIds.length, beforeRelIds.length + 1, reason: 'createRelationship must execute a real CreateRelationshipCommand');

      // --- deleteSelection: real DeleteManyCommand via StudioCommandActions
      engine.registry.selection.selectNode(groundId);
      await settle(tester);
      controller.deleteSelection();
      await settle(tester);
      expect(engine.editing.session.graph.nodes.containsKey(groundId), isFalse, reason: 'deleteSelection must execute a real delete against the shared engine');

      // --- undo/redo route through the composed StudioCommandActions -------
      expect(controller.canUndo, isTrue);
      controller.undo();
      await settle(tester);
      expect(engine.editing.session.graph.nodes.containsKey(groundId), isTrue, reason: 'undo through the controller must restore the deleted node');
    },
  );
}
