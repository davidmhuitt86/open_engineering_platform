import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/platform_event.dart';
import '../../core/events/platform_event_bus.dart';
import '../models/acquisition_connection_status.dart';
import '../models/acquisition_job.dart';
import '../models/artifact_metadata_record.dart';
import '../models/download_session.dart';
import '../models/official_source.dart';
import '../models/vault_entry_record.dart';
import '../models/verification_record.dart';
import '../settings/acquisition_settings_provider.dart';
import 'acquisition_api_client.dart';
import 'acquisition_api_exception.dart';
import 'acquisition_runtime_state.dart';

/// The Acquisition Studio's own Connection Manager (WP-PLAT-020),
/// structurally mirroring `FoundationRuntimeNotifier`'s role for
/// Knowledge/Diagram Studio: the single owner of EAM connectivity and
/// cached EAM data. Widgets watch `acquisitionRuntimeServiceProvider`
/// and call methods on its notifier; no widget constructs an
/// [AcquisitionApiClient] or calls `dart:http` itself, the same
/// "widgets never touch the bridge directly" rule
/// `docs/CONNECTION_MANAGER.md` documents for Foundation.
///
/// Rebuilds its [AcquisitionApiClient] whenever
/// `acquisitionSettingsProvider`'s `apiBaseUrl` changes (e.g. the
/// engineer edits the address on the Engineering Acquisition settings
/// page), so a corrected address takes effect without an app restart.
class AcquisitionRuntimeNotifier extends Notifier<AcquisitionServiceState> {
  AcquisitionApiClient? _client;

  @override
  AcquisitionServiceState build() {
    final baseUrl = ref.watch(acquisitionSettingsProvider).apiBaseUrl;
    _client?.dispose();
    _client = AcquisitionApiClient(baseUrl: baseUrl);
    ref.onDispose(() => _client?.dispose());
    return const AcquisitionServiceState();
  }

  AcquisitionApiClient get _api => _client!;

  /// Publishes an [OperationEvent] for every real EAM operation, so
  /// Engineering Acquisition work shows up in the Platform's own
  /// `ActivityLog`/`OperationManager` -- and therefore in the Output
  /// Panel -- exactly like Acquisition downloads and Knowledge Studio's
  /// OCR passes already do. Without this, EAM was the one subsystem
  /// doing real long-running work that reported nothing anywhere
  /// ("Every long-running operation throughout OEP should eventually
  /// report here").
  ///
  /// Overridable so tests can observe published events (or suppress them
  /// entirely) without reaching for the app-wide `PlatformEventBus`
  /// singleton, matching `StudioShell`'s own `eventBus` seam.
  @protected
  PlatformEventBus get eventBus => PlatformEventBus.instance;

  int _operationSeq = 0;

  /// The prefix every EAM operation label carries. `ActivityLog` records
  /// operations without a Studio attribution (`_handleOperation` passes
  /// no `studioLabel`), and several real pipeline steps -- "Downloading
  /// …", "Verifying artifact integrity …", "Publishing to Reference
  /// Vault" -- contain no word that identifies them as acquisition work,
  /// so the Output Panel's Acquisition Log tab needs a stable marker to
  /// filter on rather than guessing from prose.
  static const operationLabelPrefix = 'Engineering Acquisition — ';

  /// Runs [action] while reporting it as a real, trackable operation.
  Future<T> _reportingOperation<T>(String label, Future<T> Function() action) async {
    final id = 'acquisition:${_operationSeq++}';
    final prefixed = '$operationLabelPrefix$label';
    eventBus.publish(OperationEvent(id: id, kind: OperationEventKind.started, label: prefixed));
    try {
      final result = await action();
      eventBus.publish(OperationEvent(id: id, kind: OperationEventKind.completed, label: prefixed));
      return result;
    } catch (error) {
      final message = error is AcquisitionApiException ? error.message : error.toString();
      eventBus.publish(
        OperationEvent(id: id, kind: OperationEventKind.failed, label: '$prefixed — $message'),
      );
      rethrow;
    }
  }

  /// `GET /health` — used by the workspace's connection banner and
  /// Settings' "Test Connection" action.
  Future<void> testConnection() async {
    state = state.copyWith(loading: true, clearLastError: true);
    final reachable = await _api.checkHealth();
    state = state.copyWith(
      loading: false,
      connectionStatus: reachable ? AcquisitionConnectionStatus.connected : AcquisitionConnectionStatus.networkError,
      connectionMessage: reachable ? 'Connected' : 'Could not reach the Engineering Acquisition service.',
    );
  }

  /// Refreshes Sources, Jobs, and Vault — the workspace's three primary
  /// panels. Downloads/Verifications/Metadata for the selected job are
  /// refreshed separately by [selectJob], since they are scoped to one
  /// job rather than global lists.
  Future<void> refreshAll() async {
    state = state.copyWith(loading: true, clearLastError: true);
    try {
      final sources = await _api.listSources();
      final jobs = await _api.listJobs();
      final vault = await _api.listVault();
      state = state.copyWith(
        loading: false,
        connectionStatus: AcquisitionConnectionStatus.connected,
        sources: sources.map(OfficialSource.fromJson).toList(),
        jobs: jobs.map(AcquisitionJob.fromJson).toList(),
        vaultEntries: vault.map(VaultEntryRecord.fromJson).toList(),
      );
      if (state.selectedJobId != null) {
        await _refreshPipeline(state.selectedJobId!);
      }
    } on AcquisitionApiException catch (error) {
      state = state.copyWith(
        loading: false,
        connectionStatus: AcquisitionConnectionStatus.networkError,
        lastError: error.message,
      );
    }
  }

  Future<void> createSource(Map<String, Object?> body) => _runAction(() async {
        await _api.createSource(body);
        await refreshAll();
      });

  Future<void> createJob(Map<String, Object?> body) => _runAction(() async {
        await _api.createJob(body);
        await refreshAll();
      });

  Future<void> executeJob(String jobId) => _runAction(() async {
        await _api.executeJob(jobId);
        await refreshAll();
      });

  Future<void> cancelJob(String jobId) => _runAction(() async {
        await _api.cancelJob(jobId);
        await refreshAll();
      });

  Future<void> startDownload(Map<String, Object?> body) => _runAction(() async {
        await _api.startDownload(body);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
      });

  Future<void> verify(String downloadSessionId) => _runAction(() async {
        await _api.verify(downloadSessionId);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
      });

  Future<void> extractMetadata(String verificationId) => _runAction(() async {
        await _api.extractMetadata(verificationId);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
      });

  Future<void> publish(String metadataId) => _runAction(() async {
        await _api.publish(metadataId);
        await refreshAll();
      });

  // --- Value-returning variants -------------------------------------------
  //
  // The methods above exist for the classic panel-driven workflow (a
  // widget triggers an action, then reads the *refreshed list state* to
  // see the result). The Acquisition Wizard (`lib/acquisition/wizard/`)
  // instead drives a single, automatic Source -> Job -> Download ->
  // Verify -> Metadata -> Vault chain where each step needs the *id* the
  // previous step's response just returned, so it can be threaded
  // straight into the next request without waiting on a separate list
  // refresh + lookup. These wrap the exact same `AcquisitionApiClient`
  // calls (no new HTTP surface, no backend change) and still refresh
  // `state` afterward so the classic panels stay in sync regardless of
  // which caller triggered the action.

  Future<Map<String, Object?>> createSourceReturning(Map<String, Object?> body) =>
      _reportingOperation('Acquisition: Registering Official Source "${body['name'] ?? ''}"', () async {
        final result = await _api.createSource(body);
        await refreshAll();
        return result;
      });

  Future<Map<String, Object?>> createJobReturning(Map<String, Object?> body) =>
      _reportingOperation('Acquisition: Creating Job "${body['name'] ?? ''}"', () async {
        final result = await _api.createJob(body);
        await refreshAll();
        return result;
      });

  Future<Map<String, Object?>> executeJobReturning(String jobId) =>
      _reportingOperation('Acquisition: Advancing job status', () async {
        final result = await _api.executeJob(jobId);
        await refreshAll();
        return result;
      });

  Future<Map<String, Object?>> startDownloadReturning(Map<String, Object?> body) =>
      _reportingOperation('Acquisition: Downloading ${body['source_uri'] ?? 'artifact'}', () async {
        final result = await _api.startDownload(body);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
        return result;
      });

  Future<Map<String, Object?>> verifyReturning(String downloadSessionId) =>
      _reportingOperation('Acquisition: Verifying integrity (SHA-256)', () async {
        final result = await _api.verify(downloadSessionId);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
        return result;
      });

  Future<Map<String, Object?>> extractMetadataReturning(String verificationId) =>
      _reportingOperation('Acquisition: Extracting metadata', () async {
        final result = await _api.extractMetadata(verificationId);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
        return result;
      });

  Future<Map<String, Object?>> publishReturning(String metadataId) =>
      _reportingOperation('Acquisition: Publishing to Reference Vault', () async {
        final result = await _api.publish(metadataId);
        await refreshAll();
        return result;
      });

  /// Runs the **complete real acquisition** for an existing Job in one
  /// call: download -> verify -> extract metadata -> publish to the
  /// Reference Vault, then advance the Job to `completed`.
  ///
  /// This exists because `POST /jobs/{id}/execute` is **bookkeeping
  /// only** -- it advances `created -> queued -> running -> completed`
  /// and never fetches anything (see `oep_acquisition`'s own README:
  /// "Each POST .../execute call advances the job by exactly one step").
  /// Executing a Job on its own therefore marks it "completed" while
  /// acquiring literally nothing, which is actively misleading. Real
  /// acquisition only ever happens through `POST /downloads`, and that
  /// needs a `source_uri` the Job model has no field for -- hence the
  /// explicit [sourceUri] parameter here.
  Future<Map<String, Object?>> acquireForJob({required String jobId, required String sourceUri}) async {
    // Advance to `running` first if the job hasn't started -- a download
    // is rejected (`409 job_not_executable`) once a job is terminal.
    final job = state.jobs.where((j) => j.id == jobId).firstOrNull;
    var status = job?.status ?? 'created';
    while (status == 'created' || status == 'queued') {
      final advanced = await executeJobReturning(jobId);
      status = advanced['status'] as String? ?? status;
    }

    final download = await startDownloadReturning({
      'job_id': jobId,
      'connector_id': 'http-source',
      'source_uri': sourceUri,
    });
    if (download['status'] != 'completed') {
      throw AcquisitionApiException(
        message: download['error_message'] as String? ?? 'Download failed.',
        technicalDetail: download.toString(),
      );
    }

    final verification = await verifyReturning(download['id'] as String);
    if (verification['status'] != 'verified') {
      throw AcquisitionApiException(
        message: verification['error_message'] as String? ?? 'Integrity verification failed.',
        technicalDetail: verification.toString(),
      );
    }

    final metadata = await extractMetadataReturning(verification['id'] as String);
    if (metadata['status'] != 'extracted') {
      throw AcquisitionApiException(
        message: metadata['error_message'] as String? ?? 'Metadata extraction failed.',
        technicalDetail: metadata.toString(),
      );
    }

    final vaultEntry = await publishReturning(metadata['id'] as String);
    await executeJobReturning(jobId); // running -> completed
    return vaultEntry;
  }

  /// Selects [jobId] for the Pipeline panel's drill-down (Downloads →
  /// Verifications → Metadata for that one job) — at most one job
  /// selected at a time, mirroring `FoundationServiceState`'s single
  /// current-selection shape.
  Future<void> selectJob(String jobId) async {
    state = state.copyWith(selectedJobId: jobId);
    await _refreshPipeline(jobId);
  }

  void clearJobSelection() {
    state = state.copyWith(clearSelectedJobId: true, downloads: const [], verifications: const [], metadata: const []);
  }

  Future<void> _refreshPipeline(String jobId) => _runAction(() async {
        final downloads = await _api.listDownloads(jobId: jobId);
        final downloadIds = downloads.map((d) => d['id'] as String? ?? '').toList();
        final verifications = <Map<String, Object?>>[];
        for (final downloadId in downloadIds) {
          verifications.addAll(await _api.listVerifications(downloadSessionId: downloadId));
        }
        final verificationIds = verifications.map((v) => v['id'] as String? ?? '').toList();
        final metadata = <Map<String, Object?>>[];
        for (final verificationId in verificationIds) {
          metadata.addAll(await _api.listMetadata(verificationId: verificationId));
        }
        state = state.copyWith(
          downloads: downloads.map(DownloadSession.fromJson).toList(),
          verifications: verifications.map(VerificationRecord.fromJson).toList(),
          metadata: metadata.map(ArtifactMetadataRecord.fromJson).toList(),
        );
      });

  Future<void> _runAction(Future<void> Function() action) async {
    state = state.copyWith(loading: true, clearLastError: true);
    try {
      await action();
      state = state.copyWith(loading: false);
    } on AcquisitionApiException catch (error) {
      state = state.copyWith(loading: false, lastError: error.message);
    }
  }
}

final acquisitionRuntimeServiceProvider = NotifierProvider<AcquisitionRuntimeNotifier, AcquisitionServiceState>(
  AcquisitionRuntimeNotifier.new,
);
