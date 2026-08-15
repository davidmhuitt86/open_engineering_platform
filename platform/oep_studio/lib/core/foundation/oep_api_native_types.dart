import 'dart:ffi';

import 'package:ffi/ffi.dart' show Utf8;

/// Native struct and typedef layer mirroring
/// `oep_foundation/platform/api/include/oep/api/oep_api.h` field-for-field.
///
/// This file (and `oep_api_bindings.dart`) are the only places in Studio
/// that reference `dart:ffi` layout details. Everything above the
/// Foundation Bridge works with plain Dart types from `oep_api_types.dart`.

const int oepMaxErrorMessage = 256;
const int oepRepositoryIdSize = 64;
const int oepRepositoryNameSize = 256;
const int oepRepositoryVersionSize = 32;

const int oepObjectTypeCount = 6;
const int oepMaxObjectId = 64;
const int oepMaxObjectName = 256;
const int oepMaxObjectAuthor = 128;
const int oepMaxObjectVersion = 32;
const int oepMaxObjectDescription = 1024;
const int oepMaxObjectTags = 16;
const int oepMaxTagLength = 64;

const int oepMaxRelationshipId = 64;
const int oepMaxTimestamp = 32;

const int oepMaxPackageId = 256;
const int oepMaxPackageVersion = 32;
const int oepMaxPackageTitle = 256;
const int oepMaxPackageSource = 32;

// Package Lifecycle Queries (WP-REP-002).
const int oepMaxPackageSummary = 512;
const int oepMaxPackageCategory = 64;
const int oepMaxPackagePublisher = 128;
const int oepMaxPackageHash = 72;
const int oepMaxPackagePath = 512;
const int oepMaxPackageState = 32;
const int oepMaxPackageDomains = 8;
const int oepMaxPackageDomainLength = 64;

// Repository Transaction Engine (WP-REP-003).
const int oepMaxTransactionId = 64;
const int oepMaxTransactionState = 16;
const int oepMaxTransactionDescription = 128;

// Trust & Signing (WP-REP-004).
const int oepMaxPublisherId = 128;
const int oepMaxPublisherName = 128;
const int oepMaxPublicKeyHex = 65;
const int oepMaxCertIssuer = 128;
const int oepMaxCertVersion = 16;
const int oepMaxFingerprint = 65;

// Dependency Resolution (WP-REP-005).
const int oepMaxVersionConstraint = 64;
const int oepMaxCycleDescription = 512;

// Repository Events (WP-REP-006).
const int oepMaxEventSubjectId = 256;
const int oepMaxEventDetail = 256;
const int oepMaxEventTimestamp = 32;

// Package Uninstall/Update Lifecycle (WP-REP-007).
const int oepMaxTrustStatus = 32;

// Engineering Rules Engine (WP-EKE-004).
const int oepMaxRuleId = 64;
const int oepMaxRuleName = 256;
const int oepMaxRuleDescription = 1024;
const int oepMaxRuleMessage = 512;
const int oepMaxRuleRecommendation = 512;
const int oepMaxRuleDiagnosticDetail = 256;

// Engineering Validation Engine (WP-EKE-005).
const int oepMaxSessionId = 40;
const int oepMaxFindingId = 64;

// Engineering Analysis & Reasoning Engine (WP-EKE-006).
const int oepMaxEvidenceText = 256;
const int oepMaxConclusionId = 64;
const int oepMaxRecommendationId = 64;
const int oepMaxConclusionStatement = 512;
const int oepMaxConclusionExplanation = 1024;
const int oepMaxRecommendationMessage = 512;
const int oepMaxEvidenceId = 64;
const int oepMaxEvidenceReferenceId = 64;
const int oepMaxEvidenceDetail = 512;

// Engineering Intelligence Platform (WP-EKE-007).
const int oepMaxWorkflowSummary = 512;
const int oepMaxReportSummary = 512;

/// Mirrors `oep_result_t`. Every OEP Foundation API call that can fail
/// returns this by value.
final class OepResultNative extends Struct {
  @Int32()
  external int success;

  @Int32()
  external int errorCode;

  @Int32()
  external int errorCategory;

  @Array(oepMaxErrorMessage)
  external Array<Uint8> errorMessage;
}

/// Mirrors `oep_repository_status_t`.
final class OepRepositoryStatusNative extends Struct {
  @Int32()
  external int repositoryOpen;

  @Array(oepRepositoryIdSize)
  external Array<Uint8> repositoryId;

  @Array(oepRepositoryNameSize)
  external Array<Uint8> repositoryName;

  @Array(oepRepositoryVersionSize)
  external Array<Uint8> repositoryVersion;

  @Int32()
  external int loadedPackageCount;
}

/// Mirrors `oep_object_info_t`. A fixed-layout, pointer-free snapshot
/// of one Engineering Object's metadata.
final class OepObjectInfoNative extends Struct {
  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;

  @Int32()
  external int objectType;

  @Array(oepMaxObjectName)
  external Array<Uint8> name;

  @Array(oepMaxObjectAuthor)
  external Array<Uint8> author;

  @Array(oepMaxObjectVersion)
  external Array<Uint8> version;

  @Array(oepMaxObjectDescription)
  external Array<Uint8> description;

  @Int32()
  external int tagCount;

  @Array(oepMaxObjectTags, oepMaxTagLength)
  external Array<Array<Uint8>> tags;
}

/// Mirrors `oep_object_list_t`. `items` is a Foundation-owned heap
/// array — always released via `oep_object_list_release`, never `free`.
final class OepObjectListNative extends Struct {
  external Pointer<OepObjectInfoNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_repository_statistics_t`.
final class OepRepositoryStatisticsNative extends Struct {
  @Array(oepRepositoryIdSize)
  external Array<Uint8> repositoryId;

  @Array(oepRepositoryNameSize)
  external Array<Uint8> repositoryName;

  @Array(oepRepositoryVersionSize)
  external Array<Uint8> repositoryVersion;

  @Int32()
  external int totalObjectCount;

  @Array(oepObjectTypeCount)
  external Array<Int32> objectCountByType;

  @Int32()
  external int relationshipCount;

  @Int32()
  external int packageCount;
}

/// Mirrors `oep_relationship_info_t` (Work Package 013, TASK-000025).
final class OepRelationshipInfoNative extends Struct {
  @Array(oepMaxRelationshipId)
  external Array<Uint8> relationshipId;

  @Array(oepMaxObjectId)
  external Array<Uint8> sourceObjectId;

  @Array(oepMaxObjectId)
  external Array<Uint8> targetObjectId;

  @Int32()
  external int relationshipType;

  @Array(oepMaxObjectAuthor)
  external Array<Uint8> author;

  @Array(oepMaxObjectDescription)
  external Array<Uint8> description;

  @Array(oepMaxTimestamp)
  external Array<Uint8> createdUtc;
}

/// Mirrors `oep_relationship_list_t`. `items` is a Foundation-owned heap
/// array — always released via `oep_relationship_list_release`, never
/// `free`. Same ownership model as [OepObjectListNative].
final class OepRelationshipListNative extends Struct {
  external Pointer<OepRelationshipInfoNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_object_search_result_t` (Work Package 013, TASK-000026).
final class OepObjectSearchResultNative extends Struct {
  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;

  @Int32()
  external int objectType;

  @Array(oepMaxObjectName)
  external Array<Uint8> displayName;

  @Int32()
  external int matchLocation;

  @Double()
  external double matchScore;
}

/// Mirrors `oep_object_search_result_list_t`.
final class OepObjectSearchResultListNative extends Struct {
  external Pointer<OepObjectSearchResultNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_relationship_search_result_t`.
final class OepRelationshipSearchResultNative extends Struct {
  @Array(oepMaxRelationshipId)
  external Array<Uint8> relationshipId;

  @Array(oepMaxObjectId)
  external Array<Uint8> sourceObjectId;

  @Array(oepMaxObjectId)
  external Array<Uint8> targetObjectId;

  @Int32()
  external int relationshipType;

  @Int32()
  external int matchLocation;

  @Double()
  external double matchScore;
}

/// Mirrors `oep_relationship_search_result_list_t`.
final class OepRelationshipSearchResultListNative extends Struct {
  external Pointer<OepRelationshipSearchResultNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_repository_search_result_t`, whose two C members
/// (`oep_object_search_result_list_t objects`,
/// `oep_relationship_search_result_list_t relationships`) are each just
/// `{pointer; int32;}`. Rather than nesting [OepObjectSearchResultListNative]/
/// [OepRelationshipSearchResultListNative] as struct-typed fields, this
/// flattens both into four top-level fields in the same declaration
/// order — the platform ABI lays out nested structs-by-value as their
/// members concatenated in order, so this produces an identical byte
/// layout without depending on dart:ffi struct-of-struct field support.
final class OepRepositorySearchResultNative extends Struct {
  external Pointer<OepObjectSearchResultNative> objectItems;

  @Int32()
  external int objectCount;

  external Pointer<OepRelationshipSearchResultNative> relationshipItems;

  @Int32()
  external int relationshipCount;
}

/// Mirrors `oep_package_install_result_t` (WP-REP-001 — Repository
/// Runtime, first vertical slice).
final class OepPackageInstallResultNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> version;

  @Int32()
  external int objectsCreated;

  @Int32()
  external int relationshipsCreated;
}

/// Mirrors `oep_installed_package_info_t`.
final class OepInstalledPackageInfoNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> version;

  @Array(oepMaxPackageTitle)
  external Array<Uint8> title;

  @Array(oepMaxTimestamp)
  external Array<Uint8> installedUtc;

  @Array(oepMaxPackageSource)
  external Array<Uint8> source;

  @Int32()
  external int objectCount;

  @Int32()
  external int relationshipCount;
}

/// Mirrors `oep_installed_package_list_t`. `items` is a Foundation-owned
/// heap array — always released via `oep_installed_package_list_release`,
/// never `free`.
final class OepInstalledPackageListNative extends Struct {
  external Pointer<OepInstalledPackageInfoNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_package_details_t` (WP-REP-002 — Repository Registry &
/// Lifecycle): the full Repository Registry record for one installed
/// package. Plain value type on the native side — no release function.
final class OepPackageDetailsNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> version;

  @Array(oepMaxPackageTitle)
  external Array<Uint8> title;

  @Array(oepMaxPackageSummary)
  external Array<Uint8> summary;

  @Array(oepMaxPackageCategory)
  external Array<Uint8> category;

  @Array(oepMaxPackagePublisher)
  external Array<Uint8> publisherId;

  @Array(oepMaxPackagePublisher)
  external Array<Uint8> publisherName;

  @Array(oepMaxTimestamp)
  external Array<Uint8> installedUtc;

  @Array(oepMaxPackageSource)
  external Array<Uint8> source;

  @Array(oepMaxPackagePath)
  external Array<Uint8> installationPath;

  @Array(oepMaxPackageHash)
  external Array<Uint8> packageHash;

  @Array(oepMaxPackageState)
  external Array<Uint8> runtimeState;

  @Int32()
  external int engineeringDomainCount;

  @Array(oepMaxPackageDomains, oepMaxPackageDomainLength)
  external Array<Array<Uint8>> engineeringDomains;

  @Int32()
  external int objectCount;

  @Int32()
  external int relationshipCount;
}

/// Mirrors `oep_package_owner_t` (WP-REP-002).
final class OepPackageOwnerNative extends Struct {
  @Int32()
  external int found;

  @Int32()
  external int kind; // oep_owned_entity_kind_t

  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> version;

  @Array(oepMaxPackageTitle)
  external Array<Uint8> title;
}

/// Mirrors `oep_transaction_info_t` (WP-REP-003 — Repository Transaction
/// Engine): the currently active transaction, if any.
final class OepTransactionInfoNative extends Struct {
  @Int32()
  external int active;

  @Array(oepMaxTransactionId)
  external Array<Uint8> transactionId;

  @Array(oepMaxTransactionDescription)
  external Array<Uint8> description;

  @Int32()
  external int journalEntryCount;
}

/// Mirrors `oep_transaction_record_t` (WP-REP-003): one journaled
/// (closed) transaction.
final class OepTransactionRecordNative extends Struct {
  @Array(oepMaxTransactionId)
  external Array<Uint8> transactionId;

  @Array(oepMaxTransactionState)
  external Array<Uint8> state;

  @Array(oepMaxTransactionDescription)
  external Array<Uint8> description;

  @Array(oepMaxTimestamp)
  external Array<Uint8> openedUtc;

  @Array(oepMaxTimestamp)
  external Array<Uint8> closedUtc;

  @Int32()
  external int journalEntryCount;
}

/// Mirrors `oep_transaction_record_list_t` — Foundation-owned heap
/// array, released via `oep_transaction_record_list_release`.
final class OepTransactionRecordListNative extends Struct {
  external Pointer<OepTransactionRecordNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_publisher_certificate_t` (WP-REP-004 — Trust & Signing).
final class OepPublisherCertificateNative extends Struct {
  @Array(oepMaxPublisherId)
  external Array<Uint8> publisherId;

  @Array(oepMaxPublisherName)
  external Array<Uint8> publisherName;

  @Array(oepMaxPublicKeyHex)
  external Array<Uint8> publicKeyHex;

  @Array(oepMaxTimestamp)
  external Array<Uint8> issuedUtc;

  @Array(oepMaxTimestamp)
  external Array<Uint8> expiresUtc;

  @Array(oepMaxCertIssuer)
  external Array<Uint8> issuer;

  @Array(oepMaxCertVersion)
  external Array<Uint8> version;

  @Array(oepMaxFingerprint)
  external Array<Uint8> fingerprint;

  @Int32()
  external int revoked;

  @Array(oepMaxTimestamp)
  external Array<Uint8> revokedUtc;
}

/// Mirrors `oep_certificate_list_t` — Foundation-owned heap array,
/// released via `oep_certificate_list_release`.
final class OepCertificateListNative extends Struct {
  external Pointer<OepPublisherCertificateNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_package_trust_status_t` (WP-REP-004).
final class OepPackageTrustStatusNative extends Struct {
  @Int32()
  external int state; // oep_trust_state_t

  @Array(oepMaxFingerprint)
  external Array<Uint8> fingerprint;
}

/// Mirrors `oep_package_verify_result_t` (WP-REP-002).
final class OepPackageVerifyResultNative extends Struct {
  @Int32()
  external int verified;

  @Int32()
  external int objectsExpected;

  @Int32()
  external int objectsPresent;

  @Int32()
  external int relationshipsExpected;

  @Int32()
  external int relationshipsPresent;

  @Int32()
  external int archiveAvailable;

  @Int32()
  external int archiveHashMatches;
}

/// Mirrors `oep_dependency_entry_t` (WP-REP-005 — Dependency Resolution
/// Engine).
final class OepDependencyEntryNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxVersionConstraint)
  external Array<Uint8> versionConstraint;

  @Int32()
  external int optional;

  @Int32()
  external int state; // oep_dependency_state_t

  @Array(oepMaxPackageVersion)
  external Array<Uint8> installedVersion;
}

/// Mirrors `oep_dependency_entry_list_t`. `items` is a Foundation-owned
/// heap array — always released via `oep_dependency_entry_list_release`,
/// never `free`.
final class OepDependencyEntryListNative extends Struct {
  external Pointer<OepDependencyEntryNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_package_id_t` (WP-REP-005).
final class OepPackageIdNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> id;
}

/// Mirrors `oep_package_id_list_t`. `items` is a Foundation-owned heap
/// array — always released via `oep_package_id_list_release`, never
/// `free`.
final class OepPackageIdListNative extends Struct {
  external Pointer<OepPackageIdNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_dependency_resolution_result_t` (WP-REP-005). Plain
/// value type, no release function.
final class OepDependencyResolutionResultNative extends Struct {
  @Int32()
  external int resolved;

  @Int32()
  external int cycleDetected;

  @Array(oepMaxCycleDescription)
  external Array<Uint8> cycleDescription;
}

/// Mirrors `oep_repository_event_t` (WP-REP-006 — Repository Events).
final class OepRepositoryEventNative extends Struct {
  @Int32()
  external int type; // oep_event_type_t

  @Array(oepMaxEventSubjectId)
  external Array<Uint8> subjectId;

  @Array(oepMaxEventDetail)
  external Array<Uint8> detail;

  @Array(oepMaxEventTimestamp)
  external Array<Uint8> occurredAtUtc;

  @Int64()
  external int sequence;
}

/// Mirrors `oep_repository_event_list_t`. `items` is a Foundation-owned
/// heap array — always released via `oep_repository_event_list_release`,
/// never `free`.
final class OepRepositoryEventListNative extends Struct {
  external Pointer<OepRepositoryEventNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_uninstall_impact_t` (WP-REP-007 — Package Uninstall/Update
/// Lifecycle). Plain value type, no release function.
final class OepUninstallImpactNative extends Struct {
  @Int32()
  external int found;

  @Int32()
  external int objectsAffected;

  @Int32()
  external int relationshipsAffected;

  @Int32()
  external int removable;
}

/// Mirrors `oep_package_uninstall_result_t` (WP-REP-007).
final class OepPackageUninstallResultNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Int32()
  external int objectsRemoved;

  @Int32()
  external int relationshipsRemoved;
}

/// Mirrors `oep_update_impact_t` (WP-REP-007). Plain value type, no
/// release function.
final class OepUpdateImpactNative extends Struct {
  @Int32()
  external int currentlyInstalled;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> currentVersion;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> candidateVersion;

  @Array(oepMaxTrustStatus)
  external Array<Uint8> trustStatus;

  @Int32()
  external int updatable;
}

/// Mirrors `oep_package_update_result_t` (WP-REP-007).
final class OepPackageUpdateResultNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> previousVersion;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> newVersion;

  @Int32()
  external int objectsRemoved;

  @Int32()
  external int relationshipsRemoved;

  @Int32()
  external int objectsCreated;

  @Int32()
  external int relationshipsCreated;

  @Array(oepMaxTrustStatus)
  external Array<Uint8> trustStatus;
}

/// Mirrors `oep_merge_conflict_t` (WP-REP-008 — Merge Engine).
final class OepMergeConflictNative extends Struct {
  @Int32()
  external int kind; // oep_merge_conflict_kind_t

  @Array(oepMaxObjectId)
  external Array<Uint8> entityId;

  @Array(256)
  external Array<Uint8> detail;
}

/// Mirrors `oep_merge_conflict_list_t`. `items` is a Foundation-owned
/// heap array — always released via `oep_merge_conflict_list_release`,
/// never `free`.
final class OepMergeConflictListNative extends Struct {
  external Pointer<OepMergeConflictNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_merge_plan_t` (WP-REP-008). Plain value type, no release
/// function; `conflicts` is returned separately via
/// `oep_merge_conflict_list_t`.
final class OepMergePlanNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> version;

  @Array(oepMaxTrustStatus)
  external Array<Uint8> trustStatus;

  @Int32()
  external int trustBlocks;

  @Int32()
  external int dependencyBlocks;

  @Int32()
  external int alreadyRegistered;

  @Int32()
  external int objectsToCreate;

  @Int32()
  external int relationshipsToCreate;

  @Int32()
  external int mergeable;
}

/// Mirrors `oep_merge_result_t` (WP-REP-008). Not populated
/// (zero-initialized) when the call fails.
final class OepMergeResultNative extends Struct {
  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Array(oepMaxPackageVersion)
  external Array<Uint8> version;

  @Int32()
  external int objectsCreated;

  @Int32()
  external int relationshipsCreated;

  @Array(oepMaxTrustStatus)
  external Array<Uint8> trustStatus;
}

/// Mirrors `oep_engine_query_request_t` (WP-EKE-001 — Engineering
/// Knowledge Runtime). Callers populate only the field(s) `kind` needs;
/// the rest are ignored. All pointer fields are input-only, read for
/// the duration of the `oep_engine_query` call — the caller retains
/// ownership, exactly like `oep_object_create_spec_t`.
final class OepEngineQueryRequestNative extends Struct {
  @Int32()
  external int kind; // oep_engine_query_kind_t

  external Pointer<Utf8> objectId; // ById, ConnectedComponent

  @Int32()
  external int objectType; // ByType

  external Pointer<Utf8> domain; // ByDomain

  @Int32()
  external int relationshipType; // ByRelationship

  external Pointer<Utf8> sourceObjectId; // ShortestPath

  external Pointer<Utf8> targetObjectId; // ShortestPath

  external Pointer<Pointer<Utf8>> subgraphObjectIds; // Subgraph

  @Int32()
  external int subgraphObjectIdCount; // Subgraph
}

// --- Native function signatures (oep_api.h, declaration order) ---

typedef OepFoundationVersionNative = Pointer<Utf8> Function();
typedef OepApiVersionNative = Int32 Function();
typedef OepAbiVersionNative = Int32 Function();

typedef OepRuntimeStateToStringNative = Pointer<Utf8> Function(Int32 state);
typedef OepErrorCodeToStringNative = Pointer<Utf8> Function(Int32 code);
typedef OepErrorCategoryToStringNative = Pointer<Utf8> Function(Int32 category);

typedef OepRuntimeCreateNative = Pointer<Void> Function(Pointer<Utf8> foundationVersion);
typedef OepRuntimeDestroyNative = Void Function(Pointer<Void> runtime);
typedef OepRuntimeInitializeNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeOpenRepositoryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> repositoryPath,
);
typedef OepRuntimeCloseRepositoryNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeShutdownNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeGetStateNative = Int32 Function(Pointer<Void> runtime);
typedef OepRuntimeGetRepositoryStatusNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatusNative> outStatus,
);

typedef OepObjectTypeToStringNative = Pointer<Utf8> Function(Int32 type);
typedef OepObjectStoreGetCountNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepObjectStoreGetByIdNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectStoreListNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepObjectListNative> outList,
);
typedef OepObjectListReleaseNative = Void Function(Pointer<OepObjectListNative> list);
typedef OepRuntimeGetRepositoryStatisticsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatisticsNative> outStatistics,
);

typedef OepRelationshipTypeToStringNative = Pointer<Utf8> Function(Int32 type);
typedef OepRelationshipStoreGetCountNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepRelationshipStoreGetByIdNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> relationshipId,
  Pointer<OepRelationshipInfoNative> outRelationship,
);
typedef OepRelationshipStoreListNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRelationshipListNative> outList,
);
typedef OepRelationshipListReleaseNative = Void Function(Pointer<OepRelationshipListNative> list);

typedef OepMatchLocationToStringNative = Pointer<Utf8> Function(Int32 location);
typedef OepSearchRepositoryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRepositorySearchResultNative> outResult,
);
typedef OepRepositorySearchResultReleaseNative = Void Function(Pointer<OepRepositorySearchResultNative> result);
typedef OepSearchObjectsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepObjectSearchResultListNative> outList,
);
typedef OepObjectSearchResultListReleaseNative = Void Function(Pointer<OepObjectSearchResultListNative> list);
typedef OepSearchRelationshipsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRelationshipSearchResultListNative> outList,
);
typedef OepRelationshipSearchResultListReleaseNative = Void Function(
  Pointer<OepRelationshipSearchResultListNative> list,
);

// --- Object/Relationship Mutation, Transactions (Work Package 014,
// TASK-000027/28/29 — the first write-capable surface of this API) ---

typedef OepObjectCreateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Int32 objectType,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> author,
  Pointer<Pointer<Utf8>> tags,
  Int32 tagCount,
  Pointer<OepObjectInfoNative> outObject,
);

typedef OepRelationshipCreateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceObjectId,
  Pointer<Utf8> targetObjectId,
  Int32 relationshipType,
  Pointer<Utf8> author,
  Pointer<Utf8> description,
  Pointer<OepRelationshipInfoNative> outRelationship,
);

// AP-DS-002: oep_object_update/oep_object_delete/
// oep_relationship_update/oep_relationship_delete existed in oep_api.h
// since Work Package 014 but were never bound here (a real gap this
// session's own platform architecture review flagged: Studio could
// create and read objects/relationships but not update or delete
// them). oep_object_update_content/oep_object_get_content are new
// (OEP_API_VERSION 20) -- see EngineeringObject::content's own doc
// comment in oep_foundation for what the opaque `content` payload is
// for (Diagram Studio's repository-backed presentation state).
typedef OepObjectUpdateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> author,
  Pointer<Pointer<Utf8>> tags,
  Int32 tagCount,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectDeleteNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> objectId);
typedef OepObjectUpdateContentNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Utf8> content,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectGetContentNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Pointer<Utf8>> outText,
  Pointer<Size> outLength,
);
typedef OepRelationshipUpdateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> relationshipId,
  Pointer<Utf8> author,
  Pointer<Utf8> description,
  Pointer<OepRelationshipInfoNative> outRelationship,
);
typedef OepRelationshipDeleteNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> relationshipId);

typedef OepTransactionBeginNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionCommitNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionRollbackNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionIsActiveNative = Int32 Function(Pointer<Void> runtime);

typedef OepPackageInstallNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepPackageInstallResultNative> outResult,
);
typedef OepPackageListInstalledNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepInstalledPackageListNative> outList,
);
typedef OepInstalledPackageListReleaseNative = Void Function(Pointer<OepInstalledPackageListNative> list);

typedef OepPackageGetInfoNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageDetailsNative> outDetails,
);
typedef OepPackageGetContentsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepObjectListNative> outObjects,
  Pointer<OepRelationshipListNative> outRelationships,
);
typedef OepPackageLocateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> entityId,
  Pointer<OepPackageOwnerNative> outOwner,
);
typedef OepPackageVerifyNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageVerifyResultNative> outResult,
);
typedef OepPackageSearchNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepInstalledPackageListNative> outList,
);

typedef OepTransactionGetInfoNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepTransactionInfoNative> outInfo,
);
typedef OepTransactionHistoryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepTransactionRecordListNative> outList,
);
typedef OepTransactionRecordListReleaseNative = Void Function(Pointer<OepTransactionRecordListNative> list);

typedef OepTrustAddCertificateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> publisherId,
  Pointer<Utf8> publisherName,
  Pointer<Utf8> publicKeyHex,
  Pointer<Utf8> issuedUtc,
  Pointer<Utf8> expiresUtc,
  Pointer<Utf8> issuer,
  Pointer<Utf8> version,
  Pointer<OepPublisherCertificateNative> outCertificate,
);
typedef OepTrustGetCertificateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> publisherId,
  Pointer<OepPublisherCertificateNative> outCertificate,
);
typedef OepTrustListCertificatesNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepCertificateListNative> outList,
);
typedef OepCertificateListReleaseNative = Void Function(Pointer<OepCertificateListNative> list);
typedef OepTrustRevokeCertificateNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> publisherId);
typedef OepTrustGetPolicyNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Int32> outRequireSignatures);
typedef OepTrustSetPolicyNative = OepResultNative Function(Pointer<Void> runtime, Int32 requireSignatures);
typedef OepPackageGetTrustStatusNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageTrustStatusNative> outStatus,
);

typedef OepDependencyStateToStringNative = Pointer<Utf8> Function(Int32 state);
typedef OepDependencyEntryListReleaseNative = Void Function(Pointer<OepDependencyEntryListNative> list);
typedef OepPackageIdListReleaseNative = Void Function(Pointer<OepPackageIdListNative> list);
typedef OepPackageResolveDependenciesNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepDependencyResolutionResultNative> outResult,
  Pointer<OepDependencyEntryListNative> outEntries,
  Pointer<OepPackageIdListNative> outInstallOrder,
);

typedef OepEventTypeToStringNative = Pointer<Utf8> Function(Int32 type);
typedef OepRepositoryEventListReleaseNative = Void Function(Pointer<OepRepositoryEventListNative> list);
typedef OepRuntimeRecentEventsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Int32 limit,
  Pointer<OepRepositoryEventListNative> outList,
);

typedef OepPackageAnalyzeUninstallImpactNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepUninstallImpactNative> outImpact,
  Pointer<OepPackageIdListNative> outBlockingDependents,
);
typedef OepPackageUninstallNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageUninstallResultNative> outResult,
);
typedef OepPackageAnalyzeUpdateImpactNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepUpdateImpactNative> outImpact,
  Pointer<OepPackageIdListNative> outBrokenDependents,
);
typedef OepPackageUpdateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepPackageUpdateResultNative> outResult,
);

typedef OepMergeConflictKindToStringNative = Pointer<Utf8> Function(Int32 kind);
typedef OepMergeConflictListReleaseNative = Void Function(Pointer<OepMergeConflictListNative> list);
typedef OepRepositoryPlanMergeNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepMergePlanNative> outPlan,
  Pointer<OepMergeConflictListNative> outConflicts,
);
typedef OepRepositoryExecuteMergeNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepMergeResultNative> outResult,
);

/// Mirrors `oep_graph_issue_t` (WP-EKE-002 — Engineering Knowledge Graph
/// Engine).
final class OepGraphIssueNative extends Struct {
  @Int32()
  external int kind; // oep_graph_issue_kind_t

  @Array(oepMaxRelationshipId)
  external Array<Uint8> relationshipId;

  @Array(256)
  external Array<Uint8> detail;
}

/// Mirrors `oep_graph_issue_list_t`. `items` is a Foundation-owned heap
/// array — always released via `oep_graph_issue_list_release`, never
/// `free`.
final class OepGraphIssueListNative extends Struct {
  external Pointer<OepGraphIssueNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_graph_statistics_t` (WP-EKE-002). Plain value type, no
/// release function.
final class OepGraphStatisticsNative extends Struct {
  @Int32()
  external int objectCount;

  @Int32()
  external int relationshipCount;

  @Int32()
  external int connectedComponentCount;

  @Double()
  external double density;

  @Int32()
  external int maximumDepth;

  @Double()
  external double averageDegree;
}

/// Mirrors `oep_component_membership_t` (WP-EKE-002).
final class OepComponentMembershipNative extends Struct {
  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;

  @Int32()
  external int componentIndex;
}

/// Mirrors `oep_component_membership_list_t`. `items` is a
/// Foundation-owned heap array — always released via
/// `oep_component_membership_list_release`, never `free`.
final class OepComponentMembershipListNative extends Struct {
  external Pointer<OepComponentMembershipNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_query_filter_t` (WP-EKE-003 — Engineering Query Engine).
/// Every optional field follows the "has_X" flag convention
/// `OepEngineQueryRequestNative` (WP-EKE-001) already established. `tags`
/// is input-only, read for the duration of the `oep_eqe_plan_query`/
/// `oep_eqe_execute_query` call that receives it — the caller retains
/// ownership, same as `subgraphObjectIds` above.
final class OepQueryFilterNative extends Struct {
  @Int32()
  external int hasObjectType;

  @Int32()
  external int objectType;

  @Int32()
  external int hasDomain;

  @Array(oepMaxObjectName)
  external Array<Uint8> domain;

  @Int32()
  external int hasRelationshipType;

  @Int32()
  external int relationshipType;

  @Int32()
  external int hasPublisherId;

  @Array(oepMaxPackageId)
  external Array<Uint8> publisherId;

  @Int32()
  external int hasPackageId;

  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  external Pointer<Pointer<Utf8>> tags;

  @Int32()
  external int tagCount;

  @Int32()
  external int hasMaxDepth;

  @Int32()
  external int maxDepth;

  @Int32()
  external int hasOutgoingOnly;

  @Int32()
  external int outgoingOnly;
}

/// Mirrors `oep_query_request_t` (WP-EKE-003). `secondaryObjectId` is
/// only meaningful for `QueryCategory.path`; ignored otherwise, per the
/// C struct's own doc comment.
final class OepQueryRequestNative extends Struct {
  @Int32()
  external int category; // oep_query_category_t

  @Array(oepMaxObjectId)
  external Array<Uint8> primaryObjectId;

  @Array(oepMaxObjectId)
  external Array<Uint8> secondaryObjectId;

  external OepQueryFilterNative filter;
}

/// Mirrors `oep_query_plan_t` (WP-EKE-003). `strategy` mirrors
/// `TraversalStrategy`: 0 = None, 1 = BreadthFirst, 2 = DepthFirst.
final class OepQueryPlanNative extends Struct {
  @Int32()
  external int category;

  @Int32()
  external int strategy;

  @Double()
  external double estimatedCost;
}

/// Mirrors `oep_query_result_summary_t` (WP-EKE-003). Used both as the
/// `oep_eqe_execute_query` result summary and as the
/// most-recently-executed-query snapshot (`oep_eqe_query_statistics`).
final class OepQueryResultSummaryNative extends Struct {
  @Double()
  external double executionTimeMs;

  @Int32()
  external int objectsExamined;

  @Int32()
  external int relationshipsExamined;

  @Int32()
  external int traversalDepth;

  @Int32()
  external int resultCount;

  @Array(256)
  external Array<Uint8> traversalSummary;
}

/// Mirrors `oep_rule_scope_t` (WP-EKE-004 — Engineering Rules Engine).
/// Every field beyond `kind` is optional via a "has_X" flag, the same
/// convention `OepQueryFilterNative` (WP-EKE-003) established.
final class OepRuleScopeNative extends Struct {
  @Int32()
  external int kind; // oep_rule_scope_kind_t

  @Int32()
  external int hasObjectType;

  @Int32()
  external int objectType;

  @Int32()
  external int hasDomain;

  @Array(oepMaxObjectName)
  external Array<Uint8> domain;

  @Int32()
  external int hasPackageId;

  @Array(oepMaxPackageId)
  external Array<Uint8> packageId;

  @Int32()
  external int hasObjectId;

  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;
}

/// Mirrors `oep_rule_condition_t` (WP-EKE-004). `hasDirection`/`direction`
/// mirrors `OepQueryFilterNative.hasOutgoingOnly`'s own nullable-bool
/// direction convention (WP-EKE-003): nonzero `direction` means outgoing
/// only, 0 means incoming only, `hasDirection == 0` means either
/// direction.
final class OepRuleConditionNative extends Struct {
  @Int32()
  external int kind; // oep_rule_condition_kind_t

  @Int32()
  external int hasRelationshipType;

  @Int32()
  external int relationshipType;

  @Int32()
  external int hasDirection;

  @Int32()
  external int direction;

  @Int32()
  external int hasTag;

  @Array(oepMaxTagLength)
  external Array<Uint8> tag;

  @Int32()
  external int hasCount;

  @Int32()
  external int count;
}

/// Mirrors `oep_rule_condition_list_t`. `items` is a Foundation-owned
/// heap array — always released via `oep_rule_condition_list_release`,
/// never `free`.
final class OepRuleConditionListNative extends Struct {
  external Pointer<OepRuleConditionNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_engineering_rule_t` (WP-EKE-004). Doubles as the
/// `oep_rules_register` INPUT shape and the `oep_rules_get` scalar
/// OUTPUT shape — see `oep_api.h`'s "Rule input/output struct shape"
/// note: on INPUT, `conditions`/`conditionCount` carry the rule's
/// condition vector directly (caller-owned, read only for the call's
/// duration); on OUTPUT, they are always NULL/0 — conditions come back
/// separately via `oep_rule_condition_list_t`.
final class OepEngineeringRuleNative extends Struct {
  @Array(oepMaxRuleId)
  external Array<Uint8> ruleId;

  @Array(oepMaxRuleName)
  external Array<Uint8> name;

  @Array(oepMaxRuleDescription)
  external Array<Uint8> description;

  @Int32()
  external int category; // oep_rule_category_t

  @Int32()
  external int severity; // oep_rule_severity_t

  external OepRuleScopeNative scope;

  external Pointer<OepRuleConditionNative> conditions;

  @Int32()
  external int conditionCount;

  @Array(oepMaxRuleMessage)
  external Array<Uint8> message;

  @Array(oepMaxRuleRecommendation)
  external Array<Uint8> recommendation;
}

/// The scalar fields of `oep_rule_evaluation_result_t` (WP-EKE-004) —
/// Status and Message. `affected_objects`/`diagnostics` are returned
/// separately (see `oep_rules_evaluate`).
final class OepRuleEvaluationResultNative extends Struct {
  @Int32()
  external int status; // oep_rule_evaluation_status_t

  @Array(oepMaxRuleMessage)
  external Array<Uint8> message;
}

/// Mirrors `oep_rule_diagnostic_t` (WP-EKE-004). `objectId` is empty for
/// a graph-level diagnostic (e.g. a NoCycles violation).
final class OepRuleDiagnosticNative extends Struct {
  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;

  @Array(oepMaxRuleDiagnosticDetail)
  external Array<Uint8> detail;
}

/// Mirrors `oep_rule_diagnostic_list_t`. `items` is a Foundation-owned
/// heap array — always released via `oep_rule_diagnostic_list_release`,
/// never `free`.
final class OepRuleDiagnosticListNative extends Struct {
  external Pointer<OepRuleDiagnosticNative> items;

  @Int32()
  external int count;
}

/// One per-rule summary entry produced by `oep_rules_evaluate_all`
/// (WP-EKE-004) — rule_id/status/message plus affected/diagnostic
/// COUNTS, not full per-rule detail.
final class OepRuleEvaluationSummaryNative extends Struct {
  @Array(oepMaxRuleId)
  external Array<Uint8> ruleId;

  @Int32()
  external int status; // oep_rule_evaluation_status_t

  @Array(oepMaxRuleMessage)
  external Array<Uint8> message;

  @Int32()
  external int affectedObjectCount;

  @Int32()
  external int diagnosticCount;
}

/// Mirrors `oep_rule_evaluation_summary_list_t`. `items` is a
/// Foundation-owned heap array — always released via
/// `oep_rule_evaluation_summary_list_release`, never `free`.
final class OepRuleEvaluationSummaryListNative extends Struct {
  external Pointer<OepRuleEvaluationSummaryNative> items;

  @Int32()
  external int count;
}

// --- Engineering Validation Engine (WP-EKE-005) ---

/// The scalar fields of `oep_validation_report_summary_t` — everything
/// except the findings list (see `OepValidationFindingListNative`).
final class OepValidationReportSummaryNative extends Struct {
  @Int32()
  external int targetKind; // oep_validation_target_kind_t

  @Int32()
  external int passCount;

  @Int32()
  external int warningCount;

  @Int32()
  external int errorCount;

  @Int32()
  external int criticalCount;

  @Double()
  external double executionTimeMs;

  @Int32()
  external int rulesEvaluated;
}

/// Mirrors `oep_validation_finding_t`. Deliberately omits
/// affected_objects/diagnostics — see `oep_api.h`'s "Report/finding
/// detail level" note; call `oep_rules_evaluate` with `ruleId` for that
/// detail.
final class OepValidationFindingNative extends Struct {
  @Array(oepMaxFindingId)
  external Array<Uint8> findingId;

  @Array(oepMaxRuleId)
  external Array<Uint8> ruleId;

  @Int32()
  external int severity; // oep_rule_severity_t

  @Int32()
  external int category; // oep_rule_category_t

  @Array(oepMaxRuleMessage)
  external Array<Uint8> message;

  @Array(oepMaxRuleRecommendation)
  external Array<Uint8> recommendation;
}

/// Mirrors `oep_validation_finding_list_t`. `items` is a Foundation-owned
/// heap array — always released via `oep_validation_finding_list_release`,
/// never `free`.
final class OepValidationFindingListNative extends Struct {
  external Pointer<OepValidationFindingNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_validation_statistics_t`.
final class OepValidationStatisticsNative extends Struct {
  @Int32()
  external int rulesEvaluated;

  @Int32()
  external int rulesPassed;

  @Int32()
  external int rulesFailed;

  @Int32()
  external int rulesNotApplicable;

  @Int32()
  external int rulesErrored;

  @Double()
  external double executionTimeMs;
}

// --- Engineering Analysis & Reasoning Engine (WP-EKE-006) ---

/// The scalar fields of `oep_reasoning_summary_t` — everything except the
/// conclusion/recommendation id lists, mirroring
/// [OepValidationReportSummaryNative]'s (WP-EKE-005) own scalars-plus-
/// separate-lists split.
final class OepReasoningSummaryNative extends Struct {
  @Int32()
  external int conclusionCount;

  @Int32()
  external int recommendationCount;

  @Double()
  external double executionTimeMs;
}

/// One `oep_conclusion_t`, fixed-layout, minus the four id lists
/// (supportingEvidenceIds/referencedObjects/referencedRules/
/// referencedFindings), each fetched separately via
/// `oep_reasoning_get_conclusion`'s matching out_ parameter.
final class OepConclusionNative extends Struct {
  @Array(oepMaxConclusionId)
  external Array<Uint8> conclusionId;

  @Array(oepMaxConclusionStatement)
  external Array<Uint8> statement;

  @Double()
  external double confidence;

  @Array(oepMaxConclusionExplanation)
  external Array<Uint8> explanation;
}

/// One `oep_recommendation_t`, fixed-layout, minus
/// supportingEvidenceIds (fetched separately via
/// `oep_reasoning_get_recommendation`'s `out_evidence_ids`).
final class OepRecommendationNative extends Struct {
  @Array(oepMaxRecommendationId)
  external Array<Uint8> recommendationId;

  @Int32()
  external int kind; // oep_recommendation_kind_t

  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;

  @Array(oepMaxRecommendationMessage)
  external Array<Uint8> message;
}

/// Mirrors `oep_evidence_node_t`. See `oep_api.h`'s "Evidence Graph
/// exposure" note — this is the only Evidence Graph shape Studio exposes;
/// no relationship-edge enumeration, no full-graph listing.
final class OepEvidenceNodeNative extends Struct {
  @Array(oepMaxEvidenceId)
  external Array<Uint8> evidenceId;

  @Int32()
  external int kind; // oep_evidence_kind_t (see oep_api.h declared order)

  @Array(oepMaxEvidenceReferenceId)
  external Array<Uint8> referenceId;

  @Array(oepMaxEvidenceDetail)
  external Array<Uint8> detail;
}

// --- Engineering Intelligence Platform (WP-EKE-007) ---

/// The one shape every `oep_eip_*` workflow returns, minus its separately
/// returned `object_ids` list. Mirrors `oep_workflow_result_t`.
final class OepWorkflowResultNative extends Struct {
  @Int32()
  external int kind; // oep_workflow_kind_t

  @Int32()
  external int success;

  @Array(oepMaxWorkflowSummary)
  external Array<Uint8> summary;

  @Double()
  external double executionTimeMs;
}

/// Scalar, count-only summary of one KnowledgeSession. Mirrors
/// `oep_knowledge_session_summary_t`.
final class OepKnowledgeSessionSummaryNative extends Struct {
  @Array(oepMaxSessionId)
  external Array<Uint8> sessionId;

  @Array(oepMaxTimestamp)
  external Array<Uint8> createdUtc;

  @Array(oepMaxTimestamp)
  external Array<Uint8> lastActiveUtc;

  @Int32()
  external int closed;

  @Int32()
  external int queryHistoryCount;

  @Int32()
  external int validationHistoryCount;

  @Int32()
  external int analysisHistoryCount;

  @Int32()
  external int reasoningHistoryCount;

  @Int32()
  external int recommendationCount;

  @Int32()
  external int activeObjectCount;

  @Int32()
  external int activePackageCount;

  @Double()
  external double totalExecutionTimeMs;
}

/// Scalar mirror of `oep_engineering_summary_report_t`.
final class OepEngineeringSummaryReportNative extends Struct {
  @Int32()
  external int objectCount;

  @Int32()
  external int relationshipCount;

  @Int32()
  external int connectedComponentCount;

  @Int32()
  external int validationPassCount;

  @Int32()
  external int validationFindingCount;

  @Array(oepMaxReportSummary)
  external Array<Uint8> summary;
}

/// Scalar mirror of `oep_engineering_health_report_t`.
final class OepEngineeringHealthReportNative extends Struct {
  @Double()
  external double healthScore;

  @Int32()
  external int passed;

  @Int32()
  external int failed;

  @Int32()
  external int warnings;

  @Int32()
  external int errors;

  @Int32()
  external int critical;

  @Array(oepMaxReportSummary)
  external Array<Uint8> summary;
}

/// Scalar mirror of `oep_runtime_metrics_t`.
final class OepRuntimeMetricsNative extends Struct {
  @Int32()
  external int queryCount;

  @Int32()
  external int validationCount;

  @Int32()
  external int analysisCount;

  @Int32()
  external int reasoningCount;

  @Int32()
  external int cacheHits;

  @Int32()
  external int cacheMisses;

  @Int32()
  external int activeSessionCount;

  @Int32()
  external int totalSessionCount;

  @Double()
  external double totalExecutionTimeMs;
}

// --- Engineering Knowledge Runtime (WP-EKE-001) ---

typedef OepEngineLoadObjectNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepObjectInfoNative> outObject,
  Pointer<Int32> outFound,
);
typedef OepEngineLoadGraphNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outObjectsLoaded,
  Pointer<Int32> outRelationshipsLoaded,
);
typedef OepEngineQueryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineQueryRequestNative> request,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
  Pointer<Int32> outPathExists,
);
typedef OepEngineTraverseNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> startObjectId,
  Int32 order,
  Int32 hasRelationshipFilter,
  Int32 relationshipFilter,
  Int32 hasMaxDepth,
  Int32 maxDepth,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEngineRelatedObjectsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEngineDependencyGraphNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
);

// --- Engineering Knowledge Graph Engine (WP-EKE-002) ---

typedef OepKgeBuildGraphNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outObjects,
  Pointer<Int32> outRelationships,
);
typedef OepKgeRefreshGraphNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outObjects,
  Pointer<Int32> outRelationships,
);
typedef OepGraphIssueKindToStringNative = Pointer<Utf8> Function(Int32 kind);
typedef OepGraphIssueListReleaseNative = Void Function(Pointer<OepGraphIssueListNative> list);
typedef OepKgeValidateGraphNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outValid,
  Pointer<OepGraphIssueListNative> outIssues,
);
typedef OepKgeGraphStatisticsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepGraphStatisticsNative> outStats,
);
typedef OepComponentMembershipListReleaseNative = Void Function(Pointer<OepComponentMembershipListNative> list);
typedef OepKgeConnectedComponentsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepComponentMembershipListNative> outComponents,
  Pointer<Int32> outCount,
);
typedef OepKgeShortestPathNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceId,
  Pointer<Utf8> targetId,
  Pointer<Int32> outPathExists,
  Pointer<OepPackageIdListNative> outPath,
);
typedef OepKgeSubgraphNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Pointer<Utf8>> objectIds,
  Int32 objectIdCount,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
);
typedef OepStringReleaseNative = Void Function(Pointer<Pointer<Utf8>> text);
typedef OepKgeExportJsonNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Pointer<Utf8>> outText,
  Pointer<Size> outLength,
);
typedef OepKgeExportGraphmlPlaceholderNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Pointer<Utf8>> outText,
  Pointer<Size> outLength,
);

// --- Engineering Rules Engine (WP-EKE-004) ---

typedef OepRuleCategoryToStringNative = Pointer<Utf8> Function(Int32 category);
typedef OepRuleSeverityToStringNative = Pointer<Utf8> Function(Int32 severity);
typedef OepRuleScopeKindToStringNative = Pointer<Utf8> Function(Int32 kind);
typedef OepRuleConditionKindToStringNative = Pointer<Utf8> Function(Int32 kind);
typedef OepRuleEvaluationStatusToStringNative = Pointer<Utf8> Function(Int32 status);
typedef OepRuleConditionListReleaseNative = Void Function(Pointer<OepRuleConditionListNative> list);
typedef OepRuleDiagnosticListReleaseNative = Void Function(Pointer<OepRuleDiagnosticListNative> list);
typedef OepRuleEvaluationSummaryListReleaseNative = Void Function(
  Pointer<OepRuleEvaluationSummaryListNative> list,
);
typedef OepRulesRegisterNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineeringRuleNative> rule,
);
typedef OepRulesRemoveNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> ruleId);
typedef OepRulesEnableNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> ruleId);
typedef OepRulesDisableNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> ruleId);
typedef OepRulesListAllNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outRuleIds,
);
typedef OepRulesListEnabledNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outRuleIds,
);
typedef OepRulesListDisabledNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outRuleIds,
);
typedef OepRulesGetNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> ruleId,
  Pointer<OepEngineeringRuleNative> outRule,
  Pointer<OepRuleConditionListNative> outConditions,
  Pointer<Int32> outFound,
);
typedef OepRulesEvaluateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> ruleId,
  Pointer<OepRuleEvaluationResultNative> outResult,
  Pointer<OepPackageIdListNative> outAffectedObjects,
  Pointer<OepRuleDiagnosticListNative> outDiagnostics,
);
typedef OepRulesEvaluateAllNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRuleEvaluationSummaryListNative> outSummaries,
);

// --- Engineering Validation Engine (WP-EKE-005) ---

typedef OepValidationProfileToStringNative = Pointer<Utf8> Function(Int32 profile);
typedef OepValidationFindingListReleaseNative = Void Function(Pointer<OepValidationFindingListNative> list);
typedef OepValidationCreateSessionNative = OepResultNative Function(
  Pointer<Void> runtime,
  Int32 profile,
  Pointer<Utf8> outSessionId,
  Size sessionIdBufferSize,
);
typedef OepValidationValidateObjectNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationValidateObjectsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Pointer<Utf8>> objectIds,
  Int32 objectIdCount,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationValidateContextNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationValidatePackageNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> packageId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationReportNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationStatisticsFnNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepValidationStatisticsNative> outStats,
);

// --- Engineering Analysis & Reasoning Engine (WP-EKE-006) ---

typedef OepAnalysisDependenciesNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Int32> outMaxDepth,
  Pointer<OepPackageIdListNative> outDependencyObjectIds,
  Pointer<OepPackageIdListNative> outDependencyRelationshipIds,
  Pointer<Utf8> outEvidence,
);
typedef OepAnalysisImpactNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Int32> outMaxDepth,
  Pointer<OepPackageIdListNative> outAffectedObjectIds,
  Pointer<OepPackageIdListNative> outAffectedRelationshipIds,
  Pointer<Utf8> outEvidence,
);
typedef OepAnalysisReachabilityNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceId,
  Pointer<Utf8> targetId,
  Pointer<Int32> outReachable,
  Pointer<OepPackageIdListNative> outPath,
  Pointer<Utf8> outEvidence,
);
typedef OepAnalysisRootCauseNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> symptomObjectId,
  Pointer<OepPackageIdListNative> outCandidateRootCauses,
  Pointer<OepPackageIdListNative> outFailureChain,
  Pointer<Utf8> outEvidence,
);
typedef OepReasoningCreateSessionNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objective,
  Pointer<Pointer<Utf8>> startingObjectIds,
  Int32 startingObjectIdCount,
  Pointer<Utf8> outSessionId,
  Size sessionIdBufferSize,
);
typedef OepReasoningExecuteNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepReasoningSummaryNative> outSummary,
  Pointer<OepPackageIdListNative> outConclusionIds,
  Pointer<OepPackageIdListNative> outRecommendationIds,
);
typedef OepReasoningReportNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepReasoningSummaryNative> outSummary,
  Pointer<OepPackageIdListNative> outConclusionIds,
  Pointer<OepPackageIdListNative> outRecommendationIds,
);
typedef OepReasoningRecommendationsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepPackageIdListNative> outRecommendationIds,
);
typedef OepReasoningGetConclusionNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> conclusionId,
  Pointer<OepConclusionNative> outConclusion,
  Pointer<OepPackageIdListNative> outSupportingEvidenceIds,
  Pointer<OepPackageIdListNative> outReferencedObjects,
  Pointer<OepPackageIdListNative> outReferencedRules,
  Pointer<OepPackageIdListNative> outReferencedFindings,
);
typedef OepRecommendationKindToStringNative = Pointer<Utf8> Function(Int32 kind);
typedef OepReasoningGetRecommendationNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> recommendationId,
  Pointer<OepRecommendationNative> outRecommendation,
  Pointer<OepPackageIdListNative> outSupportingEvidenceIds,
);
typedef OepReasoningGetEvidenceNodeNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> evidenceId,
  Pointer<OepEvidenceNodeNative> outNode,
);

// --- Engineering Intelligence Platform (WP-EKE-007) ---

typedef OepWorkflowKindToStringNative = Pointer<Utf8> Function(Int32 kind);
typedef OepInspectionTargetKindToStringNative = Pointer<Utf8> Function(Int32 kind);
typedef OepEipCreateSessionNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> outSessionId,
  Size sessionIdBufferSize,
);
typedef OepEipResumeSessionNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> sessionId);
typedef OepEipCloneSessionNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> outSessionId,
  Size sessionIdBufferSize,
);
typedef OepEipCloseSessionNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> sessionId);
typedef OepEipSwitchSessionNative = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> sessionId);
typedef OepEipListSessionsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outSessionIds,
);
typedef OepEipGetSessionNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepKnowledgeSessionSummaryNative> outSession,
);
typedef OepEipExportSessionSummaryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Pointer<Utf8>> outSummary,
  Pointer<Size> outLength,
);
typedef OepEipQueryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Int32 category,
  Pointer<Utf8> primaryObjectId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipInspectNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Int32 kind,
  Pointer<Utf8> targetId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipValidateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  Int32 profile,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipAnalyzeNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipReasonNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objective,
  Pointer<Pointer<Utf8>> startingObjectIds,
  Int32 startingObjectIdCount,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipRecommendNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipEngineeringSummaryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineeringSummaryReportNative> outSummary,
);
typedef OepEipEngineeringHealthNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineeringHealthReportNative> outHealth,
);
typedef OepEipEngineeringRecommendationsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepPackageIdListNative> outRecommendationMessages,
);
typedef OepEipRuntimeMetricsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRuntimeMetricsNative> outMetrics,
);
typedef OepEipInvalidateCachesNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepEipCleanupNative = OepResultNative Function(Pointer<Void> runtime);

// --- Engineering Query Engine (WP-EKE-003) ---

typedef OepQueryCategoryToStringNative = Pointer<Utf8> Function(Int32 category);
typedef OepEqePlanQueryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepQueryRequestNative> request,
  Pointer<OepQueryPlanNative> outPlan,
  Pointer<OepPackageIdListNative> outIndexesUsed,
  Pointer<OepPackageIdListNative> outExecutionOrder,
);
typedef OepEqeExecuteQueryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepQueryRequestNative> request,
  Pointer<OepQueryResultSummaryNative> outSummary,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
);
typedef OepEqeQueryStatisticsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepQueryResultSummaryNative> outStats,
);
typedef OepEqeClearQueryCacheNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepEqeQueryCacheInfoNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outPlanCount,
  Pointer<Int32> outResultCount,
);

// dart:ffi requires a separate Dart-side typedef alongside each Native
// one whenever the native signature uses fixed-width types (Int32) that
// don't map 1:1 onto a Dart type.

typedef OepFoundationVersionDart = Pointer<Utf8> Function();
typedef OepApiVersionDart = int Function();
typedef OepAbiVersionDart = int Function();

typedef OepRuntimeStateToStringDart = Pointer<Utf8> Function(int state);
typedef OepErrorCodeToStringDart = Pointer<Utf8> Function(int code);
typedef OepErrorCategoryToStringDart = Pointer<Utf8> Function(int category);

typedef OepRuntimeCreateDart = Pointer<Void> Function(Pointer<Utf8> foundationVersion);
typedef OepRuntimeDestroyDart = void Function(Pointer<Void> runtime);
typedef OepRuntimeInitializeDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeOpenRepositoryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> repositoryPath,
);
typedef OepRuntimeCloseRepositoryDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeShutdownDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeGetStateDart = int Function(Pointer<Void> runtime);
typedef OepRuntimeGetRepositoryStatusDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatusNative> outStatus,
);

typedef OepObjectTypeToStringDart = Pointer<Utf8> Function(int type);
typedef OepObjectStoreGetCountDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepObjectStoreGetByIdDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectStoreListDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepObjectListNative> outList,
);
typedef OepObjectListReleaseDart = void Function(Pointer<OepObjectListNative> list);
typedef OepRuntimeGetRepositoryStatisticsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatisticsNative> outStatistics,
);

typedef OepRelationshipTypeToStringDart = Pointer<Utf8> Function(int type);
typedef OepRelationshipStoreGetCountDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepRelationshipStoreGetByIdDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> relationshipId,
  Pointer<OepRelationshipInfoNative> outRelationship,
);
typedef OepRelationshipStoreListDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRelationshipListNative> outList,
);
typedef OepRelationshipListReleaseDart = void Function(Pointer<OepRelationshipListNative> list);

typedef OepMatchLocationToStringDart = Pointer<Utf8> Function(int location);
typedef OepSearchRepositoryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRepositorySearchResultNative> outResult,
);
typedef OepRepositorySearchResultReleaseDart = void Function(Pointer<OepRepositorySearchResultNative> result);
typedef OepSearchObjectsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepObjectSearchResultListNative> outList,
);
typedef OepObjectSearchResultListReleaseDart = void Function(Pointer<OepObjectSearchResultListNative> list);
typedef OepSearchRelationshipsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRelationshipSearchResultListNative> outList,
);
typedef OepRelationshipSearchResultListReleaseDart = void Function(
  Pointer<OepRelationshipSearchResultListNative> list,
);

typedef OepObjectCreateDart = OepResultNative Function(
  Pointer<Void> runtime,
  int objectType,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> author,
  Pointer<Pointer<Utf8>> tags,
  int tagCount,
  Pointer<OepObjectInfoNative> outObject,
);

typedef OepRelationshipCreateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceObjectId,
  Pointer<Utf8> targetObjectId,
  int relationshipType,
  Pointer<Utf8> author,
  Pointer<Utf8> description,
  Pointer<OepRelationshipInfoNative> outRelationship,
);

// AP-DS-002: Dart-side counterparts of the Native typedefs added above.
typedef OepObjectUpdateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> author,
  Pointer<Pointer<Utf8>> tags,
  int tagCount,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectDeleteDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> objectId);
typedef OepObjectUpdateContentDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Utf8> content,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectGetContentDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Pointer<Utf8>> outText,
  Pointer<Size> outLength,
);
typedef OepRelationshipUpdateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> relationshipId,
  Pointer<Utf8> author,
  Pointer<Utf8> description,
  Pointer<OepRelationshipInfoNative> outRelationship,
);
typedef OepRelationshipDeleteDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> relationshipId);

typedef OepTransactionBeginDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionCommitDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionRollbackDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionIsActiveDart = int Function(Pointer<Void> runtime);

typedef OepPackageInstallDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepPackageInstallResultNative> outResult,
);
typedef OepPackageListInstalledDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepInstalledPackageListNative> outList,
);
typedef OepInstalledPackageListReleaseDart = void Function(Pointer<OepInstalledPackageListNative> list);

typedef OepPackageGetInfoDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageDetailsNative> outDetails,
);
typedef OepPackageGetContentsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepObjectListNative> outObjects,
  Pointer<OepRelationshipListNative> outRelationships,
);
typedef OepPackageLocateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> entityId,
  Pointer<OepPackageOwnerNative> outOwner,
);
typedef OepPackageVerifyDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageVerifyResultNative> outResult,
);
typedef OepPackageSearchDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepInstalledPackageListNative> outList,
);

typedef OepTransactionGetInfoDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepTransactionInfoNative> outInfo,
);
typedef OepTransactionHistoryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepTransactionRecordListNative> outList,
);
typedef OepTransactionRecordListReleaseDart = void Function(Pointer<OepTransactionRecordListNative> list);

typedef OepTrustAddCertificateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> publisherId,
  Pointer<Utf8> publisherName,
  Pointer<Utf8> publicKeyHex,
  Pointer<Utf8> issuedUtc,
  Pointer<Utf8> expiresUtc,
  Pointer<Utf8> issuer,
  Pointer<Utf8> version,
  Pointer<OepPublisherCertificateNative> outCertificate,
);
typedef OepTrustGetCertificateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> publisherId,
  Pointer<OepPublisherCertificateNative> outCertificate,
);
typedef OepTrustListCertificatesDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepCertificateListNative> outList,
);
typedef OepCertificateListReleaseDart = void Function(Pointer<OepCertificateListNative> list);
typedef OepTrustRevokeCertificateDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> publisherId);
typedef OepTrustGetPolicyDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Int32> outRequireSignatures);
typedef OepTrustSetPolicyDart = OepResultNative Function(Pointer<Void> runtime, int requireSignatures);
typedef OepPackageGetTrustStatusDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageTrustStatusNative> outStatus,
);

typedef OepDependencyStateToStringDart = Pointer<Utf8> Function(int state);
typedef OepDependencyEntryListReleaseDart = void Function(Pointer<OepDependencyEntryListNative> list);
typedef OepPackageIdListReleaseDart = void Function(Pointer<OepPackageIdListNative> list);
typedef OepPackageResolveDependenciesDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepDependencyResolutionResultNative> outResult,
  Pointer<OepDependencyEntryListNative> outEntries,
  Pointer<OepPackageIdListNative> outInstallOrder,
);

typedef OepEventTypeToStringDart = Pointer<Utf8> Function(int type);
typedef OepRepositoryEventListReleaseDart = void Function(Pointer<OepRepositoryEventListNative> list);
typedef OepRuntimeRecentEventsDart = OepResultNative Function(
  Pointer<Void> runtime,
  int limit,
  Pointer<OepRepositoryEventListNative> outList,
);

typedef OepPackageAnalyzeUninstallImpactDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepUninstallImpactNative> outImpact,
  Pointer<OepPackageIdListNative> outBlockingDependents,
);
typedef OepPackageUninstallDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> packageId,
  Pointer<OepPackageUninstallResultNative> outResult,
);
typedef OepPackageAnalyzeUpdateImpactDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepUpdateImpactNative> outImpact,
  Pointer<OepPackageIdListNative> outBrokenDependents,
);
typedef OepPackageUpdateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepPackageUpdateResultNative> outResult,
);

typedef OepMergeConflictKindToStringDart = Pointer<Utf8> Function(int kind);
typedef OepMergeConflictListReleaseDart = void Function(Pointer<OepMergeConflictListNative> list);
typedef OepRepositoryPlanMergeDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepMergePlanNative> outPlan,
  Pointer<OepMergeConflictListNative> outConflicts,
);
typedef OepRepositoryExecuteMergeDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> archivePath,
  Pointer<OepMergeResultNative> outResult,
);

// --- Engineering Knowledge Runtime (WP-EKE-001) ---

typedef OepEngineLoadObjectDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepObjectInfoNative> outObject,
  Pointer<Int32> outFound,
);
typedef OepEngineLoadGraphDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outObjectsLoaded,
  Pointer<Int32> outRelationshipsLoaded,
);
typedef OepEngineQueryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineQueryRequestNative> request,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
  Pointer<Int32> outPathExists,
);
typedef OepEngineTraverseDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> startObjectId,
  int order,
  int hasRelationshipFilter,
  int relationshipFilter,
  int hasMaxDepth,
  int maxDepth,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEngineRelatedObjectsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEngineDependencyGraphDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
);

// --- Engineering Knowledge Graph Engine (WP-EKE-002) ---

typedef OepKgeBuildGraphDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outObjects,
  Pointer<Int32> outRelationships,
);
typedef OepKgeRefreshGraphDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outObjects,
  Pointer<Int32> outRelationships,
);
typedef OepGraphIssueKindToStringDart = Pointer<Utf8> Function(int kind);
typedef OepGraphIssueListReleaseDart = void Function(Pointer<OepGraphIssueListNative> list);
typedef OepKgeValidateGraphDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outValid,
  Pointer<OepGraphIssueListNative> outIssues,
);
typedef OepKgeGraphStatisticsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepGraphStatisticsNative> outStats,
);
typedef OepComponentMembershipListReleaseDart = void Function(Pointer<OepComponentMembershipListNative> list);
typedef OepKgeConnectedComponentsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepComponentMembershipListNative> outComponents,
  Pointer<Int32> outCount,
);
typedef OepKgeShortestPathDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceId,
  Pointer<Utf8> targetId,
  Pointer<Int32> outPathExists,
  Pointer<OepPackageIdListNative> outPath,
);
typedef OepKgeSubgraphDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Pointer<Utf8>> objectIds,
  int objectIdCount,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
);
typedef OepStringReleaseDart = void Function(Pointer<Pointer<Utf8>> text);
typedef OepKgeExportJsonDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Pointer<Utf8>> outText,
  Pointer<Size> outLength,
);
typedef OepKgeExportGraphmlPlaceholderDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Pointer<Utf8>> outText,
  Pointer<Size> outLength,
);

// --- Engineering Query Engine (WP-EKE-003) ---

typedef OepQueryCategoryToStringDart = Pointer<Utf8> Function(int category);
typedef OepEqePlanQueryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepQueryRequestNative> request,
  Pointer<OepQueryPlanNative> outPlan,
  Pointer<OepPackageIdListNative> outIndexesUsed,
  Pointer<OepPackageIdListNative> outExecutionOrder,
);
typedef OepEqeExecuteQueryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepQueryRequestNative> request,
  Pointer<OepQueryResultSummaryNative> outSummary,
  Pointer<OepPackageIdListNative> outObjectIds,
  Pointer<OepPackageIdListNative> outRelationshipIds,
);
typedef OepEqeQueryStatisticsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepQueryResultSummaryNative> outStats,
);
typedef OepEqeClearQueryCacheDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepEqeQueryCacheInfoDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outPlanCount,
  Pointer<Int32> outResultCount,
);

// --- Engineering Rules Engine (WP-EKE-004) ---

typedef OepRuleCategoryToStringDart = Pointer<Utf8> Function(int category);
typedef OepRuleSeverityToStringDart = Pointer<Utf8> Function(int severity);
typedef OepRuleScopeKindToStringDart = Pointer<Utf8> Function(int kind);
typedef OepRuleConditionKindToStringDart = Pointer<Utf8> Function(int kind);
typedef OepRuleEvaluationStatusToStringDart = Pointer<Utf8> Function(int status);
typedef OepRuleConditionListReleaseDart = void Function(Pointer<OepRuleConditionListNative> list);
typedef OepRuleDiagnosticListReleaseDart = void Function(Pointer<OepRuleDiagnosticListNative> list);
typedef OepRuleEvaluationSummaryListReleaseDart = void Function(
  Pointer<OepRuleEvaluationSummaryListNative> list,
);
typedef OepRulesRegisterDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineeringRuleNative> rule,
);
typedef OepRulesRemoveDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> ruleId);
typedef OepRulesEnableDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> ruleId);
typedef OepRulesDisableDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> ruleId);
typedef OepRulesListAllDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outRuleIds,
);
typedef OepRulesListEnabledDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outRuleIds,
);
typedef OepRulesListDisabledDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outRuleIds,
);
typedef OepRulesGetDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> ruleId,
  Pointer<OepEngineeringRuleNative> outRule,
  Pointer<OepRuleConditionListNative> outConditions,
  Pointer<Int32> outFound,
);
typedef OepRulesEvaluateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> ruleId,
  Pointer<OepRuleEvaluationResultNative> outResult,
  Pointer<OepPackageIdListNative> outAffectedObjects,
  Pointer<OepRuleDiagnosticListNative> outDiagnostics,
);
typedef OepRulesEvaluateAllDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRuleEvaluationSummaryListNative> outSummaries,
);

// --- Engineering Validation Engine (WP-EKE-005) ---

typedef OepValidationProfileToStringDart = Pointer<Utf8> Function(int profile);
typedef OepValidationFindingListReleaseDart = void Function(Pointer<OepValidationFindingListNative> list);
typedef OepValidationCreateSessionDart = OepResultNative Function(
  Pointer<Void> runtime,
  int profile,
  Pointer<Utf8> outSessionId,
  int sessionIdBufferSize,
);
typedef OepValidationValidateObjectDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationValidateObjectsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Pointer<Utf8>> objectIds,
  int objectIdCount,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationValidateContextDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationValidatePackageDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> packageId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationReportDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepValidationReportSummaryNative> outSummary,
  Pointer<OepValidationFindingListNative> outFindings,
);
typedef OepValidationStatisticsFnDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepValidationStatisticsNative> outStats,
);

// --- Engineering Analysis & Reasoning Engine (WP-EKE-006) ---

typedef OepAnalysisDependenciesDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Int32> outMaxDepth,
  Pointer<OepPackageIdListNative> outDependencyObjectIds,
  Pointer<OepPackageIdListNative> outDependencyRelationshipIds,
  Pointer<Utf8> outEvidence,
);
typedef OepAnalysisImpactDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<Int32> outMaxDepth,
  Pointer<OepPackageIdListNative> outAffectedObjectIds,
  Pointer<OepPackageIdListNative> outAffectedRelationshipIds,
  Pointer<Utf8> outEvidence,
);
typedef OepAnalysisReachabilityDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceId,
  Pointer<Utf8> targetId,
  Pointer<Int32> outReachable,
  Pointer<OepPackageIdListNative> outPath,
  Pointer<Utf8> outEvidence,
);
typedef OepAnalysisRootCauseDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> symptomObjectId,
  Pointer<OepPackageIdListNative> outCandidateRootCauses,
  Pointer<OepPackageIdListNative> outFailureChain,
  Pointer<Utf8> outEvidence,
);
typedef OepReasoningCreateSessionDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objective,
  Pointer<Pointer<Utf8>> startingObjectIds,
  int startingObjectIdCount,
  Pointer<Utf8> outSessionId,
  int sessionIdBufferSize,
);
typedef OepReasoningExecuteDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepReasoningSummaryNative> outSummary,
  Pointer<OepPackageIdListNative> outConclusionIds,
  Pointer<OepPackageIdListNative> outRecommendationIds,
);
typedef OepReasoningReportDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepReasoningSummaryNative> outSummary,
  Pointer<OepPackageIdListNative> outConclusionIds,
  Pointer<OepPackageIdListNative> outRecommendationIds,
);
typedef OepReasoningRecommendationsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepPackageIdListNative> outRecommendationIds,
);
typedef OepReasoningGetConclusionDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> conclusionId,
  Pointer<OepConclusionNative> outConclusion,
  Pointer<OepPackageIdListNative> outSupportingEvidenceIds,
  Pointer<OepPackageIdListNative> outReferencedObjects,
  Pointer<OepPackageIdListNative> outReferencedRules,
  Pointer<OepPackageIdListNative> outReferencedFindings,
);
typedef OepRecommendationKindToStringDart = Pointer<Utf8> Function(int kind);
typedef OepReasoningGetRecommendationDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> recommendationId,
  Pointer<OepRecommendationNative> outRecommendation,
  Pointer<OepPackageIdListNative> outSupportingEvidenceIds,
);
typedef OepReasoningGetEvidenceNodeDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> evidenceId,
  Pointer<OepEvidenceNodeNative> outNode,
);

// --- Engineering Intelligence Platform (WP-EKE-007) ---

typedef OepWorkflowKindToStringDart = Pointer<Utf8> Function(int kind);
typedef OepInspectionTargetKindToStringDart = Pointer<Utf8> Function(int kind);
typedef OepEipCreateSessionDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> outSessionId,
  int sessionIdBufferSize,
);
typedef OepEipResumeSessionDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> sessionId);
typedef OepEipCloneSessionDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> outSessionId,
  int sessionIdBufferSize,
);
typedef OepEipCloseSessionDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> sessionId);
typedef OepEipSwitchSessionDart = OepResultNative Function(Pointer<Void> runtime, Pointer<Utf8> sessionId);
typedef OepEipListSessionsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepPackageIdListNative> outSessionIds,
);
typedef OepEipGetSessionDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<OepKnowledgeSessionSummaryNative> outSession,
);
typedef OepEipExportSessionSummaryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Pointer<Utf8>> outSummary,
  Pointer<Size> outLength,
);
typedef OepEipQueryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  int category,
  Pointer<Utf8> primaryObjectId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipInspectDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  int kind,
  Pointer<Utf8> targetId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipValidateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  int profile,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipAnalyzeDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipReasonDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objective,
  Pointer<Pointer<Utf8>> startingObjectIds,
  int startingObjectIdCount,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipRecommendDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sessionId,
  Pointer<Utf8> objectId,
  Pointer<OepWorkflowResultNative> outResult,
  Pointer<OepPackageIdListNative> outObjectIds,
);
typedef OepEipEngineeringSummaryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineeringSummaryReportNative> outSummary,
);
typedef OepEipEngineeringHealthDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepEngineeringHealthReportNative> outHealth,
);
typedef OepEipEngineeringRecommendationsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepPackageIdListNative> outRecommendationMessages,
);
typedef OepEipRuntimeMetricsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRuntimeMetricsNative> outMetrics,
);
typedef OepEipInvalidateCachesDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepEipCleanupDart = OepResultNative Function(Pointer<Void> runtime);
