import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/acquisition_api_exception.dart';
import '../services/acquisition_runtime_service.dart';
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

  bool get canGoNext => switch (_stepIndex) {
        0 => knowledgeType != null,
        1 => sourceId != null,
        2 => originalUrl.trim().isNotEmpty && engineer.trim().isNotEmpty,
        3 => true,
        4 => runStatus == AcquisitionRunStatus.completed,
        5 => runStatus == AcquisitionRunStatus.completed,
        6 => true,
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

      // Knowledge Extraction / Candidate Object generation is not
      // implemented anywhere in the backend yet (Milestone 2's
      // Engineering Knowledge Engine) -- disclosed honestly rather than
      // faked. See Step 7/8's own widgets.
      _appendLog('Knowledge Extraction: not yet available (Knowledge Engine not built)');

      runStatus = AcquisitionRunStatus.completed;
      _appendLog('Completed');
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
}

final acquisitionWizardControllerProvider =
    ChangeNotifierProvider.autoDispose<AcquisitionWizardController>((ref) => AcquisitionWizardController(ref));
