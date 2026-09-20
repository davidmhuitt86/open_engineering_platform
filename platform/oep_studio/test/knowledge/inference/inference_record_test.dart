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
import 'package:oep_studio/knowledge/inference/canonical_json.dart';
import 'package:oep_studio/knowledge/inference/inference_record.dart';
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
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-013 (Durable Inference Record). No LLM/vision code exists here:
/// the "adapter" in the TRX300 test is a deterministic test double that only
/// stands in for an inference adapter's OUTPUT.
final _t0 = DateTime.utc(2026, 9, 20, 9);
DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));

InferenceSourceIdentity _source() => InferenceSourceIdentity(
    sourceMaterialId: 'src-trx300', sourceFingerprint: 'fp-abc', pages: [1]);

const _refIdentity = ReferenceContextIdentity(
  packageId: 'core_reference',
  packageVersion: '1.0.0',
  schemaVersion: '1.0.0',
  compilerVersion: 'c1',
  contentHash: 'pkg-hash',
  runtimeVersion: '0.1.0',
  runtimeBuild: '1',
);

InferenceReferenceContextIdentity _ctx([String digest = 'digest-1']) =>
    InferenceReferenceContextIdentity(
        contextDigest: digest, reference: _refIdentity);

const _adapter = InferenceAdapterProvenance(
  adapterId: 'test-double-adapter',
  provider: 'none',
  modelName: 'deterministic-fixture',
  modelVersion: '0',
  promptVersion: 'p1',
  outputSchemaVersion: 'o1',
);

const _regionRef = InferenceEvidenceReference(
    type: InferenceEvidenceType.evidenceRegion, id: 'region-12', page: 1);

InferenceHypothesis _h(String id, String value,
        {HypothesisStatus status = HypothesisStatus.proposed,
        String? reason,
        List<InferenceEvidenceReference> evidence = const [_regionRef],
        List<String> refs = const ['symbol.iec.resistor'],
        InferenceConfidence? confidence}) =>
    InferenceHypothesis(
      hypothesisId: id,
      category: 'component',
      proposedValue: value,
      status: status,
      statusReason: reason,
      evidence: evidence,
      referenceObjectIds: refs,
      confidence: confidence,
    );

InferenceRecord _queued([String id = 'inf-1', String digest = 'digest-1']) =>
    InferenceRecord(
      inferenceId: id,
      source: _source(),
      referenceContext: _ctx(digest),
      adapter: _adapter,
      queuedAt: _at(0),
    );

String _json(Object o) => jsonEncode(o);

void main() {
  group('Record creation and identity (A-D, R)', () {
    test(
        'A: a new record is QUEUED with the current schema version and no outputs',
        () {
      final r = _queued();
      expect(r.status, InferenceRecordStatus.queued);
      expect(r.schemaVersion, InferenceRecord.currentSchemaVersion);
      expect((r.startedAt, r.completedAt), (null, null));
      expect(r.hypotheses, isEmpty);
      expect(r.errors, isEmpty);
    });

    test('B: required identity fields are enforced', () {
      InferenceRecord build(
              {String id = 'x',
              String src = 's',
              String digest = 'd',
              String adapter = 'a'}) =>
          InferenceRecord(
            inferenceId: id,
            source: InferenceSourceIdentity(sourceMaterialId: src),
            referenceContext:
                InferenceReferenceContextIdentity(contextDigest: digest),
            adapter: InferenceAdapterProvenance(adapterId: adapter),
            queuedAt: _at(0),
          );
      expect(build, returnsNormally);
      for (final bad in [
        () => build(id: ''),
        () => build(src: ''),
        () => build(digest: ''),
        () => build(adapter: ''),
      ]) {
        expect(bad, throwsA(isA<InferenceRecordException>()));
      }
    });

    test(
        'C: source identity keeps source id, the existing fingerprint and sorted unique pages',
        () {
      final s = InferenceSourceIdentity(
          sourceMaterialId: 'src',
          sourceFingerprint: 'fp',
          pages: [3, 1, 3, 2]);
      expect(s.pages, [1, 2, 3]);
      final r = _queued();
      expect(r.source.sourceMaterialId, 'src-trx300');
      expect(r.source.sourceFingerprint, 'fp-abc');
      expect(r.source.pages, [1]);
    });

    test(
        'D: the consumed Reference Context is identified by digest plus package/runtime identity, kept separate from source identity',
        () {
      final r = _queued();
      expect(r.referenceContext.contextDigest, 'digest-1');
      expect(r.referenceContext.reference!.packageId, 'core_reference');
      expect(r.referenceContext.reference!.contentHash, 'pkg-hash');
      expect(r.referenceContext.reference!.runtimeVersion, '0.1.0');
      expect(
          r.source.sourceFingerprint, isNot(r.referenceContext.contextDigest));
      // Evidence-only context: no Reference identity, still a digest.
      final evidenceOnly =
          InferenceReferenceContextIdentity(contextDigest: 'd');
      expect(evidenceOnly.reference, isNull);
    });

    test(
        'R: adapter/model provenance is vendor-neutral and optional beyond adapterId',
        () {
      final r = _queued();
      expect(r.adapter.adapterId, 'test-double-adapter');
      expect((
        r.adapter.modelName,
        r.adapter.modelVersion,
        r.adapter.promptVersion,
        r.adapter.outputSchemaVersion
      ), (
        'deterministic-fixture',
        '0',
        'p1',
        'o1'
      ));
      final minimal = const InferenceAdapterProvenance(adapterId: 'only-this');
      expect((minimal.provider, minimal.modelName, minimal.modelVersion),
          (null, null, null));
    });
  });

  group('Lifecycle (E-I)', () {
    test('E: QUEUED -> RUNNING -> COMPLETED sets times and keeps outputs', () {
      final done = _queued().markRunning(_at(1)).finish(
          InferenceRecordStatus.completed, _at(2),
          hypotheses: [_h('h1', 'resistor')]);
      expect(done.status, InferenceRecordStatus.completed);
      expect((done.startedAt, done.completedAt), (_at(1), _at(2)));
      expect(done.hypotheses.single.proposedValue, 'resistor');
    });

    test(
        'F/T: RUNNING -> PARTIAL preserves the successful outputs and the error',
        () {
      final partial = _queued().markRunning(_at(1)).finish(
        InferenceRecordStatus.partial,
        _at(2),
        hypotheses: [_h('h1', 'resistor'), _h('h2', 'connector')],
        errors: const [
          InferenceDiagnostic(
              code: 'provider_failed',
              message: 'provider failed on region 3 of 5')
        ],
      );
      expect(partial.status, InferenceRecordStatus.partial);
      expect(partial.hypotheses, hasLength(2));
      expect(partial.errors.single.code, 'provider_failed');
    });

    test('G: RUNNING -> FAILED keeps whatever intermediate output existed', () {
      final failed = _queued().markRunning(_at(1)).finish(
        InferenceRecordStatus.failed,
        _at(2),
        hypotheses: [_h('h1', 'resistor')],
        errors: const [
          InferenceDiagnostic(code: 'boom', message: 'adapter error')
        ],
      );
      expect(failed.status, InferenceRecordStatus.failed);
      expect(failed.hypotheses.single.hypothesisId, 'h1');
    });

    test('H: cancellation is distinct from failure, from RUNNING or QUEUED',
        () {
      final fromRunning = _queued()
          .markRunning(_at(1))
          .finish(InferenceRecordStatus.cancelled, _at(2));
      final fromQueued =
          _queued().finish(InferenceRecordStatus.cancelled, _at(1));
      expect(fromRunning.status, InferenceRecordStatus.cancelled);
      expect(fromQueued.status, InferenceRecordStatus.cancelled);
      expect(fromQueued.startedAt, isNull);
      expect(fromRunning.status, isNot(InferenceRecordStatus.failed));
    });

    test('I: illegal transitions are rejected', () {
      final running = _queued().markRunning(_at(1));
      final done = running.finish(InferenceRecordStatus.completed, _at(2));
      expect(() => _queued().finish(InferenceRecordStatus.completed, _at(1)),
          throwsA(isA<InferenceRecordException>()));
      expect(() => running.markRunning(_at(2)),
          throwsA(isA<InferenceRecordException>()));
      expect(() => done.markRunning(_at(3)),
          throwsA(isA<InferenceRecordException>()));
      expect(() => done.finish(InferenceRecordStatus.failed, _at(3)),
          throwsA(isA<InferenceRecordException>()));
      expect(() => running.finish(InferenceRecordStatus.running, _at(2)),
          throwsA(isA<InferenceRecordException>()));
      expect(() => running.finish(InferenceRecordStatus.queued, _at(2)),
          throwsA(isA<InferenceRecordException>()));
    });

    test(
        'a loaded RUNNING record is reconciled to FAILED with an explicit interruption error (not left running, not cancelled)',
        () {
      final interrupted =
          _queued().markRunning(_at(1)).reconciledIfInterrupted(_at(9));
      expect(interrupted.status, InferenceRecordStatus.failed);
      expect(interrupted.completedAt, _at(9));
      expect(interrupted.errors.single.code, InferenceRecord.interruptionCode);
      expect(_queued().reconciledIfInterrupted(_at(9)).status,
          InferenceRecordStatus.failed);
      final done = _queued()
          .markRunning(_at(1))
          .finish(InferenceRecordStatus.completed, _at(2));
      expect(identical(done.reconciledIfInterrupted(_at(9)), done), isTrue);
    });
  });

  group('Hypotheses (J-M, Q, AC)', () {
    final base = _queued().markRunning(_at(1));

    test(
        'J/K: multiple hypotheses over the same evidence are kept in order, as proposed',
        () {
      final r = base.finish(InferenceRecordStatus.completed, _at(2),
          hypotheses: [_h('hA', 'resistor'), _h('hB', 'fuse')]);
      expect(r.hypotheses.map((h) => h.proposedValue), ['resistor', 'fuse']);
      expect(r.hypotheses.every((h) => h.status == HypothesisStatus.proposed),
          isTrue);
    });

    test(
        'L: an accepted hypothesis is accepted as an inference outcome only (still just a record)',
        () {
      final r = base.finish(InferenceRecordStatus.completed, _at(2),
          hypotheses: [
            _h('hA', 'resistor')
          ]).withHypothesisDecision('hA', HypothesisStatus.accepted,
          reason: 'matches the annotation');
      expect(r.hypotheses.single.status, HypothesisStatus.accepted);
      expect(r.hypotheses.single.statusReason, 'matches the annotation');
      expect(r.toJson().keys, isNot(contains('candidate')));
      expect(r.toJson().keys, isNot(contains('engineeringObject')));
    });

    test(
        'M/AC: a rejected hypothesis keeps what was proposed, its evidence, its reference and the reason',
        () {
      final r = base.finish(InferenceRecordStatus.completed, _at(2),
          hypotheses: [
            _h('hA', 'resistor'),
            _h('hB', 'fuse')
          ]).withHypothesisDecision('hA', HypothesisStatus.rejected,
          reason: 'symbol geometry inconsistent');
      final rejected = r.hypotheses.first;
      expect(rejected.status, HypothesisStatus.rejected);
      expect(rejected.statusReason, 'symbol geometry inconsistent');
      expect((rejected.category, rejected.proposedValue),
          ('component', 'resistor'));
      expect(rejected.evidence.single.id, 'region-12');
      expect(rejected.referenceObjectIds, ['symbol.iec.resistor']);
      expect(r.hypotheses.last.status, HypothesisStatus.proposed);
      // and it survives a round trip
      final back = InferenceRecord.fromJson(
          jsonDecode(_json(r.toJson())) as Map<String, dynamic>);
      expect(back.hypotheses.first.status, HypothesisStatus.rejected);
      expect(
          back.hypotheses.first.statusReason, 'symbol geometry inconsistent');
    });

    test(
        'a decision is final and needs a finished record and a known hypothesis',
        () {
      final done = base.finish(InferenceRecordStatus.completed, _at(2),
          hypotheses: [_h('hA', 'resistor')]);
      final decided =
          done.withHypothesisDecision('hA', HypothesisStatus.rejected);
      expect(
          () => decided.withHypothesisDecision('hA', HypothesisStatus.accepted),
          throwsA(isA<InferenceRecordException>()));
      expect(
          () => done.withHypothesisDecision('nope', HypothesisStatus.accepted),
          throwsA(isA<InferenceRecordException>()));
      expect(() => done.withHypothesisDecision('hA', HypothesisStatus.proposed),
          throwsA(isA<InferenceRecordException>()));
      expect(() => base.withHypothesisDecision('hA', HypothesisStatus.accepted),
          throwsA(isA<InferenceRecordException>()));
    });

    test(
        'duplicate hypothesis ids and statements about unknown hypotheses are rejected',
        () {
      expect(
        () => base.finish(InferenceRecordStatus.completed, _at(2),
            hypotheses: [_h('h', 'a'), _h('h', 'b')]),
        throwsA(isA<InferenceRecordException>()),
      );
      expect(
        () => base.finish(
          InferenceRecordStatus.completed,
          _at(2),
          hypotheses: [_h('h', 'a')],
          statements: [
            InferenceStatement(
                statementId: 's', text: 'x', hypothesisIds: ['ghost'])
          ],
        ),
        throwsA(isA<InferenceRecordException>()),
      );
    });

    test(
        'Q: confidence is kept as supplied, with its basis, and is never calibrated by default',
        () {
      final r =
          base.finish(InferenceRecordStatus.completed, _at(2), hypotheses: [
        _h('hA', 'resistor',
            confidence: const InferenceConfidence(
                value: 0.82, basis: 'provider-reported')),
        _h('hB', 'fuse'),
      ]);
      expect(r.hypotheses.first.confidence!.value, 0.82);
      expect(r.hypotheses.first.confidence!.basis, 'provider-reported');
      expect(r.hypotheses.first.confidence!.calibrated, isFalse);
      expect(r.hypotheses.last.confidence, isNull,
          reason: 'no confidence is manufactured');
      expect(
        () => InferenceConfidence.fromJson({'value': double.nan}),
        throwsA(isA<FormatException>()),
      );
      expect(const InferenceConfidence(value: 0.5, calibrated: true).calibrated,
          isTrue);
    });
  });

  group('Evidence and Reference-context linkage (N, O, P)', () {
    test(
        'N/O: hypotheses point at existing evidence by stable identity, several regions at once',
        () {
      final r = _queued().markRunning(_at(1)).finish(
        InferenceRecordStatus.completed,
        _at(2),
        evidenceUsed: const [
          _regionRef,
          InferenceEvidenceReference(
              type: InferenceEvidenceType.evidenceRegion,
              id: 'region-13',
              page: 1),
          InferenceEvidenceReference(
              type: InferenceEvidenceType.ocrPage, id: 'src-trx300', page: 1),
          InferenceEvidenceReference(
              type: InferenceEvidenceType.evidenceLink, id: 'link-1'),
          InferenceEvidenceReference(
              type: InferenceEvidenceType.knowledgeCandidate, id: 'cand-1'),
        ],
        hypotheses: [
          _h('h', 'resistor', evidence: const [
            _regionRef,
            InferenceEvidenceReference(
                type: InferenceEvidenceType.evidenceRegion,
                id: 'region-13',
                page: 1),
          ]),
        ],
      );
      expect(r.hypotheses.single.evidence.map((e) => e.id),
          ['region-12', 'region-13']);
      expect(r.evidenceUsed.map((e) => e.type.name), [
        'evidenceRegion',
        'evidenceRegion',
        'ocrPage',
        'evidenceLink',
        'knowledgeCandidate'
      ]);
      // An OCR page is identified by (sourceId, page), so a page is mandatory.
      expect(
        () => InferenceEvidenceReference.fromJson(
            {'type': 'ocrPage', 'id': 'src'}),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'P: a hypothesis names the Reference objects (from the consumed context) it relates to',
        () {
      final r = _queued()
          .markRunning(_at(1))
          .finish(InferenceRecordStatus.completed, _at(2), hypotheses: [
        _h('h', 'resistor',
            refs: const ['symbol.iec.resistor', 'component.passive.resistor'])
      ]);
      expect(r.hypotheses.single.referenceObjectIds,
          ['symbol.iec.resistor', 'component.passive.resistor']);
      expect(r.referenceContext.contextDigest, 'digest-1');
    });

    test('S: warnings and errors are kept as separate typed lists', () {
      final r = _queued().markRunning(_at(1)).finish(
        InferenceRecordStatus.partial,
        _at(2),
        warnings: const [
          InferenceDiagnostic(
              code: 'low_ocr_confidence', message: 'word "R1" below threshold')
        ],
        errors: const [
          InferenceDiagnostic(code: 'timeout', message: 'provider timed out')
        ],
      );
      expect(r.warnings.single.code, 'low_ocr_confidence');
      expect(r.errors.single.code, 'timeout');
    });
  });

  group('Serialization (U, V)', () {
    final full = _queued().markRunning(_at(1)).finish(
      InferenceRecordStatus.completed,
      _at(2),
      evidenceUsed: const [_regionRef],
      hypotheses: [
        _h('h2', 'fuse',
            confidence: const InferenceConfidence(
                value: 0.3, basis: 'provider-reported')),
        _h('h1', 'resistor'),
      ],
      statements: [
        InferenceStatement(
            statementId: 's1',
            text: 'Region 12 may be a resistor.',
            hypothesisIds: ['h1', 'h2'])
      ],
      warnings: const [InferenceDiagnostic(code: 'w', message: 'warn')],
    );

    test('V: a full record round-trips through JSON exactly', () {
      final back = InferenceRecord.fromJson(
          jsonDecode(_json(full.toJson())) as Map<String, dynamic>);
      expect(canonicalJson(back.toJson()), canonicalJson(full.toJson()));
      expect(_json(back.toJson()), _json(full.toJson()));
    });

    test(
        'U: serialization is deterministic and keeps semantic list order (no sorting of hypotheses)',
        () {
      expect(_json(full.toJson()), _json(full.toJson()));
      final hypothesisIds = (full.toJson()['hypotheses'] as List)
          .map((h) => (h as Map)['hypothesisId'])
          .toList();
      expect(hypothesisIds, ['h2', 'h1'],
          reason: 'provider order is preserved, not re-sorted');
      // Structured canonicalization ignores map insertion order but not list order.
      expect(
          canonicalJson({
            'b': 1,
            'a': [2, 1]
          }),
          canonicalJson({
            'a': [2, 1],
            'b': 1
          }));
      expect(
          canonicalJson({
            'a': [1, 2]
          }),
          isNot(canonicalJson({
            'a': [2, 1]
          })));
    });

    test('malformed or unsupported persisted data fails explicitly', () {
      Map<String, dynamic> good() =>
          jsonDecode(_json(full.toJson())) as Map<String, dynamic>;
      expect(() => InferenceRecord.fromJson({...good(), 'schemaVersion': 99}),
          throwsA(isA<FormatException>()));
      expect(
          () => InferenceRecord.fromJson({...good()}..remove('schemaVersion')),
          throwsA(isA<FormatException>()));
      expect(() => InferenceRecord.fromJson({...good(), 'status': 'exploded'}),
          throwsA(isA<FormatException>()));
      expect(() => InferenceRecord.fromJson({...good()}..remove('source')),
          throwsA(isA<FormatException>()));
      expect(() => InferenceRecord.fromJson({...good(), 'inferenceId': ''}),
          throwsA(isA<FormatException>()));
      expect(
        () => InferenceRecord.fromJson({...good(), 'completedAt': null}),
        throwsA(isA<FormatException>()),
        reason:
            'a terminal record without completedAt is invalid, not silently accepted',
      );
    });

    test(
        'optional collections missing from stored JSON resolve to empty; unknown extra keys are ignored',
        () {
      final json = jsonDecode(_json(_queued().toJson())) as Map<String, dynamic>
        ..remove('evidenceUsed')
        ..remove('hypotheses')
        ..remove('statements')
        ..remove('warnings')
        ..remove('errors')
        ..['someFutureField'] = {'x': 1};
      final r = InferenceRecord.fromJson(json);
      expect(r.hypotheses, isEmpty);
      expect(r.evidenceUsed, isEmpty);
      expect(r.warnings, isEmpty);
      expect(r.errors, isEmpty);
    });

    test(
        'AD: no vendor, secret or vault field (ReferenceUsage arrived in WP-INGEST-014)',
        () {
      final keys = <String>{};
      void walk(Object? v) {
        if (v is Map) {
          for (final e in v.entries) {
            keys.add((e.key as String).toLowerCase());
            walk(e.value);
          }
        } else if (v is List) {
          v.forEach(walk);
        }
      }

      walk(full.toJson());
      for (final banned in [
        'apikey',
        'secret',
        'token',
        'openai',
        'anthropic',
        'vault'
      ]) {
        expect(keys.where((k) => k.contains(banned)), isEmpty, reason: banned);
      }
    });
  });

  group('Successor rules (no silent overwrite)', () {
    final running = _queued().markRunning(_at(1));
    final done = running.finish(InferenceRecordStatus.completed, _at(2),
        hypotheses: [_h('hA', 'resistor')]);

    test(
        'a legal successor passes; identity/provenance changes and status regressions do not',
        () {
      expect(
          () => running
              .finish(InferenceRecordStatus.completed, _at(2))
              .requireValidSuccessorOf(running),
          returnsNormally);
      expect(
          () => done
              .withHypothesisDecision('hA', HypothesisStatus.accepted)
              .requireValidSuccessorOf(done),
          returnsNormally);
      final otherContext = InferenceRecord(
        inferenceId: 'inf-1',
        source: _source(),
        referenceContext: _ctx('different'),
        adapter: _adapter,
        queuedAt: _at(0),
        startedAt: _at(1),
        status: InferenceRecordStatus.running,
      );
      expect(() => otherContext.requireValidSuccessorOf(running),
          throwsA(isA<InferenceRecordException>()));
      expect(() => running.requireValidSuccessorOf(done),
          throwsA(isA<InferenceRecordException>()));
      final rewritten = InferenceRecord(
        inferenceId: 'inf-1',
        source: _source(),
        referenceContext: _ctx(),
        adapter: _adapter,
        queuedAt: _at(0),
        startedAt: _at(1),
        completedAt: _at(2),
        status: InferenceRecordStatus.completed,
        hypotheses: [_h('hA', 'CAPACITOR')],
      );
      expect(() => rewritten.requireValidSuccessorOf(done),
          throwsA(isA<InferenceRecordException>()),
          reason: 'a finished record\'s proposals cannot be rewritten');
    });
  });

  group('KnowledgeSessionRecord persistence (W, X, Y)', () {
    final session = KnowledgeSession(
      id: 'session-x',
      name: 'x',
      repositoryName: 'r',
      author: 'a',
      createdTime: _t0,
      lastModified: _t0,
    );

    test(
        'W: an older session with no inferenceRecords key loads with an empty collection',
        () {
      final json = KnowledgeSessionRecord(session: session).toJson()
        ..remove('inferenceRecords');
      expect(KnowledgeSessionRecord.fromJson(json).inferenceRecords, isEmpty);
    });

    test(
        'X/Y: several records (including two runs over the same context) round-trip in one session record',
        () {
      final a = _queued('inf-a', 'same-digest').markRunning(_at(1)).finish(
          InferenceRecordStatus.completed, _at(2),
          hypotheses: [_h('h', 'resistor')]);
      final b = _queued('inf-b', 'same-digest')
          .markRunning(_at(3))
          .finish(InferenceRecordStatus.failed, _at(4));
      expect(a.inferenceId, isNot(b.inferenceId));
      expect(
          a.referenceContext.contextDigest, b.referenceContext.contextDigest);
      final rec =
          KnowledgeSessionRecord(session: session, inferenceRecords: [a, b]);
      final back = KnowledgeSessionRecord.fromJson(
          jsonDecode(_json(rec.toJson())) as Map<String, dynamic>);
      expect(
          back.inferenceRecords.map((r) => r.inferenceId), ['inf-a', 'inf-b']);
      expect(back.inferenceRecords.map((r) => r.status.name),
          ['completed', 'failed']);
      expect(_json(back.toJson()), _json(rec.toJson()));
    });
  });

  group('Durable storage and interruption (real file I/O)', () {
    final created = <String>[];
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
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

    KnowledgeSession newSession() {
      final id = 'inf013-${DateTime.now().microsecondsSinceEpoch}';
      created.add(id);
      return KnowledgeSession(
          id: id,
          name: 'n',
          repositoryName: 'r',
          author: 'a',
          createdTime: _t0,
          lastModified: _t0);
    }

    test('records survive save and load, including a rejected hypothesis',
        () async {
      final s = newSession();
      final r = _queued().markRunning(_at(1)).finish(
          InferenceRecordStatus.completed, _at(2), hypotheses: [
        _h('hA', 'resistor'),
        _h('hB', 'fuse')
      ]).withHypothesisDecision('hA', HypothesisStatus.rejected,
          reason: 'symbol geometry inconsistent');
      await KnowledgeSessionStorage.save(
          KnowledgeSessionRecord(session: s, inferenceRecords: [r]));
      final loaded = await KnowledgeSessionStorage.load(s.id);
      expect(loaded.inferenceRecords.single.hypotheses.first.status,
          HypothesisStatus.rejected);
      expect(loaded.inferenceRecords.single.hypotheses.first.statusReason,
          'symbol geometry inconsistent');
    });

    test(
        'a persisted RUNNING record is reconciled to FAILED on load, durably and only once',
        () async {
      final s = newSession();
      final running = _queued().markRunning(_at(1));
      await KnowledgeSessionStorage.save(
          KnowledgeSessionRecord(session: s, inferenceRecords: [running]));
      final first =
          (await KnowledgeSessionStorage.load(s.id)).inferenceRecords.single;
      expect(first.status, InferenceRecordStatus.failed);
      expect(first.errors.single.code, InferenceRecord.interruptionCode);
      final second =
          (await KnowledgeSessionStorage.load(s.id)).inferenceRecords.single;
      expect(second.completedAt, first.completedAt,
          reason: 'reconciliation is written back once');
      expect(second.errors, hasLength(1));
    });

    test(
        'a session with only terminal inference records is not rewritten by load',
        () async {
      final s = newSession();
      final done = _queued()
          .markRunning(_at(1))
          .finish(InferenceRecordStatus.completed, _at(2));
      await KnowledgeSessionStorage.save(
          KnowledgeSessionRecord(session: s, inferenceRecords: [done]));
      final file = File(
          '${KnowledgeSessionStorage.sessionDirectory(s.id).path}${Platform.pathSeparator}session.json');
      final before = file.lastModifiedSync();
      await KnowledgeSessionStorage.load(s.id);
      expect(file.lastModifiedSync(), before);
    });
  });

  group('Notifier: store only, no promotion (Z, AA, AB, AE)', () {
    final created = <String>[];
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
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
      final id = 'inf013-n-${DateTime.now().microsecondsSinceEpoch}';
      created.add(id);
      final c = ProviderContainer(overrides: [
        foundationRuntimeServiceProvider.overrideWith(() => _Seeded(
            KnowledgeSession(
                id: id,
                name: 'n',
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
        'add/update store the record and create no candidate, entity, decision or commit report',
        () async {
      final t = start();
      final before = t.c.read(foundationRuntimeServiceProvider);
      final r = _queued().markRunning(_at(1)).finish(
          InferenceRecordStatus.completed, _at(2),
          hypotheses: [_h('hA', 'resistor')]);
      t.n.addInferenceRecord(r);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      t.n.updateInferenceRecord(
          r.withHypothesisDecision('hA', HypothesisStatus.accepted));
      final after = t.c.read(foundationRuntimeServiceProvider);
      expect(after.inferenceRecords.single.hypotheses.single.status,
          HypothesisStatus.accepted);
      // Nothing was promoted or committed.
      expect(after.candidates, before.candidates);
      expect(after.candidates, isEmpty);
      expect(after.engineeringEntities, isEmpty);
      expect(after.commitReports, isEmpty);
      expect(after.reviewDecisions, isEmpty);
      expect(after.evidenceRegions, isEmpty);
      expect(after.evidenceLinks, isEmpty);
    });

    test('a duplicate id, an unknown id and an illegal successor are refused',
        () {
      final t = start();
      final r = _queued();
      t.n.addInferenceRecord(r);
      expect(() => t.n.addInferenceRecord(r), throwsA(anything));
      expect(
          () => t.n.updateInferenceRecord(_queued('other')), throwsA(anything));
      final running = r.markRunning(_at(1));
      final done = running.finish(InferenceRecordStatus.completed, _at(2));
      expect(() => t.n.updateInferenceRecord(done), throwsA(anything),
          reason: 'QUEUED -> COMPLETED skips RUNNING');
      t.n.updateInferenceRecord(running);
      t.n.updateInferenceRecord(done);
      expect(() => t.n.updateInferenceRecord(r), throwsA(anything),
          reason: 'no regression to QUEUED');
      expect(
          t.c
              .read(foundationRuntimeServiceProvider)
              .inferenceRecords
              .single
              .status,
          InferenceRecordStatus.completed);
    });

    test(
        'records are persisted by the normal session autosave and survive a reload',
        () async {
      final t = start();
      final r = _queued().markRunning(_at(1)).finish(
          InferenceRecordStatus.completed, _at(2),
          hypotheses: [_h('hA', 'resistor')]);
      t.n.addInferenceRecord(r);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final loaded = await KnowledgeSessionStorage.load(t.id);
      expect(loaded.inferenceRecords.single.inferenceId, 'inf-1');
      // and reopening restores them into state
      final t2 = start();
      await t2.n.loadKnowledgeSessionRecord(loaded);
      expect(
          t2.c
              .read(foundationRuntimeServiceProvider)
              .inferenceRecords
              .single
              .inferenceId,
          'inf-1');
    });

    test(
        'an autosave triggered by ordinary session edits does not drop inference records',
        () async {
      final t = start();
      t.n.addInferenceRecord(_queued()
          .markRunning(_at(1))
          .finish(InferenceRecordStatus.completed, _at(2)));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      t.n.createEvidenceRegion(
          sourceId: 's', page: 1, x: 0, y: 0, width: 0.1, height: 0.1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final loaded = await KnowledgeSessionStorage.load(t.id);
      expect(loaded.inferenceRecords, hasLength(1));
      expect(loaded.evidenceRegions, hasLength(1));
    });
  });

  group('Reference Context digest (deterministic identity)', () {
    test(
        'the same context digests identically; a different query or package changes it',
        () async {
      final sources = await _realSources();
      final builder =
          DiagramInterpretationReferenceContextBuilder(reference: sources);
      ReferenceContextRequest req(String q) => ReferenceContextRequest(
            evidence: _evidence(),
            queries: [
              ReferenceContextQuery(
                  purpose: ReferenceRetrievalPurpose.symbolIdentification,
                  query: q)
            ],
          );
      final a = builder.build(req('resistor'));
      final b = builder.build(req('resistor'));
      final c = builder.build(req('ohm'));
      expect(a.digest, b.digest);
      expect(a.digest, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(a.digest, isNot(c.digest));
      expect(
          builder.build(ReferenceContextRequest(evidence: _evidence())).digest,
          isNot(a.digest));
    });
  });

  group(
      'TRX300 boundary (real compiled Reference package, deterministic test double)',
      () {
    final created = <String>[];
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
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
        'evidence -> Reference Context -> InferenceRecord retains identities, a hypothesis and a rejected alternative, and promotes nothing',
        () async {
      final sources = await _realSources();
      final evidence = _evidence();
      final context =
          DiagramInterpretationReferenceContextBuilder(reference: sources)
              .build(
        ReferenceContextRequest(
          evidence: evidence,
          queries: [
            ReferenceContextQuery(
              purpose: ReferenceRetrievalPurpose.symbolIdentification,
              query: 'resistor',
              objectTypes: const ['Symbol'],
              evidenceRegionIds: const ['region-12'],
            ),
          ],
        ),
      );
      expect(context.items.single.referenceObjectId, 'symbol.iec.resistor');

      // A deterministic stand-in for an inference adapter's OUTPUT (not a model).
      final adapterOutput = _FixtureAdapter().interpret(context);

      final sessionId = 'inf013-trx-${DateTime.now().microsecondsSinceEpoch}';
      created.add(sessionId);
      final container = ProviderContainer(overrides: [
        foundationRuntimeServiceProvider.overrideWith(() => _Seeded(
            KnowledgeSession(
                id: sessionId,
                name: 'trx',
                repositoryName: 'Repo',
                author: 'david',
                createdTime: _t0,
                lastModified: _t0))),
      ]);
      addTearDown(container.dispose);
      final notifier =
          container.read(foundationRuntimeServiceProvider.notifier);

      var record = InferenceRecord(
        inferenceId: 'inference-trx-1',
        source: InferenceSourceIdentity(
          sourceMaterialId: context.source!.id,
          sourceFingerprint: context.sourceFingerprint,
          pages: [1],
        ),
        referenceContext: InferenceReferenceContextIdentity.of(context),
        adapter: const InferenceAdapterProvenance(
            adapterId: 'fixture-adapter',
            modelName: 'deterministic-test-double',
            promptVersion: 'none'),
        queuedAt: _at(0),
      );
      // Each step is a separate autosave; pace them so overlapping fire-and-forget
      // writes (a pre-existing hazard of the unserialized storage) cannot race.
      notifier.addInferenceRecord(record);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      record = record.markRunning(_at(1));
      notifier.updateInferenceRecord(record); // the RUNNING step is durable too
      await Future<void>.delayed(const Duration(milliseconds: 200));
      record = record.finish(
        InferenceRecordStatus.completed,
        _at(2),
        evidenceUsed: adapterOutput.evidence,
        hypotheses: adapterOutput.hypotheses,
      );
      notifier.updateInferenceRecord(record);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Durable, reloaded from disk.
      final loaded = await KnowledgeSessionStorage.load(sessionId);
      final stored = loaded.inferenceRecords.single;
      // Evidence identity retained.
      expect(stored.source.sourceMaterialId, 'src-trx300');
      expect(stored.source.sourceFingerprint, 'fp-abc');
      expect(stored.evidenceUsed.map((e) => e.id), contains('region-12'));
      // Reference context identity retained (digest + real package identity).
      expect(stored.referenceContext.contextDigest, context.digest);
      expect(stored.referenceContext.reference!.packageId, 'core_reference');
      expect(stored.referenceContext.reference!.contentHash,
          context.reference!.contentHash);
      // A hypothesis and a rejected alternative are both represented.
      final accepted =
          stored.hypotheses.firstWhere((h) => h.proposedValue == 'resistor');
      expect(accepted.referenceObjectIds, ['symbol.iec.resistor']);
      final decided = stored.withHypothesisDecision(
          stored.hypotheses.last.hypothesisId, HypothesisStatus.rejected,
          reason: 'symbol geometry inconsistent');
      expect(decided.hypotheses.last.status, HypothesisStatus.rejected);
      expect(decided.hypotheses.last.proposedValue, 'fuse');

      // No repository object, candidate or engineering truth was created.
      final state = container.read(foundationRuntimeServiceProvider);
      expect(state.candidates, isEmpty);
      expect(state.engineeringEntities, isEmpty);
      expect(state.commitReports, isEmpty);
      expect(loaded.candidates, isEmpty);
      expect(loaded.commitReports, isEmpty);
      // The evidence inputs (which include a pending candidate) were not altered.
      expect(
          evidence.candidates.every((c) =>
              c.status == KnowledgeCandidateStatus.pending &&
              c.committedObjectId == null),
          isTrue);
    });
  });
}

// ---- fixtures ---------------------------------------------------------------

class _Seeded extends FoundationRuntimeNotifier {
  _Seeded(this.session);
  final KnowledgeSession session;
  @override
  FoundationServiceState build() => FoundationServiceState(
      phase: FoundationConnectionPhase.connected, knowledgeSession: session);
}

/// Test double for an inference adapter's output: maps a context to fixed
/// hypotheses. It reads the context but is not a model and interprets nothing.
class _FixtureAdapter {
  ({
    List<InferenceEvidenceReference> evidence,
    List<InferenceHypothesis> hypotheses
  }) interpret(
    DiagramInterpretationReferenceContext context,
  ) {
    final symbolId = context.items.first.referenceObjectId;
    const region = InferenceEvidenceReference(
        type: InferenceEvidenceType.evidenceRegion, id: 'region-12', page: 1);
    return (
      evidence: [
        region,
        InferenceEvidenceReference(
            type: InferenceEvidenceType.ocrPage,
            id: context.source!.id,
            page: 1),
      ],
      hypotheses: [
        InferenceHypothesis(
          hypothesisId: 'hyp-resistor',
          category: 'component',
          proposedValue: 'resistor',
          evidence: const [region],
          referenceObjectIds: [symbolId],
        ),
        InferenceHypothesis(
          hypothesisId: 'hyp-fuse',
          category: 'component',
          proposedValue: 'fuse',
          evidence: const [region],
        ),
      ],
    );
  }
}

final _source0 = SourceMaterial(
  id: 'src-trx300',
  originalFileName: 'trx300_original_pdf_diagram.pdf',
  localPath: 'C:/x/trx300.pdf',
  type: SourceMaterialType.pdf,
  sizeBytes: 185420,
  importDate: DateTime.utc(2026, 9, 19),
  addedBy: 'uif',
);

DiagramEvidenceInput _evidence() => DiagramEvidenceInput(
      source: _source0,
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
