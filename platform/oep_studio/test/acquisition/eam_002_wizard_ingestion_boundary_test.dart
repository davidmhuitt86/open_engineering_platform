import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP-EAM-002 TEST-EAM-002-001 through 012 -- **superseded boundary,
/// updated by WP-EAM-003.**
///
/// This suite originally codified a "Phase 2 = Option B" decision: the
/// wizard's Candidate Preview/Engineering Review/Publish steps were
/// genuine, disconnected placeholders, and the wizard controller was
/// forbidden from ever calling `AcquisitionRuntimeNotifier.ingestVaultArtifact`,
/// `ReferenceVaultIngestionWorkflow`, `FoundationRuntimeNotifier`, or
/// `commitToFoundation` -- ingestion/review/commit were reserved
/// exclusively for the Reference Vault panel's own separate "Ingest into
/// Knowledge Studio" action.
///
/// **WP-EAM-003 explicitly reopens that decision** (see its own work
/// order §1/§5/§14 and `eam_003_wizard_orchestration_test.dart`'s top
/// doc comment): the wizard now orchestrates the SAME existing
/// `ReferenceVaultIngestionWorkflow`/`FoundationRuntimeNotifier`
/// machinery automatically, immediately after Reference Vault
/// publication, rather than requiring a second, separate manual step.
/// The boundary that remains -- and that this updated suite now
/// verifies -- is narrower but still real: the wizard may CALL those
/// existing public entry points (`AcquisitionRuntimeNotifier.ingestVaultArtifact`,
/// `FoundationRuntimeNotifier.loadKnowledgeSessionRecord`), but must
/// never reach past them into their own internals
/// (`IngestionOrchestrator`, `ReferenceVaultAdapter`,
/// `IngestionKnowledgeSessionBridge`, `CommitTransactionService`,
/// `CommitPlanService`'s computation, `FoundationBridge` object/
/// relationship creation) -- i.e. the wizard remains an orchestrator, not
/// a second implementation of any of those domains (WP-EAM-003 §4/§19).
///
/// Tests below that verified the now-superseded "never touches ingestion
/// at all" boundary have been removed; the tests that verified something
/// still true today (no shadow persistence, no shadow commit
/// implementation, the obsolete placeholder message never returns) are
/// kept. The full new positive-orchestration behavior (TEST-EAM-003-001
/// through 018) lives in `eam_003_wizard_orchestration_test.dart`.
void main() {
  final wizardDir = Directory('lib/acquisition/wizard');
  final wizardFiles = wizardDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // TEST-EAM-002-001: the obsolete message is absent from the codebase
  // (still true -- WP-EAM-003 did not reintroduce it).
  test('TEST-EAM-002-001: the obsolete "Knowledge Engine not built" message is absent from the codebase', () {
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('Knowledge Engine not built')), reason: file.path);
      expect(content, isNot(contains('Knowledge Extraction: not yet available')), reason: file.path);
    }
  });

  // TEST-EAM-002-003 (updated boundary): the wizard controller now DOES
  // call `.ingestVaultArtifact(` (that is the whole point of
  // WP-EAM-003) -- but it must never reach past that public entry point
  // into the ingestion pipeline's own internals, and never reimplement
  // Foundation Repository write machinery itself.
  test(
    'TEST-EAM-002-003 (updated by WP-EAM-003): the wizard controller orchestrates the existing ingestion '
    'entry point but never duplicates or reaches into its internals',
    () {
      final wizardControllerSource =
          File('lib/acquisition/wizard/acquisition_wizard_controller.dart').readAsStringSync();
      expect(wizardControllerSource, contains('.ingestVaultArtifact('),
          reason: 'WP-EAM-003 requires the wizard to orchestrate ingestion automatically.');
      for (final forbidden in [
        'IngestionOrchestrator',
        'ReferenceVaultAdapter',
        'IngestionKnowledgeSessionBridge',
        'ReferenceVaultIngestionWorkflow.ingest',
      ]) {
        expect(wizardControllerSource, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  // TEST-EAM-002-004..007 (still valid): wizard files define no shadow
  // IngestionRunStatus handling of their own -- the real
  // ReferenceVaultIngestionOutcome/IngestionRunStatus values are the only
  // source of truth, surfaced through WizardIngestionStatus (a thin
  // wizard-presentation enum, not a reimplementation).
  test('TEST-EAM-002-004..007: wizard files define no shadow IngestionRunStatus handling', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('IngestionRunStatus.completed')), reason: file.path);
      expect(content, isNot(contains('IngestionRunStatus.partial')), reason: file.path);
      expect(content, isNot(contains('IngestionRunStatus.failed')), reason: file.path);
    }
  });

  // TEST-EAM-002-008 (updated boundary): the wizard must still never
  // implement its own Foundation Repository write transaction --
  // `CommitTransactionService`/`FoundationBridge` object/relationship
  // creation stay exclusively inside the reused `CommitPreviewPanel`.
  // `CommitPlanService`'s own *computation* is now legitimately reused
  // (via the embedded `CommitPreviewPanel`/`EngineeringReviewPanel`), so
  // this check is narrowed to the two symbols that would indicate the
  // wizard reimplementing the transaction itself.
  test('TEST-EAM-002-008 (updated by WP-EAM-003): no automatic/duplicate Foundation Repository write '
      'transaction is introduced by the wizard', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      for (final forbidden in ['CommitTransactionService', 'FoundationBridge.create']) {
        expect(content, isNot(contains(forbidden)), reason: '${file.path} : $forbidden');
      }
    }
  });

  // TEST-EAM-002-011 (still valid): the wizard defines no shadow
  // session-persistence mechanism -- `KnowledgeSessionStorage` remains
  // reached only indirectly, through `FoundationRuntimeNotifier`.
  test('TEST-EAM-002-011: the wizard defines no shadow session-persistence mechanism', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      expect(content, isNot(contains('KnowledgeSessionStorage')), reason: file.path);
    }
  });

  // TEST-EAM-002-012 (updated boundary): the wizard must still never
  // directly touch the EKE lifecycle or the Foundation Bridge -- but it
  // now legitimately reads `foundationRuntimeServiceProvider`/calls
  // `FoundationRuntimeNotifier.loadKnowledgeSessionRecord` (WP-EAM-003
  // §5/§8), so those two symbols are no longer forbidden.
  test('TEST-EAM-002-012 (updated by WP-EAM-003): no direct EKE lifecycle or Foundation Bridge manipulation '
      'is introduced by the wizard', () {
    for (final file in wizardFiles) {
      final content = file.readAsStringSync();
      for (final forbidden in ['EkeLifecycle', 'FoundationBridge.create', 'EkeConsumerGate']) {
        expect(content, isNot(contains(forbidden)), reason: '${file.path} : $forbidden');
      }
    }
  });
}
