#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "oep/archive/export_manifest.hpp"
#include "oep/archive/repository_template.hpp"
#include "oep/archive/template_manifest.hpp"
#include "oep/installer/dependency_resolver.hpp"
#include "oep/installer/merge_engine.hpp"
#include "oep/installer/package_verifier.hpp"
#include "oep/installer/repository_registry.hpp"
#include "oep/installer/trust_store.hpp"
#include "oep/installer/version_constraint.hpp"
#include "oep/runtime/transaction_journal.hpp"
#include "oep/packages/package_manager.hpp"
#include "oep/repository/audit_store.hpp"
#include "oep/repository/batch_processor.hpp"
#include "oep/repository/graph_engine.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship_store.hpp"
#include "oep/search/search_engine.hpp"
#include "oep/validation/repository_validator.hpp"

namespace oep::runtime {

// Runtime states, per OEP-SPEC-011-FOUNDATION_RUNTIME. Transitions are
// deterministic: initialize() only succeeds from Uninitialized;
// open_repository() only from Initialized or RepositoryClosed;
// close_repository() only from RepositoryOpen; shutdown() succeeds
// from any state except Shutdown itself, closing an open repository
// first if necessary.
enum class RuntimeState {
    Uninitialized,
    Initialized,
    RepositoryOpen,
    RepositoryClosed,
    Shutdown,
};

std::string to_string(RuntimeState state);

struct RuntimeResult {
    bool success = false;
    std::string error;
};

struct RuntimeMetadataResult {
    bool success = false;
    std::string error;
    oep::repository::RepositoryMetadata metadata;
};

struct RuntimePackageSetResult {
    bool success = false;
    std::string error;
    std::vector<oep::packages::DiscoveredPackage> packages;
};

struct RuntimeRepositoryPathResult {
    bool success = false;
    std::string error;
    std::filesystem::path path;
};

struct RuntimeExportResult {
    bool success = false;
    std::string error;
    oep::archive::ExportManifest manifest;
};

struct RuntimeImportResult {
    bool success = false;
    std::string error;
    oep::archive::ExportManifest manifest;
};

struct RuntimeCreateTemplateResult {
    bool success = false;
    std::string error;
    oep::archive::TemplateManifest manifest;
};

struct RuntimeListTemplatesResult {
    bool success = false;
    std::string error;
    std::vector<oep::archive::TemplateManifest> templates;
};

struct RuntimeInstantiateTemplateResult {
    bool success = false;
    std::string error;
};

struct RuntimeBatchCreateResult {
    bool success = false;
    std::string error;
    int objects_created = 0;
    int relationships_created = 0;
};

struct RuntimeBatchDeleteResult {
    bool success = false;
    std::string error;
    int objects_deleted = 0;
    int relationships_deleted = 0;
};

struct RuntimeBatchValidateResult {
    // success is true iff the input parsed AND validated with zero
    // findings — a structurally valid-but-non-empty-findings batch is
    // reported via `findings`, not treated as an operational failure.
    bool success = false;
    std::string error;
    std::vector<std::string> findings;
};

// Mutation results (Work Package 014). RuntimeResult (success/error only)
// is reused for delete_object/delete_relationship and transaction
// begin/commit/rollback, since none of those need to return a record.
struct RuntimeObjectMutationResult {
    bool success = false;
    std::string error;
    oep::repository::EngineeringObject object;
};

struct RuntimeRelationshipMutationResult {
    bool success = false;
    std::string error;
    oep::repository::Relationship relationship;
};

// AP-OEP-FOUNDATION-GRAPH-IDENTITY-001 — results for diagram/graph
// member enumeration. Distinct from RuntimeObjectMutationResult/
// RuntimeRelationshipMutationResult (which each carry exactly one
// record) since these carry a list, mirroring
// oep::repository::ListObjectsResult/ListRelationshipsResult's own
// shape one layer up.
struct RuntimeDiagramObjectsResult {
    bool success = false;
    std::string error;
    std::vector<oep::repository::EngineeringObject> objects;
};

struct RuntimeDiagramRelationshipsResult {
    bool success = false;
    std::string error;
    std::vector<oep::repository::Relationship> relationships;
};

// Input to batch_create_objects, per OEP-SPEC (Work Package 014,
// TASK-000030). Mirrors the fields create_object accepts individually.
struct ObjectCreateSpec {
    oep::repository::ObjectType object_type = oep::repository::ObjectType::Document;
    std::string name;
    std::string description;
    std::string author;
    std::vector<std::string> tags;
};

// Input to batch_create_relationships. Mirrors the fields
// create_relationship accepts individually.
struct RelationshipCreateSpec {
    std::string source_object_id;
    std::string target_object_id;
    oep::repository::RelationshipType relationship_type = oep::repository::RelationshipType::References;
    std::string author;
    std::string description;
};

struct RuntimeBatchCreateObjectsResult {
    bool success = false;
    std::string error;
    // -1 on full success; otherwise the 0-based index into the input
    // specs of the item that failed. On failure, `created` is always
    // empty — the whole batch is rolled back, per TASK-000030's
    // "Failures shall roll back the complete batch."
    int failed_index = -1;
    std::vector<oep::repository::EngineeringObject> created;
};

struct RuntimeBatchCreateRelationshipsResult {
    bool success = false;
    std::string error;
    int failed_index = -1;
    std::vector<oep::repository::Relationship> created;
};

// Package installation (WP-REP-001, OEP-ARCH-002). Not a transaction
// result: `objects_created`/`relationships_created` report how many
// succeeded even when `success` is false, since install_package is
// deliberately not wrapped in a transaction — see its own doc comment.
struct RuntimeInstallResult {
    bool success = false;
    std::string error;
    std::string package_id;
    std::string version;
    int objects_created = 0;
    int relationships_created = 0;
    // Trust & Signing (WP-REP-004): the TrustState the package resolved
    // to (to_string of oep::installer::TrustState — "Trusted",
    // "Unsigned", "UnknownPublisher", "ExpiredCertificate",
    // "RevokedCertificate", "InvalidSignature", "Tampered"), populated
    // whenever trust verification ran far enough to produce a state —
    // including on a trust-caused failure, so the caller knows why.
    std::string trust_status;
};

struct RuntimeInstalledPackagesResult {
    bool success = false;
    std::string error;
    std::vector<oep::installer::RepositoryRegistryEntry> packages;
};

// Package lifecycle query results (WP-REP-002 §5/§6).
struct RuntimeInstalledPackageResult {
    bool success = false;
    std::string error;
    bool installed = false;
    oep::installer::RepositoryRegistryEntry entry; // meaningful only when installed is true
};

struct RuntimePackageOwnerResult {
    bool success = false;
    std::string error;
    oep::installer::OwnedEntityKind kind = oep::installer::OwnedEntityKind::None;
    oep::installer::RepositoryRegistryEntry owner; // meaningful only when kind != None
};

// The outcome of verify_package (WP-REP-002 §5 "Verify installation
// status" / §7 `oep package verify`). `verified` is true iff every
// contribution the Repository Registry recorded for the package still
// exists in the open repository, AND — when the source archive is still
// present on disk at its recorded installation path — its bytes still
// hash to the recorded SHA-256. A missing archive is NOT a verification
// failure (archives are transport, not the installed content;
// deleting one after install is normal), only a reported condition.
struct RuntimeVerifyPackageResult {
    bool success = false;
    std::string error;
    bool verified = false;
    int objects_expected = 0;
    int objects_present = 0;
    int relationships_expected = 0;
    int relationships_present = 0;
    bool archive_available = false;   // the recorded installation_path still exists
    bool archive_hash_matches = false; // meaningful only when archive_available is true
    std::vector<std::string> findings; // human-readable, one per problem/condition found
};

struct RuntimeSearchPackagesResult {
    bool success = false;
    std::string error;
    std::vector<oep::installer::RepositoryRegistryEntry> packages;
};

// Repository Transaction Engine queries (WP-REP-003).
struct RuntimeTransactionInfoResult {
    bool success = false;
    std::string error;
    bool active = false;
    std::string transaction_id; // meaningful only when active is true
    std::string description;
    int entry_count = 0;
};

struct RuntimeTransactionHistoryResult {
    bool success = false;
    std::string error;
    std::vector<TransactionRecord> records;
};

struct RuntimeTransactionRecordResult {
    bool success = false;
    std::string error;
    TransactionRecord record;
};

// Trust & Signing (WP-REP-004) query/mutation results. Trust Store
// writes (add/revoke/set_policy) are local, offline, user-directed
// actions — not Repository writes, so they do not flow through the
// Repository Transaction Engine (they touch `settings/trust/`, not
// Engineering Objects/Relationships/the Repository Registry).
struct RuntimeTrustResult {
    bool success = false;
    std::string error;
};

struct RuntimeCertificateResult {
    bool success = false;
    std::string error;
    bool found = false;
    oep::installer::PublisherCertificate certificate; // meaningful only when found is true
};

struct RuntimeCertificateListResult {
    bool success = false;
    std::string error;
    std::vector<oep::installer::PublisherCertificate> certificates;
};

struct RuntimeTrustPolicyResult {
    bool success = false;
    std::string error;
    bool require_signatures = false;
};

// Dependency Resolution (WP-REP-005, PKG-004). `success` is the
// operational outcome of the CALL itself (false only if the archive
// couldn't be read/parsed, or no repository is open) -- distinct from
// `report.result`, which is the DRE's own Resolved/Failed verdict.
// Calling this never modifies the repository (PKG-004 §2 "side-effect
// free"): it is a pure read against the currently installed set.
struct RuntimeDependencyResolutionResult {
    bool success = false;
    std::string error;
    oep::installer::DependencyResolutionReport report;
};

// Uninstall Impact Analysis (WP-REP-007): the dry-run report
// analyze_uninstall_impact produces. `removable` is true iff `found` and
// `blocking_dependents` is empty -- uninstall_package refuses to touch
// the repository unless removable is true, exactly mirroring how
// install_package refuses to open a transaction unless dependency
// resolution succeeds (this Work Package's "Trust-before-Dependency-
// before-Transaction" ordering, applied to the uninstall lifecycle: here
// impact analysis plays the role dependency resolution played for
// install).
struct RuntimeUninstallImpactResult {
    bool success = false;
    std::string error;
    bool found = false;
    int objects_affected = 0;
    int relationships_affected = 0;
    // package_ids of OTHER installed packages with a REQUIRED (non-
    // optional) dependency on the package being analyzed. Non-empty
    // means uninstalling would leave a dependent's required dependency
    // unsatisfied -- PKG-004 territory, reused here rather than
    // reimplemented (see find_required_dependents in the .cpp).
    std::vector<std::string> blocking_dependents;
    bool removable = false;
};

struct RuntimeUninstallResult {
    bool success = false;
    std::string error;
    std::string package_id;
    int objects_removed = 0;
    int relationships_removed = 0;
};

// Update Impact Analysis (WP-REP-007): the dry-run report
// analyze_update_impact produces for replacing an installed package with
// a new version from `archive_path`. Reuses Trust verification and the
// Dependency Resolution Engine exactly as install_package does (against
// the installed set with the CURRENT version of this same package
// excluded, since it is what's being replaced), plus one thing neither
// of those checks on their own: whether any OTHER installed package's
// existing REQUIRED dependency constraint on this package would become
// unsatisfied by the candidate version (`broken_dependents`).
struct RuntimeUpdateImpactResult {
    bool success = false;
    std::string error;
    bool currently_installed = false;
    std::string current_version;
    std::string candidate_version;
    std::string trust_status;
    oep::installer::DependencyResolutionReport dependency_report;
    std::vector<std::string> broken_dependents;
    // true iff currently_installed, trust does not block install,
    // dependency_report.result == Resolved, and broken_dependents is
    // empty.
    bool updatable = false;
};

struct RuntimeUpdateResult {
    bool success = false;
    std::string error;
    std::string package_id;
    std::string previous_version;
    std::string new_version;
    int objects_removed = 0;
    int relationships_removed = 0;
    int objects_created = 0;
    int relationships_created = 0;
    std::string trust_status;
};

// Merge Engine (WP-REP-008). plan_merge is side-effect-free
// (requirement #6): it extracts `archive_path`, runs Trust verification
// then Dependency Resolution against the CURRENTLY installed set —
// exactly install_package's ordering, reused unchanged — and, only if
// neither blocks it, plans the object/relationship diff via
// oep::installer::plan_merge. `mergeable` is true iff trust does not
// block, dependency resolution is Resolved, and the resulting
// MergePlan.conflicts is empty. Unlike install_package, a package
// already partially or fully present with IDENTICAL content is not an
// error -- merge is idempotent; only a REGISTRY entry already existing
// for this package_id is disallowed (merge is not update -- see
// execute_merge).
struct RuntimeMergePlanResult {
    bool success = false;
    std::string error;
    std::string package_id;
    std::string version;
    std::string trust_status;
    bool trust_blocks = false;
    oep::installer::DependencyResolutionReport dependency_report;
    bool dependency_blocks = false;
    bool already_registered = false;
    oep::installer::MergePlan plan;
    bool mergeable = false;
};

struct RuntimeMergeResult {
    bool success = false;
    std::string error;
    std::string package_id;
    std::string version;
    int objects_created = 0;
    int relationships_created = 0;
    std::string trust_status;
};

// The single entry point through which applications interact with
// Foundation. FoundationRuntime coordinates the Repository, Search,
// Validation, and Package Manager subsystems; it never reimplements
// their logic, and subsystems never locate each other directly —
// callers request services through the Runtime.
//
// Only one repository may be open within a Runtime instance at a time.
// Opening a repository establishes where Engineering Objects,
// Relationships, and Audit Events live within it:
// `<repository>/repository/objects`, `<repository>/repository/relationships`,
// and `<repository>/repository/audit`. Packages are discovered under
// `<repository>/packages`, per OEP-SPEC-002.
class FoundationRuntime {
public:
    // `foundation_version` is the Foundation version this Runtime is
    // running as, used to check package compatibility once a
    // repository is opened.
    explicit FoundationRuntime(std::string foundation_version);

    RuntimeState state() const;

    RuntimeResult initialize();
    RuntimeResult open_repository(std::filesystem::path repository_root);
    RuntimeResult close_repository();
    RuntimeResult shutdown();

    // Repository Context (OEP-SPEC-011 section 5). Available only
    // while a repository is open.
    RuntimeRepositoryPathResult current_repository() const;
    RuntimeMetadataResult current_metadata() const;
    RuntimePackageSetResult current_package_set() const;

    // Service Registry (OEP-SPEC-011 section 6). Return nullptr
    // whenever a repository is not currently open (before
    // initialization, before opening, after closing, or after shutdown).
    const oep::repository::ObjectStore* object_store() const;
    const oep::repository::RelationshipStore* relationship_store() const;
    const oep::repository::AuditStore* audit_store() const;
    const oep::search::SearchEngine* search_engine() const;
    const oep::repository::GraphEngine* graph_engine() const;
    const oep::validation::RepositoryValidator* validator() const;
    const oep::packages::PackageManager* package_manager() const;
    const oep::installer::RepositoryRegistry* repository_registry() const;
    const oep::installer::TrustStore* trust_store() const;

    // Exports the currently open repository to a single deterministic
    // archive, per OEP-SPEC-017-REPOSITORY_EXPORT. Requires a
    // repository to be open; delegates entirely to
    // oep::archive::export_repository.
    RuntimeExportResult export_repository(const std::filesystem::path& output_file, bool include_packages) const;

    // Reconstructs a repository at `destination` from a previously
    // exported archive, per OEP-SPEC-018-REPOSITORY_IMPORT. Does not
    // require (and does not use) a currently open repository —
    // `destination` is a location to create, not one to open — but is
    // exposed on FoundationRuntime so import, like every other
    // repository operation, executes through the Runtime rather than
    // the CLI reconstructing repository contents directly.
    RuntimeImportResult import_repository(const std::filesystem::path& archive_file,
                                           const std::filesystem::path& destination, bool overwrite) const;

    // Captures the currently open repository into a new template
    // stored under `templates_dir`, per OEP-SPEC-019-REPOSITORY_TEMPLATES.
    // Requires a repository to be open.
    RuntimeCreateTemplateResult create_template(const std::filesystem::path& templates_dir,
                                                 const std::string& template_name, const std::string& description,
                                                 const std::string& author, const std::vector<std::string>& tags,
                                                 bool include_packages) const;

    // Enumerates every valid template stored under `templates_dir`.
    // Does not require an open repository.
    RuntimeListTemplatesResult list_templates(const std::filesystem::path& templates_dir) const;

    // Instantiates `template_id` from `templates_dir` into a brand-new
    // repository at `destination`. Does not require (or use) a
    // currently open repository, but remains on FoundationRuntime so
    // instantiation, like every other repository operation, executes
    // through the Runtime.
    RuntimeInstantiateTemplateResult instantiate_template(const std::filesystem::path& templates_dir,
                                                           const std::string& template_id,
                                                           const std::filesystem::path& destination,
                                                           const std::string& new_repository_name) const;

    // Batch operations, per OEP-SPEC-020-BATCH_OPERATIONS. All three
    // require an open repository. Every batch is fully parsed and
    // validated before any execution begins; a validation failure
    // creates/deletes nothing.
    RuntimeBatchCreateResult execute_batch_create(const std::string& batch_json) const;
    RuntimeBatchDeleteResult execute_batch_delete(const std::string& batch_json) const;

    // Parses and validates a batch-create input without executing it.
    // success is false only for a structural/operational problem
    // (malformed JSON, no repository open); a structurally valid batch
    // with validation findings still reports success = true, with the
    // findings listed in `findings`.
    RuntimeBatchValidateResult validate_batch_create(const std::string& batch_json) const;

    // ---------------------------------------------------------------
    // Object and Relationship Mutation (Work Package 014)
    // ---------------------------------------------------------------
    //
    // Every method below requires an open repository and delegates
    // entirely to ObjectStore/RelationshipStore — no validation or
    // persistence logic is duplicated here; Runtime only orchestrates
    // which store method to call and, when a transaction is active,
    // records enough information to undo the call on rollback.
    //
    // If a transaction is active and a mutation fails, the active
    // transaction is automatically rolled back and deactivated before
    // the failure is returned — per TASK-000029, "Failures shall:
    // Abort transaction, Roll back changes." The caller does not need
    // to call rollback_transaction() again in that case (doing so is
    // safe but reports "no transaction is currently active").

    RuntimeObjectMutationResult create_object(oep::repository::ObjectType object_type, const std::string& name,
                                               const std::string& description, const std::string& author,
                                               const std::vector<std::string>& tags);

    // AP-OEP-FOUNDATION-GRAPH-IDENTITY-001 — creates an
    // ObjectType::Diagram Engineering Object: the graph/diagram identity
    // itself. A thin, dedicated wrapper over create_object rather than
    // requiring every caller to remember "pass ObjectType::Diagram" —
    // no new primitive, no new store, no duplicated persistence logic.
    RuntimeObjectMutationResult create_diagram(const std::string& name, const std::string& description,
                                                const std::string& author);

    // Loads the ObjectType::Diagram object identified by [diagram_id].
    // Fails with a not-found-shaped error if no such object exists, or
    // if an object with that id exists but is not ObjectType::Diagram
    // (never silently treats a non-diagram object as a valid graph
    // scope).
    RuntimeObjectMutationResult get_diagram(const std::string& diagram_id);

    // Same contract as create_object, plus: [diagram_id] must name an
    // existing ObjectType::Diagram object (validated before the object
    // is created — an invalid diagram_id fails the whole call, nothing
    // is persisted). The created object's diagram_id is set to
    // [diagram_id]. Participates in the same transaction/journal/
    // rollback machinery as create_object — this is not a second commit
    // mechanism, just create_object with one more field populated.
    RuntimeObjectMutationResult create_object_in_diagram(oep::repository::ObjectType object_type,
                                                          const std::string& name, const std::string& description,
                                                          const std::string& author,
                                                          const std::vector<std::string>& tags,
                                                          const std::string& diagram_id);

    // Enumerates the Engineering Objects belonging to [diagram_id]
    // (unsorted here — sorting is the API layer's job, matching
    // list_all's own division of responsibility). Fails if [diagram_id]
    // does not name an existing ObjectType::Diagram object — an empty
    // result and a "not found" result are distinguishable, per the
    // "invalid graph ID" acceptance requirement.
    RuntimeDiagramObjectsResult get_diagram_objects(const std::string& diagram_id);

    // Replaces name/description/author/tags on the object identified
    // by `object_id`; object_id, object_type, and created_utc are
    // preserved, matching ObjectStore::update's own contract exactly
    // (Runtime does not reimplement or extend it).
    RuntimeObjectMutationResult update_object(const std::string& object_id, const std::string& name,
                                               const std::string& description, const std::string& author,
                                               const std::vector<std::string>& tags);

    // Replaces only `content` on the object identified by `object_id`;
    // every other field (name, description, author, tags, object_type,
    // created_utc) is preserved from the stored object, unlike
    // update_object above, which always replaces the full editable field
    // set. A dedicated method rather than an optional parameter on
    // update_object because callers that only need to persist content
    // (e.g. Diagram Studio saving layout/viewport state on every editing
    // command) would otherwise have to re-supply name/description/author/
    // tags on every call just to leave them unchanged (AP-DS-002).
    RuntimeObjectMutationResult update_object_content(const std::string& object_id, const std::string& content);

    RuntimeResult delete_object(const std::string& object_id);

    RuntimeRelationshipMutationResult create_relationship(const std::string& source_object_id,
                                                            const std::string& target_object_id,
                                                            oep::repository::RelationshipType relationship_type,
                                                            const std::string& author, const std::string& description);

    // AP-OEP-FOUNDATION-GRAPH-IDENTITY-001 — same contract as
    // create_relationship, plus: [diagram_id] must name an existing
    // ObjectType::Diagram object (validated first; an invalid diagram_id
    // fails the whole call). Same transaction/journal/rollback
    // machinery as create_relationship.
    RuntimeRelationshipMutationResult create_relationship_in_diagram(
        const std::string& source_object_id, const std::string& target_object_id,
        oep::repository::RelationshipType relationship_type, const std::string& author,
        const std::string& description, const std::string& diagram_id);

    // Enumerates the Relationships belonging to [diagram_id] — same
    // "fails if diagram_id is invalid, unsorted result" contract as
    // get_diagram_objects.
    RuntimeDiagramRelationshipsResult get_diagram_relationships(const std::string& diagram_id);

    // Replaces author/description on the relationship identified by
    // `relationship_id`; relationship_id, source/target object IDs,
    // relationship_type, and created_utc are preserved, matching
    // RelationshipStore::update's own contract exactly.
    RuntimeRelationshipMutationResult update_relationship(const std::string& relationship_id,
                                                            const std::string& author, const std::string& description);

    RuntimeResult delete_relationship(const std::string& relationship_id);

    // ---------------------------------------------------------------
    // Transactions (Work Package 014, TASK-000029)
    // ---------------------------------------------------------------
    //
    // A transaction groups the object/relationship mutations above
    // into one deterministically reversible unit. Only one transaction
    // may be active at a time (no nesting). Each mutation still writes
    // to disk immediately, exactly as it would outside a transaction —
    // ObjectStore/RelationshipStore have no concept of a staged,
    // uncommitted write — but while a transaction is active, Runtime
    // additionally records a compensating action for every successful
    // mutation. commit_transaction() simply discards that log (the
    // mutations are already persisted); rollback_transaction() replays
    // the log in reverse, undoing each mutation via the same stores
    // (remove() undoes a create, update() undoes an update by
    // restoring the prior full record, restore() undoes a delete by
    // restoring the prior full record with its original identity).
    // This makes rollback deterministic without introducing a second,
    // parallel persistence mechanism.
    //
    // Closing the repository (close_repository()/shutdown()) while a
    // transaction is active automatically rolls it back first, so a
    // repository is never left with a transaction stranded open.

    // WP-REP-003 (Repository Transaction Engine) upgraded these
    // primitives, keeping every signature unchanged:
    //
    // - Every transaction now has a UUIDv4 transaction ID and, on close
    //   (commit, rollback, or failure), writes one permanent record to
    //   the Transaction Journal (`<repository>/logs/transactions/`,
    //   PKG-003 §15/§26), listing every journaled operation with its
    //   previous/new state.
    // - Every Runtime mutation OUTSIDE an explicit transaction now runs
    //   inside an implicit one (begun and committed automatically around
    //   the single operation), so all Repository write operations execute
    //   through Repository Transactions — including install_package,
    //   which since WP-REP-003 is atomic (see its doc comment below).
    // - commit_transaction() can now fail in exactly one new way: the
    //   journal record could not be written. The mutations themselves are
    //   already persisted in that case — the error exists so a caller
    //   knows the audit trail is incomplete, never to signal data loss.
    //   A journal problem never prevents a rollback from restoring
    //   repository state: restoring data always outranks recording
    //   history.
    //
    // Boundaries, documented rather than silently exempted:
    // `execute_batch_create`/`execute_batch_delete` (OEP-SPEC-020's
    // BatchProcessor) retain their own validate-everything-then-execute
    // atomicity and do not flow through this engine; `import_repository`/
    // `instantiate_template` construct NEW repositories rather than
    // writing to the open one, so there is no open-repository state for
    // a transaction to protect.

    RuntimeResult begin_transaction();
    RuntimeResult commit_transaction();
    RuntimeResult rollback_transaction();
    bool transaction_active() const;

    // The active transaction's identity and progress (WP-REP-003).
    // `active == false` with success == true means no transaction is
    // open — a normal answer, not an error.
    RuntimeTransactionInfoResult current_transaction_info() const;

    // Every journaled (closed) transaction for the open repository,
    // sorted by opened time then id.
    RuntimeTransactionHistoryResult transaction_history() const;

    // One journaled transaction by id, including its full entry list.
    RuntimeTransactionRecordResult get_transaction_record(const std::string& transaction_id) const;

    // ---------------------------------------------------------------
    // Batch Mutation (Work Package 014, TASK-000030)
    // ---------------------------------------------------------------
    //
    // Convenience wrappers over the transaction primitives above:
    // creates every spec in array order (the deterministic execution
    // order TASK-000030 requires) inside a transaction. If no
    // transaction is active when called, one is begun and committed
    // (or rolled back) automatically around the whole batch; if the
    // caller already has a transaction active, the batch participates
    // in it, and a failure rolls back everything in that transaction,
    // not just the batch's own entries.

    RuntimeBatchCreateObjectsResult batch_create_objects(const std::vector<ObjectCreateSpec>& specs);
    RuntimeBatchCreateRelationshipsResult batch_create_relationships(const std::vector<RelationshipCreateSpec>& specs);

    // ---------------------------------------------------------------
    // Package Installation (WP-REP-001, OEP-ARCH-002 — Repository Runtime,
    // first vertical slice)
    // ---------------------------------------------------------------
    //
    // install_package extracts archive_path (a validated .oep package,
    // PKG-001/PKG-002 — see platform/installer) and creates its Repository
    // Fragment's Engineering Objects, then its Relationships, via the
    // already-open repository's own ObjectStore/RelationshipStore —
    // exactly as create_object/create_relationship above already do, just
    // driven by extracted archive content instead of caller-supplied
    // fields. Records the install in the Repository Registry and rebuilds
    // the Search/Graph indexes on success, mirroring open_repository's own
    // index-build step.
    //
    // ATOMIC since WP-REP-003 (Repository Transaction Engine): the whole
    // install runs inside a Repository Transaction — a failure partway
    // through (an invalid object, a failing Repository Registry write)
    // rolls back every object/relationship the install had already
    // created, and the transaction is journaled (RolledBack) either way.
    // This supersedes WP-REP-001/002's documented non-transactional
    // behavior; RuntimeInstallResult::objects_created/relationships_created
    // are therefore always 0 when success is false. Fails outright
    // (creates nothing) if the package is already recorded in the
    // Repository Registry, since there is no update path yet. Fails with
    // "a transaction is already active" if called inside an explicit
    // caller transaction — an install is its own transaction, never a
    // participant in someone else's (no nesting, per Work Package 014).
    //
    // TRUST-VERIFIED since WP-REP-004 (Trust & Signing): before any
    // Repository Transaction begins, the archive is verified against the
    // Trust Store (oep::installer::verify_package_trust — structure,
    // content hashes, certificate, Ed25519 signature, per PKG-005 §11).
    // An archive that is Tampered, InvalidSignature, UnknownPublisher,
    // ExpiredCertificate, or RevokedCertificate is rejected outright —
    // nothing is extracted-and-installed, and no transaction is ever
    // opened. An Unsigned archive installs exactly as before UNLESS the
    // Trust Store's policy requires signatures
    // (TrustStore::get_policy().require_signatures), preserving
    // WP-REP-001–003's default unsigned-install behavior. On success or
    // a trust failure, RuntimeInstallResult::trust_status names the
    // resolved TrustState.
    //
    // DEPENDENCY-RESOLVED since WP-REP-005 (Dependency Resolution
    // Engine): immediately after trust verification succeeds and still
    // BEFORE any Repository Transaction begins, the manifest's declared
    // dependencies are resolved (oep::installer::resolve_dependencies)
    // against the currently installed set. A Failed resolution (a
    // missing required dependency, an unsatisfied version constraint, or
    // a circular dependency, per PKG-004 §6/§10) rejects the install
    // outright — nothing is extracted, no transaction is ever opened.
    // The DRE never downloads or acquires anything (PKG-004 §17); a
    // missing dependency is reported, never fetched. See
    // resolve_package_dependencies() below for the same resolution as a
    // standalone, side-effect-free query.
    RuntimeInstallResult install_package(const std::filesystem::path& archive_path);

    // Lists every package the Repository Registry has recorded as
    // installed.
    RuntimeInstalledPackagesResult list_installed_packages() const;

    // ---------------------------------------------------------------
    // Package Uninstall (WP-REP-007)
    // ---------------------------------------------------------------
    //
    // Removes every Engineering Object/Relationship `package_id`
    // contributed at install time, then its Repository Registry record.
    // ATOMIC: the whole uninstall runs inside one Repository Transaction
    // (reusing the Transaction Engine exactly as install_package does),
    // so a failure partway through rolls back every delete already
    // performed. Fails outright (removes nothing, opens no transaction)
    // if the package is not installed, or if any OTHER installed
    // package has a REQUIRED dependency on it (see
    // analyze_uninstall_impact) -- this Work Package does not implement
    // a --force override; that remains for a future work package
    // alongside ownership policies. Fails with "a transaction is
    // already active" if called inside an explicit caller transaction,
    // matching install_package's own no-nesting rule.

    // Read-only, side-effect-free pre-flight check (PKG-004 §2's
    // "side-effect free" applied to uninstall): reports what
    // uninstall_package WOULD do, without doing it. Requires an open
    // repository. Fails (success == false) only for an operational
    // problem (no repository open, unreadable registry); a package that
    // cannot be safely uninstalled still returns success == true, with
    // `removable == false` and `blocking_dependents` populated.
    RuntimeUninstallImpactResult analyze_uninstall_impact(const std::string& package_id) const;

    RuntimeUninstallResult uninstall_package(const std::string& package_id);

    // ---------------------------------------------------------------
    // Package Update (WP-REP-007)
    // ---------------------------------------------------------------
    //
    // Replaces the currently-installed version of `archive_path`'s
    // package with the version `archive_path` declares, as ONE atomic
    // Repository Transaction (reusing the Transaction Engine): removes
    // the old version's contributed Objects/Relationships and Registry
    // record, then installs the new version exactly as install_package
    // would, all inside a single transaction so a failure at any point
    // rolls back the ENTIRE update (the repository is never left with
    // neither version, nor both). TRUST-VERIFIED and
    // DEPENDENCY-RESOLVED before the transaction opens, in that order,
    // exactly like install_package -- and additionally refuses to
    // proceed if any OTHER installed package's required dependency on
    // this package would become unsatisfied by the candidate version
    // (see analyze_update_impact). Fails outright if the package is not
    // currently installed (this is not install_package -- there is
    // nothing to replace) or if a transaction is already active.

    // Read-only, side-effect-free pre-flight check: reports what
    // update_package WOULD do, without doing it. Requires an open
    // repository. Fails (success == false) only if the archive itself
    // could not be read/parsed, or no repository is open.
    RuntimeUpdateImpactResult analyze_update_impact(const std::filesystem::path& archive_path) const;

    RuntimeUpdateResult update_package(const std::filesystem::path& archive_path);

    // ---------------------------------------------------------------
    // Merge Engine (WP-REP-008)
    // ---------------------------------------------------------------
    //
    // Merges `archive_path`'s Repository Fragment (objects/relationships)
    // into the currently open repository via the canonical
    // RepositoryChangeSet (oep::installer::RepositoryChangeSet),
    // generalizing install_package: rather than assuming the content is
    // entirely new and failing hard on the first collision,
    // execute_merge first PLANS (see plan_merge) a conflict-free subset,
    // then applies it -- ONE Repository Transaction, reusing the
    // Transaction Engine exactly as install/uninstall/update do. Refuses
    // outright (opens no transaction) if the plan is not mergeable
    // (blocked by trust, by dependency resolution, or by any detected
    // conflict) or if the package_id is already recorded in the
    // Repository Registry (merge is not update -- see update_package for
    // replacing an installed package's version).

    // Read-only, side-effect-free (WP-REP-008 requirement #6). Requires
    // an open repository. Fails (success == false) only for an
    // operational problem (archive unreadable, no repository open); a
    // plan that is not mergeable on its own merits (trust/dependency/
    // conflicts) still returns success == true with `mergeable == false`.
    RuntimeMergePlanResult plan_merge(const std::filesystem::path& archive_path) const;

    RuntimeMergeResult execute_merge(const std::filesystem::path& archive_path);

    // ---------------------------------------------------------------
    // Dependency Resolution (WP-REP-005)
    // ---------------------------------------------------------------
    //
    // Resolves `archive_path`'s manifest dependencies against the
    // currently installed set WITHOUT installing anything — a pure,
    // read-only, side-effect-free query (PKG-004 §2), usable as a
    // pre-flight check before install_package, or purely for
    // inspection/diagnostics (`oep package resolve`). Requires an open
    // repository. Fails (success == false) only if the archive itself
    // could not be read or its manifest is invalid; a resolution that
    // fails on its own merits (missing/conflicting/cyclic) still
    // returns success == true, with the verdict in `report.result`.
    RuntimeDependencyResolutionResult resolve_package_dependencies(const std::filesystem::path& archive_path) const;

    // ---------------------------------------------------------------
    // Package Lifecycle Queries (WP-REP-002 §5/§6)
    // ---------------------------------------------------------------
    //
    // Read-only services over the Repository Registry (and, where noted,
    // the open repository's own stores). All require an open repository.
    // None of them mutate anything — update/uninstall/activation remain
    // explicitly out of scope through WP-REP-002.

    // "Query package metadata" / "Query installation state": the full
    // Repository Registry entry for `package_id`, if installed.
    // "Not installed" is a normal result (`installed == false`), not an
    // error.
    RuntimeInstalledPackageResult get_installed_package(const std::string& package_id) const;

    // "Query package ownership" / "Locate installed objects": which
    // installed package (if any) contributed the Engineering Object or
    // Relationship identified by `entity_id`.
    RuntimePackageOwnerResult find_package_owner(const std::string& entity_id) const;

    // "Verify installation status": confirms every contribution the
    // Repository Registry recorded for `package_id` still exists in the
    // open repository, and — if the source archive still exists at its
    // recorded installation path — that its bytes still match the
    // recorded SHA-256. See RuntimeVerifyPackageResult for the exact
    // semantics. Fails (success == false) only for an operational
    // problem (no repository open, package not installed, unreadable
    // registry); a package that fails verification still reports
    // success == true with verified == false and findings populated.
    RuntimeVerifyPackageResult verify_package(const std::string& package_id) const;

    // Repository Index (WP-REP-002 §8): installed packages matching
    // `query` — a case-insensitive substring match over each entry's
    // package ID, title, summary, category, version, publisher, and
    // engineering domains (RepositoryRegistry::search_packages), plus
    // the names of the Engineering Objects each package installed
    // (cross-referenced live against the open repository's ObjectStore,
    // so object names are never duplicated into the registry).
    RuntimeSearchPackagesResult search_installed_packages(const std::string& query) const;

    // ---------------------------------------------------------------
    // Trust & Signing (WP-REP-004)
    // ---------------------------------------------------------------
    //
    // The Trust Store (`oep::installer::TrustStore`) holds the
    // repository's locally trusted publisher certificates, entirely
    // offline (PKG-005 §3) — there is no certificate authority chain or
    // online revocation service; trust is established by explicit local
    // action (adding/revoking a certificate) or by the caller/CLI. These
    // methods are direct pass-throughs; they never touch a
    // Repository Transaction, since they mutate `settings/trust/`, not
    // repository content.

    RuntimeTrustResult trust_add_certificate(const oep::installer::PublisherCertificate& certificate) const;
    RuntimeCertificateResult trust_get_certificate(const std::string& publisher_id) const;
    RuntimeCertificateListResult trust_list_certificates() const;
    RuntimeTrustResult trust_revoke_certificate(const std::string& publisher_id) const;
    RuntimeTrustPolicyResult trust_get_policy() const;
    RuntimeTrustResult trust_set_policy(bool require_signatures) const;

private:
    RuntimeState state_ = RuntimeState::Uninitialized;
    std::string foundation_version_;

    std::filesystem::path repository_root_;
    std::optional<oep::repository::RepositoryMetadata> metadata_;
    std::optional<oep::repository::AuditStore> audit_;
    std::optional<oep::repository::ObjectStore> objects_;
    std::optional<oep::repository::RelationshipStore> relationships_;
    std::optional<oep::search::SearchEngine> search_;
    std::optional<oep::repository::GraphEngine> graph_;
    std::optional<oep::validation::RepositoryValidator> validator_;
    std::optional<oep::packages::PackageManager> packages_;
    std::optional<oep::installer::RepositoryRegistry> registry_;
    std::optional<oep::installer::TrustStore> trust_store_;

    // A single compensating action recorded while a transaction is
    // active, per mutation performed. Exactly one of object_snapshot /
    // relationship_snapshot is meaningful for a given `kind`; which one
    // is documented next to each Kind value below.
    struct TransactionLogEntry {
        enum class Kind {
            ObjectCreated,        // undo: remove(object_snapshot.object_id)
            ObjectUpdated,        // undo: update(object_snapshot) — the pre-update record
            ObjectDeleted,        // undo: restore(object_snapshot) — the pre-delete record
            RelationshipCreated,  // undo: remove(relationship_snapshot.relationship_id)
            RelationshipUpdated,  // undo: update(relationship_snapshot) — the pre-update record
            RelationshipDeleted,  // undo: restore(relationship_snapshot) — the pre-delete record
        };
        Kind kind;
        oep::repository::EngineeringObject object_snapshot;
        oep::repository::Relationship relationship_snapshot;
    };

    bool transaction_active_ = false;
    std::vector<TransactionLogEntry> transaction_log_;

    // The active transaction's journal-facing identity (WP-REP-003):
    // id, description, open time, and the entries accumulated so far.
    // Only meaningful while transaction_active_ is true.
    TransactionRecord current_transaction_;
    std::optional<TransactionJournal> journal_;

    void reset_repository_context();

    // Undoes every recorded entry in transaction_log_, most recent
    // first, then clears the log and deactivates the transaction.
    // Assumes objects_/relationships_ are still valid (must be called
    // before reset_repository_context() clears them, not after).
    // Writes the transaction's journal record (RolledBack) best-effort.
    void rollback_transaction_internal();

    // Opens a transaction (id/description/opened timestamp, clears
    // logs). Precondition: repository open, no transaction active.
    void open_transaction_internal(const std::string& description);

    // Closes the active transaction as Committed: discards the undo log
    // and writes the journal record. Fails only if the journal record
    // could not be written (mutations remain persisted regardless).
    RuntimeResult commit_transaction_internal();

    // Appends one journal entry to the active transaction. No-op when
    // no transaction is active (callers always run inside one, explicit
    // or implicit — this guard is belt-and-braces).
    void journal_operation(const std::string& operation, const std::string& target_id,
                            const std::string& previous_state, const std::string& new_state);

    // Adapts the Repository Registry's currently installed packages into
    // the shape the Dependency Resolution Engine consumes (WP-REP-005).
    // Requires a repository to be open.
    std::vector<oep::installer::InstalledPackageSnapshot> installed_snapshot_for_resolver() const;

    // Every OTHER installed package (package_id != exclude_package_id)
    // that declares a REQUIRED (non-optional) dependency on
    // `target_package_id`. When `candidate_version` is non-empty, a
    // dependent is only included if its version_constraint would NOT be
    // satisfied by `candidate_version` (WP-REP-007's update-impact
    // check); when empty, EVERY required dependent is included
    // regardless of constraint (WP-REP-007's uninstall-impact check,
    // where there is no replacement version to satisfy anything).
    // Reuses oep::installer::version_satisfies rather than reimplementing
    // constraint matching.
    std::vector<std::string> find_required_dependents(const std::string& target_package_id,
                                                        const std::string& exclude_package_id,
                                                        const std::string& candidate_version) const;
};

} // namespace oep::runtime
