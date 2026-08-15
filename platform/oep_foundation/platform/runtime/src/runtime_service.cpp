#include "oep/runtime/runtime_service.hpp"

namespace oep::runtime {

RuntimeService::InstallPackageResponse RuntimeService::install_package(const InstallPackageRequest& request) {
    const RuntimeInstallResult result = context_.runtime().install_package(request.archive_path);
    if (result.success) {
        context_.events().publish(EventType::PackageInstalled, result.package_id,
                                   "version " + result.version + ", trust " + result.trust_status);
    } else {
        context_.events().publish(EventType::PackageInstallFailed, request.archive_path.string(), result.error);
    }
    return InstallPackageResponse(result.success, result.error, result.package_id, result.version,
                                   result.objects_created, result.relationships_created, result.trust_status);
}

RuntimeService::ResolveDependenciesResponse RuntimeService::resolve_dependencies(const ResolveDependenciesRequest& request) {
    const RuntimeDependencyResolutionResult result = context_.runtime().resolve_package_dependencies(request.archive_path);
    if (result.success) {
        context_.events().publish(EventType::DependencyResolutionCompleted, result.report.candidate_package_id,
                                   oep::installer::to_string(result.report.result));
    }
    return ResolveDependenciesResponse(result.success, result.error, result.report);
}

RuntimeService::UninstallImpactReport RuntimeService::analyze_uninstall_impact(const AnalyzeUninstallImpactRequest& request) {
    const RuntimeUninstallImpactResult result = context_.runtime().analyze_uninstall_impact(request.package_id);
    return UninstallImpactReport(result.success, result.error, result.found, result.objects_affected,
                                  result.relationships_affected, result.blocking_dependents, result.removable);
}

RuntimeService::UninstallPackageResponse RuntimeService::uninstall_package(const UninstallPackageRequest& request) {
    const RuntimeUninstallResult result = context_.runtime().uninstall_package(request.package_id);
    if (result.success) {
        context_.events().publish(EventType::PackageUninstalled, result.package_id,
                                   "objects " + std::to_string(result.objects_removed) + ", relationships " +
                                       std::to_string(result.relationships_removed));
    }
    return UninstallPackageResponse(result.success, result.error, result.package_id, result.objects_removed,
                                     result.relationships_removed);
}

RuntimeService::UpdateImpactReport RuntimeService::analyze_update_impact(const AnalyzeUpdateImpactRequest& request) {
    const RuntimeUpdateImpactResult result = context_.runtime().analyze_update_impact(request.archive_path);
    return UpdateImpactReport(result.success, result.error, result.currently_installed, result.current_version,
                               result.candidate_version, result.trust_status, result.dependency_report,
                               result.broken_dependents, result.updatable);
}

RuntimeService::UpdatePackageResponse RuntimeService::update_package(const UpdatePackageRequest& request) {
    const RuntimeUpdateResult result = context_.runtime().update_package(request.archive_path);
    if (result.success) {
        context_.events().publish(EventType::PackageUpdated, result.package_id,
                                   result.previous_version + " -> " + result.new_version);
    }
    return UpdatePackageResponse(result.success, result.error, result.package_id, result.previous_version,
                                  result.new_version, result.objects_removed, result.relationships_removed,
                                  result.objects_created, result.relationships_created, result.trust_status);
}

RuntimeService::GetObjectResponse RuntimeService::get_object(const GetObjectRequest& request) {
    const oep::repository::ObjectStore* store = context_.runtime().object_store();
    if (store == nullptr) {
        return GetObjectResponse(false, "no repository is currently open", false, {});
    }
    const oep::repository::LoadObjectResult loaded = store->load(request.object_id);
    if (!loaded.success) {
        return GetObjectResponse(true, "", false, {});
    }
    return GetObjectResponse(true, "", true, loaded.object);
}

RuntimeService::ListObjectsResponse RuntimeService::list_objects() {
    const oep::repository::ObjectStore* store = context_.runtime().object_store();
    if (store == nullptr) {
        return ListObjectsResponse(false, "no repository is currently open", {});
    }
    const oep::repository::ListObjectsResult listed = store->list_all();
    return ListObjectsResponse(listed.success, listed.error, listed.objects);
}

RuntimeService::ListRelationshipsResponse RuntimeService::list_relationships() {
    const oep::repository::RelationshipStore* store = context_.runtime().relationship_store();
    if (store == nullptr) {
        return ListRelationshipsResponse(false, "no repository is currently open", {});
    }
    const oep::repository::ListRelationshipsResult listed = store->list_all();
    return ListRelationshipsResponse(listed.success, listed.error, listed.relationships);
}

RuntimeService::FindPackageOwnerResponse RuntimeService::find_package_owner(const FindPackageOwnerRequest& request) {
    const RuntimePackageOwnerResult result = context_.runtime().find_package_owner(request.entity_id);
    return FindPackageOwnerResponse(result.success, result.error, result.kind, result.owner);
}

RuntimeService::MergePlanReport RuntimeService::plan_merge(const PlanMergeRequest& request) {
    const RuntimeMergePlanResult result = context_.runtime().plan_merge(request.archive_path);
    return MergePlanReport(result.success, result.error, result.package_id, result.version, result.trust_status,
                            result.trust_blocks, result.dependency_report, result.dependency_blocks,
                            result.already_registered, result.plan, result.mergeable);
}

RuntimeService::ExecuteMergeResponse RuntimeService::execute_merge(const ExecuteMergeRequest& request) {
    const RuntimeMergeResult result = context_.runtime().execute_merge(request.archive_path);
    if (result.success) {
        context_.events().publish(EventType::RepositoryMerged, result.package_id,
                                   "objects " + std::to_string(result.objects_created) + ", relationships " +
                                       std::to_string(result.relationships_created));
    }
    return ExecuteMergeResponse(result.success, result.error, result.package_id, result.version,
                                 result.objects_created, result.relationships_created, result.trust_status);
}

RuntimeService::ObjectMutationResponse RuntimeService::create_object(const CreateObjectRequest& request) {
    const RuntimeObjectMutationResult result =
        context_.runtime().create_object(request.object_type, request.name, request.description, request.author, request.tags);
    if (result.success) {
        context_.events().publish(EventType::ObjectCreated, result.object.object_id, result.object.name);
    }
    return ObjectMutationResponse(result.success, result.error, result.object);
}

RuntimeService::ObjectMutationResponse RuntimeService::update_object(const UpdateObjectRequest& request) {
    const RuntimeObjectMutationResult result = context_.runtime().update_object(
        request.object_id, request.name, request.description, request.author, request.tags);
    if (result.success) {
        context_.events().publish(EventType::ObjectUpdated, result.object.object_id, result.object.name);
    }
    return ObjectMutationResponse(result.success, result.error, result.object);
}

RuntimeService::ObjectMutationResponse RuntimeService::update_object_content(const UpdateObjectContentRequest& request) {
    const RuntimeObjectMutationResult result = context_.runtime().update_object_content(request.object_id, request.content);
    if (result.success) {
        context_.events().publish(EventType::ObjectUpdated, result.object.object_id, result.object.name);
    }
    return ObjectMutationResponse(result.success, result.error, result.object);
}

RuntimeService::DeleteResponse RuntimeService::delete_object(const DeleteObjectRequest& request) {
    const RuntimeResult result = context_.runtime().delete_object(request.object_id);
    if (result.success) {
        context_.events().publish(EventType::ObjectDeleted, request.object_id, "");
    }
    return DeleteResponse(result.success, result.error);
}

RuntimeService::RelationshipMutationResponse RuntimeService::create_relationship(const CreateRelationshipRequest& request) {
    const RuntimeRelationshipMutationResult result = context_.runtime().create_relationship(
        request.source_object_id, request.target_object_id, request.relationship_type, request.author, request.description);
    if (result.success) {
        context_.events().publish(EventType::RelationshipCreated, result.relationship.relationship_id,
                                   result.relationship.source_object_id + " -> " + result.relationship.target_object_id);
    }
    return RelationshipMutationResponse(result.success, result.error, result.relationship);
}

RuntimeService::RelationshipMutationResponse RuntimeService::update_relationship(const UpdateRelationshipRequest& request) {
    const RuntimeRelationshipMutationResult result =
        context_.runtime().update_relationship(request.relationship_id, request.author, request.description);
    if (result.success) {
        context_.events().publish(EventType::RelationshipUpdated, result.relationship.relationship_id, "");
    }
    return RelationshipMutationResponse(result.success, result.error, result.relationship);
}

RuntimeService::DeleteResponse RuntimeService::delete_relationship(const DeleteRelationshipRequest& request) {
    const RuntimeResult result = context_.runtime().delete_relationship(request.relationship_id);
    if (result.success) {
        context_.events().publish(EventType::RelationshipDeleted, request.relationship_id, "");
    }
    return DeleteResponse(result.success, result.error);
}

RuntimeService::TransactionResponse RuntimeService::begin_transaction() {
    const RuntimeResult result = context_.runtime().begin_transaction();
    if (result.success) {
        context_.events().publish(EventType::TransactionBegun, "", "");
    }
    return TransactionResponse(result.success, result.error);
}

RuntimeService::TransactionResponse RuntimeService::commit_transaction() {
    const RuntimeResult result = context_.runtime().commit_transaction();
    if (result.success) {
        context_.events().publish(EventType::TransactionCommitted, "", "");
    }
    return TransactionResponse(result.success, result.error);
}

RuntimeService::TransactionResponse RuntimeService::rollback_transaction() {
    const RuntimeResult result = context_.runtime().rollback_transaction();
    if (result.success) {
        context_.events().publish(EventType::TransactionRolledBack, "", "");
    }
    return TransactionResponse(result.success, result.error);
}

} // namespace oep::runtime
