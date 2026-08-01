import 'dart:convert';
import 'dart:ffi';

import '../models/object_category.dart';
import '../models/relationship_type.dart';
import 'oep_api_native_types.dart';

/// Mirrors `oep_runtime_state_t`. Deliberately a 1:1 copy of the native
/// enum (including numeric values) rather than a re-imagined Studio
/// concept — Foundation owns this state machine; Studio just displays it.
enum FoundationRuntimeState {
  uninitialized(0, 'Uninitialized'),
  initialized(1, 'Initialized'),
  repositoryOpen(2, 'Repository Open'),
  repositoryClosed(3, 'Repository Closed'),
  shutdown(4, 'Shutdown');

  const FoundationRuntimeState(this.nativeValue, this.displayLabel);

  final int nativeValue;

  /// Human-readable label for display (e.g. in the Dashboard), distinct
  /// from the enum's own [name] (camelCase, meant for code).
  final String displayLabel;

  static FoundationRuntimeState fromNative(int value) {
    return FoundationRuntimeState.values.firstWhere(
      (state) => state.nativeValue == value,
      orElse: () => FoundationRuntimeState.uninitialized,
    );
  }
}

/// Mirrors `oep_error_code_t`.
enum FoundationErrorCode {
  none(0),
  invalidArgument(1),
  invalidState(2),
  notFound(3),
  operationFailed(4),
  internalError(5);

  const FoundationErrorCode(this.nativeValue);

  final int nativeValue;

  static FoundationErrorCode fromNative(int value) {
    return FoundationErrorCode.values.firstWhere(
      (code) => code.nativeValue == value,
      orElse: () => FoundationErrorCode.internalError,
    );
  }
}

/// Mirrors `oep_error_category_t`.
enum FoundationErrorCategory {
  none(0),
  validation(1),
  state(2),
  io(3),
  internalError(4);

  const FoundationErrorCategory(this.nativeValue);

  final int nativeValue;

  static FoundationErrorCategory fromNative(int value) {
    return FoundationErrorCategory.values.firstWhere(
      (category) => category.nativeValue == value,
      orElse: () => FoundationErrorCategory.internalError,
    );
  }
}

/// Plain Dart snapshot of `oep_repository_status_t`. Immutable and
/// pointer-free, decoded once from the native struct and never referenced
/// again — nothing above the Bridge holds onto native memory.
class RepositoryStatus {
  const RepositoryStatus({
    required this.repositoryId,
    required this.repositoryName,
    required this.repositoryVersion,
    required this.loadedPackageCount,
  });

  factory RepositoryStatus.fromNative(OepRepositoryStatusNative native) {
    return RepositoryStatus(
      repositoryId: decodeFixedCString(native.repositoryId, oepRepositoryIdSize),
      repositoryName: decodeFixedCString(native.repositoryName, oepRepositoryNameSize),
      repositoryVersion: decodeFixedCString(native.repositoryVersion, oepRepositoryVersionSize),
      loadedPackageCount: native.loadedPackageCount,
    );
  }

  final String repositoryId;
  final String repositoryName;
  final String repositoryVersion;
  final int loadedPackageCount;
}

/// Plain Dart snapshot of `oep_repository_statistics_t`. Immutable and
/// pointer-free, decoded once from the native struct.
class RepositoryStatistics {
  const RepositoryStatistics({
    required this.repositoryId,
    required this.repositoryName,
    required this.repositoryVersion,
    required this.totalObjectCount,
    required this.objectCountByCategory,
    required this.relationshipCount,
    required this.packageCount,
  });

  factory RepositoryStatistics.fromNative(OepRepositoryStatisticsNative native) {
    final countByCategory = <ObjectCategory, int>{
      for (final category in ObjectCategory.values) category: native.objectCountByType[category.nativeValue],
    };

    return RepositoryStatistics(
      repositoryId: decodeFixedCString(native.repositoryId, oepRepositoryIdSize),
      repositoryName: decodeFixedCString(native.repositoryName, oepRepositoryNameSize),
      repositoryVersion: decodeFixedCString(native.repositoryVersion, oepRepositoryVersionSize),
      totalObjectCount: native.totalObjectCount,
      objectCountByCategory: countByCategory,
      relationshipCount: native.relationshipCount,
      packageCount: native.packageCount,
    );
  }

  final String repositoryId;
  final String repositoryName;
  final String repositoryVersion;
  final int totalObjectCount;

  /// Object count per category, computed by Foundation
  /// (`oep_repository_statistics_t::object_count_by_type`) — Studio
  /// never recomputes this by enumerating objects itself.
  final Map<ObjectCategory, int> objectCountByCategory;
  final int relationshipCount;
  final int packageCount;

  /// Serializes for `CommitReport`'s "Repository Statistics Before"/
  /// "Repository Statistics After" (Work Package 012 STUDIO-TASK-000033)
  /// — the only reason this snapshot, otherwise ephemeral (decoded from
  /// a native struct and never previously persisted), needs a JSON
  /// shape at all.
  Map<String, dynamic> toJson() => {
    'repositoryId': repositoryId,
    'repositoryName': repositoryName,
    'repositoryVersion': repositoryVersion,
    'totalObjectCount': totalObjectCount,
    'objectCountByCategory': {for (final entry in objectCountByCategory.entries) entry.key.name: entry.value},
    'relationshipCount': relationshipCount,
    'packageCount': packageCount,
  };

  factory RepositoryStatistics.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['objectCountByCategory'] as Map<String, dynamic>? ?? const {};
    return RepositoryStatistics(
      repositoryId: json['repositoryId'] as String,
      repositoryName: json['repositoryName'] as String,
      repositoryVersion: json['repositoryVersion'] as String,
      totalObjectCount: json['totalObjectCount'] as int,
      objectCountByCategory: {
        for (final category in ObjectCategory.values) category: (rawCounts[category.name] as int?) ?? 0,
      },
      relationshipCount: json['relationshipCount'] as int,
      packageCount: json['packageCount'] as int,
    );
  }
}

/// Plain Dart snapshot of `oep_package_install_result_t` (WP-REP-001 —
/// Repository Runtime, first vertical slice). Only populated when the
/// install call itself succeeded — a failed install throws
/// [FoundationBridgeException] instead, per every other Bridge mutation.
class PackageInstallResult {
  const PackageInstallResult({
    required this.packageId,
    required this.version,
    required this.objectsCreated,
    required this.relationshipsCreated,
  });

  factory PackageInstallResult.fromNative(OepPackageInstallResultNative native) {
    return PackageInstallResult(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      version: decodeFixedCString(native.version, oepMaxPackageVersion),
      objectsCreated: native.objectsCreated,
      relationshipsCreated: native.relationshipsCreated,
    );
  }

  final String packageId;
  final String version;
  final int objectsCreated;
  final int relationshipsCreated;
}

/// Plain Dart snapshot of one `oep_installed_package_info_t` — one
/// Package Registry record (WP-REP-001).
class InstalledPackageInfo {
  const InstalledPackageInfo({
    required this.packageId,
    required this.version,
    required this.title,
    required this.installedUtc,
    required this.source,
    required this.objectCount,
    required this.relationshipCount,
  });

  factory InstalledPackageInfo.fromNative(OepInstalledPackageInfoNative native) {
    return InstalledPackageInfo(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      version: decodeFixedCString(native.version, oepMaxPackageVersion),
      title: decodeFixedCString(native.title, oepMaxPackageTitle),
      installedUtc: decodeFixedCString(native.installedUtc, oepMaxTimestamp),
      source: decodeFixedCString(native.source, oepMaxPackageSource),
      objectCount: native.objectCount,
      relationshipCount: native.relationshipCount,
    );
  }

  final String packageId;
  final String version;
  final String title;
  final String installedUtc;
  final String source;
  final int objectCount;
  final int relationshipCount;
}

/// Plain Dart snapshot of one `oep_package_details_t` — the full
/// Repository Registry record for one installed package (WP-REP-002 —
/// Repository Registry & Lifecycle).
class PackageDetails {
  const PackageDetails({
    required this.packageId,
    required this.version,
    required this.title,
    required this.summary,
    required this.category,
    required this.publisherId,
    required this.publisherName,
    required this.installedUtc,
    required this.source,
    required this.installationPath,
    required this.packageHash,
    required this.runtimeState,
    required this.engineeringDomains,
    required this.objectCount,
    required this.relationshipCount,
  });

  factory PackageDetails.fromNative(OepPackageDetailsNative native) {
    final domains = <String>[
      for (var i = 0; i < native.engineeringDomainCount; i++)
        decodeFixedCString(native.engineeringDomains[i], oepMaxPackageDomainLength),
    ];
    return PackageDetails(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      version: decodeFixedCString(native.version, oepMaxPackageVersion),
      title: decodeFixedCString(native.title, oepMaxPackageTitle),
      summary: decodeFixedCString(native.summary, oepMaxPackageSummary),
      category: decodeFixedCString(native.category, oepMaxPackageCategory),
      publisherId: decodeFixedCString(native.publisherId, oepMaxPackagePublisher),
      publisherName: decodeFixedCString(native.publisherName, oepMaxPackagePublisher),
      installedUtc: decodeFixedCString(native.installedUtc, oepMaxTimestamp),
      source: decodeFixedCString(native.source, oepMaxPackageSource),
      installationPath: decodeFixedCString(native.installationPath, oepMaxPackagePath),
      packageHash: decodeFixedCString(native.packageHash, oepMaxPackageHash),
      runtimeState: decodeFixedCString(native.runtimeState, oepMaxPackageState),
      engineeringDomains: domains,
      objectCount: native.objectCount,
      relationshipCount: native.relationshipCount,
    );
  }

  final String packageId;
  final String version;
  final String title;
  final String summary;
  final String category;
  final String publisherId;
  final String publisherName;
  final String installedUtc;
  final String source;
  final String installationPath;
  final String packageHash;
  final String runtimeState;
  final List<String> engineeringDomains;
  final int objectCount;
  final int relationshipCount;
}

/// Mirrors `oep_owned_entity_kind_t` (WP-REP-002).
enum OwnedEntityKind {
  none(0),
  object(1),
  relationship(2);

  const OwnedEntityKind(this.nativeValue);

  final int nativeValue;

  static OwnedEntityKind fromNative(int value) {
    return OwnedEntityKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => OwnedEntityKind.none,
    );
  }
}

/// Plain Dart snapshot of `oep_package_owner_t` (WP-REP-002): which
/// installed package (if any) contributed an Engineering Object or
/// Relationship. `found == false` is a normal answer, not an error.
class PackageOwner {
  const PackageOwner({
    required this.found,
    required this.kind,
    required this.packageId,
    required this.version,
    required this.title,
  });

  factory PackageOwner.fromNative(OepPackageOwnerNative native) {
    return PackageOwner(
      found: native.found != 0,
      kind: OwnedEntityKind.fromNative(native.kind),
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      version: decodeFixedCString(native.version, oepMaxPackageVersion),
      title: decodeFixedCString(native.title, oepMaxPackageTitle),
    );
  }

  final bool found;
  final OwnedEntityKind kind;
  final String packageId;
  final String version;
  final String title;
}

/// Plain Dart snapshot of `oep_package_verify_result_t` (WP-REP-002).
/// A missing archive is not a verification failure — see
/// [archiveAvailable].
class PackageVerifyResult {
  const PackageVerifyResult({
    required this.verified,
    required this.objectsExpected,
    required this.objectsPresent,
    required this.relationshipsExpected,
    required this.relationshipsPresent,
    required this.archiveAvailable,
    required this.archiveHashMatches,
  });

  factory PackageVerifyResult.fromNative(OepPackageVerifyResultNative native) {
    return PackageVerifyResult(
      verified: native.verified != 0,
      objectsExpected: native.objectsExpected,
      objectsPresent: native.objectsPresent,
      relationshipsExpected: native.relationshipsExpected,
      relationshipsPresent: native.relationshipsPresent,
      archiveAvailable: native.archiveAvailable != 0,
      archiveHashMatches: native.archiveHashMatches != 0,
    );
  }

  final bool verified;
  final int objectsExpected;
  final int objectsPresent;
  final int relationshipsExpected;
  final int relationshipsPresent;
  final bool archiveAvailable;

  /// Only meaningful when [archiveAvailable] is true.
  final bool archiveHashMatches;
}

/// Plain Dart snapshot of `oep_transaction_info_t` (WP-REP-003 —
/// Repository Transaction Engine): the currently active transaction.
/// `active == false` is a normal answer, not an error.
class TransactionInfo {
  const TransactionInfo({
    required this.active,
    required this.transactionId,
    required this.description,
    required this.journalEntryCount,
  });

  factory TransactionInfo.fromNative(OepTransactionInfoNative native) {
    return TransactionInfo(
      active: native.active != 0,
      transactionId: decodeFixedCString(native.transactionId, oepMaxTransactionId),
      description: decodeFixedCString(native.description, oepMaxTransactionDescription),
      journalEntryCount: native.journalEntryCount,
    );
  }

  final bool active;
  final String transactionId;
  final String description;
  final int journalEntryCount;
}

/// Plain Dart snapshot of one `oep_transaction_record_t` — one journaled
/// (closed) Repository Transaction (WP-REP-003). `state` is one of
/// "Committed", "RolledBack", or "Failed".
class TransactionRecordSummary {
  const TransactionRecordSummary({
    required this.transactionId,
    required this.state,
    required this.description,
    required this.openedUtc,
    required this.closedUtc,
    required this.journalEntryCount,
  });

  factory TransactionRecordSummary.fromNative(OepTransactionRecordNative native) {
    return TransactionRecordSummary(
      transactionId: decodeFixedCString(native.transactionId, oepMaxTransactionId),
      state: decodeFixedCString(native.state, oepMaxTransactionState),
      description: decodeFixedCString(native.description, oepMaxTransactionDescription),
      openedUtc: decodeFixedCString(native.openedUtc, oepMaxTimestamp),
      closedUtc: decodeFixedCString(native.closedUtc, oepMaxTimestamp),
      journalEntryCount: native.journalEntryCount,
    );
  }

  final String transactionId;
  final String state;
  final String description;
  final String openedUtc;
  final String closedUtc;
  final int journalEntryCount;
}

/// Mirrors `oep_trust_state_t` (WP-REP-004 — Trust & Signing).
enum TrustState {
  trusted(0),
  unsigned(1),
  unknownPublisher(2),
  expiredCertificate(3),
  revokedCertificate(4),
  invalidSignature(5),
  tampered(6);

  const TrustState(this.nativeValue);

  final int nativeValue;

  static TrustState fromNative(int value) {
    return TrustState.values.firstWhere(
      (state) => state.nativeValue == value,
      orElse: () => TrustState.invalidSignature,
    );
  }
}

/// Plain Dart snapshot of one `oep_publisher_certificate_t` — one
/// locally trusted publisher certificate in this repository's Trust
/// Store (WP-REP-004, PKG-005 §7).
class PublisherCertificate {
  const PublisherCertificate({
    required this.publisherId,
    required this.publisherName,
    required this.publicKeyHex,
    required this.issuedUtc,
    required this.expiresUtc,
    required this.issuer,
    required this.version,
    required this.fingerprint,
    required this.revoked,
    required this.revokedUtc,
  });

  factory PublisherCertificate.fromNative(OepPublisherCertificateNative native) {
    return PublisherCertificate(
      publisherId: decodeFixedCString(native.publisherId, oepMaxPublisherId),
      publisherName: decodeFixedCString(native.publisherName, oepMaxPublisherName),
      publicKeyHex: decodeFixedCString(native.publicKeyHex, oepMaxPublicKeyHex),
      issuedUtc: decodeFixedCString(native.issuedUtc, oepMaxTimestamp),
      expiresUtc: decodeFixedCString(native.expiresUtc, oepMaxTimestamp),
      issuer: decodeFixedCString(native.issuer, oepMaxCertIssuer),
      version: decodeFixedCString(native.version, oepMaxCertVersion),
      fingerprint: decodeFixedCString(native.fingerprint, oepMaxFingerprint),
      revoked: native.revoked != 0,
      revokedUtc: decodeFixedCString(native.revokedUtc, oepMaxTimestamp),
    );
  }

  final String publisherId;
  final String publisherName;
  final String publicKeyHex;
  final String issuedUtc;
  final String expiresUtc;
  final String issuer;
  final String version;
  final String fingerprint;
  final bool revoked;
  final String revokedUtc;
}

/// Plain Dart snapshot of `oep_package_trust_status_t` (WP-REP-004): the
/// trust outcome recorded for an installed package at install time.
class PackageTrustStatus {
  const PackageTrustStatus({required this.state, required this.fingerprint});

  factory PackageTrustStatus.fromNative(OepPackageTrustStatusNative native) {
    return PackageTrustStatus(
      state: TrustState.fromNative(native.state),
      fingerprint: decodeFixedCString(native.fingerprint, oepMaxFingerprint),
    );
  }

  final TrustState state;

  /// Empty unless a certificate was matched.
  final String fingerprint;
}

/// Mirrors `oep_dependency_state_t` (WP-REP-005 — Dependency Resolution
/// Engine).
enum DependencyState {
  satisfied(0),
  missing(1),
  optional(2),
  conflicting(3),
  cyclic(4),
  unknown(5);

  const DependencyState(this.nativeValue);

  final int nativeValue;

  static DependencyState fromNative(int value) {
    return DependencyState.values.firstWhere(
      (state) => state.nativeValue == value,
      orElse: () => DependencyState.unknown,
    );
  }
}

/// Plain Dart snapshot of one `oep_dependency_entry_t` (WP-REP-005): one
/// resolved dependency, in the candidate manifest's own declaration
/// order.
class OepDependencyEntry {
  const OepDependencyEntry({
    required this.packageId,
    required this.versionConstraint,
    required this.optional,
    required this.state,
    required this.installedVersion,
  });

  factory OepDependencyEntry.fromNative(OepDependencyEntryNative native) {
    return OepDependencyEntry(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      versionConstraint: decodeFixedCString(native.versionConstraint, oepMaxVersionConstraint),
      optional: native.optional != 0,
      state: DependencyState.fromNative(native.state),
      installedVersion: decodeFixedCString(native.installedVersion, oepMaxPackageVersion),
    );
  }

  final String packageId;

  /// Empty means "any version".
  final String versionConstraint;
  final bool optional;
  final DependencyState state;

  /// Empty iff not installed.
  final String installedVersion;
}

/// Plain Dart snapshot of `oep_dependency_resolution_result_t`
/// (WP-REP-005): the overall resolution outcome.
class OepDependencyResolutionResult {
  const OepDependencyResolutionResult({
    required this.resolved,
    required this.cycleDetected,
    required this.cycleDescription,
  });

  factory OepDependencyResolutionResult.fromNative(OepDependencyResolutionResultNative native) {
    return OepDependencyResolutionResult(
      resolved: native.resolved != 0,
      cycleDetected: native.cycleDetected != 0,
      cycleDescription: decodeFixedCString(native.cycleDescription, oepMaxCycleDescription),
    );
  }

  /// True iff every dependency resolved (no Missing/Conflicting/
  /// Cyclic/Unknown entries).
  final bool resolved;
  final bool cycleDetected;

  /// Human-readable cycle chain (e.g. "A -> B -> C -> A"); empty when
  /// [cycleDetected] is false.
  final String cycleDescription;
}

/// Mirrors `oep_event_type_t` (WP-REP-006 — Repository Events).
enum EventType {
  objectCreated(0),
  objectUpdated(1),
  objectDeleted(2),
  relationshipCreated(3),
  relationshipUpdated(4),
  relationshipDeleted(5),
  transactionBegun(6),
  transactionCommitted(7),
  transactionRolledBack(8),
  packageInstalled(9),
  packageInstallFailed(10),
  dependencyResolutionCompleted(11),
  packageUninstalled(12),
  packageUpdated(13),
  repositoryMerged(14);

  const EventType(this.nativeValue);

  final int nativeValue;

  static EventType fromNative(int value) {
    return EventType.values.firstWhere(
      (type) => type.nativeValue == value,
      orElse: () => EventType.objectCreated,
    );
  }
}

/// Plain Dart snapshot of one `oep_repository_event_t` (WP-REP-006): one
/// published Repository Event.
class OepRepositoryEvent {
  const OepRepositoryEvent({
    required this.type,
    required this.subjectId,
    required this.detail,
    required this.occurredAtUtc,
    required this.sequence,
  });

  factory OepRepositoryEvent.fromNative(OepRepositoryEventNative native) {
    return OepRepositoryEvent(
      type: EventType.fromNative(native.type),
      subjectId: decodeFixedCString(native.subjectId, oepMaxEventSubjectId),
      detail: decodeFixedCString(native.detail, oepMaxEventDetail),
      occurredAtUtc: decodeFixedCString(native.occurredAtUtc, oepMaxEventTimestamp),
      sequence: native.sequence,
    );
  }

  final EventType type;
  final String subjectId;
  final String detail;
  final String occurredAtUtc;

  /// 1-based position in this Runtime's publication order.
  final int sequence;
}

/// Plain Dart snapshot of `oep_uninstall_impact_t` (WP-REP-007 — Package
/// Uninstall/Update Lifecycle): a dry-run report of what uninstalling a
/// package would affect. `found == false` is a normal answer (the
/// package is not installed), not an error.
class OepUninstallImpact {
  const OepUninstallImpact({
    required this.found,
    required this.objectsAffected,
    required this.relationshipsAffected,
    required this.removable,
  });

  factory OepUninstallImpact.fromNative(OepUninstallImpactNative native) {
    return OepUninstallImpact(
      found: native.found != 0,
      objectsAffected: native.objectsAffected,
      relationshipsAffected: native.relationshipsAffected,
      removable: native.removable != 0,
    );
  }

  final bool found;
  final int objectsAffected;
  final int relationshipsAffected;

  /// False iff other installed packages depend on this one — see the
  /// accompanying blocking-dependents list returned alongside this.
  final bool removable;
}

/// Plain Dart snapshot of `oep_package_uninstall_result_t` (WP-REP-007).
class OepPackageUninstallResult {
  const OepPackageUninstallResult({
    required this.packageId,
    required this.objectsRemoved,
    required this.relationshipsRemoved,
  });

  factory OepPackageUninstallResult.fromNative(OepPackageUninstallResultNative native) {
    return OepPackageUninstallResult(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      objectsRemoved: native.objectsRemoved,
      relationshipsRemoved: native.relationshipsRemoved,
    );
  }

  final String packageId;
  final int objectsRemoved;
  final int relationshipsRemoved;
}

/// Plain Dart snapshot of `oep_update_impact_t` (WP-REP-007): a dry-run
/// report of what updating to a candidate archive would affect.
class OepUpdateImpact {
  const OepUpdateImpact({
    required this.currentlyInstalled,
    required this.currentVersion,
    required this.candidateVersion,
    required this.trustStatus,
    required this.updatable,
  });

  factory OepUpdateImpact.fromNative(OepUpdateImpactNative native) {
    return OepUpdateImpact(
      currentlyInstalled: native.currentlyInstalled != 0,
      currentVersion: decodeFixedCString(native.currentVersion, oepMaxPackageVersion),
      candidateVersion: decodeFixedCString(native.candidateVersion, oepMaxPackageVersion),
      trustStatus: decodeFixedCString(native.trustStatus, oepMaxTrustStatus),
      updatable: native.updatable != 0,
    );
  }

  final bool currentlyInstalled;

  /// Empty iff [currentlyInstalled] is false.
  final String currentVersion;
  final String candidateVersion;
  final String trustStatus;
  final bool updatable;
}

/// Plain Dart snapshot of `oep_package_update_result_t` (WP-REP-007).
class OepPackageUpdateResult {
  const OepPackageUpdateResult({
    required this.packageId,
    required this.previousVersion,
    required this.newVersion,
    required this.objectsRemoved,
    required this.relationshipsRemoved,
    required this.objectsCreated,
    required this.relationshipsCreated,
    required this.trustStatus,
  });

  factory OepPackageUpdateResult.fromNative(OepPackageUpdateResultNative native) {
    return OepPackageUpdateResult(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      previousVersion: decodeFixedCString(native.previousVersion, oepMaxPackageVersion),
      newVersion: decodeFixedCString(native.newVersion, oepMaxPackageVersion),
      objectsRemoved: native.objectsRemoved,
      relationshipsRemoved: native.relationshipsRemoved,
      objectsCreated: native.objectsCreated,
      relationshipsCreated: native.relationshipsCreated,
      trustStatus: decodeFixedCString(native.trustStatus, oepMaxTrustStatus),
    );
  }

  final String packageId;
  final String previousVersion;
  final String newVersion;
  final int objectsRemoved;
  final int relationshipsRemoved;
  final int objectsCreated;
  final int relationshipsCreated;
  final String trustStatus;
}

/// Mirrors `oep_merge_conflict_kind_t` (WP-REP-008 — Merge Engine).
enum MergeConflictKind {
  objectContent(0),
  relationshipContent(1),
  relationshipMissingEndpoint(2);

  const MergeConflictKind(this.nativeValue);

  final int nativeValue;

  static MergeConflictKind fromNative(int value) {
    return MergeConflictKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => MergeConflictKind.objectContent,
    );
  }
}

/// Plain Dart snapshot of one `oep_merge_conflict_t` (WP-REP-008): one
/// entry from a merge plan's conflict list.
class OepMergeConflict {
  const OepMergeConflict({required this.kind, required this.entityId, required this.detail});

  factory OepMergeConflict.fromNative(OepMergeConflictNative native) {
    return OepMergeConflict(
      kind: MergeConflictKind.fromNative(native.kind),
      entityId: decodeFixedCString(native.entityId, oepMaxObjectId),
      detail: decodeFixedCString(native.detail, 256),
    );
  }

  final MergeConflictKind kind;
  final String entityId;
  final String detail;
}

/// Plain Dart snapshot of `oep_merge_plan_t` (WP-REP-008): a dry-run
/// report of what merging an archive's Repository Fragment into the
/// currently open repository would do. `conflicts` is returned
/// separately alongside this plan.
class OepMergePlan {
  const OepMergePlan({
    required this.packageId,
    required this.version,
    required this.trustStatus,
    required this.trustBlocks,
    required this.dependencyBlocks,
    required this.alreadyRegistered,
    required this.objectsToCreate,
    required this.relationshipsToCreate,
    required this.mergeable,
  });

  factory OepMergePlan.fromNative(OepMergePlanNative native) {
    return OepMergePlan(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      version: decodeFixedCString(native.version, oepMaxPackageVersion),
      trustStatus: decodeFixedCString(native.trustStatus, oepMaxTrustStatus),
      trustBlocks: native.trustBlocks != 0,
      dependencyBlocks: native.dependencyBlocks != 0,
      alreadyRegistered: native.alreadyRegistered != 0,
      objectsToCreate: native.objectsToCreate,
      relationshipsToCreate: native.relationshipsToCreate,
      mergeable: native.mergeable != 0,
    );
  }

  final String packageId;
  final String version;
  final String trustStatus;
  final bool trustBlocks;
  final bool dependencyBlocks;
  final bool alreadyRegistered;
  final int objectsToCreate;
  final int relationshipsToCreate;

  /// True iff trust does not block, dependency resolution succeeds, and
  /// the plan has no conflicts.
  final bool mergeable;
}

/// Plain Dart snapshot of `oep_merge_result_t` (WP-REP-008): the outcome
/// of a successful merge.
class OepMergeResult {
  const OepMergeResult({
    required this.packageId,
    required this.version,
    required this.objectsCreated,
    required this.relationshipsCreated,
    required this.trustStatus,
  });

  factory OepMergeResult.fromNative(OepMergeResultNative native) {
    return OepMergeResult(
      packageId: decodeFixedCString(native.packageId, oepMaxPackageId),
      version: decodeFixedCString(native.version, oepMaxPackageVersion),
      objectsCreated: native.objectsCreated,
      relationshipsCreated: native.relationshipsCreated,
      trustStatus: decodeFixedCString(native.trustStatus, oepMaxTrustStatus),
    );
  }

  final String packageId;
  final String version;
  final int objectsCreated;
  final int relationshipsCreated;
  final String trustStatus;
}

/// Mirrors `oep_engine_query_kind_t` (WP-EKE-001 — Engineering Knowledge
/// Runtime).
enum EngineQueryKind {
  byId(0),
  byType(1),
  byDomain(2),
  byRelationship(3),
  shortestPath(4),
  connectedComponent(5),
  subgraph(6);

  const EngineQueryKind(this.nativeValue);

  final int nativeValue;

  static EngineQueryKind fromNative(int value) {
    return EngineQueryKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => EngineQueryKind.byId,
    );
  }
}

/// Mirrors `oep::engine::TraversalOrder`, as consumed by
/// `oep_engine_traverse`'s `order` parameter (WP-EKE-001).
enum EngineTraversalOrder {
  breadthFirst(0),
  depthFirst(1);

  const EngineTraversalOrder(this.nativeValue);

  final int nativeValue;
}

/// Mirrors `oep_graph_issue_kind_t` (WP-EKE-002 — Engineering Knowledge
/// Graph Engine).
enum GraphIssueKind {
  missingEndpoint(0),
  duplicateRelationship(1),
  selfReference(2),
  brokenReference(3),
  cycle(4),
  invalidRelationshipType(5);

  const GraphIssueKind(this.nativeValue);

  final int nativeValue;

  static GraphIssueKind fromNative(int value) {
    return GraphIssueKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => GraphIssueKind.missingEndpoint,
    );
  }
}

/// Plain Dart snapshot of `oep_graph_issue_t` (WP-EKE-002). `relationshipId`
/// is empty when the issue isn't tied to one specific relationship (e.g. a
/// [GraphIssueKind.cycle]), matching the C struct's own doc comment.
class OepGraphIssue {
  const OepGraphIssue({required this.kind, required this.relationshipId, required this.detail});

  factory OepGraphIssue.fromNative(OepGraphIssueNative native) {
    return OepGraphIssue(
      kind: GraphIssueKind.fromNative(native.kind),
      relationshipId: decodeFixedCString(native.relationshipId, oepMaxRelationshipId),
      detail: decodeFixedCString(native.detail, 256),
    );
  }

  final GraphIssueKind kind;
  final String relationshipId;
  final String detail;
}

/// Plain Dart snapshot of `oep_graph_statistics_t` (WP-EKE-002). See
/// `oep_api.h`'s "Scope decision -- statistics distributions" note for why
/// relationship/domain distributions are not represented here.
class OepGraphStatistics {
  const OepGraphStatistics({
    required this.objectCount,
    required this.relationshipCount,
    required this.connectedComponentCount,
    required this.density,
    required this.maximumDepth,
    required this.averageDegree,
  });

  factory OepGraphStatistics.fromNative(OepGraphStatisticsNative native) {
    return OepGraphStatistics(
      objectCount: native.objectCount,
      relationshipCount: native.relationshipCount,
      connectedComponentCount: native.connectedComponentCount,
      density: native.density,
      maximumDepth: native.maximumDepth,
      averageDegree: native.averageDegree,
    );
  }

  final int objectCount;
  final int relationshipCount;
  final int connectedComponentCount;
  final double density;
  final int maximumDepth;
  final double averageDegree;
}

/// Plain Dart snapshot of one `oep_component_membership_t` entry
/// (WP-EKE-002) — one object's connected-component membership. See
/// `oep_api.h`'s "Scope decision -- connected components flattening" note;
/// [FoundationBridge.connectedComponents] regroups these into per-component
/// lists.
class OepComponentMembership {
  const OepComponentMembership({required this.objectId, required this.componentIndex});

  factory OepComponentMembership.fromNative(OepComponentMembershipNative native) {
    return OepComponentMembership(
      objectId: decodeFixedCString(native.objectId, oepMaxObjectId),
      componentIndex: native.componentIndex,
    );
  }

  final String objectId;
  final int componentIndex;
}

/// Mirrors `oep_query_category_t` (WP-EKE-003 — Engineering Query Engine).
enum QueryCategory {
  object(0),
  relationship(1),
  domain(2),
  type(3),
  dependency(4),
  neighborhood(5),
  path(6),
  reference(7),
  metadata(8),
  composite(9);

  const QueryCategory(this.nativeValue);

  final int nativeValue;

  static QueryCategory fromNative(int value) {
    return QueryCategory.values.firstWhere((category) => category.nativeValue == value, orElse: () => QueryCategory.object);
  }
}

/// Mirrors `oep::engine::TraversalStrategy`, as reported on
/// `oep_query_plan_t.strategy` (WP-EKE-003).
enum QueryTraversalStrategy {
  none(0),
  breadthFirst(1),
  depthFirst(2);

  const QueryTraversalStrategy(this.nativeValue);

  final int nativeValue;

  static QueryTraversalStrategy fromNative(int value) {
    return QueryTraversalStrategy.values.firstWhere(
      (strategy) => strategy.nativeValue == value,
      orElse: () => QueryTraversalStrategy.none,
    );
  }
}

/// Dart-side builder for `oep_query_filter_t` (WP-EKE-003). Every field is
/// optional, mirroring the C struct's "has_X" flag convention — a `null`
/// field is simply omitted from the native request. Passed into
/// [FoundationBridge.planQuery]/[FoundationBridge.executeQuery].
class QueryFilter {
  const QueryFilter({
    this.objectType,
    this.domain,
    this.relationshipType,
    this.publisherId,
    this.packageId,
    this.tags = const [],
    this.maxDepth,
    this.outgoingOnly,
  });

  final ObjectCategory? objectType;
  final String? domain;
  final RelationshipType? relationshipType;
  final String? publisherId;
  final String? packageId;
  final List<String> tags;
  final int? maxDepth;
  final bool? outgoingOnly;
}

/// Plain Dart snapshot of `oep_query_plan_t` (WP-EKE-003).
class OepQueryPlan {
  const OepQueryPlan({required this.category, required this.strategy, required this.estimatedCost});

  factory OepQueryPlan.fromNative(OepQueryPlanNative native) {
    return OepQueryPlan(
      category: QueryCategory.fromNative(native.category),
      strategy: QueryTraversalStrategy.fromNative(native.strategy),
      estimatedCost: native.estimatedCost,
    );
  }

  final QueryCategory category;
  final QueryTraversalStrategy strategy;
  final double estimatedCost;
}

/// Plain Dart snapshot of `oep_query_result_summary_t` (WP-EKE-003). Used
/// both as the [FoundationBridge.executeQuery] result summary and as the
/// [FoundationBridge.queryStatistics] snapshot.
class OepQueryResultSummary {
  const OepQueryResultSummary({
    required this.executionTimeMs,
    required this.objectsExamined,
    required this.relationshipsExamined,
    required this.traversalDepth,
    required this.resultCount,
    required this.traversalSummary,
  });

  factory OepQueryResultSummary.fromNative(OepQueryResultSummaryNative native) {
    return OepQueryResultSummary(
      executionTimeMs: native.executionTimeMs,
      objectsExamined: native.objectsExamined,
      relationshipsExamined: native.relationshipsExamined,
      traversalDepth: native.traversalDepth,
      resultCount: native.resultCount,
      traversalSummary: decodeFixedCString(native.traversalSummary, 256),
    );
  }

  final double executionTimeMs;
  final int objectsExamined;
  final int relationshipsExamined;
  final int traversalDepth;
  final int resultCount;
  final String traversalSummary;
}

// --- Engineering Rules Engine (WP-EKE-004) ---

/// Mirrors `oep_rule_category_t` (WP-EKE-004 — Engineering Rules Engine).
enum RuleCategory {
  structural(0),
  connectivity(1),
  dependency(2),
  reference(3),
  documentation(4),
  metadata(5),
  package(6);

  const RuleCategory(this.nativeValue);

  final int nativeValue;

  static RuleCategory fromNative(int value) {
    return RuleCategory.values.firstWhere((category) => category.nativeValue == value, orElse: () => RuleCategory.structural);
  }
}

/// Mirrors `oep_rule_severity_t` (WP-EKE-004).
enum RuleSeverity {
  info(0),
  warning(1),
  error(2),
  critical(3);

  const RuleSeverity(this.nativeValue);

  final int nativeValue;

  static RuleSeverity fromNative(int value) {
    return RuleSeverity.values.firstWhere((severity) => severity.nativeValue == value, orElse: () => RuleSeverity.info);
  }
}

/// Mirrors `oep_rule_scope_kind_t` (WP-EKE-004).
enum RuleScopeKind {
  allObjects(0),
  byObjectType(1),
  byDomain(2),
  byPackage(3),
  singleObject(4);

  const RuleScopeKind(this.nativeValue);

  final int nativeValue;

  static RuleScopeKind fromNative(int value) {
    return RuleScopeKind.values.firstWhere((kind) => kind.nativeValue == value, orElse: () => RuleScopeKind.allObjects);
  }
}

/// Mirrors `oep_rule_condition_kind_t` (WP-EKE-004).
enum RuleConditionKind {
  requiresRelationship(0),
  forbidsRelationship(1),
  minRelationshipCount(2),
  maxRelationshipCount(3),
  requiresTag(4),
  forbidsTag(5),
  hasDescription(6),
  hasAuthor(7),
  noCycles(8),
  noIsolatedObjects(9);

  const RuleConditionKind(this.nativeValue);

  final int nativeValue;

  static RuleConditionKind fromNative(int value) {
    return RuleConditionKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => RuleConditionKind.requiresRelationship,
    );
  }
}

/// Mirrors `oep_rule_evaluation_status_t` (WP-EKE-004).
enum RuleEvaluationStatus {
  passed(0),
  failed(1),
  notApplicable(2),
  error(3);

  const RuleEvaluationStatus(this.nativeValue);

  final int nativeValue;

  static RuleEvaluationStatus fromNative(int value) {
    return RuleEvaluationStatus.values.firstWhere(
      (status) => status.nativeValue == value,
      orElse: () => RuleEvaluationStatus.error,
    );
  }
}

/// Dart-side builder for `oep_rule_scope_t` (WP-EKE-004). Every field
/// beyond [kind] is optional, mirroring the C struct's "has_X" flag
/// convention — the same approach [QueryFilter] (WP-EKE-003) already
/// takes. Only the field matching [kind] needs to be set.
class RuleScope {
  const RuleScope({this.kind = RuleScopeKind.allObjects, this.objectType, this.domain, this.packageId, this.objectId});

  final RuleScopeKind kind;
  final ObjectCategory? objectType;
  final String? domain;
  final String? packageId;
  final String? objectId;
}

/// Dart-side builder for `oep_rule_condition_t` (WP-EKE-004). Every field
/// beyond [kind] is optional, mirroring the C struct's "has_X" flag
/// convention. `direction`: `true` means outgoing only, `false` means
/// incoming only, `null` means either direction — mirrors
/// [QueryFilter.outgoingOnly]'s own nullable-bool convention.
class RuleCondition {
  const RuleCondition({required this.kind, this.relationshipType, this.direction, this.tag, this.count});

  final RuleConditionKind kind;
  final RelationshipType? relationshipType;
  final bool? direction;
  final String? tag;
  final int? count;
}

/// Dart-side builder for `oep_engineering_rule_t` (WP-EKE-004) — the
/// INPUT shape passed to [FoundationBridge.registerRule]. See
/// `oep_api.h`'s "Rule input/output struct shape" note: on OUTPUT
/// (`oep_rules_get`), the equivalent scalar fields are decoded into this
/// same class by [FoundationBridge.getRule], with conditions returned
/// separately as a `List<RuleCondition>`.
class EngineeringRule {
  const EngineeringRule({
    required this.ruleId,
    required this.name,
    this.description = '',
    required this.category,
    required this.severity,
    this.scope = const RuleScope(),
    this.conditions = const [],
    this.message = '',
    this.recommendation = '',
  });

  factory EngineeringRule.fromNative(OepEngineeringRuleNative native) {
    final scopeNative = native.scope;
    return EngineeringRule(
      ruleId: decodeFixedCString(native.ruleId, oepMaxRuleId),
      name: decodeFixedCString(native.name, oepMaxRuleName),
      description: decodeFixedCString(native.description, oepMaxRuleDescription),
      category: RuleCategory.fromNative(native.category),
      severity: RuleSeverity.fromNative(native.severity),
      scope: RuleScope(
        kind: RuleScopeKind.fromNative(scopeNative.kind),
        objectType: scopeNative.hasObjectType != 0 ? ObjectCategory.fromNative(scopeNative.objectType) : null,
        domain: scopeNative.hasDomain != 0 ? decodeFixedCString(scopeNative.domain, oepMaxObjectName) : null,
        packageId: scopeNative.hasPackageId != 0 ? decodeFixedCString(scopeNative.packageId, oepMaxPackageId) : null,
        objectId: scopeNative.hasObjectId != 0 ? decodeFixedCString(scopeNative.objectId, oepMaxObjectId) : null,
      ),
      message: decodeFixedCString(native.message, oepMaxRuleMessage),
      recommendation: decodeFixedCString(native.recommendation, oepMaxRuleRecommendation),
    );
  }

  final String ruleId;
  final String name;
  final String description;
  final RuleCategory category;
  final RuleSeverity severity;
  final RuleScope scope;
  final List<RuleCondition> conditions;
  final String message;
  final String recommendation;
}

/// Plain Dart snapshot of the scalar fields of `oep_rule_evaluation_result_t`
/// (WP-EKE-004). `affectedObjects`/`diagnostics` are decoded separately by
/// [FoundationBridge.evaluateRule].
class OepRuleEvaluationResult {
  const OepRuleEvaluationResult({required this.status, required this.message});

  factory OepRuleEvaluationResult.fromNative(OepRuleEvaluationResultNative native) {
    return OepRuleEvaluationResult(
      status: RuleEvaluationStatus.fromNative(native.status),
      message: decodeFixedCString(native.message, oepMaxRuleMessage),
    );
  }

  final RuleEvaluationStatus status;
  final String message;
}

/// Plain Dart snapshot of `oep_rule_diagnostic_t` (WP-EKE-004). `objectId`
/// is empty for a graph-level diagnostic (e.g. a NoCycles violation).
class OepRuleDiagnostic {
  const OepRuleDiagnostic({required this.objectId, required this.detail});

  factory OepRuleDiagnostic.fromNative(OepRuleDiagnosticNative native) {
    return OepRuleDiagnostic(
      objectId: decodeFixedCString(native.objectId, oepMaxObjectId),
      detail: decodeFixedCString(native.detail, oepMaxRuleDiagnosticDetail),
    );
  }

  final String objectId;
  final String detail;
}

/// Plain Dart snapshot of `oep_rule_evaluation_summary_t` (WP-EKE-004) —
/// one per-rule summary entry produced by
/// [FoundationBridge.evaluateAllRules].
class OepRuleEvaluationSummary {
  const OepRuleEvaluationSummary({
    required this.ruleId,
    required this.status,
    required this.message,
    required this.affectedObjectCount,
    required this.diagnosticCount,
  });

  factory OepRuleEvaluationSummary.fromNative(OepRuleEvaluationSummaryNative native) {
    return OepRuleEvaluationSummary(
      ruleId: decodeFixedCString(native.ruleId, oepMaxRuleId),
      status: RuleEvaluationStatus.fromNative(native.status),
      message: decodeFixedCString(native.message, oepMaxRuleMessage),
      affectedObjectCount: native.affectedObjectCount,
      diagnosticCount: native.diagnosticCount,
    );
  }

  final String ruleId;
  final RuleEvaluationStatus status;
  final String message;
  final int affectedObjectCount;
  final int diagnosticCount;
}

// --- Engineering Validation Engine (WP-EKE-005) ---

/// Mirrors `oep_validation_profile_t` (WP-EKE-005 — Engineering Validation
/// Engine).
enum ValidationProfile {
  structural(0),
  connectivity(1),
  documentation(2),
  metadata(3),
  complete(4);

  const ValidationProfile(this.nativeValue);

  final int nativeValue;

  static ValidationProfile fromNative(int value) {
    return ValidationProfile.values.firstWhere(
      (profile) => profile.nativeValue == value,
      orElse: () => ValidationProfile.structural,
    );
  }
}

/// Mirrors `oep_validation_target_kind_t` (WP-EKE-005). Note there is no
/// Dart-callable `validateQueryResult` — see `oep_api.h`'s "Scope
/// decision -- no oep_validation_validate_query_result" note; a caller
/// wanting query-result-scoped validation calls `oep_eqe_execute_query`
/// first, then passes the resulting object ids to `validateObjects`.
enum ValidationTargetKind {
  singleObject(0),
  multipleObjects(1),
  engineeringContext(2),
  package(3),
  queryResult(4);

  const ValidationTargetKind(this.nativeValue);

  final int nativeValue;

  static ValidationTargetKind fromNative(int value) {
    return ValidationTargetKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => ValidationTargetKind.singleObject,
    );
  }
}

/// Plain Dart snapshot of the scalar fields of
/// `oep_validation_report_summary_t` (WP-EKE-005) — everything except the
/// findings list, which is decoded separately (see
/// [OepValidationFinding]).
class OepValidationReportSummary {
  const OepValidationReportSummary({
    required this.targetKind,
    required this.passCount,
    required this.warningCount,
    required this.errorCount,
    required this.criticalCount,
    required this.executionTimeMs,
    required this.rulesEvaluated,
  });

  factory OepValidationReportSummary.fromNative(OepValidationReportSummaryNative native) {
    return OepValidationReportSummary(
      targetKind: ValidationTargetKind.fromNative(native.targetKind),
      passCount: native.passCount,
      warningCount: native.warningCount,
      errorCount: native.errorCount,
      criticalCount: native.criticalCount,
      executionTimeMs: native.executionTimeMs,
      rulesEvaluated: native.rulesEvaluated,
    );
  }

  final ValidationTargetKind targetKind;
  final int passCount;
  final int warningCount;
  final int errorCount;
  final int criticalCount;
  final double executionTimeMs;
  final int rulesEvaluated;
}

/// Plain Dart snapshot of `oep_validation_finding_t` (WP-EKE-005).
/// Deliberately omits affected_objects/diagnostics — see `oep_api.h`'s
/// "Report/finding detail level" note; call
/// [FoundationBridge.evaluateRule] with [ruleId] for that detail.
/// [severity]/[category] reuse the [RuleSeverity]/[RuleCategory] enums
/// WP-EKE-004 already established.
class OepValidationFinding {
  const OepValidationFinding({
    required this.findingId,
    required this.ruleId,
    required this.severity,
    required this.category,
    required this.message,
    required this.recommendation,
  });

  factory OepValidationFinding.fromNative(OepValidationFindingNative native) {
    return OepValidationFinding(
      findingId: decodeFixedCString(native.findingId, oepMaxFindingId),
      ruleId: decodeFixedCString(native.ruleId, oepMaxRuleId),
      severity: RuleSeverity.fromNative(native.severity),
      category: RuleCategory.fromNative(native.category),
      message: decodeFixedCString(native.message, oepMaxRuleMessage),
      recommendation: decodeFixedCString(native.recommendation, oepMaxRuleRecommendation),
    );
  }

  final String findingId;
  final String ruleId;
  final RuleSeverity severity;
  final RuleCategory category;
  final String message;
  final String recommendation;
}

/// Plain Dart snapshot of `oep_validation_statistics_t` (WP-EKE-005).
class OepValidationStatistics {
  const OepValidationStatistics({
    required this.rulesEvaluated,
    required this.rulesPassed,
    required this.rulesFailed,
    required this.rulesNotApplicable,
    required this.rulesErrored,
    required this.executionTimeMs,
  });

  factory OepValidationStatistics.fromNative(OepValidationStatisticsNative native) {
    return OepValidationStatistics(
      rulesEvaluated: native.rulesEvaluated,
      rulesPassed: native.rulesPassed,
      rulesFailed: native.rulesFailed,
      rulesNotApplicable: native.rulesNotApplicable,
      rulesErrored: native.rulesErrored,
      executionTimeMs: native.executionTimeMs,
    );
  }

  final int rulesEvaluated;
  final int rulesPassed;
  final int rulesFailed;
  final int rulesNotApplicable;
  final int rulesErrored;
  final double executionTimeMs;
}

// --- Engineering Analysis & Reasoning Engine (WP-EKE-006) ---

/// Mirrors `oep_evidence_kind_t`'s declared order in `oep_api.h`. The
/// header exposes `oep_evidence_node_t.kind` as a plain `int` (comment:
/// "mirrors oep::engine::EvidenceKind's declared order") rather than a
/// named enum typedef, so this enum's ordinal order is load-bearing —
/// keep it in lockstep with the C++ `EvidenceKind` declaration order.
enum EvidenceKind {
  relationship(0),
  ruleViolation(1),
  validationFinding(2),
  analysisResult(3),
  objectProperty(4);

  const EvidenceKind(this.nativeValue);

  final int nativeValue;

  static EvidenceKind fromNative(int value) {
    return EvidenceKind.values.firstWhere((kind) => kind.nativeValue == value, orElse: () => EvidenceKind.relationship);
  }
}

/// Mirrors `oep_recommendation_kind_t` (WP-EKE-006).
enum RecommendationKind {
  relatedProcedure(0),
  similarComponent(1),
  additionalInspection(2),
  connectedSystem(3),
  followUpValidation(4);

  const RecommendationKind(this.nativeValue);

  final int nativeValue;

  static RecommendationKind fromNative(int value) {
    return RecommendationKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => RecommendationKind.relatedProcedure,
    );
  }
}

/// Plain Dart snapshot of the scalar fields of `oep_reasoning_summary_t`
/// (WP-EKE-006) — everything except the conclusion/recommendation id
/// lists, which are decoded separately by
/// [FoundationBridge.executeReasoning]/[FoundationBridge.reasoningReport].
class OepReasoningSummary {
  const OepReasoningSummary({
    required this.conclusionCount,
    required this.recommendationCount,
    required this.executionTimeMs,
  });

  factory OepReasoningSummary.fromNative(OepReasoningSummaryNative native) {
    return OepReasoningSummary(
      conclusionCount: native.conclusionCount,
      recommendationCount: native.recommendationCount,
      executionTimeMs: native.executionTimeMs,
    );
  }

  final int conclusionCount;
  final int recommendationCount;
  final double executionTimeMs;
}

/// Plain Dart snapshot of `oep_conclusion_t` (WP-EKE-006). Deliberately
/// omits supportingEvidenceIds/referencedObjects/referencedRules/
/// referencedFindings — see `oep_api.h`'s "avoid nested
/// owned-list-of-owned-lists" scope decision; call
/// [FoundationBridge.getConclusion] for those four id lists.
class OepConclusion {
  const OepConclusion({
    required this.conclusionId,
    required this.statement,
    required this.confidence,
    required this.explanation,
  });

  factory OepConclusion.fromNative(OepConclusionNative native) {
    return OepConclusion(
      conclusionId: decodeFixedCString(native.conclusionId, oepMaxConclusionId),
      statement: decodeFixedCString(native.statement, oepMaxConclusionStatement),
      confidence: native.confidence,
      explanation: decodeFixedCString(native.explanation, oepMaxConclusionExplanation),
    );
  }

  final String conclusionId;
  final String statement;
  final double confidence;
  final String explanation;
}

/// Plain Dart snapshot of `oep_recommendation_t` (WP-EKE-006). Deliberately
/// omits supportingEvidenceIds — call
/// [FoundationBridge.getRecommendation] for that id list.
class OepRecommendation {
  const OepRecommendation({
    required this.recommendationId,
    required this.kind,
    required this.objectId,
    required this.message,
  });

  factory OepRecommendation.fromNative(OepRecommendationNative native) {
    return OepRecommendation(
      recommendationId: decodeFixedCString(native.recommendationId, oepMaxRecommendationId),
      kind: RecommendationKind.fromNative(native.kind),
      objectId: decodeFixedCString(native.objectId, oepMaxObjectId),
      message: decodeFixedCString(native.message, oepMaxRecommendationMessage),
    );
  }

  final String recommendationId;
  final RecommendationKind kind;
  final String objectId;
  final String message;
}

/// Plain Dart snapshot of `oep_evidence_node_t` (WP-EKE-006). See
/// `oep_api.h`'s "Evidence Graph exposure" note — this is the only
/// Evidence Graph shape Studio exposes; no relationship-edge enumeration,
/// no full-graph listing.
class OepEvidenceNode {
  const OepEvidenceNode({
    required this.evidenceId,
    required this.kind,
    required this.referenceId,
    required this.detail,
  });

  factory OepEvidenceNode.fromNative(OepEvidenceNodeNative native) {
    return OepEvidenceNode(
      evidenceId: decodeFixedCString(native.evidenceId, oepMaxEvidenceId),
      kind: EvidenceKind.fromNative(native.kind),
      referenceId: decodeFixedCString(native.referenceId, oepMaxEvidenceReferenceId),
      detail: decodeFixedCString(native.detail, oepMaxEvidenceDetail),
    );
  }

  final String evidenceId;
  final EvidenceKind kind;
  final String referenceId;
  final String detail;
}

// --- Engineering Intelligence Platform (WP-EKE-007) ---

/// Mirrors `oep::engine::WorkflowKind`, as reported on
/// `oep_workflow_result_t.kind` (WP-EKE-007).
enum WorkflowKind {
  inspect(0),
  query(1),
  validate(2),
  analyze(3),
  reason(4),
  recommend(5);

  const WorkflowKind(this.nativeValue);

  final int nativeValue;

  static WorkflowKind fromNative(int value) {
    return WorkflowKind.values.firstWhere((kind) => kind.nativeValue == value, orElse: () => WorkflowKind.inspect);
  }
}

/// Mirrors `oep::engine::InspectionTargetKind` (WP-EKE-007).
enum InspectionTargetKind {
  object(0),
  package(1),
  context(2);

  const InspectionTargetKind(this.nativeValue);

  final int nativeValue;

  static InspectionTargetKind fromNative(int value) {
    return InspectionTargetKind.values.firstWhere(
      (kind) => kind.nativeValue == value,
      orElse: () => InspectionTargetKind.object,
    );
  }
}

/// The one shape every `oep_eip_*` workflow returns, minus its separately
/// returned object id list. Mirrors `oep_workflow_result_t` (WP-EKE-007).
class OepWorkflowResult {
  const OepWorkflowResult({
    required this.kind,
    required this.success,
    required this.summary,
    required this.executionTimeMs,
  });

  factory OepWorkflowResult.fromNative(OepWorkflowResultNative native) {
    return OepWorkflowResult(
      kind: WorkflowKind.fromNative(native.kind),
      success: native.success != 0,
      summary: decodeFixedCString(native.summary, oepMaxWorkflowSummary),
      executionTimeMs: native.executionTimeMs,
    );
  }

  final WorkflowKind kind;
  final bool success;
  final String summary;
  final double executionTimeMs;
}

/// Scalar, count-only summary of one KnowledgeSession — see `oep_api.h`'s
/// "Session summary shape" header note; the underlying description
/// strings are only available via
/// [FoundationBridge.exportEipSessionSummary]'s human-readable text
/// export. Mirrors `oep_knowledge_session_summary_t` (WP-EKE-007).
class OepKnowledgeSessionSummary {
  const OepKnowledgeSessionSummary({
    required this.sessionId,
    required this.createdUtc,
    required this.lastActiveUtc,
    required this.closed,
    required this.queryHistoryCount,
    required this.validationHistoryCount,
    required this.analysisHistoryCount,
    required this.reasoningHistoryCount,
    required this.recommendationCount,
    required this.activeObjectCount,
    required this.activePackageCount,
    required this.totalExecutionTimeMs,
  });

  factory OepKnowledgeSessionSummary.fromNative(OepKnowledgeSessionSummaryNative native) {
    return OepKnowledgeSessionSummary(
      sessionId: decodeFixedCString(native.sessionId, oepMaxSessionId),
      createdUtc: decodeFixedCString(native.createdUtc, oepMaxTimestamp),
      lastActiveUtc: decodeFixedCString(native.lastActiveUtc, oepMaxTimestamp),
      closed: native.closed != 0,
      queryHistoryCount: native.queryHistoryCount,
      validationHistoryCount: native.validationHistoryCount,
      analysisHistoryCount: native.analysisHistoryCount,
      reasoningHistoryCount: native.reasoningHistoryCount,
      recommendationCount: native.recommendationCount,
      activeObjectCount: native.activeObjectCount,
      activePackageCount: native.activePackageCount,
      totalExecutionTimeMs: native.totalExecutionTimeMs,
    );
  }

  final String sessionId;
  final String createdUtc;
  final String lastActiveUtc;
  final bool closed;
  final int queryHistoryCount;
  final int validationHistoryCount;
  final int analysisHistoryCount;
  final int reasoningHistoryCount;
  final int recommendationCount;
  final int activeObjectCount;
  final int activePackageCount;
  final double totalExecutionTimeMs;
}

/// Scalar mirror of `oep::engine::EngineeringSummaryReport` (WP-EKE-007).
class OepEngineeringSummaryReport {
  const OepEngineeringSummaryReport({
    required this.objectCount,
    required this.relationshipCount,
    required this.connectedComponentCount,
    required this.validationPassCount,
    required this.validationFindingCount,
    required this.summary,
  });

  factory OepEngineeringSummaryReport.fromNative(OepEngineeringSummaryReportNative native) {
    return OepEngineeringSummaryReport(
      objectCount: native.objectCount,
      relationshipCount: native.relationshipCount,
      connectedComponentCount: native.connectedComponentCount,
      validationPassCount: native.validationPassCount,
      validationFindingCount: native.validationFindingCount,
      summary: decodeFixedCString(native.summary, oepMaxReportSummary),
    );
  }

  final int objectCount;
  final int relationshipCount;
  final int connectedComponentCount;
  final int validationPassCount;
  final int validationFindingCount;
  final String summary;
}

/// Scalar mirror of `oep::engine::EngineeringHealthReport` (WP-EKE-007).
class OepEngineeringHealthReport {
  const OepEngineeringHealthReport({
    required this.healthScore,
    required this.passed,
    required this.failed,
    required this.warnings,
    required this.errors,
    required this.critical,
    required this.summary,
  });

  factory OepEngineeringHealthReport.fromNative(OepEngineeringHealthReportNative native) {
    return OepEngineeringHealthReport(
      healthScore: native.healthScore,
      passed: native.passed,
      failed: native.failed,
      warnings: native.warnings,
      errors: native.errors,
      critical: native.critical,
      summary: decodeFixedCString(native.summary, oepMaxReportSummary),
    );
  }

  final double healthScore;
  final int passed;
  final int failed;
  final int warnings;
  final int errors;
  final int critical;
  final String summary;
}

/// Scalar mirror of `oep::engine::RuntimeMetrics` (WP-EKE-007).
class OepRuntimeMetrics {
  const OepRuntimeMetrics({
    required this.queryCount,
    required this.validationCount,
    required this.analysisCount,
    required this.reasoningCount,
    required this.cacheHits,
    required this.cacheMisses,
    required this.activeSessionCount,
    required this.totalSessionCount,
    required this.totalExecutionTimeMs,
  });

  factory OepRuntimeMetrics.fromNative(OepRuntimeMetricsNative native) {
    return OepRuntimeMetrics(
      queryCount: native.queryCount,
      validationCount: native.validationCount,
      analysisCount: native.analysisCount,
      reasoningCount: native.reasoningCount,
      cacheHits: native.cacheHits,
      cacheMisses: native.cacheMisses,
      activeSessionCount: native.activeSessionCount,
      totalSessionCount: native.totalSessionCount,
      totalExecutionTimeMs: native.totalExecutionTimeMs,
    );
  }

  final int queryCount;
  final int validationCount;
  final int analysisCount;
  final int reasoningCount;
  final int cacheHits;
  final int cacheMisses;
  final int activeSessionCount;
  final int totalSessionCount;
  final double totalExecutionTimeMs;
}

/// Decodes a NUL-terminated, fixed-length `char[]` embedded in a struct
/// into a Dart [String]. `length` is the array's declared size, not
/// necessarily the string's length — decoding stops at the first NUL.
String decodeFixedCString(Array<Uint8> array, int length) {
  final bytes = <int>[];
  for (var i = 0; i < length; i++) {
    final byte = array[i];
    if (byte == 0) break;
    bytes.add(byte);
  }
  return utf8.decode(bytes);
}
