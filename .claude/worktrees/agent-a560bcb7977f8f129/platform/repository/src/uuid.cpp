#include "oep/repository/uuid.hpp"

#include <cstdint>
#include <iomanip>
#include <random>
#include <regex>
#include <sstream>

namespace oep::repository {

namespace {
const std::regex kUuidV4Pattern(
    "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$");
}

std::string generate_uuid_v4() {
    std::random_device random_device;
    std::mt19937_64 engine(random_device());
    std::uniform_int_distribution<uint64_t> distribution;

    uint64_t high = distribution(engine);
    uint64_t low = distribution(engine);

    // Set version (4) and variant (RFC 4122) bits.
    high = (high & 0xFFFFFFFFFFFF0FFFULL) | 0x0000000000004000ULL;
    low = (low & 0x3FFFFFFFFFFFFFFFULL) | 0x8000000000000000ULL;

    std::ostringstream stream;
    stream << std::hex << std::setfill('0');
    stream << std::setw(8) << ((high >> 32) & 0xFFFFFFFF) << "-";
    stream << std::setw(4) << ((high >> 16) & 0xFFFF) << "-";
    stream << std::setw(4) << (high & 0xFFFF) << "-";
    stream << std::setw(4) << ((low >> 48) & 0xFFFF) << "-";
    stream << std::setw(12) << (low & 0xFFFFFFFFFFFFULL);

    return stream.str();
}

bool is_valid_uuid_v4(const std::string& value) {
    return std::regex_match(value, kUuidV4Pattern);
}

} // namespace oep::repository
