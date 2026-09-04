import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/services/engineering_project_service.dart';
import '../commands/studio_command_actions.dart';
import '../host/diagram_document.dart';
import '../webview/diagram_editing_host.dart';
import 'compare_project_provider.dart';

/// AP-OEP-DIAGRAM-COMPARE-001 — the Compare pane's own controller: a
/// small, purpose-built sibling of `DiagramStudioController`
/// (`diagram_studio/controller/diagram_studio_controller.dart`), not a
/// modification or subclass of it. Every method here is copied verbatim
/// in shape from that controller's own equivalent method, pointed at
/// [compareEngineeringProjectServiceProvider] instead of the Primary
/// document's `engineeringProjectServiceProvider`.
///
/// Deliberately narrower than the Primary controller: no document tab
/// list (`diagramTabsProvider` — pins/recently-closed/multiple tab
/// *references* to one shared document, per that system's own doc
/// comment, not applicable here since Compare only ever has one open
/// document at a time), no Instruments/Simulation/Copilot integration,
/// no workspace-persistence restoration (Compare always starts blank —
/// session-only, matching the same convention already used for generic
/// Web Surface tabs). Implements [DiagramEditingHost] so the existing,
/// unmodified `LegacyV2StateAdapter` can drive it exactly as it drives
/// the Primary controller, with no knowledge of which one it has.
class CompareDiagramController implements DiagramEditingHost {
  CompareDiagramController({required this.engine, required Ref ref})
      : _ref = ref,
        commands = StudioCommandActions(engine);

  @override
  final EngineeringEngine engine;

  final Ref _ref;

  @override
  final StudioCommandActions commands;

  bool get canUndo => commands.canUndo;
  bool get canRedo => commands.canRedo;

  EngineeringProjectState get _projectState =>
      _ref.read(compareEngineeringProjectServiceProvider);
  GraphSelection get selection => _projectState.selection;
  EditingSession? get session => _projectState.session;

  @override
  DiagramDocument get document => _projectState.document;

  @override
  String? get documentPath => document.path;

  bool get isDirty => document.isDirty;

  void markDirty() => _ref
      .read(compareEngineeringProjectServiceProvider.notifier)
      .markDocumentDirty();

  void undo() {
    commands.undo();
    markDirty();
  }

  void redo() {
    commands.redo();
    markDirty();
  }

  @override
  void addNodeWithMetadata(
    String symbolId,
    Point2D position, {
    String? displayName,
    Map<String, Object?> metadata = const {},
  }) {
    final symbol = engine.registry.symbols.resolve(symbolId);
    final id = engine.graph.generateId('node');
    final node = EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: displayName ?? symbol.name,
      symbolId: symbolId,
      metadata: metadata,
    );
    engine.editing.execute(CreateNodeCommand(node, position: position));
    engine.registry.selection.selectNode(id);
    markDirty();
  }

  @override
  void deleteNode(String nodeId) {
    engine.editing.execute(DeleteNodeCommand(nodeId));
    markDirty();
  }

  @override
  void renameNode(String nodeId, String newDisplayName) {
    engine.editing.execute(RenameNodeCommand(nodeId, newDisplayName));
    markDirty();
  }

  @override
  void moveNodes(Map<String, Point2D> newPositions) {
    engine.editing.execute(MoveNodesCommand(newPositions));
    markDirty();
  }

  @override
  void createRelationship(String sourceNodeId, String targetNodeId) {
    engine.editing.execute(CreateRelationshipCommand(EngineeringRelationship(
      id: engine.graph.generateId('rel'),
      relationshipType: RelationshipType.connectedTo,
      sourceNode: sourceNodeId,
      targetNode: targetNodeId,
    )));
    markDirty();
  }

  @override
  void deleteRelationship(String relationshipId) {
    engine.editing.execute(DeleteRelationshipCommand(relationshipId));
    markDirty();
  }

  @override
  void updateRelationshipMetadata(
      String relationshipId, Map<String, Object?> patch) {
    engine.editing
        .execute(UpdateRelationshipPropertiesCommand(relationshipId, patch));
    markDirty();
  }

  @override
  void updateNodeMetadata(String nodeId, Map<String, Object?> patch) {
    engine.editing.execute(UpdateNodeMetadataCommand(nodeId, patch));
    markDirty();
  }

  @override
  void setWireSegmentOffsets(String relationshipId, Map<int, double>? offsets) {
    engine.editing
        .execute(SetWireSegmentOffsetsCommand(relationshipId, offsets));
    markDirty();
  }

  Future<void> newDocument() => _ref
      .read(compareEngineeringProjectServiceProvider.notifier)
      .newDocument();

  Future<void> openDocument(String path) => _ref
      .read(compareEngineeringProjectServiceProvider.notifier)
      .openDocument(path);

  @override
  Future<void> saveDocument() => _ref
      .read(compareEngineeringProjectServiceProvider.notifier)
      .saveDocument();

  Future<void> saveDocumentAs(String path) => _ref
      .read(compareEngineeringProjectServiceProvider.notifier)
      .saveDocumentAs(path);

  Future<void> closeDocument() => _ref
      .read(compareEngineeringProjectServiceProvider.notifier)
      .closeDocument();

  /// The full bootstrap: start (or reuse) the Compare document's own
  /// `EngineHost` via [EngineeringProjectNotifier.ensureEngineStarted] —
  /// the exact same, unmodified method the Primary controller's own
  /// `bootstrap()` calls, just against the second, independent provider.
  /// Idempotent — Riverpod only ever runs this once per app session
  /// (`compareDiagramControllerProvider`'s own `AsyncNotifierProvider`
  /// caches the result), matching the Primary controller's own lifetime
  /// guarantee.
  static Future<CompareDiagramController> bootstrap({required Ref ref}) async {
    final notifier =
        ref.read(compareEngineeringProjectServiceProvider.notifier);
    final host = await notifier.ensureEngineStarted();
    return CompareDiagramController(engine: host.engine, ref: ref);
  }
}

class CompareDiagramControllerNotifier
    extends AsyncNotifier<CompareDiagramController> {
  @override
  Future<CompareDiagramController> build() =>
      CompareDiagramController.bootstrap(ref: ref);
}

final compareDiagramControllerProvider = AsyncNotifierProvider<
    CompareDiagramControllerNotifier, CompareDiagramController>(
  CompareDiagramControllerNotifier.new,
);
