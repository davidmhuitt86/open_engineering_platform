#include "oep/acquisition/integrity/hashing.hpp"

#include <fstream>
#include <system_error>
#include <vector>

#include <picosha2.h>

namespace oep::acquisition::integrity {

std::optional<FileHashResult> hash_file_sha256(const std::filesystem::path& path) {
  std::error_code error;
  if (!std::filesystem::is_regular_file(path, error) || error) {
    return std::nullopt;
  }

  std::ifstream stream(path, std::ios::binary);
  if (!stream.is_open()) {
    return std::nullopt;
  }

  picosha2::hash256_one_by_one hasher;
  std::vector<char> buffer(1 << 16);
  std::uint64_t total_bytes = 0;

  while (stream.read(buffer.data(), static_cast<std::streamsize>(buffer.size())) || stream.gcount() > 0) {
    const auto read_count = stream.gcount();
    hasher.process(buffer.begin(), buffer.begin() + read_count);
    total_bytes += static_cast<std::uint64_t>(read_count);
  }
  if (stream.bad()) {
    return std::nullopt;
  }

  hasher.finish();
  FileHashResult result;
  result.sha256_hex = picosha2::get_hash_hex_string(hasher);
  result.file_size_bytes = total_bytes;
  return result;
}

}  // namespace oep::acquisition::integrity
