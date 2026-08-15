#pragma once

#include <string>

namespace oep::repository {

// Generates a random (v4) UUID, used to identify repositories and Engineering Objects.
std::string generate_uuid_v4();

bool is_valid_uuid_v4(const std::string& value);

} // namespace oep::repository
