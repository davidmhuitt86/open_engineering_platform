import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/ingestion/models/ingestion_run.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/ingestion/models/ingestion_stage.dart';
import 'package:oep_studio/ingestion/models/stage_execution_status.dart';
import 'package:oep_studio/ingestion/models/stage_result.dart';
import 'package:oep_studio/ingestion/services/knowledge_session_bridge.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// INGEST-FOLLOWUP-005 TEST-RECON-001 through TEST-RECON-014: makes the
/// interrupted-run reconciliation `KnowledgeSessionStorage.load` already
/// performs in memory (WP-INGEST-007 § 14/§ 35, `_reconcileInterruptedRuns`)
/// durable -- the first load that discovers an interrupted QUEUED/RUNNING
/// run must persist the reconciled FAILED record back to `session.json`,
/// so every subsequent load sees the already-reconciled record directly
/// (no re-reconciliation, no changing `completedAt`).
///
/// Follows `ingestion_execution_lifecycle_test.dart`'s own established
/// pattern for TEST-007-009/010: persist a QUEUED/RUNNING run directly
/// through the real `KnowledgeSessionStorage`, bypassing the normal
/// execution path entirely, then load through the real storage path to
/// observe reconciliation.
void main() {
  final createdSessionIds = <String>[];

  tearDown(() async {
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
    createdSessionIds.clear();
  });

  IngestionRun buildRun({
    required String runId,
    required IngestionRunStatus status,
    List<StageResult> stageResults = const [],
    List<String> diagnostics = const [],
    DateTime? completedAt,
  }) => IngestionRun(
    runId: runId,
    vaultObjectId: 'vault-object-recon',
    contentHash: 'content-hash-recon',
    startedAt: DateTime(2026, 1, 1, 8),
    completedAt: completedAt,
    status: status,
    pipelineVersion: 'uif-pipeline-1.0.0',
    parserId: 'pdf',
    parserVersion: '1.0.0',
    processorVersions: const {},
    processingConfiguration: const {},
    stageResults: stageResults,
    diagnostics: diagnostics,
  );

  Future<String> persistSession(IngestionRun run, {List<IngestionRun>? extraRuns}) async {
    final sessionId = KnowledgeSessionService.generateId('session');
    createdSessionIds.add(sessionId);
    // Builds the session directly with the full run list (rather than
    // via IngestionKnowledgeSessionBridge.mergeInto, which requires a
    // full IngestionResult) -- this test file only exercises
    // KnowledgeSessionStorage/reconciliation, not the bridge.
    final record = IngestionKnowledgeSessionBridge.createQueuedSessionRecord(
      sessionId: sessionId,
      sessionName: 'recon-test',
      repositoryName: 'repo',
      author: 'author',
      queuedRun: run,
    );
    final withAllRuns = KnowledgeSessionRecord(
      session: record.session,
      candidates: record.candidates,
      relationshipCandidates: record.relationshipCandidates,
      sources: record.sources,
      reviewDecisions: record.reviewDecisions,
      evidenceRegions: record.evidenceRegions,
      evidenceLinks: record.evidenceLinks,
      pageSelections: record.pageSelections,
      procedureSteps: record.procedureSteps,
      specificationDetails: record.specificationDetails,
      commitReports: record.commitReports,
      ocrPageResults: record.ocrPageResults,
      engineeringEntities: record.engineeringEntities,
      engineeringContexts: record.engineeringContexts,
      aiSuggestions: record.aiSuggestions,
      ingestionRuns: [run, ...?extraRuns],
      derivedArtifacts: record.derivedArtifacts,
    );
    await KnowledgeSessionStorage.save(withAllRuns);
    return sessionId;
  }

  Future<Map<String, dynamic>> readRawSessionJson(String sessionId) async {
    final file = File(
      '${KnowledgeSessionStorage.sessionDirectory(sessionId).path}${Platform.pathSeparator}session.json',
    );
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  group('TEST-RECON-001/002 interrupted runs reconcile to FAILED on load', () {
    test('TEST-RECON-001: a persisted QUEUED run loads back as FAILED', () async {
      final run = buildRun(runId: 'recon-queued-1', status: IngestionRunStatus.queued);
      final sessionId = await persistSession(run);

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.ingestionRuns.single.status, IngestionRunStatus.failed);
    });

    test('TEST-RECON-002: a persisted RUNNING run loads back as FAILED', () async {
      final run = buildRun(runId: 'recon-running-1', status: IngestionRunStatus.running);
      final sessionId = await persistSession(run);

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.ingestionRuns.single.status, IngestionRunStatus.failed);
    });
  });

  group('TEST-RECON-003 reconciliation is durable on disk', () {
    test('session.json itself contains FAILED after one load, not RUNNING/QUEUED', () async {
      final run = buildRun(runId: 'recon-durable-1', status: IngestionRunStatus.running);
      final sessionId = await persistSession(run);

      await KnowledgeSessionStorage.load(sessionId);

      final raw = await readRawSessionJson(sessionId);
      final persistedRuns = raw['ingestionRuns'] as List;
      expect(persistedRuns, hasLength(1));
      expect((persistedRuns.single as Map)['status'], 'failed');
    });
  });

  group('TEST-RECON-004/009 timestamp stability across reloads', () {
    test('TEST-RECON-004: completedAt is identical across two separate loads', () async {
      final run = buildRun(runId: 'recon-stable-1', status: IngestionRunStatus.running);
      final sessionId = await persistSession(run);

      final first = await KnowledgeSessionStorage.load(sessionId);
      final firstCompletedAt = first.ingestionRuns.single.completedAt;
      expect(firstCompletedAt, isNotNull);

      final second = await KnowledgeSessionStorage.load(sessionId);
      final secondCompletedAt = second.ingestionRuns.single.completedAt;

      expect(secondCompletedAt, firstCompletedAt);
    });
  });

  group('TEST-RECON-005 diagnostic is not duplicated across reloads', () {
    test('the interruption diagnostic appears exactly once after two loads', () async {
      final run = buildRun(runId: 'recon-diag-1', status: IngestionRunStatus.running);
      final sessionId = await persistSession(run);

      await KnowledgeSessionStorage.load(sessionId);
      final second = await KnowledgeSessionStorage.load(sessionId);

      expect(
        second.ingestionRuns.single.diagnostics.where((d) => d == IngestionRun.interruptionDiagnostic),
        hasLength(1),
      );
    });
  });

  group('TEST-RECON-006 stageResults survive reconciliation unchanged', () {
    test('existing stage results on the interrupted run are preserved exactly', () async {
      final stage = StageResult(
        stage: IngestionStage.metadataExtraction,
        status: StageExecutionStatus.succeeded,
        startedAt: DateTime(2026, 1, 1, 8, 0),
        completedAt: DateTime(2026, 1, 1, 8, 1),
        diagnostics: const ['metadata ok'],
        derivedArtifactIds: const ['artifact-1'],
      );
      final run = buildRun(
        runId: 'recon-stage-1',
        status: IngestionRunStatus.running,
        stageResults: [stage],
      );
      final sessionId = await persistSession(run);

      final loaded = await KnowledgeSessionStorage.load(sessionId);
      final persistedStage = loaded.ingestionRuns.single.stageResults.single;

      expect(persistedStage.stage, stage.stage);
      expect(persistedStage.status, stage.status);
      expect(persistedStage.startedAt, stage.startedAt);
      expect(persistedStage.completedAt, stage.completedAt);
      expect(persistedStage.diagnostics, stage.diagnostics);
      expect(persistedStage.derivedArtifactIds, stage.derivedArtifactIds);
    });
  });

  group('TEST-RECON-007 terminal-only sessions are untouched', () {
    test('a session with only COMPLETED/PARTIAL/FAILED/CANCELLED runs is unchanged by load', () async {
      final terminalRuns = [
        buildRun(runId: 'recon-term-completed', status: IngestionRunStatus.completed, completedAt: DateTime(2026, 1, 2)),
        buildRun(runId: 'recon-term-partial', status: IngestionRunStatus.partial, completedAt: DateTime(2026, 1, 2)),
        buildRun(runId: 'recon-term-failed', status: IngestionRunStatus.failed, completedAt: DateTime(2026, 1, 2)),
        buildRun(runId: 'recon-term-cancelled', status: IngestionRunStatus.cancelled, completedAt: DateTime(2026, 1, 2)),
      ];
      final sessionId = await persistSession(terminalRuns.first, extraRuns: terminalRuns.skip(1).toList());

      final rawBefore = await readRawSessionJson(sessionId);
      final fileBefore = File(
        '${KnowledgeSessionStorage.sessionDirectory(sessionId).path}${Platform.pathSeparator}session.json',
      );
      final modifiedBefore = fileBefore.lastModifiedSync();

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.ingestionRuns.map((r) => r.status).toList(), [
        IngestionRunStatus.completed,
        IngestionRunStatus.partial,
        IngestionRunStatus.failed,
        IngestionRunStatus.cancelled,
      ]);
      final rawAfter = await readRawSessionJson(sessionId);
      expect(rawAfter, rawBefore, reason: 'load must not rewrite a session with only terminal runs');
      expect(fileBefore.lastModifiedSync(), modifiedBefore, reason: 'no write should occur at all');
    });
  });

  group('TEST-RECON-008/009 mixed sessions reconcile only non-terminal runs, preserving order', () {
    test('a terminal run and a RUNNING run: only the RUNNING one reconciles, list order unchanged', () async {
      final completed = buildRun(
        runId: 'recon-mixed-completed',
        status: IngestionRunStatus.completed,
        completedAt: DateTime(2026, 1, 2),
      );
      final running = buildRun(runId: 'recon-mixed-running', status: IngestionRunStatus.running);
      final sessionId = await persistSession(completed, extraRuns: [running]);

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      // TEST-RECON-009: original order preserved (completed first, then
      // the reconciled run in its original position), not reordered.
      expect(loaded.ingestionRuns.map((r) => r.runId).toList(), ['recon-mixed-completed', 'recon-mixed-running']);
      // TEST-RECON-008: only the non-terminal run was touched.
      final reloadedCompleted = loaded.ingestionRuns.firstWhere((r) => r.runId == 'recon-mixed-completed');
      expect(reloadedCompleted.status, IngestionRunStatus.completed);
      expect(reloadedCompleted.diagnostics, isEmpty);
      final reloadedRunning = loaded.ingestionRuns.firstWhere((r) => r.runId == 'recon-mixed-running');
      expect(reloadedRunning.status, IngestionRunStatus.failed);
      expect(reloadedRunning.diagnostics, contains(IngestionRun.interruptionDiagnostic));
    });
  });

  group('TEST-RECON-010 durability survives a genuinely fresh load', () {
    test('after reconciliation, a brand-new load call still returns the persisted FAILED state', () async {
      final run = buildRun(runId: 'recon-fresh-1', status: IngestionRunStatus.queued);
      final sessionId = await persistSession(run);

      await KnowledgeSessionStorage.load(sessionId); // first load persists reconciliation

      // A completely separate, later load call -- nothing shared in
      // memory with the call above except the sessionId, simulating a
      // fresh application start reading the file anew.
      final freshLoad = await KnowledgeSessionStorage.load(sessionId);
      expect(freshLoad.ingestionRuns.single.status, IngestionRunStatus.failed);

      final raw = await readRawSessionJson(sessionId);
      expect((raw['ingestionRuns'] as List).single, isA<Map>());
      expect(((raw['ingestionRuns'] as List).single as Map)['status'], 'failed');
    });
  });

  group('TEST-RECON-011/012 no automatic resume or retry', () {
    test('reconciliation never creates a new runId and never re-executes any stage', () async {
      final run = buildRun(runId: 'recon-no-retry-1', status: IngestionRunStatus.running);
      final sessionId = await persistSession(run);

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      // TEST-RECON-011/012: exactly one run, same runId, no stage
      // results were fabricated by reconciliation (still empty, as
      // originally persisted -- reconciliation never invokes any stage
      // or orchestrator).
      expect(loaded.ingestionRuns, hasLength(1));
      expect(loaded.ingestionRuns.single.runId, 'recon-no-retry-1');
      expect(loaded.ingestionRuns.single.stageResults, isEmpty);
    });
  });

  group('TEST-RECON-013 no Reference Vault / network access during reconciliation', () {
    test('reconciling a session touches no HTTP-capable object -- pure local file I/O', () async {
      // No AcquisitionApiClient, no http.Client, no MockClient is
      // constructed anywhere in this test file at all; reconciliation
      // is exercised purely through KnowledgeSessionStorage, which only
      // imports dart:io/dart:convert and the KnowledgeSessionRecord
      // model (see the source file's own imports). If reconciliation
      // ever needed network access, this session (with no server, no
      // client, no baseUrl configured anywhere in this test) would hang
      // or throw rather than complete.
      final run = buildRun(runId: 'recon-no-network-1', status: IngestionRunStatus.running);
      final sessionId = await persistSession(run);

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.ingestionRuns.single.status, IngestionRunStatus.failed);

      final source = await File(
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}knowledge'
        '${Platform.pathSeparator}services${Platform.pathSeparator}knowledge_session_storage.dart',
      ).readAsString();
      final importLines = source.split('\n').where((line) => line.trim().startsWith('import '));
      for (final line in importLines) {
        expect(line, isNot(contains('http')));
        expect(line, isNot(contains('acquisition_api_client')));
      }
    });
  });

  group('TEST-RECON-014 no Engineering Repository write during reconciliation', () {
    test('reconciliation never imports/invokes repository commit infrastructure', () async {
      final source = await File(
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}knowledge'
        '${Platform.pathSeparator}services${Platform.pathSeparator}knowledge_session_storage.dart',
      ).readAsString();
      final importLines = source.split('\n').where((line) => line.trim().startsWith('import '));
      for (final line in importLines) {
        expect(line, isNot(contains('commit_transaction_service')));
        expect(line, isNot(contains('commit_plan_service')));
        expect(line, isNot(contains('foundation_bridge')));
      }

      final run = buildRun(runId: 'recon-no-repo-1', status: IngestionRunStatus.running);
      final sessionId = await persistSession(run);

      final loaded = await KnowledgeSessionStorage.load(sessionId);

      expect(loaded.commitReports, isEmpty);
    });
  });
}
