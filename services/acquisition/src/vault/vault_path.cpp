#include "oep/acquisition/vault/vault_path.hpp"

#include <algorithm>
#include <cctype>

namespace oep::acquisition::vault {

namespace {

bool is_well_formed_sha256_hex(const std::string& text) {
  if (text.size() != 64) {
    return false;
  }
  return std::all_of(text.begin(), text.end(), [](unsigned char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
  });
}

}  // namespace

std::filesystem::path compute_vault_path(const std::filesystem::path& vault_root,
                                            const std::string& sha256_hash) {
  if (!is_well_formed_sha256_hex(sha256_hash)) {
    return {};
  }
  return vault_root / sha256_hash.substr(0, 2) / sha256_hash;
}

}  // namespace oep::acquisition::vault
