#pragma once

#include <filesystem>
#include <string>

namespace oep::cli::generator {

struct GenerationResult {
    bool success;
    std::string message;
};

// Generates a Standard Repository at `destination`, per
// OEP-SPEC-002-FOUNDATION_REPOSITORY. Fails without writing anything
// if `destination` already exists and is non-empty.
GenerationResult generate_foundation_repository(const std::filesystem::path& destination,
                                                 const std::string& repository_name);

} // namespace oep::cli::generator
