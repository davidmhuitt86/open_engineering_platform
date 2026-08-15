import 'dart:async';

import '../events/platform_event.dart';
import '../events/platform_event_bus.dart';
import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';
import '../models/relationship_summary.dart';
import '../services/foundation_runtime_state.dart';

/// The Platform's shared runtime for Engineering Objects (WP-STUDIO-031
/// Engineering Object Runtime) — loads (via [updateFromFoundationState]),
/// caches, and exposes `FoundationServiceState.objectList`/
/// `relationshipList` (the Repository's Current Object List/Current
/// Relationship List, Work Package 004/006) to every Studio, not just
/// Knowledge Studio's own widgets that already `ref.watch`
/// `foundationRuntimeServiceProvider` directly.
///
/// Deliberately **not** a redesign of Engineering Objects or the
/// Repository: [EngineeringObjectSummary]/[RelationshipSummary] and the
/// Foundation Bridge that produces them are untouched. This class only
/// adds an O(1)-by-id read layer on top of the same two lists
/// `FoundationRuntimeNotifier` already fetches and owns — it fetches
/// nothing itself, and it has no `open`/`close`/`refresh` method of its
/// own (that stays exactly where it is, in
/// `FoundationRuntimeNotifier.openRepository`/`closeRepository`/
/// `_refreshRepositoryData`).
///
/// Fed by exactly one call site — `StudioShell`'s existing
/// `ref.listenManual(foundationRuntimeServiceProvider, ...)` bridge
/// (already present since WP-STUDIO-030 for the OCR bridge) — via
/// [updateFromFoundationState]. Rebuilds its lookup maps only when
/// [FoundationServiceState.objectList]/[FoundationServiceState.relationshipList]
/// actually changed by reference (`identical`), so the far more frequent
/// unrelated Foundation state changes (AI suggestions, OCR status,
/// selection, etc.) are a no-op here — this is the "lightweight caching"
/// this Work Package asks for.
class EngineeringObjectRuntime {
  EngineeringObjectRuntime({PlatformEventBus? eventBus}) : _eventBus = eventBus ?? PlatformEventBus.instance;

  final PlatformEventBus _eventBus;

  List<EngineeringObjectSummary> _objects = const [];
  List<RelationshipSummary> _relationships = const [];
  Map<String, EngineeringObjectSummary> _objectsById = const {};
  Map<String, RelationshipSummary> _relationshipsById = const {};
  Map<String, List<RelationshipSummary>> _relationshipsByObjectId = const {};

  final StreamController<void> _changesController = StreamController<void>.broadcast();

  /// Fires after the cache has already been rebuilt — same read-after-
  /// write guarantee `OperationManager.changes`/`ActivityLog.changes`
  /// already established, for the same reason (a listener that reacts to
  /// this stream always sees already-consistent state).
  Stream<void> get changes => _changesController.stream;

  /// The Current Object List, in Foundation's own returned order —
  /// `const []` (never `null`) before the first successful load, so
  /// callers can iterate unconditionally; use [objectById]/[hasObject] to
  /// distinguish "not loaded yet" from "not found" if that matters.
  List<EngineeringObjectSummary> get objects => _objects;

  /// The Current Relationship List, in Foundation's own returned order.
  List<RelationshipSummary> get relationships => _relationships;

  EngineeringObjectSummary? objectById(String id) => _objectsById[id];

  bool hasObject(String id) => _objectsById.containsKey(id);

  RelationshipSummary? relationshipById(String id) => _relationshipsById[id];

  /// [objects] belonging to [category] — a parameterized counterpart to
  /// `FoundationServiceState.objectsInSelectedCategory`, for a Studio
  /// that wants a specific category without coupling to Knowledge
  /// Studio's own "currently selected category" concept.
  List<EngineeringObjectSummary> objectsInCategory(ObjectCategory category) =>
      [for (final object in _objects) if (object.category == category) object];

  /// Every relationship where [objectId] is the source or the target —
  /// this Work Package's "runtime relationship helper": the one
  /// cross-object query Studios need that a flat [relationships] list
  /// doesn't answer directly.
  List<RelationshipSummary> relationshipsInvolving(String objectId) =>
      _relationshipsByObjectId[objectId] ?? const [];

  /// Rebuilds the cache from [state]'s Current Object/Relationship Lists
  /// — a no-op if neither list changed by reference since the last call
  /// (see this class's own doc comment). Called from `StudioShell`'s
  /// Foundation Bridge listener; never called directly by a Studio.
  void updateFromFoundationState(FoundationServiceState state) {
    final objects = state.objectList ?? const <EngineeringObjectSummary>[];
    final relationships = state.relationshipList ?? const <RelationshipSummary>[];
    if (identical(objects, _objects) && identical(relationships, _relationships)) return;

    _objects = objects;
    _relationships = relationships;
    _objectsById = {for (final object in objects) object.objectId: object};
    _relationshipsById = {for (final relationship in relationships) relationship.relationshipId: relationship};

    final relationshipsByObjectId = <String, List<RelationshipSummary>>{};
    for (final relationship in relationships) {
      relationshipsByObjectId.putIfAbsent(relationship.sourceObjectId, () => []).add(relationship);
      if (relationship.targetObjectId != relationship.sourceObjectId) {
        relationshipsByObjectId.putIfAbsent(relationship.targetObjectId, () => []).add(relationship);
      }
    }
    _relationshipsByObjectId = relationshipsByObjectId;

    _changesController.add(null);
    _eventBus.publish(EngineeringObjectEvent(objectCount: objects.length, relationshipCount: relationships.length));
  }

  void dispose() {
    _changesController.close();
  }

  static final EngineeringObjectRuntime instance = EngineeringObjectRuntime();
}
