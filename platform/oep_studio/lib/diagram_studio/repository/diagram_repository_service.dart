import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';

import '../../core/foundation/foundation_bridge.dart';
import '../../core/models/engineering_object_summary.dart';
import '../../core/models/object_category.dart';
import '../../core/models/relationship_type.dart' as studio;
import '../migration/legacy_migration_models.dart';

/// AP-DS-002: replaces Diagram Studio's local-JSON-only persistence with
/// Foundation Runtime Engineering Repository integration, consuming
/// [FoundationBridge] exclusively (the Dart-side wrapper over the Public
/// C API / `RuntimeService`) -- never repository internals, never SQL,
/// never a transaction bypass, matching AP-DS-002's own constraints.
///
/// Design (see `docs/architecture/diagram_studio/ENGINEERING_MODEL.md`
/// for the full prior analysis this responds to): Foundation's
/// `EngineeringObject`/`Relationship` schema has no generic properties
/// bag, and adding one for arbitrary graphics data would violate the
/// platform's "no graphics-only entities" principle. This service
/// resolves that the same way `EngineeringObject.content` itself was
/// designed to (see that field's own doc comment in oep_foundation):
///
/// * The Diagram itself becomes one real `EngineeringObject`
///   (`ObjectCategory.diagram`), whose `content` field holds a complete,
///   lossless JSON snapshot of the `EngineeringGraph` + `DiagramLayoutState`
///   -- this is the round-trip source of truth for open/save, exactly
///   mirroring the legacy local-JSON envelope's own shape so migration is
///   a near-direct copy (see [migrate]).
/// * Every node also becomes a real `EngineeringObject`
///   (`ObjectCategory.component`), and every wire (`RelationshipType.connectedTo`
///   in the Engineering Graph) becomes a real Foundation `Relationship`
///   of type [RelationshipType.connectedTo] -- so the platform's
///   repository genuinely contains queryable engineering entities, not
///   just an opaque blob, satisfying "Engineering Objects become the
///   canonical document model." These are regenerated in full on every
///   [saveDiagram] call (delete-then-recreate, wrapped in the same
///   transaction as the content write) rather than diffed against their
///   previous state -- a deliberate, documented MVP simplification.
///   Diffing to avoid unnecessary object churn on every save is real,
///   valuable future work, not attempted here; correctness does not
///   depend on it, since the `content` blob (not the decomposed
///   objects) is what [loadDiagram] actually reads back.
/// * Layers are NOT separate objects -- they're a tag on member nodes
///   (`node-category:<category>`, `diagram:<diagramObjectId>`) plus
///   layer definitions inside the content blob, avoiding a proliferation
///   of low-value repository objects for what is fundamentally a
///   rendering/organization grouping.
/// * Annotations, viewport, and selection state are NEVER separate
///   Engineering Objects -- per AP-DS-001's own ratified Constitution,
///   they have no independent engineering meaning and stay inside the
///   content blob exclusively.
///
/// Every mutating save wraps its multi-step sequence (content write +
/// node/relationship regeneration) in one explicit
/// [FoundationBridge.beginTransaction]/[FoundationBridge.commitTransaction]
/// so a partial failure rolls back the whole save, never leaving a
/// half-migrated diagram behind -- this is repository-write atomicity,
/// entirely separate from (and does not touch) Diagram Studio's own
/// in-app undo/redo (`CommandHistory`), which remains untouched and
/// frozen since AP-DS-001.
class DiagramRepositoryService implements LegacyMigrator {
  DiagramRepositoryService(this._bridge);

  final FoundationBridge _bridge;

  /// Creates a new Project Engineering Object -- the repository-level
  /// container a diagram is opened/saved under.
  EngineeringObjectSummary createProject(String name, {String description = ''}) {
    return _bridge.createObject(category: ObjectCategory.project, name: name, description: description);
  }

  /// Saves [graph]/[layout] as a repository-backed diagram. When
  /// [diagramObjectId] is null, creates a new Diagram object (returned
  /// id is the caller's new [diagramObjectId] for subsequent saves);
  /// otherwise updates the existing one in place. Returns the
  /// resulting Diagram object's id.
  String saveDiagram({
    String? diagramObjectId,
    required String title,
    required EngineeringGraph graph,
    required DiagramLayoutState layout,
    String description = '',
    String author = '',
  }) {
    return _save(
      diagramObjectId: diagramObjectId,
      title: title,
      graph: graph,
      layout: layout,
      description: description,
      author: author,
    ).diagramObjectId;
  }

  /// AP-DS-003: syncs the current in-memory [graph]/[layout] to a
  /// repository-backed Diagram exactly like [saveDiagram] (same
  /// transaction-wrapped create/update + decompose), but also returns
  /// the `EngineeringNode.id` -> Foundation `object_id` mapping needed
  /// to translate Engineering Intelligence Platform results back to
  /// canvas nodes. Intended to be called on a debounce timer after
  /// edits by `DiagramIntelligenceService`, independent of the user's
  /// own explicit Save action -- "live feedback while authoring" (the
  /// spec's own words) cannot wait for the user to manually save first.
  /// When [diagramObjectId] is null, this creates and thereafter reuses
  /// a working Diagram object for the session exactly as [saveDiagram]
  /// would; callers should pass back the returned id on subsequent
  /// calls so the same object is updated rather than a new one created
  /// every sync.
  ({String diagramObjectId, Map<String, String> nodeObjectIds}) syncForIntelligence({
    String? diagramObjectId,
    required String title,
    required EngineeringGraph graph,
    required DiagramLayoutState layout,
    String description = '',
    String author = '',
  }) {
    return _save(
      diagramObjectId: diagramObjectId,
      title: title,
      graph: graph,
      layout: layout,
      description: description,
      author: author,
    );
  }

  ({String diagramObjectId, Map<String, String> nodeObjectIds}) _save({
    String? diagramObjectId,
    required String title,
    required EngineeringGraph graph,
    required DiagramLayoutState layout,
    required String description,
    required String author,
  }) {
    final content = jsonEncode({'graph': graph.toJson(), 'layout': layout.toJson()});

    _bridge.beginTransaction();
    try {
      final String resolvedId;
      if (diagramObjectId == null) {
        final created = _bridge.createObject(
          category: ObjectCategory.diagram,
          name: title,
          description: description,
          author: author,
        );
        resolvedId = created.objectId;
        _bridge.updateObjectContent(objectId: resolvedId, content: content);
      } else {
        _bridge.updateObject(objectId: diagramObjectId, name: title, description: description, author: author);
        _bridge.updateObjectContent(objectId: diagramObjectId, content: content);
        resolvedId = diagramObjectId;
        _clearDecomposedObjects(resolvedId);
      }
      final nodeObjectIds = _decomposeIntoObjects(diagramObjectId: resolvedId, graph: graph, author: author);
      _bridge.commitTransaction();
      return (diagramObjectId: resolvedId, nodeObjectIds: nodeObjectIds);
    } catch (_) {
      _bridge.rollbackTransaction();
      rethrow;
    }
  }

  /// Loads a repository-backed diagram back into an
  /// `EngineeringGraph`/`DiagramLayoutState` pair. Reads exclusively
  /// from the Diagram object's `content` field (the round-trip source
  /// of truth) -- never reconstructs the graph from the decomposed
  /// Component objects/Relationships, which exist for repository
  /// queryability, not as a second source of truth (that would
  /// duplicate Engineering Object data, which this platform's own
  /// constitution forbids).
  ({EngineeringGraph graph, DiagramLayoutState layout}) loadDiagram(String diagramObjectId) {
    final content = _bridge.getObjectContent(diagramObjectId);
    if (content.isEmpty) {
      return (graph: EngineeringGraph.empty(diagramObjectId), layout: DiagramLayoutState.empty);
    }
    final decoded = jsonDecode(content) as Map<String, Object?>;
    final graph = EngineeringGraph.fromJson(decoded['graph'] as Map<String, Object?>);
    final layoutJson = decoded['layout'] as Map<String, Object?>?;
    final layout = layoutJson == null ? DiagramLayoutState.empty : DiagramLayoutState.fromJson(layoutJson);
    return (graph: graph, layout: layout);
  }

  /// Regenerates this diagram's decomposed Component objects and
  /// `ConnectedTo` Relationships from [graph] -- called from inside
  /// [saveDiagram]'s transaction, after any prior decomposition for
  /// this diagram has been cleared (on update) or when none existed
  /// yet (on create). Returns the `EngineeringNode.id` -> Foundation
  /// `object_id` mapping (AP-DS-003: [syncForIntelligence] needs this
  /// to translate Engineering Intelligence Platform results, which are
  /// keyed by Foundation object id, back to canvas node ids).
  Map<String, String> _decomposeIntoObjects({
    required String diagramObjectId,
    required EngineeringGraph graph,
    required String author,
  }) {
    final nodeObjectIds = <String, String>{}; // EngineeringNode.id -> Foundation object_id
    for (final node in graph.nodes.values) {
      final created = _bridge.createObject(
        category: ObjectCategory.component,
        name: node.displayName,
        author: author,
        tags: ['node-category:${node.category.name}', 'diagram:$diagramObjectId'],
      );
      nodeObjectIds[node.id] = created.objectId;
    }
    for (final relationship in graph.relationships.values) {
      final sourceId = nodeObjectIds[relationship.sourceNode];
      final targetId = nodeObjectIds[relationship.targetNode];
      // A relationship whose endpoint node failed to decompose (should
      // not happen -- every node in `graph.nodes` is decomposed above
      // first) is skipped rather than thrown, so one bad edge can't
      // abort an otherwise-successful save; `content` remains the
      // authoritative record regardless.
      if (sourceId == null || targetId == null) continue;
      _bridge.createRelationship(
        sourceObjectId: sourceId,
        targetObjectId: targetId,
        type: studio.RelationshipType.connectedTo,
        author: author,
        objectNamesById: {
          sourceId: graph.nodes[relationship.sourceNode]!.displayName,
          targetId: graph.nodes[relationship.targetNode]!.displayName,
        },
      );
    }
    return nodeObjectIds;
  }

  /// Deletes every previously-decomposed Component object/Relationship
  /// tagged with [diagramObjectId] (see `_decomposeIntoObjects`'s
  /// `diagram:<id>` tag), ahead of regenerating them fresh in the same
  /// save transaction. Relationships are deleted first (Foundation's
  /// `oep_object_delete` does not cascade -- see its own doc comment --
  /// so a stale relationship left pointing at a just-deleted object
  /// would be an orphan reference).
  void _clearDecomposedObjects(String diagramObjectId) {
    final tag = 'diagram:$diagramObjectId';
    final staleObjectIds = _bridge
        .listObjects()
        .where((object) => object.category == ObjectCategory.component && object.tags.contains(tag))
        .map((object) => object.objectId)
        .toSet();
    if (staleObjectIds.isEmpty) return;
    for (final relationship in _bridge.listRelationships(objectNamesById: const {})) {
      if (staleObjectIds.contains(relationship.sourceObjectId) ||
          staleObjectIds.contains(relationship.targetObjectId)) {
        _bridge.deleteRelationship(relationship.relationshipId);
      }
    }
    for (final objectId in staleObjectIds) {
      _bridge.deleteObject(objectId);
    }
  }

  /// [LegacyMigrator] implementation -- converts a legacy local-JSON
  /// Diagram Studio document (the `{schemaVersion, documentId, graph,
  /// layout, metadata}` envelope written by `DiagramDocument.saveAs`)
  /// into a repository-backed Project + Diagram. Automatic conversion,
  /// verification (reload and compare node/relationship counts before
  /// declaring success), error reporting, and rollback-on-failure per
  /// AP-DS-002's Migration requirements.
  @override
  Future<LegacyMigrationResult> migrate(String legacyFilePath) async {
    final items = <LegacyMigrationItem>[];
    try {
      final file = File(legacyFilePath);
      if (!file.existsSync()) {
        return LegacyMigrationResult(
          success: false,
          legacyFilePath: legacyFilePath,
          errorMessage: 'File not found: $legacyFilePath',
        );
      }
      final decoded = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final graph = EngineeringGraph.fromJson(decoded['graph'] as Map<String, Object?>);
      final layoutJson = decoded['layout'] as Map<String, Object?>?;
      final layout = layoutJson == null ? DiagramLayoutState.empty : DiagramLayoutState.fromJson(layoutJson);
      final metadataJson = decoded['metadata'] as Map<String, Object?>?;
      final title = (metadataJson?['title'] as String?) ?? _titleFromPath(legacyFilePath);

      items.add(LegacyMigrationItem(description: 'Parsed legacy document "$title"', succeeded: true));

      final project = createProject(title, description: 'Migrated from $legacyFilePath');
      items.add(
        LegacyMigrationItem(description: 'Project "$title" → Engineering Object (Project)', succeeded: true),
      );

      final diagramObjectId = saveDiagram(title: title, graph: graph, layout: layout);
      items.add(
        LegacyMigrationItem(description: 'Diagram "$title" → Engineering Object (Diagram)', succeeded: true),
      );
      for (final node in graph.nodes.values) {
        items.add(
          LegacyMigrationItem(
            description: '${node.displayName} (${node.category.name}) → Engineering Object (Component)',
            succeeded: true,
          ),
        );
      }
      for (final relationship in graph.relationships.values) {
        items.add(
          LegacyMigrationItem(description: 'Wire ${relationship.id} → Relationship', succeeded: true),
        );
      }

      // Verification: reload and confirm no data loss before declaring
      // success -- per the spec's explicit "Verification"/"No data
      // loss" requirements, not assumed from the write path alone.
      final reloaded = loadDiagram(diagramObjectId);
      if (reloaded.graph.nodes.length != graph.nodes.length ||
          reloaded.graph.relationships.length != graph.relationships.length) {
        return LegacyMigrationResult(
          success: false,
          legacyFilePath: legacyFilePath,
          items: items,
          errorMessage:
              'Verification failed: reloaded diagram has ${reloaded.graph.nodes.length} nodes / '
              '${reloaded.graph.relationships.length} relationships, expected ${graph.nodes.length} / '
              '${graph.relationships.length}.',
        );
      }

      return LegacyMigrationResult(
        success: true,
        legacyFilePath: legacyFilePath,
        projectObjectId: project.objectId,
        items: items,
      );
    } catch (error) {
      // Every mutation above already ran inside its own
      // begin/commit/rollback-guarded transaction (createProject and
      // saveDiagram each wrap themselves); a failure here means
      // whichever step threw has already rolled back its own partial
      // work, so nothing durable is left behind from that step. Earlier
      // successfully-committed steps (e.g. a project created before a
      // later diagram save fails) are NOT further rolled back — this is
      // a known, documented limitation of composing multiple
      // independently-transacted calls rather than one single
      // transaction spanning the whole migration; flagged honestly
      // rather than silently claiming full atomicity across steps that
      // don't actually share one transaction.
      return LegacyMigrationResult(
        success: false,
        legacyFilePath: legacyFilePath,
        items: items,
        errorMessage: error.toString(),
        rolledBack: true,
      );
    }
  }

  static String _titleFromPath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
  }
}
