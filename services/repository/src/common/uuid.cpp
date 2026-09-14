#include "oep/server_repository/common/uuid.hpp"

#include <array>
#include <cctype>
#include <cstdio>
#include <random>

namespace oep::server_repository::common {

bool is_uuid_like(const std::string& text) {
  if (text.size() != 36) {
    return false;
  }
  for (std::size_t i = 0; i < text.size(); ++i) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (text[i] != '-') {
        return false;
      }
      continue;
    }
    if (std::isxdigit(static_cast<unsigned char>(text[i])) == 0) {
      return false;
    }
  }
  return true;
}

std::string generate_uuid_v4() {
  static thread_local std::mt19937_64 engine(std::random_device{}());
  std::uniform_int_distribution<int> hex_digit(0, 15);

  std::array<int, 16> bytes{};
  for (auto& byte : bytes) {
    byte = hex_digit(engine) << 4 | hex_digit(engine);
  }
  // Version 4, variant 1 (RFC 4122).
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  char buffer[37];
  std::snprintf(buffer, sizeof(buffer),
                "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x", bytes[0], bytes[1],
                bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10],
                bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
  return std::string(buffer);
}

}  // namespace oep::server_repository::common
