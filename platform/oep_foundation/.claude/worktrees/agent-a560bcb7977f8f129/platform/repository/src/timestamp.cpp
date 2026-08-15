#include "oep/repository/timestamp.hpp"

#include <chrono>
#include <format>

namespace oep::repository {

std::string current_timestamp_utc() {
    const auto now = std::chrono::system_clock::now();
    return std::format("{:%Y-%m-%dT%H:%M:%SZ}", std::chrono::floor<std::chrono::milliseconds>(now));
}

} // namespace oep::repository
