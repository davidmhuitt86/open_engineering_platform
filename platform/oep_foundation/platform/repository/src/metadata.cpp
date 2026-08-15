#include "oep/repository/metadata.hpp"

#include <fstream>
#include <regex>
#include <sstream>
#include <system_error>

#include "oep/repository/json_value.hpp"
#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

namespace oep::repository {

namespace {

const std::regex kSemanticVersionPattern("^[0-9]+\\.[0-9]+\\.[0-9]+$");

std::string read_field(const json::Value& object, const char* key) {
    const json::Value* found = object.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

std::vector<std::string> read_tags(const json::Value& object) {
    std::vector<std::string> tags;
    const json::Value* found = object.find("tags");
    if (found == nullptr || !found->is_array()) {
        return tags;
    }
    for (const json::Value& entry : found->as_array()) {
        if (entry.is_string()) {
            tags.push_back(entry.as_string());
        }
    }
    return tags;
}

json::Value to_json(const RepositoryMetadata& metadata) {
    json::Array tags;
    for (const std::string& tag : metadata.tags) {
        tags.push_back(json::Value::string(tag));
    }

    json::Object object;
    object.emplace_back("repositoryId", json::Value::string(metadata.repository_id));
    object.emplace_back("repositoryName", json::Value::string(metadata.repository_name));
    object.emplace_back("repositoryVersion", json::Value::string(metadata.repository_version));
    object.emplace_back("foundationVersion", json::Value::string(metadata.foundation_version));
    object.emplace_back("templateVersion", json::Value::string(metadata.template_version));
    object.emplace_back("createdUtc", json::Value::string(metadata.created_utc));
    object.emplace_back("lastModifiedUtc", json::Value::string(metadata.last_modified_utc));
    object.emplace_back("description", json::Value::string(metadata.description));
    object.emplace_back("author", json::Value::string(metadata.author));
    object.emplace_back("organization", json::Value::string(metadata.organization));
    object.emplace_back("tags", json::Value::array(std::move(tags)));
    return json::Value::object(std::move(object));
}

} // namespace

std::vector<std::string> validate_metadata(const RepositoryMetadata& metadata) {
    std::vector<std::string> errors;

    if (metadata.repository_id.empty()) {
        errors.push_back("repositoryId is required");
    } else if (!is_valid_uuid_v4(metadata.repository_id)) {
        errors.push_back("repositoryId is not a valid UUIDv4");
    }

    if (metadata.repository_name.empty()) {
        errors.push_back("repositoryName is required");
    }

    if (metadata.foundation_version.empty()) {
        errors.push_back("foundationVersion is required");
    }

    if (metadata.template_version.empty()) {
        errors.push_back("templateVersion is required");
    }

    if (metadata.created_utc.empty()) {
        errors.push_back("createdUtc is required");
    }

    if (metadata.last_modified_utc.empty()) {
        errors.push_back("lastModifiedUtc is required");
    }

    if (!std::regex_match(metadata.repository_version, kSemanticVersionPattern)) {
        errors.push_back("repositoryVersion must be in the form major.minor.patch");
    }

    return errors;
}

LoadMetadataResult load_metadata(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'", {}};
    }

    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();
    const std::string contents = contents_stream.str();

    const json::ParseResult parsed = json::parse(contents);
    if (!parsed.success) {
        return {false, "invalid JSON in '" + path.string() + "': " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "'" + path.string() + "' must contain a JSON object", {}};
    }

    RepositoryMetadata metadata;
    metadata.repository_id = read_field(parsed.value, "repositoryId");
    metadata.repository_name = read_field(parsed.value, "repositoryName");
    metadata.repository_version = read_field(parsed.value, "repositoryVersion");
    metadata.foundation_version = read_field(parsed.value, "foundationVersion");
    metadata.template_version = read_field(parsed.value, "templateVersion");
    metadata.created_utc = read_field(parsed.value, "createdUtc");
    metadata.last_modified_utc = read_field(parsed.value, "lastModifiedUtc");
    metadata.description = read_field(parsed.value, "description");
    metadata.author = read_field(parsed.value, "author");
    metadata.organization = read_field(parsed.value, "organization");
    metadata.tags = read_tags(parsed.value);

    const std::vector<std::string> errors = validate_metadata(metadata);
    if (!errors.empty()) {
        std::string message = "metadata in '" + path.string() + "' failed validation: ";
        for (std::size_t i = 0; i < errors.size(); ++i) {
            message += errors[i];
            if (i + 1 != errors.size()) message += "; ";
        }
        return {false, message, {}};
    }

    return {true, "", metadata};
}

SaveMetadataResult save_metadata(const std::filesystem::path& path, RepositoryMetadata metadata) {
    metadata.last_modified_utc = current_timestamp_utc();
    if (metadata.created_utc.empty()) {
        metadata.created_utc = metadata.last_modified_utc;
    }

    const std::vector<std::string> errors = validate_metadata(metadata);
    if (!errors.empty()) {
        std::string message = "refusing to save invalid metadata: ";
        for (std::size_t i = 0; i < errors.size(); ++i) {
            message += errors[i];
            if (i + 1 != errors.size()) message += "; ";
        }
        return {false, message};
    }

    const std::string serialized = json::serialize(to_json(metadata));

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

} // namespace oep::repository
