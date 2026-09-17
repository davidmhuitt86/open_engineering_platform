import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// `FoundationRuntimeNotifier.loadKnowledgeSessionRecord` — WP-INGEST-004's
/// hand-off point from the Reference Vault ingestion workflow into the
/// existing Knowledge Curation Session lifecycle (Work Package 008).
/// Mirrors `foundation_refresh_repository_test.dart`'s `_pumpRef` helper
/// for a live `WidgetRef` with no Foundation Bridge DLL required — this
/// method, like `createKnowledgeSession`/`openKnowledgeSession`, touches
/// only Riverpod state and `KnowledgeSessionStorage`, never the Bridge.
///
/// Exercises real `dart:io` file access against
/// `KnowledgeSessionStorage.root()`, matching
/// `knowledge_session_storage_test.dart`'s own established convention:
/// every session created here uses a `wp-ingest-004-test-` prefixed ID
/// and is deleted in `tearDown`.
Future<WidgetRef> _pumpRef(WidgetTester tester) async {
  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          capturedRef = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return capturedRef;
}

void main() {
  final createdSessionIds = <String>[];

  KnowledgeSessionRecord makeRecord({String? id}) {
    final sessionId = id ?? 'wp-ingest-004-test-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(sessionId);
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: sessionId,
        name: 'Ingested Session',
        repositoryName: 'demo-repo',
        author: 'uif',
        description: 'Created by the Universal Ingestion Framework.',
        createdTime: DateTime(2026, 1, 1),
        lastModified: DateTime(2026, 1, 1),
      ),
      candidates: [
        KnowledgeCandidate(
          id: 'candidate-1',
          type: KnowledgeCandidateType.component,
          name: 'Timing Cover Bolt',
          description: 'Ingested candidate.',
          status: KnowledgeCandidateStatus.pending,
          createdTime: DateTime(2026, 1, 1),
        ),
      ],
      sources: [
        SourceMaterial(
          id: 'source-1',
          originalFileName: 'artifact.pdf',
          localPath: 'C:/temp/artifact.pdf',
          type: SourceMaterialType.pdf,
          sizeBytes: 1024,
          importDate: DateTime(2026, 1, 1),
          addedBy: 'uif',
        ),
      ],
    );
  }

  tearDown(() async {
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
    createdSessionIds.clear();
  });

  testWidgets('loads the record into active state and persists it', (tester) async {
    final ref = await _pumpRef(tester);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final record = makeRecord();

    // `loadKnowledgeSessionRecord` performs real `dart:io` file writes
    // (`KnowledgeSessionStorage.save`). `testWidgets` runs the test body
    // inside `flutter_test`'s fake-async zone, where real OS-level I/O
    // callbacks never fire -- every real `dart:io` call in a widget test
    // must run inside `tester.runAsync` or it hangs indefinitely (it did,
    // until this fix: the first version of this test wedged the whole
    // suite for 10 minutes per run before timing out). Matches how
    // `foundation_refresh_repository_test.dart`'s own `_pumpRef` pattern
    // never needed this, since `refreshRepository()` performs no real I/O
    // without a Foundation Bridge DLL loaded.
    await tester.runAsync(() async {
      await notifier.loadKnowledgeSessionRecord(record);
    });

    final state = ref.read(foundationRuntimeServiceProvider);
    expect(state.knowledgeSession?.id, record.session.id);
    expect(state.knowledgeSession?.name, 'Ingested Session');
    expect(state.candidates, record.candidates);
    expect(state.sourceMaterials, record.sources);

    // Persisted immediately, exactly like `createKnowledgeSession`'s own
    // autosave contract (Work Package 008: "Sessions shall survive
    // application restart").
    final reloaded = await tester.runAsync(() => KnowledgeSessionStorage.load(record.session.id));
    expect(reloaded!.session.id, record.session.id);
    expect(reloaded.candidates, hasLength(1));
  });

  testWidgets('replaces a currently active session rather than merging into it', (tester) async {
    final ref = await _pumpRef(tester);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);

    notifier.createKnowledgeSession(name: 'Manually Created', repositoryName: 'demo-repo', author: 'engineer');
    createdSessionIds.add(ref.read(foundationRuntimeServiceProvider).knowledgeSession!.id);
    expect(ref.read(foundationRuntimeServiceProvider).knowledgeSession?.name, 'Manually Created');

    final ingestedRecord = makeRecord();
    // See the real-`dart:io`/`tester.runAsync` note in the previous test
    // -- `createKnowledgeSession` above is real I/O too (it triggers
    // `_persistActiveSession`'s `unawaited` save), but it is fire-and-
    // forget and not awaited here, so it never blocked the fake-async
    // zone the way an *awaited* real I/O call does.
    await tester.runAsync(() async {
      await notifier.loadKnowledgeSessionRecord(ingestedRecord);
    });

    // The same explicit-replacement contract `createKnowledgeSession`/
    // `openKnowledgeSession` already have (Work Package 008) — the
    // manually created session is no longer active, but it was never
    // silently destroyed: it is still durable on disk (autosaved when
    // created) and reachable via the Session Browser like any other
    // closed session.
    final state = ref.read(foundationRuntimeServiceProvider);
    expect(state.knowledgeSession?.id, ingestedRecord.session.id);
    expect(state.knowledgeSession?.name, 'Ingested Session');
  });
}
