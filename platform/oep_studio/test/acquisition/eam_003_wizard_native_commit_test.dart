import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-EAM-003 §18 native/real-integration acceptance test.
///
/// **What is real here, stated explicitly per §18's own requirement:**
/// this test drives the REAL, unmodified `FoundationRuntimeNotifier`
/// against the REAL, unmodified `oep_foundation_bridge.dll` -- a real
/// temp-directory Foundation Repository is opened
/// (`FoundationBridge.openRepository`), a Knowledge Session is loaded via
/// the real `loadKnowledgeSessionRecord`, a candidate is accepted via the
/// real `acceptKnowledgeCandidate`, `FoundationServiceState.commitPlan`
/// is computed by the real, unmodified `CommitPlanService`, and
/// `commitToFoundation()` performs a REAL `CommitTransactionService`
/// transaction against the real Repository -- the exact same call chain
/// `CommitPreviewPanel` (now hosted directly by
/// `WizardStepPublish`) triggers on an engineer's explicit confirmation.
/// The test then re-reads the Repository's real object list to confirm a
/// real Foundation Engineering Object now exists.
///
/// **What is substituted, stated explicitly:** the Acquisition/Reference
/// Vault/Universal Ingestion Framework stages upstream of the Knowledge
/// Session are NOT exercised here -- `oep_acquisition`'s REST backend is
/// not started in this environment (mirroring
/// `exchange_rc1_e2e_test.dart`'s own documented boundary substitutions),
/// so the `KnowledgeSessionRecord` below is constructed directly rather
/// than produced by a real `ReferenceVaultIngestionWorkflow.ingest` run.
/// That upstream chain is covered for real elsewhere:
/// `test/ingestion/reference_vault_ingestion_workflow_test.dart`
/// (WP-INGEST-004) exercises the real UIF pipeline end to end against
/// real fixture files, and `eam_003_wizard_orchestration_test.dart`
/// exercises the real `AcquisitionWizardController`/
/// `FoundationRuntimeNotifier` orchestration logic with the Acquisition
/// backend faked at its own seam. This test's unique contribution is the
/// boundary neither of those covers: real Foundation Repository Commit,
/// reached from a wizard-produced Knowledge Session.
///
/// Never call this suite "full E2E" -- it is real Foundation + real
/// Commit, with Acquisition/UIF substituted.
void main() {
  Directory writeValidRepo(String repositoryId, String name) {
    final dir = Directory.systemTemp.createTempSync('oep_eam003_${name}_');
    File('${dir.path}${Platform.pathSeparator}repository.json').writeAsStringSync(
      '{"repositoryId":"$repositoryId",'
      '"repositoryName":"$name",'
      '"repositoryVersion":"1.0.0",'
      '"foundationVersion":"0.1.0",'
      '"templateVersion":"1.0",'
      '"createdUtc":"2026-01-01T00:00:00Z",'
      '"lastModifiedUtc":"2026-01-01T00:00:00Z"}',
    );
    return dir;
  }

  final createdSessionIds = <String>[];

  tearDown(() async {
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
    createdSessionIds.clear();
  });

  /// Mirrors `eke_011_repository_switch_test.dart`'s own
  /// `setUpContainer`: skips (never fakes) if the DLL is not present in
  /// this environment, fails loudly if it is present but stale.
  ProviderContainer? setUpContainer() {
    final container = ProviderContainer();
    final foundationState = container.read(foundationRuntimeServiceProvider);
    if (foundationState.phase == FoundationConnectionPhase.error) {
      final detail = foundationState.lastError?.technicalDetail ?? '';
      if (detail.contains('Failed to lookup symbol')) {
        fail(
          'oep_foundation_bridge.dll loaded but is stale/incompatible with the current Foundation API '
          '($detail). Run `flutter build windows --debug` then `dart run tool/sync_foundation_bridge_dll.dart`.',
        );
      }
      container.dispose();
      markTestSkipped(
        'oep_foundation_bridge.dll is not present in this environment (Foundation was not built here).',
      );
      return null;
    }
    return container;
  }

  testWidgets(
    'WP-EAM-003 §18: a wizard-produced Knowledge Session reaches a real Foundation Repository Commit through '
    'the unmodified FoundationRuntimeNotifier.commitToFoundation() path',
    (tester) async {
      final container = setUpContainer();
      if (container == null) return;
      addTearDown(container.dispose);

      final validRepo = writeValidRepo('3d9f4b21-2222-4333-9444-1111111111a1', 'eam003_native');
      addTearDown(() {
        if (validRepo.existsSync()) validRepo.deleteSync(recursive: true);
      });

      final notifier = container.read(foundationRuntimeServiceProvider.notifier);
      notifier.openRepository(validRepo.path);
      final openState = container.read(foundationRuntimeServiceProvider);
      expect(openState.isRepositoryOpen, isTrue, reason: openState.lastError?.message);
      final repositoryName = openState.repositoryStatus!.repositoryName;

      // Simulates the hand-off `AcquisitionWizardController._ingest()`
      // performs after a real ingestion run -- constructed directly here
      // since the Acquisition backend is substituted (see file doc
      // comment), but loaded through the exact same real, unmodified
      // `loadKnowledgeSessionRecord` call the wizard itself uses.
      final sessionId = 'wp-eam-003-native-${DateTime.now().microsecondsSinceEpoch}';
      createdSessionIds.add(sessionId);
      final record = KnowledgeSessionRecord(
        session: KnowledgeSession(
          id: sessionId,
          name: 'Native Commit Test Session',
          repositoryName: repositoryName,
          author: 'jsmith',
          createdTime: DateTime.now(),
          lastModified: DateTime.now(),
        ),
        candidates: [
          KnowledgeCandidate(
            id: 'candidate-native-1',
            type: KnowledgeCandidateType.component,
            name: 'Native Commit Test Bolt',
            description: 'WP-EAM-003 native commit acceptance test.',
            status: KnowledgeCandidateStatus.pending,
            createdTime: DateTime.now(),
          ),
        ],
      );

      await tester.runAsync(() async {
        await notifier.loadKnowledgeSessionRecord(record);
      });

      notifier.acceptKnowledgeCandidate('candidate-native-1');
      final beforeCommit = container.read(foundationRuntimeServiceProvider);
      expect(beforeCommit.commitPlan?.canCommit, isTrue, reason: beforeCommit.commitPlan?.validationErrors.join('; '));

      await tester.runAsync(() async {
        await notifier.commitToFoundation();
      });

      final afterCommit = container.read(foundationRuntimeServiceProvider);
      final report = afterCommit.latestCommitReport;
      expect(report, isNotNull);
      expect(report!.success, isTrue, reason: report.errors.join('; '));
      expect(report.objectsCreated, hasLength(1));
      expect(
        (afterCommit.objectList ?? const []).any((o) => o.name == 'Native Commit Test Bolt'),
        isTrue,
        reason: 'The real Foundation Repository object list must reflect the real commit.',
      );
    },
  );
}
