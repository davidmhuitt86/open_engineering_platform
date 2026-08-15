#include "oep/runtime/foundation_runtime.hpp"

#include <algorithm>
#include <cctype>

#include "oep/archive/repository_exporter.hpp"
#include "oep/archive/repository_importer.hpp"
#include "oep/installer/package_installer.hpp"
#include "oep/installer/sha256.hpp"
#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

namespace oep::runtime {

std::string to_string(RuntimeState state) {
    switch (state) {
        case RuntimeState::Uninitialized: return "Uninitialized";
        case RuntimeState::Initialized: return "Initialized";
        case RuntimeState::RepositoryOpen: return "RepositoryOpen";
        case RuntimeState::RepositoryClosed: return "RepositoryClosed";
        case RuntimeState::Shutdown: return "Shutdown";
    }
    return "Uninitialized";
}

FoundationRuntime::FoundationRuntime(std::string foundation_version)
    : foundation_version_(std::move(foundation_version)) {}

RuntimeState FoundationRuntime::state() const {
    return state_;
}

void FoundationRuntime::reset_repository_context() {
    // Never leave a transaction stranded: roll it back while the stores
    // it needs (objects_/relationships_) are still valid, before they
    // are reset below.
    if (transaction_active_) {
        rollback_transaction_internal();
    }

    repository_root_.clear();
    metadata_.reset();
    audit_.reset();
    objects_.reset();
    relationships_.reset();
    search_.reset();
    graph_.reset();
    validator_.reset();
    packages_.reset();
    registry_.reset();
    journal_.reset();
    trust_store_.reset();
}

void FoundationRuntime::open_transaction_internal(const std::string& description) {
    transaction_active_ = true;
    transaction_log_.clear();
    current_transaction_ = TransactionRecord{};
    current_transaction_.transaction_id = oep::repository::generate_uuid_v4();
    current_transaction_.description = description;
    current_transaction_.opened_utc = oep::repository::current_timestamp_utc();
    current_transaction_.state = TransactionState::Opened;
}

void FoundationRuntime::journal_operation(const std::string& operation, const std::string& target_id,
                                           const std::string& previous_state, const std::string& new_state) {
    if (!transaction_active_) {
        return;
    }
    JournalEntry entry;
    entry.timestamp_utc = oep::repository::current_timestamp_utc();
    entry.operation = operation;
    entry.target_id = target_id;
    entry.previous_state = previous_state;
    entry.new_state = new_state;
    current_transaction_.entries.push_back(std::move(entry));
}

RuntimeResult FoundationRuntime::commit_transaction_internal() {
    // Every mutation was already persisted as it happened; committing
    // discards the undo log and writes the permanent journal record.
    transaction_log_.clear();
    transaction_active_ = false;
    current_transaction_.state = TransactionState::Committed;
    current_transaction_.closed_utc = oep::repository::current_timestamp_utc();

    const JournalWriteResult written = journal_->write(current_transaction_);
    if (!written.success) {
        // The mutations are committed and consistent — this error exists
        // only so the caller knows the audit trail is incomplete.
        return {false, "the transaction committed, but its journal record could not be written: " + written.error};
    }
    return {true, ""};
}

void FoundationRuntime::rollback_transaction_internal() {
    bool undo_complete = true;
    for (auto it = transaction_log_.rbegin(); it != transaction_log_.rend(); ++it) {
        switch (it->kind) {
            case TransactionLogEntry::Kind::ObjectCreated:
                undo_complete = objects_->remove(it->object_snapshot.object_id).success && undo_complete;
                break;
            case TransactionLogEntry::Kind::ObjectUpdated:
                undo_complete = objects_->update(it->object_snapshot).success && undo_complete;
                break;
            case TransactionLogEntry::Kind::ObjectDeleted:
                undo_complete = objects_->restore(it->object_snapshot).success && undo_complete;
                break;
            case TransactionLogEntry::Kind::RelationshipCreated:
                undo_complete =
                    relationships_->remove(it->relationship_snapshot.relationship_id).success && undo_complete;
                break;
            case TransactionLogEntry::Kind::RelationshipUpdated:
                undo_complete = relationships_->update(it->relationship_snapshot).success && undo_complete;
                break;
            case TransactionLogEntry::Kind::RelationshipDeleted:
                undo_complete = relationships_->restore(it->relationship_snapshot).success && undo_complete;
                break;
        }
    }
    transaction_log_.clear();
    transaction_active_ = false;

    // Journal the rollback best-effort: restoring repository state (done
    // above) always outranks recording history, so a journal problem is
    // never allowed to make a rollback report failure.
    if (journal_.has_value() && !current_transaction_.transaction_id.empty()) {
        current_transaction_.state = undo_complete ? TransactionState::RolledBack : TransactionState::Failed;
        current_transaction_.closed_utc = oep::repository::current_timestamp_utc();
        journal_->write(current_transaction_);
    }
}

RuntimeResult FoundationRuntime::initialize() {
    if (state_ != RuntimeState::Uninitialized) {
        return {false, "cannot initialize Runtime from state '" + to_string(state_) + "'"};
    }
    state_ = RuntimeState::Initialized;
    return {true, ""};
}

RuntimeResult FoundationRuntime::open_repository(std::filesystem::path repository_root) {
    if (state_ != RuntimeState::Initialized && state_ != RuntimeState::RepositoryClosed) {
        if (state_ == RuntimeState::Uninitialized) {
            return {false, "cannot open a repository before the Runtime is initialized"};
        }
        if (state_ == RuntimeState::RepositoryOpen) {
            return {false, "a repository is already open; call close_repository() first"};
        }
        return {false, "cannot open a repository from state '" + to_string(state_) + "'"};
    }

    const oep::repository::LoadMetadataResult loaded_metadata =
        oep::repository::load_metadata(repository_root / "repository.json");
    if (!loaded_metadata.success) {
        return {false, "could not load repository metadata: " + loaded_metadata.error};
    }

    oep::repository::AuditStore audit(repository_root / "repository" / "audit");
    oep::repository::ObjectStore objects(repository_root / "repository" / "objects", audit);
    oep::repository::RelationshipStore relationships(repository_root / "repository" / "relationships", objects,
                                                       audit);

    oep::search::SearchEngine search;
    search.build_index(objects, relationships);

    oep::repository::GraphEngine graph;
    graph.build_graph(objects, relationships);

    oep::validation::RepositoryValidator validator(repository_root / "repository.json", objects, relationships,
                                                    audit);

    oep::packages::PackageManager packages(repository_root / "packages", foundation_version_);

    // Repository Registry (WP-REP-001/002, OEP-ARCH-002 §4.1) — rooted
    // at the same top-level `packages/` directory OEP-SPEC-002 §6
    // reserves for "locally installed OEP packages", but keyed by
    // `registry.json` rather than `package.json`, so it never collides
    // with `oep::packages::PackageManager`'s own, unrelated discovery —
    // see platform/installer/repository_registry.hpp.
    oep::installer::RepositoryRegistry registry(repository_root / "packages");

    // Transaction Journal (WP-REP-003) — inside the `logs/` directory
    // OEP-SPEC-002 §5 already reserves.
    TransactionJournal journal(repository_root / "logs" / "transactions");

    // Trust Store (WP-REP-004, PKG-005) — inside the `settings/`
    // directory OEP-SPEC-002 §5 already reserves for repository
    // configuration.
    oep::installer::TrustStore trust_store(repository_root / "settings" / "trust");

    repository_root_ = std::move(repository_root);
    metadata_ = loaded_metadata.metadata;
    audit_ = std::move(audit);
    objects_ = std::move(objects);
    relationships_ = std::move(relationships);
    search_ = std::move(search);
    graph_ = std::move(graph);
    validator_ = std::move(validator);
    packages_ = std::move(packages);
    registry_ = std::move(registry);
    journal_ = std::move(journal);
    trust_store_ = std::move(trust_store);

    state_ = RuntimeState::RepositoryOpen;
    return {true, ""};
}

RuntimeResult FoundationRuntime::close_repository() {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open (state: '" + to_string(state_) + "')"};
    }

    reset_repository_context();
    state_ = RuntimeState::RepositoryClosed;
    return {true, ""};
}

RuntimeResult FoundationRuntime::shutdown() {
    if (state_ == RuntimeState::Shutdown) {
        return {false, "Runtime has already been shut down"};
    }

    reset_repository_context();
    state_ = RuntimeState::Shutdown;
    return {true, ""};
}

RuntimeRepositoryPathResult FoundationRuntime::current_repository() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    return {true, "", repository_root_};
}

RuntimeMetadataResult FoundationRuntime::current_metadata() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    return {true, "", *metadata_};
}

RuntimePackageSetResult FoundationRuntime::current_package_set() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    const oep::packages::ListPackagesResult listed = packages_->list_packages();
    if (!listed.success) {
        return {false, listed.error, {}};
    }
    return {true, "", listed.packages};
}

const oep::repository::ObjectStore* FoundationRuntime::object_store() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*objects_) : nullptr;
}

const oep::repository::RelationshipStore* FoundationRuntime::relationship_store() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*relationships_) : nullptr;
}

const oep::repository::AuditStore* FoundationRuntime::audit_store() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*audit_) : nullptr;
}

const oep::search::SearchEngine* FoundationRuntime::search_engine() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*search_) : nullptr;
}

const oep::repository::GraphEngine* FoundationRuntime::graph_engine() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*graph_) : nullptr;
}

const oep::validation::RepositoryValidator* FoundationRuntime::validator() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*validator_) : nullptr;
}

const oep::packages::PackageManager* FoundationRuntime::package_manager() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*packages_) : nullptr;
}

const oep::installer::RepositoryRegistry* FoundationRuntime::repository_registry() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*registry_) : nullptr;
}

const oep::installer::TrustStore* FoundationRuntime::trust_store() const {
    return state_ == RuntimeState::RepositoryOpen ? &(*trust_store_) : nullptr;
}

RuntimeInstallResult FoundationRuntime::install_package(const std::filesystem::path& archive_path) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "cannot install a package: no repository is currently open", "", "", 0, 0};
    }
    if (transaction_active_) {
        // An install is its own transaction, never a participant in a
        // caller's (no nesting, per Work Package 014's transaction model).
        return {false, "cannot install a package while a transaction is already active", "", "", 0, 0};
    }

    const oep::installer::ExtractPackageResult extracted = oep::installer::extract_package(archive_path);
    if (!extracted.success) {
        return {false, "could not extract package: " + extracted.error, "", "", 0, 0};
    }
    const oep::installer::OepPackageManifest& manifest = extracted.package.manifest;

    const oep::installer::IsInstalledResult existing = registry_->is_installed(manifest.package_id);
    if (!existing.success) {
        return {false, "could not check the Repository Registry: " + existing.error, manifest.package_id,
                manifest.version, 0, 0};
    }
    if (existing.installed) {
        return {false, "package '" + manifest.package_id + "' is already installed", manifest.package_id,
                manifest.version, 0, 0};
    }

    // TRUST VERIFICATION (WP-REP-004, PKG-005 §11) — deliberately BEFORE
    // any Repository Transaction begins, per this Work Package's explicit
    // requirement. Offline, against the repository's own Trust Store.
    const oep::installer::TrustVerification trust = oep::installer::verify_package_trust(archive_path, *trust_store_);
    if (!trust.success) {
        return {false, "could not verify package trust: " + trust.error, manifest.package_id, manifest.version, 0,
                0, ""};
    }
    const bool trust_blocks_install = trust.state != oep::installer::TrustState::Trusted &&
                                       trust.state != oep::installer::TrustState::Unsigned;
    if (trust_blocks_install) {
        return {false,
                "package trust verification failed (" + oep::installer::to_string(trust.state) +
                    "): " + trust.detail,
                manifest.package_id, manifest.version, 0, 0, oep::installer::to_string(trust.state)};
    }
    if (trust.state == oep::installer::TrustState::Unsigned) {
        const oep::installer::TrustPolicyResult policy = trust_store_->get_policy();
        if (policy.success && policy.require_signatures) {
            return {false,
                    "this repository's trust policy requires signed packages, and '" + manifest.package_id +
                        "' is unsigned",
                    manifest.package_id, manifest.version, 0, 0, oep::installer::to_string(trust.state)};
        }
    }

    // ATOMIC (WP-REP-003, Repository Transaction Engine): the whole
    // install runs inside one Repository Transaction. Any failure below
    // rolls back every create performed so far and journals the
    // transaction as RolledBack; counts are always 0 on failure.
    open_transaction_internal("install " + manifest.package_id);

    std::vector<std::string> object_ids;
    std::vector<std::string> relationship_ids;

    for (const oep::repository::EngineeringObject& object : extracted.package.objects) {
        const oep::repository::LoadObjectResult created = objects_->create(object);
        if (!created.success) {
            rollback_transaction_internal();
            return {false,
                    "failed to create Engineering Object '" + object.name + "': " + created.error +
                        " — the installation was rolled back; nothing was installed",
                    manifest.package_id, manifest.version, 0, 0};
        }
        TransactionLogEntry entry;
        entry.kind = TransactionLogEntry::Kind::ObjectCreated;
        entry.object_snapshot = created.object;
        transaction_log_.push_back(std::move(entry));
        journal_operation("ObjectCreated", created.object.object_id, "absent", "present:" + created.object.name);
        object_ids.push_back(created.object.object_id);
    }

    for (const oep::repository::Relationship& relationship : extracted.package.relationships) {
        const oep::repository::LoadRelationshipResult created = relationships_->create(relationship);
        if (!created.success) {
            rollback_transaction_internal();
            return {false,
                    "failed to create Relationship: " + created.error +
                        " — the installation was rolled back; nothing was installed",
                    manifest.package_id, manifest.version, 0, 0};
        }
        TransactionLogEntry entry;
        entry.kind = TransactionLogEntry::Kind::RelationshipCreated;
        entry.relationship_snapshot = created.relationship;
        transaction_log_.push_back(std::move(entry));
        journal_operation("RelationshipCreated", created.relationship.relationship_id, "absent",
                           "present:" + oep::repository::to_string(created.relationship.relationship_type));
        relationship_ids.push_back(created.relationship.relationship_id);
    }

    oep::installer::RepositoryRegistryEntry record;
    record.package_id = manifest.package_id;
    record.version = manifest.version;
    record.title = manifest.title;
    record.summary = manifest.summary;
    record.category = manifest.category;
    record.schema_version = manifest.schema_version;
    record.engineering_domains = manifest.engineering_domains;
    record.publisher_id = manifest.publisher_id;
    record.publisher_name = manifest.publisher_name;
    record.installed_utc = oep::repository::current_timestamp_utc();
    record.source = "local";
    record.runtime_state = "Installed";
    record.trust_status = oep::installer::to_string(trust.state);
    record.trust_fingerprint = trust.fingerprint;
    record.object_ids = object_ids;
    record.relationship_ids = relationship_ids;

    // Installation Path + Package Hash (WP-REP-002 §4): recorded from the
    // archive as supplied. The hash is an integrity fingerprint only, not
    // a trust mechanism — see oep::installer::sha256_hex's doc comment.
    std::error_code absolute_error;
    const std::filesystem::path absolute_archive = std::filesystem::absolute(archive_path, absolute_error);
    record.installation_path = absolute_error ? archive_path.string() : absolute_archive.string();
    const std::optional<std::string> hash = oep::installer::sha256_hex_file(archive_path);
    record.package_hash = hash.has_value() ? *hash : "";

    const oep::installer::RegistryResult recorded = registry_->record_install(record);
    if (!recorded.success) {
        // The Repository Registry write is the last mutating step before
        // commit — its failure rolls back every create above, so a
        // package is never left installed-but-unregistered.
        rollback_transaction_internal();
        return {false,
                "recording the install in the Repository Registry failed: " + recorded.error +
                    " — the installation was rolled back; nothing was installed",
                manifest.package_id, manifest.version, 0, 0};
    }
    journal_operation("PackageRecorded", manifest.package_id, "absent", "installed:" + manifest.version);

    // Commit the transaction. A journal-write failure here is not an
    // install failure: every mutation and the registry record are already
    // persisted and consistent; only the audit record is missing.
    commit_transaction_internal();

    // Update Repository indexes (WP-REP-001's own explicit responsibility)
    // — reuse the exact rebuild open_repository() already performs, rather
    // than a second, parallel indexing mechanism.
    search_->build_index(*objects_, *relationships_);
    graph_->build_graph(*objects_, *relationships_);

    return {true, "", manifest.package_id, manifest.version, static_cast<int>(object_ids.size()),
            static_cast<int>(relationship_ids.size()), oep::installer::to_string(trust.state)};
}

RuntimeUninstallResult FoundationRuntime::uninstall_package(const std::string& package_id) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "cannot uninstall a package: no repository is currently open", package_id, "", 0, 0};
    }
    if (transaction_active_) {
        // An uninstall is its own transaction, never a participant in a
        // caller's (no nesting, per Work Package 014's transaction model).
        return {false, "cannot uninstall a package while a transaction is already active", package_id, "", 0, 0};
    }

    const oep::installer::IsInstalledResult existing = registry_->is_installed(package_id);
    if (!existing.success) {
        return {false, "could not check the Repository Registry: " + existing.error, package_id, "", 0, 0};
    }
    if (!existing.installed) {
        return {false, "package '" + package_id + "' is not installed", package_id, "", 0, 0};
    }
    const oep::installer::RepositoryRegistryEntry& entry = existing.record;

    // ATOMIC (WP-REP-003, Repository Transaction Engine): the whole
    // uninstall runs inside one Repository Transaction. Any failure below
    // rolls back every delete performed so far and journals the
    // transaction as RolledBack; counts are always 0 on failure.
    open_transaction_internal("uninstall " + package_id);

    int relationships_deleted = 0;
    for (const std::string& relationship_id : entry.relationship_ids) {
        const oep::repository::LoadRelationshipResult loaded = relationships_->load(relationship_id);
        if (!loaded.success) {
            rollback_transaction_internal();
            return {false,
                    "failed to load Relationship '" + relationship_id + "' for uninstall: " + loaded.error +
                        " — the uninstall was rolled back; nothing was removed",
                    package_id, entry.version, 0, 0};
        }
        const oep::repository::RelationshipResult removed = relationships_->remove(relationship_id);
        if (!removed.success) {
            rollback_transaction_internal();
            return {false,
                    "failed to delete Relationship '" + relationship_id + "': " + removed.error +
                        " — the uninstall was rolled back; nothing was removed",
                    package_id, entry.version, 0, 0};
        }
        TransactionLogEntry log_entry;
        log_entry.kind = TransactionLogEntry::Kind::RelationshipDeleted;
        log_entry.relationship_snapshot = loaded.relationship; // pre-delete record, for undo
        transaction_log_.push_back(std::move(log_entry));
        journal_operation("RelationshipDeleted", relationship_id, "present", "absent");
        ++relationships_deleted;
    }

    int objects_deleted = 0;
    for (const std::string& object_id : entry.object_ids) {
        const oep::repository::LoadObjectResult loaded = objects_->load(object_id);
        if (!loaded.success) {
            rollback_transaction_internal();
            return {false,
                    "failed to load Engineering Object '" + object_id + "' for uninstall: " + loaded.error +
                        " — the uninstall was rolled back; nothing was removed",
                    package_id, entry.version, 0, 0};
        }
        const oep::repository::ObjectResult removed = objects_->remove(object_id);
        if (!removed.success) {
            rollback_transaction_internal();
            return {false,
                    "failed to delete Engineering Object '" + object_id + "': " + removed.error +
                        " — the uninstall was rolled back; nothing was removed",
                    package_id, entry.version, 0, 0};
        }
        TransactionLogEntry log_entry;
        log_entry.kind = TransactionLogEntry::Kind::ObjectDeleted;
        log_entry.object_snapshot = loaded.object; // pre-delete record, for undo
        transaction_log_.push_back(std::move(log_entry));
        journal_operation("ObjectDeleted", object_id, "present:" + loaded.object.name, "absent");
        ++objects_deleted;
    }

    const oep::installer::RegistryResult removed_record = registry_->remove_install(package_id);
    if (!removed_record.success) {
        // The Repository Registry write is the last mutating step before
        // commit — its failure rolls back every delete above, so a
        // package is never left partially uninstalled.
        rollback_transaction_internal();
        return {false,
                "removing the Repository Registry record failed: " + removed_record.error +
                    " — the uninstall was rolled back; nothing was removed",
                package_id, entry.version, 0, 0};
    }
    journal_operation("PackageRemoved", package_id, "installed:" + entry.version, "absent");

    // Commit the transaction. A journal-write failure here is not an
    // uninstall failure: every delete and the registry removal are
    // already persisted and consistent; only the audit record is missing.
    commit_transaction_internal();

    // Update Repository indexes, mirroring install_package's own final
    // step.
    search_->build_index(*objects_, *relationships_);
    graph_->build_graph(*objects_, *relationships_);

    return {true, "", package_id, entry.version, objects_deleted, relationships_deleted};
}

RuntimeInstalledPackagesResult FoundationRuntime::list_installed_packages() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    const oep::installer::ListInstalledResult listed = registry_->list_installed();
    return {listed.success, listed.error, listed.packages};
}

RuntimeInstalledPackageResult FoundationRuntime::get_installed_package(const std::string& package_id) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", false, {}};
    }
    const oep::installer::IsInstalledResult found = registry_->is_installed(package_id);
    return {found.success, found.error, found.installed, found.record};
}

RuntimePackageOwnerResult FoundationRuntime::find_package_owner(const std::string& entity_id) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", oep::installer::OwnedEntityKind::None, {}};
    }
    const oep::installer::FindOwnerResult found = registry_->find_owner(entity_id);
    return {found.success, found.error, found.kind, found.owner};
}

RuntimeVerifyPackageResult FoundationRuntime::verify_package(const std::string& package_id) const {
    RuntimeVerifyPackageResult result;
    if (state_ != RuntimeState::RepositoryOpen) {
        result.error = "no repository is currently open";
        return result;
    }

    const oep::installer::IsInstalledResult found = registry_->is_installed(package_id);
    if (!found.success) {
        result.error = "could not read the Repository Registry: " + found.error;
        return result;
    }
    if (!found.installed) {
        result.error = "package '" + package_id + "' is not installed";
        return result;
    }
    const oep::installer::RepositoryRegistryEntry& entry = found.record;

    result.success = true;
    result.objects_expected = static_cast<int>(entry.object_ids.size());
    result.relationships_expected = static_cast<int>(entry.relationship_ids.size());

    // Every recorded contribution must still exist in the open
    // repository's own stores — verification reads live repository state,
    // never a cached copy.
    for (const std::string& object_id : entry.object_ids) {
        if (objects_->load(object_id).success) {
            ++result.objects_present;
        } else {
            result.findings.push_back("Engineering Object '" + object_id + "' is recorded as installed but no longer exists");
        }
    }
    for (const std::string& relationship_id : entry.relationship_ids) {
        if (relationships_->load(relationship_id).success) {
            ++result.relationships_present;
        } else {
            result.findings.push_back("Relationship '" + relationship_id + "' is recorded as installed but no longer exists");
        }
    }

    // Archive integrity: only checkable while the source archive still
    // exists at its recorded installation path. A deleted archive is a
    // reported condition, not a failure — the archive is transport, not
    // the installed content.
    std::error_code exists_error;
    result.archive_available = !entry.installation_path.empty() &&
                                std::filesystem::exists(entry.installation_path, exists_error);
    if (result.archive_available && !entry.package_hash.empty()) {
        const std::optional<std::string> hash = oep::installer::sha256_hex_file(entry.installation_path);
        result.archive_hash_matches = hash.has_value() && *hash == entry.package_hash;
        if (!result.archive_hash_matches) {
            result.findings.push_back("the source archive at '" + entry.installation_path +
                                       "' no longer matches its recorded SHA-256 hash");
        }
    } else if (!result.archive_available) {
        result.findings.push_back("the source archive at '" + entry.installation_path +
                                   "' is no longer present (informational — not a verification failure)");
    }

    const bool contributions_intact = result.objects_present == result.objects_expected &&
                                       result.relationships_present == result.relationships_expected;
    const bool archive_intact = !result.archive_available || entry.package_hash.empty() || result.archive_hash_matches;
    result.verified = contributions_intact && archive_intact;
    return result;
}

RuntimeSearchPackagesResult FoundationRuntime::search_installed_packages(const std::string& query) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    if (query.empty()) {
        return {false, "search query must not be empty", {}};
    }

    // Registry-metadata matches first (package ID/title/summary/category/
    // version/publisher/domains) ...
    const oep::installer::SearchPackagesResult metadata_matches = registry_->search_packages(query);
    if (!metadata_matches.success) {
        return {false, metadata_matches.error, {}};
    }

    std::vector<oep::installer::RepositoryRegistryEntry> matches = metadata_matches.packages;

    // ... then "Installed Objects" matches (WP-REP-002 §8): a package also
    // matches if the *name* of an Engineering Object it installed matches.
    // Object names live only in the ObjectStore (never duplicated into the
    // registry), so this cross-reference reads them live.
    std::string query_lower = query;
    std::transform(query_lower.begin(), query_lower.end(), query_lower.begin(),
                    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

    const oep::installer::ListInstalledResult all = registry_->list_installed();
    if (!all.success) {
        return {false, all.error, {}};
    }
    for (const oep::installer::RepositoryRegistryEntry& entry : all.packages) {
        const bool already_matched =
            std::any_of(matches.begin(), matches.end(), [&entry](const oep::installer::RepositoryRegistryEntry& m) {
                return m.package_id == entry.package_id;
            });
        if (already_matched) {
            continue;
        }
        for (const std::string& object_id : entry.object_ids) {
            const oep::repository::LoadObjectResult loaded = objects_->load(object_id);
            if (!loaded.success) {
                continue;
            }
            std::string name_lower = loaded.object.name;
            std::transform(name_lower.begin(), name_lower.end(), name_lower.begin(),
                            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            if (name_lower.find(query_lower) != std::string::npos) {
                matches.push_back(entry);
                break;
            }
        }
    }

    return {true, "", matches};
}

RuntimeTrustResult FoundationRuntime::trust_add_certificate(
    const oep::installer::PublisherCertificate& certificate) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }
    const oep::installer::TrustStoreResult added = trust_store_->add_certificate(certificate);
    return {added.success, added.error};
}

RuntimeCertificateResult FoundationRuntime::trust_get_certificate(const std::string& publisher_id) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", false, {}};
    }
    const oep::installer::GetCertificateResult found = trust_store_->get_certificate(publisher_id);
    return {found.success, found.error, found.found, found.certificate};
}

RuntimeCertificateListResult FoundationRuntime::trust_list_certificates() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    const oep::installer::ListCertificatesResult listed = trust_store_->list_certificates();
    return {listed.success, listed.error, listed.certificates};
}

RuntimeTrustResult FoundationRuntime::trust_revoke_certificate(const std::string& publisher_id) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }
    const oep::installer::TrustStoreResult revoked = trust_store_->revoke_certificate(publisher_id);
    return {revoked.success, revoked.error};
}

RuntimeTrustPolicyResult FoundationRuntime::trust_get_policy() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", false};
    }
    const oep::installer::TrustPolicyResult policy = trust_store_->get_policy();
    return {policy.success, policy.error, policy.require_signatures};
}

RuntimeTrustResult FoundationRuntime::trust_set_policy(bool require_signatures) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }
    const oep::installer::TrustStoreResult set = trust_store_->set_policy(require_signatures);
    return {set.success, set.error};
}

RuntimeExportResult FoundationRuntime::export_repository(const std::filesystem::path& output_file,
                                                           bool include_packages) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }

    const oep::archive::ExportResult result = oep::archive::export_repository(
        *metadata_, *objects_, *relationships_, *audit_, include_packages ? &(*packages_) : nullptr, output_file);
    if (!result.success) {
        return {false, result.error, result.manifest};
    }
    return {true, "", result.manifest};
}

RuntimeImportResult FoundationRuntime::import_repository(const std::filesystem::path& archive_file,
                                                          const std::filesystem::path& destination,
                                                          bool overwrite) const {
    const oep::archive::ImportResult result = oep::archive::import_repository(archive_file, destination, overwrite);
    if (!result.success) {
        return {false, result.error, result.manifest};
    }
    return {true, "", result.manifest};
}

RuntimeCreateTemplateResult FoundationRuntime::create_template(const std::filesystem::path& templates_dir,
                                                                const std::string& template_name,
                                                                const std::string& description,
                                                                const std::string& author,
                                                                const std::vector<std::string>& tags,
                                                                bool include_packages) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }

    const oep::archive::TemplateStore store(templates_dir);
    const oep::archive::CreateTemplateResult result =
        store.create_template(template_name, description, author, tags, foundation_version_, *objects_,
                               *relationships_, include_packages ? &(*packages_) : nullptr);
    if (!result.success) {
        return {false, result.error, result.manifest};
    }
    return {true, "", result.manifest};
}

RuntimeListTemplatesResult FoundationRuntime::list_templates(const std::filesystem::path& templates_dir) const {
    const oep::archive::TemplateStore store(templates_dir);
    const oep::archive::ListTemplatesResult result = store.list_templates();
    if (!result.success) {
        return {false, result.error, {}};
    }
    return {true, "", result.templates};
}

RuntimeInstantiateTemplateResult FoundationRuntime::instantiate_template(const std::filesystem::path& templates_dir,
                                                                          const std::string& template_id,
                                                                          const std::filesystem::path& destination,
                                                                          const std::string& new_repository_name) const {
    const oep::archive::TemplateStore store(templates_dir);
    const oep::archive::InstantiateTemplateResult result =
        store.instantiate_template(template_id, destination, new_repository_name);
    if (!result.success) {
        return {false, result.error};
    }
    return {true, ""};
}

RuntimeBatchCreateResult FoundationRuntime::execute_batch_create(const std::string& batch_json) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", 0, 0};
    }

    const oep::repository::BatchParseResult parsed = oep::repository::parse_batch_create_request(batch_json);
    if (!parsed.success) {
        return {false, parsed.error, 0, 0};
    }

    const oep::repository::BatchCreateResult result =
        oep::repository::execute_batch_create(parsed.request, *objects_, *relationships_);
    if (!result.success) {
        return {false, result.error, result.objects_created, result.relationships_created};
    }
    return {true, "", result.objects_created, result.relationships_created};
}

RuntimeBatchDeleteResult FoundationRuntime::execute_batch_delete(const std::string& batch_json) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", 0, 0};
    }

    const oep::repository::BatchDeleteParseResult parsed = oep::repository::parse_batch_delete_request(batch_json);
    if (!parsed.success) {
        return {false, parsed.error, 0, 0};
    }

    const oep::repository::BatchDeleteResult result =
        oep::repository::execute_batch_delete(parsed.request, *objects_, *relationships_);
    if (!result.success) {
        return {false, result.error, result.objects_deleted, result.relationships_deleted};
    }
    return {true, "", result.objects_deleted, result.relationships_deleted};
}

RuntimeBatchValidateResult FoundationRuntime::validate_batch_create(const std::string& batch_json) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }

    const oep::repository::BatchParseResult parsed = oep::repository::parse_batch_create_request(batch_json);
    if (!parsed.success) {
        return {false, parsed.error, {}};
    }

    const std::vector<std::string> findings =
        oep::repository::validate_batch_create_request(parsed.request, *objects_);
    return {true, "", findings};
}

RuntimeObjectMutationResult FoundationRuntime::create_object(oep::repository::ObjectType object_type,
                                                               const std::string& name, const std::string& description,
                                                               const std::string& author,
                                                               const std::vector<std::string>& tags) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }

    oep::repository::EngineeringObject object;
    object.object_type = object_type;
    object.name = name;
    object.description = description;
    object.author = author;
    object.tags = tags;

    // Every write executes through a Repository Transaction (WP-REP-003):
    // a mutation called outside an explicit transaction runs inside an
    // implicit one, begun here and committed below, so it is journaled
    // exactly like any other write. The implicit commit's journal write
    // is best-effort — the mutation's own success is never retracted
    // because an audit record could not be written.
    const bool implicit_transaction = !transaction_active_;
    if (implicit_transaction) {
        open_transaction_internal("object create");
    }

    const oep::repository::LoadObjectResult result = objects_->create(object);
    if (!result.success) {
        rollback_transaction_internal();
        return {false, result.error, {}};
    }

    TransactionLogEntry entry;
    entry.kind = TransactionLogEntry::Kind::ObjectCreated;
    entry.object_snapshot = result.object;
    transaction_log_.push_back(std::move(entry));
    journal_operation("ObjectCreated", result.object.object_id, "absent", "present:" + result.object.name);

    if (implicit_transaction) {
        commit_transaction_internal();
    }

    return {true, "", result.object};
}

RuntimeObjectMutationResult FoundationRuntime::update_object(const std::string& object_id, const std::string& name,
                                                               const std::string& description,
                                                               const std::string& author,
                                                               const std::vector<std::string>& tags) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }

    const bool implicit_transaction = !transaction_active_;
    if (implicit_transaction) {
        open_transaction_internal("object update");
    }

    const oep::repository::LoadObjectResult existing = objects_->load(object_id);
    if (!existing.success) {
        rollback_transaction_internal();
        return {false, existing.error, {}};
    }

    oep::repository::EngineeringObject updated = existing.object;
    updated.name = name;
    updated.description = description;
    updated.author = author;
    updated.tags = tags;

    const oep::repository::ObjectResult result = objects_->update(updated);
    if (!result.success) {
        rollback_transaction_internal();
        return {false, result.error, {}};
    }

    TransactionLogEntry entry;
    entry.kind = TransactionLogEntry::Kind::ObjectUpdated;
    entry.object_snapshot = existing.object; // pre-update record, for undo
    transaction_log_.push_back(std::move(entry));
    journal_operation("ObjectUpdated", object_id, "present:" + existing.object.name, "present:" + updated.name);

    if (implicit_transaction) {
        commit_transaction_internal();
    }

    const oep::repository::LoadObjectResult reloaded = objects_->load(object_id);
    return {true, "", reloaded.success ? reloaded.object : updated};
}

RuntimeResult FoundationRuntime::delete_object(const std::string& object_id) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }

    const bool implicit_transaction = !transaction_active_;
    if (implicit_transaction) {
        open_transaction_internal("object delete");
    }

    const oep::repository::LoadObjectResult existing = objects_->load(object_id);
    if (!existing.success) {
        rollback_transaction_internal();
        return {false, existing.error};
    }

    const oep::repository::ObjectResult result = objects_->remove(object_id);
    if (!result.success) {
        rollback_transaction_internal();
        return {result.success, result.error};
    }

    TransactionLogEntry entry;
    entry.kind = TransactionLogEntry::Kind::ObjectDeleted;
    entry.object_snapshot = existing.object; // pre-delete record, for undo
    transaction_log_.push_back(std::move(entry));
    journal_operation("ObjectDeleted", object_id, "present:" + existing.object.name, "absent");

    if (implicit_transaction) {
        commit_transaction_internal();
    }

    return {true, ""};
}

RuntimeRelationshipMutationResult FoundationRuntime::create_relationship(
    const std::string& source_object_id, const std::string& target_object_id,
    oep::repository::RelationshipType relationship_type, const std::string& author, const std::string& description) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }

    oep::repository::Relationship relationship;
    relationship.source_object_id = source_object_id;
    relationship.target_object_id = target_object_id;
    relationship.relationship_type = relationship_type;
    relationship.author = author;
    relationship.description = description;

    const bool implicit_transaction = !transaction_active_;
    if (implicit_transaction) {
        open_transaction_internal("relationship create");
    }

    const oep::repository::LoadRelationshipResult result = relationships_->create(relationship);
    if (!result.success) {
        rollback_transaction_internal();
        return {false, result.error, {}};
    }

    TransactionLogEntry entry;
    entry.kind = TransactionLogEntry::Kind::RelationshipCreated;
    entry.relationship_snapshot = result.relationship;
    transaction_log_.push_back(std::move(entry));
    journal_operation("RelationshipCreated", result.relationship.relationship_id, "absent",
                       "present:" + oep::repository::to_string(result.relationship.relationship_type));

    if (implicit_transaction) {
        commit_transaction_internal();
    }

    return {true, "", result.relationship};
}

RuntimeRelationshipMutationResult FoundationRuntime::update_relationship(const std::string& relationship_id,
                                                                          const std::string& author,
                                                                          const std::string& description) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }

    const bool implicit_transaction = !transaction_active_;
    if (implicit_transaction) {
        open_transaction_internal("relationship update");
    }

    const oep::repository::LoadRelationshipResult existing = relationships_->load(relationship_id);
    if (!existing.success) {
        rollback_transaction_internal();
        return {false, existing.error, {}};
    }

    oep::repository::Relationship updated = existing.relationship;
    updated.author = author;
    updated.description = description;

    const oep::repository::RelationshipResult result = relationships_->update(updated);
    if (!result.success) {
        rollback_transaction_internal();
        return {false, result.error, {}};
    }

    TransactionLogEntry entry;
    entry.kind = TransactionLogEntry::Kind::RelationshipUpdated;
    entry.relationship_snapshot = existing.relationship; // pre-update record, for undo
    transaction_log_.push_back(std::move(entry));
    journal_operation("RelationshipUpdated", relationship_id, "present", "present");

    if (implicit_transaction) {
        commit_transaction_internal();
    }

    const oep::repository::LoadRelationshipResult reloaded = relationships_->load(relationship_id);
    return {true, "", reloaded.success ? reloaded.relationship : updated};
}

RuntimeResult FoundationRuntime::delete_relationship(const std::string& relationship_id) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }

    const bool implicit_transaction = !transaction_active_;
    if (implicit_transaction) {
        open_transaction_internal("relationship delete");
    }

    const oep::repository::LoadRelationshipResult existing = relationships_->load(relationship_id);
    if (!existing.success) {
        rollback_transaction_internal();
        return {false, existing.error};
    }

    const oep::repository::RelationshipResult result = relationships_->remove(relationship_id);
    if (!result.success) {
        rollback_transaction_internal();
        return {result.success, result.error};
    }

    TransactionLogEntry entry;
    entry.kind = TransactionLogEntry::Kind::RelationshipDeleted;
    entry.relationship_snapshot = existing.relationship; // pre-delete record, for undo
    transaction_log_.push_back(std::move(entry));
    journal_operation("RelationshipDeleted", relationship_id,
                       "present:" + oep::repository::to_string(existing.relationship.relationship_type), "absent");

    if (implicit_transaction) {
        commit_transaction_internal();
    }

    return {true, ""};
}

RuntimeResult FoundationRuntime::begin_transaction() {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }
    if (transaction_active_) {
        return {false, "a transaction is already active; nested transactions are not supported"};
    }
    open_transaction_internal("transaction");
    return {true, ""};
}

RuntimeResult FoundationRuntime::commit_transaction() {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }
    if (!transaction_active_) {
        return {false, "no transaction is currently active"};
    }
    return commit_transaction_internal();
}

RuntimeResult FoundationRuntime::rollback_transaction() {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open"};
    }
    if (!transaction_active_) {
        return {false, "no transaction is currently active"};
    }
    rollback_transaction_internal();
    return {true, ""};
}

bool FoundationRuntime::transaction_active() const {
    return transaction_active_;
}

RuntimeTransactionInfoResult FoundationRuntime::current_transaction_info() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", false, "", "", 0};
    }
    if (!transaction_active_) {
        return {true, "", false, "", "", 0};
    }
    return {true,
            "",
            true,
            current_transaction_.transaction_id,
            current_transaction_.description,
            static_cast<int>(current_transaction_.entries.size())};
}

RuntimeTransactionHistoryResult FoundationRuntime::transaction_history() const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    const JournalListResult listed = journal_->list();
    return {listed.success, listed.error, listed.records};
}

RuntimeTransactionRecordResult FoundationRuntime::get_transaction_record(const std::string& transaction_id) const {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", {}};
    }
    const JournalLoadResult loaded = journal_->load(transaction_id);
    return {loaded.success, loaded.error, loaded.record};
}

RuntimeBatchCreateObjectsResult FoundationRuntime::batch_create_objects(const std::vector<ObjectCreateSpec>& specs) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", -1, {}};
    }

    const bool started_own_transaction = !transaction_active_;
    if (started_own_transaction) {
        open_transaction_internal("batch object create");
    }

    std::vector<oep::repository::EngineeringObject> created;
    for (std::size_t i = 0; i < specs.size(); ++i) {
        const RuntimeObjectMutationResult result =
            create_object(specs[i].object_type, specs[i].name, specs[i].description, specs[i].author, specs[i].tags);
        if (!result.success) {
            // create_object() already rolled back and deactivated the
            // transaction, whether we began it just above or the
            // caller already had it active.
            return {false, result.error, static_cast<int>(i), {}};
        }
        created.push_back(result.object);
    }

    if (started_own_transaction) {
        const RuntimeResult commit_result = commit_transaction();
        if (!commit_result.success) {
            return {false, commit_result.error, -1, {}};
        }
    }

    return {true, "", -1, created};
}

RuntimeBatchCreateRelationshipsResult FoundationRuntime::batch_create_relationships(
    const std::vector<RelationshipCreateSpec>& specs) {
    if (state_ != RuntimeState::RepositoryOpen) {
        return {false, "no repository is currently open", -1, {}};
    }

    const bool started_own_transaction = !transaction_active_;
    if (started_own_transaction) {
        open_transaction_internal("batch relationship create");
    }

    std::vector<oep::repository::Relationship> created;
    for (std::size_t i = 0; i < specs.size(); ++i) {
        const RuntimeRelationshipMutationResult result =
            create_relationship(specs[i].source_object_id, specs[i].target_object_id, specs[i].relationship_type,
                                 specs[i].author, specs[i].description);
        if (!result.success) {
            return {false, result.error, static_cast<int>(i), {}};
        }
        created.push_back(result.relationship);
    }

    if (started_own_transaction) {
        const RuntimeResult commit_result = commit_transaction();
        if (!commit_result.success) {
            return {false, commit_result.error, -1, {}};
        }
    }

    return {true, "", -1, created};
}

} // namespace oep::runtime
