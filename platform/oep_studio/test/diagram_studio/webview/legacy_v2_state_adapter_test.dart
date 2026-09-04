import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/diagram_studio/simulation/diagram_simulation_service.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_bridge_transport.dart';
import 'package:oep_studio/diagram_studio/webview/legacy_v2_state_adapter.dart';

import '../../support/diagram_studio_controller_harness.dart';
import '../../support/isolated_settings_storage.dart';

/// AP-DIAGRAM-V2-WEBVIEW-001/002/003 — focused tests for
/// [LegacyV2StateAdapter] against a real, bootstrapped
/// [DiagramStudioController] (same harness pattern as
/// `diagram_studio_controller_test.dart`), with a lightweight fake
/// [LegacyV2Channel] standing in for the WebView transport — no
/// `WebviewController`/WebView internals are touched, per this task's own
/// "do not test V2 internals directly ... use the actual Controller/Engine
/// path" instruction.
///
/// Kept as a single `testWidgets` body (matching
/// `diagram_studio_controller_test.dart`'s own convention) — splitting
/// this into multiple `testWidgets` blocks, each re-running the full
/// `DiagramStudioController` bootstrap, was tried and produced
/// intermittent `controllerForTest` cast failures, apparently from
/// bootstrap state not being fully independent across sequential
/// `testWidgets` runs within one file.
class _FakeChannel implements LegacyV2Channel {
  void Function(V2ModuleMovedMessage message)? _onMoved;
  void Function(V2ModuleCreatedMessage message)? _onCreated;
  void Function(V2ModuleDeletedMessage message)? _onDeleted;
  void Function(V2ModulePropertiesChangedMessage message)? _onPropsChanged;
  void Function(V2WireCreatedMessage message)? _onWireCreated;

  final List<(String, double, double)> sentPositions = [];
  final List<(String, String)> sentLabels = [];
  final List<String> removedModules = [];
  final List<(String, String, String, double, double)> restoredModules = [];
  final List<(String, String, String)> confirmedWires = [];
  final List<String> removedWires = [];

  @override
  set onModuleMoved(void Function(V2ModuleMovedMessage message)? handler) =>
      _onMoved = handler;
  @override
  set onModuleCreated(void Function(V2ModuleCreatedMessage message)? handler) =>
      _onCreated = handler;
  @override
  set onModuleDeleted(void Function(V2ModuleDeletedMessage message)? handler) =>
      _onDeleted = handler;
  @override
  set onModulePropertiesChanged(
          void Function(V2ModulePropertiesChangedMessage message)? handler) =>
      _onPropsChanged = handler;
  @override
  set onWireCreated(void Function(V2WireCreatedMessage message)? handler) =>
      _onWireCreated = handler;
  @override
  set onWireDeleted(void Function(V2WireDeletedMessage message)? handler) =>
      _onWireDeleted = handler;
  @override
  set onWireSelectionChanged(
          void Function(V2WireSelectionChangedMessage message)? handler) =>
      _onWireSelectionChanged = handler;
  @override
  set onModuleSelectionChanged(
          void Function(V2ModuleSelectionChangedMessage message)? handler) =>
      _onModuleSelectionChanged = handler;
  @override
  set onWirePropertiesChanged(
          void Function(V2WirePropertiesChangedMessage message)? handler) =>
      _onWirePropertiesChanged = handler;
  @override
  set onMeasurementRequested(
          void Function(V2MeasurementRequestedMessage message)? handler) =>
      _onMeasurementRequested = handler;
  @override
  set onSaveRequested(void Function()? handler) => _onSaveRequested = handler;
  void Function()? _onSaveRequested;
  void Function(V2WireDeletedMessage message)? _onWireDeleted;
  void Function(V2WireSelectionChangedMessage message)? _onWireSelectionChanged;
  void Function(V2ModuleSelectionChangedMessage message)?
      _onModuleSelectionChanged;
  void Function(V2WirePropertiesChangedMessage message)?
      _onWirePropertiesChanged;
  void Function(V2MeasurementRequestedMessage message)? _onMeasurementRequested;

  final List<(String, String, String, String, String)> appliedMeasurements = [];

  @override
  Future<void> applyMeasurementResult(String v2WireId, String mode,
      String displayValue, String unit, String note) async {
    appliedMeasurements.add((v2WireId, mode, displayValue, unit, note));
  }

  @override
  Future<void> sendAuthoritativeModulePosition(
      String v2ModuleId, double x, double y) async {
    sentPositions.add((v2ModuleId, x, y));
  }

  @override
  Future<void> sendAuthoritativeModuleLabel(
      String v2ModuleId, String label) async {
    sentLabels.add((v2ModuleId, label));
  }

  @override
  Future<void> removeModuleFromV2(String v2ModuleId) async {
    removedModules.add(v2ModuleId);
  }

  @override
  Future<void> restoreModule(
      String v2ModuleId, String label, String category, double x, double y,
      {String notes = ''}) async {
    restoredModules.add((v2ModuleId, label, category, x, y));
  }

  @override
  Future<void> confirmWireCreated(
      String v2WireId, String label, String color) async {
    confirmedWires.add((v2WireId, label, color));
  }

  @override
  Future<void> removeWireFromV2(String v2WireId) async {
    removedWires.add(v2WireId);
  }

  final List<(String, String, String, String, String)> restoredWires = [];
  int clearAllSurfacesCallCount = 0;

  @override
  Future<void> restoreWire(String v2WireId, String fromModuleId,
      String toModuleId, String label, String color,
      {String fromTerminal = '', String toTerminal = ''}) async {
    restoredWires.add((v2WireId, fromModuleId, toModuleId, label, color));
  }

  @override
  Future<void> clearAllSurfaces() async {
    clearAllSurfacesCallCount++;
  }

  final List<String> saveResults = [];

  @override
  Future<void> interceptV2Save() async {}

  @override
  Future<void> reportSaveResult(bool success, String message) async {
    saveResults.add('$success:$message');
  }

  void simulateSaveRequested() => _onSaveRequested?.call();

  void simulateMove(String v2ModuleId, double x, double y) =>
      _onMoved?.call(V2ModuleMovedMessage(v2ModuleId: v2ModuleId, x: x, y: y));

  void simulateCreate(String v2ModuleId, String label, String category,
          double x, double y) =>
      _onCreated?.call(V2ModuleCreatedMessage(
          v2ModuleId: v2ModuleId,
          label: label,
          category: category,
          x: x,
          y: y));

  void simulateDelete(String v2ModuleId) =>
      _onDeleted?.call(V2ModuleDeletedMessage(v2ModuleId: v2ModuleId));

  void simulatePropertiesChanged(
          String v2ModuleId, String label, String category,
          {String notes = ''}) =>
      _onPropsChanged?.call(V2ModulePropertiesChangedMessage(
          v2ModuleId: v2ModuleId,
          label: label,
          category: category,
          notes: notes));

  void simulateWireCreated(
    String v2WireId,
    String fromModuleId,
    String fromTerminal,
    String toModuleId,
    String toTerminal,
    String label,
    String color,
  ) =>
      _onWireCreated?.call(V2WireCreatedMessage(
        v2WireId: v2WireId,
        fromModuleId: fromModuleId,
        fromTerminal: fromTerminal,
        toModuleId: toModuleId,
        toTerminal: toTerminal,
        label: label,
        color: color,
      ));

  void simulateWireDeleted(String v2WireId) =>
      _onWireDeleted?.call(V2WireDeletedMessage(v2WireId: v2WireId));

  void simulateWireSelectionChanged(String? v2WireId) => _onWireSelectionChanged
      ?.call(V2WireSelectionChangedMessage(v2WireId: v2WireId));

  void simulateModuleSelectionChanged(String? v2ModuleId) =>
      _onModuleSelectionChanged
          ?.call(V2ModuleSelectionChangedMessage(v2ModuleId: v2ModuleId));

  void simulateWirePropertiesChanged(
          String v2WireId, String label, String color) =>
      _onWirePropertiesChanged?.call(V2WirePropertiesChangedMessage(
          v2WireId: v2WireId, label: label, color: color));

  void simulateMeasurementRequested(String v2WireId, String mode) =>
      _onMeasurementRequested
          ?.call(V2MeasurementRequestedMessage(v2WireId: v2WireId, mode: mode));

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — the snapshot [flushBeforeSave] reads
  /// on the next `saveRequested`. `null` (the default) simulates "nothing
  /// to reconcile" (an empty snapshot), matching every other test in this
  /// file's convention of exercising the live per-message handlers
  /// directly rather than through the flush path unless a test says so.
  V2SaveSnapshot? nextSnapshot;
  int captureSaveSnapshotCallCount = 0;
  final List<(String, Map<String, double>)> restoredWireRouteOffsets = [];

  @override
  Future<V2SaveSnapshot?> captureSaveSnapshot() async {
    captureSaveSnapshotCallCount++;
    return nextSnapshot ??
        const V2SaveSnapshot(modules: {}, wires: {}, wireRoutes: {});
  }

  @override
  Future<void> restoreWireRouteOffsets(
      String v2WireId, Map<String, double> offsets) async {
    restoredWireRouteOffsets.add((v2WireId, offsets));
  }
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'LegacyV2StateAdapter: module create/delete/property-edit, symbol mapping gap, undo, move no-op',
    (tester) async {
      useIsolatedSettingsStorage();

      final (controller, _) = await bootstrapDiagramStudioController(tester);
      final EngineeringEngine engine = controller.engine;

      final channel = _FakeChannel();
      final adapter =
          LegacyV2StateAdapter(controller: controller, channel: channel);

      // AP-DIAGRAM-V2-BRIDGE-002 — the adapter now starts un-ready and
      // ignores every inbound message until `initializeFromDocument` has
      // run (Phase 7's race-prevention gate); the bootstrapped document
      // here is empty, so this just flips readiness without seeding
      // anything.
      expect(adapter.isReady, isFalse);
      await adapter.initializeFromDocument();
      expect(adapter.isReady, isTrue);

      // --- Module creation: "ground" has a deterministic symbol mapping --
      final before = engine.editing.session.graph.nodes.keys.toSet();
      channel.simulateCreate('gnd-1', 'Ground Point', 'ground', 10, 20);
      await settle(tester);
      final after = engine.editing.session.graph.nodes.keys.toSet();
      expect(after.length, before.length + 1,
          reason: 'a mapped category must create exactly one OEP node');
      final nodeId = after.difference(before).single;
      expect(adapter.oepNodeIdFor('gnd-1'), nodeId);
      expect(engine.editing.session.graph.nodes[nodeId]!.displayName,
          'Ground Point');
      expect(engine.editing.session.layout.positionOf(nodeId),
          const Point2D(10, 20));
      expect(channel.sentPositions.last, ('gnd-1', 10.0, 20.0));

      // --- "power" has NO deterministic symbol mapping — must not
      //     fabricate one; no node created, id recorded as unbridged -----
      final beforePower = engine.editing.session.graph.nodes.keys.toSet();
      channel.simulateCreate('pwr-1', 'Main Fuse Box', 'power', 30, 40);
      await settle(tester);
      expect(engine.editing.session.graph.nodes.keys.toSet(), beforePower,
          reason:
              'a category with no deterministic symbol mapping must not create a node');
      expect(adapter.oepNodeIdFor('pwr-1'), isNull);
      expect(adapter.unbridgedV2ModuleIds, contains('pwr-1'));

      // --- Re-sending a create for an already-mapped id is a no-op -------
      final beforeDup = engine.editing.session.graph.nodes.keys.toSet();
      channel.simulateCreate('gnd-1', 'Ground Point', 'ground', 10, 20);
      await settle(tester);
      expect(engine.editing.session.graph.nodes.keys.toSet(), beforeDup);

      // --- Move for an id that was never (or couldn't be) created is a
      //     no-op — the retired "auto-create via placeholder symbol on
      //     first move" behavior must not have come back -----------------
      final beforeMoveNoop = engine.editing.session.graph.nodes.keys.toSet();
      channel.simulateMove('pwr-1', 5, 5);
      await settle(tester);
      expect(engine.editing.session.graph.nodes.keys.toSet(), beforeMoveNoop);

      // --- A second mapped module, for the wire-creation tests below -----
      channel.simulateCreate('gnd-2', 'Second Ground', 'ground', 100, 100);
      await settle(tester);
      final secondNodeId = adapter.oepNodeIdFor('gnd-2')!;

      // --- Wire creation: both endpoints mapped -> real relationship -----
      final beforeRel = engine.editing.session.graph.relationships.keys.toSet();
      channel.simulateWireCreated(
          'wire-1', 'gnd-1', 'A', 'gnd-2', 'B', 'Bridging Wire', 'G');
      await settle(tester);
      final afterRel = engine.editing.session.graph.relationships.keys.toSet();
      expect(afterRel.length, beforeRel.length + 1,
          reason:
              'both endpoints mapped must create exactly one OEP relationship');
      final relationshipId = afterRel.difference(beforeRel).single;
      expect(adapter.oepRelationshipIdFor('wire-1'), relationshipId);
      final relationship =
          engine.editing.session.graph.relationships[relationshipId]!;
      expect(relationship.sourceNode, nodeId);
      expect(relationship.targetNode, secondNodeId);
      expect(relationship.metadata['label'], 'Bridging Wire');
      expect(relationship.metadata['wireColor'], 'G');
      expect(channel.confirmedWires.last, ('wire-1', 'Bridging Wire', 'G'));
      // AP-DIAGRAM-V2-BRIDGE-011 — terminal identity bridged via the
      // existing sourcePort/targetPort metadata convention.
      expect(relationship.metadata['sourcePort'], 'A');
      expect(relationship.metadata['targetPort'], 'B');

      // --- Wire creation: one endpoint unmapped -> not bridged, no
      //     fabricated node or relationship -------------------------------
      final beforeUnbridgedRel =
          engine.editing.session.graph.relationships.keys.toSet();
      channel.simulateWireCreated(
          'wire-2', 'gnd-1', 'A', 'pwr-1', 'X', 'Should Not Bridge', 'W');
      await settle(tester);
      expect(engine.editing.session.graph.relationships.keys.toSet(),
          beforeUnbridgedRel,
          reason:
              'a wire touching an unbridged module must not create a relationship');
      expect(adapter.oepRelationshipIdFor('wire-2'), isNull);
      expect(adapter.unbridgedV2WireIds, contains('wire-2'));

      // --- Re-sending an already-bridged wire creation is a no-op --------
      final beforeDupRel =
          engine.editing.session.graph.relationships.keys.toSet();
      channel.simulateWireCreated(
          'wire-1', 'gnd-1', 'A', 'gnd-2', 'B', 'Bridging Wire', 'G');
      await settle(tester);
      expect(engine.editing.session.graph.relationships.keys.toSet(),
          beforeDupRel);

      // --- Undo the wire creation: `_handleWireCreated` issues TWO real
      //     commands (CreateRelationshipCommand, then
      //     UpdateRelationshipPropertiesCommand for label/color) — OEP's
      //     existing undo stack reverts them one at a time, so a single
      //     undo only reverts the metadata patch; a second undo is what
      //     actually removes the relationship. This is real, observed
      //     command-stack behavior, not something this bridge changes
      //     (see the wire bridge doc §13 for the documented account) ------
      controller.commands.undo();
      await settle(tester);
      expect(
          engine.editing.session.graph.relationships
              .containsKey(relationshipId),
          isTrue,
          reason:
              'the first undo only reverts the metadata patch (label/color), not the relationship itself');
      controller.commands.undo();
      await settle(tester);
      expect(
          engine.editing.session.graph.relationships
              .containsKey(relationshipId),
          isFalse,
          reason: 'the second undo reverts CreateRelationshipCommand itself');
      adapter.resyncLastBridgedToV2();
      expect(channel.removedWires, contains('wire-1'));

      // --- Property edit: label bridges via the existing RenameNodeCommand
      channel.simulatePropertiesChanged('gnd-1', 'Chassis Ground', 'ground');
      await settle(tester);
      expect(engine.editing.session.graph.nodes[nodeId]!.displayName,
          'Chassis Ground');
      expect(channel.sentLabels.last, ('gnd-1', 'Chassis Ground'));

      // --- AP-DIAGRAM-V2-BRIDGE-011: notes bridge via the new
      //     UpdateNodeMetadataCommand (metadata, not properties) --------
      channel.simulatePropertiesChanged('gnd-1', 'Chassis Ground', 'ground',
          notes: 'Behind the dash');
      await settle(tester);
      expect(engine.editing.session.graph.nodes[nodeId]!.metadata['notes'],
          'Behind the dash');
      expect(controller.isDirty, isTrue,
          reason: 'a real notes mutation must dirty the document');

      // Blank notes clears the metadata key (null-removes-key convention).
      channel.simulatePropertiesChanged('gnd-1', 'Chassis Ground', 'ground',
          notes: '');
      await settle(tester);
      expect(
          engine.editing.session.graph.nodes[nodeId]!.metadata
              .containsKey('notes'),
          isFalse,
          reason:
              'a blank V2 notes field is a genuine clear request, unlike label/wire-color\'s fall-back-to-previous convention');

      // --- Undo the two notes commands first (LIFO -- they're on top of
      //     the rename), confirming each is independently undoable and
      //     the label is untouched by either -----------------------------
      controller.commands.undo();
      await settle(tester);
      expect(engine.editing.session.graph.nodes[nodeId]!.metadata['notes'],
          'Behind the dash',
          reason:
              'undo must revert the notes-clear command, restoring the previous note');
      expect(engine.editing.session.graph.nodes[nodeId]!.displayName,
          'Chassis Ground');
      controller.commands.undo();
      await settle(tester);
      expect(
          engine.editing.session.graph.nodes[nodeId]!.metadata
              .containsKey('notes'),
          isFalse,
          reason:
              'undo must revert the notes-set command, back to no notes at all');
      expect(engine.editing.session.graph.nodes[nodeId]!.displayName,
          'Chassis Ground');

      // --- Undo the rename: Engine reverts, adapter re-syncs V2 ----------
      controller.commands.undo();
      await settle(tester);
      expect(engine.editing.session.graph.nodes[nodeId]!.displayName,
          'Ground Point',
          reason: 'undo must revert RenameNodeCommand');
      adapter.resyncLastBridgedToV2();
      expect(channel.sentLabels.last, ('gnd-1', 'Ground Point'));

      // --- Deletion: existing DeleteNodeCommand; mapping kept for undo ---
      channel.simulateDelete('gnd-1');
      await settle(tester);
      expect(engine.editing.session.graph.nodes.containsKey(nodeId), isFalse,
          reason: 'delete must use the existing DeleteNodeCommand');
      expect(adapter.oepNodeIdFor('gnd-1'), nodeId,
          reason:
              'the id mapping must be kept after delete, so undo can still find it');

      // --- Undo the delete: Engine restores the node; adapter tells V2 to
      //     restore the module (idempotent restoreModule call), then
      //     re-syncs position/label -----------------------------------------
      controller.commands.undo();
      await settle(tester);
      expect(engine.editing.session.graph.nodes.containsKey(nodeId), isTrue,
          reason: 'Engine undo must restore the deleted node');
      adapter.resyncLastBridgedToV2();
      expect(channel.restoredModules.last,
          ('gnd-1', 'Ground Point', 'ground', 10.0, 20.0));

      // --- Two more undos remain on the real stack below this point:
      //     CreateNode(gnd-2) (never touched since it was created, so
      //     it's the next item down), then CreateNode(gnd-1) itself. The
      //     first of these two removes gnd-2, not gnd-1 — real LIFO
      //     command-stack order, not a bridge bug. -----------------------
      controller.commands.undo();
      await settle(tester);
      expect(
          engine.editing.session.graph.nodes.containsKey(secondNodeId), isFalse,
          reason:
              'the next undo down the real stack is CreateNode(gnd-2), not gnd-1 — LIFO order');
      expect(engine.editing.session.graph.nodes.containsKey(nodeId), isTrue);

      // --- Undo the original gnd-1 creation: node is gone again —
      //     adapter must tell V2 to remove the module entirely, not
      //     resync a position for a node that no longer exists ----------
      controller.commands.undo();
      await settle(tester);
      expect(engine.editing.session.graph.nodes.containsKey(nodeId), isFalse,
          reason: 'undoing the original create must remove the node again');
      adapter.resyncLastBridgedToV2();
      expect(channel.removedModules, contains('gnd-1'));

      // --- AP-DIAGRAM-V2-BRIDGE-004: wire selection/deletion, on a
      //     fresh wire id (gnd-2 is still a mapped module; both
      //     endpoints available). Placed at the very end of this test so
      //     it doesn't disturb the LIFO command-stack arithmetic every
      //     assertion above this point already depends on. -------------
      // gnd-1's own mapping is still kept (for its earlier undo), so
      // re-using that exact V2 id would be a no-op (§ the comment
      // earlier in this test about 'wire-1') — a genuinely new module
      // id gets a genuinely new node.
      channel.simulateCreate('gnd-3', 'Third Ground', 'ground', 30, 30);
      await settle(tester);
      channel.simulateWireCreated(
          'wire-4', 'gnd-3', 'A', 'gnd-2', 'B', 'Bridging Wire', 'G');
      await settle(tester);
      final wireRelId = adapter.oepRelationshipIdFor('wire-4')!;

      // --- Wire selection mirrors into OEP's own GraphSelection, not a
      //     second selection system --------------------------------------
      channel.simulateWireSelectionChanged('wire-4');
      await settle(tester);
      expect(engine.registry.selection.current.relationshipIds, {wireRelId});
      channel.simulateWireSelectionChanged(null);
      await settle(tester);
      expect(engine.registry.selection.current.isEmpty, isTrue);

      // --- AP-DIAGRAM-V2-BRIDGE-009: module selection mirrors into
      //     OEP's own GraphSelection too, symmetric with wire selection --
      final gnd3NodeId = adapter.oepNodeIdFor('gnd-3')!;
      final dirtyBeforeModuleSelection = controller.isDirty;
      channel.simulateModuleSelectionChanged('gnd-3');
      await settle(tester);
      expect(engine.registry.selection.current.nodeIds, {gnd3NodeId});
      expect(controller.isDirty, dirtyBeforeModuleSelection,
          reason: 'selection must never dirty the document');
      channel.simulateModuleSelectionChanged(null);
      await settle(tester);
      expect(engine.registry.selection.current.isEmpty, isTrue);

      // Unmapped module id: no-op, no crash, existing selection untouched.
      channel.simulateModuleSelectionChanged('gnd-3');
      await settle(tester);
      channel.simulateModuleSelectionChanged('module-never-bridged');
      await settle(tester);
      expect(engine.registry.selection.current.nodeIds, {gnd3NodeId},
          reason:
              'an unmapped module selecting in V2 must leave OEP selection exactly as it was');
      channel.simulateModuleSelectionChanged(null);
      await settle(tester);

      // --- Wire deletion: existing DeleteRelationshipCommand; mapping
      //     kept for undo ---------------------------------------------
      channel.simulateWireDeleted('wire-4');
      await settle(tester);
      expect(engine.editing.session.graph.relationships.containsKey(wireRelId),
          isFalse,
          reason: 'delete must use the existing DeleteRelationshipCommand');
      expect(adapter.oepRelationshipIdFor('wire-4'), wireRelId,
          reason:
              'the id mapping must be kept after delete, so undo can still find it');

      // --- Undo the deletion: Engine restores the relationship; adapter
      //     tells V2 to restore the wire (idempotent restoreWire call) --
      controller.commands.undo();
      await settle(tester);
      expect(engine.editing.session.graph.relationships.containsKey(wireRelId),
          isTrue,
          reason: 'Engine undo must restore the deleted relationship');
      adapter.resyncLastBridgedToV2();
      expect(channel.restoredWires.last,
          ('wire-4', 'gnd-3', 'gnd-2', 'Bridging Wire', 'G'));

      // --- AP-DIAGRAM-V2-BRIDGE-005: wire property editing, on a fresh
      //     wire id (wire-4 was deleted-then-undone above; a genuinely
      //     new id avoids disturbing the LIFO undo-stack arithmetic every
      //     assertion above this point already depends on). -------------
      channel.simulateWireCreated(
          'wire-5', 'gnd-3', 'A', 'gnd-2', 'B', 'Original Label', 'W');
      await settle(tester);
      final wire5RelId = adapter.oepRelationshipIdFor('wire-5')!;

      // Label edit: bridged via the existing updateRelationshipMetadata,
      // authoritative value read back and confirmed to V2.
      channel.simulateWirePropertiesChanged('wire-5', 'Edited Label', 'W');
      await settle(tester);
      var rel = engine.editing.session.graph.relationships[wire5RelId]!;
      expect(rel.metadata['label'], 'Edited Label');
      expect(channel.confirmedWires.last, ('wire-5', 'Edited Label', 'W'));

      // Color edit: bridged as V2's own raw code string (not hex) — the
      // same treatment wire creation already gives `color`, not a new
      // representation.
      channel.simulateWirePropertiesChanged('wire-5', 'Edited Label', 'Bl/Y');
      await settle(tester);
      rel = engine.editing.session.graph.relationships[wire5RelId]!;
      expect(rel.metadata['wireColor'], 'Bl/Y');
      expect(channel.confirmedWires.last, ('wire-5', 'Edited Label', 'Bl/Y'));

      // No-op re-send of the same values must not create a spurious undo
      // entry (verified indirectly: undoing once must revert straight to
      // 'Original Label'/'W', not stop at an intermediate no-op state).
      channel.simulateWirePropertiesChanged('wire-5', 'Edited Label', 'Bl/Y');
      await settle(tester);
      rel = engine.editing.session.graph.relationships[wire5RelId]!;
      expect(rel.metadata['label'], 'Edited Label');
      expect(rel.metadata['wireColor'], 'Bl/Y');

      // Undo restores the previous property-edit command (color edit),
      // and the adapter's resync pushes the restored value back to V2 via
      // confirmWireCreated (restoreWire alone would no-op — the wire is
      // still present in V2 throughout a property edit).
      controller.commands.undo();
      await settle(tester);
      rel = engine.editing.session.graph.relationships[wire5RelId]!;
      expect(rel.metadata['wireColor'], 'W',
          reason: 'undo must revert the color-edit command');
      adapter.resyncLastBridgedToV2();
      expect(channel.confirmedWires.last, ('wire-5', 'Edited Label', 'W'));

      // Unmapped wire id: no-op, no crash.
      channel.simulateWirePropertiesChanged('wire-unmapped', 'X', 'Y');
      await settle(tester);
      expect(engine.editing.session.graph.relationships.containsKey(wire5RelId),
          isTrue);

      // --- AP-DIAGRAM-V2-BRIDGE-006: measurement request, no simulation
      //     session reachable (`adapter` above has no
      //     simulationServiceResolver) — a real, disclosed state, not a
      //     crash or a fabricated reading. --------------------------------
      channel.simulateMeasurementRequested('wire-5', 'RES');
      await settle(tester);
      expect(channel.appliedMeasurements.last.$1, 'wire-5');
      expect(channel.appliedMeasurements.last.$2, 'RES');
      expect(channel.appliedMeasurements.last.$3, '—',
          reason: 'no session reachable must not fabricate a reading');
      expect(channel.appliedMeasurements.last.$5,
          contains('No active OEP simulation session'));

      // Unmapped wire: no-op, no crash.
      final measurementsBefore = channel.appliedMeasurements.length;
      channel.simulateMeasurementRequested('wire-unmapped', 'RES');
      await settle(tester);
      expect(channel.appliedMeasurements.length, measurementsBefore,
          reason: 'an unbridged wire id must be a no-op');

      // --- Same request, but through a second adapter/channel wired to a
      //     REAL DiagramSimulationService/SimulationEngine (not a fake) —
      //     verifies the bridge actually reaches OEP's real measurement
      //     subsystem, per this task's "use the real simulation subsystem
      //     where practical, do not fake the calculation" instruction.
      //     Uses a fresh module/wire pair rather than wire-5 (whose
      //     `gnd-2` endpoint was undone out of the graph earlier in this
      //     test, at the LIFO-undo block above — `_v2ToOepNodeId` for a
      //     brand-new adapter can only resolve nodes that currently exist,
      //     unlike the long-lived `adapter` above, whose map still holds
      //     that stale entry from before the undo). --------------------
      channel.simulateCreate('gnd-4', 'Fourth Ground', 'ground', 40, 40);
      await settle(tester);
      channel.simulateWireCreated(
          'wire-6', 'gnd-3', 'A', 'gnd-4', 'B', 'Measured Wire', 'W');
      await settle(tester);

      final simEngine = SimulationEngine();
      final simService = DiagramSimulationService(engine: simEngine);
      await simService.createSession(engine.editing.session.graph);

      final measurementChannel = _FakeChannel();
      final measurementAdapter = LegacyV2StateAdapter(
        controller: controller,
        channel: measurementChannel,
        simulationServiceResolver: () => simService,
      );
      await measurementAdapter.initializeFromDocument();

      measurementChannel.simulateMeasurementRequested('wire-6', 'CONT');
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          if (measurementChannel.appliedMeasurements.isNotEmpty) return;
          await Future.delayed(const Duration(milliseconds: 20));
        }
      });
      await settle(tester);
      expect(measurementChannel.appliedMeasurements, isNotEmpty,
          reason:
              'a real session must produce some applied result, not silence');
      final realResult = measurementChannel.appliedMeasurements.last;
      expect(realResult.$1, 'wire-6');
      expect(realResult.$2, 'CONT');
      expect(realResult.$3, anyOf('000', 'OPN'),
          reason:
              'continuity must translate to one of V2\'s own two sentinel codes, never a fabricated number');
      expect(realResult.$5, isNot(contains('No active OEP simulation session')),
          reason: 'a real session must not report the no-session message');

      // ══════════════════════════════════════════════════════════════
      // AP-DIAGRAM-V2-BRIDGE-SAVE-001 — the Save flush barrier
      // (`flushBeforeSave`). Every assertion below deliberately never
      // calls `channel.simulateMove`/`simulateWireCreated`/etc. for the
      // change being verified — the whole point is that `flushBeforeSave`
      // must reconcile V2's current state WITHOUT any live per-message
      // event ever having fired, exactly the "poller hasn't caught up
      // yet" scenario that produced the original module-position-save
      // race. Fresh module/wire ids throughout, so this doesn't disturb
      // any LIFO undo-stack arithmetic the earlier parts of this test
      // still depend on.
      // ══════════════════════════════════════════════════════════════

      // --- Module position: flush commits a move with NO moduleMoved
      //     event ever having been simulated -----------------------------
      channel.simulateCreate('flush-mod-1', 'Flush Module', 'ground', 1, 1);
      await settle(tester);
      final flushNodeId = adapter.oepNodeIdFor('flush-mod-1')!;
      expect(engine.editing.session.layout.positionOf(flushNodeId),
          const Point2D(1, 1));

      channel.nextSnapshot = V2SaveSnapshot(
        modules: {
          'flush-mod-1': const V2SnapshotModule(
              label: 'Flush Module',
              category: 'ground',
              notes: '',
              x: 77,
              y: 88)
        },
        wires: const {},
        wireRoutes: const {},
      );
      await adapter.flushBeforeSave();
      expect(engine.editing.session.layout.positionOf(flushNodeId),
          const Point2D(77, 88),
          reason:
              'flushBeforeSave must commit V2\'s current position with no moduleMoved event and no polling wait at all');

      // --- Module creation: flush detects a module that only ever
      //     appeared in a snapshot, never via simulateCreate — proving the
      //     flush does not depend on the poller for create detection
      //     either (§5's "wire/module creation-deletion state" requirement)
      final beforeFlushCreateNodes =
          engine.editing.session.graph.nodes.keys.toSet();
      channel.nextSnapshot = V2SaveSnapshot(
        modules: {
          'flush-mod-1': const V2SnapshotModule(
              label: 'Flush Module',
              category: 'ground',
              notes: '',
              x: 77,
              y: 88),
          'flush-mod-2': const V2SnapshotModule(
              label: 'Never Live-Created',
              category: 'ground',
              notes: '',
              x: 5,
              y: 6),
        },
        wires: const {},
        wireRoutes: const {},
      );
      await adapter.flushBeforeSave();
      final afterFlushCreateNodes =
          engine.editing.session.graph.nodes.keys.toSet();
      expect(afterFlushCreateNodes.length, beforeFlushCreateNodes.length + 1,
          reason:
              'a module that only ever appeared in a flush snapshot must still be bridged');
      final flushMod2NodeId = adapter.oepNodeIdFor('flush-mod-2');
      expect(flushMod2NodeId, isNotNull);
      expect(engine.editing.session.layout.positionOf(flushMod2NodeId!),
          const Point2D(5, 6));

      // --- Wire creation, property edit, and route persistence, all via
      //     one flush -- proving route offsets (never observed by the
      //     poller at all, the second confirmed bug) round-trip through
      //     the Engine's own SetWireSegmentOffsetsCommand ----------------
      channel.nextSnapshot = V2SaveSnapshot(
        modules: {
          'flush-mod-1': const V2SnapshotModule(
              label: 'Flush Module',
              category: 'ground',
              notes: '',
              x: 77,
              y: 88),
          'flush-mod-2': const V2SnapshotModule(
              label: 'Never Live-Created',
              category: 'ground',
              notes: '',
              x: 5,
              y: 6),
        },
        wires: {
          'flush-wire-1': const V2SnapshotWire(
            fromModuleId: 'flush-mod-1',
            fromTerminal: 'A',
            toModuleId: 'flush-mod-2',
            toTerminal: 'B',
            label: 'Flush Wire',
            color: 'W',
          ),
        },
        wireRoutes: {
          'flush-wire-1': {0: 12.5, 2: -3.0},
        },
      );
      await adapter.flushBeforeSave();
      final flushRelId = adapter.oepRelationshipIdFor('flush-wire-1');
      expect(flushRelId, isNotNull,
          reason:
              'a wire that only ever appeared in a flush snapshot must still be bridged');
      final flushRelationship =
          engine.editing.session.graph.relationships[flushRelId]!;
      expect(flushRelationship.metadata['label'], 'Flush Wire');
      expect(flushRelationship.metadata['wireColor'], 'W');
      expect(engine.editing.session.layout.wireSegmentOffsetsOf(flushRelId!),
          {0: 12.5, 2: -3.0},
          reason:
              'route-segment offsets must persist through the flush with no live wireRoutes observation ever having existed');

      // --- Route Reset (V2's own `delete wireRoutes[wireId]`): the next
      //     flush's snapshot omits the wire entirely from `wireRoutes` --
      channel.nextSnapshot = V2SaveSnapshot(
        modules: channel.nextSnapshot!.modules,
        wires: channel.nextSnapshot!.wires,
        wireRoutes: const {}, // reset -- no entry for 'flush-wire-1'
      );
      await adapter.flushBeforeSave();
      expect(engine.editing.session.layout.wireSegmentOffsetsOf(flushRelId),
          isNull,
          reason:
              'an absent wireRoutes entry must clear the OEP override entirely (Reset Route), not leave it stale');

      // --- Module/wire deletion via flush: both disappear from a
      //     snapshot with no simulateDelete/simulateWireDeleted ever
      //     having been called ------------------------------------------
      channel.nextSnapshot =
          const V2SaveSnapshot(modules: {}, wires: {}, wireRoutes: {});
      await adapter.flushBeforeSave();
      expect(engine.editing.session.graph.relationships.containsKey(flushRelId),
          isFalse,
          reason:
              'a wire missing from a flush snapshot must be deleted, same as a live wireDeleted event');
      expect(
          engine.editing.session.graph.nodes.containsKey(flushNodeId), isFalse,
          reason:
              'a module missing from a flush snapshot must be deleted, same as a live moduleDeleted event');
      expect(engine.editing.session.graph.nodes.containsKey(flushMod2NodeId),
          isFalse);

      // --- flushBeforeSave with no snapshot available (disabled/
      //     unreachable transport) must be a safe no-op, not a crash ----
      channel.nextSnapshot =
          null; // captureSaveSnapshot() falls back to an empty snapshot -- reconciles to no-op here
      await adapter.flushBeforeSave();
    },
  );
}
