#include "oep_api_internal.hpp"

#include "oep/runtime/foundation_version.hpp"

namespace {

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

} // namespace oep::api::detail

using oep::api::detail::category_for_code;
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

void zero_package_uninstall_result(oep_package_uninstall_result_t* out_result) {
    out_result->package_id[0] = '\0';
    out_result->version[0] = '\0';
    out_result->objects_deleted = 0;
    out_result->relationships_deleted = 0;
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
        const oep::runtime::RuntimeObjectMutationResult result = runtime->runtime.create_object(
            *internal_type, name, description != nullptr ? description : "", author != nullptr ? author : "",
            tags_from_capi(tags, tag_count));
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
        const oep::runtime::RuntimeObjectMutationResult result = runtime->runtime.update_object(
            object_id, name, description != nullptr ? description : "", author != nullptr ? author : "",
            tags_from_capi(tags, tag_count));
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
        const oep::runtime::RuntimeResult result = runtime->runtime.delete_object(object_id);
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
        const oep::runtime::RuntimeRelationshipMutationResult result = runtime->runtime.create_relationship(
            source_object_id, target_object_id, *internal_type, author != nullptr ? author : "",
            description != nullptr ? description : "");
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
        const oep::runtime::RuntimeRelationshipMutationResult result = runtime->runtime.update_relationship(
            relationship_id, author != nullptr ? author : "", description != nullptr ? description : "");
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
        const oep::runtime::RuntimeResult result = runtime->runtime.delete_relationship(relationship_id);
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
        const oep::runtime::RuntimeInstallResult result = runtime->runtime.install_package(archive_path);
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
        const oep::runtime::RuntimeUninstallResult result = runtime->runtime.uninstall_package(package_id);
        if (!result.success) {
            const bool not_found = result.error.find("is not installed") != std::string::npos;
            const oep_error_code_t code = not_found ? OEP_ERROR_NOT_FOUND : OEP_ERROR_OPERATION_FAILED;
            return make_error_result(code, category_for_code(code), result.error);
        }
        if (out_result != nullptr) {
            oep::api::detail::copy_truncated(result.package_id, out_result->package_id,
                                              sizeof(out_result->package_id));
            oep::api::detail::copy_truncated(result.version, out_result->version, sizeof(out_result->version));
            out_result->objects_deleted = result.objects_deleted;
            out_result->relationships_deleted = result.relationships_deleted;
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

} // extern "C"
