import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart'
    show
        KnowledgeObject,
        KnowledgePackage,
        KnowledgeRelationship,
        KnowledgeRuntime,
        OerpReader,
        ReferenceDiscovery,
        ReferenceDiscoveryIndexes,
        SymbolBinding,
        SymbolBindingAdapter,
        SymbolBindingRegistry,
        SymbolLibrary,
        buildElectricalCorePackage;
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/interpretation/reference_context.dart';
import 'package:oep_studio/knowledge/interpretation/reference_context_builder.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation_status.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';

/// WP-EKE-017. Layer 1 uses an in-memory Reference package whose index JSON is
/// in the Reference Compiler's exact format; layer 2 ("Real compiled package")
/// uses the REAL `.oerp` staged by `tool/generate_knowledge_asset.dart`.
const _engineSymbols = '../oep_engine/assets/symbols';
const _bindingFile =
    '../oep_engine/assets/symbol_bindings/reference_symbol_bindings.json';

KnowledgeObject _obj(String id, String type, {List<String> tags = const []}) =>
    KnowledgeObject(
      id: id,
      objectType: type,
      name: id,
      shortName: id,
      version: '1.0.0',
      lifecycleState: 'Published',
      uuid: 'u-$id',
      domain: 'Electrical',
      tags: tags,
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
  _obj('component.passive.resistor', 'Component'),
  _obj('symbol.iec.resistor', 'Symbol'),
  _obj('symbol.iec.battery',
      'Symbol'), // no binding, although Engine has "battery"
  _obj('unit.ohm', 'Unit'),
];
final _relationships = [
  _rel('component.passive.resistor.has_unit.ohm', 'HAS_UNIT',
      'component.passive.resistor', 'unit.ohm'),
  _rel('component.passive.resistor.represented_by.symbol_iec', 'REPRESENTED_BY',
      'component.passive.resistor', 'symbol.iec.resistor'),
];

KnowledgeRuntime _runtime() {
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
      objects: _objects,
      relationships: _relationships,
      developmentModeUnsigned: true,
    ),
    allowUnsignedDevelopmentPackages: true,
  );
}

const _searchIdx = {
  'version': 1,
  'terms': {
    'resistor': ['component.passive.resistor', 'symbol.iec.resistor'],
    'iec': ['symbol.iec.battery', 'symbol.iec.resistor'],
    'battery': ['symbol.iec.battery'],
    'fixed': ['component.passive.resistor'],
    'ohm': ['unit.ohm'],
  },
};
Map<String, Object?> _graphIdx() => {
      'version': 1,
      'nodes': {
        'component.passive.resistor': [
          {
            'relationship_id': 'component.passive.resistor.has_unit.ohm',
            'relationship_type': 'HAS_UNIT',
            'target': 'unit.ohm'
          },
          {
            'relationship_id':
                'component.passive.resistor.represented_by.symbol_iec',
            'relationship_type': 'REPRESENTED_BY',
            'target': 'symbol.iec.resistor',
          },
        ],
        'symbol.iec.resistor': <Object?>[],
        'symbol.iec.battery': <Object?>[],
        'unit.ohm': <Object?>[],
      },
    };

Future<ReferenceKnowledgeSources> _sources({bool withBinding = true}) async {
  final runtime = _runtime();
  final symbols = SymbolLibrary(symbolsDirectory: _engineSymbols);
  await symbols.initialize();
  return ReferenceKnowledgeSources(
    runtime: runtime,
    discovery: ReferenceDiscovery.create(
      runtime,
      ReferenceDiscoveryIndexes.parse(
        searchIdxJson: jsonEncode(_searchIdx),
        graphIdxJson: jsonEncode(_graphIdx()),
      ),
    ),
    symbolBinding: withBinding
        ? SymbolBindingAdapter(
            runtime: runtime,
            symbols: symbols,
            bindings: SymbolBindingRegistry.loadFile(File(_bindingFile)),
          )
        : null,
  );
}

// ---- evidence fixture: a small TRX300-like page ---------------------------
final _source = SourceMaterial(
  id: 'src-trx300',
  originalFileName: 'trx300_original_pdf_diagram.pdf',
  localPath: 'C:/x/trx300.pdf',
  type: SourceMaterialType.pdf,
  sizeBytes: 185420,
  importDate: DateTime.utc(2026, 9, 19),
  addedBy: 'uif',
);

OcrWord _word(String text, double conf, double x, double y, int order) =>
    OcrWord(
      text: text,
      confidence: conf,
      boundingBox: OcrBoundingBox(x: x, y: y, width: 0.03, height: 0.01),
      readingOrder: order,
      lineIndex: order,
    );

OcrPageResult _ocr(
        {int page = 1,
        String source = 'src-trx300',
        String fingerprint = 'fp-abc'}) =>
    OcrPageResult(
      sourceId: source,
      page: page,
      words: [
        _word('R1', 0.93, 0.61, 0.83, 0),
        _word('resistor', 0.88, 0.62, 0.83, 1),
        _word('10', 0.71, 0.63, 0.84, 2)
      ],
      imageWidth: 3300,
      imageHeight: 2550,
      sourceFingerprint: fingerprint,
      engineVersion: 'Tesseract v5.4',
      processedTime: DateTime.utc(2026, 9, 19, 10),
      success: true,
    );

EvidenceRegion _region(String id,
        {int page = 1,
        double y = 0.8,
        double x = 0.6,
        bool human = true,
        String source = 'src-trx300'}) =>
    EvidenceRegion(
      id: id,
      sourceId: source,
      page: page,
      x: x,
      y: y,
      width: 0.06,
      height: 0.07,
      label: human ? 'Component: R1' : 'Machine region',
      notes: human ? 'looks like the fuel pump resistor' : '',
      createdTime: DateTime.utc(2026, 9, 19, 10, 5),
      origin: human ? EvidenceOrigin.human : EvidenceOrigin.machine,
      annotatorId: human ? 'david' : null,
      status: human ? EvidenceAnnotationStatus.unverified : null,
      observationRef: human ? 'ocr-word-R1' : null,
    );

EvidenceLink _link(String id, String cand, String region) => EvidenceLink(
    id: id,
    candidateId: cand,
    regionId: region,
    createdTime: DateTime.utc(2026, 9, 19, 10, 6));

KnowledgeCandidate _candidate(String id) => KnowledgeCandidate(
      id: id,
      type: KnowledgeCandidateType.component,
      name: 'R1',
      author: 'david',
      createdTime: DateTime.utc(2026, 9, 19, 10, 6),
    );

DiagramEvidenceInput _evidence(
        {int? page, List<EvidenceRegion>? regions, List<OcrPageResult>? ocr}) =>
    DiagramEvidenceInput(
      source: _source,
      page: page,
      ocrPages: ocr ?? [_ocr()],
      evidenceRegions: regions ??
          [
            _region('reg-b'),
            _region('reg-a', y: 0.3),
            _region('reg-m', human: false, y: 0.5)
          ],
      evidenceLinks: [_link('lnk-1', 'cand-1', 'reg-b')],
      candidates: [_candidate('cand-1'), _candidate('cand-unlinked')],
    );

ReferenceContextQuery _q(String text, ReferenceRetrievalPurpose purpose,
        {List<String> types = const [],
        List<String> relTypes = const [],
        int max = 10,
        bool all = false,
        List<String> regions = const []}) =>
    ReferenceContextQuery(
      purpose: purpose,
      query: text,
      objectTypes: types,
      relationshipTypes: relTypes,
      maxResults: max,
      requireAllTerms: all,
      evidenceRegionIds: regions,
    );

String _json(DiagramInterpretationReferenceContext c) => jsonEncode(c.toJson());

void main() {
  late ReferenceKnowledgeSources sources;
  late DiagramInterpretationReferenceContextBuilder builder;

  setUp(() async {
    sources = await _sources();
    builder = DiagramInterpretationReferenceContextBuilder(reference: sources);
  });

  group('Evidence-only context (A, T)', () {
    test(
        'A: builds with no Reference stack at all, preserving all source evidence',
        () {
      final ctx = const DiagramInterpretationReferenceContextBuilder()
          .build(ReferenceContextRequest(evidence: _evidence()));
      expect(ctx.items, isEmpty);
      expect(ctx.relationships, isEmpty);
      expect(ctx.reference, isNull);
      expect(ctx.hasReferenceKnowledge, isFalse);
      expect(ctx.source!.id, 'src-trx300');
      expect(ctx.ocrPages.single.words.map((w) => w.text),
          ['R1', 'resistor', '10']);
      expect(ctx.evidenceRegions, hasLength(3));
    });

    test(
        'T: with a Reference stack but no queries, or a query with no hits, evidence-only context is valid',
        () {
      final none =
          builder.build(ReferenceContextRequest(evidence: _evidence()));
      expect(none.items, isEmpty);
      expect(none.reference!.packageId, isNotEmpty);
      final miss = builder.build(ReferenceContextRequest(
        evidence: _evidence(),
        queries: [_q('nonexistentterm', ReferenceRetrievalPurpose.terminology)],
      ));
      expect(miss.items, isEmpty);
      expect(miss.queryOutcomes.single.totalMatches, 0);
      expect(miss.queryOutcomes.single.truncated, isFalse);
      expect(miss.ocrPages, isNotEmpty);
    });

    test(
        'queries without a Reference stack fail explicitly, never silently empty',
        () {
      expect(
        () => const DiagramInterpretationReferenceContextBuilder().build(
          ReferenceContextRequest(
              queries: [_q('resistor', ReferenceRetrievalPurpose.terminology)]),
        ),
        throwsA(isA<ReferenceContextException>().having((e) => e.code, 'code',
            ReferenceContextErrorCode.referenceKnowledgeUnavailable)),
      );
    });

    test('a Reference-only context needs no source evidence', () {
      final ctx = builder.build(ReferenceContextRequest(
          queries: [_q('ohm', ReferenceRetrievalPurpose.terminology)]));
      expect(ctx.source, isNull);
      expect(ctx.items.single.referenceObjectId, 'unit.ohm');
    });
  });

  group('Reference retrieval (B, C, D, P)', () {
    test(
        'B/C/D: ids come through ReferenceDiscovery and objects are the KnowledgeRuntime\'s own',
        () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification)
        ],
      ));
      final ids = ctx.items.map((i) => i.referenceObjectId).toList();
      expect(ids, ['component.passive.resistor', 'symbol.iec.resistor']);
      expect(ids,
          sources.discovery.search('resistor').map((h) => h.objectId).toList());
      for (final item in ctx.items) {
        expect(
            identical(
                item.object, sources.runtime.getObject(item.referenceObjectId)),
            isTrue);
      }
    });

    test('P: every item carries a non-empty purpose and a structured rationale',
        () {
      final ctx = builder.build(ReferenceContextRequest(queries: [
        _q('iec resistor', ReferenceRetrievalPurpose.symbolIdentification,
            regions: ['reg-b']),
        _q('ohm', ReferenceRetrievalPurpose.standardReference),
      ]));
      for (final item in ctx.items) {
        expect(item.purpose.wireName, isNotEmpty);
        expect(item.retrieval.matchedTerms, isNotEmpty);
        expect(item.retrieval.normalizedTerms, isNotEmpty);
        expect(item.retrieval.rationale, contains(item.retrieval.queryText));
        expect(item.retrieval.rank, greaterThanOrEqualTo(1));
      }
      final top = ctx.items.first;
      expect(top.referenceObjectId, 'symbol.iec.resistor');
      expect(top.retrieval.score, 2);
      expect(top.retrieval.matchedTerms, ['iec', 'resistor']);
      expect(top.retrieval.evidenceRegionIds, ['reg-b']);
      expect(top.purpose, ReferenceRetrievalPurpose.symbolIdentification);
    });

    test('all seven retrieval purposes exist with stable wire names', () {
      expect(ReferenceRetrievalPurpose.values.map((p) => p.wireName), [
        'symbol_identification',
        'component_classification',
        'terminal_interpretation',
        'relationship_interpretation',
        'property_interpretation',
        'terminology',
        'standard_reference',
      ]);
    });

    test(
        'U: an object-type filter excludes other types (Symbol only), it does not fail or substitute',
        () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'])
        ],
      ));
      expect(ctx.items.map((i) => i.objectType).toSet(), {'Symbol'});
      expect(ctx.queryOutcomes.single.totalMatches, 1);
    });

    test('a component filter works too (not resistor/symbol specific)', () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.componentClassification,
              types: ['Component'])
        ],
      ));
      expect(ctx.items.single.referenceObjectId, 'component.passive.resistor');
    });

    test('maxResults truncates deterministically and the outcome says so', () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.terminology, max: 1)
        ],
      ));
      expect(ctx.items, hasLength(1));
      expect(ctx.queryOutcomes.single.totalMatches, 2);
      expect(ctx.queryOutcomes.single.truncated, isTrue);
    });

    test('invalid requests fail explicitly (empty query, out-of-range limit)',
        () {
      expect(() => _q('   ', ReferenceRetrievalPurpose.terminology),
          throwsA(isA<ReferenceContextException>()));
      expect(() => _q('x', ReferenceRetrievalPurpose.terminology, max: 0),
          throwsA(isA<ReferenceContextException>()));
      expect(
          () => _q('x', ReferenceRetrievalPurpose.terminology,
              max: ReferenceContextQuery.maxAllowedResults + 1),
          throwsA(isA<ReferenceContextException>()));
    });

    test(
        'items carry the package/runtime identity exactly as KnowledgeRuntime reports it',
        () {
      final ctx = builder.build(ReferenceContextRequest(
          queries: [_q('ohm', ReferenceRetrievalPurpose.terminology)]));
      final id = sources.runtime.identity;
      final ident = ctx.items.single.identity;
      expect((ident.packageId, ident.packageVersion, ident.contentHash),
          (id.packageId, id.packageVersion, id.contentHash));
      expect((ident.runtimeVersion, ident.runtimeBuild),
          (id.runtimeVersion, id.runtimeBuild));
      expect(ctx.reference!.contentHash, id.contentHash);
    });
  });

  group('Reference relationships (E)', () {
    test(
        'E: REPRESENTED_BY is included as the runtime\'s own Reference relationship, unconverted',
        () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.relationshipInterpretation,
              relTypes: ['REPRESENTED_BY'])
        ],
      ));
      final rel = ctx.relationships.single;
      expect(rel.relationship.relationshipType, 'REPRESENTED_BY');
      expect(rel.relationship.sourceObjectId, 'component.passive.resistor');
      expect(rel.relationship.targetObjectId, 'symbol.iec.resistor');
      expect(
          identical(rel.relationship,
              sources.runtime.getRelationship(rel.relationship.id)),
          isTrue);
      expect(rel.purposes, ['relationship_interpretation']);
      expect(rel.retrievedObjectIds,
          ['component.passive.resistor', 'symbol.iec.resistor']);
    });

    test(
        'a symbol-only retrieval still surfaces the incoming REPRESENTED_BY relationship',
        () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'])
        ],
      ));
      expect(ctx.relationships.map((r) => r.relationship.relationshipType),
          ['REPRESENTED_BY']);
    });

    test(
        'relationships are de-duplicated by id and ordered by id; none is invented',
        () {
      final ctx = builder.build(ReferenceContextRequest(queries: [
        _q('resistor', ReferenceRetrievalPurpose.symbolIdentification),
        _q('fixed', ReferenceRetrievalPurpose.componentClassification),
      ]));
      final ids = ctx.relationships.map((r) => r.relationship.id).toList();
      expect(ids, [...ids]..sort());
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.toSet(), {for (final r in _relationships) r.id});
      expect(ctx.relationships.first.purposes,
          ['component_classification', 'symbol_identification']);
    });

    test('an object with no relationships contributes none', () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('battery', ReferenceRetrievalPurpose.symbolIdentification)
        ],
      ));
      expect(ctx.relationships, isEmpty);
    });
  });

  group('Symbol Binding (F, G, H, I)', () {
    test('F/H: a bound Reference Symbol keeps BOTH identities as different ids',
        () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('iec resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'], all: true)
        ],
      ));
      final b = ctx.items.single.symbolBinding!;
      expect(b.status, SymbolBindingStatus.bound);
      expect(b.referenceSymbolId, 'symbol.iec.resistor');
      expect(b.engineSymbolId, 'resistor');
      expect(ctx.items.single.referenceObjectId,
          'symbol.iec.resistor'); // Reference id is not replaced
    });

    test(
        'G: a valid Reference Symbol with no binding stays valid and is explicitly unbound (nothing inferred)',
        () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('battery', ReferenceRetrievalPurpose.symbolIdentification)
        ],
      ));
      final item = ctx.items.single;
      expect(item.referenceObjectId, 'symbol.iec.battery');
      expect(item.symbolBinding!.status, SymbolBindingStatus.absent);
      expect(item.symbolBinding!.engineSymbolId, isNull,
          reason: 'Engine has "battery" but no binding exists');
      expect(item.symbolBinding!.errorCode, 'bindingMissing');
    });

    test('non-Symbol items carry no binding view', () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('fixed', ReferenceRetrievalPurpose.componentClassification)
        ],
      ));
      expect(ctx.items.single.symbolBinding, isNull);
    });

    test('without a SymbolBindingAdapter the view is notEvaluated, not guessed',
        () async {
      final noBinding = await _sources(withBinding: false);
      final ctx =
          DiagramInterpretationReferenceContextBuilder(reference: noBinding)
              .build(ReferenceContextRequest(
        queries: [
          _q('iec resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'], all: true)
        ],
      ));
      expect(ctx.items.single.symbolBinding!.status,
          SymbolBindingStatus.notEvaluated);
      expect(ctx.items.single.symbolBinding!.engineSymbolId, isNull);
    });

    test('a broken binding is reported as invalid with its code', () async {
      final runtime = sources.runtime;
      final symbols = SymbolLibrary(symbolsDirectory: _engineSymbols);
      await symbols.initialize();
      final broken = ReferenceKnowledgeSources(
        runtime: runtime,
        discovery: sources.discovery,
        symbolBinding: SymbolBindingAdapter(
          runtime: runtime,
          symbols: symbols,
          bindings: SymbolBindingRegistry([
            const SymbolBinding(
                referenceSymbolId: 'symbol.iec.resistor',
                engineSymbolId: 'no_such_engine_symbol'),
          ]),
        ),
      );
      final ctx =
          DiagramInterpretationReferenceContextBuilder(reference: broken)
              .build(ReferenceContextRequest(
        queries: [
          _q('iec resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'], all: true)
        ],
      ));
      expect(
          ctx.items.single.symbolBinding!.status, SymbolBindingStatus.invalid);
      expect(ctx.items.single.symbolBinding!.errorCode, 'engineSymbolNotFound');
    });

    test(
        'I: no visual equivalence is asserted; the binding\'s own caveat is carried verbatim',
        () {
      final ctx = builder.build(ReferenceContextRequest(
        queries: [
          _q('iec resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'], all: true)
        ],
      ));
      final b = ctx.items.single.symbolBinding!;
      expect(b.notes, contains('zigzag'));
      expect(b.notes, contains('does not make the rendered glyph match'));
      final text = _json(ctx).toLowerCase();
      expect(text, isNot(contains('equivalent')));
      expect(text, isNot(contains('visually match')));
    });
  });

  group('Observations (J, K, L, O)', () {
    test(
        'J: human annotations stay human observations with annotator, status and structured properties',
        () {
      final ctx = builder.build(ReferenceContextRequest(evidence: _evidence()));
      final human = ctx.humanObservations.map((r) => r.id).toSet();
      expect(human, {'reg-a', 'reg-b'});
      final r = ctx.evidenceRegions.firstWhere((r) => r.id == 'reg-b');
      expect(r.origin, EvidenceOrigin.human);
      expect(r.annotatorId, 'david');
      expect(r.status, EvidenceAnnotationStatus.unverified);
      expect(r.label, 'Component: R1');
      expect(r.notes, 'looks like the fuel pump resistor');
      expect(r.observationRef, 'ocr-word-R1');
      // Whatever structured annotation a region carries (WP-INGEST-013) is part
      // of its own serialization, which the context passes through unchanged.
      expect(jsonEncode(ctx.toJson()['evidenceRegions']),
          contains(jsonEncode(r.toJson())));
      expect(ctx.evidenceRegions.firstWhere((r) => r.id == 'reg-m').origin,
          EvidenceOrigin.machine);
    });

    test(
        'K: OCR keeps text, page, bounding box, confidence, reading order and engine provenance',
        () {
      final ctx = builder.build(ReferenceContextRequest(evidence: _evidence()));
      final page = ctx.ocrPages.single;
      final w = page.words.first;
      expect((page.page, page.imageWidth, page.engineVersion),
          (1, 3300, 'Tesseract v5.4'));
      expect((w.text, w.confidence, w.readingOrder), ('R1', 0.93, 0));
      expect((w.boundingBox.x, w.boundingBox.y), (0.61, 0.83));
    });

    test(
        'L: a KnowledgeCandidate stays a pending candidate (no Engineering Object, not committed)',
        () {
      final ctx = builder.build(ReferenceContextRequest(evidence: _evidence()));
      final c = ctx.candidates.single;
      expect(c.id, 'cand-1',
          reason: 'only candidates linked to included regions');
      expect(c.status, KnowledgeCandidateStatus.pending);
      expect(c.committedObjectId, isNull);
      expect(ctx.evidenceLinks.single.candidateId, 'cand-1');
    });

    test(
        'O: source identity is the existing OCR sourceFingerprint plus source id and page',
        () {
      final ctx =
          builder.build(ReferenceContextRequest(evidence: _evidence(page: 1)));
      expect(ctx.source!.id, 'src-trx300');
      expect(ctx.sourceFingerprint, 'fp-abc');
      expect(ctx.page, 1);
      expect(ctx.ocrPages.single.page, 1);
    });

    test('conflicting source fingerprints are an explicit error', () {
      expect(
        () => builder.build(ReferenceContextRequest(
          evidence: _evidence(
              ocr: [_ocr(page: 1), _ocr(page: 2, fingerprint: 'fp-other')]),
        )),
        throwsA(isA<ReferenceContextException>().having((e) => e.code, 'code',
            ReferenceContextErrorCode.inconsistentSourceIdentity)),
      );
    });

    test('evidence for another source or another page is excluded', () {
      final ctx = builder.build(ReferenceContextRequest(
        evidence: _evidence(
          page: 1,
          ocr: [_ocr(page: 1), _ocr(page: 2), _ocr(source: 'other')],
          regions: [
            _region('r1'),
            _region('r2', page: 2),
            _region('r3', source: 'other')
          ],
        ),
      ));
      expect(ctx.ocrPages.map((p) => p.page), [1]);
      expect(ctx.evidenceRegions.map((r) => r.id), ['r1']);
    });
  });

  group('Determinism and ordering (M, N)', () {
    DiagramInterpretationReferenceContext build(List<EvidenceRegion> regions,
            List<OcrPageResult> ocr, List<ReferenceContextQuery> queries) =>
        builder.build(ReferenceContextRequest(
            evidence: _evidence(regions: regions, ocr: ocr), queries: queries));

    final queries = [
      _q('iec resistor', ReferenceRetrievalPurpose.symbolIdentification),
      _q('fixed', ReferenceRetrievalPurpose.componentClassification),
    ];

    test(
        'M: identical inputs produce identical serialized contexts, across separate builders',
        () async {
      final again = DiagramInterpretationReferenceContextBuilder(
          reference: await _sources());
      final a = build(
          [_region('reg-b'), _region('reg-a', y: 0.3)], [_ocr()], queries);
      final b = again.build(ReferenceContextRequest(
        evidence: _evidence(
            regions: [_region('reg-b'), _region('reg-a', y: 0.3)],
            ocr: [_ocr()]),
        queries: queries,
      ));
      expect(_json(a), _json(b));
    });

    test(
        'N: evidence order does not depend on input order; regions by (page, y, x, id), pages ascending',
        () {
      final regions = [
        _region('c', page: 2, y: 0.1),
        _region('b', y: 0.9),
        _region('a', y: 0.9, x: 0.1),
        _region('z', y: 0.2)
      ];
      final forward = build(regions, [_ocr(page: 2), _ocr(page: 1)], queries);
      final reversed = build(
          regions.reversed.toList(), [_ocr(page: 1), _ocr(page: 2)], queries);
      expect(_json(forward), _json(reversed));
      expect(forward.evidenceRegions.map((r) => r.id), ['z', 'a', 'b', 'c']);
      expect(forward.ocrPages.map((p) => p.page), [1, 2]);
    });

    test(
        'N: Reference items follow query order then rank; relationships are sorted by id',
        () {
      final ctx = build([_region('reg-b')], [_ocr()], queries);
      expect(
          ctx.items
              .map((i) => '${i.retrieval.queryIndex}:${i.referenceObjectId}'),
          [
            '0:symbol.iec.resistor',
            '0:component.passive.resistor',
            '0:symbol.iec.battery',
            '1:component.passive.resistor',
          ]);
      final ids = ctx.relationships.map((r) => r.relationship.id).toList();
      expect(ids, [...ids]..sort());
    });

    test(
        'a different Reference package identity produces a context with that identity',
        () async {
      final ctx = builder.build(ReferenceContextRequest(
          queries: [_q('ohm', ReferenceRetrievalPurpose.terminology)]));
      expect(ctx.reference!.contentHash, sources.runtime.identity.contentHash);
    });
  });

  group('Boundaries (Q, R, S, immutability)', () {
    test('Q: nothing that looks like an interpretation is produced', () {
      final ctx = builder.build(ReferenceContextRequest(
        evidence: _evidence(),
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification)
        ],
      ));
      final keys = <String>{};
      void walk(Object? v) {
        if (v is Map) {
          for (final e in v.entries) {
            keys.add(e.key as String);
            walk(e.value);
          }
        } else if (v is List) {
          v.forEach(walk);
        }
      }

      walk(ctx.toJson());
      for (final banned in [
        'interpretation',
        'verdict',
        'conclusion',
        'inferred',
        'classification_result',
        'model'
      ]) {
        expect(keys.where((k) => k.toLowerCase().contains(banned)), isEmpty,
            reason: banned);
      }
      expect(ctx.toJson()['snapshotNotice'], contains('not an interpretation'));
    });

    test(
        'R/S: building changes neither the evidence inputs nor the Reference Knowledge',
        () {
      final evidence = _evidence();
      String snap() => jsonEncode({
            'ocr': [for (final p in evidence.ocrPages) p.toJson()],
            'regions': [for (final r in evidence.evidenceRegions) r.toJson()],
            'links': [for (final l in evidence.evidenceLinks) l.toJson()],
            'candidates': [for (final c in evidence.candidates) c.toJson()],
            'package': sources.runtime.package.toJson(),
            'capabilities': sources.runtime.capabilities.registryCounts,
          });
      final before = snap();
      builder.build(ReferenceContextRequest(
        evidence: evidence,
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification)
        ],
      ));
      expect(snap(), before);
      expect(
          evidence.candidates.every((c) =>
              c.status == KnowledgeCandidateStatus.pending &&
              c.committedObjectId == null),
          isTrue);
    });

    test('the context is an immutable snapshot', () {
      final ctx = builder.build(ReferenceContextRequest(
        evidence: _evidence(),
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification)
        ],
      ));
      expect(() => ctx.items.clear(), throwsUnsupportedError);
      expect(() => ctx.evidenceRegions.clear(), throwsUnsupportedError);
      expect(() => ctx.relationships.clear(), throwsUnsupportedError);
      expect(() => ctx.items.first.retrieval.matchedTerms.add('x'),
          throwsUnsupportedError);
    });
  });

  group('Real compiled package (TRX300-like end to end)', () {
    late ReferenceKnowledgeSources real;

    setUp(() async {
      final oerp = File('assets/knowledge/core_reference_v1.oerp');
      expect(oerp.existsSync(), isTrue,
          reason:
              'run `dart run tool/generate_knowledge_asset.dart` first (compiles the real Reference Library)');
      const reader = OerpReader();
      final runtime = KnowledgeRuntime.activate(reader.readFile(oerp),
          allowUnsignedDevelopmentPackages: true);
      final symbols = SymbolLibrary(symbolsDirectory: _engineSymbols);
      await symbols.initialize();
      real = ReferenceKnowledgeSources(
        runtime: runtime,
        discovery: ReferenceDiscovery.create(
            runtime, reader.readDiscoveryIndexesFile(oerp)),
        symbolBinding: SymbolBindingAdapter(
          runtime: runtime,
          symbols: symbols,
          bindings: SymbolBindingRegistry.loadFile(File(_bindingFile)),
        ),
      );
    });

    test(
        'OCR "resistor" + a human annotation retrieve the real Reference symbol, its relationship and binding',
        () {
      final real1 =
          DiagramInterpretationReferenceContextBuilder(reference: real)
              .build(ReferenceContextRequest(
        evidence: _evidence(),
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'], regions: ['reg-b']),
          _q('resistor', ReferenceRetrievalPurpose.componentClassification,
              types: ['Component'], regions: ['reg-b']),
        ],
      ));
      // Reference Knowledge, straight from the runtime.
      expect(real1.items.map((i) => i.referenceObjectId),
          ['symbol.iec.resistor', 'component.passive.resistor']);
      expect(real1.reference!.packageId, 'core_reference');
      final rel = real1.relationships.singleWhere(
          (r) => r.relationship.relationshipType == 'REPRESENTED_BY');
      expect(rel.relationship.sourceObjectId, 'component.passive.resistor');
      expect(rel.relationship.targetObjectId, 'symbol.iec.resistor');
      // Binding: both identities, and the mismatch caveat preserved.
      final binding = real1.items.first.symbolBinding!;
      expect(
          (binding.referenceSymbolId, binding.engineSymbolId, binding.status),
          ('symbol.iec.resistor', 'resistor', SymbolBindingStatus.bound));
      expect(binding.notes, contains('zigzag'));
      // Observations survive untouched alongside, and nothing was interpreted.
      expect(
          real1.ocrPages.single.words.map((w) => w.text), contains('resistor'));
      expect(real1.humanObservations.map((r) => r.label),
          contains('Component: R1'));
      expect(real1.candidates.single.status, KnowledgeCandidateStatus.pending);
      expect(jsonEncode(real1.toJson()).toLowerCase(),
          isNot(contains('this is a resistor')));

      // Deterministic against the real package as well.
      final real2 =
          DiagramInterpretationReferenceContextBuilder(reference: real)
              .build(ReferenceContextRequest(
        evidence: _evidence(),
        queries: [
          _q('resistor', ReferenceRetrievalPurpose.symbolIdentification,
              types: ['Symbol'], regions: ['reg-b']),
          _q('resistor', ReferenceRetrievalPurpose.componentClassification,
              types: ['Component'], regions: ['reg-b']),
        ],
      ));
      expect(_json(real1), _json(real2));
    });

    test(
        'an evidence-only context builds against the real package with no queries',
        () {
      final ctx = DiagramInterpretationReferenceContextBuilder(reference: real)
          .build(ReferenceContextRequest(evidence: _evidence()));
      expect(ctx.items, isEmpty);
      expect(ctx.reference!.packageId, 'core_reference');
      expect(ctx.evidenceRegions, hasLength(3));
    });
  });
}
