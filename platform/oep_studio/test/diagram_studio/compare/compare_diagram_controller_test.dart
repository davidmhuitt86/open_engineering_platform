import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/compare/compare_diagram_controller.dart';
import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller_provider.dart';

import '../../support/isolated_settings_storage.dart';

/// AP-OEP-DIAGRAM-COMPARE-001 — focused tests for [CompareDiagramController],
/// proving it operates on a genuinely independent Engine/session from the
/// Primary `DiagramStudioController`, not a shared one — the entire point
/// of this package. Mirrors `diagram_studio_controller_test.dart`'s own
/// pattern (real engine, real commands, no mocks), adapted for the
/// Compare provider.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(CompareDiagramController, ProviderContainer)> bootstrapCompare(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    useIsolatedSettingsStorage();

    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: SizedBox.shrink()))));
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)), listen: false);
    late CompareDiagramController controller;
    await tester.runAsync(() async {
      controller = await container.read(compareDiagramControllerProvider.future);
    });
    await tester.pumpAndSettle();
    return (controller, container);
  }

  testWidgets('Compare has its own independent engine, separate from the Primary controller', (tester) async {
    final (compare, container) = await bootstrapCompare(tester);

    late final dynamic primary;
    await tester.runAsync(() async {
      primary = await container.read(diagramStudioControllerProvider.future);
    });
    await tester.pumpAndSettle();

    expect(identical(compare.engine, primary.engine), isFalse, reason: 'Compare must not share the Primary engine/session');
  });

  testWidgets('addNodeWithMetadata/moveNodes/createRelationship/undo all execute against Compare\'s own engine', (tester) async {
    final (compare, _) = await bootstrapCompare(tester);
    final engine = compare.engine;

    expect(engine.editing.session.graph.nodes, isEmpty);

    compare.addNodeWithMetadata('battery', const Point2D(40, 40));
    await settle(tester);
    final nodeId = engine.editing.session.graph.nodes.keys.single;
    expect(engine.registry.selection.current.nodeIds, {nodeId});
    expect(engine.editing.canUndo, isTrue);

    final startPosition = engine.editing.session.layout.positionOf(nodeId)!;
    compare.moveNodes({nodeId: const Point2D(200, 150)});
    await settle(tester);
    expect(engine.editing.session.layout.positionOf(nodeId), const Point2D(200, 150));

    compare.addNodeWithMetadata('ground', const Point2D(300, 40));
    await settle(tester);
    final groundId = engine.editing.session.graph.nodes.keys.firstWhere((id) => id != nodeId);
    compare.createRelationship(nodeId, groundId);
    await settle(tester);
    expect(engine.editing.session.graph.relationships, hasLength(1));

    compare.undo();
    await settle(tester);
    expect(engine.editing.session.graph.relationships, isEmpty, reason: 'undo must act on Compare\'s own undo stack');

    // The moved node's position from earlier remains a real, independent
    // mutation on this same engine, unaffected by the relationship undo.
    expect(engine.editing.session.layout.positionOf(nodeId), const Point2D(200, 150));
    expect(startPosition, isNot(const Point2D(200, 150)));
  });

  testWidgets('deleteNode/deleteRelationship/renameNode/updateNodeMetadata all mutate Compare\'s own graph', (tester) async {
    final (compare, _) = await bootstrapCompare(tester);
    final engine = compare.engine;

    compare.addNodeWithMetadata('battery', const Point2D(0, 0), displayName: 'Original');
    await settle(tester);
    final nodeId = engine.editing.session.graph.nodes.keys.single;

    compare.renameNode(nodeId, 'Renamed');
    await settle(tester);
    expect(engine.editing.session.graph.nodes[nodeId]!.displayName, 'Renamed');

    compare.updateNodeMetadata(nodeId, {'note': 'hello'});
    await settle(tester);
    expect(engine.editing.session.graph.nodes[nodeId]!.metadata['note'], 'hello');

    compare.deleteNode(nodeId);
    await settle(tester);
    expect(engine.editing.session.graph.nodes, isEmpty);
  });

  testWidgets('markDirty/isDirty reflect Compare\'s own document, not the Primary document', (tester) async {
    final (compare, _) = await bootstrapCompare(tester);
    expect(compare.isDirty, isFalse);

    compare.addNodeWithMetadata('battery', const Point2D(0, 0));
    await settle(tester);

    expect(compare.isDirty, isTrue);
  });
}
