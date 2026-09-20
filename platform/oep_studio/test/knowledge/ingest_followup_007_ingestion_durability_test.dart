import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/knowledge/inference/inference_record.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// INGEST-FOLLOWUP-007: durable ingestion state (`ingestionRuns`,
/// `derivedArtifacts`, `normalizedProducts`) must survive
/// load -> runtime state -> autosave -> reload. The baseline is
/// `test/fixtures/trx300_ingested_session.json`: a real persisted TRX300
/// ingestion session (1 completed run, 3 derived artifacts, 1 normalized
/// product, 1 OCR page), with only its local file path generalized.
const _fixturePath = 'test/fixtures/trx300_ingested_session.json';
const _realSessionId = 'session-1789772545045-0fb6';
const _sourceId = 'source-fd7f4474f5a94ab4';

Map<String, dynamic> _fixture() =>
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _clone(Object? o) =>
    jsonDecode(jsonEncode(o)) as Map<String, dynamic>;

String _enc(Iterable<Object?> items) => jsonEncode(items.toList());

/// The three collections exactly as a record serializes them.
Map<String, String> _ingestion(KnowledgeSessionRecord r) => {
      'runs': _enc(r.ingestionRuns.map((x) => x.toJson())),
      'artifacts': _enc(r.derivedArtifacts.map((x) => x.toJson())),
      'products': _enc(r.normalizedProducts.map((x) => x.toJson())),
    };

void main() {
  final createdIds = <String>[];

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final id in createdIds) {
      final dir = KnowledgeSessionStorage.sessionDirectory(id);
      for (var i = 0; i < 10 && dir.existsSync(); i++) {
        try {
          await dir.delete(recursive: true);
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    createdIds.clear();
  });

  /// Writes [json] as a disposable session with a fresh id and returns the
  /// record it parses to. The original data is never modified.
  Future<KnowledgeSessionRecord> install(Map<String, dynamic> json) async {
    final id = 'inf-followup-007-${DateTime.now().microsecondsSinceEpoch}';
    createdIds.add(id);
    final copy = _clone(json);
    (copy['session'] as Map<String, dynamic>)['id'] = id;
    final record = KnowledgeSessionRecord.fromJson(copy);
    await KnowledgeSessionStorage.save(record);
    return record;
  }

  ({ProviderContainer c, FoundationRuntimeNotifier n}) start() {
    final c = ProviderContainer(overrides: [
      foundationRuntimeServiceProvider.overrideWith(() => _Base()),
    ]);
    addTearDown(c.dispose);
    return (c: c, n: c.read(foundationRuntimeServiceProvider.notifier));
  }

  FoundationServiceState stateOf(ProviderContainer c) =>
      c.read(foundationRuntimeServiceProvider);

  // One unrelated mutation (a spatial evidence region) -> exactly one autosave.
  Future<void> unrelatedMutationAndAutosave(FoundationRuntimeNotifier n) async {
    n.createEvidenceRegion(
        sourceId: _sourceId, page: 1, x: 0.1, y: 0.1, width: 0.1, height: 0.1);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  group('Load into runtime state (A, B, C)', () {
    test(
        'A/B/C: opening a session with ingestion data puts every collection into state, exactly',
        () async {
      final record = await install(_fixture());
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      final s = stateOf(t.c);
      expect(s.ingestionRuns.length, 1);
      expect(s.derivedArtifacts.length, 3);
      expect(s.normalizedProducts.length, 1);
      expect(_enc(s.ingestionRuns.map((x) => x.toJson())),
          _ingestion(record)['runs']);
      expect(_enc(s.derivedArtifacts.map((x) => x.toJson())),
          _ingestion(record)['artifacts']);
      expect(_enc(s.normalizedProducts.map((x) => x.toJson())),
          _ingestion(record)['products']);
    });

    test(
        'loadKnowledgeSessionRecord (the post-ingestion hand-off) also carries them',
        () async {
      final record = await install(_fixture());
      final t = start();
      await t.n.loadKnowledgeSessionRecord(record);
      final s = stateOf(t.c);
      expect((
        s.ingestionRuns.length,
        s.derivedArtifacts.length,
        s.normalizedProducts.length
      ), (
        1,
        3,
        1
      ));
    });
  });

  group('Autosave preserves durable ingestion state (D, E, F, G)', () {
    test(
        'D/E/F/G: load -> unrelated mutation -> autosave -> reload keeps all three collections byte-for-byte',
        () async {
      final record = await install(_fixture());
      final before = _ingestion(record);
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      await unrelatedMutationAndAutosave(t.n);

      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(reloaded.evidenceRegions, hasLength(1),
          reason: 'the autosave really happened');
      expect(_ingestion(reloaded), before);
      // artifact fields survive unchanged
      final a = reloaded.derivedArtifacts.first;
      expect((
        a.runId,
        a.vaultObjectId,
        a.stage.name,
        a.artifactType,
        a.contentHash,
        a.processorId,
        a.processorVersion
      ), (
        record.derivedArtifacts.first.runId,
        record.derivedArtifacts.first.vaultObjectId,
        record.derivedArtifacts.first.stage.name,
        record.derivedArtifacts.first.artifactType,
        record.derivedArtifacts.first.contentHash,
        record.derivedArtifacts.first.processorId,
        record.derivedArtifacts.first.processorVersion
      ));
      expect(reloaded.normalizedProducts.single.runId,
          record.normalizedProducts.single.runId);
      expect(reloaded.normalizedProducts.single.derivedArtifactId,
          record.normalizedProducts.single.derivedArtifactId);
    });

    test('repeated autosaves (several unrelated mutations) never erase them',
        () async {
      final record = await install(_fixture());
      final before = _ingestion(record);
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      await unrelatedMutationAndAutosave(t.n);
      await unrelatedMutationAndAutosave(t.n);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(reloaded.evidenceRegions, hasLength(2));
      expect(_ingestion(reloaded), before);
    });

    test(
        'close and reopen keeps them (state is a projection of the durable record)',
        () async {
      final record = await install(_fixture());
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      t.n.closeKnowledgeSession();
      expect(stateOf(t.c).ingestionRuns, isEmpty,
          reason: 'closing clears the projection, not the durable record');
      await t.n.openKnowledgeSession(record.session.id);
      expect(_enc(stateOf(t.c).ingestionRuns.map((x) => x.toJson())),
          _ingestion(record)['runs']);
      expect(
          (await KnowledgeSessionStorage.load(record.session.id)).ingestionRuns,
          hasLength(1));
    });
  });

  group('Multiple records (H, I, J)', () {
    Map<String, dynamic> multi() {
      final j = _fixture();
      final run = _clone((j['ingestionRuns'] as List).single);
      final run2 = _clone(run)
        ..['runId'] = 'run-second'
        ..['vaultObjectId'] = 'vault-object-other'
        ..['status'] = 'partial';
      final run3 = _clone(run)
        ..['runId'] = 'run-third'
        ..['status'] = 'failed';
      final artifacts = [
        for (final a in j['derivedArtifacts'] as List) _clone(a)
      ];
      final artifacts2 = [
        for (final a in artifacts)
          _clone(a)
            ..['derivedArtifactId'] = '${a['derivedArtifactId']}-b'
            ..['runId'] = 'run-second'
            ..['vaultObjectId'] = 'vault-object-other',
      ];
      final product = _clone((j['normalizedProducts'] as List).single);
      final product2 = _clone(product)
        ..['runId'] = 'run-second'
        ..['derivedArtifactId'] = '${product['derivedArtifactId']}-b';
      j['ingestionRuns'] = [run, run2, run3];
      j['derivedArtifacts'] = [...artifacts, ...artifacts2];
      j['normalizedProducts'] = [product, product2];
      return j;
    }

    test(
        'H/I/J: several runs, artifacts and products (different vault objects) survive, in order',
        () async {
      final record = await install(multi());
      expect((
        record.ingestionRuns.length,
        record.derivedArtifacts.length,
        record.normalizedProducts.length
      ), (
        3,
        6,
        2
      ));
      final before = _ingestion(record);
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      await unrelatedMutationAndAutosave(t.n);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(_ingestion(reloaded), before);
      expect(reloaded.ingestionRuns.map((r) => r.runId),
          record.ingestionRuns.map((r) => r.runId).toList());
      expect(reloaded.ingestionRuns.map((r) => r.status.name),
          ['completed', 'partial', 'failed']);
      expect(reloaded.derivedArtifacts.map((a) => a.derivedArtifactId),
          record.derivedArtifacts.map((a) => a.derivedArtifactId).toList());
    });
  });

  group('Legacy and empty sessions (K)', () {
    test(
        'K: a session with none of the three keys loads with empty collections and still autosaves cleanly',
        () async {
      final j = _fixture()
        ..remove('ingestionRuns')
        ..remove('derivedArtifacts')
        ..remove('normalizedProducts')
        ..remove('inferenceRecords');
      final record = await install(j);
      expect(
          (
            record.ingestionRuns,
            record.derivedArtifacts,
            record.normalizedProducts
          ).toString(),
          '([], [], [])');
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      expect(stateOf(t.c).ingestionRuns, isEmpty);
      await unrelatedMutationAndAutosave(t.n);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(reloaded.ingestionRuns, isEmpty);
      expect(reloaded.evidenceRegions, hasLength(1));
    });
  });

  group('Alongside InferenceRecords (L, M)', () {
    test(
        'L/M: ingestion data and inference records both survive an autosave, inference records unchanged',
        () async {
      final inference = InferenceRecord(
        inferenceId: 'inf-1',
        source: InferenceSourceIdentity(
            sourceMaterialId: _sourceId, sourceFingerprint: 'fp', pages: [1]),
        referenceContext:
            const InferenceReferenceContextIdentity(contextDigest: 'digest'),
        adapter: const InferenceAdapterProvenance(adapterId: 'test-double'),
        queuedAt: DateTime.utc(2026, 9, 20, 9),
      ).markRunning(DateTime.utc(2026, 9, 20, 9, 1)).finish(
          InferenceRecordStatus.completed, DateTime.utc(2026, 9, 20, 9, 2));
      final j = _fixture()..['inferenceRecords'] = [inference.toJson()];
      final record = await install(j);
      final before = _ingestion(record);
      final inferenceBefore =
          jsonEncode(record.inferenceRecords.map((r) => r.toJson()).toList());
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      await unrelatedMutationAndAutosave(t.n);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(_ingestion(reloaded), before);
      expect(
          jsonEncode(reloaded.inferenceRecords.map((r) => r.toJson()).toList()),
          inferenceBefore);
    });
  });

  group('Lifecycle and reconciliation untouched (N, O)', () {
    test('O: run statuses are exactly what was persisted after the round trip',
        () async {
      final record = await install(_fixture());
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      await unrelatedMutationAndAutosave(t.n);
      final run = (await KnowledgeSessionStorage.load(record.session.id))
          .ingestionRuns
          .single;
      expect(run.status, IngestionRunStatus.completed);
      expect(run.completedAt, record.ingestionRuns.single.completedAt);
      expect(run.processingIdentity,
          record.ingestionRuns.single.processingIdentity);
    });

    test(
        'N: an interrupted RUNNING run is reconciled to FAILED once on load, and that survives autosave and reload',
        () async {
      final j = _fixture();
      final run = (j['ingestionRuns'] as List).single as Map<String, dynamic>
        ..['status'] = 'running'
        ..['completedAt'] = null;
      expect(run['status'], 'running');
      final record = await install(j);
      final t = start();
      await t.n.openKnowledgeSession(
          record.session.id); // load() reconciles and writes back
      final inState = stateOf(t.c).ingestionRuns.single;
      expect(inState.status, IngestionRunStatus.failed);
      expect(inState.diagnostics,
          contains('Execution interrupted before completion.'));
      await unrelatedMutationAndAutosave(t.n);
      final reloaded = (await KnowledgeSessionStorage.load(record.session.id))
          .ingestionRuns
          .single;
      expect(reloaded.status, IngestionRunStatus.failed);
      expect(
          reloaded.diagnostics
              .where((d) => d == 'Execution interrupted before completion.'),
          hasLength(1));
      expect(reloaded.completedAt, inState.completedAt);
    });
  });

  group('Archive path (P) and no promotion (Q)', () {
    test(
        'P: archiving (which rebuilds the record) preserves all three collections',
        () async {
      final record = await install(_fixture());
      final before = _ingestion(record);
      final t = start();
      await t.n.setKnowledgeSessionArchived(record.session.id, archived: true);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(reloaded.session.archived, isTrue);
      expect(_ingestion(reloaded), before);
    });

    test(
        'Q: none of this creates candidates, entities, review decisions, commits or Repository state',
        () async {
      final record = await install(_fixture());
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      await unrelatedMutationAndAutosave(t.n);
      final s = stateOf(t.c);
      expect(s.candidates, isEmpty);
      expect(s.engineeringEntities, isEmpty);
      expect(s.reviewDecisions, isEmpty);
      expect(s.commitReports, isEmpty);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(reloaded.candidates, isEmpty);
      expect(reloaded.commitReports, isEmpty);
    });
  });

  group('Real TRX300 persisted session (local copy; original never modified)',
      () {
    final realFile = File(
      '${KnowledgeSessionStorage.sessionDirectory(_realSessionId).path}${Platform.pathSeparator}session.json',
    );

    test(
        'a real TRX300 ingestion session round-trips through load -> unrelated change -> autosave -> reload',
        () async {
      final originalBytes = realFile.readAsBytesSync();
      final j = jsonDecode(utf8.decode(originalBytes)) as Map<String, dynamic>;
      final record = await install(j);
      expect(record.ingestionRuns, isNotEmpty,
          reason: 'sanity: the real session still holds its ingestion data');
      final before = _ingestion(record);
      final t = start();
      await t.n.openKnowledgeSession(record.session.id);
      await unrelatedMutationAndAutosave(t.n);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(_ingestion(reloaded), before);
      expect(realFile.readAsBytesSync(), originalBytes,
          reason: 'the original session file is untouched');
    },
        skip: realFile.existsSync()
            ? false
            : 'the local real TRX300 session is not present on this machine');
  });
}

class _Base extends FoundationRuntimeNotifier {
  @override
  FoundationServiceState build() =>
      const FoundationServiceState(phase: FoundationConnectionPhase.connected);
}
