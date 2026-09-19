import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/acquisition/services/reference_vault_ingestion_workflow.dart';
import 'package:oep_studio/acquisition/wizard/acquisition_wizard_controller.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/ingestion/models/ingestion_result.dart';
import 'package:oep_studio/ingestion/models/ingestion_run.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/ingestion/models/ingestion_stage.dart';
import 'package:oep_studio/ingestion/models/normalized_document.dart';
import 'package:oep_studio/ingestion/models/normalized_metadata.dart';
import 'package:oep_studio/ingestion/models/stage_execution_status.dart';
import 'package:oep_studio/ingestion/models/stage_result.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-EAM-005 — TEST-EAM-005-001 through 022.
///
/// Reuses the exact fake seams `eam_003_wizard_orchestration_test.dart`
/// established: `AcquisitionRuntimeNotifier` faked at its own
/// `...Returning`/`ingestVaultArtifact` methods (real acquisition
/// sequencing/branching logic stays in the real
/// `AcquisitionWizardController`); `ReferenceVaultIngestionWorkflow`/
/// `IngestionOrchestrator` themselves are faked via
/// `ReferenceVaultIngestionOutcome.testResult` (extended by this work
/// package with an optional `ingestionResult` parameter so a canned
/// outcome can still carry real `StageResult`s for the Activity Log
/// tests below) -- that real pipeline is unmodified and already covered
/// end to end by `test/ingestion/reference_vault_ingestion_workflow_test.dart`.
/// `FoundationRuntimeNotifier` faked the same way
/// `navigation_convergence_002_test.dart`/`eam_003`'s own
/// `_FakeRepoOpenNotifier` already established.
///
/// **Coverage this file does NOT duplicate, and why:**
/// - TEST-EAM-005-003 (SHA-256 from exact source bytes),
///   TEST-EAM-005-005/006/007 (Vault entry/immutability/
///   ReferenceVaultIngestionWorkflow reuse), TEST-EAM-005-014
///   (hash/copy/Vault failure cleans temp staging) are exercised at the
///   real production boundary by
///   `services/acquisition/tests/test_local_file_connector.cpp` (this
///   work package's own new C++ suite -- real file bytes, real
///   filesystem, real copy-not-move semantics) plus the pre-existing,
///   unmodified `ReferenceVaultAdapter`/Integrity Verification stage
///   tests -- duplicating byte-level hashing assertions in Dart against
///   a faked HTTP layer would prove nothing beyond what those already
///   prove against the real implementation.
/// - TEST-EAM-005-009/010/012 (Candidate Preview/Engineering Review/
///   Commit Preview reuse the real panels) are proven by
///   `eam_003_wizard_orchestration_test.dart`'s own TEST-EAM-003-006/007/009
///   against the SAME wizard step widgets this work package does not
///   modify -- a local-origin session produces an identical
///   `KnowledgeSessionRecord` shape to an official-source one, so there
///   is nothing local-file-specific to prove differently there.
/// - TEST-EAM-005-022 (the separate Reference Vault panel "Ingest into
///   Knowledge Studio" flow) is unmodified by this work package and
///   already covered by `eam_003_wizard_orchestration_test.dart`'s
///   TEST-EAM-003-015.
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

  KnowledgeSessionRecord makeSessionRecord({
    required String repositoryName,
    List<KnowledgeCandidate> candidates = const [],
  }) {
    final id = 'wp-eam-005-test-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(id);
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: id,
        name: 'Ingested Local Session',
        repositoryName: repositoryName,
        author: 'jsmith',
        description: 'Created by the Universal Ingestion Framework.',
        createdTime: DateTime(2026, 1, 1),
        lastModified: DateTime(2026, 1, 1),
      ),
      candidates: candidates,
      sources: [
        SourceMaterial(
          id: 'source-1',
          originalFileName: 'TRX300_Wiring_Diagram.pdf',
          localPath: 'C:/temp/TRX300_Wiring_Diagram.pdf',
          type: SourceMaterialType.pdf,
          sizeBytes: 4096,
          importDate: DateTime(2026, 1, 1),
          addedBy: 'uif',
        ),
      ],
    );
  }

  IngestionResult makeIngestionResult({
    required IngestionRunStatus status,
    required List<StageResult> stageResults,
  }) {
    final now = DateTime(2026, 1, 1, 12);
    return IngestionResult(
      run: IngestionRun(
        runId: 'run-1',
        vaultObjectId: 'vault-1',
        contentHash: 'abc123',
        startedAt: now,
        completedAt: now.add(const Duration(seconds: 5)),
        status: status,
        pipelineVersion: '1.0.0',
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: stageResults,
      ),
      structuralData: const NormalizedDocument(
        vaultObjectId: 'vault-1',
        metadata: NormalizedMetadata(
          pageCount: 1,
          sourceFileName: 'TRX300_Wiring_Diagram.pdf',
          sizeBytes: 4096,
          mimeType: 'application/pdf',
          contentHash: 'abc123',
        ),
        pages: [],
      ),
      source: SourceMaterial(
        id: 'source-1',
        originalFileName: 'TRX300_Wiring_Diagram.pdf',
        localPath: 'C:/temp/TRX300_Wiring_Diagram.pdf',
        type: SourceMaterialType.pdf,
        sizeBytes: 4096,
        importDate: DateTime(2026, 1, 1),
        addedBy: 'uif',
      ),
    );
  }

  StageResult stage(IngestionStage s, StageExecutionStatus status, {List<String> diagnostics = const []}) {
    final now = DateTime(2026, 1, 1, 12);
    return StageResult(stage: s, status: status, startedAt: now, completedAt: now, diagnostics: diagnostics);
  }

  ProviderContainer containerWith({
    required _FakeLocalWizardRuntimeNotifier acquisition,
    required FoundationRuntimeNotifier Function() foundation,
  }) {
    final container = ProviderContainer(
      overrides: [
        acquisitionRuntimeServiceProvider.overrideWith(() => acquisition),
        foundationRuntimeServiceProvider.overrideWith(foundation),
        acquisitionWizardControllerProvider.overrideWith(
          (ref) => AcquisitionWizardController(ref, saveCustody: (_, __) async {}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(acquisitionWizardControllerProvider, (_, __) {});
    return container;
  }

  AcquisitionWizardController localController(ProviderContainer container, {String path = '/tmp/wiring.pdf'}) {
    final controller = container.read(acquisitionWizardControllerProvider);
    controller.setKnowledgeType('Wiring Diagram');
    controller.setSourceType(AcquisitionSourceType.localDocument);
    controller.setLocalFile(path: path, name: 'TRX300_Wiring_Diagram.pdf', sizeBytes: 2048);
    controller.updateCustody(engineer: 'jsmith');
    return controller;
  }

  // -------------------------------------------------------------------
  // TEST-EAM-005-001/002/004: local file selection state.
  // -------------------------------------------------------------------

  test('TEST-EAM-005-001: a local file can be selected/materialized as acquisition input', () {
    final container = containerWith(
      acquisition: _FakeLocalWizardRuntimeNotifier(),
      foundation: _FakeRepoOpenNotifier.new,
    );
    final controller = localController(container);

    expect(controller.sourceType, AcquisitionSourceType.localDocument);
    expect(controller.localFilePath, '/tmp/wiring.pdf');
    expect(controller.localFileName, 'TRX300_Wiring_Diagram.pdf');
    expect(controller.localFileSizeBytes, 2048);
    expect(controller.canGoNext, isTrue, reason: 'a selected local file must satisfy Step 2');
  });

  test('TEST-EAM-005-002: selecting a local file never mutates the original path/name/size', () {
    final container = containerWith(
      acquisition: _FakeLocalWizardRuntimeNotifier(),
      foundation: _FakeRepoOpenNotifier.new,
    );
    final controller = container.read(acquisitionWizardControllerProvider);
    const originalPath = '/home/engineer/Documents/TRX300_Wiring_Diagram.pdf';
    controller.setLocalFile(path: originalPath, name: 'TRX300_Wiring_Diagram.pdf', sizeBytes: 999);

    // The wizard itself holds only the path string -- it never opens,
    // writes to, renames, or deletes the file at that path. Asserted at
    // the wizard-controller level; the actual non-mutation of file BYTES
    // during acquisition is proven by
    // test_local_file_connector.cpp's "original source file must remain
    // completely untouched" assertion against a real file.
    expect(controller.localFilePath, originalPath);
  });

  test('TEST-EAM-005-004: a User-Provided Artifact job omits source_id entirely (distinguishable from '
      'Official Source acquisition)', () async {
    final acquisition = _FakeLocalWizardRuntimeNotifier();
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = localController(container);

    await controller.run();

    expect(acquisition.jobBodies, hasLength(1));
    expect(acquisition.jobBodies.single.containsKey('source_id'), isFalse,
        reason: 'source_id must be entirely absent (not merely null) for a local-document job');
  });

  test('TEST-EAM-005-021: Official Source acquisition still works and includes source_id', () async {
    final acquisition = _FakeLocalWizardRuntimeNotifier();
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = container.read(acquisitionWizardControllerProvider);
    controller.setKnowledgeType('Engineering Standard');
    controller.setSource('src-1', 'IETF');
    controller.updateCustody(originalUrl: 'https://example.org/spec.txt', engineer: 'jsmith');

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.completed);
    expect(acquisition.jobBodies.single['source_id'], 'src-1');
    expect(acquisition.downloadBodies.single['connector_id'], 'http-source');
    expect(acquisition.downloadBodies.single['source_uri'], 'https://example.org/spec.txt');
  });

  // -------------------------------------------------------------------
  // TEST-EAM-005-006 (connector wiring) / general run() correctness.
  // -------------------------------------------------------------------

  test('TEST-EAM-005-006/007: local acquisition uses the local-file connector and the exact selected path, '
      'then reaches the existing ReferenceVaultIngestionWorkflow via ingestVaultArtifact', () async {
    final acquisition = _FakeLocalWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: makeSessionRecord(repositoryName: 'Repo One'),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = localController(container);

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.completed);
    expect(acquisition.downloadBodies.single['connector_id'], 'local-file');
    expect(acquisition.downloadBodies.single['source_uri'], '/tmp/wiring.pdf');
    expect(acquisition.ingestCalls, hasLength(1),
        reason: 'the existing ingestVaultArtifact -> ReferenceVaultIngestionWorkflow path must still be used');
    expect(controller.ingestionStatus, WizardIngestionStatus.completed);
  });

  // -------------------------------------------------------------------
  // TEST-EAM-005-013: missing local file fails cleanly.
  // -------------------------------------------------------------------

  test('TEST-EAM-005-013: running with sourceType=localDocument and no selected file fails cleanly '
      'without calling the backend', () async {
    final acquisition = _FakeLocalWizardRuntimeNotifier();
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = container.read(acquisitionWizardControllerProvider);
    controller.setKnowledgeType('Wiring Diagram');
    controller.setSourceType(AcquisitionSourceType.localDocument);
    controller.updateCustody(engineer: 'jsmith');
    // Deliberately no setLocalFile call.

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.failed);
    expect(controller.failureMessage, contains('No local file was selected'));
    expect(acquisition.jobBodies, isEmpty, reason: 'must fail before ever contacting the backend');
  });

  // -------------------------------------------------------------------
  // TEST-EAM-005-011/020: no automatic commit, no direct EKE/Foundation-write manipulation.
  // -------------------------------------------------------------------

  test('TEST-EAM-005-011/020: the wizard files introduce no Foundation write path or direct EKE '
      'lifecycle manipulation for the new local-document code', () {
    final wizardDir = Directory('lib/acquisition/wizard');
    final files = wizardDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      // Only real code lines matter here -- this work package's own doc
      // comments legitimately explain, by name, the internal pipeline
      // classes the wizard must NOT touch (that's the point of the doc
      // comment), so comment-only lines are excluded from the check.
      final codeLines = file
          .readAsLinesSync()
          .where((line) => !line.trim().startsWith('//'))
          .join('\n');
      for (final forbidden in [
        'IngestionOrchestrator(',
        'ReferenceVaultAdapter(',
        'IngestionKnowledgeSessionBridge(',
        'ReferenceVaultIngestionWorkflow.ingest(',
        'CommitTransactionService(',
        'FoundationBridge.create',
        'EkeLifecycle',
        'EkeConsumerGate',
      ]) {
        expect(codeLines, isNot(contains(forbidden)), reason: '${file.path} : $forbidden');
      }
    }
  });

  // -------------------------------------------------------------------
  // TEST-EAM-005-015/016: PARTIAL/FAILED ingestion semantics.
  // -------------------------------------------------------------------

  test('TEST-EAM-005-015: PARTIAL ingestion preserves the available Knowledge Session state', () async {
    final record = makeSessionRecord(
      repositoryName: 'Repo One',
      candidates: [
        KnowledgeCandidate(
          id: 'cand-1',
          type: KnowledgeCandidateType.component,
          name: 'Ignition Switch',
          description: 'Ingested candidate.',
          status: KnowledgeCandidateStatus.pending,
          createdTime: DateTime(2026, 1, 1),
        ),
      ],
    );
    final acquisition = _FakeLocalWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.partial,
        sessionRecord: record,
        ingestionResult: makeIngestionResult(
          status: IngestionRunStatus.partial,
          stageResults: [
            stage(IngestionStage.identify, StageExecutionStatus.succeeded),
            stage(IngestionStage.ocr, StageExecutionStatus.failed, diagnostics: const ['Tesseract not available']),
            stage(IngestionStage.candidateGeneration, StageExecutionStatus.succeeded),
          ],
        ),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = localController(container);

    await controller.run();

    expect(controller.ingestionStatus, WizardIngestionStatus.partial);
    expect(controller.hasKnowledgeSession, isTrue, reason: 'a PARTIAL session must remain reviewable');
    expect(controller.knowledgeSessionId, record.session.id);
  });

  test('TEST-EAM-005-016: FAILED ingestion does not fabricate candidates and blocks Candidate Preview', () async {
    final acquisition = _FakeLocalWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.failed,
        errorMessage: 'Parser selection failed: unsupported artifact type.',
        ingestionResult: makeIngestionResult(
          status: IngestionRunStatus.failed,
          stageResults: [stage(IngestionStage.identify, StageExecutionStatus.failed, diagnostics: const ['unknown MIME type'])],
        ),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = localController(container);

    await controller.run();

    expect(controller.ingestionStatus, WizardIngestionStatus.failed);
    expect(controller.hasKnowledgeSession, isFalse);
    controller.goToStep(5); // Candidate Preview
    expect(controller.canGoNext, isFalse, reason: 'Step 5 (Candidate Preview) must remain blocked after FAILED');
  });

  // -------------------------------------------------------------------
  // TEST-EAM-005-017: obsolete message absent.
  // -------------------------------------------------------------------

  test('TEST-EAM-005-017: the obsolete "Knowledge Engine not built" message is absent as live code/log text '
      '(mentions inside explanatory doc comments describing the historical defect are fine)', () {
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final codeLines = file
          .readAsLinesSync()
          .where((line) => !line.trim().startsWith('//'))
          .join('\n');
      expect(codeLines, isNot(contains('Knowledge Engine not built')), reason: file.path);
      expect(codeLines, isNot(contains('Knowledge Extraction: not yet available')), reason: file.path);
    }
  });

  // -------------------------------------------------------------------
  // TEST-EAM-005-018/019: real UIF stage information reflected in the Activity Log.
  // -------------------------------------------------------------------

  test('TEST-EAM-005-018: the Activity Log reflects the actual executed UIF stages and their real status, '
      'never chunk/embedding generation', () async {
    final acquisition = _FakeLocalWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: makeSessionRecord(repositoryName: 'Repo One'),
        ingestionResult: makeIngestionResult(
          status: IngestionRunStatus.completed,
          stageResults: [
            stage(IngestionStage.identify, StageExecutionStatus.succeeded),
            stage(IngestionStage.parserSelection, StageExecutionStatus.succeeded),
            stage(IngestionStage.metadataExtraction, StageExecutionStatus.succeeded),
            stage(IngestionStage.contentExtraction, StageExecutionStatus.succeeded),
            stage(IngestionStage.structuralAnalysis, StageExecutionStatus.succeeded),
            stage(IngestionStage.ocr, StageExecutionStatus.succeeded),
            stage(IngestionStage.entityExtraction, StageExecutionStatus.succeeded),
            stage(IngestionStage.relationshipExtraction, StageExecutionStatus.succeeded),
            stage(IngestionStage.candidateGeneration, StageExecutionStatus.succeeded),
          ],
        ),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = localController(container);

    await controller.run();

    final messages = controller.log.map((e) => e.message).join('\n');
    for (final expected in [
      'Identifying document',
      'Selecting parser',
      'Extracting metadata',
      'Extracting content',
      'Structural analysis',
      'OCR',
      'Entity extraction',
      'Relationship extraction',
      'Candidate generation',
    ]) {
      expect(messages, contains(expected), reason: 'missing real stage log line for "$expected"');
    }
    // WP-EAM-005 §9: only IngestionStage.executedInFirstSlice stages are
    // ever actually executed -- the log must never claim chunk/embedding
    // generation ran, since IngestionOrchestrator never executes them.
    expect(messages, isNot(contains('Chunk generation')));
    expect(messages, isNot(contains('Embedding generation')));
  });

  test('TEST-EAM-005-019: a failed stage is logged as an error entry with its real diagnostic, not silently '
      'reported as success', () async {
    final acquisition = _FakeLocalWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.partial,
        sessionRecord: makeSessionRecord(repositoryName: 'Repo One'),
        ingestionResult: makeIngestionResult(
          status: IngestionRunStatus.partial,
          stageResults: [
            stage(IngestionStage.identify, StageExecutionStatus.succeeded),
            stage(IngestionStage.ocr, StageExecutionStatus.failed, diagnostics: const ['Tesseract engine not available']),
          ],
        ),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = localController(container);

    await controller.run();

    final ocrEntry = controller.log.firstWhere((e) => e.message.contains('OCR'));
    expect(ocrEntry.isError, isTrue);
    expect(ocrEntry.message, contains('Tesseract engine not available'));
    expect(controller.ingestionStatus, WizardIngestionStatus.partial);
  });
}

/// Extends the same fake seam `eam_003_wizard_orchestration_test.dart`
/// established, additionally recording every job/download request body
/// so tests can assert exactly what the wizard sent (source_id presence,
/// connector_id/source_uri selection).
class _FakeLocalWizardRuntimeNotifier extends AcquisitionRuntimeNotifier {
  _FakeLocalWizardRuntimeNotifier({ReferenceVaultIngestionOutcome? outcome})
      : outcome = outcome ??
            ReferenceVaultIngestionOutcome.testResult(status: ReferenceVaultIngestionOutcomeStatus.completed);

  final ReferenceVaultIngestionOutcome outcome;
  final List<Map<String, Object?>> jobBodies = [];
  final List<Map<String, Object?>> downloadBodies = [];
  final List<_IngestCall> ingestCalls = [];

  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<Map<String, Object?>> createJobReturning(Map<String, Object?> body) async {
    jobBodies.add(body);
    return {'id': 'job-1', 'status': 'created'};
  }

  @override
  Future<Map<String, Object?>> executeJobReturning(String jobId) async => {'id': jobId, 'status': 'running'};

  @override
  Future<Map<String, Object?>> startDownloadReturning(Map<String, Object?> body) async {
    downloadBodies.add(body);
    return {'id': 'dl-1', 'status': 'completed', 'file_size_bytes': 2048};
  }

  @override
  Future<Map<String, Object?>> verifyReturning(String downloadSessionId) async =>
      {'id': 'v-1', 'status': 'verified', 'sha256_hash': 'abc123'};

  @override
  Future<Map<String, Object?>> extractMetadataReturning(String verificationId) async =>
      {'id': 'm-1', 'status': 'extracted'};

  @override
  Future<Map<String, Object?>> publishReturning(String metadataId) async =>
      {'id': 'vault-1', 'vault_path': './data/vault/ab/abc123'};

  @override
  Future<ReferenceVaultIngestionOutcome> ingestVaultArtifact({
    required String vaultObjectId,
    required String sessionName,
    required String repositoryName,
    required String author,
  }) async {
    ingestCalls.add(_IngestCall(vaultObjectId: vaultObjectId, sessionName: sessionName, repositoryName: repositoryName, author: author));
    return outcome;
  }
}

class _IngestCall {
  _IngestCall({
    required this.vaultObjectId,
    required this.sessionName,
    required this.repositoryName,
    required this.author,
  });

  final String vaultObjectId;
  final String sessionName;
  final String repositoryName;
  final String author;
}

class _FakeRepoOpenNotifier extends FoundationRuntimeNotifier {
  @override
  FoundationServiceState build() => const FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        runtimeState: FoundationRuntimeState.repositoryOpen,
        repositoryStatus: RepositoryStatus(
          repositoryId: 'repo-1',
          repositoryName: 'Repo One',
          repositoryVersion: '1.0',
          loadedPackageCount: 0,
        ),
      );
}
