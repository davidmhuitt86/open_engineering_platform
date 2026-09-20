import 'dart:convert';

import '../knowledge_runtime_errors.dart';

/// Parsed, validated, immutable form of a compiled package's `search.idx`
/// and `graph.idx` (WP-EKE-014).
///
/// The formats are exactly what the Reference Compiler
/// (`knowledge/reference_library/compiler/indexes.py`) writes -- nothing
/// here is inferred from file names:
///
/// ```text
/// search.idx  {"version": 1, "terms": {"<token>": ["<objectId>", ...]}}
/// graph.idx   {"version": 1, "nodes": {"<objectId>": [
///               {"relationship_id": ..., "relationship_type": ..., "target": ...}]}}
/// ```
///
/// A token is a lower-case `[a-z0-9]+` run; the index records *which*
/// objects contain a token but not which field it came from. `graph.idx`
/// lists **outgoing** edges only; the source of an edge is its node key.
///
/// Parsing never treats a malformed index as an empty one: any structural
/// problem throws [KnowledgeRuntimeException] (`packageInvalid`), and an
/// unsupported `version` throws `schemaUnsupported`.
class ReferenceDiscoveryIndexes {
  /// The only index `version` this reader understands.
  static const int supportedVersion = 1;

  final ReferenceSearchIndex searchIndex;
  final ReferenceGraphIndex graphIndex;

  const ReferenceDiscoveryIndexes({
    required this.searchIndex,
    required this.graphIndex,
  });

  /// Parses the text of `search.idx` and `graph.idx`.
  factory ReferenceDiscoveryIndexes.parse({
    required String searchIdxJson,
    required String graphIdxJson,
  }) => ReferenceDiscoveryIndexes(
    searchIndex: ReferenceSearchIndex._parse(searchIdxJson),
    graphIndex: ReferenceGraphIndex._parse(graphIdxJson),
  );
}

Never _invalid(String file, String detail) => throw KnowledgeRuntimeException(
  KnowledgeRuntimeErrorCode.packageInvalid,
  '$file is malformed: $detail',
);

Map<String, Object?> _decodeRoot(String file, String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    _invalid(file, 'not valid JSON ($e)');
  }
  if (decoded is! Map<String, Object?>) {
    _invalid(file, 'top level is not a JSON object');
  }
  final version = decoded['version'];
  if (version is! int) {
    _invalid(file, 'missing integer "version"');
  }
  if (version != ReferenceDiscoveryIndexes.supportedVersion) {
    throw KnowledgeRuntimeException(
      KnowledgeRuntimeErrorCode.schemaUnsupported,
      '$file version $version is unsupported (supported: '
      '${ReferenceDiscoveryIndexes.supportedVersion}).',
    );
  }
  return decoded;
}

final RegExp _tokenPattern = RegExp(r'^[a-z0-9]+$');

/// `search.idx`: token -> object ids.
class ReferenceSearchIndex {
  final int version;

  /// token -> sorted, unique, unmodifiable object ids.
  final Map<String, List<String>> terms;

  const ReferenceSearchIndex._(this.version, this.terms);

  static ReferenceSearchIndex _parse(String text) {
    const file = 'search.idx';
    final root = _decodeRoot(file, text);
    final rawTerms = root['terms'];
    if (rawTerms is! Map<String, Object?>) {
      _invalid(file, 'missing "terms" object');
    }
    final terms = <String, List<String>>{};
    for (final entry in rawTerms.entries) {
      // A term the query normalizer could never produce would be
      // unreachable -- a silent hole -- so it is rejected.
      if (!_tokenPattern.hasMatch(entry.key)) {
        _invalid(file, 'term "${entry.key}" is not a lower-case [a-z0-9]+ token');
      }
      final ids = entry.value;
      if (ids is! List || ids.isEmpty || ids.any((i) => i is! String || i.isEmpty)) {
        _invalid(file, 'term "${entry.key}" must map to a non-empty list of object ids');
      }
      final sorted = ids.cast<String>().toSet().toList()..sort();
      terms[entry.key] = List.unmodifiable(sorted);
    }
    return ReferenceSearchIndex._(
      ReferenceDiscoveryIndexes.supportedVersion,
      Map.unmodifiable(terms),
    );
  }

  /// Every distinct object id that appears in any posting list.
  Set<String> get objectIds => {for (final ids in terms.values) ...ids};
}

/// One outgoing relationship edge as recorded by `graph.idx`. It carries
/// identifiers only; the authoritative relationship is
/// `KnowledgeRuntime.getRelationship(relationshipId)`.
class ReferenceGraphEdge {
  final String relationshipId;
  final String relationshipType;
  final String sourceObjectId;
  final String targetObjectId;

  const ReferenceGraphEdge({
    required this.relationshipId,
    required this.relationshipType,
    required this.sourceObjectId,
    required this.targetObjectId,
  });
}

/// `graph.idx`: object id -> outgoing edges (as compiled: ordered by
/// relationship type, then target, then relationship id).
class ReferenceGraphIndex {
  final int version;
  final Map<String, List<ReferenceGraphEdge>> nodes;

  const ReferenceGraphIndex._(this.version, this.nodes);

  static ReferenceGraphIndex _parse(String text) {
    const file = 'graph.idx';
    final root = _decodeRoot(file, text);
    final rawNodes = root['nodes'];
    if (rawNodes is! Map<String, Object?>) {
      _invalid(file, 'missing "nodes" object');
    }
    final nodes = <String, List<ReferenceGraphEdge>>{};
    final seenRelationshipIds = <String>{};
    for (final entry in rawNodes.entries) {
      final edges = entry.value;
      if (edges is! List) {
        _invalid(file, 'node "${entry.key}" must map to a list of edges');
      }
      final parsed = <ReferenceGraphEdge>[];
      for (final edge in edges) {
        if (edge is! Map<String, Object?>) {
          _invalid(file, 'node "${entry.key}" has a non-object edge');
        }
        final id = edge['relationship_id'];
        final type = edge['relationship_type'];
        final target = edge['target'];
        if (id is! String || id.isEmpty || type is! String || type.isEmpty || target is! String || target.isEmpty) {
          _invalid(file, 'node "${entry.key}" has an edge without string relationship_id/relationship_type/target');
        }
        if (!seenRelationshipIds.add(id)) {
          _invalid(file, 'relationship "$id" appears more than once');
        }
        parsed.add(
          ReferenceGraphEdge(
            relationshipId: id,
            relationshipType: type,
            sourceObjectId: entry.key,
            targetObjectId: target,
          ),
        );
      }
      nodes[entry.key] = List.unmodifiable(parsed);
    }
    return ReferenceGraphIndex._(
      ReferenceDiscoveryIndexes.supportedVersion,
      Map.unmodifiable(nodes),
    );
  }

  int get edgeCount => nodes.values.fold(0, (n, edges) => n + edges.length);
}
