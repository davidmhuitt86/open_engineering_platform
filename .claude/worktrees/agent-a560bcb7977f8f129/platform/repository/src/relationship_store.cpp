#include "oep/repository/relationship_store.hpp"

#include <fstream>
#include <sstream>
#include <system_error>

#include "oep/repository/json_value.hpp"
#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

namespace oep::repository {

namespace {

std::string join_errors(const std::vector<std::string>& errors) {
    std::string message;
    for (std::size_t i = 0; i < errors.size(); ++i) {
        message += errors[i];
        if (i + 1 != errors.size()) message += "; ";
    }
    return message;
}

json::Value to_json(const Relationship& relationship) {
    json::Object fields;
    fields.emplace_back("relationshipId", json::Value::string(relationship.relationship_id));
    fields.emplace_back("sourceObjectId", json::Value::string(relationship.source_object_id));
    fields.emplace_back("targetObjectId", json::Value::string(relationship.target_object_id));
    fields.emplace_back("relationshipType", json::Value::string(to_string(relationship.relationship_type)));
    fields.emplace_back("createdUtc", json::Value::string(relationship.created_utc));
    fields.emplace_back("author", json::Value::string(relationship.author));
    fields.emplace_back("description", json::Value::string(relationship.description));
    return json::Value::object(std::move(fields));
}

std::string read_string_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

struct ParsedRelationship {
    bool success = false;
    std::string error;
    Relationship relationship;
};

ParsedRelationship read_relationship_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'", {}};
    }

    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();

    const json::ParseResult parsed = json::parse(contents_stream.str());
    if (!parsed.success) {
        return {false, "invalid JSON in '" + path.string() + "': " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "'" + path.string() + "' must contain a JSON object", {}};
    }

    Relationship relationship;
    relationship.relationship_id = read_string_field(parsed.value, "relationshipId");
    relationship.source_object_id = read_string_field(parsed.value, "sourceObjectId");
    relationship.target_object_id = read_string_field(parsed.value, "targetObjectId");

    const std::string type_name = read_string_field(parsed.value, "relationshipType");
    const std::optional<RelationshipType> type = relationship_type_from_string(type_name);
    if (!type.has_value()) {
        return {false, "'" + path.string() + "' has an unrecognized relationshipType '" + type_name + "'", {}};
    }
    relationship.relationship_type = *type;

    relationship.created_utc = read_string_field(parsed.value, "createdUtc");
    relationship.author = read_string_field(parsed.value, "author");
    relationship.description = read_string_field(parsed.value, "description");

    return {true, "", relationship};
}

RelationshipResult write_relationship_file(const std::filesystem::path& path, const Relationship& relationship) {
    const std::string serialized = json::serialize(to_json(relationship));

    const std::filesystem::path temp_path = path.string() + ".tmp";
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file) {
            return {false, "could not open '" + temp_path.string() + "' for writing"};
        }
        file << serialized;
    }

    std::error_code error_code;
    std::filesystem::rename(temp_path, path, error_code);
    if (error_code) {
        std::filesystem::remove(temp_path, error_code);
        return {false, "could not finalize '" + path.string() + "': " + error_code.message()};
    }

    return {true, ""};
}

} // namespace

RelationshipStore::RelationshipStore(std::filesystem::path root, ObjectStore objects, AuditStore audit)
    : root_(std::move(root)), objects_(std::move(objects)), audit_(std::move(audit)) {}

std::filesystem::path RelationshipStore::path_for(const std::string& relationship_id) const {
    return root_ / (relationship_id + ".json");
}

void RelationshipStore::record_audit(AuditEventType event_type, const std::string& relationship_id) const {
    AuditEvent event;
    event.event_type = event_type;
    event.object_id = relationship_id;
    audit_.record_event(event); // best effort: never blocks the calling operation's success
}

LoadRelationshipResult RelationshipStore::create(Relationship relationship) const {
    if (relationship.relationship_id.empty()) {
        relationship.relationship_id = generate_uuid_v4();
    }
    if (relationship.created_utc.empty()) {
        relationship.created_utc = current_timestamp_utc();
    }

    const std::vector<std::string> errors = validate_relationship(relationship);
    if (!errors.empty()) {
        return {false, "refusing to create invalid relationship: " + join_errors(errors), {}};
    }

    if (!objects_.load(relationship.source_object_id).success) {
        return {false, "sourceObjectId '" + relationship.source_object_id + "' does not exist", {}};
    }
    if (!objects_.load(relationship.target_object_id).success) {
        return {false, "targetObjectId '" + relationship.target_object_id + "' does not exist", {}};
    }

    std::error_code error_code;
    std::filesystem::create_directories(root_, error_code);
    if (error_code) {
        return {false, "could not create '" + root_.string() + "': " + error_code.message(), {}};
    }

    const std::filesystem::path path = path_for(relationship.relationship_id);
    if (std::filesystem::exists(path)) {
        return {false, "a relationship with id '" + relationship.relationship_id + "' already exists", {}};
    }

    const RelationshipResult write_result = write_relationship_file(path, relationship);
    if (!write_result.success) {
        return {false, write_result.error, {}};
    }

    record_audit(AuditEventType::RelationshipCreated, relationship.relationship_id);
    return {true, "", relationship};
}

LoadRelationshipResult RelationshipStore::restore(Relationship relationship) const {
    const std::vector<std::string> errors = validate_relationship(relationship);
    if (!errors.empty()) {
        return {false, "refusing to restore invalid relationship: " + join_errors(errors), {}};
    }

    if (!objects_.load(relationship.source_object_id).success) {
        return {false, "sourceObjectId '" + relationship.source_object_id + "' does not exist", {}};
    }
    if (!objects_.load(relationship.target_object_id).success) {
        return {false, "targetObjectId '" + relationship.target_object_id + "' does not exist", {}};
    }

    std::error_code error_code;
    std::filesystem::create_directories(root_, error_code);
    if (error_code) {
        return {false, "could not create '" + root_.string() + "': " + error_code.message(), {}};
    }

    const std::filesystem::path path = path_for(relationship.relationship_id);
    if (std::filesystem::exists(path)) {
        return {false, "a relationship with id '" + relationship.relationship_id + "' already exists", {}};
    }

    const RelationshipResult write_result = write_relationship_file(path, relationship);
    if (!write_result.success) {
        return {false, write_result.error, {}};
    }

    return {true, "", relationship};
}

LoadRelationshipResult RelationshipStore::load(const std::string& relationship_id) const {
    const std::filesystem::path path = path_for(relationship_id);
    if (!std::filesystem::exists(path)) {
        return {false, "no relationship with id '" + relationship_id + "'", {}};
    }

    const ParsedRelationship parsed = read_relationship_file(path);
    if (!parsed.success) {
        return {false, parsed.error, {}};
    }

    const std::vector<std::string> errors = validate_relationship(parsed.relationship);
    if (!errors.empty()) {
        return {false, "relationship '" + relationship_id + "' failed validation: " + join_errors(errors), {}};
    }

    return {true, "", parsed.relationship};
}

RelationshipResult RelationshipStore::update(Relationship relationship) const {
    const std::filesystem::path path = path_for(relationship.relationship_id);
    if (!std::filesystem::exists(path)) {
        return {false, "no relationship with id '" + relationship.relationship_id + "'"};
    }

    const ParsedRelationship existing = read_relationship_file(path);
    if (!existing.success) {
        return {false, existing.error};
    }

    // relationshipId, sourceObjectId, targetObjectId, relationshipType, and
    // createdUtc are immutable; only author and description may change.
    relationship.source_object_id = existing.relationship.source_object_id;
    relationship.target_object_id = existing.relationship.target_object_id;
    relationship.relationship_type = existing.relationship.relationship_type;
    relationship.created_utc = existing.relationship.created_utc;

    const std::vector<std::string> errors = validate_relationship(relationship);
    if (!errors.empty()) {
        return {false, "refusing to save invalid relationship: " + join_errors(errors)};
    }

    const RelationshipResult write_result = write_relationship_file(path, relationship);
    if (write_result.success) {
        record_audit(AuditEventType::RelationshipUpdated, relationship.relationship_id);
    }
    return write_result;
}

RelationshipResult RelationshipStore::remove(const std::string& relationship_id) const {
    const std::filesystem::path path = path_for(relationship_id);
    if (!std::filesystem::exists(path)) {
        return {false, "no relationship with id '" + relationship_id + "'"};
    }

    std::error_code error_code;
    std::filesystem::remove(path, error_code);
    if (error_code) {
        return {false, "could not remove '" + path.string() + "': " + error_code.message()};
    }

    record_audit(AuditEventType::RelationshipDeleted, relationship_id);
    return {true, ""};
}

ListRelationshipsResult RelationshipStore::list_by_object(const std::string& object_id) const {
    const ListRelationshipsResult all = list_all();
    if (!all.success) {
        return all;
    }

    std::vector<Relationship> matching;
    for (const Relationship& relationship : all.relationships) {
        if (relationship.source_object_id == object_id || relationship.target_object_id == object_id) {
            matching.push_back(relationship);
        }
    }

    return {true, "", matching};
}

ListRelationshipsResult RelationshipStore::list_all() const {
    std::vector<Relationship> relationships;
    std::vector<std::string> invalid_entries;

    std::error_code error_code;
    if (!std::filesystem::exists(root_, error_code)) {
        return {true, "", relationships, invalid_entries};
    }

    for (const std::filesystem::directory_entry& entry :
         std::filesystem::directory_iterator(root_, error_code)) {
        if (!entry.is_regular_file() || entry.path().extension() != ".json") {
            continue;
        }
        const ParsedRelationship parsed = read_relationship_file(entry.path());
        if (!parsed.success) {
            invalid_entries.push_back(entry.path().string() + ": " + parsed.error);
            continue;
        }
        relationships.push_back(parsed.relationship);
    }

    if (error_code) {
        return {false, "could not enumerate '" + root_.string() + "': " + error_code.message(), {}, {}};
    }

    return {true, "", relationships, invalid_entries};
}

} // namespace oep::repository
