import '../knowledge_runtime.dart';
import '../knowledge_runtime_errors.dart';
import 'reference_discovery_indexes.dart';

export 'reference_discovery_indexes.dart'
    show ReferenceDiscoveryIndexes, ReferenceGraphEdge;

/// One deterministic search hit (WP-EKE-014).
///
/// A hit only *identifies* an authoritative object and explains the match;
/// it is not knowledge. Resolve [objectId] through
/// `KnowledgeRuntime.getObject` for anything authoritative.
class ReferenceSearchHit {
  /// Authoritative Reference Library object id (resolves in
  /// `KnowledgeRuntime.getObject`).
  final String objectId;

  /// The distinct normalized query tokens this object matched, sorted.
  /// (`search.idx` records no field of origin, so none is reported.)
  final List<String> matchedTerms;

  ReferenceSearchHit._(this.objectId, List<String> matched)
    : matchedTerms = List.unmodifiable(matched);

  /// Deterministic rank: the number of distinct query tokens matched.
  int get score => matchedTerms.length;

  @override
  String toString() => 'ReferenceSearchHit($objectId, $matchedTerms)';
}

/// What this discovery instance can do, separate from
/// `KnowledgeRuntimeCapabilities` (which describes authoritative content).
class ReferenceDiscoveryCapabilities {
  /// Token search over the compiled `search.idx`.
  final bool termSearch;

  /// Outgoing relationship traversal over the compiled `graph.idx`.
  final bool relationshipTraversal;
  final int searchIndexVersion;
  final int graphIndexVersion;
  final int indexedTermCount;
  final int indexedObjectCount;
  final int graphEdgeCount;

  const ReferenceDiscoveryCapabilities._({
    required this.termSearch,
    required this.relationshipTraversal,
    required this.searchIndexVersion,
    required this.graphIndexVersion,
    required this.indexedTermCount,
    required this.indexedObjectCount,
    required this.graphEdgeCount,
  });
}

/// Deterministic discovery over a compiled package's precompiled indexes
/// (WP-EKE-014; SDD-R007 exact/alias search and relationship navigation).
///
/// ```text
/// KnowledgeRuntime   = authoritative typed reference knowledge
/// ReferenceDiscovery = retrieval of authoritative IDs; never a second
///                      knowledge store
/// ```
///
/// Results are identifiers. Callers resolve them through the same
/// [KnowledgeRuntime] (`getObject`, `getRelationship`). This class holds no
/// object or relationship definitions of its own, reads no package files,
/// and never mutates its inputs. It is unrelated to the workspace/diagram
/// `SearchService` (`lib/core/search`).
///
/// **Not implemented** (no index support exists): property, behavior,
/// natural-language, semantic or fuzzy search; ranking by relationship
/// distance; incoming-edge traversal (`graph.idx` lists outgoing edges only;
/// `KnowledgeRuntime.relationshipsForObject` is the authority for both
/// directions).
class ReferenceDiscovery {
  final KnowledgeRuntime _runtime;
  final ReferenceDiscoveryIndexes _indexes;
  final Set<String> _objectIds;
  final ReferenceDiscoveryCapabilities capabilities;

  ReferenceDiscovery._(
    this._runtime,
    this._indexes,
    this._objectIds,
    this.capabilities,
  );

  /// Binds [indexes] to the authoritative [runtime] they were compiled with.
  ///
  /// Throws `packageInvalid` if the indexes disagree with the runtime: a
  /// posting or graph node naming an object the runtime does not have, an
  /// edge naming a relationship the runtime does not have or whose
  /// source/target/type differ from it, or a runtime relationship missing
  /// from the graph. That guarantees every returned id resolves.
  factory ReferenceDiscovery.create(
    KnowledgeRuntime runtime,
    ReferenceDiscoveryIndexes indexes,
  ) {
    Never mismatch(String detail) => throw KnowledgeRuntimeException(
      KnowledgeRuntimeErrorCode.packageInvalid,
      'Discovery indexes do not match the active package '
      '${runtime.identity.packageId}@${runtime.identity.packageVersion}: '
      '$detail',
    );

    final objectIds = {for (final o in runtime.package.objects) o.id};
    final relationships = {for (final r in runtime.package.relationships) r.id: r};

    for (final id in indexes.searchIndex.objectIds) {
      if (!objectIds.contains(id)) {
        mismatch('search.idx references unknown object "$id".');
      }
    }
    var edgeCount = 0;
    for (final node in indexes.graphIndex.nodes.entries) {
      if (!objectIds.contains(node.key)) {
        mismatch('graph.idx has a node for unknown object "${node.key}".');
      }
      for (final edge in node.value) {
        edgeCount++;
        final rel = relationships[edge.relationshipId];
        if (rel == null) {
          mismatch('graph.idx edge "${edge.relationshipId}" is not a runtime relationship.');
        }
        if (rel.sourceObjectId != edge.sourceObjectId ||
            rel.targetObjectId != edge.targetObjectId ||
            rel.relationshipType != edge.relationshipType) {
          mismatch('graph.idx edge "${edge.relationshipId}" disagrees with the runtime relationship.');
        }
      }
    }
    if (edgeCount != relationships.length) {
      mismatch(
        'graph.idx lists $edgeCount edges but the runtime has '
        '${relationships.length} relationships.',
      );
    }

    return ReferenceDiscovery._(
      runtime,
      indexes,
      objectIds,
      ReferenceDiscoveryCapabilities._(
        termSearch: true,
        relationshipTraversal: true,
        searchIndexVersion: indexes.searchIndex.version,
        graphIndexVersion: indexes.graphIndex.version,
        indexedTermCount: indexes.searchIndex.terms.length,
        indexedObjectCount: indexes.searchIndex.objectIds.length,
        graphEdgeCount: edgeCount,
      ),
    );
  }

  /// The compiler's tokenization (`indexes.py`: lower-case, `[a-z0-9]+`
  /// runs), and nothing more: no stemming, synonyms or fuzzy matching.
  /// Characters outside `[a-z0-9]` (including all non-ASCII) separate
  /// tokens and are dropped, exactly as they were when the index was built.
  /// Duplicates are removed, first occurrence kept.
  static List<String> normalizeQuery(String query) {
    final seen = <String>{};
    final tokens = <String>[];
    for (final m in RegExp(r'[a-z0-9]+').allMatches(query.toLowerCase())) {
      if (seen.add(m.group(0)!)) tokens.add(m.group(0)!);
    }
    return tokens;
  }

  /// Token search.
  ///
  /// [query] is normalized with [normalizeQuery]. An object matches if it
  /// contains at least one query token (or every one, when
  /// [requireAllTerms] is true). A query with no tokens, or one that
  /// matches nothing, is a **valid empty result** (`[]`), not an error.
  ///
  /// Ordering is total and reproducible: [ReferenceSearchHit.score]
  /// descending (distinct query tokens matched), then object id ascending.
  /// Each object appears once.
  List<ReferenceSearchHit> search(String query, {bool requireAllTerms = false}) {
    final tokens = normalizeQuery(query);
    if (tokens.isEmpty) return const [];

    final matchedByObject = <String, List<String>>{};
    for (final token in tokens) {
      final ids = _indexes.searchIndex.terms[token];
      if (ids == null) continue;
      for (final id in ids) {
        matchedByObject.putIfAbsent(id, () => []).add(token);
      }
    }

    final hits = <ReferenceSearchHit>[
      for (final e in matchedByObject.entries)
        if (!requireAllTerms || e.value.length == tokens.length)
          ReferenceSearchHit._(e.key, e.value.toList()..sort()),
    ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.objectId.compareTo(b.objectId);
      });
    return List.unmodifiable(hits);
  }

  /// Outgoing relationship edges of [objectId], in the compiled order
  /// (relationship type, target, relationship id). Empty for an object with
  /// no outgoing relationships. Throws `referenceNotFound` for an unknown
  /// object. Resolve an edge's [ReferenceGraphEdge.relationshipId] with
  /// `KnowledgeRuntime.getRelationship` for authoritative semantics.
  List<ReferenceGraphEdge> outgoing(String objectId) {
    _requireObject(objectId);
    return _indexes.graphIndex.nodes[objectId] ?? const [];
  }

  /// Distinct target object ids of [objectId]'s outgoing edges, sorted.
  List<String> relatedObjectIds(String objectId) => List.unmodifiable(
    (outgoing(objectId).map((e) => e.targetObjectId).toSet().toList())..sort(),
  );

  void _requireObject(String objectId) {
    if (_objectIds.contains(objectId)) return;
    // Delegate so the error is the runtime's own, identical to getObject's.
    _runtime.getObject(objectId);
  }
}
