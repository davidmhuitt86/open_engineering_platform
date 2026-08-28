import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';
import '../models/relationship_summary.dart';
import '../models/relationship_type.dart';
import '../models/search_result.dart';
import 'foundation_bridge_exception.dart';
import 'oep_api_bindings.dart';
import 'oep_api_native_types.dart';
import 'oep_api_types.dart';

/// The Foundation Bridge (SDD-006, Work Package 002 STUDIO-TASK-000003).
///
/// The sole language-neutral boundary between Studio and OEP Foundation.
/// Every call here goes through `oep_api.h` — no Foundation header beyond
/// that one, and no Foundation C++ type, is ever referenced above this
/// class. Callers work entirely in plain Dart types (`FoundationRuntimeState`,
/// `RepositoryStatus`, `FoundationBridgeException`); nothing here leaks a
/// `Pointer` or a native struct past this file.
///
/// One [FoundationBridge] wraps exactly one native `OEP_Runtime` handle.
/// It is not safe for concurrent use from multiple isolates.
class FoundationBridge {
  FoundationBridge._(this._bindings, this._runtime);

  /// Creates and initializes a new Runtime for the Foundation build this
  /// DLL was compiled against (`oep_foundation_version()` — the same
  /// version the Runtime itself later checks packages against, so this
  /// is never hardcoded on the Studio side).
  /// Throws [FoundationBridgeException] if initialization fails.
  factory FoundationBridge.create() {
    final bindings = OepApiBindings.load();
    final foundationVersion = bindings.foundationVersion().toDartString();
    final versionPointer = foundationVersion.toNativeUtf8();
    final Pointer<Void> runtime;
    try {
      runtime = bindings.runtimeCreate(versionPointer);
    } finally {
      malloc.free(versionPointer);
    }
    if (runtime == nullptr) {
      throw FoundationBridgeException(
        code: FoundationErrorCode.internalError,
        category: FoundationErrorCategory.internalError,
        message: 'OEP Foundation could not be started.',
        technicalDetail: 'oep_runtime_create returned NULL',
      );
    }
    final bridge = FoundationBridge._(bindings, runtime);
    bridge._checkResult(bindings.runtimeInitialize(runtime));
    return bridge;
  }

  final OepApiBindings _bindings;
  final Pointer<Void> _runtime;
  bool _disposed = false;

  /// The Foundation version this build implements (e.g. "0.1.0").
  String get foundationVersion => _bindings.foundationVersion().toDartString();

  /// The Public C API's own version (`OEP_API_VERSION`).
  int get apiVersion => _bindings.apiVersion();

  /// The ABI version (`OEP_ABI_VERSION`).
  int get abiVersion => _bindings.abiVersion();

  /// The Runtime's current lifecycle state.
  FoundationRuntimeState get state {
    _assertNotDisposed();
    return FoundationRuntimeState.fromNative(_bindings.runtimeGetState(_runtime));
  }

  /// Opens the repository rooted at [repositoryPath].
  /// Throws [FoundationBridgeException] on failure.
  void openRepository(String repositoryPath) {
    _assertNotDisposed();
    final pathPointer = repositoryPath.toNativeUtf8();
    try {
      _checkResult(_bindings.runtimeOpenRepository(_runtime, pathPointer));
    } finally {
      malloc.free(pathPointer);
    }
  }

  /// Closes the currently open repository.
  /// Throws [FoundationBridgeException] on failure.
  void closeRepository() {
    _assertNotDisposed();
    _checkResult(_bindings.runtimeCloseRepository(_runtime));
  }

  /// Reads a snapshot of the currently open repository.
  /// Throws [FoundationBridgeException] if no repository is open.
  RepositoryStatus getRepositoryStatus() {
    _assertNotDisposed();
    final statusPointer = malloc<OepRepositoryStatusNative>();
    try {
      _checkResult(_bindings.runtimeGetRepositoryStatus(_runtime, statusPointer));
      return RepositoryStatus.fromNative(statusPointer.ref);
    } finally {
      malloc.free(statusPointer);
    }
  }

  /// Reads repository-wide statistics (total object count, per-category
  /// counts, relationship count, package count), computed by Foundation.
  /// Throws [FoundationBridgeException] if no repository is open.
  RepositoryStatistics getRepositoryStatistics() {
    _assertNotDisposed();
    final statisticsPointer = malloc<OepRepositoryStatisticsNative>();
    try {
      _checkResult(_bindings.runtimeGetRepositoryStatistics(_runtime, statisticsPointer));
      return RepositoryStatistics.fromNative(statisticsPointer.ref);
    } finally {
      malloc.free(statisticsPointer);
    }
  }

  /// The number of Engineering Objects in the currently open repository.
  /// Throws [FoundationBridgeException] if no repository is open.
  int getObjectCount() {
    _assertNotDisposed();
    final countPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.objectStoreGetCount(_runtime, countPointer));
      return countPointer.value;
    } finally {
      malloc.free(countPointer);
    }
  }

  /// Fetches a single Engineering Object by ID.
  /// Throws [FoundationBridgeException] if no repository is open or no
  /// object with that ID exists.
  EngineeringObjectSummary getObjectById(String objectId) {
    _assertNotDisposed();
    final idPointer = objectId.toNativeUtf8();
    final objectPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(_bindings.objectStoreGetById(_runtime, idPointer, objectPointer));
      return EngineeringObjectSummary.fromNative(objectPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(objectPointer);
    }
  }

  /// Enumerates every Engineering Object in the currently open
  /// repository, sorted deterministically by object ID (the same order
  /// Foundation itself guarantees — Studio never re-sorts the raw list).
  /// Throws [FoundationBridgeException] if no repository is open.
  List<EngineeringObjectSummary> listObjects() {
    _assertNotDisposed();
    final listPointer = malloc<OepObjectListNative>();
    try {
      _checkResult(_bindings.objectStoreList(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) EngineeringObjectSummary.fromNative(list.items[i])];
      } finally {
        // Foundation-owned heap array: release through Foundation's own
        // function, never malloc.free/free directly (see oep_api.h's
        // ownership contract for oep_object_list_t).
        _bindings.objectListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// The number of Relationships in the currently open repository.
  /// Throws [FoundationBridgeException] if no repository is open.
  int getRelationshipCount() {
    _assertNotDisposed();
    final countPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.relationshipStoreGetCount(_runtime, countPointer));
      return countPointer.value;
    } finally {
      malloc.free(countPointer);
    }
  }

  /// Fetches a single Relationship by ID. [objectNamesById] resolves
  /// its source/target display names (see [RelationshipSummary.fromNative]).
  /// Throws [FoundationBridgeException] if no repository is open or no
  /// relationship with that ID exists.
  RelationshipSummary getRelationshipById(String relationshipId, {required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final idPointer = relationshipId.toNativeUtf8();
    final relationshipPointer = malloc<OepRelationshipInfoNative>();
    try {
      _checkResult(_bindings.relationshipStoreGetById(_runtime, idPointer, relationshipPointer));
      return RelationshipSummary.fromNative(relationshipPointer.ref, objectNamesById: objectNamesById);
    } finally {
      malloc.free(idPointer);
      malloc.free(relationshipPointer);
    }
  }

  /// Enumerates every Relationship in the currently open repository,
  /// sorted deterministically by relationship ID (the same order
  /// Foundation itself guarantees — Studio never re-sorts the raw list).
  /// [objectNamesById] resolves source/target display names.
  /// Throws [FoundationBridgeException] if no repository is open.
  List<RelationshipSummary> listRelationships({required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final listPointer = malloc<OepRelationshipListNative>();
    try {
      _checkResult(_bindings.relationshipStoreList(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [
          for (var i = 0; i < list.count; i++)
            RelationshipSummary.fromNative(list.items[i], objectNamesById: objectNamesById),
        ];
      } finally {
        // Foundation-owned heap array: release through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.relationshipListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Searches Engineering Objects only for [query] (case-insensitive,
  /// partial-match, per Foundation's SearchEngine). Results are returned
  /// in exactly the order Foundation produced them — never reordered.
  /// Throws [FoundationBridgeException] if no repository is open or
  /// [query] is empty.
  List<SearchResult> searchObjects(String query) {
    _assertNotDisposed();
    final queryPointer = query.toNativeUtf8();
    final listPointer = malloc<OepObjectSearchResultListNative>();
    try {
      _checkResult(_bindings.searchObjects(_runtime, queryPointer, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) SearchResult.fromNativeObject(list.items[i])];
      } finally {
        _bindings.objectSearchResultListRelease(listPointer);
      }
    } finally {
      malloc.free(queryPointer);
      malloc.free(listPointer);
    }
  }

  /// Searches Relationships only for [query]. [objectNamesById] resolves
  /// each hit's source/target display names for [SearchResult.name].
  /// Throws [FoundationBridgeException] if no repository is open or
  /// [query] is empty.
  List<SearchResult> searchRelationships(String query, {required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final queryPointer = query.toNativeUtf8();
    final listPointer = malloc<OepRelationshipSearchResultListNative>();
    try {
      _checkResult(_bindings.searchRelationships(_runtime, queryPointer, listPointer));
      final list = listPointer.ref;
      try {
        return [
          for (var i = 0; i < list.count; i++)
            SearchResult.fromNativeRelationship(list.items[i], objectNamesById: objectNamesById),
        ];
      } finally {
        _bindings.relationshipSearchResultListRelease(listPointer);
      }
    } finally {
      malloc.free(queryPointer);
      malloc.free(listPointer);
    }
  }

  /// Searches both Engineering Objects and Relationships for [query].
  /// Returns every object hit followed by every relationship hit — each
  /// group in exactly the order Foundation's SearchEngine produced it,
  /// matching `oep_repository_search_result_t`'s own two-list, never-
  /// merged shape (and `oep search`'s own "Objects: ... / Relationships:
  /// ..." presentation) rather than interleaving or re-sorting them by
  /// score. Throws [FoundationBridgeException] if no repository is open
  /// or [query] is empty.
  List<SearchResult> searchRepository(String query, {required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final queryPointer = query.toNativeUtf8();
    final resultPointer = malloc<OepRepositorySearchResultNative>();
    try {
      _checkResult(_bindings.searchRepository(_runtime, queryPointer, resultPointer));
      final result = resultPointer.ref;
      try {
        return [
          for (var i = 0; i < result.objectCount; i++) SearchResult.fromNativeObject(result.objectItems[i]),
          for (var i = 0; i < result.relationshipCount; i++)
            SearchResult.fromNativeRelationship(result.relationshipItems[i], objectNamesById: objectNamesById),
        ];
      } finally {
        _bindings.repositorySearchResultRelease(resultPointer);
      }
    } finally {
      malloc.free(queryPointer);
      malloc.free(resultPointer);
    }
  }

  /// Creates a new Engineering Object (Work Package 012/Foundation Work
  /// Package 014's `oep_object_create`, the first write-capable function
  /// in this API). [name] must not be empty — Foundation's own
  /// validation rejects it with [FoundationErrorCategory.validation].
  /// Throws [FoundationBridgeException] if no repository is open or
  /// Foundation rejects the object. If a transaction is active
  /// (see [beginTransaction]) and this call fails, Foundation
  /// automatically rolls the transaction back before the failure is
  /// returned — the caller does not need to (but safely may) call
  /// [rollbackTransaction] itself afterward.
  EngineeringObjectSummary createObject({
    required ObjectCategory category,
    required String name,
    String description = '',
    String author = '',
    List<String> tags = const [],
  }) {
    _assertNotDisposed();
    final namePointer = name.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final tagsPointer = _allocateTagArray(tags);
    final outObjectPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(
        _bindings.objectCreate(
          _runtime,
          category.nativeValue,
          namePointer,
          descriptionPointer,
          authorPointer,
          tagsPointer,
          tags.length,
          outObjectPointer,
        ),
      );
      return EngineeringObjectSummary.fromNative(outObjectPointer.ref);
    } finally {
      malloc.free(namePointer);
      malloc.free(descriptionPointer);
      malloc.free(authorPointer);
      _freeTagArray(tagsPointer, tags.length);
      malloc.free(outObjectPointer);
    }
  }

  /// Creates a new Relationship between two existing Engineering
  /// Objects (Foundation Work Package 014's `oep_relationship_create`).
  /// [objectNamesById] resolves the created relationship's source/
  /// target display names (see [RelationshipSummary.fromNative]) — the
  /// caller already knows both names (it just supplied both IDs), so
  /// this never needs a fresh Current Object List fetch. Throws
  /// [FoundationBridgeException] if no repository is open, either
  /// referenced object doesn't exist, or the relationship is otherwise
  /// invalid (e.g. source equals target). Same automatic-rollback-on-
  /// failure behavior as [createObject] while a transaction is active.
  RelationshipSummary createRelationship({
    required String sourceObjectId,
    required String targetObjectId,
    required RelationshipType type,
    String author = '',
    String description = '',
    required Map<String, String> objectNamesById,
  }) {
    _assertNotDisposed();
    final sourcePointer = sourceObjectId.toNativeUtf8();
    final targetPointer = targetObjectId.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final outRelationshipPointer = malloc<OepRelationshipInfoNative>();
    try {
      _checkResult(
        _bindings.relationshipCreate(
          _runtime,
          sourcePointer,
          targetPointer,
          type.nativeValue,
          authorPointer,
          descriptionPointer,
          outRelationshipPointer,
        ),
      );
      return RelationshipSummary.fromNative(outRelationshipPointer.ref, objectNamesById: objectNamesById);
    } finally {
      malloc.free(sourcePointer);
      malloc.free(targetPointer);
      malloc.free(authorPointer);
      malloc.free(descriptionPointer);
      malloc.free(outRelationshipPointer);
    }
  }

  /// Replaces name/description/author/tags on the Engineering Object
  /// identified by [objectId] (`oep_object_update`, AP-DS-002 — bound
  /// for the first time this session; the underlying C function
  /// existed since Work Package 014). [objectId], [objectType], and
  /// the object's created timestamp never change. Throws
  /// [FoundationBridgeException] with [FoundationErrorCategory.notFound]
  /// if no object with [objectId] exists. Same automatic-rollback-
  /// on-failure behavior as [createObject] while a transaction is
  /// active.
  EngineeringObjectSummary updateObject({
    required String objectId,
    required String name,
    String description = '',
    String author = '',
    List<String> tags = const [],
  }) {
    _assertNotDisposed();
    final objectIdPointer = objectId.toNativeUtf8();
    final namePointer = name.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final tagsPointer = _allocateTagArray(tags);
    final outObjectPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(
        _bindings.objectUpdate(
          _runtime,
          objectIdPointer,
          namePointer,
          descriptionPointer,
          authorPointer,
          tagsPointer,
          tags.length,
          outObjectPointer,
        ),
      );
      return EngineeringObjectSummary.fromNative(outObjectPointer.ref);
    } finally {
      malloc.free(objectIdPointer);
      malloc.free(namePointer);
      malloc.free(descriptionPointer);
      malloc.free(authorPointer);
      _freeTagArray(tagsPointer, tags.length);
      malloc.free(outObjectPointer);
    }
  }

  /// Deletes the Engineering Object identified by [objectId]
  /// (`oep_object_delete`, AP-DS-002). Does not cascade to
  /// Relationships referencing the deleted object — mirrors
  /// Foundation's own `ObjectStore::remove` behavior. Throws
  /// [FoundationBridgeException] with [FoundationErrorCategory.notFound]
  /// if no such object exists.
  void deleteObject(String objectId) {
    _assertNotDisposed();
    final objectIdPointer = objectId.toNativeUtf8();
    try {
      _checkResult(_bindings.objectDelete(_runtime, objectIdPointer));
    } finally {
      malloc.free(objectIdPointer);
    }
  }

  /// Replaces `content` on the Engineering Object identified by
  /// [objectId] (`oep_object_update_content`, AP-DS-002); every other
  /// field is left unchanged. `content` is an opaque, application-
  /// owned payload — Foundation never parses it (see
  /// `EngineeringObject::content`'s doc comment in oep_foundation).
  /// Diagram Studio uses this to persist a diagram's presentation-only
  /// state (layout, viewport, layers, annotations, selection) that has
  /// no independent engineering meaning of its own. Throws
  /// [FoundationBridgeException] with [FoundationErrorCategory.notFound]
  /// if no object with [objectId] exists.
  EngineeringObjectSummary updateObjectContent({required String objectId, required String content}) {
    _assertNotDisposed();
    final objectIdPointer = objectId.toNativeUtf8();
    final contentPointer = content.toNativeUtf8();
    final outObjectPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(_bindings.objectUpdateContent(_runtime, objectIdPointer, contentPointer, outObjectPointer));
      return EngineeringObjectSummary.fromNative(outObjectPointer.ref);
    } finally {
      malloc.free(objectIdPointer);
      malloc.free(contentPointer);
      malloc.free(outObjectPointer);
    }
  }

  /// Returns the `content` payload of the Engineering Object
  /// identified by [objectId] (`oep_object_get_content`, AP-DS-002) —
  /// the read counterpart to [updateObjectContent]. An object with no
  /// content (including every object that predates this field) returns
  /// an empty string, not an error. Throws [FoundationBridgeException]
  /// with [FoundationErrorCategory.notFound] if no object with
  /// [objectId] exists. Uses the same owned-heap-string convention as
  /// [exportKnowledgeGraphJson] (see [_kgeExportText]), released via
  /// exactly one [OepApiBindings.stringRelease] call.
  String getObjectContent(String objectId) {
    _assertNotDisposed();
    final objectIdPointer = objectId.toNativeUtf8();
    final textPointer = malloc<Pointer<Utf8>>();
    final lengthPointer = malloc<Size>();
    textPointer.value = nullptr;
    try {
      _checkResult(_bindings.objectGetContent(_runtime, objectIdPointer, textPointer, lengthPointer));
      try {
        return textPointer.value.toDartString(length: lengthPointer.value);
      } finally {
        _bindings.stringRelease(textPointer);
      }
    } finally {
      malloc.free(objectIdPointer);
      malloc.free(textPointer);
      malloc.free(lengthPointer);
    }
  }

  /// Replaces author/description on the Relationship identified by
  /// [relationshipId] (`oep_relationship_update`, AP-DS-002 — bound for
  /// the first time this session). [relationshipId], source/target
  /// object ids, [type], and the created timestamp never change.
  /// Throws [FoundationBridgeException] with
  /// [FoundationErrorCategory.notFound] if no such relationship
  /// exists.
  RelationshipSummary updateRelationship({
    required String relationshipId,
    String author = '',
    String description = '',
    required Map<String, String> objectNamesById,
  }) {
    _assertNotDisposed();
    final relationshipIdPointer = relationshipId.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final outRelationshipPointer = malloc<OepRelationshipInfoNative>();
    try {
      _checkResult(
        _bindings.relationshipUpdate(
          _runtime,
          relationshipIdPointer,
          authorPointer,
          descriptionPointer,
          outRelationshipPointer,
        ),
      );
      return RelationshipSummary.fromNative(outRelationshipPointer.ref, objectNamesById: objectNamesById);
    } finally {
      malloc.free(relationshipIdPointer);
      malloc.free(authorPointer);
      malloc.free(descriptionPointer);
      malloc.free(outRelationshipPointer);
    }
  }

  /// Deletes the Relationship identified by [relationshipId]
  /// (`oep_relationship_delete`, AP-DS-002). Throws
  /// [FoundationBridgeException] with [FoundationErrorCategory.notFound]
  /// if no such relationship exists.
  void deleteRelationship(String relationshipId) {
    _assertNotDisposed();
    final relationshipIdPointer = relationshipId.toNativeUtf8();
    try {
      _checkResult(_bindings.relationshipDelete(_runtime, relationshipIdPointer));
    } finally {
      malloc.free(relationshipIdPointer);
    }
  }

  /// Creates a new diagram/graph identity (`oep_diagram_create`,
  /// AP-OEP-FOUNDATION-GRAPH-IDENTITY-001/AP-OEP-FOUNDATION-BRIDGE-002)
  /// — an `OEP_OBJECT_TYPE_DIAGRAM` Engineering Object whose `objectId`
  /// becomes the diagram's persistent identity. Throws
  /// [FoundationBridgeException] if no repository is open.
  EngineeringObjectSummary createDiagram({required String name, String description = '', String author = ''}) {
    _assertNotDisposed();
    final namePointer = name.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final outDiagramPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(_bindings.diagramCreate(_runtime, namePointer, descriptionPointer, authorPointer, outDiagramPointer));
      return EngineeringObjectSummary.fromNative(outDiagramPointer.ref);
    } finally {
      malloc.free(namePointer);
      malloc.free(descriptionPointer);
      malloc.free(authorPointer);
      malloc.free(outDiagramPointer);
    }
  }

  /// Resolves the diagram identity [diagramId] (`oep_diagram_get`).
  /// Throws [FoundationBridgeException] (not-found) if no such diagram
  /// exists, or an object with that id exists but is not a diagram.
  EngineeringObjectSummary getDiagram(String diagramId) {
    _assertNotDisposed();
    final idPointer = diagramId.toNativeUtf8();
    final outDiagramPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(_bindings.diagramGet(_runtime, idPointer, outDiagramPointer));
      return EngineeringObjectSummary.fromNative(outDiagramPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(outDiagramPointer);
    }
  }

  /// Creates a new Engineering Object as a member of [diagramId]
  /// (`oep_object_create_with_diagram`) — the same contract as
  /// [createObject], plus referential-integrity validation of
  /// [diagramId] against [getDiagram]. Throws
  /// [FoundationBridgeException] with
  /// [FoundationErrorCategory.validation] if [diagramId] does not name
  /// an existing diagram (nothing is persisted in that case).
  EngineeringObjectSummary createObjectInDiagram({
    required ObjectCategory category,
    required String name,
    required String diagramId,
    String description = '',
    String author = '',
    List<String> tags = const [],
  }) {
    _assertNotDisposed();
    final namePointer = name.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final diagramIdPointer = diagramId.toNativeUtf8();
    final tagsPointer = _allocateTagArray(tags);
    final outObjectPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(
        _bindings.objectCreateWithDiagram(
          _runtime,
          category.nativeValue,
          namePointer,
          descriptionPointer,
          authorPointer,
          tagsPointer,
          tags.length,
          diagramIdPointer,
          outObjectPointer,
        ),
      );
      return EngineeringObjectSummary.fromNative(outObjectPointer.ref);
    } finally {
      malloc.free(namePointer);
      malloc.free(descriptionPointer);
      malloc.free(authorPointer);
      malloc.free(diagramIdPointer);
      _freeTagArray(tagsPointer, tags.length);
      malloc.free(outObjectPointer);
    }
  }

  /// Creates a new Relationship as a member of [diagramId]
  /// (`oep_relationship_create_with_diagram`) — the same contract as
  /// [createRelationship], plus the same [diagramId] validation
  /// [createObjectInDiagram] performs. Throws [FoundationBridgeException]
  /// with [FoundationErrorCategory.validation] if [diagramId] does not
  /// name an existing diagram.
  RelationshipSummary createRelationshipInDiagram({
    required String sourceObjectId,
    required String targetObjectId,
    required RelationshipType type,
    required String diagramId,
    String author = '',
    String description = '',
    required Map<String, String> objectNamesById,
  }) {
    _assertNotDisposed();
    final sourcePointer = sourceObjectId.toNativeUtf8();
    final targetPointer = targetObjectId.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final diagramIdPointer = diagramId.toNativeUtf8();
    final outRelationshipPointer = malloc<OepRelationshipInfoNative>();
    try {
      _checkResult(
        _bindings.relationshipCreateWithDiagram(
          _runtime,
          sourcePointer,
          targetPointer,
          type.nativeValue,
          authorPointer,
          descriptionPointer,
          diagramIdPointer,
          outRelationshipPointer,
        ),
      );
      return RelationshipSummary.fromNative(outRelationshipPointer.ref, objectNamesById: objectNamesById);
    } finally {
      malloc.free(sourcePointer);
      malloc.free(targetPointer);
      malloc.free(authorPointer);
      malloc.free(descriptionPointer);
      malloc.free(diagramIdPointer);
      malloc.free(outRelationshipPointer);
    }
  }

  /// Enumerates exactly the Engineering Objects belonging to [diagramId]
  /// (`oep_diagram_get_objects`) — never the whole repository. Sorted
  /// deterministically by object ID, the same ordering guarantee
  /// [listObjects] provides. An empty diagram returns an empty list
  /// successfully. Throws [FoundationBridgeException] with
  /// [FoundationErrorCategory.validation] if [diagramId] does not name
  /// an existing diagram — distinct from a valid, empty diagram.
  List<EngineeringObjectSummary> getDiagramObjects(String diagramId) {
    _assertNotDisposed();
    final idPointer = diagramId.toNativeUtf8();
    final listPointer = malloc<OepObjectListNative>();
    try {
      _checkResult(_bindings.diagramGetObjects(_runtime, idPointer, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) EngineeringObjectSummary.fromNative(list.items[i])];
      } finally {
        // Foundation-owned heap array: release through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.objectListRelease(listPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(listPointer);
    }
  }

  /// Enumerates exactly the Relationships belonging to [diagramId]
  /// (`oep_diagram_get_relationships`) — never the whole repository.
  /// Same determinism/ownership/error contract as [getDiagramObjects].
  /// [objectNamesById] resolves source/target display names, exactly as
  /// [listRelationships] does.
  List<RelationshipSummary> getDiagramRelationships(
    String diagramId, {
    required Map<String, String> objectNamesById,
  }) {
    _assertNotDisposed();
    final idPointer = diagramId.toNativeUtf8();
    final listPointer = malloc<OepRelationshipListNative>();
    try {
      _checkResult(_bindings.diagramGetRelationships(_runtime, idPointer, listPointer));
      final list = listPointer.ref;
      try {
        return [
          for (var i = 0; i < list.count; i++)
            RelationshipSummary.fromNative(list.items[i], objectNamesById: objectNamesById),
        ];
      } finally {
        // Foundation-owned heap array: release through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.relationshipListRelease(listPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(listPointer);
    }
  }

  /// Begins a transaction (Foundation Work Package 014's
  /// `oep_transaction_begin`) — "Repository Commit shall execute as one
  /// logical transaction" (Work Package 012). Only one transaction may
  /// be active per Runtime; a nested call fails with
  /// [FoundationErrorCategory.state]. Each mutation still writes
  /// immediately when called (Foundation's stores have no staged/
  /// uncommitted write concept); while a transaction is active,
  /// Foundation additionally records what each successful mutation
  /// would need to undo it, so [rollbackTransaction] can reverse
  /// everything performed since this call.
  void beginTransaction() {
    _assertNotDisposed();
    _checkResult(_bindings.transactionBegin(_runtime));
  }

  /// Commits the active transaction — discards its undo record (every
  /// mutation within it already persisted; there is nothing further to
  /// write). Throws [FoundationBridgeException] if no transaction is
  /// active.
  void commitTransaction() {
    _assertNotDisposed();
    _checkResult(_bindings.transactionCommit(_runtime));
  }

  /// Rolls back the active transaction, undoing every mutation
  /// performed since [beginTransaction] in reverse order. Throws
  /// [FoundationBridgeException] if no transaction is active.
  void rollbackTransaction() {
    _assertNotDisposed();
    _checkResult(_bindings.transactionRollback(_runtime));
  }

  /// Whether a transaction is currently active on this Runtime.
  bool get isTransactionActive {
    _assertNotDisposed();
    return _bindings.transactionIsActive(_runtime) != 0;
  }

  /// Installs a validated `.oep` package archive (WP-REP-001 — Repository
  /// Runtime, first vertical slice) into the currently open repository —
  /// extracting its Repository Fragment's Engineering Objects and
  /// Relationships, recording the install in the Package Registry, and
  /// rebuilding the Search/Graph indexes.
  ///
  /// Not transactional: a failure partway through does not roll back
  /// objects/relationships already created (see
  /// `oep::runtime::FoundationRuntime::install_package`'s own
  /// documentation, `oep_foundation/platform/runtime`). Dependency
  /// resolution, signature verification, updates, and uninstallation are
  /// not part of this surface — see `OEP-ARCH-002` for the roadmap.
  /// Throws [FoundationBridgeException] on failure (including "already
  /// installed" and "no repository is open").
  PackageInstallResult installPackage(String archivePath) {
    _assertNotDisposed();
    final pathPointer = archivePath.toNativeUtf8();
    final resultPointer = malloc<OepPackageInstallResultNative>();
    try {
      _checkResult(_bindings.packageInstall(_runtime, pathPointer, resultPointer));
      return PackageInstallResult.fromNative(resultPointer.ref);
    } finally {
      malloc.free(pathPointer);
      malloc.free(resultPointer);
    }
  }

  /// Lists every package the Package Registry has recorded as installed
  /// in the currently open repository (WP-REP-001).
  /// Throws [FoundationBridgeException] if no repository is open.
  List<InstalledPackageInfo> listInstalledPackages() {
    _assertNotDisposed();
    final listPointer = malloc<OepInstalledPackageListNative>();
    try {
      _checkResult(_bindings.packageListInstalled(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) InstalledPackageInfo.fromNative(list.items[i])];
      } finally {
        // Foundation-owned heap array: release through Foundation's own
        // function, never malloc.free/free directly — see
        // oep_api.h's ownership contract for oep_installed_package_list_t.
        _bindings.installedPackageListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// The full Repository Registry record for [packageId] (WP-REP-002 —
  /// Repository Registry & Lifecycle): manifest metadata, publisher,
  /// installation path, package hash, runtime state, and contribution
  /// counts. Throws [FoundationBridgeException] if no repository is open
  /// or the package is not installed.
  PackageDetails getPackageInfo(String packageId) {
    _assertNotDisposed();
    final idPointer = packageId.toNativeUtf8();
    final detailsPointer = malloc<OepPackageDetailsNative>();
    try {
      _checkResult(_bindings.packageGetInfo(_runtime, idPointer, detailsPointer));
      return PackageDetails.fromNative(detailsPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(detailsPointer);
    }
  }

  /// The Engineering Objects and Relationships the package identified by
  /// [packageId] contributed, loaded live from the repository's own
  /// stores (never duplicated into the Repository Registry). A recorded
  /// contribution that has since been deleted is simply absent — use
  /// [verifyPackage] to detect that condition explicitly.
  /// [objectNamesById] resolves each relationship's source/target
  /// display names, exactly as [listRelationships] does.
  /// Throws [FoundationBridgeException] if no repository is open or the
  /// package is not installed.
  ({List<EngineeringObjectSummary> objects, List<RelationshipSummary> relationships}) getPackageContents(
    String packageId, {
    required Map<String, String> objectNamesById,
  }) {
    _assertNotDisposed();
    final idPointer = packageId.toNativeUtf8();
    final objectsPointer = malloc<OepObjectListNative>();
    final relationshipsPointer = malloc<OepRelationshipListNative>();
    try {
      _checkResult(_bindings.packageGetContents(_runtime, idPointer, objectsPointer, relationshipsPointer));
      try {
        final objects = [
          for (var i = 0; i < objectsPointer.ref.count; i++)
            EngineeringObjectSummary.fromNative(objectsPointer.ref.items[i]),
        ];
        final relationships = [
          for (var i = 0; i < relationshipsPointer.ref.count; i++)
            RelationshipSummary.fromNative(relationshipsPointer.ref.items[i], objectNamesById: objectNamesById),
        ];
        return (objects: objects, relationships: relationships);
      } finally {
        // Foundation-owned heap arrays: released through Foundation's own
        // functions — the same pair every other object/relationship list
        // in this API uses.
        _bindings.objectListRelease(objectsPointer);
        _bindings.relationshipListRelease(relationshipsPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(objectsPointer);
      malloc.free(relationshipsPointer);
    }
  }

  /// Which installed package (if any) contributed the Engineering Object
  /// or Relationship identified by [entityId]. An entity no package owns
  /// returns [PackageOwner.found] == false — a normal answer, not an
  /// exception. Throws [FoundationBridgeException] if no repository is
  /// open.
  PackageOwner locatePackageOwner(String entityId) {
    _assertNotDisposed();
    final idPointer = entityId.toNativeUtf8();
    final ownerPointer = malloc<OepPackageOwnerNative>();
    try {
      _checkResult(_bindings.packageLocate(_runtime, idPointer, ownerPointer));
      return PackageOwner.fromNative(ownerPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(ownerPointer);
    }
  }

  /// Verifies [packageId]'s installation status against live repository
  /// state (WP-REP-002). A package that fails verification still returns
  /// normally — the outcome is [PackageVerifyResult.verified]; only an
  /// operational problem (no repository open, package not installed)
  /// throws [FoundationBridgeException].
  PackageVerifyResult verifyPackage(String packageId) {
    _assertNotDisposed();
    final idPointer = packageId.toNativeUtf8();
    final resultPointer = malloc<OepPackageVerifyResultNative>();
    try {
      _checkResult(_bindings.packageVerify(_runtime, idPointer, resultPointer));
      return PackageVerifyResult.fromNative(resultPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(resultPointer);
    }
  }

  /// Searches installed packages for [query] (case-insensitive substring
  /// match over registry metadata plus the names of each package's
  /// installed Engineering Objects). Results are sorted deterministically
  /// by package ID. Throws [FoundationBridgeException] if no repository
  /// is open or [query] is empty.
  List<InstalledPackageInfo> searchInstalledPackages(String query) {
    _assertNotDisposed();
    final queryPointer = query.toNativeUtf8();
    final listPointer = malloc<OepInstalledPackageListNative>();
    try {
      _checkResult(_bindings.packageSearch(_runtime, queryPointer, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) InstalledPackageInfo.fromNative(list.items[i])];
      } finally {
        _bindings.installedPackageListRelease(listPointer);
      }
    } finally {
      malloc.free(queryPointer);
      malloc.free(listPointer);
    }
  }

  /// The currently active Repository Transaction, if any (WP-REP-003 —
  /// Repository Transaction Engine). [TransactionInfo.active] == false is
  /// a normal answer, not an exception. Throws
  /// [FoundationBridgeException] if no repository is open.
  TransactionInfo getTransactionInfo() {
    _assertNotDisposed();
    final infoPointer = malloc<OepTransactionInfoNative>();
    try {
      _checkResult(_bindings.transactionGetInfo(_runtime, infoPointer));
      return TransactionInfo.fromNative(infoPointer.ref);
    } finally {
      malloc.free(infoPointer);
    }
  }

  /// Every journaled (closed) Repository Transaction for the open
  /// repository, sorted by opened time then id (WP-REP-003). Throws
  /// [FoundationBridgeException] if no repository is open.
  List<TransactionRecordSummary> listTransactionHistory() {
    _assertNotDisposed();
    final listPointer = malloc<OepTransactionRecordListNative>();
    try {
      _checkResult(_bindings.transactionHistory(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) TransactionRecordSummary.fromNative(list.items[i])];
      } finally {
        _bindings.transactionRecordListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Adds (trusts) a publisher certificate to this repository's Trust
  /// Store (WP-REP-004 — Trust & Signing). [publisherId] and
  /// [publicKeyHex] (exactly 64 hex characters) are required;
  /// [publisherName]/[issuedUtc]/[expiresUtc]/[issuer]/[version] are
  /// optional, matching `oep_trust_add_certificate`'s own NULL-means-
  /// empty contract. Throws [FoundationBridgeException] if the publisher
  /// already has a certificate (renewal is out of scope) or the key is
  /// malformed.
  PublisherCertificate trustAddCertificate(
    String publisherId,
    String publicKeyHex, {
    String? publisherName,
    String? issuedUtc,
    String? expiresUtc,
    String? issuer,
    String? version,
  }) {
    _assertNotDisposed();
    final publisherIdPointer = publisherId.toNativeUtf8();
    final publicKeyPointer = publicKeyHex.toNativeUtf8();
    final namePointer = publisherName?.toNativeUtf8() ?? nullptr;
    final issuedPointer = issuedUtc?.toNativeUtf8() ?? nullptr;
    final expiresPointer = expiresUtc?.toNativeUtf8() ?? nullptr;
    final issuerPointer = issuer?.toNativeUtf8() ?? nullptr;
    final versionPointer = version?.toNativeUtf8() ?? nullptr;
    final certificatePointer = malloc<OepPublisherCertificateNative>();
    try {
      _checkResult(
        _bindings.trustAddCertificate(
          _runtime,
          publisherIdPointer,
          namePointer,
          publicKeyPointer,
          issuedPointer,
          expiresPointer,
          issuerPointer,
          versionPointer,
          certificatePointer,
        ),
      );
      return PublisherCertificate.fromNative(certificatePointer.ref);
    } finally {
      malloc.free(publisherIdPointer);
      malloc.free(publicKeyPointer);
      if (namePointer != nullptr) malloc.free(namePointer);
      if (issuedPointer != nullptr) malloc.free(issuedPointer);
      if (expiresPointer != nullptr) malloc.free(expiresPointer);
      if (issuerPointer != nullptr) malloc.free(issuerPointer);
      if (versionPointer != nullptr) malloc.free(versionPointer);
      malloc.free(certificatePointer);
    }
  }

  /// The certificate trusted for [publisherId]. Throws
  /// [FoundationBridgeException] if no certificate is on file for that
  /// publisher, or if no repository is open.
  PublisherCertificate trustGetCertificate(String publisherId) {
    _assertNotDisposed();
    final idPointer = publisherId.toNativeUtf8();
    final certificatePointer = malloc<OepPublisherCertificateNative>();
    try {
      _checkResult(_bindings.trustGetCertificate(_runtime, idPointer, certificatePointer));
      return PublisherCertificate.fromNative(certificatePointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(certificatePointer);
    }
  }

  /// Every certificate in this repository's Trust Store, trusted and
  /// revoked alike (check [PublisherCertificate.revoked]). Throws
  /// [FoundationBridgeException] if no repository is open.
  List<PublisherCertificate> trustListCertificates() {
    _assertNotDisposed();
    final listPointer = malloc<OepCertificateListNative>();
    try {
      _checkResult(_bindings.trustListCertificates(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) PublisherCertificate.fromNative(list.items[i])];
      } finally {
        _bindings.certificateListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Revokes [publisherId]'s trusted certificate. The certificate record
  /// is kept, marked revoked — this does not uninstall any package
  /// already installed from that publisher. Throws
  /// [FoundationBridgeException] if no certificate is on file, or it is
  /// already revoked.
  void trustRevokeCertificate(String publisherId) {
    _assertNotDisposed();
    final idPointer = publisherId.toNativeUtf8();
    try {
      _checkResult(_bindings.trustRevokeCertificate(_runtime, idPointer));
    } finally {
      malloc.free(idPointer);
    }
  }

  /// This repository's trust policy: true iff unsigned packages are
  /// rejected at install. The default is false. Throws
  /// [FoundationBridgeException] if no repository is open.
  bool trustGetPolicy() {
    _assertNotDisposed();
    final requireSignaturesPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.trustGetPolicy(_runtime, requireSignaturesPointer));
      return requireSignaturesPointer.value != 0;
    } finally {
      malloc.free(requireSignaturesPointer);
    }
  }

  /// Sets this repository's trust policy. Throws
  /// [FoundationBridgeException] if no repository is open.
  void trustSetPolicy(bool requireSignatures) {
    _assertNotDisposed();
    _checkResult(_bindings.trustSetPolicy(_runtime, requireSignatures ? 1 : 0));
  }

  /// The trust outcome recorded for [packageId] at install time
  /// (WP-REP-004). Throws [FoundationBridgeException] if no package with
  /// that ID is installed.
  PackageTrustStatus getPackageTrustStatus(String packageId) {
    _assertNotDisposed();
    final idPointer = packageId.toNativeUtf8();
    final statusPointer = malloc<OepPackageTrustStatusNative>();
    try {
      _checkResult(_bindings.packageGetTrustStatus(_runtime, idPointer, statusPointer));
      return PackageTrustStatus.fromNative(statusPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(statusPointer);
    }
  }

  /// Resolves the .oep archive at [archivePath] against the currently
  /// open repository's installed packages, WITHOUT installing anything
  /// (WP-REP-005 — Dependency Resolution Engine). Entirely offline and
  /// side-effect free — safe to call as a pre-flight check or purely for
  /// diagnostics. A resolution that fails on its own merits (a missing,
  /// conflicting, or cyclic dependency) is not an error; it is reported
  /// in the returned [OepDependencyResolutionResult.resolved]. Throws
  /// [FoundationBridgeException] if no repository is open or the archive
  /// cannot be read/parsed.
  ({OepDependencyResolutionResult result, List<OepDependencyEntry> entries, List<String> installOrder})
  resolveDependencies(String archivePath) {
    _assertNotDisposed();
    final pathPointer = archivePath.toNativeUtf8();
    final resultPointer = malloc<OepDependencyResolutionResultNative>();
    final entriesPointer = malloc<OepDependencyEntryListNative>();
    final installOrderPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.packageResolveDependencies(_runtime, pathPointer, resultPointer, entriesPointer, installOrderPointer),
      );
      try {
        final result = OepDependencyResolutionResult.fromNative(resultPointer.ref);
        final entries = [
          for (var i = 0; i < entriesPointer.ref.count; i++)
            OepDependencyEntry.fromNative(entriesPointer.ref.items[i]),
        ];
        final installOrder = [
          for (var i = 0; i < installOrderPointer.ref.count; i++)
            decodeFixedCString(installOrderPointer.ref.items[i].id, oepMaxPackageId),
        ];
        return (result: result, entries: entries, installOrder: installOrder);
      } finally {
        // Foundation-owned heap arrays: released through Foundation's own
        // functions, never malloc.free/free directly.
        _bindings.dependencyEntryListRelease(entriesPointer);
        _bindings.packageIdListRelease(installOrderPointer);
      }
    } finally {
      malloc.free(pathPointer);
      malloc.free(resultPointer);
      malloc.free(entriesPointer);
      malloc.free(installOrderPointer);
    }
  }

  /// The most recently published Repository Events (WP-REP-006), oldest
  /// first, capped at [limit] (0, the default, means "no limit", subject
  /// to the Runtime's own internal retention bound). Valid regardless of
  /// whether a repository is open — a freshly-initialized Runtime simply
  /// reports zero events.
  List<OepRepositoryEvent> recentEvents({int limit = 0}) {
    _assertNotDisposed();
    final listPointer = malloc<OepRepositoryEventListNative>();
    try {
      _checkResult(_bindings.runtimeRecentEvents(_runtime, limit, listPointer));
      try {
        return [
          for (var i = 0; i < listPointer.ref.count; i++) OepRepositoryEvent.fromNative(listPointer.ref.items[i]),
        ];
      } finally {
        // Foundation-owned heap array: released through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.repositoryEventListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Analyzes what uninstalling [packageId] would affect, WITHOUT
  /// uninstalling anything (WP-REP-007 — Package Uninstall/Update
  /// Lifecycle). Entirely side-effect free — safe to call as a pre-flight
  /// check. [OepUninstallImpact.found] == false is a normal answer (the
  /// package is not installed), not an exception. Throws
  /// [FoundationBridgeException] if no repository is open.
  ({OepUninstallImpact impact, List<String> blockingDependents}) analyzeUninstallImpact(String packageId) {
    _assertNotDisposed();
    final idPointer = packageId.toNativeUtf8();
    final impactPointer = malloc<OepUninstallImpactNative>();
    final blockingPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.packageAnalyzeUninstallImpact(_runtime, idPointer, impactPointer, blockingPointer));
      try {
        final impact = OepUninstallImpact.fromNative(impactPointer.ref);
        final blockingDependents = [
          for (var i = 0; i < blockingPointer.ref.count; i++)
            decodeFixedCString(blockingPointer.ref.items[i].id, oepMaxPackageId),
        ];
        return (impact: impact, blockingDependents: blockingDependents);
      } finally {
        // Foundation-owned heap array: released through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.packageIdListRelease(blockingPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(impactPointer);
      malloc.free(blockingPointer);
    }
  }

  /// Uninstalls [packageId] from the currently open repository
  /// (WP-REP-007), removing every Engineering Object and Relationship it
  /// contributed and its Package Registry record. Throws
  /// [FoundationBridgeException] if no repository is open, the package is
  /// not installed, or other installed packages depend on it (see
  /// [analyzeUninstallImpact] to check beforehand).
  OepPackageUninstallResult uninstallPackage(String packageId) {
    _assertNotDisposed();
    final idPointer = packageId.toNativeUtf8();
    final resultPointer = malloc<OepPackageUninstallResultNative>();
    try {
      _checkResult(_bindings.packageUninstall(_runtime, idPointer, resultPointer));
      return OepPackageUninstallResult.fromNative(resultPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(resultPointer);
    }
  }

  /// Analyzes what updating to the .oep archive at [archivePath] would
  /// affect, WITHOUT updating anything (WP-REP-007). Entirely side-effect
  /// free — safe to call as a pre-flight check. Throws
  /// [FoundationBridgeException] if no repository is open or the archive
  /// cannot be read/parsed.
  ({OepUpdateImpact impact, List<String> brokenDependents}) analyzeUpdateImpact(String archivePath) {
    _assertNotDisposed();
    final pathPointer = archivePath.toNativeUtf8();
    final impactPointer = malloc<OepUpdateImpactNative>();
    final brokenPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.packageAnalyzeUpdateImpact(_runtime, pathPointer, impactPointer, brokenPointer));
      try {
        final impact = OepUpdateImpact.fromNative(impactPointer.ref);
        final brokenDependents = [
          for (var i = 0; i < brokenPointer.ref.count; i++)
            decodeFixedCString(brokenPointer.ref.items[i].id, oepMaxPackageId),
        ];
        return (impact: impact, brokenDependents: brokenDependents);
      } finally {
        // Foundation-owned heap array: released through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.packageIdListRelease(brokenPointer);
      }
    } finally {
      malloc.free(pathPointer);
      malloc.free(impactPointer);
      malloc.free(brokenPointer);
    }
  }

  /// Updates an already-installed package to the version contained in the
  /// .oep archive at [archivePath] (WP-REP-007): removes the previous
  /// version's contributed Engineering Objects/Relationships, then
  /// installs the candidate's. Throws [FoundationBridgeException] if no
  /// repository is open, the archive cannot be read/parsed, the package is
  /// not currently installed, or the update would break another
  /// installed package's dependencies (see [analyzeUpdateImpact] to check
  /// beforehand).
  OepPackageUpdateResult updatePackage(String archivePath) {
    _assertNotDisposed();
    final pathPointer = archivePath.toNativeUtf8();
    final resultPointer = malloc<OepPackageUpdateResultNative>();
    try {
      _checkResult(_bindings.packageUpdate(_runtime, pathPointer, resultPointer));
      return OepPackageUpdateResult.fromNative(resultPointer.ref);
    } finally {
      malloc.free(pathPointer);
      malloc.free(resultPointer);
    }
  }

  /// Analyzes merging the .oep archive at [archivePath]'s Repository
  /// Fragment into the currently open repository, WITHOUT merging
  /// anything (WP-REP-008 — Merge Engine). Entirely side-effect free —
  /// safe to call as a pre-flight check. A plan that is not mergeable on
  /// its own merits (trust/dependency/conflicts/already registered) is a
  /// normal answer reflected in [OepMergePlan.mergeable], not an
  /// exception. Throws [FoundationBridgeException] if no repository is
  /// open or the archive cannot be read/parsed.
  ({OepMergePlan plan, List<OepMergeConflict> conflicts}) planMerge(String archivePath) {
    _assertNotDisposed();
    final pathPointer = archivePath.toNativeUtf8();
    final planPointer = malloc<OepMergePlanNative>();
    final conflictsPointer = malloc<OepMergeConflictListNative>();
    try {
      _checkResult(_bindings.repositoryPlanMerge(_runtime, pathPointer, planPointer, conflictsPointer));
      try {
        final plan = OepMergePlan.fromNative(planPointer.ref);
        final conflicts = [
          for (var i = 0; i < conflictsPointer.ref.count; i++)
            OepMergeConflict.fromNative(conflictsPointer.ref.items[i]),
        ];
        return (plan: plan, conflicts: conflicts);
      } finally {
        // Foundation-owned heap array: released through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.mergeConflictListRelease(conflictsPointer);
      }
    } finally {
      malloc.free(pathPointer);
      malloc.free(planPointer);
      malloc.free(conflictsPointer);
    }
  }

  /// Merges the .oep archive at [archivePath]'s Repository Fragment into
  /// the currently open repository (WP-REP-008). Throws
  /// [FoundationBridgeException] if no repository is open, the archive
  /// cannot be read/parsed, the resulting plan is not mergeable (blocked
  /// by trust, dependency resolution, or a detected conflict), or the
  /// package_id is already recorded in the Repository Registry (see
  /// [planMerge] to check beforehand).
  OepMergeResult executeMerge(String archivePath) {
    _assertNotDisposed();
    final pathPointer = archivePath.toNativeUtf8();
    final resultPointer = malloc<OepMergeResultNative>();
    try {
      _checkResult(_bindings.repositoryExecuteMerge(_runtime, pathPointer, resultPointer));
      return OepMergeResult.fromNative(resultPointer.ref);
    } finally {
      malloc.free(pathPointer);
      malloc.free(resultPointer);
    }
  }

  /// Loads (and caches) exactly one Engineering Object via the Object
  /// Loader (WP-EKE-001 — Engineering Knowledge Runtime), WITHOUT
  /// touching or requiring the Runtime Graph (see [loadEngineeringGraph]).
  /// [found] == false is a normal answer (no such object exists), not an
  /// exception — [object] is Foundation's zero-initialized
  /// [EngineeringObjectSummary] in that case. Throws
  /// [FoundationBridgeException] if no repository is open.
  ({EngineeringObjectSummary object, bool found}) loadEngineeringObject(String objectId) {
    _assertNotDisposed();
    final idPointer = objectId.toNativeUtf8();
    final objectPointer = malloc<OepObjectInfoNative>();
    final foundPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.engineLoadObject(_runtime, idPointer, objectPointer, foundPointer));
      return (object: EngineeringObjectSummary.fromNative(objectPointer.ref), found: foundPointer.value != 0);
    } finally {
      malloc.free(idPointer);
      malloc.free(objectPointer);
      malloc.free(foundPointer);
    }
  }

  /// Batch-loads every Engineering Object and Relationship in the
  /// currently open repository and (re)builds this Runtime handle's
  /// Runtime Graph from that snapshot (WP-EKE-001). Must succeed before
  /// [engineQueryById]/[engineQueryByType]/[engineQueryByDomain]/
  /// [engineQueryByRelationship]/[engineShortestPath]/
  /// [engineConnectedComponent]/[engineSubgraph]/[engineTraverse]/
  /// [engineRelatedObjects]/[engineDependencyGraph] — the graph is cached
  /// on this handle, not the repository, so it must be (re)loaded once
  /// per process/handle and again after any mutation that should be
  /// reflected. Throws [FoundationBridgeException] if no repository is
  /// open.
  ({int objectsLoaded, int relationshipsLoaded}) loadEngineeringGraph() {
    _assertNotDisposed();
    final objectsLoadedPointer = malloc<Int32>();
    final relationshipsLoadedPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.engineLoadGraph(_runtime, objectsLoadedPointer, relationshipsLoadedPointer));
      return (objectsLoaded: objectsLoadedPointer.value, relationshipsLoaded: relationshipsLoadedPointer.value);
    } finally {
      malloc.free(objectsLoadedPointer);
      malloc.free(relationshipsLoadedPointer);
    }
  }

  /// Finds the single object matching [objectId] in this handle's loaded
  /// Runtime Graph (WP-EKE-001, `OEP_ENGINE_QUERY_BY_ID`). Requires a
  /// prior [loadEngineeringGraph] call. Throws [FoundationBridgeException]
  /// if the graph has not been loaded.
  List<String> engineQueryById(String objectId) {
    return _engineQuery(kind: EngineQueryKind.byId, objectId: objectId).objectIds;
  }

  /// Finds every object of [type] in this handle's loaded Runtime Graph
  /// (WP-EKE-001, `OEP_ENGINE_QUERY_BY_TYPE`). Requires a prior
  /// [loadEngineeringGraph] call.
  List<String> engineQueryByType(ObjectCategory type) {
    return _engineQuery(kind: EngineQueryKind.byType, objectType: type).objectIds;
  }

  /// Finds every object tagged with engineering [domain] in this handle's
  /// loaded Runtime Graph (WP-EKE-001, `OEP_ENGINE_QUERY_BY_DOMAIN`).
  /// Requires a prior [loadEngineeringGraph] call.
  List<String> engineQueryByDomain(String domain) {
    return _engineQuery(kind: EngineQueryKind.byDomain, domain: domain).objectIds;
  }

  /// Finds every object touched by a Relationship of [type] in this
  /// handle's loaded Runtime Graph (WP-EKE-001,
  /// `OEP_ENGINE_QUERY_BY_RELATIONSHIP`). Requires a prior
  /// [loadEngineeringGraph] call.
  List<String> engineQueryByRelationship(RelationshipType type) {
    return _engineQuery(kind: EngineQueryKind.byRelationship, relationshipType: type).objectIds;
  }

  /// The shortest path from [sourceObjectId] to [targetObjectId] in this
  /// handle's loaded Runtime Graph (WP-EKE-001,
  /// `OEP_ENGINE_QUERY_SHORTEST_PATH`). [pathExists] == false (with
  /// [path] empty) is a normal answer, not an exception. When a path
  /// exists, [path] holds it from source to target inclusive, in path
  /// order. Requires a prior [loadEngineeringGraph] call.
  ({bool pathExists, List<String> path}) engineShortestPath(String sourceObjectId, String targetObjectId) {
    final result = _engineQuery(
      kind: EngineQueryKind.shortestPath,
      sourceObjectId: sourceObjectId,
      targetObjectId: targetObjectId,
    );
    return (pathExists: result.pathExists, path: result.objectIds);
  }

  /// Every object reachable from [objectId] in this handle's loaded
  /// Runtime Graph, following relationships in either direction
  /// (WP-EKE-001, `OEP_ENGINE_QUERY_CONNECTED_COMPONENT`). Requires a
  /// prior [loadEngineeringGraph] call.
  List<String> engineConnectedComponent(String objectId) {
    return _engineQuery(kind: EngineQueryKind.connectedComponent, objectId: objectId).objectIds;
  }

  /// The induced subgraph over [objectIds] in this handle's loaded
  /// Runtime Graph: every relationship with both endpoints in
  /// [objectIds] (WP-EKE-001, `OEP_ENGINE_QUERY_SUBGRAPH`). Requires a
  /// prior [loadEngineeringGraph] call.
  ({List<String> objectIds, List<String> relationshipIds}) engineSubgraph(List<String> objectIds) {
    final result = _engineQuery(kind: EngineQueryKind.subgraph, subgraphObjectIds: objectIds);
    return (objectIds: result.objectIds, relationshipIds: result.relationshipIds);
  }

  /// Traverses this handle's loaded Runtime Graph starting at
  /// [startObjectId] (WP-EKE-001). [depthFirst] selects depth-first order
  /// instead of the default breadth-first. [relationshipFilter], if
  /// given, restricts traversal to that one Relationship type; otherwise
  /// every type is followed. [maxDepth], if given, bounds traversal
  /// depth; otherwise it is unbounded. Requires a prior
  /// [loadEngineeringGraph] call.
  List<String> engineTraverse(
    String startObjectId, {
    bool depthFirst = false,
    RelationshipType? relationshipFilter,
    int? maxDepth,
  }) {
    _assertNotDisposed();
    final startPointer = startObjectId.toNativeUtf8();
    final outObjectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.engineTraverse(
          _runtime,
          startPointer,
          depthFirst ? EngineTraversalOrder.depthFirst.nativeValue : EngineTraversalOrder.breadthFirst.nativeValue,
          relationshipFilter != null ? 1 : 0,
          relationshipFilter?.nativeValue ?? 0,
          maxDepth != null ? 1 : 0,
          maxDepth ?? 0,
          outObjectIdsPointer,
        ),
      );
      try {
        return _decodeIdList(outObjectIdsPointer.ref);
      } finally {
        _bindings.packageIdListRelease(outObjectIdsPointer);
      }
    } finally {
      malloc.free(startPointer);
      malloc.free(outObjectIdsPointer);
    }
  }

  /// Every object directly connected to [objectId] (any relationship
  /// type, either direction) in this handle's loaded Runtime Graph,
  /// sorted and deduplicated (WP-EKE-001). Requires a prior
  /// [loadEngineeringGraph] call.
  List<String> engineRelatedObjects(String objectId) {
    _assertNotDisposed();
    final idPointer = objectId.toNativeUtf8();
    final outObjectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.engineRelatedObjects(_runtime, idPointer, outObjectIdsPointer));
      try {
        return _decodeIdList(outObjectIdsPointer.ref);
      } finally {
        _bindings.packageIdListRelease(outObjectIdsPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(outObjectIdsPointer);
    }
  }

  /// The full transitive closure of [objectId]'s outgoing DependsOn
  /// Relationships in this handle's loaded Runtime Graph: [objectId]
  /// itself, plus every object reachable by following only DependsOn
  /// edges outward, plus the DependsOn relationship ids traversed to
  /// reach them (WP-EKE-001). Throws [FoundationBridgeException] if
  /// [objectId] is not present in the loaded graph, or the graph has not
  /// been loaded.
  ({List<String> objectIds, List<String> relationshipIds}) engineDependencyGraph(String objectId) {
    _assertNotDisposed();
    final idPointer = objectId.toNativeUtf8();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    final relationshipIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.engineDependencyGraph(_runtime, idPointer, objectIdsPointer, relationshipIdsPointer));
      try {
        return (
          objectIds: _decodeIdList(objectIdsPointer.ref),
          relationshipIds: _decodeIdList(relationshipIdsPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(objectIdsPointer);
        _bindings.packageIdListRelease(relationshipIdsPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(objectIdsPointer);
      malloc.free(relationshipIdsPointer);
    }
  }

  /// Runs one Graph Query against this handle's loaded Runtime Graph, per
  /// `kind` (WP-EKE-001, `oep_engine_query`). The sole marshaling point
  /// for `oep_engine_query_request_t` — every `engineQuery*`/
  /// `engineShortestPath`/`engineConnectedComponent`/`engineSubgraph`
  /// convenience method above funnels through this. `relationshipIds` is
  /// only ever populated for [EngineQueryKind.subgraph]; `pathExists` is
  /// only ever meaningful for [EngineQueryKind.shortestPath]. Throws
  /// [FoundationBridgeException] if the graph has not been loaded (see
  /// [loadEngineeringGraph]).
  ({List<String> objectIds, List<String> relationshipIds, bool pathExists}) _engineQuery({
    required EngineQueryKind kind,
    String? objectId,
    ObjectCategory? objectType,
    String? domain,
    RelationshipType? relationshipType,
    String? sourceObjectId,
    String? targetObjectId,
    List<String>? subgraphObjectIds,
  }) {
    _assertNotDisposed();
    final requestPointer = malloc<OepEngineQueryRequestNative>();
    final objectIdPointer = objectId?.toNativeUtf8() ?? nullptr;
    final domainPointer = domain?.toNativeUtf8() ?? nullptr;
    final sourcePointer = sourceObjectId?.toNativeUtf8() ?? nullptr;
    final targetPointer = targetObjectId?.toNativeUtf8() ?? nullptr;
    final subgraphCount = subgraphObjectIds?.length ?? 0;
    final subgraphArray = subgraphObjectIds != null ? _allocateTagArray(subgraphObjectIds) : nullptr;
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    final relationshipIdsPointer = malloc<OepPackageIdListNative>();
    final pathExistsPointer = malloc<Int32>();
    try {
      final request = requestPointer.ref;
      request.kind = kind.nativeValue;
      request.objectId = objectIdPointer;
      request.objectType = objectType?.nativeValue ?? 0;
      request.domain = domainPointer;
      request.relationshipType = relationshipType?.nativeValue ?? 0;
      request.sourceObjectId = sourcePointer;
      request.targetObjectId = targetPointer;
      request.subgraphObjectIds = subgraphArray;
      request.subgraphObjectIdCount = subgraphCount;

      _checkResult(
        _bindings.engineQuery(
          _runtime,
          requestPointer,
          objectIdsPointer,
          relationshipIdsPointer,
          pathExistsPointer,
        ),
      );
      try {
        return (
          objectIds: _decodeIdList(objectIdsPointer.ref),
          relationshipIds: _decodeIdList(relationshipIdsPointer.ref),
          pathExists: pathExistsPointer.value != 0,
        );
      } finally {
        _bindings.packageIdListRelease(objectIdsPointer);
        _bindings.packageIdListRelease(relationshipIdsPointer);
      }
    } finally {
      malloc.free(requestPointer);
      if (objectIdPointer != nullptr) malloc.free(objectIdPointer);
      if (domainPointer != nullptr) malloc.free(domainPointer);
      if (sourcePointer != nullptr) malloc.free(sourcePointer);
      if (targetPointer != nullptr) malloc.free(targetPointer);
      if (subgraphObjectIds != null) _freeTagArray(subgraphArray, subgraphCount);
      malloc.free(objectIdsPointer);
      malloc.free(relationshipIdsPointer);
      malloc.free(pathExistsPointer);
    }
  }

  /// Decodes an `oep_package_id_list_t` (reused generically as an
  /// "object id list" or "relationship id list" throughout WP-EKE-001 —
  /// see `oep_api.h`'s ID-list reuse decision) into a plain [List<String>].
  /// Does not release the list — callers release via
  /// [OepApiBindings.packageIdListRelease] once done, same as
  /// [resolveDependencies]/[analyzeUninstallImpact]/etc. already do.
  List<String> _decodeIdList(OepPackageIdListNative list) {
    return [for (var i = 0; i < list.count; i++) decodeFixedCString(list.items[i].id, oepMaxPackageId)];
  }

  /// Allocates a native `const char* const*` array from [tags] — `NULL`
  /// (not an empty allocation) when [tags] is empty, matching
  /// `oep_object_create`'s own "`tags` may be NULL iff `tag_count` is 0"
  /// contract. Each element must be released individually (see
  /// [_freeTagArray]) since each is its own heap allocation, distinct
  /// from every other `toNativeUtf8()` call in this file, which only
  /// ever marshals a single string at a time.
  Pointer<Pointer<Utf8>> _allocateTagArray(List<String> tags) {
    if (tags.isEmpty) return nullptr;
    final array = malloc<Pointer<Utf8>>(tags.length);
    for (var i = 0; i < tags.length; i++) {
      array[i] = tags[i].toNativeUtf8();
    }
    return array;
  }

  /// Releases every individual tag string [_allocateTagArray] allocated,
  /// then the array itself. Safe to call with `array == nullptr` (the
  /// empty-tags case) — a no-op, mirroring every release function
  /// `oep_api.h` itself defines.
  void _freeTagArray(Pointer<Pointer<Utf8>> array, int length) {
    if (array == nullptr) return;
    for (var i = 0; i < length; i++) {
      malloc.free(array[i]);
    }
    malloc.free(array);
  }

  // --- Engineering Knowledge Graph Engine (WP-EKE-002) ---

  /// Builds this handle's Knowledge Graph from EngineeringContext from
  /// scratch (WP-EKE-002, `oep_kge_build_graph`). Every other `kge*`/
  /// `knowledgeGraph*` method below requires a prior call to this (or
  /// [refreshKnowledgeGraph]). Only valid once a repository is open.
  ({int objects, int relationships}) buildKnowledgeGraph() {
    return _kgeBuildOrRefresh(_bindings.kgeBuildGraph);
  }

  /// Identical to [buildKnowledgeGraph] — both fully re-pull from
  /// EngineeringContext and rebuild the graph from scratch (WP-EKE-002,
  /// `oep_kge_refresh_graph`).
  ({int objects, int relationships}) refreshKnowledgeGraph() {
    return _kgeBuildOrRefresh(_bindings.kgeRefreshGraph);
  }

  ({int objects, int relationships}) _kgeBuildOrRefresh(
    OepResultNative Function(Pointer<Void> runtime, Pointer<Int32> outObjects, Pointer<Int32> outRelationships) fn,
  ) {
    _assertNotDisposed();
    final objectsPointer = malloc<Int32>();
    final relationshipsPointer = malloc<Int32>();
    try {
      _checkResult(fn(_runtime, objectsPointer, relationshipsPointer));
      return (objects: objectsPointer.value, relationships: relationshipsPointer.value);
    } finally {
      malloc.free(objectsPointer);
      malloc.free(relationshipsPointer);
    }
  }

  /// Validates this handle's currently built Knowledge Graph (WP-EKE-002,
  /// `oep_kge_validate_graph`). A graph with issues is a normal answer
  /// (`valid == false` with populated `issues`), not an exception. Requires
  /// a prior [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  ({bool valid, List<OepGraphIssue> issues}) validateKnowledgeGraph() {
    _assertNotDisposed();
    final validPointer = malloc<Int32>();
    final issuesPointer = malloc<OepGraphIssueListNative>();
    try {
      _checkResult(_bindings.kgeValidateGraph(_runtime, validPointer, issuesPointer));
      try {
        final issues = [
          for (var i = 0; i < issuesPointer.ref.count; i++) OepGraphIssue.fromNative(issuesPointer.ref.items[i]),
        ];
        return (valid: validPointer.value != 0, issues: issues);
      } finally {
        _bindings.graphIssueListRelease(issuesPointer);
      }
    } finally {
      malloc.free(validPointer);
      malloc.free(issuesPointer);
    }
  }

  /// The six scalar statistics of this handle's currently built Knowledge
  /// Graph (WP-EKE-002, `oep_kge_graph_statistics`). Requires a prior
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  OepGraphStatistics knowledgeGraphStatistics() {
    _assertNotDisposed();
    final statsPointer = malloc<OepGraphStatisticsNative>();
    try {
      _checkResult(_bindings.kgeGraphStatistics(_runtime, statsPointer));
      return OepGraphStatistics.fromNative(statsPointer.ref);
    } finally {
      malloc.free(statsPointer);
    }
  }

  /// Every connected component of this handle's currently built Knowledge
  /// Graph, grouped into one inner [List<String>] per component, in
  /// component-index order (WP-EKE-002, `oep_kge_connected_components`).
  /// The native API returns a flat `{object_id, component_index}` list
  /// (see `oep_api.h`'s "Scope decision -- connected components
  /// flattening" note); this method performs the grouping in Dart.
  /// Requires a prior [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  List<List<String>> connectedComponents() {
    _assertNotDisposed();
    final componentsPointer = malloc<OepComponentMembershipListNative>();
    final countPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.kgeConnectedComponents(_runtime, componentsPointer, countPointer));
      try {
        final memberships = [
          for (var i = 0; i < componentsPointer.ref.count; i++)
            OepComponentMembership.fromNative(componentsPointer.ref.items[i]),
        ];
        final grouped = <int, List<String>>{};
        for (final membership in memberships) {
          grouped.putIfAbsent(membership.componentIndex, () => []).add(membership.objectId);
        }
        final indices = grouped.keys.toList()..sort();
        return [for (final index in indices) grouped[index]!];
      } finally {
        _bindings.componentMembershipListRelease(componentsPointer);
      }
    } finally {
      malloc.free(componentsPointer);
      malloc.free(countPointer);
    }
  }

  /// The shortest path (by hop count) between [sourceId] and [targetId] in
  /// this handle's currently built Knowledge Graph (WP-EKE-002,
  /// `oep_kge_shortest_path`). `pathExists == false` (with `path` empty)
  /// is a normal answer, not an exception. Requires a prior
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  ({bool pathExists, List<String> path}) knowledgeGraphShortestPath(String sourceId, String targetId) {
    _assertNotDisposed();
    final sourcePointer = sourceId.toNativeUtf8();
    final targetPointer = targetId.toNativeUtf8();
    final pathExistsPointer = malloc<Int32>();
    final pathPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.kgeShortestPath(_runtime, sourcePointer, targetPointer, pathExistsPointer, pathPointer));
      try {
        return (pathExists: pathExistsPointer.value != 0, path: _decodeIdList(pathPointer.ref));
      } finally {
        _bindings.packageIdListRelease(pathPointer);
      }
    } finally {
      malloc.free(sourcePointer);
      malloc.free(targetPointer);
      malloc.free(pathExistsPointer);
      malloc.free(pathPointer);
    }
  }

  /// The induced subgraph over [objectIds] in this handle's currently
  /// built Knowledge Graph: every relationship with both endpoints in
  /// [objectIds] (WP-EKE-002, `oep_kge_subgraph`). Requires a prior
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  ({List<String> objectIds, List<String> relationshipIds}) knowledgeGraphSubgraph(List<String> objectIds) {
    _assertNotDisposed();
    final objectIdCount = objectIds.length;
    final objectIdArray = _allocateTagArray(objectIds);
    final outObjectIdsPointer = malloc<OepPackageIdListNative>();
    final outRelationshipIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.kgeSubgraph(
          _runtime,
          objectIdArray,
          objectIdCount,
          outObjectIdsPointer,
          outRelationshipIdsPointer,
        ),
      );
      try {
        return (
          objectIds: _decodeIdList(outObjectIdsPointer.ref),
          relationshipIds: _decodeIdList(outRelationshipIdsPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(outObjectIdsPointer);
        _bindings.packageIdListRelease(outRelationshipIdsPointer);
      }
    } finally {
      _freeTagArray(objectIdArray, objectIdCount);
      malloc.free(outObjectIdsPointer);
      malloc.free(outRelationshipIdsPointer);
    }
  }

  /// A complete, valid JSON document exported from this handle's currently
  /// built Knowledge Graph (WP-EKE-002, `oep_kge_export_json`). Requires a
  /// prior [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  String exportKnowledgeGraphJson() {
    return _kgeExportText(_bindings.kgeExportJson);
  }

  /// A minimal, well-formed GraphML PLACEHOLDER document exported from
  /// this handle's currently built Knowledge Graph (WP-EKE-002,
  /// `oep_kge_export_graphml_placeholder`). Requires a prior
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  String exportKnowledgeGraphGraphml() {
    return _kgeExportText(_bindings.kgeExportGraphmlPlaceholder);
  }

  /// Shared marshaling for [exportKnowledgeGraphJson]/
  /// [exportKnowledgeGraphGraphml]: both return a caller-owned,
  /// heap-allocated NUL-terminated buffer (WP-EKE-002's "Owned-heap-string
  /// export" convention — this codebase's first owned-dynamically-sized-
  /// string return, distinct from the fixed-layout-struct pattern used
  /// everywhere else), released via exactly one [OepApiBindings.stringRelease]
  /// call.
  String _kgeExportText(
    OepResultNative Function(Pointer<Void> runtime, Pointer<Pointer<Utf8>> outText, Pointer<Size> outLength) fn,
  ) {
    _assertNotDisposed();
    final textPointer = malloc<Pointer<Utf8>>();
    final lengthPointer = malloc<Size>();
    textPointer.value = nullptr;
    try {
      _checkResult(fn(_runtime, textPointer, lengthPointer));
      try {
        return textPointer.value.toDartString(length: lengthPointer.value);
      } finally {
        _bindings.stringRelease(textPointer);
      }
    } finally {
      malloc.free(textPointer);
      malloc.free(lengthPointer);
    }
  }

  // --- Engineering Query Engine (WP-EKE-003) ---

  /// Plans (never executes) a query against this handle's currently built
  /// Knowledge Graph (WP-EKE-003, `oep_eqe_plan_query`). Requires a prior
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call — surfaces as a
  /// normal [FoundationBridgeException] if the graph hasn't been built,
  /// same as every other WP-EKE-002/003 method.
  ({OepQueryPlan plan, List<String> indexesUsed, List<String> executionOrder}) planQuery({
    required QueryCategory category,
    String primaryObjectId = '',
    String secondaryObjectId = '',
    QueryFilter filter = const QueryFilter(),
  }) {
    final (planPointer, indexesUsedPointer, executionOrderPointer) = _eqeQuery(
      category: category,
      primaryObjectId: primaryObjectId,
      secondaryObjectId: secondaryObjectId,
      filter: filter,
      run: (requestPointer, planPointer, indexesUsedPointer, executionOrderPointer) {
        _checkResult(_bindings.eqePlanQuery(_runtime, requestPointer, planPointer, indexesUsedPointer, executionOrderPointer));
      },
    );
    try {
      return (
        plan: OepQueryPlan.fromNative(planPointer.ref),
        indexesUsed: _decodeIdList(indexesUsedPointer.ref),
        executionOrder: _decodeIdList(executionOrderPointer.ref),
      );
    } finally {
      _bindings.packageIdListRelease(indexesUsedPointer);
      _bindings.packageIdListRelease(executionOrderPointer);
      malloc.free(planPointer);
      malloc.free(indexesUsedPointer);
      malloc.free(executionOrderPointer);
    }
  }

  /// Plans (or reuses a cached plan for) and executes a query against this
  /// handle's currently built Knowledge Graph in one call (WP-EKE-003,
  /// `oep_eqe_execute_query`). Also updates the state [queryStatistics]
  /// reports. Requires a prior [buildKnowledgeGraph]/[refreshKnowledgeGraph]
  /// call.
  ({OepQueryResultSummary summary, List<String> objectIds, List<String> relationshipIds}) executeQuery({
    required QueryCategory category,
    String primaryObjectId = '',
    String secondaryObjectId = '',
    QueryFilter filter = const QueryFilter(),
  }) {
    _assertNotDisposed();
    final requestPointer = malloc<OepQueryRequestNative>();
    final tagArray = _allocateTagArray(filter.tags);
    final summaryPointer = malloc<OepQueryResultSummaryNative>();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    final relationshipIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _fillQueryRequest(requestPointer.ref, category, primaryObjectId, secondaryObjectId, filter, tagArray);
      _checkResult(
        _bindings.eqeExecuteQuery(_runtime, requestPointer, summaryPointer, objectIdsPointer, relationshipIdsPointer),
      );
      try {
        return (
          summary: OepQueryResultSummary.fromNative(summaryPointer.ref),
          objectIds: _decodeIdList(objectIdsPointer.ref),
          relationshipIds: _decodeIdList(relationshipIdsPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(objectIdsPointer);
        _bindings.packageIdListRelease(relationshipIdsPointer);
      }
    } finally {
      malloc.free(requestPointer);
      _freeTagArray(tagArray, filter.tags.length);
      malloc.free(summaryPointer);
      malloc.free(objectIdsPointer);
      malloc.free(relationshipIdsPointer);
    }
  }

  /// The most recently executed query's statistics on this handle
  /// (WP-EKE-003, `oep_eqe_query_statistics`). Zero-valued if no query has
  /// been executed yet via [executeQuery] on this handle.
  OepQueryResultSummary queryStatistics() {
    _assertNotDisposed();
    final statsPointer = malloc<OepQueryResultSummaryNative>();
    try {
      _checkResult(_bindings.eqeQueryStatistics(_runtime, statsPointer));
      return OepQueryResultSummary.fromNative(statsPointer.ref);
    } finally {
      malloc.free(statsPointer);
    }
  }

  /// Discards every cached plan and result on this handle's Engineering
  /// Query Engine (WP-EKE-003, `oep_eqe_clear_query_cache`). Callers MUST
  /// call this after [buildKnowledgeGraph]/[refreshKnowledgeGraph] if
  /// subsequent queries should reflect the rebuilt graph — the Engineering
  /// Query Engine has no way to detect the rebuild on its own.
  void clearQueryCache() {
    _assertNotDisposed();
    _checkResult(_bindings.eqeClearQueryCache(_runtime));
  }

  /// The Engineering Query Engine's current cache occupancy (WP-EKE-003,
  /// `oep_eqe_query_cache_info`) — a diagnostic, not part of WP-EKE-003's
  /// literal five-method Runtime API list.
  ({int planCount, int resultCount}) queryCacheInfo() {
    _assertNotDisposed();
    final planCountPointer = malloc<Int32>();
    final resultCountPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.eqeQueryCacheInfo(_runtime, planCountPointer, resultCountPointer));
      return (planCount: planCountPointer.value, resultCount: resultCountPointer.value);
    } finally {
      malloc.free(planCountPointer);
      malloc.free(resultCountPointer);
    }
  }

  /// Shared marshaling for [planQuery]: builds the native
  /// `oep_query_request_t`, invokes [run], and returns the three raw output
  /// pointers for the caller to decode/release. Kept separate from
  /// [executeQuery]'s own inline marshaling since `planQuery` has a
  /// different output shape (`oep_query_plan_t` instead of
  /// `oep_query_result_summary_t`).
  (Pointer<OepQueryPlanNative>, Pointer<OepPackageIdListNative>, Pointer<OepPackageIdListNative>) _eqeQuery({
    required QueryCategory category,
    required String primaryObjectId,
    required String secondaryObjectId,
    required QueryFilter filter,
    required void Function(
      Pointer<OepQueryRequestNative> requestPointer,
      Pointer<OepQueryPlanNative> planPointer,
      Pointer<OepPackageIdListNative> indexesUsedPointer,
      Pointer<OepPackageIdListNative> executionOrderPointer,
    )
    run,
  }) {
    _assertNotDisposed();
    final requestPointer = malloc<OepQueryRequestNative>();
    final tagArray = _allocateTagArray(filter.tags);
    final planPointer = malloc<OepQueryPlanNative>();
    final indexesUsedPointer = malloc<OepPackageIdListNative>();
    final executionOrderPointer = malloc<OepPackageIdListNative>();
    try {
      _fillQueryRequest(requestPointer.ref, category, primaryObjectId, secondaryObjectId, filter, tagArray);
      run(requestPointer, planPointer, indexesUsedPointer, executionOrderPointer);
      return (planPointer, indexesUsedPointer, executionOrderPointer);
    } finally {
      malloc.free(requestPointer);
      _freeTagArray(tagArray, filter.tags.length);
    }
  }

  /// Populates `request` (and its nested `filter`) in place from Studio's
  /// [QueryCategory]/[QueryFilter] inputs, following the "has_X" flag
  /// convention `oep_query_filter_t` mirrors from
  /// `OepEngineQueryRequestNative` (WP-EKE-001). `tagArray` must already be
  /// allocated via [_allocateTagArray] and stays owned by the caller.
  void _fillQueryRequest(
    OepQueryRequestNative request,
    QueryCategory category,
    String primaryObjectId,
    String secondaryObjectId,
    QueryFilter filter,
    Pointer<Pointer<Utf8>> tagArray,
  ) {
    request.category = category.nativeValue;
    _writeFixedCString(request.primaryObjectId, primaryObjectId, oepMaxObjectId);
    _writeFixedCString(request.secondaryObjectId, secondaryObjectId, oepMaxObjectId);

    final nativeFilter = request.filter;
    nativeFilter.hasObjectType = filter.objectType != null ? 1 : 0;
    nativeFilter.objectType = filter.objectType?.nativeValue ?? 0;
    nativeFilter.hasDomain = filter.domain != null ? 1 : 0;
    _writeFixedCString(nativeFilter.domain, filter.domain ?? '', oepMaxObjectName);
    nativeFilter.hasRelationshipType = filter.relationshipType != null ? 1 : 0;
    nativeFilter.relationshipType = filter.relationshipType?.nativeValue ?? 0;
    nativeFilter.hasPublisherId = filter.publisherId != null ? 1 : 0;
    _writeFixedCString(nativeFilter.publisherId, filter.publisherId ?? '', oepMaxPackageId);
    nativeFilter.hasPackageId = filter.packageId != null ? 1 : 0;
    _writeFixedCString(nativeFilter.packageId, filter.packageId ?? '', oepMaxPackageId);
    nativeFilter.tags = tagArray;
    nativeFilter.tagCount = filter.tags.length;
    nativeFilter.hasMaxDepth = filter.maxDepth != null ? 1 : 0;
    nativeFilter.maxDepth = filter.maxDepth ?? 0;
    nativeFilter.hasOutgoingOnly = filter.outgoingOnly != null ? 1 : 0;
    nativeFilter.outgoingOnly = (filter.outgoingOnly ?? false) ? 1 : 0;
  }

  /// Writes [value] into a fixed-length `char[]` struct field, truncating
  /// (on UTF-8 byte length) to `maxLength - 1` and NUL-terminating —
  /// the write-side counterpart to [decodeFixedCString].
  void _writeFixedCString(Array<Uint8> array, String value, int maxLength) {
    final bytes = utf8.encode(value);
    final writable = bytes.length > maxLength - 1 ? maxLength - 1 : bytes.length;
    for (var i = 0; i < writable; i++) {
      array[i] = bytes[i];
    }
    array[writable] = 0;
  }

  // --- Engineering Rules Engine (WP-EKE-004) ---

  /// Registers [rule] on this handle's Rules Engine (WP-EKE-004,
  /// `oep_rules_register`), enabled by default. In-memory, per-handle
  /// state — not persisted; does not survive closing/reopening a
  /// repository or process exit. Throws [FoundationBridgeException] if
  /// `rule.ruleId` is already registered on this handle (matching the
  /// "already installed" style errors [installPackage] surfaces —
  /// remove the existing rule first via [removeRule]).
  void registerRule(EngineeringRule rule) {
    _assertNotDisposed();
    final rulePointer = malloc<OepEngineeringRuleNative>();
    final conditionsArray = rule.conditions.isEmpty
        ? nullptr
        : malloc<OepRuleConditionNative>(rule.conditions.length);
    try {
      for (var i = 0; i < rule.conditions.length; i++) {
        _fillRuleCondition(conditionsArray[i], rule.conditions[i]);
      }
      _fillEngineeringRule(rulePointer.ref, rule, conditionsArray);
      _checkResult(_bindings.rulesRegister(_runtime, rulePointer));
    } finally {
      if (conditionsArray != nullptr) malloc.free(conditionsArray);
      malloc.free(rulePointer);
    }
  }

  /// Removes the rule identified by [ruleId] from this handle's Rules
  /// Engine (WP-EKE-004, `oep_rules_remove`). Throws
  /// [FoundationBridgeException] (`OEP_ERROR_NOT_FOUND`) if [ruleId] is
  /// not registered.
  void removeRule(String ruleId) {
    _assertNotDisposed();
    final idPointer = ruleId.toNativeUtf8();
    try {
      _checkResult(_bindings.rulesRemove(_runtime, idPointer));
    } finally {
      malloc.free(idPointer);
    }
  }

  /// Enables the rule identified by [ruleId] (WP-EKE-004,
  /// `oep_rules_enable`). Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) if [ruleId] is not registered.
  void enableRule(String ruleId) => _ruleSetEnabled(ruleId, enable: true);

  /// Disables the rule identified by [ruleId] (WP-EKE-004,
  /// `oep_rules_disable`). Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) if [ruleId] is not registered.
  void disableRule(String ruleId) => _ruleSetEnabled(ruleId, enable: false);

  void _ruleSetEnabled(String ruleId, {required bool enable}) {
    _assertNotDisposed();
    final idPointer = ruleId.toNativeUtf8();
    try {
      _checkResult(enable ? _bindings.rulesEnable(_runtime, idPointer) : _bindings.rulesDisable(_runtime, idPointer));
    } finally {
      malloc.free(idPointer);
    }
  }

  /// Every registered rule id on this handle's Rules Engine, sorted by
  /// rule_id (WP-EKE-004, `oep_rules_list_all`).
  List<String> listAllRules() => _ruleIdList(_bindings.rulesListAll);

  /// Every ENABLED rule id on this handle's Rules Engine, sorted by
  /// rule_id (WP-EKE-004, `oep_rules_list_enabled`).
  List<String> listEnabledRules() => _ruleIdList(_bindings.rulesListEnabled);

  /// Every DISABLED rule id on this handle's Rules Engine, sorted by
  /// rule_id (WP-EKE-004, `oep_rules_list_disabled`).
  List<String> listDisabledRules() => _ruleIdList(_bindings.rulesListDisabled);

  List<String> _ruleIdList(
    OepResultNative Function(Pointer<Void> runtime, Pointer<OepPackageIdListNative> outRuleIds) fn,
  ) {
    _assertNotDisposed();
    final listPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(fn(_runtime, listPointer));
      try {
        return _decodeIdList(listPointer.ref);
      } finally {
        _bindings.packageIdListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Fetches the full definition of the rule identified by [ruleId]
  /// (WP-EKE-004, `oep_rules_get`). Not finding [ruleId] is not an error
  /// — `found` comes back `false` with an empty [EngineeringRule].
  /// `conditions` is decoded from the separate `oep_rule_condition_list_t`
  /// output, per `oep_api.h`'s documented input/output asymmetry for
  /// `oep_engineering_rule_t.conditions`.
  ({EngineeringRule rule, List<RuleCondition> conditions, bool found}) getRule(String ruleId) {
    _assertNotDisposed();
    final idPointer = ruleId.toNativeUtf8();
    final rulePointer = malloc<OepEngineeringRuleNative>();
    final conditionsPointer = malloc<OepRuleConditionListNative>();
    final foundPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.rulesGet(_runtime, idPointer, rulePointer, conditionsPointer, foundPointer));
      final found = foundPointer.value != 0;
      if (!found) {
        return (rule: const EngineeringRule(ruleId: '', name: '', category: RuleCategory.structural, severity: RuleSeverity.info), conditions: const [], found: false);
      }
      final conditionsList = conditionsPointer.ref;
      try {
        final conditions = [
          for (var i = 0; i < conditionsList.count; i++) _decodeRuleCondition(conditionsList.items[i]),
        ];
        return (rule: EngineeringRule.fromNative(rulePointer.ref), conditions: conditions, found: true);
      } finally {
        _bindings.ruleConditionListRelease(conditionsPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(rulePointer);
      malloc.free(conditionsPointer);
      malloc.free(foundPointer);
    }
  }

  /// Evaluates one registered rule by id, regardless of its
  /// enabled/disabled state (WP-EKE-004, `oep_rules_evaluate`). Requires
  /// a prior [loadKnowledgeGraph]/`oep_engine_load_graph` AND
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call — surfaces as a
  /// normal [FoundationBridgeException] (`OEP_ERROR_INVALID_STATE`)
  /// otherwise. Throws [FoundationBridgeException] (`OEP_ERROR_NOT_FOUND`)
  /// if [ruleId] is not registered.
  ({OepRuleEvaluationResult result, List<String> affectedObjects, List<OepRuleDiagnostic> diagnostics}) evaluateRule(
    String ruleId,
  ) {
    _assertNotDisposed();
    final idPointer = ruleId.toNativeUtf8();
    final resultPointer = malloc<OepRuleEvaluationResultNative>();
    final affectedPointer = malloc<OepPackageIdListNative>();
    final diagnosticsPointer = malloc<OepRuleDiagnosticListNative>();
    try {
      _checkResult(_bindings.rulesEvaluate(_runtime, idPointer, resultPointer, affectedPointer, diagnosticsPointer));
      try {
        final diagnosticsList = diagnosticsPointer.ref;
        return (
          result: OepRuleEvaluationResult.fromNative(resultPointer.ref),
          affectedObjects: _decodeIdList(affectedPointer.ref),
          diagnostics: [
            for (var i = 0; i < diagnosticsList.count; i++) OepRuleDiagnostic.fromNative(diagnosticsList.items[i]),
          ],
        );
      } finally {
        _bindings.packageIdListRelease(affectedPointer);
        _bindings.ruleDiagnosticListRelease(diagnosticsPointer);
      }
    } finally {
      malloc.free(idPointer);
      malloc.free(resultPointer);
      malloc.free(affectedPointer);
      malloc.free(diagnosticsPointer);
    }
  }

  /// Evaluates every ENABLED rule on this handle's Rules Engine, sorted
  /// by rule_id (WP-EKE-004, `oep_rules_evaluate_all`). Returns one
  /// SUMMARY per rule (counts only) rather than full per-rule detail —
  /// see `oep_api.h`'s "evaluate_all detail level" note; call
  /// [evaluateRule] for a specific rule's full affected-objects/
  /// diagnostics detail. Requires the same graph-readiness precondition
  /// as [evaluateRule].
  List<OepRuleEvaluationSummary> evaluateAllRules() {
    _assertNotDisposed();
    final listPointer = malloc<OepRuleEvaluationSummaryListNative>();
    try {
      _checkResult(_bindings.rulesEvaluateAll(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) OepRuleEvaluationSummary.fromNative(list.items[i])];
      } finally {
        _bindings.ruleEvaluationSummaryListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Populates `native` in place from Studio's [EngineeringRule] input,
  /// following the "has_X" flag convention `oep_rule_scope_t`/
  /// `oep_rule_condition_t` mirror from `oep_query_filter_t`
  /// (WP-EKE-003). `conditionsArray` must already be allocated and
  /// populated (see [_fillRuleCondition]) and stays owned by the caller
  /// — only valid as INPUT (`oep_rules_register`), per `oep_api.h`'s
  /// documented input/output asymmetry for `conditions`/`condition_count`.
  void _fillEngineeringRule(
    OepEngineeringRuleNative native,
    EngineeringRule rule,
    Pointer<OepRuleConditionNative> conditionsArray,
  ) {
    _writeFixedCString(native.ruleId, rule.ruleId, oepMaxRuleId);
    _writeFixedCString(native.name, rule.name, oepMaxRuleName);
    _writeFixedCString(native.description, rule.description, oepMaxRuleDescription);
    native.category = rule.category.nativeValue;
    native.severity = rule.severity.nativeValue;

    final scope = rule.scope;
    final nativeScope = native.scope;
    nativeScope.kind = scope.kind.nativeValue;
    nativeScope.hasObjectType = scope.objectType != null ? 1 : 0;
    nativeScope.objectType = scope.objectType?.nativeValue ?? 0;
    nativeScope.hasDomain = scope.domain != null ? 1 : 0;
    _writeFixedCString(nativeScope.domain, scope.domain ?? '', oepMaxObjectName);
    nativeScope.hasPackageId = scope.packageId != null ? 1 : 0;
    _writeFixedCString(nativeScope.packageId, scope.packageId ?? '', oepMaxPackageId);
    nativeScope.hasObjectId = scope.objectId != null ? 1 : 0;
    _writeFixedCString(nativeScope.objectId, scope.objectId ?? '', oepMaxObjectId);

    native.conditions = conditionsArray;
    native.conditionCount = rule.conditions.length;
    _writeFixedCString(native.message, rule.message, oepMaxRuleMessage);
    _writeFixedCString(native.recommendation, rule.recommendation, oepMaxRuleRecommendation);
  }

  /// Populates one element of a native `oep_rule_condition_t` array from
  /// Studio's [RuleCondition] input — this codebase's first array-of-
  /// STRUCTS marshaling (as opposed to [_allocateTagArray]'s array-of-
  /// strings), used only for [registerRule]'s `conditions` field.
  void _fillRuleCondition(OepRuleConditionNative native, RuleCondition condition) {
    native.kind = condition.kind.nativeValue;
    native.hasRelationshipType = condition.relationshipType != null ? 1 : 0;
    native.relationshipType = condition.relationshipType?.nativeValue ?? 0;
    native.hasDirection = condition.direction != null ? 1 : 0;
    native.direction = (condition.direction ?? false) ? 1 : 0;
    native.hasTag = condition.tag != null ? 1 : 0;
    _writeFixedCString(native.tag, condition.tag ?? '', oepMaxTagLength);
    native.hasCount = condition.count != null ? 1 : 0;
    native.count = condition.count ?? 0;
  }

  /// Decodes one element of an `oep_rule_condition_list_t` (an OUTPUT
  /// list, e.g. from [getRule]) into a Dart [RuleCondition].
  RuleCondition _decodeRuleCondition(OepRuleConditionNative native) {
    return RuleCondition(
      kind: RuleConditionKind.fromNative(native.kind),
      relationshipType: native.hasRelationshipType != 0 ? RelationshipType.fromNative(native.relationshipType) : null,
      direction: native.hasDirection != 0 ? native.direction != 0 : null,
      tag: native.hasTag != 0 ? decodeFixedCString(native.tag, oepMaxTagLength) : null,
      count: native.hasCount != 0 ? native.count : null,
    );
  }

  // --- Engineering Validation Engine (WP-EKE-005) ---

  /// Creates a new ValidationSession for [profile] on this handle's
  /// Validation Engine and returns its session_id (WP-EKE-005,
  /// `oep_validation_create_session`). Does NOT require a prior
  /// [loadKnowledgeGraph]/[buildKnowledgeGraph] call — see `oep_api.h`'s
  /// "Graph-readiness precondition" note; only the `validate*` calls
  /// below require a built graph. In-memory, per-handle state — not
  /// persisted; does not survive closing/reopening a repository or
  /// process exit.
  String createValidationSession(ValidationProfile profile) {
    _assertNotDisposed();
    final sessionIdPointer = malloc<Uint8>(oepMaxSessionId).cast<Utf8>();
    try {
      _checkResult(
        _bindings.validationCreateSession(_runtime, profile.nativeValue, sessionIdPointer, oepMaxSessionId),
      );
      return sessionIdPointer.toDartString();
    } finally {
      malloc.free(sessionIdPointer);
    }
  }

  /// Validates a single object under [sessionId] (WP-EKE-005,
  /// `oep_validation_validate_object`). Requires a prior
  /// [loadKnowledgeGraph]/`oep_engine_load_graph` AND
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call — surfaces as a
  /// normal [FoundationBridgeException] (`OEP_ERROR_INVALID_STATE`)
  /// otherwise. Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) if [sessionId] was not created via
  /// [createValidationSession] on this handle.
  ({OepValidationReportSummary summary, List<OepValidationFinding> findings}) validateObject(
    String sessionId,
    String objectId,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final objectIdPointer = objectId.toNativeUtf8();
    final summaryPointer = malloc<OepValidationReportSummaryNative>();
    final findingsPointer = malloc<OepValidationFindingListNative>();
    try {
      _checkResult(
        _bindings.validationValidateObject(
          _runtime,
          sessionIdPointer,
          objectIdPointer,
          summaryPointer,
          findingsPointer,
        ),
      );
      return _decodeValidationReport(summaryPointer, findingsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(objectIdPointer);
      malloc.free(summaryPointer);
      malloc.free(findingsPointer);
    }
  }

  /// Validates [objectIds] together under [sessionId] (WP-EKE-005,
  /// `oep_validation_validate_objects`). Same graph-readiness/not-found
  /// error contract as [validateObject].
  ({OepValidationReportSummary summary, List<OepValidationFinding> findings}) validateObjects(
    String sessionId,
    List<String> objectIds,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final objectIdCount = objectIds.length;
    final objectIdArray = _allocateTagArray(objectIds);
    final summaryPointer = malloc<OepValidationReportSummaryNative>();
    final findingsPointer = malloc<OepValidationFindingListNative>();
    try {
      _checkResult(
        _bindings.validationValidateObjects(
          _runtime,
          sessionIdPointer,
          objectIdArray,
          objectIdCount,
          summaryPointer,
          findingsPointer,
        ),
      );
      return _decodeValidationReport(summaryPointer, findingsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      _freeTagArray(objectIdArray, objectIdCount);
      malloc.free(summaryPointer);
      malloc.free(findingsPointer);
    }
  }

  /// Validates the whole (unfiltered) Engineering Context under
  /// [sessionId] (WP-EKE-005, `oep_validation_validate_context`). Same
  /// graph-readiness/not-found error contract as [validateObject].
  ({OepValidationReportSummary summary, List<OepValidationFinding> findings}) validateContext(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final summaryPointer = malloc<OepValidationReportSummaryNative>();
    final findingsPointer = malloc<OepValidationFindingListNative>();
    try {
      _checkResult(_bindings.validationValidateContext(_runtime, sessionIdPointer, summaryPointer, findingsPointer));
      return _decodeValidationReport(summaryPointer, findingsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(summaryPointer);
      malloc.free(findingsPointer);
    }
  }

  /// Validates [packageId] under [sessionId] (WP-EKE-005,
  /// `oep_validation_validate_package`). Same graph-readiness/not-found
  /// error contract as [validateObject].
  ({OepValidationReportSummary summary, List<OepValidationFinding> findings}) validatePackage(
    String sessionId,
    String packageId,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final packageIdPointer = packageId.toNativeUtf8();
    final summaryPointer = malloc<OepValidationReportSummaryNative>();
    final findingsPointer = malloc<OepValidationFindingListNative>();
    try {
      _checkResult(
        _bindings.validationValidatePackage(
          _runtime,
          sessionIdPointer,
          packageIdPointer,
          summaryPointer,
          findingsPointer,
        ),
      );
      return _decodeValidationReport(summaryPointer, findingsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(packageIdPointer);
      malloc.free(summaryPointer);
      malloc.free(findingsPointer);
    }
  }

  /// The most recent ValidationReport for [sessionId] (WP-EKE-005,
  /// `oep_validation_report`). Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) if [sessionId] was not created via
  /// [createValidationSession] on this handle, or
  /// (`OEP_ERROR_INVALID_STATE`) if the session exists but has never been
  /// validated.
  ({OepValidationReportSummary summary, List<OepValidationFinding> findings}) validationReport(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final summaryPointer = malloc<OepValidationReportSummaryNative>();
    final findingsPointer = malloc<OepValidationFindingListNative>();
    try {
      _checkResult(_bindings.validationReport(_runtime, sessionIdPointer, summaryPointer, findingsPointer));
      return _decodeValidationReport(summaryPointer, findingsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(summaryPointer);
      malloc.free(findingsPointer);
    }
  }

  /// The most recent ValidationStatistics for [sessionId] (WP-EKE-005,
  /// `oep_validation_statistics`). Same not-found/not-yet-validated error
  /// contract as [validationReport].
  OepValidationStatistics validationStatistics(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final statsPointer = malloc<OepValidationStatisticsNative>();
    try {
      _checkResult(_bindings.validationStatistics(_runtime, sessionIdPointer, statsPointer));
      return OepValidationStatistics.fromNative(statsPointer.ref);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(statsPointer);
    }
  }

  /// Shared decode+release for every `validate*`/`validationReport`
  /// method above: builds the plain Dart result from `summaryPointer`/
  /// `findingsPointer`, then releases the findings list via
  /// [OepApiBindings.validationFindingListRelease] — the caller owns
  /// `out_findings->items` on success per `oep_api.h`'s documented
  /// ownership contract for every Validation Scope function.
  ({OepValidationReportSummary summary, List<OepValidationFinding> findings}) _decodeValidationReport(
    Pointer<OepValidationReportSummaryNative> summaryPointer,
    Pointer<OepValidationFindingListNative> findingsPointer,
  ) {
    final findingsList = findingsPointer.ref;
    try {
      return (
        summary: OepValidationReportSummary.fromNative(summaryPointer.ref),
        findings: [
          for (var i = 0; i < findingsList.count; i++) OepValidationFinding.fromNative(findingsList.items[i]),
        ],
      );
    } finally {
      _bindings.validationFindingListRelease(findingsPointer);
    }
  }

  // --- Engineering Analysis & Reasoning Engine (WP-EKE-006) ---

  /// The transitive outgoing DependsOn closure of [objectId] (WP-EKE-006,
  /// `oep_analysis_dependencies`). Requires a prior
  /// [loadKnowledgeGraph]/`oep_engine_load_graph` AND
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call.
  ({int maxDepth, List<String> dependencyObjectIds, List<String> dependencyRelationshipIds}) analyzeDependencies(
    String objectId,
  ) {
    _assertNotDisposed();
    final objectIdPointer = objectId.toNativeUtf8();
    final maxDepthPointer = malloc<Int32>();
    final dependencyObjectIdsPointer = malloc<OepPackageIdListNative>();
    final dependencyRelationshipIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.analysisDependencies(
          _runtime,
          objectIdPointer,
          maxDepthPointer,
          dependencyObjectIdsPointer,
          dependencyRelationshipIdsPointer,
          nullptr,
        ),
      );
      try {
        return (
          maxDepth: maxDepthPointer.value,
          dependencyObjectIds: _decodeIdList(dependencyObjectIdsPointer.ref),
          dependencyRelationshipIds: _decodeIdList(dependencyRelationshipIdsPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(dependencyObjectIdsPointer);
        _bindings.packageIdListRelease(dependencyRelationshipIdsPointer);
      }
    } finally {
      malloc.free(objectIdPointer);
      malloc.free(maxDepthPointer);
      malloc.free(dependencyObjectIdsPointer);
      malloc.free(dependencyRelationshipIdsPointer);
    }
  }

  /// The transitive INCOMING DependsOn closure of [objectId] (WP-EKE-006,
  /// `oep_analysis_impact`). Same graph-readiness contract as
  /// [analyzeDependencies].
  ({int maxDepth, List<String> affectedObjectIds, List<String> affectedRelationshipIds}) analyzeImpact(
    String objectId,
  ) {
    _assertNotDisposed();
    final objectIdPointer = objectId.toNativeUtf8();
    final maxDepthPointer = malloc<Int32>();
    final affectedObjectIdsPointer = malloc<OepPackageIdListNative>();
    final affectedRelationshipIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.analysisImpact(
          _runtime,
          objectIdPointer,
          maxDepthPointer,
          affectedObjectIdsPointer,
          affectedRelationshipIdsPointer,
          nullptr,
        ),
      );
      try {
        return (
          maxDepth: maxDepthPointer.value,
          affectedObjectIds: _decodeIdList(affectedObjectIdsPointer.ref),
          affectedRelationshipIds: _decodeIdList(affectedRelationshipIdsPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(affectedObjectIdsPointer);
        _bindings.packageIdListRelease(affectedRelationshipIdsPointer);
      }
    } finally {
      malloc.free(objectIdPointer);
      malloc.free(maxDepthPointer);
      malloc.free(affectedObjectIdsPointer);
      malloc.free(affectedRelationshipIdsPointer);
    }
  }

  /// Whether [targetId] is reachable from [sourceId] (WP-EKE-006,
  /// `oep_analysis_reachability`). Same graph-readiness contract as
  /// [analyzeDependencies].
  ({bool reachable, List<String> path}) analyzeReachability(String sourceId, String targetId) {
    _assertNotDisposed();
    final sourcePointer = sourceId.toNativeUtf8();
    final targetPointer = targetId.toNativeUtf8();
    final reachablePointer = malloc<Int32>();
    final pathPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.analysisReachability(_runtime, sourcePointer, targetPointer, reachablePointer, pathPointer, nullptr),
      );
      try {
        return (reachable: reachablePointer.value != 0, path: _decodeIdList(pathPointer.ref));
      } finally {
        _bindings.packageIdListRelease(pathPointer);
      }
    } finally {
      malloc.free(sourcePointer);
      malloc.free(targetPointer);
      malloc.free(reachablePointer);
      malloc.free(pathPointer);
    }
  }

  /// Candidate root causes and failure chain for [symptomObjectId]
  /// (WP-EKE-006, `oep_analysis_root_cause`; routes through
  /// `ReasoningEngine::analyze_root_cause`). Same graph-readiness contract
  /// as [analyzeDependencies].
  ({List<String> candidateRootCauses, List<String> failureChain}) analyzeRootCause(String symptomObjectId) {
    _assertNotDisposed();
    final symptomPointer = symptomObjectId.toNativeUtf8();
    final candidatesPointer = malloc<OepPackageIdListNative>();
    final failureChainPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.analysisRootCause(_runtime, symptomPointer, candidatesPointer, failureChainPointer, nullptr),
      );
      try {
        return (
          candidateRootCauses: _decodeIdList(candidatesPointer.ref),
          failureChain: _decodeIdList(failureChainPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(candidatesPointer);
        _bindings.packageIdListRelease(failureChainPointer);
      }
    } finally {
      malloc.free(symptomPointer);
      malloc.free(candidatesPointer);
      malloc.free(failureChainPointer);
    }
  }

  /// Creates a new ReasoningSession for [objective], scoped to
  /// [startingObjectIds] (WP-EKE-006, `oep_reasoning_create_session`), and
  /// returns its session_id. Does NOT require a prior
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call — mirrors
  /// [createValidationSession]'s own precedent; only [executeReasoning]
  /// (and the four `analyze*` methods above, which need no session at
  /// all) require a built graph. In-memory, per-handle state — not
  /// persisted, same as [createValidationSession].
  String createReasoningSession(String objective, List<String> startingObjectIds) {
    _assertNotDisposed();
    final objectivePointer = objective.toNativeUtf8();
    final startingObjectIdCount = startingObjectIds.length;
    final startingObjectIdArray = _allocateTagArray(startingObjectIds);
    final sessionIdPointer = malloc<Uint8>(oepMaxSessionId).cast<Utf8>();
    try {
      _checkResult(
        _bindings.reasoningCreateSession(
          _runtime,
          objectivePointer,
          startingObjectIdArray,
          startingObjectIdCount,
          sessionIdPointer,
          oepMaxSessionId,
        ),
      );
      return sessionIdPointer.toDartString();
    } finally {
      malloc.free(objectivePointer);
      _freeTagArray(startingObjectIdArray, startingObjectIdCount);
      malloc.free(sessionIdPointer);
    }
  }

  /// Runs [sessionId]'s reasoning (WP-EKE-006, `oep_reasoning_execute`):
  /// dependency/impact/root-cause analysis, validation, Evidence Graph
  /// construction, and EngineeringConclusion/EngineeringRecommendation
  /// derivation for each starting object. Requires a prior
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call. Throws
  /// [FoundationBridgeException] (`OEP_ERROR_NOT_FOUND`) if [sessionId]
  /// was not created via [createReasoningSession] on this handle.
  ({OepReasoningSummary summary, List<String> conclusionIds, List<String> recommendationIds}) executeReasoning(
    String sessionId,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final summaryPointer = malloc<OepReasoningSummaryNative>();
    final conclusionIdsPointer = malloc<OepPackageIdListNative>();
    final recommendationIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.reasoningExecute(
          _runtime,
          sessionIdPointer,
          summaryPointer,
          conclusionIdsPointer,
          recommendationIdsPointer,
        ),
      );
      return _decodeReasoningReport(summaryPointer, conclusionIdsPointer, recommendationIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(summaryPointer);
      malloc.free(conclusionIdsPointer);
      malloc.free(recommendationIdsPointer);
    }
  }

  /// The most recent ReasoningReport for [sessionId] (WP-EKE-006,
  /// `oep_reasoning_report`). Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) if [sessionId] was not created via
  /// [createReasoningSession] on this handle, or
  /// (`OEP_ERROR_INVALID_STATE`) if the session exists but has never been
  /// executed.
  ({OepReasoningSummary summary, List<String> conclusionIds, List<String> recommendationIds}) reasoningReport(
    String sessionId,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final summaryPointer = malloc<OepReasoningSummaryNative>();
    final conclusionIdsPointer = malloc<OepPackageIdListNative>();
    final recommendationIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.reasoningReport(
          _runtime,
          sessionIdPointer,
          summaryPointer,
          conclusionIdsPointer,
          recommendationIdsPointer,
        ),
      );
      return _decodeReasoningReport(summaryPointer, conclusionIdsPointer, recommendationIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(summaryPointer);
      malloc.free(conclusionIdsPointer);
      malloc.free(recommendationIdsPointer);
    }
  }

  /// Convenience accessor equivalent to [reasoningReport]'s
  /// `recommendationIds` (WP-EKE-006, `oep_reasoning_recommendations`).
  /// Same not-found/not-yet-executed error contract as [reasoningReport].
  List<String> reasoningRecommendations(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final recommendationIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.reasoningRecommendations(_runtime, sessionIdPointer, recommendationIdsPointer));
      try {
        return _decodeIdList(recommendationIdsPointer.ref);
      } finally {
        _bindings.packageIdListRelease(recommendationIdsPointer);
      }
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(recommendationIdsPointer);
    }
  }

  /// Fetches one EngineeringConclusion by [conclusionId] from [sessionId]'s
  /// most recent ReasoningReport (WP-EKE-006,
  /// `oep_reasoning_get_conclusion`) — FOUR separate id lists
  /// (supportingEvidenceIds/referencedObjects/referencedRules/
  /// referencedFindings), each released after decoding. Throws
  /// [FoundationBridgeException] (`OEP_ERROR_NOT_FOUND`) if [sessionId]
  /// was not created on this handle, or [conclusionId] is not found
  /// within that report's session.
  ({
    OepConclusion conclusion,
    List<String> supportingEvidenceIds,
    List<String> referencedObjects,
    List<String> referencedRules,
    List<String> referencedFindings,
  })
  getConclusion(String sessionId, String conclusionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final conclusionIdPointer = conclusionId.toNativeUtf8();
    final conclusionPointer = malloc<OepConclusionNative>();
    final supportingEvidenceIdsPointer = malloc<OepPackageIdListNative>();
    final referencedObjectsPointer = malloc<OepPackageIdListNative>();
    final referencedRulesPointer = malloc<OepPackageIdListNative>();
    final referencedFindingsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.reasoningGetConclusion(
          _runtime,
          sessionIdPointer,
          conclusionIdPointer,
          conclusionPointer,
          supportingEvidenceIdsPointer,
          referencedObjectsPointer,
          referencedRulesPointer,
          referencedFindingsPointer,
        ),
      );
      try {
        return (
          conclusion: OepConclusion.fromNative(conclusionPointer.ref),
          supportingEvidenceIds: _decodeIdList(supportingEvidenceIdsPointer.ref),
          referencedObjects: _decodeIdList(referencedObjectsPointer.ref),
          referencedRules: _decodeIdList(referencedRulesPointer.ref),
          referencedFindings: _decodeIdList(referencedFindingsPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(supportingEvidenceIdsPointer);
        _bindings.packageIdListRelease(referencedObjectsPointer);
        _bindings.packageIdListRelease(referencedRulesPointer);
        _bindings.packageIdListRelease(referencedFindingsPointer);
      }
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(conclusionIdPointer);
      malloc.free(conclusionPointer);
      malloc.free(supportingEvidenceIdsPointer);
      malloc.free(referencedObjectsPointer);
      malloc.free(referencedRulesPointer);
      malloc.free(referencedFindingsPointer);
    }
  }

  /// Fetches one EngineeringRecommendation by [recommendationId] from
  /// [sessionId]'s most recent ReasoningReport (WP-EKE-006,
  /// `oep_reasoning_get_recommendation`). Same not-found contract as
  /// [getConclusion].
  ({OepRecommendation recommendation, List<String> supportingEvidenceIds}) getRecommendation(
    String sessionId,
    String recommendationId,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final recommendationIdPointer = recommendationId.toNativeUtf8();
    final recommendationPointer = malloc<OepRecommendationNative>();
    final supportingEvidenceIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.reasoningGetRecommendation(
          _runtime,
          sessionIdPointer,
          recommendationIdPointer,
          recommendationPointer,
          supportingEvidenceIdsPointer,
        ),
      );
      try {
        return (
          recommendation: OepRecommendation.fromNative(recommendationPointer.ref),
          supportingEvidenceIds: _decodeIdList(supportingEvidenceIdsPointer.ref),
        );
      } finally {
        _bindings.packageIdListRelease(supportingEvidenceIdsPointer);
      }
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(recommendationIdPointer);
      malloc.free(recommendationPointer);
      malloc.free(supportingEvidenceIdsPointer);
    }
  }

  /// Fetches one EvidenceNode by [evidenceId] from [sessionId]'s most
  /// recent ReasoningReport's Evidence Graph (WP-EKE-006,
  /// `oep_reasoning_get_evidence_node`). See `oep_api.h`'s "Evidence Graph
  /// exposure" note — this is the only Evidence Graph shape Studio
  /// exposes. Same not-found contract as [getConclusion].
  OepEvidenceNode getEvidenceNode(String sessionId, String evidenceId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final evidenceIdPointer = evidenceId.toNativeUtf8();
    final nodePointer = malloc<OepEvidenceNodeNative>();
    try {
      _checkResult(_bindings.reasoningGetEvidenceNode(_runtime, sessionIdPointer, evidenceIdPointer, nodePointer));
      return OepEvidenceNode.fromNative(nodePointer.ref);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(evidenceIdPointer);
      malloc.free(nodePointer);
    }
  }

  /// Shared decode+release for [executeReasoning]/[reasoningReport]: builds
  /// the plain Dart result from `summaryPointer`/`conclusionIdsPointer`/
  /// `recommendationIdsPointer`, then releases both id lists — the caller
  /// owns `out_conclusion_ids->items`/`out_recommendation_ids->items` on
  /// success per `oep_api.h`'s documented ownership contract.
  ({OepReasoningSummary summary, List<String> conclusionIds, List<String> recommendationIds}) _decodeReasoningReport(
    Pointer<OepReasoningSummaryNative> summaryPointer,
    Pointer<OepPackageIdListNative> conclusionIdsPointer,
    Pointer<OepPackageIdListNative> recommendationIdsPointer,
  ) {
    try {
      return (
        summary: OepReasoningSummary.fromNative(summaryPointer.ref),
        conclusionIds: _decodeIdList(conclusionIdsPointer.ref),
        recommendationIds: _decodeIdList(recommendationIdsPointer.ref),
      );
    } finally {
      _bindings.packageIdListRelease(conclusionIdsPointer);
      _bindings.packageIdListRelease(recommendationIdsPointer);
    }
  }

  // --- Engineering Intelligence Platform (WP-EKE-007) ---

  /// Creates a new KnowledgeSession on the EngineeringIntelligencePlatform
  /// facade (WP-EKE-007, `oep_eip_create_session`) and returns its
  /// session_id. Does NOT require a prior [loadKnowledgeGraph]/
  /// [buildKnowledgeGraph] call — mirrors [createReasoningSession]'s own
  /// precedent; only the Workflow methods below (query/inspect/validate/
  /// analyze/reason/recommend) require a built graph. In-memory,
  /// per-handle state — not persisted, same as [createReasoningSession].
  String createEipSession() {
    _assertNotDisposed();
    final sessionIdPointer = malloc<Uint8>(oepMaxSessionId).cast<Utf8>();
    try {
      _checkResult(_bindings.eipCreateSession(_runtime, sessionIdPointer, oepMaxSessionId));
      return sessionIdPointer.toDartString();
    } finally {
      malloc.free(sessionIdPointer);
    }
  }

  /// Marks [sessionId] as resumed / most-recently-active (WP-EKE-007,
  /// `oep_eip_resume_session`). Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) for an unknown or already-closed session_id.
  void resumeEipSession(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    try {
      _checkResult(_bindings.eipResumeSession(_runtime, sessionIdPointer));
    } finally {
      malloc.free(sessionIdPointer);
    }
  }

  /// Clones [sessionId]'s history/active-set snapshot into a new session
  /// (statistics reset to zero — WP-EKE-007, `oep_eip_clone_session`) and
  /// returns the new session_id. Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) if [sessionId] is unknown.
  String cloneEipSession(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final outSessionIdPointer = malloc<Uint8>(oepMaxSessionId).cast<Utf8>();
    try {
      _checkResult(_bindings.eipCloneSession(_runtime, sessionIdPointer, outSessionIdPointer, oepMaxSessionId));
      return outSessionIdPointer.toDartString();
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(outSessionIdPointer);
    }
  }

  /// Closes [sessionId] (WP-EKE-007, `oep_eip_close_session`). Throws
  /// [FoundationBridgeException] (`OEP_ERROR_NOT_FOUND`) for an unknown
  /// session_id.
  void closeEipSession(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    try {
      _checkResult(_bindings.eipCloseSession(_runtime, sessionIdPointer));
    } finally {
      malloc.free(sessionIdPointer);
    }
  }

  /// Sets this handle's "current" session pointer to [sessionId] (a
  /// CLI/convenience concept — WP-EKE-007, `oep_eip_switch_session`);
  /// every Workflow method below always takes an explicit `sessionId` and
  /// never relies on this. Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) for an unknown or closed session_id.
  void switchEipSession(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    try {
      _checkResult(_bindings.eipSwitchSession(_runtime, sessionIdPointer));
    } finally {
      malloc.free(sessionIdPointer);
    }
  }

  /// Every session_id ever created on this handle (including closed
  /// ones), sorted (WP-EKE-007, `oep_eip_list_sessions`).
  List<String> listEipSessions() {
    _assertNotDisposed();
    final listPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.eipListSessions(_runtime, listPointer));
      try {
        return _decodeIdList(listPointer.ref);
      } finally {
        _bindings.packageIdListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Fetches [sessionId]'s KnowledgeSession scalar summary (WP-EKE-007,
  /// `oep_eip_get_session`). Throws [FoundationBridgeException]
  /// (`OEP_ERROR_NOT_FOUND`) for an unknown session_id.
  OepKnowledgeSessionSummary getEipSession(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final summaryPointer = malloc<OepKnowledgeSessionSummaryNative>();
    try {
      _checkResult(_bindings.eipGetSession(_runtime, sessionIdPointer, summaryPointer));
      return OepKnowledgeSessionSummary.fromNative(summaryPointer.ref);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(summaryPointer);
    }
  }

  /// A short, human-readable text summary of [sessionId] (WP-EKE-007,
  /// `oep_eip_export_session_summary`), a caller-owned, heap-allocated
  /// NUL-terminated buffer released via exactly one
  /// [OepApiBindings.stringRelease] call — same "owned-heap-string export"
  /// convention as [exportKnowledgeGraphJson]. Throws
  /// [FoundationBridgeException] (`OEP_ERROR_NOT_FOUND`) for an unknown
  /// session_id.
  String exportEipSessionSummary(String sessionId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final textPointer = malloc<Pointer<Utf8>>();
    final lengthPointer = malloc<Size>();
    textPointer.value = nullptr;
    try {
      _checkResult(_bindings.eipExportSessionSummary(_runtime, sessionIdPointer, textPointer, lengthPointer));
      try {
        return textPointer.value.toDartString(length: lengthPointer.value);
      } finally {
        _bindings.stringRelease(textPointer);
      }
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(textPointer);
      malloc.free(lengthPointer);
    }
  }

  /// "Query" workflow (WP-EKE-007, `oep_eip_query`). [sessionId] must
  /// already exist on this handle (`OEP_ERROR_NOT_FOUND` otherwise).
  /// Requires a prior [loadKnowledgeGraph]/`oep_engine_load_graph` AND
  /// [buildKnowledgeGraph]/[refreshKnowledgeGraph] call (see `oep_api.h`'s
  /// "Graph-readiness precondition" note), surfacing as
  /// `OEP_ERROR_INVALID_STATE` otherwise.
  ({OepWorkflowResult result, List<String> objectIds}) eipQuery(
    String sessionId,
    QueryCategory category,
    String primaryObjectId,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final primaryObjectIdPointer = primaryObjectId.toNativeUtf8();
    final resultPointer = malloc<OepWorkflowResultNative>();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.eipQuery(
          _runtime,
          sessionIdPointer,
          category.nativeValue,
          primaryObjectIdPointer,
          resultPointer,
          objectIdsPointer,
        ),
      );
      return _decodeEipWorkflowResult(resultPointer, objectIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(primaryObjectIdPointer);
      malloc.free(resultPointer);
      malloc.free(objectIdsPointer);
    }
  }

  /// "Inspect" workflow (WP-EKE-007, `oep_eip_inspect`). Same
  /// session_id/graph-readiness contract as [eipQuery]. [targetId] may be
  /// empty when [kind] is [InspectionTargetKind.context].
  ({OepWorkflowResult result, List<String> objectIds}) eipInspect(
    String sessionId,
    InspectionTargetKind kind,
    String targetId,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final targetIdPointer = targetId.toNativeUtf8();
    final resultPointer = malloc<OepWorkflowResultNative>();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.eipInspect(
          _runtime,
          sessionIdPointer,
          kind.nativeValue,
          targetIdPointer,
          resultPointer,
          objectIdsPointer,
        ),
      );
      return _decodeEipWorkflowResult(resultPointer, objectIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(targetIdPointer);
      malloc.free(resultPointer);
      malloc.free(objectIdsPointer);
    }
  }

  /// "Validate" workflow (WP-EKE-007, `oep_eip_validate`). Same
  /// session_id/graph-readiness contract as [eipQuery].
  ({OepWorkflowResult result, List<String> objectIds}) eipValidate(
    String sessionId,
    String objectId,
    ValidationProfile profile,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final objectIdPointer = objectId.toNativeUtf8();
    final resultPointer = malloc<OepWorkflowResultNative>();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.eipValidate(
          _runtime,
          sessionIdPointer,
          objectIdPointer,
          profile.nativeValue,
          resultPointer,
          objectIdsPointer,
        ),
      );
      return _decodeEipWorkflowResult(resultPointer, objectIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(objectIdPointer);
      malloc.free(resultPointer);
      malloc.free(objectIdsPointer);
    }
  }

  /// "Analyze" workflow (WP-EKE-007, `oep_eip_analyze`). Same
  /// session_id/graph-readiness contract as [eipQuery].
  ({OepWorkflowResult result, List<String> objectIds}) eipAnalyze(String sessionId, String objectId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final objectIdPointer = objectId.toNativeUtf8();
    final resultPointer = malloc<OepWorkflowResultNative>();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.eipAnalyze(_runtime, sessionIdPointer, objectIdPointer, resultPointer, objectIdsPointer));
      return _decodeEipWorkflowResult(resultPointer, objectIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(objectIdPointer);
      malloc.free(resultPointer);
      malloc.free(objectIdsPointer);
    }
  }

  /// "Reason" workflow (WP-EKE-007, `oep_eip_reason`). Same
  /// session_id/graph-readiness contract as [eipQuery]. [objective] may be
  /// empty; [startingObjectIds] may be empty (marshaled the same way as
  /// [createReasoningSession]'s own starting-object array).
  ({OepWorkflowResult result, List<String> objectIds}) eipReason(
    String sessionId,
    String objective,
    List<String> startingObjectIds,
  ) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final objectivePointer = objective.toNativeUtf8();
    final startingObjectIdCount = startingObjectIds.length;
    final startingObjectIdArray = _allocateTagArray(startingObjectIds);
    final resultPointer = malloc<OepWorkflowResultNative>();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.eipReason(
          _runtime,
          sessionIdPointer,
          objectivePointer,
          startingObjectIdArray,
          startingObjectIdCount,
          resultPointer,
          objectIdsPointer,
        ),
      );
      return _decodeEipWorkflowResult(resultPointer, objectIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(objectivePointer);
      _freeTagArray(startingObjectIdArray, startingObjectIdCount);
      malloc.free(resultPointer);
      malloc.free(objectIdsPointer);
    }
  }

  /// "Recommend" workflow (WP-EKE-007, `oep_eip_recommend`). Same
  /// session_id/graph-readiness contract as [eipQuery]. `objectIds` is
  /// filled with each recommendation's target object_id (one entry per
  /// recommendation — see `oep_api.h`'s `WorkflowResult::object_ids`
  /// note).
  ({OepWorkflowResult result, List<String> objectIds}) eipRecommend(String sessionId, String objectId) {
    _assertNotDisposed();
    final sessionIdPointer = sessionId.toNativeUtf8();
    final objectIdPointer = objectId.toNativeUtf8();
    final resultPointer = malloc<OepWorkflowResultNative>();
    final objectIdsPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(
        _bindings.eipRecommend(_runtime, sessionIdPointer, objectIdPointer, resultPointer, objectIdsPointer),
      );
      return _decodeEipWorkflowResult(resultPointer, objectIdsPointer);
    } finally {
      malloc.free(sessionIdPointer);
      malloc.free(objectIdPointer);
      malloc.free(resultPointer);
      malloc.free(objectIdsPointer);
    }
  }

  /// Shared decode+release for every `eip*` Workflow method above: builds
  /// the plain Dart result, then releases the object id list — the
  /// caller owns `out_object_ids->items` on success per `oep_api.h`'s
  /// documented ownership contract.
  ({OepWorkflowResult result, List<String> objectIds}) _decodeEipWorkflowResult(
    Pointer<OepWorkflowResultNative> resultPointer,
    Pointer<OepPackageIdListNative> objectIdsPointer,
  ) {
    try {
      return (result: OepWorkflowResult.fromNative(resultPointer.ref), objectIds: _decodeIdList(objectIdsPointer.ref));
    } finally {
      _bindings.packageIdListRelease(objectIdsPointer);
    }
  }

  /// Stateless Service Orchestrator call (WP-EKE-007,
  /// `oep_eip_engineering_summary`). No session required. Requires a
  /// prior [loadKnowledgeGraph]/[buildKnowledgeGraph] call.
  OepEngineeringSummaryReport engineeringSummary() {
    _assertNotDisposed();
    final summaryPointer = malloc<OepEngineeringSummaryReportNative>();
    try {
      _checkResult(_bindings.eipEngineeringSummary(_runtime, summaryPointer));
      return OepEngineeringSummaryReport.fromNative(summaryPointer.ref);
    } finally {
      malloc.free(summaryPointer);
    }
  }

  /// Stateless Service Orchestrator call (WP-EKE-007,
  /// `oep_eip_engineering_health`). No session required. Requires a prior
  /// [loadKnowledgeGraph]/[buildKnowledgeGraph] call.
  OepEngineeringHealthReport engineeringHealth() {
    _assertNotDisposed();
    final healthPointer = malloc<OepEngineeringHealthReportNative>();
    try {
      _checkResult(_bindings.eipEngineeringHealth(_runtime, healthPointer));
      return OepEngineeringHealthReport.fromNative(healthPointer.ref);
    } finally {
      malloc.free(healthPointer);
    }
  }

  /// Stateless Service Orchestrator call (WP-EKE-007,
  /// `oep_eip_engineering_recommendations`). No session required.
  /// Requires a prior [loadKnowledgeGraph]/[buildKnowledgeGraph] call.
  /// Returns recommendation MESSAGE strings, not full
  /// EngineeringRecommendation objects — see `oep_api.h`'s
  /// "oep_eip_engineering_recommendations shape" header note:
  /// `EngineeringIntelligencePlatform::engineering_recommendations`
  /// creates its own ephemeral internal ReasoningSession each call, never
  /// exposed and never queryable afterward, so only its message text
  /// survives (returned via the reused `oep_package_id_list_t`). A caller
  /// wanting full EngineeringRecommendation objects
  /// (kind/object_id/evidence) should use [createReasoningSession] +
  /// [executeReasoning] + [getRecommendation] instead, over their own
  /// session.
  List<String> engineeringRecommendations(String objectId) {
    _assertNotDisposed();
    final objectIdPointer = objectId.toNativeUtf8();
    final messagesPointer = malloc<OepPackageIdListNative>();
    try {
      _checkResult(_bindings.eipEngineeringRecommendations(_runtime, objectIdPointer, messagesPointer));
      try {
        return _decodeIdList(messagesPointer.ref);
      } finally {
        _bindings.packageIdListRelease(messagesPointer);
      }
    } finally {
      malloc.free(objectIdPointer);
      malloc.free(messagesPointer);
    }
  }

  /// Snapshot of this handle's Runtime Metrics (WP-EKE-007,
  /// `oep_eip_runtime_metrics`). No session required, no graph-readiness
  /// precondition — a fresh handle simply reports all zeros.
  OepRuntimeMetrics runtimeMetrics() {
    _assertNotDisposed();
    final metricsPointer = malloc<OepRuntimeMetricsNative>();
    try {
      _checkResult(_bindings.eipRuntimeMetrics(_runtime, metricsPointer));
      return OepRuntimeMetrics.fromNative(metricsPointer.ref);
    } finally {
      malloc.free(metricsPointer);
    }
  }

  /// Clears the Query Engine's cache (WP-EKE-007,
  /// `oep_eip_invalidate_caches`). No session required, no
  /// graph-readiness precondition.
  void invalidateCaches() {
    _assertNotDisposed();
    _checkResult(_bindings.eipInvalidateCaches(_runtime));
  }

  /// Closes every open session on this handle and clears every lower
  /// engine's cache (WP-EKE-007, `oep_eip_cleanup`).
  void cleanupEip() {
    _assertNotDisposed();
    _checkResult(_bindings.eipCleanup(_runtime));
  }

  /// Shuts the Runtime down, closing an open repository first if needed.
  /// Throws [FoundationBridgeException] on failure. Safe to call at most
  /// once; call [dispose] afterward (or instead) to release the handle.
  void shutdown() {
    _assertNotDisposed();
    _checkResult(_bindings.runtimeShutdown(_runtime));
  }

  /// Releases the native Runtime handle. Safe to call multiple times.
  /// Does not throw — mirrors `oep_runtime_destroy`, which is a no-op-safe
  /// void function by design so cleanup code never needs its own
  /// try/catch.
  void dispose() {
    if (_disposed) return;
    _bindings.runtimeDestroy(_runtime);
    _disposed = true;
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('FoundationBridge used after dispose()');
    }
  }

  void _checkResult(OepResultNative result) {
    if (result.success != 0) return;
    final code = FoundationErrorCode.fromNative(result.errorCode);
    final category = FoundationErrorCategory.fromNative(result.errorCategory);
    final technicalDetail = decodeFixedCString(result.errorMessage, oepMaxErrorMessage);
    throw FoundationBridgeException.fromResult(code: code, category: category, technicalDetail: technicalDetail);
  }
}
