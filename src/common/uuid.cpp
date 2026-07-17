#include "oep/acquisition/common/uuid.hpp"

#include <cctype>

namespace oep::acquisition::common {

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

}  // namespace oep::acquisition::common
