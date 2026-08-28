#include "oep_api_internal.hpp"

#include "oep/runtime/foundation_version.hpp"

namespace {

// Defined further below (owned-heap-string helper, shared by every
// unbounded-text export function in this file, itself nested inside an
// `extern "C" { ... }` block further down — matched here via an
// explicit linkage-specification so this forward declaration doesn't
// conflict with that later C-linkage definition); forward-declared
// here so oep_object_get_content (AP-DS-002) can call it despite
// appearing earlier in the file than the export functions that
// originally introduced it.
extern "C" char* copy_owned_string(const std::string& text, std::size_t* out_length);

oep_runtime_state_t to_capi_state(oep::runtime::RuntimeState state) {
    switch (state) {
        case oep::runtime::RuntimeState::Uninitialized: return OEP_STATE_UNINITIALIZED;
        case oep::runtime::RuntimeState::Initialized: return OEP_STATE_INITIALIZED;
        case oep::runtime::RuntimeState::RepositoryOpen: return OEP_STATE_REPOSITORY_OPEN;
        case oep::runtime::RuntimeState::RepositoryClosed: return OEP_STATE_REPOSITORY_CLOSED;
        case oep::runtime::RuntimeState::Shutdown: return OEP_STATE_SHUTDOWN;
    }
    return OEP_STATE_UNINITIALIZED;
}

void zero_status(oep_repository_status_t* out_status) {
    out_status->repository_open = 0;
    out_status->repository_id[0] = '\0';
    out_status->repository_name[0] = '\0';
    out_status->repository_version[0] = '\0';
    out_status->loaded_package_count = 0;
}

void zero_object_info(oep_object_info_t* out_object) {
    out_object->object_id[0] = '\0';
    out_object->object_type = OEP_OBJECT_TYPE_DOCUMENT;
    out_object->name[0] = '\0';
    out_object->author[0] = '\0';
    out_object->version[0] = '\0';
    out_object->description[0] = '\0';
    out_object->tag_count = 0;
    for (int i = 0; i < OEP_MAX_OBJECT_TAGS; ++i) {
        out_object->tags[i][0] = '\0';
    }
}

void zero_object_list(oep_object_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_statistics(oep_repository_statistics_t* out_statistics) {
    out_statistics->repository_id[0] = '\0';
    out_statistics->repository_name[0] = '\0';
    out_statistics->repository_version[0] = '\0';
    out_statistics->total_object_count = 0;
    for (int i = 0; i < OEP_OBJECT_TYPE_COUNT; ++i) {
        out_statistics->object_count_by_type[i] = 0;
    }
    out_statistics->relationship_count = 0;
    out_statistics->package_count = 0;
}

void zero_relationship_info(oep_relationship_info_t* out_relationship) {
    out_relationship->relationship_id[0] = '\0';
    out_relationship->source_object_id[0] = '\0';
    out_relationship->target_object_id[0] = '\0';
    out_relationship->relationship_type = OEP_RELATIONSHIP_TYPE_REFERENCES;
    out_relationship->author[0] = '\0';
    out_relationship->description[0] = '\0';
    out_relationship->created_utc[0] = '\0';
}

void zero_relationship_list(oep_relationship_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_object_search_result_list(oep_object_search_result_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_relationship_search_result_list(oep_relationship_search_result_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_repository_search_result(oep_repository_search_result_t* out_result) {
    zero_object_search_result_list(&out_result->objects);
    zero_relationship_search_result_list(&out_result->relationships);
}

void zero_batch_create_objects_result(oep_batch_create_objects_result_t* out_result) {
    out_result->success = 0;
    out_result->failed_index = -1;
    out_result->created.items = nullptr;
    out_result->created.count = 0;
}

void zero_batch_create_relationships_result(oep_batch_create_relationships_result_t* out_result) {
    out_result->success = 0;
    out_result->failed_index = -1;
    out_result->created.items = nullptr;
    out_result->created.count = 0;
}

// Builds a std::vector<std::string> from a C `tags`/`tag_count` pair,
// treating a NULL individual entry as an empty string (never
// dereferencing a NULL char*). Shared by oep_object_create,
// oep_object_update, and the batch object-create path.
std::vector<std::string> tags_from_capi(const char* const* tags, int tag_count) {
    std::vector<std::string> result;
    for (int i = 0; i < tag_count; ++i) {
        result.emplace_back(tags != nullptr && tags[i] != nullptr ? tags[i] : "");
    }
    return result;
}

} // namespace

namespace oep::api::detail {

void copy_truncated(const std::string& text, char* buffer, std::size_t buffer_size) {
    if (buffer == nullptr || buffer_size == 0) {
        return;
    }
    const std::size_t copy_length = text.size() < buffer_size - 1 ? text.size() : buffer_size - 1;
    std::memcpy(buffer, text.data(), copy_length);
    buffer[copy_length] = '\0';
}

oep_error_category_t category_for_code(oep_error_code_t code) {
    switch (code) {
        case OEP_ERROR_NONE: return OEP_ERROR_CATEGORY_NONE;
        case OEP_ERROR_INVALID_ARGUMENT: return OEP_ERROR_CATEGORY_VALIDATION;
        case OEP_ERROR_INVALID_STATE: return OEP_ERROR_CATEGORY_STATE;
        case OEP_ERROR_NOT_FOUND: return OEP_ERROR_CATEGORY_IO;
        case OEP_ERROR_OPERATION_FAILED: return OEP_ERROR_CATEGORY_IO;
        case OEP_ERROR_INTERNAL: return OEP_ERROR_CATEGORY_INTERNAL;
    }
    return OEP_ERROR_CATEGORY_INTERNAL;
}

oep_result_t make_success_result() {
    oep_result_t result{};
    result.success = 1;
    result.error_code = OEP_ERROR_NONE;
    result.error_category = OEP_ERROR_CATEGORY_NONE;
    result.error_message[0] = '\0';
    return result;
}

oep_result_t make_error_result(oep_error_code_t code, oep_error_category_t category, const std::string& message) {
    oep_result_t result{};
    result.success = 0;
    result.error_code = code;
    result.error_category = category;
    copy_truncated(message, result.error_message, OEP_MAX_ERROR_MESSAGE);
    return result;
}

oep_object_type_t to_capi_object_type(oep::repository::ObjectType type) {
    switch (type) {
        case oep::repository::ObjectType::Document: return OEP_OBJECT_TYPE_DOCUMENT;
        case oep::repository::ObjectType::Diagram: return OEP_OBJECT_TYPE_DIAGRAM;
        case oep::repository::ObjectType::Component: return OEP_OBJECT_TYPE_COMPONENT;
        case oep::repository::ObjectType::Procedure: return OEP_OBJECT_TYPE_PROCEDURE;
        case oep::repository::ObjectType::Project: return OEP_OBJECT_TYPE_PROJECT;
        case oep::repository::ObjectType::Image: return OEP_OBJECT_TYPE_IMAGE;
    }
    return OEP_OBJECT_TYPE_DOCUMENT;
}

void populate_object_info(const oep::repository::EngineeringObject& object, oep_object_info_t* out_object) {
    copy_truncated(object.object_id, out_object->object_id, sizeof(out_object->object_id));
    out_object->object_type = to_capi_object_type(object.object_type);
    copy_truncated(object.name, out_object->name, sizeof(out_object->name));
    copy_truncated(object.author, out_object->author, sizeof(out_object->author));
    copy_truncated(object.version, out_object->version, sizeof(out_object->version));
    copy_truncated(object.description, out_object->description, sizeof(out_object->description));

    const int tag_count =
        static_cast<int>(object.tags.size()) < OEP_MAX_OBJECT_TAGS ? static_cast<int>(object.tags.size())
                                                                    : OEP_MAX_OBJECT_TAGS;
    out_object->tag_count = tag_count;
    for (int i = 0; i < tag_count; ++i) {
        copy_truncated(object.tags[static_cast<std::size_t>(i)], out_object->tags[i], OEP_MAX_TAG_LENGTH);
    }
    for (int i = tag_count; i < OEP_MAX_OBJECT_TAGS; ++i) {
        out_object->tags[i][0] = '\0';
    }
    copy_truncated(object.diagram_id, out_object->diagram_id, sizeof(out_object->diagram_id));
}

oep_relationship_type_t to_capi_relationship_type(oep::repository::RelationshipType type) {
    switch (type) {
        case oep::repository::RelationshipType::References: return OEP_RELATIONSHIP_TYPE_REFERENCES;
        case oep::repository::RelationshipType::Contains: return OEP_RELATIONSHIP_TYPE_CONTAINS;
        case oep::repository::RelationshipType::DependsOn: return OEP_RELATIONSHIP_TYPE_DEPENDS_ON;
        case oep::repository::RelationshipType::ConnectedTo: return OEP_RELATIONSHIP_TYPE_CONNECTED_TO;
        case oep::repository::RelationshipType::Documents: return OEP_RELATIONSHIP_TYPE_DOCUMENTS;
        case oep::repository::RelationshipType::Implements: return OEP_RELATIONSHIP_TYPE_IMPLEMENTS;
    }
    return OEP_RELATIONSHIP_TYPE_REFERENCES;
}

void populate_relationship_info(const oep::repository::Relationship& relationship,
                                 oep_relationship_info_t* out_relationship) {
    copy_truncated(relationship.relationship_id, out_relationship->relationship_id,
                   sizeof(out_relationship->relationship_id));
    copy_truncated(relationship.source_object_id, out_relationship->source_object_id,
                   sizeof(out_relationship->source_object_id));
    copy_truncated(relationship.target_object_id, out_relationship->target_object_id,
                   sizeof(out_relationship->target_object_id));
    out_relationship->relationship_type = to_capi_relationship_type(relationship.relationship_type);
    copy_truncated(relationship.author, out_relationship->author, sizeof(out_relationship->author));
    copy_truncated(relationship.description, out_relationship->description, sizeof(out_relationship->description));
    copy_truncated(relationship.created_utc, out_relationship->created_utc, sizeof(out_relationship->created_utc));
    copy_truncated(relationship.diagram_id, out_relationship->diagram_id, sizeof(out_relationship->diagram_id));
}

oep_match_location_t to_capi_match_location(oep::search::MatchLocation location) {
    switch (location) {
        case oep::search::MatchLocation::Name: return OEP_MATCH_LOCATION_NAME;
        case oep::search::MatchLocation::Description: return OEP_MATCH_LOCATION_DESCRIPTION;
        case oep::search::MatchLocation::Author: return OEP_MATCH_LOCATION_AUTHOR;
        case oep::search::MatchLocation::Tags: return OEP_MATCH_LOCATION_TAGS;
        case oep::search::MatchLocation::ObjectType: return OEP_MATCH_LOCATION_OBJECT_TYPE;
        case oep::search::MatchLocation::RelationshipType: return OEP_MATCH_LOCATION_RELATIONSHIP_TYPE;
    }
    return OEP_MATCH_LOCATION_NAME;
}

void populate_object_search_result(const oep::search::ObjectSearchResult& result,
                                    oep_object_search_result_t* out_result) {
    copy_truncated(result.object_id, out_result->object_id, sizeof(out_result->object_id));
    out_result->object_type = to_capi_object_type(result.object_type);
    copy_truncated(result.display_name, out_result->display_name, sizeof(out_result->display_name));
    out_result->match_location = to_capi_match_location(result.match_location);
    out_result->match_score = result.match_score;
}

void populate_relationship_search_result(const oep::search::RelationshipSearchResult& result,
                                          oep_relationship_search_result_t* out_result) {
    copy_truncated(result.relationship_id, out_result->relationship_id, sizeof(out_result->relationship_id));
    copy_truncated(result.source_object_id, out_result->source_object_id, sizeof(out_result->source_object_id));
    copy_truncated(result.target_object_id, out_result->target_object_id, sizeof(out_result->target_object_id));
    out_result->relationship_type = to_capi_relationship_type(result.relationship_type);
    out_result->match_location = to_capi_match_location(result.match_location);
    out_result->match_score = result.match_score;
}

std::optional<oep::repository::ObjectType> from_capi_object_type(oep_object_type_t type) {
    switch (type) {
        case OEP_OBJECT_TYPE_DOCUMENT: return oep::repository::ObjectType::Document;
        case OEP_OBJECT_TYPE_DIAGRAM: return oep::repository::ObjectType::Diagram;
        case OEP_OBJECT_TYPE_COMPONENT: return oep::repository::ObjectType::Component;
        case OEP_OBJECT_TYPE_PROCEDURE: return oep::repository::ObjectType::Procedure;
        case OEP_OBJECT_TYPE_PROJECT: return oep::repository::ObjectType::Project;
        case OEP_OBJECT_TYPE_IMAGE: return oep::repository::ObjectType::Image;
    }
    return std::nullopt;
}

std::optional<oep::repository::RelationshipType> from_capi_relationship_type(oep_relationship_type_t type) {
    switch (type) {
        case OEP_RELATIONSHIP_TYPE_REFERENCES: return oep::repository::RelationshipType::References;
        case OEP_RELATIONSHIP_TYPE_CONTAINS: return oep::repository::RelationshipType::Contains;
        case OEP_RELATIONSHIP_TYPE_DEPENDS_ON: return oep::repository::RelationshipType::DependsOn;
        case OEP_RELATIONSHIP_TYPE_CONNECTED_TO: return oep::repository::RelationshipType::ConnectedTo;
        case OEP_RELATIONSHIP_TYPE_DOCUMENTS: return oep::repository::RelationshipType::Documents;
        case OEP_RELATIONSHIP_TYPE_IMPLEMENTS: return oep::repository::RelationshipType::Implements;
    }
    return std::nullopt;
}

oep_error_code_t classify_mutation_error(const std::string& message) {
    if (message.find("does not exist") != std::string::npos ||
        message.find("no object with id") != std::string::npos ||
        message.find("no relationship with id") != std::string::npos) {
        return OEP_ERROR_NOT_FOUND;
    }
    if (message.find("refusing to create invalid") != std::string::npos ||
        message.find("refusing to save invalid") != std::string::npos ||
        message.find("refusing to restore invalid") != std::string::npos) {
        return OEP_ERROR_INVALID_ARGUMENT;
    }
    return OEP_ERROR_OPERATION_FAILED;
}

// AP-OEP-FOUNDATION-GRAPH-IDENTITY-001 — classify_mutation_error's
// existing patterns don't recognize "invalid diagram_id: ..." (a message
// this task's own Runtime methods construct, not one of the pre-existing
// store-level messages that function's patterns were written against),
// so it would otherwise fall through to the generic OEP_ERROR_OPERATION_FAILED
// default rather than the OEP_ERROR_INVALID_ARGUMENT this API's own doc
// comment promises for an invalid diagram_id. A small, explicit prefix
// check here — rather than trying to make one shared string-classifier
// recognize every caller's message shape — keeps classify_mutation_error
// itself unchanged for the mutation paths that already worked.
oep_error_code_t classify_diagram_mutation_error(const std::string& message) {
    if (message.rfind("invalid diagram_id:", 0) == 0) {
        return OEP_ERROR_INVALID_ARGUMENT;
    }
    return classify_mutation_error(message);
}

} // namespace oep::api::detail

using oep::api::detail::category_for_code;
using oep::api::detail::classify_diagram_mutation_error;
using oep::api::detail::classify_mutation_error;
using oep::api::detail::from_capi_object_type;
using oep::api::detail::from_capi_relationship_type;
using oep::api::detail::make_error_result;
using oep::api::detail::make_success_result;
using oep::api::detail::populate_object_info;
using oep::api::detail::populate_object_search_result;
using oep::api::detail::populate_relationship_info;
using oep::api::detail::populate_relationship_search_result;

namespace {

oep_result_t validate_search_arguments(OEP_Runtime runtime, const char* query) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (query == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "query is null");
    }
    if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "no repository is currently open");
    }
    return make_success_result();
}

oep_object_search_result_list_t build_object_search_result_list(const oep::search::SearchObjectsResult& searched) {
    const int count = static_cast<int>(searched.results.size());
    oep_object_search_result_t* items =
        count > 0 ? new oep_object_search_result_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        populate_object_search_result(searched.results[static_cast<std::size_t>(i)], &items[i]);
    }
    oep_object_search_result_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

oep_relationship_search_result_list_t build_relationship_search_result_list(
    const oep::search::SearchRelationshipsResult& searched) {
    const int count = static_cast<int>(searched.results.size());
    oep_relationship_search_result_t* items =
        count > 0 ? new oep_relationship_search_result_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        populate_relationship_search_result(searched.results[static_cast<std::size_t>(i)], &items[i]);
    }
    oep_relationship_search_result_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

void zero_package_install_result(oep_package_install_result_t* out_result) {
    out_result->package_id[0] = '\0';
    out_result->version[0] = '\0';
    out_result->objects_created = 0;
    out_result->relationships_created = 0;
}

void zero_installed_package_list(oep_installed_package_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void populate_installed_package_info(const oep::installer::RepositoryRegistryEntry& record,
                                      oep_installed_package_info_t* out_info) {
    oep::api::detail::copy_truncated(record.package_id, out_info->package_id, sizeof(out_info->package_id));
    oep::api::detail::copy_truncated(record.version, out_info->version, sizeof(out_info->version));
    oep::api::detail::copy_truncated(record.title, out_info->title, sizeof(out_info->title));
    oep::api::detail::copy_truncated(record.installed_utc, out_info->installed_utc, sizeof(out_info->installed_utc));
    oep::api::detail::copy_truncated(record.source, out_info->source, sizeof(out_info->source));
    out_info->object_count = static_cast<int>(record.object_ids.size());
    out_info->relationship_count = static_cast<int>(record.relationship_ids.size());
}

void zero_package_details(oep_package_details_t* out_details) {
    out_details->package_id[0] = '\0';
    out_details->version[0] = '\0';
    out_details->title[0] = '\0';
    out_details->summary[0] = '\0';
    out_details->category[0] = '\0';
    out_details->publisher_id[0] = '\0';
    out_details->publisher_name[0] = '\0';
    out_details->installed_utc[0] = '\0';
    out_details->source[0] = '\0';
    out_details->installation_path[0] = '\0';
    out_details->package_hash[0] = '\0';
    out_details->runtime_state[0] = '\0';
    out_details->engineering_domain_count = 0;
    for (int i = 0; i < OEP_MAX_PACKAGE_DOMAINS; ++i) {
        out_details->engineering_domains[i][0] = '\0';
    }
    out_details->object_count = 0;
    out_details->relationship_count = 0;
}

void populate_package_details(const oep::installer::RepositoryRegistryEntry& entry,
                               oep_package_details_t* out_details) {
    oep::api::detail::copy_truncated(entry.package_id, out_details->package_id, sizeof(out_details->package_id));
    oep::api::detail::copy_truncated(entry.version, out_details->version, sizeof(out_details->version));
    oep::api::detail::copy_truncated(entry.title, out_details->title, sizeof(out_details->title));
    oep::api::detail::copy_truncated(entry.summary, out_details->summary, sizeof(out_details->summary));
    oep::api::detail::copy_truncated(entry.category, out_details->category, sizeof(out_details->category));
    oep::api::detail::copy_truncated(entry.publisher_id, out_details->publisher_id,
                                      sizeof(out_details->publisher_id));
    oep::api::detail::copy_truncated(entry.publisher_name, out_details->publisher_name,
                                      sizeof(out_details->publisher_name));
    oep::api::detail::copy_truncated(entry.installed_utc, out_details->installed_utc,
                                      sizeof(out_details->installed_utc));
    oep::api::detail::copy_truncated(entry.source, out_details->source, sizeof(out_details->source));
    oep::api::detail::copy_truncated(entry.installation_path, out_details->installation_path,
                                      sizeof(out_details->installation_path));
    oep::api::detail::copy_truncated(entry.package_hash, out_details->package_hash,
                                      sizeof(out_details->package_hash));
    oep::api::detail::copy_truncated(entry.runtime_state, out_details->runtime_state,
                                      sizeof(out_details->runtime_state));

    const int domain_count = static_cast<int>(entry.engineering_domains.size()) < OEP_MAX_PACKAGE_DOMAINS
                                 ? static_cast<int>(entry.engineering_domains.size())
                                 : OEP_MAX_PACKAGE_DOMAINS;
    out_details->engineering_domain_count = domain_count;
    for (int i = 0; i < domain_count; ++i) {
        oep::api::detail::copy_truncated(entry.engineering_domains[static_cast<std::size_t>(i)],
                                          out_details->engineering_domains[i], OEP_MAX_PACKAGE_DOMAIN_LENGTH);
    }
    for (int i = domain_count; i < OEP_MAX_PACKAGE_DOMAINS; ++i) {
        out_details->engineering_domains[i][0] = '\0';
    }

    out_details->object_count = static_cast<int>(entry.object_ids.size());
    out_details->relationship_count = static_cast<int>(entry.relationship_ids.size());
}

void zero_package_owner(oep_package_owner_t* out_owner) {
    out_owner->found = 0;
    out_owner->kind = OEP_OWNED_ENTITY_NONE;
    out_owner->package_id[0] = '\0';
    out_owner->version[0] = '\0';
    out_owner->title[0] = '\0';
}

void zero_transaction_info(oep_transaction_info_t* out_info) {
    out_info->active = 0;
    out_info->transaction_id[0] = '\0';
    out_info->description[0] = '\0';
    out_info->journal_entry_count = 0;
}

void zero_transaction_record_list(oep_transaction_record_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void populate_transaction_record(const oep::runtime::TransactionRecord& record,
                                  oep_transaction_record_t* out_record) {
    oep::api::detail::copy_truncated(record.transaction_id, out_record->transaction_id,
                                      sizeof(out_record->transaction_id));
    oep::api::detail::copy_truncated(oep::runtime::to_string(record.state), out_record->state,
                                      sizeof(out_record->state));
    oep::api::detail::copy_truncated(record.description, out_record->description, sizeof(out_record->description));
    oep::api::detail::copy_truncated(record.opened_utc, out_record->opened_utc, sizeof(out_record->opened_utc));
    oep::api::detail::copy_truncated(record.closed_utc, out_record->closed_utc, sizeof(out_record->closed_utc));
    out_record->journal_entry_count = static_cast<int>(record.entries.size());
}

oep_trust_state_t to_capi_trust_state(oep::installer::TrustState state) {
    switch (state) {
        case oep::installer::TrustState::Trusted: return OEP_TRUST_TRUSTED;
        case oep::installer::TrustState::Unsigned: return OEP_TRUST_UNSIGNED;
        case oep::installer::TrustState::UnknownPublisher: return OEP_TRUST_UNKNOWN_PUBLISHER;
        case oep::installer::TrustState::ExpiredCertificate: return OEP_TRUST_EXPIRED_CERTIFICATE;
        case oep::installer::TrustState::RevokedCertificate: return OEP_TRUST_REVOKED_CERTIFICATE;
        case oep::installer::TrustState::InvalidSignature: return OEP_TRUST_INVALID_SIGNATURE;
        case oep::installer::TrustState::Tampered: return OEP_TRUST_TAMPERED;
    }
    return OEP_TRUST_INVALID_SIGNATURE;
}

oep::installer::TrustState from_capi_trust_state_name(const std::string& name) {
    if (name == "Trusted") return oep::installer::TrustState::Trusted;
    if (name == "UnknownPublisher") return oep::installer::TrustState::UnknownPublisher;
    if (name == "ExpiredCertificate") return oep::installer::TrustState::ExpiredCertificate;
    if (name == "RevokedCertificate") return oep::installer::TrustState::RevokedCertificate;
    if (name == "InvalidSignature") return oep::installer::TrustState::InvalidSignature;
    if (name == "Tampered") return oep::installer::TrustState::Tampered;
    return oep::installer::TrustState::Unsigned;
}

void zero_publisher_certificate(oep_publisher_certificate_t* out_certificate) {
    out_certificate->publisher_id[0] = '\0';
    out_certificate->publisher_name[0] = '\0';
    out_certificate->public_key_hex[0] = '\0';
    out_certificate->issued_utc[0] = '\0';
    out_certificate->expires_utc[0] = '\0';
    out_certificate->issuer[0] = '\0';
    out_certificate->version[0] = '\0';
    out_certificate->fingerprint[0] = '\0';
    out_certificate->revoked = 0;
    out_certificate->revoked_utc[0] = '\0';
}

void populate_publisher_certificate(const oep::installer::PublisherCertificate& certificate,
                                     oep_publisher_certificate_t* out_certificate) {
    oep::api::detail::copy_truncated(certificate.publisher_id, out_certificate->publisher_id,
                                      sizeof(out_certificate->publisher_id));
    oep::api::detail::copy_truncated(certificate.publisher_name, out_certificate->publisher_name,
                                      sizeof(out_certificate->publisher_name));
    oep::api::detail::copy_truncated(certificate.public_key_hex, out_certificate->public_key_hex,
                                      sizeof(out_certificate->public_key_hex));
    oep::api::detail::copy_truncated(certificate.issued_utc, out_certificate->issued_utc,
                                      sizeof(out_certificate->issued_utc));
    oep::api::detail::copy_truncated(certificate.expires_utc, out_certificate->expires_utc,
                                      sizeof(out_certificate->expires_utc));
    oep::api::detail::copy_truncated(certificate.issuer, out_certificate->issuer, sizeof(out_certificate->issuer));
    oep::api::detail::copy_truncated(certificate.version, out_certificate->version,
                                      sizeof(out_certificate->version));
    oep::api::detail::copy_truncated(certificate.fingerprint, out_certificate->fingerprint,
                                      sizeof(out_certificate->fingerprint));
    out_certificate->revoked = certificate.revoked ? 1 : 0;
    oep::api::detail::copy_truncated(certificate.revoked_utc, out_certificate->revoked_utc,
                                      sizeof(out_certificate->revoked_utc));
}

void zero_certificate_list(oep_certificate_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_package_trust_status(oep_package_trust_status_t* out_status) {
    out_status->state = OEP_TRUST_UNSIGNED;
    out_status->fingerprint[0] = '\0';
}

oep_dependency_state_t to_capi_dependency_state(oep::installer::DependencyState state) {
    switch (state) {
        case oep::installer::DependencyState::Satisfied: return OEP_DEPENDENCY_SATISFIED;
        case oep::installer::DependencyState::Missing: return OEP_DEPENDENCY_MISSING;
        case oep::installer::DependencyState::Optional: return OEP_DEPENDENCY_OPTIONAL;
        case oep::installer::DependencyState::Conflicting: return OEP_DEPENDENCY_CONFLICTING;
        case oep::installer::DependencyState::Cyclic: return OEP_DEPENDENCY_CYCLIC;
        case oep::installer::DependencyState::Unknown: return OEP_DEPENDENCY_UNKNOWN;
    }
    return OEP_DEPENDENCY_UNKNOWN;
}

void zero_dependency_resolution_result(oep_dependency_resolution_result_t* out_result) {
    out_result->resolved = 0;
    out_result->cycle_detected = 0;
    out_result->cycle_description[0] = '\0';
}

void zero_dependency_entry_list(oep_dependency_entry_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_uninstall_impact(oep_uninstall_impact_t* out_impact) {
    out_impact->found = 0;
    out_impact->objects_affected = 0;
    out_impact->relationships_affected = 0;
    out_impact->removable = 0;
}

void zero_package_uninstall_result(oep_package_uninstall_result_t* out_result) {
    out_result->package_id[0] = '\0';
    out_result->objects_removed = 0;
    out_result->relationships_removed = 0;
}

void zero_update_impact(oep_update_impact_t* out_impact) {
    out_impact->currently_installed = 0;
    out_impact->current_version[0] = '\0';
    out_impact->candidate_version[0] = '\0';
    out_impact->trust_status[0] = '\0';
    out_impact->updatable = 0;
}

void zero_package_update_result(oep_package_update_result_t* out_result) {
    out_result->package_id[0] = '\0';
    out_result->previous_version[0] = '\0';
    out_result->new_version[0] = '\0';
    out_result->objects_removed = 0;
    out_result->relationships_removed = 0;
    out_result->objects_created = 0;
    out_result->relationships_created = 0;
    out_result->trust_status[0] = '\0';
}

void zero_package_id_list(oep_package_id_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

oep_merge_conflict_kind_t to_capi_merge_conflict_kind(oep::installer::MergeConflictKind kind) {
    switch (kind) {
        case oep::installer::MergeConflictKind::ObjectContentConflict: return OEP_MERGE_CONFLICT_OBJECT_CONTENT;
        case oep::installer::MergeConflictKind::RelationshipContentConflict:
            return OEP_MERGE_CONFLICT_RELATIONSHIP_CONTENT;
        case oep::installer::MergeConflictKind::RelationshipMissingEndpoint:
            return OEP_MERGE_CONFLICT_RELATIONSHIP_MISSING_ENDPOINT;
    }
    return OEP_MERGE_CONFLICT_OBJECT_CONTENT;
}

void zero_merge_conflict_list(oep_merge_conflict_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_merge_plan(oep_merge_plan_t* out_plan) {
    out_plan->package_id[0] = '\0';
    out_plan->version[0] = '\0';
    out_plan->trust_status[0] = '\0';
    out_plan->trust_blocks = 0;
    out_plan->dependency_blocks = 0;
    out_plan->already_registered = 0;
    out_plan->objects_to_create = 0;
    out_plan->relationships_to_create = 0;
    out_plan->mergeable = 0;
}

void zero_merge_result(oep_merge_result_t* out_result) {
    out_result->package_id[0] = '\0';
    out_result->version[0] = '\0';
    out_result->objects_created = 0;
    out_result->relationships_created = 0;
    out_result->trust_status[0] = '\0';
}

oep_merge_conflict_list_t build_merge_conflict_list(const std::vector<oep::installer::MergeConflict>& conflicts) {
    const int count = static_cast<int>(conflicts.size());
    oep_merge_conflict_t* items = count > 0 ? new oep_merge_conflict_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        const oep::installer::MergeConflict& conflict = conflicts[static_cast<std::size_t>(i)];
        items[i].kind = to_capi_merge_conflict_kind(conflict.kind);
        oep::api::detail::copy_truncated(conflict.entity_id, items[i].entity_id, sizeof(items[i].entity_id));
        oep::api::detail::copy_truncated(conflict.detail, items[i].detail, sizeof(items[i].detail));
    }
    oep_merge_conflict_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

void populate_dependency_entry(const oep::installer::DependencyResolutionEntry& entry,
                                oep_dependency_entry_t* out_entry) {
    oep::api::detail::copy_truncated(entry.package_id, out_entry->package_id, sizeof(out_entry->package_id));
    oep::api::detail::copy_truncated(entry.version_constraint, out_entry->version_constraint,
                                      sizeof(out_entry->version_constraint));
    out_entry->optional = entry.optional ? 1 : 0;
    out_entry->state = to_capi_dependency_state(entry.state);
    oep::api::detail::copy_truncated(entry.installed_version, out_entry->installed_version,
                                      sizeof(out_entry->installed_version));
}

oep_event_type_t to_capi_event_type(oep::runtime::EventType type) {
    switch (type) {
        case oep::runtime::EventType::ObjectCreated: return OEP_EVENT_OBJECT_CREATED;
        case oep::runtime::EventType::ObjectUpdated: return OEP_EVENT_OBJECT_UPDATED;
        case oep::runtime::EventType::ObjectDeleted: return OEP_EVENT_OBJECT_DELETED;
        case oep::runtime::EventType::RelationshipCreated: return OEP_EVENT_RELATIONSHIP_CREATED;
        case oep::runtime::EventType::RelationshipUpdated: return OEP_EVENT_RELATIONSHIP_UPDATED;
        case oep::runtime::EventType::RelationshipDeleted: return OEP_EVENT_RELATIONSHIP_DELETED;
        case oep::runtime::EventType::TransactionBegun: return OEP_EVENT_TRANSACTION_BEGUN;
        case oep::runtime::EventType::TransactionCommitted: return OEP_EVENT_TRANSACTION_COMMITTED;
        case oep::runtime::EventType::TransactionRolledBack: return OEP_EVENT_TRANSACTION_ROLLED_BACK;
        case oep::runtime::EventType::PackageInstalled: return OEP_EVENT_PACKAGE_INSTALLED;
        case oep::runtime::EventType::PackageInstallFailed: return OEP_EVENT_PACKAGE_INSTALL_FAILED;
        case oep::runtime::EventType::DependencyResolutionCompleted: return OEP_EVENT_DEPENDENCY_RESOLUTION_COMPLETED;
        case oep::runtime::EventType::PackageUninstalled: return OEP_EVENT_PACKAGE_UNINSTALLED;
        case oep::runtime::EventType::PackageUpdated: return OEP_EVENT_PACKAGE_UPDATED;
        case oep::runtime::EventType::RepositoryMerged: return OEP_EVENT_REPOSITORY_MERGED;
    }
    return OEP_EVENT_OBJECT_CREATED;
}

void zero_repository_event_list(oep_repository_event_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void populate_repository_event(const oep::runtime::RepositoryEvent& event, oep_repository_event_t* out_event) {
    out_event->type = to_capi_event_type(event.type());
    oep::api::detail::copy_truncated(event.subject_id(), out_event->subject_id, sizeof(out_event->subject_id));
    oep::api::detail::copy_truncated(event.detail(), out_event->detail, sizeof(out_event->detail));
    oep::api::detail::copy_truncated(event.occurred_at_utc(), out_event->occurred_at_utc,
                                      sizeof(out_event->occurred_at_utc));
    out_event->sequence = static_cast<long long>(event.sequence());
}

std::string describe_cycle(const oep::installer::DependencyCycle& cycle) {
    std::string description;
    for (std::size_t i = 0; i < cycle.chain.size(); ++i) {
        description += cycle.chain[i];
        if (i + 1 != cycle.chain.size()) description += " -> ";
    }
    return description;
}

void zero_package_verify_result(oep_package_verify_result_t* out_result) {
    out_result->verified = 0;
    out_result->objects_expected = 0;
    out_result->objects_present = 0;
    out_result->relationships_expected = 0;
    out_result->relationships_present = 0;
    out_result->archive_available = 0;
    out_result->archive_hash_matches = 0;
}

} // namespace

extern "C" {

const char* oep_foundation_version(void) {
    return oep::runtime::kFoundationVersion;
}

int oep_api_version(void) {
    return OEP_API_VERSION;
}

int oep_abi_version(void) {
    return OEP_ABI_VERSION;
}

const char* oep_runtime_state_to_string(oep_runtime_state_t state) {
    switch (state) {
        case OEP_STATE_UNINITIALIZED: return "Uninitialized";
        case OEP_STATE_INITIALIZED: return "Initialized";
        case OEP_STATE_REPOSITORY_OPEN: return "RepositoryOpen";
        case OEP_STATE_REPOSITORY_CLOSED: return "RepositoryClosed";
        case OEP_STATE_SHUTDOWN: return "Shutdown";
    }
    return "Uninitialized";
}

const char* oep_error_code_to_string(oep_error_code_t code) {
    switch (code) {
        case OEP_ERROR_NONE: return "None";
        case OEP_ERROR_INVALID_ARGUMENT: return "InvalidArgument";
        case OEP_ERROR_INVALID_STATE: return "InvalidState";
        case OEP_ERROR_NOT_FOUND: return "NotFound";
        case OEP_ERROR_OPERATION_FAILED: return "OperationFailed";
        case OEP_ERROR_INTERNAL: return "Internal";
    }
    return "Internal";
}

const char* oep_error_category_to_string(oep_error_category_t category) {
    switch (category) {
        case OEP_ERROR_CATEGORY_NONE: return "None";
        case OEP_ERROR_CATEGORY_VALIDATION: return "Validation";
        case OEP_ERROR_CATEGORY_STATE: return "State";
        case OEP_ERROR_CATEGORY_IO: return "IO";
        case OEP_ERROR_CATEGORY_INTERNAL: return "Internal";
    }
    return "Internal";
}

OEP_Runtime oep_runtime_create(const char* foundation_version) {
    if (foundation_version == nullptr) {
        return nullptr;
    }
    try {
        return new oep_runtime_impl(std::string(foundation_version));
    } catch (...) {
        return nullptr;
    }
}

void oep_runtime_destroy(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return;
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::Shutdown) {
            runtime->runtime.shutdown();
        }
    } catch (...) {
        // Destruction must not throw; a failed best-effort shutdown is
        // not a reason to leak the handle.
    }
    delete runtime;
}

oep_result_t oep_runtime_initialize(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        const oep::runtime::RuntimeResult result = runtime->runtime.initialize();
        if (!result.success) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_runtime_open_repository(OEP_Runtime runtime, const char* repository_path) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (repository_path == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "repository_path is null");
    }
    try {
        const oep::runtime::RuntimeState state_before = runtime->runtime.state();
        if (state_before != oep::runtime::RuntimeState::Initialized &&
            state_before != oep::runtime::RuntimeState::RepositoryClosed) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "cannot open a repository from state '" +
                                          oep::runtime::to_string(state_before) + "'");
        }
        const oep::runtime::RuntimeResult result = runtime->runtime.open_repository(repository_path);
        if (!result.success) {
            const oep_error_code_t code =
                result.error.find("could not load repository metadata") != std::string::npos ? OEP_ERROR_NOT_FOUND
                                                                                                : OEP_ERROR_OPERATION_FAILED;
            return make_error_result(code, category_for_code(code), result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_runtime_close_repository(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeResult result = runtime->runtime.close_repository();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_runtime_shutdown(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() == oep::runtime::RuntimeState::Shutdown) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "Runtime is already shut down");
        }
        const oep::runtime::RuntimeResult result = runtime->runtime.shutdown();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_runtime_state_t oep_runtime_get_state(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return OEP_STATE_UNINITIALIZED;
    }
    try {
        return to_capi_state(runtime->runtime.state());
    } catch (...) {
        return OEP_STATE_UNINITIALIZED;
    }
}

oep_result_t oep_runtime_get_repository_status(OEP_Runtime runtime, oep_repository_status_t* out_status) {
    if (out_status != nullptr) {
        zero_status(out_status);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_status == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_status is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }

        const oep::runtime::RuntimeMetadataResult metadata_result = runtime->runtime.current_metadata();
        if (!metadata_result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      metadata_result.error);
        }

        const oep::runtime::RuntimePackageSetResult package_result = runtime->runtime.current_package_set();
        if (!package_result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      package_result.error);
        }

        int loaded_count = 0;
        for (const oep::packages::DiscoveredPackage& package : package_result.packages) {
            if (package.state == oep::packages::PackageState::Loaded) {
                ++loaded_count;
            }
        }

        out_status->repository_open = 1;
        oep::api::detail::copy_truncated(metadata_result.metadata.repository_id, out_status->repository_id,
                                          sizeof(out_status->repository_id));
        oep::api::detail::copy_truncated(metadata_result.metadata.repository_name, out_status->repository_name,
                                          sizeof(out_status->repository_name));
        oep::api::detail::copy_truncated(metadata_result.metadata.repository_version,
                                          out_status->repository_version, sizeof(out_status->repository_version));
        out_status->loaded_package_count = loaded_count;

        return make_success_result();
    } catch (const std::exception& ex) {
        zero_status(out_status);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_status(out_status);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

const char* oep_object_type_to_string(oep_object_type_t type) {
    switch (type) {
        case OEP_OBJECT_TYPE_DOCUMENT: return "Document";
        case OEP_OBJECT_TYPE_DIAGRAM: return "Diagram";
        case OEP_OBJECT_TYPE_COMPONENT: return "Component";
        case OEP_OBJECT_TYPE_PROCEDURE: return "Procedure";
        case OEP_OBJECT_TYPE_PROJECT: return "Project";
        case OEP_OBJECT_TYPE_IMAGE: return "Image";
    }
    return "Document";
}

oep_result_t oep_object_store_get_count(OEP_Runtime runtime, int* out_count) {
    if (out_count != nullptr) {
        *out_count = 0;
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_count == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_count is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::repository::ListObjectsResult listed = runtime->runtime.object_store()->list_all();
        if (!listed.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      listed.error);
        }
        *out_count = static_cast<int>(listed.objects.size());
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_object_store_get_by_id(OEP_Runtime runtime, const char* object_id, oep_object_info_t* out_object) {
    if (out_object != nullptr) {
        zero_object_info(out_object);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    if (out_object == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_object is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::repository::LoadObjectResult loaded = runtime->runtime.object_store()->load(object_id);
        if (!loaded.success) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND), loaded.error);
        }
        populate_object_info(loaded.object, out_object);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_object_store_list(OEP_Runtime runtime, oep_object_list_t* out_list) {
    if (out_list != nullptr) {
        zero_object_list(out_list);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::repository::ListObjectsResult listed = runtime->runtime.object_store()->list_all();
        if (!listed.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      listed.error);
        }

        std::vector<oep::repository::EngineeringObject> objects = listed.objects;
        std::sort(objects.begin(), objects.end(),
                  [](const oep::repository::EngineeringObject& a, const oep::repository::EngineeringObject& b) {
                      return a.object_id < b.object_id;
                  });

        const int count = static_cast<int>(objects.size());
        oep_object_info_t* items = count > 0 ? new oep_object_info_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_object_info(objects[static_cast<std::size_t>(i)], &items[i]);
        }

        out_list->items = items;
        out_list->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_object_list_release(oep_object_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_runtime_get_repository_statistics(OEP_Runtime runtime, oep_repository_statistics_t* out_statistics) {
    if (out_statistics != nullptr) {
        zero_statistics(out_statistics);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_statistics == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_statistics is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }

        const oep::runtime::RuntimeMetadataResult metadata_result = runtime->runtime.current_metadata();
        if (!metadata_result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      metadata_result.error);
        }

        const oep::repository::ListObjectsResult objects_result = runtime->runtime.object_store()->list_all();
        if (!objects_result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      objects_result.error);
        }

        const oep::repository::ListRelationshipsResult relationships_result =
            runtime->runtime.relationship_store()->list_all();
        if (!relationships_result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      relationships_result.error);
        }

        const oep::runtime::RuntimePackageSetResult package_result = runtime->runtime.current_package_set();
        if (!package_result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      package_result.error);
        }

        oep::api::detail::copy_truncated(metadata_result.metadata.repository_id, out_statistics->repository_id,
                                          sizeof(out_statistics->repository_id));
        oep::api::detail::copy_truncated(metadata_result.metadata.repository_name,
                                          out_statistics->repository_name, sizeof(out_statistics->repository_name));
        oep::api::detail::copy_truncated(metadata_result.metadata.repository_version,
                                          out_statistics->repository_version,
                                          sizeof(out_statistics->repository_version));

        out_statistics->total_object_count = static_cast<int>(objects_result.objects.size());
        for (const oep::repository::EngineeringObject& object : objects_result.objects) {
            const int type_index = static_cast<int>(oep::api::detail::to_capi_object_type(object.object_type));
            ++out_statistics->object_count_by_type[type_index];
        }
        out_statistics->relationship_count = static_cast<int>(relationships_result.relationships.size());
        out_statistics->package_count = static_cast<int>(package_result.packages.size());

        return make_success_result();
    } catch (const std::exception& ex) {
        zero_statistics(out_statistics);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_statistics(out_statistics);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

const char* oep_relationship_type_to_string(oep_relationship_type_t type) {
    switch (type) {
        case OEP_RELATIONSHIP_TYPE_REFERENCES: return "References";
        case OEP_RELATIONSHIP_TYPE_CONTAINS: return "Contains";
        case OEP_RELATIONSHIP_TYPE_DEPENDS_ON: return "DependsOn";
        case OEP_RELATIONSHIP_TYPE_CONNECTED_TO: return "ConnectedTo";
        case OEP_RELATIONSHIP_TYPE_DOCUMENTS: return "Documents";
        case OEP_RELATIONSHIP_TYPE_IMPLEMENTS: return "Implements";
    }
    return "References";
}

oep_result_t oep_relationship_store_get_count(OEP_Runtime runtime, int* out_count) {
    if (out_count != nullptr) {
        *out_count = 0;
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_count == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_count is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::repository::ListRelationshipsResult listed = runtime->runtime.relationship_store()->list_all();
        if (!listed.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      listed.error);
        }
        *out_count = static_cast<int>(listed.relationships.size());
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_relationship_store_get_by_id(OEP_Runtime runtime, const char* relationship_id,
                                               oep_relationship_info_t* out_relationship) {
    if (out_relationship != nullptr) {
        zero_relationship_info(out_relationship);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (relationship_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "relationship_id is null");
    }
    if (out_relationship == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_relationship is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::repository::LoadRelationshipResult loaded =
            runtime->runtime.relationship_store()->load(relationship_id);
        if (!loaded.success) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND), loaded.error);
        }
        populate_relationship_info(loaded.relationship, out_relationship);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_relationship_store_list(OEP_Runtime runtime, oep_relationship_list_t* out_list) {
    if (out_list != nullptr) {
        zero_relationship_list(out_list);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::repository::ListRelationshipsResult listed = runtime->runtime.relationship_store()->list_all();
        if (!listed.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      listed.error);
        }

        std::vector<oep::repository::Relationship> relationships = listed.relationships;
        std::sort(relationships.begin(), relationships.end(),
                  [](const oep::repository::Relationship& a, const oep::repository::Relationship& b) {
                      return a.relationship_id < b.relationship_id;
                  });

        const int count = static_cast<int>(relationships.size());
        oep_relationship_info_t* items =
            count > 0 ? new oep_relationship_info_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_relationship_info(relationships[static_cast<std::size_t>(i)], &items[i]);
        }

        out_list->items = items;
        out_list->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_relationship_list_release(oep_relationship_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

const char* oep_match_location_to_string(oep_match_location_t location) {
    switch (location) {
        case OEP_MATCH_LOCATION_NAME: return "Name";
        case OEP_MATCH_LOCATION_DESCRIPTION: return "Description";
        case OEP_MATCH_LOCATION_AUTHOR: return "Author";
        case OEP_MATCH_LOCATION_TAGS: return "Tags";
        case OEP_MATCH_LOCATION_OBJECT_TYPE: return "ObjectType";
        case OEP_MATCH_LOCATION_RELATIONSHIP_TYPE: return "RelationshipType";
    }
    return "Name";
}

oep_result_t oep_search_repository(OEP_Runtime runtime, const char* query,
                                    oep_repository_search_result_t* out_result) {
    if (out_result != nullptr) {
        zero_repository_search_result(out_result);
    }
    const oep_result_t argument_check = validate_search_arguments(runtime, query);
    if (!argument_check.success) {
        return argument_check;
    }
    if (out_result == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_result is null");
    }
    try {
        const oep::search::SearchObjectsResult objects_searched = runtime->runtime.search_engine()->search_objects(query);
        if (!objects_searched.success) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      objects_searched.error);
        }
        const oep::search::SearchRelationshipsResult relationships_searched =
            runtime->runtime.search_engine()->search_relationships(query);
        if (!relationships_searched.success) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      relationships_searched.error);
        }

        out_result->objects = build_object_search_result_list(objects_searched);
        out_result->relationships = build_relationship_search_result_list(relationships_searched);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_repository_search_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_repository_search_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_repository_search_result_release(oep_repository_search_result_t* result) {
    if (result == nullptr) {
        return;
    }
    delete[] result->objects.items;
    result->objects.items = nullptr;
    result->objects.count = 0;
    delete[] result->relationships.items;
    result->relationships.items = nullptr;
    result->relationships.count = 0;
}

oep_result_t oep_search_objects(OEP_Runtime runtime, const char* query, oep_object_search_result_list_t* out_list) {
    if (out_list != nullptr) {
        zero_object_search_result_list(out_list);
    }
    const oep_result_t argument_check = validate_search_arguments(runtime, query);
    if (!argument_check.success) {
        return argument_check;
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        const oep::search::SearchObjectsResult searched = runtime->runtime.search_engine()->search_objects(query);
        if (!searched.success) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      searched.error);
        }
        *out_list = build_object_search_result_list(searched);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_object_search_result_list_release(oep_object_search_result_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_search_relationships(OEP_Runtime runtime, const char* query,
                                      oep_relationship_search_result_list_t* out_list) {
    if (out_list != nullptr) {
        zero_relationship_search_result_list(out_list);
    }
    const oep_result_t argument_check = validate_search_arguments(runtime, query);
    if (!argument_check.success) {
        return argument_check;
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        const oep::search::SearchRelationshipsResult searched =
            runtime->runtime.search_engine()->search_relationships(query);
        if (!searched.success) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      searched.error);
        }
        *out_list = build_relationship_search_result_list(searched);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_relationship_search_result_list_release(oep_relationship_search_result_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_object_create(OEP_Runtime runtime, oep_object_type_t object_type, const char* name,
                                const char* description, const char* author, const char* const* tags, int tag_count,
                                oep_object_info_t* out_object) {
    if (out_object != nullptr) {
        zero_object_info(out_object);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (name == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "name is null");
    }
    if (tag_count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "tag_count is negative");
    }
    if (tag_count > 0 && tags == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "tags is null but tag_count is nonzero");
    }
    const std::optional<oep::repository::ObjectType> internal_type = from_capi_object_type(object_type);
    if (!internal_type.has_value()) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "unrecognized object_type");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::ObjectMutationResponse result = runtime->service.create_object(
            oep::runtime::RuntimeService::CreateObjectRequest(*internal_type, name,
                                                                description != nullptr ? description : "",
                                                                author != nullptr ? author : "",
                                                                tags_from_capi(tags, tag_count)));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object != nullptr) {
            populate_object_info(result.object, out_object);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_object_update(OEP_Runtime runtime, const char* object_id, const char* name,
                                const char* description, const char* author, const char* const* tags, int tag_count,
                                oep_object_info_t* out_object) {
    if (out_object != nullptr) {
        zero_object_info(out_object);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    if (name == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "name is null");
    }
    if (tag_count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "tag_count is negative");
    }
    if (tag_count > 0 && tags == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "tags is null but tag_count is nonzero");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::ObjectMutationResponse result = runtime->service.update_object(
            oep::runtime::RuntimeService::UpdateObjectRequest(object_id, name,
                                                                description != nullptr ? description : "",
                                                                author != nullptr ? author : "",
                                                                tags_from_capi(tags, tag_count)));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object != nullptr) {
            populate_object_info(result.object, out_object);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_object_update_content(OEP_Runtime runtime, const char* object_id, const char* content,
                                        oep_object_info_t* out_object) {
    if (out_object != nullptr) {
        zero_object_info(out_object);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::ObjectMutationResponse result = runtime->service.update_object_content(
            oep::runtime::RuntimeService::UpdateObjectContentRequest(object_id, content != nullptr ? content : ""));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object != nullptr) {
            populate_object_info(result.object, out_object);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_object_get_content(OEP_Runtime runtime, const char* object_id, char** out_text, size_t* out_length) {
    if (out_text != nullptr) *out_text = nullptr;
    if (out_length != nullptr) *out_length = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    if (out_text == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_text is null");
    }
    if (out_length == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_length is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::repository::LoadObjectResult loaded = runtime->runtime.object_store()->load(object_id);
        if (!loaded.success) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND), loaded.error);
        }
        *out_text = copy_owned_string(loaded.object.content, out_length);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_text != nullptr) *out_text = nullptr;
        if (out_length != nullptr) *out_length = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_text != nullptr) *out_text = nullptr;
        if (out_length != nullptr) *out_length = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_object_delete(OEP_Runtime runtime, const char* object_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::DeleteResponse result =
            runtime->service.delete_object(oep::runtime::RuntimeService::DeleteObjectRequest(object_id));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_relationship_create(OEP_Runtime runtime, const char* source_object_id,
                                      const char* target_object_id, oep_relationship_type_t relationship_type,
                                      const char* author, const char* description,
                                      oep_relationship_info_t* out_relationship) {
    if (out_relationship != nullptr) {
        zero_relationship_info(out_relationship);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (source_object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "source_object_id is null");
    }
    if (target_object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "target_object_id is null");
    }
    const std::optional<oep::repository::RelationshipType> internal_type =
        from_capi_relationship_type(relationship_type);
    if (!internal_type.has_value()) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "unrecognized relationship_type");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::RelationshipMutationResponse result = runtime->service.create_relationship(
            oep::runtime::RuntimeService::CreateRelationshipRequest(source_object_id, target_object_id,
                                                                      *internal_type,
                                                                      author != nullptr ? author : "",
                                                                      description != nullptr ? description : ""));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_relationship != nullptr) {
            populate_relationship_info(result.relationship, out_relationship);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_relationship != nullptr) zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_relationship != nullptr) zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_relationship_update(OEP_Runtime runtime, const char* relationship_id, const char* author,
                                      const char* description, oep_relationship_info_t* out_relationship) {
    if (out_relationship != nullptr) {
        zero_relationship_info(out_relationship);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (relationship_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "relationship_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::RelationshipMutationResponse result = runtime->service.update_relationship(
            oep::runtime::RuntimeService::UpdateRelationshipRequest(
                relationship_id, author != nullptr ? author : "", description != nullptr ? description : ""));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_relationship != nullptr) {
            populate_relationship_info(result.relationship, out_relationship);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_relationship != nullptr) zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_relationship != nullptr) zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_relationship_delete(OEP_Runtime runtime, const char* relationship_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (relationship_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "relationship_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::DeleteResponse result = runtime->service.delete_relationship(
            oep::runtime::RuntimeService::DeleteRelationshipRequest(relationship_id));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

// --------------------------------------------------------------------
// Diagram/Graph Identity and Membership (AP-OEP-FOUNDATION-GRAPH-IDENTITY-001)
// --------------------------------------------------------------------

oep_result_t oep_diagram_create(OEP_Runtime runtime, const char* name, const char* description, const char* author,
                                 oep_object_info_t* out_diagram) {
    if (out_diagram != nullptr) {
        zero_object_info(out_diagram);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (name == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "name is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::ObjectMutationResponse result =
            runtime->service.create_diagram(oep::runtime::RuntimeService::CreateDiagramRequest(
                name, description != nullptr ? description : "", author != nullptr ? author : ""));
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_diagram != nullptr) {
            populate_object_info(result.object, out_diagram);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_diagram != nullptr) zero_object_info(out_diagram);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_diagram != nullptr) zero_object_info(out_diagram);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_diagram_get(OEP_Runtime runtime, const char* diagram_id, oep_object_info_t* out_diagram) {
    if (out_diagram != nullptr) {
        zero_object_info(out_diagram);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (diagram_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "diagram_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeObjectMutationResult result = runtime->runtime.get_diagram(diagram_id);
        if (!result.success) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND), result.error);
        }
        if (out_diagram != nullptr) {
            populate_object_info(result.object, out_diagram);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_object_create_with_diagram(OEP_Runtime runtime, oep_object_type_t object_type, const char* name,
                                             const char* description, const char* author, const char* const* tags,
                                             int tag_count, const char* diagram_id, oep_object_info_t* out_object) {
    if (out_object != nullptr) {
        zero_object_info(out_object);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (name == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "name is null");
    }
    if (diagram_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "diagram_id is null");
    }
    if (tag_count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "tag_count is negative");
    }
    if (tag_count > 0 && tags == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "tags is null but tag_count is nonzero");
    }
    const std::optional<oep::repository::ObjectType> internal_type = from_capi_object_type(object_type);
    if (!internal_type.has_value()) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "unrecognized object_type");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::ObjectMutationResponse result =
            runtime->service.create_object_in_diagram(oep::runtime::RuntimeService::CreateObjectInDiagramRequest(
                *internal_type, name, description != nullptr ? description : "",
                author != nullptr ? author : "", tags_from_capi(tags, tag_count), diagram_id));
        if (!result.success) {
            const oep_error_code_t code = classify_diagram_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object != nullptr) {
            populate_object_info(result.object, out_object);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object != nullptr) zero_object_info(out_object);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_relationship_create_with_diagram(OEP_Runtime runtime, const char* source_object_id,
                                                   const char* target_object_id,
                                                   oep_relationship_type_t relationship_type, const char* author,
                                                   const char* description, const char* diagram_id,
                                                   oep_relationship_info_t* out_relationship) {
    if (out_relationship != nullptr) {
        zero_relationship_info(out_relationship);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (source_object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "source_object_id is null");
    }
    if (target_object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "target_object_id is null");
    }
    if (diagram_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "diagram_id is null");
    }
    const std::optional<oep::repository::RelationshipType> internal_type =
        from_capi_relationship_type(relationship_type);
    if (!internal_type.has_value()) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "unrecognized relationship_type");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::RelationshipMutationResponse result = runtime->service
            .create_relationship_in_diagram(oep::runtime::RuntimeService::CreateRelationshipInDiagramRequest(
                source_object_id, target_object_id, *internal_type, author != nullptr ? author : "",
                description != nullptr ? description : "", diagram_id));
        if (!result.success) {
            const oep_error_code_t code = classify_diagram_mutation_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_relationship != nullptr) {
            populate_relationship_info(result.relationship, out_relationship);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_relationship != nullptr) zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_relationship != nullptr) zero_relationship_info(out_relationship);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_diagram_get_objects(OEP_Runtime runtime, const char* diagram_id, oep_object_list_t* out_objects) {
    if (out_objects != nullptr) {
        zero_object_list(out_objects);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (diagram_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "diagram_id is null");
    }
    if (out_objects == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_objects is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeDiagramObjectsResult result = runtime->runtime.get_diagram_objects(diagram_id);
        if (!result.success) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      result.error);
        }

        std::vector<oep::repository::EngineeringObject> objects = result.objects;
        std::sort(objects.begin(), objects.end(),
                  [](const oep::repository::EngineeringObject& a, const oep::repository::EngineeringObject& b) {
                      return a.object_id < b.object_id;
                  });

        const int count = static_cast<int>(objects.size());
        oep_object_info_t* items = count > 0 ? new oep_object_info_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_object_info(objects[static_cast<std::size_t>(i)], &items[i]);
        }

        out_objects->items = items;
        out_objects->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_diagram_get_relationships(OEP_Runtime runtime, const char* diagram_id,
                                            oep_relationship_list_t* out_relationships) {
    if (out_relationships != nullptr) {
        zero_relationship_list(out_relationships);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (diagram_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "diagram_id is null");
    }
    if (out_relationships == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_relationships is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeDiagramRelationshipsResult result =
            runtime->runtime.get_diagram_relationships(diagram_id);
        if (!result.success) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      result.error);
        }

        std::vector<oep::repository::Relationship> relationships = result.relationships;
        std::sort(relationships.begin(), relationships.end(),
                  [](const oep::repository::Relationship& a, const oep::repository::Relationship& b) {
                      return a.relationship_id < b.relationship_id;
                  });

        const int count = static_cast<int>(relationships.size());
        oep_relationship_info_t* items =
            count > 0 ? new oep_relationship_info_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_relationship_info(relationships[static_cast<std::size_t>(i)], &items[i]);
        }

        out_relationships->items = items;
        out_relationships->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_transaction_begin(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        if (runtime->runtime.transaction_active()) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "a transaction is already active; nested transactions are not supported");
        }
        const oep::runtime::RuntimeResult result = runtime->runtime.begin_transaction();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_transaction_commit(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        if (!runtime->runtime.transaction_active()) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no transaction is currently active");
        }
        const oep::runtime::RuntimeResult result = runtime->runtime.commit_transaction();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_transaction_rollback(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        if (!runtime->runtime.transaction_active()) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no transaction is currently active");
        }
        const oep::runtime::RuntimeResult result = runtime->runtime.rollback_transaction();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

int oep_transaction_is_active(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return 0;
    }
    try {
        return runtime->runtime.transaction_active() ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

oep_result_t oep_batch_create_objects(OEP_Runtime runtime, const oep_object_create_spec_t* specs, int count,
                                       oep_batch_create_objects_result_t* out_result) {
    if (out_result != nullptr) {
        zero_batch_create_objects_result(out_result);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_result == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_result is null");
    }
    if (count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "count is negative");
    }
    if (count > 0 && specs == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "specs is null but count is nonzero");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }

        std::vector<oep::runtime::ObjectCreateSpec> internal_specs;
        internal_specs.reserve(static_cast<std::size_t>(count));
        for (int i = 0; i < count; ++i) {
            if (specs[i].name == nullptr) {
                return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                          "specs[" + std::to_string(i) + "].name is null");
            }
            const std::optional<oep::repository::ObjectType> internal_type =
                from_capi_object_type(specs[i].object_type);
            if (!internal_type.has_value()) {
                return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                          "specs[" + std::to_string(i) + "].object_type is unrecognized");
            }
            if (specs[i].tag_count < 0) {
                return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                          "specs[" + std::to_string(i) + "].tag_count is negative");
            }
            if (specs[i].tag_count > 0 && specs[i].tags == nullptr) {
                return make_error_result(
                    OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                    "specs[" + std::to_string(i) + "].tags is null but tag_count is nonzero");
            }

            oep::runtime::ObjectCreateSpec internal_spec;
            internal_spec.object_type = *internal_type;
            internal_spec.name = specs[i].name;
            internal_spec.description = specs[i].description != nullptr ? specs[i].description : "";
            internal_spec.author = specs[i].author != nullptr ? specs[i].author : "";
            internal_spec.tags = tags_from_capi(specs[i].tags, specs[i].tag_count);
            internal_specs.push_back(std::move(internal_spec));
        }

        const oep::runtime::RuntimeBatchCreateObjectsResult result =
            runtime->runtime.batch_create_objects(internal_specs);
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            oep_result_t error_result = make_error_result(code, category_for_code(code), result.error);
            out_result->failed_index = result.failed_index;
            return error_result;
        }

        const int created_count = static_cast<int>(result.created.size());
        oep_object_info_t* items =
            created_count > 0 ? new oep_object_info_t[static_cast<std::size_t>(created_count)] : nullptr;
        for (int i = 0; i < created_count; ++i) {
            populate_object_info(result.created[static_cast<std::size_t>(i)], &items[i]);
        }
        out_result->success = 1;
        out_result->failed_index = -1;
        out_result->created.items = items;
        out_result->created.count = created_count;
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_batch_create_objects_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_batch_create_objects_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_batch_create_objects_result_release(oep_batch_create_objects_result_t* result) {
    if (result == nullptr) {
        return;
    }
    delete[] result->created.items;
    result->created.items = nullptr;
    result->created.count = 0;
}

oep_result_t oep_batch_create_relationships(OEP_Runtime runtime, const oep_relationship_create_spec_t* specs,
                                             int count, oep_batch_create_relationships_result_t* out_result) {
    if (out_result != nullptr) {
        zero_batch_create_relationships_result(out_result);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_result == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_result is null");
    }
    if (count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "count is negative");
    }
    if (count > 0 && specs == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "specs is null but count is nonzero");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }

        std::vector<oep::runtime::RelationshipCreateSpec> internal_specs;
        internal_specs.reserve(static_cast<std::size_t>(count));
        for (int i = 0; i < count; ++i) {
            if (specs[i].source_object_id == nullptr) {
                return make_error_result(
                    OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                    "specs[" + std::to_string(i) + "].source_object_id is null");
            }
            if (specs[i].target_object_id == nullptr) {
                return make_error_result(
                    OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                    "specs[" + std::to_string(i) + "].target_object_id is null");
            }
            const std::optional<oep::repository::RelationshipType> internal_type =
                from_capi_relationship_type(specs[i].relationship_type);
            if (!internal_type.has_value()) {
                return make_error_result(
                    OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                    "specs[" + std::to_string(i) + "].relationship_type is unrecognized");
            }

            oep::runtime::RelationshipCreateSpec internal_spec;
            internal_spec.source_object_id = specs[i].source_object_id;
            internal_spec.target_object_id = specs[i].target_object_id;
            internal_spec.relationship_type = *internal_type;
            internal_spec.author = specs[i].author != nullptr ? specs[i].author : "";
            internal_spec.description = specs[i].description != nullptr ? specs[i].description : "";
            internal_specs.push_back(std::move(internal_spec));
        }

        const oep::runtime::RuntimeBatchCreateRelationshipsResult result =
            runtime->runtime.batch_create_relationships(internal_specs);
        if (!result.success) {
            const oep_error_code_t code = classify_mutation_error(result.error);
            oep_result_t error_result = make_error_result(code, category_for_code(code), result.error);
            out_result->failed_index = result.failed_index;
            return error_result;
        }

        const int created_count = static_cast<int>(result.created.size());
        oep_relationship_info_t* items =
            created_count > 0 ? new oep_relationship_info_t[static_cast<std::size_t>(created_count)] : nullptr;
        for (int i = 0; i < created_count; ++i) {
            populate_relationship_info(result.created[static_cast<std::size_t>(i)], &items[i]);
        }
        out_result->success = 1;
        out_result->failed_index = -1;
        out_result->created.items = items;
        out_result->created.count = created_count;
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_batch_create_relationships_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_batch_create_relationships_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_batch_create_relationships_result_release(oep_batch_create_relationships_result_t* result) {
    if (result == nullptr) {
        return;
    }
    delete[] result->created.items;
    result->created.items = nullptr;
    result->created.count = 0;
}

oep_result_t oep_package_install(OEP_Runtime runtime, const char* archive_path,
                                  oep_package_install_result_t* out_result) {
    if (out_result != nullptr) {
        zero_package_install_result(out_result);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (archive_path == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "archive_path is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        // WP-REP-006: routed through RuntimeService (sequencing +
        // event publication) instead of calling runtime.install_package
        // directly. The install logic itself is unchanged -- it still
        // lives entirely in FoundationRuntime::install_package.
        const oep::runtime::RuntimeService::InstallPackageResponse result =
            runtime->service.install_package(oep::runtime::RuntimeService::InstallPackageRequest(
                std::filesystem::path(archive_path)));
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_result != nullptr) {
            oep::api::detail::copy_truncated(result.package_id, out_result->package_id,
                                              sizeof(out_result->package_id));
            oep::api::detail::copy_truncated(result.version, out_result->version, sizeof(out_result->version));
            out_result->objects_created = result.objects_created;
            out_result->relationships_created = result.relationships_created;
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_package_install_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_package_install_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_list_installed(OEP_Runtime runtime, oep_installed_package_list_t* out_list) {
    if (out_list != nullptr) {
        zero_installed_package_list(out_list);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeInstalledPackagesResult listed = runtime->runtime.list_installed_packages();
        if (!listed.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      listed.error);
        }

        std::vector<oep::installer::RepositoryRegistryEntry> packages = listed.packages;
        std::sort(packages.begin(), packages.end(),
                  [](const oep::installer::RepositoryRegistryEntry& a, const oep::installer::RepositoryRegistryEntry& b) {
                      return a.package_id < b.package_id;
                  });

        const int count = static_cast<int>(packages.size());
        oep_installed_package_info_t* items =
            count > 0 ? new oep_installed_package_info_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_installed_package_info(packages[static_cast<std::size_t>(i)], &items[i]);
        }

        out_list->items = items;
        out_list->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_installed_package_list_release(oep_installed_package_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_package_get_info(OEP_Runtime runtime, const char* package_id, oep_package_details_t* out_details) {
    if (out_details != nullptr) {
        zero_package_details(out_details);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (package_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "package_id is null");
    }
    if (out_details == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_details is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeInstalledPackageResult found = runtime->runtime.get_installed_package(package_id);
        if (!found.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      found.error);
        }
        if (!found.installed) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "package '" + std::string(package_id) + "' is not installed");
        }
        populate_package_details(found.entry, out_details);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_package_details(out_details);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_package_details(out_details);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_get_contents(OEP_Runtime runtime, const char* package_id, oep_object_list_t* out_objects,
                                       oep_relationship_list_t* out_relationships) {
    if (out_objects != nullptr) {
        zero_object_list(out_objects);
    }
    if (out_relationships != nullptr) {
        zero_relationship_list(out_relationships);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (package_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "package_id is null");
    }
    if (out_objects == nullptr || out_relationships == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_objects/out_relationships must not be null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeInstalledPackageResult found = runtime->runtime.get_installed_package(package_id);
        if (!found.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      found.error);
        }
        if (!found.installed) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "package '" + std::string(package_id) + "' is not installed");
        }

        // Load each recorded contribution live from the repository's own
        // stores; a recorded-but-deleted entity is silently skipped here
        // (oep_package_verify is the function that reports that
        // condition explicitly).
        std::vector<oep::repository::EngineeringObject> objects;
        for (const std::string& object_id : found.entry.object_ids) {
            const oep::repository::LoadObjectResult loaded = runtime->runtime.object_store()->load(object_id);
            if (loaded.success) {
                objects.push_back(loaded.object);
            }
        }
        std::vector<oep::repository::Relationship> relationships;
        for (const std::string& relationship_id : found.entry.relationship_ids) {
            const oep::repository::LoadRelationshipResult loaded =
                runtime->runtime.relationship_store()->load(relationship_id);
            if (loaded.success) {
                relationships.push_back(loaded.relationship);
            }
        }

        const int object_count = static_cast<int>(objects.size());
        oep_object_info_t* object_items =
            object_count > 0 ? new oep_object_info_t[static_cast<std::size_t>(object_count)] : nullptr;
        for (int i = 0; i < object_count; ++i) {
            populate_object_info(objects[static_cast<std::size_t>(i)], &object_items[i]);
        }

        const int relationship_count = static_cast<int>(relationships.size());
        oep_relationship_info_t* relationship_items = nullptr;
        try {
            relationship_items = relationship_count > 0
                                     ? new oep_relationship_info_t[static_cast<std::size_t>(relationship_count)]
                                     : nullptr;
        } catch (...) {
            delete[] object_items;
            throw;
        }
        for (int i = 0; i < relationship_count; ++i) {
            populate_relationship_info(relationships[static_cast<std::size_t>(i)], &relationship_items[i]);
        }

        out_objects->items = object_items;
        out_objects->count = object_count;
        out_relationships->items = relationship_items;
        out_relationships->count = relationship_count;
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_object_list(out_objects);
        zero_relationship_list(out_relationships);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_object_list(out_objects);
        zero_relationship_list(out_relationships);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_locate(OEP_Runtime runtime, const char* entity_id, oep_package_owner_t* out_owner) {
    if (out_owner != nullptr) {
        zero_package_owner(out_owner);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (entity_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "entity_id is null");
    }
    if (out_owner == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_owner is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimePackageOwnerResult found = runtime->runtime.find_package_owner(entity_id);
        if (!found.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      found.error);
        }
        if (found.kind != oep::installer::OwnedEntityKind::None) {
            out_owner->found = 1;
            out_owner->kind = found.kind == oep::installer::OwnedEntityKind::Object ? OEP_OWNED_ENTITY_OBJECT
                                                                                     : OEP_OWNED_ENTITY_RELATIONSHIP;
            oep::api::detail::copy_truncated(found.owner.package_id, out_owner->package_id,
                                              sizeof(out_owner->package_id));
            oep::api::detail::copy_truncated(found.owner.version, out_owner->version, sizeof(out_owner->version));
            oep::api::detail::copy_truncated(found.owner.title, out_owner->title, sizeof(out_owner->title));
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_package_owner(out_owner);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_package_owner(out_owner);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_verify(OEP_Runtime runtime, const char* package_id,
                                 oep_package_verify_result_t* out_result) {
    if (out_result != nullptr) {
        zero_package_verify_result(out_result);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (package_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "package_id is null");
    }
    if (out_result == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_result is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeVerifyPackageResult verified = runtime->runtime.verify_package(package_id);
        if (!verified.success) {
            const oep_error_code_t code = verified.error.find("is not installed") != std::string::npos
                                               ? OEP_ERROR_NOT_FOUND
                                               : OEP_ERROR_OPERATION_FAILED;
            return make_error_result(code, category_for_code(code), verified.error);
        }
        out_result->verified = verified.verified ? 1 : 0;
        out_result->objects_expected = verified.objects_expected;
        out_result->objects_present = verified.objects_present;
        out_result->relationships_expected = verified.relationships_expected;
        out_result->relationships_present = verified.relationships_present;
        out_result->archive_available = verified.archive_available ? 1 : 0;
        out_result->archive_hash_matches = verified.archive_hash_matches ? 1 : 0;
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_package_verify_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_package_verify_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_search(OEP_Runtime runtime, const char* query, oep_installed_package_list_t* out_list) {
    if (out_list != nullptr) {
        zero_installed_package_list(out_list);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (query == nullptr || query[0] == '\0') {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "query must not be null or empty");
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeSearchPackagesResult searched = runtime->runtime.search_installed_packages(query);
        if (!searched.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      searched.error);
        }

        std::vector<oep::installer::RepositoryRegistryEntry> packages = searched.packages;
        std::sort(packages.begin(), packages.end(),
                  [](const oep::installer::RepositoryRegistryEntry& a, const oep::installer::RepositoryRegistryEntry& b) {
                      return a.package_id < b.package_id;
                  });

        const int count = static_cast<int>(packages.size());
        oep_installed_package_info_t* items =
            count > 0 ? new oep_installed_package_info_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_installed_package_info(packages[static_cast<std::size_t>(i)], &items[i]);
        }

        out_list->items = items;
        out_list->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_transaction_get_info(OEP_Runtime runtime, oep_transaction_info_t* out_info) {
    if (out_info != nullptr) {
        zero_transaction_info(out_info);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_info == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_info is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeTransactionInfoResult info = runtime->runtime.current_transaction_info();
        if (!info.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      info.error);
        }
        out_info->active = info.active ? 1 : 0;
        if (info.active) {
            oep::api::detail::copy_truncated(info.transaction_id, out_info->transaction_id,
                                              sizeof(out_info->transaction_id));
            oep::api::detail::copy_truncated(info.description, out_info->description,
                                              sizeof(out_info->description));
            out_info->journal_entry_count = info.entry_count;
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_transaction_info(out_info);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_transaction_info(out_info);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_transaction_history(OEP_Runtime runtime, oep_transaction_record_list_t* out_list) {
    if (out_list != nullptr) {
        zero_transaction_record_list(out_list);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeTransactionHistoryResult history = runtime->runtime.transaction_history();
        if (!history.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      history.error);
        }

        const int count = static_cast<int>(history.records.size());
        oep_transaction_record_t* items =
            count > 0 ? new oep_transaction_record_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_transaction_record(history.records[static_cast<std::size_t>(i)], &items[i]);
        }
        out_list->items = items;
        out_list->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_transaction_record_list_release(oep_transaction_record_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

const char* oep_trust_state_to_string(oep_trust_state_t state) {
    switch (state) {
        case OEP_TRUST_TRUSTED: return "Trusted";
        case OEP_TRUST_UNSIGNED: return "Unsigned";
        case OEP_TRUST_UNKNOWN_PUBLISHER: return "UnknownPublisher";
        case OEP_TRUST_EXPIRED_CERTIFICATE: return "ExpiredCertificate";
        case OEP_TRUST_REVOKED_CERTIFICATE: return "RevokedCertificate";
        case OEP_TRUST_INVALID_SIGNATURE: return "InvalidSignature";
        case OEP_TRUST_TAMPERED: return "Tampered";
    }
    return "InvalidSignature";
}

oep_result_t oep_trust_add_certificate(OEP_Runtime runtime, const char* publisher_id, const char* publisher_name,
                                        const char* public_key_hex, const char* issued_utc, const char* expires_utc,
                                        const char* issuer, const char* version,
                                        oep_publisher_certificate_t* out_certificate) {
    if (out_certificate != nullptr) {
        zero_publisher_certificate(out_certificate);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (publisher_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "publisher_id is null");
    }
    if (public_key_hex == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "public_key_hex is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        oep::installer::PublisherCertificate certificate;
        certificate.publisher_id = publisher_id;
        certificate.publisher_name = publisher_name != nullptr ? publisher_name : "";
        certificate.public_key_hex = public_key_hex;
        certificate.issued_utc = issued_utc != nullptr ? issued_utc : "";
        certificate.expires_utc = expires_utc != nullptr ? expires_utc : "";
        certificate.issuer = issuer != nullptr ? issuer : "";
        certificate.version = version != nullptr ? version : "";

        const oep::runtime::RuntimeTrustResult added = runtime->runtime.trust_add_certificate(certificate);
        if (!added.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      added.error);
        }
        if (out_certificate != nullptr) {
            const oep::runtime::RuntimeCertificateResult stored = runtime->runtime.trust_get_certificate(publisher_id);
            if (stored.success && stored.found) {
                populate_publisher_certificate(stored.certificate, out_certificate);
            }
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_publisher_certificate(out_certificate);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_publisher_certificate(out_certificate);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_trust_get_certificate(OEP_Runtime runtime, const char* publisher_id,
                                        oep_publisher_certificate_t* out_certificate) {
    if (out_certificate != nullptr) {
        zero_publisher_certificate(out_certificate);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (publisher_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "publisher_id is null");
    }
    if (out_certificate == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_certificate is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeCertificateResult found = runtime->runtime.trust_get_certificate(publisher_id);
        if (!found.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      found.error);
        }
        if (!found.found) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "publisher '" + std::string(publisher_id) + "' has no trusted certificate");
        }
        populate_publisher_certificate(found.certificate, out_certificate);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_publisher_certificate(out_certificate);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_publisher_certificate(out_certificate);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_trust_list_certificates(OEP_Runtime runtime, oep_certificate_list_t* out_list) {
    if (out_list != nullptr) {
        zero_certificate_list(out_list);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeCertificateListResult listed = runtime->runtime.trust_list_certificates();
        if (!listed.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      listed.error);
        }
        const int count = static_cast<int>(listed.certificates.size());
        oep_publisher_certificate_t* items =
            count > 0 ? new oep_publisher_certificate_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_publisher_certificate(listed.certificates[static_cast<std::size_t>(i)], &items[i]);
        }
        out_list->items = items;
        out_list->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

void oep_certificate_list_release(oep_certificate_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_trust_revoke_certificate(OEP_Runtime runtime, const char* publisher_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (publisher_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "publisher_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeCertificateResult existing = runtime->runtime.trust_get_certificate(publisher_id);
        if (existing.success && !existing.found) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "publisher '" + std::string(publisher_id) + "' has no trusted certificate");
        }
        const oep::runtime::RuntimeTrustResult revoked = runtime->runtime.trust_revoke_certificate(publisher_id);
        if (!revoked.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      revoked.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_trust_get_policy(OEP_Runtime runtime, int* out_require_signatures) {
    if (out_require_signatures != nullptr) {
        *out_require_signatures = 0;
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_require_signatures == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_require_signatures is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeTrustPolicyResult policy = runtime->runtime.trust_get_policy();
        if (!policy.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      policy.error);
        }
        *out_require_signatures = policy.require_signatures ? 1 : 0;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_trust_set_policy(OEP_Runtime runtime, int require_signatures) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeTrustResult set = runtime->runtime.trust_set_policy(require_signatures != 0);
        if (!set.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      set.error);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_get_trust_status(OEP_Runtime runtime, const char* package_id,
                                           oep_package_trust_status_t* out_status) {
    if (out_status != nullptr) {
        zero_package_trust_status(out_status);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (package_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "package_id is null");
    }
    if (out_status == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_status is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeInstalledPackageResult found = runtime->runtime.get_installed_package(package_id);
        if (!found.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      found.error);
        }
        if (!found.installed) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "package '" + std::string(package_id) + "' is not installed");
        }
        out_status->state = to_capi_trust_state(from_capi_trust_state_name(found.entry.trust_status));
        oep::api::detail::copy_truncated(found.entry.trust_fingerprint, out_status->fingerprint,
                                          sizeof(out_status->fingerprint));
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_package_trust_status(out_status);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_package_trust_status(out_status);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

const char* oep_dependency_state_to_string(oep_dependency_state_t state) {
    switch (state) {
        case OEP_DEPENDENCY_SATISFIED: return "Satisfied";
        case OEP_DEPENDENCY_MISSING: return "Missing";
        case OEP_DEPENDENCY_OPTIONAL: return "Optional";
        case OEP_DEPENDENCY_CONFLICTING: return "Conflicting";
        case OEP_DEPENDENCY_CYCLIC: return "Cyclic";
        case OEP_DEPENDENCY_UNKNOWN: return "Unknown";
    }
    return "Unknown";
}

void oep_dependency_entry_list_release(oep_dependency_entry_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

void oep_package_id_list_release(oep_package_id_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_package_resolve_dependencies(OEP_Runtime runtime, const char* archive_path,
                                               oep_dependency_resolution_result_t* out_result,
                                               oep_dependency_entry_list_t* out_entries,
                                               oep_package_id_list_t* out_install_order) {
    if (out_result != nullptr) {
        zero_dependency_resolution_result(out_result);
    }
    if (out_entries != nullptr) {
        zero_dependency_entry_list(out_entries);
    }
    if (out_install_order != nullptr) {
        zero_package_id_list(out_install_order);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (archive_path == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "archive_path is null");
    }
    if (out_result == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_result is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeDependencyResolutionResult resolved =
            runtime->runtime.resolve_package_dependencies(archive_path);
        if (!resolved.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      resolved.error);
        }

        const oep::installer::DependencyResolutionReport& report = resolved.report;
        out_result->resolved = report.result == oep::installer::DependencyResolutionResult::Resolved ? 1 : 0;
        out_result->cycle_detected = report.cycle.has_value() ? 1 : 0;
        if (report.cycle.has_value()) {
            oep::api::detail::copy_truncated(describe_cycle(*report.cycle), out_result->cycle_description,
                                              sizeof(out_result->cycle_description));
        }

        if (out_entries != nullptr) {
            const int count = static_cast<int>(report.entries.size());
            oep_dependency_entry_t* items =
                count > 0 ? new oep_dependency_entry_t[static_cast<std::size_t>(count)] : nullptr;
            for (int i = 0; i < count; ++i) {
                populate_dependency_entry(report.entries[static_cast<std::size_t>(i)], &items[i]);
            }
            out_entries->items = items;
            out_entries->count = count;
        }

        if (out_install_order != nullptr) {
            const int count = static_cast<int>(report.install_order.size());
            oep_package_id_t* items = count > 0 ? new oep_package_id_t[static_cast<std::size_t>(count)] : nullptr;
            for (int i = 0; i < count; ++i) {
                oep::api::detail::copy_truncated(report.install_order[static_cast<std::size_t>(i)], items[i].id,
                                                  sizeof(items[i].id));
            }
            out_install_order->items = items;
            out_install_order->count = count;
        }

        return make_success_result();
    } catch (const std::exception& ex) {
        zero_dependency_resolution_result(out_result);
        if (out_entries != nullptr) zero_dependency_entry_list(out_entries);
        if (out_install_order != nullptr) zero_package_id_list(out_install_order);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_dependency_resolution_result(out_result);
        if (out_entries != nullptr) zero_dependency_entry_list(out_entries);
        if (out_install_order != nullptr) zero_package_id_list(out_install_order);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

namespace {

oep_package_id_list_t build_package_id_list(const std::vector<std::string>& ids) {
    const int count = static_cast<int>(ids.size());
    oep_package_id_t* items = count > 0 ? new oep_package_id_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        oep::api::detail::copy_truncated(ids[static_cast<std::size_t>(i)], items[i].id, sizeof(items[i].id));
    }
    oep_package_id_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

} // namespace

oep_result_t oep_package_analyze_uninstall_impact(OEP_Runtime runtime, const char* package_id,
                                                    oep_uninstall_impact_t* out_impact,
                                                    oep_package_id_list_t* out_blocking_dependents) {
    if (out_impact != nullptr) {
        zero_uninstall_impact(out_impact);
    }
    if (out_blocking_dependents != nullptr) {
        zero_package_id_list(out_blocking_dependents);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (package_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "package_id is null");
    }
    if (out_impact == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_impact is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        // WP-REP-007: routed through RuntimeService exclusively (not
        // runtime->runtime directly), per this Work Package's "all
        // lifecycle operations execute exclusively through
        // RuntimeService" requirement.
        const oep::runtime::RuntimeService::UninstallImpactReport report =
            runtime->service.analyze_uninstall_impact(
                oep::runtime::RuntimeService::AnalyzeUninstallImpactRequest(package_id));
        if (!report.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      report.error);
        }

        out_impact->found = report.found ? 1 : 0;
        out_impact->objects_affected = report.objects_affected;
        out_impact->relationships_affected = report.relationships_affected;
        out_impact->removable = report.removable ? 1 : 0;

        if (out_blocking_dependents != nullptr) {
            *out_blocking_dependents = build_package_id_list(report.blocking_dependents);
        }

        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_impact != nullptr) zero_uninstall_impact(out_impact);
        if (out_blocking_dependents != nullptr) zero_package_id_list(out_blocking_dependents);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_impact != nullptr) zero_uninstall_impact(out_impact);
        if (out_blocking_dependents != nullptr) zero_package_id_list(out_blocking_dependents);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_uninstall(OEP_Runtime runtime, const char* package_id,
                                    oep_package_uninstall_result_t* out_result) {
    if (out_result != nullptr) {
        zero_package_uninstall_result(out_result);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (package_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "package_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::UninstallPackageResponse result =
            runtime->service.uninstall_package(oep::runtime::RuntimeService::UninstallPackageRequest(package_id));
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_result != nullptr) {
            oep::api::detail::copy_truncated(result.package_id, out_result->package_id,
                                              sizeof(out_result->package_id));
            out_result->objects_removed = result.objects_removed;
            out_result->relationships_removed = result.relationships_removed;
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_package_uninstall_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_package_uninstall_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_analyze_update_impact(OEP_Runtime runtime, const char* archive_path,
                                                 oep_update_impact_t* out_impact,
                                                 oep_package_id_list_t* out_broken_dependents) {
    if (out_impact != nullptr) {
        zero_update_impact(out_impact);
    }
    if (out_broken_dependents != nullptr) {
        zero_package_id_list(out_broken_dependents);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (archive_path == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "archive_path is null");
    }
    if (out_impact == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_impact is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::UpdateImpactReport report = runtime->service.analyze_update_impact(
            oep::runtime::RuntimeService::AnalyzeUpdateImpactRequest(std::filesystem::path(archive_path)));
        if (!report.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      report.error);
        }

        out_impact->currently_installed = report.currently_installed ? 1 : 0;
        oep::api::detail::copy_truncated(report.current_version, out_impact->current_version,
                                          sizeof(out_impact->current_version));
        oep::api::detail::copy_truncated(report.candidate_version, out_impact->candidate_version,
                                          sizeof(out_impact->candidate_version));
        oep::api::detail::copy_truncated(report.trust_status, out_impact->trust_status,
                                          sizeof(out_impact->trust_status));
        out_impact->updatable = report.updatable ? 1 : 0;

        if (out_broken_dependents != nullptr) {
            *out_broken_dependents = build_package_id_list(report.broken_dependents);
        }

        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_impact != nullptr) zero_update_impact(out_impact);
        if (out_broken_dependents != nullptr) zero_package_id_list(out_broken_dependents);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_impact != nullptr) zero_update_impact(out_impact);
        if (out_broken_dependents != nullptr) zero_package_id_list(out_broken_dependents);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_package_update(OEP_Runtime runtime, const char* archive_path,
                                 oep_package_update_result_t* out_result) {
    if (out_result != nullptr) {
        zero_package_update_result(out_result);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (archive_path == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "archive_path is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::UpdatePackageResponse result = runtime->service.update_package(
            oep::runtime::RuntimeService::UpdatePackageRequest(std::filesystem::path(archive_path)));
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_result != nullptr) {
            oep::api::detail::copy_truncated(result.package_id, out_result->package_id,
                                              sizeof(out_result->package_id));
            oep::api::detail::copy_truncated(result.previous_version, out_result->previous_version,
                                              sizeof(out_result->previous_version));
            oep::api::detail::copy_truncated(result.new_version, out_result->new_version,
                                              sizeof(out_result->new_version));
            out_result->objects_removed = result.objects_removed;
            out_result->relationships_removed = result.relationships_removed;
            out_result->objects_created = result.objects_created;
            out_result->relationships_created = result.relationships_created;
            oep::api::detail::copy_truncated(result.trust_status, out_result->trust_status,
                                              sizeof(out_result->trust_status));
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_package_update_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_package_update_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

const char* oep_merge_conflict_kind_to_string(oep_merge_conflict_kind_t kind) {
    switch (kind) {
        case OEP_MERGE_CONFLICT_OBJECT_CONTENT: return "ObjectContentConflict";
        case OEP_MERGE_CONFLICT_RELATIONSHIP_CONTENT: return "RelationshipContentConflict";
        case OEP_MERGE_CONFLICT_RELATIONSHIP_MISSING_ENDPOINT: return "RelationshipMissingEndpoint";
    }
    return "Unknown";
}

void oep_merge_conflict_list_release(oep_merge_conflict_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_repository_plan_merge(OEP_Runtime runtime, const char* archive_path, oep_merge_plan_t* out_plan,
                                        oep_merge_conflict_list_t* out_conflicts) {
    if (out_plan != nullptr) {
        zero_merge_plan(out_plan);
    }
    if (out_conflicts != nullptr) {
        zero_merge_conflict_list(out_conflicts);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (archive_path == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "archive_path is null");
    }
    if (out_plan == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_plan is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        // WP-REP-008: routed through RuntimeService exclusively (not
        // runtime->runtime directly), mirroring WP-REP-007's
        // uninstall/update.
        const oep::runtime::RuntimeService::MergePlanReport report =
            runtime->service.plan_merge(oep::runtime::RuntimeService::PlanMergeRequest(std::filesystem::path(archive_path)));
        if (!report.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      report.error);
        }

        oep::api::detail::copy_truncated(report.package_id, out_plan->package_id, sizeof(out_plan->package_id));
        oep::api::detail::copy_truncated(report.version, out_plan->version, sizeof(out_plan->version));
        oep::api::detail::copy_truncated(report.trust_status, out_plan->trust_status, sizeof(out_plan->trust_status));
        out_plan->trust_blocks = report.trust_blocks ? 1 : 0;
        out_plan->dependency_blocks = report.dependency_blocks ? 1 : 0;
        out_plan->already_registered = report.already_registered ? 1 : 0;
        out_plan->objects_to_create = static_cast<int>(report.plan.change_set.object_changes().size());
        out_plan->relationships_to_create = static_cast<int>(report.plan.change_set.relationship_changes().size());
        out_plan->mergeable = report.mergeable ? 1 : 0;

        if (out_conflicts != nullptr) {
            *out_conflicts = build_merge_conflict_list(report.plan.conflicts);
        }

        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_plan != nullptr) zero_merge_plan(out_plan);
        if (out_conflicts != nullptr) zero_merge_conflict_list(out_conflicts);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_plan != nullptr) zero_merge_plan(out_plan);
        if (out_conflicts != nullptr) zero_merge_conflict_list(out_conflicts);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_repository_execute_merge(OEP_Runtime runtime, const char* archive_path,
                                           oep_merge_result_t* out_result) {
    if (out_result != nullptr) {
        zero_merge_result(out_result);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (archive_path == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "archive_path is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::runtime::RuntimeService::ExecuteMergeResponse result = runtime->service.execute_merge(
            oep::runtime::RuntimeService::ExecuteMergeRequest(std::filesystem::path(archive_path)));
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_result != nullptr) {
            oep::api::detail::copy_truncated(result.package_id, out_result->package_id,
                                              sizeof(out_result->package_id));
            oep::api::detail::copy_truncated(result.version, out_result->version, sizeof(out_result->version));
            out_result->objects_created = result.objects_created;
            out_result->relationships_created = result.relationships_created;
            oep::api::detail::copy_truncated(result.trust_status, out_result->trust_status,
                                              sizeof(out_result->trust_status));
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_merge_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_merge_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

const char* oep_event_type_to_string(oep_event_type_t type) {
    switch (type) {
        case OEP_EVENT_OBJECT_CREATED: return "ObjectCreated";
        case OEP_EVENT_OBJECT_UPDATED: return "ObjectUpdated";
        case OEP_EVENT_OBJECT_DELETED: return "ObjectDeleted";
        case OEP_EVENT_RELATIONSHIP_CREATED: return "RelationshipCreated";
        case OEP_EVENT_RELATIONSHIP_UPDATED: return "RelationshipUpdated";
        case OEP_EVENT_RELATIONSHIP_DELETED: return "RelationshipDeleted";
        case OEP_EVENT_TRANSACTION_BEGUN: return "TransactionBegun";
        case OEP_EVENT_TRANSACTION_COMMITTED: return "TransactionCommitted";
        case OEP_EVENT_TRANSACTION_ROLLED_BACK: return "TransactionRolledBack";
        case OEP_EVENT_PACKAGE_INSTALLED: return "PackageInstalled";
        case OEP_EVENT_PACKAGE_INSTALL_FAILED: return "PackageInstallFailed";
        case OEP_EVENT_DEPENDENCY_RESOLUTION_COMPLETED: return "DependencyResolutionCompleted";
        case OEP_EVENT_PACKAGE_UNINSTALLED: return "PackageUninstalled";
        case OEP_EVENT_PACKAGE_UPDATED: return "PackageUpdated";
        case OEP_EVENT_REPOSITORY_MERGED: return "RepositoryMerged";
    }
    return "Unknown";
}

void oep_repository_event_list_release(oep_repository_event_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_runtime_recent_events(OEP_Runtime runtime, int limit, oep_repository_event_list_t* out_list) {
    if (out_list != nullptr) {
        zero_repository_event_list(out_list);
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_list == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_list is null");
    }
    try {
        const std::vector<oep::runtime::RepositoryEvent> events =
            runtime->events.recent_events(limit > 0 ? static_cast<std::size_t>(limit) : 0);
        const int count = static_cast<int>(events.size());
        oep_repository_event_t* items = count > 0 ? new oep_repository_event_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            populate_repository_event(events[static_cast<std::size_t>(i)], &items[i]);
        }
        out_list->items = items;
        out_list->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_repository_event_list(out_list);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_repository_event_list(out_list);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

// -------------------------------------------------------------------
// Engineering Knowledge Runtime (WP-EKE-001)
// -------------------------------------------------------------------

namespace {

// Translates an EngineeringContext-family "not loaded"/"not found"-style
// failure string into an oep_error_code_t. These calls never touch
// ObjectStore/RelationshipStore directly (see classify_mutation_error's
// own doc comment for why that classifier doesn't apply here), so the
// classification is intentionally small: "has not been loaded" is
// always the graph-not-loaded precondition (INVALID_STATE); "is not
// present" is always a missing object (NOT_FOUND); anything else is a
// generic OPERATION_FAILED.
oep_error_code_t classify_engine_error(const std::string& message) {
    if (message.find("has not been loaded") != std::string::npos) {
        return OEP_ERROR_INVALID_STATE;
    }
    if (message.find("is not present") != std::string::npos || message.find("not found") != std::string::npos) {
        return OEP_ERROR_NOT_FOUND;
    }
    return OEP_ERROR_OPERATION_FAILED;
}

} // namespace

oep_result_t oep_engine_load_object(OEP_Runtime runtime, const char* object_id, oep_object_info_t* out_object,
                                     int* out_found) {
    if (out_object != nullptr) {
        zero_object_info(out_object);
    }
    if (out_found != nullptr) {
        *out_found = 0;
    }
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::ObjectLoader::LoadObjectResult result = runtime->engine_context.load_object(object_id);
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_found != nullptr) {
            *out_found = result.found ? 1 : 0;
        }
        if (result.found && out_object != nullptr) {
            populate_object_info(result.object, out_object);
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object != nullptr) zero_object_info(out_object);
        if (out_found != nullptr) *out_found = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object != nullptr) zero_object_info(out_object);
        if (out_found != nullptr) *out_found = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_engine_load_graph(OEP_Runtime runtime, int* out_objects_loaded, int* out_relationships_loaded) {
    if (out_objects_loaded != nullptr) *out_objects_loaded = 0;
    if (out_relationships_loaded != nullptr) *out_relationships_loaded = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::EngineeringContext::LoadGraphResult result = runtime->engine_context.load_graph();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_objects_loaded != nullptr) *out_objects_loaded = static_cast<int>(result.objects_loaded);
        if (out_relationships_loaded != nullptr) *out_relationships_loaded = static_cast<int>(result.relationships_loaded);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_engine_query(OEP_Runtime runtime, const oep_engine_query_request_t* request,
                               oep_package_id_list_t* out_object_ids, oep_package_id_list_t* out_relationship_ids,
                               int* out_path_exists) {
    if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
    if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
    if (out_path_exists != nullptr) *out_path_exists = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (request == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "request is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }

        if (request->kind == OEP_ENGINE_QUERY_SUBGRAPH) {
            if (request->subgraph_object_id_count < 0) {
                return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                          "subgraph_object_id_count is negative");
            }
            if (request->subgraph_object_id_count > 0 && request->subgraph_object_ids == nullptr) {
                return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                          "subgraph_object_ids is null but subgraph_object_id_count is nonzero");
            }
            std::vector<std::string> ids;
            ids.reserve(static_cast<std::size_t>(request->subgraph_object_id_count));
            for (int i = 0; i < request->subgraph_object_id_count; ++i) {
                ids.emplace_back(request->subgraph_object_ids[i] != nullptr ? request->subgraph_object_ids[i] : "");
            }
            const oep::engine::SubgraphResult result = runtime->engine_context.subgraph(ids);
            if (!result.success) {
                const oep_error_code_t code = classify_engine_error(result.error);
                return make_error_result(code, category_for_code(code), result.error);
            }
            if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
            if (out_relationship_ids != nullptr) *out_relationship_ids = build_package_id_list(result.relationship_ids);
            return make_success_result();
        }

        if (request->kind == OEP_ENGINE_QUERY_SHORTEST_PATH) {
            const oep::engine::PathResult result = runtime->engine_context.shortest_path(
                request->source_object_id != nullptr ? request->source_object_id : "",
                request->target_object_id != nullptr ? request->target_object_id : "");
            if (!result.success) {
                const oep_error_code_t code = classify_engine_error(result.error);
                return make_error_result(code, category_for_code(code), result.error);
            }
            if (out_path_exists != nullptr) *out_path_exists = result.path_exists ? 1 : 0;
            if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.path);
            return make_success_result();
        }

        oep::engine::EngineeringContext::QueryRequest internal_request;
        switch (request->kind) {
            case OEP_ENGINE_QUERY_BY_ID:
                internal_request.kind = oep::engine::EngineeringContext::QueryKind::ById;
                internal_request.object_id = request->object_id != nullptr ? request->object_id : "";
                break;
            case OEP_ENGINE_QUERY_BY_TYPE: {
                const std::optional<oep::repository::ObjectType> internal_type =
                    from_capi_object_type(request->object_type);
                if (!internal_type.has_value()) {
                    return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                              "unrecognized object_type");
                }
                internal_request.kind = oep::engine::EngineeringContext::QueryKind::ByType;
                internal_request.object_type = *internal_type;
                break;
            }
            case OEP_ENGINE_QUERY_BY_DOMAIN:
                internal_request.kind = oep::engine::EngineeringContext::QueryKind::ByDomain;
                internal_request.domain = request->domain != nullptr ? request->domain : "";
                break;
            case OEP_ENGINE_QUERY_BY_RELATIONSHIP: {
                const std::optional<oep::repository::RelationshipType> internal_type =
                    from_capi_relationship_type(request->relationship_type);
                if (!internal_type.has_value()) {
                    return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                              "unrecognized relationship_type");
                }
                internal_request.kind = oep::engine::EngineeringContext::QueryKind::ByRelationship;
                internal_request.relationship_type = *internal_type;
                break;
            }
            case OEP_ENGINE_QUERY_CONNECTED_COMPONENT:
                internal_request.kind = oep::engine::EngineeringContext::QueryKind::ConnectedComponent;
                internal_request.object_id = request->object_id != nullptr ? request->object_id : "";
                break;
            case OEP_ENGINE_QUERY_SHORTEST_PATH:
            case OEP_ENGINE_QUERY_SUBGRAPH:
                // Handled above; unreachable here.
                return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL),
                                          "unreachable query kind dispatch");
            default:
                return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                          "unrecognized query kind");
        }

        const oep::engine::QueryResult result = runtime->engine_context.query(internal_request);
        if (!result.success) {
            const oep_error_code_t code = classify_engine_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_engine_traverse(OEP_Runtime runtime, const char* start_object_id, int order,
                                  int has_relationship_filter, oep_relationship_type_t relationship_filter,
                                  int has_max_depth, int max_depth, oep_package_id_list_t* out_object_ids) {
    if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (start_object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "start_object_id is null");
    }
    if (order != 0 && order != 1) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "order must be 0 (BreadthFirst) or 1 (DepthFirst)");
    }
    oep::engine::TraversalOptions options;
    options.order = order == 1 ? oep::engine::TraversalOrder::DepthFirst : oep::engine::TraversalOrder::BreadthFirst;
    if (has_relationship_filter) {
        const std::optional<oep::repository::RelationshipType> internal_type =
            from_capi_relationship_type(relationship_filter);
        if (!internal_type.has_value()) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      "unrecognized relationship_filter");
        }
        options.relationship_type_filter = *internal_type;
    }
    if (has_max_depth) {
        if (max_depth < 0) {
            return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                      "max_depth is negative");
        }
        options.max_depth = max_depth;
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::TraversalResult result = runtime->engine_context.traverse(start_object_id, options);
        if (!result.success) {
            const oep_error_code_t code = classify_engine_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_engine_related_objects(OEP_Runtime runtime, const char* object_id,
                                         oep_package_id_list_t* out_object_ids) {
    if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::RelatedObjectsResult result = runtime->engine_context.related_objects(object_id);
        if (!result.success) {
            const oep_error_code_t code = classify_engine_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_engine_dependency_graph(OEP_Runtime runtime, const char* object_id,
                                          oep_package_id_list_t* out_object_ids,
                                          oep_package_id_list_t* out_relationship_ids) {
    if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
    if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::EngineeringContext::DependencyGraphResult result =
            runtime->engine_context.dependency_graph(object_id);
        if (!result.success) {
            const oep_error_code_t code = classify_engine_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        if (out_relationship_ids != nullptr) *out_relationship_ids = build_package_id_list(result.relationship_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

// -------------------------------------------------------------------
// Engineering Knowledge Graph Engine (WP-EKE-002)
// -------------------------------------------------------------------

namespace {

oep_graph_issue_kind_t to_capi_graph_issue_kind(oep::engine::GraphIssueKind kind) {
    switch (kind) {
        case oep::engine::GraphIssueKind::MissingEndpoint: return OEP_GRAPH_ISSUE_MISSING_ENDPOINT;
        case oep::engine::GraphIssueKind::DuplicateRelationship: return OEP_GRAPH_ISSUE_DUPLICATE_RELATIONSHIP;
        case oep::engine::GraphIssueKind::SelfReference: return OEP_GRAPH_ISSUE_SELF_REFERENCE;
        case oep::engine::GraphIssueKind::BrokenReference: return OEP_GRAPH_ISSUE_BROKEN_REFERENCE;
        case oep::engine::GraphIssueKind::Cycle: return OEP_GRAPH_ISSUE_CYCLE;
        case oep::engine::GraphIssueKind::InvalidRelationshipType: return OEP_GRAPH_ISSUE_INVALID_RELATIONSHIP_TYPE;
    }
    return OEP_GRAPH_ISSUE_MISSING_ENDPOINT;
}

void zero_graph_issue_list(oep_graph_issue_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_graph_statistics(oep_graph_statistics_t* out_stats) {
    out_stats->object_count = 0;
    out_stats->relationship_count = 0;
    out_stats->connected_component_count = 0;
    out_stats->density = 0.0;
    out_stats->maximum_depth = 0;
    out_stats->average_degree = 0.0;
}

void zero_component_membership_list(oep_component_membership_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

oep_graph_issue_list_t build_graph_issue_list(const std::vector<oep::engine::GraphIssue>& issues) {
    const int count = static_cast<int>(issues.size());
    oep_graph_issue_t* items = count > 0 ? new oep_graph_issue_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        const oep::engine::GraphIssue& issue = issues[static_cast<std::size_t>(i)];
        items[i].kind = to_capi_graph_issue_kind(issue.kind);
        oep::api::detail::copy_truncated(issue.relationship_id, items[i].relationship_id,
                                          sizeof(items[i].relationship_id));
        oep::api::detail::copy_truncated(issue.detail, items[i].detail, sizeof(items[i].detail));
    }
    oep_graph_issue_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

oep_component_membership_list_t build_component_membership_list(const std::vector<std::vector<std::string>>& components) {
    std::size_t total = 0;
    for (const std::vector<std::string>& component : components) total += component.size();
    const int count = static_cast<int>(total);
    oep_component_membership_t* items =
        count > 0 ? new oep_component_membership_t[static_cast<std::size_t>(count)] : nullptr;
    int index = 0;
    for (std::size_t component_index = 0; component_index < components.size(); ++component_index) {
        for (const std::string& object_id : components[component_index]) {
            oep::api::detail::copy_truncated(object_id, items[index].object_id, sizeof(items[index].object_id));
            items[index].component_index = static_cast<int>(component_index);
            ++index;
        }
    }
    oep_component_membership_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

// The Knowledge Graph Engine's own result types carry a plain `error`
// string with no structured code (unlike EngineeringContext's family,
// which classify_engine_error above already handles); everything here
// that fails on its own merits (not built yet, bad argument) is
// OPERATION_FAILED, distinguished only by message text.
oep_error_code_t classify_kge_error(const std::string& message) {
    if (message.find("has not been") != std::string::npos || message.find("not been built") != std::string::npos) {
        return OEP_ERROR_INVALID_STATE;
    }
    if (message.find("not present") != std::string::npos || message.find("not found") != std::string::npos) {
        return OEP_ERROR_NOT_FOUND;
    }
    return OEP_ERROR_OPERATION_FAILED;
}

char* copy_owned_string(const std::string& text, std::size_t* out_length) {
    char* buffer = new char[text.size() + 1];
    std::memcpy(buffer, text.data(), text.size());
    buffer[text.size()] = '\0';
    if (out_length != nullptr) *out_length = text.size();
    return buffer;
}

} // namespace

const char* oep_graph_issue_kind_to_string(oep_graph_issue_kind_t kind) {
    switch (kind) {
        case OEP_GRAPH_ISSUE_MISSING_ENDPOINT: return "MissingEndpoint";
        case OEP_GRAPH_ISSUE_DUPLICATE_RELATIONSHIP: return "DuplicateRelationship";
        case OEP_GRAPH_ISSUE_SELF_REFERENCE: return "SelfReference";
        case OEP_GRAPH_ISSUE_BROKEN_REFERENCE: return "BrokenReference";
        case OEP_GRAPH_ISSUE_CYCLE: return "Cycle";
        case OEP_GRAPH_ISSUE_INVALID_RELATIONSHIP_TYPE: return "InvalidRelationshipType";
    }
    return "MissingEndpoint";
}

void oep_graph_issue_list_release(oep_graph_issue_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

void oep_component_membership_list_release(oep_component_membership_list_t* list) {
    if (list == nullptr) {
        return;
    }
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

void oep_string_release(char** text) {
    if (text == nullptr) {
        return;
    }
    delete[] *text;
    *text = nullptr;
}

namespace {

oep_result_t require_graph_built(OEP_Runtime runtime) {
    if (!runtime->knowledge_graph_engine.graph_built()) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "Knowledge Graph has not been built -- call oep_kge_build_graph first");
    }
    return make_success_result();
}

} // namespace

oep_result_t oep_kge_build_graph(OEP_Runtime runtime, int* out_objects, int* out_relationships) {
    if (out_objects != nullptr) *out_objects = 0;
    if (out_relationships != nullptr) *out_relationships = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::KnowledgeGraphEngine::BuildResult result = runtime->knowledge_graph_engine.build_graph();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_objects != nullptr) *out_objects = static_cast<int>(result.objects);
        if (out_relationships != nullptr) *out_relationships = static_cast<int>(result.relationships);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_refresh_graph(OEP_Runtime runtime, int* out_objects, int* out_relationships) {
    if (out_objects != nullptr) *out_objects = 0;
    if (out_relationships != nullptr) *out_relationships = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::KnowledgeGraphEngine::BuildResult result = runtime->knowledge_graph_engine.refresh_graph();
        if (!result.success) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      result.error);
        }
        if (out_objects != nullptr) *out_objects = static_cast<int>(result.objects);
        if (out_relationships != nullptr) *out_relationships = static_cast<int>(result.relationships);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_validate_graph(OEP_Runtime runtime, int* out_valid, oep_graph_issue_list_t* out_issues) {
    if (out_valid != nullptr) *out_valid = 0;
    if (out_issues != nullptr) zero_graph_issue_list(out_issues);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_valid == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_valid is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const oep::engine::GraphValidationReport report = runtime->knowledge_graph_engine.validate_graph();
        *out_valid = report.valid() ? 1 : 0;
        if (out_issues != nullptr) *out_issues = build_graph_issue_list(report.issues());
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_valid != nullptr) *out_valid = 0;
        if (out_issues != nullptr) zero_graph_issue_list(out_issues);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_valid != nullptr) *out_valid = 0;
        if (out_issues != nullptr) zero_graph_issue_list(out_issues);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_graph_statistics(OEP_Runtime runtime, oep_graph_statistics_t* out_stats) {
    if (out_stats != nullptr) zero_graph_statistics(out_stats);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_stats == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_stats is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const oep::engine::GraphStatistics stats = runtime->knowledge_graph_engine.graph_statistics();
        out_stats->object_count = static_cast<int>(stats.object_count);
        out_stats->relationship_count = static_cast<int>(stats.relationship_count);
        out_stats->connected_component_count = static_cast<int>(stats.connected_component_count);
        out_stats->density = stats.density;
        out_stats->maximum_depth = stats.maximum_depth;
        out_stats->average_degree = stats.average_degree;
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_graph_statistics(out_stats);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_graph_statistics(out_stats);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_connected_components(OEP_Runtime runtime, oep_component_membership_list_t* out_components,
                                           int* out_count) {
    if (out_components != nullptr) zero_component_membership_list(out_components);
    if (out_count != nullptr) *out_count = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const oep::engine::ComponentsResult result = runtime->knowledge_graph_engine.connected_components();
        if (!result.success) {
            const oep_error_code_t code = classify_kge_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_components != nullptr) *out_components = build_component_membership_list(result.components);
        if (out_count != nullptr) *out_count = static_cast<int>(result.components.size());
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_components != nullptr) zero_component_membership_list(out_components);
        if (out_count != nullptr) *out_count = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_components != nullptr) zero_component_membership_list(out_components);
        if (out_count != nullptr) *out_count = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_shortest_path(OEP_Runtime runtime, const char* source_id, const char* target_id,
                                    int* out_path_exists, oep_package_id_list_t* out_path) {
    if (out_path_exists != nullptr) *out_path_exists = 0;
    if (out_path != nullptr) zero_package_id_list(out_path);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (source_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "source_id is null");
    }
    if (target_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "target_id is null");
    }
    if (out_path_exists == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_path_exists is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const oep::engine::GraphPathResult result = runtime->knowledge_graph_engine.shortest_path(source_id, target_id);
        if (!result.success) {
            const oep_error_code_t code = classify_kge_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        *out_path_exists = result.path_exists ? 1 : 0;
        if (out_path != nullptr) *out_path = build_package_id_list(result.path);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_path_exists != nullptr) *out_path_exists = 0;
        if (out_path != nullptr) zero_package_id_list(out_path);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_path_exists != nullptr) *out_path_exists = 0;
        if (out_path != nullptr) zero_package_id_list(out_path);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_subgraph(OEP_Runtime runtime, const char* const* object_ids, int object_id_count,
                               oep_package_id_list_t* out_object_ids, oep_package_id_list_t* out_relationship_ids) {
    if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
    if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id_count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id_count is negative");
    }
    if (object_id_count > 0 && object_ids == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_ids is null but object_id_count is nonzero");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        std::vector<std::string> ids;
        ids.reserve(static_cast<std::size_t>(object_id_count));
        for (int i = 0; i < object_id_count; ++i) {
            ids.emplace_back(object_ids[i] != nullptr ? object_ids[i] : "");
        }
        const oep::engine::GraphSubgraphResult result = runtime->knowledge_graph_engine.subgraph(ids);
        if (!result.success) {
            const oep_error_code_t code = classify_kge_error(result.error);
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        if (out_relationship_ids != nullptr) *out_relationship_ids = build_package_id_list(result.relationship_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_export_json(OEP_Runtime runtime, char** out_text, size_t* out_length) {
    if (out_text != nullptr) *out_text = nullptr;
    if (out_length != nullptr) *out_length = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_text == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_text is null");
    }
    if (out_length == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_length is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const std::string json = runtime->knowledge_graph_engine.export_json();
        *out_text = copy_owned_string(json, out_length);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_text != nullptr) *out_text = nullptr;
        if (out_length != nullptr) *out_length = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_text != nullptr) *out_text = nullptr;
        if (out_length != nullptr) *out_length = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_kge_export_graphml_placeholder(OEP_Runtime runtime, char** out_text, size_t* out_length) {
    if (out_text != nullptr) *out_text = nullptr;
    if (out_length != nullptr) *out_length = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_text == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_text is null");
    }
    if (out_length == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_length is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const std::string graphml = runtime->knowledge_graph_engine.export_graphml_placeholder();
        *out_text = copy_owned_string(graphml, out_length);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_text != nullptr) *out_text = nullptr;
        if (out_length != nullptr) *out_length = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_text != nullptr) *out_text = nullptr;
        if (out_length != nullptr) *out_length = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

} // extern "C"

namespace {

oep::engine::QueryCategory from_capi_query_category(oep_query_category_t category) {
    switch (category) {
        case OEP_QUERY_CATEGORY_OBJECT: return oep::engine::QueryCategory::Object;
        case OEP_QUERY_CATEGORY_RELATIONSHIP: return oep::engine::QueryCategory::Relationship;
        case OEP_QUERY_CATEGORY_DOMAIN: return oep::engine::QueryCategory::Domain;
        case OEP_QUERY_CATEGORY_TYPE: return oep::engine::QueryCategory::Type;
        case OEP_QUERY_CATEGORY_DEPENDENCY: return oep::engine::QueryCategory::Dependency;
        case OEP_QUERY_CATEGORY_NEIGHBORHOOD: return oep::engine::QueryCategory::Neighborhood;
        case OEP_QUERY_CATEGORY_PATH: return oep::engine::QueryCategory::Path;
        case OEP_QUERY_CATEGORY_REFERENCE: return oep::engine::QueryCategory::Reference;
        case OEP_QUERY_CATEGORY_METADATA: return oep::engine::QueryCategory::Metadata;
        case OEP_QUERY_CATEGORY_COMPOSITE: return oep::engine::QueryCategory::Composite;
    }
    return oep::engine::QueryCategory::Object;
}

oep_query_category_t to_capi_query_category(oep::engine::QueryCategory category) {
    switch (category) {
        case oep::engine::QueryCategory::Object: return OEP_QUERY_CATEGORY_OBJECT;
        case oep::engine::QueryCategory::Relationship: return OEP_QUERY_CATEGORY_RELATIONSHIP;
        case oep::engine::QueryCategory::Domain: return OEP_QUERY_CATEGORY_DOMAIN;
        case oep::engine::QueryCategory::Type: return OEP_QUERY_CATEGORY_TYPE;
        case oep::engine::QueryCategory::Dependency: return OEP_QUERY_CATEGORY_DEPENDENCY;
        case oep::engine::QueryCategory::Neighborhood: return OEP_QUERY_CATEGORY_NEIGHBORHOOD;
        case oep::engine::QueryCategory::Path: return OEP_QUERY_CATEGORY_PATH;
        case oep::engine::QueryCategory::Reference: return OEP_QUERY_CATEGORY_REFERENCE;
        case oep::engine::QueryCategory::Metadata: return OEP_QUERY_CATEGORY_METADATA;
        case oep::engine::QueryCategory::Composite: return OEP_QUERY_CATEGORY_COMPOSITE;
    }
    return OEP_QUERY_CATEGORY_OBJECT;
}

int to_capi_traversal_strategy(oep::engine::TraversalStrategy strategy) {
    switch (strategy) {
        case oep::engine::TraversalStrategy::None: return 0;
        case oep::engine::TraversalStrategy::BreadthFirst: return 1;
        case oep::engine::TraversalStrategy::DepthFirst: return 2;
    }
    return 0;
}

oep::engine::QueryRequest build_query_request(const oep_query_request_t& request) {
    oep::engine::QueryFilter filter;
    if (request.filter.has_object_type) {
        filter.object_type = from_capi_object_type(request.filter.object_type);
    }
    if (request.filter.has_domain) {
        filter.domain = std::string(request.filter.domain);
    }
    if (request.filter.has_relationship_type) {
        filter.relationship_type = from_capi_relationship_type(request.filter.relationship_type);
    }
    if (request.filter.has_publisher_id) {
        filter.publisher_id = std::string(request.filter.publisher_id);
    }
    if (request.filter.has_package_id) {
        filter.package_id = std::string(request.filter.package_id);
    }
    for (int i = 0; i < request.filter.tag_count; ++i) {
        if (request.filter.tags != nullptr && request.filter.tags[i] != nullptr) {
            filter.tags.emplace_back(request.filter.tags[i]);
        }
    }
    if (request.filter.has_max_depth) {
        filter.max_depth = request.filter.max_depth;
    }
    if (request.filter.has_outgoing_only) {
        filter.outgoing_only = request.filter.outgoing_only != 0;
    }
    return oep::engine::QueryRequest(from_capi_query_category(request.category), request.primary_object_id,
                                      request.secondary_object_id, filter);
}

void zero_query_plan(oep_query_plan_t* out_plan) {
    out_plan->category = OEP_QUERY_CATEGORY_OBJECT;
    out_plan->strategy = 0;
    out_plan->estimated_cost = 0.0;
}

void populate_query_plan(const oep::engine::QueryPlan& plan, oep_query_plan_t* out_plan) {
    out_plan->category = to_capi_query_category(plan.category());
    out_plan->strategy = to_capi_traversal_strategy(plan.strategy());
    out_plan->estimated_cost = plan.estimated_cost();
}

void zero_query_result_summary(oep_query_result_summary_t* out_summary) {
    out_summary->execution_time_ms = 0.0;
    out_summary->objects_examined = 0;
    out_summary->relationships_examined = 0;
    out_summary->traversal_depth = 0;
    out_summary->result_count = 0;
    out_summary->traversal_summary[0] = '\0';
}

void populate_query_result_summary(const oep::engine::QueryStatistics& stats, const std::string& traversal_summary,
                                    oep_query_result_summary_t* out_summary) {
    out_summary->execution_time_ms = stats.execution_time_ms;
    out_summary->objects_examined = static_cast<int>(stats.objects_examined);
    out_summary->relationships_examined = static_cast<int>(stats.relationships_examined);
    out_summary->traversal_depth = stats.traversal_depth;
    out_summary->result_count = static_cast<int>(stats.result_count);
    oep::api::detail::copy_truncated(traversal_summary, out_summary->traversal_summary,
                                      sizeof(out_summary->traversal_summary));
}

} // namespace

extern "C" {

const char* oep_query_category_to_string(oep_query_category_t category) {
    switch (category) {
        case OEP_QUERY_CATEGORY_OBJECT: return "Object";
        case OEP_QUERY_CATEGORY_RELATIONSHIP: return "Relationship";
        case OEP_QUERY_CATEGORY_DOMAIN: return "Domain";
        case OEP_QUERY_CATEGORY_TYPE: return "Type";
        case OEP_QUERY_CATEGORY_DEPENDENCY: return "Dependency";
        case OEP_QUERY_CATEGORY_NEIGHBORHOOD: return "Neighborhood";
        case OEP_QUERY_CATEGORY_PATH: return "Path";
        case OEP_QUERY_CATEGORY_REFERENCE: return "Reference";
        case OEP_QUERY_CATEGORY_METADATA: return "Metadata";
        case OEP_QUERY_CATEGORY_COMPOSITE: return "Composite";
    }
    return "Object";
}

oep_result_t oep_eqe_plan_query(OEP_Runtime runtime, const oep_query_request_t* request, oep_query_plan_t* out_plan,
                                 oep_package_id_list_t* out_indexes_used, oep_package_id_list_t* out_execution_order) {
    if (out_plan != nullptr) zero_query_plan(out_plan);
    if (out_indexes_used != nullptr) zero_package_id_list(out_indexes_used);
    if (out_execution_order != nullptr) zero_package_id_list(out_execution_order);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (request == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "request is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const oep::engine::QueryRequest internal_request = build_query_request(*request);
        const oep::engine::QueryPlan plan = runtime->engineering_query_engine.plan_query(internal_request);
        if (out_plan != nullptr) populate_query_plan(plan, out_plan);
        if (out_indexes_used != nullptr) *out_indexes_used = build_package_id_list(plan.indexes_used());
        if (out_execution_order != nullptr) *out_execution_order = build_package_id_list(plan.execution_order());
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_plan != nullptr) zero_query_plan(out_plan);
        if (out_indexes_used != nullptr) zero_package_id_list(out_indexes_used);
        if (out_execution_order != nullptr) zero_package_id_list(out_execution_order);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_plan != nullptr) zero_query_plan(out_plan);
        if (out_indexes_used != nullptr) zero_package_id_list(out_indexes_used);
        if (out_execution_order != nullptr) zero_package_id_list(out_execution_order);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eqe_execute_query(OEP_Runtime runtime, const oep_query_request_t* request,
                                    oep_query_result_summary_t* out_summary, oep_package_id_list_t* out_object_ids,
                                    oep_package_id_list_t* out_relationship_ids) {
    if (out_summary != nullptr) zero_query_result_summary(out_summary);
    if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
    if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (request == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "request is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const oep::engine::QueryRequest internal_request = build_query_request(*request);
        const oep::engine::EngineeringQueryResult result = runtime->engineering_query_engine.execute_query(internal_request);
        if (out_summary != nullptr) {
            populate_query_result_summary(result.statistics(), result.traversal_summary(), out_summary);
        }
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids());
        if (out_relationship_ids != nullptr) *out_relationship_ids = build_package_id_list(result.relationship_ids());
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_query_result_summary(out_summary);
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_query_result_summary(out_summary);
        if (out_object_ids != nullptr) zero_package_id_list(out_object_ids);
        if (out_relationship_ids != nullptr) zero_package_id_list(out_relationship_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eqe_query_statistics(OEP_Runtime runtime, oep_query_result_summary_t* out_stats) {
    if (out_stats != nullptr) zero_query_result_summary(out_stats);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_stats == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_stats is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep_result_t built_check = require_graph_built(runtime);
        if (!built_check.success) {
            return built_check;
        }
        const oep::engine::QueryStatistics& stats = runtime->engineering_query_engine.query_statistics();
        populate_query_result_summary(stats, "", out_stats);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_query_result_summary(out_stats);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_query_result_summary(out_stats);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eqe_clear_query_cache(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        runtime->engineering_query_engine.clear_query_cache();
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eqe_query_cache_info(OEP_Runtime runtime, int* out_plan_count, int* out_result_count) {
    if (out_plan_count != nullptr) *out_plan_count = 0;
    if (out_result_count != nullptr) *out_result_count = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
            return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                      "no repository is currently open");
        }
        const oep::engine::QueryCache& cache = runtime->engineering_query_engine.query_cache();
        if (out_plan_count != nullptr) *out_plan_count = static_cast<int>(cache.plan_count());
        if (out_result_count != nullptr) *out_result_count = static_cast<int>(cache.result_count());
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_plan_count != nullptr) *out_plan_count = 0;
        if (out_result_count != nullptr) *out_result_count = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_plan_count != nullptr) *out_plan_count = 0;
        if (out_result_count != nullptr) *out_result_count = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

} // extern "C"

namespace {

oep_rule_category_t to_capi_rule_category(oep::engine::RuleCategory category) {
    switch (category) {
        case oep::engine::RuleCategory::Structural: return OEP_RULE_CATEGORY_STRUCTURAL;
        case oep::engine::RuleCategory::Connectivity: return OEP_RULE_CATEGORY_CONNECTIVITY;
        case oep::engine::RuleCategory::Dependency: return OEP_RULE_CATEGORY_DEPENDENCY;
        case oep::engine::RuleCategory::Reference: return OEP_RULE_CATEGORY_REFERENCE;
        case oep::engine::RuleCategory::Documentation: return OEP_RULE_CATEGORY_DOCUMENTATION;
        case oep::engine::RuleCategory::Metadata: return OEP_RULE_CATEGORY_METADATA;
        case oep::engine::RuleCategory::Package: return OEP_RULE_CATEGORY_PACKAGE;
    }
    return OEP_RULE_CATEGORY_STRUCTURAL;
}

oep::engine::RuleCategory from_capi_rule_category(oep_rule_category_t category) {
    switch (category) {
        case OEP_RULE_CATEGORY_STRUCTURAL: return oep::engine::RuleCategory::Structural;
        case OEP_RULE_CATEGORY_CONNECTIVITY: return oep::engine::RuleCategory::Connectivity;
        case OEP_RULE_CATEGORY_DEPENDENCY: return oep::engine::RuleCategory::Dependency;
        case OEP_RULE_CATEGORY_REFERENCE: return oep::engine::RuleCategory::Reference;
        case OEP_RULE_CATEGORY_DOCUMENTATION: return oep::engine::RuleCategory::Documentation;
        case OEP_RULE_CATEGORY_METADATA: return oep::engine::RuleCategory::Metadata;
        case OEP_RULE_CATEGORY_PACKAGE: return oep::engine::RuleCategory::Package;
    }
    return oep::engine::RuleCategory::Structural;
}

oep_rule_severity_t to_capi_rule_severity(oep::engine::RuleSeverity severity) {
    switch (severity) {
        case oep::engine::RuleSeverity::Info: return OEP_RULE_SEVERITY_INFO;
        case oep::engine::RuleSeverity::Warning: return OEP_RULE_SEVERITY_WARNING;
        case oep::engine::RuleSeverity::Error: return OEP_RULE_SEVERITY_ERROR;
        case oep::engine::RuleSeverity::Critical: return OEP_RULE_SEVERITY_CRITICAL;
    }
    return OEP_RULE_SEVERITY_INFO;
}

oep::engine::RuleSeverity from_capi_rule_severity(oep_rule_severity_t severity) {
    switch (severity) {
        case OEP_RULE_SEVERITY_INFO: return oep::engine::RuleSeverity::Info;
        case OEP_RULE_SEVERITY_WARNING: return oep::engine::RuleSeverity::Warning;
        case OEP_RULE_SEVERITY_ERROR: return oep::engine::RuleSeverity::Error;
        case OEP_RULE_SEVERITY_CRITICAL: return oep::engine::RuleSeverity::Critical;
    }
    return oep::engine::RuleSeverity::Info;
}

oep_rule_scope_kind_t to_capi_rule_scope_kind(oep::engine::RuleScopeKind kind) {
    switch (kind) {
        case oep::engine::RuleScopeKind::AllObjects: return OEP_RULE_SCOPE_ALL_OBJECTS;
        case oep::engine::RuleScopeKind::ByObjectType: return OEP_RULE_SCOPE_BY_OBJECT_TYPE;
        case oep::engine::RuleScopeKind::ByDomain: return OEP_RULE_SCOPE_BY_DOMAIN;
        case oep::engine::RuleScopeKind::ByPackage: return OEP_RULE_SCOPE_BY_PACKAGE;
        case oep::engine::RuleScopeKind::SingleObject: return OEP_RULE_SCOPE_SINGLE_OBJECT;
    }
    return OEP_RULE_SCOPE_ALL_OBJECTS;
}

oep::engine::RuleScopeKind from_capi_rule_scope_kind(oep_rule_scope_kind_t kind) {
    switch (kind) {
        case OEP_RULE_SCOPE_ALL_OBJECTS: return oep::engine::RuleScopeKind::AllObjects;
        case OEP_RULE_SCOPE_BY_OBJECT_TYPE: return oep::engine::RuleScopeKind::ByObjectType;
        case OEP_RULE_SCOPE_BY_DOMAIN: return oep::engine::RuleScopeKind::ByDomain;
        case OEP_RULE_SCOPE_BY_PACKAGE: return oep::engine::RuleScopeKind::ByPackage;
        case OEP_RULE_SCOPE_SINGLE_OBJECT: return oep::engine::RuleScopeKind::SingleObject;
    }
    return oep::engine::RuleScopeKind::AllObjects;
}

oep_rule_condition_kind_t to_capi_rule_condition_kind(oep::engine::RuleConditionKind kind) {
    switch (kind) {
        case oep::engine::RuleConditionKind::RequiresRelationship: return OEP_RULE_CONDITION_REQUIRES_RELATIONSHIP;
        case oep::engine::RuleConditionKind::ForbidsRelationship: return OEP_RULE_CONDITION_FORBIDS_RELATIONSHIP;
        case oep::engine::RuleConditionKind::MinRelationshipCount: return OEP_RULE_CONDITION_MIN_RELATIONSHIP_COUNT;
        case oep::engine::RuleConditionKind::MaxRelationshipCount: return OEP_RULE_CONDITION_MAX_RELATIONSHIP_COUNT;
        case oep::engine::RuleConditionKind::RequiresTag: return OEP_RULE_CONDITION_REQUIRES_TAG;
        case oep::engine::RuleConditionKind::ForbidsTag: return OEP_RULE_CONDITION_FORBIDS_TAG;
        case oep::engine::RuleConditionKind::HasDescription: return OEP_RULE_CONDITION_HAS_DESCRIPTION;
        case oep::engine::RuleConditionKind::HasAuthor: return OEP_RULE_CONDITION_HAS_AUTHOR;
        case oep::engine::RuleConditionKind::NoCycles: return OEP_RULE_CONDITION_NO_CYCLES;
        case oep::engine::RuleConditionKind::NoIsolatedObjects: return OEP_RULE_CONDITION_NO_ISOLATED_OBJECTS;
    }
    return OEP_RULE_CONDITION_HAS_DESCRIPTION;
}

oep::engine::RuleConditionKind from_capi_rule_condition_kind(oep_rule_condition_kind_t kind) {
    switch (kind) {
        case OEP_RULE_CONDITION_REQUIRES_RELATIONSHIP: return oep::engine::RuleConditionKind::RequiresRelationship;
        case OEP_RULE_CONDITION_FORBIDS_RELATIONSHIP: return oep::engine::RuleConditionKind::ForbidsRelationship;
        case OEP_RULE_CONDITION_MIN_RELATIONSHIP_COUNT: return oep::engine::RuleConditionKind::MinRelationshipCount;
        case OEP_RULE_CONDITION_MAX_RELATIONSHIP_COUNT: return oep::engine::RuleConditionKind::MaxRelationshipCount;
        case OEP_RULE_CONDITION_REQUIRES_TAG: return oep::engine::RuleConditionKind::RequiresTag;
        case OEP_RULE_CONDITION_FORBIDS_TAG: return oep::engine::RuleConditionKind::ForbidsTag;
        case OEP_RULE_CONDITION_HAS_DESCRIPTION: return oep::engine::RuleConditionKind::HasDescription;
        case OEP_RULE_CONDITION_HAS_AUTHOR: return oep::engine::RuleConditionKind::HasAuthor;
        case OEP_RULE_CONDITION_NO_CYCLES: return oep::engine::RuleConditionKind::NoCycles;
        case OEP_RULE_CONDITION_NO_ISOLATED_OBJECTS: return oep::engine::RuleConditionKind::NoIsolatedObjects;
    }
    return oep::engine::RuleConditionKind::HasDescription;
}

oep_rule_evaluation_status_t to_capi_rule_evaluation_status(oep::engine::RuleEvaluationStatus status) {
    switch (status) {
        case oep::engine::RuleEvaluationStatus::Passed: return OEP_RULE_EVAL_PASSED;
        case oep::engine::RuleEvaluationStatus::Failed: return OEP_RULE_EVAL_FAILED;
        case oep::engine::RuleEvaluationStatus::NotApplicable: return OEP_RULE_EVAL_NOT_APPLICABLE;
        case oep::engine::RuleEvaluationStatus::Error: return OEP_RULE_EVAL_ERROR;
    }
    return OEP_RULE_EVAL_ERROR;
}

oep::engine::RuleScope build_rule_scope(const oep_rule_scope_t& scope) {
    oep::engine::RuleScope internal_scope;
    internal_scope.kind = from_capi_rule_scope_kind(scope.kind);
    if (scope.has_object_type) {
        internal_scope.object_type = oep::api::detail::from_capi_object_type(scope.object_type);
    }
    if (scope.has_domain) {
        internal_scope.domain = std::string(scope.domain);
    }
    if (scope.has_package_id) {
        internal_scope.package_id = std::string(scope.package_id);
    }
    if (scope.has_object_id) {
        internal_scope.object_id = std::string(scope.object_id);
    }
    return internal_scope;
}

oep::engine::RuleCondition build_rule_condition(const oep_rule_condition_t& condition) {
    oep::engine::RuleCondition internal_condition;
    internal_condition.kind = from_capi_rule_condition_kind(condition.kind);
    if (condition.has_relationship_type) {
        internal_condition.relationship_type = oep::api::detail::from_capi_relationship_type(condition.relationship_type);
    }
    if (condition.has_direction) {
        internal_condition.direction = condition.direction != 0;
    }
    if (condition.has_tag) {
        internal_condition.tag = std::string(condition.tag);
    }
    if (condition.has_count) {
        internal_condition.count = condition.count;
    }
    return internal_condition;
}

oep::engine::EngineeringRule build_engineering_rule(const oep_engineering_rule_t& rule) {
    std::vector<oep::engine::RuleCondition> conditions;
    for (int i = 0; i < rule.condition_count; ++i) {
        if (rule.conditions != nullptr) {
            conditions.push_back(build_rule_condition(rule.conditions[i]));
        }
    }
    return oep::engine::EngineeringRule(std::string(rule.rule_id), std::string(rule.name), std::string(rule.description),
                                         from_capi_rule_category(rule.category), from_capi_rule_severity(rule.severity),
                                         build_rule_scope(rule.scope), std::move(conditions), std::string(rule.message),
                                         std::string(rule.recommendation));
}

void zero_rule_scope(oep_rule_scope_t* out_scope) {
    out_scope->kind = OEP_RULE_SCOPE_ALL_OBJECTS;
    out_scope->has_object_type = 0;
    out_scope->object_type = OEP_OBJECT_TYPE_DOCUMENT;
    out_scope->has_domain = 0;
    out_scope->domain[0] = '\0';
    out_scope->has_package_id = 0;
    out_scope->package_id[0] = '\0';
    out_scope->has_object_id = 0;
    out_scope->object_id[0] = '\0';
}

void zero_engineering_rule(oep_engineering_rule_t* out_rule) {
    out_rule->rule_id[0] = '\0';
    out_rule->name[0] = '\0';
    out_rule->description[0] = '\0';
    out_rule->category = OEP_RULE_CATEGORY_STRUCTURAL;
    out_rule->severity = OEP_RULE_SEVERITY_INFO;
    zero_rule_scope(&out_rule->scope);
    out_rule->conditions = nullptr;
    out_rule->condition_count = 0;
    out_rule->message[0] = '\0';
    out_rule->recommendation[0] = '\0';
}

void populate_rule_scope(const oep::engine::RuleScope& scope, oep_rule_scope_t* out_scope) {
    zero_rule_scope(out_scope);
    out_scope->kind = to_capi_rule_scope_kind(scope.kind);
    if (scope.object_type.has_value()) {
        out_scope->has_object_type = 1;
        out_scope->object_type = oep::api::detail::to_capi_object_type(*scope.object_type);
    }
    if (scope.domain.has_value()) {
        out_scope->has_domain = 1;
        oep::api::detail::copy_truncated(*scope.domain, out_scope->domain, sizeof(out_scope->domain));
    }
    if (scope.package_id.has_value()) {
        out_scope->has_package_id = 1;
        oep::api::detail::copy_truncated(*scope.package_id, out_scope->package_id, sizeof(out_scope->package_id));
    }
    if (scope.object_id.has_value()) {
        out_scope->has_object_id = 1;
        oep::api::detail::copy_truncated(*scope.object_id, out_scope->object_id, sizeof(out_scope->object_id));
    }
}

void populate_engineering_rule(const oep::engine::EngineeringRule& rule, oep_engineering_rule_t* out_rule) {
    zero_engineering_rule(out_rule);
    oep::api::detail::copy_truncated(rule.rule_id(), out_rule->rule_id, sizeof(out_rule->rule_id));
    oep::api::detail::copy_truncated(rule.name(), out_rule->name, sizeof(out_rule->name));
    oep::api::detail::copy_truncated(rule.description(), out_rule->description, sizeof(out_rule->description));
    out_rule->category = to_capi_rule_category(rule.category());
    out_rule->severity = to_capi_rule_severity(rule.severity());
    populate_rule_scope(rule.scope(), &out_rule->scope);
    /* conditions/condition_count deliberately left NULL/0 on output -- see
       oep_engineering_rule_t's doc comment. */
    oep::api::detail::copy_truncated(rule.message(), out_rule->message, sizeof(out_rule->message));
    oep::api::detail::copy_truncated(rule.recommendation(), out_rule->recommendation, sizeof(out_rule->recommendation));
}

void zero_rule_condition_list(oep_rule_condition_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

oep_rule_condition_list_t build_rule_condition_list(const std::vector<oep::engine::RuleCondition>& conditions) {
    const int count = static_cast<int>(conditions.size());
    oep_rule_condition_t* items = count > 0 ? new oep_rule_condition_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        const oep::engine::RuleCondition& condition = conditions[static_cast<std::size_t>(i)];
        oep_rule_condition_t& out_condition = items[i];
        out_condition.kind = to_capi_rule_condition_kind(condition.kind);
        out_condition.has_relationship_type = condition.relationship_type.has_value() ? 1 : 0;
        out_condition.relationship_type = condition.relationship_type.has_value()
                                               ? oep::api::detail::to_capi_relationship_type(*condition.relationship_type)
                                               : OEP_RELATIONSHIP_TYPE_REFERENCES;
        out_condition.has_direction = condition.direction.has_value() ? 1 : 0;
        out_condition.direction = condition.direction.has_value() ? (*condition.direction ? 1 : 0) : 0;
        out_condition.has_tag = condition.tag.has_value() ? 1 : 0;
        out_condition.tag[0] = '\0';
        if (condition.tag.has_value()) {
            oep::api::detail::copy_truncated(*condition.tag, out_condition.tag, sizeof(out_condition.tag));
        }
        out_condition.has_count = condition.count.has_value() ? 1 : 0;
        out_condition.count = condition.count.has_value() ? *condition.count : 0;
    }
    oep_rule_condition_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

void zero_rule_evaluation_result(oep_rule_evaluation_result_t* out_result) {
    out_result->status = OEP_RULE_EVAL_ERROR;
    out_result->message[0] = '\0';
}

void populate_rule_evaluation_result(const oep::engine::RuleEvaluationResult& result,
                                      oep_rule_evaluation_result_t* out_result) {
    out_result->status = to_capi_rule_evaluation_status(result.status());
    oep::api::detail::copy_truncated(result.message(), out_result->message, sizeof(out_result->message));
}

void zero_rule_diagnostic_list(oep_rule_diagnostic_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

oep_rule_diagnostic_list_t build_rule_diagnostic_list(const std::vector<oep::engine::RuleDiagnostic>& diagnostics) {
    const int count = static_cast<int>(diagnostics.size());
    oep_rule_diagnostic_t* items = count > 0 ? new oep_rule_diagnostic_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        const oep::engine::RuleDiagnostic& diagnostic = diagnostics[static_cast<std::size_t>(i)];
        oep::api::detail::copy_truncated(diagnostic.object_id, items[i].object_id, sizeof(items[i].object_id));
        oep::api::detail::copy_truncated(diagnostic.detail, items[i].detail, sizeof(items[i].detail));
    }
    oep_rule_diagnostic_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

void zero_rule_evaluation_summary_list(oep_rule_evaluation_summary_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

oep_result_t require_repository_open_for_rules(OEP_Runtime runtime) {
    if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "no repository is currently open");
    }
    return make_success_result();
}

oep_result_t require_rules_graph_ready(OEP_Runtime runtime) {
    if (!runtime->rules_engine.graph_ready()) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "Knowledge Graph is not ready -- call oep_engine_load_graph and "
                                  "oep_kge_build_graph first");
    }
    return make_success_result();
}

} // namespace

extern "C" {

const char* oep_rule_category_to_string(oep_rule_category_t category) {
    switch (category) {
        case OEP_RULE_CATEGORY_STRUCTURAL: return "Structural";
        case OEP_RULE_CATEGORY_CONNECTIVITY: return "Connectivity";
        case OEP_RULE_CATEGORY_DEPENDENCY: return "Dependency";
        case OEP_RULE_CATEGORY_REFERENCE: return "Reference";
        case OEP_RULE_CATEGORY_DOCUMENTATION: return "Documentation";
        case OEP_RULE_CATEGORY_METADATA: return "Metadata";
        case OEP_RULE_CATEGORY_PACKAGE: return "Package";
    }
    return "Structural";
}

const char* oep_rule_severity_to_string(oep_rule_severity_t severity) {
    switch (severity) {
        case OEP_RULE_SEVERITY_INFO: return "Info";
        case OEP_RULE_SEVERITY_WARNING: return "Warning";
        case OEP_RULE_SEVERITY_ERROR: return "Error";
        case OEP_RULE_SEVERITY_CRITICAL: return "Critical";
    }
    return "Info";
}

const char* oep_rule_scope_kind_to_string(oep_rule_scope_kind_t kind) {
    switch (kind) {
        case OEP_RULE_SCOPE_ALL_OBJECTS: return "AllObjects";
        case OEP_RULE_SCOPE_BY_OBJECT_TYPE: return "ByObjectType";
        case OEP_RULE_SCOPE_BY_DOMAIN: return "ByDomain";
        case OEP_RULE_SCOPE_BY_PACKAGE: return "ByPackage";
        case OEP_RULE_SCOPE_SINGLE_OBJECT: return "SingleObject";
    }
    return "AllObjects";
}

const char* oep_rule_condition_kind_to_string(oep_rule_condition_kind_t kind) {
    switch (kind) {
        case OEP_RULE_CONDITION_REQUIRES_RELATIONSHIP: return "RequiresRelationship";
        case OEP_RULE_CONDITION_FORBIDS_RELATIONSHIP: return "ForbidsRelationship";
        case OEP_RULE_CONDITION_MIN_RELATIONSHIP_COUNT: return "MinRelationshipCount";
        case OEP_RULE_CONDITION_MAX_RELATIONSHIP_COUNT: return "MaxRelationshipCount";
        case OEP_RULE_CONDITION_REQUIRES_TAG: return "RequiresTag";
        case OEP_RULE_CONDITION_FORBIDS_TAG: return "ForbidsTag";
        case OEP_RULE_CONDITION_HAS_DESCRIPTION: return "HasDescription";
        case OEP_RULE_CONDITION_HAS_AUTHOR: return "HasAuthor";
        case OEP_RULE_CONDITION_NO_CYCLES: return "NoCycles";
        case OEP_RULE_CONDITION_NO_ISOLATED_OBJECTS: return "NoIsolatedObjects";
    }
    return "HasDescription";
}

const char* oep_rule_evaluation_status_to_string(oep_rule_evaluation_status_t status) {
    switch (status) {
        case OEP_RULE_EVAL_PASSED: return "Passed";
        case OEP_RULE_EVAL_FAILED: return "Failed";
        case OEP_RULE_EVAL_NOT_APPLICABLE: return "NotApplicable";
        case OEP_RULE_EVAL_ERROR: return "Error";
    }
    return "Error";
}

void oep_rule_condition_list_release(oep_rule_condition_list_t* list) {
    if (list == nullptr) return;
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

void oep_rule_diagnostic_list_release(oep_rule_diagnostic_list_t* list) {
    if (list == nullptr) return;
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

void oep_rule_evaluation_summary_list_release(oep_rule_evaluation_summary_list_t* list) {
    if (list == nullptr) return;
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_rules_register(OEP_Runtime runtime, const oep_engineering_rule_t* rule) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (rule == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "rule is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        const bool registered = runtime->rules_engine.register_rule(build_engineering_rule(*rule));
        if (!registered) {
            return make_error_result(OEP_ERROR_OPERATION_FAILED, category_for_code(OEP_ERROR_OPERATION_FAILED),
                                      "rule_id is already registered");
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_rules_remove(OEP_Runtime runtime, const char* rule_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (rule_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "rule_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        if (!runtime->rules_engine.remove_rule(rule_id)) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "rule_id is not registered");
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_rules_enable(OEP_Runtime runtime, const char* rule_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (rule_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "rule_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        if (!runtime->rules_engine.enable_rule(rule_id)) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "rule_id is not registered");
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_rules_disable(OEP_Runtime runtime, const char* rule_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (rule_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "rule_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        if (!runtime->rules_engine.disable_rule(rule_id)) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "rule_id is not registered");
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

namespace {

oep_result_t rules_list_impl(OEP_Runtime runtime, oep_package_id_list_t* out_rule_ids,
                              std::vector<oep::engine::EngineeringRule> (oep::engine::RulesEngine::*getter)() const) {
    if (out_rule_ids != nullptr) zero_package_id_list(out_rule_ids);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_rule_ids == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_rule_ids is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        const std::vector<oep::engine::EngineeringRule> rules = (runtime->rules_engine.*getter)();
        std::vector<std::string> ids;
        ids.reserve(rules.size());
        for (const oep::engine::EngineeringRule& rule : rules) ids.push_back(rule.rule_id());
        *out_rule_ids = build_package_id_list(ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_package_id_list(out_rule_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_package_id_list(out_rule_ids);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

} // namespace

oep_result_t oep_rules_list_all(OEP_Runtime runtime, oep_package_id_list_t* out_rule_ids) {
    return rules_list_impl(runtime, out_rule_ids, &oep::engine::RulesEngine::all_rules);
}

oep_result_t oep_rules_list_enabled(OEP_Runtime runtime, oep_package_id_list_t* out_rule_ids) {
    return rules_list_impl(runtime, out_rule_ids, &oep::engine::RulesEngine::enabled_rules);
}

oep_result_t oep_rules_list_disabled(OEP_Runtime runtime, oep_package_id_list_t* out_rule_ids) {
    return rules_list_impl(runtime, out_rule_ids, &oep::engine::RulesEngine::disabled_rules);
}

oep_result_t oep_rules_get(OEP_Runtime runtime, const char* rule_id, oep_engineering_rule_t* out_rule,
                            oep_rule_condition_list_t* out_conditions, int* out_found) {
    if (out_rule != nullptr) zero_engineering_rule(out_rule);
    if (out_conditions != nullptr) zero_rule_condition_list(out_conditions);
    if (out_found != nullptr) *out_found = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (rule_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "rule_id is null");
    }
    if (out_rule == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_rule is null");
    }
    if (out_found == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_found is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        std::optional<oep::engine::EngineeringRule> found;
        for (const oep::engine::EngineeringRule& rule : runtime->rules_engine.all_rules()) {
            if (rule.rule_id() == rule_id) {
                found = rule;
                break;
            }
        }
        if (!found.has_value()) {
            *out_found = 0;
            return make_success_result();
        }
        *out_found = 1;
        populate_engineering_rule(*found, out_rule);
        if (out_conditions != nullptr) *out_conditions = build_rule_condition_list(found->conditions());
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_rule != nullptr) zero_engineering_rule(out_rule);
        if (out_conditions != nullptr) zero_rule_condition_list(out_conditions);
        if (out_found != nullptr) *out_found = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_rule != nullptr) zero_engineering_rule(out_rule);
        if (out_conditions != nullptr) zero_rule_condition_list(out_conditions);
        if (out_found != nullptr) *out_found = 0;
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_rules_evaluate(OEP_Runtime runtime, const char* rule_id, oep_rule_evaluation_result_t* out_result,
                                 oep_package_id_list_t* out_affected_objects,
                                 oep_rule_diagnostic_list_t* out_diagnostics) {
    if (out_result != nullptr) zero_rule_evaluation_result(out_result);
    if (out_affected_objects != nullptr) zero_package_id_list(out_affected_objects);
    if (out_diagnostics != nullptr) zero_rule_diagnostic_list(out_diagnostics);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (rule_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "rule_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_rules_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const std::optional<oep::engine::RuleEvaluationResult> result = runtime->rules_engine.evaluate_rule(rule_id);
        if (!result.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "rule_id is not registered");
        }
        if (out_result != nullptr) populate_rule_evaluation_result(*result, out_result);
        if (out_affected_objects != nullptr) *out_affected_objects = build_package_id_list(result->affected_objects());
        if (out_diagnostics != nullptr) *out_diagnostics = build_rule_diagnostic_list(result->diagnostics());
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_rule_evaluation_result(out_result);
        if (out_affected_objects != nullptr) zero_package_id_list(out_affected_objects);
        if (out_diagnostics != nullptr) zero_rule_diagnostic_list(out_diagnostics);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_rule_evaluation_result(out_result);
        if (out_affected_objects != nullptr) zero_package_id_list(out_affected_objects);
        if (out_diagnostics != nullptr) zero_rule_diagnostic_list(out_diagnostics);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_rules_evaluate_all(OEP_Runtime runtime, oep_rule_evaluation_summary_list_t* out_summaries) {
    if (out_summaries != nullptr) zero_rule_evaluation_summary_list(out_summaries);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_summaries == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_summaries is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_rules(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_rules_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const std::vector<oep::engine::RuleEvaluationResult> results = runtime->rules_engine.evaluate_all();
        const int count = static_cast<int>(results.size());
        oep_rule_evaluation_summary_t* items =
            count > 0 ? new oep_rule_evaluation_summary_t[static_cast<std::size_t>(count)] : nullptr;
        for (int i = 0; i < count; ++i) {
            const oep::engine::RuleEvaluationResult& result = results[static_cast<std::size_t>(i)];
            oep_rule_evaluation_summary_t& summary = items[i];
            oep::api::detail::copy_truncated(result.rule().rule_id(), summary.rule_id, sizeof(summary.rule_id));
            summary.status = to_capi_rule_evaluation_status(result.status());
            oep::api::detail::copy_truncated(result.message(), summary.message, sizeof(summary.message));
            summary.affected_object_count = static_cast<int>(result.affected_objects().size());
            summary.diagnostic_count = static_cast<int>(result.diagnostics().size());
        }
        out_summaries->items = items;
        out_summaries->count = count;
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_rule_evaluation_summary_list(out_summaries);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_rule_evaluation_summary_list(out_summaries);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

} // extern "C"

namespace {

oep_validation_profile_t to_capi_validation_profile(oep::engine::ValidationProfile profile) {
    switch (profile) {
        case oep::engine::ValidationProfile::Structural: return OEP_VALIDATION_PROFILE_STRUCTURAL;
        case oep::engine::ValidationProfile::Connectivity: return OEP_VALIDATION_PROFILE_CONNECTIVITY;
        case oep::engine::ValidationProfile::Documentation: return OEP_VALIDATION_PROFILE_DOCUMENTATION;
        case oep::engine::ValidationProfile::Metadata: return OEP_VALIDATION_PROFILE_METADATA;
        case oep::engine::ValidationProfile::Complete: return OEP_VALIDATION_PROFILE_COMPLETE;
    }
    return OEP_VALIDATION_PROFILE_STRUCTURAL;
}

oep::engine::ValidationProfile from_capi_validation_profile(oep_validation_profile_t profile) {
    switch (profile) {
        case OEP_VALIDATION_PROFILE_STRUCTURAL: return oep::engine::ValidationProfile::Structural;
        case OEP_VALIDATION_PROFILE_CONNECTIVITY: return oep::engine::ValidationProfile::Connectivity;
        case OEP_VALIDATION_PROFILE_DOCUMENTATION: return oep::engine::ValidationProfile::Documentation;
        case OEP_VALIDATION_PROFILE_METADATA: return oep::engine::ValidationProfile::Metadata;
        case OEP_VALIDATION_PROFILE_COMPLETE: return oep::engine::ValidationProfile::Complete;
    }
    return oep::engine::ValidationProfile::Structural;
}

oep_validation_target_kind_t to_capi_validation_target_kind(oep::engine::ValidationTargetKind kind) {
    switch (kind) {
        case oep::engine::ValidationTargetKind::SingleObject: return OEP_VALIDATION_TARGET_SINGLE_OBJECT;
        case oep::engine::ValidationTargetKind::MultipleObjects: return OEP_VALIDATION_TARGET_MULTIPLE_OBJECTS;
        case oep::engine::ValidationTargetKind::EngineeringContext: return OEP_VALIDATION_TARGET_ENGINEERING_CONTEXT;
        case oep::engine::ValidationTargetKind::Package: return OEP_VALIDATION_TARGET_PACKAGE;
        case oep::engine::ValidationTargetKind::QueryResult: return OEP_VALIDATION_TARGET_QUERY_RESULT;
    }
    return OEP_VALIDATION_TARGET_ENGINEERING_CONTEXT;
}

void zero_validation_report_summary(oep_validation_report_summary_t* out_summary) {
    out_summary->target_kind = OEP_VALIDATION_TARGET_ENGINEERING_CONTEXT;
    out_summary->pass_count = 0;
    out_summary->warning_count = 0;
    out_summary->error_count = 0;
    out_summary->critical_count = 0;
    out_summary->execution_time_ms = 0.0;
    out_summary->rules_evaluated = 0;
}

void zero_validation_finding_list(oep_validation_finding_list_t* out_list) {
    out_list->items = nullptr;
    out_list->count = 0;
}

void zero_validation_statistics(oep_validation_statistics_t* out_stats) {
    out_stats->rules_evaluated = 0;
    out_stats->rules_passed = 0;
    out_stats->rules_failed = 0;
    out_stats->rules_not_applicable = 0;
    out_stats->rules_errored = 0;
    out_stats->execution_time_ms = 0.0;
}

void populate_validation_report_summary(const oep::engine::ValidationReport& report,
                                         oep_validation_report_summary_t* out_summary) {
    out_summary->target_kind = to_capi_validation_target_kind(report.session().target().kind());
    out_summary->pass_count = report.pass_count();
    out_summary->warning_count = report.warning_count();
    out_summary->error_count = report.error_count();
    out_summary->critical_count = report.critical_count();
    out_summary->execution_time_ms = report.execution_time_ms();
    out_summary->rules_evaluated = static_cast<int>(report.statistics().rules_evaluated);
}

oep_validation_finding_list_t build_validation_finding_list(const std::vector<oep::engine::ValidationFinding>& findings) {
    const int count = static_cast<int>(findings.size());
    oep_validation_finding_t* items = count > 0 ? new oep_validation_finding_t[static_cast<std::size_t>(count)] : nullptr;
    for (int i = 0; i < count; ++i) {
        const oep::engine::ValidationFinding& finding = findings[static_cast<std::size_t>(i)];
        oep_validation_finding_t& out_finding = items[i];
        oep::api::detail::copy_truncated(finding.finding_id(), out_finding.finding_id, sizeof(out_finding.finding_id));
        oep::api::detail::copy_truncated(finding.rule_id(), out_finding.rule_id, sizeof(out_finding.rule_id));
        out_finding.severity = to_capi_rule_severity(finding.severity());
        out_finding.category = to_capi_rule_category(finding.category());
        oep::api::detail::copy_truncated(finding.message(), out_finding.message, sizeof(out_finding.message));
        oep::api::detail::copy_truncated(finding.recommendation(), out_finding.recommendation,
                                          sizeof(out_finding.recommendation));
    }
    oep_validation_finding_list_t list;
    list.items = items;
    list.count = count;
    return list;
}

void populate_validation_statistics(const oep::engine::ValidationStatistics& statistics,
                                     oep_validation_statistics_t* out_stats) {
    out_stats->rules_evaluated = static_cast<int>(statistics.rules_evaluated);
    out_stats->rules_passed = static_cast<int>(statistics.rules_passed);
    out_stats->rules_failed = static_cast<int>(statistics.rules_failed);
    out_stats->rules_not_applicable = static_cast<int>(statistics.rules_not_applicable);
    out_stats->rules_errored = static_cast<int>(statistics.rules_errored);
    out_stats->execution_time_ms = statistics.execution_time_ms;
}

oep_result_t require_repository_open_for_validation(OEP_Runtime runtime) {
    if (runtime->runtime.state() != oep::runtime::RuntimeState::RepositoryOpen) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "no repository is currently open");
    }
    return make_success_result();
}

oep_result_t require_validation_graph_ready(OEP_Runtime runtime) {
    if (!runtime->validation_engine.graph_ready()) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "Knowledge Graph is not ready -- call oep_engine_load_graph and "
                                  "oep_kge_build_graph first");
    }
    return make_success_result();
}

// Shared tail for every oep_validation_validate_*/oep_validation_report
// call: writes `report` (if present) into `out_summary`/`out_findings`,
// or fails with OEP_ERROR_NOT_FOUND (session_id never created on this
// handle) / OEP_ERROR_INVALID_STATE (session exists but has no report
// yet) if `report` is nullopt while `session_known` distinguishes the
// two cases.
oep_result_t finish_validation_report(const std::optional<oep::engine::ValidationReport>& report, bool session_known,
                                       oep_validation_report_summary_t* out_summary,
                                       oep_validation_finding_list_t* out_findings) {
    if (!report.has_value()) {
        if (!session_known) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle");
        }
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "session_id has not been validated yet");
    }
    if (out_summary != nullptr) populate_validation_report_summary(*report, out_summary);
    if (out_findings != nullptr) *out_findings = build_validation_finding_list(report->findings());
    return make_success_result();
}

} // namespace

extern "C" {

const char* oep_validation_profile_to_string(oep_validation_profile_t profile) {
    switch (profile) {
        case OEP_VALIDATION_PROFILE_STRUCTURAL: return "Structural";
        case OEP_VALIDATION_PROFILE_CONNECTIVITY: return "Connectivity";
        case OEP_VALIDATION_PROFILE_DOCUMENTATION: return "Documentation";
        case OEP_VALIDATION_PROFILE_METADATA: return "Metadata";
        case OEP_VALIDATION_PROFILE_COMPLETE: return "Complete";
    }
    return "Structural";
}

void oep_validation_finding_list_release(oep_validation_finding_list_t* list) {
    if (list == nullptr) return;
    delete[] list->items;
    list->items = nullptr;
    list->count = 0;
}

oep_result_t oep_validation_create_session(OEP_Runtime runtime, oep_validation_profile_t profile,
                                            char* out_session_id, size_t session_id_buffer_size) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_session_id is null");
    }
    if (session_id_buffer_size == 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id_buffer_size is zero");
    }
    out_session_id[0] = '\0';
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::string session_id =
            runtime->validation_engine.create_validation_session(from_capi_validation_profile(profile));
        oep::api::detail::copy_truncated(session_id, out_session_id, session_id_buffer_size);
        return make_success_result();
    } catch (const std::exception& ex) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_validation_validate_object(OEP_Runtime runtime, const char* session_id, const char* object_id,
                                             oep_validation_report_summary_t* out_summary,
                                             oep_validation_finding_list_t* out_findings) {
    if (out_summary != nullptr) zero_validation_report_summary(out_summary);
    if (out_findings != nullptr) zero_validation_finding_list(out_findings);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_validation_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const std::optional<oep::engine::ValidationReport> report =
            runtime->validation_engine.validate_object(session_id, object_id);
        return finish_validation_report(report, /*session_known=*/report.has_value(), out_summary, out_findings);
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_validation_validate_objects(OEP_Runtime runtime, const char* session_id,
                                              const char* const* object_ids, int object_id_count,
                                              oep_validation_report_summary_t* out_summary,
                                              oep_validation_finding_list_t* out_findings) {
    if (out_summary != nullptr) zero_validation_report_summary(out_summary);
    if (out_findings != nullptr) zero_validation_finding_list(out_findings);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (object_id_count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id_count is negative");
    }
    if (object_id_count > 0 && object_ids == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_ids is null but object_id_count is nonzero");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_validation_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        std::vector<std::string> ids;
        ids.reserve(static_cast<std::size_t>(object_id_count));
        for (int i = 0; i < object_id_count; ++i) {
            ids.emplace_back(object_ids[i] != nullptr ? object_ids[i] : "");
        }
        const std::optional<oep::engine::ValidationReport> report =
            runtime->validation_engine.validate_objects(session_id, ids);
        return finish_validation_report(report, /*session_known=*/report.has_value(), out_summary, out_findings);
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_validation_validate_context(OEP_Runtime runtime, const char* session_id,
                                              oep_validation_report_summary_t* out_summary,
                                              oep_validation_finding_list_t* out_findings) {
    if (out_summary != nullptr) zero_validation_report_summary(out_summary);
    if (out_findings != nullptr) zero_validation_finding_list(out_findings);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_validation_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const std::optional<oep::engine::ValidationReport> report = runtime->validation_engine.validate_context(session_id);
        return finish_validation_report(report, /*session_known=*/report.has_value(), out_summary, out_findings);
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_validation_validate_package(OEP_Runtime runtime, const char* session_id, const char* package_id,
                                              oep_validation_report_summary_t* out_summary,
                                              oep_validation_finding_list_t* out_findings) {
    if (out_summary != nullptr) zero_validation_report_summary(out_summary);
    if (out_findings != nullptr) zero_validation_finding_list(out_findings);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (package_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "package_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_validation_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const std::optional<oep::engine::ValidationReport> report =
            runtime->validation_engine.validate_package(session_id, package_id);
        return finish_validation_report(report, /*session_known=*/report.has_value(), out_summary, out_findings);
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_validation_report(OEP_Runtime runtime, const char* session_id,
                                    oep_validation_report_summary_t* out_summary,
                                    oep_validation_finding_list_t* out_findings) {
    if (out_summary != nullptr) zero_validation_report_summary(out_summary);
    if (out_findings != nullptr) zero_validation_finding_list(out_findings);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::ValidationReport> report = runtime->validation_engine.validation_report(session_id);
        // validation_report() returns nullopt for both "unknown session" and
        // "session exists but never validated"; distinguish via
        // validation_statistics() (which the engine also keys by session_id
        // and which is populated -- with zeros -- for a known-but-
        // unvalidated session) so the two cases map to different error codes,
        // matching this section's documented not-found/not-yet-validated
        // contract.
        const bool session_known = report.has_value() || runtime->validation_engine.validation_statistics(session_id).has_value();
        return finish_validation_report(report, session_known, out_summary, out_findings);
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_validation_report_summary(out_summary);
        if (out_findings != nullptr) zero_validation_finding_list(out_findings);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

} // extern "C"

// ------------------------------------------------------------------ //
// Engineering Analysis & Reasoning Engine (WP-EKE-006)                 //
// ------------------------------------------------------------------ //

namespace {

oep_result_t require_reasoning_graph_ready(OEP_Runtime runtime) {
    if (!runtime->reasoning_engine.graph_ready()) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "Knowledge Graph is not ready -- call oep_engine_load_graph and "
                                  "oep_kge_build_graph first");
    }
    return make_success_result();
}

void write_evidence(const std::string& evidence, char* out_evidence) {
    if (out_evidence != nullptr) oep::api::detail::copy_truncated(evidence, out_evidence, OEP_MAX_EVIDENCE_TEXT);
}

oep_recommendation_kind_t to_capi_recommendation_kind(oep::engine::RecommendationKind kind) {
    switch (kind) {
        case oep::engine::RecommendationKind::RelatedProcedure: return OEP_RECOMMENDATION_RELATED_PROCEDURE;
        case oep::engine::RecommendationKind::SimilarComponent: return OEP_RECOMMENDATION_SIMILAR_COMPONENT;
        case oep::engine::RecommendationKind::AdditionalInspection: return OEP_RECOMMENDATION_ADDITIONAL_INSPECTION;
        case oep::engine::RecommendationKind::ConnectedSystem: return OEP_RECOMMENDATION_CONNECTED_SYSTEM;
        case oep::engine::RecommendationKind::FollowUpValidation: return OEP_RECOMMENDATION_FOLLOW_UP_VALIDATION;
    }
    return OEP_RECOMMENDATION_RELATED_PROCEDURE;
}

void zero_reasoning_summary(oep_reasoning_summary_t* out_summary) {
    out_summary->conclusion_count = 0;
    out_summary->recommendation_count = 0;
    out_summary->execution_time_ms = 0.0;
}

void populate_reasoning_summary(const oep::engine::ReasoningReport& report, oep_reasoning_summary_t* out_summary) {
    out_summary->conclusion_count = static_cast<int>(report.session().conclusions().size());
    out_summary->recommendation_count = static_cast<int>(report.recommendations().size());
    out_summary->execution_time_ms = report.execution_time_ms();
}

oep_package_id_list_t build_conclusion_id_list(const oep::engine::ReasoningReport& report) {
    std::vector<std::string> ids;
    ids.reserve(report.session().conclusions().size());
    for (const oep::engine::EngineeringConclusion& conclusion : report.session().conclusions()) {
        ids.push_back(conclusion.conclusion_id());
    }
    return build_package_id_list(ids);
}

oep_package_id_list_t build_recommendation_id_list(const oep::engine::ReasoningReport& report) {
    std::vector<std::string> ids;
    ids.reserve(report.recommendations().size());
    for (const oep::engine::EngineeringRecommendation& recommendation : report.recommendations()) {
        ids.push_back(recommendation.recommendation_id());
    }
    return build_package_id_list(ids);
}

// Shared tail for oep_reasoning_execute/oep_reasoning_report: writes
// `report` (if present) into the summary/id-list outputs, or fails with
// OEP_ERROR_NOT_FOUND. ReasoningEngine::reasoning_report returns nullopt
// both for an unknown session_id AND for a known session that has never
// been executed (it exposes no separate check to distinguish the two,
// unlike ValidationEngine's validation_statistics precedent), so both
// cases map to OEP_ERROR_NOT_FOUND here -- a deliberate, documented
// deviation from WP-EKE-005's not-found/not-yet-validated split.
oep_result_t finish_reasoning_report(const std::optional<oep::engine::ReasoningReport>& report,
                                      oep_reasoning_summary_t* out_summary, oep_package_id_list_t* out_conclusion_ids,
                                      oep_package_id_list_t* out_recommendation_ids) {
    if (!report.has_value()) {
        return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                  "session_id is not a session created on this handle, or has not been executed yet");
    }
    if (out_summary != nullptr) populate_reasoning_summary(*report, out_summary);
    if (out_conclusion_ids != nullptr) *out_conclusion_ids = build_conclusion_id_list(*report);
    if (out_recommendation_ids != nullptr) *out_recommendation_ids = build_recommendation_id_list(*report);
    return make_success_result();
}

const oep::engine::EngineeringConclusion* find_conclusion(const oep::engine::ReasoningReport& report,
                                                            const std::string& conclusion_id) {
    for (const oep::engine::EngineeringConclusion& conclusion : report.session().conclusions()) {
        if (conclusion.conclusion_id() == conclusion_id) return &conclusion;
    }
    return nullptr;
}

const oep::engine::EngineeringRecommendation* find_recommendation(const oep::engine::ReasoningReport& report,
                                                                    const std::string& recommendation_id) {
    for (const oep::engine::EngineeringRecommendation& recommendation : report.recommendations()) {
        if (recommendation.recommendation_id() == recommendation_id) return &recommendation;
    }
    return nullptr;
}

const oep::engine::EvidenceNode* find_evidence_node(const oep::engine::ReasoningReport& report,
                                                      const std::string& evidence_id) {
    for (const oep::engine::EvidenceNode& node : report.session().evidence().nodes()) {
        if (node.evidence_id() == evidence_id) return &node;
    }
    return nullptr;
}

} // namespace

extern "C" {

oep_result_t oep_analysis_dependencies(OEP_Runtime runtime, const char* object_id, int* out_max_depth,
                                        oep_package_id_list_t* out_dependency_object_ids,
                                        oep_package_id_list_t* out_dependency_relationship_ids,
                                        char* out_evidence) {
    if (out_max_depth != nullptr) *out_max_depth = 0;
    if (out_dependency_object_ids != nullptr) *out_dependency_object_ids = oep_package_id_list_t{nullptr, 0};
    if (out_dependency_relationship_ids != nullptr) *out_dependency_relationship_ids = oep_package_id_list_t{nullptr, 0};
    if (out_evidence != nullptr) out_evidence[0] = '\0';
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_reasoning_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::DependencyReport report = runtime->reasoning_engine.analyze_dependencies(object_id);
        if (out_max_depth != nullptr) *out_max_depth = report.max_depth();
        if (out_dependency_object_ids != nullptr) *out_dependency_object_ids = build_package_id_list(report.dependency_object_ids());
        if (out_dependency_relationship_ids != nullptr)
            *out_dependency_relationship_ids = build_package_id_list(report.dependency_relationship_ids());
        write_evidence(report.evidence(), out_evidence);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_analysis_impact(OEP_Runtime runtime, const char* object_id, int* out_max_depth,
                                  oep_package_id_list_t* out_affected_object_ids,
                                  oep_package_id_list_t* out_affected_relationship_ids, char* out_evidence) {
    if (out_max_depth != nullptr) *out_max_depth = 0;
    if (out_affected_object_ids != nullptr) *out_affected_object_ids = oep_package_id_list_t{nullptr, 0};
    if (out_affected_relationship_ids != nullptr) *out_affected_relationship_ids = oep_package_id_list_t{nullptr, 0};
    if (out_evidence != nullptr) out_evidence[0] = '\0';
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_reasoning_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::ImpactReport report = runtime->reasoning_engine.analyze_impact(object_id);
        if (out_max_depth != nullptr) *out_max_depth = report.max_depth();
        if (out_affected_object_ids != nullptr) *out_affected_object_ids = build_package_id_list(report.affected_object_ids());
        if (out_affected_relationship_ids != nullptr)
            *out_affected_relationship_ids = build_package_id_list(report.affected_relationship_ids());
        write_evidence(report.evidence(), out_evidence);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_analysis_reachability(OEP_Runtime runtime, const char* source_id, const char* target_id,
                                        int* out_reachable, oep_package_id_list_t* out_path, char* out_evidence) {
    if (out_reachable != nullptr) *out_reachable = 0;
    if (out_path != nullptr) *out_path = oep_package_id_list_t{nullptr, 0};
    if (out_evidence != nullptr) out_evidence[0] = '\0';
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (source_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "source_id is null");
    }
    if (target_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "target_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_reasoning_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::ReachabilityReport report = runtime->reasoning_engine.analyze_reachability(source_id, target_id);
        if (out_reachable != nullptr) *out_reachable = report.reachable() ? 1 : 0;
        if (out_path != nullptr) *out_path = build_package_id_list(report.path());
        write_evidence(report.evidence(), out_evidence);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_analysis_root_cause(OEP_Runtime runtime, const char* symptom_object_id,
                                      oep_package_id_list_t* out_candidate_root_causes,
                                      oep_package_id_list_t* out_failure_chain, char* out_evidence) {
    if (out_candidate_root_causes != nullptr) *out_candidate_root_causes = oep_package_id_list_t{nullptr, 0};
    if (out_failure_chain != nullptr) *out_failure_chain = oep_package_id_list_t{nullptr, 0};
    if (out_evidence != nullptr) out_evidence[0] = '\0';
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (symptom_object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "symptom_object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_reasoning_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::RootCauseReport report = runtime->reasoning_engine.analyze_root_cause(symptom_object_id);
        if (out_candidate_root_causes != nullptr) *out_candidate_root_causes = build_package_id_list(report.candidate_root_causes());
        if (out_failure_chain != nullptr) *out_failure_chain = build_package_id_list(report.failure_chain());
        write_evidence(report.evidence(), out_evidence);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_reasoning_create_session(OEP_Runtime runtime, const char* objective,
                                           const char* const* starting_object_ids, int starting_object_id_count,
                                           char* out_session_id, size_t session_id_buffer_size) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (objective == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "objective is null");
    }
    if (out_session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_session_id is null");
    }
    if (session_id_buffer_size == 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id_buffer_size is zero");
    }
    if (starting_object_id_count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "starting_object_id_count is negative");
    }
    if (starting_object_id_count > 0 && starting_object_ids == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "starting_object_ids is null but starting_object_id_count is nonzero");
    }
    out_session_id[0] = '\0';
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        std::vector<std::string> starting_objects;
        starting_objects.reserve(static_cast<std::size_t>(starting_object_id_count));
        for (int i = 0; i < starting_object_id_count; ++i) {
            starting_objects.emplace_back(starting_object_ids[i] != nullptr ? starting_object_ids[i] : "");
        }
        const std::string session_id =
            runtime->reasoning_engine.create_reasoning_session(objective, std::move(starting_objects));
        oep::api::detail::copy_truncated(session_id, out_session_id, session_id_buffer_size);
        return make_success_result();
    } catch (const std::exception& ex) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_reasoning_execute(OEP_Runtime runtime, const char* session_id, oep_reasoning_summary_t* out_summary,
                                    oep_package_id_list_t* out_conclusion_ids,
                                    oep_package_id_list_t* out_recommendation_ids) {
    if (out_summary != nullptr) zero_reasoning_summary(out_summary);
    if (out_conclusion_ids != nullptr) *out_conclusion_ids = oep_package_id_list_t{nullptr, 0};
    if (out_recommendation_ids != nullptr) *out_recommendation_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_reasoning_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const std::optional<oep::engine::ReasoningReport> report = runtime->reasoning_engine.execute_reasoning(session_id);
        return finish_reasoning_report(report, out_summary, out_conclusion_ids, out_recommendation_ids);
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_reasoning_summary(out_summary);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_reasoning_summary(out_summary);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_reasoning_report(OEP_Runtime runtime, const char* session_id, oep_reasoning_summary_t* out_summary,
                                   oep_package_id_list_t* out_conclusion_ids,
                                   oep_package_id_list_t* out_recommendation_ids) {
    if (out_summary != nullptr) zero_reasoning_summary(out_summary);
    if (out_conclusion_ids != nullptr) *out_conclusion_ids = oep_package_id_list_t{nullptr, 0};
    if (out_recommendation_ids != nullptr) *out_recommendation_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::ReasoningReport> report = runtime->reasoning_engine.reasoning_report(session_id);
        return finish_reasoning_report(report, out_summary, out_conclusion_ids, out_recommendation_ids);
    } catch (const std::exception& ex) {
        if (out_summary != nullptr) zero_reasoning_summary(out_summary);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_summary != nullptr) zero_reasoning_summary(out_summary);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_reasoning_recommendations(OEP_Runtime runtime, const char* session_id,
                                            oep_package_id_list_t* out_recommendation_ids) {
    if (out_recommendation_ids != nullptr) *out_recommendation_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::ReasoningReport> report = runtime->reasoning_engine.reasoning_report(session_id);
        if (!report.has_value()) {
            return make_error_result(
                OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                "session_id is not a session created on this handle, or has not been executed yet");
        }
        if (out_recommendation_ids != nullptr) *out_recommendation_ids = build_recommendation_id_list(*report);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

const char* oep_recommendation_kind_to_string(oep_recommendation_kind_t kind) {
    switch (kind) {
        case OEP_RECOMMENDATION_RELATED_PROCEDURE: return "RelatedProcedure";
        case OEP_RECOMMENDATION_SIMILAR_COMPONENT: return "SimilarComponent";
        case OEP_RECOMMENDATION_ADDITIONAL_INSPECTION: return "AdditionalInspection";
        case OEP_RECOMMENDATION_CONNECTED_SYSTEM: return "ConnectedSystem";
        case OEP_RECOMMENDATION_FOLLOW_UP_VALIDATION: return "FollowUpValidation";
    }
    return "RelatedProcedure";
}

oep_result_t oep_reasoning_get_conclusion(OEP_Runtime runtime, const char* session_id, const char* conclusion_id,
                                           oep_conclusion_t* out_conclusion,
                                           oep_package_id_list_t* out_supporting_evidence_ids,
                                           oep_package_id_list_t* out_referenced_objects,
                                           oep_package_id_list_t* out_referenced_rules,
                                           oep_package_id_list_t* out_referenced_findings) {
    if (out_conclusion != nullptr) *out_conclusion = oep_conclusion_t{};
    if (out_supporting_evidence_ids != nullptr) *out_supporting_evidence_ids = oep_package_id_list_t{nullptr, 0};
    if (out_referenced_objects != nullptr) *out_referenced_objects = oep_package_id_list_t{nullptr, 0};
    if (out_referenced_rules != nullptr) *out_referenced_rules = oep_package_id_list_t{nullptr, 0};
    if (out_referenced_findings != nullptr) *out_referenced_findings = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (conclusion_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "conclusion_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::ReasoningReport> report = runtime->reasoning_engine.reasoning_report(session_id);
        if (!report.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle, or has not been executed yet");
        }
        const oep::engine::EngineeringConclusion* conclusion = find_conclusion(*report, conclusion_id);
        if (conclusion == nullptr) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "conclusion_id was not found in this session's most recent report");
        }
        if (out_conclusion != nullptr) {
            oep::api::detail::copy_truncated(conclusion->conclusion_id(), out_conclusion->conclusion_id,
                                              sizeof(out_conclusion->conclusion_id));
            oep::api::detail::copy_truncated(conclusion->statement(), out_conclusion->statement,
                                              sizeof(out_conclusion->statement));
            out_conclusion->confidence = conclusion->confidence();
            oep::api::detail::copy_truncated(conclusion->explanation(), out_conclusion->explanation,
                                              sizeof(out_conclusion->explanation));
        }
        if (out_supporting_evidence_ids != nullptr)
            *out_supporting_evidence_ids = build_package_id_list(conclusion->supporting_evidence_ids());
        if (out_referenced_objects != nullptr) *out_referenced_objects = build_package_id_list(conclusion->referenced_objects());
        if (out_referenced_rules != nullptr) *out_referenced_rules = build_package_id_list(conclusion->referenced_rules());
        if (out_referenced_findings != nullptr) *out_referenced_findings = build_package_id_list(conclusion->referenced_findings());
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_reasoning_get_recommendation(OEP_Runtime runtime, const char* session_id,
                                               const char* recommendation_id, oep_recommendation_t* out_recommendation,
                                               oep_package_id_list_t* out_evidence_ids) {
    if (out_recommendation != nullptr) *out_recommendation = oep_recommendation_t{};
    if (out_evidence_ids != nullptr) *out_evidence_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (recommendation_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "recommendation_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::ReasoningReport> report = runtime->reasoning_engine.reasoning_report(session_id);
        if (!report.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle, or has not been executed yet");
        }
        const oep::engine::EngineeringRecommendation* recommendation = find_recommendation(*report, recommendation_id);
        if (recommendation == nullptr) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "recommendation_id was not found in this session's most recent report");
        }
        if (out_recommendation != nullptr) {
            oep::api::detail::copy_truncated(recommendation->recommendation_id(), out_recommendation->recommendation_id,
                                              sizeof(out_recommendation->recommendation_id));
            out_recommendation->kind = to_capi_recommendation_kind(recommendation->kind());
            oep::api::detail::copy_truncated(recommendation->object_id(), out_recommendation->object_id,
                                              sizeof(out_recommendation->object_id));
            oep::api::detail::copy_truncated(recommendation->message(), out_recommendation->message,
                                              sizeof(out_recommendation->message));
        }
        if (out_evidence_ids != nullptr) *out_evidence_ids = build_package_id_list(recommendation->supporting_evidence_ids());
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_reasoning_get_evidence_node(OEP_Runtime runtime, const char* session_id, const char* evidence_id,
                                              oep_evidence_node_t* out_node) {
    if (out_node != nullptr) *out_node = oep_evidence_node_t{};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (evidence_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "evidence_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::ReasoningReport> report = runtime->reasoning_engine.reasoning_report(session_id);
        if (!report.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle, or has not been executed yet");
        }
        const oep::engine::EvidenceNode* node = find_evidence_node(*report, evidence_id);
        if (node == nullptr) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "evidence_id was not found in this session's Evidence Graph");
        }
        if (out_node != nullptr) {
            oep::api::detail::copy_truncated(node->evidence_id(), out_node->evidence_id, sizeof(out_node->evidence_id));
            out_node->kind = static_cast<int>(node->kind());
            oep::api::detail::copy_truncated(node->reference_id(), out_node->reference_id, sizeof(out_node->reference_id));
            oep::api::detail::copy_truncated(node->detail(), out_node->detail, sizeof(out_node->detail));
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_validation_statistics(OEP_Runtime runtime, const char* session_id,
                                        oep_validation_statistics_t* out_stats) {
    if (out_stats != nullptr) zero_validation_statistics(out_stats);
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (out_stats == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_stats is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::ValidationStatistics> statistics =
            runtime->validation_engine.validation_statistics(session_id);
        if (!statistics.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle");
        }
        populate_validation_statistics(*statistics, out_stats);
        return make_success_result();
    } catch (const std::exception& ex) {
        zero_validation_statistics(out_stats);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        zero_validation_statistics(out_stats);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

} // extern "C"

namespace {

oep::engine::InspectionTargetKind from_capi_inspection_target_kind(oep_inspection_target_kind_t kind) {
    switch (kind) {
        case OEP_INSPECTION_TARGET_OBJECT: return oep::engine::InspectionTargetKind::Object;
        case OEP_INSPECTION_TARGET_PACKAGE: return oep::engine::InspectionTargetKind::Package;
        case OEP_INSPECTION_TARGET_CONTEXT: return oep::engine::InspectionTargetKind::Context;
    }
    return oep::engine::InspectionTargetKind::Object;
}

oep_workflow_kind_t to_capi_workflow_kind(oep::engine::WorkflowKind kind) {
    switch (kind) {
        case oep::engine::WorkflowKind::Inspect: return OEP_WORKFLOW_INSPECT;
        case oep::engine::WorkflowKind::Query: return OEP_WORKFLOW_QUERY;
        case oep::engine::WorkflowKind::Validate: return OEP_WORKFLOW_VALIDATE;
        case oep::engine::WorkflowKind::Analyze: return OEP_WORKFLOW_ANALYZE;
        case oep::engine::WorkflowKind::Reason: return OEP_WORKFLOW_REASON;
        case oep::engine::WorkflowKind::Recommend: return OEP_WORKFLOW_RECOMMEND;
    }
    return OEP_WORKFLOW_INSPECT;
}

oep_result_t require_eip_graph_ready(OEP_Runtime runtime) {
    if (!runtime->intelligence_platform.graph_ready()) {
        return make_error_result(OEP_ERROR_INVALID_STATE, category_for_code(OEP_ERROR_INVALID_STATE),
                                  "Knowledge Graph is not ready -- call oep_engine_load_graph and "
                                  "oep_kge_build_graph first");
    }
    return make_success_result();
}

oep_result_t require_eip_session(OEP_Runtime runtime, const std::string& session_id) {
    if (!runtime->intelligence_platform.get_session(session_id).has_value()) {
        return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                  "session_id is not a session created on this handle");
    }
    return make_success_result();
}

void zero_workflow_result(oep_workflow_result_t* out_result) {
    out_result->kind = OEP_WORKFLOW_INSPECT;
    out_result->success = 0;
    out_result->summary[0] = '\0';
    out_result->execution_time_ms = 0.0;
}

void populate_workflow_result(const oep::engine::WorkflowResult& result, oep_workflow_result_t* out_result) {
    out_result->kind = to_capi_workflow_kind(result.kind);
    out_result->success = result.success ? 1 : 0;
    oep::api::detail::copy_truncated(result.summary, out_result->summary, sizeof(out_result->summary));
    out_result->execution_time_ms = result.execution_time_ms;
}

void populate_session_summary(const oep::engine::KnowledgeSession& session, oep_knowledge_session_summary_t* out_session) {
    oep::api::detail::copy_truncated(session.session_id(), out_session->session_id, sizeof(out_session->session_id));
    oep::api::detail::copy_truncated(session.created_utc(), out_session->created_utc, sizeof(out_session->created_utc));
    oep::api::detail::copy_truncated(session.last_active_utc(), out_session->last_active_utc,
                                      sizeof(out_session->last_active_utc));
    out_session->closed = session.closed() ? 1 : 0;
    out_session->query_history_count = static_cast<int>(session.query_history().size());
    out_session->validation_history_count = static_cast<int>(session.validation_history().size());
    out_session->analysis_history_count = static_cast<int>(session.analysis_history().size());
    out_session->reasoning_history_count = static_cast<int>(session.reasoning_history().size());
    out_session->recommendation_count = static_cast<int>(session.recommendations().size());
    out_session->active_object_count = static_cast<int>(session.active_objects().size());
    out_session->active_package_count = static_cast<int>(session.active_packages().size());
    out_session->total_execution_time_ms = session.statistics().total_execution_time_ms;
}

} // namespace

extern "C" {

const char* oep_workflow_kind_to_string(oep_workflow_kind_t kind) {
    switch (kind) {
        case OEP_WORKFLOW_INSPECT: return "Inspect";
        case OEP_WORKFLOW_QUERY: return "Query";
        case OEP_WORKFLOW_VALIDATE: return "Validate";
        case OEP_WORKFLOW_ANALYZE: return "Analyze";
        case OEP_WORKFLOW_REASON: return "Reason";
        case OEP_WORKFLOW_RECOMMEND: return "Recommend";
    }
    return "Inspect";
}

const char* oep_inspection_target_kind_to_string(oep_inspection_target_kind_t kind) {
    switch (kind) {
        case OEP_INSPECTION_TARGET_OBJECT: return "Object";
        case OEP_INSPECTION_TARGET_PACKAGE: return "Package";
        case OEP_INSPECTION_TARGET_CONTEXT: return "Context";
    }
    return "Object";
}

oep_result_t oep_eip_create_session(OEP_Runtime runtime, char* out_session_id, size_t buffer_size) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_session_id is null");
    }
    if (buffer_size == 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "buffer_size is zero");
    }
    out_session_id[0] = '\0';
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::string session_id = runtime->intelligence_platform.create_session();
        oep::api::detail::copy_truncated(session_id, out_session_id, buffer_size);
        return make_success_result();
    } catch (const std::exception& ex) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_resume_session(OEP_Runtime runtime, const char* session_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        if (!runtime->intelligence_platform.resume_session(session_id)) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle, or is closed");
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_clone_session(OEP_Runtime runtime, const char* session_id, char* out_session_id,
                                    size_t buffer_size) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (out_session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_session_id is null");
    }
    if (buffer_size == 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "buffer_size is zero");
    }
    out_session_id[0] = '\0';
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<std::string> cloned = runtime->intelligence_platform.clone_session(session_id);
        if (!cloned.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle");
        }
        oep::api::detail::copy_truncated(*cloned, out_session_id, buffer_size);
        return make_success_result();
    } catch (const std::exception& ex) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        out_session_id[0] = '\0';
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_close_session(OEP_Runtime runtime, const char* session_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        if (!runtime->intelligence_platform.close_session(session_id)) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle");
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_switch_session(OEP_Runtime runtime, const char* session_id) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        if (!runtime->intelligence_platform.switch_session(session_id)) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle, or is closed");
        }
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_list_sessions(OEP_Runtime runtime, oep_package_id_list_t* out_session_ids) {
    if (out_session_ids != nullptr) *out_session_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_session_ids == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_session_ids is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        *out_session_ids = build_package_id_list(runtime->intelligence_platform.list_sessions());
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_get_session(OEP_Runtime runtime, const char* session_id,
                                  oep_knowledge_session_summary_t* out_session) {
    if (out_session != nullptr) *out_session = oep_knowledge_session_summary_t{};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<oep::engine::KnowledgeSession> session = runtime->intelligence_platform.get_session(session_id);
        if (!session.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle");
        }
        if (out_session != nullptr) populate_session_summary(*session, out_session);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_export_session_summary(OEP_Runtime runtime, const char* session_id, char** out_summary,
                                             size_t* out_length) {
    if (out_summary != nullptr) *out_summary = nullptr;
    if (out_length != nullptr) *out_length = 0;
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (out_summary == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_summary is null");
    }
    if (out_length == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_length is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const std::optional<std::string> summary = runtime->intelligence_platform.export_session_summary(session_id);
        if (!summary.has_value()) {
            return make_error_result(OEP_ERROR_NOT_FOUND, category_for_code(OEP_ERROR_NOT_FOUND),
                                      "session_id is not a session created on this handle");
        }
        *out_summary = copy_owned_string(*summary, out_length);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_query(OEP_Runtime runtime, const char* session_id, oep_query_category_t category,
                            const char* primary_object_id, oep_workflow_result_t* out_result,
                            oep_package_id_list_t* out_object_ids) {
    if (out_result != nullptr) zero_workflow_result(out_result);
    if (out_object_ids != nullptr) *out_object_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (primary_object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "primary_object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t session_check = require_eip_session(runtime, session_id);
        if (!session_check.success) return session_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::WorkflowResult result =
            runtime->intelligence_platform.query(session_id, from_capi_query_category(category), primary_object_id);
        if (out_result != nullptr) populate_workflow_result(result, out_result);
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_inspect(OEP_Runtime runtime, const char* session_id, oep_inspection_target_kind_t kind,
                              const char* target_id, oep_workflow_result_t* out_result,
                              oep_package_id_list_t* out_object_ids) {
    if (out_result != nullptr) zero_workflow_result(out_result);
    if (out_object_ids != nullptr) *out_object_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (target_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "target_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t session_check = require_eip_session(runtime, session_id);
        if (!session_check.success) return session_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::WorkflowResult result =
            runtime->intelligence_platform.inspect(session_id, from_capi_inspection_target_kind(kind), target_id);
        if (out_result != nullptr) populate_workflow_result(result, out_result);
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_validate(OEP_Runtime runtime, const char* session_id, const char* object_id,
                               oep_validation_profile_t profile, oep_workflow_result_t* out_result,
                               oep_package_id_list_t* out_object_ids) {
    if (out_result != nullptr) zero_workflow_result(out_result);
    if (out_object_ids != nullptr) *out_object_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t session_check = require_eip_session(runtime, session_id);
        if (!session_check.success) return session_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::WorkflowResult result =
            runtime->intelligence_platform.validate(session_id, object_id, from_capi_validation_profile(profile));
        if (out_result != nullptr) populate_workflow_result(result, out_result);
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_analyze(OEP_Runtime runtime, const char* session_id, const char* object_id,
                              oep_workflow_result_t* out_result, oep_package_id_list_t* out_object_ids) {
    if (out_result != nullptr) zero_workflow_result(out_result);
    if (out_object_ids != nullptr) *out_object_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t session_check = require_eip_session(runtime, session_id);
        if (!session_check.success) return session_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::WorkflowResult result = runtime->intelligence_platform.analyze(session_id, object_id);
        if (out_result != nullptr) populate_workflow_result(result, out_result);
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_reason(OEP_Runtime runtime, const char* session_id, const char* objective,
                             const char* const* starting_object_ids, int starting_object_id_count,
                             oep_workflow_result_t* out_result, oep_package_id_list_t* out_object_ids) {
    if (out_result != nullptr) zero_workflow_result(out_result);
    if (out_object_ids != nullptr) *out_object_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (objective == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "objective is null");
    }
    if (starting_object_id_count < 0) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "starting_object_id_count is negative");
    }
    if (starting_object_id_count > 0 && starting_object_ids == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "starting_object_ids is null but starting_object_id_count is nonzero");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t session_check = require_eip_session(runtime, session_id);
        if (!session_check.success) return session_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        std::vector<std::string> starting_objects;
        starting_objects.reserve(static_cast<std::size_t>(starting_object_id_count));
        for (int i = 0; i < starting_object_id_count; ++i) {
            starting_objects.emplace_back(starting_object_ids[i] != nullptr ? starting_object_ids[i] : "");
        }
        const oep::engine::WorkflowResult result =
            runtime->intelligence_platform.reason(session_id, objective, starting_objects);
        if (out_result != nullptr) populate_workflow_result(result, out_result);
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_recommend(OEP_Runtime runtime, const char* session_id, const char* object_id,
                                oep_workflow_result_t* out_result, oep_package_id_list_t* out_object_ids) {
    if (out_result != nullptr) zero_workflow_result(out_result);
    if (out_object_ids != nullptr) *out_object_ids = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (session_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "session_id is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t session_check = require_eip_session(runtime, session_id);
        if (!session_check.success) return session_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::WorkflowResult result = runtime->intelligence_platform.recommend(session_id, object_id);
        if (out_result != nullptr) populate_workflow_result(result, out_result);
        if (out_object_ids != nullptr) *out_object_ids = build_package_id_list(result.object_ids);
        return make_success_result();
    } catch (const std::exception& ex) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        if (out_result != nullptr) zero_workflow_result(out_result);
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_engineering_summary(OEP_Runtime runtime, oep_engineering_summary_report_t* out_summary) {
    if (out_summary != nullptr) *out_summary = oep_engineering_summary_report_t{};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_summary == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_summary is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::EngineeringSummaryReport report = runtime->intelligence_platform.engineering_summary();
        out_summary->object_count = static_cast<int>(report.object_count());
        out_summary->relationship_count = static_cast<int>(report.relationship_count());
        out_summary->connected_component_count = static_cast<int>(report.connected_component_count());
        out_summary->validation_pass_count = static_cast<int>(report.validation_pass_count());
        out_summary->validation_finding_count = static_cast<int>(report.validation_finding_count());
        oep::api::detail::copy_truncated(report.summary(), out_summary->summary, sizeof(out_summary->summary));
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_engineering_health(OEP_Runtime runtime, oep_engineering_health_report_t* out_health) {
    if (out_health != nullptr) *out_health = oep_engineering_health_report_t{};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_health == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_health is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const oep::engine::EngineeringHealthReport report = runtime->intelligence_platform.engineering_health();
        out_health->health_score = report.health_score();
        out_health->passed = static_cast<int>(report.passed());
        out_health->failed = static_cast<int>(report.failed());
        out_health->warnings = static_cast<int>(report.warnings());
        out_health->errors = static_cast<int>(report.errors());
        out_health->critical = static_cast<int>(report.critical());
        oep::api::detail::copy_truncated(report.summary(), out_health->summary, sizeof(out_health->summary));
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_engineering_recommendations(OEP_Runtime runtime, const char* object_id,
                                                  oep_package_id_list_t* out_recommendation_messages) {
    if (out_recommendation_messages != nullptr) *out_recommendation_messages = oep_package_id_list_t{nullptr, 0};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (object_id == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "object_id is null");
    }
    if (out_recommendation_messages == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_recommendation_messages is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep_result_t ready_check = require_eip_graph_ready(runtime);
        if (!ready_check.success) return ready_check;
        const std::vector<oep::engine::EngineeringRecommendation> recommendations =
            runtime->intelligence_platform.engineering_recommendations(object_id);
        std::vector<std::string> messages;
        messages.reserve(recommendations.size());
        for (const oep::engine::EngineeringRecommendation& recommendation : recommendations) {
            messages.push_back(recommendation.message());
        }
        *out_recommendation_messages = build_package_id_list(messages);
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_runtime_metrics(OEP_Runtime runtime, oep_runtime_metrics_t* out_metrics) {
    if (out_metrics != nullptr) *out_metrics = oep_runtime_metrics_t{};
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    if (out_metrics == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "out_metrics is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        const oep::engine::RuntimeMetrics metrics = runtime->intelligence_platform.runtime_metrics();
        out_metrics->query_count = static_cast<int>(metrics.query_count);
        out_metrics->validation_count = static_cast<int>(metrics.validation_count);
        out_metrics->analysis_count = static_cast<int>(metrics.analysis_count);
        out_metrics->reasoning_count = static_cast<int>(metrics.reasoning_count);
        out_metrics->cache_hits = static_cast<int>(metrics.cache_hits);
        out_metrics->cache_misses = static_cast<int>(metrics.cache_misses);
        out_metrics->active_session_count = static_cast<int>(metrics.active_session_count);
        out_metrics->total_session_count = static_cast<int>(metrics.total_session_count);
        out_metrics->total_execution_time_ms = metrics.total_execution_time_ms;
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_invalidate_caches(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        runtime->intelligence_platform.invalidate_caches();
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

oep_result_t oep_eip_cleanup(OEP_Runtime runtime) {
    if (runtime == nullptr) {
        return make_error_result(OEP_ERROR_INVALID_ARGUMENT, category_for_code(OEP_ERROR_INVALID_ARGUMENT),
                                  "runtime handle is null");
    }
    try {
        const oep_result_t open_check = require_repository_open_for_validation(runtime);
        if (!open_check.success) return open_check;
        runtime->intelligence_platform.cleanup();
        return make_success_result();
    } catch (const std::exception& ex) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), ex.what());
    } catch (...) {
        return make_error_result(OEP_ERROR_INTERNAL, category_for_code(OEP_ERROR_INTERNAL), "unknown internal error");
    }
}

} // extern "C"
