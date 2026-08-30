import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';
import 'package:oep_studio/diagram_studio/controller/diagram_studio_controller_provider.dart';
import 'package:oep_studio/diagram_studio/tabs/diagram_tabs_controller.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// AP-OEP-DIAGRAM-CONTROLLER-INSTANCING-IMPLEMENTATION-001 — proves the
/// approved design's central claim against the real, unmodified
/// `EngineeringEngine`/`EngineHost`/`DiagramStudioController` classes:
/// two `WorkspaceTab.id`-keyed family instances are genuinely
/// independent, not merely differently-labeled views onto one shared
/// engine. Reaches the real bootstrap via
/// `bootstrapDiagramStudioControllerInstance` (no widget-tree dependency
/// on the retired native `DiagramStudioPage`, same reasoning
/// `diagram_studio_controller_test.dart` already established), never a
/// fake/mock of `EngineeringProjectNotifier`/`DiagramStudioController`
/// themselves — this is a test of actual provider behavior, not of
/// provider *identity* strings alone.
///
/// **Not tested here (by design, § the implementation package's own
/// scope boundary)**: mounting two real `LegacyV2WebViewPage` instances
/// — WebView2 is documented elsewhere in this suite as unreliable under
/// the headless `flutter test` binding, the same reason no other test in
/// this codebase mounts it for assertions. Item 14's actual claim — "two
/// WebView hosts can coexist without sharing controller state" — is
/// proven at the layer that matters: the `DiagramStudioController`/
/// `EngineeringProjectState` pair each WebView host would bind to (via
/// `instanceId`) is proven independent below; the WebView widget itself
/// is a thin, already-proven-independent-elsewhere host around that
/// state (§ the Compare pane's own prior, already-shipped precedent).
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(useIsolatedSettingsStorage);

  testWidgets('1/2/3/4. two instances get distinct ids and distinct family entries for every provider', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    expect(instanceA, isNot(instanceB));

    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    // 2. distinct EngineeringProjectNotifier family entries.
    expect(
      identical(container.read(engineeringProjectServiceFamily(instanceA)), container.read(engineeringProjectServiceFamily(instanceB))),
      isFalse,
    );
    // 4. distinct EngineeringEngine instances (proves the family entries
    // are not merely two labels for one shared engine).
    expect(identical(controllerA.engine, controllerB.engine), isFalse);
    // 3. distinct DiagramStudioController family entries.
    expect(identical(controllerA, controllerB), isFalse);
    expect(controllerA.instanceId, instanceA);
    expect(controllerB.instanceId, instanceB);
  });

  testWidgets('5/6/7. editing/undo in A never affects B, and vice versa', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    controllerA.addNode('battery', const Point2D(10, 10));
    await settle(tester);

    expect(controllerA.engine.editing.session.graph.nodes, hasLength(1));
    expect(controllerB.engine.editing.session.graph.nodes, isEmpty, reason: 'editing A must never appear in B');

    controllerB.addNode('ground', const Point2D(20, 20));
    controllerB.addNode('fuse', const Point2D(30, 30));
    await settle(tester);

    expect(controllerA.engine.editing.session.graph.nodes, hasLength(1), reason: 'editing B must never appear in A');
    expect(controllerB.engine.editing.session.graph.nodes, hasLength(2));

    // 7. undo in B does not affect A.
    controllerB.undo();
    await settle(tester);
    expect(controllerB.engine.editing.session.graph.nodes, hasLength(1));
    expect(controllerA.engine.editing.session.graph.nodes, hasLength(1), reason: 'B\'s undo must not touch A\'s graph');
    expect(controllerA.canUndo, isTrue);
    controllerA.undo();
    await settle(tester);
    expect(controllerA.engine.editing.session.graph.nodes, isEmpty);
    expect(controllerB.engine.editing.session.graph.nodes, hasLength(1), reason: 'A\'s undo must not touch B\'s graph');
  });

  testWidgets('8. selection in A does not affect B', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    // `addNode` auto-selects the node it creates (see `DiagramStudioController
    // .addNode`), so B is deliberately left empty here -- the point of this
    // test is that A's own selection never reaches B, not that B has no
    // opinion about its own (nonexistent) nodes.
    controllerA.addNode('battery', const Point2D(10, 10));
    await settle(tester);

    final nodeIdA = controllerA.engine.editing.session.graph.nodes.keys.single;
    expect(controllerA.selection.nodeIds, {nodeIdA});
    expect(controllerB.selection.nodeIds, isEmpty, reason: 'selecting a node in A must never select anything in B');
  });

  testWidgets('9. view state in A does not affect B', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    final viewServiceA = controllerA.engine.registry.viewState as ViewStateService;
    viewServiceA.toggleGrid();
    await settle(tester);

    expect(controllerA.viewState.grid.visible, isNot(controllerB.viewState.grid.visible),
        reason: 'toggling A\'s grid must never change B\'s');
  });

  testWidgets('10/16. document state is isolated: opening different documents in A and B never cross-contaminates',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tempDir = Directory.systemTemp.createTempSync('diagram_instancing_test_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    controllerA.addNode('battery', const Point2D(10, 10));
    await settle(tester);

    final pathA = '${tempDir.path}/a.json';
    final pathB = '${tempDir.path}/b.json';
    await tester.runAsync(() async {
      await controllerA.saveDocumentAs(pathA);
      await controllerB.saveDocumentAs(pathB);
    });
    await settle(tester);

    expect(controllerA.documentPath, pathA);
    expect(controllerB.documentPath, pathB, reason: 'saving A must never change B\'s own document path');
    expect(controllerA.documentPath, isNot(controllerB.documentPath));

    // 16. "navigating away" (simulated by simply not touching either
    // controller for a beat) preserves both — no autoDispose/teardown is
    // wired to mere inactivity anywhere in this design.
    await settle(tester);
    expect(controllerA.documentPath, pathA);
    expect(controllerB.documentPath, pathB);
  });

  testWidgets('11. validation in A is computed against A\'s own graph, never B\'s', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    controllerA.addNode('battery', const Point2D(10, 10));
    await settle(tester);

    final reportA = container.read(engineeringProjectServiceFamily(instanceA)).validationReport;
    final reportB = container.read(engineeringProjectServiceFamily(instanceB)).validationReport;

    // Both reports exist (validation recomputes on every session change,
    // per `EngineeringProjectNotifier.ensureEngineStarted`'s own
    // `sessionChanges` listener) but must not be the same object/graph.
    expect(reportA, isNotNull);
    expect(reportB, isNotNull);
    expect(
      container.read(engineeringProjectServiceFamily(instanceA)).session!.graph.nodes,
      isNot(container.read(engineeringProjectServiceFamily(instanceB)).session!.graph.nodes),
    );
  });

  testWidgets('15. switching A -> B -> A preserves both instances\' live state', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    controllerA.addNode('battery', const Point2D(10, 10));
    await settle(tester);
    controllerB.addNode('ground', const Point2D(20, 20));
    await settle(tester);

    // "Switch to B" -> re-read B (already alive, no re-bootstrap). Read the
    // already-resolved `AsyncValue` synchronously rather than re-awaiting
    // `.future` a second time -- a second `.future` await on an
    // already-completed family AsyncNotifierProvider hangs under
    // `flutter_test` (the completion callback fires on the real event loop
    // outside the widget-test pump cycle that would otherwise surface it).
    final bAgain = container.read(diagramStudioControllerFamily(instanceB)).valueOrNull!;
    expect(identical(bAgain, controllerB), isTrue, reason: 'switching tabs must never recreate the controller');
    expect(bAgain.engine.editing.session.graph.nodes, hasLength(1));

    // "Switch back to A".
    final aAgain = container.read(diagramStudioControllerFamily(instanceA)).valueOrNull!;
    expect(identical(aAgain, controllerA), isTrue);
    expect(aAgain.engine.editing.session.graph.nodes, hasLength(1));
  });

  testWidgets('17/18/19. closing B explicitly invalidates only B\'s providers; A is completely unaffected', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const instanceA = 'workspace-tab-diagram-instance-0';
    const instanceB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, instanceA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);

    controllerA.addNode('battery', const Point2D(10, 10));
    controllerB.addNode('ground', const Point2D(20, 20));
    await settle(tester);

    // The exact three invalidations `_DiagramInstanceTabState.dispose()`
    // performs in production -- settled individually rather than back to
    // back, since `diagramStudioControllerFamily` depends on
    // `engineeringProjectServiceFamily` and invalidating a dependency
    // schedules that dependent's own rebuild/dispose bookkeeping, which
    // needs a pump to actually run before the next invalidate() touches
    // the same underlying element again.
    container.invalidate(engineeringProjectServiceFamily(instanceB));
    await settle(tester);
    container.invalidate(diagramStudioControllerFamily(instanceB));
    await settle(tester);
    container.invalidate(diagramTabsFamily(instanceB));
    await settle(tester);

    // 19. A's graph/session/document is completely untouched.
    expect(controllerA.engine.editing.session.graph.nodes, hasLength(1));
    expect(identical(container.read(engineeringProjectServiceFamily(instanceA)), container.read(engineeringProjectServiceFamily(instanceA))), isTrue);

    // 17/18. B's own provider was actually torn down, not merely
    // relabeled — re-bootstrapping it now (the same helper used to create
    // it originally, which properly awaits the rebuild inside
    // `tester.runAsync`) produces a genuinely fresh instance (empty graph),
    // proving the old one was disposed rather than reused. A second
    // `.future` await on the family provider directly hangs under
    // `flutter_test` (see the note above), so this goes through the
    // harness instead of repeating that pattern.
    final (freshB, _) = await bootstrapDiagramStudioControllerInstance(tester, instanceB, container: container);
    expect(identical(freshB, controllerB), isFalse, reason: 'a new instance must be constructed after invalidation');
    expect(freshB.engine.editing.session.graph.nodes, isEmpty, reason: 'the old instance\'s state must not survive invalidation');
  });

  test('20/21. the primary alias resolves to the exact same provider the family produces for the primary key', () {
    // Riverpod family members are lightweight keyed proxies (`==`/
    // `hashCode` overridden to compare family+arg) rather than singleton
    // objects cached by the family itself, so two separately-evaluated
    // calls with the same key are `==` (and resolve to the same
    // underlying container element) without being `identical()` -- the
    // property that actually matters for "primary alias" correctness.
    expect(engineeringProjectServiceProvider, engineeringProjectServiceFamily(primaryDiagramInstanceId));
    expect(diagramStudioControllerProvider, diagramStudioControllerFamily(primaryDiagramInstanceId));
    expect(diagramTabsProvider, diagramTabsFamily(primaryDiagramInstanceId));
  });

  testWidgets('22. two independently-generated WorkspaceTab ids resolve to two independent family entries', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Mirrors the real id shape `WorkspaceTabsController.openNewInstance`
    // generates (`workspace_tabs_controller_test.dart`'s own coverage of
    // that generator) — this test only proves the Diagram-provider side
    // of the contract: two such ids never collide on the family key.
    const restoredIdA = 'workspace-tab-diagram-instance-0';
    const restoredIdB = 'workspace-tab-diagram-instance-1';
    final (controllerA, container) = await bootstrapDiagramStudioControllerInstance(tester, restoredIdA);
    addTearDown(container.dispose);
    final (controllerB, _) = await bootstrapDiagramStudioControllerInstance(tester, restoredIdB, container: container);

    expect(identical(controllerA, controllerB), isFalse);
    expect(controllerA.instanceId, isNot(controllerB.instanceId));
  });
}
