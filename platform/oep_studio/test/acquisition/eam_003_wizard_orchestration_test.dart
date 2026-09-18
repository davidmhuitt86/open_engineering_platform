import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/acquisition/services/reference_vault_ingestion_workflow.dart';
import 'package:oep_studio/acquisition/wizard/acquisition_wizard_controller.dart';
import 'package:oep_studio/acquisition/wizard/steps/wizard_step_candidate_preview.dart';
import 'package:oep_studio/acquisition/wizard/steps/wizard_step_publish.dart';
import 'package:oep_studio/acquisition/wizard/steps/wizard_step_review.dart';
import 'package:oep_studio/core/foundation/oep_api_types.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/review/engineering_review_panel.dart';
import 'package:oep_studio/knowledge/services/commit_plan_service.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/commit_preview_panel.dart';

/// WP-EAM-003 TEST-EAM-003-001 through 018.
///
/// Restores the Acquisition Wizard's end-to-end orchestration
/// (Acquisition -> Reference Vault -> UIF -> Knowledge Session ->
/// Candidate Preview -> Engineering Review -> Commit Preview -> explicit
/// Commit), reopening WP-EAM-002's Phase 2 = Option B decision (see the
/// updated `eam_002_wizard_ingestion_boundary_test.dart` doc comment for
/// how that boundary evolved).
///
/// **Fake seams used here, stated explicitly:** the Acquisition/EAM REST
/// backend is faked at `AcquisitionRuntimeNotifier`'s own `...Returning`
/// method seam (the same convention `acquisition_wizard_controller_test.dart`
/// already established). `ReferenceVaultIngestionWorkflow`/
/// `IngestionOrchestrator` themselves are faked at the
/// `AcquisitionRuntimeNotifier.ingestVaultArtifact` seam via a canned
/// `ReferenceVaultIngestionOutcome.testResult` (a `@visibleForTesting`
/// constructor added by this work package) -- that real pipeline is
/// unmodified and already covered end to end by
/// `test/ingestion/reference_vault_ingestion_workflow_test.dart`
/// (WP-INGEST-004's own suite). Everything downstream of ingestion --
/// `FoundationRuntimeNotifier.loadKnowledgeSessionRecord`,
/// `KnowledgeSessionStorage`, `CommitPlanService.computeCommitPlan` -- is
/// the real, unmodified production code, exercised against a
/// `FoundationRuntimeNotifier` subclass that only overrides `build()`
/// (the same pattern `navigation_convergence_002_test.dart`'s
/// `_FakeRepoOpenNotifier` already established), so no Foundation Bridge
/// DLL is required for these tests. A real-native-Foundation companion
/// test covering the boundary these fakes stand in for lives in
/// `eam_003_wizard_native_commit_test.dart`.
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
    List<RelationshipCandidate> relationshipCandidates = const [],
  }) {
    final id = 'wp-eam-003-test-${DateTime.now().microsecondsSinceEpoch}';
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
      relationshipCandidates: relationshipCandidates,
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

  KnowledgeCandidate makeCandidate(String id, {String name = 'Timing Cover Bolt'}) => KnowledgeCandidate(
        id: id,
        type: KnowledgeCandidateType.component,
        name: name,
        description: 'Ingested candidate.',
        status: KnowledgeCandidateStatus.pending,
        createdTime: DateTime(2026, 1, 1),
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
    controller.setKnowledgeType('Engineering Standard');
    controller.setSource('src-1', 'IETF');
    controller.updateCustody(originalUrl: 'https://example.org/spec.txt', engineer: 'jsmith');
    return controller;
  }

  // ---------------------------------------------------------------------
  // TEST-EAM-003-001 / 002 / 010 / 011: orchestration boundary.
  // ---------------------------------------------------------------------

  test(
    'TEST-EAM-003-001: successful wizard acquisition publishes to the Reference Vault and proceeds to UIF ingestion',
    () async {
      final acquisition = _FakeWizardRuntimeNotifier();
      final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
      final controller = readyController(container);

      await controller.run();

      expect(controller.runStatus, AcquisitionRunStatus.completed);
      expect(controller.vaultEntryId, 'vault-1');
      expect(acquisition.ingestCalls, hasLength(1));
      expect(acquisition.ingestCalls.single.vaultObjectId, 'vault-1');
    },
  );

  test('TEST-EAM-003-002: the wizard uses AcquisitionRuntimeNotifier.ingestVaultArtifact rather than '
      'duplicating ingestion logic itself', () {
    final source = File('lib/acquisition/wizard/acquisition_wizard_controller.dart').readAsStringSync();
    expect(source, contains('.ingestVaultArtifact('));
    for (final forbidden in [
      'IngestionOrchestrator',
      'ReferenceVaultAdapter',
      'IngestionKnowledgeSessionBridge',
      'ReferenceVaultIngestionWorkflow.ingest',
      'CommitTransactionService',
      'CommitPlanService.computeCommitPlan(',
      'FoundationBridge.create',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('TEST-EAM-003-010: the wizard does not directly call Foundation repository creation APIs during ingestion',
      () {
    final wizardDir = Directory('lib/acquisition/wizard');
    for (final file in wizardDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      for (final forbidden in ['FoundationBridge.create', '.createObject(', '.createRelationship(', '.openRepository(']) {
        expect(content, isNot(contains(forbidden)), reason: '${file.path} : $forbidden');
      }
    }
  });

  test('TEST-EAM-003-011: the wizard does not automatically commit candidates', () {
    final wizardDir = Directory('lib/acquisition/wizard');
    for (final file in wizardDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      // `CommitPreviewPanel` (reused wholesale, embedded as a widget) is
      // the only place allowed to actually CALL `commitToFoundation()`,
      // and it does so only after its own engineer confirmation dialog --
      // the wizard controller/step files themselves must never contain
      // that call shape directly. (Prose mentioning the method name in a
      // doc comment, e.g. explaining what `CommitPreviewPanel` does, is
      // fine and expected -- this checks for the real invocation shape
      // `commit_preview_panel.dart` itself uses:
      // `...notifier).commitToFoundation(`.)
      expect(content, isNot(contains('notifier).commitToFoundation(')), reason: file.path);
    }
  });

  // ---------------------------------------------------------------------
  // TEST-EAM-003-003 / 004 / 005 / 016: ingestion result handling.
  // ---------------------------------------------------------------------

  test('TEST-EAM-003-003: successful ingestion produces a real KnowledgeSessionRecord', () async {
    final record = makeSessionRecord(repositoryName: 'Repo One', candidates: [makeCandidate('c1')]);
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: record,
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);

    await controller.run();

    expect(controller.ingestionStatus, WizardIngestionStatus.completed);
    expect(controller.ingestionOutcome?.sessionRecord?.session.id, record.session.id);
    expect(controller.hasKnowledgeSession, isTrue);
  });

  test('TEST-EAM-003-004: the Knowledge Session is persisted', () async {
    final record = makeSessionRecord(repositoryName: 'Repo One', candidates: [makeCandidate('c1')]);
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: record,
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);

    await controller.run();

    final reloaded = await KnowledgeSessionStorage.load(record.session.id);
    expect(reloaded.session.id, record.session.id);
    expect(reloaded.candidates, hasLength(1));
  });

  test('TEST-EAM-003-005: the wizard exposes the actual generated Knowledge Candidates', () async {
    final record = makeSessionRecord(
      repositoryName: 'Repo One',
      candidates: [makeCandidate('c1', name: 'Head Bolt'), makeCandidate('c2', name: 'Gasket')],
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

    final foundation = container.read(foundationRuntimeServiceProvider);
    expect(foundation.candidates.map((c) => c.name), containsAll(['Head Bolt', 'Gasket']));
  });

  test('TEST-EAM-003-016: Repository context is resolved from the currently-open Foundation Repository '
      '(WP-EAM-003 §5 Option A)', () async {
    final acquisition = _FakeWizardRuntimeNotifier();
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);

    await controller.run();

    expect(acquisition.ingestCalls.single.repositoryName, 'Repo One');
  });

  test('TEST-EAM-003-016b: ingestion is deferred (never bound to a guessed repository name) when no '
      'Repository is open', () async {
    final acquisition = _FakeWizardRuntimeNotifier();
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoClosedNotifier.new);
    final controller = readyController(container);

    await controller.run();

    expect(controller.ingestionStatus, WizardIngestionStatus.blockedNoRepository);
    expect(acquisition.ingestCalls, isEmpty);
    // The acquisition/Vault-publication stage itself still succeeded --
    // never fabricated as failed just because ingestion was deferred.
    expect(controller.runStatus, AcquisitionRunStatus.completed);
  });

  // ---------------------------------------------------------------------
  // TEST-EAM-003-013 / 014: FAILED / PARTIAL ingestion handling.
  // ---------------------------------------------------------------------

  test('TEST-EAM-003-013: FAILED ingestion does not produce fabricated candidates', () async {
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.failed,
        errorMessage: 'Unsupported artifact type.',
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);

    await controller.run();

    expect(controller.ingestionStatus, WizardIngestionStatus.failed);
    expect(controller.ingestionErrorMessage, 'Unsupported artifact type.');
    expect(controller.hasKnowledgeSession, isFalse);
    expect(container.read(foundationRuntimeServiceProvider).candidates, isEmpty);
    expect(container.read(foundationRuntimeServiceProvider).knowledgeSession, isNull);
  });

  test('TEST-EAM-003-014: PARTIAL ingestion preserves its session and available results', () async {
    final record = makeSessionRecord(repositoryName: 'Repo One', candidates: [makeCandidate('c1')]);
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.partial,
        sessionRecord: record,
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);

    await controller.run();

    expect(controller.ingestionStatus, WizardIngestionStatus.partial);
    expect(controller.hasKnowledgeSession, isTrue);
    expect(container.read(foundationRuntimeServiceProvider).candidates, hasLength(1));
  });

  // ---------------------------------------------------------------------
  // TEST-EAM-003-006: Candidate Preview widget never fabricates.
  // ---------------------------------------------------------------------

  testWidgets('TEST-EAM-003-006: Candidate Preview shows only real candidates, never fabricated ones',
      (tester) async {
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: makeSessionRecord(
          repositoryName: 'Repo One',
          candidates: [makeCandidate('c1', name: 'Real Head Bolt')],
        ),
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    // `controller.run()` performs real `dart:io` writes via
    // `loadKnowledgeSessionRecord` -> `KnowledgeSessionStorage.save`;
    // `testWidgets` runs in a fake-async zone where real I/O callbacks
    // never fire, so it must run inside `tester.runAsync` (see
    // `foundation_load_knowledge_session_record_test.dart`'s own note).
    await tester.runAsync(() => controller.run());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: WizardStepCandidatePreview(controller: controller))),
      ),
    );

    // `Component` (the candidate's real type) shows a genuine "1
    // candidate" count on its collapsed `ExpansionTile` header -- expand
    // it to reveal the real name underneath.
    expect(find.text('1 candidate'), findsOneWidget);
    await tester.tap(find.text('Component'));
    await tester.pumpAndSettle();

    expect(find.text('Real Head Bolt'), findsOneWidget);
    // Every other, genuinely-empty candidate category must honestly say
    // "0 candidates" on its own header, never a fabricated count --
    // visible without expanding each one individually.
    expect(find.text('0 candidates'), findsWidgets);
  });

  testWidgets('TEST-EAM-003-006b: Candidate Preview never claims a session exists when ingestion failed',
      (tester) async {
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.failed,
        errorMessage: 'boom',
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await controller.run();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: WizardStepCandidatePreview(controller: controller))),
      ),
    );

    expect(find.text('Knowledge Extraction Failed'), findsOneWidget);
    expect(find.text('Candidate Knowledge Preview'), findsNothing);
  });

  // ---------------------------------------------------------------------
  // TEST-EAM-003-007 / 008: Engineering Review reuse + human control.
  // ---------------------------------------------------------------------

  test('TEST-EAM-003-007: Engineering Review hosts the existing EngineeringReviewPanel, not a new '
      'implementation', () {
    final source = File('lib/acquisition/wizard/steps/wizard_step_review.dart').readAsStringSync();
    expect(source, contains('EngineeringReviewPanel'));
    // No wizard-specific review service/controller/repository class is
    // ever *defined* in this file (a doc comment may legitimately name
    // those classes to explain that they were deliberately NOT
    // introduced -- so this checks for a class/type declaration shape,
    // not a bare substring).
    for (final forbidden in ['class WizardReviewService', 'class WizardCandidateController', 'class WizardCandidateRepository']) {
      expect(source, isNot(contains(forbidden)));
    }
  });

  testWidgets('TEST-EAM-003-007b: WizardStepReview renders the real EngineeringReviewPanel widget',
      (tester) async {
    final container = ProviderContainer(overrides: [foundationRuntimeServiceProvider.overrideWith(_FakeRepoOpenNotifier.new)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: WizardStepReview())),
      ),
    );

    expect(find.byType(EngineeringReviewPanel), findsOneWidget);
  });

  test('TEST-EAM-003-008: candidate acceptance/rejection remains human-controlled -- the wizard never calls '
      'accept/reject itself', () {
    final wizardDir = Directory('lib/acquisition/wizard');
    for (final file in wizardDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('.acceptKnowledgeCandidate(')), reason: file.path);
      expect(content, isNot(contains('.rejectKnowledgeCandidate(')), reason: file.path);
    }
  });

  // ---------------------------------------------------------------------
  // TEST-EAM-003-009 / 012 / 018: Commit Preview reuse + explicit commit.
  // ---------------------------------------------------------------------

  test('TEST-EAM-003-009: Publish hosts the existing CommitPreviewPanel (backed by the real CommitPlan), '
      'not a reimplementation', () {
    final source = File('lib/acquisition/wizard/steps/wizard_step_publish.dart').readAsStringSync();
    expect(source, contains('CommitPreviewPanel'));
    expect(source, isNot(contains('class CommitPlan')));
  });

  testWidgets('TEST-EAM-003-012: WizardStepPublish renders the real CommitPreviewPanel once a Knowledge '
      'Session exists, so explicit Commit still reaches FoundationRuntimeNotifier.commitToFoundation()',
      (tester) async {
    final record = makeSessionRecord(repositoryName: 'Repo One', candidates: [makeCandidate('c1')]);
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: record,
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await tester.runAsync(() => controller.run());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: WizardStepPublish(controller: controller))),
      ),
    );

    expect(find.byType(CommitPreviewPanel), findsOneWidget);
  });

  testWidgets('TEST-EAM-003-018: WizardStepPublish does not claim Repository Commit happened before an '
      'explicit commit actually occurred', (tester) async {
    final record = makeSessionRecord(repositoryName: 'Repo One', candidates: [makeCandidate('c1')]);
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: record,
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await tester.runAsync(() => controller.run());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: WizardStepPublish(controller: controller))),
      ),
    );

    expect(find.text('Not committed yet -- nothing has changed in the Repository'), findsOneWidget);
    expect(find.text('Committed by explicit engineer confirmation below'), findsNothing);
  });

  // ---------------------------------------------------------------------
  // TEST-EAM-003-015: Reference Vault secondary entry point unaffected.
  // ---------------------------------------------------------------------

  test('TEST-EAM-003-015: the Reference Vault panel\'s "Ingest into Knowledge Studio" flow is untouched by '
      'this work package', () {
    final dialogSource =
        File('lib/acquisition/panels/ingest_vault_artifact_dialog.dart').readAsStringSync();
    final panelSource = File('lib/acquisition/panels/acquisition_vault_panel.dart').readAsStringSync();
    expect(dialogSource, contains('.ingestVaultArtifact('));
    expect(dialogSource, contains('.loadKnowledgeSessionRecord('));
    expect(panelSource, contains('showIngestVaultArtifactDialog'));
    expect(panelSource, contains('Ingest into Knowledge Studio'));
  });

  // ---------------------------------------------------------------------
  // TEST-EAM-003-017: Repository mismatch protection remains intact.
  // ---------------------------------------------------------------------

  test('TEST-EAM-003-017: Repository mismatch protection (CommitPlanService) is untouched and still blocks '
      'commit if the open Repository changes after ingestion', () async {
    final record = makeSessionRecord(repositoryName: 'Repo One', candidates: [makeCandidate('c1')]);
    final acquisition = _FakeWizardRuntimeNotifier(
      outcome: ReferenceVaultIngestionOutcome.testResult(
        status: ReferenceVaultIngestionOutcomeStatus.completed,
        sessionRecord: record,
      ),
    );
    final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
    final controller = readyController(container);
    await controller.run();

    // The session was bound to "Repo One" while it was open (WP-EAM-003
    // §5). If a *different* Repository is open by the time Commit is
    // attempted, the real, wizard-untouched `CommitPlanService` must
    // still flag the mismatch -- never silently retargeted by the
    // wizard. Calling it directly with a switched `openRepositoryName`
    // exercises exactly the check `FoundationServiceState.commitPlan`
    // itself delegates to, the same way `commit_plan_service_test.dart`
    // already tests this invariant.
    final foundation = container.read(foundationRuntimeServiceProvider);
    final plan = CommitPlanService.computeCommitPlan(
      session: foundation.knowledgeSession!,
      candidates: foundation.candidates,
      relationshipCandidates: foundation.relationshipCandidates,
      isRepositoryOpen: true,
      openRepositoryName: 'Repo Two',
      objectList: foundation.objectList,
      currentStatistics: foundation.repositoryStatistics,
    );
    expect(plan.canCommit, isFalse);
    expect(plan.validationErrors.first, contains('Repo One'));
    expect(plan.validationErrors.first, contains('Repo Two'));
  });

  // ---------------------------------------------------------------------
  // Full end-to-end orchestration chain (not merely isolated widgets).
  // ---------------------------------------------------------------------

  test(
    'Full chain: wizard acquisition -> Reference Vault -> UIF ingestion -> Knowledge Session -> candidate '
    'acceptance -> a committable CommitPlan, all through the real controller/notifier production code',
    () async {
      final record = makeSessionRecord(repositoryName: 'Repo One', candidates: [makeCandidate('c1', name: 'Head Bolt')]);
      final acquisition = _FakeWizardRuntimeNotifier(
        outcome: ReferenceVaultIngestionOutcome.testResult(
          status: ReferenceVaultIngestionOutcomeStatus.completed,
          sessionRecord: record,
        ),
      );
      final container = containerWith(acquisition: acquisition, foundation: _FakeRepoOpenNotifier.new);
      final controller = readyController(container);

      // 1) Acquisition -> Reference Vault.
      await controller.run();
      expect(controller.runStatus, AcquisitionRunStatus.completed);
      expect(controller.vaultEntryId, isNotNull);

      // 2) Reference Vault -> UIF ingestion -> Knowledge Session, handed
      //    to the real FoundationRuntimeNotifier.
      expect(controller.ingestionStatus, WizardIngestionStatus.completed);
      final foundationNotifier = container.read(foundationRuntimeServiceProvider.notifier);
      var foundation = container.read(foundationRuntimeServiceProvider);
      expect(foundation.knowledgeSession?.id, record.session.id);
      expect(foundation.candidates, hasLength(1));

      // 3) Candidate Preview -> Engineering Review: human-controlled
      //    acceptance via the real FoundationRuntimeNotifier method
      //    EngineeringReviewPanel itself calls.
      foundationNotifier.acceptKnowledgeCandidate(foundation.candidates.single.id);
      foundation = container.read(foundationRuntimeServiceProvider);
      expect(foundation.candidates.single.status, KnowledgeCandidateStatus.accepted);

      // 4) Commit Preview: the real CommitPlanService now reports a
      //    committable plan -- but nothing has been committed yet.
      final plan = foundation.commitPlan;
      expect(plan, isNotNull);
      expect(plan!.canCommit, isTrue);
      expect(plan.newObjects.single.name, 'Head Bolt');
      expect(foundation.latestCommitReport, isNull);
    },
  );
}

class _IngestCall {
  const _IngestCall({required this.vaultObjectId, required this.sessionName, required this.repositoryName, required this.author});
  final String vaultObjectId;
  final String sessionName;
  final String repositoryName;
  final String author;
}

/// Fakes `AcquisitionRuntimeNotifier` at its own `...Returning` method
/// seam (real acquisition/download/verify/publish sequencing logic stays
/// in the real `AcquisitionWizardController`) plus `ingestVaultArtifact`
/// itself, so the real `ReferenceVaultIngestionWorkflow`/
/// `IngestionOrchestrator` pipeline is never exercised here -- see this
/// file's own top doc comment for why.
class _FakeWizardRuntimeNotifier extends AcquisitionRuntimeNotifier {
  _FakeWizardRuntimeNotifier({ReferenceVaultIngestionOutcome? outcome})
      : outcome = outcome ??
            ReferenceVaultIngestionOutcome.testResult(status: ReferenceVaultIngestionOutcomeStatus.completed);

  final ReferenceVaultIngestionOutcome outcome;
  final List<_IngestCall> ingestCalls = [];

  @override
  AcquisitionServiceState build() => const AcquisitionServiceState();

  @override
  Future<Map<String, Object?>> createJobReturning(Map<String, Object?> body) async => {'id': 'job-1', 'status': 'created'};

  @override
  Future<Map<String, Object?>> executeJobReturning(String jobId) async => {'id': jobId, 'status': 'running'};

  @override
  Future<Map<String, Object?>> startDownloadReturning(Map<String, Object?> body) async =>
      {'id': 'dl-1', 'status': 'completed', 'file_size_bytes': 1234};

  @override
  Future<Map<String, Object?>> verifyReturning(String downloadSessionId) async =>
      {'id': 'v-1', 'status': 'verified', 'sha256_hash': 'abc123'};

  @override
  Future<Map<String, Object?>> extractMetadataReturning(String verificationId) async => {'id': 'm-1', 'status': 'extracted'};

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
    ingestCalls.add(_IngestCall(
      vaultObjectId: vaultObjectId,
      sessionName: sessionName,
      repositoryName: repositoryName,
      author: author,
    ));
    return outcome;
  }
}

/// Mirrors `navigation_convergence_002_test.dart`'s `_FakeRepoOpenNotifier`
/// -- a repository-open `FoundationServiceState` with no real Foundation
/// Bridge DLL required, so these tests run in any environment.
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

class _FakeRepoClosedNotifier extends FoundationRuntimeNotifier {
  @override
  FoundationServiceState build() => const FoundationServiceState(phase: FoundationConnectionPhase.connected);
}
