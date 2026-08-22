import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// AP-DIAGRAM-V2-011's mandatory "Node Movement Test" (task Phase 11) —
/// empirically demonstrates, against the real Engine (not just by
/// reading source), the exact route-model incompatibility this task's
/// completion report classifies as CASE C: once a wire has a manual
/// route override (`SetWireRouteCommand`, the existing command behind
/// `DiagramStudioController.setWireRoute`), moving a connected node does
/// **not** reflow that route — the stored absolute points remain
/// exactly as set. This is the opposite of V2's own model (`renderer.js`'s
/// `route()`: the base path is *always* recomputed from current node
/// positions, with V2's differential `wireRoutes` offsets reapplied on
/// top of the fresh path every time) — see
/// `docs/DIAGRAM_STUDIO_V2_RENDERER_IMPLEMENTATION_PLAN.md`'s wire-edit
/// model section for the full analysis this test backs up.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'a manually-routed wire override does not reflow when a connected node moves (CASE C evidence)',
    (tester) async {
      useIsolatedSettingsStorage();

      final (controller, _) = await bootstrapDiagramStudioController(tester);
      final EngineeringEngine engine = controller.engine;

      controller.addNode('battery', const Point2D(40, 40));
      await settle(tester);
      final firstId = engine.editing.session.graph.nodes.keys.single;
      controller.addNode('ground', const Point2D(300, 40));
      await settle(tester);
      final secondId = engine.editing.session.graph.nodes.keys.firstWhere((id) => id != firstId);
      final beforeRelIds = Set<String>.from(engine.editing.session.graph.relationships.keys);
      controller.createRelationship(firstId, secondId);
      await settle(tester);
      final wireId = engine.editing.session.graph.relationships.keys.toSet().difference(beforeRelIds).single;

      // A manual multi-segment route override -- the exact operation the
      // existing wire-edit interaction commits via `WireEditHandles`.
      const manualRoute = [
        Point2D(90, 40),
        Point2D(90, 100),
        Point2D(250, 100),
        Point2D(250, 40),
        Point2D(300, 40),
      ];
      controller.setWireRoute(wireId, manualRoute);
      await settle(tester);
      expect(engine.editing.session.layout.wireOverrideOf(wireId), manualRoute);

      // Move the connected node far away.
      controller.moveNodes({firstId: const Point2D(900, 900)});
      await settle(tester);

      // CASE C evidence: the override is still the exact same stale
      // absolute points -- it did not reflow to reach the node's new
      // position. This is the opposite of V2's own always-recomputed
      // base path.
      expect(
        engine.editing.session.layout.wireOverrideOf(wireId),
        manualRoute,
        reason: 'OEP wire overrides are terminal absolute points -- MoveNodesCommand never touches wireOverrides, '
            'so a manually-routed wire does not reflow when its connected node moves. This is the exact model '
            'incompatibility documented as CASE C: V2 always recomputes the base path from current node positions.',
      );

      // The node itself genuinely did move -- proving the mismatch is
      // real, not an artifact of the move failing.
      expect(engine.editing.session.layout.positionOf(firstId), const Point2D(900, 900));
    },
  );
}
