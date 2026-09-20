import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';

import 'support/stored_zip.dart';

/// WP-EKE-014 (Reference Package Discovery Runtime).
///
/// The index JSON below is written in exactly the format the Reference
/// Compiler emits (`compiler/indexes.py`; a real compiled package is
/// verified separately by `tool/verify_reference_discovery.dart`). Layer
/// under test: in-memory `KnowledgeRuntime` + parsed indexes.
KnowledgeObject _obj(String id) => KnowledgeObject(
  id: id,
  objectType: 'Component',
  name: id,
  shortName: id,
  version: '1.0.0',
  lifecycleState: 'Published',
  uuid: 'u-$id',
  domain: 'Electrical',
  tags: const [],
  provenanceId: 'prov.unit.volt',
);

KnowledgeRelationship _rel(String id, String type, String s, String t) =>
    KnowledgeRelationship(
      id: id,
      relationshipType: type,
      sourceObjectId: s,
      targetObjectId: t,
      cardinality: '',
      lifecycle: '',
      confidence: '',
      notes: '',
      provenanceId: 'prov.unit.volt',
    );

final _objects = [
  _obj('component.resistor'),
  _obj('symbol.resistor'),
  _obj('unit.ohm'),
  _obj('component.lonely'),
];
final _relationships = [
  _rel('c.res.has_unit.ohm', 'HAS_UNIT', 'component.resistor', 'unit.ohm'),
  _rel('c.res.represented_by.sym', 'REPRESENTED_BY', 'component.resistor', 'symbol.resistor'),
];

KnowledgeRuntime _runtime({
  List<KnowledgeObject>? objects,
  List<KnowledgeRelationship>? relationships,
}) {
  final base = buildElectricalCorePackage();
  return KnowledgeRuntime.activate(
    KnowledgePackage(
      manifest: base.manifest,
      dimensions: base.dimensions,
      units: base.units,
      componentModels: base.componentModels,
      laws: base.laws,
      equations: base.equations,
      constraints: base.constraints,
      provenance: base.provenance,
      objects: objects ?? _objects,
      relationships: relationships ?? _relationships,
      developmentModeUnsigned: true,
    ),
    allowUnsignedDevelopmentPackages: true,
  );
}

// Compiler format: sorted postings; tokens are lower-case [a-z0-9]+.
const _searchTerms = <String, List<String>>{
  '60115': ['component.resistor'], // a standards-reference token
  'fixed': ['component.resistor'],
  'ohm': ['unit.ohm'],
  'r': ['component.resistor', 'symbol.resistor'], // an abbreviation
  'resistor': ['component.resistor', 'symbol.resistor'],
  'symbol': ['symbol.resistor'],
};

String _search([Map<String, List<String>> terms = _searchTerms, int version = 1]) =>
    jsonEncode({'version': version, 'terms': terms});

// graph.idx lists every object as a node, outgoing edges only, ordered by
// (relationship_type, target, relationship_id).
Map<String, Object?> _graphMap() => {
  'version': 1,
  'nodes': {
    'component.lonely': <Object?>[],
    'component.resistor': [
      {'relationship_id': 'c.res.has_unit.ohm', 'relationship_type': 'HAS_UNIT', 'target': 'unit.ohm'},
      {
        'relationship_id': 'c.res.represented_by.sym',
        'relationship_type': 'REPRESENTED_BY',
        'target': 'symbol.resistor',
      },
    ],
    'symbol.resistor': <Object?>[],
    'unit.ohm': <Object?>[],
  },
};

ReferenceDiscoveryIndexes _indexes({String? search, String? graph}) =>
    ReferenceDiscoveryIndexes.parse(
      searchIdxJson: search ?? _search(),
      graphIdxJson: graph ?? jsonEncode(_graphMap()),
    );

ReferenceDiscovery _discovery() =>
    ReferenceDiscovery.create(_runtime(), _indexes());

Matcher _fails(KnowledgeRuntimeErrorCode code, [Pattern? message]) => throwsA(
  isA<KnowledgeRuntimeException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.message, 'message', message == null ? anything : contains(message)),
);

List<String> _ids(List<ReferenceSearchHit> hits) => hits.map((h) => h.objectId).toList();

void main() {
  group('Search', () {
    final d = _discovery();

    test('an exact known term returns its objects, and nothing else', () {
      expect(_ids(d.search('ohm')), ['unit.ohm']);
    });

    test('an alias/abbreviation token (compiled from classification) is found', () {
      expect(_ids(d.search('R')), ['component.resistor', 'symbol.resistor']);
    });

    test('a standards-reference token is found', () {
      expect(_ids(d.search('60115')), ['component.resistor']);
    });

    test('no match is a valid empty result, not an error', () {
      expect(d.search('nonexistent'), isEmpty);
    });

    test('an empty, blank or token-free query is a valid empty result', () {
      expect(d.search(''), isEmpty);
      expect(d.search('   \t '), isEmpty);
      expect(d.search('!!! --- ???'), isEmpty);
      expect(d.search('Ω'), isEmpty); // non-ASCII is dropped, as at compile time
    });

    test('normalization is the compiler tokenization only: case, punctuation, whitespace', () {
      expect(ReferenceDiscovery.normalizeQuery('  Fixed-RESISTOR, IEC 60115! '), [
        'fixed',
        'resistor',
        'iec',
        '60115',
      ]);
      expect(_ids(d.search('FIXED')), ['component.resistor']);
      expect(d.search('resistors'), isEmpty, reason: 'no stemming');
      expect(d.search('resist'), isEmpty, reason: 'no prefix/fuzzy matching');
    });

    test('multiple terms: objects matching more tokens rank first, ties by object id', () {
      final hits = d.search('symbol resistor');
      expect(_ids(hits), ['symbol.resistor', 'component.resistor']);
      expect(hits.first.matchedTerms, ['resistor', 'symbol']);
      expect(hits.first.score, 2);
      expect(hits.last.matchedTerms, ['resistor']);
    });

    test('an object matched by several tokens/postings appears exactly once', () {
      final hits = d.search('r resistor fixed r');
      expect(_ids(hits).where((i) => i == 'component.resistor'), hasLength(1));
      expect(hits.first.objectId, 'component.resistor');
      expect(hits.first.matchedTerms, ['fixed', 'r', 'resistor']);
    });

    test('requireAllTerms keeps only objects matching every token', () {
      expect(_ids(d.search('resistor fixed', requireAllTerms: true)), ['component.resistor']);
      expect(d.search('resistor ohm', requireAllTerms: true), isEmpty);
      expect(d.search('resistor nonexistent', requireAllTerms: true), isEmpty);
    });

    test('results are unmodifiable', () {
      expect(() => d.search('resistor').clear(), throwsUnsupportedError);
      expect(() => d.search('resistor').first.matchedTerms.add('x'), throwsUnsupportedError);
    });
  });

  group('Determinism', () {
    test('same package + same query gives identical ordered results, across instances', () {
      final a = _discovery();
      final b = _discovery();
      for (final q in ['resistor', 'symbol resistor', 'r fixed ohm', 'nothing']) {
        expect(a.search(q).map((h) => '${h.objectId}:${h.matchedTerms}').toList(),
            b.search(q).map((h) => '${h.objectId}:${h.matchedTerms}').toList());
      }
    });

    test('ordering does not depend on query word order or index posting order', () {
      final shuffled = {
        for (final e in _searchTerms.entries) e.key: e.value.reversed.toList(),
      };
      final reordered = ReferenceDiscovery.create(
        _runtime(),
        _indexes(search: _search(shuffled)),
      );
      final base = _discovery();
      expect(_ids(reordered.search('resistor symbol')), _ids(base.search('symbol resistor')));
      expect(_ids(reordered.search('r')), _ids(base.search('r')));
    });
  });

  group('Graph', () {
    final d = _discovery();

    test('a known object lists its outgoing edges in compiled order', () {
      final edges = d.outgoing('component.resistor');
      expect(edges.map((e) => e.relationshipId), ['c.res.has_unit.ohm', 'c.res.represented_by.sym']);
      expect(edges.first.sourceObjectId, 'component.resistor');
      expect(edges.first.targetObjectId, 'unit.ohm');
      expect(edges.first.relationshipType, 'HAS_UNIT');
    });

    test('an object with no outgoing relationships returns an empty list', () {
      expect(d.outgoing('component.lonely'), isEmpty);
      expect(d.outgoing('unit.ohm'), isEmpty);
    });

    test('an unknown object is referenceNotFound', () {
      expect(() => d.outgoing('component.ghost'), _fails(KnowledgeRuntimeErrorCode.referenceNotFound));
      expect(() => d.relatedObjectIds('component.ghost'), _fails(KnowledgeRuntimeErrorCode.referenceNotFound));
    });

    test('related object ids are distinct, sorted targets', () {
      expect(d.relatedObjectIds('component.resistor'), ['symbol.resistor', 'unit.ohm']);
      expect(d.relatedObjectIds('unit.ohm'), isEmpty);
    });

    test('edge relationship ids resolve authoritatively through KnowledgeRuntime', () {
      final runtime = _runtime();
      final discovery = ReferenceDiscovery.create(runtime, _indexes());
      for (final edge in discovery.outgoing('component.resistor')) {
        final authoritative = runtime.getRelationship(edge.relationshipId);
        expect(authoritative.sourceObjectId, edge.sourceObjectId);
        expect(authoritative.targetObjectId, edge.targetObjectId);
        expect(authoritative.relationshipType, edge.relationshipType);
      }
    });
  });

  group('Authority', () {
    test('every search hit resolves in KnowledgeRuntime.getObject', () {
      final runtime = _runtime();
      final d = ReferenceDiscovery.create(runtime, _indexes());
      for (final q in ['resistor', 'r', 'ohm', 'symbol', '60115']) {
        for (final hit in d.search(q)) {
          expect(runtime.getObject(hit.objectId).id, hit.objectId);
        }
      }
    });

    test('a hit carries only identifiers, not the authoritative object', () {
      // The type has no name/uuid/properties: authoritative data comes only
      // from the runtime.
      final hit = _discovery().search('ohm').single;
      expect(hit.objectId, 'unit.ohm');
      expect(hit.matchedTerms, ['ohm']);
    });

    test('an index naming an object the runtime lacks is rejected at binding', () {
      final terms = {..._searchTerms, 'ghost': ['component.ghost']};
      expect(
        () => ReferenceDiscovery.create(_runtime(), _indexes(search: _search(terms))),
        _fails(KnowledgeRuntimeErrorCode.packageInvalid, 'component.ghost'),
      );
    });

    test('a graph node for an unknown object is rejected', () {
      final g = _graphMap();
      (g['nodes'] as Map)['component.ghost'] = <Object?>[];
      expect(
        () => ReferenceDiscovery.create(_runtime(), _indexes(graph: jsonEncode(g))),
        _fails(KnowledgeRuntimeErrorCode.packageInvalid, 'component.ghost'),
      );
    });

    test('an edge that is not a runtime relationship, or disagrees with it, is rejected', () {
      final unknownEdge = _graphMap();
      ((unknownEdge['nodes'] as Map)['unit.ohm'] as List).add(
        {'relationship_id': 'ghost.rel', 'relationship_type': 'HAS_UNIT', 'target': 'unit.ohm'},
      );
      expect(
        () => ReferenceDiscovery.create(_runtime(), _indexes(graph: jsonEncode(unknownEdge))),
        _fails(KnowledgeRuntimeErrorCode.packageInvalid, 'ghost.rel'),
      );

      final wrongTarget = _graphMap();
      (((wrongTarget['nodes'] as Map)['component.resistor'] as List).first as Map)['target'] = 'symbol.resistor';
      expect(
        () => ReferenceDiscovery.create(_runtime(), _indexes(graph: jsonEncode(wrongTarget))),
        _fails(KnowledgeRuntimeErrorCode.packageInvalid, 'disagrees'),
      );
    });

    test('a runtime relationship missing from graph.idx is rejected', () {
      final g = _graphMap();
      ((g['nodes'] as Map)['component.resistor'] as List).removeLast();
      expect(
        () => ReferenceDiscovery.create(_runtime(), _indexes(graph: jsonEncode(g))),
        _fails(KnowledgeRuntimeErrorCode.packageInvalid, 'edges'),
      );
    });
  });

  group('Index integrity', () {
    ReferenceDiscoveryIndexes parseSearch(String s) =>
        ReferenceDiscoveryIndexes.parse(searchIdxJson: s, graphIdxJson: jsonEncode(_graphMap()));
    ReferenceDiscoveryIndexes parseGraph(String g) =>
        ReferenceDiscoveryIndexes.parse(searchIdxJson: _search(), graphIdxJson: g);

    test('malformed search.idx is rejected, never read as empty', () {
      for (final bad in [
        'not json',
        '[]',
        '{"version": 1}',
        '{"version": 1, "terms": []}',
        '{"version": 1, "terms": {"a": "x"}}',
        '{"version": 1, "terms": {"a": []}}',
        '{"version": 1, "terms": {"a": [""]}}',
        '{"version": 1, "terms": {"Resistor": ["x"]}}',
        '{"version": 1, "terms": {"two words": ["x"]}}',
        '{"terms": {}}',
        '{"version": "1", "terms": {}}',
      ]) {
        expect(() => parseSearch(bad), _fails(KnowledgeRuntimeErrorCode.packageInvalid, 'search.idx'), reason: bad);
      }
    });

    test('malformed graph.idx is rejected, never read as empty', () {
      for (final bad in [
        'not json',
        '{"version": 1}',
        '{"version": 1, "nodes": []}',
        '{"version": 1, "nodes": {"a": {}}}',
        '{"version": 1, "nodes": {"a": [1]}}',
        '{"version": 1, "nodes": {"a": [{"relationship_id": "r", "relationship_type": "T"}]}}',
        '{"version": 1, "nodes": {"a": [{"relationship_id": "r", "relationship_type": "T", "target": "b"}], "b": [{"relationship_id": "r", "relationship_type": "T", "target": "a"}]}}',
      ]) {
        expect(() => parseGraph(bad), _fails(KnowledgeRuntimeErrorCode.packageInvalid, 'graph.idx'), reason: bad);
      }
    });

    test('an unsupported index version is schemaUnsupported', () {
      expect(() => parseSearch(_search(_searchTerms, 2)), _fails(KnowledgeRuntimeErrorCode.schemaUnsupported, 'search.idx'));
      expect(
        () => parseGraph('{"version": 2, "nodes": {}}'),
        _fails(KnowledgeRuntimeErrorCode.schemaUnsupported, 'graph.idx'),
      );
    });

    test('a valid but empty index is valid (a package with no indexed terms)', () {
      final d = ReferenceDiscovery.create(
        _runtime(objects: const [], relationships: const []),
        ReferenceDiscoveryIndexes.parse(
          searchIdxJson: '{"version": 1, "terms": {}}',
          graphIdxJson: '{"version": 1, "nodes": {}}',
        ),
      );
      expect(d.search('anything'), isEmpty);
      expect(d.capabilities.indexedTermCount, 0);
    });
  });

  group('OerpReader.readDiscoveryIndexes', () {
    test('reads both indexes from the package archive', () {
      final bytes = buildStoredZip({
        'search.idx': utf8.encode(_search()),
        'graph.idx': utf8.encode(jsonEncode(_graphMap())),
      });
      final indexes = const OerpReader().readDiscoveryIndexes(bytes);
      expect(ReferenceDiscovery.create(_runtime(), indexes).search('ohm').single.objectId, 'unit.ohm');
    });

    test('a missing index member is packageInvalid, not an empty index', () {
      for (final missing in ['search.idx', 'graph.idx']) {
        final entries = <String, List<int>>{
          'search.idx': utf8.encode(_search()),
          'graph.idx': utf8.encode(jsonEncode(_graphMap())),
        }..remove(missing);
        expect(
          () => const OerpReader().readDiscoveryIndexes(buildStoredZip(entries)),
          _fails(KnowledgeRuntimeErrorCode.packageInvalid, missing),
        );
      }
    });

    test('non-archive bytes are packageInvalid', () {
      expect(
        () => const OerpReader().readDiscoveryIndexes(Uint8List.fromList([1, 2, 3, 4])),
        _fails(KnowledgeRuntimeErrorCode.packageInvalid),
      );
    });
  });

  group('Capabilities', () {
    test('describe discovery separately from the runtime and reflect the indexes', () {
      final c = _discovery().capabilities;
      expect(c.termSearch, isTrue);
      expect(c.relationshipTraversal, isTrue);
      expect(c.searchIndexVersion, 1);
      expect(c.graphIndexVersion, 1);
      expect(c.indexedTermCount, _searchTerms.length);
      expect(c.indexedObjectCount, 3); // component.resistor, symbol.resistor, unit.ohm
      expect(c.graphEdgeCount, 2);
    });
  });

  group('Boundaries', () {
    test('no mapping between a Reference symbol id and an Engine symbol identifier is made', () {
      // "resistor" is a token in the index; it returns the Reference objects
      // whose *index entries* contain it, never a SymbolDefinition.
      final ids = _ids(_discovery().search('resistor'));
      expect(ids, contains('symbol.resistor'));
      expect(ids, isNot(contains('resistor')));
    });
  });
}
