import '../../core/foundation/foundation_bridge.dart';
import '../../core/models/object_category.dart';
import '../../core/models/relationship_summary.dart';
import '../../core/models/relationship_type.dart';
import '../../core/models/engineering_object_summary.dart';

/// AP-OEP-FOUNDATION-BRIDGE-001 — the narrow "create/transact against
/// Foundation" capability `StudioFoundationBridgePort.commitGraph`
/// depends on, rather than the whole concrete `FoundationBridge` class.
///
/// Same testability-seam pattern already established in this codebase
/// by `LegacyV2Channel` (`lib/diagram_studio/webview/legacy_v2_bridge_transport.dart`):
/// an abstract capability interface lets the bridge's own logic
/// (id-correspondence, skip-already-committed, rollback-on-failure) be
/// unit-tested against a lightweight fake, without a real
/// `FoundationBridge`/native DLL — `FoundationBridge` itself has no
/// interface to mock (it's a concrete class wrapping raw FFI structs),
/// so this seam is what makes that possible at all.
abstract class FoundationCommitOperations {
  /// AP-OEP-FOUNDATION-BRIDGE-003 — establishes the Foundation diagram
  /// identity `commitGraph` assigns every newly-created node/
  /// relationship in a commit to (`oep_diagram_create`). Called at most
  /// once per commit — a graph that already carries a diagram identity
  /// (`EngineeringGraph.diagramRepositoryId`) reuses it instead of
  /// calling this again, so a graph is never split across two diagrams.
  EngineeringObjectSummary createDiagram({required String name, String description, String author});

  /// Creates a new Engineering Object as a member of [diagramId]
  /// (`oep_object_create_with_diagram`) — replaces the plain,
  /// unscoped `createObject` this seam exposed before
  /// AP-OEP-FOUNDATION-BRIDGE-003; every object `commitGraph` creates
  /// now belongs to a diagram from the moment it exists.
  EngineeringObjectSummary createObjectInDiagram({
    required ObjectCategory category,
    required String name,
    required String diagramId,
    String description,
    String author,
    List<String> tags,
  });

  /// Creates a new Relationship as a member of [diagramId]
  /// (`oep_relationship_create_with_diagram`) — the relationship
  /// counterpart to [createObjectInDiagram].
  RelationshipSummary createRelationshipInDiagram({
    required String sourceObjectId,
    required String targetObjectId,
    required RelationshipType type,
    required String diagramId,
    String author,
    String description,
    required Map<String, String> objectNamesById,
  });

  List<EngineeringObjectSummary> listObjects();

  List<RelationshipSummary> listRelationships({required Map<String, String> objectNamesById});

  /// AP-OEP-FOUNDATION-BRIDGE-002 — exactly the Engineering Objects
  /// belonging to diagram [diagramId] (`oep_diagram_get_objects`), never
  /// the whole repository. Backs `loadCommittedGraph`'s diagram-scoped
  /// load.
  List<EngineeringObjectSummary> listObjectsForDiagram(String diagramId);

  /// AP-OEP-FOUNDATION-BRIDGE-002 — exactly the Relationships belonging
  /// to diagram [diagramId] (`oep_diagram_get_relationships`), never the
  /// whole repository.
  List<RelationshipSummary> listRelationshipsForDiagram(String diagramId, {required Map<String, String> objectNamesById});

  void beginTransaction();

  void commitTransaction();

  void rollbackTransaction();

  bool get isTransactionActive;
}

/// The real implementation — pure delegation to a live [FoundationBridge].
/// No logic of its own; AP-OEP-FOUNDATION-BRIDGE-003 switched the create
/// calls to their diagram-scoped counterparts, but the delegation itself
/// remains as direct as Knowledge Studio's original Repository Commit
/// feature established (`docs/REPOSITORY_COMMIT.md`).
class RealFoundationCommitOperations implements FoundationCommitOperations {
  RealFoundationCommitOperations(this._bridge);

  final FoundationBridge _bridge;

  @override
  EngineeringObjectSummary createDiagram({required String name, String description = '', String author = ''}) {
    return _bridge.createDiagram(name: name, description: description, author: author);
  }

  @override
  EngineeringObjectSummary createObjectInDiagram({
    required ObjectCategory category,
    required String name,
    required String diagramId,
    String description = '',
    String author = '',
    List<String> tags = const [],
  }) {
    return _bridge.createObjectInDiagram(
      category: category,
      name: name,
      diagramId: diagramId,
      description: description,
      author: author,
      tags: tags,
    );
  }

  @override
  RelationshipSummary createRelationshipInDiagram({
    required String sourceObjectId,
    required String targetObjectId,
    required RelationshipType type,
    required String diagramId,
    String author = '',
    String description = '',
    required Map<String, String> objectNamesById,
  }) {
    return _bridge.createRelationshipInDiagram(
      sourceObjectId: sourceObjectId,
      targetObjectId: targetObjectId,
      type: type,
      diagramId: diagramId,
      author: author,
      description: description,
      objectNamesById: objectNamesById,
    );
  }

  @override
  List<EngineeringObjectSummary> listObjects() => _bridge.listObjects();

  @override
  List<RelationshipSummary> listRelationships({required Map<String, String> objectNamesById}) =>
      _bridge.listRelationships(objectNamesById: objectNamesById);

  @override
  List<EngineeringObjectSummary> listObjectsForDiagram(String diagramId) => _bridge.getDiagramObjects(diagramId);

  @override
  List<RelationshipSummary> listRelationshipsForDiagram(String diagramId, {required Map<String, String> objectNamesById}) =>
      _bridge.getDiagramRelationships(diagramId, objectNamesById: objectNamesById);

  @override
  void beginTransaction() => _bridge.beginTransaction();

  @override
  void commitTransaction() => _bridge.commitTransaction();

  @override
  void rollbackTransaction() => _bridge.rollbackTransaction();

  @override
  bool get isTransactionActive => _bridge.isTransactionActive;
}
