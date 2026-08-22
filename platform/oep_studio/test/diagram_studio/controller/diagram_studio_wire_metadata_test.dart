import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/core/services/engineering_project_service.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// Focused coverage for AP-DIAGRAM-V2-006's Wire Metadata Editor,
/// controller layer — verifies
/// `DiagramStudioController.updateRelationshipMetadata` (the existing
/// `UpdateRelationshipPropertiesCommand` routed through the controller's
/// own centralized command/dirty pathway, not a new mutation mechanism).
///
/// AP-DIAGRAM-V2-BRIDGE-010 — the native-renderer scene-adapter
/// visibility step this test used to include (re-confirming the mutated
/// graph was a valid input to `adaptDiagramScene`) was removed along
/// with `diagram_scene_adapter.dart` itself when the native renderer was
/// retired; the metadata-mutation/undo/redo/dirty-state coverage below,
/// which is what actually matters to the bridge, is unchanged.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'updateRelationshipMetadata: real command execution, undo/redo, clearing, dirty-state',
    (tester) async {
      useIsolatedSettingsStorage();

      final (controller, container) = await bootstrapDiagramStudioController(tester);
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

      // --- A. Missing metadata: label/wireColor are null before any edit ---
      final initial = engine.editing.session.graph.relationships[wireId]!;
      expect(initial.metadata['label'], isNull);
      expect(initial.metadata['wireColor'], isNull);

      // --- C/D. Label + color mutation via the real command -----------------
      controller.updateRelationshipMetadata(wireId, {'label': 'TEST LABEL', 'wireColor': '#FF0000'});
      await settle(tester);
      final afterEdit = engine.editing.session.graph.relationships[wireId]!;
      expect(afterEdit.metadata['label'], 'TEST LABEL');
      expect(afterEdit.metadata['wireColor'], '#FF0000');
      expect(container.read(engineeringProjectServiceProvider).isDirty, isTrue, reason: 'a real metadata mutation must dirty the document through the same centralized markDirty() pathway as every other edit');

      // --- F. Undo restores the previous (null) metadata ---------------------
      controller.undo();
      await settle(tester);
      final afterUndo = engine.editing.session.graph.relationships[wireId]!;
      expect(afterUndo.metadata['label'], isNull);
      expect(afterUndo.metadata['wireColor'], isNull);

      // --- G. Redo restores the edited state ----------------------------------
      controller.redo();
      await settle(tester);
      final afterRedo = engine.editing.session.graph.relationships[wireId]!;
      expect(afterRedo.metadata['label'], 'TEST LABEL');
      expect(afterRedo.metadata['wireColor'], '#FF0000');

      // --- E. Clearing removes the metadata key (patch value null) -----------
      controller.updateRelationshipMetadata(wireId, {'label': null});
      await settle(tester);
      final afterClear = engine.editing.session.graph.relationships[wireId]!;
      expect(afterClear.metadata.containsKey('label'), isFalse, reason: 'a null patch value must remove the key entirely, matching UpdateRelationshipPropertiesCommand\'s own documented convention');
      expect(afterClear.metadata['wireColor'], '#FF0000', reason: 'clearing one key must not disturb the other');
    },
  );
}
