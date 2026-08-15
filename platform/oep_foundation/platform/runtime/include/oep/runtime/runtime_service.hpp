#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

namespace oep::runtime {

// RuntimeService (WP-REP-006) is an orchestration-only layer in front
// of FoundationRuntime. It introduces two things that did not exist
// before this work package:
//
//   1. Immutable Request/Response types for the Runtime's mutating and
//      orchestrated operations (install, object/relationship mutation,
//      transactions, dependency resolution), replacing bare positional
//      arguments with a named, cannot-change-after-construction value.
//   2. Repository Events: after each sequenced call to FoundationRuntime
//      completes, RuntimeService publishes one RepositoryEvent to the
//      EventBus supplied via RuntimeContext, recording what happened.
//
// RuntimeService owns SEQUENCING ONLY. It does not reimplement, move,
// or duplicate any business logic that already lives in
// FoundationRuntime, the Repository Transaction Engine, the Trust
// Store, the Repository Registry, or the Dependency Resolution Engine
// — every method below is a direct, single call into the corresponding
// FoundationRuntime method, whose own doc comments remain the
// authoritative description of *what* happens (trust verification
// before dependency resolution before transaction creation, rollback
// semantics, etc.). RuntimeService only decides *that* the call
// happens and *what gets published afterward* — it is the seam future
// work packages will extend (event subscribers, cross-cutting
// concerns) without touching FoundationRuntime or its subsystems.
//
// Every RuntimeService method requires whatever FoundationRuntime's
// corresponding method requires (most need an open repository); this
// is not re-validated here; FoundationRuntime's existing error
// messages flow through unchanged in Response::error.
class RuntimeService {
public:
    explicit RuntimeService(RuntimeContext context) : context_(context) {}

    // ---------------------------------------------------------------
    // Package Installation (WP-REP-001/003/004/005, sequenced here since
    // WP-REP-006)
    // ---------------------------------------------------------------

    struct InstallPackageRequest {
        explicit InstallPackageRequest(std::filesystem::path archive_path) : archive_path(std::move(archive_path)) {}
        const std::filesystem::path archive_path;
    };

    struct InstallPackageResponse {
        InstallPackageResponse(bool success, std::string error, std::string package_id, std::string version,
                                int objects_created, int relationships_created, std::string trust_status)
            : success(success),
              error(std::move(error)),
              package_id(std::move(package_id)),
              version(std::move(version)),
              objects_created(objects_created),
              relationships_created(relationships_created),
              trust_status(std::move(trust_status)) {}

        const bool success;
        const std::string error;
        const std::string package_id;
        const std::string version;
        const int objects_created;
        const int relationships_created;
        const std::string trust_status;
    };

    // Sequences: FoundationRuntime::install_package, then publishes
    // PackageInstalled on success or PackageInstallFailed on failure.
    InstallPackageResponse install_package(const InstallPackageRequest& request);

    // ---------------------------------------------------------------
    // Dependency Resolution (WP-REP-005, sequenced here since WP-REP-006)
    // ---------------------------------------------------------------

    struct ResolveDependenciesRequest {
        explicit ResolveDependenciesRequest(std::filesystem::path archive_path) : archive_path(std::move(archive_path)) {}
        const std::filesystem::path archive_path;
    };

    struct ResolveDependenciesResponse {
        ResolveDependenciesResponse(bool success, std::string error, oep::installer::DependencyResolutionReport report)
            : success(success), error(std::move(error)), report(std::move(report)) {}

        const bool success;
        const std::string error;
        const oep::installer::DependencyResolutionReport report;
    };

    // Sequences: FoundationRuntime::resolve_package_dependencies, then
    // publishes DependencyResolutionCompleted. This call never mutates
    // the repository (see FoundationRuntime's own doc comment).
    ResolveDependenciesResponse resolve_dependencies(const ResolveDependenciesRequest& request);

    // ---------------------------------------------------------------
    // Package Uninstall (WP-REP-007)
    // ---------------------------------------------------------------
    //
    // WP-REP-007 requirement: "All lifecycle operations execute
    // exclusively through RuntimeService." Uninstall and Update are new
    // lifecycle operations introduced by this Work Package; unlike
    // install_package (still directly callable on FoundationRuntime as
    // well, for backward compatibility per WP-REP-006), the intended
    // entry point for uninstall/update going forward is exclusively
    // through RuntimeService. FoundationRuntime::uninstall_package/
    // update_package still hold 100% of the actual logic (WP-REP-007
    // requirement: do not move business logic) — RuntimeService again
    // sequences one call plus one event publication.

    struct AnalyzeUninstallImpactRequest {
        explicit AnalyzeUninstallImpactRequest(std::string package_id) : package_id(std::move(package_id)) {}
        const std::string package_id;
    };

    // Immutable Impact Report (WP-REP-007 requirement #6): every field
    // is set at construction; there are no setters.
    struct UninstallImpactReport {
        UninstallImpactReport(bool success, std::string error, bool found, int objects_affected,
                               int relationships_affected, std::vector<std::string> blocking_dependents,
                               bool removable)
            : success(success),
              error(std::move(error)),
              found(found),
              objects_affected(objects_affected),
              relationships_affected(relationships_affected),
              blocking_dependents(std::move(blocking_dependents)),
              removable(removable) {}

        const bool success;
        const std::string error;
        const bool found;
        const int objects_affected;
        const int relationships_affected;
        const std::vector<std::string> blocking_dependents;
        const bool removable;
    };

    // Sequences: FoundationRuntime::analyze_uninstall_impact. Read-only;
    // publishes no event (nothing changed).
    UninstallImpactReport analyze_uninstall_impact(const AnalyzeUninstallImpactRequest& request);

    struct UninstallPackageRequest {
        explicit UninstallPackageRequest(std::string package_id) : package_id(std::move(package_id)) {}
        const std::string package_id;
    };

    struct UninstallPackageResponse {
        UninstallPackageResponse(bool success, std::string error, std::string package_id, int objects_removed,
                                  int relationships_removed)
            : success(success),
              error(std::move(error)),
              package_id(std::move(package_id)),
              objects_removed(objects_removed),
              relationships_removed(relationships_removed) {}

        const bool success;
        const std::string error;
        const std::string package_id;
        const int objects_removed;
        const int relationships_removed;
    };

    // Sequences: FoundationRuntime::uninstall_package, then publishes
    // PackageUninstalled on success (nothing on failure, matching
    // install_package's PackageInstallFailed asymmetry — a failed
    // uninstall changes nothing, so nothing is recorded as failed
    // either; the caller's Response::error is authoritative).
    UninstallPackageResponse uninstall_package(const UninstallPackageRequest& request);

    // ---------------------------------------------------------------
    // Package Update (WP-REP-007)
    // ---------------------------------------------------------------

    struct AnalyzeUpdateImpactRequest {
        explicit AnalyzeUpdateImpactRequest(std::filesystem::path archive_path) : archive_path(std::move(archive_path)) {}
        const std::filesystem::path archive_path;
    };

    // Immutable Impact Report (WP-REP-007 requirement #6).
    struct UpdateImpactReport {
        UpdateImpactReport(bool success, std::string error, bool currently_installed, std::string current_version,
                            std::string candidate_version, std::string trust_status,
                            oep::installer::DependencyResolutionReport dependency_report,
                            std::vector<std::string> broken_dependents, bool updatable)
            : success(success),
              error(std::move(error)),
              currently_installed(currently_installed),
              current_version(std::move(current_version)),
              candidate_version(std::move(candidate_version)),
              trust_status(std::move(trust_status)),
              dependency_report(std::move(dependency_report)),
              broken_dependents(std::move(broken_dependents)),
              updatable(updatable) {}

        const bool success;
        const std::string error;
        const bool currently_installed;
        const std::string current_version;
        const std::string candidate_version;
        const std::string trust_status;
        const oep::installer::DependencyResolutionReport dependency_report;
        const std::vector<std::string> broken_dependents;
        const bool updatable;
    };

    // Sequences: FoundationRuntime::analyze_update_impact. Read-only;
    // publishes no event.
    UpdateImpactReport analyze_update_impact(const AnalyzeUpdateImpactRequest& request);

    struct UpdatePackageRequest {
        explicit UpdatePackageRequest(std::filesystem::path archive_path) : archive_path(std::move(archive_path)) {}
        const std::filesystem::path archive_path;
    };

    struct UpdatePackageResponse {
        UpdatePackageResponse(bool success, std::string error, std::string package_id, std::string previous_version,
                               std::string new_version, int objects_removed, int relationships_removed,
                               int objects_created, int relationships_created, std::string trust_status)
            : success(success),
              error(std::move(error)),
              package_id(std::move(package_id)),
              previous_version(std::move(previous_version)),
              new_version(std::move(new_version)),
              objects_removed(objects_removed),
              relationships_removed(relationships_removed),
              objects_created(objects_created),
              relationships_created(relationships_created),
              trust_status(std::move(trust_status)) {}

        const bool success;
        const std::string error;
        const std::string package_id;
        const std::string previous_version;
        const std::string new_version;
        const int objects_removed;
        const int relationships_removed;
        const int objects_created;
        const int relationships_created;
        const std::string trust_status;
    };

    // Sequences: FoundationRuntime::update_package, then publishes
    // PackageUpdated on success.
    UpdatePackageResponse update_package(const UpdatePackageRequest& request);

    // ---------------------------------------------------------------
    // Repository Reads (WP-EKE-001)
    // ---------------------------------------------------------------
    //
    // Read-only accessors over the currently open repository's Object/
    // Relationship stores, added so external consumers that must
    // "operate exclusively through RuntimeService" (per WP-EKE-001's
    // architectural constraint on the Engineering Knowledge Runtime,
    // platform/oep_engine) never need FoundationRuntime::object_store()/
    // relationship_store() directly. These simply call through to
    // FoundationRuntime's own already-public accessors — no storage
    // logic is duplicated here, and no new storage capability is
    // introduced; this is a read-only sequencing wrapper, exactly like
    // every other RuntimeService method. Publishes no event (read-only).

    struct GetObjectRequest {
        explicit GetObjectRequest(std::string object_id) : object_id(std::move(object_id)) {}
        const std::string object_id;
    };

    struct GetObjectResponse {
        GetObjectResponse(bool success, std::string error, bool found, oep::repository::EngineeringObject object)
            : success(success), error(std::move(error)), found(found), object(std::move(object)) {}

        const bool success;
        const std::string error;
        const bool found;
        const oep::repository::EngineeringObject object;
    };

    GetObjectResponse get_object(const GetObjectRequest& request);

    struct ListObjectsResponse {
        ListObjectsResponse(bool success, std::string error, std::vector<oep::repository::EngineeringObject> objects)
            : success(success), error(std::move(error)), objects(std::move(objects)) {}

        const bool success;
        const std::string error;
        const std::vector<oep::repository::EngineeringObject> objects;
    };

    ListObjectsResponse list_objects();

    struct ListRelationshipsResponse {
        ListRelationshipsResponse(bool success, std::string error, std::vector<oep::repository::Relationship> relationships)
            : success(success), error(std::move(error)), relationships(std::move(relationships)) {}

        const bool success;
        const std::string error;
        const std::vector<oep::repository::Relationship> relationships;
    };

    ListRelationshipsResponse list_relationships();

    // Package ownership lookup (reused by WP-EKE-002's Knowledge Graph
    // Engine to index objects by publisher/package without ever
    // touching the Repository Registry directly -- it only ever holds
    // an EngineeringContext, which in turn only ever holds a
    // RuntimeService). Pass-through to
    // FoundationRuntime::find_package_owner.
    struct FindPackageOwnerRequest {
        explicit FindPackageOwnerRequest(std::string entity_id) : entity_id(std::move(entity_id)) {}
        const std::string entity_id;
    };

    struct FindPackageOwnerResponse {
        FindPackageOwnerResponse(bool success, std::string error, oep::installer::OwnedEntityKind kind,
                                  oep::installer::RepositoryRegistryEntry owner)
            : success(success), error(std::move(error)), kind(kind), owner(std::move(owner)) {}

        const bool success;
        const std::string error;
        const oep::installer::OwnedEntityKind kind;
        const oep::installer::RepositoryRegistryEntry owner; // meaningful only when kind != None
    };

    FindPackageOwnerResponse find_package_owner(const FindPackageOwnerRequest& request);

    // ---------------------------------------------------------------
    // Merge Engine (WP-REP-008)
    // ---------------------------------------------------------------
    //
    // Like Uninstall/Update (WP-REP-007), Merge is RuntimeService-only
    // by design (WP-REP-008 requirement #1: "operate exclusively
    // through RuntimeService") — the C API and CLI call these methods,
    // never FoundationRuntime::plan_merge/execute_merge directly. All
    // business logic (planning, conflict detection, Trust/Dependency
    // sequencing, transactional application) remains entirely in
    // FoundationRuntime and oep::installer::plan_merge; RuntimeService
    // sequences one call plus, for execute_merge, one event publication.

    struct PlanMergeRequest {
        explicit PlanMergeRequest(std::filesystem::path archive_path) : archive_path(std::move(archive_path)) {}
        const std::filesystem::path archive_path;
    };

    // Immutable Report (mirrors WP-REP-007's Impact Reports): every
    // field set at construction, no setters.
    struct MergePlanReport {
        MergePlanReport(bool success, std::string error, std::string package_id, std::string version,
                         std::string trust_status, bool trust_blocks,
                         oep::installer::DependencyResolutionReport dependency_report, bool dependency_blocks,
                         bool already_registered, oep::installer::MergePlan plan, bool mergeable)
            : success(success),
              error(std::move(error)),
              package_id(std::move(package_id)),
              version(std::move(version)),
              trust_status(std::move(trust_status)),
              trust_blocks(trust_blocks),
              dependency_report(std::move(dependency_report)),
              dependency_blocks(dependency_blocks),
              already_registered(already_registered),
              plan(std::move(plan)),
              mergeable(mergeable) {}

        const bool success;
        const std::string error;
        const std::string package_id;
        const std::string version;
        const std::string trust_status;
        const bool trust_blocks;
        const oep::installer::DependencyResolutionReport dependency_report;
        const bool dependency_blocks;
        const bool already_registered;
        const oep::installer::MergePlan plan;
        const bool mergeable;
    };

    // Sequences: FoundationRuntime::plan_merge. Read-only; publishes no
    // event (nothing changed — WP-REP-008 requirement #6).
    MergePlanReport plan_merge(const PlanMergeRequest& request);

    struct ExecuteMergeRequest {
        explicit ExecuteMergeRequest(std::filesystem::path archive_path) : archive_path(std::move(archive_path)) {}
        const std::filesystem::path archive_path;
    };

    struct ExecuteMergeResponse {
        ExecuteMergeResponse(bool success, std::string error, std::string package_id, std::string version,
                              int objects_created, int relationships_created, std::string trust_status)
            : success(success),
              error(std::move(error)),
              package_id(std::move(package_id)),
              version(std::move(version)),
              objects_created(objects_created),
              relationships_created(relationships_created),
              trust_status(std::move(trust_status)) {}

        const bool success;
        const std::string error;
        const std::string package_id;
        const std::string version;
        const int objects_created;
        const int relationships_created;
        const std::string trust_status;
    };

    // Sequences: FoundationRuntime::execute_merge, then publishes
    // RepositoryMerged on success.
    ExecuteMergeResponse execute_merge(const ExecuteMergeRequest& request);

    // ---------------------------------------------------------------
    // Object Mutation (Work Package 014, sequenced here since WP-REP-006)
    // ---------------------------------------------------------------

    struct CreateObjectRequest {
        CreateObjectRequest(oep::repository::ObjectType object_type, std::string name, std::string description,
                             std::string author, std::vector<std::string> tags)
            : object_type(object_type),
              name(std::move(name)),
              description(std::move(description)),
              author(std::move(author)),
              tags(std::move(tags)) {}

        const oep::repository::ObjectType object_type;
        const std::string name;
        const std::string description;
        const std::string author;
        const std::vector<std::string> tags;
    };

    struct UpdateObjectRequest {
        UpdateObjectRequest(std::string object_id, std::string name, std::string description, std::string author,
                             std::vector<std::string> tags)
            : object_id(std::move(object_id)),
              name(std::move(name)),
              description(std::move(description)),
              author(std::move(author)),
              tags(std::move(tags)) {}

        const std::string object_id;
        const std::string name;
        const std::string description;
        const std::string author;
        const std::vector<std::string> tags;
    };

    // AP-DS-002. See FoundationRuntime::update_object_content for why
    // this is a dedicated request type rather than an optional field on
    // UpdateObjectRequest.
    struct UpdateObjectContentRequest {
        UpdateObjectContentRequest(std::string object_id, std::string content)
            : object_id(std::move(object_id)), content(std::move(content)) {}
        const std::string object_id;
        const std::string content;
    };

    struct DeleteObjectRequest {
        explicit DeleteObjectRequest(std::string object_id) : object_id(std::move(object_id)) {}
        const std::string object_id;
    };

    struct ObjectMutationResponse {
        ObjectMutationResponse(bool success, std::string error, oep::repository::EngineeringObject object)
            : success(success), error(std::move(error)), object(std::move(object)) {}

        const bool success;
        const std::string error;
        const oep::repository::EngineeringObject object;
    };

    struct DeleteResponse {
        DeleteResponse(bool success, std::string error) : success(success), error(std::move(error)) {}
        const bool success;
        const std::string error;
    };

    // Sequences: FoundationRuntime::create_object, then publishes
    // ObjectCreated on success.
    ObjectMutationResponse create_object(const CreateObjectRequest& request);

    // Sequences: FoundationRuntime::update_object, then publishes
    // ObjectUpdated on success.
    ObjectMutationResponse update_object(const UpdateObjectRequest& request);

    // Sequences: FoundationRuntime::update_object_content, then publishes
    // ObjectUpdated on success. AP-DS-002.
    ObjectMutationResponse update_object_content(const UpdateObjectContentRequest& request);

    // Sequences: FoundationRuntime::delete_object, then publishes
    // ObjectDeleted on success.
    DeleteResponse delete_object(const DeleteObjectRequest& request);

    // ---------------------------------------------------------------
    // Relationship Mutation (Work Package 014, sequenced here since
    // WP-REP-006)
    // ---------------------------------------------------------------

    struct CreateRelationshipRequest {
        CreateRelationshipRequest(std::string source_object_id, std::string target_object_id,
                                   oep::repository::RelationshipType relationship_type, std::string author,
                                   std::string description)
            : source_object_id(std::move(source_object_id)),
              target_object_id(std::move(target_object_id)),
              relationship_type(relationship_type),
              author(std::move(author)),
              description(std::move(description)) {}

        const std::string source_object_id;
        const std::string target_object_id;
        const oep::repository::RelationshipType relationship_type;
        const std::string author;
        const std::string description;
    };

    struct UpdateRelationshipRequest {
        UpdateRelationshipRequest(std::string relationship_id, std::string author, std::string description)
            : relationship_id(std::move(relationship_id)), author(std::move(author)), description(std::move(description)) {}

        const std::string relationship_id;
        const std::string author;
        const std::string description;
    };

    struct DeleteRelationshipRequest {
        explicit DeleteRelationshipRequest(std::string relationship_id) : relationship_id(std::move(relationship_id)) {}
        const std::string relationship_id;
    };

    struct RelationshipMutationResponse {
        RelationshipMutationResponse(bool success, std::string error, oep::repository::Relationship relationship)
            : success(success), error(std::move(error)), relationship(std::move(relationship)) {}

        const bool success;
        const std::string error;
        const oep::repository::Relationship relationship;
    };

    // Sequences: FoundationRuntime::create_relationship, then publishes
    // RelationshipCreated on success.
    RelationshipMutationResponse create_relationship(const CreateRelationshipRequest& request);

    // Sequences: FoundationRuntime::update_relationship, then publishes
    // RelationshipUpdated on success.
    RelationshipMutationResponse update_relationship(const UpdateRelationshipRequest& request);

    // Sequences: FoundationRuntime::delete_relationship, then publishes
    // RelationshipDeleted on success.
    DeleteResponse delete_relationship(const DeleteRelationshipRequest& request);

    // ---------------------------------------------------------------
    // Transactions (Work Package 014 / WP-REP-003, sequenced here since
    // WP-REP-006)
    // ---------------------------------------------------------------

    struct TransactionResponse {
        TransactionResponse(bool success, std::string error) : success(success), error(std::move(error)) {}
        const bool success;
        const std::string error;
    };

    // Sequences: FoundationRuntime::begin_transaction, then publishes
    // TransactionBegun on success.
    TransactionResponse begin_transaction();

    // Sequences: FoundationRuntime::commit_transaction, then publishes
    // TransactionCommitted on success.
    TransactionResponse commit_transaction();

    // Sequences: FoundationRuntime::rollback_transaction, then
    // publishes TransactionRolledBack on success.
    TransactionResponse rollback_transaction();

    // Direct, unsequenced accessor — exposed for callers (the CLI,
    // Public C API) that need to inspect the EventBus RuntimeService is
    // publishing to, e.g. for diagnostics. Not itself an orchestrated
    // operation.
    const EventBus& events() const { return context_.events(); }

private:
    RuntimeContext context_;
};

} // namespace oep::runtime
