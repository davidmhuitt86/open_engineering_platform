import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/models/engineering_inspectable.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// Regression coverage for AP-DIAGRAM-W2-B (Wave 2 Stage B — Subscription
/// Boundary Extraction), updated for AP-DIAGRAM-V2-BRIDGE-010.
///
/// The original version of this test covered two independent
/// subscriptions the retired native `DiagramStudioPage` used to own:
/// selection→Property-Inspector sync, and selection→wire-edit-mode
/// point reseeding. The second was genuinely native-canvas-specific
/// (wire-edit mode does not exist without the canvas) and was retired
/// along with the page, not moved anywhere — there is nothing left to
/// test. The first, selection→Property-Inspector sync, is real,
/// UI-independent business logic the shared, cross-Studio
/// `PropertyInspectorPanel` still needs regardless of which surface
/// changes the selection (native canvas, previously; the V2 bridge's
/// `GraphSelection` mirroring, now) — this task's own extraction audit
/// confirmed it was not yet moved, and moved it into
/// `DiagramStudioController.bootstrap` (§ that method's own doc comment
/// on the subscription it now owns). This file now verifies that
/// controller-owned subscription directly.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'DiagramStudioController: selection changes sync the shared Property Inspector',
    (tester) async {
      useIsolatedSettingsStorage();

      final (controller, container) = await bootstrapDiagramStudioController(tester);
      final EngineeringEngine engine = controller.engine;

      // Diffed against a snapshot rather than assuming an empty graph:
      // this environment's real, non-mocked `SettingsStorage.root()` may
      // have restored an actual persisted diagram with existing content.
      final nodesBeforeA = Set<String>.from(engine.editing.session.graph.nodes.keys);
      controller.addNode('battery', const Point2D(40, 40));
      await settle(tester);
      final nodeAId = engine.editing.session.graph.nodes.keys.toSet().difference(nodesBeforeA).single;

      final nodesBeforeB = Set<String>.from(engine.editing.session.graph.nodes.keys);
      controller.addNode('ground', const Point2D(300, 40));
      await settle(tester);
      final nodeBId = engine.editing.session.graph.nodes.keys.toSet().difference(nodesBeforeB).single;

      final relationshipsBefore = Set<String>.from(engine.editing.session.graph.relationships.keys);
      controller.createRelationship(nodeAId, nodeBId);
      await settle(tester);
      final relationshipId = engine.editing.session.graph.relationships.keys.toSet().difference(relationshipsBefore).single;

      // --- Selecting a node pushes it into the shared Property Inspector --
      engine.registry.selection.selectNode(nodeAId);
      await settle(tester);
      var inspectorState = container.read(foundationRuntimeServiceProvider);
      expect(inspectorState.selectedEngineeringInspectable?.kind, EngineeringInspectableKind.node);
      expect(inspectorState.selectedEngineeringInspectable?.node?.id, nodeAId);

      // --- Deselecting clears the Inspector --------------------------------
      engine.registry.selection.deselectAll();
      await settle(tester);
      inspectorState = container.read(foundationRuntimeServiceProvider);
      expect(inspectorState.selectedEngineeringInspectable, isNull);

      // --- Selecting a relationship pushes it into the Inspector too ------
      engine.registry.selection.selectRelationship(relationshipId);
      await settle(tester);
      inspectorState = container.read(foundationRuntimeServiceProvider);
      expect(inspectorState.selectedEngineeringInspectable?.kind, EngineeringInspectableKind.relationship);
      expect(inspectorState.selectedEngineeringInspectable?.relationship?.id, relationshipId);

      // --- A multi-selection clears the single-item Inspector (matches
      //     the pre-extraction `_selection.length != 1` guard) -----------
      engine.registry.selection.selectNode(nodeAId);
      await settle(tester);
      engine.registry.selection.selectNode(nodeBId, additive: true);
      await settle(tester);
      inspectorState = container.read(foundationRuntimeServiceProvider);
      expect(inspectorState.selectedEngineeringInspectable, isNull, reason: 'a multi-node selection has no single Inspectable to show');
    },
  );
}
