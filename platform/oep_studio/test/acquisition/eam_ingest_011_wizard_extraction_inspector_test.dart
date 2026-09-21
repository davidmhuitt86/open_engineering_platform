import 'dart:io';

import 'package:oep_studio/knowledge/models/document_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/acquisition/services/reference_vault_ingestion_workflow.dart';
import 'package:oep_studio/acquisition/wizard/acquisition_wizard_controller.dart';
import 'package:oep_studio/acquisition/wizard/steps/wizard_step_candidate_preview.dart';
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
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-011 test list (8 items). Reuses the exact fake seams
/// `eam_003_wizard_orchestration_test.dart` already established
/// (`AcquisitionRuntimeNotifier` faked at its own `...Returning`/
/// `ingestVaultArtifact` methods; `FoundationRuntimeNotifier` faked only
/// at `build()`) so no native Foundation Bridge DLL is required.
///
/// **Does not pump the real `ExtractionInspectorDialog`/`PdfViewer`.**
/// No test anywhere in this codebase renders a real `pdfrx` `PdfViewer`
/// against a fake/nonexistent file path (confirmed by search) -- doing so
/// here would be exactly the "artificial PDF rendering harness" this
/// work package's own instructions say to avoid when impractical. Item 5
/// ("the action invokes the existing showExtractionInspectorDialog") is
/// instead verified at the source level: the wizard step's own source
/// must call that exact, existing function -- proving the wiring without
/// needing the dialog's PDF content to actually render.
void main() {
  final createdSessionIds = <String>[];

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
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
    List<OcrPageResult> ocrPageResults = const [],
  }) {
    final id = 'wp-ingest-011-test-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(id);
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: id,
        name: 'Ingested Session',
        repositoryName: repositoryName,
        author: 'jsmith',
        description: 'Created by the Universal Ingestion Framework.',
        createdTime: DateTime(2026, 1, 1),
        lastModified: DateTime(2026, 1, 1),
      ),
      candidates: candidates,
      ocrPageResults: ocrPageResults,
      sources: [
        SourceMaterial(
          id: 'source-trx300',
          originalFileName: 'trx300_factory_wiring_diagram.pdf',
          localPath: 'C:/temp/trx300_factory_wiring_diagram.pdf',
          type: SourceMaterialType.pdf,
          sizeBytes: 185420,
          importDate: DateTime(2026, 1, 1),
          addedBy: 'uif',
        ),
      ],
    );
  }

  /// Mirrors the real TRX300 run's own shape: OCR produced words, entity
  /// extraction and candidate generation both produced nothing.
  IngestionResult makeZeroEntityIngestionResult() {
    final now = DateTime(2026, 1, 1, 12);
    return IngestionResult(
      run: IngestionRun(
        runId: 'run-1',
        vaultObjectId: 'vault-1',
        contentHash: 'fd7f4474f5a94ab4',
        startedAt: now,
        completedAt: now,
        status: IngestionRunStatus.completed,
        pipelineVersion: '1.0.0',
        parserId: 'uif.pdf_parser',
        parserVersion: '1.0.0',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: [
          StageResult(stage: IngestionStage.ocr, status: StageExecutionStatus.succeeded, startedAt: now, completedAt: now),
          StageResult(
              stage: IngestionStage.entityExtraction,
              status: StageExecutionStatus.skipped,
              startedAt: now,
              completedAt: now,
              diagnostics: const ['extracted=0']),
        ],
      ),
      structuralData: const NormalizedDocument(
        vaultObjectId: 'vault-1',
        metadata: NormalizedMetadata(
          pageCount: 1,
          sourceFileName: 'trx300_factory_wiring_diagram.pdf',
          sizeBytes: 185420,
          mimeType: 'application/pdf',
          contentHash: 'fd7f4474f5a94ab4',
        ),
        pages: [],
      ),
      source: SourceMaterial(
        id: 'source-trx300',
        originalFileName: 'trx300_factory_wiring_diagram.pdf',
        localPath: 'C:/temp/trx300_factory_wiring_diagram.pdf',
        type: SourceMaterialType.pdf,
        sizeBytes: 185420,
        importDate: DateTime(2026, 1, 1),
        addedBy: 'uif',
      ),
    );
  }

  OcrPageResult makeTrx300OcrResult() => OcrPageResult(
        sourceId: 'source-trx300',
        page: 1,
        words: const [
          OcrWord(
            text: 'WIRING',
            confidence: 0.96,
            boundingBox: OcrBoundingBox(x: 0.01, y: 0.24, width: 0.03, height: 0.12),
            readingOrder: 0,
            lineIndex: 0,
          ),
        ],
        imageWidth: 3300,
        imageHeight: 2550,
        sourceFingerprint: 'fd7f4474f5a94ab4',
        engineVersion: 'Tesseract v5.4.0.20240606',
        processedTime: DateTime(2026, 1, 1),
        success: true,
      );

  ProviderContainer containerWith({
    required _FakeWizardRuntimeNotifier acquisition,
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

  AcquisitionWizardController readyController(ProviderContainer container) {
    final controller = container.read(acquisitionWizardControllerProvider);
    controller.setKnowledgeType('Wiring Diagram');
    controller.setSource('src-1', 'Factory Manual');
    controller.updateCustody(originalUrl: 'https://example.org/trx300.pdf', engineer: 'jsmith');
    return controller;
  }

  Widget hostedIn(ProviderContainer container, AcquisitionWizardController controller) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: WizardStepCandidatePreview(controller: controller))),
    );
  }

  // -------------------------------------------------------------------
  // Item 8: static wiring/no-second-mechanism checks.
  // -------------------------------------------------------------------

  test('item 8: the wizard step calls the existing showExtractionInspectorDialog, introduces no new provider/'
      'state model/session loader/persistence mechanism, and does not modify ExtractionInspectorDialog', () {
    final stepSource = File('lib/acquisition/wizard/steps/wizard_step_candidate_preview.dart').readAsStringSync();
    expect(stepSource, contains('showExtractionInspectorDialog('), reason: 'must call the existing API');
    expect(stepSource, contains('controller.ingestedSource'), reason: 'must use the existing session-record data');
    for (final forbidden in [
      'Provider<',
      'StateNotifier',
      'KnowledgeSessionStorage.load',
      '_persistActiveSession',
      'showDialog<void>(', // a second, hand-rolled dialog rather than the existing helper
    ]) {
      expect(stepSource, isNot(contains(forbidden)), reason: forbidden);
    }

    // The Inspector itself must remain untouched -- this WP's own scope.
    final inspectorSource = File('lib/knowledge/workspaces/extraction_inspector_dialog.dart').readAsStringSync();
    expect(inspectorSource, contains('Future<void> showExtractionInspectorDialog('),
        reason: 'the existing public API signature must be unchanged');
  });

  // -------------------------------------------------------------------
  // Items 1/2/3: COMPLETE / PARTIAL / FAILED availability.
  // -------------------------------------------------------------------

  testWidgets('item 1: COMPLETE ingestion exposes an enabled Inspect Extraction action', (tester) async {
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: makeSessionRecord(repositoryName: 'Repo One'),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await tester.runAsync(() => controller.run());

    await tester.pumpWidget(hostedIn(container, controller));

    final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Inspect Extraction'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('item 2: PARTIAL ingestion exposes an enabled Inspect Extraction action', (tester) async {
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.partial,
        sessionRecord: makeSessionRecord(repositoryName: 'Repo One'),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await tester.runAsync(() => controller.run());

    await tester.pumpWidget(hostedIn(container, controller));

    final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Inspect Extraction'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('item 3: FAILED ingestion does not expose Inspect Extraction at all', (tester) async {
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.failed,
        errorMessage: 'boom',
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await controller.run();

    await tester.pumpWidget(hostedIn(container, controller));

    expect(find.widgetWithText(OutlinedButton, 'Inspect Extraction'), findsNothing);
    expect(controller.ingestedSource, isNull, reason: 'no KnowledgeSessionRecord exists after FAILED');
  });

  // -------------------------------------------------------------------
  // Item 4: correct SourceMaterial handoff.
  // -------------------------------------------------------------------

  test('item 4: controller.ingestedSource resolves to the exact SourceMaterial from the ingestion session '
      'record, not a fabricated or reconstructed one', () async {
    final expectedSource = SourceMaterial(
      id: 'source-trx300',
      originalFileName: 'trx300_factory_wiring_diagram.pdf',
      localPath: 'C:/temp/trx300_factory_wiring_diagram.pdf',
      type: SourceMaterialType.pdf,
      sizeBytes: 185420,
      importDate: DateTime(2026, 1, 1),
      addedBy: 'uif',
    );
    final id = 'wp-ingest-011-test-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(id);
    final record = KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: id,
        name: 'Ingested Session',
        repositoryName: 'Repo One',
        author: 'jsmith',
        createdTime: DateTime(2026, 1, 1),
        lastModified: DateTime(2026, 1, 1),
      ),
      sources: [expectedSource],
    );
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: record,
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);

    await controller.run();

    expect(controller.ingestedSource, isNotNull);
    expect(controller.ingestedSource!.id, expectedSource.id);
    expect(controller.ingestedSource!.localPath, expectedSource.localPath);
  });

  // -------------------------------------------------------------------
  // Item 6: the TRX300 zero-entity case.
  // -------------------------------------------------------------------

  testWidgets('item 6: TRX300-like state (OCR > 0, entities = 0, candidates = 0) still exposes an enabled '
      'Inspect Extraction action', (tester) async {
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: makeSessionRecord(repositoryName: 'Repo One', ocrPageResults: [makeTrx300OcrResult()]),
        ingestionResult: makeZeroEntityIngestionResult(),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await tester.runAsync(() => controller.run());

    await tester.pumpWidget(hostedIn(container, controller));

    // Honest zero counts, exactly the real TRX300 result.
    expect(find.textContaining('OCR 1'), findsOneWidget);
    expect(find.textContaining('Entities 0'), findsOneWidget);
    expect(find.textContaining('Candidates 0'), findsOneWidget);

    final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Inspect Extraction'));
    expect(button.onPressed, isNotNull, reason: 'must remain usable with zero machine-derived results');
  });

  // -------------------------------------------------------------------
  // Item 7: existing wizard behavior is unchanged.
  // -------------------------------------------------------------------

  testWidgets('item 7: existing candidate/relationship/evidence category tiles still render exactly as '
      'before this work package', (tester) async {
    final candidate = KnowledgeCandidate(
      id: 'c1',
      type: KnowledgeCandidateType.component,
      name: 'Real Head Bolt',
      status: KnowledgeCandidateStatus.pending,
      createdTime: DateTime(2026, 1, 1),
    );
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: makeSessionRecord(repositoryName: 'Repo One', candidates: [candidate]),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await tester.runAsync(() => controller.run());

    await tester.pumpWidget(hostedIn(container, controller));

    expect(find.text('1 candidate'), findsOneWidget);
    await tester.tap(find.text('Component'));
    await tester.pumpAndSettle();
    expect(find.text('Real Head Bolt'), findsOneWidget);
  });
}

class _FakeWizardRuntimeNotifier extends AcquisitionRuntimeNotifier {
  _FakeWizardRuntimeNotifier({ReferenceVaultIngestionOutcome? outcome})
      : outcome = outcome ??
            ReferenceVaultIngestionOutcome.testResult(status: ReferenceVaultIngestionOutcomeStatus.completed);

  final ReferenceVaultIngestionOutcome outcome;

  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<Map<String, Object?>> createJobReturning(Map<String, Object?> body) async =>
      {'id': 'job-1', 'status': 'created'};

  @override
  Future<Map<String, Object?>> executeJobReturning(String jobId) async => {'id': jobId, 'status': 'running'};

  @override
  Future<Map<String, Object?>> startDownloadReturning(Map<String, Object?> body) async =>
      {'id': 'dl-1', 'status': 'completed', 'file_size_bytes': 185420};

  @override
  Future<Map<String, Object?>> verifyReturning(String downloadSessionId) async =>
      {'id': 'v-1', 'status': 'verified', 'sha256_hash': 'fd7f4474f5a94ab4'};

  @override
  Future<Map<String, Object?>> extractMetadataReturning(String verificationId) async =>
      {'id': 'm-1', 'status': 'extracted'};

  @override
  Future<Map<String, Object?>> publishReturning(String metadataId) async =>
      {'id': 'vault-1', 'vault_path': './data/vault/fd/fd7f4474f5a94ab4'};

  final ingestOrientations = <DocumentOrientation>[];

  @override
  Future<ReferenceVaultIngestionOutcome> ingestVaultArtifact({
    required String vaultObjectId,
    required String sessionName,
    required String repositoryName,
    required String author,
    DocumentOrientation orientation = DocumentOrientation.deg0,
  }) async {
    ingestOrientations.add(orientation);
    return outcome;
  }
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
