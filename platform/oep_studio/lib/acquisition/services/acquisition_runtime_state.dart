import '../models/acquisition_connection_status.dart';
import '../models/acquisition_job.dart';
import '../models/artifact_metadata_record.dart';
import '../models/download_session.dart';
import '../models/official_source.dart';
import '../models/vault_entry_record.dart';
import '../models/verification_record.dart';

/// The Acquisition Studio Connection Manager's state (WP-PLAT-020),
/// mirroring `FoundationServiceState`'s own role for Knowledge/Diagram
/// Studio: immutable; widgets watch this through
/// `acquisitionRuntimeServiceProvider` and never call
/// [AcquisitionApiClient] directly. [selectedJobId] drives the Pipeline
/// panel's drill-down (Downloads → Verifications → Metadata for one
/// selected job) — never more than one job selected at a time, the same
/// "at most one current selection" shape `FoundationServiceState` uses.
class AcquisitionServiceState {
  const AcquisitionServiceState({
    this.connectionStatus = AcquisitionConnectionStatus.notTested,
    this.connectionMessage,
    this.loading = false,
    this.sources = const [],
    this.jobs = const [],
    this.downloads = const [],
    this.verifications = const [],
    this.metadata = const [],
    this.vaultEntries = const [],
    this.selectedJobId,
    this.lastError,
  });

  final AcquisitionConnectionStatus connectionStatus;
  final String? connectionMessage;
  final bool loading;
  final List<OfficialSource> sources;
  final List<AcquisitionJob> jobs;
  final List<DownloadSession> downloads;
  final List<VerificationRecord> verifications;
  final List<ArtifactMetadataRecord> metadata;
  final List<VaultEntryRecord> vaultEntries;
  final String? selectedJobId;
  final String? lastError;

  bool get isConnected => connectionStatus == AcquisitionConnectionStatus.connected;

  AcquisitionServiceState copyWith({
    AcquisitionConnectionStatus? connectionStatus,
    String? connectionMessage,
    bool? loading,
    List<OfficialSource>? sources,
    List<AcquisitionJob>? jobs,
    List<DownloadSession>? downloads,
    List<VerificationRecord>? verifications,
    List<ArtifactMetadataRecord>? metadata,
    List<VaultEntryRecord>? vaultEntries,
    String? selectedJobId,
    bool clearSelectedJobId = false,
    String? lastError,
    bool clearLastError = false,
  }) {
    return AcquisitionServiceState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionMessage: connectionMessage ?? this.connectionMessage,
      loading: loading ?? this.loading,
      sources: sources ?? this.sources,
      jobs: jobs ?? this.jobs,
      downloads: downloads ?? this.downloads,
      verifications: verifications ?? this.verifications,
      metadata: metadata ?? this.metadata,
      vaultEntries: vaultEntries ?? this.vaultEntries,
      selectedJobId: clearSelectedJobId ? null : (selectedJobId ?? this.selectedJobId),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}
