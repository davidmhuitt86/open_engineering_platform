#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace oep::repository {

// Strongly typed repository.json contents, per OEP-SPEC-003-REPOSITORY_METADATA.
struct RepositoryMetadata {
    std::string repository_id;
    std::string repository_name;
    std::string repository_version = "1.0.0";
    std::string foundation_version;
    std::string template_version;
    std::string created_utc;
    std::string last_modified_utc;
    std::string description;
    std::string author;
    std::string organization;
    std::vector<std::string> tags;
};

// Validates required fields, repositoryId's UUIDv4 format, and
// version fields' semantic-version format. Returns a human-readable
// error per violation found; an empty result means `metadata` is valid.
std::vector<std::string> validate_metadata(const RepositoryMetadata& metadata);

struct LoadMetadataResult {
    bool success = false;
    std::string error;
    RepositoryMetadata metadata;
};

// Reads and parses `path` as repository metadata and validates it.
// On any failure (invalid JSON, missing fields, malformed values),
// returns success = false with a descriptive error and never modifies `path`.
LoadMetadataResult load_metadata(const std::filesystem::path& path);

struct SaveMetadataResult {
    bool success = false;
    std::string error;
};

// Serializes `metadata` to `path`, setting last_modified_utc to the
// current time. Writes to a temporary file in the same directory and
// renames it into place, so `path` is never left partially written.
SaveMetadataResult save_metadata(const std::filesystem::path& path, RepositoryMetadata metadata);

} // namespace oep::repository
