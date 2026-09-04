#include "oep/acquisition/vault/vault_entry.hpp"

namespace oep::acquisition::vault {

std::string to_string(VaultEntryStatus status) {
  switch (status) {
    case VaultEntryStatus::Published:
      return "published";
  }
  return "published";
}

std::optional<VaultEntryStatus> vault_entry_status_from_string(const std::string& text) {
  if (text == "published") return VaultEntryStatus::Published;
  return std::nullopt;
}

}  // namespace oep::acquisition::vault
