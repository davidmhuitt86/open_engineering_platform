#include "oep/acquisition/api/auth.hpp"

#include <cstddef>

namespace oep::acquisition::api {

bool constant_time_equals(std::string_view a, std::string_view b) noexcept {
  if (a.size() != b.size()) {
    return false;
  }
  unsigned char diff = 0;
  for (std::size_t i = 0; i < a.size(); ++i) {
    diff |= static_cast<unsigned char>(a[i]) ^ static_cast<unsigned char>(b[i]);
  }
  return diff == 0;
}

namespace {
constexpr std::string_view kBearerPrefix = "Bearer ";
}  // namespace

std::optional<std::string> parse_bearer_token(const std::string& header_value) {
  if (header_value.size() <= kBearerPrefix.size()) {
    return std::nullopt;
  }
  if (header_value.compare(0, kBearerPrefix.size(), kBearerPrefix) != 0) {
    return std::nullopt;
  }
  std::string token = header_value.substr(kBearerPrefix.size());
  if (token.empty() || token.find(' ') != std::string::npos) {
    return std::nullopt;
  }
  return token;
}

}  // namespace oep::acquisition::api
