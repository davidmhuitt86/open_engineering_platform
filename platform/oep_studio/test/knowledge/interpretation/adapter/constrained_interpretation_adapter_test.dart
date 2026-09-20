import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart'
    show
        KnowledgeRuntime,
        OerpReader,
        ReferenceDiscovery,
        SymbolBindingAdapter,
        SymbolBindingRegistry,
        SymbolLibrary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/inference/inference_record.dart';
import 'package:oep_studio/knowledge/interpretation/adapter/constrained_interpretation_adapter.dart';
import 'package:oep_studio/knowledge/interpretation/adapter/interpretation_request.dart';
import 'package:oep_studio/knowledge/interpretation/adapter/provider_result.dart';
import 'package:oep_studio/knowledge/interpretation/reference_context.dart';
import 'package:oep_studio/knowledge/interpretation/reference_context_builder.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation_status.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

import '../../../support/deterministic_interpretation_provider.dart';

/// WP-EKE-018 (Constrained Interpretation Adapter). Every context is built
/// against the REAL compiled `core_reference` package (staged by
/// `tool/generate_knowledge_asset.dart`); the provider is a deterministic test
/// double, never a model.
final _t0 = DateTime.utc(2026, 9, 20, 11);

final _source = SourceMaterial(
  id: 'src-trx300',
  originalFileName: 'trx300_original_pdf_diagram.pdf',
  localPath: 'C:/x/trx300.pdf',
  type: SourceMaterialType.pdf,
  sizeBytes: 185420,
  importDate: DateTime.utc(2026, 9, 19),
  addedBy: 'uif',
);

EvidenceRegion _region(String id, {int page = 1, double y = 0.8}) =>
    EvidenceRegion(
      id: id,
      sourceId: 'src-trx300',
      page: page,
      x: 0.6,
      y: y,
      width: 0.06,
      height: 0.07,
      label: 'Component: R1',
      createdTime: DateTime.utc(2026, 9, 19, 10, 5),
      origin: EvidenceOrigin.human,
      annotatorId: 'david',
      status: EvidenceAnnotationStatus.unverified,
    );

DiagramEvidenceInput _evidence() => DiagramEvidenceInput(
      source: _source,
      ocrPages: [
        OcrPageResult(
          sourceId: 'src-trx300',
          page: 1,
          words: [
            OcrWord(
              text: 'R1',
              confidence: 0.93,
              boundingBox: const OcrBoundingBox(
                  x: 0.61, y: 0.83, width: 0.03, height: 0.01),
              readingOrder: 0,
              lineIndex: 0,
            ),
          ],
          imageWidth: 3300,
          imageHeight: 2550,
          sourceFingerprint: 'fp-abc',
          engineVersion: 'Tesseract v5.4',
          processedTime: DateTime.utc(2026, 9, 19, 10),
          success: true,
        ),
      ],
      evidenceRegions: [_region('region-12'), _region('region-13', y: 0.5)],
      evidenceLinks: [
        EvidenceLink(
            id: 'link-1',
            candidateId: 'cand-1',
            regionId: 'region-12',
            createdTime: DateTime.utc(2026, 9, 19, 10, 6)),
      ],
      candidates: [
        KnowledgeCandidate(
          id: 'cand-1',
          type: KnowledgeCandidateType.component,
          name: 'R1',
          createdTime: DateTime.utc(2026, 9, 19, 10, 6),
        ),
      ],
    );

Future<ReferenceKnowledgeSources> _realSources() async {
  final oerp = File('assets/knowledge/core_reference_v1.oerp');
  expect(oerp.existsSync(), isTrue,
      reason:
          'run `dart run tool/generate_knowledge_asset.dart` first (compiles the real Reference Library)');
  const reader = OerpReader();
  final runtime = KnowledgeRuntime.activate(reader.readFile(oerp),
      allowUnsignedDevelopmentPackages: true);
  final symbols =
      SymbolLibrary(symbolsDirectory: '../oep_engine/assets/symbols');
  await symbols.initialize();
  return ReferenceKnowledgeSources(
    runtime: runtime,
    discovery: ReferenceDiscovery.create(
        runtime, reader.readDiscoveryIndexesFile(oerp)),
    symbolBinding: SymbolBindingAdapter(
      runtime: runtime,
      symbols: symbols,
      bindings: SymbolBindingRegistry.loadFile(File(
          '../oep_engine/assets/symbol_bindings/reference_symbol_bindings.json')),
    ),
  );
}

/// symbol.iec.resistor (query 0), component.passive.resistor (query 1),
/// unit.ohm (query 2, to be retrieved but never used).
Future<DiagramInterpretationReferenceContext> _context(
    {ReferenceKnowledgeSources? sources}) async {
  final builder = DiagramInterpretationReferenceContextBuilder(
      reference: sources ?? await _realSources());
  return builder.build(ReferenceContextRequest(
    evidence: _evidence(),
    queries: [
      ReferenceContextQuery(
        purpose: ReferenceRetrievalPurpose.symbolIdentification,
        query: 'resistor',
        objectTypes: const ['Symbol'],
        evidenceRegionIds: const ['region-12'],
      ),
      ReferenceContextQuery(
        purpose: ReferenceRetrievalPurpose.componentClassification,
        query: 'resistor',
        objectTypes: const ['Component'],
        evidenceRegionIds: const ['region-12'],
      ),
      ReferenceContextQuery(
          purpose: ReferenceRetrievalPurpose.terminology,
          query: 'ohm',
          objectTypes: const ['Unit']),
    ],
  ));
}

const _regionRef =
    ProviderEvidenceRef(type: 'evidenceRegion', id: 'region-12', page: 1);

ProviderHypothesis _hyp({
  String id = 'hyp-resistor',
  String value = 'resistor',
  String category = 'component',
  String status = 'proposed',
  List<ProviderEvidenceRef> evidence = const [_regionRef],
  List<String> refs = const [
    'symbol.iec.resistor',
    'component.passive.resistor'
  ],
  ProviderConfidence? confidence,
}) =>
    ProviderHypothesis(
      hypothesisId: id,
      category: category,
      proposedValue: value,
      status: status,
      evidence: evidence,
      referenceObjectIds: refs,
      confidence: confidence,
    );

ProviderReferenceUsage _use(
  String id,
  String purpose, {
  List<String> hyps = const ['hyp-resistor'],
  String? engine,
  String role = 'supporting',
}) =>
    ProviderReferenceUsage(
      referenceObjectId: id,
      purpose: purpose,
      role: role,
      rationale: 'relied on $id for $purpose',
      evidenceRegionIds: const ['region-12'],
      hypothesisIds: hyps,
      claimedEngineSymbolId: engine,
    );

ProviderResult _good() => ProviderResult(
      hypotheses: [
        _hyp(
            confidence: const ProviderConfidence(
                value: 0.82, basis: 'provider-reported'))
      ],
      statements: const [
        ProviderStatement(
            statementId: 'stmt-1',
            text: 'The symbol appears consistent with a resistor.',
            hypothesisIds: ['hyp-resistor'])
      ],
      referenceUsage: [
        _use('symbol.iec.resistor', 'symbol_identification',
            engine: 'resistor', role: 'primary'),
        _use('component.passive.resistor', 'component_classification'),
      ],
    );

String _j(Object? o) => jsonEncode(o);

int _tick = 0;
DateTime _clock() => _t0.add(Duration(seconds: _tick++));

Future<InferenceRecord> _run(
  ProviderResult result, {
  InterpretationRequest? request,
  List<InferenceRecord>? steps,
  bool Function()? cancelled,
}) async {
  _tick = 0;
  final ctx = await _context();
  return ConstrainedInterpretationAdapter(
    DeterministicTestInterpretationProvider.returning(result),
    clock: _clock,
  ).interpret(
    request ??
        InterpretationRequest(
            objective: InterpretationObjective.symbolIdentification,
            context: ctx),
    inferenceId: 'inf-1',
    onRecord: steps?.add,
    isCancelled: cancelled,
  );
}

Set<String> _codes(InferenceRecord r) => {for (final e in r.errors) e.code};

void main() {
  late DiagramInterpretationReferenceContext ctx;
  setUp(() async {
    ctx = await _context();
    _tick = 0;
  });

  group('Request (1, 2)', () {
    test(
        '1: a valid request carries the context, the scoped regions, the pages and the source identity',
        () {
      final r = InterpretationRequest(
        objective: InterpretationObjective.symbolIdentification,
        context: ctx,
        instructionVersion: 'instr-1',
      );
      expect(r.sourceMaterialId, 'src-trx300');
      expect(r.scopedRegionIds, ['region-13', 'region-12'],
          reason: "the context's own (page, y, x, id) order");
      expect(r.pages, [1]);
      expect(identical(r.context, ctx), isTrue);
      expect(r.outputSchemaVersion, 1);
    });

    test(
        'an explicit selection narrows the interpretable evidence; an unknown selection, a Reference-only context and a bad schema are rejected',
        () async {
      final r = InterpretationRequest(
        objective: InterpretationObjective.symbolIdentification,
        context: ctx,
        selectedEvidenceRegionIds: ['region-12'],
      );
      expect(r.scopedRegionIds, ['region-12']);
      expect(
        () => InterpretationRequest(
            objective: InterpretationObjective.symbolIdentification,
            context: ctx,
            selectedEvidenceRegionIds: ['region-ghost']),
        throwsA(isA<InterpretationAdapterException>()),
      );
      final referenceOnly = DiagramInterpretationReferenceContextBuilder(
              reference: await _realSources())
          .build(ReferenceContextRequest(queries: [
        ReferenceContextQuery(
            purpose: ReferenceRetrievalPurpose.terminology, query: 'ohm')
      ]));
      expect(
        () => InterpretationRequest(
            objective: InterpretationObjective.terminology,
            context: referenceOnly),
        throwsA(isA<InterpretationAdapterException>().having(
            (e) => e.code, 'code', InterpretationFailureCode.invalidRequest)),
      );
      expect(
        () => InterpretationRequest(
            objective: InterpretationObjective.terminology,
            context: ctx,
            outputSchemaVersion: 9),
        throwsA(isA<InterpretationAdapterException>()),
      );
    });

    test(
        '2: the provider is invoked once with exactly the structured request (no other route to Reference Knowledge)',
        () async {
      final provider =
          DeterministicTestInterpretationProvider.returning(_good());
      final request = InterpretationRequest(
          objective: InterpretationObjective.symbolIdentification,
          context: ctx);
      await ConstrainedInterpretationAdapter(provider, clock: _clock)
          .interpret(request, inferenceId: 'inf-1');
      expect(provider.received, hasLength(1));
      expect(identical(provider.received.single, request), isTrue);
      expect(
          provider.received.single.context.items
              .map((i) => i.referenceObjectId),
          containsAll([
            'symbol.iec.resistor',
            'component.passive.resistor',
            'unit.ohm'
          ]));
      expect(provider.identity.adapterId, 'test-adapter.deterministic');
      expect(provider.identity.provider, contains('not a model'));
    });

    test(
        'an objective the provider does not support is rejected before any record exists',
        () async {
      final provider = DeterministicTestInterpretationProvider.returning(
        _good(),
        supported: {InterpretationObjective.terminology},
      );
      await expectLater(
        ConstrainedInterpretationAdapter(provider, clock: _clock).interpret(
          InterpretationRequest(
              objective: InterpretationObjective.symbolIdentification,
              context: ctx),
          inferenceId: 'inf-1',
        ),
        throwsA(isA<InterpretationAdapterException>().having((e) => e.code,
            'code', InterpretationFailureCode.unsupportedObjective)),
      );
      expect(provider.received, isEmpty,
          reason: 'the provider was never called');
    });
  });

  group('A valid result becomes a record (3, 4, 5)', () {
    test(
        '3/4: COMPLETED record; identity fields are built by the adapter from the request, not the provider',
        () async {
      final steps = <InferenceRecord>[];
      final r = await _run(_good(), steps: steps);
      expect(r.status, InferenceRecordStatus.completed);
      expect(r.errors, isEmpty);
      // source identity from the context
      expect((r.source.sourceMaterialId, r.source.sourceFingerprint),
          ('src-trx300', 'fp-abc'));
      expect(r.source.pages, [1]);
      // context identity + package/runtime identity from the context
      expect(r.referenceContext.contextDigest, ctx.digest);
      expect(_j(r.referenceContext.reference!.toJson()),
          _j(ctx.reference!.toJson()));
      // provenance: the provider's own declaration, nothing invented
      expect(r.adapter.adapterId, 'test-adapter.deterministic');
      expect(r.adapter.modelName, isNull);
      expect(r.adapter.modelVersion, isNull);
      expect(r.adapter.outputSchemaVersion, '1');
      // the lifecycle was reported step by step
      expect(
          steps.map((s) => s.status.name), ['queued', 'running', 'completed']);
      // evidence used is derived, not supplied
      expect(r.evidenceUsed.map((e) => '${e.type.name}:${e.id}'),
          ['evidenceRegion:region-12']);
      expect(r.hypotheses.single.status, HypothesisStatus.proposed);
      expect(r.hypotheses.single.evidence.single.page, 1);
    });

    test(
        '5/15/16: usage is constructed by the adapter from the context items; retrieved-but-unused stays unused; both symbol identities are kept',
        () async {
      final r = await _run(_good());
      expect(r.referenceUsage.map((u) => u.referenceObjectId),
          ['symbol.iec.resistor', 'component.passive.resistor']);
      expect(r.referenceUsage.map((u) => u.usageId),
          ['inf-1-usage-1', 'inf-1-usage-2']);
      expect(r.referenceUsage.map((u) => u.purpose.wireName),
          ['symbol_identification', 'component_classification']);
      final symbol = r.referenceUsage.first;
      expect(symbol.package.contentHash, ctx.reference!.contentHash);
      expect(symbol.contextDigest, ctx.digest);
      expect((symbol.retrieval!.queryIndex, symbol.retrieval!.queryText),
          (0, 'resistor'));
      expect(symbol.symbolBinding!.referenceSymbolId, 'symbol.iec.resistor');
      expect(symbol.symbolBinding!.engineSymbolId, 'resistor');
      expect(symbol.referenceObjectId,
          isNot(symbol.symbolBinding!.engineSymbolId));
      // unit.ohm was retrieved into the context and used by nothing
      expect(ctx.items.map((i) => i.referenceObjectId), contains('unit.ohm'));
      expect(r.referenceUsage.where((u) => u.referenceObjectId == 'unit.ohm'),
          isEmpty);
      r.requireReferenceUsageMatches(ctx);
    });

    test(
        'statements stay interpretation: kept verbatim, linked to hypotheses, nothing more',
        () async {
      final r = await _run(_good());
      expect(r.statements.single.text,
          'The symbol appears consistent with a resistor.');
      expect(r.statements.single.hypothesisIds, ['hyp-resistor']);
      final keys = (r.toJson()).keys;
      expect(keys, isNot(contains('engineeringObjects')));
      expect(keys, isNot(contains('candidates')));
    });

    test(
        'a provider that declares no usage yields none, however much was retrieved',
        () async {
      final r = await _run(ProviderResult(hypotheses: [_hyp(refs: const [])]));
      expect(r.status, InferenceRecordStatus.completed);
      expect(r.referenceUsage, isEmpty);
    });

    test(
        '27: determinism: the same request and result give byte-identical records',
        () async {
      final a = await _run(_good());
      final b = await _run(_good());
      expect(_j(a.toJson()), _j(b.toJson()));
    });
  });

  group('Evidence validation (6, 10)', () {
    test(
        'an unknown evidence region rejects the hypothesis explicitly (nothing untraceable is recorded)',
        () async {
      final r = await _run(ProviderResult(hypotheses: [
        _hyp(evidence: const [
          ProviderEvidenceRef(
              type: 'evidenceRegion', id: 'region-ghost', page: 1)
        ]),
      ]));
      expect(r.status, InferenceRecordStatus.failed);
      expect(r.hypotheses, isEmpty);
      expect(_codes(r), {'invalid_evidence_reference'});
      expect(r.errors.single.message, contains('region-ghost'));
    });

    test(
        'evidence outside the selected scope, a page mismatch, a foreign OCR page and a hypothesis with no evidence are all rejected',
        () async {
      final scoped = InterpretationRequest(
        objective: InterpretationObjective.symbolIdentification,
        context: ctx,
        selectedEvidenceRegionIds: ['region-12'],
      );
      final outside = await _run(
        ProviderResult(hypotheses: [
          _hyp(evidence: const [
            ProviderEvidenceRef(
                type: 'evidenceRegion', id: 'region-13', page: 1)
          ])
        ]),
        request: scoped,
      );
      expect(_codes(outside), {'invalid_evidence_reference'});
      for (final bad in [
        const ProviderEvidenceRef(
            type: 'evidenceRegion', id: 'region-12', page: 2),
        const ProviderEvidenceRef(type: 'ocrPage', id: 'other-source', page: 1),
        const ProviderEvidenceRef(type: 'ocrPage', id: 'src-trx300', page: 9),
        const ProviderEvidenceRef(type: 'evidenceLink', id: 'link-ghost'),
        const ProviderEvidenceRef(type: 'knowledgeCandidate', id: 'cand-ghost'),
        const ProviderEvidenceRef(type: 'bogus', id: 'x'),
      ]) {
        final r = await _run(ProviderResult(hypotheses: [
          _hyp(evidence: [bad])
        ]));
        expect(_codes(r), {'invalid_evidence_reference'},
            reason: '${bad.type}:${bad.id}');
        expect(r.hypotheses, isEmpty);
      }
      final none =
          await _run(ProviderResult(hypotheses: [_hyp(evidence: const [])]));
      expect(_codes(none), {'invalid_evidence_reference'});
    });

    test(
        'valid region, link, candidate and OCR-page references are accepted with the adapter\'s authoritative pages',
        () async {
      final r = await _run(ProviderResult(hypotheses: [
        _hyp(evidence: const [
          ProviderEvidenceRef(type: 'evidenceRegion', id: 'region-12'),
          ProviderEvidenceRef(type: 'evidenceLink', id: 'link-1'),
          ProviderEvidenceRef(type: 'knowledgeCandidate', id: 'cand-1'),
          ProviderEvidenceRef(type: 'ocrPage', id: 'src-trx300', page: 1),
        ]),
      ]));
      expect(r.status, InferenceRecordStatus.completed);
      expect(r.hypotheses.single.evidence.map((e) => e.type.name),
          ['evidenceRegion', 'evidenceLink', 'knowledgeCandidate', 'ocrPage']);
      expect(r.hypotheses.single.evidence.first.page, 1,
          reason: 'the page comes from the region, not the provider');
    });
  });

  group('Context and package identity (7, 8)', () {
    test(
        'a wrong context digest fails the whole result; nothing from it is recorded',
        () async {
      final r = await _run(ProviderResult(
          claimedContextDigest: 'not-the-digest',
          hypotheses: [
            _hyp()
          ],
          referenceUsage: [
            _use('symbol.iec.resistor', 'symbol_identification')
          ]));
      expect(r.status, InferenceRecordStatus.failed);
      expect(_codes(r), {'invalid_context_identity'});
      expect(r.hypotheses, isEmpty);
      expect(r.referenceUsage, isEmpty);
    });

    test('a wrong package/runtime identity claim fails the result', () async {
      final wrong = ReferenceContextIdentity(
        packageId: 'core_reference',
        packageVersion: '9.9.9',
        schemaVersion: ctx.reference!.schemaVersion,
        compilerVersion: ctx.reference!.compilerVersion,
        contentHash: ctx.reference!.contentHash,
        runtimeVersion: ctx.reference!.runtimeVersion,
        runtimeBuild: ctx.reference!.runtimeBuild,
      );
      final r = await _run(
          ProviderResult(claimedPackage: wrong, hypotheses: [_hyp()]));
      expect(_codes(r), {'invalid_context_identity'});
      expect(r.status, InferenceRecordStatus.failed);
    });

    test(
        'correct claims are accepted but never copied: the record holds the context\'s own identity',
        () async {
      final r = await _run(ProviderResult(
        claimedContextDigest: ctx.digest,
        claimedPackage: ctx.reference,
        hypotheses: [_hyp()],
      ));
      expect(r.status, InferenceRecordStatus.completed);
      expect(r.referenceContext.contextDigest, ctx.digest);
    });
  });

  group('Reference validation (9, 11, 16, A, E, H, I)', () {
    test(
        'A/9: a usage of a Reference object that was not supplied is rejected; the adapter does not search or accept it',
        () async {
      final r = await _run(ProviderResult(
        hypotheses: [_hyp()],
        referenceUsage: [
          _use('some.reference.that.was.not.supplied', 'terminology'),
          _use('symbol.iec.resistor', 'symbol_identification')
        ],
      ));
      expect(r.status, InferenceRecordStatus.partial);
      expect(r.referenceUsage.map((u) => u.referenceObjectId),
          ['symbol.iec.resistor']);
      expect(_codes(r), {'unknown_reference_object'});
      expect(r.errors.single.message,
          contains('some.reference.that.was.not.supplied'));
      // a hypothesis citing an unsupplied Reference object is rejected too
      final h = await _run(ProviderResult(hypotheses: [
        _hyp(refs: const ['symbol.iec.fuse'])
      ]));
      expect(_codes(h), {'unknown_reference_object'});
      expect(h.hypotheses, isEmpty);
    });

    test(
        'I/11: an invalid purpose or role, or a missing rationale, is rejected',
        () async {
      for (final bad in [
        _use('symbol.iec.resistor', 'made_up_purpose'),
        _use('symbol.iec.resistor', 'symbol_identification', role: 'boss'),
        ProviderReferenceUsage(
            referenceObjectId: 'symbol.iec.resistor',
            purpose: 'symbol_identification',
            rationale: ' ',
            evidenceRegionIds: const ['region-12']),
      ]) {
        final r = await _run(
            ProviderResult(hypotheses: [_hyp()], referenceUsage: [bad]));
        expect(_codes(r), {'invalid_reference_usage'});
        expect(r.referenceUsage, isEmpty);
        expect(r.hypotheses, hasLength(1),
            reason: 'the valid hypothesis is preserved (PARTIAL)');
        expect(r.status, InferenceRecordStatus.partial);
      }
    });

    test(
        'E/16: an invented or wrong Engine symbol mapping is rejected; the real binding claim is accepted',
        () async {
      for (final claim in ['resistor2', 'symbol.iec.resistor', 'battery']) {
        final r = await _run(ProviderResult(hypotheses: [
          _hyp()
        ], referenceUsage: [
          _use('symbol.iec.resistor', 'symbol_identification', engine: claim)
        ]));
        expect(_codes(r), {'invalid_reference_usage'}, reason: claim);
        expect(r.referenceUsage, isEmpty);
      }
      // a claim about an object with no binding at all
      final none = await _run(ProviderResult(hypotheses: [
        _hyp()
      ], referenceUsage: [
        _use('component.passive.resistor', 'component_classification',
            engine: 'resistor')
      ]));
      expect(_codes(none), {'invalid_reference_usage'});
      final ok = await _run(ProviderResult(hypotheses: [
        _hyp()
      ], referenceUsage: [
        _use('symbol.iec.resistor', 'symbol_identification', engine: 'resistor')
      ]));
      expect(ok.status, InferenceRecordStatus.completed);
      expect(
          ok.referenceUsage.single.symbolBinding!.engineSymbolId, 'resistor');
    });

    test(
        'H: a retrieved-but-unused item never becomes a usage, and duplicate usages are rejected',
        () async {
      final dup = await _run(ProviderResult(hypotheses: [
        _hyp()
      ], referenceUsage: [
        _use('component.passive.resistor', 'component_classification'),
        _use('component.passive.resistor', 'component_classification'),
      ]));
      expect(dup.referenceUsage, hasLength(1));
      expect(_codes(dup), {'invalid_reference_usage'});
      expect(dup.referenceUsage.every((u) => u.referenceObjectId != 'unit.ohm'),
          isTrue);
    });

    test(
        'a usage of a hypothesis that was itself rejected is rejected (no dangling link)',
        () async {
      final r = await _run(ProviderResult(
        hypotheses: [
          _hyp(evidence: const [
            ProviderEvidenceRef(type: 'evidenceRegion', id: 'region-ghost')
          ])
        ],
        referenceUsage: [_use('symbol.iec.resistor', 'symbol_identification')],
      ));
      expect(r.hypotheses, isEmpty);
      expect(r.referenceUsage, isEmpty);
      expect(
          _codes(r), {'invalid_evidence_reference', 'invalid_reference_usage'});
    });
  });

  group('Schema, duplicates, confidence (12, 13, 14, J, K, L)', () {
    test(
        'J/12: an unsupported provider schema is rejected (typed result and JSON)',
        () async {
      final r =
          await _run(const ProviderResult(schemaVersion: 2, hypotheses: []));
      expect(_codes(r), {'unsupported_provider_schema'});
      expect(r.status, InferenceRecordStatus.failed);
      for (final json in [
        {'schemaVersion': 2},
        <String, dynamic>{},
      ]) {
        expect(
          () => ProviderResult.fromJson(json),
          throwsA(isA<ProviderResultException>().having((e) => e.code, 'code',
              InterpretationFailureCode.unsupportedProviderSchema)),
        );
      }
    });

    test(
        'K/13: a duplicate hypothesis id rejects every declaration of it; other hypotheses survive as PARTIAL',
        () async {
      final r = await _run(ProviderResult(hypotheses: [
        _hyp(id: 'dup', value: 'resistor'),
        _hyp(id: 'dup', value: 'fuse'),
        _hyp(id: 'unique', value: 'connector'),
      ]));
      expect(r.hypotheses.map((h) => h.hypothesisId), ['unique']);
      expect(_codes(r), {'malformed_hypothesis'});
      expect(r.errors, hasLength(2));
      expect(r.status, InferenceRecordStatus.partial);
    });

    test(
        'L/14: confidence is kept exactly as supplied (not calibrated, normalized or ranked); malformed or calibrated claims are rejected',
        () async {
      final r = await _run(ProviderResult(hypotheses: [
        _hyp(
            id: 'low',
            value: 'fuse',
            confidence: const ProviderConfidence(value: 0.2)),
        _hyp(
            id: 'high',
            value: 'resistor',
            confidence: const ProviderConfidence(
                value: 7.5, basis: 'provider-reported')),
        _hyp(id: 'none', value: 'relay'),
      ]));
      expect(r.hypotheses.map((h) => h.hypothesisId), ['low', 'high', 'none'],
          reason: 'provider order kept; nothing is ranked');
      expect(r.hypotheses[0].confidence!.value, 0.2);
      expect(r.hypotheses[0].confidence!.basis, 'provider-supplied');
      expect(r.hypotheses[1].confidence!.value, 7.5,
          reason: 'not normalized or clamped');
      expect(r.hypotheses[1].confidence!.calibrated, isFalse);
      expect(r.hypotheses[2].confidence, isNull,
          reason: 'none is manufactured');
      for (final bad in [
        const ProviderConfidence(value: double.nan),
        const ProviderConfidence(value: double.infinity),
        const ProviderConfidence(value: 0.9, calibrated: true),
      ]) {
        final rr =
            await _run(ProviderResult(hypotheses: [_hyp(confidence: bad)]));
        expect(_codes(rr), {'malformed_hypothesis'});
        expect(rr.hypotheses, isEmpty);
      }
    });

    test(
        'G: a provider cannot self-accept a hypothesis or use an unknown status; it may only propose or reject',
        () async {
      for (final status in ['accepted', 'committed', 'engineering_truth']) {
        final r =
            await _run(ProviderResult(hypotheses: [_hyp(status: status)]));
        expect(_codes(r), {'malformed_hypothesis'}, reason: status);
        expect(r.hypotheses, isEmpty);
      }
      final rejected =
          await _run(ProviderResult(hypotheses: [_hyp(status: 'rejected')]));
      expect(rejected.hypotheses.single.status, HypothesisStatus.rejected);
      expect(rejected.status, InferenceRecordStatus.completed);
    });

    test('statements naming a rejected hypothesis, or duplicated, are rejected',
        () async {
      final r = await _run(ProviderResult(
        hypotheses: [_hyp()],
        statements: const [
          ProviderStatement(
              statementId: 's1', text: 'ok', hypothesisIds: ['hyp-resistor']),
          ProviderStatement(
              statementId: 's2', text: 'bad', hypothesisIds: ['ghost']),
          ProviderStatement(statementId: 's3', text: 'dup'),
          ProviderStatement(statementId: 's3', text: 'dup'),
        ],
      ));
      expect(r.statements.map((s) => s.statementId), ['s1']);
      expect(_codes(r), {'malformed_statement'});
    });
  });

  group(
      'Strict provider JSON: no engineering truth through the schema (F, G, M, N, O)',
      () {
    Map<String, dynamic> base() => {
          'schemaVersion': 1,
          'hypotheses': <Object?>[],
          'statements': <Object?>[],
          'referenceUsage': <Object?>[]
        };

    test(
        'F/M/O: fields for Engineering Objects, repository operations, commits, candidates or unknown authoritative claims are rejected, never ignored',
        () async {
      for (final extra in [
        'engineeringObjects',
        'engineeringRelationships',
        'repository',
        'commit',
        'candidates',
        'autoAcceptCandidates',
        'verified',
      ]) {
        final json = base()
          ..[extra] = [
            <String, dynamic>{'x': 1}
          ];
        expect(
          () => ProviderResult.fromJson(json),
          throwsA(isA<ProviderResultException>().having((e) => e.code, 'code',
              InterpretationFailureCode.unsupportedProviderField)),
          reason: extra,
        );
      }
      final nested = base()
        ..['hypotheses'] = [
          {
            'hypothesisId': 'h',
            'category': 'c',
            'proposedValue': 'v',
            'evidence': <Object?>[],
            'engineeringTruth': true
          },
        ];
      expect(() => ProviderResult.fromJson(nested),
          throwsA(isA<ProviderResultException>()));
      final usage = base()
        ..['referenceUsage'] = [
          {
            'referenceObjectId': 'a',
            'purpose': 'terminology',
            'rationale': 'r',
            'createReferenceObject': true
          },
        ];
      expect(() => ProviderResult.fromJson(usage),
          throwsA(isA<ProviderResultException>()));
    });

    test(
        'a provider that parses such output makes the inference FAILED with an explicit code, and nothing is created',
        () async {
      final provider = DeterministicTestInterpretationProvider(
        (request, cancelled) async => ProviderResult.fromJson({
          'schemaVersion': 1,
          'engineeringObjects': [
            {'id': 'R1'}
          ]
        }),
      );
      _tick = 0;
      final r = await ConstrainedInterpretationAdapter(provider, clock: _clock)
          .interpret(
        InterpretationRequest(
            objective: InterpretationObjective.symbolIdentification,
            context: ctx),
        inferenceId: 'inf-1',
      );
      expect(r.status, InferenceRecordStatus.failed);
      expect(_codes(r), {'unsupported_provider_field'});
      expect(r.hypotheses, isEmpty);
    });

    test(
        'a valid JSON result round-trips into the typed schema and the adapter validates it like any other',
        () async {
      final json = {
        'schemaVersion': 1,
        'hypotheses': [
          {
            'hypothesisId': 'hyp-resistor',
            'category': 'component',
            'proposedValue': 'resistor',
            'evidence': [
              {'type': 'evidenceRegion', 'id': 'region-12', 'page': 1}
            ],
            'referenceObjectIds': ['symbol.iec.resistor'],
            'confidence': {'value': 0.5, 'basis': 'provider-reported'},
          },
        ],
        'referenceUsage': [
          {
            'referenceObjectId': 'symbol.iec.resistor',
            'purpose': 'symbol_identification',
            'rationale': 'matches the drawn symbol',
            'evidenceRegionIds': ['region-12'],
            'hypothesisIds': ['hyp-resistor'],
            'claimedEngineSymbolId': 'resistor',
          },
        ],
      };
      final r = await _run(ProviderResult.fromJson(json));
      expect(r.status, InferenceRecordStatus.completed);
      expect(r.referenceUsage.single.symbolBinding!.engineSymbolId, 'resistor');
    });

    test(
        'N/17: a relationship hypothesis is stored only as a hypothesis; no relationship structure exists in the record',
        () async {
      final r = await _run(ProviderResult(hypotheses: [
        _hyp(
          id: 'hyp-rel',
          category: 'relationship',
          value:
              'component.passive.resistor REPRESENTED_BY symbol.iec.resistor',
        ),
      ]));
      expect(r.status, InferenceRecordStatus.completed);
      expect(r.hypotheses.single.category, 'relationship');
      expect(r.hypotheses.single.status, HypothesisStatus.proposed);
      expect(r.toJson().keys, isNot(contains('relationships')));
    });
  });

  group('Partial, failure, insufficiency (18, 19, 20)', () {
    test(
        '18: valid output alongside an invalid item is preserved as PARTIAL, with the failure recorded explicitly',
        () async {
      final r = await _run(ProviderResult(hypotheses: [
        _hyp(),
        _hyp(id: 'bad', evidence: const [
          ProviderEvidenceRef(type: 'evidenceRegion', id: 'ghost')
        ]),
      ]));
      expect(r.status, InferenceRecordStatus.partial);
      expect(r.hypotheses.map((h) => h.hypothesisId), ['hyp-resistor']);
      expect(_codes(r), {'invalid_evidence_reference'});
    });

    test(
        'a provider that reports its own result as incomplete is PARTIAL with an explicit error',
        () async {
      final r = await _run(ProviderResult(
          outcome: ProviderOutcome.partial, hypotheses: [_hyp()]));
      expect(r.status, InferenceRecordStatus.partial);
      expect(_codes(r), {'incomplete_provider_result'});
      expect(r.hypotheses, hasLength(1));
    });

    test(
        'provider warnings and errors are kept as typed lists (an error alone makes the result PARTIAL, not COMPLETED)',
        () async {
      final r = await _run(ProviderResult(
        hypotheses: [_hyp()],
        warnings: const [
          InferenceDiagnostic(
              code: 'low_ocr_confidence', message: 'R1 read at 0.71')
        ],
        errors: const [
          InferenceDiagnostic(code: 'timeout', message: 'region 3 timed out')
        ],
      ));
      expect(r.status, InferenceRecordStatus.partial);
      expect(r.warnings.single.code, 'low_ocr_confidence');
      expect(_codes(r), {'timeout'});
    });

    test(
        '19: a provider failure becomes a FAILED record with an explicit error (typed exception, or any thrown error)',
        () async {
      for (final thrown in <Object>[
        const InterpretationProviderException('model unavailable'),
        StateError('boom')
      ]) {
        _tick = 0;
        final provider = DeterministicTestInterpretationProvider(
            (request, cancelled) async => throw thrown);
        final r =
            await ConstrainedInterpretationAdapter(provider, clock: _clock)
                .interpret(
          InterpretationRequest(
              objective: InterpretationObjective.symbolIdentification,
              context: ctx),
          inferenceId: 'inf-1',
        );
        expect(r.status, InferenceRecordStatus.failed);
        expect(_codes(r), {'provider_failure'});
        expect(r.hypotheses, isEmpty);
      }
    });

    test(
        'a provider needing Reference Knowledge it was not given yields an explicit "insufficient" condition and no retrieval',
        () async {
      final r = await _run(ProviderResult(
        hypotheses: [_hyp()],
        referenceContextInsufficient: const [
          'need an IEC terminal convention object'
        ],
      ));
      expect(r.status, InferenceRecordStatus.partial);
      expect(_codes(r), {'reference_context_insufficient'});
      expect(r.errors.single.message, contains('terminal convention'));
      expect(r.referenceUsage, isEmpty,
          reason: 'nothing was retrieved or invented');
      final none = await _run(const ProviderResult(
          referenceContextInsufficient: ['nothing to go on']));
      expect(none.status, InferenceRecordStatus.failed);
    });

    test(
        '20: cancellation before the provider runs, output after cancellation, and a provider-declared cancel',
        () async {
      // before: the provider is never called
      final provider =
          DeterministicTestInterpretationProvider.returning(_good());
      _tick = 0;
      final before =
          await ConstrainedInterpretationAdapter(provider, clock: _clock)
              .interpret(
        InterpretationRequest(
            objective: InterpretationObjective.symbolIdentification,
            context: ctx),
        inferenceId: 'inf-1',
        isCancelled: () => true,
      );
      expect(before.status, InferenceRecordStatus.cancelled);
      expect(provider.received, isEmpty);
      expect(before.status, isNot(InferenceRecordStatus.failed));

      // cancelled while the provider ran: its output is not made durable
      var cancelNow = false;
      final late =
          DeterministicTestInterpretationProvider((request, cancelled) async {
        cancelNow = true;
        return _good();
      });
      _tick = 0;
      final discarded =
          await ConstrainedInterpretationAdapter(late, clock: _clock).interpret(
        InterpretationRequest(
            objective: InterpretationObjective.symbolIdentification,
            context: ctx),
        inferenceId: 'inf-1',
        isCancelled: () => cancelNow,
      );
      expect(discarded.status, InferenceRecordStatus.cancelled);
      expect(discarded.hypotheses, isEmpty);
      expect(discarded.referenceUsage, isEmpty);
      expect(discarded.warnings.single.code,
          'output_discarded_after_cancellation');

      // a provider that observed the cancellation keeps what already validated
      final declared = await _run(ProviderResult(
          outcome: ProviderOutcome.cancelled,
          hypotheses: [
            _hyp()
          ],
          referenceUsage: [
            _use('symbol.iec.resistor', 'symbol_identification')
          ]));
      expect(declared.status, InferenceRecordStatus.cancelled);
      expect(declared.hypotheses, hasLength(1));
      expect(declared.referenceUsage, hasLength(1));
    });
  });

  group('Persistence and boundaries (21-26)', () {
    final created = <String>[];
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final id in created) {
        final dir = KnowledgeSessionStorage.sessionDirectory(id);
        for (var i = 0; i < 10 && dir.existsSync(); i++) {
          try {
            await dir.delete(recursive: true);
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
      }
      created.clear();
    });

    ({ProviderContainer c, FoundationRuntimeNotifier n, String id}) start() {
      final id = 'inf018-${DateTime.now().microsecondsSinceEpoch}';
      created.add(id);
      final c = ProviderContainer(overrides: [
        foundationRuntimeServiceProvider.overrideWith(() => _Seeded(
            KnowledgeSession(
                id: id,
                name: 'u',
                repositoryName: 'Repo',
                author: 'a',
                createdTime: _t0,
                lastModified: _t0))),
      ]);
      addTearDown(c.dispose);
      return (
        c: c,
        n: c.read(foundationRuntimeServiceProvider.notifier),
        id: id
      );
    }

    test(
        '21/22/23/24-27: TRX300 end to end on the real package: interpret -> persist each step -> unrelated autosave -> reload; nothing is promoted or mutated',
        () async {
      final sources = await _realSources();
      final packageBefore = _j(sources.runtime.package.toJson());
      final countsBefore = _j(sources.runtime.capabilities.registryCounts);
      final context = await _context(sources: sources);
      final evidence = _evidence();

      final steps = <InferenceRecord>[];
      _tick = 0;
      final record = await ConstrainedInterpretationAdapter(
        DeterministicTestInterpretationProvider.returning(_good()),
        clock: _clock,
      ).interpret(
        InterpretationRequest(
            objective: InterpretationObjective.symbolIdentification,
            context: context,
            instructionVersion: 'instr-1'),
        inferenceId: 'inference-trx-1',
        onRecord: steps.add,
      );
      expect(
          steps.map((s) => s.status.name), ['queued', 'running', 'completed']);

      // Persist every lifecycle step through the ordinary notifier/session path.
      final t = start();
      t.n.addInferenceRecord(steps[0]);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      t.n.updateInferenceRecord(steps[1]);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      t.n.updateInferenceRecord(steps[2]);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      t.n.createEvidenceRegion(
          sourceId: 'src-trx300', page: 1, x: 0, y: 0, width: 0.1, height: 0.1);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final loaded = await KnowledgeSessionStorage.load(t.id);
      final stored = loaded.inferenceRecords.single;
      expect(_j(stored.toJson()), _j(record.toJson()));
      // source identity, context digest, package/runtime identity
      expect((stored.source.sourceMaterialId, stored.source.sourceFingerprint),
          ('src-trx300', 'fp-abc'));
      expect(stored.referenceContext.contextDigest, context.digest);
      expect(stored.referenceContext.reference!.packageId, 'core_reference');
      expect(stored.referenceContext.reference!.contentHash,
          context.reference!.contentHash);
      // hypothesis, evidence linkage, usage, retrieval provenance, symbol binding
      expect(stored.hypotheses.single.proposedValue, 'resistor');
      expect(stored.hypotheses.single.evidence.single.id, 'region-12');
      expect(
          stored.referenceUsage
              .map((u) => '${u.referenceObjectId}:${u.purpose.wireName}'),
          [
            'symbol.iec.resistor:symbol_identification',
            'component.passive.resistor:component_classification'
          ]);
      expect(stored.referenceUsage.first.retrieval!.queryText, 'resistor');
      expect(stored.referenceUsage.first.symbolBinding!.engineSymbolId,
          'resistor');
      expect(
          stored.referenceUsage.any((u) => u.referenceObjectId == 'unit.ohm'),
          isFalse,
          reason: 'retrieved, not used');
      stored.requireReferenceUsageMatches(context);

      // Nothing was promoted, created or committed, and no Reference Knowledge changed.
      final s = t.c.read(foundationRuntimeServiceProvider);
      expect(s.candidates, isEmpty);
      expect(s.engineeringEntities, isEmpty);
      expect(s.reviewDecisions, isEmpty);
      expect(s.commitReports, isEmpty);
      expect(s.inferenceRecords.single.hypotheses.single.status,
          HypothesisStatus.proposed);
      expect(
          evidence.candidates.every((c) =>
              c.status == KnowledgeCandidateStatus.pending &&
              c.committedObjectId == null),
          isTrue);
      expect(_j(sources.runtime.package.toJson()), packageBefore);
      expect(_j(sources.runtime.capabilities.registryCounts), countsBefore);
    });
  });
}

class _Seeded extends FoundationRuntimeNotifier {
  _Seeded(this.session);
  final KnowledgeSession session;
  @override
  FoundationServiceState build() => FoundationServiceState(
      phase: FoundationConnectionPhase.connected, knowledgeSession: session);
}
