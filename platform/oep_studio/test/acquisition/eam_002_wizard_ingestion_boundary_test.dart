import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_service.dart';
import 'package:oep_studio/acquisition/services/acquisition_runtime_state.dart';
import 'package:oep_studio/acquisition/wizard/acquisition_wizard_controller.dart';
import 'package:oep_studio/acquisition/wizard/steps/wizard_step_candidate_preview.dart';
import 'package:oep_studio/acquisition/wizard/steps/wizard_step_review.dart';

/// WP-EAM-002 TEST-EAM-002-001 through 012.
///
/// **Architectural decision this suite verifies (see the work package's
/// own final report for the full audit): Phase 2 = OPTION B.** The
/// Acquisition Wizard's Step 7 ("Candidate Knowledge Preview") and
/// Step 8 ("Engineering Review") are genuine, standalone, stateless
/// placeholder widgets -- they take no controller, session id, or
/// candidate list of any kind as input, and never did. The real,
/// already-implemented ingestion entry point
/// (`AcquisitionRuntimeNotifier.ingestVaultArtifact` ->
/// `ReferenceVaultIngestionWorkflow.ingest`, surfaced through
/// `showIngestVaultArtifactDialog` on `AcquisitionVaultPanel`) requires a
/// destination Foundation Repository name, which this wizard's own
/// 8-step flow (Knowledge Type / Official Source / Chain of Custody /
/// Scope / Acquire / Candidate Preview / Engineering Review / Publish)
/// never collects. Duplicating that entry point's inputs inside the
/// wizard, or silently invoking it with fabricated values, would not be
/// "reconciling the wizard with the existing architecture" -- it would
/// be inventing a second, parallel ingestion path. The correct fix is
/// therefore: replace the obsolete "Knowledge Engine not built" message
/// with an honest "published, ready for ingestion via the existing
/// Reference Vault panel action" status, and leave the wizard's own
/// Step 7/8 honestly disclosed as out-of-flow rather than faked.
///
/// TEST-EAM-002-004 through 007 (ingestion result handling: completed /
/// partial / failed / vault-preserved-on-failure) are consequently
/// **adapted**: they are already fully covered, end to end, against the
/// real `ReferenceVaultIngestionWorkflow`/`IngestionOrchestrator`, by
/// `test/ingestion/reference_vault_ingestion_workflow_test.dart`
/// (WP-INGEST-004's own TEST-004-001..014) -- that workflow is
/// unmodified by this work package. What this suite instead verifies is
/// the *boundary*: that the wizard controller changed in this work
/// package never calls that workflow, never fabricates a completed/
/// partial/failed ingestion result of its own, and never duplicates
/// `KnowledgeSessionStorage`.
void main() {
  final wizardControllerSource =
      File('lib/acquisition/wizard/acquisition_wizard_controller.dart').readAsStringSync();
  final candidatePreviewSource =
      File('lib/acquisition/wizard/steps/wizard_step_candidate_preview.dart').readAsStringSync();
  final reviewSource = File('lib/acquisition/wizard/steps/wizard_step_review.dart').readAsStringSync();
  final publishSource = File('lib/acquisition/wizard/steps/wizard_step_publish.dart').readAsStringSync();
  final wizardDir = Directory('lib/acquisition/wizard');
  final wizardFiles = wizardDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // TEST-EAM-002-001: the obsolete message is gone from the whole tree,
  // not just reworded in the one file we know about.
  test('TEST-EAM-002-001: the obsolete "Knowledge Engine not built" message is absent from the codebase', () {
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('Knowledge Engine not built')), reason: file.path);
      expect(content, isNot(contains('Knowledge Extraction: not yet available')), reason: file.path);
    }
  });

  // TEST-EAM-002-002: successful publication produces an accurate next
  // state -- an honest "published, ready for ingestion" log line, using
  // the real vault entry id the run actually produced.
  test('TEST-EAM-002-002: successful Reference Vault publication logs an honest ready-for-ingestion status', () async {
    final fake = _FakeRuntimeNotifier();
    final container = ProviderContainer(
      overrides: [
        acquisitionRuntimeServiceProvider.overrideWith(() => fake),
        acquisitionWizardControllerProvider.overrideWith(
          (ref) => AcquisitionWizardController(ref, saveCustody: (_, __) async {}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(acquisitionWizardControllerProvider, (_, __) {});

    final controller = container.read(acquisitionWizardControllerProvider);
    controller.setKnowledgeType('Engineering Standard');
    controller.setSource('src-1', 'IETF');
    controller.updateCustody(originalUrl: 'https://example.org/spec.txt', engineer: 'jsmith');

    await controller.run();

    expect(controller.runStatus, AcquisitionRunStatus.completed);
    expect(controller.vaultEntryId, 'vault-1');
    final messages = controller.log.map((e) => e.message).join('\n');
    expect(messages, contains('ready for ingestion'));
    expect(messages, contains('Ingest into Knowledge Studio'));
    expect(messages, isNot(contains('not yet available')));
    expect(messages, isNot(contains('not built')));
  });

  // TEST-EAM-002-003: the wizard controller never instantiates or calls
  // the ingestion machinery directly -- it is a UI orchestration layer,
  // and (per the Phase 2 = B decision) it does not call the ingestion
  // service boundary at all; ingestion stays the Reference Vault panel's
  // own, separate, already-correct action.
  test('TEST-EAM-002-003: the wizard controller does not invoke or duplicate the ingestion pipeline', () {
    for (final forbidden in [
      'IngestionOrchestrator',
      'ReferenceVaultAdapter',
      'IngestionKnowledgeSessionBridge',
      'ReferenceVaultIngestionWorkflow',
      '.ingestVaultArtifact(',
    ]) {
      expect(wizardControllerSource, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  // TEST-EAM-002-004..007 (adapted -- see file doc comment): the real
  // COMPLETED/PARTIAL/FAILED/vault-preserved-on-failure behavior is
  // exercised end to end against the unmodified, real workflow in
  // test/ingestion/reference_vault_ingestion_workflow_test.dart. Here we
  // confirm this work package did not introduce a second, competing
  // implementation of that result handling anywhere in the wizard.
  test('TEST-EAM-002-004..007 (adapted): wizard files define no shadow IngestionRunStatus handling', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('IngestionRunStatus.completed')), reason: file.path);
      expect(content, isNot(contains('IngestionRunStatus.partial')), reason: file.path);
      expect(content, isNot(contains('IngestionRunStatus.failed')), reason: file.path);
    }
  });

  // TEST-EAM-002-008: no code path introduced/changed by this work
  // package touches Foundation/Repository commit machinery.
  test('TEST-EAM-002-008: no automatic Foundation/Repository commit is introduced', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      for (final forbidden in ['CommitTransactionService', 'CommitPlanService', 'FoundationBridge']) {
        expect(content, isNot(contains(forbidden)), reason: '${file.path} : $forbidden');
      }
    }
  });

  // TEST-EAM-002-009 (adapted for Phase 2 = B): Candidate Preview shows
  // the honest "not generated by this wizard, use Ingest into Knowledge
  // Studio" status and fabricates zero candidates -- every category is
  // genuinely empty, never a fake populated list.
  testWidgets('TEST-EAM-002-009: Candidate Preview discloses the real boundary, fabricates no candidates',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WizardStepCandidatePreview())));

    expect(find.textContaining('Ingest into Knowledge Studio'), findsWidgets);
    expect(find.textContaining('does not generate Candidate Engineering Objects automatically'), findsOneWidget);
    expect(find.text('Not yet available. Turning an acquired document'), findsNothing);
    // Every disclosed category must be honestly empty -- no fabricated counts.
    expect(find.text('0 candidates'), findsNWidgets(9));
  });

  // TEST-EAM-002-010 (adapted for Phase 2 = B): Engineering Review
  // discloses the same real boundary and points at the actual place
  // review happens (Knowledge Studio's EngineeringReviewPanel).
  testWidgets('TEST-EAM-002-010: Engineering Review discloses the real boundary, not a fabricated session',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WizardStepReview())));

    expect(find.textContaining('This wizard does not review Candidate Engineering Objects'), findsOneWidget);
    expect(find.textContaining('Ingest into Knowledge Studio'), findsWidgets);
    expect(find.textContaining('no Candidate Engineering Objects exist to annotate'), findsNothing);
  });

  // TEST-EAM-002-011 (adapted -- see file doc comment): persisted
  // ingestion data surviving reload is exercised at the real storage
  // layer by test/ingestion/*persistence*_test.dart and
  // test/knowledge/knowledge_session_durable_reconciliation_test.dart
  // (WP-INGEST-005/006/008), reusing the real `KnowledgeSessionStorage`
  // save/load path unmodified. Here we confirm the wizard introduces no
  // second, wizard-owned persistence mechanism that could diverge from
  // it.
  test('TEST-EAM-002-011 (adapted): the wizard defines no shadow session-persistence mechanism', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('KnowledgeSessionStorage')), reason: file.path);
    }
  });

  // TEST-EAM-002-012: no direct EKE lifecycle manipulation anywhere in
  // the changed wizard files.
  test('TEST-EAM-002-012: no direct EKE lifecycle manipulation is introduced by the wizard', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      for (final forbidden in [
        'EkeLifecycle',
        'FoundationBridge',
        'EkeConsumerGate',
        'FoundationRuntimeNotifier',
        'foundationRuntimeServiceProvider',
      ]) {
        expect(content, isNot(contains(forbidden)), reason: '${file.path} : $forbidden');
      }
    }
  });

  // Cross-check the honest publish-step wording directly, since several
  // tests above assert absence of the old strings rather than presence
  // of specific new ones in wizard_step_publish.dart.
  test('sanity: wizard_step_publish.dart no longer claims candidates/Knowledge Studio require the Knowledge Engine', () {
    expect(publishSource, isNot(contains('Requires the Knowledge Engine (not built yet)')));
    expect(publishSource, isNot(contains('Requires Candidate Objects above')));
    expect(publishSource, contains('Ingest into Knowledge Studio'));
  });

  test('sanity: candidate preview and review source no longer reference "Milestone 2" / "not built"', () {
    for (final content in [candidatePreviewSource, reviewSource]) {
      expect(content, isNot(contains('Milestone 2')));
      expect(content, isNot(contains('not been built yet')));
    }
  });
}

class _FakeRuntimeNotifier extends AcquisitionRuntimeNotifier {
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
  Future<Map<String, Object?>> extractMetadataReturning(String verificationId) async =>
      {'id': 'm-1', 'status': 'extracted'};

  @override
  Future<Map<String, Object?>> publishReturning(String metadataId) async =>
      {'id': 'vault-1', 'vault_path': './data/vault/ab/abc123'};
}
