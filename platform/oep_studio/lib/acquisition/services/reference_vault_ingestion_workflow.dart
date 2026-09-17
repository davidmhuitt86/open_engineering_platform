import 'dart:io';

import '../../ingestion/models/ingestion_result.dart';
import '../../ingestion/models/ingestion_run_status.dart';
import '../../ingestion/models/vault_object_input.dart';
import '../../ingestion/services/ingestion_orchestrator.dart';
import '../../ingestion/services/knowledge_session_bridge.dart';
import '../../knowledge/models/knowledge_session_record.dart';
import '../../knowledge/services/knowledge_session_service.dart';
import '../../knowledge/services/knowledge_session_storage.dart';
import '../../knowledge/services/ocr_pipeline_service.dart';
import '../../knowledge/services/source_material_service.dart';
import 'acquisition_api_client.dart';
import 'acquisition_api_exception.dart';
import 'reference_vault_adapter.dart';

/// The production application workflow WP-INGEST-004 introduces: the
/// missing piece connecting the already-existing
///
/// ```
/// Reference Vault -> AcquisitionApiClient -> ReferenceVaultAdapter ->
/// VaultObjectInput -> IngestionOrchestrator -> IngestionResult ->
/// IngestionKnowledgeSessionBridge -> Knowledge Session
/// ```
///
/// chain into one small, application-level coordinator (WP-INGEST-004
/// § 6). This is workflow integration only — it introduces no new
/// Reference Vault client, no new ingestion engine, and no new
/// Knowledge Session model; it exists purely to call the four existing
/// components above, in order, and hand their result to whatever caller
/// wants to make it the active Knowledge Session (WP-INGEST-004 § 8:
/// "UI should orchestrate user interaction. The workflow service should
/// orchestrate ingestion.").
///
/// **Reconnaissance finding** (WP-INGEST-004 § 5): a repository-wide
/// search for `IngestionOrchestrator.run`, `IngestionKnowledgeSessionBridge`,
/// `ReferenceVaultAdapter.materialize`, `VaultObjectInput.fromFile`,
/// `attachSourceMaterial`, and `createKnowledgeSession` production call
/// sites found that none of WP-INGEST-001/002/003's ingestion machinery
/// is wired into any production workflow yet — every call site is
/// either the component's own doc comment or its own unit/vertical-slice
/// test. This file is therefore new integration, not a rename or
/// refactor of something that already existed.
///
/// Lives under `lib/acquisition/services/`, alongside
/// [ReferenceVaultAdapter] rather than under `lib/ingestion/` — the
/// Universal Ingestion Framework must remain source-agnostic
/// (WP-INGEST-004 § 2.2: it "must NOT know about... AcquisitionApiClient,
/// ReferenceVaultAdapter"), and this workflow depends on both the
/// adapter and the orchestrator, so it belongs on the acquisition side
/// of that boundary — the same reasoning [ReferenceVaultAdapter]'s own
/// doc comment gives for its own location.
///
/// Owns exactly the responsibility WP-INGEST-004 § 6 lists — Vault
/// Entry ID -> [ReferenceVaultAdapter] -> [IngestionOrchestrator] ->
/// [IngestionKnowledgeSessionBridge] -> a ready-to-load
/// [KnowledgeSessionRecord] — and nothing else. It never calls
/// `CommitTransactionService`/`CommitPlanService`/`FoundationBridge`
/// repository-write APIs (WP-INGEST-004 § 12: "Ingestion itself is not
/// approval"), and it never mutates `FoundationRuntimeNotifier` state
/// itself — that hand-off is the caller's job (see
/// `AcquisitionRuntimeNotifier.ingestVaultArtifact` and
/// `FoundationRuntimeNotifier.loadKnowledgeSessionRecord`), keeping this
/// class a plain, Flutter/Riverpod-free coordinator that is trivial to
/// unit test, the same discipline [IngestionOrchestrator] and
/// [ReferenceVaultAdapter] already follow.
abstract final class ReferenceVaultIngestionWorkflow {
  /// Runs the full workflow for [vaultObjectId] against [client].
  ///
  /// Always materializes then cleans up the temporary artifact via
  /// try/finally (WP-INGEST-004 § 10), on every path — Reference Vault
  /// failure, ingestion failure, session-bridge failure, or success —
  /// except when materialization itself never produced a
  /// [VaultObjectInput] to begin with (nothing to clean up in that
  /// case).
  ///
  /// Never throws: every failure mode WP-INGEST-004 § 9 calls out
  /// (Reference Vault retrieval failure, checksum/integrity failure,
  /// unsupported MIME/ArtifactType, Acquisition Record/provenance
  /// failure, session-bridge failure) is reported as a
  /// [ReferenceVaultIngestionOutcome] with [ReferenceVaultIngestionOutcome.isFailed]
  /// true and a stage-specific [ReferenceVaultIngestionOutcome.failureStage],
  /// not a raw exception — the same "no opaque generic error" discipline
  /// the work package requires. Parser/OCR/entity/candidate-generation
  /// failures are not raised here at all; [IngestionOrchestrator.run]
  /// already reports those *within* the returned [IngestionResult] (via
  /// `IngestionRun.status`/`StageResult`), which this method preserves
  /// unmodified.
  static Future<ReferenceVaultIngestionOutcome> ingest({
    required AcquisitionApiClient client,
    required String vaultObjectId,
    required String sessionName,
    required String repositoryName,
    required String author,
    String? runId,
    // Forwarded verbatim to `IngestionOrchestrator.run` — defaults to
    // the real, unmodified `OcrPipelineService.processSource`, exactly
    // like the orchestrator's own default. Exposed here only so tests
    // can substitute a fake at the same seam WP-INGEST-001/002/003's own
    // tests already use (this build/test machine has no `tesseract`
    // executable), never a second OCR implementation.
    OcrRunner ocrRunner = OcrPipelineService.processSource,
  }) async {
    VaultObjectInput? input;
    try {
      try {
        input = await ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultObjectId);
      } on AcquisitionApiException catch (error) {
        // Covers Reference Vault retrieval failure, checksum/integrity
        // failure, and Acquisition Record/provenance-list-fetch failure
        // — every failure `ReferenceVaultAdapter.materialize` itself
        // documents as an `AcquisitionApiException`.
        return ReferenceVaultIngestionOutcome.failure(
          stage: ReferenceVaultIngestionStage.referenceVault,
          message: error.message,
          technicalDetail: error.technicalDetail,
        );
      } on ReferenceVaultAdapterException catch (error) {
        // Unsupported MIME / ArtifactType (WP-INGEST-004 § 9).
        return ReferenceVaultIngestionOutcome.failure(
          stage: ReferenceVaultIngestionStage.unsupportedArtifact,
          message: error.message,
        );
      }

      final result = await IngestionOrchestrator.run(input: input, runId: runId, ocrRunner: ocrRunner);

      if (result.run.status == IngestionRunStatus.failed) {
        // A failed ingestion must not be presented as successfully
        // ingested (WP-INGEST-004 § 9/§ 18) — no Knowledge Session is
        // built or returned; the caller sees FAILED plus the
        // `IngestionResult` for diagnostics (stage diagnostics already
        // distinguish parser/OCR/entity/candidate causes).
        return ReferenceVaultIngestionOutcome._(
          status: ReferenceVaultIngestionOutcomeStatus.failed,
          ingestionResult: result,
          failureStage: ReferenceVaultIngestionStage.ingestion,
          errorMessage: 'Ingestion run ${result.run.runId} failed. See stage diagnostics for detail.',
        );
      }

      final KnowledgeSessionRecord sessionRecord;
      final candidateSessionId = KnowledgeSessionService.generateId('session');
      try {
        final builtRecord = IngestionKnowledgeSessionBridge.toNewSessionRecord(
          result: result,
          sessionId: candidateSessionId,
          sessionName: sessionName,
          repositoryName: repositoryName,
          author: author,
        );
        // WP-INGEST-005: copy the ingested source's bytes into this
        // session's own managed `sources/` directory *before* the
        // outer `finally` block below deletes the temporary
        // materialization `ReferenceVaultAdapter.materialize` created —
        // `result.source.localPath` still points at that temporary file
        // at this point, so it is still safe to read from. Without this
        // step, `KnowledgeSessionRecord.sources` would keep pointing at
        // a file the temp-cleanup step is about to delete, leaving the
        // Source Viewer unable to reopen it.
        final sessionOwnedSource = await SourceMaterialService.attachIngestedSource(
          sessionId: candidateSessionId,
          source: result.source,
        );
        sessionRecord = IngestionKnowledgeSessionBridge.withReplacedSource(builtRecord, sessionOwnedSource);
      } catch (error) {
        // Either the session record itself could not be built, or the
        // source copy failed partway through — in both cases no usable
        // Knowledge Session exists, so any `sources/<candidateSessionId>`
        // directory the failed copy attempt may have started is an
        // orphan with nothing else ever referencing it. Best-effort
        // cleanup only, mirroring `ReferenceVaultAdapter.cleanupTemporaryFile`.
        await _cleanupOrphanedSessionSource(candidateSessionId);
        return ReferenceVaultIngestionOutcome._(
          status: ReferenceVaultIngestionOutcomeStatus.failed,
          ingestionResult: result,
          failureStage: ReferenceVaultIngestionStage.sessionBridge,
          errorMessage: 'Could not build a Knowledge Session from ingestion run ${result.run.runId}: $error',
        );
      }

      // COMPLETE vs PARTIAL is preserved from the existing orchestrator's
      // own `IngestionRunStatus` — never collapsed to a single "success"
      // (WP-INGEST-004 § 9/§ 18).
      final status = result.run.status == IngestionRunStatus.partial
          ? ReferenceVaultIngestionOutcomeStatus.partial
          : ReferenceVaultIngestionOutcomeStatus.completed;
      return ReferenceVaultIngestionOutcome._(
        status: status,
        ingestionResult: result,
        sessionRecord: sessionRecord,
      );
    } finally {
      if (input != null) {
        await ReferenceVaultAdapter.cleanupTemporaryFile(input);
      }
    }
  }

  /// Deletes [sessionId]'s `sources/` directory if it exists (WP-INGEST-005)
  /// — used only when a session build/source-copy failure means
  /// [sessionId] will never become a real, returned Knowledge Session, so
  /// nothing else will ever reference whatever [SourceMaterialService.attachIngestedSource]
  /// managed to write before failing. Best-effort, like
  /// [ReferenceVaultAdapter.cleanupTemporaryFile] — a failure to delete an
  /// orphaned directory is not itself an ingestion failure.
  static Future<void> _cleanupOrphanedSessionSource(String sessionId) async {
    final directory = KnowledgeSessionStorage.sourcesDirectory(sessionId);
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup only.
    }
  }
}

/// Which stage of [ReferenceVaultIngestionWorkflow.ingest] a failure
/// occurred in (WP-INGEST-004 § 9: "Errors must preserve useful
/// technical distinctions... Do not catch everything and convert it to
/// an opaque generic error.").
enum ReferenceVaultIngestionStage {
  /// [ReferenceVaultAdapter.materialize] failed: Reference Vault
  /// retrieval, checksum/integrity verification, or Acquisition Record
  /// provenance resolution.
  referenceVault,

  /// The Vault Entry's MIME type has no supported UIF ArtifactType.
  unsupportedArtifact,

  /// [IngestionOrchestrator.run] itself reported `IngestionRunStatus.failed`
  /// for this run (parser failure, or a total OCR-engine-unavailable
  /// failure with no usable intermediate results — see
  /// `IngestionOrchestrator`'s own doc comment for exactly which stage
  /// failures escalate a run to FAILED versus PARTIAL).
  ingestion,

  /// [IngestionKnowledgeSessionBridge.toNewSessionRecord] itself threw.
  sessionBridge,
}

enum ReferenceVaultIngestionOutcomeStatus { completed, partial, failed }

/// The result of [ReferenceVaultIngestionWorkflow.ingest] — always one
/// of COMPLETED, PARTIAL, or FAILED (WP-INGEST-004 § 9/§ 18), never a
/// collapsed "success/failure" boolean.
class ReferenceVaultIngestionOutcome {
  const ReferenceVaultIngestionOutcome._({
    required this.status,
    this.ingestionResult,
    this.sessionRecord,
    this.failureStage,
    this.errorMessage,
    this.technicalDetail,
  });

  factory ReferenceVaultIngestionOutcome.failure({
    required ReferenceVaultIngestionStage stage,
    required String message,
    String? technicalDetail,
  }) =>
      ReferenceVaultIngestionOutcome._(
        status: ReferenceVaultIngestionOutcomeStatus.failed,
        failureStage: stage,
        errorMessage: message,
        technicalDetail: technicalDetail,
      );

  final ReferenceVaultIngestionOutcomeStatus status;

  /// Present whenever [IngestionOrchestrator.run] actually ran — even on
  /// a FAILED run — so a caller can inspect `IngestionRun.stageResults`
  /// for diagnostics. Absent only when materialization itself never
  /// reached the orchestrator (Reference Vault / unsupported-artifact
  /// failures).
  final IngestionResult? ingestionResult;

  /// Present only for COMPLETED/PARTIAL — a FAILED outcome never carries
  /// a session record, so a failed ingestion can never be mistaken for
  /// one that produced a (possibly empty) Knowledge Session
  /// (WP-INGEST-004 § 9: "A failed ingestion must not be presented as
  /// successfully ingested.").
  final KnowledgeSessionRecord? sessionRecord;

  /// Present only when [status] is FAILED.
  final ReferenceVaultIngestionStage? failureStage;

  /// A professional, user-facing message. Present only when [status] is
  /// FAILED.
  final String? errorMessage;

  /// Technical detail for logging only, mirroring
  /// [AcquisitionApiException]'s own message/technicalDetail split.
  final String? technicalDetail;

  bool get isFailed => status == ReferenceVaultIngestionOutcomeStatus.failed;
  bool get isPartial => status == ReferenceVaultIngestionOutcomeStatus.partial;
  bool get isCompleted => status == ReferenceVaultIngestionOutcomeStatus.completed;
}
