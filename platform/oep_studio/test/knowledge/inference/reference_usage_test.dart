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
import 'package:oep_studio/knowledge/inference/reference_usage.dart';
import 'package:oep_studio/knowledge/interpretation/reference_context.dart';
import 'package:oep_studio/knowledge/interpretation/reference_context_builder.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation_status.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-014 (ReferenceUsage). Every context here is built against the REAL
/// compiled `core_reference` package (staged by
/// `tool/generate_knowledge_asset.dart`); the "adapter" is a deterministic test
/// double, not a model.
final _t0 = DateTime.utc(2026, 9, 20, 10);
DateTime _at(int m) => _t0.add(Duration(minutes: m));

final _source = SourceMaterial(
  id: 'src-trx300',
  originalFileName: 'trx300_original_pdf_diagram.pdf',
  localPath: 'C:/x/trx300.pdf',
  type: SourceMaterialType.pdf,
  sizeBytes: 185420,
  importDate: DateTime.utc(2026, 9, 19),
  addedBy: 'uif',
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
      evidenceRegions: [
        EvidenceRegion(
          id: 'region-12',
          sourceId: 'src-trx300',
          page: 1,
          x: 0.6,
          y: 0.8,
          width: 0.06,
          height: 0.07,
          label: 'Component: R1',
          createdTime: DateTime.utc(2026, 9, 19, 10, 5),
          origin: EvidenceOrigin.human,
          annotatorId: 'david',
          status: EvidenceAnnotationStatus.unverified,
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

/// Query 0: symbol.iec.resistor (Symbol). Query 1: component.passive.resistor
/// (Component). Query 2: unit.ohm, retrieved but never used.
Future<DiagramInterpretationReferenceContext> _context() async {
  final builder = DiagramInterpretationReferenceContextBuilder(
      reference: await _realSources());
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

ReferenceContextItem _item(
        DiagramInterpretationReferenceContext c, String id) =>
    c.items.firstWhere((i) => i.referenceObjectId == id);

InferenceRecord _queued(DiagramInterpretationReferenceContext c,
        [String id = 'inf-1']) =>
    InferenceRecord(
      inferenceId: id,
      source: InferenceSourceIdentity(
          sourceMaterialId: 'src-trx300',
          sourceFingerprint: c.sourceFingerprint,
          pages: [1]),
      referenceContext: InferenceReferenceContextIdentity.of(c),
      adapter:
          const InferenceAdapterProvenance(adapterId: 'test-double-adapter'),
      queuedAt: _at(0),
    );

InferenceHypothesis _hyp(String id, String value) => InferenceHypothesis(
      hypothesisId: id,
      category: 'component',
      proposedValue: value,
      evidence: const [
        InferenceEvidenceReference(
            type: InferenceEvidenceType.evidenceRegion,
            id: 'region-12',
            page: 1)
      ],
    );

ReferenceUsage _use(
  DiagramInterpretationReferenceContext c,
  String id,
  String usageId, {
  ReferenceRetrievalPurpose? purpose,
  List<String> regions = const ['region-12'],
  List<String> hypotheses = const [],
  String inference = 'inf-1',
  ReferenceUsageRole role = ReferenceUsageRole.supporting,
}) =>
    ReferenceUsage.fromContextItem(
      usageId: usageId,
      inferenceId: inference,
      context: c,
      item: _item(c, id),
      purpose: purpose ?? _item(c, id).purpose,
      rationale: 'used $id for ${(purpose ?? _item(c, id).purpose).wireName}',
      role: role,
      evidenceRegionIds: regions,
      hypothesisIds: hypotheses,
    );

String _j(Object? o) => jsonEncode(o);

void main() {
  late DiagramInterpretationReferenceContext ctx;
  setUp(() async => ctx = await _context());

  group('Creation and identity (A-D)', () {
    test(
        'A: a usage is created from a retrieved context item with an explicit purpose and rationale',
        () {
      final u = _use(ctx, 'symbol.iec.resistor', 'u1', hypotheses: ['h1']);
      expect(u.referenceObjectId, 'symbol.iec.resistor');
      expect(u.purpose, ReferenceRetrievalPurpose.symbolIdentification);
      expect(u.rationale, contains('symbol.iec.resistor'));
      expect(u.schemaVersion, ReferenceUsage.currentSchemaVersion);
      expect(u.role, ReferenceUsageRole.supporting);
    });

    test(
        'B: reference identity (id, type, version) and the required fields are enforced',
        () {
      final u = _use(ctx, 'component.passive.resistor', 'u1');
      expect((u.referenceObjectType, u.referenceObjectVersion),
          ('Component', '1.0.0'));
      ReferenceUsage build(
              {String id = 'u', String obj = 'o', String rationale = 'r'}) =>
          ReferenceUsage(
            usageId: id,
            inferenceId: 'i',
            contextDigest: 'd',
            referenceObjectId: obj,
            referenceObjectType: 'Symbol',
            referenceObjectVersion: '1',
            package: ctx.reference!,
            purpose: ReferenceRetrievalPurpose.terminology,
            rationale: rationale,
          );
      expect(build, returnsNormally);
      expect(() => build(id: ''), throwsA(isA<ReferenceUsageException>()));
      expect(() => build(obj: ''), throwsA(isA<ReferenceUsageException>()));
      expect(
          () => build(rationale: '  '), throwsA(isA<ReferenceUsageException>()),
          reason: 'why it was used is mandatory');
    });

    test(
        'C: the exact package/runtime identity of the consumed context is preserved (no second version model)',
        () {
      final u = _use(ctx, 'symbol.iec.resistor', 'u1');
      expect(_j(u.package.toJson()), _j(ctx.reference!.toJson()));
      expect(u.package.packageId, 'core_reference');
      expect(u.package.contentHash, ctx.reference!.contentHash);
      expect((u.package.runtimeVersion, u.package.runtimeBuild),
          (ctx.reference!.runtimeVersion, ctx.reference!.runtimeBuild));
    });

    test(
        'D: only the frozen WP-EKE-017 purpose vocabulary is accepted; the purpose is never inferred from the object type',
        () {
      for (final p in ReferenceRetrievalPurpose.values) {
        final u =
            _use(ctx, 'symbol.iec.resistor', 'u-${p.wireName}', purpose: p);
        expect(
            ReferenceUsage.fromJson(
                    jsonDecode(_j(u.toJson())) as Map<String, dynamic>)
                .purpose,
            p);
      }
      final j = _use(ctx, 'symbol.iec.resistor', 'u1').toJson()
        ..['purpose'] = 'made_up_purpose';
      expect(
          () => ReferenceUsage.fromJson(
              jsonDecode(_j(j)) as Map<String, dynamic>),
          throwsA(isA<FormatException>()));
      // A Symbol object used for terminal interpretation keeps that stated purpose.
      final u = _use(ctx, 'symbol.iec.resistor', 'u2',
          purpose: ReferenceRetrievalPurpose.terminalInterpretation);
      expect(u.purpose, ReferenceRetrievalPurpose.terminalInterpretation);
      expect(u.retrieval!.queryIndex, 0,
          reason: 'why it was retrieved is kept separately');
    });
  });

  group('Evidence, hypothesis, context, retrieval linkage (E-I)', () {
    test(
        'E: evidence regions link by id, sorted and unique; a region outside the context is rejected',
        () {
      final u = _use(ctx, 'symbol.iec.resistor', 'u1',
          regions: ['region-12', 'region-12']);
      expect(u.evidenceRegionIds, ['region-12']);
      expect(
        () => _use(ctx, 'symbol.iec.resistor', 'u2', regions: ['region-ghost']),
        throwsA(isA<ReferenceUsageException>()),
      );
    });

    test(
        'F: hypothesis links are kept, and the record rejects a link to a hypothesis it does not have',
        () {
      final ok = _queued(ctx).markRunning(_at(1)).finish(
        InferenceRecordStatus.completed,
        _at(2),
        hypotheses: [_hyp('h1', 'resistor')],
        referenceUsage: [
          _use(ctx, 'component.passive.resistor', 'u1', hypotheses: ['h1'])
        ],
      );
      expect(ok.referenceUsage.single.hypothesisIds, ['h1']);
      expect(
        () => _queued(ctx).markRunning(_at(1)).finish(
          InferenceRecordStatus.completed,
          _at(2),
          hypotheses: [_hyp('h1', 'resistor')],
          referenceUsage: [
            _use(ctx, 'component.passive.resistor', 'u1', hypotheses: ['ghost'])
          ],
        ),
        throwsA(isA<InferenceRecordException>()),
      );
    });

    test(
        'G: the usage carries the context digest, and a record rejects a usage from a different context',
        () async {
      final u = _use(ctx, 'symbol.iec.resistor', 'u1');
      expect(u.contextDigest, ctx.digest);
      final other = DiagramInterpretationReferenceContextBuilder(
              reference: await _realSources())
          .build(
        ReferenceContextRequest(
          evidence: _evidence(),
          queries: [
            ReferenceContextQuery(
                purpose: ReferenceRetrievalPurpose.terminology, query: 'volt')
          ],
        ),
      );
      expect(other.digest, isNot(ctx.digest));
      final foreign = _use(other, 'unit.volt', 'ux');
      expect(
        () => _queued(ctx).markRunning(_at(1)).finish(
            InferenceRecordStatus.completed, _at(2),
            referenceUsage: [foreign]),
        throwsA(isA<InferenceRecordException>()),
      );
    });

    test(
        'H/I: retrieval provenance is preserved as retrieval facts; the retrieval score is never a confidence',
        () {
      final u = _use(ctx, 'symbol.iec.resistor', 'u1');
      final r = u.retrieval!;
      expect((r.queryIndex, r.queryText, r.rank), (0, 'resistor', 1));
      expect(r.normalizedTerms, ['resistor']);
      expect(r.matchedTerms, ['resistor']);
      expect(r.score, 1);
      final json = u.toJson();
      expect(json.keys, isNot(contains('confidence')));
      expect((json['retrieval'] as Map).keys, isNot(contains('confidence')));
      expect(jsonEncode(json).toLowerCase(), isNot(contains('"confidence"')));
    });

    test(
        'the Reference id stays authoritative and the Engine symbol id appears only in the preserved binding view',
        () {
      final u = _use(ctx, 'symbol.iec.resistor', 'u1');
      expect(u.referenceObjectId, 'symbol.iec.resistor');
      expect(u.symbolBinding!.referenceSymbolId, 'symbol.iec.resistor');
      expect(u.symbolBinding!.engineSymbolId, 'resistor');
      expect(u.symbolBinding!.notes, contains('zigzag'));
      expect(u.referenceObjectId, isNot(u.symbolBinding!.engineSymbolId));
      // A non-symbol carries no binding view.
      expect(
          _use(ctx, 'component.passive.resistor', 'u2').symbolBinding, isNull);
    });
  });

  group('Used vs retrieved (J) and duplication (K, L, S)', () {
    test('J: retrieved-but-unused context items produce no usage', () {
      expect(
          ctx.items.map((i) => i.referenceObjectId),
          containsAll([
            'symbol.iec.resistor',
            'component.passive.resistor',
            'unit.ohm'
          ]));
      final rec = _queued(ctx).markRunning(_at(1)).finish(
        InferenceRecordStatus.completed,
        _at(2),
        hypotheses: [_hyp('h1', 'resistor')],
        referenceUsage: [
          _use(ctx, 'symbol.iec.resistor', 'u1', hypotheses: ['h1']),
          _use(ctx, 'component.passive.resistor', 'u2', hypotheses: ['h1']),
        ],
      );
      expect(rec.referenceUsage.map((u) => u.referenceObjectId),
          ['symbol.iec.resistor', 'component.passive.resistor']);
      expect(rec.referenceUsage.where((u) => u.referenceObjectId == 'unit.ohm'),
          isEmpty);
      expect(ctx.items.length, greaterThan(rec.referenceUsage.length),
          reason: 'context membership is not usage');
      // Building a record without stating any usage yields none, however many items were retrieved.
      expect(
          _queued(ctx)
              .markRunning(_at(1))
              .finish(InferenceRecordStatus.completed, _at(2))
              .referenceUsage,
          isEmpty);
    });

    test(
        'K: the same reference used for different purposes is two distinct usages',
        () {
      final rec = _queued(ctx)
          .markRunning(_at(1))
          .finish(InferenceRecordStatus.completed, _at(2), referenceUsage: [
        _use(ctx, 'symbol.iec.resistor', 'u1',
            purpose: ReferenceRetrievalPurpose.symbolIdentification),
        _use(ctx, 'symbol.iec.resistor', 'u2',
            purpose: ReferenceRetrievalPurpose.terminalInterpretation),
      ]);
      expect(rec.referenceUsage, hasLength(2));
    });

    test(
        'L: the same reference and purpose supporting different hypotheses is distinct (attribution stays auditable)',
        () {
      final rec = _queued(ctx).markRunning(_at(1)).finish(
        InferenceRecordStatus.completed,
        _at(2),
        hypotheses: [_hyp('h1', 'resistor'), _hyp('h2', 'fuse')],
        referenceUsage: [
          _use(ctx, 'component.passive.resistor', 'u1', hypotheses: ['h1']),
          _use(ctx, 'component.passive.resistor', 'u2', hypotheses: ['h2']),
        ],
      );
      expect(rec.referenceUsage.map((u) => u.hypothesisIds), [
        ['h1'],
        ['h2']
      ]);
    });

    test(
        'S: the same reference + purpose + evidence + hypotheses is one semantic usage and is rejected as a duplicate',
        () {
      expect(
        () => _queued(ctx).markRunning(_at(1)).finish(
          InferenceRecordStatus.completed,
          _at(2),
          hypotheses: [_hyp('h1', 'resistor')],
          referenceUsage: [
            _use(ctx, 'component.passive.resistor', 'u1', hypotheses: ['h1']),
            _use(ctx, 'component.passive.resistor', 'u2', hypotheses: ['h1']),
          ],
        ),
        throwsA(isA<InferenceRecordException>()
            .having((e) => e.message, 'message', contains('duplicates'))),
      );
      expect(
        () => _queued(ctx)
            .markRunning(_at(1))
            .finish(InferenceRecordStatus.completed, _at(2), referenceUsage: [
          _use(ctx, 'unit.ohm', 'same'),
          _use(ctx, 'component.passive.resistor', 'same'),
        ]),
        throwsA(isA<InferenceRecordException>()),
        reason: 'usageIds are unique',
      );
    });

    test(
        'the semantic key is structured canonical JSON, independent of link order, ignoring ids and times',
        () {
      final a = _use(ctx, 'component.passive.resistor', 'ua',
          hypotheses: ['h2', 'h1']);
      final b = _use(ctx, 'component.passive.resistor', 'ub',
          hypotheses: ['h1', 'h2']);
      expect(a.semanticKey, b.semanticKey);
      expect(
          a.semanticKey,
          isNot(
              _use(ctx, 'component.passive.resistor', 'uc', hypotheses: ['h1'])
                  .semanticKey));
    });
  });

  group('Record integration and serialization (M-Q, T)', () {
    InferenceRecord full([String id = 'inf-1']) =>
        _queued(ctx, id).markRunning(_at(1)).finish(
          InferenceRecordStatus.completed,
          _at(2),
          hypotheses: [_hyp('h1', 'resistor')],
          referenceUsage: [
            _use(ctx, 'symbol.iec.resistor', 'u1',
                hypotheses: ['h1'],
                inference: id,
                role: ReferenceUsageRole.primary),
            _use(ctx, 'component.passive.resistor', 'u2',
                hypotheses: ['h1'], inference: id),
          ],
        );

    test(
        'M/N: several usages per inference, and independent usages across inference records',
        () {
      final a = full('inf-a');
      final b = _queued(ctx, 'inf-b')
          .markRunning(_at(3))
          .finish(InferenceRecordStatus.completed, _at(4), referenceUsage: [
        _use(ctx, 'unit.ohm', 'u1', inference: 'inf-b'),
      ]);
      expect(a.referenceUsage, hasLength(2));
      expect(b.referenceUsage, hasLength(1));
      expect(a.referenceUsage.first.inferenceId, 'inf-a');
      expect(b.referenceUsage.single.inferenceId, 'inf-b');
      // a usage belongs to the inference that made it
      expect(
        () => _queued(ctx, 'inf-c')
            .markRunning(_at(1))
            .finish(InferenceRecordStatus.completed, _at(2), referenceUsage: [
          _use(ctx, 'unit.ohm', 'u1', inference: 'inf-other'),
        ]),
        throwsA(isA<InferenceRecordException>()),
      );
    });

    test(
        'O/T: a record with usage round-trips exactly, with deterministic, stable ordering',
        () {
      final rec = full();
      final back = InferenceRecord.fromJson(
          jsonDecode(_j(rec.toJson())) as Map<String, dynamic>);
      expect(_j(back.toJson()), _j(rec.toJson()));
      expect(_j(full().toJson()), _j(full().toJson()));
      expect(back.referenceUsage.map((u) => u.usageId), ['u1', 'u2'],
          reason: 'the adapter\'s order is kept');
      expect(back.referenceUsage.first.role, ReferenceUsageRole.primary);
      expect(back.referenceUsage.first.retrieval!.score,
          rec.referenceUsage.first.retrieval!.score);
    });

    test(
        'P: an older InferenceRecord with no referenceUsage key loads with an empty list',
        () {
      final json = jsonDecode(_j(full().toJson())) as Map<String, dynamic>
        ..remove('referenceUsage');
      expect(InferenceRecord.fromJson(json).referenceUsage, isEmpty);
    });

    test(
        'Q: an unsupported or missing usage schemaVersion, and malformed usage data, fail explicitly',
        () {
      Map<String, dynamic> recJson() =>
          jsonDecode(_j(full().toJson())) as Map<String, dynamic>;
      Map<String, dynamic> withUsage(void Function(Map<String, dynamic>) f) {
        final j = recJson();
        f((j['referenceUsage'] as List).first as Map<String, dynamic>);
        return j;
      }

      expect(
          () => InferenceRecord.fromJson(
              withUsage((u) => u['schemaVersion'] = 2)),
          throwsA(isA<FormatException>()));
      expect(
          () => InferenceRecord.fromJson(
              withUsage((u) => u.remove('schemaVersion'))),
          throwsA(isA<FormatException>()));
      expect(
          () => InferenceRecord.fromJson(withUsage((u) => u.remove('package'))),
          throwsA(isA<FormatException>()));
      expect(
          () => InferenceRecord.fromJson(withUsage((u) => u['rationale'] = '')),
          throwsA(isA<FormatException>()));
      expect(
          () => InferenceRecord.fromJson(withUsage((u) => u['role'] = 'boss')),
          throwsA(isA<FormatException>()));
    });

    test(
        'a finished record\'s usage is immutable (only hypothesis decisions may change it)',
        () {
      final rec = full();
      final rewritten = InferenceRecord(
        inferenceId: 'inf-1',
        source: rec.source,
        referenceContext: rec.referenceContext,
        adapter: rec.adapter,
        queuedAt: rec.queuedAt,
        startedAt: rec.startedAt,
        completedAt: rec.completedAt,
        status: rec.status,
        hypotheses: rec.hypotheses,
        referenceUsage: [rec.referenceUsage.first],
      );
      expect(() => rewritten.requireValidSuccessorOf(rec),
          throwsA(isA<InferenceRecordException>()));
      expect(
          () => rec
              .withHypothesisDecision('h1', HypothesisStatus.accepted)
              .requireValidSuccessorOf(rec),
          returnsNormally);
      expect(
          rec
              .withHypothesisDecision('h1', HypothesisStatus.rejected)
              .referenceUsage
              .length,
          2);
    });
  });

  group('Dangling references (R)', () {
    test(
        'R: a usage cannot be built from an item outside its context, and a record can be checked against its context',
        () async {
      final other = DiagramInterpretationReferenceContextBuilder(
              reference: await _realSources())
          .build(
        ReferenceContextRequest(
          evidence: _evidence(),
          queries: [
            ReferenceContextQuery(
                purpose: ReferenceRetrievalPurpose.terminology, query: 'volt')
          ],
        ),
      );
      final foreignItem = _item(other, 'unit.volt');
      expect(
        () => ReferenceUsage.fromContextItem(
          usageId: 'u',
          inferenceId: 'inf-1',
          context: ctx,
          item: foreignItem,
          purpose: ReferenceRetrievalPurpose.terminology,
          rationale: 'x',
        ),
        throwsA(isA<ReferenceUsageException>()),
      );
      // A record whose usage is consistent with its context validates; a stale context does not.
      final rec = _queued(ctx).markRunning(_at(1)).finish(
          InferenceRecordStatus.completed, _at(2),
          referenceUsage: [_use(ctx, 'symbol.iec.resistor', 'u1')]);
      expect(() => rec.requireReferenceUsageMatches(ctx), returnsNormally);
      expect(() => rec.requireReferenceUsageMatches(other),
          throwsA(isA<InferenceRecordException>()));
    });
  });

  group('Lifecycle (X, Y)', () {
    ReferenceUsage usageFor(DiagramInterpretationReferenceContext c) =>
        _use(c, 'symbol.iec.resistor', 'u1');

    test('X: a FAILED inference preserves the usage produced before it failed',
        () {
      final r = _queued(ctx).markRunning(_at(1)).finish(
        InferenceRecordStatus.failed,
        _at(2),
        referenceUsage: [usageFor(ctx)],
        errors: const [
          InferenceDiagnostic(code: 'boom', message: 'adapter failed')
        ],
      );
      expect(r.status, InferenceRecordStatus.failed);
      expect(r.referenceUsage.single.referenceObjectId, 'symbol.iec.resistor');
    });

    test(
        'Y: a CANCELLED inference preserves its usage; a PARTIAL one does too; a QUEUED one has none required',
        () {
      expect(_queued(ctx).referenceUsage, isEmpty);
      final cancelled = _queued(ctx).markRunning(_at(1)).finish(
          InferenceRecordStatus.cancelled, _at(2),
          referenceUsage: [usageFor(ctx)]);
      final partial = _queued(ctx).markRunning(_at(1)).finish(
          InferenceRecordStatus.partial, _at(2),
          referenceUsage: [usageFor(ctx)]);
      expect(cancelled.referenceUsage, hasLength(1));
      expect(partial.referenceUsage, hasLength(1));
    });
  });

  group('Persistence: autosave, reload, archive; no promotion (U, V, W, Z-AC)',
      () {
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
      final id = 'inf014-${DateTime.now().microsecondsSinceEpoch}';
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

    InferenceRecord finished() => _queued(ctx).markRunning(_at(1)).finish(
          InferenceRecordStatus.completed,
          _at(2),
          hypotheses: [_hyp('h1', 'resistor')],
          referenceUsage: [
            _use(ctx, 'symbol.iec.resistor', 'u1', hypotheses: ['h1']),
            _use(ctx, 'component.passive.resistor', 'u2', hypotheses: ['h1']),
          ],
        );

    test(
        'U/V: usage survives the notifier autosave and a reload from disk (including after an unrelated autosave)',
        () async {
      final t = start();
      final running = _queued(ctx).markRunning(_at(1));
      t.n.addInferenceRecord(_queued(ctx));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      t.n.updateInferenceRecord(running);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final done = finished();
      t.n.updateInferenceRecord(done);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      // an unrelated mutation triggers another autosave that rebuilds the record from state
      t.n.createEvidenceRegion(
          sourceId: 'src-trx300', page: 1, x: 0, y: 0, width: 0.1, height: 0.1);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final loaded = await KnowledgeSessionStorage.load(t.id);
      expect(loaded.evidenceRegions, hasLength(1));
      expect(_j(loaded.inferenceRecords.single.toJson()), _j(done.toJson()));
      expect(
          loaded.inferenceRecords.single.referenceUsage
              .map((u) => u.referenceObjectId),
          ['symbol.iec.resistor', 'component.passive.resistor']);
    });

    test(
        'W: archiving (which rebuilds the record) preserves inference records with their usage',
        () async {
      final t = start();
      final s = KnowledgeSession(
          id: t.id,
          name: 'u',
          repositoryName: 'Repo',
          author: 'a',
          createdTime: _t0,
          lastModified: _t0);
      final done = finished();
      await KnowledgeSessionStorage.save(
          KnowledgeSessionRecord(session: s, inferenceRecords: [done]));
      await t.n.setKnowledgeSessionArchived(t.id, archived: true);
      final loaded = await KnowledgeSessionStorage.load(t.id);
      expect(loaded.session.archived, isTrue);
      expect(_j(loaded.inferenceRecords.single.toJson()), _j(done.toJson()));
    });

    test(
        'Z/AA/AB/AC: recording usage creates no candidate, Engineering Object, review decision, commit, and changes no Reference Knowledge',
        () async {
      final sources = await _realSources();
      final packageBefore = _j(sources.runtime.package.toJson());
      final countsBefore = _j(sources.runtime.capabilities.registryCounts);
      final t = start();
      t.n.addInferenceRecord(_queued(ctx));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      t.n.updateInferenceRecord(_queued(ctx).markRunning(_at(1)));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      t.n.updateInferenceRecord(finished());
      final s = t.c.read(foundationRuntimeServiceProvider);
      expect(s.candidates, isEmpty);
      expect(s.engineeringEntities, isEmpty);
      expect(s.reviewDecisions, isEmpty);
      expect(s.commitReports, isEmpty);
      expect(s.evidenceLinks, isEmpty);
      // Reference Knowledge is untouched.
      expect(_j(sources.runtime.package.toJson()), packageBefore);
      expect(_j(sources.runtime.capabilities.registryCounts), countsBefore);
      // the usage never alters hypothesis status
      expect(s.inferenceRecords.single.hypotheses.single.status,
          HypothesisStatus.proposed);
    });
  });

  group('TRX300: retrieved, used, and not used (real compiled package)', () {
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

    test(
        'a deterministic adapter uses the symbol and the component, not the unit; usage survives save/reload with the real package identity',
        () async {
      // A deterministic stand-in for an adapter's OUTPUT (reads the context, is not a model).
      final hypothesis = _hyp('hyp-resistor', 'resistor');
      final usages = [
        _use(ctx, 'symbol.iec.resistor', 'use-symbol',
            hypotheses: ['hyp-resistor'], role: ReferenceUsageRole.primary),
        _use(ctx, 'component.passive.resistor', 'use-component',
            hypotheses: ['hyp-resistor']),
      ];
      expect(usages.map((u) => u.purpose.wireName),
          ['symbol_identification', 'component_classification']);

      final id = 'inf014-trx-${DateTime.now().microsecondsSinceEpoch}';
      created.add(id);
      final container = ProviderContainer(overrides: [
        foundationRuntimeServiceProvider.overrideWith(() => _Seeded(
            KnowledgeSession(
                id: id,
                name: 'trx',
                repositoryName: 'Repo',
                author: 'david',
                createdTime: _t0,
                lastModified: _t0))),
      ]);
      addTearDown(container.dispose);
      final n = container.read(foundationRuntimeServiceProvider.notifier);
      var rec = _queued(ctx);
      n.addInferenceRecord(rec);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      rec = rec.markRunning(_at(1));
      n.updateInferenceRecord(rec);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      rec = rec.finish(InferenceRecordStatus.completed, _at(2),
          hypotheses: [hypothesis], referenceUsage: usages);
      rec.requireReferenceUsageMatches(ctx);
      n.updateInferenceRecord(rec);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final stored =
          (await KnowledgeSessionStorage.load(id)).inferenceRecords.single;
      // Retrieved by the context: symbol, component and the unit; USED: only the first two.
      expect(ctx.items.map((i) => i.referenceObjectId), contains('unit.ohm'));
      expect(stored.referenceUsage.map((u) => u.referenceObjectId),
          ['symbol.iec.resistor', 'component.passive.resistor']);
      expect(
          stored.referenceUsage.any((u) => u.referenceObjectId == 'unit.ohm'),
          isFalse);
      // Real package/runtime identity, evidence and hypothesis links, both symbol identities.
      final symbolUse = stored.referenceUsage.first;
      expect(symbolUse.package.packageId, 'core_reference');
      expect(symbolUse.package.contentHash, ctx.reference!.contentHash);
      expect(symbolUse.evidenceRegionIds, ['region-12']);
      expect(symbolUse.hypothesisIds, ['hyp-resistor']);
      expect((
        symbolUse.referenceObjectId,
        symbolUse.symbolBinding!.engineSymbolId
      ), (
        'symbol.iec.resistor',
        'resistor'
      ));
      expect(stored.referenceContext.contextDigest, ctx.digest);
      // Nothing was promoted.
      final s = container.read(foundationRuntimeServiceProvider);
      expect(s.candidates, isEmpty);
      expect(s.engineeringEntities, isEmpty);
      expect(s.commitReports, isEmpty);
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
