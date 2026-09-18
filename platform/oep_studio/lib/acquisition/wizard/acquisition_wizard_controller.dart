import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../services/acquisition_api_exception.dart';
import '../services/acquisition_runtime_service.dart';
import '../services/reference_vault_ingestion_workflow.dart';
import 'chain_of_custody_record.dart';
import 'chain_of_custody_storage.dart';

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
  String? sourceId;
  String? sourceName;

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

  bool get canGoNext => switch (_stepIndex) {
        0 => knowledgeType != null,
        1 => sourceId != null,
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

    try {
      _appendLog('Initializing…');
      final jobName = knowledgeType == null ? 'Acquisition' : 'Acquire $knowledgeType';
      final job = await _runtime.createJobReturning({
        'source_id': sourceId,
        'name': jobName,
        'priority': 2,
        if (engineer.trim().isNotEmpty) 'requested_by': engineer.trim(),
      });
      _jobId = job['id'] as String?;
      if (_jobId == null) throw StateError('Job creation did not return an id.');

      _appendLog('Connecting…');
      await _runtime.executeJobReturning(_jobId!); // created -> queued
      await _runtime.executeJobReturning(_jobId!); // queued -> running

      _appendLog('Downloading…');
      downloadProgress = 0;
      notifyListeners();
      final download = await _runtime.startDownloadReturning({
        'job_id': _jobId,
        'connector_id': _connectorId,
        'source_uri': originalUrl.trim(),
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
    _appendLog('Knowledge Extraction Started — ingesting into the Universal Ingestion Framework…');
    notifyListeners();

    try {
      final sessionName = '${knowledgeType ?? 'Acquisition'} — ${sourceName ?? entryId}';
      final outcome = await _runtime.ingestVaultArtifact(
        vaultObjectId: entryId,
        sessionName: sessionName,
        repositoryName: openRepositoryName,
        author: engineer.trim(),
      );
      ingestionOutcome = outcome;

      if (outcome.isFailed || outcome.isCancelled) {
        ingestionStatus = WizardIngestionStatus.failed;
        ingestionErrorMessage = outcome.errorMessage;
        _appendLog('Knowledge Extraction Failed — ${outcome.errorMessage ?? 'unknown error'}', isError: true);
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
      _appendLog(
        outcome.isPartial
            ? 'Knowledge Extraction Complete (partial) — Review Package Created with the results that '
                'succeeded.'
            : 'Knowledge Extraction Complete — Review Package Created.',
      );
    } catch (error) {
      ingestionStatus = WizardIngestionStatus.failed;
      ingestionErrorMessage = error.toString();
      _appendLog('Knowledge Extraction Failed — $error', isError: true);
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
