#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>

#include "oep/acquisition/integrity/hashing.hpp"

using namespace oep::acquisition::integrity;

namespace {

std::filesystem::path make_scratch_dir() {
  static std::atomic<int> counter{0};
  auto path = std::filesystem::temp_directory_path() / ("oep_hashing_test_" + std::to_string(++counter));
  std::filesystem::create_directories(path);
  return path;
}

}  // namespace

TEST_CASE("hash_file_sha256 computes the correct hash for known content", "[integrity][hashing]") {
  const auto dir = make_scratch_dir();
  const auto path = dir / "artifact.txt";
  std::ofstream(path, std::ios::binary) << "abc";

  const auto result = hash_file_sha256(path);
  REQUIRE(result.has_value());
  // SHA-256("abc") is a well-known test vector (FIPS 180-2 Appendix B.1).
  CHECK(result->sha256_hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  CHECK(result->file_size_bytes == 3);
}

TEST_CASE("hash_file_sha256 is deterministic across repeated reads", "[integrity][hashing]") {
  const auto dir = make_scratch_dir();
  const auto path = dir / "artifact.bin";
  std::ofstream(path, std::ios::binary) << "some engineering artifact contents";

  const auto first = hash_file_sha256(path);
  const auto second = hash_file_sha256(path);
  REQUIRE(first.has_value());
  REQUIRE(second.has_value());
  CHECK(first->sha256_hex == second->sha256_hex);
}

TEST_CASE("hash_file_sha256 hashes content larger than one internal chunk", "[integrity][hashing]") {
  const auto dir = make_scratch_dir();
  const auto path = dir / "large.bin";
  {
    std::ofstream stream(path, std::ios::binary);
    const std::string chunk(1024, 'x');
    for (int i = 0; i < 200; ++i) {  // ~200 KiB, larger than the 64 KiB read buffer.
      stream << chunk;
    }
  }

  const auto result = hash_file_sha256(path);
  REQUIRE(result.has_value());
  CHECK(result->file_size_bytes == 200 * 1024);
}

TEST_CASE("hash_file_sha256 returns nullopt for a missing file", "[integrity][hashing][missing-file]") {
  const auto dir = make_scratch_dir();
  const auto missing_path = dir / "does-not-exist.bin";

  CHECK_FALSE(hash_file_sha256(missing_path).has_value());
}

TEST_CASE("hash_file_sha256 returns nullopt for a path that is a directory, not a regular file",
          "[integrity][hashing][corrupt-file]") {
  const auto dir = make_scratch_dir();

  // A directory exists on disk but is not readable as artifact content --
  // WORK_PACKAGE-007's "Corrupt Files" case (distinct from "Missing
  // Files"), simulated here without needing to fabricate genuine bit-level
  // corruption, since content-level parsing is explicitly out of scope.
  CHECK_FALSE(hash_file_sha256(dir).has_value());
}
