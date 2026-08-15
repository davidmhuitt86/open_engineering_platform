#include "archive_codec.hpp"

#include <string>

namespace oep::archive::archive_codec {

namespace {

std::string read_string(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

int read_int(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    if (found == nullptr || !found->is_string()) return 0; // counts are stored as strings for a uniform codec
    try {
        return std::stoi(found->as_string());
    } catch (...) {
        return 0;
    }
}

std::vector<std::string> read_string_array(const json::Value& value, const char* key) {
    std::vector<std::string> result;
    const json::Value* found = value.find(key);
    if (found == nullptr || !found->is_array()) return result;
    for (const json::Value& entry : found->as_array()) {
        if (entry.is_string()) result.push_back(entry.as_string());
    }
    return result;
}

json::Value string_array(const std::vector<std::string>& values) {
    json::Array array;
    for (const std::string& value : values) array.push_back(json::Value::string(value));
    return json::Value::array(std::move(array));
}

} // namespace

json::Value to_json(const ExportManifest& manifest) {
    json::Object fields;
    fields.emplace_back("exportVersion", json::Value::string(manifest.export_version));
    fields.emplace_back("exportTimestampUtc", json::Value::string(manifest.export_timestamp_utc));
    fields.emplace_back("repositoryId", json::Value::string(manifest.repository_id));
    fields.emplace_back("repositoryVersion", json::Value::string(manifest.repository_version));
    fields.emplace_back("objectCount", json::Value::string(std::to_string(manifest.object_count)));
    fields.emplace_back("relationshipCount", json::Value::string(std::to_string(manifest.relationship_count)));
    fields.emplace_back("packageCount", json::Value::string(std::to_string(manifest.package_count)));
    return json::Value::object(std::move(fields));
}

ExportManifest export_manifest_from_json(const json::Value& value) {
    ExportManifest manifest;
    manifest.export_version = read_string(value, "exportVersion");
    manifest.export_timestamp_utc = read_string(value, "exportTimestampUtc");
    manifest.repository_id = read_string(value, "repositoryId");
    manifest.repository_version = read_string(value, "repositoryVersion");
    manifest.object_count = read_int(value, "objectCount");
    manifest.relationship_count = read_int(value, "relationshipCount");
    manifest.package_count = read_int(value, "packageCount");
    return manifest;
}

json::Value to_json(const oep::repository::RepositoryMetadata& metadata) {
    json::Object fields;
    fields.emplace_back("repositoryId", json::Value::string(metadata.repository_id));
    fields.emplace_back("repositoryName", json::Value::string(metadata.repository_name));
    fields.emplace_back("repositoryVersion", json::Value::string(metadata.repository_version));
    fields.emplace_back("foundationVersion", json::Value::string(metadata.foundation_version));
    fields.emplace_back("templateVersion", json::Value::string(metadata.template_version));
    fields.emplace_back("createdUtc", json::Value::string(metadata.created_utc));
    fields.emplace_back("lastModifiedUtc", json::Value::string(metadata.last_modified_utc));
    fields.emplace_back("description", json::Value::string(metadata.description));
    fields.emplace_back("author", json::Value::string(metadata.author));
    fields.emplace_back("organization", json::Value::string(metadata.organization));
    fields.emplace_back("tags", string_array(metadata.tags));
    return json::Value::object(std::move(fields));
}

oep::repository::RepositoryMetadata metadata_from_json(const json::Value& value) {
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = read_string(value, "repositoryId");
    metadata.repository_name = read_string(value, "repositoryName");
    metadata.repository_version = read_string(value, "repositoryVersion");
    metadata.foundation_version = read_string(value, "foundationVersion");
    metadata.template_version = read_string(value, "templateVersion");
    metadata.created_utc = read_string(value, "createdUtc");
    metadata.last_modified_utc = read_string(value, "lastModifiedUtc");
    metadata.description = read_string(value, "description");
    metadata.author = read_string(value, "author");
    metadata.organization = read_string(value, "organization");
    metadata.tags = read_string_array(value, "tags");
    return metadata;
}

json::Value to_json(const oep::repository::EngineeringObject& object) {
    json::Object fields;
    fields.emplace_back("objectId", json::Value::string(object.object_id));
    fields.emplace_back("objectType", json::Value::string(oep::repository::to_string(object.object_type)));
    fields.emplace_back("name", json::Value::string(object.name));
    fields.emplace_back("description", json::Value::string(object.description));
    fields.emplace_back("createdUtc", json::Value::string(object.created_utc));
    fields.emplace_back("lastModifiedUtc", json::Value::string(object.last_modified_utc));
    fields.emplace_back("version", json::Value::string(object.version));
    fields.emplace_back("author", json::Value::string(object.author));
    fields.emplace_back("tags", string_array(object.tags));
    return json::Value::object(std::move(fields));
}

oep::repository::EngineeringObject object_from_json(const json::Value& value, bool& ok) {
    oep::repository::EngineeringObject object;
    object.object_id = read_string(value, "objectId");
    const auto type = oep::repository::object_type_from_string(read_string(value, "objectType"));
    if (!type.has_value()) {
        ok = false;
        return object;
    }
    object.object_type = *type;
    object.name = read_string(value, "name");
    object.description = read_string(value, "description");
    object.created_utc = read_string(value, "createdUtc");
    object.last_modified_utc = read_string(value, "lastModifiedUtc");
    object.version = read_string(value, "version");
    object.author = read_string(value, "author");
    object.tags = read_string_array(value, "tags");
    ok = true;
    return object;
}

json::Value to_json(const oep::repository::Relationship& relationship) {
    json::Object fields;
    fields.emplace_back("relationshipId", json::Value::string(relationship.relationship_id));
    fields.emplace_back("sourceObjectId", json::Value::string(relationship.source_object_id));
    fields.emplace_back("targetObjectId", json::Value::string(relationship.target_object_id));
    fields.emplace_back("relationshipType",
                         json::Value::string(oep::repository::to_string(relationship.relationship_type)));
    fields.emplace_back("createdUtc", json::Value::string(relationship.created_utc));
    fields.emplace_back("author", json::Value::string(relationship.author));
    fields.emplace_back("description", json::Value::string(relationship.description));
    return json::Value::object(std::move(fields));
}

oep::repository::Relationship relationship_from_json(const json::Value& value, bool& ok) {
    oep::repository::Relationship relationship;
    relationship.relationship_id = read_string(value, "relationshipId");
    relationship.source_object_id = read_string(value, "sourceObjectId");
    relationship.target_object_id = read_string(value, "targetObjectId");
    const auto type = oep::repository::relationship_type_from_string(read_string(value, "relationshipType"));
    if (!type.has_value()) {
        ok = false;
        return relationship;
    }
    relationship.relationship_type = *type;
    relationship.created_utc = read_string(value, "createdUtc");
    relationship.author = read_string(value, "author");
    relationship.description = read_string(value, "description");
    ok = true;
    return relationship;
}

json::Value to_json(const oep::repository::AuditEvent& event) {
    json::Object fields;
    fields.emplace_back("eventId", json::Value::string(event.event_id));
    fields.emplace_back("timestampUtc", json::Value::string(event.timestamp_utc));
    fields.emplace_back("eventType", json::Value::string(oep::repository::to_string(event.event_type)));
    fields.emplace_back("objectId", json::Value::string(event.object_id));
    fields.emplace_back("user", json::Value::string(event.user));
    fields.emplace_back("description", json::Value::string(event.description));
    return json::Value::object(std::move(fields));
}

oep::repository::AuditEvent audit_event_from_json(const json::Value& value, bool& ok) {
    oep::repository::AuditEvent event;
    event.event_id = read_string(value, "eventId");
    event.timestamp_utc = read_string(value, "timestampUtc");
    const auto type = oep::repository::audit_event_type_from_string(read_string(value, "eventType"));
    if (!type.has_value()) {
        ok = false;
        return event;
    }
    event.event_type = *type;
    event.object_id = read_string(value, "objectId");
    event.user = read_string(value, "user");
    event.description = read_string(value, "description");
    ok = true;
    return event;
}

json::Value to_json(const oep::packages::PackageManifest& manifest) {
    json::Object fields;
    fields.emplace_back("packageId", json::Value::string(manifest.package_id));
    fields.emplace_back("packageName", json::Value::string(manifest.package_name));
    fields.emplace_back("packageVersion", json::Value::string(manifest.package_version));
    fields.emplace_back("packageType", json::Value::string(oep::packages::to_string(manifest.package_type)));
    fields.emplace_back("author", json::Value::string(manifest.author));
    fields.emplace_back("organization", json::Value::string(manifest.organization));
    fields.emplace_back("description", json::Value::string(manifest.description));
    fields.emplace_back("tags", string_array(manifest.tags));
    fields.emplace_back("foundationVersion", json::Value::string(manifest.foundation_version));
    fields.emplace_back("createdUtc", json::Value::string(manifest.created_utc));
    return json::Value::object(std::move(fields));
}

oep::packages::PackageManifest package_manifest_from_json(const json::Value& value, bool& ok) {
    oep::packages::PackageManifest manifest;
    manifest.package_id = read_string(value, "packageId");
    manifest.package_name = read_string(value, "packageName");
    manifest.package_version = read_string(value, "packageVersion");
    const auto type = oep::packages::package_type_from_string(read_string(value, "packageType"));
    if (!type.has_value()) {
        ok = false;
        return manifest;
    }
    manifest.package_type = *type;
    manifest.author = read_string(value, "author");
    manifest.organization = read_string(value, "organization");
    manifest.description = read_string(value, "description");
    manifest.tags = read_string_array(value, "tags");
    manifest.foundation_version = read_string(value, "foundationVersion");
    manifest.created_utc = read_string(value, "createdUtc");
    ok = true;
    return manifest;
}

json::Value to_json(const TemplateManifest& manifest) {
    json::Object fields;
    fields.emplace_back("templateId", json::Value::string(manifest.template_id));
    fields.emplace_back("templateName", json::Value::string(manifest.template_name));
    fields.emplace_back("version", json::Value::string(manifest.version));
    fields.emplace_back("description", json::Value::string(manifest.description));
    fields.emplace_back("author", json::Value::string(manifest.author));
    fields.emplace_back("tags", string_array(manifest.tags));
    fields.emplace_back("foundationVersion", json::Value::string(manifest.foundation_version));
    return json::Value::object(std::move(fields));
}

TemplateManifest template_manifest_from_json(const json::Value& value) {
    TemplateManifest manifest;
    manifest.template_id = read_string(value, "templateId");
    manifest.template_name = read_string(value, "templateName");
    manifest.version = read_string(value, "version");
    manifest.description = read_string(value, "description");
    manifest.author = read_string(value, "author");
    manifest.tags = read_string_array(value, "tags");
    manifest.foundation_version = read_string(value, "foundationVersion");
    return manifest;
}

} // namespace oep::archive::archive_codec
