import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../ingestion/models/ingestion_stage.dart';
import '../../ingestion/models/stage_execution_status.dart';
import '../../ingestion/models/stage_result.dart';
import '../../knowledge/models/source_material.dart';
import '../services/acquisition_api_exception.dart';
import '../services/acquisition_runtime_service.dart';
import '../../knowledge/models/document_orientation.dart';
import '../services/reference_vault_ingestion_workflow.dart';
import 'chain_of_custody_record.dart';
import 'chain_of_custody_storage.dart';

/// WP-EAM-005 §2: the acquisition WIZARD distinguishes two ways an
/// artifact enters the pipeline. Neither is a fake Official Source --
/// [localDocument] jobs are created with no `source_id` at all
/// (services/acquisition's `acquisition_jobs.source_id` is nullable as
/// of migrations/V11__acquisition_jobs_optional_source.sql precisely so
/// this doesn't require inventing a placeholder registry entry).
enum AcquisitionSourceType { officialSource, localDocument }

/// A human-readable label for one executed UIF [IngestionStage] (WP-EAM-005
/// §8/§9) -- used only for Activity Log display; never claims a stage ran
/// if [StageResult] doesn't say so, and never mentions
/// [IngestionStage.chunkGeneration]/[IngestionStage.embeddingGeneration]
/// because [IngestionStage.executedInFirstSlice] proves neither is ever
/// actually executed by the current ingestion pipeline -- reporting
/// them would be exactly the "claim an operation ran if it did not"
/// defect this work package exists to remove.
String _stageLabel(IngestionStage stage) => switch (stage) {
      IngestionStage.identify => 'Identifying document',
      IngestionStage.parserSelection => 'Selecting parser',
      IngestionStage.metadataExtraction => 'Extracting metadata',
      IngestionStage.contentExtraction => 'Extracting content',
      IngestionStage.structuralAnalysis => 'Structural analysis',
      IngestionStage.ocr => 'OCR',
      IngestionStage.entityExtraction => 'Entity extraction',
      IngestionStage.relationshipExtraction => 'Relationship extraction',
      IngestionStage.candidateGeneration => 'Candidate generation',
      IngestionStage.chunkGeneration => 'Chunk generation',
      IngestionStage.embeddingGeneration => 'Embedding generation',
    };

String _stageStatusLabel(StageExecutionStatus status) => switch (status) {
      StageExecutionStatus.succeeded => 'succeeded',
      StageExecutionStatus.partial => 'partially succeeded',
      StageExecutionStatus.failed => 'failed',
      StageExecutionStatus.skipped => 'skipped',
    };

/// One line of the Step 6 live acquisition log -- "No silent operations.
/// The engineer should always know exactly what the system is doing."
class AcquisitionLogEntry {
  AcquisitionLogEntry(this.message, {this.isError = false}) : timestamp = DateTime.now();
  final String message;
  final bool isError;
  final DateTime timestamp;
}

enum AcquisitionRunStatus { idle, running, completed, failed }

/// WP-EAM-003 §6 wizard ingestion lifecycle -- tracked separately from
/// [AcquisitionRunStatus] because acquisition/Reference Vault publication
/// (Step 5's own concern) and UIF ingestion (this) are two different
/// stages of the pipeline that can each independently succeed, partially
/// succeed, or fail (WP-EAM-003 §6: "ACQUIRING -> VAULT_PUBLISHED ->
/// INGESTING -> KNOWLEDGE_SESSION_READY -> ...").
enum WizardIngestionStatus {
  /// Acquisition has not yet published to the Reference Vault.
  notStarted,

  /// Vault publication succeeded, but no Foundation Repository is open,
  /// so there is no [KnowledgeSession.repositoryName] to bind the
  /// resulting session to (WP-EAM-003 §5 Option A). The artifact is
  /// safely in the Reference Vault; ingestion is deferred until an
  /// engineer opens a repository and presses "Retry Ingestion".
  blockedNoRepository,
  ingesting,
  completed,
  partial,
  failed,
}

/// Orchestrates the real Source -> Job -> Download -> Verify -> Metadata
/// -> Vault chain automatically (Wizard Steps 5-6), so the engineer never
/// has to understand or manually drive `oep_acquisition`'s own REST
/// state machine -- exactly the "the wizard should orchestrate the
/// existing backend automatically" requirement. Every call here is a
/// real, already-tested `AcquisitionRuntimeNotifier` method; nothing new
/// is invented at the HTTP layer.
///
/// **`connectorId` is hardcoded to `'http-source'`.** `oep_acquisition`
/// ships exactly two connectors (`GET /connectors`): `example-stub`
/// (fabricates a placeholder file, no real network I/O) and
/// `http-source` (a real HTTP/HTTPS client). Since "the engineer should
/// not have to understand our internal architecture" is this whole
/// work's own guiding principle, the wizard never asks which connector
/// to use -- it always uses the one that does real acquisition. A
/// future work package adding more real connector types (FTP, a
/// browser-automation connector, etc.) is the natural point to turn this
/// into a real selection.
class AcquisitionWizardController extends ChangeNotifier {
  AcquisitionWizardController(this._ref, {Future<void> Function(String, ChainOfCustodyRecord)? saveCustody})
      : _saveCustody = saveCustody ?? ChainOfCustodyStorage.save;

  final Ref _ref;

  /// Defaults to [ChainOfCustodyStorage.save] (a real write to the
  /// user's settings directory); injectable so tests exercise the full
  /// orchestration without writing into the real `%APPDATA%` -- the same
  /// discipline `WorkspaceStateStorage`-backed code follows elsewhere.
  final Future<void> Function(String vaultEntryId, ChainOfCustodyRecord record) _saveCustody;

  static const _connectorId = 'http-source';

  AcquisitionRuntimeNotifier get _runtime => _ref.read(acquisitionRuntimeServiceProvider.notifier);

  int _stepIndex = 0;
  int get stepIndex => _stepIndex;

  // Step 1
  String? knowledgeType;

  // Step 2
  AcquisitionSourceType sourceType = AcquisitionSourceType.officialSource;
  String? sourceId;
  String? sourceName;

  // Step 2 -- User-Provided Artifact (WP-EAM-005). The original file path
  // the engineer selected; never modified or deleted by this wizard (§4).
  String? localFilePath;

  /// Persistent Extraction Orientation, chosen before acquisition and applied
  /// before OCR (WP-INGEST-014). Not the Inspector's temporary viewer rotation.
  DocumentOrientation extractionOrientation = DocumentOrientation.deg0;

  void setExtractionOrientation(DocumentOrientation orientation) {
    if (extractionOrientation == orientation) return;
    extractionOrientation = orientation;
    notifyListeners();
  }
  String? localFileName;
  int? localFileSizeBytes;

  // Step 3
  String originalUrl = '';
  String publisher = '';
  String publicationDate = '';
  String revision = '';
  String license = '';
  String language = '';
  String acquisitionMethod = 'Direct download';
  String engineer = '';

  // Step 4
  String scopeKind = 'Entire Document';
  String scopeDetail = '';

  // Steps 5-6
  final List<AcquisitionLogEntry> log = [];
  AcquisitionRunStatus runStatus = AcquisitionRunStatus.idle;
  String? failureMessage;
  double? downloadProgress;

  String? _jobId;
  String? _downloadId;
  String? _verificationId;
  String? _metadataId;
  String? vaultEntryId;
  String? sha256Hash;
  String? vaultPath;
  int? fileSizeBytes;

  // Step 7 (index 5): Knowledge Session / ingestion outcome (WP-EAM-003
  // §6-9). `ingestionOutcome` is the real, unmodified
  // `ReferenceVaultIngestionWorkflow` result -- never a wizard-fabricated
  // stand-in (WP-EAM-003 §9/§16).
  WizardIngestionStatus ingestionStatus = WizardIngestionStatus.notStarted;
  ReferenceVaultIngestionOutcome? ingestionOutcome;
  String? ingestionErrorMessage;
  String? knowledgeSessionId;

  /// True only once ingestion produced a real [KnowledgeSessionRecord]
  /// that is now the Foundation runtime's active session (COMPLETE or
  /// PARTIAL) -- never true for FAILED/blocked/not-started, so Candidate
  /// Preview/Engineering Review never present themselves as available
  /// over a session that does not exist (WP-EAM-003 §9/§15).
  bool get hasKnowledgeSession =>
      ingestionStatus == WizardIngestionStatus.completed || ingestionStatus == WizardIngestionStatus.partial;

  /// WP-INGEST-011: the [SourceMaterial] the Extraction Inspector needs
  /// (`showExtractionInspectorDialog`'s own required parameter) --
  /// already present on [ingestionOutcome], never a new field or a
  /// second session load. `null` whenever [hasKnowledgeSession] is
  /// `false` (no [KnowledgeSessionRecord] exists yet, per
  /// [ReferenceVaultIngestionOutcome]'s own contract), so callers never
  /// need a separate null-check against `ingestionStatus` first.
  SourceMaterial? get ingestedSource {
    final sources = ingestionOutcome?.sessionRecord?.sources;
    return (sources == null || sources.isEmpty) ? null : sources.first;
  }

  bool get canGoNext => switch (_stepIndex) {
        0 => knowledgeType != null,
        1 => sourceType == AcquisitionSourceType.officialSource ? sourceId != null : localFilePath != null,
        2 => originalUrl.trim().isNotEmpty && engineer.trim().isNotEmpty,
        3 => true,
        4 => runStatus == AcquisitionRunStatus.completed,
        // Candidate Preview requires a real Knowledge Session -- FAILED
        // ingestion or a still-closed Repository must not let the
        // engineer advance into a review stage with nothing behind it
        // (WP-EAM-003 §9/§15).
        5 => hasKnowledgeSession,
        6 => hasKnowledgeSession,
        7 => true,
        _ => false,
      };

  void goToStep(int index) {
    _stepIndex = index;
    notifyListeners();
  }

  void next() {
    if (!canGoNext || _stepIndex >= 8) return;
    _stepIndex++;
    notifyListeners();
  }

  void back() {
    if (_stepIndex == 0) return;
    _stepIndex--;
    notifyListeners();
  }

  void setKnowledgeType(String value) {
    knowledgeType = value;
    notifyListeners();
  }

  void setSource(String id, String name) {
    sourceId = id;
    sourceName = name;
    notifyListeners();
  }

  /// WP-EAM-005 §2: switches between the two acquisition origins.
  /// Clearing the other origin's selection when switching prevents a
  /// stale `sourceId`/`localFilePath` from a previous choice silently
  /// surviving into [run] under the wrong [sourceType].
  void setSourceType(AcquisitionSourceType type) {
    sourceType = type;
    if (type == AcquisitionSourceType.officialSource) {
      localFilePath = null;
      localFileName = null;
      localFileSizeBytes = null;
    } else {
      sourceId = null;
      sourceName = null;
    }
    notifyListeners();
  }

  /// WP-EAM-005 §3/§4: records the local file the engineer selected via
  /// the native file picker. `path` must be the original file's own
  /// absolute path -- this wizard never copies it anywhere itself; the
  /// existing `local-file` connector (services/acquisition) performs the
  /// one real copy, into acquisition's own temporary staging location,
  /// during [run]. `originalUrl`/`acquisitionMethod` are auto-populated
  /// with an honest description (never a `file://` URL -- that would be
  /// exactly the connector-URL workaround this work package's own
  /// architecture prohibits) so Step 3's Chain of Custody fields make
  /// sense without the engineer having to invent an "Original URL" for
  /// something that was never downloaded from anywhere.
  void setLocalFile({required String path, required String name, required int sizeBytes}) {
    localFilePath = path;
    localFileName = name;
    localFileSizeBytes = sizeBytes;
    originalUrl = 'Local file: $name';
    acquisitionMethod = 'User-provided local file';
    notifyListeners();
  }

  void updateCustody({
    String? originalUrl,
    String? publisher,
    String? publicationDate,
    String? revision,
    String? license,
    String? language,
    String? acquisitionMethod,
    String? engineer,
  }) {
    if (originalUrl != null) this.originalUrl = originalUrl;
    if (publisher != null) this.publisher = publisher;
    if (publicationDate != null) this.publicationDate = publicationDate;
    if (revision != null) this.revision = revision;
    if (license != null) this.license = license;
    if (language != null) this.language = language;
    if (acquisitionMethod != null) this.acquisitionMethod = acquisitionMethod;
    if (engineer != null) this.engineer = engineer;
    notifyListeners();
  }

  void setScope(String kind, String detail) {
    scopeKind = kind;
    scopeDetail = detail;
    notifyListeners();
  }

  void _appendLog(String message, {bool isError = false}) {
    log.add(AcquisitionLogEntry(message, isError: isError));
    notifyListeners();
  }

  /// Runs the entire real pipeline once, start to finish -- "The user
  /// should never need to press Run twice." Any failure at any stage
  /// stops the chain and sets [runStatus] to `failed` with the real
  /// error message; nothing downstream of a failure is attempted.
  Future<void> run() async {
    if (runStatus == AcquisitionRunStatus.running) return;
    runStatus = AcquisitionRunStatus.running;
    failureMessage = null;
    log.clear();
    notifyListeners();

    final isLocal = sourceType == AcquisitionSourceType.localDocument;
    if (isLocal && (localFilePath == null || localFilePath!.trim().isEmpty)) {
      runStatus = AcquisitionRunStatus.failed;
      failureMessage = 'No local file was selected.';
      _appendLog(failureMessage!, isError: true);
      notifyListeners();
      return;
    }

    try {
      _appendLog('Initializing…');
      final jobName = isLocal
          ? 'Acquire ${localFileName ?? 'local document'}'
          : (knowledgeType == null ? 'Acquisition' : 'Acquire $knowledgeType');
      final job = await _runtime.createJobReturning({
        // WP-EAM-005: omitted entirely (not merely null) for a
        // User-Provided Artifact -- the server distinguishes "no
        // source_id key present" from "an empty string was sent by
        // mistake" (see services/acquisition's validation.cpp).
        if (!isLocal) 'source_id': sourceId,
        'name': jobName,
        'priority': 2,
        if (engineer.trim().isNotEmpty) 'requested_by': engineer.trim(),
      });
      _jobId = job['id'] as String?;
      if (_jobId == null) throw StateError('Job creation did not return an id.');

      _appendLog(isLocal ? 'Reading local file…' : 'Connecting…');
      await _runtime.executeJobReturning(_jobId!); // created -> queued
      await _runtime.executeJobReturning(_jobId!); // queued -> running

      _appendLog(isLocal ? 'Acquiring local artifact…' : 'Downloading…');
      downloadProgress = 0;
      notifyListeners();
      final download = await _runtime.startDownloadReturning({
        'job_id': _jobId,
        'connector_id': isLocal ? 'local-file' : _connectorId,
        'source_uri': isLocal ? localFilePath!.trim() : originalUrl.trim(),
      });
      final downloadStatus = download['status'] as String?;
      _downloadId = download['id'] as String?;
      fileSizeBytes = download['file_size_bytes'] as int?;
      if (downloadStatus != 'completed') {
        throw AcquisitionApiException(
          message: download['error_message'] as String? ?? 'Download failed.',
          technicalDetail: download.toString(),
        );
      }
      downloadProgress = 1;
      _appendLog('Download Complete');

      _appendLog('Verifying integrity…');
      final verification = await _runtime.verifyReturning(_downloadId!);
      _verificationId = verification['id'] as String?;
      sha256Hash = verification['sha256_hash'] as String?;
      if (verification['status'] != 'verified') {
        throw AcquisitionApiException(
          message: verification['error_message'] as String? ?? 'Integrity verification failed.',
          technicalDetail: verification.toString(),
        );
      }
      _appendLog('SHA-256 Verified — ${sha256Hash ?? '(unknown)'}');

      _appendLog('Extracting metadata…');
      final metadata = await _runtime.extractMetadataReturning(_verificationId!);
      _metadataId = metadata['id'] as String?;
      if (metadata['status'] != 'extracted') {
        throw AcquisitionApiException(
          message: metadata['error_message'] as String? ?? 'Metadata extraction failed.',
          technicalDetail: metadata.toString(),
        );
      }
      _appendLog('Metadata Extracted');

      _appendLog('Publishing to Reference Vault…');
      final vaultEntry = await _runtime.publishReturning(_metadataId!);
      vaultEntryId = vaultEntry['id'] as String?;
      vaultPath = vaultEntry['vault_path'] as String?;
      _appendLog('Published — permanent, content-addressable, immutable');

      await _runtime.executeJobReturning(_jobId!); // running -> completed

      // Real Chain of Custody, saved locally (see ChainOfCustodyRecord's
      // own doc comment for why local rather than server-side today).
      if (vaultEntryId != null) {
        await _saveCustody(
          vaultEntryId!,
          ChainOfCustodyRecord(
            knowledgeType: knowledgeType ?? '',
            originalUrl: originalUrl.trim(),
            publisher: publisher.trim(),
            publicationDate: publicationDate.trim(),
            revision: revision.trim(),
            license: license.trim(),
            language: language.trim(),
            acquisitionMethod: acquisitionMethod.trim(),
            engineer: engineer.trim(),
            scopeDescription: scopeKind == 'Entire Document' ? scopeKind : '$scopeKind: $scopeDetail',
            recordedAt: DateTime.now().toIso8601String(),
          ),
        );
      }
      _appendLog('Chain of Custody Recorded');

      // Acquisition/Reference Vault publication is complete. Vault
      // publication and Repository commit are deliberately distinct
      // concepts (WP-EAM-003 §12) -- runStatus tracks this stage only.
      runStatus = AcquisitionRunStatus.completed;
      _appendLog('Completed');

      // WP-EAM-003 §7: acquisition does not stop here -- the wizard now
      // immediately orchestrates the existing, unmodified
      // ReferenceVaultIngestionWorkflow (the same one
      // "Ingest into Knowledge Studio" on the Reference Vault panel
      // already uses) rather than leaving the engineer to trigger it
      // manually. This call is orchestration, not reimplementation: the
      // wizard never touches the ingestion pipeline's own internal
      // orchestrator/adapter/bridge classes, and never touches the
      // Foundation Repository write transaction machinery either --
      // only the existing public `AcquisitionRuntimeNotifier.ingestVaultArtifact`
      // and `FoundationRuntimeNotifier.loadKnowledgeSessionRecord` entry
      // points those callers already used.
      await _ingest();
    } on AcquisitionApiException catch (error) {
      runStatus = AcquisitionRunStatus.failed;
      failureMessage = error.message;
      _appendLog(error.message, isError: true);
    } catch (error) {
      runStatus = AcquisitionRunStatus.failed;
      failureMessage = error.toString();
      _appendLog(error.toString(), isError: true);
    }
    notifyListeners();
  }

  /// WP-EAM-003 §5 Option A: the Knowledge Session's repository context is
  /// derived from whichever Foundation Repository is currently open
  /// (`FoundationServiceState.repositoryStatus?.repositoryName`), never
  /// retyped by the engineer -- `KnowledgeSession.repositoryName` exists
  /// only to be compared against the open Repository at Commit time
  /// (`CommitPlanService.computeCommitPlan`'s mismatch check), so OEP
  /// already knows the only value that would ever be valid here. If no
  /// Repository is open, ingestion is deliberately deferred rather than
  /// binding the session to an empty/guessed name -- see
  /// [WizardIngestionStatus.blockedNoRepository] and [retryIngestion].
  Future<void> _ingest() async {
    final entryId = vaultEntryId;
    if (entryId == null) return;

    final openRepositoryName = _ref.read(foundationRuntimeServiceProvider).repositoryStatus?.repositoryName;
    if (openRepositoryName == null || openRepositoryName.trim().isEmpty) {
      ingestionStatus = WizardIngestionStatus.blockedNoRepository;
      _appendLog(
        'No Foundation Repository is open, so the resulting Knowledge Session has nowhere to bind. '
        'Open a Repository, then use "Retry Ingestion" to continue -- the acquired artifact is safely '
        'stored in the Reference Vault regardless.',
        isError: true,
      );
      return;
    }

    ingestionStatus = WizardIngestionStatus.ingesting;
    final sourceName_ = sourceType == AcquisitionSourceType.localDocument ? localFileName : sourceName;
    _appendLog('Ingesting Reference Vault artifact into the Universal Ingestion Framework…');
    notifyListeners();

    try {
      final sessionName = '${knowledgeType ?? 'Acquisition'} — ${sourceName_ ?? entryId}';
      final outcome = await _runtime.ingestVaultArtifact(
        vaultObjectId: entryId,
        sessionName: sessionName,
        repositoryName: openRepositoryName,
        author: engineer.trim(),
        orientation: extractionOrientation,
      );
      ingestionOutcome = outcome;

      // WP-EAM-005 §8/§9: log the ACTUAL executed UIF stages (from the
      // real IngestionRun this outcome carries), not a fixed pair of
      // generic "Started"/"Complete" lines -- this is the defect that let
      // a stale, hardcoded pipeline-unavailable message linger unnoticed
      // in the Activity Log: nothing downstream of it ever surfaced what
      // UIF actually did. `run` is present on both a failed and a
      // successful outcome (the ingestion pipeline's own orchestrator
      // always constructs one), so this reports real stage results even
      // when ingestion ultimately failed.
      final run = outcome.ingestionResult?.run;
      if (run != null) {
        for (final stage in run.stageResults) {
          final label = '${_stageLabel(stage.stage)} — ${_stageStatusLabel(stage.status)}';
          final isProblem =
              stage.status == StageExecutionStatus.failed || stage.status == StageExecutionStatus.partial;
          final diagnostics = stage.diagnostics.isEmpty ? '' : ' (${stage.diagnostics.join('; ')})';
          _appendLog('$label$diagnostics', isError: isProblem);
        }
      }

      if (outcome.isFailed || outcome.isCancelled) {
        ingestionStatus = WizardIngestionStatus.failed;
        ingestionErrorMessage = outcome.errorMessage;
        _appendLog(
          outcome.isCancelled
              ? 'Ingestion cancelled.'
              : 'Ingestion failed — ${outcome.errorMessage ?? 'unknown error'}',
          isError: true,
        );
        return;
      }

      final record = outcome.sessionRecord!;
      knowledgeSessionId = record.session.id;
      // WP-EAM-003 §8: hand the real KnowledgeSessionRecord to the
      // existing, centralized Knowledge Studio state owner -- the same
      // path the Reference Vault panel's own ingestion entry point uses.
      await _ref.read(foundationRuntimeServiceProvider.notifier).loadKnowledgeSessionRecord(record);

      ingestionStatus =
          outcome.isPartial ? WizardIngestionStatus.partial : WizardIngestionStatus.completed;
      final candidateCount = record.candidates.length;
      _appendLog(
        outcome.isPartial
            ? 'Knowledge Session ready (partial) — $candidateCount candidate(s) from the results that succeeded.'
            : 'Knowledge Session ready — $candidateCount candidate(s) generated.',
      );
    } catch (error) {
      ingestionStatus = WizardIngestionStatus.failed;
      ingestionErrorMessage = error.toString();
      _appendLog('Ingestion failed — $error', isError: true);
    }
  }

  /// Re-attempts ingestion after it was deferred by
  /// [WizardIngestionStatus.blockedNoRepository] (or failed and the
  /// engineer wants to try again) -- without re-running acquisition
  /// itself, since the artifact is already published to the Reference
  /// Vault and re-publishing it would be pointless work against an
  /// immutable store (WP-EAM-003 §15: never fake progress, but also never
  /// force redundant real work).
  Future<void> retryIngestion() async {
    if (vaultEntryId == null) return;
    if (ingestionStatus == WizardIngestionStatus.ingesting) return;
    await _ingest();
    notifyListeners();
  }
}

final acquisitionWizardControllerProvider =
    ChangeNotifierProvider.autoDispose<AcquisitionWizardController>((ref) => AcquisitionWizardController(ref));
